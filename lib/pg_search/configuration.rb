module PgSearch
  class Configuration
    def initialize(options)
      options = options.reverse_merge(default_options)
      assert_valid_options(options)
      @options = options
    end

    def search_columns
      Array(@options[:against])
    end

    def query
      @options[:query].to_s
    end

    def dictionary
      @options[:with_dictionary]
    end

    def normalizations
      Array.wrap(@options[:normalizing])
    end

    def ranking_sql
      @options[:ranked_by]
    end

    def features
      Array(@options[:using])
    end

    private

    def default_options
      {:using => :tsearch}
    end

    def assert_valid_options(options)
      valid_keys = [:against, :ranked_by, :normalizing, :with_dictionary, :using, :query]
      valid_values = {
        :normalizing => [:prefixes, :diacritics]
      }
      raise ArgumentError, "the search scope #{@name} must have :against in its options" unless options[:against]

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
