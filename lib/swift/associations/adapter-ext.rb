module Swift
  class Adapter
    module Associations
      class SQL
        def all relationship
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
            sql += ' order by %s' % ordering.gsub(/:(\w+)/){ 't1.%s' % relationship.target.send($1).field }
          end

          [ sql, bind ]
        end

        def join rel, alias1, alias2
          if rel.source == rel.target
            '%s %s' % [ rel.source.store, alias1 ]
          else
            condition = rel.target_keys.zip(rel.source_keys)
            condition = condition.map {|t,s| '%s.%s = %s.%s' % [alias1, t, alias2, s] }.join(' and ')
            '%s %s join %s %s on (%s)' % [ rel.target.store, alias1, rel.source_scheme.store, alias2, condition ]
          end
        end

        def join_with rel, alias1, alias2
          condition = rel.target_keys.zip(rel.source_keys)
          condition = condition.map {|t,s| '%s.%s = %s.%s' % [alias1, t, alias2, s] }.join(' and ')
          '%s %s on (%s)' % [ rel.source_scheme.store, alias2, condition ]
        end

        def conditions rel, alias1, alias2
          bind   = rel.bind
          clause = rel.conditions.map{|c| c.gsub(/:(\w+)/){ '%s.%s' % [ alias1, rel.target.send($1).field ] } }
          if rel.source.kind_of?(Scheme)
            keys   =  rel.source_scheme.header.keys
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

    def load_through scheme, relationship, extra = ''
      sql, bind = associations.all(relationship)
      prepare(scheme, sql + extra).execute(*bind)
    end

    def destroy_through scheme, relationship
      target = relationship.target
      if target.header.keys.length > 1
        self.load_through(scheme, relationship).map(&:destroy)
      else
        key = target.header.keys.first
        sql, bind = associations.all(relationship)
        sql.sub!(/t1\.\*/, 't1.%s' % key)
        sql = 'delete from %s where %s in (%s)' % [ target.store, key, sql ]
        execute(sql, *bind)
      end
    end
  end # Adapter
end # Swift
