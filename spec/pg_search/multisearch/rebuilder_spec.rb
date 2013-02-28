require "spec_helper"

shared_examples_for "all user defined rebuilds" do |class_name, method_name|
  let(:klass){ Object.const_get(class_name) }

  before(:each) do
    (class << klass; self end).class_eval do
      define_method method_name do
      end
    end
  end

  it "should call .#{method_name}" do
    klass.should_receive(method_name)
    subject.rebuild
  end
end

shared_examples_for "all default rebuilds" do |class_name, method_name|
  let(:klass){ Object.const_get(class_name) }

  it "should not have .#{method_name} class method defined" do
    klass.should_not respond_to(method_name)
  end

  it "should not call .#{method_name}" do
    # stub respond_to? to return false since should_not_receive defines the method
    original_respond_to = klass.method(:respond_to?)
    klass.stub(:respond_to?) do |meth_name, *args|
      if meth_name == method_name
        false
      elsif meth_name == :pg_search_multisearchable_options  # smell that? added for ruby1.8
                                                             # w/out which raises NoMethodError
                                                             #  super: no superclass method
                                                             #  `respond_to?' for
                                                             #  Model(Table doesn't exist):Class
        true
      else
        original_respond_to.call(meth_name, *args)
      end
    end
    klass.should_not_receive(method_name)
    subject.rebuild
  end
end

shared_examples_for "non-optimized rebuilds" do |class_name, doc_class_name|
  let(:klass){ Object.const_get(class_name) }
  let(:doc_klass){ Object.const_get(doc_class_name) }
  let(:document_model_reader){ doc_class_name.underscore.parameterize('_').to_sym }
  let(:update_method_name){ "update_#{doc_class_name.underscore.parameterize('_')}".to_sym }
  let(:rebuild_method_name){ "rebuild_#{doc_class_name.underscore.parameterize('_').pluralize}".to_sym }

  it "calls update_\#{document_object} on each record" do
    # stub respond_to? to return false since should_not_receive defines the method
    original_respond_to = klass.method(:respond_to?)
    klass.stub(:respond_to?) do |method_name, *args|
      if method_name == rebuild_method_name
        false
      elsif method_name.to_s =~ /pg_search_multisearchable_options|logger/ # smell that? added for ruby1.8
                                                                           # w/out which raises NoMethodError
                                                                           #  super: no superclass method
                                                                           #  `respond_to?' for
                                                                           #  Model(Table doesn't exist):Class
        true
      else
        print "\n#{self}\nmethod_name = #{method_name}\nargs = #{args}\n#{original_respond_to}\n"
        original_respond_to.call(method_name, *args)
      end
    end
    klass.should_not_receive(rebuild_method_name)

    subject.rebuild
  end
end

shared_examples_for "optimized rebuilds" do |class_name, doc_class_name|
  let(:klass){ Object.const_get(class_name) }
  let(:doc_klass) do
    unless doc_class_name.nil?
      Object.const_get(doc_class_name)
    else
      PgSearch::Document
    end
  end

  it "should execute the default SQL" do
    expected_sql = <<-SQL
