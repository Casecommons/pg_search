module PgSearch
  class Configuration
    class Association
      attr_reader :columns
      
      def initialize(model, name, columns)
        @model = model
        @name = name
        @columns = columns
      end
      
      def table_name
        @model.reflect_on_association(@name).table_name
      end
      
      def join
        @model.joins(@name)
      end
      
      def subselect_alias
        subselect_name = ["pg_search", table_name, @name, "subselect"].compact.join('_')
        "pg_search_#{MD5.hexdigest(subselect_name)}"
      end
    end
  end
end
