require "digest"

module PgSearch
  class Configuration
    class ArelAssociation
      attr_reader :columns

      # ArelAssociation accepts an Arel::Nodes::TableAlias and pulls specified columns into the search query
      # For this to work, the TableAlias needs an `id` column that corresponds to the primary key of the root
      # search model where the associated arel is specified.
      def initialize(model, arel, column_names)
        @model = model
        @arel = arel
        @columns = Array(column_names).map do |column_name, weight|
          ForeignColumn.new(column_name, weight, @model, self)
        end
      end

      def table_name
        @arel.name.to_s
      end

      def join(primary_key)
        "LEFT OUTER JOIN (#{select_manager.to_sql}) #{subselect_alias} ON #{subselect_alias}.id = #{primary_key}"
      end

      def subselect_alias
        Configuration.alias(table_name, "subselect")
      end

      private

      def selects
        columns.map do |column|
          "string_agg(#{column.full_name}::text, ' ') AS #{column.alias}"
        end.join(", ")
      end

      def select_manager
        Arel::SelectManager.new(@arel).project(Arel.sql('id'), Arel.sql(selects)).group(@arel[:id])
      end
    end
  end
end
