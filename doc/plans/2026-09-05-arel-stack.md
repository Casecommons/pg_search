# Incremental Arel migration

Replace useful SQL-string construction with composable Arel expressions in five
small, independently mergeable changes. Complete elimination of interpolation is
not required. Each change includes its own caller adaptations and tests; no later
change should be needed to make an earlier one work.

Use `to_arel` for expressions and `to_sql` for rendered SQL strings. Keep behavior
unchanged, including trusted SQL expressions and custom ordering. Preserve the
existing rank-join alias handling. Prefer named immutable values (`Data.define`)
for structured records, while retaining arrays for genuine expression lists.

## Review and test each layer

Before changing code, assess existing coverage and characterize the relevant
behavior. Demonstrate failing coverage for new contracts or missing regressions,
then implement the narrow change. Test SQL execution against PostgreSQL, not just
rendered strings. Run focused examples, the full suite, and Standard for every
layer. Review correctness, coverage quality, and unnecessary complexity before
publishing it.

Exercise expression behavior through `to_arel`. Keep `to_sql` coverage focused on
its rendering-adapter contract, so eventually removing it does not discard the
behavioral coverage or require duplicating that coverage across both interfaces.

- [x] **Column expressions:** add explicit Arel conversions for normal and foreign
  columns, preserving string conversions. Cover NULLs, casts, quoted identifiers,
  and trusted JSON expressions.
- [x] **Association queries:** build aggregated projections and joins with Arel.
  Cover association types, missing associations, aggregation, and alias collisions.
- [ ] **Rank selection and ordering:** convert projections and ordering without
  replacing the existing rank-join fix. Cover selected ranks, tie-breaking,
  custom ordering, associations, and chained scopes.
- [ ] **Feature expressions and normalization:** compose search expressions as
  nodes while preserving sanitization. Cover blank queries, quotes and accents,
  prefix/negation, weighted and stored vectors, highlighting, and other features.
- [ ] **Multisearch rebuilds:** convert useful statement components without forcing
  every fixed SQL fragment into Arel. Cover actual rebuilds, STI, NULL content,
  multiple columns, and custom identifiers.

Record remaining interpolation after the stack as deferred work, not a release
gate. Keep unrelated cleanup, historical planning artifacts, and obsolete
compatibility code out of these changes.
