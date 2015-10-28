require 'digest'

module PgSearch
  class Configuration
    class Column
      attr_reader :weight, :name

      def initialize(column, weight, model)
        column = PlainColumn.new(column) unless column.is_a?(PlainColumn)
        @column = column
        @name = @column.name
        @model = model
        @weight = weight
      end

      def to_sql
        "coalesce(#{@column.to_sql(connection, *to_sql_options)}::text, '')"
      end

      def full_name
        @column.full_name(connection, *full_name_options)
      end

      private

      def connection
        @model.connection
      end

      def to_sql_options
        [@model.table_name]
      end

      def full_name_options
        [@model.table_name]
      end
    end
  end
end
