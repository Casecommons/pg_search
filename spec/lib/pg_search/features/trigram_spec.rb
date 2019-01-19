# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

describe PgSearch::Features::Trigram do
  subject(:feature) { described_class.new(query, options, columns, Model, normalizer) }
  let(:query) { 'lolwut' }
  let(:options) { {} }
  let(:columns) {
    [
      PgSearch::Configuration::Column.new(:name, nil, Model),
      PgSearch::Configuration::Column.new(:content, nil, Model)
    ]
  }
  let(:normalizer) { PgSearch::Normalizer.new(config) }
  let(:config) { OpenStruct.new(:ignore => []) }

  let(:coalesced_columns) do
    <<-SQL.strip_heredoc.chomp
      coalesce(#{Model.quoted_table_name}."name"::text, '') || ' ' || coalesce(#{Model.quoted_table_name}."content"::text, '')
    SQL
  end

  with_model :Model do
    table do |t|
      t.string :name
      t.string :content
    end
  end

  describe 'conditions' do
    it 'escapes the search document and query' do
      config.ignore = []
      expect(feature.conditions.to_sql).to eq("((#{coalesced_columns}) % '#{query}')")
    end

    context 'ignoring accents' do
      it 'escapes the search document and query, but not the accent function' do
        config.ignore = [:accents]
        expect(feature.conditions.to_sql).to eq("((unaccent(#{coalesced_columns})) % unaccent('#{query}'))")
      end
    end

    context 'when a threshold is specified' do
      let(:options) do
        { threshold: 0.5 }
      end

      it 'uses a minimum similarity expression instead of the "%" operator' do
        expect(feature.conditions.to_sql).to eq(
          "(similarity((#{coalesced_columns}), '#{query}') >= 0.5)"
        )
      end
    end

    context 'only certain columns are selected' do
      context 'one column' do
        let(:options) { { only: :name } }

        it 'only searches against the select column' do
          options = { only: :name }
          coalesced_column = "coalesce(#{Model.quoted_table_name}.\"name\"::text, '')"
          expect(feature.conditions.to_sql).to eq("((#{coalesced_column}) % '#{query}')")
        end
      end
      context 'multiple columns' do
        let(:options) { { only: %i[name content] } }

        it 'concatenates when multiples columns are selected' do
          options = { only: %i[name content] }
          expect(feature.conditions.to_sql).to eq("((#{coalesced_columns}) % '#{query}')")
        end
      end
    end
  end

  describe '#rank' do
    it 'returns an expression using the similarity() function' do
      expect(feature.rank.to_sql).to eq("(similarity((#{coalesced_columns}), '#{query}'))")
    end
  end
end
