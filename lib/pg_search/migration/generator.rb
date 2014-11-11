require 'rails/generators/base'

module PgSearch
  module Migration
    class Generator < Rails::Generators::Base
      Rails::Generators.hide_namespace namespace

      def self.inherited(subclass)
        super
        subclass.source_root File.expand_path('../templates', __FILE__)
      end

      def create_migration
        now = Time.now.utc
        filename = "#{now.strftime('%Y%m%d%H%M%S')}_#{migration_name}.rb"
        template "#{migration_name}.rb.erb", "db/migrate/#{filename}"
      end

      private

      def read_sql_file(filename)
        sql_directory = File.expand_path('../../../../sql', __FILE__)
        source_path = File.join(sql_directory, "#{filename}.sql")
        File.read(source_path).strip
      end
    end
  end
end
