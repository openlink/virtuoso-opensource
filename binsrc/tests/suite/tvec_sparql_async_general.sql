--
--  tvec_sparql_async_general.sql
--
--  Regression test for Feature 2: maintenance = 'async' on a general
--  (KEY / EMBEDDING / WHERE) SPARQL vector index, with predicate-precise
--  (graph, predicate) incremental maintenance.
--
--  Covers:
--    A. Predicate-precise trigger rows on CREATE (explicit GRAPH + constant
--       predicate) and catalog state = active.
--    B. Unrelated predicate in the same graph does NOT enqueue; the indexed
--       predicate DOES enqueue.
--    C. Variable predicate over an explicit graph -> graph-only trigger row
--       (SVT_PRED_IRI = '') and enqueue on any predicate in that graph.
--    D. No explicit graph (default graph) -> rejected with VEC77; the catalogue
--       row is removed, no trigger rows, and the IRI is reusable.
--    E. General manual index: trigger rows exist but DML does NOT enqueue
--       (enqueue path filters on SVI_MAINTENANCE = 'async').
--    F. Drain applies a delete: removing the triple enqueues the subject and
--       the drain deletes the backing-table row.
--    G. DROP VECTOR INDEX removes trigger + queue rows.
--    H. Shorthand async behaviour is unchanged (regression).
--
--  Run with:
--    isql <port> dba dba binsrc/tests/suite/tvec_sparql_async_general.sql
--

echo BOTH "STARTED: SPARQL Vector Index async general selector (predicate-precise)\n";

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

-- Register a deterministic test_embedding model (native dim 8).  The async
-- drain path only embeds when the text hash differs from the stored hash; we
-- pre-seed backing-table hashes so the drain no-op path is exercised without
-- needing a real embedding backend.  The delete path needs no embedding at all.
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-async-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-sparql-async-8', 'deterministic SPARQL async-general test model (native dim 8)',
   'internal:vvec-sparql-async-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-sparql-async-8 model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: look up the backing source_table name for an index IRI.
