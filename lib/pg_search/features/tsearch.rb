# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/deprecation"

module PgSearch
  module Features
    class TSearch < Feature
      def self.valid_options
        super + %i[dictionary prefix negation any_word normalization tsvector_column highlight]
      end

      def conditions
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new("@@", tsdocument, tsquery)
        )
      end

      def rank
        Arel::Nodes::NamedFunction.new("ts_rank", [
          tsdocument,
          tsquery,
          normalization
        ])
      end

      def highlight
        arel_wrap(ts_headline)
      end

      private

      def ts_headline
        Arel::Nodes::NamedFunction.new("ts_headline", [
          dictionary,
          document,
          tsquery,
          Arel::Nodes.build_quoted(ts_headline_options)
        ]).to_sql
      end

      def ts_headline_options
        return "" unless options[:highlight].is_a?(Hash)

        headline_options
          .merge(deprecated_headline_options)
          .filter_map { |key, value| "#{key} = #{value}" unless value.nil? }
          .join(", ")
      end

      def headline_options
        indifferent_options = options.with_indifferent_access

        %w[
          StartSel StopSel MaxFragments MaxWords MinWords ShortWord FragmentDelimiter HighlightAll
        ].reduce({}) do |hash, key|
          hash.tap do
            value = indifferent_options[:highlight][key]

            hash[key] = ts_headline_option_value(value)
          end
        end
      end

      def deprecated_headline_options
        indifferent_options = options.with_indifferent_access

        %w[
          start_sel stop_sel max_fragments max_words min_words short_word fragment_delimiter highlight_all
        ].reduce({}) do |hash, deprecated_key|
          hash.tap do
            value = indifferent_options[:highlight][deprecated_key]

            unless value.nil?
              key = deprecated_key.camelize

              warn(
                "pg_search 3.0 will no longer accept :#{deprecated_key} as an argument to :ts_headline, " \
                  "use :#{key} instead.",
                category: :deprecated,
                uplevel: 1
              )

              hash[key] = ts_headline_option_value(value)
            end
          end
        end
      end

      def ts_headline_option_value(value)
        case value
        when String
          %("#{value.gsub('"', '""')}")
        when true
          "TRUE"
        when false
          "FALSE"
        else
          value
        end
      end

      DISALLOWED_TSQUERY_CHARACTERS = /['?\\:‘’ʻʼ]/ # standard:disable Lint/UselessConstantScoping

      def tsquery_for_term(unsanitized_term)
        if options[:negation] && unsanitized_term.start_with?("!")
          unsanitized_term[0] = ""
          negated = true
        end

        sanitized_term = unsanitized_term.gsub(DISALLOWED_TSQUERY_CHARACTERS, " ")

        term_sql = normalize(Arel::Nodes.build_quoted(sanitized_term))

        tsquery = tsquery_expression(term_sql, negated: negated, prefix: options[:prefix])

        Arel::Nodes::NamedFunction.new("to_tsquery", [dictionary, tsquery])
      end

      # After this, the SQL expression evaluates to a string containing the term surrounded by single-quotes.
      # If :prefix is true, then the term will have :* appended to the end.
      # If :negated is true, then the term will have ! prepended to the front.
      def tsquery_expression(term_sql, negated:, prefix:)
        terms = [
          (Arel::Nodes.build_quoted("!") if negated),
          Arel::Nodes.build_quoted("' "),
          term_sql,
          Arel::Nodes.build_quoted(" '"),
          (Arel::Nodes.build_quoted(":*") if prefix)
        ].compact

        terms.inject do |memo, term|
          Arel::Nodes::InfixOperation.new("||", memo, Arel::Nodes.build_quoted(term))
        end
      end

      def tsquery
        return Arel::Nodes.build_quoted(query) if query.blank?

        operator = tsquery_operator

        Arel::Nodes::Grouping.new(
          query
            .split
            .compact
            .map { tsquery_for_term(_1) }
            .inject { Arel::Nodes::InfixOperation.new(operator, _1, _2) }
        )
      end

      def tsquery_operator = options[:any_word] ? "||" : "&&"

      def tsdocument
        tsdocument_terms = [
          *(columns_to_use || []).map { column_to_tsvector(_1) },
          *Array.wrap(options[:tsvector_column]).map { arel_table[_1] }
        ]

        return Arel::Nodes.build_quoted(nil) if tsdocument_terms.empty?

        Arel::Nodes::Grouping.new(
          tsdocument_terms.inject do |memo, term|
            Arel::Nodes::InfixOperation.new("||", memo, term)
          end
        )
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

      def dictionary
        Arel::Nodes.build_quoted(options[:dictionary] || :simple)
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
          [dictionary, normalize(search_column.to_arel)]
        )

        if search_column.weight.nil?
          tsvector
        else
          weight = Arel::Nodes.build_quoted(search_column.weight)
          Arel::Nodes::NamedFunction.new("setweight", [tsvector, weight])
        end
      end
    end
  end
end
