require "active_support/concern"
require "active_support/core_ext/class/attribute"

module PgSearch
  module Multisearchable
    extend ActiveSupport::Concern

    included do
      has_one :pg_search_document,
        :as => :searchable,
        :class_name => "PgSearch::Document",
        :dependent => :delete

      after_save :update_pg_search_document, :if => :pg_search_enabled?
    end

    def update_pg_search_document
      if_conditions = Array(pg_search_multisearchable_options[:if])
      unless_conditions = Array(pg_search_multisearchable_options[:unless])

      should_have_document =
        if_conditions.all? { |condition| condition.to_proc.call(self) } &&
        unless_conditions.all? { |condition| !condition.to_proc.call(self) }

      if should_have_document
        pg_search_document ? pg_search_document.save : create_pg_search_document
      else
        pg_search_document.destroy if pg_search_document
      end
    end

    def pg_search_enabled?
      ! pg_search_multisearchable_options[:disable_auto_indexing] && PgSearch.multisearch_enabled?
    end
  end
end
