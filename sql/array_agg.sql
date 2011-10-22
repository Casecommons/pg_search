CREATE AGGREGATE array_agg(anyelement) (
  SFUNC=array_append,
  STYPE=anyarray,
  INITCOND='{}'
)
