# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class ParadeDB < Feature
      def self.valid_options
        super + %i[
          index_name key_field text_fields numeric_fields boolean_fields 
          json_fields range_fields query_type limit offset
          fuzzy_distance prefix_search phrase_search
        ]
      end

      def conditions
        # ParadeDB uses the @@@ operator for BM25 search
        # We need direct column references without coalesce
        if columns.any?
          conditions = columns.map do |column|
            # Use column.full_name to avoid coalesce wrapper
            Arel::Nodes::InfixOperation.new("@@@", 
              arel_wrap(column.full_name), 
              arel_wrap(formatted_query)
            )
          end
          
          # Combine all conditions with OR
          if conditions.size > 1
            conditions.reduce do |combined, condition|
              Arel::Nodes::Or.new(combined, condition)
            end
          else
            conditions.first
          end
        else
          # Fallback to content column for multisearch
          Arel::Nodes::InfixOperation.new("@@@", 
            arel_wrap("#{quoted_table_name}.content"), 
            arel_wrap(formatted_query)
          )
        end
      end

      def rank
        # Return an Arel node for ParadeDB scoring
        # Use the id column as the key field for scoring
        # Wrap in NamedFunction to ensure it has to_sql method
        Arel::Nodes::NamedFunction.new(
          "paradedb.score",
          [Arel.sql("#{quoted_table_name}.#{connection.quote_column_name('id')}")]
        )
      end

      private

      def formatted_query
        return "''" if query.blank?
        
        # Handle different query types
        case options[:query_type]
        when :phrase
          phrase_query
        when :prefix
          prefix_query
        when :fuzzy
          fuzzy_query
        else
          standard_query
        end
      end

      def standard_query
        # Escape single quotes and wrap in quotes
        escaped = query.gsub("'", "''")
        "'#{escaped}'"
      end

      def phrase_query
        # For phrase search, wrap the query in double quotes within the SQL string
        escaped = query.gsub("'", "''").gsub('"', '""')
        "'\"#{escaped}\"'"
      end

      def prefix_query
        # For prefix search, add wildcard at the end
        escaped = query.gsub("'", "''")
        "'#{escaped}*'"
      end

      def fuzzy_query
        # For fuzzy search, use the ~N syntax where N is the distance
        distance = options[:fuzzy_distance] || 1
        escaped = query.gsub("'", "''")
        "'#{escaped}~#{distance}'"
      end

      def arel_wrap(sql_string)
        Arel::Nodes::Grouping.new(Arel.sql(sql_string))
      end
    end
  end
end