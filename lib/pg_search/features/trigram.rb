require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class Trigram
      delegate :connection, :quoted_table_name, :sanitize_sql_array, :primary_key, :to => :'@model'

      # config is temporary as we refactor
      def initialize(query, options, config, model, interpolations, normalizer)
        @query = query
        @options = options
        @config = config
        @model = model
        @interpolations = interpolations
        @normalizer = normalizer
      end

      def columns
        @config.search_columns.map do |column_name, *|
          "coalesce(#{quoted_table_name}.#{connection.quote_column_name(column_name)}, '')"
        end
      end

      def document
        columns.map { |column, *| column }.join(" || ' ' || ")
      end

      def conditions
        "(#{@normalizer.add_normalization(document)}) % #{@normalizer.add_normalization(":query")}"
      end
    end
  end
end
