module PgSearch
  class Configuration
    class PlainColumn
      def initialize(name)
        @name = name.to_s
      end
      attr_reader :name

      def to_sql(connection, table_name, name = @name)
        table_name = connection.quote_table_name table_name if table_name
        name = connection.quote_column_name name
        [table_name, name].compact.join('.')
      end

      def full_name(connection, table_name)
        "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(@name)}"
      end
    end
  end
end
