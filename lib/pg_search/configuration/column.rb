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
      end

      # Physical source-column attribute, or the supplied trusted SQL literal.
      # Foreign columns refer to the association table, not the search alias.
      def source_attribute
        return @column_name if @column_name.is_a?(Arel::Nodes::SqlLiteral)

        Arel::Attributes::Attribute.new(source_table, @name)
      end

      # Composable search expression cast to text, with NULL mapped to "".
      # Foreign columns use their derived search alias rather than the source.
      def to_arel = coalesce_to_blank_string(cast_to_text(attribute))

      private

      def attribute
        return @column_name if @column_name.is_a?(Arel::Nodes::SqlLiteral)

        @model.arel_table[@name]
      end

      def cast_to_text(node)
        Arel::Nodes::NamedFunction.new("cast", [node.as(Arel.sql("text"))])
      end

      def coalesce_to_blank_string(node)
        Arel::Nodes::NamedFunction.new("coalesce", [node, Arel::Nodes.build_quoted("")])
      end

      def source_table = @model.arel_table
    end
  end
end
