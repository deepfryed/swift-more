module Swift
  module Associations

    def has_many name, target=nil, options={}
      options, target = target, nil if target.kind_of?(Hash)
      HasMany.install self, options.merge(name: name, target: target)
      HasMany.install self, options.merge(name: options[:through], through: nil) if options[:through]
    end

    def belongs_to name, target=nil, options={}
      options, target = target, nil if target.kind_of?(Hash)
      BelongsTo.install self, options.merge(name: name, target: target)
    end

    def has_one name, target=nil, options={}
      options, target = target, nil if target.kind_of?(Hash)
      HasOne.install self, options.merge(name: name, target: target)
    end

    module Chainable
      def method_missing name, *args
        if target.respond_to?(name)
          self.class.send(:define_method, name) do |*params|
            options = params.last.is_a?(Hash) ? params.pop : {}
            params.push(options.merge(chains: self.chains ? self.chains.unshift(self) : [self]))
            self.target.send(name, *params)
          end
          self.send(name, *args)
        else
          super
        end
      end
    end # Chainable

    class Base
      include Chainable
      include Enumerable

      attr_accessor :source, :target, :source_scheme, :source_keys, :target_keys
      attr_accessor :chains, :conditions, :bind, :ordering, :endpoint, :name

      def initialize options
        name           = options.fetch :name
        @source        = options.fetch :source
        @source_scheme = source.is_a?(Class) && source || source.class
        @target        = name_to_class(options[:target] ||  name)

        # optional stuff
        @chains     = options.fetch :chains,     nil
        @conditions = options.fetch :conditions, []
        @bind       = options.fetch :bind,       []
        @ordering   = options.fetch :order,      []

        if through = options[:through]
          @endpoint = name
          @target   = name_to_class(through)
        end

        @source or raise ArgumentError, '+source+ required'
        @target or raise ArgumentError, "Unable to deduce class name for relation :#{name} in #{@source}"

        if mapping = options.delete(:mapping)
          options.merge! source_keys: mapping.keys, target_keys: mapping.values
        end
      end

      def name_to_class name
        klass = name.kind_of?(Class) && name || name.class
        klass < Swift::Scheme ? klass : const_search(source_scheme, name)
      end

      def const_search scheme, name
        name = name.kind_of?(Symbol) ? Inflect.singular(name.to_s).capitalize : name.to_s
        scheme.const_get_recursive(name)
      end

      def size
        all.size
      end

      def each &block
        all.each(&block)
      end

      def all
        @collection ||= source && source.respond_to?(:new?) && source.new? ? [] : self.load.to_a
      end

      def load
        if endpoint
          opts = {chains: chains ? [self] + chains : [self]}
          target.send(endpoint, opts.merge(conditions: conditions, bind: bind, order: ordering))
        else
          Swift.db.load_through(target, self)
        end
      end

      # only appends to whatever has been loaded so far. you need to save and reload if you want to
      # iterate through the entire collection.
      def << *list
        @collection ||= []
        if invalid = list.reject {|scheme| scheme.kind_of?(target)} and !invalid.empty?
          #raise ArgumentError, "invalid object, expecting #{target.class_name} got #{invalid}"
        end
        @collection += list
      end

      def [] n
        all[n]
      end

      def last
        all.last
      end

      def replace list
        @collection = list.flatten.reject(&:nil?).uniq
      end

      def create attrs
        if source.kind_of?(Swift::Scheme)
          target.create attrs.merge! Hash[target_keys.zip(source_keys.map{|name| source.send(name)})]
        elsif chains && chains.first
          chains.first.map do |source|
            target.create attrs.merge! Hash[target_keys.zip(source_keys.map{|name| source.send(name)})]
          end
        end
      end

      def reload
        @collection = nil
        target.send(endpoint).reload if endpoint
        self
      end

      def delete
        if endpoint
          opts = {chains: chains ? [self] + chains : [self]}
          target.send(endpoint, opts.merge(conditions: conditions, bind: bind, order: ordering)).delete
        else
          Swift.db.delete_through target, self
        end
      end

      def self.cached source, name, args, options
        if args.empty?
          source.send(association_cache)[name] ||= new(options.merge(source: source))
        else
          uncached(source, name, args, options)
        end
      end

      def self.uncached source, name, args, options
        options = options.merge source: source
        custom = args.last.kind_of?(Hash) ? args.pop.merge(options) : options
        custom.merge!(conditions: [args.shift], bind: args) if args.first
        new(custom)
      end

      def self.label
        @label ||= self.to_s.split(/::/).last.downcase.to_sym
      end

      def self.association_cache
        @association_cache ||= "_#{label}_cached"
      end

      def self.get_association_index klass
        if klass.class_variable_defined?(:@@association_index)
          klass.class_variable_get(:@@association_index)[label] || {}
        else
          {}
        end
      end

      def self.set_association_index klass, value
        orig  = klass.class_variable_get(:@@association_index) rescue {}
        klass.class_variable_set(:@@association_index, orig.merge(label => value))
      end

      def self.add_association klass, type, options
        __assoc__   = self
        index       = get_association_index(klass)
        name        = options.fetch(:name)
        index[name] = lambda {__assoc__.new(options.merge(source: klass))}
        set_association_index(klass, index)
      end

      def self.scheme_name scheme
        Inflect.singular scheme.class_name.to_s.split(/::/).last.downcase
      end
    end # Base

    class HasMany < Base
      attr_accessor :old

      def initialize options
        super(options)
        @source_keys = options.fetch :source_keys, [:id]
        @target_keys = options.fetch :target_keys, ["#{Base.scheme_name(source_scheme)}_id"]
      end

      def self.install klass, options
        name = options.fetch(:name)
        add_association(klass, :hasmany, options)

        klass.send(:define_method, association_cache) do
          (@__rel ||= Hash.new{|h,k| h[k] = Hash.new})[:hasmany]
        end
        klass.send(:define_method, name) do |*args|
          HasMany.cached(self, name, args, options)
        end
        klass.send(:define_method, "#{name}=") do |list|
          HasMany.cached(self, name, [], options).replace(list)
        end
        klass.send(:define_singleton_method, name) do |*args|
          HasMany.uncached(self, name, args, options)
        end
      end

      def save
        endpoint ? save_through : save_collection
      end

      # TODO very slow, speed it up.
      def save_through
        rel = BelongsTo.get_association_index(target)
        fn1 = rel.find {|k,v| v.call.target == self.source_scheme}[0]
        fn2 = (rel.keys - [fn1])[0]
        (@collection || []).each {|item| target.new(fn1 => source, fn2 => item).save}
      end

      def save_collection
        old.each(&:delete) if old && !old.empty?
        (@collection || []).each do |item|
          next if item.visited
          target_keys.zip(source_keys).each {|t,s| item.send("#{t}=", source.send(s))}
          # in case the whole thing fails, we will roll back persisted and internal states.
          item.persisted, discarded_value = item.persisted, item.save
        end
      end

      def replace list
        reload
        self.old = all
        super
      end

      def commit
        self.old = nil
        (@collection || []).each {|item| item.send(:commit)}
      end

      def rollback
        (@collection || []).each {|item| item.send(:rollback)}
      end
    end # HasMany

    class BelongsTo < Base
      def initialize options
        super(options)
        @target_keys = options.fetch :target_keys, [:id]
        @source_keys = options.fetch :source_keys, ["#{Base.scheme_name(target)}_id"]
      end

      def self.install klass, options
        name = options.fetch(:name)
        add_association(klass, :belongsto, options)

        klass.send(:define_method, association_cache) do
          (@__rel ||= Hash.new{|h,k| h[k] = Hash.new})[:belongsto]
        end
        klass.send(:define_method, name) do |*args|
          BelongsTo.cached(self, name, args, options).first
        end
        klass.send(:define_method, "#{name}=") do |list|
          BelongsTo.cached(self, name, [], options).replace([list])
        end
        klass.send(:define_singleton_method, Inflect.plural(name.to_s)) do |*args|
          BelongsTo.uncached(self, name, args, options)
        end
      end

      def replace list
        super
        save
      end

      def save
        if item = @collection.first
          item.save if item.new? && !item.visited
          target_keys.zip(source_keys).each {|t,s| source.send("#{s}=", item.send(t))}
        else
          target_keys.zip(source_keys).each {|t,s| source.send("#{s}=", nil)}
        end
      end
    end # BelongsTo

    class HasOne < HasMany
      def self.install klass, options
        name = options.fetch(:name)
        add_association(klass, :hasone, options)

        klass.send(:define_method, association_cache) do
          (@__rel ||= Hash.new{|h,k| h[k] = Hash.new})[:hasone]
        end
        klass.send(:define_method, name) do |*args|
          HasOne.cached(self, name, args, options).first
        end
        klass.send(:define_method, "#{name}=") do |list|
          HasOne.cached(self, name, [], options).replace([list])
        end
        klass.send(:define_singleton_method, Inflect.plural(name.to_s)) do |*args|
          HasOne.uncached(self, name, args, options)
        end
      end
    end # HasOne
  end # Associations

  class Scheme
    extend Associations

    class LazyAll
      def self.new scheme, args, &block
        if block_given?
          scheme._all(*args, &block)
        else
          instance = allocate
          instance.setup(scheme, args)
          instance
        end
      end

      def setup scheme, args
        @scheme, @args = scheme, args
        @index = [Associations::HasMany, Associations::HasOne, Associations::BelongsTo].map do |klass|
          klass.get_association_index(scheme).keys.map(&:to_sym)
        end.flatten
      end

      def method_missing name, *args, &block
        if @index.include?(name)
          Associations::HasMany.uncached(@scheme, nil, @args, {target: @scheme, name: nil}).send(name, *args)
        else
          @scheme._all(*@args).send(name, *args, &block)
        end
      end
    end # LazyAll

    class << self
      alias _all all

      def all *args, &block
        LazyAll.new(self, args, &block)
      end
    end
  end # Scheme
end #Swift
