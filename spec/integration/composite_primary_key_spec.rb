# frozen_string_literal: true

require "spec_helper"

describe "a model with a composite primary key" do
  with_model :Author do
    table do |t|
      t.string :name
    end
  end

  with_model :Book do
    table primary_key: [:author_id, :number] do |t|
      t.integer :author_id
      t.integer :number
      t.string :title
    end

    model do
      include PgSearch::Model

      belongs_to :author
      has_many :reviews, foreign_key: [:book_author_id, :book_number]

      pg_search_scope :search_title, against: :title
      pg_search_scope :search_author_name, associated_against: {author: :name}
      pg_search_scope :search_reviews, associated_against: {reviews: :body}
    end
  end

  with_model :Review do
    table do |t|
      t.integer :book_author_id
      t.integer :book_number
      t.string :body
    end

    model do
      include PgSearch::Model

      belongs_to :book, foreign_key: [:book_author_id, :book_number]

      pg_search_scope :search_book_title, associated_against: {book: :title}
    end
  end

  let(:author) { Author.create!(name: "Tolkien") }

  it "joins the rank on every key column and orders ties by the key" do
    second = Book.create!(author:, number: 2, title: "Ruby")
    first = Book.create!(author:, number: 1, title: "Ruby")
    Book.create!(author:, number: 3, title: "Python")

    expect(Book.search_title("Ruby")).to eq [first, second]
  end

  it "joins an associated record on every key column" do
    ruby_review = Review.create!(book: Book.create!(author:, number: 1, title: "Ruby"))
    Review.create!(book: Book.create!(author:, number: 2, title: "Python"))

    expect(Review.search_book_title("Ruby")).to eq [ruby_review]
  end

  it "joins its own singular association on every key column" do
    first = Book.create!(author:, number: 1)
    second = Book.create!(author:, number: 2)
    Book.create!(author: Author.create!(name: "Lewis"), number: 1)

    expect(Book.search_author_name("Tolkien")).to eq [first, second]
  end

  it "aggregates its own collection association by every key column" do
    reviewed = Book.create!(author:, number: 1)
    reviewed.reviews.create!(body: "gripping")
    reviewed.reviews.create!(body: "plot")
    Book.create!(author:, number: 2).reviews.create!(body: "gripping")

    expect(Book.search_reviews("gripping plot")).to eq [reviewed]
  end
end
