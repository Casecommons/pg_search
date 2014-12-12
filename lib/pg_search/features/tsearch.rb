require "pg_search/compatibility"
require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class TSearch < Feature
      def self.valid_options
        super + [:dictionary, :prefix, :negation, :any_word, :normalization, :tsvector_column]
      end

      def initialize(*args)
        super

        if options[:prefix] && model.connection.send(:postgresql_version) < 80400 # rubocop:disable Style/GuardClause
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

      def tsquery_for_term(unsanitized_term) # rubocop:disable Metrics/AbcSize
        if options[:negation] && unsanitized_term.start_with?("!")
          unsanitized_term[0] = ''
          negated = true
        end

        sanitized_term = unsanitized_term.gsub(DISALLOWED_TSQUERY_CHARACTERS, " ")

        term_sql = Arel.sql(normalize(connection.quote(sanitized_term)))

        # After this, the SQL expression evaluates to a string containing the term surrounded by single-quotes.
        # If :prefix is true, then the term will have :* appended to the end.
        # If :negated is true, then the term will have ! prepended to the front.
        terms = [
          (Compatibility.build_quoted('!') if negated),
          Compatibility.build_quoted("' "),
          term_sql,
          Compatibility.build_quoted(" '"),
          (Compatibility.build_quoted(":*") if options[:prefix])
        ].compact

        tsquery_sql = terms.inject do |memo, term|
          Arel::Nodes::InfixOperation.new("||", memo, Compatibility.build_quoted(term))
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
        tsdocument_terms = (columns_to_use || []).map do |search_column|
          column_to_tsvector(search_column)
        end

        if options[:tsvector_column]
          tsvector_columns = Array.wrap(options[:tsvector_column])

          tsdocument_terms << tsvector_columns.map do |tsvector_column|
            column_name = connection.quote_column_name(tsvector_column)

            "#{quoted_table_name}.#{column_name}"
          end
        end

        tsdocument_terms.join(' || ')
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
        Compatibility.build_quoted(options[:dictionary] || :simple)
      end

      def arel_wrap(sql_string)
        Arel::Nodes::Grouping.new(Arel.sql(sql_string))
      end

      def columns_to_use
        if options[:tsvector_column]
          columns.select { |c| c.is_a?(PgSearch::Configuration::ForeignColumn) }
        else
          columns
        end
      end

      def column_to_tsvector(search_column)
        tsvector = Arel::Nodes::NamedFunction.new(
          "to_tsvector",
          [dictionary, Arel.sql(normalize(search_column.to_sql))]
        ).to_sql

        if search_column.weight.nil?
          tsvector
        else
          "setweight(#{tsvector}, #{connection.quote(search_column.weight)})"
        end
      end
    end
  end
end
