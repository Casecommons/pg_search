require "spec_helper"

describe PgSearch::Multisearch::Rebuilder do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  describe "#rebuild" do
    context "when the model defines .rebuild_pg_search_documents" do
      context "and multisearchable is not conditional" do
        with_model :Model do
          model do
            include PgSearch
            multisearchable

            def rebuild_pg_search_documents
            end
          end
        end

        it "should call .rebuild_pg_search_documents" do
          rebuilder = PgSearch::Multisearch::Rebuilder.new(Model)
          expect(Model).to receive(:rebuild_pg_search_documents)
          rebuilder.rebuild
        end
      end

      context "when multisearch is conditional" do
        [:if, :unless].each do |conditional_key|
          context "via :#{conditional_key}" do
            with_model :Model do
              table do |t|
                t.boolean :active
              end

              model do
                include PgSearch
                multisearchable conditional_key => :active?

                def rebuild_pg_search_documents
                end
              end
            end

            it "should call .rebuild_pg_search_documents" do
              rebuilder = PgSearch::Multisearch::Rebuilder.new(Model)
              expect(Model).to receive(:rebuild_pg_search_documents)
              rebuilder.rebuild
            end
          end
        end
      end
    end

    context "when the model does not define .rebuild_pg_search_documents" do
      context "when multisearchable is not conditional" do
        with_model :Model do
          table do |t|
            t.string :name
          end

          model do
            include PgSearch
            multisearchable :against => :name
          end
        end

        it "should not call :rebuild_pg_search_documents" do
          rebuilder = PgSearch::Multisearch::Rebuilder.new(Model)

          # stub respond_to? to return false since should_not_receive defines the method
          original_respond_to = Model.method(:respond_to?)
          allow(Model).to receive(:respond_to?) do |method_name, *args|
            if method_name == :rebuild_pg_search_documents
              false
            else
              original_respond_to.call(method_name, *args)
            end
          end

          expect(Model).not_to receive(:rebuild_pg_search_documents)
          rebuilder.rebuild
        end

        it "should execute the default SQL" do
          time = DateTime.parse("2001-01-01")
          rebuilder = PgSearch::Multisearch::Rebuilder.new(Model, lambda { time } )

          # Handle change in precision of DateTime objects in SQL in Active Record 4.0.1
          # https://github.com/rails/rails/commit/17f5d8e062909f1fcae25351834d8e89967b645e
          version_4_0_1_or_newer = (
            (ActiveRecord::VERSION::MAJOR > 4) ||
            (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR >= 1) ||
            (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR == 0 && ActiveRecord::VERSION::TINY >= 1)
          )

          expected_timestamp =
            if version_4_0_1_or_newer
              "2001-01-01 00:00:00.000000"
            else
              "2001-01-01 00:00:00"
            end

          expected_sql = <<-SQL.strip_heredoc
            INSERT INTO "pg_search_documents" (searchable_type, searchable_id, content, created_at, updated_at)
              SELECT 'Model' AS searchable_type,
                     #{Model.quoted_table_name}.#{Model.primary_key} AS searchable_id,
                     (
                       coalesce(#{Model.quoted_table_name}.name::text, '')
                     ) AS content,
                     '#{expected_timestamp}' AS created_at,
                     '#{expected_timestamp}' AS updated_at
              FROM #{Model.quoted_table_name}
          SQL

          executed_sql = []

          notifier = ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
            executed_sql << payload[:sql] if payload[:sql].include?(%Q{INSERT INTO "pg_search_documents"})
          end

          rebuilder.rebuild
          ActiveSupport::Notifications.unsubscribe(notifier)

          expect(executed_sql.length).to eq(1)
          expect(executed_sql.first.strip).to eq(expected_sql.strip)
        end

        context "for a model with a non-standard primary key" do
          with_model :ModelWithNonStandardPrimaryKey do
            table primary_key: :non_standard_primary_key do |t|
              t.string :name
            end

            model do
              include PgSearch
              multisearchable :against => :name
            end
          end

          it "generates SQL with the correct primary key" do
            time = DateTime.parse("2001-01-01")
            rebuilder = PgSearch::Multisearch::Rebuilder.new(ModelWithNonStandardPrimaryKey, lambda { time } )

            # Handle change in precision of DateTime objects in SQL in Active Record 4.0.1
            # https://github.com/rails/rails/commit/17f5d8e062909f1fcae25351834d8e89967b645e
            version_4_0_1_or_newer = (
              (ActiveRecord::VERSION::MAJOR > 4) ||
              (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR >= 1) ||
              (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR == 0 && ActiveRecord::VERSION::TINY >= 1)
            )

            expected_timestamp =
              if version_4_0_1_or_newer
                "2001-01-01 00:00:00.000000"
              else
                "2001-01-01 00:00:00"
              end

            expected_sql = <<-SQL.strip_heredoc
              INSERT INTO "pg_search_documents" (searchable_type, searchable_id, content, created_at, updated_at)
                SELECT 'ModelWithNonStandardPrimaryKey' AS searchable_type,
                       #{ModelWithNonStandardPrimaryKey.quoted_table_name}.non_standard_primary_key AS searchable_id,
                       (
                         coalesce(#{ModelWithNonStandardPrimaryKey.quoted_table_name}.name::text, '')
                       ) AS content,
                       '#{expected_timestamp}' AS created_at,
                       '#{expected_timestamp}' AS updated_at
                FROM #{ModelWithNonStandardPrimaryKey.quoted_table_name}
            SQL

            executed_sql = []

            notifier = ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
              executed_sql << payload[:sql] if payload[:sql].include?(%Q{INSERT INTO "pg_search_documents"})
            end

            rebuilder.rebuild
            ActiveSupport::Notifications.unsubscribe(notifier)

            expect(executed_sql.length).to eq(1)
            expect(executed_sql.first.strip).to eq(expected_sql.strip)
          end
        end
      end

      context "when multisearchable is conditional" do
        context "via :if" do
          with_model :Model do
            table do |t|
              t.boolean :active
            end

            model do
              include PgSearch
              multisearchable :if => :active?
            end
          end

          it "calls update_pg_search_document on each record" do
            record1 = Model.create!(:active => true)
            record2 = Model.create!(:active => false)

            rebuilder = PgSearch::Multisearch::Rebuilder.new(Model)

            # stub respond_to? to return false since should_not_receive defines the method
            original_respond_to = Model.method(:respond_to?)
            allow(Model).to receive(:respond_to?) do |method_name, *args|
              if method_name == :rebuild_pg_search_documents
                false
              else
                original_respond_to.call(method_name, *args)
              end
            end
            expect(Model).not_to receive(:rebuild_pg_search_documents)

            rebuilder.rebuild

            expect(record1.pg_search_document).to be_present
            expect(record2.pg_search_document).not_to be_present
          end
        end

        context "via :unless" do
          with_model :Model do
            table do |t|
              t.boolean :inactive
            end

            model do
              include PgSearch
              multisearchable :unless => :inactive?
            end
          end

          it "calls update_pg_search_document on each record" do
            record1 = Model.create!(:inactive => true)
            record2 = Model.create!(:inactive => false)

            rebuilder = PgSearch::Multisearch::Rebuilder.new(Model)

            # stub respond_to? to return false since should_not_receive defines the method
            original_respond_to = Model.method(:respond_to?)
            allow(Model).to receive(:respond_to?) do |method_name, *args|
              if method_name == :rebuild_pg_search_documents
                false
              else
                original_respond_to.call(method_name, *args)
              end
            end
            expect(Model).not_to receive(:rebuild_pg_search_documents)

            rebuilder.rebuild

            expect(record1.pg_search_document).not_to be_present
            expect(record2.pg_search_document).to be_present
          end
        end
      end
    end
  end
end
