require "spec_helper"

describe PgSearch::Document do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  with_model :Searchable do
    table
    model do
      include PgSearch
      multisearchable
    end
  end

  it { should be_an(ActiveRecord::Base) }

  describe "callbacks" do
    describe "before_validation" do
      subject { document }
      let(:document) { PgSearch::Document.new(:searchable => searchable) }
      let(:searchable) { Searchable.new }

      before do
        # Redefine the options for multisearchable
        Searchable.multisearchable(multisearchable_options)
      end

      context "when searching against a single column" do
        let(:multisearchable_options) { {:against => :some_content} }
        let(:text) { "foo bar" }
        before do
          allow(searchable).to receive(:some_content) { text }
          document.valid?
        end

        describe '#content' do
          subject { super().content }
          it { should == text }
        end
      end

      context "when searching against multiple columns" do
        let(:multisearchable_options) { {:against => [:attr1, :attr2]} }
        before do
          allow(searchable).to receive(:attr1) { '1' }
          allow(searchable).to receive(:attr2) { '2' }
          document.valid?
        end

        describe '#content' do
          subject { super().content }
          it { should == "1 2" }
        end
      end
    end
  end
end
