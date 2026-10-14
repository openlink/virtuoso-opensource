--
--  tvec_sparql_begin.sql
--
--  Regression test for SPARQL vector index DDL (Milestone 2: shorthand selector).
--  Tests CREATE/REFRESH/DROP VECTOR INDEX with shorthand selector.
--

echo BOTH "STARTED: SPARQL Vector Index DDL (shorthand)\n";

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

-- Register a test model if not already present
insert soft DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, vocab_path, max_seq_len, created_at, updated_at)
values
  ('granite-384-local', 'local bootstrap model', 'onnx-models/granite-embedding-30m-english/model.onnx', 'text_embedding', 'pooled_output', '1,384', 'onnx-models/granite-embedding-30m-english/vocab.json', 512, now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ensure test model registered STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Test 1: Create vector index with shorthand selector
sparql define input:storage ""
create vector index <http://example/vec/test1>
  on graph <http://example/graph/test>
  for predicate <http://example/pred/content>
  using model 'granite-384-local'
  with (dimensions = 384, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (shorthand) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify catalog record
select SVI_STATE, SVI_SELECTOR_TYPE, SVI_SELECTOR_GRAPH, SVI_SELECTOR_PRED
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test1';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": catalog state after create = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] shorthand "PASSED" "***FAILED";
ECHO BOTH ": selector type = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] http://example/graph/test "PASSED" "***FAILED";
ECHO BOTH ": selector graph = " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] http://example/pred/content "PASSED" "***FAILED";
ECHO BOTH ": selector pred = " $LAST[4] "\n";

-- Refresh an empty selector result set; this exercises stale-key detection
-- without requiring model embedding.
sparql define input:storage ""
refresh vector index <http://example/vec/test1>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REFRESH VECTOR INDEX (empty shorthand selector) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Test 2: Drop the vector index
sparql define input:storage ""
drop vector index <http://example/vec/test1>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DROP VECTOR INDEX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify catalog record is gone
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test1';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": catalog record after drop = " $LAST[1] "\n";

-- Test 3: Drop with SILENT on non-existent index
sparql define input:storage ""
drop silent vector index <http://example/vec/nonexistent>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DROP SILENT VECTOR INDEX (nonexistent) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Test 4: Drop without SILENT on non-existent index should error
-- The QM handler returns the error as a warning row, not a SQL exception.
-- Verify the index still does not exist.
sparql define input:storage ""
drop vector index <http://example/vec/nonexistent2>
;
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/nonexistent2';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": DROP VECTOR INDEX (nonexistent, no silent) - index should not exist, count=" $LAST[1] "\n";

-- Test 5: Create without dimensions
-- When the ONNX plugin is loaded and the model is resolvable, VEC_INDEX_RESOLVE_MODEL
-- infers dimensions from the model's output_shape and the create succeeds (state=active).
-- When the plugin is absent or the model can't be loaded, dims stay 0 and END_CREATE
-- signals VEC21, leaving state=creating. Both outcomes are valid.
sparql define input:storage ""
create vector index <http://example/vec/test2>
  on graph <http://example/graph/test>
  for predicate <http://example/pred/content>
  using model 'granite-384-local'
;
select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test2';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX without dimensions (model inferred) state=" $LAST[1] "\n";

-- Cleanup any leftover
sparql define input:storage ""
drop silent vector index <http://example/vec/test2>
;

-- Test 6: Create vector index with general selector
sparql define input:storage ""
create vector index <http://example/vec/test3>
  key ?s
  embedding ?text
  where {
    graph <http://example/graph/test> {
      ?s <http://example/pred/content> ?text
    }
  }
  using model 'granite-384-local'
  with (dimensions = 384, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (general selector) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify catalog record for general selector
select SVI_STATE, SVI_SELECTOR_TYPE, SVI_KEY_VAR, SVI_EMBEDDING_VAR
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test3';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": general selector state after create = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] general "PASSED" "***FAILED";
ECHO BOTH ": general selector type = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] s "PASSED" "***FAILED";
ECHO BOTH ": general selector key var = " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] text "PASSED" "***FAILED";
ECHO BOTH ": general selector embedding var = " $LAST[4] "\n";

-- Verify WHERE text is stored
select length (SVI_WHERE_TEXT) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test3';
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": general selector WHERE text length = " $LAST[1] "\n";

