CREATE OR REPLACE FUNCTION concat_tsvectors(tsv1 tsvector, tsv2 tsvector) RETURNS tsvector AS
$function$ BEGIN
  RETURN tsv1 || tsv2;
END; $function$
LANGUAGE plpgsql;

CREATE AGGREGATE tsvector_agg(tsvector) (
  SFUNC=concat_tsvectors,
  STYPE=tsvector,
  INITCOND=''
);
