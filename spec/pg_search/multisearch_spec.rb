require "spec_helper"

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
    let(:now) { Time.now }

    before do
      Time.stub(:now => now)
    end

    context "with one attribute" do
      it "should generate the proper SQL code" do
        model = MultisearchableModel
        connection = model.connection

        model.multisearchable :against => :title

        expected_sql = <<-SQL
INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
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
INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title, '') || ' ' || coalesce(#{model.quoted_table_name}.content, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
  FROM #{model.quoted_table_name}
SQL

        PgSearch::Multisearch.rebuild_sql(MultisearchableModel).should == expected_sql
      end
    end

  end
end
