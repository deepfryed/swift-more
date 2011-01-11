module Swift
  module Associations
    def has_many name, options={}
      HasMany.install self, options.merge(name: name)
      if options[:through]
        options = options.dup.merge(name: options[:through], through: nil, target: nil)
        HasMany.install self, options.reject{|k,v| v.nil?}
      end
    end

    def belongs_to name, options={}
      BelongsTo.install self, options.merge(name: name)
    end

    module Chainable
      def method_missing name, *args
        if target.respond_to?(name)
          options = args.last.is_a?(Hash) ? args.pop : {}
          target.send(name, *args.push(options.merge(chains: chains ? chains.unshift(self) : [self])))
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
        @target        = name_to_class(options.fetch :target, name)

        # optional stuff
        @chains     = options.fetch :chains,     nil
        @conditions = options.fetch :conditions, []
        @bind       = options.fetch :bind,       []
        @ordering   = options.fetch :ordering,   []

        if through = options[:through]
          @endpoint = name
          @target   = name_to_class(through)
        end

        @source or raise ArgumentError, '+source+ required'
        @target or raise ArgumentError, "Unable to deduce class name for relation :#{name}, provide :target"
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
        endpoint ? target.send(endpoint, {chains: chains ? [self] + chains : [self]})
                 : Swift.db.load_through(target, self)
      end

      def << *list
        all && list.each {|item| @collection << item }
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
        self
      end

      def self.cached source, name, args, options
        if args.empty?
          source.send(cache_label)[name] ||= new(options.merge(source: source))
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

      def self.cache_label
        @cache_label ||= '_%s_cached' % self.to_s.split(/::/).last.downcase
      end

      def save; end
    end # Base

    class HasMany < Base
      attr_accessor :old

      def initialize options
        super(options)
        @source_keys = options.fetch :source_keys, [:id]
        @target_keys = options.fetch :target_keys, [source_scheme.to_s.split(/::/).last.downcase + '_id']
      end

      def self.install klass, options
        name = options.fetch(:name)
        klass.send(:define_method, cache_label) do
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
        old.each(&:destroy) if old && !old.empty?
        (@collection || []).each do |item|
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
        @source_keys = options.fetch :source_keys, [target.to_s.split(/::/).last.downcase + '_id']
      end

      def self.install klass, options
        name = options.fetch(:name)
        klass.send(:define_method, cache_label) do
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
          item.save if item.new?
          target_keys.zip(source_keys).each {|t,s| source.send("#{s}=", item.send(t))}
        else
          target_keys.zip(source_keys).each {|t,s| source.send("#{s}=", nil)}
        end
      end
    end # BelongsTo

    class HasOne < HasMany
      def self.install klass, options
        name = options.fetch(:name)
        klass.send(:define_method, cache_label) do
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

    # TODO find a better name, though i don't want to mix #all and #only
    def self.only *args
      Associations::HasMany.uncached(self, nil, args, {target: self, name: nil})
    end
  end # Scheme
end #Swift
