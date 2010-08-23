require_relative 'associations'

module Swift
  class Scheme
    attr_accessor :persisted

    def self.attribute name, type, options = {}
      type = Swift::Type.const_get(type.name) rescue type
      header.push(attribute = type.new(self, name, options))
      (class << self; self end).send(:define_method, name, lambda{ attribute })
    end

    def self.load tuple
      scheme           = allocate
      scheme.tuple     = tuple
      scheme.persisted = true
      scheme
    end

    def self.create *options
      res = Swift.db.create(self, *options)
      options.length > 1 ? res : res.first
    end

    def save
      instance = persisted ? update.first : scheme.create(self)
      instance.persisted = true
      instance
    end

    def new?
      !persisted
    end

    Boolean = Type::Boolean
  end # Scheme
end # Swift
