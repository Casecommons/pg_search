DROP AGGREGATE IF EXISTS tsvector_agg(tsvector);

DROP FUNCTION IF EXISTS concat_tsvectors(tsvector, tsvector);
