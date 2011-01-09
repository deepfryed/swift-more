# I wish we can avoid this somehow :(
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
  class Scheme
    attr_accessor :persisted

    def self.load tuple
      scheme           = allocate
      scheme.tuple     = tuple
      scheme.persisted = true
      scheme
    end

    def new?
      !persisted
    end

    def save
      cache = @__rel || {}
      Swift.db.transaction do
        (cache[:belongsto] || {}).each {|name, rel| rel.save}
        new? && scheme.create(self) || self.update
        (cache[:hasmany] || {}).each {|name, rel| rel.save}
        (cache[:hasone]  || {}).each {|name, rel| rel.save}
      end
      self.persisted = true
    end

    def self.attribute name, type, options = {}
      type = Swift::Type.const_get(type.name) rescue type
      header.push(attribute = type.new(self, name, options))
      (class << self; self end).send(:define_method, name, lambda{ attribute })
    end
    Boolean = Type::Boolean
  end
end
