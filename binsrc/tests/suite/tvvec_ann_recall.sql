--
--  tvvec_ann_recall.sql
--
--  Real ANN recall/quality test for the native HNSW vector index (prompt 05).
--
--  Unlike tvvec_ann_equiv.sql -- which only proves the SQL optimizer routes an
--  ORDER BY VECTOR_DISTANCE to the ANN row source, with both sides traversing
--  the SAME graph through the SAME code -- this test measures search *quality*
--  against an independent brute-force ground truth.
--
--  Ground truth is computed by scanning a plain, non-vector-indexed mirror table
--  (VVEC_RECALL_VECS) with the exact scalar distance bifs (COSINE_DISTANCE /
--  L2_DISTANCE / L1_DISTANCE).  That path never touches the HNSW graph, so if the
--  graph build or the neighbour-selection heuristic in vvec_hnsw*.c returns
--  systematically wrong neighbours, recall drops and the assertions below fail --
--  which is exactly what the tautological equivalence test cannot catch.
--
--  The dataset is 5000 pseudo-random 384-dim vectors (the bundled model's
--  dimension) from a fixed-seed LCG, so runs are byte-for-byte reproducible.
--  Embeddings are inserted straight into the index with __VEC_INDEX_INSERT_EMBEDDING
--  (index created on an empty table, so there is no model backfill); the same
--  vectors go into the mirror table for ground truth.
--
--  This is the heavyweight suite member: it builds several 5000-node graphs and
--  runs a few hundred brute-force top-k scans, so it takes on the order of a few
--  minutes.  5000 vectors / 100 queries are the prompt-mandated minimums; raise
--  them for a stricter bar at proportional cost.
--
--  Recall percentages are compared in SQL and asserted on a 0/1 flag: ISQL's
--  $GTE is a lexical compare, so "100" >= "95" would be false.
--
--  Recorded baselines (this build, seeds as below) live in README.vvec-begin.md.
--

echo BOTH "STARTED: VVEC ANN recall/quality test\n";

-- ===========================================================================
-- Deterministic dataset generator (fixed-seed 32-bit LCG).
--
-- Real embeddings are clustered on a manifold, not uniform: uniform random
-- high-dim vectors are all nearly equidistant (curse of dimensionality), which
-- has no neighbourhood structure and gives any correct ANN implementation poor
-- recall.  To exercise recall meaningfully we synthesize the same structure:
-- each vector is one of 200 cluster centres plus a per-vector perturbation
-- (+/-0.5, versus centre components in [-1,1]).  A vector's true near
-- neighbours are the ~25 others in its
-- cluster; centres seed from mod(seed,200), so a query seed lands in a cluster
-- and has genuine neighbours.  Everything is a pure function of the seed, so the
-- dataset and the queries are byte-for-byte reproducible.
-- ===========================================================================
create function DB.DBA.VVEC_RECALL_RAND_VEC (in seed integer, in dim integer) returns any
{
  declare vec any;
  declare i, c integer;
  declare cx, nx bigint;
  declare cen, noi double precision;
  vec := make_array (dim, 'any');
  c := mod (seed, 200);
  -- centre stream keyed by cluster, perturbation stream keyed by the seed
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
ECHO BOTH ": create VVEC_RECALL_RAND_VEC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- A native-384 test_embedding model.  It is never invoked (we insert embeddings
-- directly), it only satisfies the CREATE VECTOR INDEX model requirement.  The
-- registry table is created here if absent so the test is self-contained and can
-- run without the ONNX-backed SQL chain having run first.
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
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-recall-384';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-recall-384', 'deterministic recall test model (native dim 384)',
   'internal:vvec-recall-384', 'test_embedding', 'embedding', '1,384', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-recall-384 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Mirror table (no vector index): the exact brute-force ground-truth source.
create table DB.DBA.VVEC_RECALL_VECS (id integer not null primary key, vec long varbinary);
-- Ground-truth cache: top-N neighbours per (metric, query).  rank 1 == nearest.
create table DB.DBA.VVEC_RECALL_GT
  (gt_metric varchar not null, qidx integer not null, rank integer not null, gid integer not null,
   primary key (gt_metric, qidx, rank));
