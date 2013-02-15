require "spec_helper"

describe PgSearch::Multisearchable do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  describe "a model that is multisearchable with PgSearch::Document and CustomDocument document models" do
    with_model :CustomDocument do
      table do |t|
        t.text 'content'
        t.belongs_to :searchable, :polymorphic => true
      end

      model do
        include PgSearch
        belongs_to :searchable, :polymorphic => true
        before_validation :update_content
        pg_search_scope :search, lambda { |*args|
          options = if PgSearch.multisearch_options.respond_to?(:call)
            PgSearch.multisearch_options.call(*args)
          else
            {:query => args.first}.merge(PgSearch.multisearch_options)
          end

          {:against => :content}.merge(options)
        }
        def update_content
          methods = Array(searchable.pg_search_multisearchable_options["#{self.class}"][:against])
          searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
          self.content = searchable_text
        end
      end
    end

    with_model :ModelThatIsMultisearchable do
      model do
        include PgSearch
        multisearchable({
          'PgSearch::Document' => {},
          'CustomDocument' => {}
        })
      end
    end

    describe "callbacks" do
      describe "after_create" do
        let(:record) { ModelThatIsMultisearchable.new }

        describe "saving the record" do
          it "should create a PgSearch::Document record" do
            expect { record.save! }.to change(PgSearch::Document, :count).by(1)
          end

          it "should create a CustomDocument record" do
            expect { record.save! }.to change(CustomDocument, :count).by(1)
          end

          context "with multisearch disabled" do
            before { PgSearch.stub(:multisearch_enabled? => false) }

            it "should not create a PgSearch::Document record" do
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end

            it "should not create a CustomDocument record" do
              expect { record.save! }.not_to change(CustomDocument, :count)
            end
          end
        end

        describe "the pg_search_document" do
          it "should be associated to the record" do
            record.save!
            newest_pg_search_document = PgSearch::Document.last
            record.pg_search_document.should == newest_pg_search_document
            newest_pg_search_document.searchable.should == record
          end
        end

        describe "the custom_document" do
          it "should be associated to the record" do
            record.save!
            newest_custom_document = CustomDocument.last
            record.custom_document.should == newest_custom_document
            newest_custom_document.searchable.should == record
          end
        end
      end

      describe "after_update" do
        let!(:record) { ModelThatIsMultisearchable.create! }

        context "when the document is present" do
          before do
           record.pg_search_document.should be_present
           record.custom_document.should be_present
         end

          describe "saving the record" do
            it "calls save on the pg_search_document" do
              record.pg_search_document.should_receive(:save)
              record.save!
            end

            it "calls save on the custom_document" do
              record.custom_document.should_receive(:save)
              record.save!
            end

            it "should not create a PgSearch::Document record" do
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end

            it "should not create a CustomDocument record" do
              expect { record.save! }.not_to change(CustomDocument, :count)
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled? => false) }

              it "should not create a PgSearch::Document record" do
                record.pg_search_document.should_not_receive(:save)
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end

              it "should not create a CustomDocument record" do
                record.custom_document.should_not_receive(:save)
                expect { record.save! }.not_to change(CustomDocument, :count)
              end
            end
          end
        end

        context "when the document is missing" do
          before do
            record.pg_search_document = nil
            record.custom_document = nil
          end

          describe "saving the record" do
            it "should create a PgSearch::Document record" do
              expect { record.save! }.to change(PgSearch::Document, :count).by(1)
            end

            it "should create a CustomDocument record" do
              expect { record.save! }.to change(CustomDocument, :count).by(1)
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled? => false) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end

              it "should not create a CustomDocument record" do
                expect { record.save! }.not_to change(CustomDocument, :count)
              end
            end
          end
        end
      end

      describe "after_destroy" do
        it "should remove its pg_search_document" do
          record = ModelThatIsMultisearchable.create!
          document = record.pg_search_document
          expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
          expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it "should remove its custom_document" do
          record = ModelThatIsMultisearchable.create!
          document = record.custom_document
          expect { record.destroy }.to change(CustomDocument, :count).by(-1)
          expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  describe "a model which is conditionally multisearchable using a Proc" do
    context "via :if" do
      with_model :CustomDocument do
        table do |t|
          t.text 'content'
          t.belongs_to :searchable, :polymorphic => true
        end

        model do
          include PgSearch
          belongs_to :searchable, :polymorphic => true
          before_validation :update_content
          pg_search_scope :search, lambda { |*args|
            options = if PgSearch.multisearch_options.respond_to?(:call)
              PgSearch.multisearch_options.call(*args)
            else
              {:query => args.first}.merge(PgSearch.multisearch_options)
            end

            {:against => :content}.merge(options)
          }
          def update_content
            methods = Array(searchable.pg_search_multisearchable_options["#{self.class}"][:against])
            searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
            self.content = searchable_text
          end
        end
      end

      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :multisearchable
        end

        model do
          include PgSearch
          multisearchable({
            :if => lambda { |record| record.multisearchable? },
            'CustomDocument' => {
              :if => lambda { |record| record.multisearchable? }
            }
          })
        end
      end

      describe "callbacks" do
        describe "after_create" do
          describe "saving the record" do
            context "when the condition is true" do
              let(:record) { ModelThatIsMultisearchable.new(:multisearchable => true) }

              it "should create a PgSearch::Document record" do
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end

              it "should create a CustomDocument record" do
                expect { record.save! }.to change(CustomDocument, :count).by(1)
              end

              context "with multisearch disabled" do
                before { PgSearch.stub(:multisearch_enabled? => false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end

            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:multisearchable => false) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end

              it "should not create a CustomDocument record" do
                expect { record.save! }.not_to change(CustomDocument, :count)
              end
            end
          end
        end

        describe "after_update" do
          let(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          context "when the document is present" do
            before do
              record.pg_search_document.should be_present
              record.custom_document.should be_present
           end

            describe "saving the record" do
              context "when the condition is true" do
                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it "calls save on the custom_document" do
                  record.custom_document.should_receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end

              context "when the condition is false" do
                before { record.multisearchable = false }

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it "calls destroy on the custom_document" do
                  record.custom_document.should_receive(:destroy)
                  record.save!
                end

                it "should remove its pg_search_document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end

                it "should remove its custom_document" do
                  document = record.custom_document
                  expect { record.save! }.to change(CustomDocument, :count).by(-1)
                  expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end

              context "with multisearch disabled" do
                before do
                  PgSearch.stub(:multisearch_enabled? => false)
                  record.pg_search_document.should_not_receive(:save)
                  record.custom_document.should_not_receive(:save)
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end
          end

          context "when the document is missing" do
            before do
              record.pg_search_document = nil
              record.custom_document = nil
            end

            describe "saving the record" do
              context "when the condition is true" do
                it "should create a PgSearch::Document record" do
                  expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                end

                it "should create a CustomDocument record" do
                  expect { record.save! }.to change(CustomDocument, :count).by(1)
                end

                context "with multisearch disabled" do
                  before { PgSearch.stub(:multisearch_enabled? => false) }

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end

                  it "should not create a CustomDocument record" do
                    expect { record.save! }.not_to change(CustomDocument, :count)
                  end
                end
              end

              context "when the condition is false" do
                before { record.multisearchable = false }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end
          end
        end

        describe "after_destroy" do
          let(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          it "should remove its pg_search_document" do
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it "should remove its custom_document" do
            document = record.custom_document
            expect { record.destroy }.to change(CustomDocument, :count).by(-1)
            expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context "using :unless" do
      with_model :CustomDocument do
        table do |t|
          t.text 'content'
          t.belongs_to :searchable, :polymorphic => true
        end

        model do
          include PgSearch
          belongs_to :searchable, :polymorphic => true
          before_validation :update_content
          pg_search_scope :search, lambda { |*args|
            options = if PgSearch.multisearch_options.respond_to?(:call)
              PgSearch.multisearch_options.call(*args)
            else
              {:query => args.first}.merge(PgSearch.multisearch_options)
            end

            {:against => :content}.merge(options)
          }
          def update_content
            methods = Array(searchable.pg_search_multisearchable_options["#{self.class}"][:against])
            searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
            self.content = searchable_text
          end
        end
      end

      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :not_multisearchable
        end

        model do
          include PgSearch
          multisearchable({
            :unless => lambda { |record| record.not_multisearchable? },
            'CustomDocument' => {
              :unless => lambda { |record| record.not_multisearchable? }
            }
          })
        end
      end

      describe "callbacks" do
        describe "after_create" do
          describe "saving the record" do
            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:not_multisearchable => false) }

              it "should create a PgSearch::Document record" do
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end

              it "should create a CustomDocument record" do
                expect { record.save! }.to change(CustomDocument, :count).by(1)
              end

              context "with multisearch disabled" do
                before { PgSearch.stub(:multisearch_enabled? => false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end

            context "when the condition is true" do
              let(:record) { ModelThatIsMultisearchable.new(:not_multisearchable => true) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end

              it "should not create a CustomDocument record" do
                expect { record.save! }.not_to change(CustomDocument, :count)
              end
            end
          end
        end

        describe "after_update" do
          let!(:record) { ModelThatIsMultisearchable.create!(:not_multisearchable => false) }

          context "when the document is present" do
            before { record.pg_search_document.should be_present }

            describe "saving the record" do
              context "when the condition is false" do
                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it "calls save on the custom_document" do
                  record.custom_document.should_receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end

                context "with multisearch disabled" do
                  before do
                    PgSearch.stub(:multisearch_enabled? => false)
                    record.pg_search_document.should_not_receive(:save)
                    record.custom_document.should_not_receive(:save)
                  end

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end

                  it "should not create a CustomDocument record" do
                    expect { record.save! }.not_to change(CustomDocument, :count)
                  end
                end
              end

              context "when the condition is true" do
                before { record.not_multisearchable = true }

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it "calls destroy on the custom_document" do
                  record.custom_document.should_receive(:destroy)
                  record.save!
                end

                it "should remove its pg_search_document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end

                it "should remove its custom_document" do
                  document = record.custom_document
                  expect { record.save! }.to change(CustomDocument, :count).by(-1)
                  expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end

            end
          end

          context "when the document is missing" do
            before do
              record.pg_search_document = nil
              record.custom_document = nil
            end

            describe "saving the record" do
              context "when the condition is false" do
                it "should create a PgSearch::Document record" do
                  expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                end

                it "should create a CustomDocument record" do
                  expect { record.save! }.to change(CustomDocument, :count).by(1)
                end
              end

              context "when the condition is true" do
                before { record.not_multisearchable = true }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end

              context "with multisearch disabled" do
                before { PgSearch.stub(:multisearch_enabled? => false) }
                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end
          end
        end

        describe "after_destroy" do
          it "should remove its pg_search_document" do
            record = ModelThatIsMultisearchable.create!
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it "should remove its custom_document" do
            record = ModelThatIsMultisearchable.create!
            document = record.custom_document
            expect { record.destroy }.to change(CustomDocument, :count).by(-1)
            expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end

  describe "a model which is conditionally multisearchable using a Symbol" do
    context "via :if" do
      with_model :CustomDocument do
        table do |t|
          t.text 'content'
          t.belongs_to :searchable, :polymorphic => true
        end

        model do
          include PgSearch
          belongs_to :searchable, :polymorphic => true
          before_validation :update_content
          pg_search_scope :search, lambda { |*args|
            options = if PgSearch.multisearch_options.respond_to?(:call)
              PgSearch.multisearch_options.call(*args)
            else
              {:query => args.first}.merge(PgSearch.multisearch_options)
            end

            {:against => :content}.merge(options)
          }
          def update_content
            methods = Array(searchable.pg_search_multisearchable_options["#{self.class}"][:against])
            searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
            self.content = searchable_text
          end
        end
      end

      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :multisearchable
        end

        model do
          include PgSearch
          multisearchable({
            :if => :multisearchable?,
            'CustomDocument' => {
              :if => :multisearchable?
            }
          })
        end
      end

      describe "callbacks" do
        describe "after_create" do
          describe "saving the record" do
            context "when the condition is true" do
              let(:record) { ModelThatIsMultisearchable.new(:multisearchable => true) }

              it "should create a PgSearch::Document record" do
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end

              it "should create a CustomDocument record" do
                expect { record.save! }.to change(CustomDocument, :count).by(1)
              end

              context "with multisearch disabled" do
                before { PgSearch.stub(:multisearch_enabled? => false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end

            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:multisearchable => false) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end

              it "should not create a CustomDocument record" do
                expect { record.save! }.not_to change(CustomDocument, :count)
              end
            end
          end
        end

        describe "after_update" do
          let!(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          context "when the document is present" do
            before do
              record.pg_search_document.should be_present
              record.custom_document.should be_present
            end

            describe "saving the record" do
              context "when the condition is true" do
                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it "calls save on the custom_document" do
                  record.custom_document.should_receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end

                context "with multisearch disabled" do
                  before do
                    PgSearch.stub(:multisearch_enabled? => false)
                    record.pg_search_document.should_not_receive(:save)
                    record.custom_document.should_not_receive(:save)
                  end

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end

                  it "should not create a CustomDocument record" do
                    expect { record.save! }.not_to change(CustomDocument, :count)
                  end
                end
              end

              context "when the condition is false" do
                before do
                  record.multisearchable = false
                end

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it "calls destroy on the custom_document" do
                  record.custom_document.should_receive(:destroy)
                  record.save!
                end

                it "should remove its pg_search_document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end

                it "should remove its custom_document" do
                  document = record.custom_document
                  expect { record.save! }.to change(CustomDocument, :count).by(-1)
                  expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end
            end
          end

          context "when the document is missing" do
            before do
              record.pg_search_document = nil
              record.custom_document = nil
            end

            describe "saving the record" do
              context "with multisearch enabled" do
                before { PgSearch.stub(:multisearch_enabled? => true) }

                context "when the condition is true" do
                  it "should create a PgSearch::Document record" do
                    expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                  end

                  it "should create a CustomDocument record" do
                    expect { record.save! }.to change(CustomDocument, :count).by(1)
                  end
                end

                context "when the condition is false" do
                  before { record.multisearchable = false }

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end

                  it "should not create a CustomDocument record" do
                    expect { record.save! }.not_to change(CustomDocument, :count)
                  end
                end
              end

              context "with multisearch disabled" do
                before { PgSearch.stub(:multisearch_enabled? => false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end
          end
        end

        describe "after_destroy" do
          let(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          it "should remove its pg_search_document" do
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it "should remove its custom_document" do
            document = record.custom_document
            expect { record.destroy }.to change(CustomDocument, :count).by(-1)
            expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context "using :unless" do
      with_model :CustomDocument do
        table do |t|
          t.text 'content'
          t.belongs_to :searchable, :polymorphic => true
        end

        model do
          include PgSearch
          belongs_to :searchable, :polymorphic => true
          before_validation :update_content
          pg_search_scope :search, lambda { |*args|
            options = if PgSearch.multisearch_options.respond_to?(:call)
              PgSearch.multisearch_options.call(*args)
            else
              {:query => args.first}.merge(PgSearch.multisearch_options)
            end

            {:against => :content}.merge(options)
          }
          def update_content
            methods = Array(searchable.pg_search_multisearchable_options["#{self.class}"][:against])
            searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
            self.content = searchable_text
          end
        end
      end

      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :not_multisearchable
        end

        model do
          include PgSearch
          multisearchable({
            :unless => :not_multisearchable?,
            'CustomDocument' => {
              :unless => :not_multisearchable?
            }
          })
        end
      end

      describe "callbacks" do
        describe "after_create" do
          describe "saving the record" do
            context "when the condition is true" do
              let(:record) { ModelThatIsMultisearchable.new(:not_multisearchable => true) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end

              it "should not create a CustomDocument record" do
                expect { record.save! }.not_to change(CustomDocument, :count)
              end
            end

            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:not_multisearchable => false) }

              it "should create a PgSearch::Document record" do
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end

              it "should create a CustomDocument record" do
                expect { record.save! }.to change(CustomDocument, :count).by(1)
              end

              context "with multisearch disabled" do
                before { PgSearch.stub(:multisearch_enabled? => false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end
              end
            end
          end
        end

        describe "after_update" do
          let!(:record) { ModelThatIsMultisearchable.create!(:not_multisearchable => false) }

          context "when the document is present" do
            before do
              record.custom_document.should be_present
            end

            describe "saving the record" do
              context "when the condition is true" do
                before { record.not_multisearchable = true }

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it "calls destroy on the custom_document" do
                  record.custom_document.should_receive(:destroy)
                  record.save!
                end

                it "should remove its pg_search_document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end

                it "should remove its custom_document" do
                  document = record.custom_document
                  expect { record.save! }.to change(CustomDocument, :count).by(-1)
                  expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end

              context "when the condition is false" do
                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it "calls save on the custom_document" do
                  record.custom_document.should_receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                it "should not create a CustomDocument record" do
                  expect { record.save! }.not_to change(CustomDocument, :count)
                end

                context "with multisearch disabled" do
                  before do
                    PgSearch.stub(:multisearch_enabled? => false)
                    record.pg_search_document.should_not_receive(:save)
                    record.custom_document.should_not_receive(:save)
                  end

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end

                  it "should not create a CustomDocument record" do
                    expect { record.save! }.not_to change(CustomDocument, :count)
                  end
                end
              end
            end
          end

          context "when the document is missing" do
            before do
              record.pg_search_document = nil
              record.custom_document = nil
            end

            describe "saving the record" do
              context "with multisearch enabled" do
                before { PgSearch.stub(:multisearch_enabled? => true) }

                context "when the condition is true" do
                  before { record.not_multisearchable = true }

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end

                  it "should not create a CustomDocument record" do
                    expect { record.save! }.not_to change(CustomDocument, :count)
                  end
                end

                context "when the condition is false" do
                  it "should create a PgSearch::Document record" do
                    expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                  end

                  it "should create a CustomDocument record" do
                    expect { record.save! }.to change(CustomDocument, :count).by(1)
                  end

                  context "with multisearch disabled" do
                    before { PgSearch.stub(:multisearch_enabled? => false) }

                    it "should not create a PgSearch::Document record" do
                      expect { record.save! }.not_to change(PgSearch::Document, :count)
                    end

                    it "should not create a CustomDocument record" do
                      expect { record.save! }.not_to change(CustomDocument, :count)
                    end
                  end
                end
              end
            end
          end
        end

        describe "after_destroy" do
          let(:record) { ModelThatIsMultisearchable.create!(:not_multisearchable => false) }

          it "should remove its pg_search_document" do
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it "should remove its custom_document" do
            document = record.custom_document
            expect { record.destroy }.to change(CustomDocument, :count).by(-1)
            expect { CustomDocument.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end
end
