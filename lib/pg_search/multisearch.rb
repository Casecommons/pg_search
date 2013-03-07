module PgSearch
  module Multisearch
    autoload :Rebuilder, "pg_search/multisearch/rebuilder"

    class << self
      def rebuild(model, clean_up=true)
        model.transaction do
          PgSearch::SearchDocument.where(:searchable_type => model.name).delete_all if clean_up
          Rebuilder.new(model).rebuild
        end
      end
    end

    class ModelNotMultisearchable < StandardError
      def initialize(model_class)
        @model_class = model_class
      end

      def message
        "#{@model_class.name} is not multisearchable. See PgSearch::ClassMethods#multisearchable"
      end
    end
  end
end


