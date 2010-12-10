module PgSearch
  class Configuration
    class Column
      attr_reader :weight

      def initialize(column_name, weight, model)
        @column_name = column_name
        @weight = weight
        @model = model
      end

      def full_name
        table, column = @column_name.to_s.split(".")
        table, column = @model.table_name, table if column.nil?
        "#{@model.connection.quote_table_name(table)}.#{@model.connection.quote_column_name(column)}"
      end

      def to_sql
        name = if foreign?
                 self.alias
               else
                 full_name
               end
        "coalesce(#{name}, '')"
      end

      def foreign?
        @column_name.to_s.include?('.')
      end

      def alias
        'pg_search_text'
      end
    end
  end
end
