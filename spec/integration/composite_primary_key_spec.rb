# frozen_string_literal: true

require "spec_helper"

describe "a model with a composite primary key" do
  with_model :Book do
    table primary_key: [:author_id, :number] do |t|
      t.integer :author_id
      t.integer :number
      t.string :title
    end

    model do
      include PgSearch::Model

      pg_search_scope :search_title, against: :title
    end
  end

  it "joins the rank on every key column and orders ties by the key" do
    second = Book.create!(author_id: 1, number: 2, title: "Ruby")
    first = Book.create!(author_id: 1, number: 1, title: "Ruby")
    Book.create!(author_id: 1, number: 3, title: "Python")

    expect(Book.search_title("Ruby")).to eq [first, second]
  end

  context "when searched through an association" do
    with_model :Review do
      table do |t|
        t.integer :book_author_id
        t.integer :book_number
      end

      model do
        include PgSearch::Model

        belongs_to :book, foreign_key: [:book_author_id, :book_number]

        pg_search_scope :search_book_title, associated_against: {book: :title}
      end
    end

    it "joins the associated record on every key column" do
      ruby_review = Review.create!(book: Book.create!(author_id: 1, number: 1, title: "Ruby"))
      Review.create!(book: Book.create!(author_id: 1, number: 2, title: "Python"))

      expect(Review.search_book_title("Ruby")).to eq [ruby_review]
    end
  end
end
