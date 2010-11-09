require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "an ActiveRecord model which includes PgSearch" do
  before do
    @klass = Class.new(ActiveRecord::Base) do
      include PgSearch
    end
  end

  describe ".pg_search_index" do
    it "creates a scope" do
      @klass.class_eval do
        pg_search_scope "matching_query"
      end

      lambda {
        @klass.matching_query("foo")
      }.should_not raise_error
    end
  end
end
