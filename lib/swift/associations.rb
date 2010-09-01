require_relative 'inflect'
require_relative 'associations/crud'

# TODO find a better way to do this without mucking around in core.
class Object
  def const_get_relative name
    klass = self
    mods  = klass.to_s.split(/::/)
    while mods.length > 0
      mods.pop
      return klass.const_get(name) if klass.const_defined?(name)
      klass = klass.const_get(mods.join('::'))
    end
  end
  def const_get_recursive name
    name.split(/::/).inject(self) {|a,v| a.const_get_relative(v) } rescue nil
  end
end

module Swift
  module Associations
    class Relationship
      attr_accessor :source, :target, :source_keys, :target_keys, :chains
      attr_reader   :source_scheme, :target_scheme, :conditions, :bind, :ordering

      def initialize options = {}
        @chains        = options.fetch(:chains, [])
        @source        = options[:source] or raise ArgumentError, '+source+ required'
        @target        = options[:target] or raise ArgumentError, '+target+ required'
        @source_scheme = source.kind_of?(Scheme) ? source.scheme : source
        @target_scheme = target.kind_of?(Scheme) ? target.scheme : target
        @source_keys   = options[:source_keys]
        @target_keys   = options[:target_keys]

        @conditions    = options.fetch(:condition, [])
        @bind          = options.fetch(:bind, [])
        @ordering      = options.fetch(:order, nil)
        @conditions    = [ conditions ] unless conditions.kind_of?(Array)
      end

      def load
        Swift.db.associations_fetch(target, self)
      end

      def self.parse_options args
        options = args.last.is_a?(Hash) ? args.pop : {}
        options[:condition] = args.shift unless args.empty?
        options[:bind]      = args       unless args.empty?
        options
      end

      def self.find_scheme klass, name
        if name.kind_of?(Class)
          name
        else
          name  = Inflect.singular(name.to_s).sub(/^(.)/) { $1.upcase } unless name =~ /::/
          klass.const_get_recursive(name)
        end
      end

      def all
        self.load.to_a
      end

      def each &block
        self.load.each(&block)
      end

      def first
        Swift.db.associations_fetch_first(target, self)
      end

      def create args={}
        if source.kind_of?(Scheme)
          defaults = Hash[*target_keys.zip(source.tuple.values_at(*source_keys)).flatten]
          target.create(args.merge(defaults))
        else
          raise NoMethodError, 'undefined method create in %s' % self
        end
      end

      def destroy *args
        Swift.db.associations_destroy(target, self)
      end

      module Chainable
        def method_missing name, *args
          options = args.last.is_a?(Hash) ? args.pop : {}
          args << { chains: [ self ] + chains }.merge(options)
          if target.respond_to?(name)
            target.send(name, *args)
          else
            raise NoMethodError, 'undefined method %s in %s' % [ name, self ]
          end
        end
      end # Chainable

      include Chainable
    end # Relationship

    class Has < Relationship
      def initialize options = {}
        source = options[:source]
        scheme = source.kind_of?(Scheme) ? source.scheme : source
        name   = Inflect.singular(scheme.store.to_s)
        options[:source_keys] ||= scheme.header.keys
        options[:target_keys] ||= scheme.header.keys.map {|k| '%s_%s' % [ name, k ] }
        super(options)
      end
    end # Has

    class HasMany < Has
      def self.install source, accessor, options
        source.send(:define_method, accessor) do |*args|
          scheme  = HasMany.find_scheme(source, options.fetch(:scheme, accessor))
          args    = HasMany.parse_options(args)
          options = options.merge(source: self, target: scheme)
          HasMany.new(options.merge(args))
        end
        source.send(:define_singleton_method, accessor) do |*args|
          scheme  = HasMany.find_scheme(self, options.fetch(:scheme, accessor))
          args    = HasMany.parse_options(args)
          options = options.merge(source: source, target: scheme)
          HasMany.new(options.merge(args))
        end
      end
    end # HasMany

    class HasOne < Has
      def self.install source, accessor, options
        source.send(:define_method, accessor) do |*args|
          scheme  = HasOne.find_scheme(source, options.fetch(:scheme, accessor))
          args    = HasOne.parse_options(args)
          options = options.merge(source: self, target: scheme)
          HasOne.new(options.merge(args)).first
        end
        source.send(:define_singleton_method, Inflect.plural(accessor.to_s)) do |*args|
          scheme  = HasOne.find_scheme(self, options.fetch(:scheme, accessor))
          args    = HasOne.parse_options(args)
          options = options.merge(source: source, target: scheme)
          HasOne.new(options.merge(args))
        end
      end
    end # HasOne

    class BelongsTo < Relationship
      def initialize options = {}
        target = options[:target]
        name   = Inflect.singular(target.store.to_s)
        options[:source_keys] ||= target.header.keys.map {|k| '%s_%s' % [ name, k ] }
        options[:target_keys] ||= target.header.keys
        super(options)
      end
      def create args={}
        raise NoMethodError, 'undefined method create in %s' % self
      end
      def self.install source, accessor, options
        source.send(:define_method, accessor) do |*args|
          scheme  = BelongsTo.find_scheme(source, options.fetch(:scheme, accessor))
          args    = BelongsTo.parse_options(args)
          options = options.merge(source: self, target: scheme)
          BelongsTo.new(options.merge(args)).first
        end
        source.send(:define_singleton_method, Inflect.plural(accessor.to_s)) do |*args|
          scheme  = BelongsTo.find_scheme(self, options.fetch(:scheme, accessor))
          args    = BelongsTo.parse_options(args)
          options = options.merge(source: source, target: scheme)
          BelongsTo.new(options.merge(args))
        end
      end
    end # BelongsTo

    module Helpers
      def has_one name, options={}
        HasOne.install(self, name, options)
      end

      def has_many name, options={}
        HasMany.install(self, name, options)
      end

      def belongs_to name, options={}
        BelongsTo.install(self, name, options)
      end
    end
  end # Associations

  class Scheme
    extend Associations::Helpers
  end # Scheme
end
