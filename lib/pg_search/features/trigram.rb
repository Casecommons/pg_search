require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class Trigram
      delegate :connection, :quoted_table_name, :to => :'@model'

      # config is temporary as we refactor
      def initialize(query, options, config, model, normalizer)
        @query = query
        @options = options
        @config = config
        @model = model
        @normalizer = normalizer
      end

      def conditions
        ["(#{@normalizer.add_normalization(document)}) % #{@normalizer.add_normalization(":query")}", {:query => @query}]
      end

      def rank
        ["similarity((#{@normalizer.add_normalization(document)}), #{@normalizer.add_normalization(":query")})", {:query => @query}]
      end

      private

      def columns
        @config.search_columns
      end

      def document
        columns.map { |column, *| column }.join(" || ' ' || ")
      end
    end
  end
end
