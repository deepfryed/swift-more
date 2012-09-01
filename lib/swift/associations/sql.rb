module Swift
  class Adapter
    module Associations
      class SQL
        FIELD_RE = %r{:(\w+)|(?:\w+\.(\w+))}

        def all_without_join relationship
          sql  = "select * from #{relationship.target.store} where "
          sql += relationship.target_keys.map{|key| "#{key} = ?"}.join(' and ')
          bind = relationship.source_keys.map{|key| relationship.source.send(key)}

          unless relationship.conditions.empty?
            bind += relationship.bind
            sql  += ' and (%s)' % relationship.conditions.first.gsub(FIELD_RE) {relationship.target.send($+).field}
          end

          unless relationship.ordering.empty?
            ordering = relationship.ordering.join(', ')
            sql += ' order by %s' % ordering.gsub(FIELD_RE) {relationship.target.send($+).field}
          end

          [sql, bind]
        end

        def all relationship
          return all_without_join(relationship) if relationship.chains.nil? or relationship.chains.empty?

          sql = 'select distinct t1.* from %s' % join(relationship, 't1', 't2')
          if relationship.chains

            chains = relationship.chains.map.with_index do |r, idx|
              r.source == r.target ? nil : join_with(r, 't%d' % (idx+2), 't%d' % (idx+3))
            end.reject(&:nil?).join(' join ')

            sql += ' join %s' % chains unless chains.empty?
          end

          where, bind = conditions(relationship, 't1', 't2')
          (relationship.chains || []).each_with_index do |r, idx|
            w, b  = conditions(r, 't%d' % (idx+2), 't%d' % (idx+3))
            where += w
            bind  += b
          end

          sql += ' where %s' % where.join(' and ') unless where.empty?
          unless relationship.ordering.empty?
            ordering = relationship.ordering.join(', ')
            sql += ' order by %s' % ordering.gsub(FIELD_RE){ 't1.%s' % relationship.target.send($+).field }
          end

          [ sql, bind ]
        end

        def join rel, alias1, alias2
          if rel.source == rel.target
            '%s %s' % [ rel.source.store, alias1 ]
          else
            condition = rel.target_keys.zip(rel.source_keys)
            condition = condition.map {|t,s| '%s.%s = %s.%s' % [alias1, t, alias2, s] }.join(' and ')
            '%s %s join %s %s on (%s)' % [ rel.target.store, alias1, rel.source_record.store, alias2, condition ]
          end
        end

        def join_with rel, alias1, alias2
          condition = rel.target_keys.zip(rel.source_keys)
          condition = condition.map {|t,s| '%s.%s = %s.%s' % [alias1, t, alias2, s] }.join(' and ')
          '%s %s on (%s)' % [ rel.source_record.store, alias2, condition ]
        end

        def conditions rel, alias1, alias2
          bind   = rel.bind
          clause = rel.conditions.map{|c| c.gsub(FIELD_RE){ '%s.%s' % [ alias1, rel.target.send($+).field ] } }
          if rel.source.kind_of?(Record)
            keys   =  rel.source_record.header.keys
            clause << '(%s)' % keys.map{|k| '%s.%s = ?' % [alias2, k] }.join(' and ')
            bind   += rel.source.tuple.values_at(*keys)
          end
          [ clause.map{|c| '(%s)' % c}, bind ]
        end
      end # SQL
    end # Associations

    def associations
      @associations ||= Associations::SQL.new
    end

    def load_through record, relationship, extra = ''
      sql, bind = associations.all(relationship)
      execute(record, sql + extra, *bind)
    end

    def delete_through record, relationship
      target = relationship.target
      if target.header.keys.length > 1
        self.load_through(record, relationship).map(&:delete)
      else
        key = target.header.keys.first
        sql, bind = associations.all(relationship)
        sql.sub!(/\*/, '%s' % key)
        sql = 'delete from %s where %s in (%s)' % [ target.store, key, sql ]
        execute(sql, *bind)
      end
    end
  end # Adapter
end # Swift
