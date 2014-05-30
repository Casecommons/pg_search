require 'pg_search/migration/generator'

module PgSearch
  module Migration
    class DmetaphoneGenerator < Generator
      def migration_name
        'add_pg_search_dmetaphone_support_functions'.freeze
      end
    end
  end
end
