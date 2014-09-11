require 'digest'

module PgSearch
  class Configuration
    class Column
      attr_reader :weight, :name

      def initialize(column_name, weight, model)
        @column_name, @hstore_key = column_name.to_s.split(/->/)
        @name = @column_name
        @weight = weight
        @model = model
        @connection = model.connection
      end

      def full_name
        "#{table_name}.#{column_name}"
      end

      def to_sql
        "coalesce(#{expression}#{hstore_key}::text, '')"
      end

      private

      def table_name
        @model.quoted_table_name
      end

      def column_name
        @connection.quote_column_name(@column_name)
      end

      def expression
        full_name
      end
      
      def hstore_key
        @hstore_key.present? ? "->'#{@hstore_key.delete("'\"")}'" : ""
      end
    end
  end
end
