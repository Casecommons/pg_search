require "pg_search/features/feature"

require "pg_search/features/dmetaphone"
require "pg_search/features/trigram"
require "pg_search/features/tsearch"

module PgSearch
  module Features
    FEATURE_CLASSES = {
      :dmetaphone => Features::DMetaphone,
      :tsearch => Features::TSearch,
      :trigram => Features::Trigram
    }

    class Builder
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def normalizer
        @normalizer ||= Normalizer.new(config)
      end

      def build(feature_name)
        feature_name = feature_name.to_sym
        feature_class = FEATURE_CLASSES[feature_name]

        raise ArgumentError.new("Unknown feature: #{feature_name}") unless feature_class

        feature_class.new(
          config.query,
          config.feature_options[feature_name],
          config.columns,
          config.model,
          normalizer
        )
      end
    end
  end
end
