--
--  tvvec_sql_backfill.sql
--
--  CREATE VECTOR INDEX on a table that already has rows must index every row.
--
--  The backfill queued the rows with a SELECT whose select list did the
--  queueing, run through exec () without fetching its result, and exec
--  evaluates such a select list for the first vector batch only.  The index
--  came up ready holding one batch of the table -- 1,000 rows with the stock
--  virtuoso.ini -- and said nothing.
--
--  Each CREATE below runs with the stock virtuoso.ini's batch (VectorSize =
--  1000, AdjustVectorSize = 0).  The suite's template sets neither, so it
--  gets the C defaults (10,000, adjusting), which would hide the bug for any
--  table under 10,000 rows; the server's own values are put back after each
--  statement.
--
--  Sections, all of them tests of the change (each fails before it):
--    1. 2,500 rows of text, model test_embedding: every row is in the hidden
--       table and the graph, rows from all three batches by key.  Before:
--       1,000.
--    2. The same for a precomputed-vector (source_kind = 'vector') index.
--    3. A wrong-dimension vector in row 1,700 -- past the first batch -- fails
--       the CREATE with VEC31 and leaves no index, as one in the first batch
--       already does (tvvec_passthrough_column, section 8).  Before: the row
--       was never read and the CREATE succeeded.
--  and one guard, which holds on both sides:
--    4. After the create, an inserted row still goes through the DML trigger
--       and the queue: the index grows by exactly one.
--  5. Writing a row to an indexed table costs little more than to a plain
--     one: 5,000 inserts take at most 100 times as long (a ratio, measured in
--     the same run).  Before, every queued row tried three CREATE TABLEs and
--     the ratio was over 1,000.
--  6. CREATE with build = 'bulk' over 10,000 rows indexes every row and
--     builds the graph in one pass, packed; an unknown build method is refused
--     with VEC81.
--
--  Self-contained: the in-core deterministic test_embedding model, and no
--  ANN assertion, so it needs neither ONNX nor the VVEC_BEGIN_* fixtures.
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

echo BOTH "STARTED: SQL CREATE VECTOR INDEX backfills every existing row\n";

-- ===========================================================================
-- Fixtures
-- ===========================================================================
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
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-bf-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values ('vvec-bf-8', 'deterministic 8-dim test model', 'internal:vvec-bf-8',
        'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register the test model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.VEC_SQL_QUEUE_INIT ();

create function DB.DBA.VVEC_BF_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv))
    return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k)
      return aref (kv, i + 1);
  return null;
};

create function DB.DBA.VVEC_BF_METRIC (in idx varchar, in k varchar) returns integer
{
  return cast (DB.DBA.VVEC_BF_KV (__VEC_INDEX_METRICS (idx), k) as integer);
};

create function DB.DBA.VVEC_BF_VEC8 (in a integer) returns any
{
  return vector (a, a + 1, a + 2, a + 3, a + 4, a + 5, a + 6, a + 7);
};

