--
--  tvvec_chunked_replay.sql   (phase 1)
--
--  Regression test for the chunked-commit replay rebuild
--  (vvec_replay_rebuild_chunked).  Replay used to run the whole rebuild in one
--  transaction, whose resident dirty-buffer set grew with N and thrashed at
--  scale; it now commits every VVEC_REPLAY_CHUNK_SIZE (4000) inserts.  This
--  test builds a >4000-row index via replay so the rebuild crosses at least one
--  chunk boundary (an intermediate commit), and checks:
--
--    * the rebuild covers every row and the graph is consistent;
--    * the rebuild advances the graph epoch by rebuilt_count + 1 -- the +1 is the
--      epoch bump vvec_graph_reset now emits so an emptied/partial graph is never
--      reconciled as healthy (the durability window this test's phase 2 exercises);
--    * a cleanly-checkpointed chunked-replay graph survives an unclean crash
--      (CLEAN index -> phase 2 consistent);
--    * graph mutations committed after the last checkpoint survive the crash as
--      well, because LOG_VEC_PAGE replays their pages alongside the rows (ARMED
--      index -> phase 2 consistent, with every armed node back in the graph).
--      A graph that does fall behind its data is tvvec_recovery_graph.sh.
--
--  Self-contained: uses the in-core 'test_embedding' model, so it needs neither
--  the ONNX plugin nor the SPARQL backfill bootstrap (indexes are created on
--  empty tables and filled with __VEC_INDEX_INSERT_TEST_EMBEDDING).
--
--  Run via the two-phase driver: this file, then an unclean stop (raw_exit),
--  restart, then tvvec_chunked_replay_reopen.sql.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software
--  GNU GPL v2, 1991.  See tvvec_rebuild_durable.sql for the full header.
--

echo BOTH "STARTED: VVEC chunked replay rebuild (phase 1)\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

create function DB.DBA.TCR_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv)) return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k) return aref (kv, i + 1);
  return null;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCR_KV STATE=" $STATE "\n";

