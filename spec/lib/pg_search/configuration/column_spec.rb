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

  describe "#to_arel" do
    with_model :Model do
      table do |t|
        t.string :name
        t.integer :count
        t.json :object
      end
    end

    it "coalesces NULL values to an empty string when composed into a query" do
      model = Model.create!(name: nil)
      column = described_class.new("name", nil, Model)
      query = Model.arel_table
        .project(column.to_arel.as("value"))
        .where(Model.arel_table[:id].eq(model.id))

      sql = Model.connection.visitor.compile(query.ast)
      expect(Model.connection.select_value(sql)).to eq("")
    end

    it "casts a non-text column to text when composed into a query" do
      model = Model.create!(count: 42)
      column = described_class.new("count", nil, Model)
      query = Model.arel_table
        .project(column.to_arel.as("value"))
        .where(Model.arel_table[:id].eq(model.id))

      sql = Model.connection.visitor.compile(query.ast)
      expect(Model.connection.select_value(sql)).to eq("42")
    end

    it "evaluates a trusted SQL literal JSON expression when composed into a query" do
      model = Model.create!(object: {name: "hello world"})
      column = described_class.new(Arel.sql("object->>'name'"), nil, Model)
      query = Model.arel_table
        .project(column.to_arel.as("value"))
        .where(Model.arel_table[:id].eq(model.id))

      sql = Model.connection.visitor.compile(query.ast)
      expect(Model.connection.select_value(sql)).to eq("hello world")
    end

    context "with quoted identifiers" do
      with_model :QuotedModel do
        table do |t|
          t.string "select"
          t.string "order"
        end
      end

      it "executes a reserved-word column through a projected Arel node" do
        model = QuotedModel.create!(select: "value1")
        column = described_class.new("select", nil, QuotedModel)
        query = QuotedModel.arel_table
          .project(column.to_arel.as("value"))
          .where(QuotedModel.arel_table[:id].eq(model.id))

        sql = QuotedModel.connection.visitor.compile(query.ast)
        expect(QuotedModel.connection.select_value(sql)).to eq("value1")
      end

      it "composes multiple quoted column nodes before execution" do
        model = QuotedModel.create!(select: "abc", order: "def")
        select_column = described_class.new("select", nil, QuotedModel)
        order_column = described_class.new("order", nil, QuotedModel)
        combined = Arel::Nodes::NamedFunction.new(
          "concat",
          [select_column.to_arel, order_column.to_arel]
        )
        query = QuotedModel.arel_table
          .project(combined.as("value"))
          .where(QuotedModel.arel_table[:id].eq(model.id))

        sql = QuotedModel.connection.visitor.compile(query.ast)
        expect(QuotedModel.connection.select_value(sql)).to eq("abcdef")
      end
    end
  end

  describe "#to_sql" do
    with_model :Model do
      table do |t|
        t.string :name
      end
    end

    it "uses the model connection's visitor as a String adapter" do
      column = described_class.new("name", nil, Model)

      expect(column.to_sql).to be_a(String)
      expect(column.to_sql).to eq(Model.connection.visitor.compile(column.to_arel))
    end
  end
end
