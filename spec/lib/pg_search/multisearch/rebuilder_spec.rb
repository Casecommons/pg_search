# frozen_string_literal: true

require "spec_helper"

# standard:disable RSpec/NestedGroups
describe PgSearch::Multisearch::Rebuilder do
  with_table "pg_search_documents", &DOCUMENTS_SCHEMA

  describe "when initialized with a model that is not multisearchable" do
    with_model :NotSearchable do
      table
    end

    it "raises an exception" do
      expect {
        described_class.new(NotSearchable)
      }.to raise_exception(
        PgSearch::Multisearch::ModelNotMultisearchable,
        "NotSearchable is not multisearchable. See PgSearch::ClassMethods#multisearchable"
      )
    end
  end

  describe "#rebuild" do
    context "when the model defines .rebuild_pg_search_documents" do
      context "when multisearchable is not conditional" do
        with_model :Book do
          table

          model do
            include PgSearch::Model

            multisearchable

            class_attribute :documents_rebuilt, default: false

            def self.rebuild_pg_search_documents = self.documents_rebuilt = true
          end
        end

        it "dispatches to .rebuild_pg_search_documents" do
          described_class.new(Book).rebuild

          expect(Book.documents_rebuilt).to be true
        end
      end

      context "when multisearchable is conditional" do
        %i[if unless].each do |key|
          context "via :#{key}" do
            with_model :Book do
              table do |t|
                t.boolean :active
              end

              model do
                include PgSearch::Model

                multisearchable key => :active?

                class_attribute :documents_rebuilt, default: false

                def self.rebuild_pg_search_documents
                  self.documents_rebuilt = true
                end
              end
            end

            it "dispatches to .rebuild_pg_search_documents" do
              described_class.new(Book).rebuild

              expect(Book.documents_rebuilt).to be true
            end
          end
        end
      end
    end

    context "when the model does not define .rebuild_pg_search_documents" do
      context "when multisearchable is not conditional" do
        context "when :against only includes columns" do
          with_model :Book do
            table do |t|
              t.string :title
            end

            model do
              include PgSearch::Model

              multisearchable against: :title
            end
          end

          it "inserts a document for each record via bulk INSERT" do
            book = PgSearch.disable_multisearch { Book.create!(title: "Dune") }

            described_class.new(Book).rebuild

            doc = PgSearch::Document.find_by!(searchable: book)
            expect(doc.searchable_type).to eq("Book")
            expect(doc.searchable_id).to eq(book.id)
            expect(doc.content).to eq("Dune")
          end

          it "coalesces NULL column values to empty string" do
            book = PgSearch.disable_multisearch { Book.create!(title: nil) }

            described_class.new(Book).rebuild

            doc = PgSearch::Document.find_by!(searchable: book)
            expect(doc.content).to eq("")
          end

          it "stamps both timestamps with the precision and offset of one clock call" do
            time = Time.iso8601("2001-01-01T06:30:00.123456+05:30")
            call_count = 0
            time_source = lambda do
              call_count += 1
              time
            end

            book = PgSearch.disable_multisearch { Book.create!(title: "Dune") }

            described_class.new(Book, time_source).rebuild

            expect(call_count).to eq(1)
            document = PgSearch::Document.find_by!(searchable: book)
            expect(document.created_at).to eq(time)
            expect(document.updated_at).to eq(time)
          end
        end

        context "when :against includes multiple columns" do
          with_model :Book do
            table do |t|
              t.string :title
              t.text :body
            end

            model do
              include PgSearch::Model

              multisearchable against: %i[title body]
            end
          end

          it "joins column values with a space" do
            book = PgSearch.disable_multisearch { Book.create!(title: "Dune", body: "The spice") }

            described_class.new(Book).rebuild

            doc = PgSearch::Document.find_by!(searchable: book)
            expect(doc.content).to eq("Dune The spice")
          end

          it "coalesces NULL in any column to empty string" do
            book = PgSearch.disable_multisearch { Book.create!(title: "Dune", body: nil) }

            described_class.new(Book).rebuild

            doc = PgSearch::Document.find_by!(searchable: book)
            # Keep the separator when the NULL body becomes an empty string.
            expect(doc.content).to eq("Dune ")
          end
        end

        context "with a camelCase column name" do
          with_model :Book do
            table do |t|
              t.string :camelName
            end

            model do
              include PgSearch::Model

              multisearchable against: :camelName
            end
          end

          it "quotes the column name and inserts correct content" do
            book = PgSearch.disable_multisearch { Book.create!(camelName: "CamelValue") }

            described_class.new(Book).rebuild

            doc = PgSearch::Document.find_by!(searchable: book)
            expect(doc.content).to eq("CamelValue")
          end
        end

        context "with a non-standard primary key" do
          with_model :Book do
            table primary_key: :isbn do |t|
              t.string :title
            end

            model do
              include PgSearch::Model

              multisearchable against: :title
            end
          end

          it "stores the non-standard primary key in searchable_id" do
            book = PgSearch.disable_multisearch { Book.create!(title: "Dune") }

            described_class.new(Book).rebuild

            doc = PgSearch::Document.find_by!(searchable_type: "Book")
            expect(doc.searchable_id).to eq(book.isbn)
          end
        end

        context "with an identifier that requires quoting" do
          with_model :Book do
            table do |t|
              t.string :title
            end

            model do
              include PgSearch::Model

              multisearchable against: :title
            end
          end

          it "quotes a malicious primary key in the generated SQL" do
            malicious_pk = %(id"; DROP TABLE pg_search_documents; --)
            allow(Book).to receive(:primary_key).and_return(malicious_pk)

            sql = described_class.new(Book).send(:rebuild_sql)

            expect(sql).to include(Book.connection.quote_column_name(malicious_pk))
          end

          it "quotes a malicious inheritance column in the generated SQL" do
            malicious_column = %(type"; DROP TABLE pg_search_documents; --)
            allow(Book).to receive(:inheritance_column).and_return(malicious_column)
            allow(Book).to receive(:column_names).and_return(Book.column_names + [malicious_column])

            sql = described_class.new(Book).send(:rebuild_sql)

            expect(sql).to include(Book.connection.quote_column_name(malicious_column))
          end
        end

        context "with STI" do
          with_model :Animal do
            table do |t|
              t.string :type
              t.string :name
            end

            model do
              include PgSearch::Model

              multisearchable against: :name
            end
          end

          with_model :Cat, superclass: :Animal do
            table(false)

            model do
              include PgSearch::Model

              multisearchable against: :name
            end
          end

          it "rebuilds base class documents for null-typed rows only" do
            base = PgSearch.disable_multisearch { Animal.create!(name: "Base") }
            PgSearch.disable_multisearch { Cat.create!(name: "Whiskers") }

            described_class.new(Animal).rebuild

            # Only the directly-typed Animal row is included; Cat rows require their own rebuild
            ids = PgSearch::Document.where(searchable_type: "Animal").map(&:searchable_id)
            expect(ids).to contain_exactly(base.id)
          end

          it "rebuilds subclass documents with exact type match" do
            PgSearch.disable_multisearch { Animal.create!(name: "Base") }
            cat = PgSearch.disable_multisearch { Cat.create!(name: "Whiskers") }

            described_class.new(Cat).rebuild

            # Cat rebuild stores searchable_type = base class name
            ids = PgSearch::Document.where(searchable_type: "Animal").map(&:searchable_id)
            expect(ids).to contain_exactly(cat.id)
          end

          it "stores base_class.name as searchable_type for subclass rows" do
            cat = PgSearch.disable_multisearch { Cat.create!(name: "Whiskers") }

            described_class.new(Cat).rebuild

            doc = PgSearch::Document.find_by!(searchable_id: cat.id, searchable_type: "Animal")
            expect(doc.content).to eq("Whiskers")
          end
        end
      end

      context "when :against includes non-column dynamic methods" do
        with_model :Book do
          table

          model do
            include PgSearch::Model

            multisearchable against: [:summary]

            def summary = "dynamic"
          end
        end

        it "falls back to find_each and creates a document per record" do
          book = PgSearch.disable_multisearch { Book.create! }
          PgSearch::Document.delete_all

          described_class.new(Book).rebuild

          expect(PgSearch::Document.find_by!(searchable: book)).to be_present
        end
      end

      context "when only additional_attributes is set" do
        with_model :Book do
          table do |t|
            t.string :title
          end

          model do
            include PgSearch::Model

            multisearchable against: :title,
              additional_attributes: ->(obj) { {additional_attribute_column: "#{obj.class}::#{obj.id}"} }
          end
        end

        it "falls back to find_each and populates additional attributes" do
          book1 = PgSearch.disable_multisearch { Book.create!(title: "Dune") }
          book2 = PgSearch.disable_multisearch { Book.create!(title: "Foundation") }
          PgSearch::Document.delete_all

          described_class.new(Book).rebuild

          expect(book1.reload.pg_search_document.additional_attribute_column).to eq("Book::#{book1.id}")
          expect(book2.reload.pg_search_document.additional_attribute_column).to eq("Book::#{book2.id}")
        end
      end

      context "when multisearchable is conditional" do
        context "via :if" do
          with_model :Book do
            table do |t|
              t.boolean :published
            end

            model do
              include PgSearch::Model

              multisearchable if: :published?
            end
          end

          it "falls back to find_each and only creates documents for matching records" do
            pub = PgSearch.disable_multisearch { Book.create!(published: true) }
            draft = PgSearch.disable_multisearch { Book.create!(published: false) }
            PgSearch::Document.delete_all

            described_class.new(Book).rebuild

            expect(PgSearch::Document.find_by(searchable: pub)).to be_present
            expect(PgSearch::Document.find_by(searchable: draft)).to be_nil
          end
        end

        context "via :unless" do
          with_model :Book do
            table do |t|
              t.boolean :archived
            end

            model do
              include PgSearch::Model

              multisearchable unless: :archived?
            end
          end

          it "falls back to find_each and skips records matching the condition" do
            live = PgSearch.disable_multisearch { Book.create!(archived: false) }
            archived = PgSearch.disable_multisearch { Book.create!(archived: true) }
            PgSearch::Document.delete_all

            described_class.new(Book).rebuild

            expect(PgSearch::Document.find_by(searchable: live)).to be_present
            expect(PgSearch::Document.find_by(searchable: archived)).to be_nil
          end
        end
      end
    end
  end
end
# standard:enable RSpec/NestedGroups
