require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PgSearch::Document do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  with_model :searchable do
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
      let(:text) { double(:text) }
      before do
        searchable.stub!(:pg_search_text => text)
        document.valid?
      end

      its(:content) { should == text }
    end
  end
end
