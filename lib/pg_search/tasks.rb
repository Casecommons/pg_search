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

  namespace :migration do
    desc "Generate migration to add table for multisearch"
    task :multisearch do
      now = Time.now.utc
      filename = "#{now.strftime('%Y%m%d%H%M%S')}_create_pg_search_documents.rb"

      File.open(Rails.root + 'db' + 'migrate' + filename, 'wb') do |migration_file|
        migration_file.puts <<-RUBY
class CreatePgSearchDocuments < ActiveRecord::Migration
  def self.up
    say_with_time("Creating table for pg_search multisearch") do
      create_table :pg_search_documents do |t|
        t.text :content
        t.belongs_to :searchable, :polymorphic => true
        t.timestamps
      end
    end
  end

  def self.down
    say_with_time("Dropping table for pg_search multisearch") do
      drop_table :pg_search_documents
    end
  end
end
        RUBY
      end
    end

    desc "Generate migration to add support functions for :dmetaphone"
    task :dmetaphone do
      now = Time.now.utc
      filename = "#{now.strftime('%Y%m%d%H%M%S')}_add_pg_search_dmetaphone_support_functions.rb"

      dmetaphone_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'dmetaphone.sql')).chomp
      uninstall_dmetaphone_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'uninstall_dmetaphone.sql')).chomp

      unnest_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'unnest.sql')).chomp
      uninstall_unnest_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'uninstall_unnest.sql')).chomp

      File.open(Rails.root + 'db' + 'migrate' + filename, 'wb') do |migration_file|
        migration_file.puts <<-RUBY
class AddPgSearchDmetaphoneSupportFunctions < ActiveRecord::Migration
  def self.up
    say_with_time("Adding support functions for pg_search :dmetaphone") do
      if ActiveRecord::Base.connection.send(:postgresql_version) < 80400
        ActiveRecord::Base.connection.execute(<<-SQL)
          #{unnest_sql}
        SQL
      end
      ActiveRecord::Base.connection.execute(<<-SQL)
        #{dmetaphone_sql}
      SQL
    end
  end

  def self.down
    say_with_time("Dropping support functions for pg_search :dmetaphone") do
      ActiveRecord::Base.connection.execute(<<-SQL)
        #{uninstall_dmetaphone_sql}
      SQL
      if ActiveRecord::Base.connection.send(:postgresql_version) < 80400
        ActiveRecord::Base.connection.execute(<<-SQL)
          #{uninstall_unnest_sql}
        end
      end
    end
  end
end
        RUBY
      end
    end

    desc "Generate migration to add support functions for :associated_against in PostgreSQL 8.3 and earlier"
    task :associated_against do
      now = Time.now.utc
      filename = "#{now.strftime('%Y%m%d%H%M%S')}_add_pg_search_associated_against_support_functions.rb"

      array_agg_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'array_agg.sql')).chomp
      uninstall_array_agg_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'uninstall_array_agg.sql')).chomp

      File.open(Rails.root + 'db' + 'migrate' + filename, 'wb') do |migration_file|
        migration_file.puts <<-RUBY
class AddPgSearchAssociatedAgainstSupportFunctions < ActiveRecord::Migration
  def self.up
    say_with_time("Adding support functions for pg_search :associated_against") do
      if ActiveRecord::Base.connection.send(:postgresql_version) < 80400
        ActiveRecord::Base.connection.execute(<<-SQL)
          #{array_agg_sql}
        SQL
      end
    end
  end

  def self.down
    say_with_time("Dropping support functions for pg_search :associated_against") do
      if ActiveRecord::Base.connection.send(:postgresql_version) < 80400
        ActiveRecord::Base.connection.execute(<<-SQL)
          #{uninstall_array_agg_sql}
        SQL
      end
    end
  end
end
        RUBY
      end
    end
  end
end
