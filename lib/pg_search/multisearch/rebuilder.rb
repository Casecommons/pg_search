module PgSearch
  module Multisearch
    class Rebuilder
      def initialize(model, time_source = Time.method(:now))
        unless model.respond_to?(:pg_search_multisearchable_options)
          raise ModelNotMultisearchable.new(model)
        end

        @model = model
        @time_source = time_source
      end

      def rebuild
        if model.respond_to?(:rebuild_pg_search_documents)
          model.rebuild_pg_search_documents
        elsif model.pg_search_multisearchable_options.key?(:if) || model.pg_search_multisearchable_options.key?(:unless)
          model.find_each { |record| record.update_pg_search_document }
        else
          model.connection.execute(rebuild_sql)
        end
      end

      private

      attr_reader :model

      def connection
        model.connection
      end

      def primary_key
        model.primary_key
      end

      def rebuild_sql_template
         <<-SQL.strip_heredoc
          INSERT INTO :documents_table (searchable_type, searchable_id, content, created_at, updated_at)
            SELECT :base_model_name AS searchable_type,
                   :model_table.#{primary_key} AS searchable_id,
                   (
                     :content_expressions
                   ) AS content,
                   :current_time AS created_at,
                   :current_time AS updated_at
            FROM :model_table :sti_clause
        SQL
      end

      def rebuild_sql
        replacements.inject(rebuild_sql_template) do |sql, key|
          sql.gsub ":#{key}", send(key)
        end
      end

      def sti_clause
        clause = ""
        if model.column_names.include? 'type'
          clause = "WHERE"
          if model.base_class == model
            clause = "#{clause} type IS NULL OR"
          end
          clause = "#{clause} type = #{model_name}"
        end
        clause
      end

      def replacements
        %w[content_expressions base_model_name model_name model_table documents_table current_time sti_clause]
      end

      def content_expressions
        columns.map { |column|
          %Q{coalesce(:model_table.#{column}::text, '')}
        }.join(" || ' ' || ")
      end

      def columns
        Array(model.pg_search_multisearchable_options[:against])
      end

      def model_name
        connection.quote(model.name)
      end

      def base_model_name
        connection.quote(model.base_class.name)
      end

      def model_table
        model.quoted_table_name
      end

      def documents_table
        PgSearch::Document.quoted_table_name
      end

      def current_time
        connection.quote(connection.quoted_date(@time_source.call))
      end
    end
  end
end
