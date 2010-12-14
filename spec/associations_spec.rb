require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe PgSearch do
  context "joining to another table" do
    if defined?(ActiveRecord::Relation)
      context "with Arel support" do
        context "through a belongs_to association" do
          with_model :associated_model do
            table do |t|
              t.string 'title'
            end
          end

          with_model :model_with_belongs_to do
            table do |t|
              t.string 'title'
              t.belongs_to 'another_model'
            end

            model do
              include PgSearch
              belongs_to :another_model, :class_name => 'AssociatedModel'

              #pg_search_scope :with_associated, :against => :title, :associated_against => {:another_model => [[:title, 'A'], :name]}
              #pg_search_scope :with_associated, :against => :title, :associated_against => {:another_model => [:title, :name]}
              pg_search_scope :with_associated, :against => :title, :associated_against => {:another_model => :title}
            end
          end

          it "returns rows that match the query in either its own columns or the columns of the associated model" do
            associated = associated_model.create!(:title => 'abcdef')
            included = [
              model_with_belongs_to.create!(:title => 'ghijkl', :another_model => associated),
              model_with_belongs_to.create!(:title => 'abcdef')
            ]
            excluded = model_with_belongs_to.create!(:title => 'mnopqr',
                                                     :another_model => associated_model.create!(:title => 'stuvwx'))

            results = model_with_belongs_to.with_associated('abcdef')
            results.map(&:title).should =~ included.map(&:title)
            results.should_not include(excluded)
          end
        end

        context "through a has_many association" do
          with_model :associated_model_with_has_many do
            table do |t|
              t.string 'title'
              t.belongs_to 'model_with_has_many'
            end
          end

          with_model :model_with_has_many do
            table do |t|
              t.string 'title'
            end

            model do
              include PgSearch
              has_many :other_models, :class_name => 'AssociatedModelWithHasMany', :foreign_key => 'model_with_has_many_id'

              pg_search_scope :with_associated, :against => [:title], :associated_against => {:other_models => :title}
            end
          end

          it "returns rows that match the query in either its own columns or the columns of the associated model" do
            included = [
              model_with_has_many.create!(:title => 'abcdef', :other_models => [
                                          associated_model_with_has_many.create!(:title => 'foo'),
                                          associated_model_with_has_many.create!(:title => 'bar')
            ]),
              model_with_has_many.create!(:title => 'ghijkl', :other_models => [
                                          associated_model_with_has_many.create!(:title => 'foo bar'),
                                          associated_model_with_has_many.create!(:title => 'mnopqr')
            ]),
              model_with_has_many.create!(:title => 'foo bar')
            ]
            excluded = model_with_has_many.create!(:title => 'stuvwx', :other_models => [
                                                   associated_model_with_has_many.create!(:title => 'abcdef')
            ])

            results = model_with_has_many.with_associated('foo bar')
            results.map(&:title).should =~ included.map(&:title)
            results.should_not include(excluded)
          end
        end
      end
    else
      context "without Arel support" do
        with_model :model do
          table do |t|
            t.string 'title'
          end

          model do
            include PgSearch
            pg_search_scope :with_joins, :against => :title, :joins => :another_model
          end
        end

        it "should raise an error" do
          lambda {
            Model.with_joins('foo')
          }.should raise_error(ArgumentError, /joins/)
        end
      end
    end
  end
end
