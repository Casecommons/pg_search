# frozen_string_literal: true

require "spec_helper"

describe "composite_primary_key" do
  context "without associations" do
    with_model :CompositePrimaryKeyModel do
      table primary_key: [:prefix, :postfix] do |t|
        t.string :prefix
        t.string :postfix
        t.string :name
      end

      model do
        include PgSearch::Model
        self.primary_key = [:prefix, :postfix]
        pg_search_scope :search_name, against: :name
      end
    end

    before { CompositePrimaryKeyModel.create!(id: ["prefix", "postfix"], name: "bar") }
    let!(:record_1) { CompositePrimaryKeyModel.create!(id: ["prefix_2", "postfix_2"], name: "foo") }

    it "searches without any issues" do
      expect(CompositePrimaryKeyModel.search_name("foo")).to eq([record_1])
    end
  end
end
