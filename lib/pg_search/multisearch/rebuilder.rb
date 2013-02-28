module PgSearch
  module Multisearch
    class Rebuilder
      def initialize(model, time_source = Time.method(:now), document_model=PgSearch::Document)
        unless model.respond_to?(:pg_search_multisearchable_options)
          raise ModelNotMultisearchable.new(model)
        end

        @model = model
        @document_model = document_model
        @options = model.pg_search_multisearchable_options[document_model.to_s]
        @options ||= {}
        @time_source = time_source
      end

      def rebuild
        if model.respond_to?(:"rebuild_#{document_model.to_s.pluralize.underscore.parameterize('_')}")
          model.send(:"rebuild_#{document_model.to_s.pluralize.underscore.parameterize('_')}")
        elsif options.key?(:if) || options.key?(:unless)
          model.find_each { |record| record.send(:"update_#{document_model.to_s.underscore.parameterize('_')}") }
        else
          model.connection.execute(rebuild_sql)
        end
      end

      private

      attr_reader :model, :document_model, :options

      def connection
        model.connection
      end

      REBUILD_SQL_TEMPLATE = <<-SQL
INSERT INTO :documents_table (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT :model_name AS searchable_type,
         :model_table.id AS searchable_id,
         (
           :content_expressions
         ) AS content,
         :current_time AS created_at,
         :current_time AS updated_at
  FROM :model_table
SQL

      def rebuild_sql
        replacements.inject(REBUILD_SQL_TEMPLATE) do |sql, key|
          sql.gsub ":#{key}", send(key)
        end
      end

      def replacements
        %w[content_expressions model_name model_table documents_table current_time]
      end

      def content_expressions
        columns.map { |column|
          %Q{coalesce(:model_table.#{column}::text, '')}
        }.join(" || ' ' || ")
      end

      def columns
        Array(options[:against])
      end

      def model_name
        connection.quote(model.name)
      end

      def model_table
        model.quoted_table_name
      end

      def documents_table
        document_model.quoted_table_name
      end

      def current_time
        connection.quote(connection.quoted_date(@time_source.call))
      end
    end
  end
end
