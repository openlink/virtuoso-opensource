--
--  tvvec_rollback_undo_rebuilt.sql
--
--  After roll forward past an unresynced rollback: the index is rebuilt from
--  its stored embeddings, so it holds exactly the committed rows.
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

echo BOTH "STARTED: vector index rollback undo -- rebuilt after roll forward\n";

select __VEC_INDEX_HEALTH_RECHECK ('VRU_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": health=" $LAST[1] "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VRU_IDX'));
ECHO BOTH $IF $EQU $LAST[1] legacy "PASSED" "***FAILED";
ECHO BOTH ": rebuilt, format=" $LAST[1] "\n";

select DB.DBA.VRU_KV ('embedding_rows');
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
ECHO BOTH ": stored embeddings=" $LAST[1] " expected 101\n";

select DB.DBA.VRU_KV ('active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
ECHO BOTH ": graph nodes=" $LAST[1] " expected 101\n";

select DB.DBA.VRU_KV ('consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent=" $LAST[1] "\n";

select DB.DBA.VRU_FOUND (7);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the row whose delete was rolled back is found=" $LAST[1] "\n";

select DB.DBA.VRU_FOUND (121);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the committed row is found=" $LAST[1] "\n";

echo BOTH "COMPLETED: vector index rollback undo -- rebuilt after roll forward\n";