create function DB.DBA.TVEC_ASYNC_SRC_TABLE (in idx_iri varchar) returns varchar
{
  declare st varchar;
  whenever not found goto nf;
  select SVI_SOURCE_TABLE into st from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
  return st;
nf:;
  return null;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_ASYNC_SRC_TABLE helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: count queue rows for an index.
create function DB.DBA.TVEC_ASYNC_QUEUE_COUNT (in idx_iri varchar) returns integer
{
  return (select count (*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = idx_iri);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_ASYNC_QUEUE_COUNT helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: count trigger rows for an index.
create function DB.DBA.TVEC_ASYNC_TRIG_COUNT (in idx_iri varchar) returns integer
{
  return (select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI = idx_iri);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_ASYNC_TRIG_COUNT helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: check whether a backing-table row exists for a key.
create function DB.DBA.TVEC_ASYNC_BACKING_HAS (in idx_iri varchar, in subj_iri varchar) returns integer
{
  declare st varchar;
  declare kid bigint;
  declare stmt_state, stmt_msg varchar;
  declare qm, qr any;
  st := DB.DBA.TVEC_ASYNC_SRC_TABLE (idx_iri);
  if (st is null)
    return 0;
  kid := iri_id_num (iri_to_id (subj_iri));
  stmt_state := '00000';
  exec (sprintf ('select 1 from %s where RV_ID = %d', st, kid), stmt_state, stmt_msg, vector (), 1, qm, qr);
  if (stmt_state <> '00000' and stmt_state <> 0)
    return 0;
  if (length (qr) = 0)
    return 0;
  return 1;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_ASYNC_BACKING_HAS helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Pre-clean any leftover indexes and graphs from prior runs.
sparql define input:storage ""
drop silent vector index <urn:ag:precise-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:varpred-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:nograph-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:manual-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:drain-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:short-idx>
;
sparql define input:storage ""
clear graph <urn:ag:g1>
;
sparql define input:storage ""
clear graph <urn:ag:g2>
;
sparql define input:storage ""
clear graph <urn:ag:g3>
;
sparql define input:storage ""
clear graph <urn:ag:g4>
;
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI like 'urn:ag:%';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": async-general pre-clean STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Suspend the queue so DML during setup does not process prematurely.
DB.DBA.VEC_INDEX_QUEUE_SUSPEND ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": queue suspended for setup STATE=" $STATE "\n";

-- ===========================================================================
-- Test A: Predicate-precise trigger rows on CREATE
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:ag:precise-idx>
  key ?s
  embedding ?text
  where {
    graph <urn:ag:g1> {
      ?s <urn:ag:content> ?text
    }
  }
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestA CREATE general async (precise predicate) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Catalog state must be active (SET_OPTIONS allowed async because trigger rows exist).
select SVI_STATE, SVI_MAINTENANCE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ag:precise-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": TestA catalog state=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] async "PASSED" "***FAILED";
ECHO BOTH ": TestA catalog maintenance=" $LAST[2] "\n";

-- Exactly one trigger row, predicate-precise (SVT_PRED_IRI = urn:ag:content).
select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER
  where SVT_INDEX_IRI = 'urn:ag:precise-idx';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestA trigger row count (expect 1)=" $LAST[1] "\n";

select SVT_GRAPH_IRI, SVT_PRED_IRI from DB.DBA.SPARQL_VEC_INDEX_TRIGGER
  where SVT_INDEX_IRI = 'urn:ag:precise-idx';
ECHO BOTH $IF $EQU $LAST[1] "urn:ag:g1" "PASSED" "***FAILED";
ECHO BOTH ": TestA trigger graph (expect urn:ag:g1)=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "urn:ag:content" "PASSED" "***FAILED";
ECHO BOTH ": TestA trigger predicate (expect urn:ag:content)=" $LAST[2] "\n";

-- ===========================================================================
-- Test B: Unrelated predicate does NOT enqueue; indexed predicate DOES
-- ===========================================================================
-- Clear any queue rows left from setup.
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:precise-idx';
commit work;

-- Insert a triple with an UNRELATED predicate in the same graph.
sparql define input:storage ""
insert data {
  graph <urn:ag:g1> {
    <urn:ag:doc-unrelated> <urn:ag:other-pred> "unrelated text" .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestB insert unrelated-predicate triple STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Queue must be empty: the trigger row is predicate-precise on urn:ag:content,
-- so a change on urn:ag:other-pred does not match.
select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:precise-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestB queue after unrelated-predicate insert (expect 0)=" $LAST[1] "\n";

-- Insert a triple with the INDEXED predicate.
sparql define input:storage ""
insert data {
  graph <urn:ag:g1> {
    <urn:ag:doc-indexed> <urn:ag:content> "indexed text" .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestB insert indexed-predicate triple STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Queue must now contain the changed subject (urn:ag:doc-indexed).
select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:precise-idx');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestB queue after indexed-predicate insert (expect 1)=" $LAST[1] "\n";

-- Compare in SQL: ISQL's $EQU cannot evaluate iri_id_num(iri_to_id(...)), so the
-- expected key must be computed server-side and the assertion made on the result.
select case when SVQ_KEY_ID = iri_id_num (iri_to_id ('urn:ag:doc-indexed')) then 1 else 0 end
  from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:precise-idx';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestB queued key is urn:ag:doc-indexed (1=match)=" $LAST[1] "\n";

-- Clean up the queue and the test triples before the next test.
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:precise-idx';
sparql define input:storage ""
delete { graph <urn:ag:g1> { <urn:ag:doc-unrelated> <urn:ag:other-pred> ?o . } }
where { graph <urn:ag:g1> { <urn:ag:doc-unrelated> <urn:ag:other-pred> ?o . } }
;
sparql define input:storage ""
delete { graph <urn:ag:g1> { <urn:ag:doc-indexed> <urn:ag:content> ?o . } }
where { graph <urn:ag:g1> { <urn:ag:doc-indexed> <urn:ag:content> ?o . } }
;
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:precise-idx';
commit work;

-- ===========================================================================
-- Test C: Variable predicate -> graph-only trigger row (SVT_PRED_IRI = '')
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:ag:varpred-idx>
  key ?s
  embedding ?text
  where {
    graph <urn:ag:g2> {
      ?s ?p ?text
    }
  }
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestC CREATE general async (variable predicate) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ag:varpred-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": TestC catalog state=" $LAST[1] "\n";

-- One graph-only trigger row with empty SVT_PRED_IRI.
select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER
  where SVT_INDEX_IRI = 'urn:ag:varpred-idx';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestC trigger row count (expect 1)=" $LAST[1] "\n";

select SVT_GRAPH_IRI, SVT_PRED_IRI from DB.DBA.SPARQL_VEC_INDEX_TRIGGER
  where SVT_INDEX_IRI = 'urn:ag:varpred-idx';
ECHO BOTH $IF $EQU $LAST[1] "urn:ag:g2" "PASSED" "***FAILED";
ECHO BOTH ": TestC trigger graph (expect urn:ag:g2)=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "" "PASSED" "***FAILED";
ECHO BOTH ": TestC trigger predicate (expect empty string, graph-only)=" $LAST[2] "\n";

-- Any predicate in g2 should enqueue (graph-only fallback).
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:varpred-idx';
commit work;
sparql define input:storage ""
insert data {
  graph <urn:ag:g2> {
    <urn:ag:doc-any> <urn:ag:whatever-pred> "any text" .
  }
}
;
select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:varpred-idx');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestC queue after any-predicate insert in g2 (expect 1)=" $LAST[1] "\n";

-- Clean up.
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:varpred-idx';
sparql define input:storage ""
delete { graph <urn:ag:g2> { <urn:ag:doc-any> ?p ?o . } }
where { graph <urn:ag:g2> { <urn:ag:doc-any> ?p ?o . } }
;
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:varpred-idx';
commit work;

-- ===========================================================================
-- Test D: No explicit graph -> rejected (VEC77), nothing left behind
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:ag:nograph-idx>
  key ?s
  embedding ?text
  where {
    ?s <urn:ag:content> ?text
  }
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
-- The QM handler catches the VEC77 signal from SET_OPTIONS; END_CREATE never
-- runs, so VEC_INDEX_ABORT_CREATE removes the 'creating' row BEGIN_CREATE had
-- inserted, together with its backing table and native index.  count(*) rather
-- than SVI_STATE: it always returns exactly one row, so an empty result cannot
-- be misread as a value left in $LAST[1] by the preceding statement.
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ag:nograph-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestD no-graph async rejected, no catalogue residue, rows=" $LAST[1] "\n";

-- No trigger rows should have been stored for the rejected index.
select DB.DBA.TVEC_ASYNC_TRIG_COUNT ('urn:ag:nograph-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestD no-graph trigger rows (expect 0)=" $LAST[1] "\n";

-- The point of removing the row is that the IRI stays usable.  A stranded
-- 'creating' row was not active, not reachable through DROP, and made the next
-- attempt at the same IRI fail with VEC01 "already exists" -- so assert the
-- retry, not just the absence.  VEC77 is the refusal that shows up in practice,
-- which is why the re-create check lives here.
sparql define input:storage ""
create vector index <urn:ag:nograph-idx>
  key ?s
  embedding ?text
  where {
    graph <urn:ag:g1> { ?s <urn:ag:content> ?text }
  }
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestD same IRI re-creatable after refusal STATE=" $STATE " MSG=" $MESSAGE "\n";
select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ag:nograph-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": TestD re-created index is active state=" $LAST[1] "\n";

sparql define input:storage ""
drop silent vector index <urn:ag:nograph-idx>
;

-- ===========================================================================
-- Test E: General manual index -> trigger rows exist but DML does NOT enqueue
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:ag:manual-idx>
  key ?s
  embedding ?text
  where {
    graph <urn:ag:g3> {
      ?s <urn:ag:content> ?text
    }
  }
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestE CREATE general manual STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SVI_STATE, SVI_MAINTENANCE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ag:manual-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": TestE catalog state=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] manual "PASSED" "***FAILED";
ECHO BOTH ": TestE catalog maintenance=" $LAST[2] "\n";

-- Trigger rows are stored unconditionally at create time, even for manual.
select DB.DBA.TVEC_ASYNC_TRIG_COUNT ('urn:ag:manual-idx');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestE trigger rows exist for manual index (expect 1)=" $LAST[1] "\n";

-- DML on the indexed predicate must NOT enqueue (maintenance = manual).
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:manual-idx';
commit work;
sparql define input:storage ""
insert data {
  graph <urn:ag:g3> {
    <urn:ag:doc-manual> <urn:ag:content> "manual text" .
  }
}
;
select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:manual-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestE queue after DML on manual index (expect 0)=" $LAST[1] "\n";

-- Clean up the test triple.
sparql define input:storage ""
delete { graph <urn:ag:g3> { <urn:ag:doc-manual> <urn:ag:content> ?o . } }
where { graph <urn:ag:g3> { <urn:ag:doc-manual> <urn:ag:content> ?o . } }
;

-- ===========================================================================
-- Test F: Drain applies a delete (remove triple -> enqueue -> drain deletes)
-- ===========================================================================
-- Create a dedicated async general index for the drain test.  It uses its own
-- graph <urn:ag:g4>: VEC_INDEX_QUEUE_DRAIN drains the queue globally (oldest
-- pending across all indexes), so if drain-idx shared graph <urn:ag:g1>/predicate
-- <urn:ag:content> with the still-active precise-idx, a single insert would
-- enqueue for both and the drain counts below would double.  A dedicated graph
-- keeps this test's drain counts attributable to drain-idx alone.
sparql define input:storage ""
create vector index <urn:ag:drain-idx>
  key ?s
  embedding ?text
  where {
    graph <urn:ag:g4> {
      ?s <urn:ag:content> ?text
    }
  }
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestF CREATE general async (drain) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Insert the triple (queue is suspended, so no processing yet).
sparql define input:storage ""
insert data {
  graph <urn:ag:g4> {
    <urn:ag:drain-doc> <urn:ag:content> "drain text" .
  }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestF insert drain-doc triple STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Pre-seed the backing-table row with the matching text hash so the first
-- drain (processing the insert enqueue) is a no-op (need_update = 0) and does
-- not attempt to embed via the test_embedding model.
-- Inlined as a single call: a bare top-level { ... } block is parsed
-- unreliably by isql when it follows other statements, so express the two
-- lookups as arguments to one UPSERT call instead.
DB.DBA.VEC_INDEX_UPSERT_ROW (
  DB.DBA.TVEC_ASYNC_SRC_TABLE ('urn:ag:drain-idx'),
  iri_id_num (iri_to_id ('urn:ag:drain-doc')),
  'drain text',
  md5 ('drain text'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestF pre-seed backing row with matching hash STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Resume and drain: the insert enqueue is processed; the re-eval finds the
-- triple, the hash matches, so no embed is needed and the row stays.
DB.DBA.VEC_INDEX_QUEUE_RESUME ();
select DB.DBA.VEC_INDEX_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestF first drain processed count (expect 1)=" $LAST[1] "\n";

select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:drain-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestF queue empty after first drain (expect 0)=" $LAST[1] "\n";

select DB.DBA.TVEC_ASYNC_BACKING_HAS ('urn:ag:drain-idx', 'urn:ag:drain-doc');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestF backing row still present after no-op drain (expect 1)=" $LAST[1] "\n";

-- Now suspend, delete the triple, then resume and drain.  The re-eval finds
-- no triple for the key, so the drain deletes the backing-table row.
DB.DBA.VEC_INDEX_QUEUE_SUSPEND ();
sparql define input:storage ""
delete { graph <urn:ag:g4> { <urn:ag:drain-doc> <urn:ag:content> ?o . } }
where { graph <urn:ag:g4> { <urn:ag:drain-doc> <urn:ag:content> ?o . } }
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestF delete drain-doc triple STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:drain-idx');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestF queue after delete (expect 1)=" $LAST[1] "\n";

DB.DBA.VEC_INDEX_QUEUE_RESUME ();
select DB.DBA.VEC_INDEX_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestF second drain processed count (expect 1)=" $LAST[1] "\n";

select DB.DBA.TVEC_ASYNC_BACKING_HAS ('urn:ag:drain-idx', 'urn:ag:drain-doc');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestF backing row deleted after drain (expect 0)=" $LAST[1] "\n";

select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:drain-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestF queue empty after delete drain (expect 0)=" $LAST[1] "\n";

-- ===========================================================================
-- Test G: DROP VECTOR INDEX removes trigger + queue rows
-- ===========================================================================
-- Verify trigger rows exist before drop.
select DB.DBA.TVEC_ASYNC_TRIG_COUNT ('urn:ag:precise-idx');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestG trigger rows before drop (expect 1)=" $LAST[1] "\n";

sparql define input:storage ""
drop silent vector index <urn:ag:precise-idx>
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestG DROP precise-idx STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TVEC_ASYNC_TRIG_COUNT ('urn:ag:precise-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestG trigger rows after drop (expect 0)=" $LAST[1] "\n";

select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:precise-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestG queue rows after drop (expect 0)=" $LAST[1] "\n";

-- ===========================================================================
-- Test H: Shorthand async behaviour is unchanged (regression)
-- ===========================================================================
-- A shorthand async index must still create, enqueue on matching predicate,
-- and not populate the trigger table (it matches via SVI_SELECTOR_GRAPH/PRED).
sparql define input:storage ""
create vector index <urn:ag:short-idx>
  on graph <urn:ag:g1>
  for predicate <urn:ag:content>
  using model 'vvec-sparql-async-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 24, maintenance = 'async')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": TestH CREATE shorthand async STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SVI_STATE, SVI_MAINTENANCE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ag:short-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": TestH shorthand state=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] async "PASSED" "***FAILED";
ECHO BOTH ": TestH shorthand maintenance=" $LAST[2] "\n";

-- Shorthand does not use the trigger table.
select DB.DBA.TVEC_ASYNC_TRIG_COUNT ('urn:ag:short-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestH shorthand trigger rows (expect 0)=" $LAST[1] "\n";

-- DML on the matching predicate enqueues.
DB.DBA.VEC_INDEX_QUEUE_SUSPEND ();
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:short-idx';
commit work;
sparql define input:storage ""
insert data {
  graph <urn:ag:g1> {
    <urn:ag:short-doc> <urn:ag:content> "short text" .
  }
}
;
select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:short-idx');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TestH shorthand queue after matching insert (expect 1)=" $LAST[1] "\n";

-- DML on a non-matching predicate does not enqueue.
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = 'urn:ag:short-idx';
commit work;
sparql define input:storage ""
insert data {
  graph <urn:ag:g1> {
    <urn:ag:short-doc2> <urn:ag:other-pred> "other text" .
  }
}
;
select DB.DBA.TVEC_ASYNC_QUEUE_COUNT ('urn:ag:short-idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TestH shorthand queue after non-matching insert (expect 0)=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
DB.DBA.VEC_INDEX_QUEUE_RESUME ();
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI like 'urn:ag:%';
sparql define input:storage ""
drop silent vector index <urn:ag:varpred-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:manual-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:drain-idx>
;
sparql define input:storage ""
drop silent vector index <urn:ag:short-idx>
;
sparql define input:storage ""
clear graph <urn:ag:g1>
;
sparql define input:storage ""
clear graph <urn:ag:g2>
;
sparql define input:storage ""
clear graph <urn:ag:g3>
;
sparql define input:storage ""
clear graph <urn:ag:g4>
;
delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI like 'urn:ag:%';
delete from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI like 'urn:ag:%';
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-sparql-async-8';
drop function DB.DBA.TVEC_ASYNC_BACKING_HAS;
drop function DB.DBA.TVEC_ASYNC_TRIG_COUNT;
drop function DB.DBA.TVEC_ASYNC_QUEUE_COUNT;
drop function DB.DBA.TVEC_ASYNC_SRC_TABLE;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": async-general cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Ensure the async flag is recalculated (no active async indexes left).
DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
commit work;

checkpoint;

echo BOTH "COMPLETED: SPARQL Vector Index async general selector (predicate-precise)\n";
