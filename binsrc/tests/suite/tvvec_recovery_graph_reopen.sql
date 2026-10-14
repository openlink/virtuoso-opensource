--
--  tvvec_recovery_graph_reopen.sql
--
--  Run after the unclean stop in tvvec_recovery_graph.sh.
--
--  The contract asserted here is that roll-forward brings the graph back to
--  the same point as the data, with NO __VEC_INDEX_REBUILD: the four rows
--  inserted after the last checkpoint are searchable again once the server
--  comes back.
--
--  This is the opposite of tvvec_crash_recovery_reopen.sql, which still asserts
--  the unrepaired behaviour -- graph_epoch behind data_epoch, consistent = 0,
--  health = needs_rebuild.  That file documents what the engine used to do;
--  this one documents what it does now, and those older expectations are what
--  change.  See lace2/plans/vvec-recovery-page-logging/plan.md.
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

echo BOTH "STARTED: VVEC recovery graph -- after crash roll-forward\n";

--  The logged half.  These pass today: the rows and the embeddings are
--  ordinary tables and the log replays them.
select count (*) from DB.DBA.VRG_T;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": rows replayed from the log=" $LAST[1] " expected 84\n";

select count (*) from DB.DBA.VRG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": embeddings replayed from the log=" $LAST[1] " expected 84\n";

--  The unlogged half.  These are what this work has to make true.
--  Health first: it is the call that drives reconciliation.  __VEC_INDEX_VALIDATE
--  deliberately does not trigger a repair (a diagnostic must not start an
--  hours-long rebuild as a side effect), so it is asserted after, where it
--  reports the repaired graph.  VVEC_HEALTH_OK is 1; 0 is UNCHECKED.
select __VEC_INDEX_HEALTH_RECHECK ('VRG_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": health code after roll-forward=" $LAST[1] " expected 1 (healthy)\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_IDX'), 'active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": graph nodes after roll-forward=" $LAST[1] " expected 84\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": graph consistent after roll-forward=" $LAST[1] " expected 1\n";

select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'VRG_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": epoch state after roll-forward=" $LAST[1] " expected ok\n";

--  Searchable without a rebuild, and the post-checkpoint rows are in it.
select length (__VEC_INDEX_SEARCH ('VRG_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VRG_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": ANN search after roll-forward hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.VRG_T where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": X_SIMILAR count after roll-forward=" $LAST[1] " expected 84\n";

--  Specifically the rows that existed only after the checkpoint.  Asserted by
--  id rather than by count, so a graph that came back holding only the
--  checkpointed 80 cannot pass on a threshold technicality.  Compared as a
--  set rather than by position: the probe ties across many rows, and an exact
--  distance tie may be ordered either way by an approximate search.
select count (*) from DB.DBA.VRG_T where id in (81, 82, 83, 84)
   and X_SIMILAR (content, 'hot 0 7', 84) > 0.0;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": post-checkpoint rows searchable after roll-forward=" $LAST[1] " expected 4\n";

--  The packed graph: its post-checkpoint records exist only in LOG_VEC_PAGE, and a repair would replay it to legacy.
select count (*) from DB.DBA.VRG_P_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": packed index embeddings replayed from the log=" $LAST[1] " expected 84\n";

select __VEC_INDEX_HEALTH_RECHECK ('VRG_P_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": packed health code after roll-forward=" $LAST[1] " expected 1 (healthy)\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_P_IDX'), 'active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": packed graph nodes after roll-forward=" $LAST[1] " expected 84\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_P_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": packed graph consistent after roll-forward=" $LAST[1] " expected 1\n";

select length (__VEC_INDEX_SEARCH ('VRG_P_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VRG_P_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": packed ANN search after roll-forward hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.VRG_PT where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 84 "PASSED" "***FAILED";
ECHO BOTH ": packed X_SIMILAR count after roll-forward=" $LAST[1] " expected 84\n";

select count (*) from DB.DBA.VRG_PT where id in (81, 82, 83, 84)
   and X_SIMILAR (content, 'hot 0 7', 84) > 0.0;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": post-checkpoint rows searchable in the packed graph=" $LAST[1] " expected 4\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": VRG_P_IDX format after roll-forward without repair=" $LAST[1] " expected packed\n";

select case when get_keyword ('physical_node_pages', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX')) < 84 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VRG_P_IDX still fewer pages than nodes after roll-forward=" $LAST[1] "\n";

--
--  Fail closed: an index that CANNOT be repaired must still be refused.
--
--  Automatic repair replaced the old "divergent index refuses to search"
--  assertions in tvvec_crash_recovery.sql, because the divergence those
--  injected -- a falsified catalog counter, with no rows actually lost -- now
--  self-heals, correctly.  That removed the only coverage of the guarantee
--  that matters most, so it is reconstructed here against a divergence that is
--  genuinely unrepairable: the embeddings the rebuild would read are gone.
--
--  vvec_epoch_sync () force-writes the catalog epoch to the root's, so any
--  rebuild that returns at all has converged; the condemn path is reachable
--  only when the rebuild raises, which is exactly what this arranges.
--
create table DB.DBA.VRG_FC (id integer not null primary key, content varchar);
insert into DB.DBA.VRG_FC values (1, 'hot 0 1');
insert into DB.DBA.VRG_FC values (2, 'hot 0 2');
insert into DB.DBA.VRG_FC values (3, 'hot 0 3');
CREATE VECTOR INDEX VRG_FC_IDX ON DB.DBA.VRG_FC (content) USING 'vrg-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fail-closed fixture STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_HEALTH_RECHECK ('VRG_FC_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fail-closed fixture starts healthy=" $LAST[1] " expected 1\n";

--  Remove what a rebuild would read, then diverge the epochs.
drop table DB.DBA.VRG_FC_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop the embeddings a rebuild needs STATE=" $STATE "\n";

update DB.DBA.VEC_INDEX_EPOCH set VIE_EPOCH = VIE_EPOCH + 5 where VIE_NAME = 'VRG_FC_IDX';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": diverge the unrepairable index STATE=" $STATE "\n";

--  The repair is attempted, raises, is caught, and the index is condemned --
--  rather than the rebuild's own error escaping into the caller's SELECT.
select __VEC_INDEX_HEALTH_RECHECK ('VRG_FC_IDX');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": unrepairable index is condemned=" $LAST[1] " expected 2 (needs_rebuild)\n";

select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'VRG_FC_IDX'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "needs_rebuild" "PASSED" "***FAILED";
ECHO BOTH ": unrepairable index catalog state=" $LAST[1] " expected needs_rebuild\n";

echo BOTH "COMPLETED: VVEC recovery graph -- after crash roll-forward\n";
