module Swift
  class Adapter
    def aggregates aggregate, options={}
      aggr = []
      grouping, having = options.values_at(:grouping, :having)
      aggregate.chain.each do |verb, expr, result_alias|
        result_alias ||= aggregate.alias(verb, expr)
        expr = exchange_names(aggregate.relation.target, expr.to_s)
        case verb
          when :max   then aggr << "max(#{expr}) as #{result_alias}"
          when :min   then aggr << "min(#{expr}) as #{result_alias}"
          when :sum   then aggr << "sum(#{expr}) as #{result_alias}"
          when :avg   then aggr << "avg(#{expr}) as #{result_alias}"
          when :count then aggr <<     "count(*) as #{result_alias}"
        end
      end

      sql, bind = associations.all(aggregate.relation)
      if grouping
        group = grouping.join(', ')
        sql   = "select #{aggr.join(', ')}, #{group} from (#{sql}) aggr group by #{group}"
      else
        sql = "select #{aggr.join(', ')} from (#{sql}) aggr"
      end

      sql += " having #{having}" if having
      execute(sql, *bind)
    end
  end # Adapter
end # Swift
