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

  let(:model) { MultisearchableModel }
  let(:connection) { model.connection }
  let(:documents) { double(:documents) }

  describe ".rebuild" do
    before do
      model.multisearchable :against => :title
    end

    it "should operate inside a transaction" do
      model.should_receive(:transaction).once()

      PgSearch::Multisearch.rebuild(model)
    end

    describe "cleaning up search documents for this model" do
      before do
        connection.execute <<-SQL
          INSERT INTO pg_search_documents
            (searchable_type, searchable_id, content, created_at, updated_at)
            VALUES
            ('#{model.name}', 123, 'foo', now(), now());
          INSERT INTO pg_search_documents
            (searchable_type, searchable_id, content, created_at, updated_at)
            VALUES
            ('Bar', 123, 'foo', now(), now());
        SQL
        PgSearch::Document.count.should == 2
      end

      context "when clean_up is not passed" do
        it "should delete the document for the model" do
          PgSearch::Multisearch.rebuild(model)
          PgSearch::Document.count.should == 1
          PgSearch::Document.first.searchable_type.should == "Bar"
        end
      end

      context "when clean_up is true" do
        let(:clean_up) { true }

        it "should delete the document for the model" do
          PgSearch::Multisearch.rebuild(model, clean_up)
          PgSearch::Document.count.should == 1
          PgSearch::Document.first.searchable_type.should == "Bar"
        end
      end

      context "when clean_up is false" do
        let(:clean_up) { false }

        it "should not delete the document for the model" do
          PgSearch::Multisearch.rebuild(model, clean_up)
          PgSearch::Document.count.should == 2
        end
      end
    end

    describe "inserting the new documents" do
      let!(:new_models) { [] }
      before do
        new_models << model.create!(:title => "Foo", :content => "Bar")
        new_models << model.create!(:title => "Baz", :content => "Bar")
      end

      it "should create new documents for the two models" do
        PgSearch::Multisearch.rebuild(model)
        PgSearch::Document.last(2).map(&:searchable).map(&:title).should =~ new_models.map(&:title)
      end
    end
  end

  describe ".rebuild_sql" do
    let(:now) { Time.now }

    before do
      Time.stub(:now => now)
    end

    context "with one attribute" do
      before do
        model.multisearchable :against => [:title]
      end

      it "should generate the proper SQL code" do
        expected_sql = <<-SQL
INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title::text, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
  FROM #{model.quoted_table_name}
  SQL

        PgSearch::Multisearch.rebuild_sql(model).should == expected_sql
      end
    end

    context "with multiple attributes" do
      before do
        model.multisearchable :against => [:title, :content]
      end

      it "should generate the proper SQL code" do
        expected_sql = <<-SQL
INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title::text, '') || ' ' || coalesce(#{model.quoted_table_name}.content::text, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
  FROM #{model.quoted_table_name}
  SQL

        PgSearch::Multisearch.rebuild_sql(model).should == expected_sql
      end
    end
  end
end
