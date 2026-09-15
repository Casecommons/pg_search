# frozen_string_literal: true

require "pg_search/migration/generator"

module PgSearch
  module Migration
    class ParadedbGenerator < Generator
      def migration_name
        "add_pg_search_paradedb_support"
      end
    end
  end
end