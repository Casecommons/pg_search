require 'digest'

module PgSearch
  class Configuration
    class ForeignColumn < Column
      def initialize(column, weight, model, association)
        super(column, weight, model)
        @association = association
      end

      def alias
        Configuration.alias(table_alias, @column.name)
      end

      private

      def table_alias
        @association.subselect_alias
      end

      def to_sql_options
        [table_alias, self.alias]
      end

      def full_name_options
        [@association.table_name]
      end
    end
  end
end
