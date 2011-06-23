require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe PgSearch do
  context "joining to another table" do
    context "with Arel support" do
      context "without an :against" do
        with_model :AssociatedModel do
          table do |t|
            t.string "title"
          end
        end

        with_model :ModelWithoutAgainst do
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

        it "returns rows that match the query in the columns of the associated model only" do
          associated = AssociatedModel.create!(:title => 'abcdef')
          included = [
            ModelWithoutAgainst.create!(:title => 'abcdef', :another_model => associated),
            ModelWithoutAgainst.create!(:title => 'ghijkl', :another_model => associated)
          ]
          excluded = [
            ModelWithoutAgainst.create!(:title => 'abcdef')
          ]

          results = ModelWithoutAgainst.with_another('abcdef')
          results.map(&:title).should =~ included.map(&:title)
          results.should_not include(excluded)
        end
      end

      context "through a belongs_to association" do
        with_model :AssociatedModel do
          table do |t|
            t.string 'title'
          end
        end

        with_model :ModelWithBelongsTo do
          table do |t|
            t.string 'title'
            t.belongs_to 'another_model'
          end

          model do
            include PgSearch
            belongs_to :another_model, :class_name => 'AssociatedModel'

            pg_search_scope :with_associated, :against => :title, :associated_against => {:another_model => :title}
          end
        end

        it "returns rows that match the query in either its own columns or the columns of the associated model" do
          associated = AssociatedModel.create!(:title => 'abcdef')
          included = [
            ModelWithBelongsTo.create!(:title => 'ghijkl', :another_model => associated),
            ModelWithBelongsTo.create!(:title => 'abcdef')
          ]
          excluded = ModelWithBelongsTo.create!(:title => 'mnopqr',
                                                   :another_model => AssociatedModel.create!(:title => 'stuvwx'))

          results = ModelWithBelongsTo.with_associated('abcdef')
          results.map(&:title).should =~ included.map(&:title)
          results.should_not include(excluded)
        end
      end

      context "through a has_many association" do
        with_model :AssociatedModelWithHasMany do
          table do |t|
            t.string 'title'
            t.belongs_to 'ModelWithHasMany'
          end
        end

        with_model :ModelWithHasMany do
          table do |t|
            t.string 'title'
          end

          model do
            include PgSearch
            has_many :other_models, :class_name => 'AssociatedModelWithHasMany', :foreign_key => 'ModelWithHasMany_id'

            pg_search_scope :with_associated, :against => [:title], :associated_against => {:other_models => :title}
          end
        end

        it "returns rows that match the query in either its own columns or the columns of the associated model" do
          included = [
            ModelWithHasMany.create!(:title => 'abcdef', :other_models => [
                                        AssociatedModelWithHasMany.create!(:title => 'foo'),
                                        AssociatedModelWithHasMany.create!(:title => 'bar')
          ]),
            ModelWithHasMany.create!(:title => 'ghijkl', :other_models => [
                                        AssociatedModelWithHasMany.create!(:title => 'foo bar'),
                                        AssociatedModelWithHasMany.create!(:title => 'mnopqr')
          ]),
            ModelWithHasMany.create!(:title => 'foo bar')
          ]
          excluded = ModelWithHasMany.create!(:title => 'stuvwx', :other_models => [
                                                 AssociatedModelWithHasMany.create!(:title => 'abcdef')
          ])

          results = ModelWithHasMany.with_associated('foo bar')
          results.map(&:title).should =~ included.map(&:title)
          results.should_not include(excluded)
        end
      end

      context "across multiple associations" do
        context "on different tables" do
          with_model :FirstAssociatedModel do
            table do |t|
              t.string 'title'
              t.belongs_to 'ModelWithManyAssociations'
            end
            model {}
          end

          with_model :SecondAssociatedModel do
            table do |t|
              t.string 'title'
            end
            model {}
          end

          with_model :ModelWithManyAssociations do
            table do |t|
              t.string 'title'
              t.belongs_to 'model_of_second_type'
            end

            model do
              include PgSearch
              has_many :models_of_first_type, :class_name => 'FirstAssociatedModel', :foreign_key => 'ModelWithManyAssociations_id'
              belongs_to :model_of_second_type, :class_name => 'SecondAssociatedModel'

              pg_search_scope :with_associated, :against => :title,
                :associated_against => {:models_of_first_type => :title, :model_of_second_type => :title}
            end
          end

          it "returns rows that match the query in either its own columns or the columns of the associated model" do
            matching_second = SecondAssociatedModel.create!(:title => "foo bar")
            unmatching_second = SecondAssociatedModel.create!(:title => "uiop")

            included = [
              ModelWithManyAssociations.create!(:title => 'abcdef', :models_of_first_type => [
                                                FirstAssociatedModel.create!(:title => 'foo'),
                                                FirstAssociatedModel.create!(:title => 'bar')
            ]),
              ModelWithManyAssociations.create!(:title => 'ghijkl', :models_of_first_type => [
                                                FirstAssociatedModel.create!(:title => 'foo bar'),
                                                FirstAssociatedModel.create!(:title => 'mnopqr')
            ]),
              ModelWithManyAssociations.create!(:title => 'foo bar'),
              ModelWithManyAssociations.create!(:title => 'qwerty', :model_of_second_type => matching_second)
            ]
            excluded = [
              ModelWithManyAssociations.create!(:title => 'stuvwx', :models_of_first_type => [
                                                FirstAssociatedModel.create!(:title => 'abcdef')
            ]),
              ModelWithManyAssociations.create!(:title => 'qwerty', :model_of_second_type => unmatching_second)
            ]

            results = ModelWithManyAssociations.with_associated('foo bar')
            results.map(&:title).should =~ included.map(&:title)
            excluded.each { |object| results.should_not include(object) }
          end
        end

        context "on the same table" do
          with_model :DoublyAssociatedModel do
            table do |t|
              t.string 'title'
              t.belongs_to 'ModelWithDoubleAssociation'
              t.belongs_to 'ModelWithDoubleAssociation_again'
            end
            model {}
          end

          with_model :ModelWithDoubleAssociation do
            table do |t|
              t.string 'title'
            end

            model do
              include PgSearch
              has_many :things, :class_name => 'DoublyAssociatedModel', :foreign_key => 'ModelWithDoubleAssociation_id'
              has_many :thingamabobs, :class_name => 'DoublyAssociatedModel', :foreign_key => 'ModelWithDoubleAssociation_again_id'

              pg_search_scope :with_associated, :against => :title,
                :associated_against => {:things => :title, :thingamabobs => :title}
            end
          end

          it "returns rows that match the query in either its own columns or the columns of the associated model" do
            included = [
              ModelWithDoubleAssociation.create!(:title => 'abcdef', :things => [
                                                    DoublyAssociatedModel.create!(:title => 'foo'),
                                                    DoublyAssociatedModel.create!(:title => 'bar')
            ]),
              ModelWithDoubleAssociation.create!(:title => 'ghijkl', :things => [
                                                    DoublyAssociatedModel.create!(:title => 'foo bar'),
                                                    DoublyAssociatedModel.create!(:title => 'mnopqr')
            ]),
              ModelWithDoubleAssociation.create!(:title => 'foo bar'),
              ModelWithDoubleAssociation.create!(:title => 'qwerty', :thingamabobs => [
                                                    DoublyAssociatedModel.create!(:title => "foo bar")
            ])
            ]
            excluded = [
              ModelWithDoubleAssociation.create!(:title => 'stuvwx', :things => [
                                                    DoublyAssociatedModel.create!(:title => 'abcdef')
            ]),
              ModelWithDoubleAssociation.create!(:title => 'qwerty', :thingamabobs => [
                                                    DoublyAssociatedModel.create!(:title => "uiop")
            ])
            ]

            results = ModelWithDoubleAssociation.with_associated('foo bar')
            results.map(&:title).should =~ included.map(&:title)
            excluded.each { |object| results.should_not include(object) }
          end
        end
      end

      context "against multiple attributes on one association" do
        with_model :AssociatedModel do
          table do |t|
            t.string 'title'
            t.text 'author'
          end
        end

        with_model :ModelWithAssociation do
          table do |t|
            t.belongs_to 'another_model'
          end

          model do
            include PgSearch
            belongs_to :another_model, :class_name => 'AssociatedModel'

            pg_search_scope :with_associated, :associated_against => {:another_model => [:title, :author]}
          end
        end

        it "should only do one join" do
          included = [
            ModelWithAssociation.create!(
              :another_model => AssociatedModel.create!(
                :title => "foo",
                :author => "bar"
              )
            ),
            ModelWithAssociation.create!(
              :another_model => AssociatedModel.create!(
                :title => "foo bar",
                :author => "baz"
              )
            )
          ]
          excluded = [
            ModelWithAssociation.create!(
              :another_model => AssociatedModel.create!(
                :title => "foo",
                :author => "baz"
              )
            )
          ]

          results = ModelWithAssociation.with_associated('foo bar')

          results.to_sql.scan("INNER JOIN").length.should == 1
          included.each { |object| results.should include(object) }
          excluded.each { |object| results.should_not include(object) }
        end

      end
    end
  end
end