INSERT INTO #{doc_klass.quoted_table_name} (searchable_type, searchable_id, content, created_at, updated_at)
  SELECT '#{class_name}' AS searchable_type,
         #{klass.quoted_table_name}.id AS searchable_id,
         (
           coalesce(#{klass.quoted_table_name}.name::text, '')
         ) AS content,
         '2001-01-01 00:00:00' AS created_at,
         '2001-01-01 00:00:00' AS updated_at
  FROM #{klass.quoted_table_name}
      SQL

    executed_sql = []

    notifier = ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
      executed_sql << payload[:sql]
    end

    subject.rebuild
    ActiveSupport::Notifications.unsubscribe(notifier)

    executed_sql.length.should == 1
    executed_sql.first.should == expected_sql
  end
end

def setup_default_document_model(searchable_class, searchable_opts, method_name=nil)
  with_model searchable_class.to_sym do
    table do |t|
      t.string :name
      t.boolean :active
    end

    model do
      include PgSearch
      multisearchable(searchable_opts)
    end
  end
end

def setup_custom_document_model(doc_class, searchable_class, searchable_opts, method_name=nil)
  with_model doc_class.to_sym do
    table do |t|
      t.belongs_to :searchable, :polymorphic => true
      t.text :content
      t.timestamps
    end
    model do
      include PgSearch
      belongs_to :searchable, :polymorphic => true
    end
  end

  with_model searchable_class.to_sym do
    table do |t|
      t.text :name
    end
    model do
      include PgSearch
      multisearchable({
        doc_class => searchable_opts
      })
    end
  end
end

describe PgSearch::Multisearch::Rebuilder do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  describe "#rebuild" do
    context "when the model does define a .rebuild_\#{your_document_table} class method" do
      context "when multisearchable is not conditional" do
        context "with a custom document model" do
          setup_custom_document_model('DocumentModel', 'CustomModel', {}, :rebuild_document_models)

          subject { PgSearch::Multisearch::Rebuilder.new(CustomModel, nil, DocumentModel) }

          it_behaves_like "all user defined rebuilds", 'CustomModel', :rebuild_document_models
        end

        context "with PgSearch::Document (default)" do
          setup_default_document_model('DefaultModel', {})

          subject { PgSearch::Multisearch::Rebuilder.new(DefaultModel) }

          it_behaves_like "all user defined rebuilds", 'DefaultModel', :rebuild_pg_search_documents
        end
      end

      context "when multisearch is conditional" do
        context "with a custom document model" do
          [:if, :unless].each do |conditional_key|
            context "via :#{conditional_key}" do
              setup_custom_document_model('PublicDocument', 'MyModel', {
                conditional_key => :active?,
                :against => :name
              }, :rebuild_public_documents)

              subject { PgSearch::Multisearch::Rebuilder.new(MyModel, nil, PublicDocument) }

              it_behaves_like "all user defined rebuilds", 'MyModel', :rebuild_public_documents
            end
          end
        end

        context "with PgSearch::Document (default)" do
          [:if, :unless].each do |conditional_key|
            context "via :#{conditional_key}" do
              setup_default_document_model('Model', {
                conditional_key => :active?,
                :against => :name
              }, :rebuild_pg_search_documents)

              subject { PgSearch::Multisearch::Rebuilder.new(Model) }

              it_behaves_like "all user defined rebuilds", 'Model', :rebuild_pg_search_documents
            end
          end
        end
      end
    end

    context "when the model does not define a .rebuild_\#{your_document_table} class method" do
      context "when multisearchable is not conditional" do
        context "with a custom document model" do
          setup_custom_document_model('YourDoc', 'YourModel', {:against => :name})

          subject { PgSearch::Multisearch::Rebuilder.new(YourModel) }

          it_behaves_like "all default rebuilds", 'YourModel', :rebuild_your_docs

          let(:time) { DateTime.parse("2001-01-01") }
          subject { PgSearch::Multisearch::Rebuilder.new(YourModel, lambda { time }, YourDoc) }

          it_behaves_like "optimized rebuilds", 'YourModel', 'YourDoc'
        end

        context "with PgSearch::Document (default)" do
          setup_default_document_model('Model', {:against => :name})

          subject { PgSearch::Multisearch::Rebuilder.new(Model) }

          it_behaves_like "all default rebuilds", 'Model', :rebuild_pg_search_documents

          let(:time) { DateTime.parse("2001-01-01") }
          subject { PgSearch::Multisearch::Rebuilder.new(Model, lambda { time }, PgSearch::Document ) }

          it_behaves_like "optimized rebuilds", 'Model'
        end
      end

      context "when multisearchable is conditional" do
        context "with a custom document model" do
          context "via :if" do
            setup_custom_document_model('CustomDocument','Model', {
              :if => :active?,
              :against => [:name]
            })

            subject { PgSearch::Multisearch::Rebuilder.new(Model, nil, CustomDocument) }
            let(:record1){ Model.create!(:active => true) }
            let(:record2){ Model.create!(:active => false) }

            it_behaves_like "non-optimized rebuilds", 'Model', 'CustomDocument'
          end

          context "via :unless" do
            setup_custom_document_model('CustomDocument', 'Model', {
              :unless => :inactive?,
              :against => :name
            })

            subject { PgSearch::Multisearch::Rebuilder.new(Model, nil, CustomDocument) }
            let(:record1){ Model.create!(:inactive => true) }
            let(:record2){ Model.create!(:inactive => false) }

            it_behaves_like "non-optimized rebuilds", 'Model', 'CustomDocument'
          end
        end

        context "with PgSearch::Document (default)" do
          context "via :if" do
            setup_default_document_model('Model', {
              :if => :active?,
              :against => [:name]
            })

            subject { PgSearch::Multisearch::Rebuilder.new(Model) }
            let(:record1){ Model.create!(:active => true) }
            let(:record2){ Model.create!(:active => false) }

            it_behaves_like "non-optimized rebuilds", 'Model', 'PgSearch::Document'
          end

          context "via :unless" do
            setup_default_document_model('Model', {
              :unless => :inactive?,
              :against => :name
            })

            subject { PgSearch::Multisearch::Rebuilder.new(Model) }
            let(:record1){ Model.create!(:inactive => true) }
            let(:record2){ Model.create!(:inactive => false) }

            it_behaves_like "non-optimized rebuilds", 'Model', 'PgSearch::Document'
          end
        end
      end
    end
  end
end
