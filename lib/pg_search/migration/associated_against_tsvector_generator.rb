# frozen_string_literal: true

require 'pg_search/migration/generator'

module PgSearch
  module Migration
    class AssociatedAgainstTsvectorGenerator < Generator
      def migration_name
        'add_pg_search_associated_against_tsvector_support_functions'
      end
    end
  end
end
