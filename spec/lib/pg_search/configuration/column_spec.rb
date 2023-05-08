# frozen_string_literal: true

require "spec_helper"

describe PgSearch::Configuration::Column do
  describe "#full_name" do
    with_model :Model do
      table do |t|
        t.string :name
        t.json :object
      end
    end

    it "returns the fully-qualified table and column name" do
      column = described_class.new("name", nil, Model)
      expect(column.full_name).to eq(%(#{Model.quoted_table_name}."name"))
    end

    it "returns nested json attributes" do
      column = described_class.new(Arel.sql("object->>'name'"), nil, Model)
      expect(column.full_name).to eq(%(object->>'name'))
    end
  end

  describe "#to_sql" do
    with_model :Model do
      table do |t|
        t.string :name
        t.json :object
      end
    end

    it "returns an expression that casts the column to text and coalesces it with an empty string" do
      column = described_class.new("name", nil, Model)
      expect(column.to_sql).to eq(%{coalesce((#{Model.quoted_table_name}."name")::text, '')})
    end

    it "returns an expression that casts the nested json attribute to text and coalesces it with an empty string" do
      column = described_class.new(Arel.sql("object->>'name'"), nil, Model)
      expect(column.to_sql).to eq(%{coalesce((object->>'name')::text, '')})
    end
  end
end
