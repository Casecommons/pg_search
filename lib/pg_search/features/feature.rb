require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class Feature
      delegate :connection, :quoted_table_name, :to => :'@model'

      def initialize(query, options, all_columns, model, normalizer)
        @query = query
        @options = options || {}
        @all_columns = all_columns
        @model = model
        @normalizer = normalizer
      end

      private

      attr_reader :query, :options, :all_columns, :model, :normalizer

      def document
        columns.map { |column| column.to_sql }.join(" || ' ' || ")
      end

      def columns
        if options[:only]
          all_columns.select do |column|
            Array.wrap(options[:only]).map(&:to_s).include? column.name
          end
        else
          all_columns
        end
      end

      def normalize(expression)
        normalizer.add_normalization(expression)
      end
    end
  end
end
