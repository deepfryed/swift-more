module Swift
  class Scheme
    attr_accessor :persisted

    # TODO wrappers for load & create ?
    def self.load tuple
      scheme           = allocate
      scheme.tuple     = tuple
      scheme.persisted = true
      scheme
    end

    def self.create options = {}
      if instance = Swift.db.create(self, options).first
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
          (cache[:belongsto] || {}).each {|name, rel| rel.save}
          new? && db.create(scheme, self) || self.update
          (cache[:hasmany] || {}).each {|name, rel| rel.save}
          (cache[:hasone]  || {}).each {|name, rel| rel.save}
        end
        commit
      rescue Exception => error
        rollback
        raise error
      end
    end

    # TODO commit and rollback terminology here might be confusing since its
    #      used in the context of internal states not persisted ones.
    private
      def commit
        cache = @__rel || {}
        (cache[:hasmany] || {}).each {|name, rel| rel.commit}
        (cache[:hasone]  || {}).each {|name, rel| rel.commit}
        self.persisted = true
      end

      def rollback
        cache = @__rel || {}
        self.send("#{scheme.header.serial}=", nil) if new? && scheme.header.serial
        (cache[:hasmany] || {}).each {|name, rel| rel.rollback}
        (cache[:hasone]  || {}).each {|name, rel| rel.rollback}
      end
  end
end
