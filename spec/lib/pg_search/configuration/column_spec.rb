require "spec_helper"

describe PgSearch::Configuration::Column do
  describe "#to_sql" do
    with_model :Model do
      table do |t|
        t.string :name
      end
    end

    it "returns an expression that casts the column to text and coalesces it with an empty string" do
      column = described_class.new("name", nil, Model)
      expect(column.to_sql).to eq(%{coalesce(#{Model.quoted_table_name}."name"::text, '')})
    end
  end
end
