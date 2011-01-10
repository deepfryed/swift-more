require_relative 'aggregate/adapter-ext'
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

      def alias verb, expr
        "#{verb}_#{expr}".downcase.gsub(/[^a-zA-Z]/, '_').gsub(/_+/, '_').sub(/^_|_$/, '')
      end

      def execute options={}
        Swift.db.aggregates(self, options)
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
