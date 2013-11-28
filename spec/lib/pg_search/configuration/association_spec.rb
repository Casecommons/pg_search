require "spec_helper"

describe PgSearch::Configuration::Association do
  with_model :AssociatedModel do
    table do |t|
      t.string "title"
    end
  end

  with_model :Model do
    table do |t|
      t.string "title"
      t.belongs_to :another_model
    end

    model do
      include PgSearch
      belongs_to :another_model, :class_name => 'AssociatedModel'

      pg_search_scope :with_another, :associated_against => {:another_model => :title}
    end
  end

  let(:association) { described_class.new(Model, :another_model, :title) }

  describe "#table_name" do
    it "returns the table name for the associated model" do
      expect(association.table_name).to eq AssociatedModel.table_name
    end
  end

  describe "#join" do
    let(:expected_sql) do
      <<-EOS.gsub(/\s+/, ' ').strip
        LEFT OUTER JOIN
          (SELECT model_id AS id,
                  #{column_select} AS #{association.columns.first.alias}
          FROM \"#{Model.table_name}\"
          INNER JOIN \"#{association.table_name}\"
          ON \"#{association.table_name}\".\"id\" = \"#{Model.table_name}\".\"another_model_id\"
          GROUP BY model_id) #{association.subselect_alias}
        ON #{association.subselect_alias}.id = model_id
      EOS
    end

    context "given postgresql_version 0..90_000" do
      let(:column_select) do
        "array_to_string(array_agg(\"#{association.table_name}\".\"title\"::text), ' ')"
      end

      it "returns the correct SQL join" do
        allow(Model.connection).to receive(:postgresql_version).and_return(1)
        expect(association.join("model_id")).to eq(expected_sql)
      end
    end

    context "given any other postgresql_version" do
      let(:column_select) do
        "string_agg(\"#{association.table_name}\".\"title\"::text, ' ')"
      end

      it "returns the correct SQL join" do
        allow(Model.connection).to receive(:postgresql_version).and_return(100_000)
        expect(association.join("model_id")).to eq(expected_sql)
      end
    end
  end

  describe "#subselect_alias" do
    it "returns a consistent string" do
      subselect_alias = association.subselect_alias
      expect(subselect_alias).to be_a String
      expect(association.subselect_alias).to eq subselect_alias
    end
  end
end
