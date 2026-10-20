--
--  tvvec_concurrency.sql
--
--  Concurrent-writer safety test for the native HNSW vector index (prompt 06).
--
--  One HNSW insert is a multi-page read-modify-write: it rewrites the neighbour
--  lists of several existing nodes, adds reciprocal backlinks, and updates the
--  root-page entry point / max layer / node counters.  The per-page latches the
--  code takes protect one page at a time; they do NOT make that sequence atomic.
--  Before prompt 06 nothing serialized two writers on the same index, so two
--  concurrent inserts could interleave and lose neighbour edges, strand the
--  entry point on a stale layer, or (structurally) leave a graph that no longer
--  navigates to its own nodes.  The counters stay correct even when interleaved
--  (vvec_meta_inc_i64 is atomic under the root latch), so a corrupt build is
--  invisible to a count check alone -- it shows up as collapsed recall.
--
--  This test drives genuine concurrency with async_queue / aq_request (the same
--  idiom as ginx.sql / taq.sql): N background workers insert disjoint id ranges
--  into ONE shared index at the same time.  It then asserts, on the merged
--  result:
--
--    (A) writer safety
--        * __VEC_INDEX_VALIDATE reports consistent = 1
--        * graph active_nodes == embedding_rows == READY hidden-table rows
--        * every inserted id is present exactly once
--        * recall@10 against a brute-force ground truth still meets the bar --
--          the structural check the counters cannot make
--
--    (B) reader safety
--        * searches running *during* a heavy concurrent insert workload never
--          error/crash and never return a key with no READY hidden-table row
--          (a phantom neighbour is indistinguishable from a real one).
--
--  Self-contained: it creates its own table, model and indexes and uses the
--  in-core 'test_embedding' model type, so it needs no ONNX plugin.  The dataset
--  is 4000 deterministic clustered 128-dim vectors from a fixed-seed LCG (the
--  same construction as tvvec_ann_recall.sql), so the ground truth is
--  reproducible; only the interleaving of the concurrent writers varies between
--  runs, which is exactly what the test is meant to stress.
--
--  Recorded baselines (this build) live in README.vvec-begin.md.
--

echo BOTH "STARTED: VVEC concurrency / writer-safety test\n";

-- ===========================================================================
-- Deterministic clustered vector generator (compact form of the recall test's:
-- 200 cluster centres keyed by mod(seed,200) plus a per-seed perturbation, so a
-- vector's true near neighbours are the others in its cluster).
-- ===========================================================================
create function DB.DBA.VCONC_RAND_VEC (in seed integer, in dim integer) returns any
{
  declare vec any;
  declare i, c integer;
  declare cx, nx bigint;
  declare cen, noi double precision;
  vec := make_array (dim, 'any');
  c := mod (seed, 200);
  cx := mod (cast (c + 1 as bigint) * 2654435761 + 1013904223, 2147483648);
  nx := mod (cast (seed as bigint) * 40503 + 12345, 2147483648);
  if (cx < 0)
    cx := cx + 2147483648;
  if (nx < 0)
    nx := nx + 2147483648;
  for (i := 0; i < dim; i := i + 1)
    {
      cx := mod (cx * 1103515245 + 12345, 2147483648);
      nx := mod (nx * 1103515245 + 12345, 2147483648);
      cen := (cast (cx as double precision) / 2147483648.0) * 2.0 - 1.0;
      noi := ((cast (nx as double precision) / 2147483648.0) * 2.0 - 1.0) * 0.5;
      aset (vec, i, cen + noi);
    }
  return vec;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_RAND_VEC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Extract one value from a __VEC_INDEX_VALIDATE key-value vector.
create function DB.DBA.VCONC_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv))
    return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k)
      return aref (kv, i + 1);
  return null;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_KV STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- A native-128 test_embedding model.  Never invoked (embeddings are inserted
-- directly); it only satisfies the CREATE VECTOR INDEX model requirement.
create table DB.DBA.ONNX_MODELS (
  model_id integer identity,
  model_name varchar not null,
  description varchar,
  model_path varchar not null,
  model_type varchar not null,
  input_names varchar,
  input_shapes varchar,
  output_name varchar,
  output_shape varchar,
  vocab_path varchar,
  max_seq_len integer,
  handle integer,
  created_at datetime,
  updated_at datetime,
  primary key (model_id)
) if not exists;
create unique index ONNX_MODELS_NAME_IDX on DB.DBA.ONNX_MODELS (model_name) if not exists;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-conc-128';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-conc-128', 'deterministic concurrency test model (native dim 128)',
   'internal:vvec-conc-128', 'test_embedding', 'embedding', '1,128', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-conc-128 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Mirror table (no vector index): the brute-force ground-truth source, and the
