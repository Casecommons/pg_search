module PgSearch
  class Configuration
    autoload :Association, "pg_search/configuration/association"
    autoload :Column, "pg_search/configuration/column"
    autoload :ForeignColumn, "pg_search/configuration/foreign_column"

    attr_reader :model

    def initialize(options, model)
      @options = default_options.merge(options)
      @model = model

      assert_valid_options(@options)
    end

    class << self
      def alias(*strings)
        name = Array.wrap(strings).compact.join("_")
        # By default, PostgreSQL limits names to 32 characters, so we hash and limit to 32 characters.
        "pg_search_#{Digest::SHA2.hexdigest(name)}"[0,32]
      end
    end

    def columns
      regular_columns + associated_columns
    end

    def regular_columns
      return [] unless options[:against]
      Array(options[:against]).map do |column_name, weight|
        Column.new(column_name, weight, model)
      end
    end

    def associations
      return [] unless options[:associated_against]
      options[:associated_against].map do |association, column_names|
        Association.new(model, association, column_names)
      end.flatten
    end

    def associated_columns
      associations.map(&:columns).flatten
    end

    def query
      options[:query].to_s
    end

    def ignore
      Array.wrap(options[:ignoring])
    end

    def ranking_sql
      options[:ranked_by]
    end

    def features
      Array(options[:using])
    end

    def order_within_rank
      options[:order_within_rank]
    end

    def postgresql_version
      model.connection.send(:postgresql_version)
    end

    private

    attr_reader :options

    def default_options
      {:using => :tsearch}
    end

    VALID_KEYS = %w[
      against ranked_by ignoring using query associated_against order_within_rank
    ].map(&:to_sym)

    VALID_VALUES = {
      :ignoring => [:accents]
    }

    def assert_valid_options(options)
      unless options[:against] || options[:associated_against]
        raise ArgumentError, "the search scope #{@name} must have :against#{" or :associated_against" if defined?(ActiveRecord::Relation)} in its options"
      end

      if options[:associated_against] && !defined?(ActiveRecord::Relation)
        raise ArgumentError, ":associated_against requires Active Record 3 or later"
      end

      options.assert_valid_keys(VALID_KEYS)

      VALID_VALUES.each do |key, values_for_key|
        Array.wrap(options[key]).each do |value|
          unless values_for_key.include?(value)
            raise ArgumentError, ":#{key} cannot accept #{value}"
          end
        end
      end
    end
  end
end
