--
--  tvvec_crash_recovery.sql
--
--  Phase 1 of the vector-index durability tests.
--
--  The HNSW graph lives in DPF_VEC pages that reach disk only at checkpoint,
--  and Virtuoso's transaction log is logical, so nothing replays them.  The
--  stored embeddings in <index>_vec_embeddings are ordinary logged rows and
--  recover in full.  An unclean shutdown therefore leaves the graph behind the
--  data; a rollback leaves it ahead.
--
--  Detection reconciles VVEC_META_EPOCH on the root page (which follows the
--  checkpoint) against DB.DBA.VEC_INDEX_EPOCH.VIE_EPOCH (which follows the
--  log).
--
--  This phase covers everything testable inside one server lifetime:
--  injected divergence in both directions, the read guard, repair by rebuild,
--  and rollback undo.  It then leaves the index deliberately dirty -- rows
--  committed after the last checkpoint -- so that tvvec_crash_recovery_reopen
--  can assert real crash behaviour after a kill -9.
--
--  Self-contained: creates its own table, model and index, and uses the
--  'test_embedding' model type so it runs without the ONNX plugin.
--
--  Run via binsrc/tests/suite/tvvec_crash_recovery.sh, which sequences the
--  kill and restart between the two phases.
--

echo BOTH "STARTED: VVEC crash recovery / durability (phase 1)\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": init model registry STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- A deterministic in-process model: no ONNX plugin, no helper process, so the
-- durability logic is tested in isolation from embedding infrastructure.
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-dur-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vvec-dur-8', 'deterministic durability test model', 'internal:vvec-dur-8',
          'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-dur-8 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VDUR_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv))
    return null;
  for (i := 0; i < length (kv); i := i + 2)
    {
      if (cast (aref (kv, i) as varchar) = k)
        return aref (kv, i + 1);
    }
  return null;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VDUR_KV STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Reports whether the read guard fired, so the guard can be asserted rather
-- than aborting the script.
create function DB.DBA.VDUR_SEARCH_BLOCKED (in index_name varchar, in txt varchar) returns integer
{
  declare _ignore any;
  declare exit handler for sqlstate '*'
    {
      if (__SQL_MESSAGE like '%VEC80%' or __SQL_MESSAGE like '%inconsistent with its stored embeddings%')
        return 1;
      return -1;
    };
  _ignore := __VEC_INDEX_SEARCH (index_name, __VEC_INDEX_QUERY_TEXT_VECTOR (index_name, txt), 10, 20);
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VDUR_SEARCH_BLOCKED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VDUR_HITS (in index_name varchar, in txt varchar) returns integer
{
  return length (__VEC_INDEX_SEARCH (index_name, __VEC_INDEX_QUERY_TEXT_VECTOR (index_name, txt), 10, 20));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VDUR_HITS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VDUR_DOCS (id integer not null primary key, content varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VDUR_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VDUR_DOCS (id, content) values (1, 'alpha 10 11');
insert into DB.DBA.VDUR_DOCS (id, content) values (2, 'beta 20 21');
insert into DB.DBA.VDUR_DOCS (id, content) values (3, 'gamma 30 31');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed VDUR_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VDUR_IDX ON DB.DBA.VDUR_DOCS (content) USING 'vvec-dur-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VDUR_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
--  1. A healthy index reconciles clean and its epochs agree.
--

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": baseline consistent=" $LAST[1] " STATE=" $STATE "\n";

select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'graph_epoch')
             = DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'data_epoch')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": baseline graph_epoch = data_epoch flag=" $LAST[1] "\n";

select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'active_nodes')
             = DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": baseline active_nodes = embedding_rows flag=" $LAST[1] "\n";

