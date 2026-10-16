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

      # Builds an outer join, on every model primary-key column, to the search
      # subquery, retaining association-scope binds.
      def to_arel = Arel::Nodes::OuterJoin.new(subquery, Arel::Nodes::On.new(on_condition))

      def subselect_alias
        Configuration.alias(table_name, @name, "subselect")
      end

      private

      def subquery = @subquery ||= relation.arel.as(subselect_alias)

      def on_condition = Arel::Nodes::And.new(primary_keys.map { |attribute| subquery[attribute.name].eq(attribute) })

      def primary_keys = Array(@model.primary_key).map { |column| @model.arel_table[column] }

      def relation
        result = @model.unscoped.joins(@name).select(*primary_keys, *selects)
        result = result.group(*primary_keys) unless singular_association?
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
