require "active_support/concern"

module PgSearch
  module Multisearchable
    extend ActiveSupport::Concern

    included do
      has_one :pg_search_document,
        :as => :searchable,
        :class_name => "PgSearch::Document",
        :dependent => :delete

      after_create :create_pg_search_document
      after_update { self.pg_search_document.save }
    end

    module InstanceMethods
      def search_text
      end
    end
  end
end
