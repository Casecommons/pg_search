module PgSearch
  module Compatibility
    module ActiveRecord3
      def pg_search_rank
        read_attribute(:pg_search_rank).to_f
      end
    end

    def self.build_quoted(string)
      if defined?(Arel::Nodes::Quoted)
        Arel::Nodes.build_quoted(string)
      else
        string
      end
    end
  end
end
