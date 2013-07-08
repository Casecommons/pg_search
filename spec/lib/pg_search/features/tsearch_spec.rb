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
      feature.rank.to_sql.should ==
        %Q{(ts_rank((to_tsvector('simple', coalesce(#{Model.quoted_table_name}."name"::text, '')) || to_tsvector('simple', coalesce(#{Model.quoted_table_name}."content"::text, ''))), (to_tsquery('simple', ''' ' || 'query' || ' ''')), 0))}
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
      feature.conditions.to_sql.should ==
        %Q{((to_tsvector('simple', coalesce(#{Model.quoted_table_name}."name"::text, '')) || to_tsvector('simple', coalesce(#{Model.quoted_table_name}."content"::text, ''))) @@ (to_tsquery('simple', ''' ' || 'query' || ' ''')))}
    end
  end
end
