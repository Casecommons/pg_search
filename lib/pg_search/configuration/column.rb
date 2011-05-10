require 'md5'

module PgSearch
  class Configuration
    class Column
      attr_reader :weight
      attr_accessor :association

      def initialize(column_name, weight, model)
        @column_name = column_name.to_s
        @weight = weight
        @model = model
      end

      def table
        foreign? ? @association.table_name : @model.table_name
      end

      def full_name
        "#{@model.connection.quote_table_name(table)}.#{@model.connection.quote_column_name(@column_name)}"
      end

      def to_sql
        name = if foreign?
                 "#{@association.subselect_alias}.#{self.alias}"
               else
                 full_name
               end
        "coalesce(#{name}, '')"
      end

      def foreign?
        @association.present?
      end

      def alias
        name = [association.subselect_alias, @column_name].compact.join('_')
        "pg_search_#{MD5.hexdigest(name)}"
      end
    end
  end
end
