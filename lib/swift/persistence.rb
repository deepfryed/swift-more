require 'zlib'

module Swift
  class Record
    attr_accessor :persisted, :visited, :crc

    class << self
      alias :class_name :name
    end

    def self.first where = nil, *args
      execute("select * from #{self} %s limit 1" % (where ? "where #{where}" : ''), *args).first
    end

    def self.all where = nil, *args, &block
      execute("select * from #{self} %s" % (where ? "where #{where}" : ''), *args, &block)
    end

    def self.load tuple
      record           = allocate
      record.tuple     = tuple
      record.persisted = true
      record.crc       = Hash[tuple.map {|key, value| [key, Zlib.crc32(value.to_s)]}]
      record
    end

    def self.create resources = {}
      instances = []
      [resources].flatten.each do |resource|
        # create includes nested associations
        if resource.find {|k, v| v.kind_of?(Record) || (v.kind_of?(Array) && v.first.kind_of?(Record))}
          instance = new(resource)
          instance.save
        else
          instance = resource.kind_of?(Record) ? resource : new(resource)
          Swift.db.create(self, instance)
        end
        instance.crc       = Hash[instance.tuple.map {|key, value| [key, Zlib.crc32(value.to_s)]}]
        instance.persisted = true
        instances         << instance
      end
      instances.size == 1 ? instances.first : instances
    end

    def new?
      !persisted
    end

    def dirty?
      !tuple.find {|key, value| crc[key] != Zlib.crc32(value.to_s)}.empty?
    end

    def crc
      @crc ||= {}
    end

    def dirty_attributes
      tuple.select do |key, value|
        record.header.updatable.include?(record.send(key).field) && crc[key] != Zlib.crc32(value.to_s)
      end
    end

    def save transaction = true
      begin
        transaction ? Swift.db.transaction { _save } : _save
        commit
      rescue => e
        rollback
        raise e
      end
      self
    end

    def update attrs = {}
      attrs.each {|key, value| self.send("#{key}=", value)}
      dirty = dirty_attributes
      return if dirty.empty?

      set   = dirty.keys.map {|key| "#{record.send(key).field} = ?"}.join(', ')
      where = record.header.keys.map{|key| "#{key} = ?"}.join(' and ')
      Swift.db.execute("update #{record.store} set #{set} where #{where}", *dirty.values, *tuple.values_at(*record.header.keys))
    end

    private

      def _save
        cache = @__rel || {}
        self.visited = true
        (cache[:belongsto] || {}).each {|name, rel| rel.save}
        new? && Swift.db.create(record, self) || self.update
        (cache[:hasmany]   || {}).each {|name, rel| rel.save}
        (cache[:hasone]    || {}).each {|name, rel| rel.save}
      end

      # NOTE commit and rollback terminology is confusing since its
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
        if new? && (serial = record.header.serial)
          tuple[serial] = nil
        end
        (cache[:hasmany] || {}).each {|name, rel| rel.rollback}
        (cache[:hasone]  || {}).each {|name, rel| rel.rollback}
        self.visited = false
      end
  end # Record
end # Swift
