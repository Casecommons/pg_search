require "spec_helper"

describe PgSearch::Normalizer do
  describe "#add_normalization" do
    context "for PostgreSQL 9.0 and above" do
      context "when config[:ignore] includes :accents" do
        it "wraps the expression in unaccent()" do
          config = stub("config", ignore: [:accents], postgresql_version: 90000)

          normalizer = PgSearch::Normalizer.new(config)
          normalizer.add_normalization("foo").should == "unaccent(foo)"
        end
      end

      context "when config[:ignore] does not include :accents" do
        it "passes the expression through" do
          config = stub("config", ignore: [], postgresql_version: 90000)

          normalizer = PgSearch::Normalizer.new(config)
          normalizer.add_normalization("foo").should == "foo"
        end
      end
    end

    context "for PostgreSQL versions before 9.0" do
      context "when config[:ignore] includes :accents" do
        it "raises a NotSupportedForPostgresqlVersion exception" do
          config = stub("config", ignore: [:accents], postgresql_version: 89999)

          normalizer = PgSearch::Normalizer.new(config)
          expect {
            normalizer.add_normalization("foo")
          }.to raise_exception(PgSearch::NotSupportedForPostgresqlVersion)
        end
      end

      context "when config[:ignore] does not include :accents" do
        it "passes the expression through" do
          config = stub("config", ignore: [], postgresql_version: 90000)

          normalizer = PgSearch::Normalizer.new(config)
          normalizer.add_normalization("foo").should == "foo"
        end
      end
    end
  end
end
