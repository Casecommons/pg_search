require "spec_helper"

describe PgSearch::Normalizer do
  describe "#add_normalization" do
    context "for PostgreSQL 9.0 and above" do
      context "when config[:ignore] includes :accents" do
        context "when passed an Arel node" do
          it "wraps the expression in unaccent()" do
            config = double("config", :ignore => [:accents], :postgresql_version => 90000)
            node = Arel::Nodes::NamedFunction.new("foo", [PgSearch::Compatibility.build_quoted("bar")])

            normalizer = PgSearch::Normalizer.new(config)
            expect(normalizer.add_normalization(node)).to eq("unaccent(foo('bar'))")
          end

          context "when a custom unaccent function is specified" do
            it "wraps the expression in that function" do
              allow(PgSearch).to receive(:unaccent_function).and_return("my_unaccent")
              node = Arel::Nodes::NamedFunction.new("foo", [PgSearch::Compatibility.build_quoted("bar")])

              config = double("config", :ignore => [:accents], :postgresql_version => 90000)

              normalizer = PgSearch::Normalizer.new(config)
              expect(normalizer.add_normalization(node)).to eq("my_unaccent(foo('bar'))")
            end
          end
        end

        context "when passed a String" do
          it "wraps the expression in unaccent()" do
            config = double("config", :ignore => [:accents], :postgresql_version => 90000)

            normalizer = PgSearch::Normalizer.new(config)
            expect(normalizer.add_normalization("foo")).to eq("unaccent(foo)")
          end

          context "when a custom unaccent function is specified" do
            it "wraps the expression in that function" do
              allow(PgSearch).to receive(:unaccent_function).and_return("my_unaccent")

              config = double("config", :ignore => [:accents], :postgresql_version => 90000)

              normalizer = PgSearch::Normalizer.new(config)
              expect(normalizer.add_normalization("foo")).to eq("my_unaccent(foo)")
            end
          end
        end
      end

      context "when config[:ignore] does not include :accents" do
        it "passes the expression through" do
          config = double("config", :ignore => [], :postgresql_version => 90000)

          normalizer = PgSearch::Normalizer.new(config)
          expect(normalizer.add_normalization("foo")).to eq("foo")
        end
      end
    end

    context "for PostgreSQL versions before 9.0" do
      context "when config[:ignore] includes :accents" do
        it "raises a NotSupportedForPostgresqlVersion exception" do
          config = double("config", :ignore => [:accents], :postgresql_version => 89999)

          normalizer = PgSearch::Normalizer.new(config)
          expect {
            normalizer.add_normalization("foo")
          }.to raise_exception(PgSearch::NotSupportedForPostgresqlVersion)
        end
      end

      context "when config[:ignore] does not include :accents" do
        it "passes the expression through" do
          config = double("config", :ignore => [], :postgresql_version => 90000)

          normalizer = PgSearch::Normalizer.new(config)
          expect(normalizer.add_normalization("foo")).to eq("foo")
        end
      end
    end
  end
end
