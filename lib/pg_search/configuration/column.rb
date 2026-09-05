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

      def to_arel = coalesce_to_blank_string(cast_to_text(attribute))

      def to_sql = @connection.visitor.compile(to_arel)

      private

      def attribute
        return @column_name if @column_name.is_a?(Arel::Nodes::SqlLiteral)

        @model.arel_table[@name]
      end

      def cast_to_text(node)
        Arel::Nodes::NamedFunction.new("cast", [node.as(Arel.sql("text"))])
      end

      def coalesce_to_blank_string(node)
        Arel::Nodes::NamedFunction.new("coalesce", [node, Arel.sql("''")])
      end

      def table_name = @model.quoted_table_name

      def column_name = @connection.quote_column_name(@name)
    end
  end
end
