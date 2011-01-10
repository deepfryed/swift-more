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
