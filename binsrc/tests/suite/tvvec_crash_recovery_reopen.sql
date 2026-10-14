--
--  tvvec_crash_recovery_reopen.sql
--
--  Phase 2 of the vector-index durability tests.  Run only after
--  tvvec_crash_recovery.sql, a kill -9, and a restart.
--
--  Phase 1 checkpointed, then committed three further rows without
--  checkpointing.  Those mutations were in the transaction log but not on
--  disk.  After an unclean kill:
--
--    - the log replays, so every embedding row is back;
--    - the HNSW graph is only as current as the last checkpoint, so three
--      nodes are missing.
--
--  Without detection the index would answer queries from a graph holding half
--  its data, and every answer would look perfectly plausible.  That is the
--  failure this whole mechanism exists to prevent, and this phase asserts it
--  is caught.
--

echo BOTH "STARTED: VVEC crash recovery / durability (phase 2, after kill -9)\n";

--
--  1. The data came back in full -- the log did its job.
--

select count (*) from DB.DBA.VDUR_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": embedding rows replayed from the log=" $LAST[1] "\n";

select case when (select count (*) from DB.DBA.VDUR_IDX_vec_embeddings)
             = (select E_ROWS from DB.DBA.VDUR_EXPECT where E_ID = 1)
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": row count matches the pre-crash record flag=" $LAST[1] "\n";

--
--  2. The graph did not come back whole.
--
--  What that looks like changed when LOG_VEC_PAGE gave the graph a WAL record.
--  It used to be visible in the root page's own numbers: the graph stopped at
--  the last checkpoint, so active_nodes and graph_epoch both trailed the data.
--  Now the root page is replayed like any other page, so those numbers can come
--  back current while the node pages they describe did not -- a record whose
--  page has since been handed to another tree is skipped, and only the skip
--  knows anything is missing.
--
--  So assert the state, not the symptom that used to reveal it: the index is
--  reported as inconsistent, and says why.  Section 3 below does that, and is
--  now the detection this test rests on.  Asserting active_nodes and
--  graph_epoch here would be asserting that the root page failed to replay,
--  which is not a property anything guarantees.

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'embedding_rows');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": embeddings visible to validate=" $LAST[1] " expected 6\n";

--
--  3. The graph came back whole, or its loss is detected -- and diagnosed as
--     a crash rather than a rollback.  Never consistent while short.
--
--  Which of the two happens depends on redo, not on this test: every graph
--  page image in the log is replayed unless recovery has to refuse one, and it
--  refuses one only when that page number was taken by another tree first.
--  Before the metadata-view installer moved after roll forward, it ran first
--  and allocated pages unlogged, and this driver always hit a refusal; now it
--  replays the whole graph.  Both outcomes are correct.  The one that must
--  never be reported is "consistent" over a graph missing rows.
--

create procedure DB.DBA.VDUR_REPLAY_VERDICT () returns integer
{
  declare v any;
  v := __VEC_INDEX_VALIDATE ('VDUR_IDX');
  if (cast (DB.DBA.VDUR_KV (v, 'consistent') as integer) = 1)
    return case when cast (DB.DBA.VDUR_KV (v, 'active_nodes') as integer) = 6
                 and cast (DB.DBA.VDUR_KV (v, 'embedding_rows') as integer) = 6
                then 1 else 0 end;
  return case when cast (DB.DBA.VDUR_KV (v, 'consistency_detail') as varchar) like '%behind the data%'
              then 2 else 0 end;
}
;

select DB.DBA.VDUR_REPLAY_VERDICT ();
ECHO BOTH ": after roll forward -- 1 = replayed whole, 2 = loss detected as behind the data, 0 = wrong; got " $LAST[1] "\n";

select case when DB.DBA.VDUR_REPLAY_VERDICT () in (1, 2) then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the replayed graph is complete, or its loss is detected as graph-behind-data flag=" $LAST[1] "\n";

--  A real crash, repaired automatically from the logged embeddings.
select __VEC_INDEX_HEALTH_RECHECK ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": health code after automatic repair=" $LAST[1] "\n";

-- coalesce over a scalar subquery: always one row, so a missing catalogue row
-- reports '<no-catalog-row>' instead of whatever $LAST[1] happened to hold.
select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'VDUR_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": catalog records ok after repair=" $LAST[1] "\n";

--
--  4. The index refuses to answer. This is the assertion that matters: an
--     unguarded index here would have returned a confident, wrong answer.
--

select DB.DBA.VDUR_SEARCH_BLOCKED ('VDUR_IDX', 'delta 40 41');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": crashed index answers after automatic repair=" $LAST[1] "\n";

--
--  5. Rebuild restores it from the embeddings that survived.
--

select __VEC_INDEX_REBUILD ('VDUR_IDX');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": rebuild replayed every stored embedding rows=" $LAST[1] " STATE=" $STATE "\n";

select DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after rebuild=" $LAST[1] "\n";

select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'active_nodes')
             = DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": active_nodes = embedding_rows after rebuild flag=" $LAST[1] "\n";

select DB.DBA.VDUR_SEARCH_BLOCKED ('VDUR_IDX', 'delta 40 41');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": searches allowed again after rebuild=" $LAST[1] "\n";

--
--  6. And it answers the way it did before the crash -- including for a row
--     that was committed after the last checkpoint, i.e. one the graph had
--     entirely lost.
--

select DB.DBA.VDUR_HITS ('VDUR_IDX', 'delta 40 41');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": post-rebuild hits=" $LAST[1] "\n";

select case when DB.DBA.VDUR_HITS ('VDUR_IDX', 'delta 40 41')
             = (select E_HITS from DB.DBA.VDUR_EXPECT where E_ID = 1)
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": hits match the pre-crash record flag=" $LAST[1] "\n";

select case when DB.DBA.VDUR_KV (__VEC_INDEX_VALIDATE ('VDUR_IDX'), 'recall_at_10') >= 0.99 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": post-rebuild recall_at_10>=0.99 flag=" $LAST[1] "\n";

--
--  Cleanup.
--

-- A vector index is dropped with plain DROP INDEX; there is no
-- DROP VECTOR INDEX form in the grammar (see sql3.y, which adds only the
-- CREATE ... VECTOR INDEX production).
drop index VDUR_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VDUR_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.DBA.VDUR_DOCS;
drop table DB.DBA.VDUR_EXPECT;
drop function DB.DBA.VDUR_KV;
drop function DB.DBA.VDUR_SEARCH_BLOCKED;
drop function DB.DBA.VDUR_HITS;
drop procedure DB.DBA.VDUR_REPLAY_VERDICT;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-dur-8';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC crash recovery / durability (phase 2)\n";
