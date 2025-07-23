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
        # Example: WHERE content @@@ 'shoes'
        # For multiple columns, we use OR conditions
        if columns.any?
          conditions = columns.map do |column|
            Arel::Nodes::InfixOperation.new("@@@", 
              arel_wrap(column.to_sql), 
              arel_wrap(formatted_query)
            )
          end
          
          # Combine all conditions with OR
          conditions.reduce do |combined, condition|
            Arel::Nodes::Or.new(combined, condition)
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
        # ParadeDB uses paradedb.score(key_field) for ranking
        # Example: ORDER BY paradedb.score(id) DESC
        arel_wrap(paradedb_score)
      end

      private

      def formatted_query
        return "''" if query.blank?
        
        # Handle different query types
        case options[:query_type]
        when :phrase
          # Phrase search: wrap in double quotes
          phrase_query
        when :prefix
          # Prefix search: add wildcard
          prefix_query
        when :fuzzy
          # Fuzzy search with distance
          fuzzy_query
        else
          # Default: standard query
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

      def paradedb_score
        # Generate the paradedb.score() function call
        # For multisearch, we need to use searchable_id as the key field
        # since it's part of the indexed columns
        key_field = if model.name == "PgSearch::Document"
          "searchable_id"
        else
          options[:key_field] || "id"
        end
        
        "paradedb.score(#{quoted_table_name}.#{connection.quote_column_name(key_field)})"
      end

      def arel_wrap(sql_string)
        Arel::Nodes::Grouping.new(Arel.sql(sql_string))
      end
    end
  end
end