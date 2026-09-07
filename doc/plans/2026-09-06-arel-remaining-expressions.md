# Remaining Arel expression construction

Continuation of the approved [Arel stack](2026-09-05-arel-stack.md), authorized
for autonomous follow-through while the earlier PRs are reviewed. Preserve
those PR heads; publish new independently green layers above #587.

## Contract

Replace remaining SQL-construction interpolation with composable expressions,
without changing query behavior or existing String-returning adapter contracts.
Do not rewrite ordinary messages, generated names, or PostgreSQL headline-option
data merely to eliminate Ruby interpolation. No new database functions/migrations.

- [x] **Query projections and vectors:** convert ScopeOptions star/highlight/rank
  projections and qualified primary-key rendering, plus TSearch's stored-vector
  references. Preserve explicit select behavior, trusted custom SQL, chained
  aliases, quoted identifiers, and synthetic rank references without accidentally
  applying model attribute aliases.
- [ ] **Column source references:** replace full_name interpolation and the
  aggregate's String-to-Arel round trip with a coherent source-attribute
  expression. Preserve the distinction between a foreign column's original
  association source and its derived search-document alias, non-coalesced
  aggregation, and the existing full_name/to_sql String interfaces.
- [ ] **Final audit:** verify remaining interpolation is intentional data or
  trusted escape-hatch serialization; report residue rather than hiding it.

## Verification and delivery

Characterize meaningful missing behavior before refactoring; no private-helper
specs or test-only visibility subclasses. Simplify touched fixture setup using
normal schema names and Rails conventions. Prefer public database behavior over
additional SQL golden matrices. Run relevant specs and bin/rake independently
for each layer, including the existing pinned Rails-main environment; require
one focused independent review per layer and green hosted CI.

Check each item with its owning code. Keep an empty working commit above the
stack. Until /hi, do not sign; record any new unsigned commits for later signing.
