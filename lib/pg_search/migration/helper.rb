module PgSearch
  module Migration
    module Helper
      def add_pg_search_index(table, field, options = {})
        dictionaries = parse_pg_search_index_dictionaries(options)
        index_type = options[:index_type] == :gist ? :gist : :gin

        dictionaries.each do |dictionary|
          index_name = calculate_pg_search_index_name(table, dictionary, field)
          execute "create index #{index_name} on #{quote_table_name table} using #{index_type}(to_tsvector('#{dictionary}', #{field}))"
        end
      end

      def remove_pg_search_index(table, field, options)
        dictionaries = parse_pg_search_index_dictionaries(options)
        dictionaries.each do |dictionary|
          index_name = calculate_pg_search_index_name(table, dictionary, field)
          execute "drop index #{index_name}"
        end
      end

      private

      def parse_pg_search_index_dictionaries(options)
        dicts = options[:dictionary] || options[:dictionaries] || 'simple'
        dicts.is_a?(Array) ? dicts : [dicts]
      end

      def calculate_pg_search_index_name(table, dictionary, field)
        "pg_search_#{table}_#{dictionary}_#{field}"
      end
    end
  end
end

# Optional
ActiveRecord::Migration.class_eval do
  include PgSearch::Migration::Helper
end
