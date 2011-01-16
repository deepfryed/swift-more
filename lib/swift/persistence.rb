module Swift
  class Scheme
    attr_accessor :persisted, :visited

    # TODO wrappers for load & create ?
    def self.load tuple
      scheme           = allocate
      scheme.tuple     = tuple
      scheme.persisted = true
      scheme
    end

    def self.create options = {}
      if options.find {|k,v| v.kind_of?(Scheme) || v.kind_of?(Array)}
        instance = new(options)
        instance.save
        instance
      elsif instance = Swift.db.create(self, options).first
        instance.persisted = true
        instance
      end
    end

    def new?
      !persisted
    end

    def save
      cache = @__rel || {}
      begin
        Swift.db.transaction do |db|
          self.visited = true
          (cache[:belongsto] || {}).each {|name, rel| rel.save}
          new? && db.create(scheme, self) || self.update
          (cache[:hasmany]   || {}).each {|name, rel| rel.save}
          (cache[:hasone]    || {}).each {|name, rel| rel.save}
        end
        commit
      rescue Exception => error
        rollback
        raise error
      end
      self
    end

    # TODO commit and rollback terminology here might be confusing since its
    #      used in the context of internal states not persisted ones.
    def commit
      cache = @__rel || {}
      (cache[:hasmany] || {}).each {|name, rel| rel.commit}
      (cache[:hasone]  || {}).each {|name, rel| rel.commit}
      self.persisted = true
      self.visited   = false
    end

    def rollback
      cache = @__rel || {}
      if new? && (serial = scheme.header.serial)
        tuple[serial] = nil
      end
      (cache[:hasmany] || {}).each {|name, rel| rel.rollback}
      (cache[:hasone]  || {}).each {|name, rel| rel.rollback}
      self.visited = false
    end
  end
end