--  Run a statement with the stock virtuoso.ini's vector batch, then put the
--  server's own values back.  '00000', or the SQLSTATE and the message.
create function DB.DBA.VVEC_BF_EXEC_STOCK_BATCH (in stmt varchar) returns varchar
{
  declare bs, dyn integer;
  declare st, msg varchar;
  bs := __dbf_set ('dc_batch_sz', 1000);
  dyn := __dbf_set ('enable_dyn_batch_sz', 0);
  st := '00000';
  msg := '';
  exec (stmt, st, msg);
  __dbf_set ('dc_batch_sz', bs);
  __dbf_set ('enable_dyn_batch_sz', dyn);
  if (st = '00000')
    return st;
  return st || ' ' || msg;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create helpers STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VVEC_BF_T (ID integer not null primary key, TXT varchar);
create table DB.DBA.VVEC_BF_V (ID integer not null primary key, EMB any);
create table DB.DBA.VVEC_BF_BAD (ID integer not null primary key, EMB any);

create procedure DB.DBA.VVEC_BF_FILL (in n integer, in bad_row integer)
{
  declare i integer;
  for (i := 1; i <= n; i := i + 1)
    {
      insert into DB.DBA.VVEC_BF_T (ID, TXT)
        values (i, sprintf ('row %d of the backfill test, %d words in', i, mod (i * 7919, 1000)));
      insert into DB.DBA.VVEC_BF_V (ID, EMB)
        values (i, serialize (DB.DBA.VVEC_BF_VEC8 (i)));
      insert into DB.DBA.VVEC_BF_BAD (ID, EMB)
        values (i, serialize (case when i = bad_row then vector (i, i + 1, i + 2) else DB.DBA.VVEC_BF_VEC8 (i) end));
    }
  commit work;
};

DB.DBA.VVEC_BF_FILL (2500, 1700);
select (select count (*) from DB.DBA.VVEC_BF_T) + (select count (*) from DB.DBA.VVEC_BF_V) + (select count (*) from DB.DBA.VVEC_BF_BAD);
ECHO BOTH $IF $EQU $LAST[1] 7500 "PASSED" "***FAILED";
ECHO BOTH ": three tables of 2,500 rows=" $LAST[1] "\n";

-- ===========================================================================
-- 1. Text, model test_embedding
-- ===========================================================================
select DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_IDX on DB.DBA.VVEC_BF_T (TXT) using ''vvec-bf-8'' with (dimensions = 8, distance_metric = ''cosine'', hnsw_m = 8, ef_construction = 64)');
ECHO BOTH $IF $EQU $LAST[1] "00000" "PASSED" "***FAILED";
ECHO BOTH ": create the text index over 2,500 rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_METRIC ('VVEC_BF_IDX', 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 2500 "PASSED" "***FAILED";
ECHO BOTH ": text index managed_rows (was one batch, 1000)=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_METRIC ('VVEC_BF_IDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 2500 "PASSED" "***FAILED";
ECHO BOTH ": text index graph_nodes=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_BF_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 2500 "PASSED" "***FAILED";
ECHO BOTH ": text index embedding rows=" $LAST[1] "\n";

--  By key, so a count that came out right for the wrong rows cannot pass: the
--  first and last row of each of the three batches.
select count (*) from DB.DBA.VVEC_BF_IDX_vec_embeddings where VE_D_ID in (1, 1000, 1001, 2000, 2001, 2500);
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": rows 1, 1000, 1001, 2000, 2001 and 2500 embedded=" $LAST[1] "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_BF_IDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": nothing left queued for the text index=" $LAST[1] "\n";

-- ===========================================================================
-- 2. Precomputed vectors (source_kind = 'vector')
-- ===========================================================================
create procedure DB.DBA.VVEC_BF_GATE (in val varchar) returns varchar
{
  declare prev any;
  prev := registry_get ('__vvec_passthrough_column');
  registry_set ('__vvec_passthrough_column', val);
  return case when isstring (prev) then prev else 'off' end;
};
create table DB.DBA.VVEC_BF_GATE_WAS (V varchar);
insert into DB.DBA.VVEC_BF_GATE_WAS (V) values (DB.DBA.VVEC_BF_GATE ('on'));

select DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_VIDX on DB.DBA.VVEC_BF_V (EMB) with (dimensions = 8, distance_metric = ''cosine'', hnsw_m = 8, ef_construction = 64, source_kind = ''vector'')');
ECHO BOTH $IF $EQU $LAST[1] "00000" "PASSED" "***FAILED";
ECHO BOTH ": create the vector index over 2,500 rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_METRIC ('VVEC_BF_VIDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 2500 "PASSED" "***FAILED";
ECHO BOTH ": vector index graph_nodes (was one batch, 1000)=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_BF_VIDX_vec_embeddings where VE_D_ID in (1, 1000, 1001, 2000, 2001, 2500);
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": vector rows 1, 1000, 1001, 2000, 2001 and 2500 indexed=" $LAST[1] "\n";

-- ===========================================================================
-- 3. A bad row past the first batch fails the CREATE
-- ===========================================================================
select case when DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_BADIDX on DB.DBA.VVEC_BF_BAD (EMB) with (dimensions = 8, distance_metric = ''cosine'', hnsw_m = 8, ef_construction = 64, source_kind = ''vector'')') like '%VEC31%' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a wrong-dimension vector in row 1,700 fails the create with VEC31=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_BF_BADIDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": the failed create left no index=" $LAST[1] "\n";

-- ===========================================================================
-- 4. Guard: after the create, DML still goes through the trigger and queue
-- ===========================================================================
create table DB.DBA.VVEC_BF_BEFORE (N integer);
insert into DB.DBA.VVEC_BF_BEFORE (N) values (DB.DBA.VVEC_BF_METRIC ('VVEC_BF_IDX', 'managed_rows'));
insert into DB.DBA.VVEC_BF_T (ID, TXT) values (2501, 'a row inserted after the create');
DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
select DB.DBA.VVEC_BF_METRIC ('VVEC_BF_IDX', 'managed_rows') - (select N from DB.DBA.VVEC_BF_BEFORE);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a row inserted after the create is indexed through the queue, rows added=" $LAST[1] "\n";

-- ===========================================================================
-- 5. A row written to an indexed table is queued cheaply
-- ===========================================================================
--  The AFTER INSERT trigger queues every row through VEC_SQL_QUEUE_ENQUEUE,
--  which ran VEC_SQL_QUEUE_INIT each time: three CREATE TABLEs that fail,
--  each compiled afresh.  10,000 inserts took ~40 s against 36 ms without an
--  index.  Timed here against the same inserts into a plain table, in the
--  same run, so the assertion is a ratio and holds on a slower machine: 5,000
--  rows, and the indexed table may take at most 100 times as long.  Before
--  the fix the ratio was over 1,000.
create table DB.DBA.VVEC_BF_PLAIN (ID integer not null primary key, TXT varchar);
create table DB.DBA.VVEC_BF_DML (ID integer not null primary key, TXT varchar);
create vector index VVEC_BF_DML_IDX on DB.DBA.VVEC_BF_DML (TXT) using 'vvec-bf-8'
  with (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create an index on an empty table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.VVEC_BF_INSERT_PLAIN (in n integer) returns integer
{
  declare i, t0 integer;
  t0 := msec_time ();
  for (i := 1; i <= n; i := i + 1)
    insert into DB.DBA.VVEC_BF_PLAIN (ID, TXT) values (i, sprintf ('row %d, written after the create', i));
  commit work;
  return msec_time () - t0;
};
create procedure DB.DBA.VVEC_BF_INSERT_INDEXED (in n integer) returns integer
{
  declare i, t0 integer;
  t0 := msec_time ();
  for (i := 1; i <= n; i := i + 1)
    insert into DB.DBA.VVEC_BF_DML (ID, TXT) values (i, sprintf ('row %d, written after the create', i));
  commit work;
  return msec_time () - t0;
};
create table DB.DBA.VVEC_BF_TIMES (PLAIN_MS integer, INDEXED_MS integer);
insert into DB.DBA.VVEC_BF_TIMES (PLAIN_MS, INDEXED_MS)
  values (DB.DBA.VVEC_BF_INSERT_PLAIN (5000), DB.DBA.VVEC_BF_INSERT_INDEXED (5000));
select sprintf ('%d ms plain, %d ms indexed', PLAIN_MS, INDEXED_MS) from DB.DBA.VVEC_BF_TIMES;
ECHO BOTH "+ 5,000 inserts: " $LAST[1] "\n";

select case when INDEXED_MS <= 100 * (PLAIN_MS + 1) then 1 else 0 end from DB.DBA.VVEC_BF_TIMES;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": inserting into the indexed table takes at most 100 times the plain table's time=" $LAST[1] "\n";

--  Guard, on both sides: every row was queued.
select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_BF_DML_IDX' and VQ_STATE = 'pending';
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";
ECHO BOTH ": every inserted row is queued=" $LAST[1] "\n";

-- ===========================================================================
-- 6. build = 'bulk'
-- ===========================================================================
--  CREATE over 10,000 text rows with build = 'bulk': every row is embedded
--  and staged, and the graph is derived in one pass at the end, by the fast
--  builder, which writes packed pages -- an incremental build writes one 8 KB
--  page per node, so __VEC_INDEX_PAGE_STATS says 'legacy' for it.  10,000,
--  because that is where __VEC_INDEX_REBUILD's 'auto' starts choosing the fast
--  builder (VVEC_REBUILD_AUTO_MIN); below it, replay.  An unknown build method
--  is refused at CREATE.  The rows keep the hash of their text (a guard: the
--  incremental path keeps it too).
create function DB.DBA.VVEC_BF_FORMAT (in idx varchar) returns varchar
{
  return cast (DB.DBA.VVEC_BF_KV (__VEC_INDEX_PAGE_STATS (idx), 'format') as varchar);
};
create table DB.DBA.VVEC_BF_BULK (ID integer not null primary key, TXT varchar);
create procedure DB.DBA.VVEC_BF_BULK_FILL (in n integer)
{
  declare i integer;
  for (i := 1; i <= n; i := i + 1)
    insert into DB.DBA.VVEC_BF_BULK (ID, TXT)
      values (i, sprintf ('row %d of the bulk test, %d words in', i, mod (i * 7919, 1000)));
  commit work;
};
DB.DBA.VVEC_BF_BULK_FILL (10000);
select count (*) from DB.DBA.VVEC_BF_BULK;
ECHO BOTH $IF $EQU $LAST[1] 10000 "PASSED" "***FAILED";
ECHO BOTH ": 10,000 text rows for the bulk build=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_BULK_IDX on DB.DBA.VVEC_BF_BULK (TXT) using ''vvec-bf-8'' with (dimensions = 8, distance_metric = ''cosine'', hnsw_m = 8, ef_construction = 64, build = ''bulk'')');
ECHO BOTH $IF $EQU $LAST[1] "00000" "PASSED" "***FAILED";
ECHO BOTH ": create with build = 'bulk'=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_METRIC ('VVEC_BF_BULK_IDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 10000 "PASSED" "***FAILED";
ECHO BOTH ": bulk index graph_nodes=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_FORMAT ('VVEC_BF_BULK_IDX');
ECHO BOTH $IF $EQU $LAST[1] "packed" "PASSED" "***FAILED";
ECHO BOTH ": the bulk graph was built in one pass, packed=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_FORMAT ('VVEC_BF_IDX');
ECHO BOTH $IF $EQU $LAST[1] "legacy" "PASSED" "***FAILED";
ECHO BOTH ": the incremental index of section 1 was not=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_BF_BULK_IDX_vec_embeddings where SOURCE_HASH is not null;
ECHO BOTH $IF $EQU $LAST[1] 10000 "PASSED" "***FAILED";
ECHO BOTH ": bulk rows keep the hash of their text=" $LAST[1] "\n";

create table DB.DBA.VVEC_BF_BB (ID integer not null primary key, TXT varchar);
select case when DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_BB_IDX on DB.DBA.VVEC_BF_BB (TXT) using ''vvec-bf-8'' with (dimensions = 8, build = ''sideways'')') like '%VEC81%' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an unknown build method is refused with VEC81=" $LAST[1] "\n";

--  build_method is SPARQL's other spelling of build, and the docs list it for
--  both surfaces: it must be checked and honoured on SQL too, not stored and
--  ignored.
select case when DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_BB_IDX on DB.DBA.VVEC_BF_BB (TXT) using ''vvec-bf-8'' with (dimensions = 8, build_method = ''sideways'')') like '%VEC81%' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an unknown build_method is refused with VEC81=" $LAST[1] "\n";

drop index VVEC_BF_BULK_IDX;
select DB.DBA.VVEC_BF_EXEC_STOCK_BATCH ('create vector index VVEC_BF_BULK_IDX on DB.DBA.VVEC_BF_BULK (TXT) using ''vvec-bf-8'' with (dimensions = 8, distance_metric = ''cosine'', hnsw_m = 8, ef_construction = 64, build_method = ''bulk'')');
ECHO BOTH $IF $EQU $LAST[1] "00000" "PASSED" "***FAILED";
ECHO BOTH ": create with build_method = 'bulk'=" $LAST[1] "\n";

select DB.DBA.VVEC_BF_FORMAT ('VVEC_BF_BULK_IDX');
ECHO BOTH $IF $EQU $LAST[1] "packed" "PASSED" "***FAILED";
ECHO BOTH ": build_method = 'bulk' builds the packed graph too=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
DB.DBA.VVEC_BF_GATE ((select V from DB.DBA.VVEC_BF_GATE_WAS));
drop index VVEC_BF_IDX;
drop index VVEC_BF_VIDX;
drop table DB.DBA.VVEC_BF_T;
drop table DB.DBA.VVEC_BF_V;
drop table DB.DBA.VVEC_BF_BAD;
drop table DB.DBA.VVEC_BF_BEFORE;
drop table DB.DBA.VVEC_BF_GATE_WAS;
drop index VVEC_BF_DML_IDX;
drop table DB.DBA.VVEC_BF_DML;
drop table DB.DBA.VVEC_BF_PLAIN;
drop table DB.DBA.VVEC_BF_TIMES;
drop procedure DB.DBA.VVEC_BF_INSERT_PLAIN;
drop procedure DB.DBA.VVEC_BF_INSERT_INDEXED;
drop index VVEC_BF_BULK_IDX;
drop table DB.DBA.VVEC_BF_BULK;
drop table DB.DBA.VVEC_BF_BB;
drop function DB.DBA.VVEC_BF_FORMAT;
drop procedure DB.DBA.VVEC_BF_BULK_FILL;
delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX in ('VVEC_BF_IDX', 'VVEC_BF_VIDX', 'VVEC_BF_BADIDX', 'VVEC_BF_DML_IDX', 'VVEC_BF_BULK_IDX');
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-bf-8';
drop procedure DB.DBA.VVEC_BF_FILL;
drop procedure DB.DBA.VVEC_BF_GATE;
drop function DB.DBA.VVEC_BF_EXEC_STOCK_BATCH;
drop function DB.DBA.VVEC_BF_VEC8;
drop function DB.DBA.VVEC_BF_METRIC;
drop function DB.DBA.VVEC_BF_KV;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": SQL backfill test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: SQL CREATE VECTOR INDEX backfills every existing row\n";
