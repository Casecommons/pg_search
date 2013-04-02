require "spec_helper"

describe PgSearch::Features::Trigram do
  describe "#rank" do
    with_model :Model do
      table do |t|
        t.string :name
        t.text :content
      end
    end

    it "returns an expression using the similarity() function" do
      query = "query"
      columns = [
        PgSearch::Configuration::Column.new(:name, nil, Model),
        PgSearch::Configuration::Column.new(:content, nil, Model),
      ]
      options = stub(:options)
      config = stub(:config, :ignore => [])
      normalizer = PgSearch::Normalizer.new(config)

      feature = described_class.new(query, options, columns, Model, normalizer)
      feature.rank.to_sql.should == %Q{(similarity((coalesce(#{Model.quoted_table_name}."name"::text, '') || ' ' || coalesce(#{Model.quoted_table_name}."content"::text, '')), 'query'))}
    end
  end
end
