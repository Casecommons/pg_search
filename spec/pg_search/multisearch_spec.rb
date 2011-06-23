require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PgSearch::Multisearch do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  with_model :MultisearchableModel do
    table do |t|
      t.string :title
      t.text :content
      t.timestamps
    end
    model do
      include PgSearch
    end
  end

  describe ".rebuild" do
    it "should fetch the proper columns from the model" do
    end
  end

  describe ".rebuild_sql" do
    context "with one attribute" do
      it "should generate the proper SQL code" do
        model = MultisearchableModel
        connection = model.connection

        model.multisearchable :against => :title

        expected_sql = <<-SQL
INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title, '')
         ) AS content
  FROM #{model.quoted_table_name}
SQL

        PgSearch::Multisearch.rebuild_sql(MultisearchableModel).should == expected_sql
      end
    end

    context "with multiple attributes" do
      it "should generate the proper SQL code" do
        model = MultisearchableModel
        connection = model.connection

        model.multisearchable :against => [:title, :content]

        expected_sql = <<-SQL
INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title, '') || ' ' || coalesce(#{model.quoted_table_name}.content, '')
         ) AS content
  FROM #{model.quoted_table_name}
SQL

        PgSearch::Multisearch.rebuild_sql(MultisearchableModel).should == expected_sql
      end
    end

  end
end
