--
--  tvvec_passthrough_column_reopen.sql
--
--  Phase 2 of the passthrough-column test: after tvvec_passthrough_column.sql
--  ran a fast rebuild + checkpoint and the server was stopped cleanly, assert the
--  passthrough index came back durable -- its graph answers by-vector queries and
--  still rejects text queries (VEC88).  The helper procedures (PT_TOP, PT_METRIC,
--  PT_ERRCODE) persist across the restart.
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

echo BOTH "STARTED: VVEC passthrough column reopen (durability)\n";

-- PT_IDX after phase 1: rows 1 (seed 1000, updated), 2 (seed 50), 4 (seed 200),
-- fast-rebuilt and checkpointed.
select DB.DBA.PT_METRIC ('PT_IDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuilt graph durable after restart (graph_nodes)=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_IDX', 1000, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": by-vector search after restart (seed1000 -> row1)=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_IDX', 200, 3);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": by-vector search after restart (seed200 -> row4)=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_IDX', 50, 3);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": by-vector search after restart (seed50 -> row2)=" $LAST[1] "\n";
select DB.DBA.PT_ERRCODE ('select __VEC_INDEX_QUERY_TEXT_VECTOR (''PT_IDX'', ''hello'')', 'VEC88');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": text query still VEC88 after restart=" $LAST[1] "\n";

-- The backfilled index is durable too.
select DB.DBA.PT_METRIC ('PT_BIDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": backfilled index durable after restart (graph_nodes)=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_BIDX', 10, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": backfilled index searchable after restart=" $LAST[1] "\n";

echo BOTH "COMPLETED: VVEC passthrough column reopen\n";
