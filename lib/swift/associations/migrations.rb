module Swift
  def self.migrate! name = nil
    db(name).run_migrations do |db|
      schema.each {|scheme| db.migrate! scheme}
      schema.each {|scheme| db.migrate_associations! scheme}
    end
  end

  class Scheme
    def self.migrate! db = Swift.db, associations=false
      db.migrate! self
      db.migrate_associations!(self) if associations
    end
  end

  # TODO customizable on-delete and on-update actions.
  class Adapter::Sql
    def foreign_key_definition source, source_keys, target, target_keys
      name = "#{source.store}_#{target.store}_#{source_keys.join('_')}_fkey"
      sql  =<<-SQL
        alter table #{source.store} add constraint #{name} foreign key(#{source_keys.join(', ')})
        references #{target.store}(#{target_keys.join(', ')}) on delete cascade on update cascade
      SQL
      sql.gsub(/[\r\n]/, ' ').gsub(/ +/, ' ').strip
    end

    def run_migrations &block
      block.call(self)
    end

    def migrate_associations! scheme
      Swift::Associations::BelongsTo.get_association_index(scheme).values.map(&:call).each do |rel|
        args = [rel.source, rel.source_keys, rel.target, rel.target_keys]
        [foreign_key_definition(*args)].flatten.each {|sql| execute(sql)}
      end
    end
  end

  module DB
    class Sqlite3 < Adapter::Sql
      # NOTE no alter table add foreign key support - got to rebuild the table.
      def foreign_key_definition source, source_keys, target, target_keys

        cascade = "on delete cascade on update cascade"
        map     = Hash[source_keys.map(&:to_s).zip(target_keys.map{|f| " references #{target.store}(#{f}) #{cascade}"})]

        keys    =  source.header.keys
        serial  =  source.header.find(&:serial)
        fields  =  source.header.map {|p| field_definition(p) + (map[p.field.to_s] || '')}.join(', ')
        fields += ", primary key (#{keys.join(', ')})" unless serial or keys.empty?

        [ "drop table if exists #{source.store}", "create table #{source.store} (#{fields})"]
      end
    end # Sqlite3

    class Mysql < Adapter::Sql
      def run_migrations &block
        execute('set foreign_key_checks = 0')
        block.call(self)
        execute('set foreign_key_checks = 1')
      end
    end # Mysql
  end # DB
end # Swift
