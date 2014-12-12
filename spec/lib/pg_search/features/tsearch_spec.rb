require "spec_helper"

describe PgSearch::Features::TSearch do
  describe "#rank" do
    with_model :Model do
      table do |t|
        t.string :name
        t.text :content
      end
    end

    it "returns an expression using the ts_rank() function" do
      query = "query"
      columns = [
        PgSearch::Configuration::Column.new(:name, nil, Model),
        PgSearch::Configuration::Column.new(:content, nil, Model),
      ]
      options = {}
      config = double(:config, :ignore => [])
      normalizer = PgSearch::Normalizer.new(config)

      feature = described_class.new(query, options, columns, Model, normalizer)
      expect(feature.rank.to_sql).to eq(
        %{(ts_rank((to_tsvector('simple', coalesce(#{Model.quoted_table_name}."name"::text, '')) || to_tsvector('simple', coalesce(#{Model.quoted_table_name}."content"::text, ''))), (to_tsquery('simple', ''' ' || 'query' || ' ''')), 0))}
      )
    end
  end

  describe "#conditions" do
    with_model :Model do
      table do |t|
        t.string :name
        t.text :content
      end
    end

    it "returns an expression using the @@ infix operator" do
      query = "query"
      columns = [
        PgSearch::Configuration::Column.new(:name, nil, Model),
        PgSearch::Configuration::Column.new(:content, nil, Model),
      ]
      options = {}
      config = double(:config, :ignore => [])
      normalizer = PgSearch::Normalizer.new(config)

      feature = described_class.new(query, options, columns, Model, normalizer)
      expect(feature.conditions.to_sql).to eq(
        %{((to_tsvector('simple', coalesce(#{Model.quoted_table_name}."name"::text, '')) || to_tsvector('simple', coalesce(#{Model.quoted_table_name}."content"::text, ''))) @@ (to_tsquery('simple', ''' ' || 'query' || ' ''')))}
      )
    end

    context "when options[:negation] is true" do
      it "returns a negated expression when a query is prepended with !" do
        query = "!query"
        columns = [
          PgSearch::Configuration::Column.new(:name, nil, Model),
          PgSearch::Configuration::Column.new(:content, nil, Model),
        ]
        options = {:negation => true}
        config = double(:config, :ignore => [])
        normalizer = PgSearch::Normalizer.new(config)

        feature = described_class.new(query, options, columns, Model, normalizer)
        expect(feature.conditions.to_sql).to eq(
          %{((to_tsvector('simple', coalesce(#{Model.quoted_table_name}."name"::text, '')) || to_tsvector('simple', coalesce(#{Model.quoted_table_name}."content"::text, ''))) @@ (to_tsquery('simple', '!' || ''' ' || 'query' || ' ''')))}
        )
      end
    end

    context "when options[:negation] is false" do
      it "does not return a negated expression when a query is prepended with !" do
        query = "!query"
        columns = [
          PgSearch::Configuration::Column.new(:name, nil, Model),
          PgSearch::Configuration::Column.new(:content, nil, Model),
        ]
        options = {:negation => false}
        config = double(:config, :ignore => [])
        normalizer = PgSearch::Normalizer.new(config)

        feature = described_class.new(query, options, columns, Model, normalizer)
        expect(feature.conditions.to_sql).to eq(
          %{((to_tsvector('simple', coalesce(#{Model.quoted_table_name}."name"::text, '')) || to_tsvector('simple', coalesce(#{Model.quoted_table_name}."content"::text, ''))) @@ (to_tsquery('simple', ''' ' || '!query' || ' ''')))}
        )
      end
    end

    context "when options[:tsvector_column] is a string" do
      it 'uses the tsvector column' do
        query = "query"
        columns = [
          PgSearch::Configuration::Column.new(:name, nil, Model),
          PgSearch::Configuration::Column.new(:content, nil, Model),
        ]
        options = { tsvector_column: "my_tsvector" }
        config = double(:config, :ignore => [])
        normalizer = PgSearch::Normalizer.new(config)

        feature = described_class.new(query, options, columns, Model, normalizer)
        expect(feature.conditions.to_sql).to eq(
          %{((#{Model.quoted_table_name}.\"my_tsvector\") @@ (to_tsquery('simple', ''' ' || 'query' || ' ''')))}
        )
      end
    end

    context "when options[:tsvector_column] is an array of strings" do
      it 'uses the tsvector column' do
        query = "query"
        columns = [
          PgSearch::Configuration::Column.new(:name, nil, Model),
          PgSearch::Configuration::Column.new(:content, nil, Model),
        ]
        options = { tsvector_column: ["tsvector1", "tsvector2"] }
        config = double(:config, :ignore => [])
        normalizer = PgSearch::Normalizer.new(config)

        feature = described_class.new(query, options, columns, Model, normalizer)
        expect(feature.conditions.to_sql).to eq(
          %{((#{Model.quoted_table_name}.\"tsvector1\" || #{Model.quoted_table_name}.\"tsvector2\") @@ (to_tsquery('simple', ''' ' || 'query' || ' ''')))}
        )
      end
    end
  end
end
