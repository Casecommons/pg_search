require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "an ActiveRecord model which includes PgSearch" do

  with_model :ModelWithPgSearch do
    table do |t|
      t.string 'title'
      t.text 'content'
      t.integer 'importance'
    end

    model do
      include PgSearch
    end
  end

  describe ".pg_search_scope" do
    it "builds a scope" do
      ModelWithPgSearch.class_eval do
        pg_search_scope "matching_query", :against => []
      end

      lambda {
        ModelWithPgSearch.scoped({}).matching_query("foo").scoped({})
      }.should_not raise_error
    end

    context "when passed a lambda" do
      it "builds a dynamic scope" do
        ModelWithPgSearch.class_eval do
          pg_search_scope :search_title_or_content, lambda { |query, pick_content|
            {
              :query => query.gsub("-remove-", ""),
              :against => pick_content ? :content : :title
            }
          }
        end

        included = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')
        excluded = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')

        ModelWithPgSearch.search_title_or_content('fo-remove-o', false).should == [included]
        ModelWithPgSearch.search_title_or_content('b-remove-ar', true).should == [included]
      end
    end

    context "when an unknown option is passed in" do
      it "raises an exception when invoked" do
        lambda {
          ModelWithPgSearch.class_eval do
            pg_search_scope :with_unknown_option, :against => :content, :foo => :bar
          end
          ModelWithPgSearch.with_unknown_option("foo")
        }.should raise_error(ArgumentError, /foo/)
      end

      context "dynamically" do
        it "raises an exception when invoked" do
          lambda {
            ModelWithPgSearch.class_eval do
              pg_search_scope :with_unknown_option, lambda { |*| {:against => :content, :foo => :bar} }
            end
            ModelWithPgSearch.with_unknown_option("foo")
          }.should raise_error(ArgumentError, /foo/)
        end
      end
    end

    context "when an unknown :using is passed" do
      it "raises an exception when invoked" do
        lambda {
          ModelWithPgSearch.class_eval do
            pg_search_scope :with_unknown_using, :against => :content, :using => :foo
          end
          ModelWithPgSearch.with_unknown_using("foo")
        }.should raise_error(ArgumentError, /foo/)
      end

      context "dynamically" do
        it "raises an exception when invoked" do
          lambda {
            ModelWithPgSearch.class_eval do
              pg_search_scope :with_unknown_using, lambda { |*| {:against => :content, :using => :foo} }
            end
            ModelWithPgSearch.with_unknown_using("foo")
          }.should raise_error(ArgumentError, /foo/)
        end
      end
    end

    context "when an unknown :ignoring is passed" do
      it "raises an exception when invoked" do
        lambda {
          ModelWithPgSearch.class_eval do
            pg_search_scope :with_unknown_ignoring, :against => :content, :ignoring => :foo
          end
          ModelWithPgSearch.with_unknown_ignoring("foo")
        }.should raise_error(ArgumentError, /ignoring.*foo/)
      end

      context "dynamically" do
        it "raises an exception when invoked" do
          lambda {
            ModelWithPgSearch.class_eval do
              pg_search_scope :with_unknown_ignoring, lambda { |*| {:against => :content, :ignoring => :foo} }
            end
            ModelWithPgSearch.with_unknown_ignoring("foo")
          }.should raise_error(ArgumentError, /ignoring.*foo/)
        end
      end

      context "when :against is not passed in" do
        it "raises an exception when invoked" do
          lambda {
            ModelWithPgSearch.class_eval do
              pg_search_scope :with_unknown_ignoring, {}
            end
            ModelWithPgSearch.with_unknown_ignoring("foo")
          }.should raise_error(ArgumentError, /against/)
        end
        context "dynamically" do
          it "raises an exception when invoked" do
            lambda {
              ModelWithPgSearch.class_eval do
                pg_search_scope :with_unknown_ignoring, lambda { |*| {} }
              end
              ModelWithPgSearch.with_unknown_ignoring("foo")
            }.should raise_error(ArgumentError, /against/)
          end
        end
      end
    end
  end

  describe "a search scope" do
    context "against a single column" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :search_content, :against => :content
        end
      end

      it "returns an empty array when a blank query is passed in" do
        ModelWithPgSearch.create!(:content => 'foo')

        results = ModelWithPgSearch.search_content('')
        results.should == []
      end

      it "returns rows where the column contains the term in the query" do
        included = ModelWithPgSearch.create!(:content => 'foo')
        excluded = ModelWithPgSearch.create!(:content => 'bar')

        results = ModelWithPgSearch.search_content('foo')
        results.should include(included)
        results.should_not include(excluded)
      end

      it "returns rows where the column contains all the terms in the query in any order" do
        included = [ModelWithPgSearch.create!(:content => 'foo bar'),
                    ModelWithPgSearch.create!(:content => 'bar foo')]
        excluded = ModelWithPgSearch.create!(:content => 'foo')

        results = ModelWithPgSearch.search_content('foo bar')
        results.should =~ included
        results.should_not include(excluded)
      end

      it "returns rows that match the query but not its case" do
        # \303\241 is a with acute accent
        # \303\251 is e with acute accent

        included = [ModelWithPgSearch.create!(:content => "foo"),
                    ModelWithPgSearch.create!(:content => "FOO")]

        results = ModelWithPgSearch.search_content("Foo")
        results.should =~ included
      end

      it "returns rows that match the query only if their accents match" do
        # \303\241 is a with acute accent
        # \303\251 is e with acute accent

        included = ModelWithPgSearch.create!(:content => "abcd\303\251f")
        excluded = ModelWithPgSearch.create!(:content => "\303\241bcdef")

        results = ModelWithPgSearch.search_content("abcd\303\251f")
        results.should == [included]
        results.should_not include(excluded)
      end

      it "returns rows that match the query but not rows that are prefixed by the query" do
        included = ModelWithPgSearch.create!(:content => 'pre')
        excluded = ModelWithPgSearch.create!(:content => 'prefix')

        results = ModelWithPgSearch.search_content("pre")
        results.should == [included]
        results.should_not include(excluded)
      end

      it "returns rows that match the query exactly and not those that match the query when stemmed by the default english dictionary" do
        included = ModelWithPgSearch.create!(:content => "jumped")
        excluded = [ModelWithPgSearch.create!(:content => "jump"),
                    ModelWithPgSearch.create!(:content => "jumping")]

        results = ModelWithPgSearch.search_content("jumped")
        results.should == [included]
      end

      it "returns rows that match sorted by rank" do
        loser = ModelWithPgSearch.create!(:content => 'foo')
        winner = ModelWithPgSearch.create!(:content => 'foo foo')

        results = ModelWithPgSearch.search_content("foo")
        results[0].rank.should > results[1].rank
        results.should == [winner, loser]
      end

      it "returns results that match sorted by primary key for records that rank the same" do
        sorted_results = [ModelWithPgSearch.create!(:content => 'foo'),
                          ModelWithPgSearch.create!(:content => 'foo')].sort_by(&:id)

        results = ModelWithPgSearch.search_content("foo")
        results.should == sorted_results
      end

      it "returns results that match a query with multiple space-separated search terms" do
        included = [
          ModelWithPgSearch.create!(:content => 'foo bar'),
          ModelWithPgSearch.create!(:content => 'bar foo'),
          ModelWithPgSearch.create!(:content => 'bar foo baz'),
        ]
        excluded = [
          ModelWithPgSearch.create!(:content => 'foo'),
          ModelWithPgSearch.create!(:content => 'foo baz')
        ]

        results = ModelWithPgSearch.search_content('foo bar')
        results.should =~ included
        results.should_not include(excluded)
      end

      it "returns rows that match a query with characters that are invalid in a tsquery expression" do
        included = ModelWithPgSearch.create!(:content => "(:Foo.) Bar?, \\")

        results = ModelWithPgSearch.search_content("foo :bar .,?() \\")
        results.should == [included]
      end

      it "accepts non-string queries and calls #to_s on them" do
        foo = ModelWithPgSearch.create!(:content => "foo")
        not_a_string = stub(:to_s => "foo")
        ModelWithPgSearch.search_content(not_a_string).should == [foo]
      end
    end

    context "against multiple columns" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :search_title_and_content, :against => [:title, :content]
        end
      end

      it "returns rows whose columns contain all of the terms in the query across columns" do
        included = [
          ModelWithPgSearch.create!(:title => 'foo', :content => 'bar'),
          ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
        ]
        excluded = [
          ModelWithPgSearch.create!(:title => 'foo', :content => 'foo'),
          ModelWithPgSearch.create!(:title => 'bar', :content => 'bar')
        ]

        results = ModelWithPgSearch.search_title_and_content('foo bar')

        results.should =~ included
        excluded.each do |result|
          results.should_not include(result)
        end
      end

      it "returns rows where at one column contains all of the terms in the query and another does not" do
        in_title = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')
        in_content = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')

        results  = ModelWithPgSearch.search_title_and_content('foo')
        results.should =~ [in_title, in_content]
      end

      # Searching with a NULL column will prevent any matches unless we coalesce it.
      it "returns rows where at one column contains all of the terms in the query and another is NULL" do
        included = ModelWithPgSearch.create!(:title => 'foo', :content => nil)
        results  = ModelWithPgSearch.search_title_and_content('foo')
        results.should == [included]
      end
    end

    context "using trigram" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :with_trigrams, :against => [:title, :content], :using => :trigram
        end
      end

      it "returns rows where one searchable column and the query share enough trigrams" do
        included = ModelWithPgSearch.create!(:title => 'abcdefghijkl', :content => nil)
        results = ModelWithPgSearch.with_trigrams('cdefhijkl')
        results.should == [included]
      end

      it "returns rows where multiple searchable columns and the query share enough trigrams" do
        included = ModelWithPgSearch.create!(:title => 'abcdef', :content => 'ghijkl')
        results = ModelWithPgSearch.with_trigrams('cdefhijkl')
        results.should == [included]
      end
    end

    context "using tsearch" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :search_title_with_prefixes,
                          :against => :title,
                          :using => {
                            :tsearch => {:prefix => true}
                          }
        end
      end

      if ActiveRecord::Base.connection.send(:postgresql_version) < 80400
        it "is unsupported in PostgreSQL 8.3 and earlier" do
          lambda do
            ModelWithPgSearch.search_title_with_prefixes("abcd\303\251f")
          end.should raise_exception(PgSearch::NotSupportedForPostgresqlVersion)
        end
      else
        context "with :prefix => true" do
          it "returns rows that match the query and that are prefixed by the query" do
            included = ModelWithPgSearch.create!(:title => 'prefix')
            excluded = ModelWithPgSearch.create!(:title => 'postfix')

            results = ModelWithPgSearch.search_title_with_prefixes("pre")
            results.should == [included]
            results.should_not include(excluded)
          end

          it "returns rows that match the query when the query has a hyphen" do
            included = [
              ModelWithPgSearch.create!(:title => 'foo bar'),
              ModelWithPgSearch.create!(:title => 'foo-bar')
            ]
            excluded = ModelWithPgSearch.create!(:title => 'baz quux')

            results = ModelWithPgSearch.search_title_with_prefixes("foo-bar")
            results.should =~ included
            results.should_not include(excluded)
          end
        end
      end

      context "with the english dictionary" do
        before do
          ModelWithPgSearch.class_eval do
            pg_search_scope :search_content_with_english,
                            :against => :content,
                            :using => {
                              :tsearch => {:dictionary => :english}
                            }
          end
        end

        it "returns rows that match the query when stemmed by the english dictionary" do
          included = [ModelWithPgSearch.create!(:content => "jump"),
                      ModelWithPgSearch.create!(:content => "jumped"),
                      ModelWithPgSearch.create!(:content => "jumping")]

          results = ModelWithPgSearch.search_content_with_english("jump")
          results.should =~ included
        end
      end

      describe "ranking" do
        before do
          ["Strip Down", "Down", "Down and Out", "Won't Let You Down"].each do |name|
            ModelWithPgSearch.create! :content => name
          end
        end

        context "with a normalization specified" do
          before do
            ModelWithPgSearch.class_eval do
              pg_search_scope :search_content_with_normalization,
                              :against => :content,
                              :using => {
                                :tsearch => {:normalization => 2}
                              }
            end
          end
          it "ranks the results for documents with less text higher" do
            results = ModelWithPgSearch.search_content_with_normalization("down")

            results.map(&:content).should == ["Down", "Strip Down", "Down and Out", "Won't Let You Down"]
            results.first.rank.should be > results.last.rank
          end
        end

        context "with no normalization" do
          before do
            ModelWithPgSearch.class_eval do
              pg_search_scope :search_content_without_normalization,
                              :against => :content,
                              :using => :tsearch
            end
          end
          it "ranks the results equally" do
            results = ModelWithPgSearch.search_content_without_normalization("down")

            results.map(&:content).should == ["Strip Down", "Down", "Down and Out", "Won't Let You Down"]
            results.first.rank.should == results.last.rank
          end
        end
      end

      context "against columns ranked with arrays" do
        before do
          ModelWithPgSearch.class_eval do
             pg_search_scope :search_weighted_by_array_of_arrays, :against => [[:content, 'B'], [:title, 'A']]
           end
        end

        it "returns results sorted by weighted rank" do
          loser = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
          winner = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')

          results = ModelWithPgSearch.search_weighted_by_array_of_arrays('foo')
          results[0].rank.should > results[1].rank
          results.should == [winner, loser]
        end
      end

      context "against columns ranked with a hash" do
        before do
          ModelWithPgSearch.class_eval do
            pg_search_scope :search_weighted_by_hash, :against => {:content => 'B', :title => 'A'}
          end
        end

        it "returns results sorted by weighted rank" do
          loser = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
          winner = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')

          results = ModelWithPgSearch.search_weighted_by_hash('foo')
          results[0].rank.should > results[1].rank
          results.should == [winner, loser]
        end
      end

      context "against columns of which only some are ranked" do
        before do
          ModelWithPgSearch.class_eval do
            pg_search_scope :search_weighted, :against => [:content, [:title, 'A']]
          end
        end

        it "returns results sorted by weighted rank using an implied low rank for unranked columns" do
          loser = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
          winner = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')

          results = ModelWithPgSearch.search_weighted('foo')
          results[0].rank.should > results[1].rank
          results.should == [winner, loser]
        end
      end

      context "searching any_word option" do
        before do
          ModelWithPgSearch.class_eval do
            pg_search_scope :search_title_with_any_word,
                            :against => :title,
                            :using => {
                              :tsearch => {:any_word => true}
                            }

            pg_search_scope :search_title_with_all_words,
                            :against => :title
          end
        end

        it "returns all results containing any word in their title" do
          numbers = %w(one two three four).map{|number| ModelWithPgSearch.create!(:title => number)}

          results = ModelWithPgSearch.search_title_with_any_word("one two three four")

          results.map(&:title).should == %w(one two three four)

          results = ModelWithPgSearch.search_title_with_all_words("one two three four")

          results.map(&:title).should == []
        end
      end
    end

    context "using dmetaphone" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :with_dmetaphones, :against => [:title, :content], :using => :dmetaphone
        end
      end

      it "returns rows where one searchable column and the query share enough dmetaphones" do
        included = ModelWithPgSearch.create!(:title => 'Geoff', :content => nil)
        excluded = ModelWithPgSearch.create!(:title => 'Bob', :content => nil)
        results = ModelWithPgSearch.with_dmetaphones('Jeff')
        results.should == [included]
      end

      it "returns rows where multiple searchable columns and the query share enough dmetaphones" do
        included = ModelWithPgSearch.create!(:title => 'Geoff', :content => 'George')
        excluded = ModelWithPgSearch.create!(:title => 'Bob', :content => 'Jones')
        results = ModelWithPgSearch.with_dmetaphones('Jeff Jorge')
        results.should == [included]
      end

      it "returns rows that match dmetaphones that are English stopwords" do
        included = ModelWithPgSearch.create!(:title => 'White', :content => nil)
        excluded = ModelWithPgSearch.create!(:title => 'Black', :content => nil)
        results = ModelWithPgSearch.with_dmetaphones('Wight')
        results.should == [included]
      end

      it "can handle terms that do not have a dmetaphone equivalent" do
        term_with_blank_metaphone = "w"

        included = ModelWithPgSearch.create!(:title => 'White', :content => nil)
        excluded = ModelWithPgSearch.create!(:title => 'Black', :content => nil)

        results = ModelWithPgSearch.with_dmetaphones('Wight W')
        results.should == [included]
      end
    end

    context "using multiple features" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :with_tsearch,
                          :against => :title,
                          :using => [
                            [:tsearch, {:dictionary => 'english'}]
                          ]

          pg_search_scope :with_trigram, :against => :title, :using => :trigram

          pg_search_scope :with_tsearch_and_trigram_using_array,
                          :against => :title,
                          :using => [
                            [:tsearch, {:dictionary => 'english'}],
                            :trigram
                          ]

        end
      end

      it "returns rows that match using any of the features" do
        record = ModelWithPgSearch.create!(:title => "tiling is grouty")

        # matches trigram only
        trigram_query = "ling is grouty"
        ModelWithPgSearch.with_trigram(trigram_query).should include(record)
        ModelWithPgSearch.with_tsearch(trigram_query).should_not include(record)
        ModelWithPgSearch.with_tsearch_and_trigram_using_array(trigram_query).should == [record]

        # matches tsearch only
        tsearch_query = "tiles"
        ModelWithPgSearch.with_tsearch(tsearch_query).should include(record)
        ModelWithPgSearch.with_trigram(tsearch_query).should_not include(record)
        ModelWithPgSearch.with_tsearch_and_trigram_using_array(tsearch_query).should == [record]
      end

      context "with feature-specific configuration" do
        before do
          @tsearch_config = tsearch_config = {:dictionary => 'english'}
          @trigram_config = trigram_config = {:foo => 'bar'}

          ModelWithPgSearch.class_eval do
            pg_search_scope :with_tsearch_and_trigram_using_hash,
                            :against => :title,
                            :using => {
                              :tsearch => tsearch_config,
                              :trigram => trigram_config
                            }
          end
        end

        it "should pass the custom configuration down to the specified feature" do
          stub_feature = stub(:conditions => "1 = 1", :rank => "1.0")
          PgSearch::Features::TSearch.should_receive(:new).with(anything, @tsearch_config, anything, anything, anything).at_least(:once).and_return(stub_feature)
          PgSearch::Features::Trigram.should_receive(:new).with(anything, @trigram_config, anything, anything, anything).at_least(:once).and_return(stub_feature)

          ModelWithPgSearch.with_tsearch_and_trigram_using_hash("foo")
        end
      end
    end

    context "ignoring accents" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :search_title_without_accents, :against => :title, :ignoring => :accents
        end
      end

      if ActiveRecord::Base.connection.send(:postgresql_version) < 90000
        it "is unsupported in PostgreSQL 8.x" do
          lambda do
            ModelWithPgSearch.search_title_without_accents("abcd\303\251f")
          end.should raise_exception(PgSearch::NotSupportedForPostgresqlVersion)
        end
      else
        it "returns rows that match the query but not its accents" do
          # \303\241 is a with acute accent
          # \303\251 is e with acute accent

          included = ModelWithPgSearch.create!(:title => "\303\241bcdef")

          results = ModelWithPgSearch.search_title_without_accents("abcd\303\251f")
          results.should == [included]
        end
      end
    end

    context "when passed a :ranked_by expression" do
      before do
        ModelWithPgSearch.class_eval do
          pg_search_scope :search_content_with_default_rank,
                          :against => :content
          pg_search_scope :search_content_with_importance_as_rank,
                          :against => :content,
                          :ranked_by => "importance"
          pg_search_scope :search_content_with_importance_as_rank_multiplier,
                          :against => :content,
                          :ranked_by => ":tsearch * importance"
        end
      end

      it "should return records with a rank attribute equal to the :ranked_by expression" do
        ModelWithPgSearch.create!(:content => 'foo', :importance => 10)
        results = ModelWithPgSearch.search_content_with_importance_as_rank("foo")
        results.first.rank.should == 10
      end

      it "should substitute :tsearch with the tsearch rank expression in the :ranked_by expression" do
        ModelWithPgSearch.create!(:content => 'foo', :importance => 10)

        tsearch_rank = ModelWithPgSearch.search_content_with_default_rank("foo").first.rank
        multiplied_rank = ModelWithPgSearch.search_content_with_importance_as_rank_multiplier("foo").first.rank

        multiplied_rank.should be_within(0.001).of(tsearch_rank * 10)
      end

      it "should return results in descending order of the value of the rank expression" do
        records = [
          ModelWithPgSearch.create!(:content => 'foo', :importance => 1),
          ModelWithPgSearch.create!(:content => 'foo', :importance => 3),
          ModelWithPgSearch.create!(:content => 'foo', :importance => 2)
        ]

        results = ModelWithPgSearch.search_content_with_importance_as_rank("foo")
        results.should == records.sort_by(&:importance).reverse
      end

      %w[tsearch trigram dmetaphone].each do |feature|

        context "using the #{feature} ranking algorithm" do
          before do
            @scope_name = scope_name = :"search_content_ranked_by_#{feature}"
            ModelWithPgSearch.class_eval do
              pg_search_scope scope_name,
                              :against => :content,
                              :ranked_by => ":#{feature}"
            end
          end

          it "should return results with a rank" do
            ModelWithPgSearch.create!(:content => 'foo')

            results = ModelWithPgSearch.send(@scope_name, 'foo')
            results.first.rank.should_not be_nil
          end
        end
      end
    end
  end

  describe ".multisearchable" do
    it "should include the Multisearchable module" do
      ModelWithPgSearch.should_receive(:include).with(PgSearch::Multisearchable)
      ModelWithPgSearch.multisearchable
    end

    it "should set pg_search_multisearchable_options on the class" do
      options = double(:options)
      ModelWithPgSearch.multisearchable(options)
      ModelWithPgSearch.pg_search_multisearchable_options.should == options
    end
  end

  describe ".multisearch" do
    subject { PgSearch.multisearch(query) }
    let(:query) { double(:query) }
    let(:relation) { double(:relation) }
    before do
      PgSearch::Document.should_receive(:search).with(query).and_return(relation)
    end

    it { should == relation }
  end

  describe ".disable_multisearch" do
    it "should temporarily disable multisearch" do
      @multisearch_enabled_before = PgSearch.multisearch_enabled?
      PgSearch.disable_multisearch do
        @multisearch_enabled_inside = PgSearch.multisearch_enabled?
      end
      @multisearch_enabled_after = PgSearch.multisearch_enabled?

      @multisearch_enabled_before.should be(true)
      @multisearch_enabled_inside.should be(false)
      @multisearch_enabled_after.should be(true)
    end

    it "should reenable multisearch after an error" do
      @multisearch_enabled_before = PgSearch.multisearch_enabled?
      begin
        PgSearch.disable_multisearch do
          @multisearch_enabled_inside = PgSearch.multisearch_enabled?
          raise
        end
      rescue
      end

      @multisearch_enabled_after = PgSearch.multisearch_enabled?

      @multisearch_enabled_before.should be(true)
      @multisearch_enabled_inside.should be(false)
      @multisearch_enabled_after.should be(true)
    end

    it "should not disable multisearch on other threads" do
      values = Queue.new
      sync = Queue.new
      Thread.new do
        values.push PgSearch.multisearch_enabled?
        sync.pop # wait
        values.push PgSearch.multisearch_enabled?
        sync.pop # wait
        values.push PgSearch.multisearch_enabled?
      end

      @multisearch_enabled_before = values.pop
      PgSearch.disable_multisearch do
        sync.push :go
        @multisearch_enabled_inside = values.pop
      end
      sync.push :go
      @multisearch_enabled_after = values.pop

      @multisearch_enabled_before.should be(true)
      @multisearch_enabled_inside.should be(true)
      @multisearch_enabled_after.should be(true)
    end
  end
end
