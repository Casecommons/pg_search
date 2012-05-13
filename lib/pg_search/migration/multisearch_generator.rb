require "rails/generators/base"

module PgSearch
  module Migration
    class MultisearchGenerator < Rails::Generators::Base
      source_root Pathname.new(File.dirname(__FILE__)).join("templates")

      def create_migration
        now = Time.now.utc
        filename = "#{now.strftime('%Y%m%d%H%M%S')}_create_pg_search_documents.rb"
        copy_file "create_pg_search_documents.rb", "db/migrate/#{filename}"
      end
    end
  end
end

