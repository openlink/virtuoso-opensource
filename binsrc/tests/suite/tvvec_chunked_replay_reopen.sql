--
--  tvvec_chunked_replay_reopen.sql   (phase 2)
--
--  Runs after tvvec_chunked_replay.sql (phase 1), an unclean stop (raw_exit,
--  no checkpoint), and a restart.  Roll-forward replays the committed embedding
--  rows; the HNSW graph is only what the phase-1 checkpoint captured.
--
--    * TCR_CLEAN_IDX was checkpointed and never mutated afterward -> its
--      chunked-replay graph is intact and reconciles consistent.
--    * TCR_ARMED_IDX had 3 rows committed after the checkpoint -> LOG_VEC_PAGE
--      logged those graph pages, so roll-forward brings them back with the rows
--      and the index reconciles consistent, with every armed node still in the
--      graph.  The opposite case, a graph genuinely behind its data, is
--      reached by a restore rather than a crash -- tvvec_recovery_graph.sh.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software.  GNU GPL v2, 1991.
--

echo BOTH "STARTED: VVEC chunked replay rebuild (phase 2 -- after crash)\n";

-- CLEAN index survived the crash: checkpointed chunked-replay graph is durable.
select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": CLEAN consistent after crash=" $LAST[1] "\n";

select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'graph_epoch')
       - DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'data_epoch');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": CLEAN graph_epoch == data_epoch delta=" $LAST[1] "\n";

select case when DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_CLEAN_IDX'), 'active_nodes')
             = (select E_HITS from DB.DBA.TCR_EXPECT where E_ID = 1) then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": CLEAN active_nodes preserved=" $LAST[1] "\n";

select DB.DBA.TCR_SEARCH_BLOCKED ('TCR_CLEAN_IDX');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": CLEAN searchable (not blocked)=" $LAST[1] "\n";

-- ARMED index: the post-checkpoint graph mutations came back with the rows.
select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'graph_epoch')
       - DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'data_epoch');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": ARMED graph_epoch == data_epoch delta=" $LAST[1] "\n";

select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ARMED consistent after crash=" $LAST[1] "\n";

--  Equal epochs alone would also hold for a graph that lost the armed nodes and
--  the rows together, so check the nodes themselves are back.
select case when DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'active_nodes')
             = (select S_VAL from DB.DBA.TCR_SCRATCH where S_ID = 2) then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ARMED active_nodes preserved=" $LAST[1] "\n";

--  1 is VVEC_HEALTH_OK: reconciliation finds nothing to repair, because nothing
--  diverged.  tvvec_recovery_graph.sh is where this same call repairs a real
--  divergence, the one a restore leaves behind.
select __VEC_INDEX_HEALTH_RECHECK ('TCR_ARMED_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ARMED health code (nothing to repair)=" $LAST[1] "\n";

-- coalesce over a scalar subquery: always one row, so a missing catalogue row
-- reports '<no-catalog-row>' instead of whatever $LAST[1] happened to hold.
select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'TCR_ARMED_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": ARMED catalog state=" $LAST[1] "\n";

select DB.DBA.TCR_SEARCH_BLOCKED ('TCR_ARMED_IDX');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": ARMED searchable after crash=" $LAST[1] "\n";

-- Repair by rebuild (chunked replay again).
select __VEC_INDEX_REBUILD ('TCR_ARMED_IDX', 'replay');
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH ": ARMED rebuild covers every row=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TCR_KV (__VEC_INDEX_VALIDATE ('TCR_ARMED_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ARMED consistent after repair=" $LAST[1] "\n";

select DB.DBA.TCR_SEARCH_BLOCKED ('TCR_ARMED_IDX');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": ARMED searchable after repair=" $LAST[1] "\n";

echo BOTH "COMPLETED: VVEC chunked replay rebuild (phase 2)\n";
