--
--  tvvec_rebuild_durable.sql
--
--  Phase 1 of the vector-index REBUILD durability test.
--
--  The HNSW graph lives in DPF_VEC pages that reach disk only at checkpoint.
--  A __VEC_INDEX_REBUILD throws the graph away (freeing its node pages) and
--  rebuilds it, advancing VVEC_META_EPOCH on the root page and the logged
--  DB.DBA.VEC_INDEX_EPOCH.VIE_EPOCH together.  The question this test answers is
--  narrow and previously uncovered: does a rebuilt graph, once checkpointed,
--  survive a clean shutdown and restart -- i.e. does the checkpoint durably
--  write the rebuild's root and node pages, not a stale pre-rebuild copy?
--
--  tvvec_crash_recovery cannot answer it: that test arms an unclean kill with
--  extra uncheckpointed rows, so its reopen only ever asserts graph_epoch <
--  data_epoch, which holds whether or not the rebuild's checkpoint persisted.
--  This test checkpoints the rebuild and then shuts down CLEANLY, so the reopen
--  phase can assert the strict equality graph_epoch == data_epoch that only a
--  durable rebuild produces.
--
--  Two indexes are built: VRBD_IDX is rebuilt; VRBD_CTL is only ever built
--  incrementally and is the control -- if the control diverges too, the fault is
--  general graph durability, not the rebuild path.
--
--  Self-contained: uses the 'test_embedding' model type, so it runs without the
--  ONNX plugin.  Run via tvvec_rebuild_durable.sh, which sequences the clean
--  shutdown and restart between the two phases.
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

echo BOTH "STARTED: VVEC rebuild durability (phase 1)\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": init model registry STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vrbd-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vrbd-8', 'deterministic rebuild-durability test model', 'internal:vrbd-8',
          'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vrbd-8 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VRBD_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv)) return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k) return aref (kv, i + 1);
  return null;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VRBD_KV STATE=" $STATE "\n";

