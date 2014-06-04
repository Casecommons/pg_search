RSpec::Matchers::BuiltIn::OperatorMatcher.register(
  ActiveRecord::Relation, '=~', RSpec::Matchers::BuiltIn::MatchArray
)
