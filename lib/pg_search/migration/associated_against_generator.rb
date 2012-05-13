require "rails/generators/base"

module PgSearch
  module Migration
    class AssociatedAgainstGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def create_migration
        now = Time.now.utc
        filename = "#{now.strftime('%Y%m%d%H%M%S')}_add_pg_search_associated_against_support_functions.rb"
        template "add_pg_search_associated_against_support_functions.rb.erb", "db/migrate/#{filename}"
      end

      private

      def read_sql_file(filename)
        sql_directory = File.expand_path("../../../../sql", __FILE__)
        source_path = File.join(sql_directory, "#{filename}.sql")
        File.read(source_path)
      end
    end
  end
end
