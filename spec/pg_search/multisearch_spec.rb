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
      model.should_receive(:transaction).once

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
        PgSearch::SearchDocument.count.should == 2
      end

      context "when clean_up is not passed" do
        it "should delete the document for the model" do
          PgSearch::Multisearch.rebuild(model)
          PgSearch::SearchDocument.count.should == 1
          PgSearch::SearchDocument.first.searchable_type.should == "Bar"
        end
      end

      context "when clean_up is true" do
        let(:clean_up) { true }

        it "should delete the document for the model" do
          PgSearch::Multisearch.rebuild(model, clean_up)
          PgSearch::SearchDocument.count.should == 1
          PgSearch::SearchDocument.first.searchable_type.should == "Bar"
        end
      end

      context "when clean_up is false" do
        let(:clean_up) { false }

        it "should not delete the document for the model" do
          PgSearch::Multisearch.rebuild(model, clean_up)
          PgSearch::SearchDocument.count.should == 2
        end
      end

      context "when the model implements .rebuild_pg_search_documents" do
        before do
          def model.rebuild_pg_search_documents
            connection.execute <<-SQL
              INSERT INTO pg_search_documents
                (searchable_type, searchable_id, content, created_at, updated_at)
                VALUES
                ('Baz', 789, 'baz', now(), now());
            SQL
          end
        end

        it "should call .rebuild_pg_search_documents and skip the default behavior" do
          PgSearch::Multisearch.should_not_receive(:rebuild_sql)
          PgSearch::Multisearch.rebuild(model)

          record = PgSearch::SearchDocument.find_by_searchable_type_and_searchable_id("Baz", 789)
          record.content.should == "baz"
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
        PgSearch::SearchDocument.last(2).map(&:searchable).map(&:title).should =~ new_models.map(&:title)
      end
    end

    describe "the generated SQL" do
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
INSERT INTO #{PgSearch::SearchDocument.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title::text, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
  FROM #{model.quoted_table_name}
  SQL

          statements = []
          connection.stub(:execute) { |sql| statements << sql }

          PgSearch::Multisearch.rebuild(model)

          statements.should include(expected_sql)
        end
      end

      context "with multiple attributes" do
        before do
          model.multisearchable :against => [:title, :content]
        end

        it "should generate the proper SQL code" do
          expected_sql = <<-SQL
INSERT INTO #{PgSearch::SearchDocument.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title::text, '') || ' ' || coalesce(#{model.quoted_table_name}.content::text, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
  FROM #{model.quoted_table_name}
SQL

          statements = []
          connection.stub(:execute) { |sql| statements << sql }

          PgSearch::Multisearch.rebuild(model)

          statements.should include(expected_sql)
        end
      end
    end
  end
end
