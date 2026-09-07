# frozen_string_literal: true

require "spec_helper"

# standard:disable RSpec/NestedGroups
describe PgSearch::Normalizer do
  describe "#add_normalization" do
    context "when config[:ignore] includes :accents" do
      context "when passed an Arel node" do
        it "returns an Arel node wrapping the expression in unaccent()" do
          config = instance_double(PgSearch::Configuration, "config", ignore: [:accents])
          node = Arel::Nodes::NamedFunction.new("foo", [Arel::Nodes.build_quoted("bar")])

          normalizer = described_class.new(config)
          result = normalizer.add_normalization(node)
          expect(result).to be_an(Arel::Nodes::Node)
          expect(result.to_sql).to eq("regexp_replace(unaccent(foo('bar')), '[''?\\:]', '', 'g')")
        end

        context "when a custom unaccent function is specified" do
          it "returns an Arel node using that function" do
            allow(PgSearch).to receive(:unaccent_function).and_return("my_unaccent")
            node = Arel::Nodes::NamedFunction.new("foo", [Arel::Nodes.build_quoted("bar")])

            config = instance_double(PgSearch::Configuration, "config", ignore: [:accents])

            normalizer = described_class.new(config)
            result = normalizer.add_normalization(node)
            expect(result).to be_an(Arel::Nodes::Node)
            expect(result.to_sql).to eq("regexp_replace(my_unaccent(foo('bar')), '[''?\\:]', '', 'g')")
          end
        end
      end

      context "when passed a String (trusted SQL expression)" do
        it "returns an Arel node wrapping the expression in unaccent()" do
          config = instance_double(PgSearch::Configuration, "config", ignore: [:accents])

          normalizer = described_class.new(config)
          result = normalizer.add_normalization("foo")
          expect(result).to be_an(Arel::Nodes::Node)
          expect(result.to_sql).to eq("regexp_replace(unaccent(foo), '[''?\\:]', '', 'g')")
        end

        context "when a custom unaccent function is specified" do
          it "returns an Arel node using that function" do
            allow(PgSearch).to receive(:unaccent_function).and_return("my_unaccent")

            config = instance_double(PgSearch::Configuration, "config", ignore: [:accents])

            normalizer = described_class.new(config)
            result = normalizer.add_normalization("foo")
            expect(result).to be_an(Arel::Nodes::Node)
            expect(result.to_sql).to eq("regexp_replace(my_unaccent(foo), '[''?\\:]', '', 'g')")
          end
        end
      end
    end

    it "rejects unsupported inputs instead of turning them into SQL" do
      config = instance_double(PgSearch::Configuration, ignore: [])
      normalizer = described_class.new(config)

      [nil, Object.new, 123].each do |input|
        expect { normalizer.add_normalization(input) }.to raise_error(TypeError)
      end
    end

    context "when config[:ignore] does not include :accents" do
      it "passes the expression through as an Arel-compatible object" do
        config = instance_double(PgSearch::Configuration, "config", ignore: [])

        normalizer = described_class.new(config)
        result = normalizer.add_normalization("foo")
        expect(result).to eq("foo")  # SqlLiteral is a String subclass, usable in Arel contexts
      end
    end
  end

  describe "executed against PostgreSQL" do
    with_model :Book do
      table { |t| t.string :title }
    end

    it "strips accents and disallowed punctuation but preserves backslashes" do
      Book.create!(title: "café's? déjà: vu\\path")
      config = instance_double(PgSearch::Configuration, ignore: [:accents])
      normalizer = described_class.new(config)
      expression = normalizer.add_normalization(Book.arel_table[:title])

      expect(Book.pick(expression)).to eq("cafes deja vu\\path")
    end

    it "preserves attributes when accents are not ignored" do
      book = Book.create!(title: "café's? déjà: vu\\path")
      config = instance_double(PgSearch::Configuration, ignore: [])
      normalizer = described_class.new(config)
      expression = normalizer.add_normalization(Book.arel_table[:title])

      expect(Book.pick(expression)).to eq(book.title)
    end

    it "preserves quoted data rather than interpreting it as SQL" do
      Book.create!
      value = Arel::Nodes.build_quoted("café's? déjà: vu\\path")
      config = instance_double(PgSearch::Configuration, ignore: [])
      normalizer = described_class.new(config)

      expect(normalizer.add_normalization(value)).to equal(value)
      expect(Book.pick(normalizer.add_normalization(value)))
        .to eq("café's? déjà: vu\\path")
    end
  end
end
# standard:enable RSpec/NestedGroups
