module PgSearch
  class MultisearchModelGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("../templates", __FILE__)

    argument :name, {
      :type => :string,
      :banner => "MyDocument[, Admin::Document, ...]",
      :desc => "Class name of model to generate."
    }
    argument :search_type, {
      :default => "default",
      :type => :string,
      :banner => "default, tsearch, dmetaphone",
      :desc => "Type of tsvector to create (optional and affects column naming only)."
    }

  private

    def last_migration_file(glob="*_#{plural_name}.rb")
      migration_file_path = ""
      Dir.glob("db/migrate/#{glob}") do |path|
        migration_file_path = path
      end
      migration_file_path
    end

    def add_tsvector_field_to_table
      #migration_template("add_tsvector_field_tsearch_to_table.rb", "db/migrate/add_tsvector_content_#{search_type}_to_#{table_name}.rb")
      generate("migration", "AddTsvectorContent#{search_type.capitalize}To#{table_name.classify}")
      path = last_migration_file("*add_tsvector_content_#{search_type.downcase}*.rb")
      flag = <<-FLAG
  def change
  end
FLAG
      gsub_file(path, flag) do
<<-MEGATRON
  def up
    add_column :#{table_name}, :ts_vector_content_#{search_type.downcase}, :tsvector
    trigger_sql = <<-SQL
      CREATE TRIGGER #{table_name}_ts_vector_#{search_type.downcase}_update BEFORE INSERT OR UPDATE
      ON #{table_name} FOR EACH ROW EXECUTE PROCEDURE
      tsvector_update_trigger(ts_vector_content_#{search_type.downcase}, 'pg_catalog.english', content);
    SQL
    execute trigger_sql
  end

  def down
    remove_column :#{table_name}, :ts_vector_content_#{search_type.downcase}
    untrigger_sql = <<-SQL
      DROP TRIGGER #{table_name}_ts_vector_#{search_type.downcase}_update ON #{table_name}
    SQL
    execute untrigger_sql
  end
MEGATRON
      end
    end

  public

    def generate_document_model
      generate("model", "#{class_name} content:text")

      marker = "t.text :content"
      insert_into_file(last_migration_file, :after => marker) do
        "\n      t.belongs_to :searchable, :polymorphic => true"
      end
    end

    def conditionally_add_tsvector_column
      unless search_type == "default"
        add_tsvector_field_to_table
      end
    end

    def add_code_to_document_model
      model_file_path = File.join('app/models', class_path, "#{file_name}.rb")
      marker = "class #{class_name} < ActiveRecord::Base\n"
      insert_into_file(model_file_path, :after => marker) do
        <<-MODEL
  include PgSearch
  belongs_to :searchable, :polymorphic => true

  before_validation :update_content

  pg_search_scope :search, lambda { |*args|
    options = if PgSearch.multisearch_options.respond_to?(:call)
      PgSearch.multisearch_options.call(*args)
    else
      {:query => args.first}.merge(PgSearch.multisearch_options)
    end

    {:against => :content}.merge(options)
  }

  private

  def update_content
    methods = Array(searchable.pg_search_multisearchable_options[self.class.to_s][:against])
    searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
    self.content = searchable_text
  end
MODEL
      end
    end
  end
end
