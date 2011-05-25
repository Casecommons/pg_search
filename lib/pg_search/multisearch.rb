module PgSearch
  module Multisearch
    REBUILD_SQL_TEMPLATE = <<-SQL
INSERT INTO :documents_table (searchable_type, searchable_id, content)
  SELECT :model_name AS searchable_type,
         :model_table.id AS searchable_id,
         (
           :content_expressions
         ) AS content
  FROM :model_table
SQL

    class << self
      def rebuild(model)
        model.transaction do
          PgSearch::Document.where(:searchable_type => model.name).delete_all
          model.connection.execute(rebuild_sql(model))
        end
      end

      def rebuild_sql(model)
        connection = model.connection

        columns = Array.wrap(
          model.pg_search_multisearchable_options[:against]
        )

        content_expressions = columns.map do |column|
          %Q{coalesce(:model_table.#{column}, '')}
        end.join(" || ' ' || ")

        REBUILD_SQL_TEMPLATE.gsub(
          ":content_expressions", content_expressions
        ).gsub(
          ":model_name", connection.quote(model.name)
        ).gsub(
          ":model_table", model.quoted_table_name
        ).gsub(
          ":documents_table", PgSearch::Document.quoted_table_name
        )
      end
    end
  end
end