create function DB.DBA.VRBD_HITS (in index_name varchar, in txt varchar) returns integer
{
  return length (__VEC_INDEX_SEARCH (index_name, __VEC_INDEX_QUERY_TEXT_VECTOR (index_name, txt), 10, 20));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VRBD_HITS STATE=" $STATE "\n";

create table DB.DBA.VRBD_DOCS (id integer not null primary key, content varchar);
create table DB.DBA.VRBD_CTLD (id integer not null primary key, content varchar);
insert into DB.DBA.VRBD_DOCS (id, content) values (1, 'alpha 10 11');
insert into DB.DBA.VRBD_DOCS (id, content) values (2, 'beta 20 21');
insert into DB.DBA.VRBD_DOCS (id, content) values (3, 'gamma 30 31');
insert into DB.DBA.VRBD_DOCS (id, content) values (4, 'delta 40 41');
insert into DB.DBA.VRBD_DOCS (id, content) values (5, 'epsilon 50 51');
insert into DB.DBA.VRBD_DOCS (id, content) values (6, 'zeta 60 61');
insert into DB.DBA.VRBD_CTLD select id, content from DB.DBA.VRBD_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed 6 rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VRBD_IDX ON DB.DBA.VRBD_DOCS (content) USING 'vrbd-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24);
CREATE VECTOR INDEX VRBD_CTL ON DB.DBA.VRBD_CTLD (content) USING 'vrbd-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VRBD_IDX + VRBD_CTL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Both indexes are healthy at the outset.
select DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": baseline VRBD_IDX consistent=" $LAST[1] "\n";

-- Make the incrementally-built graphs durable BEFORE the rebuild: this puts the
-- pre-rebuild root epoch on disk, so a rebuild that failed to checkpoint would
-- leave that stale value behind and be caught in phase 2.
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": pre-rebuild checkpoint STATE=" $STATE "\n";

-- Rebuild VRBD_IDX only.  VRBD_CTL is the never-rebuilt control.
select __VEC_INDEX_REBUILD ('VRBD_IDX');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": rebuild replayed rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent in-session after rebuild=" $LAST[1] "\n";

-- Record the post-rebuild expectations for phase 2 to compare against.
create table DB.DBA.VRBD_EXPECT (E_ID integer primary key, E_GE integer, E_DE integer, E_HITS integer);
insert into DB.DBA.VRBD_EXPECT (E_ID, E_GE, E_DE, E_HITS) values
  (1, DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'graph_epoch'),
      DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_IDX'), 'data_epoch'),
      DB.DBA.VRBD_HITS ('VRBD_IDX', 'alpha 10 11'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": record post-rebuild expectations STATE=" $STATE "\n";

select E_HITS from DB.DBA.VRBD_EXPECT where E_ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": rebuilt index returns all rows in-session hits=" $LAST[1] "\n";

--
--  Overflow through the FAST rebuild path.
--
--  A 2048-d vector at hnsw_m = 8 does not fit inline on an 8 KB DPF_VEC page, so
--  each node spills into overflow pages.  VRBD_OVF pins the fast bulk builder with
--  WITH (rebuild = 'fast'), so this exercises vvec_bulk_serialize's overflow
--  branch (vvec_write_overflow_vector) -- the one part of the fast path the small
--  inline indexes above never reach -- and phase 2 confirms it survives a restart.
--

delete from DB.DBA.ONNX_MODELS where model_name = 'vrbd-2048';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vrbd-2048', 'deterministic overflow test model', 'internal:vrbd-2048',
          'test_embedding', 'embedding', '1,2048', now (), now ());
create table DB.DBA.VRBD_OVFD (id integer not null primary key, content varchar);
CREATE VECTOR INDEX VRBD_OVF ON DB.DBA.VRBD_OVFD (content) USING 'vrbd-2048'
  WITH (dimensions = 2048, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16, rebuild = 'fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VRBD_OVF (2048-d, rebuild=fast) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRBD_OVF', 1, 100, 101);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRBD_OVF', 2, 300, 301);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRBD_OVF', 3, 700, 701);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRBD_OVF', 4, 1100, 1101);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRBD_OVF', 5, 1500, 1501);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRBD_OVF', 6, 1900, 1901);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": overflow embeddings inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- The stored dimension exceeds the inline limit, and overflow pages were allocated.
select case when DB.DBA.VRBD_KV (__VEC_INDEX_PAGE_STATS ('VRBD_OVF'), 'inline_dim_limit') < 2048 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 2048-d exceeds inline limit flag=" $LAST[1] "\n";
select case when DB.DBA.VRBD_KV (__VEC_INDEX_PAGE_STATS ('VRBD_OVF'), 'overflow_pages') >= 6 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow pages allocated on insert flag=" $LAST[1] "\n";

-- Rebuild via the fast path (stored default 'fast'); it must re-serialize the
-- overflow vectors, stay consistent, and keep overflow pages.
select __VEC_INDEX_REBUILD ('VRBD_OVF');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild of overflow index rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow index consistent after fast rebuild=" $LAST[1] "\n";
select case when DB.DBA.VRBD_KV (__VEC_INDEX_PAGE_STATS ('VRBD_OVF'), 'overflow_pages') >= 6 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow pages present after fast rebuild flag=" $LAST[1] "\n";

insert into DB.DBA.VRBD_EXPECT (E_ID, E_GE, E_DE, E_HITS) values
  (2, DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'graph_epoch'),
      DB.DBA.VRBD_KV (__VEC_INDEX_VALIDATE ('VRBD_OVF'), 'data_epoch'),
      DB.DBA.VRBD_KV (__VEC_INDEX_PAGE_STATS ('VRBD_OVF'), 'overflow_pages'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": record overflow expectations STATE=" $STATE "\n";

-- Checkpoint the rebuilt graph.  This is the step under test: it MUST write the
-- rebuild's root (epoch advanced) and node pages, not a stale pre-rebuild copy.
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": post-rebuild checkpoint STATE=" $STATE "\n";

echo BOTH "COMPLETED: VVEC rebuild durability (phase 1)\n";
echo BOTH "NOTE: shut the server down CLEANLY, restart it, then run tvvec_rebuild_durable_reopen.sql\n";
