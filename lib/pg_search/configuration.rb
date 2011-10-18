require "pg_search/configuration/association"
require "pg_search/configuration/column"

module PgSearch
  class Configuration
    def initialize(options, model)
      options = options.reverse_merge(default_options)
      assert_valid_options(options)
      @options = options
      @model = model
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
      return [] unless @options[:against]
      Array(@options[:against]).map do |column_name, weight|
        Column.new(column_name, weight, @model)
      end
    end

    def associations
      return [] unless @options[:associated_against]
      @options[:associated_against].map do |association, column_names|
        association = Association.new(@model, association, column_names)
        association
      end.flatten
    end

    def associated_columns
      associations.map(&:columns).flatten
    end

    def query
      @options[:query].to_s
    end

    def ignore
      Array.wrap(@options[:ignoring])
    end

    def ranking_sql
      @options[:ranked_by]
    end

    def features
      Array(@options[:using])
    end

    def order_within_rank
      @options[:order_within_rank]
    end

    def postgresql_version
      @model.connection.send(:postgresql_version)
    end

    def logger
      @model.logger
    end

    private

    def default_options
      {:using => :tsearch}
    end

    def assert_valid_options(options)
      valid_keys = [:against, :ranked_by, :ignoring, :using, :query, :associated_against, :order_within_rank]
      valid_values = {
        :ignoring => [:accents]
      }

      unless options[:against] || options[:associated_against]
        raise ArgumentError, "the search scope #{@name} must have :against#{" or :associated_against" if defined?(ActiveRecord::Relation)} in its options"
      end
      raise ArgumentError, ":associated_against requires ActiveRecord 3 or later" if options[:associated_against] && !defined?(ActiveRecord::Relation)

      options.assert_valid_keys(valid_keys)

      valid_values.each do |key, values_for_key|
        Array.wrap(options[key]).each do |value|
          unless values_for_key.include?(value)
            raise ArgumentError, ":#{key} cannot accept #{value}"
          end
        end
      end
    end
  end
end