-- reference id set.  Filled once, single-threaded.
create table DB.DBA.VCONC_VECS (id integer not null primary key, vec long varbinary);
create table DB.DBA.VCONC_GT (qidx integer not null, rank integer not null, gid integer not null,
  primary key (qidx, rank));
-- Doc tables to hang the indexes on (rows never needed for search).
create table DB.DBA.VCONC_DOCS_A (id integer not null primary key, content varchar);
create table DB.DBA.VCONC_DOCS_B (id integer not null primary key, content varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create concurrency tables STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.VCONC_GEN (in n integer, in dim integer)
{
  declare i integer;
  for (i := 1; i <= n; i := i + 1)
    insert into DB.DBA.VCONC_VECS (id, vec) values (i, serialize (DB.DBA.VCONC_RAND_VEC (i, dim)));
}
;
DB.DBA.VCONC_GEN (4000, 128);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": generate 4000 mirror vectors STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VCONC_VECS;
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": mirror row count=" $LAST[1] "\n";

-- ===========================================================================
-- The worker: insert a disjoint id range [lo, hi) into the shared index.  Each
-- aq_request runs this in its own background thread and transaction, so several
-- run against the SAME index simultaneously.  Vectors are regenerated from the
-- seed (a pure function of the id), identical to the mirror.
-- ===========================================================================
create procedure DB.DBA.VCONC_INSERT_RANGE (in idx varchar, in lo integer, in hi integer, in dim integer)
{
  declare i integer;
  for (i := lo; i < hi; i := i + 1)
    {
      __VEC_INDEX_INSERT_EMBEDDING (idx, i, DB.DBA.VCONC_RAND_VEC (i, dim));
      -- Commit each row in its own transaction, as independent client sessions
      -- would.  This releases the shared per-index epoch-catalog row lock
      -- immediately, so the workers genuinely interleave their graph mutations
      -- (contending on the per-index writer lock) instead of serializing behind
      -- one long transaction -- which is the concurrency this test means to
      -- stress.
      commit work;
    }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_INSERT_RANGE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Fan out inserts of ids (base, n] across `threads` workers and wait for all.
create procedure DB.DBA.VCONC_RUN_PARALLEL (in idx varchar, in base integer, in n integer,
    in threads integer, in dim integer)
{
  declare aq any;
  declare t, per, lo, hi integer;
  aq := async_queue (threads);
  per := ((n - base) + threads - 1) / threads;
  for (t := 0; t < threads; t := t + 1)
    {
      lo := base + 1 + t * per;
      hi := lo + per;
      if (hi > n + 1)
        hi := n + 1;
      if (lo < hi)
        aq_request (aq, 'DB.DBA.VCONC_INSERT_RANGE', vector (idx, lo, hi, dim));
    }
  aq_wait_all (aq);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_RUN_PARALLEL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- PHASE A -- writer safety: 8 workers build one index concurrently.
-- ===========================================================================
CREATE VECTOR INDEX VCONC_IDX ON DB.DBA.VCONC_DOCS_A (content)
  USING 'vvec-conc-128' WITH (dimensions = 128, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.VCONC_RUN_PARALLEL ('VCONC_IDX', 0, 4000, 8, 128);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": 8-thread concurrent build of 4000 vectors STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- (A1) the index reconciles clean after a concurrent build.
select DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after concurrent build=" $LAST[1] "\n";

-- (A2) active graph nodes == embedding rows (no lost or double-counted insert).
select case when DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'active_nodes')
            = DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'embedding_rows')
           then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": active_nodes = embedding_rows flag=" $LAST[1] "\n";

-- (A3) active graph nodes == READY hidden-table rows == 4000.
select DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": active_nodes=" $LAST[1] " (expect 4000)\n";

select count (*) from DB.DBA.VCONC_IDX_vec_embeddings where EMBED_STATUS = 'ready';
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": ready hidden-table rows=" $LAST[1] " (expect 4000)\n";

-- (A4) every id 1..4000 present exactly once (no worker dropped or duplicated).
select count (distinct VE_D_ID) from DB.DBA.VCONC_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": distinct inserted ids=" $LAST[1] " (expect 4000)\n";

-- (A5) recall@10 -- the structural check.  A concurrent build that lost edges or
-- corrupted the entry point navigates badly and recall collapses; a correctly
-- serialized build is equivalent to *some* sequential order and stays high.
-- Ground truth: exact cosine top-10 for query seeds 100001..100100.
create procedure DB.DBA.VCONC_GT_FILL (in nq integer, in dim integer)
{
  declare qi, r integer;
  declare q any;
  delete from DB.DBA.VCONC_GT;
  for (qi := 1; qi <= nq; qi := qi + 1)
    {
      q := DB.DBA.VCONC_RAND_VEC (100000 + qi, dim);
      r := 0;
      for (select top 10 id as gid from DB.DBA.VCONC_VECS order by COSINE_DISTANCE (deserialize (vec), q)) do
        { r := r + 1; insert into DB.DBA.VCONC_GT (qidx, rank, gid) values (qi, r, gid); }
    }
}
;
create function DB.DBA.VCONC_RECALL (in idx varchar, in k integer, in ef integer, in nq integer, in dim integer) returns integer
{
  declare qi, j, total integer;
  declare q, res any;
  declare gset any;
  total := 0;
  for (qi := 1; qi <= nq; qi := qi + 1)
    {
      q := DB.DBA.VCONC_RAND_VEC (100000 + qi, dim);
      gset := dict_new ();
      for (select gid from DB.DBA.VCONC_GT where qidx = qi and rank <= k) do
        dict_put (gset, gid, 1);
      res := __VEC_INDEX_SEARCH (idx, q, k, ef);
      for (j := 0; j < length (res); j := j + 1)
        if (dict_get (gset, cast (res[j][0] as integer), 0) = 1)
          total := total + 1;
    }
  return (total * 100) / (nq * k);
}
;
DB.DBA.VCONC_GT_FILL (100, 128);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fill ground truth STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select r, case when r >= 90 then 1 else 0 end
  from (select DB.DBA.VCONC_RECALL ('VCONC_IDX', 10, 128, 100, 128) as r) x;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": concurrent-build recall@10 pct=" $LAST[1] " (>=90) flag=" $LAST[2] "\n";

-- ===========================================================================
-- PHASE B -- reader safety: search a second index WHILE it is being built
-- concurrently, and assert no error and no phantom key.
--
-- A base set is seeded single-threaded so searches have a graph to traverse
-- from the first iteration; the remaining ids are then inserted concurrently by
-- the workers while the main session searches in a tight loop.  The dispatch,
-- the search loop and the wait all live in one procedure because ISQL does not
-- carry PL state (the async_queue handle) across statements.
-- ===========================================================================
CREATE VECTOR INDEX VCONC_IDX2 ON DB.DBA.VCONC_DOCS_B (content)
  USING 'vvec-conc-128' WITH (dimensions = 128, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_IDX2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Seed the base set (ids 1..500) single-threaded.
DB.DBA.VCONC_INSERT_RANGE ('VCONC_IDX2', 1, 501, 128);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed 500 base rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Results land in a table because ISQL cannot pass PL OUT params back to $LAST.
create table DB.DBA.VCONC_STAT (id integer not null primary key, leaks integer, errs integer);

create procedure DB.DBA.VCONC_READER_TEST (in idx varchar, in base integer, in n integer,
    in threads integer, in dim integer, in nq integer, in rounds integer)
{
  declare aq any;
  declare t, per, lo, hi, r, qi, j, leaks, errs integer;
  declare q, res any;
  leaks := 0;
  errs := 0;
  -- Warm the per-index health verdict to OK on the fully-committed base set
  -- BEFORE any concurrent writer starts.  Reconciliation is cached for the life
  -- of the process, so this one search means the searches below never re-run it.
  -- That deliberately keeps this test focused on writer serialization: the
  -- separate graph-ahead orphan sweep (prompt 01) can transiently misread an
  -- in-flight, not-yet-committed insert as an orphan, which is its own concern.
  res := __VEC_INDEX_SEARCH (idx, DB.DBA.VCONC_RAND_VEC (200000, dim), 10, 64);
  -- Launch the concurrent writers for ids (base, n].
  aq := async_queue (threads);
  per := ((n - base) + threads - 1) / threads;
  for (t := 0; t < threads; t := t + 1)
    {
      lo := base + 1 + t * per;
      hi := lo + per;
      if (hi > n + 1)
        hi := n + 1;
      if (lo < hi)
        aq_request (aq, 'DB.DBA.VCONC_INSERT_RANGE', vector (idx, lo, hi, dim));
    }
  -- Search in this thread while the writers run.
  for (r := 0; r < rounds; r := r + 1)
    {
      for (qi := 1; qi <= nq; qi := qi + 1)
        {
          -- One query, isolated: a crash/error is counted, not fatal.
          {
            declare exit handler for sqlstate '*' { errs := errs + 1; };
            q := DB.DBA.VCONC_RAND_VEC (200000 + qi, dim);
            res := __VEC_INDEX_SEARCH (idx, q, 10, 64);
            for (j := 0; j < length (res); j := j + 1)
              {
                if (not exists (select 1 from DB.DBA.VCONC_IDX2_vec_embeddings
                      where VE_D_ID = cast (res[j][0] as integer) and EMBED_STATUS = 'ready'))
                  leaks := leaks + 1;
              }
          }
        }
    }
  aq_wait_all (aq);
  delete from DB.DBA.VCONC_STAT where id = 1;
  insert into DB.DBA.VCONC_STAT (id, leaks, errs) values (1, leaks, errs);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_READER_TEST STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Run it: 7 workers insert ids 501..4000 while 3x100 searches run here.
DB.DBA.VCONC_READER_TEST ('VCONC_IDX2', 500, 4000, 7, 128, 100, 3);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": run concurrent read+write mix STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select leaks from DB.DBA.VCONC_STAT where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": phantom keys returned during concurrent build (expect 0)=" $LAST[1] "\n";
select errs from DB.DBA.VCONC_STAT where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": search errors during concurrent build (expect 0)=" $LAST[1] "\n";

-- After the mix: the WRITE side stays whole -- every committed insert has both
-- a graph node and a hidden-table row -- so all 4000 embeddings are stored.
select count (*) from DB.DBA.VCONC_IDX2_vec_embeddings where EMBED_STATUS = 'ready';
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 ready hidden-table rows after mix=" $LAST[1] " (expect 4000)\n";

-- A search can see an insert's graph node before the inserting transaction's
-- hidden row commits.  It must filter that hit, not retire the node as an orphan:
-- absence from the reader's snapshot does not prove rollback.  The graph must
-- therefore remain complete after the mixed workload without a repair first.
select DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX2'), 'active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 active_nodes after mix=" $LAST[1] " (expect 4000)\n";

-- The durability contract: the index is always repairable from its stored
-- embeddings.  A rebuild after the mix must restore a fully consistent graph.
select __VEC_INDEX_REBUILD ('VCONC_IDX2');
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 rebuild replayed rows=" $LAST[1] " (expect 4000)\n";

select DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX2'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 consistent after rebuild=" $LAST[1] "\n";

select case when DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX2'), 'active_nodes')
            = DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX2'), 'embedding_rows')
           then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 active_nodes = embedding_rows after rebuild flag=" $LAST[1] "\n";

select DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX2'), 'active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4000 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 active_nodes after rebuild=" $LAST[1] " (expect 4000)\n";

-- ===========================================================================
-- PHASE D -- Stage C.6: reader-during-fast-rebuild + writer-on-other-index.
--
-- The fast bulk __VEC_INDEX_REBUILD holds the per-index graph write gate across
-- the whole graph rebuild.  Concurrent searches on that index wait until its
-- pages have stable lifetime again, while a writer on a DIFFERENT index proceeds
-- independently through that index's own gate and writer lock.
--
-- This dispatches a fast rebuild of VCONC_IDX (4000 vectors from Phase A) via
-- async_queue, searches VCONC_IDX from the main thread while it runs, and also
-- dispatches inserts into VCONC_IDX2 on another worker.  After both complete,
-- consistency is verified.
-- ===========================================================================

create procedure DB.DBA.VCONC_REBUILD_READER_TEST (in rebuild_idx varchar,
    in write_idx varchar, in write_lo integer, in write_hi integer, in dim integer,
    in nq integer, in rounds integer)
{
  declare aq any;
  declare r, qi, j, errs, leaks integer;
  declare q, res any;
  errs := 0;
  leaks := 0;
  -- Dispatch the fast rebuild on rebuild_idx.
  aq := async_queue (2);
  aq_request (aq, 'DB.DBA.VCONC_REBUILD_WRAPPED', vector (rebuild_idx));
  -- Dispatch concurrent inserts into write_idx (a different index).
  aq_request (aq, 'DB.DBA.VCONC_INSERT_RANGE', vector (write_idx, write_lo, write_hi, dim));
  -- Search rebuild_idx in this thread while the rebuild + writes run.
  for (r := 0; r < rounds; r := r + 1)
    {
      for (qi := 1; qi <= nq; qi := qi + 1)
        {
          declare exit handler for sqlstate '*' { errs := errs + 1; };
          q := DB.DBA.VCONC_RAND_VEC (300000 + qi, dim);
          res := __VEC_INDEX_SEARCH (rebuild_idx, q, 10, 64);
          for (j := 0; j < length (res); j := j + 1)
            {
              if (not exists (select 1 from DB.DBA.VCONC_IDX_vec_embeddings
                    where VE_D_ID = cast (res[j][0] as integer) and EMBED_STATUS = 'ready'))
                leaks := leaks + 1;
            }
        }
    }
  aq_wait_all (aq);
  delete from DB.DBA.VCONC_STAT where id = 2;
  insert into DB.DBA.VCONC_STAT (id, leaks, errs) values (2, leaks, errs);
}
;

-- Wrapper so async_queue can call __VEC_INDEX_REBUILD with the 'fast' argument.
create procedure DB.DBA.VCONC_REBUILD_WRAPPED (in idx varchar)
{
  declare r any;
  r := __VEC_INDEX_REBUILD (idx, 'fast');
}
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VCONC_REBUILD_READER_TEST STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Run: fast rebuild VCONC_IDX + insert 4001..5000 into VCONC_IDX2, while
-- searching VCONC_IDX.  VCONC_IDX2 already has 4000 from Phase B/C; this adds
-- 1000 more.
DB.DBA.VCONC_REBUILD_READER_TEST ('VCONC_IDX', 'VCONC_IDX2', 4001, 5001, 128, 50, 5);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": run concurrent fast-rebuild + read + cross-index write STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select errs from DB.DBA.VCONC_STAT where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": search errors during fast rebuild (expect 0)=" $LAST[1] "\n";

select leaks from DB.DBA.VCONC_STAT where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": phantom keys during fast rebuild (expect 0)=" $LAST[1] "\n";

-- VCONC_IDX is consistent after the fast rebuild.
select DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX consistent after fast rebuild=" $LAST[1] "\n";

select case when DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'active_nodes')
            = DB.DBA.VCONC_KV (__VEC_INDEX_VALIDATE ('VCONC_IDX'), 'embedding_rows')
           then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX active_nodes = embedding_rows after fast rebuild flag=" $LAST[1] "\n";

-- VCONC_IDX2 received the concurrent writes (4000 from before + 1000 new = 5000).
select count (*) from DB.DBA.VCONC_IDX2_vec_embeddings where EMBED_STATUS = 'ready';
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";
ECHO BOTH ": VCONC_IDX2 rows after concurrent write-during-rebuild=" $LAST[1] " (expect 5000)\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
-- A vector index is dropped with plain DROP INDEX; there is no
-- DROP VECTOR INDEX form in the grammar (sql3.y adds only the
-- CREATE ... VECTOR INDEX production).  These read DROP VECTOR INDEX until
-- 2026-09-18 and were therefore seven SQ074 syntax errors that CHECK_LOG does
-- not count -- so the drop path was never exercised here at all.  Asserted now,
-- because an unasserted DDL statement in a cleanup block is how that survived.

drop index VCONC_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VCONC_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VCONC_IDX2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VCONC_IDX2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
drop table DB.DBA.VCONC_DOCS_A;
drop table DB.DBA.VCONC_DOCS_B;
drop table DB.DBA.VCONC_VECS;
drop table DB.DBA.VCONC_GT;
drop table DB.DBA.VCONC_STAT;
drop procedure DB.DBA.VCONC_GEN;
drop procedure DB.DBA.VCONC_INSERT_RANGE;
drop procedure DB.DBA.VCONC_RUN_PARALLEL;
drop procedure DB.DBA.VCONC_GT_FILL;
drop procedure DB.DBA.VCONC_READER_TEST;
drop procedure DB.DBA.VCONC_REBUILD_READER_TEST;
drop procedure DB.DBA.VCONC_REBUILD_WRAPPED;
drop function DB.DBA.VCONC_RECALL;
drop function DB.DBA.VCONC_KV;
drop function DB.DBA.VCONC_RAND_VEC;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-conc-128';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": concurrency test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: VVEC concurrency / writer-safety test\n";
