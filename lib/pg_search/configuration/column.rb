# frozen_string_literal: true

require "digest"

module PgSearch
  class Configuration
    class Column
      attr_reader :weight, :name

      def initialize(column_name, weight, model)
        @name = column_name.to_s
        @column_name = column_name
        @weight = weight
        @model = model
        @connection = model.connection
      end

      def full_name
        return @column_name if @column_name.is_a?(Arel::Nodes::SqlLiteral)

        "#{table_name}.#{column_name}"
      end

      def to_sql
        to_arel.to_sql
      end

      def to_arel
        # Return Arel node that casts the column to text and coalesces with empty string
        expr = Arel.sql(expression)
        cast_expr = Arel::Nodes::NamedFunction.new("CAST", [
          Arel::Nodes::InfixOperation.new("AS", expr, Arel.sql("text"))
        ])
        Arel::Nodes::NamedFunction.new("coalesce", [
          cast_expr,
          Arel::Nodes::Quoted.new("")
        ])
      end

      private

      def table_name
        @model.quoted_table_name
      end

      def column_name
        @connection.quote_column_name(@name)
      end

      def expression
        full_name
      end
    end
  end
end
