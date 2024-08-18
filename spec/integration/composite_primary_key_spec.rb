# frozen_string_literal: true

require "spec_helper"

describe "composite_primary_key" do
  context 'without associations' do
    with_model :Parent do
      table primary_key: [:first_name, :last_name] do |t|
        t.string :first_name
        t.string :last_name
        t.string :hobby
      end

      model do
        include PgSearch::Model
        self.primary_key = [:first_name, :last_name]
        pg_search_scope :search_hobby, against: :hobby
      end
    end

    before { Parent.create!(id: ["first_name", "last_name"], hobby: "golf") }
    let!(:record_1) { Parent.create!(id: ["first_name_2", "last_name_2"], hobby: "basketball") }

    it "searches without any issues" do
      expect(Parent.search_hobby("basketball")).to eq([record_1])
    end
  end

  context "without composite_primary_key, searching against association with a composite_primary_key" do
    with_model :Parent do
      table primary_key: [:first_name, :last_name] do |t|
        t.string :first_name
        t.string :last_name
        t.string :hobby
      end

      model do
        include PgSearch::Model
        has_many :children
        self.primary_key = [:first_name, :last_name]
      end
    end
    
    with_model :Child do
      table do |t|
        t.string :parent_first_name
        t.string :parent_last_name
      end

      model do
        include PgSearch::Model
        belongs_to :parent, foreign_key: [:parent_first_name, :parent_last_name]

        pg_search_scope :search_parent_hobby, associated_against: {
          parent: [:hobby]
        } 
      end
    end

    before do
      parent = Parent.create!(id: ["first_name", "last_name"], hobby: "golf")
      Child.create!(parent: parent)
    end

    let!(:record_1) do
      parent = Parent.create!(id: ["first_name_2", "last_name_2"], hobby: "basketball")
      Child.create!(parent: parent)
    end

    it "searches without any issues" do
      expect(Child.search_parent_hobby("basketball")).to eq([record_1])
    end
  end
end
