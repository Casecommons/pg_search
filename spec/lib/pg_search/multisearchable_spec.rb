require "spec_helper"

describe PgSearch::Multisearchable do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

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
          it "should create a PgSearch::Document record" do
            expect { record.save! }.to change(PgSearch::Document, :count).by(1)
          end

          context "with multisearch disabled" do
            before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

            it "should not create a PgSearch::Document record" do
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end
          end
        end

        describe "the document" do
          it "should be associated to the record" do
            record.save!
            newest_pg_search_document = PgSearch::Document.last
            expect(record.pg_search_document).to eq(newest_pg_search_document)
            expect(newest_pg_search_document.searchable).to eq(record)
          end
        end
      end

      describe "after_update" do
        let!(:record) { ModelThatIsMultisearchable.create! }

        context "when the document is present" do
          before { expect(record.pg_search_document).to be_present }

          describe "saving the record" do
            it "calls save on the pg_search_document" do
              expect(record.pg_search_document).to receive(:save)
              record.save!
            end

            it "should not create a PgSearch::Document record" do
              expect { record.save! }.not_to change(PgSearch::Document, :count)
            end

            context "with multisearch disabled" do
              before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

              it "should not create a PgSearch::Document record" do
                expect(record.pg_search_document).not_to receive(:save)
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        context "when the document is missing" do
          before { record.pg_search_document = nil }

          describe "saving the record" do
            it "should create a PgSearch::Document record" do
              expect { record.save! }.to change(PgSearch::Document, :count).by(1)
            end

            context "with multisearch disabled" do
              before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

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

  describe "a model which is conditionally multisearchable using a Proc" do
    context "via :if" do
      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :multisearchable
        end

        model do
          include PgSearch
          multisearchable :if => lambda { |record| record.multisearchable? }
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

              context "with multisearch disabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end

            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:multisearchable => false) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        describe "after_update" do
          let(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          context "when the document is present" do
            before { expect(record.pg_search_document).to be_present }

            describe "saving the record" do
              context "when the condition is true" do
                it "calls save on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end

              context "when the condition is false" do
                before { record.multisearchable = false }

                it "calls destroy on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:destroy)
                  record.save!
                end

                it "should remove its document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end

              context "with multisearch disabled" do
                before do
                  allow(PgSearch).to receive(:multisearch_enabled?).and_return(false)
                end

                it "should not create a PgSearch::Document record" do
                  expect(record.pg_search_document).not_to receive(:save)
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end
          end

          context "when the document is missing" do
            before { record.pg_search_document = nil }

            describe "saving the record" do
              context "when the condition is true" do
                it "should create a PgSearch::Document record" do
                  expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                end

                context "with multisearch disabled" do
                  before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end
                end
              end

              context "when the condition is false" do
                before { record.multisearchable = false }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end
          end
        end

        describe "after_destroy" do
          let(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          it "should remove its document" do
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context "using :unless" do
      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :not_multisearchable
        end

        model do
          include PgSearch
          multisearchable :unless => lambda { |record| record.not_multisearchable? }
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

              context "with multisearch disabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end

            context "when the condition is true" do
              let(:record) { ModelThatIsMultisearchable.new(:not_multisearchable => true) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        describe "after_update" do
          let!(:record) { ModelThatIsMultisearchable.create!(:not_multisearchable => false) }

          context "when the document is present" do
            before { expect(record.pg_search_document).to be_present }

            describe "saving the record" do
              context "when the condition is false" do
                it "calls save on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                context "with multisearch disabled" do
                  before do
                    allow(PgSearch).to receive(:multisearch_enabled?).and_return(false)
                    expect(record.pg_search_document).not_to receive(:save)
                  end

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end
                end
              end

              context "when the condition is true" do
                before { record.not_multisearchable = true }

                it "calls destroy on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:destroy)
                  record.save!
                end

                it "should remove its document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end
            end
          end

          context "when the document is missing" do
            before { record.pg_search_document = nil }

            describe "saving the record" do
              context "when the condition is false" do
                it "should create a PgSearch::Document record" do
                  expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                end
              end

              context "when the condition is true" do
                before { record.not_multisearchable = true }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end

              context "with multisearch disabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

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

  describe "a model which is conditionally multisearchable using a Symbol" do
    context "via :if" do
      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :multisearchable
        end

        model do
          include PgSearch
          multisearchable :if => :multisearchable?
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

              context "with multisearch disabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end

            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:multisearchable => false) }

              it "should not create a PgSearch::Document record" do
                expect { record.save! }.not_to change(PgSearch::Document, :count)
              end
            end
          end
        end

        describe "after_update" do
          let!(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          context "when the document is present" do
            before { expect(record.pg_search_document).to be_present }

            describe "saving the record" do
              context "when the condition is true" do
                it "calls save on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                context "with multisearch disabled" do
                  before do
                    allow(PgSearch).to receive(:multisearch_enabled?).and_return(false)
                    expect(record.pg_search_document).not_to receive(:save)
                  end

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end
                end
              end

              context "when the condition is false" do
                before { record.multisearchable = false }

                it "calls destroy on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:destroy)
                  record.save!
                end

                it "should remove its document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end
            end
          end

          context "when the document is missing" do
            before { record.pg_search_document = nil }

            describe "saving the record" do
              context "with multisearch enabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(true) }

                context "when the condition is true" do
                  it "should create a PgSearch::Document record" do
                    expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                  end
                end

                context "when the condition is false" do
                  before { record.multisearchable = false }

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end
                end
              end

              context "with multisearch disabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end
          end
        end

        describe "after_destroy" do
          let(:record) { ModelThatIsMultisearchable.create!(:multisearchable => true) }

          it "should remove its document" do
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context "using :unless" do
      with_model :ModelThatIsMultisearchable do
        table do |t|
          t.boolean :not_multisearchable
        end

        model do
          include PgSearch
          multisearchable :unless => :not_multisearchable?
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
            end

            context "when the condition is false" do
              let(:record) { ModelThatIsMultisearchable.new(:not_multisearchable => false) }

              it "should create a PgSearch::Document record" do
                expect { record.save! }.to change(PgSearch::Document, :count).by(1)
              end

              context "with multisearch disabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end
              end
            end
          end
        end

        describe "after_update" do
          let!(:record) { ModelThatIsMultisearchable.create!(:not_multisearchable => false) }

          context "when the document is present" do
            before { expect(record.pg_search_document).to be_present }

            describe "saving the record" do
              context "when the condition is true" do
                before { record.not_multisearchable = true }

                it "calls destroy on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:destroy)
                  record.save!
                end

                it "should remove its document" do
                  document = record.pg_search_document
                  expect { record.save! }.to change(PgSearch::Document, :count).by(-1)
                  expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
                end
              end

              context "when the condition is false" do
                it "calls save on the pg_search_document" do
                  expect(record.pg_search_document).to receive(:save)
                  record.save!
                end

                it "should not create a PgSearch::Document record" do
                  expect { record.save! }.not_to change(PgSearch::Document, :count)
                end

                context "with multisearch disabled" do
                  before do
                    allow(PgSearch).to receive(:multisearch_enabled?).and_return(false)
                    expect(record.pg_search_document).not_to receive(:save)
                  end

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end
                end
              end
            end
          end

          context "when the document is missing" do
            before { record.pg_search_document = nil }

            describe "saving the record" do
              context "with multisearch enabled" do
                before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(true) }

                context "when the condition is true" do
                  before { record.not_multisearchable = true }

                  it "should not create a PgSearch::Document record" do
                    expect { record.save! }.not_to change(PgSearch::Document, :count)
                  end
                end

                context "when the condition is false" do
                  it "should create a PgSearch::Document record" do
                    expect { record.save! }.to change(PgSearch::Document, :count).by(1)
                  end

                  context "with multisearch disabled" do
                    before { allow(PgSearch).to receive(:multisearch_enabled?).and_return(false) }

                    it "should not create a PgSearch::Document record" do
                      expect { record.save! }.not_to change(PgSearch::Document, :count)
                    end
                  end
                end
              end
            end
          end
        end

        describe "after_destroy" do
          let(:record) { ModelThatIsMultisearchable.create!(:not_multisearchable => false) }

          it "should remove its document" do
            document = record.pg_search_document
            expect { record.destroy }.to change(PgSearch::Document, :count).by(-1)
            expect { PgSearch::Document.find(document.id) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end
end
