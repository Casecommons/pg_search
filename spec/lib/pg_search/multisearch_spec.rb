# frozen_string_literal: true

require "spec_helper"

describe PgSearch::Multisearch do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  with_model :MultisearchableModel do
    table do |t|
      t.string :title
      t.text :content
      t.timestamps null: false
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
      expect(model).to receive(:transaction).once

      PgSearch::Multisearch.rebuild(model)
    end

    describe "cleaning up search documents for this model" do
      before do
        connection.execute <<-SQL.strip_heredoc
          INSERT INTO pg_search_documents
            (searchable_type, searchable_id, content, created_at, updated_at)
            VALUES
            ('#{model.name}', 123, 'foo', now(), now());
          INSERT INTO pg_search_documents
            (searchable_type, searchable_id, content, created_at, updated_at)
            VALUES
            ('Bar', 123, 'foo', now(), now());
        SQL
        expect(PgSearch::Document.count).to eq(2)
      end

      context "when clean_up is not passed" do
        it "should delete the document for the model" do
          PgSearch::Multisearch.rebuild(model)
          expect(PgSearch::Document.count).to eq(1)
          expect(PgSearch::Document.first.searchable_type).to eq("Bar")
        end
      end

      context "when clean_up is true" do
        let(:clean_up) { true }

        it "should delete the document for the model" do
          PgSearch::Multisearch.rebuild(model, clean_up)
          expect(PgSearch::Document.count).to eq(1)
          expect(PgSearch::Document.first.searchable_type).to eq("Bar")
        end
      end

      context "when clean_up is false" do
        let(:clean_up) { false }

        it "should not delete the document for the model" do
          PgSearch::Multisearch.rebuild(model, clean_up)
          expect(PgSearch::Document.count).to eq(2)
        end
      end

      context "when the model implements .rebuild_pg_search_documents" do
        before do
          def model.rebuild_pg_search_documents
            connection.execute <<-SQL.strip_heredoc
              INSERT INTO pg_search_documents
                (searchable_type, searchable_id, content, created_at, updated_at)
                VALUES
                ('Baz', 789, 'baz', now(), now());
            SQL
          end
        end

        it "should call .rebuild_pg_search_documents and skip the default behavior" do
          expect(PgSearch::Multisearch).not_to receive(:rebuild_sql)
          PgSearch::Multisearch.rebuild(model)

          record = PgSearch::Document.find_by_searchable_type_and_searchable_id("Baz", 789)
          expect(record.content).to eq("baz")
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
        expect(PgSearch::Document.last(2).map(&:searchable).map(&:title)).to match_array(new_models.map(&:title))
      end
    end

    describe "the generated SQL" do
      let(:now) { Time.now }
      before { allow(Time).to receive(:now).and_return(now) }

      context "with one attribute" do
        before do
          model.multisearchable :against => [:title]
        end

        it "should generate the proper SQL code" do
          expected_sql = <<-SQL.strip_heredoc
            INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
              SELECT #{connection.quote(model.name)} AS searchable_type,
                     #{model.quoted_table_name}.id AS searchable_id,
                     (
                       coalesce(#{model.quoted_table_name}."title"::text, '')
                     ) AS content,
                     #{connection.quote(connection.quoted_date(now))} AS created_at,
                     #{connection.quote(connection.quoted_date(now))} AS updated_at
              FROM #{model.quoted_table_name}
          SQL

          statements = []
          allow(connection).to receive(:execute) { |sql| statements << sql.strip }

          PgSearch::Multisearch.rebuild(model)

          expect(statements).to include(expected_sql.strip)
        end
      end

      context "with multiple attributes" do
        before do
          model.multisearchable :against => %i[title content]
        end

        it "should generate the proper SQL code" do
          expected_sql = <<-SQL.strip_heredoc
            INSERT INTO #{PgSearch::Document.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
              SELECT #{connection.quote(model.name)} AS searchable_type,
                     #{model.quoted_table_name}.id AS searchable_id,
                     (
                       coalesce(#{model.quoted_table_name}."title"::text, '') || ' ' || coalesce(#{model.quoted_table_name}."content"::text, '')
                     ) AS content,
                     #{connection.quote(connection.quoted_date(now))} AS created_at,
                     #{connection.quote(connection.quoted_date(now))} AS updated_at
              FROM #{model.quoted_table_name}
          SQL

          statements = []
          allow(connection).to receive(:execute) { |sql| statements << sql.strip }

          PgSearch::Multisearch.rebuild(model)

          expect(statements).to include(expected_sql.strip)
        end
      end
    end
  end
end
