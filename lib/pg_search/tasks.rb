require 'rake'
require 'pg_search'

namespace :pg_search do
  namespace :migration do
    desc "Generate migration to add support functions for :dmetaphone"
    task :dmetaphone do
      now = Time.now.utc
      filename = "#{now.strftime('%Y%m%d%H%M%S')}_add_pg_search_dmetaphone_support_functions.rb"

      dmetaphone_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'dmetaphone.sql')).chomp
      uninstall_dmetaphone_sql = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', 'uninstall_dmetaphone.sql')).chomp

      File.open(Rails.root + 'db' + 'migrate' + filename, 'wb') do |migration_file|
        migration_file.puts <<-RUBY
class AddPgSearchDmetaphoneSupportFunctions < ActiveRecord::Migration
  def self.up
    say_with_time("Adding support functions for pg_search :dmetaphone") do
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
    end
  end
end
        RUBY
      end
    end
  end
end
