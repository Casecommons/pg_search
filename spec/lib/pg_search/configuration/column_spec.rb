require "spec_helper"

describe PgSearch::Configuration::Column do
  describe "#full_name" do
    with_model :Model do
      table do |t|
        t.string :name
      end
    end

    it "returns the fully-qualified table and column name" do
      column = described_class.new("name", nil, Model)
      expect(column.full_name).to eq(%Q{#{Model.quoted_table_name}."name"})
    end
  end

  describe "#to_sql" do
    with_model :Model do
      table do |t|
        t.string :name
      end
    end

    it "returns an expression that casts the column to text and coalesces it with an empty string" do
      column = described_class.new("name", nil, Model)
      expect(column.to_sql).to eq(%Q{coalesce(#{Model.quoted_table_name}."name"::text, '')})
    end
  end
end
