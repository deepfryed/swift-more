module Swift
  module Associations
    class Aggregate
      attr_accessor :chain, :relation

      def initialize relation, op
        @relation = relation
        @chain    = [ op ]
      end

      def push op
        @chain << op
      end

      def execute options={}
        aggr = []
        grouping, having = options.values_at(:grouping, :having)
        chain.each do |verb, expr, result_alias|
          result_alias ||= [verb, expr].map do |value|
            value.to_s.downcase.gsub(/[^a-zA-Z]/, '_').gsub(/_+/, '_')
          end.join('_').gsub(/_+/, '_')
          case verb
            when :max   then aggr << "max(#{expr}) as #{result_alias}"
            when :min   then aggr << "min(#{expr}) as #{result_alias}"
            when :sum   then aggr << "sum(#{expr}) as #{result_alias}"
            when :count then aggr <<     "count(*) as #{result_alias}"
          end
        end

        sql, bind = Swift.db.associations.all(relation)
        if grouping
          group = grouping.join(', ')
          sql   = "select #{aggr.join(', ')}, #{group} from (#{sql}) aggr group by #{group}"
        else
          sql = "select #{aggr.join(', ')} from (#{sql}) aggr"
        end

        sql += " having #{having}" if having
        grouping ? Swift.db.execute(sql, *bind) : Swift.db.execute(sql, *bind).first
      end

      module Helpers
        def do_aggregate op
          if self.kind_of?(Aggregate)
            push op
            self
          else
            Aggregate.new(self, op)
          end
        end

        def min expr, result_alias = nil
          do_aggregate [:min, expr, result_alias]
        end

        def max expr, result_alias = nil
          do_aggregate [:max, expr, result_alias]
        end

        def sum expr, result_alias = nil
          do_aggregate [:sum, expr, result_alias]
        end

        def count result_alias = nil
          do_aggregate [:count, '', result_alias]
        end
      end

      include Helpers
    end

    class Base
      include Aggregate::Helpers
    end
  end
end