create procedure DB.DBA.TCR_FILL (in idx varchar, in lo integer, in hi integer)
{
  declare i integer;
  for (i := lo; i <= hi; i := i + 1)
    {
      __VEC_INDEX_INSERT_TEST_EMBEDDING (idx, i, mod (i, 8), mod (i * 3, 8));
      if (mod (i - lo + 1, 1000) = 0)
	commit work;
    }
  commit work;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCR_FILL STATE=" $STATE "\n";

-- Is a search on <idx> blocked by VEC80 (divergent graph refuses to answer)?
create function DB.DBA.TCR_SEARCH_BLOCKED (in idx varchar) returns integer
{
  declare c integer;
  -- VEC80 is raised as SQLSTATE 42000 with the code in the message, so match
  -- on the message the way tvvec_crash_recovery.sql does.
  declare exit handler for sqlstate '*'
    {
      if (__SQL_MESSAGE like '%VEC80%' or __SQL_MESSAGE like '%inconsistent with its stored embeddings%')
        return 1;
      return -1;
    };
  c := length (__VEC_INDEX_SEARCH_TEST_EMBEDDING (idx, 1, 3, 10, 40));
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCR_SEARCH_BLOCKED STATE=" $STATE "\n";

-- How many hits does a search return, with an error reported as -1 rather than
-- left for $LAST[1] to answer from the previous statement (isql keeps the last
-- non-empty result; see the note in tvvec_chunked_replay_crash_reopen.sql).
create function DB.DBA.TCR_HITS (in idx varchar) returns integer
{
  declare exit handler for sqlstate '*' { return -1; };
  return length (__VEC_INDEX_SEARCH_TEST_EMBEDDING (idx, 1, 3, 10, 40));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCR_HITS STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'tcr-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('tcr-8', 'chunked replay test model', 'internal:tcr-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tcr-8 STATE=" $STATE "\n";

create table DB.DBA.TCR_SCRATCH (S_ID integer primary key, S_VAL integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCR_SCRATCH STATE=" $STATE "\n";

--------------------------------------------------------------------------------
-- CLEAN index: chunked replay, checkpointed, never mutated afterward.
--------------------------------------------------------------------------------
create table DB.DBA.TCR_CLEAN (id integer not null primary key, content varchar);
CREATE VECTOR INDEX TCR_CLEAN_IDX ON DB.DBA.TCR_CLEAN (content) USING 'tcr-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24, rebuild = 'replay');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCR_CLEAN_IDX (rebuild=replay) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TCR_FILL ('TCR_CLEAN_IDX', 1, 4005);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fill 4005 embeddings STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Epoch before the rebuild, to prove the graph_reset bump afterward.
select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'graph_epoch');
ECHO BOTH ": graph_epoch before rebuild=" $LAST[1] "\n";
insert into DB.DBA.TCR_SCRATCH (S_ID, S_VAL) values (1, DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'graph_epoch'));

-- The change under test: replay rebuild across >1 chunk.
select __VEC_INDEX_REBUILD ('TCR_CLEAN_IDX', 'replay');
ECHO BOTH $IF $EQU $LAST[1] 4005 "PASSED" "***FAILED";
ECHO BOTH ": chunked replay rebuilt rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after chunked replay=" $LAST[1] "\n";

-- graph_reset bump: post-rebuild epoch = pre-rebuild epoch + rebuilt + 1.
select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'graph_epoch')
       - (select S_VAL from DB.DBA.TCR_SCRATCH where S_ID = 1);
ECHO BOTH $IF $EQU $LAST[1] 4006 "PASSED" "***FAILED";
ECHO BOTH ": epoch delta = rebuilt+1 (graph_reset bump present) delta=" $LAST[1] "\n";

select DB.DBA.TCR_HITS ('TCR_CLEAN_IDX');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": CLEAN searchable hits=" $LAST[1] "\n";

--------------------------------------------------------------------------------
-- ARMED index: chunked replay, checkpointed, THEN mutated without checkpoint.
--------------------------------------------------------------------------------
create table DB.DBA.TCR_ARMED (id integer not null primary key, content varchar);
CREATE VECTOR INDEX TCR_ARMED_IDX ON DB.DBA.TCR_ARMED (content) USING 'tcr-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24, rebuild = 'replay');
-- ARMED is small: crash detection is size-independent, and the >1-chunk path is
-- already covered by TCR_CLEAN above.  Keeping it small keeps phase 1 fast.
DB.DBA.TCR_FILL ('TCR_ARMED_IDX', 1, 6);
select __VEC_INDEX_REBUILD ('TCR_ARMED_IDX', 'replay');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": ARMED replay rebuilt rows=" $LAST[1] "\n";
select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ARMED consistent before crash=" $LAST[1] "\n";

-- Make both graphs durable up to here.
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint (graphs durable) STATE=" $STATE "\n";

-- Now mutate ARMED AFTER the checkpoint and commit.  These graph pages never
-- reach disk, but LOG_VEC_PAGE writes an image of each one, so roll-forward
-- brings them back with the rows -- phase 2 asserts the mutations survived.
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('TCR_ARMED_IDX', 20001, 2, 5);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('TCR_ARMED_IDX', 20002, 4, 7);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('TCR_ARMED_IDX', 20003, 1, 6);
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": commit 3 post-checkpoint rows STATE=" $STATE "\n";

-- Recorded so phase 2 can prove the armed nodes came back, not merely that the
-- epochs agree -- agreeing epochs over a short graph would look identical.
insert into DB.DBA.TCR_SCRATCH (S_ID, S_VAL)
  values (2, DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'active_nodes'));
select coalesce ((select S_VAL from DB.DBA.TCR_SCRATCH where S_ID = 2), -1);
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH ": ARMED active_nodes before crash=" $LAST[1] "\n";

create table DB.DBA.TCR_EXPECT (E_ID integer primary key, E_HITS integer);
insert into DB.DBA.TCR_EXPECT (E_ID, E_HITS) values
  (1, DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'active_nodes'));
select coalesce ((select E_HITS from DB.DBA.TCR_EXPECT where E_ID = 1), -1);
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": record CLEAN active_nodes=" $LAST[1] "\n";

echo BOTH "COMPLETED: VVEC chunked replay rebuild (phase 1)\n";
echo BOTH "NOTE: stop the server uncleanly (raw_exit), restart, then run tvvec_chunked_replay_reopen.sql\n";
