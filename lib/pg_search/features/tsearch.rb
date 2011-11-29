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

        if @options[:prefix] && @model.connection.send(:postgresql_version) < 80400
          raise PgSearch::NotSupportedForPostgresqlVersion.new(<<-MESSAGE.gsub /^\s*/, '')
            Sorry, {:using => {:tsearch => {:prefix => true}}} only works in PostgreSQL 8.4 and above.")
          MESSAGE
        end
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

      DISALLOWED_TSQUERY_CHARACTERS = /['?\\:]/

      def tsquery_for_term(term)
        sanitized_term = term.gsub(DISALLOWED_TSQUERY_CHARACTERS, " ")

        term_sql = @normalizer.add_normalization(connection.quote(sanitized_term))

        # After this, the SQL expression evaluates to a string containing the term surrounded by single-quotes.
        # If :prefix is true, then the term will also have :* appended to the end.
        tsquery_sql = [
            connection.quote("' "),
            term_sql,
            connection.quote(" '"),
            (connection.quote(':*') if @options[:prefix])
        ].compact.join(" || ")

        "to_tsquery(:dictionary, #{tsquery_sql})"
      end

      def tsquery
        return "''" if @query.blank?
        @query.split(" ").compact.map { |term| tsquery_for_term(term) }.join(@options[:any_word] ? ' || ' : ' && ')
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

      # From http://www.postgresql.org/docs/8.3/static/textsearch-controls.html
      #   0 (the default) ignores the document length
      #   1 divides the rank by 1 + the logarithm of the document length
      #   2 divides the rank by the document length
      #   4 divides the rank by the mean harmonic distance between extents (this is implemented only by ts_rank_cd)
      #   8 divides the rank by the number of unique words in document
      #   16 divides the rank by 1 + the logarithm of the number of unique words in document
      #   32 divides the rank by itself + 1
      # The integer option controls several behaviors, so it is a bit mask: you can specify one or more behaviors
      def normalization
        @options[:normalization] || 0
      end

      def tsearch_rank
        ["ts_rank((#{tsdocument}), (#{tsquery}), #{normalization})", interpolations]
      end

      def dictionary
        @options[:dictionary] || :simple
      end
    end
  end
end
