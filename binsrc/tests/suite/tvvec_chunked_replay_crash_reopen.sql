--
--  tvvec_chunked_replay_crash_reopen.sql   (phase 2)
--
--  Runs after tvvec_chunked_replay_crash.sql crashed the server in the middle of
--  a chunked replay rebuild (partial graph checkpointed, final epoch sync never
--  run) and the server was restarted WITHOUT the fault env var.
--
--  The durable graph is the partial one the fault hook checkpointed; its epoch is
--  ahead of the catalog data epoch (never synced).  The index must therefore
--  reconcile needs_rebuild, refuse searches with VEC80, and be fully repairable by
--  a rebuild -- proving a half-built graph is never trusted.  This is the case the
--  vvec_graph_reset epoch bump exists to make safe.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software.  GNU GPL v2, 1991.
--

echo BOTH "STARTED: VVEC mid-chunk crash (phase 2 -- after crash)\n";

-- The partial graph the fault hook checkpointed is ahead of the never-synced
-- catalog epoch.
select case when DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'graph_epoch')
             > DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'data_epoch')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": partial graph ahead of data (graph_epoch > data_epoch)=" $LAST[1] "\n";

select DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": mid-rebuild crash detected consistent=" $LAST[1] "\n";

select __VEC_INDEX_HEALTH_RECHECK ('TCC_IDX');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": health code needs_rebuild=" $LAST[1] "\n";

-- Scalar subquery + coalesce so the statement always returns exactly one row:
-- a bare "select VIE_STATE ... where ..." returns none when the catalogue row is
-- missing, and $LAST[1] then still holds the previous statement's value
-- (binsrc/tests/isql.c returns out_cols[n-1].o_buffer, which nothing clears on
-- an empty result set).  A missing row is a real possible outcome here -- it is
-- what this test exists to catch -- so it must be reported, not masked.
select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'TCC_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "needs_rebuild" "PASSED" "***FAILED";
ECHO BOTH ": catalog state=" $LAST[1] "\n";

-- A partial graph must never answer: no partial-graph node was an orphan (all
-- back real rows), so orphan-sweep cannot "repair" it into looking healthy.
select DB.DBA.TCC_SEARCH_BLOCKED ('TCC_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": partial graph refuses to search (VEC80)=" $LAST[1] "\n";

-- All embedding rows survived the crash (they were committed + checkpointed).
-- Cross-check against the phase-1 record, then assert the deterministic count
-- (isql $IF $EQU cannot take a subquery operand, so compare the literal).
select case when DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'embedding_rows')
             = (select E_ROWS from DB.DBA.TCC_EXPECT where E_ID = 1) then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": embedding rows match phase-1 record=" $LAST[1] "\n";
select DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'embedding_rows');
ECHO BOTH $IF $EQU $LAST[1] 4005 "PASSED" "***FAILED";
ECHO BOTH ": embedding rows intact=" $LAST[1] "\n";

-- Repair by rebuild (chunked replay, no fault env this time): covers every row.
select __VEC_INDEX_REBUILD ('TCC_IDX', 'replay');
ECHO BOTH $IF $EQU $LAST[1] 4005 "PASSED" "***FAILED";
ECHO BOTH ": repaired rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after repair=" $LAST[1] "\n";

select DB.DBA.TCC_SEARCH_BLOCKED ('TCC_IDX');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": searchable after repair=" $LAST[1] "\n";

echo BOTH "COMPLETED: VVEC mid-chunk crash (phase 2)\n";
