# frozen_string_literal: true

require "spec_helper"

describe PgSearch::Features::ParadeDB do
  subject(:feature) do
    described_class.new(query, options, columns, Model, normalizer)
  end

  let(:query) { "search query" }
  let(:options) { {} }
  let(:columns) { [column_double] }
  let(:normalizer) { PgSearch::Normalizer.new(config_double) }
  let(:config_double) { instance_double(PgSearch::Configuration, ignore: []) }
  let(:column_double) do
    instance_double(PgSearch::Configuration::Column, 
      name: "content",
      to_sql: %("#{Model.table_name}"."content")
    )
  end

  with_model :Model do
    table do |t|
      t.string :content
      t.integer :searchable_id
      t.timestamps
    end
  end

  describe "#conditions" do
    context "with a simple query" do
      let(:query) { "shoes" }
      
      it "generates the correct ParadeDB search condition" do
        condition = feature.conditions
        expect(condition.to_sql).to match(/@@@ 'shoes'/)
      end
    end

    context "with special characters" do
      let(:query) { "men's shoes" }
      
      it "escapes single quotes properly" do
        condition = feature.conditions
        expect(condition.to_sql).to match(/@@@ 'men''s shoes'/)
      end
    end

    context "with phrase search" do
      let(:options) { { query_type: :phrase } }
      let(:query) { "red shoes" }
      
      it "wraps the query in double quotes" do
        condition = feature.conditions
        expect(condition.to_sql).to match(/@@@ '"red shoes"'/)
      end
    end

    context "with prefix search" do
      let(:options) { { query_type: :prefix } }
      let(:query) { "sho" }
      
      it "adds wildcard to the query" do
        condition = feature.conditions
        expect(condition.to_sql).to match(/@@@ 'sho\*'/)
      end
    end

    context "with fuzzy search" do
      let(:options) { { query_type: :fuzzy, fuzzy_distance: 2 } }
      let(:query) { "sheos" }
      
      it "adds fuzzy distance to the query" do
        condition = feature.conditions
        expect(condition.to_sql).to match(/@@@ 'sheos~2'/)
      end
    end

    context "with multiple columns" do
      let(:columns) do
        [
          instance_double(PgSearch::Configuration::Column,
            name: "title",
            to_sql: %("#{Model.table_name}"."title")
          ),
          instance_double(PgSearch::Configuration::Column,
            name: "content", 
            to_sql: %("#{Model.table_name}"."content")
          )
        ]
      end
      
      it "creates OR conditions for each column" do
        condition = feature.conditions
        sql = condition.to_sql
        expect(sql).to include("OR")
        expect(sql).to match(/"title" @@@ 'search query'/)
        expect(sql).to match(/"content" @@@ 'search query'/)
      end
    end
  end

  describe "#rank" do
    context "for regular models" do
      let(:options) { { key_field: "id" } }
      
      it "generates paradedb.score with the specified key field" do
        rank = feature.rank
        expect(rank.to_sql).to match(/paradedb\.score\(.*"id"\)/)
      end
    end

    context "for PgSearch::Document model" do
      before do
        allow(Model).to receive(:name).and_return("PgSearch::Document")
      end
      
      it "uses searchable_id as the key field" do
        rank = feature.rank
        expect(rank.to_sql).to match(/paradedb\.score\(.*"searchable_id"\)/)
      end
    end

    context "without specified key field" do
      it "defaults to id for regular models" do
        rank = feature.rank
        expect(rank.to_sql).to match(/paradedb\.score\(.*"id"\)/)
      end
    end
  end

  describe ".valid_options" do
    it "includes ParadeDB-specific options" do
      valid_options = described_class.valid_options
      expect(valid_options).to include(
        :index_name,
        :key_field,
        :text_fields,
        :numeric_fields,
        :boolean_fields,
        :json_fields,
        :range_fields,
        :query_type,
        :limit,
        :offset,
        :fuzzy_distance,
        :prefix_search,
        :phrase_search
      )
    end

    it "includes base feature options" do
      valid_options = described_class.valid_options
      expect(valid_options).to include(:only, :sort_only)
    end
  end
end