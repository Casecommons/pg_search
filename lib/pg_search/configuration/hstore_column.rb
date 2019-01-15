module PgSearch
  class Configuration
    class HstoreColumn < PlainColumn
      def initialize(name, key)
        super(name)
        @key = key.to_s
      end

      def to_sql(connection, *)
        super + "->#{connection.quote(@key)}"
      end
    end
  end
end
