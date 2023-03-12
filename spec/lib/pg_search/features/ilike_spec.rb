# frozen_string_literal: true

require "spec_helper"
require "ostruct"

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
describe PgSearch::Features::ILike do
  subject(:feature) { described_class.new(query, options, columns, Model, normalizer) }

  let(:query) { "lolwut" }
  let(:options) { {} }
  let(:columns) {
    [
      PgSearch::Configuration::Column.new(:name, nil, Model),
      PgSearch::Configuration::Column.new(:content, nil, Model)
    ]
  }
  let(:normalizer) { PgSearch::Normalizer.new(config) }
  let(:config) { OpenStruct.new(ignore: []) }

  let(:coalesced_columns) do
    <<~SQL.squish
      coalesce(#{Model.quoted_table_name}."name"::text, '')
        || ' '
        || coalesce(#{Model.quoted_table_name}."content"::text, '')
    SQL
  end

  with_model :Model do
    table do |t|
      t.string :name
      t.string :content
    end
  end

  describe "conditions" do
    it "escapes the search document and query" do
      expect(feature.conditions.to_sql).to eq("((#{coalesced_columns}) ILIKE '%#{query}%')")
    end
  end
end