# frozen_string_literal: true

require "spec_helper"

describe "composite_primary_key" do
  context 'without relations' do
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

  context "without composite_primary_key, searching against relation with a composite_primary_key" do
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

  context "with composite_primary_key, searching against relation with a composite_primary_key" do
    with_model :Parent do
      table primary_key: [:first_name, :last_name] do |t|
        t.string :first_name
        t.string :last_name
        t.string :hobby
      end

      model do
        include PgSearch::Model
        has_many :children, foreign_key: [:first_name, :last_name]
        self.primary_key = [:first_name, :last_name]
      end
    end

    with_model :Child do
      table primary_key: [:first_name, :last_name] do |t|
        t.string :hobby
        t.string :first_name
        t.string :last_name
        t.string :parent_first_name
        t.string :parent_last_name
      end

      model do
        include PgSearch::Model
        belongs_to :parent, foreign_key: [:parent_first_name, :parent_last_name]
        has_many :siblings, through: :parent, source: :children

        pg_search_scope :search_parent_hobby, associated_against: {
          parent: [:hobby]
        } 

        pg_search_scope :search_sibling_hobby, associated_against: {
          siblings: [:hobby]
        } 

        pg_search_scope :search_hobby, associated_against: {
          parent: [:hobby],
          siblings: [:hobby]
        }
      end
    end

    before do
      parent = Parent.create!(id: ["first_name", "last_name"], hobby: "golf")
      Child.create!(id: ["first_name", "last_name"], parent: parent)
    end

    it "searches direct relation without any issues" do
      parent = Parent.create!(id: ["first_name_2", "last_name_2"], hobby: "basketball")
      record_1 = Child.create!(id: ["first_name_2", "last_name_2"], parent: parent)
      expect(Child.search_parent_hobby("basketball")).to eq([record_1])
    end

    it "searches through relation without any issues" do
      parent = Parent.create!(id: ["first_name_2", "last_name_2"], hobby: "juggling")
      Child.create!(id: ["first_name_2", "last_name_2"], parent: parent, hobby: "basketball")
      record_1 = Child.create!(id: ["first_name_3", "last_name_3"], parent: parent, hobby: "studying")

      expect(Child.search_sibling_hobby("basketball")).to eq([record_1])
    end

    it "searches through multiple relations without any issues" do
      parent_1 = Parent.create!(id: ["first_name_2", "last_name_2"], hobby: "basketball")
      record_1 = Child.create!(id: ["first_name_2", "last_name_2"], parent: parent_1, hobby: "studying") # match by parent

      parent_2 = Parent.create!(id: ["first_name_3", "last_name_3"], hobby: "juggling")
      record_2 = Child.create!(id: ["first_name_3", "last_name_3"], parent: parent_2, hobby: "bowling") # match by sibling
      record_3 = Child.create!(id: ["first_name_4", "last_name_4"], parent: parent_2, hobby: "basketball") # match by self

      parent_3 = Parent.create!(id: ["first_name_4", "last_name_4"], hobby: "golf")
      Child.create!(id: ["first_name_5", "last_name_5"], parent: parent_3, hobby: "sleeping") 

      expect(Child.search_hobby("basketball")).to eq([record_1, record_2, record_3])
    end
  end
end
