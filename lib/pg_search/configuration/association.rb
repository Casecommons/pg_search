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
      # Arguments
      #
      # +primary_keys+:: Arel attributes identifying every model primary-key
      #                  column, not a record key value.
      #
      # Returns a composable outer join to the search subquery.
      def to_arel(*primary_keys)
        join_keys = primary_keys.each.with_index(1).to_h { |attribute, index| ["id_#{index}", attribute] }
        subquery = relation(join_keys).arel.as(subselect_alias)
        on_condition = Arel::Nodes::And.new(join_keys.map { |key_alias, attribute| subquery[key_alias].eq(attribute) })
        Arel::Nodes::OuterJoin.new(subquery, Arel::Nodes::On.new(on_condition))
      end

      def subselect_alias
        Configuration.alias(table_name, @name, "subselect")
      end

      private

      def relation(join_keys)
        result = @model.unscoped.joins(@name).select(
          *join_keys.map { |key_alias, attribute| attribute.as(key_alias) },
          *selects
        )
        result = result.group(*join_keys.values) unless singular_association?
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
