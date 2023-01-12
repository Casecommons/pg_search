# frozen_string_literal: true

module PgSearch
  class Railtie < Rails::Railtie
    rake_tasks do
      load "pg_search/tasks.rb"
    end

    generators do
      require "pg_search/migration/multisearch_generator"
      require "pg_search/migration/dmetaphone_generator"
      require "pg_search/migration/associated_against_generator"
      require "pg_search/migration/associated_against_tsvector_generator"
    end
  end
end
