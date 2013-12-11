module PgSearch
  module Compatibility
    module ActiveRecord3
      def pg_search_rank
        read_attribute(:pg_search_rank).to_f
      end
    end
  end
end