select DB.DBA.VDUR_SEARCH_BLOCKED ('VDUR_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": healthy index search not blocked=" $LAST[1] "\n";

--
--  2. Graph behind data -- the crash signature. Injected here; phase 2 produces
--     it for real.
--

update DB.DBA.VEC_INDEX_EPOCH set VIE_EPOCH = VIE_EPOCH + 5 where VIE_NAME = 'VDUR_IDX';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": inject graph-behind-data STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": divergence detected consistent=" $LAST[1] "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistency_detail');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": divergence detail=" $LAST[1] "\n";

-- The verdict is cached per process because a crash is only visible at
-- startup; recheck drops it and reconciles again, as a restart would.
--  Reconciliation repairs a behind graph rather than condemning it, so the
--  recheck that used to report needs_rebuild now reports healthy.  The injected
--  divergence is a falsified counter -- no rows were actually lost -- so a
--  rebuild + epoch resync is the correct resolution.
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": recheck repairs and reports healthy code=" $LAST[1] "\n";

-- coalesce over a scalar subquery: always one row, so a missing catalogue row
-- reports '<no-catalog-row>' instead of whatever $LAST[1] happened to hold.
select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'VDUR_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": catalog state after repair=" $LAST[1] "\n";

-- The point of the exercise has moved: the read path repairs the divergence and
-- then answers, instead of refusing.  It still never answers FROM a divergent
-- graph -- the repair completes first, and an index that cannot be repaired is
-- still refused, which tvvec_recovery_graph_reopen.sql covers against a
-- genuinely unrepairable index.
select DB.DBA.VDUR_SEARCH_BLOCKED ('VDUR_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": repaired index answers rather than refusing=" $LAST[1] "\n";

--
--  3. Repair by rebuild.
--

select __VEC_INDEX_REBUILD ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuild replayed rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after rebuild=" $LAST[1] "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_METRICS ('VDUR_IDX'), 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": rebuild left no soft-deleted nodes=" $LAST[1] "\n";

select DB.DBA.VDUR_SEARCH_BLOCKED ('VDUR_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": searches allowed again after rebuild=" $LAST[1] "\n";

select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'VDUR_IDX';
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": catalog state back to ok=" $LAST[1] "\n";

select DB.DBA.VDUR_HITS ('VDUR_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuilt index returns all rows hits=" $LAST[1] "\n";

--
--  3a. A needs-rebuild verdict holds until a rebuild.
--
--  A graph ahead of the data with no orphan to reap -- what a rebuild leaves
--  when it dies after writing part of its graph -- cannot be repaired in place,
--  so the index is marked needs_rebuild and refused.  The next check, and the
--  next restart, must reach the same verdict.  They did not: the mark wrote
--  the GRAPH's epoch into the catalog's data epoch, so the next comparison
--  found the two equal and declared the divergent graph healthy.
--

update DB.DBA.VEC_INDEX_EPOCH set VIE_EPOCH = VIE_EPOCH - 2 where VIE_NAME = 'VDUR_IDX';
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": graph ahead with nothing to reap is condemned, health=" $LAST[1] "\n";

select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": and a second check reaches the same verdict, health=" $LAST[1] "\n";

select DB.DBA.VDUR_SEARCH_BLOCKED ('VDUR_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the condemned index still refuses to answer=" $LAST[1] "\n";

--  Writes keep arriving at a condemned index -- a trigger-maintained one gets
--  every insert on its table.  Each ends by mirroring the graph's epoch into
--  the catalog, and doing that here made the pair agree: the verdict survived
--  exactly until the next recheck or restart.  An insert and a delete, so the
--  row count the later sections rely on is unchanged.
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VDUR_IDX', 77, 70, 71);
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": an insert into the condemned index does not clear its verdict, health=" $LAST[1] "\n";

select __VEC_INDEX_DELETE_EMBEDDING ('VDUR_IDX', 77);
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": nor does a delete, health=" $LAST[1] "\n";

select __VEC_INDEX_REBUILD ('VDUR_IDX');
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a rebuild clears it, health=" $LAST[1] "\n";

--
--  4. Rollback undo. A transaction that mutates the graph and then aborts
--     leaves an orphan node: the graph insert reached the buffer pool but the
--     embedding row never committed. It must not be reachable, and the
--     counters must return to the truth.
--

set autocommit manual;
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VDUR_IDX', 999, 55, 56);
rollback work;
set autocommit on;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": rolled back a graph insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VDUR_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rollback discarded the embedding row, rows=" $LAST[1] "\n";

-- Before repair the graph is ahead of the data: the orphan is present.
select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'active_nodes')
             > DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": orphan node present before repair flag=" $LAST[1] "\n";

-- The health verdict was already cached as ok before this rollback, so nothing
-- re-reconciles.  The read path itself must still refuse to hand back the
-- orphan -- otherwise a mid-session rollback would leak a phantom neighbour
-- until the next restart.  No recheck is issued before this search on purpose.
select DB.DBA.VDUR_HITS ('VDUR_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rolled-back node not reachable on a plain search, hits=" $LAST[1] "\n";

-- A search cannot safely retire it: its transaction snapshot may also hide the
-- backing row of a concurrent insert that has not committed yet.  It filters
-- the hit but leaves orphan retirement to reconciliation.
select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'active_nodes')
             > DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": read path left orphan cleanup for recheck flag=" $LAST[1] "\n";

-- Reconciliation also repairs the graph-ahead case in place rather than
-- condemning the index: a rolled-back insert must not cost a full rebuild.
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": index reconciles ok after rollback undo, health=" $LAST[1] "\n";

select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'active_nodes')
             = DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": active_nodes correct after rollback flag=" $LAST[1] "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent again after rollback undo=" $LAST[1] "\n";

--
--  5. Rebuild is idempotent on a healthy index.
--

select __VEC_INDEX_REBUILD ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": redundant rebuild rows=" $LAST[1] " STATE=" $STATE "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after redundant rebuild=" $LAST[1] "\n";

--
--  6. Arm phase 2.
--
--  Checkpoint to make the graph durable up to here, then commit three more
--  rows WITHOUT checkpointing. Those mutations exist in the log but not on
--  disk, so a kill -9 now loses them from the graph while the log replays the
--  embedding rows -- the exact divergence this whole mechanism exists to
--  catch. Recorded for the reopen phase to assert against.
--

checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint before arming STATE=" $STATE "\n";

create table DB.DBA.VDUR_EXPECT (E_ID integer primary key, E_ROWS integer, E_HITS integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VDUR_EXPECT STATE=" $STATE "\n";

insert into DB.DBA.VDUR_DOCS (id, content) values (10, 'delta 40 41');
insert into DB.DBA.VDUR_DOCS (id, content) values (11, 'epsilon 50 51');
insert into DB.DBA.VDUR_DOCS (id, content) values (12, 'zeta 60 61');
select DB.DBA.VEC_SQL_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": commit 3 rows after the checkpoint STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert replacing DB.DBA.VDUR_EXPECT (E_ID, E_ROWS, E_HITS)
  values (1, (select count (*) from DB.DBA.VDUR_IDX_vec_embeddings),
             DB.DBA.VDUR_HITS ('VDUR_IDX', 'delta 40 41'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": record pre-crash expectations STATE=" $STATE "\n";

select E_ROWS from DB.DBA.VDUR_EXPECT where E_ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": pre-crash embedding rows=" $LAST[1] "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent immediately before the kill=" $LAST[1] "\n";

echo BOTH "COMPLETED: VVEC crash recovery / durability (phase 1)\n";
echo BOTH "NOTE: kill -9 the server now, restart it, then run tvvec_crash_recovery_reopen.sql\n";