-- Test 7: Drop the general selector vector index
sparql define input:storage ""
drop vector index <http://example/vec/test3>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DROP VECTOR INDEX (general selector) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Test 8: Create with KEY = EMBEDDING (same variable) should error
sparql define input:storage ""
create vector index <http://example/vec/test4>
  key ?s
  embedding ?s
  where {
    graph <http://example/graph/test> {
      ?s <http://example/pred/content> ?s
    }
  }
  using model 'granite-384-local'
  with (dimensions = 384, distance = 'cosine')
;
-- VEC09 refuses the create, and VEC_INDEX_ABORT_CREATE removes the 'creating'
-- row it had already inserted, so nothing is left behind.  count(*) rather than
-- SVI_STATE: it always returns one row, so the assertion cannot silently read a
-- previous statement's value out of $LAST[1] when the result set is empty.
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test4';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (KEY=EMBEDDING) rejected, no catalogue residue, rows=" $LAST[1] "\n";

-- Test 8b: DROP VECTOR INDEX on an index stuck in 'error' state (regression for VEC90 trap)
-- Create a valid index, force SVI_STATE = 'error', then drop it.
sparql define input:storage ""
create vector index <http://example/vec/test_err>
  on graph <http://example/graph/test>
  for predicate <http://example/pred/content>
  using model 'granite-384-local'
  with (dimensions = 384, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test8b CREATE VECTOR INDEX for error-state test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify it is active
select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test_err';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": Test8b index is active before forcing error state=" $LAST[1] "\n";

-- Capture source_table name for later verification
select SVI_SOURCE_TABLE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test_err';

-- Force the state to 'error' to simulate a failed CREATE/REFRESH
update DB.DBA.SPARQL_VEC_INDEX set SVI_STATE = 'error', SVI_LAST_ERROR = 'simulated failure'
  where SVI_IRI = 'http://example/vec/test_err';
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test8b force SVI_STATE=error STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Drop the error-state index; before the fix this would signal VEC90
sparql define input:storage ""
drop vector index <http://example/vec/test_err>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test8b DROP VECTOR INDEX on error-state index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Verify catalog row is gone
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'http://example/vec/test_err';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Test8b catalog row after drop = " $LAST[1] "\n";

-- Verify work queue entries are gone
select count(*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'http://example/vec/test_err';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Test8b queue entries after drop = " $LAST[1] "\n";

-- Test 9: VEC_INDEX_SEARCH function should return empty for non-existent index
select DB.DBA.VEC_INDEX_SEARCH ('http://example/vec/nonexistent', 'test', 10, 100);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VEC_INDEX_SEARCH on non-existent index should error STATE=" $STATE "\n";

-- Test 10: VEC_INDEX_DISTANCE_TO_SCORE function: 1 - distance / 2 for cosine,
-- the scale SQL's X_SIMILAR uses (it was 1 - distance, 0.7 here).
select DB.DBA.VEC_INDEX_DISTANCE_TO_SCORE ('cosine', 0.3);
ECHO BOTH $IF $EQU $LAST[1] 0.85 "PASSED" "***FAILED";
ECHO BOTH ": cosine score for distance 0.3 = " $LAST[1] "\n";

select DB.DBA.VEC_INDEX_DISTANCE_TO_SCORE ('l2', 0.5);
ECHO BOTH $IF $EQU $LAST[1] 0.666666666666667 "PASSED" "***FAILED";
ECHO BOTH ": l2 score for distance 0.5 = " $LAST[1] "\n";

-- Test 11: Async queue suspend/resume
DB.DBA.VEC_INDEX_QUEUE_SUSPEND ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": queue suspend STATE=" $STATE "\n";

select DB.DBA.VEC_INDEX_QUEUE_IS_SUSPENDED ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": queue is suspended = " $LAST[1] "\n";

-- Drain should return 0 when suspended
select DB.DBA.VEC_INDEX_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": queue drain when suspended = " $LAST[1] "\n";

DB.DBA.VEC_INDEX_QUEUE_RESUME ();
select DB.DBA.VEC_INDEX_QUEUE_IS_SUSPENDED ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": queue is resumed = " $LAST[1] "\n";

-- Test 12: Drain on empty queue
select DB.DBA.VEC_INDEX_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": queue drain on empty = " $LAST[1] "\n";

-- Test 13: Enqueue on non-existent index (should be no-op)
DB.DBA.VEC_INDEX_ENQUEUE ('http://example/vec/nonexistent', 123);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": enqueue on non-existent index is no-op STATE=" $STATE "\n";

-- Q6: public bif:vector_search predicate coverage.
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-test-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-sparql-test-8', 'deterministic SPARQL vector-search test model', 'internal:vvec-sparql-test-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 register deterministic SPARQL test model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.TVEC_SPARQL_Q6_RESULT_LIST (in q varchar) returns varchar
{
  declare st, msg, out_str varchar;
  declare md, rows any;
  declare inx, len integer;
  st := '00000';
  exec (q, st, msg, vector (), 10000, md, rows);
  if (st <> '00000' and st <> 'OK')
    return sprintf ('ERROR:%s:%s', st, msg);
  out_str := '';
  len := length (rows);
  for (inx := 0; inx < len; inx := inx + 1)
    {
      if (inx > 0)
        out_str := out_str || ',';
      out_str := out_str || cast (rows[inx][0] as varchar);
    }
  return out_str;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 create result-list helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.TVEC_SPARQL_Q6_COUNT_AS_USER (in uname varchar, in passwd varchar, in q varchar) returns integer
{
  declare st, msg varchar;
  declare md, rows any;
  declare exit handler for sqlstate '*'
    {
      set_user_id ('dba', 1);
      return -1;
    };
  st := '00000';
  set_user_id (uname, 1, passwd);
  exec (q, st, msg, vector (), 10000, md, rows);
  set_user_id ('dba', 1);
  if (st <> '00000' and st <> 'OK')
    return -1;
  return length (rows);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 create as-user helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.TVEC_SPARQL_Q6_SEED_HIT (
  in idx_iri varchar,
  in entity_iri varchar,
  in txt varchar,
  in pos1 integer,
  in pos2 integer )
{
  declare internal_name, source_table varchar;
  declare rid bigint;
  declare node any;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE
    into internal_name, source_table
    from DB.DBA.SPARQL_VEC_INDEX
    where SVI_IRI = idx_iri;
  rid := iri_id_num (iri_to_id (entity_iri));
  DB.DBA.VEC_INDEX_UPSERT_ROW (source_table, rid, txt, md5 (txt));
  node := __VEC_INDEX_INSERT_TEST_EMBEDDING (internal_name, rid, pos1, pos2);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 create seed helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage ""
drop silent vector index <urn:q6:idx>
;
sparql define input:storage ""
drop silent vector index <urn:q6:idx2>
;
sparql define input:storage ""
clear graph <urn:q6:graph>
;
sparql define input:storage ""
insert data {
  graph <urn:q6:graph> {
    <urn:q6:doc1> <urn:q6:content> "positions 1" .
    <urn:q6:doc2> <urn:q6:content> "positions 5 6" .
    <urn:q6:doc3> <urn:q6:content> "positions 5" .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 seed RDF graph STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage ""
create vector index <urn:q6:idx>
  on graph <urn:q6:graph>
  for predicate <urn:q6:content>
  using model 'vvec-sparql-test-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 create vector-search index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TVEC_SPARQL_Q6_SEED_HIT ('urn:q6:idx', 'urn:q6:doc1', 'positions 1', 1, -1);
DB.DBA.TVEC_SPARQL_Q6_SEED_HIT ('urn:q6:idx', 'urn:q6:doc2', 'positions 5 6', 5, 6);
DB.DBA.TVEC_SPARQL_Q6_SEED_HIT ('urn:q6:idx', 'urn:q6:doc3', 'positions 5', 5, -1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 seed deterministic ANN rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TVEC_SPARQL_Q6_RESULT_LIST (
  'sparql define input:storage "" select ?s where { ?s bif:vector_search "positions 5 6" option (index <urn:q6:idx>, limit 3, ef_search 8) }'
);
ECHO BOTH $IF $EQU $LAST[1] "urn:q6:doc2,urn:q6:doc3,urn:q6:doc1" "PASSED" "***FAILED";
ECHO BOTH ": Q6 vector_search explicit-index order=" $LAST[1] "\n";

select count (*)
  from (sparql define input:storage "" select ?s ?score ?distance where {
    ?s bif:vector_search "positions 5 6"
      option (index <urn:q6:idx>, score ?score, distance ?distance,
              score_limit 0.999999, distance_limit 0.000001, limit 3, ef_search 8)
  }) as sub
  where "score" >= 0.999999
    and "distance" >= -0.000001
    and "distance" <= 0.000001;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Q6 all options and inclusive score/distance boundaries rows=" $LAST[1] "\n";

select DB.DBA.TVEC_SPARQL_Q6_RESULT_LIST (
  'sparql define input:storage "" select ?s where { ?s bif:vector_search "positions 5 6" option (limit 1, ef_search 8) }'
);
ECHO BOTH $IF $EQU $LAST[1] "urn:q6:doc2" "PASSED" "***FAILED";
ECHO BOTH ": Q6 inferred single index result=" $LAST[1] "\n";

select __VEC_INDEX_QUERY_TEXT_VECTOR_CALLS (1);
select DB.DBA.TVEC_SPARQL_Q6_RESULT_LIST (
  'sparql define input:storage "" select ?s where { ?s bif:vector_search "positions 5 6" option (index <urn:q6:idx>, limit 1, ef_search 8) }'
);
select __VEC_INDEX_QUERY_TEXT_VECTOR_CALLS (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Q6 vector_search embeds query text once count=" $LAST[1] "\n";

-- Q6: Direct SQL VEC_INDEX_SEARCH returns hits (regression for VEC_INDEX_EMBED_TEXTS format mismatch)
create function DB.DBA.TVEC_SPARQL_Q6_VEC_SEARCH_LIST (
  in idx_iri varchar,
  in query_text varchar,
  in limit_count integer,
  in ef_search integer ) returns varchar
{
  declare hits any;
  declare i, len integer;
  declare out_str varchar;
  hits := DB.DBA.VEC_INDEX_SEARCH (idx_iri, query_text, limit_count, ef_search);
  if (hits is null)
    return '';
  out_str := '';
  len := length (hits);
  for (i := 0; i < len; i := i + 1)
    {
      if (i > 0)
        out_str := out_str || ',';
      out_str := out_str || cast (id_to_iri (iri_id_from_num (cast (hits[i][0] as bigint))) as varchar);
    }
  return out_str;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 create VEC_INDEX_SEARCH helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TVEC_SPARQL_Q6_VEC_SEARCH_LIST ('urn:q6:idx', 'positions 5 6', 3, 8);
ECHO BOTH $IF $EQU $LAST[1] "urn:q6:doc2,urn:q6:doc3,urn:q6:doc1" "PASSED" "***FAILED";
ECHO BOTH ": Q6 VEC_INDEX_SEARCH direct SQL hit order=" $LAST[1] "\n";

select length (DB.DBA.VEC_INDEX_SEARCH ('urn:q6:idx', 'positions 1', 1, 8));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Q6 VEC_INDEX_SEARCH single-hit result count=" $LAST[1] "\n";

sparql define input:storage ""
create vector index <urn:q6:idx2>
  on graph <urn:q6:graph>
  for predicate <urn:q6:content>
  using model 'vvec-sparql-test-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
sparql define input:storage ""
select ?s where { ?s bif:vector_search "positions 5 6" option (limit 1, ef_search 8) }
;
ECHO BOTH $IF $EQU $STATE VEC59 "PASSED" "***FAILED";
ECHO BOTH ": Q6 omitted index is ambiguous STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
sparql define input:storage ""
drop silent vector index <urn:q6:idx2>
;

select case when strstr (cast (sparql_to_sql_text (
  'select ?s where { ?s bif:vector_search "positions 5 6" option (index <urn:q6:idx>, limit 1, ef_search 8) }') as varchar),
  'VEC_INDEX_SEARCH_ROWS') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Q6 generated SQL uses vector-search row source flag=" $LAST[1] "\n";

select case when strstr (cast (sparql_to_sql_text (
  'select ?s where { ?s bif:vector_search "positions 5 6" option (index <urn:q6:idx>, limit 1, ef_search 8) }') as varchar),
  '__VEC_INDEX_ROW_SIMILARITY') is null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Q6 generated SQL avoids scalar row-similarity scan flag=" $LAST[1] "\n";

delete from DB.DBA.SYS_ROLE_GRANTS
  where GI_SUPER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'Q6_VEC_USER')
     or GI_SUB = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'Q6_VEC_USER');
delete from DB.DBA.SYS_USERS where U_NAME = 'Q6_VEC_USER';
DB.DBA.USER_CREATE ('Q6_VEC_USER', 'Q6_VEC_USER', vector ('SQL_ENABLE', 1));
grant SPARQL_SELECT to Q6_VEC_USER;
DB.DBA.RDF_GRAPH_GROUP_CREATE ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 1);
DB.DBA.RDF_GRAPH_GROUP_INS ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:q6:graph');
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('Q6_VEC_USER', 0, 1);
select DB.DBA.TVEC_SPARQL_Q6_COUNT_AS_USER (
  'Q6_VEC_USER',
  'Q6_VEC_USER',
  'sparql define input:storage "" select ?s where { ?s bif:vector_search "positions 5 6" option (index <urn:q6:idx>, limit 3, ef_search 8) }'
);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Q6 non-DBA unreadable graph vector_search rows=" $LAST[1] "\n";

DB.DBA.RDF_GRAPH_GROUP_DEL ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:q6:graph');
DB.DBA.RDF_DEFAULT_USER_PERMS_DEL ('Q6_VEC_USER', 1);
delete from DB.DBA.SYS_ROLE_GRANTS
  where GI_SUPER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'Q6_VEC_USER')
     or GI_SUB = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'Q6_VEC_USER');
delete from DB.DBA.SYS_USERS where U_NAME = 'Q6_VEC_USER';

sparql define input:storage ""
drop silent vector index <urn:q6:idx>
;
sparql define input:storage ""
clear graph <urn:q6:graph>
;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-test-8';
drop procedure DB.DBA.TVEC_SPARQL_Q6_SEED_HIT;
drop function DB.DBA.TVEC_SPARQL_Q6_COUNT_AS_USER;
drop function DB.DBA.TVEC_SPARQL_Q6_RESULT_LIST;
drop function DB.DBA.TVEC_SPARQL_Q6_VEC_SEARCH_LIST;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Q6 cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Test 14: Multi-valued subject determinism — the full backfill and the
-- incremental drain re-eval both select MIN(str(?text)) per subject, so a
-- re-eval of unchanged data yields need_update = 0 (no re-embed).
-- Regression for RV_TEXT_HASH thrash when SAMPLE (non-deterministic) was used.
insert soft DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-sparql-test-min', 'deterministic test model for MIN selector test', 'internal:vvec-sparql-test-min', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14 register test model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage ""
drop silent vector index <urn:test-min:idx>
;
sparql define input:storage ""
clear graph <urn:test-min:graph>
;
sparql define input:storage ""
insert data {
  graph <urn:test-min:graph> {
    <urn:test-min:doc1> <urn:test-min:content> "zzz text" .
    <urn:test-min:doc1> <urn:test-min:content> "aaa text" .
    <urn:test-min:doc1> <urn:test-min:content> "mmm text" .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14 seed multi-valued subject STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage ""
create vector index <urn:test-min:idx>
  on graph <urn:test-min:graph>
  for predicate <urn:test-min:content>
  using model 'vvec-sparql-test-min'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14 CREATE VECTOR INDEX (multi-valued) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: run both selector paths for a subject, store the full-backfill hash,
-- then check whether the incremental path's hash matches (need_update = 0).
-- Returns 0 on success (both agree, no re-embed needed).
create function DB.DBA.TVEC_SPARQL_MIN_TEST (in idx_iri varchar, in graph_iri varchar, in pred_iri varchar, in subj_iri varchar) returns integer
{
  declare source_table varchar;
  declare kid bigint;
  declare full_text, incr_text varchar;
  declare st, msg varchar;
  declare md, qr any;
  declare need_update integer;

  select SVI_SOURCE_TABLE into source_table from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
  kid := iri_id_num (iri_to_id (subj_iri));

  -- Full backfill selector: MIN(str(?text)) group by ?s
  st := '00000';
  exec (
    sprintf (
      'select cast ("text" as varchar) from (sparql define input:storage "" ' ||
      'select ?s (MIN (str (?text))) as ?text where { graph <%s> { ?s <%s> ?text } } group by ?s) as sub ' ||
      'where iri_id_num (iri_to_id ("s")) = %d',
      graph_iri, pred_iri, kid),
    st, msg, vector (), 10000, md, qr);
  if (st <> '00000' and st <> 0)
    return -1;
  if (length (qr) = 0)
    return -2;
  full_text := cast (qr[0][0] as varchar);

  -- Incremental re-eval: exactly the query the async drain runs for a single
  -- key -- MIN(str(?text)) grouped by subject, restricted to this key in the
  -- OUTER SQL.  (An earlier version used 'order by str(?o) limit 1' spliced as
  -- '... from sparql <select> ...', which is invalid both as SQL -- ?o is not a
  -- column -- and, with an iri_id_num() filter, as SPARQL.)  Both the backfill
  -- and the incremental path selecting MIN(str()) is precisely what makes the
  -- re-eval deterministic, so a hash-stable re-eval needs no re-embed.
  st := '00000';
  exec (
    sprintf (
      'select cast ("text" as varchar) from (sparql define input:storage "" ' ||
      'select ?s (MIN (str (?text))) as ?text where { graph <%s> { ?s <%s> ?text } } group by ?s) as sub ' ||
      'where iri_id_num (iri_to_id ("s")) = %d',
      graph_iri, pred_iri, kid),
    st, msg, vector (), 10000, md, qr);
  if (st <> '00000' and st <> 0)
    return -3;
  if (length (qr) = 0)
    return -4;
  incr_text := cast (qr[0][0] as varchar);

  -- Both paths must select the same value
  if (full_text <> incr_text)
    return -5;

  -- Simulate full-backfill hash storage
  DB.DBA.VEC_INDEX_UPSERT_ROW (source_table, kid, full_text, md5 (full_text));

  -- Check: would incremental re-evaluation need an update?
  need_update := DB.DBA.VEC_INDEX_CHECK_HASH (source_table, kid, md5 (incr_text));
  return need_update;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14 create MIN test helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Both selector paths must agree: need_update = 0 (no re-embed)
select DB.DBA.TVEC_SPARQL_MIN_TEST ('urn:test-min:idx', 'urn:test-min:graph', 'urn:test-min:content', 'urn:test-min:doc1');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Test14 need_update = 0 (full backfill MIN == incremental MIN) = " $LAST[1] "\n";

-- End-to-end: enqueue the key (simulates trigger fire with no data change) and drain.
-- With the fix, the incremental path finds hash matches and skips embedding,
-- so the queue item is processed successfully (not left in error state).
DB.DBA.VEC_INDEX_ENQUEUE ('urn:test-min:idx', iri_id_num (iri_to_id ('urn:test-min:doc1')));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14 enqueue key for incremental re-eval STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_INDEX_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Test14 queue drain processed count=" $LAST[1] "\n";

select count(*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:test-min:idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Test14 queue empty after drain (no re-embed error) count=" $LAST[1] "\n";

-- Test 14b: Mixed-datatype subject — both the backfill and the incremental
-- re-eval select MIN(str(?text)) per subject, so they agree even when the
-- predicate carries heterogeneous datatypes (plain string, number, language-
-- tagged string).  SPARQL term-ordering (by datatype group, then typed value)
-- would diverge from lexical ordering for mixed datatypes; wrapping every value
-- in str() before MIN keeps both paths deterministic and equal.
sparql define input:storage ""
clear graph <urn:test-min:mixed-graph>
;
sparql define input:storage ""
insert data {
  graph <urn:test-min:mixed-graph> {
    <urn:test-min:doc2> <urn:test-min:content> "zebra" .
    <urn:test-min:doc2> <urn:test-min:content> 42 .
    <urn:test-min:doc2> <urn:test-min:content> "apple"@en .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14b seed mixed-datatype subject STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage ""
create vector index <urn:test-min:mixed-idx>
  on graph <urn:test-min:mixed-graph>
  for predicate <urn:test-min:content>
  using model 'vvec-sparql-test-min'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14b CREATE VECTOR INDEX (mixed-datatype) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Both selector paths must agree on the mixed-datatype subject: need_update = 0
select DB.DBA.TVEC_SPARQL_MIN_TEST ('urn:test-min:mixed-idx', 'urn:test-min:mixed-graph', 'urn:test-min:content', 'urn:test-min:doc2');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Test14b need_update = 0 (mixed-datatype full backfill MIN == incremental MIN) = " $LAST[1] "\n";

-- Cleanup
sparql define input:storage ""
drop silent vector index <urn:test-min:idx>
;
sparql define input:storage ""
drop silent vector index <urn:test-min:mixed-idx>
;
sparql define input:storage ""
clear graph <urn:test-min:graph>
;
sparql define input:storage ""
clear graph <urn:test-min:mixed-graph>
;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-test-min';
drop function DB.DBA.TVEC_SPARQL_MIN_TEST;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Test14 cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: SPARQL Vector Index DDL (shorthand + general + search + async + determinism)\n";
