require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PgSearch::Multisearchable do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  before { PgSearch.stub(:multisearch_enabled?) { true } }

  describe "a model that is multisearchable" do
    subject { ModelThatIsMultisearchable }

    with_model :ModelThatIsMultisearchable do
      table do |t|
      end
      model do
        include PgSearch
        multisearchable
      end
    end

    describe "callbacks" do
      describe "after_create" do
        let(:record) { ModelThatIsMultisearchable.new }

        describe "saving the record" do
          subject do
            lambda { record.save! }
          end

          context "with multisearch enabled" do
            before { PgSearch.stub(:multisearch_enabled?) { true } }
            it { should change(PgSearch::Document, :count).by(1) }
          end

          context "with multisearch disabled" do
            before { PgSearch.stub(:multisearch_enabled?) { false } }
            it { should_not change(PgSearch::Document, :count) }
          end
        end

        describe "the document" do
          subject { document }
          before { record.save! }
          let(:document) { PgSearch::Document.last }

          its(:searchable) { should == record }
        end
      end

      describe "after_update" do
        let!(:record) { ModelThatIsMultisearchable.create! }

        context "when the document is present" do
          describe "saving the record" do
            subject do
              lambda { record.save! }
            end

            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled?) { true } }

              before { record.pg_search_document.should_receive(:save) }
              it { should_not change(PgSearch::Document, :count) }
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled?) { false } }

              before { record.pg_search_document.should_not_receive(:save) }
              it { should_not change(PgSearch::Document, :count) }
            end
          end
        end

        context "when the document is missing" do
          before { record.pg_search_document = nil }

          describe "saving the record" do
            subject do
              lambda { record.save! }
            end

            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled?) { true } }
              it { should change(PgSearch::Document, :count).by(1) }
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled?) { false } }
              it { should_not change(PgSearch::Document, :count) }
            end
          end
        end
      end

      describe "after_destroy" do
        it "should remove its document" do
          record = ModelThatIsMultisearchable.create!
          document = record.pg_search_document

          lambda { record.destroy }.should change(PgSearch::Document, :count).by(-1)
          lambda {
            PgSearch::Document.find(document.id)
          }.should raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
