require "spec_helper"

describe "an Active Record model which includes PgSearch" do
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
    it "builds a chainable scope" do
      ModelWithPgSearch.pg_search_scope "matching_query", :against => []
      scope = ModelWithPgSearch.where("1 = 1").matching_query("foo").where("1 = 1")
      expect(scope).to be_an ActiveRecord::Relation
    end

    context "when passed a lambda" do
      it "builds a dynamic scope" do
        ModelWithPgSearch.pg_search_scope :search_title_or_content,
          lambda { |query, pick_content|
            {
              :query => query.gsub("-remove-", ""),
              :against => pick_content ? :content : :title
            }
          }

        included = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')
        excluded = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')

        expect(ModelWithPgSearch.search_title_or_content('fo-remove-o', false)).to eq([included])
        expect(ModelWithPgSearch.search_title_or_content('b-remove-ar', true)).to eq([included])
      end
    end

    context "when an unknown option is passed in" do
      it "raises an exception when invoked" do
        scope_object = PgSearch::ScopeBuilder.new(ModelWithPgSearch, :with_unknown_option, :against => :content, :foo => :bar)
        allow(scope_object).to receive(:define_tsvector_rebuilders!)
        scope_object.define!

        expect {
          ModelWithPgSearch.with_unknown_option("foo")
        }.to raise_error(ArgumentError, /foo/)
      end

      context "dynamically" do
        it "raises an exception when invoked" do
          ModelWithPgSearch.pg_search_scope :with_unknown_option,
            lambda { |*| {:against => :content, :foo => :bar} }

          expect {
            ModelWithPgSearch.with_unknown_option("foo")
          }.to raise_error(ArgumentError, /foo/)
        end
      end
    end

    context "when an unknown :using is passed" do
      it "raises an exception when invoked" do
        scope_object = PgSearch::ScopeBuilder.new(ModelWithPgSearch, :with_unknown_using, :against => :content, :using => :foo)
        allow(scope_object).to receive(:define_tsvector_rebuilders!)
        scope_object.define!

        expect {
          ModelWithPgSearch.with_unknown_using("foo")
        }.to raise_error(ArgumentError, /foo/)
      end

      context "dynamically" do
        it "raises an exception when invoked" do
          ModelWithPgSearch.pg_search_scope :with_unknown_using,
            lambda { |*| {:against => :content, :using => :foo} }

          expect {
            ModelWithPgSearch.with_unknown_using("foo")
          }.to raise_error(ArgumentError, /foo/)
        end
      end
    end

    context "when an unknown :ignoring is passed" do
      it "raises an exception when invoked" do
        scope_object = PgSearch::ScopeBuilder.new(ModelWithPgSearch, :with_unknown_ignoring, :against => :content, :ignoring => :foo)
        allow(scope_object).to receive(:define_tsvector_rebuilders!)
        scope_object.define!

        expect {
          ModelWithPgSearch.with_unknown_ignoring("foo")
        }.to raise_error(ArgumentError, /ignoring.*foo/)
      end

      context "dynamically" do
        it "raises an exception when invoked" do
          ModelWithPgSearch.pg_search_scope :with_unknown_ignoring,
            lambda { |*| {:against => :content, :ignoring => :foo} }

          expect {
            ModelWithPgSearch.with_unknown_ignoring("foo")
          }.to raise_error(ArgumentError, /ignoring.*foo/)
        end
      end

      context "when :against is not passed in" do
        it "raises an exception when invoked" do
          scope_object = PgSearch::ScopeBuilder.new(ModelWithPgSearch, :with_unknown_ignoring, {})
          allow(scope_object).to receive(:define_tsvector_rebuilders!)
          scope_object.define!

          expect {
            ModelWithPgSearch.with_unknown_ignoring("foo")
          }.to raise_error(ArgumentError, /against/)
        end

        context "dynamically" do
          it "raises an exception when invoked" do
            ModelWithPgSearch.pg_search_scope :with_unknown_ignoring,
              lambda { |*| {} }

            expect {
              ModelWithPgSearch.with_unknown_ignoring("foo")
            }.to raise_error(ArgumentError, /against/)
          end
        end
      end
    end
  end

  describe "a search scope" do
    context "against a single column" do
      before do
        ModelWithPgSearch.pg_search_scope :search_content, :against => :content
      end

      it "returns an empty array when a blank query is passed in" do
        ModelWithPgSearch.create!(:content => 'foo')

        results = ModelWithPgSearch.search_content('')
        expect(results).to eq([])
      end

      it "returns rows where the column contains the term in the query" do
        included = ModelWithPgSearch.create!(:content => 'foo')
        excluded = ModelWithPgSearch.create!(:content => 'bar')

        results = ModelWithPgSearch.search_content('foo')
        expect(results).to include(included)
        expect(results).not_to include(excluded)
      end

      it "returns the correct count" do
        ModelWithPgSearch.create!(:content => 'foo')
        ModelWithPgSearch.create!(:content => 'bar')

        results = ModelWithPgSearch.search_content('foo')
        expect(results.count(:all)).to eq 1
      end

      it "returns rows where the column contains all the terms in the query in any order" do
        included = [ModelWithPgSearch.create!(:content => 'foo bar'),
                    ModelWithPgSearch.create!(:content => 'bar foo')]
        excluded = ModelWithPgSearch.create!(:content => 'foo')

        results = ModelWithPgSearch.search_content('foo bar')
        expect(results).to match_array(included)
        expect(results).not_to include(excluded)
      end

      it "returns rows that match the query but not its case" do
        included = [ModelWithPgSearch.create!(:content => "foo"),
                    ModelWithPgSearch.create!(:content => "FOO")]

        results = ModelWithPgSearch.search_content("Foo")
        expect(results).to match_array(included)
      end

      it "returns rows that match the query only if their accents match" do
        # \303\241 is a with acute accent
        # \303\251 is e with acute accent

        included = ModelWithPgSearch.create!(:content => "abcd\303\251f")
        excluded = ModelWithPgSearch.create!(:content => "\303\241bcdef")

        results = ModelWithPgSearch.search_content("abcd\303\251f")
        expect(results).to eq([included])
        expect(results).not_to include(excluded)
      end

      it "returns rows that match the query but not rows that are prefixed by the query" do
        included = ModelWithPgSearch.create!(:content => 'pre')
        excluded = ModelWithPgSearch.create!(:content => 'prefix')

        results = ModelWithPgSearch.search_content("pre")
        expect(results).to eq([included])
        expect(results).not_to include(excluded)
      end

      it "returns rows that match the query exactly and not those that match the query when stemmed by the default english dictionary" do
        included = ModelWithPgSearch.create!(:content => "jumped")
        excluded = [ModelWithPgSearch.create!(:content => "jump"),
                    ModelWithPgSearch.create!(:content => "jumping")]

        results = ModelWithPgSearch.search_content("jumped")
        expect(results).to eq([included])
      end

      it "returns rows that match sorted by rank" do
        loser = ModelWithPgSearch.create!(:content => 'foo')
        winner = ModelWithPgSearch.create!(:content => 'foo foo')

        results = ModelWithPgSearch.search_content("foo")
        expect(results[0].pg_search_rank).to be > results[1].pg_search_rank
        expect(results).to eq([winner, loser])
      end

      it "returns results that match sorted by primary key for records that rank the same" do
        sorted_results = [ModelWithPgSearch.create!(:content => 'foo'),
                          ModelWithPgSearch.create!(:content => 'foo')].sort_by(&:id)

        results = ModelWithPgSearch.search_content("foo")
        expect(results).to eq(sorted_results)
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
        expect(results).to match_array(included)
        expect(results).not_to include(excluded)
      end

      it "returns rows that match a query with characters that are invalid in a tsquery expression" do
        included = ModelWithPgSearch.create!(:content => "(:Foo.) Bar?, \\")

        results = ModelWithPgSearch.search_content("foo :bar .,?() \\")
        expect(results).to eq([included])
      end

      it "accepts non-string queries and calls #to_s on them" do
        foo = ModelWithPgSearch.create!(:content => "foo")
        not_a_string = double(:to_s => "foo")
        expect(ModelWithPgSearch.search_content(not_a_string)).to eq([foo])
      end

      context "when the column is not text" do
        with_model :ModelWithTimestamps do
          table do |t|
            t.timestamps null: false
          end

          model do
            include PgSearch

            # WARNING: searching timestamps is not something PostgreSQL
            # full-text search is good at. Use at your own risk.
            pg_search_scope :search_timestamps,
              :against => [:created_at, :updated_at]
          end
        end

        it "casts the column to text" do
          record = ModelWithTimestamps.create!

          query = record.created_at.strftime("%Y-%m-%d")
          results = ModelWithTimestamps.search_timestamps(query)
          expect(results).to eq([record])
        end
      end
    end

    context "against multiple columns" do
      before do
        ModelWithPgSearch.pg_search_scope :search_title_and_content, :against => [:title, :content]
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

        expect(results).to match_array(included)
        excluded.each do |result|
          expect(results).not_to include(result)
        end
      end

      it "returns rows where at one column contains all of the terms in the query and another does not" do
        in_title = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')
        in_content = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')

        results  = ModelWithPgSearch.search_title_and_content('foo')
        expect(results).to match_array([in_title, in_content])
      end

      # Searching with a NULL column will prevent any matches unless we coalesce it.
      it "returns rows where at one column contains all of the terms in the query and another is NULL" do
        included = ModelWithPgSearch.create!(:title => 'foo', :content => nil)
        results  = ModelWithPgSearch.search_title_and_content('foo')
        expect(results).to eq([included])
      end
    end

    context "using trigram" do
      before do
        ModelWithPgSearch.pg_search_scope :with_trigrams, :against => [:title, :content], :using => :trigram
      end

      it "returns rows where one searchable column and the query share enough trigrams" do
        included = ModelWithPgSearch.create!(:title => 'abcdefghijkl', :content => nil)
        results = ModelWithPgSearch.with_trigrams('cdefhijkl')
        expect(results).to eq([included])
      end

      it "returns rows where multiple searchable columns and the query share enough trigrams" do
        included = ModelWithPgSearch.create!(:title => 'abcdef', :content => 'ghijkl')
        results = ModelWithPgSearch.with_trigrams('cdefhijkl')
        expect(results).to eq([included])
      end

      context "when a threshold is specified" do
        before do
          ModelWithPgSearch.pg_search_scope :with_strict_trigrams, :against => [:title, :content], :using => {trigram: {threshold: 0.5}}
          ModelWithPgSearch.pg_search_scope :with_permissive_trigrams, :against => [:title, :content], :using => {trigram: {threshold: 0.1}}
        end

        it "uses the threshold in the trigram expression" do
          low_similarity = ModelWithPgSearch.create!(:title => "a")
          medium_similarity = ModelWithPgSearch.create!(:title => "abc")
          high_similarity = ModelWithPgSearch.create!(:title => "abcdefghijkl")

          results = ModelWithPgSearch.with_strict_trigrams("abcdefg")
          expect(results).to include(high_similarity)
          expect(results).not_to include(medium_similarity, low_similarity)

          results = ModelWithPgSearch.with_trigrams("abcdefg")
          expect(results).to include(high_similarity, medium_similarity)
          expect(results).not_to include(low_similarity)

          results = ModelWithPgSearch.with_permissive_trigrams("abcdefg")
          expect(results).to include(high_similarity, medium_similarity, low_similarity)
        end
      end
    end

    context "using tsearch" do
      before do
        ModelWithPgSearch.pg_search_scope :search_title_with_prefixes,
                                          :against => :title,
                                          :using => {
                                            :tsearch => {:prefix => true}
                                          }
      end

      if ActiveRecord::Base.connection.send(:postgresql_version) < 80400
        it "is unsupported in PostgreSQL 8.3 and earlier" do
          expect {
            ModelWithPgSearch.search_title_with_prefixes("abcd\303\251f")
          }.to raise_exception(PgSearch::NotSupportedForPostgresqlVersion)
        end
      else
        context "with :prefix => true" do
          it "returns rows that match the query and that are prefixed by the query" do
            included = ModelWithPgSearch.create!(:title => 'prefix')
            excluded = ModelWithPgSearch.create!(:title => 'postfix')

            results = ModelWithPgSearch.search_title_with_prefixes("pre")
            expect(results).to eq([included])
            expect(results).not_to include(excluded)
          end

          it "returns rows that match the query when the query has a hyphen" do
            included = ModelWithPgSearch.create!(:title => 'foo-bar')
            excluded = ModelWithPgSearch.create!(:title => 'foo bar')

            results = ModelWithPgSearch.search_title_with_prefixes("foo-bar")
            expect(results).to include(included)
            expect(results).not_to include(excluded)
          end
        end
      end

      context "with the english dictionary" do
        before do
          ModelWithPgSearch.pg_search_scope :search_content_with_english,
            :against => :content,
            :using => {
              :tsearch => {:dictionary => :english}
            }
        end

        it "returns rows that match the query when stemmed by the english dictionary" do
          included = [ModelWithPgSearch.create!(:content => "jump"),
                      ModelWithPgSearch.create!(:content => "jumped"),
                      ModelWithPgSearch.create!(:content => "jumping")]

          results = ModelWithPgSearch.search_content_with_english("jump")
          expect(results).to match_array(included)
        end
      end

      describe "ranking" do
        before do
          ["Strip Down", "Down", "Down and Out", "Won't Let You Down"].each do |name|
            ModelWithPgSearch.create! :content => name
          end
        end

        it "adds a #pg_search_rank method to each returned model record" do
          ModelWithPgSearch.pg_search_scope :search_content, :against => :content

          result = ModelWithPgSearch.search_content("Strip Down").first

          expect(result.pg_search_rank).to be_a(Float)
        end

        context "with a normalization specified" do
          before do
            ModelWithPgSearch.pg_search_scope :search_content_with_normalization,
              :against => :content,
              :using => {
                :tsearch => {:normalization => 2}
              }
          end

          it "ranks the results for documents with less text higher" do
            results = ModelWithPgSearch.search_content_with_normalization("down")

            expect(results.map(&:content)).to eq(["Down", "Strip Down", "Down and Out", "Won't Let You Down"])
            expect(results.first.pg_search_rank).to be > results.last.pg_search_rank
          end
        end

        context "with no normalization" do
          before do
            ModelWithPgSearch.pg_search_scope :search_content_without_normalization,
              :against => :content,
              :using => :tsearch
          end

          it "ranks the results equally" do
            results = ModelWithPgSearch.search_content_without_normalization("down")

            expect(results.map(&:content)).to eq(["Strip Down", "Down", "Down and Out", "Won't Let You Down"])
            expect(results.first.pg_search_rank).to eq(results.last.pg_search_rank)
          end
        end
      end

      context "against columns ranked with arrays" do
        before do
          ModelWithPgSearch.pg_search_scope :search_weighted_by_array_of_arrays,
            :against => [[:content, 'B'], [:title, 'A']]
        end

        it "returns results sorted by weighted rank" do
          loser = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
          winner = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')

          results = ModelWithPgSearch.search_weighted_by_array_of_arrays('foo')
          expect(results[0].pg_search_rank).to be > results[1].pg_search_rank
          expect(results).to eq([winner, loser])
        end
      end

      context "against columns ranked with a hash" do
        before do
          ModelWithPgSearch.pg_search_scope :search_weighted_by_hash,
            :against => {:content => 'B', :title => 'A'}
        end

        it "returns results sorted by weighted rank" do
          loser = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
          winner = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')

          results = ModelWithPgSearch.search_weighted_by_hash('foo')
          expect(results[0].pg_search_rank).to be > results[1].pg_search_rank
          expect(results).to eq([winner, loser])
        end
      end

      context "against columns of which only some are ranked" do
        before do
          ModelWithPgSearch.pg_search_scope :search_weighted,
            :against => [:content, [:title, 'A']]
        end

        it "returns results sorted by weighted rank using an implied low rank for unranked columns" do
          loser = ModelWithPgSearch.create!(:title => 'bar', :content => 'foo')
          winner = ModelWithPgSearch.create!(:title => 'foo', :content => 'bar')

          results = ModelWithPgSearch.search_weighted('foo')
          expect(results[0].pg_search_rank).to be > results[1].pg_search_rank
          expect(results).to eq([winner, loser])
        end
      end

      context "searching any_word option" do
        before do
          ModelWithPgSearch.pg_search_scope :search_title_with_any_word,
            :against => :title,
            :using => {
              :tsearch => {:any_word => true}
            }

            ModelWithPgSearch.pg_search_scope :search_title_with_all_words,
              :against => :title
        end

        it "returns all results containing any word in their title" do
          numbers = %w(one two three four).map{|number| ModelWithPgSearch.create!(:title => number)}

          results = ModelWithPgSearch.search_title_with_any_word("one two three four")

          expect(results.map(&:title)).to eq(%w(one two three four))

          results = ModelWithPgSearch.search_title_with_all_words("one two three four")

          expect(results.map(&:title)).to eq([])
        end
      end

      context "with :negation" do
        before do
          ModelWithPgSearch.pg_search_scope :search_with_negation,
            :against => :title,
            :using => {
              :tsearch => {:negation => true}
            }
        end

        it "doesn't return results that contain terms prepended with '!'" do
          included = [
            ModelWithPgSearch.create!(:title => "one fish"),
            ModelWithPgSearch.create!(:title => "two fish")
          ]

          excluded = [
            ModelWithPgSearch.create!(:title => "red fish"),
            ModelWithPgSearch.create!(:title => "blue fish")
          ]

          results = ModelWithPgSearch.search_with_negation("fish !red !blue")

          expect(results).to include(*included)
          expect(results).not_to include(*excluded)
        end
      end

      context "without :negation" do
        before do
          ModelWithPgSearch.pg_search_scope :search_without_negation,
            :against => :title,
            :using => {
              :tsearch => {}
            }
        end

        it "return results that contain terms prepended with '!'" do
          included = [
            ModelWithPgSearch.create!(:title => "!bang")
          ]

          excluded = [
            ModelWithPgSearch.create!(:title => "?question")
          ]

          results = ModelWithPgSearch.search_without_negation("!bang")

          expect(results).to include(*included)
          expect(results).not_to include(*excluded)
        end
      end
    end

    context "using dmetaphone" do
      before do
        ModelWithPgSearch.pg_search_scope :with_dmetaphones,
          :against => [:title, :content],
          :using => :dmetaphone
      end

      it "returns rows where one searchable column and the query share enough dmetaphones" do
        included = ModelWithPgSearch.create!(:title => 'Geoff', :content => nil)
        excluded = ModelWithPgSearch.create!(:title => 'Bob', :content => nil)
        results = ModelWithPgSearch.with_dmetaphones('Jeff')
        expect(results).to eq([included])
      end

      it "returns rows where multiple searchable columns and the query share enough dmetaphones" do
        included = ModelWithPgSearch.create!(:title => 'Geoff', :content => 'George')
        excluded = ModelWithPgSearch.create!(:title => 'Bob', :content => 'Jones')
        results = ModelWithPgSearch.with_dmetaphones('Jeff Jorge')
        expect(results).to eq([included])
      end

      it "returns rows that match dmetaphones that are English stopwords" do
        included = ModelWithPgSearch.create!(:title => 'White', :content => nil)
        excluded = ModelWithPgSearch.create!(:title => 'Black', :content => nil)
        results = ModelWithPgSearch.with_dmetaphones('Wight')
        expect(results).to eq([included])
      end

      it "can handle terms that do not have a dmetaphone equivalent" do
        term_with_blank_metaphone = "w"

        included = ModelWithPgSearch.create!(:title => 'White', :content => nil)
        excluded = ModelWithPgSearch.create!(:title => 'Black', :content => nil)

        results = ModelWithPgSearch.with_dmetaphones('Wight W')
        expect(results).to eq([included])
      end
    end

    context "using multiple features" do
      before do
        ModelWithPgSearch.pg_search_scope :with_tsearch,
          :against => :title,
          :using => [
            [:tsearch, {:dictionary => 'english'}]
          ]

        ModelWithPgSearch.pg_search_scope :with_trigram,
          :against => :title,
          :using => :trigram

        ModelWithPgSearch.pg_search_scope :with_trigram_and_ignoring_accents,
          :against => :title,
          :ignoring => :accents,
          :using => :trigram

        ModelWithPgSearch.pg_search_scope :with_tsearch_and_trigram,
          :against => :title,
          :using => [
            [:tsearch, {:dictionary => 'english'}],
            :trigram
          ]

        ModelWithPgSearch.pg_search_scope :complex_search,
          :against => [:content, :title],
          :ignoring => :accents,
          :using => {
            :tsearch => {:dictionary => 'english'},
            :dmetaphone => {},
            :trigram => {}
          }
      end

      it "returns rows that match using any of the features" do
        record = ModelWithPgSearch.create!(:title => "tiling is grouty")

        # matches trigram only
        trigram_query = "ling is grouty"
        expect(ModelWithPgSearch.with_trigram(trigram_query)).to include(record)
        expect(ModelWithPgSearch.with_trigram_and_ignoring_accents(trigram_query)).to include(record)
        expect(ModelWithPgSearch.with_tsearch(trigram_query)).not_to include(record)
        expect(ModelWithPgSearch.with_tsearch_and_trigram(trigram_query)).to eq([record])
        expect(ModelWithPgSearch.complex_search(trigram_query)).to include(record)

        # matches accent
        # \303\266 is o with diaeresis
        # \303\272 is u with acute accent
        accent_query = "gr\303\266\303\272ty"
        expect(ModelWithPgSearch.with_trigram(accent_query)).not_to include(record)
        expect(ModelWithPgSearch.with_trigram_and_ignoring_accents(accent_query)).to include(record)
        expect(ModelWithPgSearch.with_tsearch(accent_query)).not_to include(record)
        expect(ModelWithPgSearch.with_tsearch_and_trigram(accent_query).count(:all)).to eq(0)
        expect(ModelWithPgSearch.complex_search(accent_query)).to include(record)

        # matches tsearch only
        tsearch_query = "tiles"
        expect(ModelWithPgSearch.with_tsearch(tsearch_query)).to include(record)
        expect(ModelWithPgSearch.with_trigram(tsearch_query)).not_to include(record)
        expect(ModelWithPgSearch.with_trigram_and_ignoring_accents(tsearch_query)).not_to include(record)
        expect(ModelWithPgSearch.with_tsearch_and_trigram(tsearch_query)).to eq([record])
        expect(ModelWithPgSearch.complex_search(tsearch_query)).to include(record)

        # matches dmetaphone only
        dmetaphone_query = "tyling"
        expect(ModelWithPgSearch.with_tsearch(dmetaphone_query)).not_to include(record)
        expect(ModelWithPgSearch.with_trigram(dmetaphone_query)).not_to include(record)
        expect(ModelWithPgSearch.with_trigram_and_ignoring_accents(dmetaphone_query)).not_to include(record)
        expect(ModelWithPgSearch.with_tsearch_and_trigram(dmetaphone_query)).not_to include(record)
        expect(ModelWithPgSearch.complex_search(dmetaphone_query)).to include(record)
      end

      context "with feature-specific configuration" do
        before do
          @tsearch_config = tsearch_config = {:dictionary => 'english'}
          @trigram_config = trigram_config = {:foo => 'bar'}

          ModelWithPgSearch.pg_search_scope :with_tsearch_and_trigram_using_hash,
            :against => :title,
            :using => {
              :tsearch => tsearch_config,
              :trigram => trigram_config
            }
        end

        it "should pass the custom configuration down to the specified feature" do
          stub_feature = double(
            :conditions => Arel::Nodes::Grouping.new(Arel.sql("1 = 1")),
            :rank => Arel::Nodes::Grouping.new(Arel.sql("1.0"))
          )

          expect(PgSearch::Features::TSearch).to receive(:new).with(anything, @tsearch_config, anything, anything, anything).at_least(:once).and_return(stub_feature)
          expect(PgSearch::Features::Trigram).to receive(:new).with(anything, @trigram_config, anything, anything, anything).at_least(:once).and_return(stub_feature)

          ModelWithPgSearch.with_tsearch_and_trigram_using_hash("foo")
        end
      end
    end

    context "using a tsvector column and an association" do
      with_model :Comment do
        table do |t|
          t.integer :post_id
          t.string :body
        end

        model do
          belongs_to :post
        end
      end

      with_model :Post do
        table do |t|
          t.text 'content'
          t.tsvector 'content_tsvector'
        end

        model do
          include PgSearch
          has_many :comments
        end
      end

      let!(:expected) { Post.create!(content: 'phooey') }
      let!(:unexpected) { Post.create!(content: 'longcat is looooooooong') }

      before do
        expected.comments.create(body: 'commentone')
        unexpected.comments.create(body: 'commentwo')

        Post.pg_search_scope :search_by_content_with_tsvector,
          :against => :content,
          :associated_against => { comments: [:body] },
          :using => {
            :tsearch => {
              :tsvector_column => 'content_tsvector',
              :tsvector_rebuilders => true,
              :dictionary => 'english'
            }
          }
        Post.rebuild_all_content_tsvectors
      end

      it "should find by the tsvector column" do
        expect(Post.search_by_content_with_tsvector("phooey").map(&:id)).to eq([expected.id])
      end

      it "should find by the associated record" do
        expect(Post.search_by_content_with_tsvector("commentone").map(&:id)).to eq([expected.id])
      end

      it 'should find by a combination of the two' do
        expect(Post.search_by_content_with_tsvector("phooey commentone").map(&:id)).to eq([expected.id])
      end
    end

    context 'using multiple tsvector columns' do
      with_model :ModelWithTsvector do
        model do
          include PgSearch

          pg_search_scope :search_by_multiple_tsvector_columns,
            :against => ['content', 'message'],
            :using => {
              :tsearch => {
                :tsvector_column => ['content_tsvector', 'message_tsvector'],
                :dictionary => 'english'
              }
            }
        end
      end

      it 'concats tsvector columns' do
        expected = "#{ModelWithTsvector.quoted_table_name}.\"content_tsvector\" || "\
                   "#{ModelWithTsvector.quoted_table_name}.\"message_tsvector\""

        expect(ModelWithTsvector.search_by_multiple_tsvector_columns("something").to_sql).to include(expected)
      end
    end

    context 'using multiple tsvector columns with rebuilders' do
      with_model :ModelWithTsvector do
        model do
          include PgSearch
        end
      end

      it "should raise error" do
        expect {
          ModelWithTsvector.pg_search_scope :search_by_multiple_tsvector_columns,
            :against => ['content', 'message'],
            :using => {
              :tsearch => {
                :tsvector_column => ['content_tsvector', 'message_tsvector'],
                :tsvector_rebuilders => true,
                :dictionary => 'english'
              }
            }
        }.to raise_exception(ArgumentError)
      end
    end

    context "using a tsvector column with" do
      with_model :ModelWithTsvector do
        table do |t|
          t.text 'title'
          t.text 'content'
          t.tsvector 'content_tsvector'
        end

        model { include PgSearch }
      end

      context "without rebuilders" do
        let!(:expected) { ModelWithTsvector.create!(:content => 'tiling is grouty') }
        let!(:unexpected) { ModelWithTsvector.create!(:content => 'longcat is looooooooong') }
        before do
          ActiveRecord::Base.connection.execute <<-SQL.strip_heredoc
            UPDATE #{ModelWithTsvector.quoted_table_name}
            SET content_tsvector = to_tsvector('english'::regconfig, #{ModelWithTsvector.quoted_table_name}."content")
          SQL
        end

        before do
          ModelWithTsvector.pg_search_scope :search_by_content_with_tsvector,
            :against => :content,
            :using => {
              :tsearch => {
                :tsvector_column => 'content_tsvector',
                :dictionary => 'english'
              }
            }
        end

        it "should not use to_tsvector in the query" do
          expect(ModelWithTsvector.search_by_content_with_tsvector("tiles").to_sql).not_to match(/to_tsvector/)
        end

        it "should find the expected result" do
          expect(ModelWithTsvector.search_by_content_with_tsvector("tiles").map(&:id)).to eq([expected.id])
        end

        context "when joining to a table with a column of the same name" do
          with_model :AnotherModel do
            table do |t|
              t.string :content_tsvector # the type of the column doesn't matter
              t.belongs_to :model_with_tsvector
            end
          end

          before do
            ModelWithTsvector.has_many :another_models
          end

          it "should refer to the tsvector column in the query unambiguously" do
            expect {
              ModelWithTsvector.joins(:another_models).search_by_content_with_tsvector("test").to_a
            }.not_to raise_exception
          end
        end
      end

      context "with rebuilders and call_after_save" do
        before do
          ModelWithTsvector.pg_search_scope :search_by_content_with_tsvector,
            :against => :content,
            :using => {
              :tsearch => {
                :tsvector_column => 'content_tsvector',
                :tsvector_rebuilders => {
                  :call_after_save => true
                },
                :dictionary => 'english'
              }
            }
        end

        let!(:expected) { ModelWithTsvector.create!(:content => 'tiling is grouty') }
        let!(:unexpected) { ModelWithTsvector.create!(:content => 'longcat is looooooooong') }

        it "should find the expected result" do
          expect(ModelWithTsvector.search_by_content_with_tsvector("tiles").map(&:id)).to eq([expected.id])
        end

        it "calls rebuild on update" do
          expect(expected).to receive(:rebuild_content_tsvector)
          expected.update_attributes(:content => 'whatever')
        end

        it "doesn't call rebuild when updating other fields" do
          expect(expected).not_to receive(:rebuild_content_tsvector)
          expected.update_attributes(:title => 'just title')
        end
      end
    end

    context "ignoring accents" do
      before do
        ModelWithPgSearch.pg_search_scope :search_title_without_accents,
          :against => :title,
          :ignoring => :accents
      end

      if ActiveRecord::Base.connection.send(:postgresql_version) < 90000
        it "is unsupported in PostgreSQL 8.x" do
          expect {
            ModelWithPgSearch.search_title_without_accents("abcd\303\251f")
          }.to raise_exception(PgSearch::NotSupportedForPostgresqlVersion)
        end
      else
        it "returns rows that match the query but not its accents" do
          # \303\241 is a with acute accent
          # \303\251 is e with acute accent

          included = ModelWithPgSearch.create!(:title => "\303\241bcdef")

          results = ModelWithPgSearch.search_title_without_accents("abcd\303\251f")
          expect(results).to eq([included])
        end
      end
    end

    context "when passed a :ranked_by expression" do
      before do
        ModelWithPgSearch.pg_search_scope :search_content_with_default_rank,
          :against => :content

        ModelWithPgSearch.pg_search_scope :search_content_with_importance_as_rank,
          :against => :content,
          :ranked_by => "importance"

        ModelWithPgSearch.pg_search_scope :search_content_with_importance_as_rank_multiplier,
          :against => :content,
          :ranked_by => ":tsearch * importance"
      end

      it "should return records with a rank attribute equal to the :ranked_by expression" do
        ModelWithPgSearch.create!(:content => 'foo', :importance => 10)
        results = ModelWithPgSearch.search_content_with_importance_as_rank("foo")
        expect(results.first.pg_search_rank).to eq(10)
      end

      it "should substitute :tsearch with the tsearch rank expression in the :ranked_by expression" do
        ModelWithPgSearch.create!(:content => 'foo', :importance => 10)

        tsearch_rank = ModelWithPgSearch.search_content_with_default_rank("foo").first.pg_search_rank
        multiplied_rank = ModelWithPgSearch.search_content_with_importance_as_rank_multiplier("foo").first.pg_search_rank

        expect(multiplied_rank).to be_within(0.001).of(tsearch_rank * 10)
      end

      it "should return results in descending order of the value of the rank expression" do
        records = [
          ModelWithPgSearch.create!(:content => 'foo', :importance => 1),
          ModelWithPgSearch.create!(:content => 'foo', :importance => 3),
          ModelWithPgSearch.create!(:content => 'foo', :importance => 2)
        ]

        results = ModelWithPgSearch.search_content_with_importance_as_rank("foo")
        expect(results).to eq(records.sort_by(&:importance).reverse)
      end

      %w[tsearch trigram dmetaphone].each do |feature|
        context "using the #{feature} ranking algorithm" do
          it "should return results with a rank" do
            scope_name = :"search_content_ranked_by_#{feature}"

            ModelWithPgSearch.pg_search_scope scope_name,
              :against => :content,
              :ranked_by => ":#{feature}"

            ModelWithPgSearch.create!(:content => 'foo')

            results = ModelWithPgSearch.send(scope_name, 'foo')
            expect(results.first.pg_search_rank).to be_a Float
          end
        end
      end

      context "using the tsearch ranking algorithm" do
        it "sorts results by the tsearch rank" do
          ModelWithPgSearch.pg_search_scope :search_content_ranked_by_tsearch,
            :using => :tsearch,
            :against => :content,
            :ranked_by => ":tsearch"


          once = ModelWithPgSearch.create!(:content => 'foo bar')
          twice = ModelWithPgSearch.create!(:content => 'foo foo')

          results = ModelWithPgSearch.search_content_ranked_by_tsearch('foo')
          expect(results.index(twice)).to be < results.index(once)
        end
      end

      context "using the trigram ranking algorithm" do
        it "sorts results by the trigram rank" do
          ModelWithPgSearch.pg_search_scope :search_content_ranked_by_trigram,
            :using => :trigram,
            :against => :content,
            :ranked_by => ":trigram"

          close = ModelWithPgSearch.create!(:content => 'abcdef')
          exact = ModelWithPgSearch.create!(:content => 'abc')

          results = ModelWithPgSearch.search_content_ranked_by_trigram('abc')
          expect(results.index(exact)).to be < results.index(close)
        end
      end

      context "using the dmetaphone ranking algorithm" do
        it "sorts results by the dmetaphone rank" do
          ModelWithPgSearch.pg_search_scope :search_content_ranked_by_dmetaphone,
            :using => :dmetaphone,
            :against => :content,
            :ranked_by => ":dmetaphone"

          once = ModelWithPgSearch.create!(:content => 'Phoo Bar')
          twice = ModelWithPgSearch.create!(:content => 'Phoo Fu')

          results = ModelWithPgSearch.search_content_ranked_by_dmetaphone('foo')
          expect(results.index(twice)).to be < results.index(once)
        end
      end
    end

    context "on an STI subclass" do
      with_model :SuperclassModel do
        table do |t|
          t.text 'content'
          t.string 'type'
        end

        model do
          include PgSearch
        end
      end

      before do
        SuperclassModel.pg_search_scope :search_content, :against => :content

        class SearchableSubclassModel < SuperclassModel
        end

        class AnotherSearchableSubclassModel < SuperclassModel
        end
      end

      it "returns only results for that subclass" do
        included = [
          SearchableSubclassModel.create!(:content => "foo bar")
        ]
        excluded = [
          SearchableSubclassModel.create!(:content => "baz"),
          SuperclassModel.create!(:content => "foo bar"),
          SuperclassModel.create!(:content => "baz"),
          AnotherSearchableSubclassModel.create!(:content => "foo bar"),
          AnotherSearchableSubclassModel.create!(:content => "baz")
        ]

        expect(SuperclassModel.count).to eq(6)
        expect(SearchableSubclassModel.count).to eq(2)

        results = SearchableSubclassModel.search_content("foo bar")

        expect(results).to include(*included)
        expect(results).not_to include(*excluded)
      end
    end

    context "when there is a sort only feature" do
      it "excludes that feature from the conditions, but uses it in the sorting" do
        ModelWithPgSearch.pg_search_scope :search_content_ranked_by_dmetaphone,
          :against => :content,
          :using => {
            :tsearch => { :any_word => true, :prefix => true },
            :dmetaphone => { :any_word => true, :prefix => true, :sort_only => true }
          },
          :ranked_by => ":tsearch + (0.5 * :dmetaphone)"

        exact = ModelWithPgSearch.create!(:content => "ash hines")
        one_exact_one_close = ModelWithPgSearch.create!(:content => "ash heinz")
        one_exact = ModelWithPgSearch.create!(:content => "ash smith")
        one_close = ModelWithPgSearch.create!(:content => "leigh heinz")

        results = ModelWithPgSearch.search_content_ranked_by_dmetaphone("ash hines")
        expect(results).to eq [exact, one_exact_one_close, one_exact]
      end
    end
  end

  describe ".multisearchable" do
    it "should include the Multisearchable module" do
      expect(ModelWithPgSearch).to receive(:include).with(PgSearch::Multisearchable)
      ModelWithPgSearch.multisearchable
    end

    it "should set pg_search_multisearchable_options on the class" do
      options = double(:options)
      ModelWithPgSearch.multisearchable(options)
      expect(ModelWithPgSearch.pg_search_multisearchable_options).to eq(options)
    end
  end

  describe ".multisearch" do
    with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

    describe "delegation to PgSearch::Document.search" do
      subject { PgSearch.multisearch(query) }

      let(:query) { double(:query) }
      let(:relation) { double(:relation) }
      before do
        expect(PgSearch::Document).to receive(:search).with(query).and_return(relation)
      end

      it { is_expected.to eq(relation) }
    end

    context "with PgSearch.multisearch_options set to a Hash" do
      before { allow(PgSearch).to receive(:multisearch_options).and_return({:using => :dmetaphone}) }
      subject { PgSearch.multisearch(query).map(&:searchable) }

      with_model :MultisearchableModel do
        table do |t|
          t.string :title
        end
        model do
          include PgSearch
          multisearchable :against => :title
        end
      end

      let!(:soundalike_record) { MultisearchableModel.create!(:title => 'foning') }
      let(:query) { "Phoning" }
      it { is_expected.to include(soundalike_record) }
    end

    context "with PgSearch.multisearch_options set to a Proc" do
      subject { PgSearch.multisearch(query, soundalike).map(&:searchable) }

      before do
        allow(PgSearch).to receive(:multisearch_options) do
          lambda do |query, soundalike|
            if soundalike
              {:using => :dmetaphone, :query => query}
            else
              {:query => query}
            end
          end
        end
      end

      with_model :MultisearchableModel do
        table do |t|
          t.string :title
        end
        model do
          include PgSearch
          multisearchable :against => :title
        end
      end

      let!(:soundalike_record) { MultisearchableModel.create!(:title => 'foning') }
      let(:query) { "Phoning" }

      context "with soundalike true" do
        let(:soundalike) { true }
        it { is_expected.to include(soundalike_record) }
      end

      context "with soundalike false" do
        let(:soundalike) { false }
        it { is_expected.not_to include(soundalike_record) }
      end
    end

    context "on an STI subclass" do
      with_model :SuperclassModel do
        table do |t|
          t.text 'content'
          t.string 'type'
        end
      end

      before do
        searchable_subclass_model = Class.new(SuperclassModel) do
          include PgSearch
          multisearchable :against => :content
        end
        stub_const("SearchableSubclassModel", searchable_subclass_model)
        stub_const("AnotherSearchableSubclassModel", searchable_subclass_model)
        stub_const("NonSearchableSubclassModel", Class.new(SuperclassModel))
      end

      it "returns only results for that subclass" do
        included = [
          SearchableSubclassModel.create!(:content => "foo bar")
        ]
        excluded = [
          SearchableSubclassModel.create!(:content => "baz"),
          SuperclassModel.create!(:content => "foo bar"),
          SuperclassModel.create!(:content => "baz"),
          NonSearchableSubclassModel.create!(:content => "foo bar"),
          NonSearchableSubclassModel.create!(:content => "baz")
        ]

        expect(SuperclassModel.count).to be 6
        expect(SearchableSubclassModel.count).to be 2

        expect(PgSearch::Document.count).to be 2

        results = PgSearch.multisearch("foo bar")

        expect(results.length).to be 1
        expect(results.first.searchable.class).to be SearchableSubclassModel
        expect(results.first.searchable).to eq included.first
      end

      it "updates an existing STI model does not create a new pg_search document" do
        model = SearchableSubclassModel.create!(:content => "foo bar")
        expect(SearchableSubclassModel.count).to eq(1)
        # We fetch the model from the database again otherwise
        # the pg_search_document from the cache is used.
        model = SearchableSubclassModel.find(model.id)
        model.content = "foo"
        model.save!
        results = PgSearch.multisearch("foo")
        expect(results.size).to eq(SearchableSubclassModel.count)
      end

      it "reindexing works" do
        NonSearchableSubclassModel.create!(:content => "foo bar")
        NonSearchableSubclassModel.create!(:content => "baz")
        expected = SearchableSubclassModel.create!(:content => "baz")
        SuperclassModel.create!(:content => "foo bar")
        SuperclassModel.create!(:content => "baz")
        SuperclassModel.create!(:content => "baz2")

        expect(SuperclassModel.count).to be 6
        expect(NonSearchableSubclassModel.count).to be 2
        expect(SearchableSubclassModel.count).to be 1

        expect(PgSearch::Document.count).to be 1

        PgSearch::Multisearch.rebuild(SearchableSubclassModel)

        expect(PgSearch::Document.count).to be 1
        expect(PgSearch::Document.first.searchable.class).to be SearchableSubclassModel
        expect(PgSearch::Document.first.searchable).to eq expected
      end

      it "reindexing searchable STI doesn't clobber other related STI models" do
        searchable_s = SearchableSubclassModel.create!(:content => "baz")
        searchable_a = AnotherSearchableSubclassModel.create!(:content => "baz")

        expect(PgSearch::Document.count).to be 2
        PgSearch::Multisearch.rebuild(SearchableSubclassModel)
        expect(PgSearch::Document.count).to be 2

        classes = PgSearch::Document.all.collect {|d| d.searchable.class }
        expect(classes).to include SearchableSubclassModel
        expect(classes).to include AnotherSearchableSubclassModel
      end
    end
  end

  describe ".disable_multisearch" do
    it "should temporarily disable multisearch" do
      @multisearch_enabled_before = PgSearch.multisearch_enabled?
      PgSearch.disable_multisearch do
        @multisearch_enabled_inside = PgSearch.multisearch_enabled?
      end
      @multisearch_enabled_after = PgSearch.multisearch_enabled?

      expect(@multisearch_enabled_before).to be(true)
      expect(@multisearch_enabled_inside).to be(false)
      expect(@multisearch_enabled_after).to be(true)
    end

    it "should reenable multisearch after an error" do
      @multisearch_enabled_before = PgSearch.multisearch_enabled?
      begin
        PgSearch.disable_multisearch do
          @multisearch_enabled_inside = PgSearch.multisearch_enabled?
          raise
        end
      rescue # rubocop:disable Lint/HandleExceptions
      end

      @multisearch_enabled_after = PgSearch.multisearch_enabled?

      expect(@multisearch_enabled_before).to be(true)
      expect(@multisearch_enabled_inside).to be(false)
      expect(@multisearch_enabled_after).to be(true)
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

      expect(@multisearch_enabled_before).to be(true)
      expect(@multisearch_enabled_inside).to be(true)
      expect(@multisearch_enabled_after).to be(true)
    end
  end

  describe ".pg_search_tsvrebuilders", focus: true do
    with_model :Post do
      table do |t|
        t.text 'content'
        t.text 'title'
        t.tsvector 'search_tsvector'
      end

      model do
        include PgSearch
      end
    end
    let(:post) { Post.new }

    context "with default options" do
      before do
        Post.pg_search_tsvrebuilders :against => :content,
                                     :tsvector_column => 'search_tsvector'
      end

      it "should respond to class method name" do
        expect(Post).to respond_to(:rebuild_all_search_tsvectors)
      end

      it "should respond to instance method name" do
        expect(post).to respond_to(:rebuild_search_tsvector)
      end
    end

    context "with disabled instance method" do
      before do
        Post.pg_search_tsvrebuilders :against => :content,
                                     :tsvector_column => 'search_tsvector',
                                     :instance_method => false
      end

      it "should respond to class method name" do
        expect(Post).to respond_to(:rebuild_all_search_tsvectors)
      end

      it "should not respond to instance method name" do
        expect(post).to_not respond_to(:rebuild_search_tsvector)
      end
    end

    context "with disabled class method" do
      before do
        Post.pg_search_tsvrebuilders :against => :content,
                                     :tsvector_column => 'search_tsvector',
                                     :class_method => false
      end

      it "should not respond to class method name" do
        expect(Post).to_not respond_to(:rebuild_all_search_tsvectors)
      end

      it "should respond to instance method name" do
        expect(post).to respond_to(:rebuild_search_tsvector)
      end
    end

    context "with custom method names" do
      before do
        Post.pg_search_tsvrebuilders :against => :content,
                                     :tsvector_column => 'search_tsvector',
                                     :instance_method => 'rebuild_tsvector',
                                     :class_method => 'rebuild_all_tsvectors'
      end

      it "should respond to class method name" do
        expect(Post).to respond_to(:rebuild_all_tsvectors)
      end

      it "should respond to instance method name" do
        expect(post).to respond_to(:rebuild_tsvector)
      end
    end

    context "without columns" do
      it "should raise ArgumentError" do
        expect {
          Post.pg_search_tsvrebuilders :tsvector_column => 'search_tsvector'
        }.to raise_error(ArgumentError)
      end
    end
  end
end
