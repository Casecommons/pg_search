require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class TSearch
      delegate :connection, :quoted_table_name, :to => :'@model'

      def initialize(query, options, columns, model, normalizer)
        @query = query
        @options = options || {}
        @model = model
        @columns = columns
        @normalizer = normalizer
      end

      def conditions
        ["(#{tsdocument}) @@ (#{tsquery})", interpolations]
      end

      def rank
        tsearch_rank
      end

      private

      def interpolations
        {:query => @query.to_s, :dictionary => dictionary.to_s}
      end

      def document
        @columns.map { |column| column.to_sql }.join(" || ' ' || ")
      end

      def tsquery
        return "''" if @query.blank?

        @query.split(" ").compact.map do |term|
          sanitized_term = term.gsub(/['?\-\\:]/, " ")

          term_sql = @normalizer.add_normalization(connection.quote(sanitized_term))

          # After this, the SQL expression evaluates to a string containing the term surrounded by single-quotes.
          tsquery_sql = "#{connection.quote("' ")} || #{term_sql} || #{connection.quote(" '")}"

          # Add tsearch prefix operator if we're using a prefix search.
          tsquery_sql = "#{tsquery_sql} || #{connection.quote(':*')}" if @options[:prefix]

          "to_tsquery(:dictionary, #{tsquery_sql})"
        end.join(" && ")
      end

      def tsdocument
        if @options[:tsvector_column]
          @options[:tsvector_column].to_s
        else
          @columns.map do |search_column|
            tsvector = "to_tsvector(:dictionary, #{@normalizer.add_normalization(search_column.to_sql)})"
            search_column.weight.nil? ? tsvector : "setweight(#{tsvector}, #{connection.quote(search_column.weight)})"
          end.join(" || ")
        end
      end

      def tsearch_rank
        ["ts_rank((#{tsdocument}), (#{tsquery}))", interpolations]
      end

      def dictionary
        @options[:dictionary] || :simple
      end
    end
  end
end
