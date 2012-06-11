module Swift
  class Scheme
    attr_accessor :persisted, :visited

    class << self
      alias :class_name :name
    end

    def self.first where = nil, *args
      execute("select * from #{self} %s limit 1" % (where ? "where #{where}" : ''), *args).first
    end

    def self.all where = nil, *args, &block
      execute("select * from #{self} %s" % (where ? "where #{where}" : ''), *args, &block)
    end

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
      elsif instance = Swift.db.create(self, options)
        instance.persisted = true
        instance
      end
    end

    def new?
      !persisted
    end

    def save transaction = true
      begin
        transaction ? Swift.db.transaction { _save } : _save
        commit
      rescue Exception => e  # TODO: do we need to trap Exception here ?
        rollback
        raise e
      end
      self
    end

    private

      def _save
        cache = @__rel || {}
        self.visited = true
        (cache[:belongsto] || {}).each {|name, rel| rel.save}
        new? && Swift.db.create(scheme, self) || self.update
        (cache[:hasmany]   || {}).each {|name, rel| rel.save}
        (cache[:hasone]    || {}).each {|name, rel| rel.save}
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
