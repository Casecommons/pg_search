require "arel/visitors/depth_first"

# Workaround for https://github.com/Casecommons/pg_search/issues/101
# Based on the solution from https://github.com/ernie/squeel/issues/122
Arel::Visitors::DepthFirst.class_eval do
  unless method_defined?(:visit_Arel_Nodes_InfixOperation)
    alias_method :visit_Arel_Nodes_InfixOperation, :binary
  end
end

