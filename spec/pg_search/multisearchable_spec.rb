require "spec_helper"

describe PgSearch::Multisearchable do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  before { PgSearch.stub(:multisearch_enabled? => true) }

  describe "a model that is multisearchable" do
    with_model :ModelThatIsMultisearchable do
      model do
        include PgSearch
        multisearchable
      end
    end

    describe "callbacks" do
      describe "after_create" do
        let(:record) { ModelThatIsMultisearchable.new }

        describe "saving the record" do
          context "with multisearch enabled" do
            it "should create a PgSearch::Document record" do
              PgSearch.stub(:multisearch_enabled? => true)
              expect { record.save! }.to change(PgSearch::Document, :count).by(1)
            end
          end

          context "with multisearch disabled" do
            it "should not create a PgSearch::Document record" do
              PgSearch.stub(:multisearch_enabled? => false)
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end
          end
        end

        describe "the document" do
          it "should be associated to the record" do
            record.save!
            newest_pg_search_document = PgSearch::Document.last
            record.pg_search_document.should == newest_pg_search_document
            newest_pg_search_document.searchable.should == record
          end
        end
      end

      describe "after_update" do
        let!(:record) { ModelThatIsMultisearchable.create! }

        context "when the document is present" do
          before { record.pg_search_document.should be_present }

          describe "saving the record" do
            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled? => true) }

              it "calls save on the pg_search_document" do
                record.pg_search_document.should_receive(:save)
                record.save!
              end

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end

            context "with multisearch disabled" do
              it "should not create a PgSearch::Document record" do
                PgSearch.stub(:multisearch_enabled? => false)
                record.pg_search_document.should_not_receive(:save)
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        context "when the document is missing" do
          before { record.pg_search_document = nil }

          describe "saving the record" do
            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled? => true) }

              it "should create a PgSearch::Document record" do
                record.stub(:multisearchable? => true)
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled? => false) }
              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end
      end

      describe "after_destroy" do
        it "should remove its document" do
          record = ModelThatIsMultisearchable.create!
          document = record.pg_search_document
          expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
          expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  describe "a model which is conditionally multisearchable via a Proc" do
    with_model :ModelThatIsMultisearchable do
      model do
        include PgSearch
        multisearchable :if => lambda { |record| record.multisearchable? }

        def multisearchable?
          true
        end
      end
    end

    describe "callbacks" do
      describe "after_create" do
        let(:record) { ModelThatIsMultisearchable.new }

        describe "saving the record" do
          context "with multisearch enabled" do
            before { PgSearch.stub(:multisearch_enabled? => true) }

            context "when the record itself is multisearchable" do
              it "should create a PgSearch::Document record" do
                record.stub(:multisearchable? => true)
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end
            end

            context "when the record itself is not multisearchable" do
              it "should not create a PgSearch::Document record" do
                record.stub(:multisearchable? => false)
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end

          context "with multisearch disabled" do
            it "should not create a PgSearch::Document record" do
              PgSearch.stub(:multisearch_enabled? => false)
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end
          end
        end
      end

      describe "after_update" do
        let!(:record) { ModelThatIsMultisearchable.create! }

        context "when the document is present" do
          before { record.pg_search_document.should be_present }

          describe "saving the record" do
            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled? => true) }

              context "when the record itself is multisearchable" do
                before { record.stub(:multisearchable? => true) }

                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end

              context "when the record itself is not multisearchable" do
                before { record.stub(:multisearchable? => false) }

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it "should remove its document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end
            end

            context "with multisearch disabled" do
              before do
                PgSearch.stub(:multisearch_enabled? => false)
                record.pg_search_document.should_not_receive(:save)
              end

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        context "when the document is missing" do
          before { record.pg_search_document = nil }

          describe "saving the record" do
            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled? => true) }

              context "when the record itself is multisearchable" do
                it "should create a PgSearch::Document record" do
                  record.stub(:multisearchable? => true)
                  expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                end
              end

              context "when the record itself is not multisearchable" do
                before { record.stub(:multisearchable? => false) }
                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled? => false) }
              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end
      end

      describe "after_destroy" do
        it "should remove its document" do
          record = ModelThatIsMultisearchable.create!
          document = record.pg_search_document
          expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
          expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  describe "a model which is conditionally multisearchable via a Symbol" do
    with_model :ModelThatIsMultisearchable do
      model do
        include PgSearch
        multisearchable :if => :multisearchable?

        def multisearchable?
          true
        end
      end
    end

    describe "callbacks" do
      describe "after_create" do
        let(:record) { ModelThatIsMultisearchable.new }

        describe "saving the record" do
          context "with multisearch enabled" do
            before { PgSearch.stub(:multisearch_enabled? => true) }

            context "when the record itself is multisearchable" do
              it "should create a PgSearch::Document record" do
                record.stub(:multisearchable? => true)
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end
            end

            context "when the record itself is not multisearchable" do
              it "should not create a PgSearch::Document record" do
                record.stub(:multisearchable? => false)
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end

          context "with multisearch disabled" do
            it "should not create a PgSearch::Document record" do
              PgSearch.stub(:multisearch_enabled? => false)
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end
          end
        end
      end

      describe "after_update" do
        let!(:record) { ModelThatIsMultisearchable.create! }

        context "when the document is present" do
          before { record.pg_search_document.should be_present }

          describe "saving the record" do
            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled? => true) }

              context "when the record itself is multisearchable" do
                before { record.stub(:multisearchable? => true) }

                it "calls save on the pg_search_document" do
                  record.pg_search_document.should_receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end

              context "when the record itself is not multisearchable" do
                before { record.stub(:multisearchable? => false) }

                it "calls destroy on the pg_search_document" do
                  record.pg_search_document.should_receive(:destroy)
                  record.save!
                end

                it "should remove its document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end
            end

            context "with multisearch disabled" do
              before do
                PgSearch.stub(:multisearch_enabled? => false)
                record.pg_search_document.should_not_receive(:save)
              end

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        context "when the document is missing" do
          before { record.pg_search_document = nil }

          describe "saving the record" do
            context "with multisearch enabled" do
              before { PgSearch.stub(:multisearch_enabled? => true) }

              context "when the record itself is multisearchable" do
                it "should create a PgSearch::Document record" do
                  record.stub(:multisearchable? => true)
                  expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                end
              end

              context "when the record itself is not multisearchable" do
                before { record.stub(:multisearchable? => false) }
                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end

            context "with multisearch disabled" do
              before { PgSearch.stub(:multisearch_enabled? => false) }
              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end
      end

      describe "after_destroy" do
        it "should remove its document" do
          record = ModelThatIsMultisearchable.create!
          document = record.pg_search_document
          expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
          expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
