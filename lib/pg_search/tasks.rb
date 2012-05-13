require 'rake'
require 'pg_search'

namespace :pg_search do
  namespace :multisearch do
    desc "Rebuild PgSearch multisearch records for MODEL"
    task :rebuild => :environment do
      raise "must set MODEL=<model name>" unless ENV["MODEL"]
      model_class = ENV["MODEL"].classify.constantize
      PgSearch::Multisearch.rebuild(model_class)
    end
  end
end
