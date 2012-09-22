require "spec_helper"

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

          context "with multisearch enabled on the model" do
            before { PgSearch.stub(:multisearch_enabled?) { true } }

            context "when the record itself is multisearchable (default)" do
              it { should change(PgSearch::Document, :count).by(1) }
            end

            context "when the record itself is not multisearchable" do
              before { record.stub(:multisearchable?) { false } }
              it { should_not change(PgSearch::Document, :count) }
            end
          end

          context "with multisearch disabled on the model" do
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

            context "with multisearch enabled on the model" do
              before { PgSearch.stub(:multisearch_enabled?) { true } }

              context "when the record itself is multisearchable" do
                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it { should_not change(PgSearch::Document, :count) }
              end

              context "when the record itself is not multisearchable" do
                before { record.stub(:multisearchable?) { false } }

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it { should change(PgSearch::Document, :count).by(-1) }
              end
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

              context "when the record itself is multisearchable" do
                it { should change(PgSearch::Document, :count).by(1) }
              end

              context "when the record itself is not multisearchable" do
                before { record.stub(:multisearchable?) { false } }
                it { should_not change(PgSearch::Document, :count) }
              end
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

          expect {
            record.destroy
          }.to change(PgSearch::Document, :count).by(-1)

          expect {
            PgSearch::Document.find(document.id)
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
