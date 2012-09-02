# TODO customizable on-delete and on-update actions.
module Swift
  class Adapter
    class Sql
      alias :migrate_record :migrate!

      def migrate! record
        migrate_record(record)
        migrate_associations(record)
      end

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

      def migrate_associations record
        Swift::Associations::BelongsTo.get_association_index(record).values.map(&:call).each do |rel|
          [foreign_key_definition(rel.source, rel.source_keys, rel.target, rel.target_keys)].flatten.each {|sql| execute(sql)}
        end
      end
    end

    class Sqlite3 < Sql
      alias :migrate_record :migrate!

      # NOTE no alter table add foreign key support - got to rebuild the table.
      def migrate! record
        if Swift::Associations::BelongsTo.get_association_index(record).empty?
          migrate_record(record)
        else
          migrate_associations(record)
        end
      end

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

    class Mysql < Sql
      def run_migrations &block
        execute('set foreign_key_checks = 0')
        block.call(self)
        execute('set foreign_key_checks = 1')
      end
    end # Mysql
  end # Adapter
end # Swift
