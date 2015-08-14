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

        if ActiveRecord::VERSION::MAJOR < 4 ||
           (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR < 1)

          # For ActiveRecord versions before 4.1 we need to enforce document
          # deletion. If there are any updates to multisearchable object during
          # its destroy process (like, when there is a has_many association
          # with :dependent => :destroy and child associates update their
          # parent state in their own after_destroy hooks), document tends to
          # get recreated even if it has already been deleted.
          #
          # Since 4.1 hook system performs in a more consistent fashion, and we
          # can be less paranoid about such stale documents.
          after_destroy do
            doc = pg_search_document(true)

            doc && doc.destroy
          end
        end
      end
    end

    def update_pg_search_document # rubocop:disable Metrics/AbcSize
      if_conditions = Array(pg_search_multisearchable_options[:if])
      unless_conditions = Array(pg_search_multisearchable_options[:unless])

      should_have_document =
        if_conditions.all? { |condition| condition.to_proc.call(self) } &&
        unless_conditions.all? { |condition| !condition.to_proc.call(self) }

      if should_have_document
        save_pg_search_document
      else
        pg_search_document.destroy if pg_search_document
      end
    end

    private

    def save_pg_search_document
      if pg_search_document
        pg_search_document.save unless pg_search_document.destroyed?
      else
        create_pg_search_document
      end
    end
  end
end
