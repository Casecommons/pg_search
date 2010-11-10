require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "an ActiveRecord model which includes PgSearch" do

  with_model :model_with_pg_search do
    table do |t|
      t.string 'title'
      t.text 'content'
    end

    model do
      include PgSearch
    end
  end

  describe ".pg_search_scope" do
    it "builds a scope" do
      model_with_pg_search.class_eval do
        pg_search_scope "matching_query", []
      end

      lambda {
        model_with_pg_search.scoped({}).matching_query("foo").scoped({})
      }.should_not raise_error
    end

    it "builds a scope for searching on a particular column" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_content, :content
      end

      included = model_with_pg_search.create!(:content => 'foo')
      excluded = model_with_pg_search.create!(:content => 'bar')

      results = model_with_pg_search.search_content('foo')
      results.should include(included)
      results.should_not include(excluded)
    end

    it "builds a scope for searching on multiple columns" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_text_and_content, [:title, :content]
      end

      included = [
        model_with_pg_search.create!(:title => 'foo', :content => 'bar'),
        model_with_pg_search.create!(:title => 'bar', :content => 'foo')
      ]
      excluded = [
        model_with_pg_search.create!(:title => 'foo', :content => 'foo'),
        model_with_pg_search.create!(:title => 'bar', :content => 'bar')
      ]

      results = model_with_pg_search.search_text_and_content('foo bar')

      results.should =~ included
      excluded.each do |result|
        results.should_not include(result)
      end
    end
  end

  describe "a given pg_search_scope" do
    before do
      model_with_pg_search.class_eval do
        pg_search_scope :search_content, [:content]
      end
   end

    it "allows for multiple space-separated search terms" do
      included = [
        model_with_pg_search.create!(:content => 'foo bar'),
        model_with_pg_search.create!(:content => 'bar foo'),
        model_with_pg_search.create!(:content => 'bar foo baz'),
      ]
      excluded = [
        model_with_pg_search.create!(:content => 'foo'),
        model_with_pg_search.create!(:content => 'foo baz')
      ]

      results = model_with_pg_search.search_content('foo bar')
      results.should =~ included
      results.should_not include(excluded)
    end

  end

end
