--
--  tvvec_recovery_graph_restore.sql
--
--  Run against a database rebuilt by replaying a "virtuoso-t +backup-dump"
--  log into a fresh database file.
--
--  The contract asserted here is that the vector index answers immediately,
--  with NO __VEC_INDEX_REBUILD.  That is deliberately stricter than
--  tvvec_backup_verify.sql, which asserts only that a rebuild can put the
--  index back together afterwards.  A restore that hands back a database
--  whose vector searches all raise VEC80 until an operator runs a full
--  O(N log N) graph rebuild by hand has lost user data in every sense that
--  matters, even though the bytes needed to reconstruct it are present.
--
--  The graph is repaired automatically from the logged embeddings when the
--  index is first used -- see lace2/plans/vvec-recovery-page-logging/plan.md.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

echo BOTH "STARTED: VVEC recovery graph -- after logical restore\n";

--  What already worked before this change: the ordinary logged tables.
select count (*) from DB.DBA.VRG_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored source rows=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.VRG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored embeddings=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'VRG_IDX';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored vector index catalogue rows=" $LAST[1] " expected 1\n";

--  What this work is about: the graph itself.  No __VEC_INDEX_REBUILD is issued
--  anywhere in this file -- if the index answers, it answers because recovery
--  repaired it without an operator.
--  Health first, because it is the call that drives reconciliation.  A restore
--  leaves the graph behind its data, and the engine repairs that on first use
--  rather than eagerly at open.  __VEC_INDEX_VALIDATE deliberately does NOT
--  trigger a repair -- a diagnostic that could silently start an hours-long
--  rebuild on a large index would be a trap -- so it is asserted afterwards,
--  where it reports the repaired state.  VVEC_HEALTH_OK is 1; 0 is UNCHECKED.
select __VEC_INDEX_HEALTH_RECHECK ('VRG_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored health code=" $LAST[1] " expected 1 (healthy)\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored graph consistent without rebuild=" $LAST[1] " expected 1\n";

select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'VRG_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": restored epoch state=" $LAST[1] " expected ok\n";

select length (__VEC_INDEX_SEARCH ('VRG_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VRG_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": restored ANN search hits without rebuild=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.VRG_T where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored X_SIMILAR count without rebuild=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.VRG_P_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored packed index embeddings=" $LAST[1] " expected 80\n";

select __VEC_INDEX_HEALTH_RECHECK ('VRG_P_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored packed health code=" $LAST[1] " expected 1 (healthy)\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_P_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored packed graph consistent=" $LAST[1] " expected 1\n";

select length (__VEC_INDEX_SEARCH ('VRG_P_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VRG_P_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": restored packed ANN search hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.VRG_PT where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored packed X_SIMILAR count=" $LAST[1] " expected 80\n";

--  Still packed: an automatic repair would have replayed the 80 rows into legacy pages.
select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": restored VRG_P_IDX format without repair=" $LAST[1] " expected packed\n";

select case when get_keyword ('physical_node_pages', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX')) < 80 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored VRG_P_IDX still fewer pages than nodes=" $LAST[1] "\n";

--  The restored database must itself still be backup-able, so the DPF_VEC
--  guard that stopped walk_db () crashing (e00d773dfa) is still in force on a
--  tree that came back through recovery rather than through CREATE.
checkpoint;
backup 'vrg2_';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": backup of the restored database STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC recovery graph -- after logical restore\n";
