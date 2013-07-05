require "spec_helper"

describe "pagination" do
  describe "using LIMIT and OFFSET" do
    with_model :PaginatedModel do
      table do |t|
        t.string :name
      end

      model do
        include PgSearch
        pg_search_scope :search_name, :against => :name

        def self.page(page_number)
          offset = (page_number - 1) * 2
          limit(2).offset(offset)
        end
      end
    end

    it "is chainable before a search scope" do
      better = PaginatedModel.create!(:name => "foo foo bar")
      best = PaginatedModel.create!(:name => "foo foo foo")
      good = PaginatedModel.create!(:name => "foo bar bar")

      PaginatedModel.page(1).search_name("foo").should == [best, better]
      PaginatedModel.page(2).search_name("foo").should == [good]
    end

    it "is chainable after a search scope" do
      better = PaginatedModel.create!(:name => "foo foo bar")
      best = PaginatedModel.create!(:name => "foo foo foo")
      good = PaginatedModel.create!(:name => "foo bar bar")

      PaginatedModel.search_name("foo").page(1).should == [best, better]
      PaginatedModel.search_name("foo").page(2).should == [good]
    end
  end
end
