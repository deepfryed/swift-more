module Swift
  class Scheme
    ORIGINAL_ATTRIBUTE_METHOD = method(:attribute)

    def self.attribute name, type, options = {}
      type = Swift::Type.const_get(type.name) rescue type
      ORIGINAL_ATTRIBUTE_METHOD.unbind.bind(self).call(name, type, options)
    end

    Boolean = Type::Boolean
  end
end
