require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class TSearch
      delegate :connection, :quoted_table_name, :sanitize_sql_array, :primary_key, :to => :'@model'

      # config is temporary as we refactor
      def initialize(query, options, config, model, normalizer)
        @query = query
        @options = options || {}
        @config = config
        @model = model
        @normalizer = normalizer
      end

      def conditions
        sanitize_sql_array ["(#{tsdocument}) @@ (#{tsquery})", interpolations]
      end

      def rank
        tsearch_rank
      end

      private

      def interpolations
        {:query => @query, :dictionary => @options[:dictionary].to_s}
      end

      def columns_with_weights
        @config.search_columns.map do |column_name, weight|
          ["coalesce(#{quoted_table_name}.#{connection.quote_column_name(column_name)}, '')",
           weight]
        end
      end

      def document
        columns_with_weights.map { |column, *| column }.join(" || ' ' || ")
      end

      def tsquery
        @query.split(" ").compact.map do |term|
          term = term.gsub(/['?]/, " ")
          term = "'#{term}'"
          term = "#{term}:*" if @options[:prefix]
          "to_tsquery(#{":dictionary," if @options[:dictionary]} #{@normalizer.add_normalization(connection.quote(term))})"
        end.join(" && ")
      end

      def tsdocument
        columns_with_weights.map do |column, weight|
          tsvector = "to_tsvector(#{":dictionary," if @options[:dictionary]} #{@normalizer.add_normalization(column)})"
          weight.nil? ? tsvector : "setweight(#{tsvector}, #{connection.quote(weight)})"
        end.join(" || ")
      end

      def tsearch_rank
        sanitize_sql_array(["ts_rank((#{tsdocument}), (#{tsquery}))", interpolations])
      end
    end
  end
end
