module Swift
  def self.migrate! name = nil
    schema.each do |scheme|
      scheme.migrate! db(name)
    end

    schema.each do |scheme|
      Associations::BelongsTo.get_association_index(scheme).values.map(&:call).each do |rel|
        adapter = db(name)
        args    = [rel.source, rel.source_keys, rel.target, rel.target_keys]
        [adapter.foreign_key_definition(*args)].flatten.each do |sql|
          adapter.execute(sql)
        end
      end
    end
  end

  # TODO customizable on-delete and on-update actions.
  class Adapter
    def foreign_key_definition source, source_keys, target, target_keys
      name = "#{source.store}_#{target.store}_#{source_keys.join('_')}_fkey"
      sql  =<<-SQL
        alter table #{source.store} add constraint #{name} foreign key(#{source_keys.join(', ')})
        references #{target.store}(#{target_keys.join(', ')}) on delete cascade on update cascade
      SQL
    end
  end

  module DB
    class Sqlite3 < Adapter
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
    end
  end
end # Swift
