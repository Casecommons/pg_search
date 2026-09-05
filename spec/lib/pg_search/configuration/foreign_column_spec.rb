# frozen_string_literal: true

require "spec_helper"

describe PgSearch::Configuration::ForeignColumn do
  with_model :AssociatedModel do
    table do |t|
      t.string :title
    end
  end

  with_model :Model do
    table do |t|
      t.string :name
      t.belongs_to :associated_model, index: false, null: true
    end

    model do
      include PgSearch::Model

      belongs_to :associated_model, class_name: "AssociatedModel", optional: true

      pg_search_scope :with_title, associated_against: {associated_model: :title}
    end
  end

  let(:association) do
    PgSearch::Configuration::Association.new(Model, :associated_model, :title)
  end
  let(:foreign_column) { described_class.new("title", nil, Model, association) }

  describe "#alias" do
    it "returns a consistent string" do
      column_alias = foreign_column.alias
      expect(column_alias).to be_a String
      expect(foreign_column.alias).to eq column_alias
    end
  end

  describe "#full_name" do
    it "returns the fully-qualified associated table and column name" do
      expect(foreign_column.full_name).to eq(
        %(#{AssociatedModel.quoted_table_name}."title")
      )
    end
  end

  describe "#to_arel" do
    def selected_value(model)
      primary_key = Model.connection.visitor.compile(Model.arel_table[:id])
      relation = Model
        .joins(association.join(primary_key))
        .where(Model.arel_table[:id].eq(model.id))
        .select(foreign_column.to_arel.as("value"))
      sql = Model.connection.visitor.compile(relation.arel.ast)

      Model.connection.select_value(sql)
    end

    it "evaluates the associated value through the association join alias" do
      associated = AssociatedModel.create!(title: "hello world")
      model = Model.create!(name: "example", associated_model: associated)

      expect(selected_value(model)).to eq("hello world")
    end

    it "coalesces a NULL associated value through the association join alias" do
      associated = AssociatedModel.create!(title: nil)
      model = Model.create!(name: "example", associated_model: associated)

      expect(selected_value(model)).to eq("")
    end

    it "coalesces a missing association through the outer join alias" do
      model = Model.create!(name: "example", associated_model: nil)

      expect(selected_value(model)).to eq("")
    end
  end

  describe "#to_sql" do
    it "uses the model connection's visitor as a String adapter" do
      expect(foreign_column.to_sql).to be_a(String)
      expect(foreign_column.to_sql).to eq(
        Model.connection.visitor.compile(foreign_column.to_arel)
      )
    end
  end
end
