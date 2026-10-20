--
--  tvvec_backup_verify.sql
--
--  Run against a database rebuilt from a dump (either "virtuoso-t
--  +backup-dump" replayed from the transaction log, or an online backup
--  replayed with -r).  Both dumps are logical: walk_db () emits rows, not
--  page images, and a native vector index has no rows -- its DPF_VEC graph is
--  derived data.  What has to survive is therefore the source table and the
--  index's embeddings, from which the graph is reconstructible; this script
--  asserts that it did, and that a rebuild makes the index answer again.
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

echo BOTH "STARTED: VVEC backup restore verification\n";

select count (*) from DB.DBA.BK_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored source rows=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.BK_T2;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": restored second source rows=" $LAST[1] " expected 2\n";

select count (*) from DB.DBA.BK_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored embeddings rows=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'BK_IDX';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored vector index catalogue rows=" $LAST[1] " expected 1\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'BK_IDX2';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored second vector index catalogue rows=" $LAST[1] " expected 1\n";

--  The graph now comes back with the dump rather than being reconstructed from
--  the embeddings, so ask before anything else does: __VEC_INDEX_VALIDATE is a
--  diagnostic and does not repair, whereas the first read would silently rebuild
--  a graph the restore had lost and make everything below pass for the wrong
--  reason.
select DB.DBA.BK_KV (__VEC_INDEX_VALIDATE ('BK_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored graph consistent without a rebuild=" $LAST[1] "\n";

select count (*) from DB.DBA.BK_P_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored packed index embeddings rows=" $LAST[1] " expected 80\n";

select DB.DBA.BK_KV (__VEC_INDEX_VALIDATE ('BK_P_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored packed graph consistent without a rebuild=" $LAST[1] "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('BK_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": restored BK_P_IDX format=" $LAST[1] " expected packed\n";

select length (__VEC_INDEX_SEARCH ('BK_P_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_P_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": restored packed index answers without rebuild hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.BK_PT where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored packed index X_SIMILAR count=" $LAST[1] " expected 80\n";

--  Still packed after searching: a search that triggered a repair would have replayed it to legacy.
select case when get_keyword ('format', __VEC_INDEX_PAGE_STATS ('BK_P_IDX')) = 'packed'
    and get_keyword ('physical_node_pages', __VEC_INDEX_PAGE_STATS ('BK_P_IDX')) < 80 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored packed graph not rebuilt by the searches=" $LAST[1] "\n";

--  A rebuild must still work on the restored database: it stays the fallback
--  for everything a dump cannot carry, so it keeps its coverage here.
select __VEC_INDEX_REBUILD ('BK_IDX');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": rebuild BK_IDX from restored embeddings STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select length (__VEC_INDEX_SEARCH ('BK_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": restored index answers after rebuild hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.BK_T where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": restored index answers X_SIMILAR count=" $LAST[1] " expected 80\n";

--  A second backup of the restored database must work too, so the restored
--  vector key is skipped by the same guard the original one was.
checkpoint;
backup 'vbk2_';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": backup of the restored database STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC backup restore verification\n";
