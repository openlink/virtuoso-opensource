--
--  tvvec_recovery_graph_crash.sql
--
--  Second half of tvvec_recovery_graph.sh: set up graph mutations that exist
--  only AFTER the last checkpoint, then let the driver stop the server
--  uncleanly.
--
--  The asymmetry being exercised: the base-table rows and the embedding rows
--  are ordinary logged tables, so roll-forward brings them back.  The graph
--  pages are not logged at all (vvec.c has no log_* call sites), so they can
--  only ever be as new as the last checkpoint.  Insert after checkpointing
--  and the two halves are guaranteed to diverge across a crash.
--
--  The queue drain matters: the DML trigger enqueues through
--  VEC_SQL_QUEUE_ENQUEUE and the work is applied by an explicit
--  VEC_SQL_QUEUE_DRAIN, so without it the new rows would never reach the
--  graph and the test would prove nothing about recovery.
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

echo BOTH "STARTED: VVEC recovery graph -- pre-crash mutations\n";

--  Start from a known-good graph.  The logical-restore half of this driver
--  ran first, so the index may be behind; put it right and checkpoint, so
--  that everything after this point is unambiguously post-checkpoint.
select __VEC_INDEX_REBUILD ('VRG_IDX');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": pre-crash rebuild STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_REBUILD ('VRG_P_IDX', 'fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": pre-crash fast rebuild VRG_P_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": pre-crash VRG_P_IDX format=" $LAST[1] " expected packed\n";

checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": pre-crash checkpoint STATE=" $STATE "\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent at the checkpoint=" $LAST[1] " expected 1\n";

--  Now the post-checkpoint work.  Four rows, embedded for real.
insert into DB.DBA.VRG_T values (81, 'hot 0 7');
insert into DB.DBA.VRG_T values (82, 'hot 0 8');
insert into DB.DBA.VRG_T values (83, 'hot 0 9');
insert into DB.DBA.VRG_T values (84, 'hot 0 10');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": post-checkpoint inserts STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Linked into the packed graph: backlinks rewrite packed records, logged only as LOG_VEC_PAGE.
insert into DB.DBA.VRG_PT values (81, 'hot 0 7');
insert into DB.DBA.VRG_PT values (82, 'hot 0 8');
insert into DB.DBA.VRG_PT values (83, 'hot 0 9');
insert into DB.DBA.VRG_PT values (84, 'hot 0 10');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": post-checkpoint inserts into the packed index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drain the embed queue drained=" $LAST[1] " STATE=" $STATE "\n";

select count (*) from DB.DBA.VRG_T;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": pre-crash rows=" $LAST[1] " expected 84\n";

select count (*) from DB.DBA.VRG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": pre-crash embeddings=" $LAST[1] " expected 84\n";

--  Proof the graph really did take the new rows before the crash: without
--  this, a post-crash failure could just mean the inserts never landed.
select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after post-checkpoint inserts=" $LAST[1] " expected 1\n";

select count (*) from DB.DBA.VRG_T where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": pre-crash X_SIMILAR count=" $LAST[1] " expected 84\n";

select count (*) from DB.DBA.VRG_P_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": pre-crash packed index embeddings=" $LAST[1] " expected 84\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_P_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": packed consistent after post-checkpoint inserts=" $LAST[1] " expected 1\n";

select count (*) from DB.DBA.VRG_PT where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": pre-crash packed X_SIMILAR count=" $LAST[1] " expected 84\n";

--  Deliberately NO checkpoint here.  The driver stops the server with
--  raw_exit () next.
echo BOTH "COMPLETED: VVEC recovery graph -- pre-crash mutations\n";
