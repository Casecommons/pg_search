require 'digest'

module PgSearch
  class Configuration
    class Column
      attr_reader :weight, :name

      def initialize(column_name, weight, model)
        @name = column_name.to_s

        if column_name.is_a?(Symbol) || column_name.is_a?(String)
          column_name = model.arel_table[column_name]
        end

        @column_name = column_name
        @weight = weight
        @model = model
        @connection = model.connection
      end

      def full_name
        @connection.visitor.accept(Arel::Nodes.build_quoted(@column_name), []).join
      end

      def to_sql
        @connection.visitor.accept(Arel::Nodes::NamedFunction.new('coalesce',
          [ Arel.sql("#{Arel.sql(self.full_name)}::text"), Arel::Nodes.build_quoted('') ]), []).join
      end
    end
  end
end