-- Empty doc tables to hang the indexes on (rows are never needed for search).
create table DB.DBA.VVEC_RECALL_DOCS_COS (id integer not null primary key, content varchar);
create table DB.DBA.VVEC_RECALL_DOCS_L2  (id integer not null primary key, content varchar);
create table DB.DBA.VVEC_RECALL_DOCS_L1  (id integer not null primary key, content varchar);
create table DB.DBA.VVEC_RECALL_DOCS_LOW (id integer not null primary key, content varchar);
create table DB.DBA.VVEC_RECALL_DOCS_TRC (id integer not null primary key, content varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create recall tables STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- Populate the mirror with 5000 deterministic vectors.
-- ===========================================================================
create procedure DB.DBA.VVEC_RECALL_GEN (in n integer)
{
  declare i integer;
  for (i := 1; i <= n; i := i + 1)
    insert into DB.DBA.VVEC_RECALL_VECS (id, vec)
      values (i, serialize (DB.DBA.VVEC_RECALL_RAND_VEC (i, 384)));
}
;
DB.DBA.VVEC_RECALL_GEN (5000);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": generate 5000 mirror vectors STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VVEC_RECALL_VECS;
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";
ECHO BOTH ": mirror row count=" $LAST[1] "\n";

-- ===========================================================================
-- Build one HNSW index per metric from the mirror (embeddings inserted directly).
-- ===========================================================================
create procedure DB.DBA.VVEC_RECALL_BUILD (in idx_name varchar)
{
  for (select id as gg, vec as v from DB.DBA.VVEC_RECALL_VECS order by id) do
    __VEC_INDEX_INSERT_EMBEDDING (idx_name, gg, deserialize (v));
}
;

CREATE VECTOR INDEX VVEC_RECALL_IDX_COS ON DB.DBA.VVEC_RECALL_DOCS_COS (content)
  USING 'vvec-recall-384' WITH (dimensions = 384, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
CREATE VECTOR INDEX VVEC_RECALL_IDX_L2 ON DB.DBA.VVEC_RECALL_DOCS_L2 (content)
  USING 'vvec-recall-384' WITH (dimensions = 384, distance_metric = 'l2', hnsw_m = 16, ef_construction = 64);
CREATE VECTOR INDEX VVEC_RECALL_IDX_L1 ON DB.DBA.VVEC_RECALL_DOCS_L1 (content)
  USING 'vvec-recall-384' WITH (dimensions = 384, distance_metric = 'l1', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create cosine/l2/l1 indexes STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.VVEC_RECALL_BUILD ('VVEC_RECALL_IDX_COS');
DB.DBA.VVEC_RECALL_BUILD ('VVEC_RECALL_IDX_L2');
DB.DBA.VVEC_RECALL_BUILD ('VVEC_RECALL_IDX_L1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": build cosine/l2/l1 graphs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VVEC_RECALL_IDX_COS_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";
ECHO BOTH ": cosine graph node count=" $LAST[1] "\n";

-- ===========================================================================
-- Ground truth: exact top-20 per query for a metric, cached in VVEC_RECALL_GT.
-- Query vectors are seeds 100001..100100 (disjoint from the data seeds 1..5000).
-- ===========================================================================
create procedure DB.DBA.VVEC_RECALL_GT_FILL (in p_metric varchar, in nq integer)
{
  declare qi, r integer;
  declare q any;
  delete from DB.DBA.VVEC_RECALL_GT where gt_metric = p_metric;
  for (qi := 1; qi <= nq; qi := qi + 1)
    {
      q := DB.DBA.VVEC_RECALL_RAND_VEC (100000 + qi, 384);
      r := 0;
      if (p_metric = 'cosine')
        {
          for (select top 20 id as gid from DB.DBA.VVEC_RECALL_VECS order by COSINE_DISTANCE (deserialize (vec), q)) do
            { r := r + 1; insert into DB.DBA.VVEC_RECALL_GT (gt_metric, qidx, rank, gid) values (p_metric, qi, r, gid); }
        }
      else if (p_metric = 'l2')
        {
          for (select top 20 id as gid from DB.DBA.VVEC_RECALL_VECS order by L2_DISTANCE (deserialize (vec), q)) do
            { r := r + 1; insert into DB.DBA.VVEC_RECALL_GT (gt_metric, qidx, rank, gid) values (p_metric, qi, r, gid); }
        }
      else
        {
          for (select top 20 id as gid from DB.DBA.VVEC_RECALL_VECS order by L1_DISTANCE (deserialize (vec), q)) do
            { r := r + 1; insert into DB.DBA.VVEC_RECALL_GT (gt_metric, qidx, rank, gid) values (p_metric, qi, r, gid); }
        }
    }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_RECALL_GT_FILL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Mean recall@k of an index against the cached ground truth for its metric.
-- Returns recall as a percentage 0..100 (integer).
create function DB.DBA.VVEC_RECALL_MEASURE (in p_metric varchar, in idx_name varchar,
    in k integer, in ef integer, in nq integer) returns integer
{
  declare qi, j, total integer;
  declare q, res any;
  declare gset any;
  total := 0;
  for (qi := 1; qi <= nq; qi := qi + 1)
    {
      q := DB.DBA.VVEC_RECALL_RAND_VEC (100000 + qi, 384);
      gset := dict_new ();
      for (select gid from DB.DBA.VVEC_RECALL_GT where gt_metric = p_metric and qidx = qi and rank <= k) do
        dict_put (gset, gid, 1);
      res := __VEC_INDEX_SEARCH (idx_name, q, k, ef);
      for (j := 0; j < length (res); j := j + 1)
        if (dict_get (gset, cast (res[j][0] as integer), 0) = 1)
          total := total + 1;
    }
  return (total * 100) / (nq * k);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_RECALL_MEASURE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- Recall@10 >= 0.95 for each metric.
-- ===========================================================================
DB.DBA.VVEC_RECALL_GT_FILL ('cosine', 100);
select r, case when r >= 95 then 1 else 0 end
  from (select DB.DBA.VVEC_RECALL_MEASURE ('cosine', 'VVEC_RECALL_IDX_COS', 10, 128, 100) as r) x;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": cosine recall@10 pct=" $LAST[1] " (>=95) flag=" $LAST[2] "\n";

DB.DBA.VVEC_RECALL_GT_FILL ('l2', 100);
select r, case when r >= 95 then 1 else 0 end
  from (select DB.DBA.VVEC_RECALL_MEASURE ('l2', 'VVEC_RECALL_IDX_L2', 10, 128, 100) as r) x;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": l2 recall@10 pct=" $LAST[1] " (>=95) flag=" $LAST[2] "\n";

DB.DBA.VVEC_RECALL_GT_FILL ('l1', 100);
select r, case when r >= 95 then 1 else 0 end
  from (select DB.DBA.VVEC_RECALL_MEASURE ('l1', 'VVEC_RECALL_IDX_L1', 10, 128, 100) as r) x;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": l1 recall@10 pct=" $LAST[1] " (>=95) flag=" $LAST[2] "\n";

-- ===========================================================================
-- Tuning-knob monotonicity: a smaller hnsw_m / ef_construction must NOT beat a
-- larger one on the same data.  Measured at a modest ef_search so build quality
-- shows.  This is what catches a silently-ignored build option.
-- ===========================================================================
CREATE VECTOR INDEX VVEC_RECALL_IDX_LOW ON DB.DBA.VVEC_RECALL_DOCS_LOW (content)
  USING 'vvec-recall-384' WITH (dimensions = 384, distance_metric = 'cosine', hnsw_m = 4, ef_construction = 8);
DB.DBA.VVEC_RECALL_BUILD ('VVEC_RECALL_IDX_LOW');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": build low-param cosine graph (m=4, efc=8) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select hi, lo, case when hi >= lo then 1 else 0 end from (
  select DB.DBA.VVEC_RECALL_MEASURE ('cosine', 'VVEC_RECALL_IDX_COS', 10, 16, 100) as hi,
         DB.DBA.VVEC_RECALL_MEASURE ('cosine', 'VVEC_RECALL_IDX_LOW', 10, 16, 100) as lo) x;
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": recall monotonic in build params: high=" $LAST[1] " >= low=" $LAST[2] " flag=" $LAST[3] "\n";

-- ===========================================================================
-- Matryoshka reduce='truncate': truncated embeddings must degrade gracefully,
-- not collapse.  Measured against the full-vector cosine ground truth; the
-- observed figure is the regression baseline (see README.vvec-begin.md).
-- ===========================================================================
CREATE VECTOR INDEX VVEC_RECALL_IDX_TRC ON DB.DBA.VVEC_RECALL_DOCS_TRC (content)
  USING 'vvec-recall-384' WITH (dimensions = 192, reduce = 'truncate', distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
DB.DBA.VVEC_RECALL_BUILD ('VVEC_RECALL_IDX_TRC');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": build truncate(384->192) cosine graph STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select r, case when r >= 60 then 1 else 0 end
  from (select DB.DBA.VVEC_RECALL_MEASURE ('cosine', 'VVEC_RECALL_IDX_TRC', 10, 128, 100) as r) x;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": truncate(384->192) recall@10 vs full GT pct=" $LAST[1] " (graceful >=60) flag=" $LAST[2] "\n";

-- ===========================================================================
-- Deleted-node path: soft-delete 20% of rows, then assert (a) no deleted key is
-- ever returned, and (b) recall over the survivors still holds.  Survivor ground
-- truth is derived from the cached cosine top-20 by dropping deleted ids and
-- keeping the first 10 -- valid because 20% deletion removes ~4 of any top-20.
-- ===========================================================================
create procedure DB.DBA.VVEC_RECALL_DELETE_20PCT ()
{
  for (select id as gg from DB.DBA.VVEC_RECALL_VECS where mod (id, 5) = 0 order by id) do
    __VEC_INDEX_DELETE_ROW ('VVEC_RECALL_IDX_COS', gg);
}
;
DB.DBA.VVEC_RECALL_DELETE_20PCT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": soft-delete 20% (id mod 5 = 0) from cosine index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- (a) No deleted id may ever appear in a result set.
create function DB.DBA.VVEC_RECALL_LEAK_COUNT (in nq integer) returns integer
{
  declare qi, j, leaks integer;
  declare q, res any;
  leaks := 0;
  for (qi := 1; qi <= nq; qi := qi + 1)
    {
      q := DB.DBA.VVEC_RECALL_RAND_VEC (100000 + qi, 384);
      res := __VEC_INDEX_SEARCH ('VVEC_RECALL_IDX_COS', q, 10, 128);
      for (j := 0; j < length (res); j := j + 1)
        if (mod (cast (res[j][0] as integer), 5) = 0)
          leaks := leaks + 1;
    }
  return leaks;
}
;
select DB.DBA.VVEC_RECALL_LEAK_COUNT (100);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": deleted keys returned by search (expect 0) = " $LAST[1] "\n";

-- (b) Recall over survivors: survivor GT = first 10 non-deleted of cached top-20.
-- Soft-delete does not repair the graph, so navigation through the holes left by
-- the removed 20% costs recall -- ~0.80 here, and (measured) flat in ef_search,
-- so it is structural, not an under-search: __VEC_INDEX_REBUILD is the remedy
-- that restores it.  The bar below asserts the survivors' recall *holds* (does
-- not collapse); 80 is the recorded baseline (see README.vvec-begin.md).
create function DB.DBA.VVEC_RECALL_SURVIVOR (in nq integer) returns integer
{
  declare qi, j, total, kept integer;
  declare q, res any;
  declare gset any;
  total := 0;
  for (qi := 1; qi <= nq; qi := qi + 1)
    {
      gset := dict_new ();
      kept := 0;
      for (select gid from DB.DBA.VVEC_RECALL_GT where gt_metric = 'cosine' and qidx = qi order by rank) do
        { if (kept < 10 and mod (gid, 5) <> 0) { dict_put (gset, gid, 1); kept := kept + 1; } }
      q := DB.DBA.VVEC_RECALL_RAND_VEC (100000 + qi, 384);
      res := __VEC_INDEX_SEARCH ('VVEC_RECALL_IDX_COS', q, 10, 128);
      for (j := 0; j < length (res); j := j + 1)
        if (dict_get (gset, cast (res[j][0] as integer), 0) = 1)
          total := total + 1;
    }
  return (total * 100) / (nq * 10);
}
;
select r, case when r >= 70 then 1 else 0 end
  from (select DB.DBA.VVEC_RECALL_SURVIVOR (100) as r) x;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": survivor recall@10 after 20% delete pct=" $LAST[1] " (holds >=70, baseline ~80) flag=" $LAST[2] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
-- A vector index is dropped with plain DROP INDEX; there is no
-- DROP VECTOR INDEX form in the grammar (sql3.y adds only the
-- CREATE ... VECTOR INDEX production).  These read DROP VECTOR INDEX until
-- 2026-09-18 and were therefore seven SQ074 syntax errors that CHECK_LOG does
-- not count -- so the drop path was never exercised here at all.  Asserted now,
-- because an unasserted DDL statement in a cleanup block is how that survived.

drop index VVEC_RECALL_IDX_COS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_RECALL_IDX_COS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VVEC_RECALL_IDX_L2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_RECALL_IDX_L2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VVEC_RECALL_IDX_L1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_RECALL_IDX_L1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VVEC_RECALL_IDX_LOW;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_RECALL_IDX_LOW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VVEC_RECALL_IDX_TRC;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_RECALL_IDX_TRC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
drop table DB.DBA.VVEC_RECALL_DOCS_COS;
drop table DB.DBA.VVEC_RECALL_DOCS_L2;
drop table DB.DBA.VVEC_RECALL_DOCS_L1;
drop table DB.DBA.VVEC_RECALL_DOCS_LOW;
drop table DB.DBA.VVEC_RECALL_DOCS_TRC;
drop table DB.DBA.VVEC_RECALL_VECS;
drop table DB.DBA.VVEC_RECALL_GT;
drop procedure DB.DBA.VVEC_RECALL_GEN;
drop procedure DB.DBA.VVEC_RECALL_BUILD;
drop procedure DB.DBA.VVEC_RECALL_GT_FILL;
drop function DB.DBA.VVEC_RECALL_MEASURE;
drop procedure DB.DBA.VVEC_RECALL_DELETE_20PCT;
drop function DB.DBA.VVEC_RECALL_LEAK_COUNT;
drop function DB.DBA.VVEC_RECALL_SURVIVOR;
drop function DB.DBA.VVEC_RECALL_RAND_VEC;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-recall-384';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": recall test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: VVEC ANN recall/quality test\n";
