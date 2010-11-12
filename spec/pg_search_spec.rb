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
        pg_search_scope "matching_query", :against => []
      end

      lambda {
        model_with_pg_search.scoped({}).matching_query("foo").scoped({})
      }.should_not raise_error
    end

    it "builds a scope for searching on a particular column" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_content, :against => :content
      end

      included = model_with_pg_search.create!(:content => 'foo')
      excluded = model_with_pg_search.create!(:content => 'bar')

      results = model_with_pg_search.search_content('foo')
      results.should include(included)
      results.should_not include(excluded)
    end

    it "builds a scope for searching on multiple columns" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title_and_content, :against => [:title, :content]
      end

      included = [
        model_with_pg_search.create!(:title => 'foo', :content => 'bar'),
        model_with_pg_search.create!(:title => 'bar', :content => 'foo')
      ]
      excluded = [
        model_with_pg_search.create!(:title => 'foo', :content => 'foo'),
        model_with_pg_search.create!(:title => 'bar', :content => 'bar')
      ]

      results = model_with_pg_search.search_title_and_content('foo bar')

      results.should =~ included
      excluded.each do |result|
        results.should_not include(result)
      end
    end

    it "builds a scope for searching on multiple columns where one is NULL" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title_and_content, :against => [:title, :content]
      end

      included = model_with_pg_search.create!(:title => 'foo', :content => nil)

      results = model_with_pg_search.search_title_and_content('foo')

      results.should == [included]
    end

    it "builds a scope for searching trigrams" do
      model_with_pg_search.class_eval do
        pg_search_scope :with_trigrams, :against => [:title, :content], :using => :trigram
      end

      included = model_with_pg_search.create!(:title => 'abcdef', :content => 'ghijkl')

      results = model_with_pg_search.with_trigrams('cdef ijkl')

      results.should == [included]
    end

    it "builds a scope using multiple features" do
      model_with_pg_search.class_eval do
        pg_search_scope :with_tsearch_and_trigrams, :against =>  [:title, :content], :using => [:tsearch, :trigram]
      end

      included = model_with_pg_search.create!(:title => 'abcdef', :content => 'ghijkl')

      results = model_with_pg_search.with_tsearch_and_trigrams('cdef ijkl') # matches trigram only
      results.should == [included]

      results = model_with_pg_search.with_tsearch_and_trigrams('ghijkl abcdef') # matches tsearch only
      results.should == [included]
    end

    it "builds a scope which is case-insensitive" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title, :against => :title
      end

      # \303\241 is a with acute accent
      # \303\251 is e with acute accent

      included = [model_with_pg_search.create!(:title => "foo"),
                  model_with_pg_search.create!(:title => "FOO")]

      results = model_with_pg_search.search_title("Foo")
      results.should =~ included
    end

    it "builds a scope which is diacritic-sensitive" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title_with_diacritics, :against => :title
      end

      # \303\241 is a with acute accent
      # \303\251 is e with acute accent

      included = model_with_pg_search.create!(:title => "abcd\303\251f")
      excluded = model_with_pg_search.create!(:title => "\303\241bcdef")

      results = model_with_pg_search.search_title_with_diacritics("abcd\303\251f")
      results.should == [included]
      results.should_not include(excluded)
    end

    context "when normalizing diacritics" do
      it "ignores diacritics" do
        model_with_pg_search.class_eval do
          pg_search_scope :search_title_without_diacritics, :against => :title, :normalizing => :diacritics
        end

        # \303\241 is a with acute accent
        # \303\251 is e with acute accent

        included = model_with_pg_search.create!(:title => "\303\241bcdef")

        results = model_with_pg_search.search_title_without_diacritics("abcd\303\251f")
        results.should == [included]
      end
    end

    context "when passed a lambda" do
      it "builds a dynamic scope" do
        model_with_pg_search.class_eval do
          pg_search_scope :search_title_or_content, lambda { |query, pick_content|
            {
              :query => query.gsub("-remove-", ""),
              :against => pick_content ? :content : :title
            }
          }
        end

        included = model_with_pg_search.create!(:title => 'foo', :content => 'bar')
        excluded = model_with_pg_search.create!(:title => 'bar', :content => 'foo')

        model_with_pg_search.search_title_or_content('fo-remove-o', false).should == [included]
        model_with_pg_search.search_title_or_content('b-remove-ar', true).should == [included]
      end
    end

    it "builds a scope that doesn't match prefixes" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title_without_prefixes, :against => :title
      end

      included = model_with_pg_search.create!(:title => 'pre')
      excluded = model_with_pg_search.create!(:title => 'prefix')

      results = model_with_pg_search.search_title_without_prefixes("pre")
      results.should == [included]
      results.should_not include(excluded)
    end

    context "when normalizing prefixes" do
      it "builds a scope that matches prefixes" do
        model_with_pg_search.class_eval do
          pg_search_scope :search_title_with_prefixes, :against => :title, :normalizing => :prefixes
        end

        included = model_with_pg_search.create!(:title => 'prefix')
        excluded = model_with_pg_search.create!(:title => 'postfix')

        results = model_with_pg_search.search_title_with_prefixes("pre")
        results.should == [included]
        results.should_not include(excluded)
      end
    end

    it "builds a scope that stems with the english dictionary by default" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title, :against => :title
      end

      included = [model_with_pg_search.create!(:title => "jump"),
                  model_with_pg_search.create!(:title => "jumped"),
                  model_with_pg_search.create!(:title => "jumping")]

      results = model_with_pg_search.search_title("jump")
      results.should =~ included
    end

    context "when using the simple dictionary" do
      it "builds a scope that matches terms that would have been stemmed by the english dictionary" do
        model_with_pg_search.class_eval do
          pg_search_scope :search_title, :against => :title, :with_dictionary => :simple
        end

        included = model_with_pg_search.create!(:title => "jumped")
        excluded = [model_with_pg_search.create!(:title => "jump"),
                    model_with_pg_search.create!(:title => "jumping")]

        results = model_with_pg_search.search_title("jumped")
        results.should == [included]
        excluded.each do |result|
          results.should_not include(result)
        end
      end
    end

    it "builds a scope that sorts by rank" do
      model_with_pg_search.class_eval do
        pg_search_scope :search_title_and_content, :against => [:title, :content]
      end

      loser = model_with_pg_search.create!(:title => 'foo', :content => 'bar')
      winner = model_with_pg_search.create!(:title => 'foo', :content => 'foo')

      results = model_with_pg_search.search_title_and_content("foo")
      results[0].rank.should > results[1].rank
      results.should == [winner, loser]
    end
  end

  it "builds a scope that sorts by primary key for records that rank the same" do
    model_with_pg_search.class_eval do
      pg_search_scope :search_title, :against => :title
    end

    sorted_results = [model_with_pg_search.create!(:title => 'foo'),
                      model_with_pg_search.create!(:title => 'foo')].sort_by(&:id)

    results = model_with_pg_search.search_title("foo")
    results.should == sorted_results
  end

  it "builds a scope that allows for multiple space-separated search terms" do
    model_with_pg_search.class_eval do
      pg_search_scope :search_content, :against => [:content]
    end

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

  it "builds a scope that sorts by weighted rank using an array of arrays" do
    model_with_pg_search.class_eval do
      pg_search_scope :search_weighted_by_array_of_arrays, :against => [[:content, 'B'], [:title, 'A']]
    end

    loser = model_with_pg_search.create!(:title => 'bar', :content => 'foo')
    winner = model_with_pg_search.create!(:title => 'foo', :content => 'bar')

    results = model_with_pg_search.search_weighted_by_array_of_arrays('foo')
    results[0].rank.to_f.should > results[1].rank.to_f
    results.should == [winner, loser]
  end

  it "builds a scope that sorts by weighted rank using a hash" do
    model_with_pg_search.class_eval do
      pg_search_scope :search_weighted_by_hash, :against => {:content => 'B', :title => 'A'}
    end

    loser = model_with_pg_search.create!(:title => 'bar', :content => 'foo')
    winner = model_with_pg_search.create!(:title => 'foo', :content => 'bar')

    results = model_with_pg_search.search_weighted_by_hash('foo')
    results[0].rank.to_f.should > results[1].rank.to_f
    results.should == [winner, loser]
  end

  it "builds a scope that sorts by weighted rank only for some columns" do
    model_with_pg_search.class_eval do
      pg_search_scope :search_weighted, :against => [:content, [:title, 'A']]
    end

    loser = model_with_pg_search.create!(:title => 'bar', :content => 'foo')
    winner = model_with_pg_search.create!(:title => 'foo', :content => 'bar')

    results = model_with_pg_search.search_weighted('foo')
    results[0].rank.to_f.should > results[1].rank.to_f
    results.should == [winner, loser]
  end

  it "builds a scope that allows searching with characters that are invalid in a tsquery" do
    model_with_pg_search.class_eval do
      pg_search_scope :search_title, :against => :title
    end

    included = model_with_pg_search.create!(:title => 'foo')

    results = model_with_pg_search.search_title('foo & ,')
    results.should == [included]
  end

end
