--
--  tvvec_page_fit.sql
--
--  CREATE VECTOR INDEX must refuse an hnsw_m whose graph node does not fit
--  on a page, however the dimension is given.
--
--  A node page holds the neighbour slots of every layer -- (16 + 1) * hnsw_m
--  page numbers -- then the vector, or a reference to the overflow pages that
--  hold it.  An hnsw_m that leaves no room for either is refused with VEC17.
--  The check was made before a dimension taken from the model's declared
--  output shape was known, so with WITH (dimensions = ...) left out it
--  compared against 0 and passed; and its arithmetic is int, so an hnsw_m
--  large enough to wrap it (2^30) passed with any dimension.  Either way the
--  CREATE succeeded, and the first row inserted would have been written past
--  the end of its page.
--
--  Sections 1-3 are tests of the change (each fails before it); 4 and 5 are
--  guards and hold on both sides:
--    1. No dimensions, hnsw_m = 119 (the first that cannot fit): VEC17, and
--       no index is left.  Before: the index was created.
--    2. dimensions = 8, hnsw_m = 2^30: VEC17, no index.  Before: created.
--    3. No dimensions, hnsw_m = 2^30: VEC17, no index.  Before: created.
--    4. dimensions = 8, hnsw_m = 119: VEC17, as before.
--    5. No dimensions, hnsw_m = 118 (the last that fits) on a 16-dim model,
--       which must keep its vectors on overflow pages: created, existing and
--       inserted rows indexed, and found.
--
--  No row is ever written to a table that carries one of the refused indexes:
--  before the change those indexes exist, and an insert would corrupt memory.
--  Each is dropped straight after its assertion.
--
--  Self-contained: the in-core deterministic test_embedding model, so it
--  needs neither ONNX nor the VVEC_BEGIN_* fixtures.
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

