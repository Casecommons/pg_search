require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class TSearch < Feature
      def initialize(*args)
        super

        if options[:prefix] && model.connection.send(:postgresql_version) < 80400
          raise PgSearch::NotSupportedForPostgresqlVersion.new(<<-MESSAGE.strip_heredoc)
            Sorry, {:using => {:tsearch => {:prefix => true}}} only works in PostgreSQL 8.4 and above.")
          MESSAGE
        end
      end

      def conditions
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new("@@", arel_wrap(tsdocument), arel_wrap(tsquery))
        )
      end

      def rank
        arel_wrap(tsearch_rank)
      end

      private

      DISALLOWED_TSQUERY_CHARACTERS = /['?\\:]/

      def tsquery_for_term(term)
        sanitized_term = term.gsub(DISALLOWED_TSQUERY_CHARACTERS, " ")

        term_sql = Arel.sql(normalize(connection.quote(sanitized_term)))

        # After this, the SQL expression evaluates to a string containing the term surrounded by single-quotes.
        # If :prefix is true, then the term will also have :* appended to the end.
        terms = ["' ", term_sql, " '", (':*' if options[:prefix])].compact

        tsquery_sql = terms.inject do |memo, term|
          Arel::Nodes::InfixOperation.new("||", memo, term)
        end

        Arel::Nodes::NamedFunction.new(
          "to_tsquery",
          [dictionary, tsquery_sql]
        ).to_sql
      end

      def tsquery
        return "''" if query.blank?
        query_terms = query.split(" ").compact
        tsquery_terms = query_terms.map { |term| tsquery_for_term(term) }
        tsquery_terms.join(options[:any_word] ? ' || ' : ' && ')
      end

      def tsdocument
        if options[:tsvector_column] && columns.empty?
          column_name = connection.quote_column_name(options[:tsvector_column])
          "#{quoted_table_name}.#{column_name}"
        else
          return_str = columns.map do |search_column|
            tsvector = Arel::Nodes::NamedFunction.new(
              "to_tsvector",
              [dictionary, Arel.sql(normalize(search_column.to_sql))]
            ).to_sql

            if search_column.weight.nil?
              tsvector
            else
              "setweight(#{tsvector}, #{connection.quote(search_column.weight)})"
            end
          end.join(" || ")

          if options[:tsvector_column]
            column_name = connection.quote_column_name(options[:tsvector_column])
            return_str += " || #{quoted_table_name}.#{column_name}"
          end

          return_str
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
        options[:normalization] || 0
      end

      def tsearch_rank
        "ts_rank((#{tsdocument}), (#{tsquery}), #{normalization})"
      end

      def dictionary
        options[:dictionary] || :simple
      end

      def arel_wrap(sql_string)
        Arel::Nodes::Grouping.new(Arel.sql(sql_string))
      end
    end
  end
end
