require 'pg_search/migration/generator'

module PgSearch
  module Migration
    class AssociatedAgainstGenerator < Generator
      def migration_name
        'add_pg_search_associated_against_support_functions'.freeze
      end
    end
  end
end
