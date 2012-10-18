require 'rake'
require 'pg_search'

namespace :pg_search do
  namespace :multisearch do
    desc "Rebuild PgSearch multisearch records for a given model"
    task :rebuild, [:model,:schema] => :environment do |task, args|
      raise ArgumentError, <<-MESSAGE unless args.model
You must pass a model as an argument.
Example: rake pg_search:multisearch:rebuild[BlogPost]
      MESSAGE
      model_class = args.model.classify.constantize
      ActiveRecord::Base.connection.schema_search_path = args.schema unless !args.schema
      PgSearch::Multisearch.rebuild(model_class)
    end
  end
end
