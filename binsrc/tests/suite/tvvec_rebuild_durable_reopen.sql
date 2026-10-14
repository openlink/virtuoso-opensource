--
--  tvvec_rebuild_durable_reopen.sql
--
--  Phase 2 of the vector-index REBUILD durability test.  Run only after
--  tvvec_rebuild_durable.sql, a CLEAN shutdown, and a restart.
--
--  Phase 1 rebuilt VRBD_IDX, checkpointed, and shut down cleanly.  A clean
--  shutdown checkpoints, so the rebuilt graph -- root epoch and all node pages --
--  must be on disk in full.  This phase asserts the rebuild was durable:
--  graph_epoch == data_epoch (strict equality, the signature of a graph that is
--  neither behind nor ahead of the data), the node/row counts agree, and the
--  index answers exactly as it did in-session.  The never-rebuilt control
--  VRBD_CTL must be equally intact.
--
--  A failure here (graph_epoch < data_epoch, VEC80 on search) would mean the
--  checkpoint wrote a stale pre-rebuild root instead of the rebuilt one -- the
--  durability regression this test exists to catch.
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

echo BOTH "STARTED: VVEC rebuild durability (phase 2, after clean restart)\n";

--
--  1. The rebuilt index is consistent: its checkpointed graph epoch matches the
--     logged data epoch.  This is the assertion tvvec_crash_recovery cannot make.
--

select DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": rebuilt index consistent after clean restart=" $LAST[1] "\n";

select case when DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'graph_epoch')
             = DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'data_epoch')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": graph_epoch = data_epoch after restart flag=" $LAST[1] "\n";

select case when DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'graph_epoch')
             = (select E_GE from DB.DBA.VRBD_EXPECT where E_ID = 1)
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": graph_epoch matches the pre-restart record flag=" $LAST[1] "\n";

select case when DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'active_nodes')
             = DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": active_nodes = embedding_rows after restart flag=" $LAST[1] "\n";

--
--  2. It still answers, and answers the way it did in-session -- no VEC80, and
--     every row reachable.
--

select DB.DBA.VRBD_HITS ('VRBD_IDX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": rebuilt index returns all rows after restart hits=" $LAST[1] "\n";

select case when DB.DBA.VRBD_HITS ('VRBD_IDX', 'alpha 10 11')
             = (select E_HITS from DB.DBA.VRBD_EXPECT where E_ID = 1)
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": hits match the pre-restart record flag=" $LAST[1] "\n";

--
--  3. The never-rebuilt control survived the restart too, so any failure above
--     is specific to the rebuild path and not general graph durability.
--

select DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_CTL'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": control index consistent after restart=" $LAST[1] "\n";

select DB.DBA.VRBD_HITS ('VRBD_CTL', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": control index returns all rows after restart hits=" $LAST[1] "\n";

--
--  4. The fast-rebuilt 2048-d overflow index survived the restart intact: still
--     consistent, epochs agree, its overflow pages are on disk, the node/row
--     counts match, and it still answers.  This is the fast path's overflow
--     branch proven durable across a clean restart.
--

select DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow index consistent after restart=" $LAST[1] "\n";

select case when DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'graph_epoch')
             = DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'data_epoch')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow index graph_epoch = data_epoch after restart flag=" $LAST[1] "\n";

select case when DB.DBA.VRBD_KV (__VEC_INDEX_PAGE_STATS ('VRBD_OVF'), 'overflow_pages')
             = (select E_HITS from DB.DBA.VRBD_EXPECT where E_ID = 2)
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow pages persisted across restart flag=" $LAST[1] "\n";

select case when DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'active_nodes')
             = DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'embedding_rows')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow index active_nodes = embedding_rows after restart flag=" $LAST[1] "\n";

select case when length (__VEC_INDEX_SEARCH_TEST_EMBEDDING ('VRBD_OVF', 100, 101, 6, 20)) > 0 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow index answers after restart flag=" $LAST[1] "\n";

--
--  Cleanup.
--

drop index VRBD_IDX;
drop index VRBD_CTL;
drop index VRBD_OVF;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop indexes STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.DBA.VRBD_DOCS;
drop table DB.DBA.VRBD_CTLD;
drop table DB.DBA.VRBD_OVFD;
drop table DB.DBA.VRBD_EXPECT;
drop function DB.DBA.VRBD_KV;
drop function DB.DBA.VRBD_HITS;
delete from DB.DBA.ONNX_MODELS where model_name = 'vrbd-8';
delete from DB.DBA.ONNX_MODELS where model_name = 'vrbd-2048';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC rebuild durability (phase 2)\n";
