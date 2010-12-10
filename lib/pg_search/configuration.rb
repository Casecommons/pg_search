module PgSearch
  class Configuration
    def initialize(options, model)
      options = options.reverse_merge(default_options)
      assert_valid_options(options)
      @options = options
      @model = model
    end

    def columns
      Array(@options[:against]).map do |column_name, weight|
        Column.new(column_name, weight, @model)
      end
    end

    def query
      @options[:query].to_s
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
      valid_keys = [:against, :ranked_by, :normalizing, :using, :query]
      valid_values = {
        :normalizing => [:diacritics]
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

    class Column
      attr_reader :weight

      def initialize(column_name, weight, model)
        @column_name = column_name
        @weight = weight
        @model = model
      end

      def to_sql
        "coalesce(#{@model.quoted_table_name}.#{@model.connection.quote_column_name(@column_name)}, '')"
      end
    end

  end
end
