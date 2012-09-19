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

      after_save :update_pg_search_document,
        :if => lambda { PgSearch.multisearch_enabled? }
    end

    def update_pg_search_document
      if multisearchable?
        pg_search_document ? pg_search_document.save : create_pg_search_document
      else
        pg_search_document.destroy if pg_search_document
      end
    end
    
    def multisearchable?
      true
    end
  end
end
