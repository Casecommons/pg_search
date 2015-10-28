require "spec_helper"

describe PgSearch::Configuration::PlainColumn do
  describe "#full_name" do
    with_model :Model do
      table do |t|
        t.string :name
      end
    end

    it "returns the fully-qualified table and column name" do
      column = described_class.new("name")
      expect(column.full_name(Model.connection, Model.table_name)).to eq(%(#{Model.quoted_table_name}."name"))
    end
  end
end
