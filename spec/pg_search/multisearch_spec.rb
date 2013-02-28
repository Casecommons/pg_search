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

  with_model :DocumentModel do
    table do |t|
      t.text :content
      t.belongs_to :searchable, :polymorphic => true
      t.timestamps
    end
    model do
      include PgSearch
      belongs_to :searchable, :polymorphic => true
    end
  end

  let(:model) { MultisearchableModel }
  let(:document_model) { DocumentModel }
  let(:connection) { model.connection }
  let(:documents) { double(:documents) }

  describe ".rebuild" do
    before do
      model.multisearchable({
        :against => :title,
        'DocumentModel' => {:against => :title}
      })
    end

    it "should operate inside a transaction" do
      model.should_receive(:transaction).exactly(model.pg_search_multisearchable_options.keys.size)

      PgSearch::Multisearch.rebuild(model) # rebuilds all documents
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
          INSERT INTO #{document_model.table_name}
            (searchable_type, searchable_id, content, created_at, updated_at)
            VALUES
            ('#{model.name}', 123, 'bar', now(), now());
          INSERT INTO #{document_model.table_name}
            (searchable_type, searchable_id, content, created_at, updated_at)
            VALUES
            ('Bar', 123, 'bar', now(), now());
        SQL
        PgSearch::Document.count.should == 2
        document_model.count.should == 2
      end

      context "when clean_up and document_model are not passed" do
        it "should delete the document from all document tables for the model" do
          PgSearch::Multisearch.rebuild(model)
          PgSearch::Document.count.should == 1
          PgSearch::Document.first.searchable_type.should == "Bar"
          document_model.count.should == 1
          document_model.first.searchable_type.should == "Bar"
        end
      end

      context "when clean_up is true" do
        let(:clean_up) { true }

        context "and document_model is not passed" do
          it "should delete the document from all document tables for the model" do
            PgSearch::Multisearch.rebuild(model, clean_up)
            PgSearch::Document.count.should == 1
            PgSearch::Document.first.searchable_type.should == "Bar"
            document_model.count.should == 1
            document_model.first.searchable_type.should == "Bar"
          end
        end

        context "and document_model is passed" do
          it "should delete the document from document_model table only e.g. PgSearch::Document or document_model" do
            PgSearch::Multisearch.rebuild(model, clean_up, document_model)
            document_model.count.should == 1
            document_model.first.searchable_type.should == "Bar"
            PgSearch::Document.count.should == 2
          end
        end
      end

      context "when clean_up is false" do
        let(:clean_up) { false }

        context "and document_model is not passed" do
          it "should not delete any documents for the model" do
            PgSearch::Multisearch.rebuild(model, clean_up)
            PgSearch::Document.count.should == 2
            document_model.count.should == 2
          end
        end
        
        context "and document_model is passed" do
          it "should not delete any documents for the model" do
            PgSearch::Multisearch.rebuild(model, clean_up, PgSearch::Document)
            PgSearch::Document.count.should == 2
            document_model.count.should == 2
          end
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
              INSERT INTO #{DocumentModel.table_name}
                (searchable_type, searchable_id, content, created_at, updated_at)
                VALUES
                ('Baz', 789, 'baz', now(), now());
            SQL
          end
        end

        it "should call .rebuild_pg_search_documents and skip the default behavior" do
          PgSearch::Multisearch.should_not_receive(:rebuild_sql)
          PgSearch::Multisearch.rebuild(model)

          record = PgSearch::Document.find_by_searchable_type_and_searchable_id("Baz", 789)
          record.content.should == "baz"
          record = document_model.find_by_searchable_type_and_searchable_id("Baz", 789)
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
        PgSearch::Document.last(2).map(&:searchable).map(&:title).should =~ new_models.map(&:title)
        document_model.last(2).map(&:searchable).map(&:title).should =~ new_models.map(&:title)
      end
    end

    describe "the generated SQL" do
      let(:now) { Time.now }

      before do
        Time.stub(:now => now)
      end

      context "with one document table" do
        before do
          model.pg_search_multisearchable_options = {}
          model.multisearchable({
            :against => [:title]
          })
        end
        
        context "with one attribute" do
          it "should generate the proper SQL code for PgSearch::Document" do
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

          it "should generate the proper SQL code for PgSearch::Document" do
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

            statements = []
            connection.stub(:execute) { |sql| statements << sql }

            PgSearch::Multisearch.rebuild(model)

            statements.should include(expected_sql)
          end
        end
      end
      
      context "with multiple document tables" do
        before do
          # unsure why but w/out this stub_chain test fails on jruby
          DocumentModel.stub_chain(:where, :delete_all)
        end
        context "with one attribute" do
          before do
            model.multisearchable({
              :against => [:title],
              'DocumentModel' => {
                :against => [:title]
              }
            }) 
          end 
        
          it "should generate the proper SQL code for all document models" do
            expected_sql_document_model = <<-SQL
INSERT INTO #{document_model.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT #{connection.quote(model.name)} AS searchable_type,
         #{model.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{model.quoted_table_name}.title::text, '')
         ) AS content,
         #{connection.quote(connection.quoted_date(now))} AS created_at,
         #{connection.quote(connection.quoted_date(now))} AS updated_at
  FROM #{model.quoted_table_name}
  SQL
            expected_sql_pg_search_document = <<-SQL
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

            statements = []
            connection.stub(:execute) { |sql| statements << sql }

            PgSearch::Multisearch.rebuild(model)

            statements.should include(expected_sql_document_model)
            statements.should include(expected_sql_pg_search_document)
          end
        end

        context "with multiple attributes" do
          before do
            model.multisearchable({
              :against => [:title, :content],
              'DocumentModel' => {
                :against => [:title, :content],
              }
            }) 
          end

          it "should generate the proper SQL code for all document tables" do
            expected_sql_pg_search_document = <<-SQL
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

            expected_sql_document_model = <<-SQL
INSERT INTO #{document_model.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
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

            statements.should include(expected_sql_pg_search_document)
            statements.should include(expected_sql_document_model)
          end
        end
      end 
    end
  end
end
