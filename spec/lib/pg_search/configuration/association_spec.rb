# frozen_string_literal: true

require "spec_helper"

# standard:disable RSpec/NestedGroups
describe PgSearch::Configuration::Association do
  with_model :Avatar do
    table do |t|
      t.string :url
      t.references :user
    end
  end

  with_model :User do
    table do |t|
      t.string :name
      t.belongs_to :site
    end

    model do
      include PgSearch::Model

      has_one :avatar
      belongs_to :site

      pg_search_scope :with_avatar, associated_against: {avatar: :url}
      pg_search_scope :with_site, associated_against: {site: :title}
    end
  end

  with_model :Site do
    table do |t|
      t.string :title
    end

    model do
      include PgSearch::Model

      has_many :users

      pg_search_scope :with_users, associated_against: {users: :name}
    end
  end

  context "with has_one" do
    let(:association) { described_class.new(User, :avatar, :url) }

    describe "#table_name" do
      it "returns the table name for the associated model" do
        expect(association.table_name).to eq Avatar.table_name
      end
    end

    describe "#join" do
      let(:expected_sql) do
        <<~SQL.squish
          LEFT OUTER JOIN
            (SELECT model_id AS id,
                    #{column_select} AS #{association.columns.first.alias}
            FROM "#{User.table_name}"
            INNER JOIN "#{association.table_name}"
            ON "#{association.table_name}"."user_id" = "#{User.table_name}"."id") #{association.subselect_alias}
          ON #{association.subselect_alias}."id" = model_id
        SQL
      end
      let(:column_select) do
        "cast(\"#{association.table_name}\".\"url\" AS text)"
      end

      it "returns the correct SQL join" do
        expect(association.join("model_id")).to eq(expected_sql)
      end
    end
  end

  context "with belongs_to" do
    let(:association) { described_class.new(User, :site, :title) }

    describe "#table_name" do
      it "returns the table name for the associated model" do
        expect(association.table_name).to eq Site.table_name
      end
    end

    describe "#join" do
      let(:expected_sql) do
        <<~SQL.squish
          LEFT OUTER JOIN
            (SELECT model_id AS id,
                    #{column_select} AS #{association.columns.first.alias}
            FROM "#{User.table_name}"
            INNER JOIN "#{association.table_name}"
            ON "#{association.table_name}"."id" = "#{User.table_name}"."site_id") #{association.subselect_alias}
          ON #{association.subselect_alias}."id" = model_id
        SQL
      end
      let(:column_select) do
        "cast(\"#{association.table_name}\".\"title\" AS text)"
      end

      it "returns the correct SQL join" do
        expect(association.join("model_id")).to eq(expected_sql)
      end
    end
  end

  context "with has_many" do
    let(:association) { described_class.new(Site, :users, :name) }

    describe "#table_name" do
      it "returns the table name for the associated model" do
        expect(association.table_name).to eq User.table_name
      end
    end

    describe "#join" do
      let(:expected_sql) do
        <<~SQL.squish
          LEFT OUTER JOIN
            (SELECT model_id AS id,
                    string_agg(cast("#{association.table_name}"."name" AS text), ' ') AS #{association.columns.first.alias}
            FROM "#{Site.table_name}"
            INNER JOIN "#{association.table_name}"
            ON "#{association.table_name}"."site_id" = "#{Site.table_name}"."id"
            GROUP BY model_id) #{association.subselect_alias}
          ON #{association.subselect_alias}."id" = model_id
        SQL
      end

      it "returns the correct SQL join" do
        expect(association.join("model_id")).to eq(expected_sql)
      end

      let(:projected_column) do
        Arel.sql("#{association.subselect_alias}.#{association.columns.first.alias}")
      end
      let(:joined_sites) do
        primary_key = Site.connection.visitor.compile(Site.arel_table[:id])
        Site.joins(association.join(primary_key))
      end

      it "ignores NULL inputs without padding the aggregate" do
        site = Site.create!
        site.users.create!(name: nil)
        site.users.create!(name: "visible")
        site.users.create!(name: nil)

        expect(joined_sites.pluck(projected_column)).to eq ["visible"]
      end

      it "preserves an all-NULL aggregate" do
        site = Site.create!
        site.users.create!(name: nil)
        site.users.create!(name: nil)

        expect(joined_sites.pluck(projected_column)).to eq [nil]
      end

      it "retains the parent when no associated rows exist" do
        site = Site.create!

        expect(joined_sites.pluck(Site.arel_table[:id])).to eq [site.id]
        expect(joined_sites.pluck(projected_column)).to eq [nil]
      end

      describe "#subselect_alias" do
        it "returns a consistent string" do
          subselect_alias = association.subselect_alias
          expect(subselect_alias).to be_a String
          expect(association.subselect_alias).to eq subselect_alias
        end
      end
    end
  end
end
# standard:enable RSpec/NestedGroups
