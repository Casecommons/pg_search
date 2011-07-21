module PgSearch
  class Railtie < Rails::Railtie
    rake_tasks do
      load "pg_search/tasks.rb"
    end
  end
end
