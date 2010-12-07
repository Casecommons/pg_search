require 'pg_search'
#require 'rails'

module PgSearch
  class Railtie < Rails::Railtie
    rake_tasks do
      raise
      load "pg_search/tasks.rb"
    end
  end
end
