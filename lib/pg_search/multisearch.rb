# frozen_string_literal: true

require "pg_search/multisearch/rebuilder"

module PgSearch
  module Multisearch
    class << self
      def rebuild(model, clean_up = true)
        model.transaction do
          PgSearch::Document.where(:searchable_type => model.base_class.name).delete_all if clean_up
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
