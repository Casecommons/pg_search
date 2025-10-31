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

      def join(primary_key)
        # Build join using Arel join node instead of string interpolation
        builder = Arel::SelectManager.new

        # Build join components using Arel constructs
        alias_table = Arel::Table.new(subselect_alias)
        alias_id_column = alias_table[:id]
        primary_key_expr = Arel.sql(primary_key)
        join_condition = alias_id_column.eq(primary_key_expr)

        # Use SelectManager's native join methods to build the subquery join
        subquery_relation = relation(primary_key)
        builder.join(subquery_relation.arel.as(subselect_alias), Arel::Nodes::OuterJoin).on(join_condition)

        # Return the properly constructed join node
        builder.join_sources.first
      end

      def subselect_alias
        Configuration.alias(table_name, @name, "subselect")
      end

      private

      def cast_column_to_text(column_expression)
        # Build Arel node with CAST for text conversion (without coalesce)
        Arel::Nodes::NamedFunction.new("CAST", [
          Arel::Nodes::InfixOperation.new("AS", column_expression, Arel.sql("text"))
        ])
      end

      def selects
        if singular_association?
          selects_for_singular_association
        else
          selects_for_multiple_association
        end
      end

      def selects_for_singular_association
        columns.map do |column|
          # Use helper method to build proper Arel node with CAST
          column_expr = Arel.sql(column.full_name)
          cast_column_to_text(column_expr).as(column.alias)
        end
      end

      def selects_for_multiple_association
        columns.map do |column|
          # Use helper method to build proper Arel node with CAST
          column_expr = Arel.sql(column.full_name)
          cast_expr = cast_column_to_text(column_expr)
          string_agg_func = Arel::Nodes::NamedFunction.new("string_agg", [cast_expr, Arel::Nodes::Quoted.new(" ")])
          string_agg_func.as(column.alias)
        end
      end

      def relation(primary_key)
        # Use Arel to build the SELECT clause instead of string interpolation
        primary_key_expr = Arel.sql(primary_key).as("id")
        select_expressions = [primary_key_expr] + selects

        result = @model.unscoped.joins(@name).select(select_expressions)
        result = result.group(primary_key) unless singular_association?
        result
      end

      def singular_association?
        %i[has_one belongs_to].include?(@model.reflect_on_association(@name).macro)
      end
    end
  end
end
