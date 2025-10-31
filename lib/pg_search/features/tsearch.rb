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
          Arel::Nodes::InfixOperation.new("@@", Arel::Nodes::Grouping.new(tsdocument), Arel::Nodes::Grouping.new(tsquery))
        )
      end

      def rank
        Arel::Nodes::Grouping.new(tsearch_rank)
      end

      def highlight
        Arel::Nodes::Grouping.new(ts_headline)
      end

      private

      def ts_headline
        Arel::Nodes::NamedFunction.new("ts_headline", [
          dictionary,
          Arel::Nodes::Grouping.new(document),
          Arel::Nodes::Grouping.new(tsquery),
          Arel::Nodes.build_quoted(ts_headline_options)
        ])
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

        # Use Arel::Nodes::Quoted instead of connection.quote + Arel.sql wrapper
        quoted_term = Arel::Nodes::Quoted.new(sanitized_term)
        normalized_sql = normalize(quoted_term.to_sql)
        term_sql = Arel.sql(normalized_sql)

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
          Arel::Nodes::InfixOperation.new("||", memo, term)
        end
      end

      def tsquery
        return Arel::Nodes::Quoted.new("") if query.blank?

        query_terms = query.split.compact
        tsquery_nodes = query_terms.map { |term| tsquery_for_term(term) }

        if tsquery_nodes.size == 1
          tsquery_nodes.first
        else
          operator = options[:any_word] ? " || " : " && "
          tsquery_nodes.inject do |memo, node|
            Arel::Nodes::InfixOperation.new(operator, memo, node)
          end
        end
      end

      def tsdocument
        tsdocument_terms = (columns_to_use || []).map do |search_column|
          column_to_tsvector(search_column)
        end

        if options[:tsvector_column]
          tsvector_columns = Array.wrap(options[:tsvector_column])

          tsvector_terms = tsvector_columns.map do |tsvector_column|
            column_name = connection.quote_column_name(tsvector_column)
            Arel.sql("#{quoted_table_name}.#{column_name}")
          end

          tsdocument_terms.concat(tsvector_terms)
        end

        # Combine all terms using Arel InfixOperation for || concatenation
        if tsdocument_terms.empty?
          # Return empty tsvector when no columns are specified
          Arel::Nodes::NamedFunction.new("to_tsvector", [dictionary, Arel::Nodes::Quoted.new("")])
        else
          tsdocument_terms.inject do |memo, term|
            Arel::Nodes::InfixOperation.new("||", memo, term)
          end
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
        Arel::Nodes::NamedFunction.new("ts_rank", [
          Arel::Nodes::Grouping.new(tsdocument),
          Arel::Nodes::Grouping.new(tsquery),
          normalization
        ])
      end

      def dictionary
        Arel::Nodes.build_quoted(options[:dictionary] || :simple)
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
        )

        if search_column.weight.nil?
          tsvector
        else
          Arel::Nodes::NamedFunction.new("setweight", [
            tsvector,
            Arel::Nodes::Quoted.new(search_column.weight)
          ])
        end
      end
    end
  end
end
