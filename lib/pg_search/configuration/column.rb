require 'digest'

module PgSearch
  class Configuration
    class Column
      COLUMN_REGEX = /.+/

      attr_reader :weight, :name

      def initialize(column, weight, model)
        @column =
          case column
          when String, Symbol
            case column.to_s
            when /(#{COLUMN_REGEX})\s*->\s*'(.+)'/
              HstoreColumn.new(Regexp.last_match[1], Regexp.last_match[2])
            when COLUMN_REGEX
              PlainColumn.new(column)
            end
          when PlainColumn
            column
          end || raise("Unexpected column - #{column.inspect}")
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
