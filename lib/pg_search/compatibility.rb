module PgSearch
  module Compatibility
    def self.build_quoted(string)
      if defined?(Arel::Nodes::Quoted)
        Arel::Nodes.build_quoted(string)
      else
        string
      end
    end
  end
end
