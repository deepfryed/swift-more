module Swift
  class Record
    class << self
      alias define_attribute attribute
    end

    def self.attribute name, type, options = {}
      define_attribute(name, swift_type(type), options)
    end

    def self.swift_type type
      Swift::Type.const_get(type.name) rescue type
    end

    Boolean = Type::Boolean
  end
end
