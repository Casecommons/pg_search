# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class ParadeDB < Feature
      class ExtensionNotInstalled < StandardError; end
      class IndexNotFound < StandardError; end
      
      def self.valid_options
        super + %i[
          index_name key_field text_fields numeric_fields boolean_fields 
          json_fields range_fields query_type limit offset
          fuzzy_distance prefix_search phrase_search
          auto_create_index check_extension
        ]
      end

      def initialize(query, options, all_columns, model, normalizer)
        super
        # Default to checking extension and auto-creating index
        @check_extension = options.fetch(:check_extension, true)
        @auto_create_index = options.fetch(:auto_create_index, true)
        
        ensure_paradedb_ready! if @check_extension
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
          [Arel.sql("#{quoted_table_name}.#{connection.quote_column_name(key_field)}")]
        )
      end

      private

      def key_field
        # For pg_search_documents table, always use 'id' as the key field
        # For other tables, allow customization
        if model.table_name == 'pg_search_documents'
          'id'
        else
          options[:key_field] || model.primary_key || 'id'
        end
      end

      def ensure_paradedb_ready!
        check_extension!
        ensure_bm25_index! if @auto_create_index
      end

      def check_extension!
        result = connection.execute(<<-SQL)
          SELECT 1 FROM pg_extension WHERE extname = 'pg_search' LIMIT 1
        SQL
        
        unless result.any?
          raise ExtensionNotInstalled, <<~ERROR
            ParadeDB pg_search extension is not installed.
            
            To fix this, run the following SQL command:
              CREATE EXTENSION IF NOT EXISTS pg_search;
            
            Or generate and run the ParadeDB migration:
              rails generate pg_search:migration:paradedb
              rails db:migrate
          ERROR
        end
      rescue ActiveRecord::StatementInvalid => e
        # Handle case where pg_extension table doesn't exist (unlikely but possible)
        raise ExtensionNotInstalled, "Could not verify pg_search extension: #{e.message}"
      end

      def ensure_bm25_index!
        return unless model.table_name == 'pg_search_documents'
        
        # Check if BM25 index exists
        index_name = options[:index_name] || 'pg_search_documents_bm25_idx'
        
        result = connection.execute(<<-SQL)
          SELECT 1 
          FROM pg_indexes 
          WHERE tablename = 'pg_search_documents' 
          AND indexname = '#{index_name}'
          LIMIT 1
        SQL
        
        # Create index if it doesn't exist
        unless result.any?
          create_bm25_index!(index_name)
        end
      end

      def create_bm25_index!(index_name)
        # Determine which columns to include in the index
        index_columns = if model.table_name == 'pg_search_documents'
          # For multisearch, index the key columns
          'id, content, searchable_id, searchable_type'
        else
          # For single model search, index the searchable columns
          columns.map { |col| connection.quote_column_name(col.name) }.join(', ')
        end
        
        begin
          connection.execute(<<-SQL)
            CREATE INDEX CONCURRENTLY IF NOT EXISTS #{index_name}
            ON #{quoted_table_name}
            USING bm25 (#{index_columns})
            WITH (key_field='#{key_field}')
          SQL
          
          Rails.logger.info "[pg_search] Created BM25 index: #{index_name}" if defined?(Rails)
        rescue ActiveRecord::StatementInvalid => e
          if e.message.include?("already exists")
            # Index already exists, that's fine
          elsif e.message.include?("CONCURRENTLY")
            # Retry without CONCURRENTLY (might be in a transaction)
            connection.execute(<<-SQL)
              CREATE INDEX IF NOT EXISTS #{index_name}
              ON #{quoted_table_name}
              USING bm25 (#{index_columns})
              WITH (key_field='#{key_field}')
            SQL
          else
            raise IndexNotFound, <<~ERROR
              Failed to create BM25 index: #{e.message}
              
              Please create the index manually:
                CREATE INDEX #{index_name}
                ON #{quoted_table_name}
                USING bm25 (#{index_columns})
                WITH (key_field='#{key_field}')
            ERROR
          end
        end
      end

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