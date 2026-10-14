# Composite primary keys in search scopes

Builds on #537 (causztic), which this branch merges onto the Arel-based scope
construction. The merge commit itself supports searching a composite-key model
by its own columns and searching through an association to a composite-key model.

## Contract

`pg_search_scope` works on a model with a composite primary key: ranking joins,
default ordering within rank, and `associated_against` match every key column.
Single-key SQL is unchanged except for internal aliases that callers cannot
reference. Multisearch stays single-key: its `searchable_id` column holds one
value, and Rails already rejects the polymorphic association for a composite key.

- [x] **Spec fixtures:** simplify the merged composite-key spec to ordinary
  domain models, meaningful columns, conventional associations, and examples
  that describe their behavior.
- [ ] **Associations from a composite-key model:** join and group the association
  subquery on every primary-key column, covering aggregated and singular
  associations.

## Verification and delivery

Show each new example failing before its fix. Run the focused specs, the full
suite, and Standard for each commit. Review the branch with independent
reviewers before publishing it as a Casecommons branch and pull request that
credits #537.
