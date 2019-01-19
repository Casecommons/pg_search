# frozen_string_literal: true

require "spec_helper"

describe PgSearch::Normalizer do
  describe "#add_normalization" do
    context "when config[:ignore] includes :accents" do
      context "when passed an Arel node" do
        it "wraps the expression in unaccent()" do
          config = double("config", :ignore => [:accents])
          node = Arel::Nodes::NamedFunction.new("foo", [Arel::Nodes.build_quoted("bar")])

          normalizer = PgSearch::Normalizer.new(config)
          expect(normalizer.add_normalization(node)).to eq("unaccent(foo('bar'))")
        end

        context "when a custom unaccent function is specified" do
          it "wraps the expression in that function" do
            allow(PgSearch).to receive(:unaccent_function).and_return("my_unaccent")
            node = Arel::Nodes::NamedFunction.new("foo", [Arel::Nodes.build_quoted("bar")])

            config = double("config", :ignore => [:accents])

            normalizer = PgSearch::Normalizer.new(config)
            expect(normalizer.add_normalization(node)).to eq("my_unaccent(foo('bar'))")
          end
        end
      end

      context "when passed a String" do
        it "wraps the expression in unaccent()" do
          config = double("config", :ignore => [:accents])

          normalizer = PgSearch::Normalizer.new(config)
          expect(normalizer.add_normalization("foo")).to eq("unaccent(foo)")
        end

        context "when a custom unaccent function is specified" do
          it "wraps the expression in that function" do
            allow(PgSearch).to receive(:unaccent_function).and_return("my_unaccent")

            config = double("config", :ignore => [:accents])

            normalizer = PgSearch::Normalizer.new(config)
            expect(normalizer.add_normalization("foo")).to eq("my_unaccent(foo)")
          end
        end
      end
    end

    context "when config[:ignore] does not include :accents" do
      it "passes the expression through" do
        config = double("config", :ignore => [])

        normalizer = PgSearch::Normalizer.new(config)
        expect(normalizer.add_normalization("foo")).to eq("foo")
      end
    end
  end
end
