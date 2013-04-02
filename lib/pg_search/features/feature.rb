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
    end
  end
end