echo BOTH "STARTED: vector index node page fit (VEC17)\n";

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
delete from DB.DBA.ONNX_MODELS where model_name in ('vvec-pf-8', 'vvec-pf-16');
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values ('vvec-pf-8', 'deterministic 8-dim test model', 'internal:vvec-pf-8',
        'test_embedding', 'embedding', '1,8', now (), now ());
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values ('vvec-pf-16', 'deterministic 16-dim test model', 'internal:vvec-pf-16',
        'test_embedding', 'embedding', '1,16', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register the test models STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.VEC_SQL_QUEUE_INIT ();

--  Never written to: see the header.
create table DB.DBA.VVEC_PF_EMPTY (id integer not null primary key, content varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_PF_EMPTY STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Run a CREATE VECTOR INDEX: 'created', 'VEC17', or the SQLSTATE and the
--  message of any other error.
create function DB.DBA.VVEC_PF_TRY (in stmt varchar) returns varchar
{
  declare st, msg varchar;
  st := '00000';
  msg := '';
  exec (stmt, st, msg);
  if (st = '00000')
    return 'created';
  if (strstr (msg, 'VEC17') is not null)
    return 'VEC17';
  return st || ' ' || msg;
};

create function DB.DBA.VVEC_PF_KEYS (in idx varchar) returns integer
{
  return (select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = idx);
};

create function DB.DBA.VVEC_PF_KV (in kv any, in k varchar) returns integer
{
  declare i integer;
  if (not isvector (kv))
    return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k)
      return cast (aref (kv, i + 1) as integer);
  return null;
};

-- ===========================================================================
-- 1. No dimensions, hnsw_m = 119
-- ===========================================================================
select DB.DBA.VVEC_PF_TRY ('CREATE VECTOR INDEX VVEC_PF_M119 ON DB.DBA.VVEC_PF_EMPTY (content) USING ''vvec-pf-8'' WITH (hnsw_m = 119)');
ECHO BOTH $IF $EQU $LAST[1] "VEC17" "PASSED" "***FAILED";
ECHO BOTH ": no dimensions, hnsw_m = 119 refused: " $LAST[1] "\n";

select DB.DBA.VVEC_PF_KEYS ('VVEC_PF_M119');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no dimensions, hnsw_m = 119 leaves no index, keys=" $LAST[1] "\n";
DB.DBA.VVEC_PF_TRY ('drop index VVEC_PF_M119');

-- ===========================================================================
-- 2. dimensions = 8, hnsw_m = 2^30
-- ===========================================================================
select DB.DBA.VVEC_PF_TRY ('CREATE VECTOR INDEX VVEC_PF_WRAP_DIM ON DB.DBA.VVEC_PF_EMPTY (content) USING ''vvec-pf-8'' WITH (dimensions = 8, hnsw_m = 1073741824)');
ECHO BOTH $IF $EQU $LAST[1] "VEC17" "PASSED" "***FAILED";
ECHO BOTH ": dimensions = 8, hnsw_m = 2^30 refused: " $LAST[1] "\n";

select DB.DBA.VVEC_PF_KEYS ('VVEC_PF_WRAP_DIM');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": dimensions = 8, hnsw_m = 2^30 leaves no index, keys=" $LAST[1] "\n";
DB.DBA.VVEC_PF_TRY ('drop index VVEC_PF_WRAP_DIM');

-- ===========================================================================
-- 3. No dimensions, hnsw_m = 2^30
-- ===========================================================================
select DB.DBA.VVEC_PF_TRY ('CREATE VECTOR INDEX VVEC_PF_WRAP ON DB.DBA.VVEC_PF_EMPTY (content) USING ''vvec-pf-8'' WITH (hnsw_m = 1073741824)');
ECHO BOTH $IF $EQU $LAST[1] "VEC17" "PASSED" "***FAILED";
ECHO BOTH ": no dimensions, hnsw_m = 2^30 refused: " $LAST[1] "\n";

select DB.DBA.VVEC_PF_KEYS ('VVEC_PF_WRAP');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no dimensions, hnsw_m = 2^30 leaves no index, keys=" $LAST[1] "\n";
DB.DBA.VVEC_PF_TRY ('drop index VVEC_PF_WRAP');

-- ===========================================================================
-- 4. Guard: dimensions = 8, hnsw_m = 119 was refused already
-- ===========================================================================
select DB.DBA.VVEC_PF_TRY ('CREATE VECTOR INDEX VVEC_PF_M119_DIM ON DB.DBA.VVEC_PF_EMPTY (content) USING ''vvec-pf-8'' WITH (dimensions = 8, hnsw_m = 119)');
ECHO BOTH $IF $EQU $LAST[1] "VEC17" "PASSED" "***FAILED";
ECHO BOTH ": dimensions = 8, hnsw_m = 119 refused: " $LAST[1] "\n";
DB.DBA.VVEC_PF_TRY ('drop index VVEC_PF_M119_DIM');

-- ===========================================================================
-- 5. Guard: hnsw_m = 118 still fits, with the vector on overflow pages
-- ===========================================================================
create table DB.DBA.VVEC_PF_OK (id integer not null primary key, content varchar);
insert into DB.DBA.VVEC_PF_OK values (1, 'alpha beta');
insert into DB.DBA.VVEC_PF_OK values (2, 'gamma delta');
insert into DB.DBA.VVEC_PF_OK values (3, 'epsilon zeta');

select DB.DBA.VVEC_PF_TRY ('CREATE VECTOR INDEX VVEC_PF_OK_IDX ON DB.DBA.VVEC_PF_OK (content) USING ''vvec-pf-16'' WITH (hnsw_m = 118)');
ECHO BOTH $IF $EQU $LAST[1] "created" "PASSED" "***FAILED";
ECHO BOTH ": no dimensions, hnsw_m = 118, 16 dimensions: " $LAST[1] "\n";

insert into DB.DBA.VVEC_PF_OK values (4, 'eta theta');
select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);

select DB.DBA.VVEC_PF_KV (__VEC_INDEX_METRICS ('VVEC_PF_OK_IDX'), 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": hnsw_m = 118 graph nodes=" $LAST[1] "\n";

--  8 floats fit inline at hnsw_m = 118, so 16 go to an overflow page.
select case when DB.DBA.VVEC_PF_KV (__VEC_INDEX_PAGE_STATS ('VVEC_PF_OK_IDX'), 'inline_dim_limit') < 16
             and DB.DBA.VVEC_PF_KV (__VEC_INDEX_PAGE_STATS ('VVEC_PF_OK_IDX'), 'overflow_pages') >= 4
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": hnsw_m = 118 keeps 16-dim vectors on overflow pages flag=" $LAST[1] "\n";

select id from DB.DBA.VVEC_PF_OK where X_SIMILAR (content, 'eta theta') > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": hnsw_m = 118 finds the inserted row=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
drop index VVEC_PF_OK_IDX;
drop table DB.DBA.VVEC_PF_OK;
drop table DB.DBA.VVEC_PF_EMPTY;
delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX in ('VVEC_PF_M119', 'VVEC_PF_WRAP_DIM', 'VVEC_PF_WRAP', 'VVEC_PF_M119_DIM', 'VVEC_PF_OK_IDX');
delete from DB.DBA.ONNX_MODELS where model_name in ('vvec-pf-8', 'vvec-pf-16');
drop function DB.DBA.VVEC_PF_KV;
drop function DB.DBA.VVEC_PF_KEYS;
drop function DB.DBA.VVEC_PF_TRY;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": page fit test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: vector index node page fit (VEC17)\n";
