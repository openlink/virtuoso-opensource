--
--  tvec_sparql_reduce.sql
--
--  Regression test for SPARQL-side Matryoshka (reduce = 'truncate') vector
--  index DDL. Mirrors the SQL-side reduce tests in tvvec_begin.sql (lines
--  ~165-215) and mtest.sql, but exercises the SPARQL DDL path:
--    sparql create vector index <iri> ... with (reduce = 'truncate', ...)
--
--  Covers both the shorthand (ON GRAPH / FOR PREDICATE) and general
--  (KEY / EMBEDDING / WHERE) selectors.
--
--  Run with:
--    isql <port> dba dba binsrc/tests/suite/tvec_sparql_reduce.sql
--

echo BOTH "STARTED: SPARQL Vector Index Matryoshka reduce=truncate\n";

-- Ensure ONNX_MODELS table exists (may already exist from tvvec_begin.sql)
create table DB.DBA.ONNX_MODELS (
  model_id integer identity,
  model_name varchar not null,
  description varchar,
  model_path varchar not null,
  model_type varchar not null,
  input_names varchar,
  input_shapes varchar,
  output_name varchar,
  output_shape varchar,
  vocab_path varchar,
  max_seq_len integer,
  handle integer,
  created_at datetime,
  updated_at datetime,
  primary key (model_id)
) if not exists;
create unique index ONNX_MODELS_NAME_IDX on DB.DBA.ONNX_MODELS (model_name) if not exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ensure ONNX_MODELS table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Register a deterministic native-dim-8 test model for the reduce tests.
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-reduce-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-sparql-reduce-8', 'deterministic SPARQL reduce test model (native dim 8)',
   'internal:vvec-sparql-reduce-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-sparql-reduce-8 model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: build a native-dim (8) one-hot float vector for insert/search.
