module PgSearch
  module Features
    class Feature
      delegate :connection, :quoted_table_name, :to => :'@model'

      begin
        include ActiveRecord::Sanitization::ClassMethods
      rescue NameError
        delegate :sanitize_sql_array, :to => :'@model'
      end

      def initialize(query, options, columns, model, normalizer)
        @query = query
        @options = options || {}
        @columns = columns
        @model = model
        @normalizer = normalizer
      end

      private

      attr_reader :query, :options, :columns, :model, :normalizer

      def document
        columns.map { |column| column.to_sql }.join(" || ' ' || ")
      end

      def normalize(expression)
        normalizer.add_normalization(expression)
      end

      def arel_wrap(sql_string, interpolations = {})
        Arel::Nodes::Grouping.new(
          Arel.sql(
            sanitize_sql_array([sql_string, interpolations])
          )
        )
      end
    end
  end
end
