# frozen_string_literal: true

require "digest"

module PgSearch
  class Configuration
    class Association
      attr_reader :columns

      def initialize(model, name, column_names)
        @model = model
        @name = name
        @columns = Array(column_names).map do |column_name, weight|
          ForeignColumn.new(column_name, weight, @model, self)
        end
      end

      def table_name
        @model.reflect_on_association(@name).table_name
      end

      def arel_table = @model.reflect_on_association(@name).klass.arel_table

      # Builds an outer join retaining association-scope binds.
      #
      # @param primary_key an Arel expression or trusted SQL String identifying
      #   the model's primary-key column, not a record's key value
      # @return [Arel::Nodes::OuterJoin] a composable join to the search subquery
      def to_arel(primary_key)
        primary_key = Arel.sql(primary_key) if primary_key.is_a?(String)
        subquery = relation(primary_key).arel.as(subselect_alias)
        on_condition = Arel::Nodes::On.new(subquery[:id].eq(primary_key))
        Arel::Nodes::OuterJoin.new(subquery, on_condition)
      end

      def subselect_alias
        Configuration.alias(table_name, @name, "subselect")
      end

      private

      def relation(primary_key)
        result = @model.unscoped.joins(@name).select(
          primary_key.as("id"),
          *selects
        )
        result = result.group(primary_key) unless singular_association?
        result
      end

      def selects
        columns.map do |column|
          cast_node = Arel::Nodes::NamedFunction.new(
            "cast",
            [column.source_attribute.as(Arel.sql("text"))]
          )
          projection = if singular_association?
            cast_node
          else
            Arel::Nodes::NamedFunction.new(
              "string_agg",
              [cast_node, Arel::Nodes.build_quoted(" ")]
            )
          end
          projection.as(column.alias)
        end
      end

      def singular_association?
        %i[has_one belongs_to].include?(@model.reflect_on_association(@name).macro)
      end
    end
  end
end