create function DB.DBA.TVEC_SPARQL_REDUCE_VEC (in pos integer, in pos2 integer) returns any
{
  declare vec any;
  declare inx integer;
  vec := make_array (8, 'any');
  for (inx := 0; inx < 8; inx := inx + 1)
    aset (vec, inx, 0);
  if (pos is not null and pos >= 0 and pos < 8)
    aset (vec, pos, 1);
  if (pos2 is not null and pos2 >= 0 and pos2 < 8)
    aset (vec, pos2, 1);
  return vec;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_SPARQL_REDUCE_VEC helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: fetch a key-value field from __VEC_INDEX_METRICS output.
create function DB.DBA.TVEC_SPARQL_REDUCE_KV_GET (in kv any, in key_name varchar) returns any
{
  declare inx integer;
  if (not isvector (kv))
    return null;
  for (inx := 0; inx < length (kv); inx := inx + 2)
    {
      if (cast (aref (kv, inx) as varchar) = key_name)
        return aref (kv, inx + 1);
    }
  return null;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_SPARQL_REDUCE_KV_GET helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: insert a native-dim embedding row into a SPARQL vector index by
-- looking up its internal name from the catalog.
create procedure DB.DBA.TVEC_SPARQL_REDUCE_SEED (
  in idx_iri varchar,
  in entity_iri varchar,
  in txt varchar,
  in pos integer,
  in pos2 integer )
{
  declare internal_name, source_table varchar;
  declare rid bigint;
  declare node any;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE
    into internal_name, source_table
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
  rid := iri_id_num (iri_to_id (entity_iri));
  DB.DBA.VEC_INDEX_UPSERT_ROW (source_table, rid, txt, md5 (txt));
  node := __VEC_INDEX_INSERT_EMBEDDING (internal_name, rid, DB.DBA.TVEC_SPARQL_REDUCE_VEC (pos, pos2));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_SPARQL_REDUCE_SEED helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: return the top search hit entity IRI for a native-dim query vector.
create function DB.DBA.TVEC_SPARQL_REDUCE_SEARCH_TOP (
  in idx_iri varchar,
  in pos integer,
  in pos2 integer ) returns varchar
{
  declare internal_name varchar;
  declare res any;
  select SVI_INTERNAL_NAME into internal_name
    from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
  res := __VEC_INDEX_SEARCH (internal_name, DB.DBA.TVEC_SPARQL_REDUCE_VEC (pos, pos2), 1, 8);
  return cast (id_to_iri (iri_id_from_num (cast (aref (aref (res, 0), 0) as bigint))) as varchar);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_SPARQL_REDUCE_SEARCH_TOP helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Seed an RDF graph for the shorthand selector tests.
sparql define input:storage ""
drop silent vector index <urn:reduce:short-idx>
;
sparql define input:storage ""
drop silent vector index <urn:reduce:general-idx>
;
sparql define input:storage ""
clear graph <urn:reduce:graph>
;
sparql define input:storage ""
insert data {
  graph <urn:reduce:graph> {
    <urn:reduce:doc1> <urn:reduce:content> "positions 0 1" .
    <urn:reduce:doc2> <urn:reduce:content> "positions 2 3" .
    <urn:reduce:doc3> <urn:reduce:content> "positions 4 5" .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed reduce test RDF graph STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- Negative 1: reduce = 'truncate' without dimensions must be rejected (VEC73)
-- ===========================================================================
-- The SPARQL QM handler catches the VEC73 signal from SET_OPTIONS; END_CREATE
-- never runs, so VEC_INDEX_ABORT_CREATE (installed as an exit handler in each
-- procedure between BEGIN_CREATE and END_CREATE) removes the 'creating' row
-- along with its backing table and native index.  Assert the absence: a
-- stranded row was the bug -- it was neither active nor reachable through DROP,
-- and it made a retry at the same IRI fail with VEC01 "already exists".
-- count(*) also always returns exactly one row, so the assertion cannot be
-- fooled by $LAST[1] holding a previous statement's value on an empty result.
sparql define input:storage ""
create vector index <urn:reduce:nodim-idx>
  on graph <urn:reduce:graph>
  for predicate <urn:reduce:content>
  using model 'vvec-sparql-reduce-8'
  with (reduce = 'truncate', distance = 'cosine', hnsw_m = 8, ef_construction = 16)
;
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:reduce:nodim-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": reduce=truncate without dimensions rejected, no catalogue residue, rows=" $LAST[1] "\n";

-- ===========================================================================
-- Negative 2: dimensions >= native model dim with reduce='truncate' (VEC74)
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:reduce:wide-idx>
  on graph <urn:reduce:graph>
  for predicate <urn:reduce:content>
  using model 'vvec-sparql-reduce-8'
  with (dimensions = 16, reduce = 'truncate', distance = 'cosine', hnsw_m = 8, ef_construction = 16)
;
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:reduce:wide-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": reduce=truncate with dimensions >= native rejected, no catalogue residue, rows=" $LAST[1] "\n";

-- ===========================================================================
-- Negative 3: reduce = 'bogus' must be rejected (VEC72)
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:reduce:bogus-idx>
  on graph <urn:reduce:graph>
  for predicate <urn:reduce:content>
  using model 'vvec-sparql-reduce-8'
  with (dimensions = 4, reduce = 'bogus', distance = 'cosine', hnsw_m = 8, ef_construction = 16)
;
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:reduce:bogus-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": reduce=bogus rejected, no catalogue residue, rows=" $LAST[1] "\n";

-- ===========================================================================
-- Positive 1: shorthand reduced index (native 8 -> stored 4)
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:reduce:short-idx>
  on graph <urn:reduce:graph>
  for predicate <urn:reduce:content>
  using model 'vvec-sparql-reduce-8'
  with (dimensions = 4, reduce = 'truncate', distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (shorthand reduced) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify catalog fields
select SVI_STATE, SVI_REDUCE, SVI_DIMENSIONS, SVI_MODEL_DIMENSIONS
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:reduce:short-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced catalog state=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] truncate "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced catalog SVI_REDUCE=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] 4 "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced catalog SVI_DIMENSIONS (stored, expect 4)=" $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] 8 "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced catalog SVI_MODEL_DIMENSIONS (native, expect 8)=" $LAST[4] "\n";

-- Verify the native index dimension is the reduced value (4), not the native 8.
select cast (DB.DBA.TVEC_SPARQL_REDUCE_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:reduce:short-idx')),
  'dimension') as varchar);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced native index dimension (expect 4)=" $LAST[1] "\n";

-- Seed native-dim (8) embeddings; the native layer truncates + renormalizes to 4.
DB.DBA.TVEC_SPARQL_REDUCE_SEED ('urn:reduce:short-idx', 'urn:reduce:doc1', 'positions 0 1', 0, 1);
DB.DBA.TVEC_SPARQL_REDUCE_SEED ('urn:reduce:short-idx', 'urn:reduce:doc2', 'positions 2 3', 2, 3);
DB.DBA.TVEC_SPARQL_REDUCE_SEED ('urn:reduce:short-idx', 'urn:reduce:doc3', 'positions 4 5', 4, 5);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced seed native-dim embeddings STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Search with a native-dim (8) query; expect doc1 as nearest (query one-hot
-- at dims 0,1 -> after truncation matches doc1's reduced vector).
select DB.DBA.TVEC_SPARQL_REDUCE_SEARCH_TOP ('urn:reduce:short-idx', 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "urn:reduce:doc1" "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced search top (expect urn:reduce:doc1)=" $LAST[1] "\n";

-- Search with a query matching doc2.
select DB.DBA.TVEC_SPARQL_REDUCE_SEARCH_TOP ('urn:reduce:short-idx', 2, 3);
ECHO BOTH $IF $EQU $LAST[1] "urn:reduce:doc2" "PASSED" "***FAILED";
ECHO BOTH ": shorthand reduced search top (expect urn:reduce:doc2)=" $LAST[1] "\n";

-- REFRESH must succeed (model dim check uses native dim, not stored dim).
sparql define input:storage ""
refresh vector index <urn:reduce:short-idx>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REFRESH VECTOR INDEX (shorthand reduced) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- Positive 2: general selector reduced index (native 8 -> stored 4)
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:reduce:general-idx>
  key ?s
  embedding ?text
  where {
    graph <urn:reduce:graph> {
      ?s <urn:reduce:content> ?text
    }
  }
  using model 'vvec-sparql-reduce-8'
  with (dimensions = 4, reduce = 'truncate', distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (general reduced) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify catalog fields
select SVI_STATE, SVI_REDUCE, SVI_DIMENSIONS, SVI_MODEL_DIMENSIONS
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:reduce:general-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": general reduced catalog state=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] truncate "PASSED" "***FAILED";
ECHO BOTH ": general reduced catalog SVI_REDUCE=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] 4 "PASSED" "***FAILED";
ECHO BOTH ": general reduced catalog SVI_DIMENSIONS (stored, expect 4)=" $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] 8 "PASSED" "***FAILED";
ECHO BOTH ": general reduced catalog SVI_MODEL_DIMENSIONS (native, expect 8)=" $LAST[4] "\n";

-- Verify the native index dimension is the reduced value (4).
select cast (DB.DBA.TVEC_SPARQL_REDUCE_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:reduce:general-idx')),
  'dimension') as varchar);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": general reduced native index dimension (expect 4)=" $LAST[1] "\n";

-- Seed and search.
DB.DBA.TVEC_SPARQL_REDUCE_SEED ('urn:reduce:general-idx', 'urn:reduce:doc1', 'positions 0 1', 0, 1);
DB.DBA.TVEC_SPARQL_REDUCE_SEED ('urn:reduce:general-idx', 'urn:reduce:doc2', 'positions 2 3', 2, 3);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": general reduced seed native-dim embeddings STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TVEC_SPARQL_REDUCE_SEARCH_TOP ('urn:reduce:general-idx', 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "urn:reduce:doc1" "PASSED" "***FAILED";
ECHO BOTH ": general reduced search top (expect urn:reduce:doc1)=" $LAST[1] "\n";

-- REFRESH the general reduced index.
sparql define input:storage ""
refresh vector index <urn:reduce:general-idx>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REFRESH VECTOR INDEX (general reduced) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- Positive 3: non-reduced index still behaves as before (backward compat)
-- ===========================================================================
sparql define input:storage ""
drop silent vector index <urn:reduce:nonreduced-idx>
;
sparql define input:storage ""
create vector index <urn:reduce:nonreduced-idx>
  on graph <urn:reduce:graph>
  for predicate <urn:reduce:content>
  using model 'vvec-sparql-reduce-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (non-reduced backward compat) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SVI_REDUCE, SVI_DIMENSIONS, SVI_MODEL_DIMENSIONS
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:reduce:nonreduced-idx';
ECHO BOTH $IF $EQU $LAST[1] none "PASSED" "***FAILED";
ECHO BOTH ": non-reduced SVI_REDUCE (expect none)=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 8 "PASSED" "***FAILED";
ECHO BOTH ": non-reduced SVI_DIMENSIONS (expect 8)=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] 8 "PASSED" "***FAILED";
ECHO BOTH ": non-reduced SVI_MODEL_DIMENSIONS (expect 8)=" $LAST[3] "\n";

select cast (DB.DBA.TVEC_SPARQL_REDUCE_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:reduce:nonreduced-idx')),
  'dimension') as varchar);
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": non-reduced native index dimension (expect 8)=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
sparql define input:storage ""
drop silent vector index <urn:reduce:short-idx>
;
sparql define input:storage ""
drop silent vector index <urn:reduce:general-idx>
;
sparql define input:storage ""
drop silent vector index <urn:reduce:nonreduced-idx>
;
sparql define input:storage ""
clear graph <urn:reduce:graph>
;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-reduce-8';
drop function DB.DBA.TVEC_SPARQL_REDUCE_SEARCH_TOP;
drop procedure DB.DBA.TVEC_SPARQL_REDUCE_SEED;
drop function DB.DBA.TVEC_SPARQL_REDUCE_KV_GET;
drop function DB.DBA.TVEC_SPARQL_REDUCE_VEC;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": reduce test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: SPARQL Vector Index Matryoshka reduce=truncate\n";
