require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PgSearch::Multisearchable do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  describe "a model that is multisearchable" do
    subject { ModelThatIsMultisearchable }

    with_model :model_that_is_multisearchable do
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

          it { should change(PgSearch::Document, :count).by(1) }
        end

        describe "the document" do
          subject { document }
          before { record.save! }
          let(:document) { PgSearch::Document.last }

          its(:searchable) { should == record }
        end
      end

      describe "after_update" do
        it "should touch its document" do
          record = ModelThatIsMultisearchable.create!

          record.pg_search_document.should_receive(:save)
          lambda { record.save! }.should_not change(PgSearch::Document, :count)
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
