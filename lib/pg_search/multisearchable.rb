require "active_support/core_ext/class/attribute"

module PgSearch
  module Multisearchable
    def self.included mod
      mod.class_eval do
        has_one :pg_search_document,
          :as => :searchable,
          :class_name => "PgSearch::Document",
          :dependent => :delete

        after_save :update_pg_search_document,
          :if => lambda { PgSearch.multisearch_enabled? }
      end
    end

    def update_pg_search_document
      if should_have_document?
        create_or_update_document
      else
        destroy_document
      end
    end

    def should_have_document?
      if_conditions.all? { |condition| condition.to_proc.call(self) } &&
      unless_conditions.all? { |condition| !condition.to_proc.call(self) }
    end

    def if_conditions
      Array(pg_search_multisearchable_options[:if])
    end

    def unless_conditions
      Array(pg_search_multisearchable_options[:unless])
    end

    def create_or_update_document
      pg_search_document ? pg_search_document.save : create_pg_search_document
    end

    def destroy_document
      pg_search_document.destroy if pg_search_document
    end
  end
end
