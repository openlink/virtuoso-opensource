--
--  tvvec_rollback_undo.sql
--
--  Graph pages are not transactional: a rolled-back transaction's inserts
--  and soft deletes stay in the graph while its embedding rows and catalog
--  epoch go.  The next committed write must undo them first, so the graph
--  matches the stored embeddings again: no orphan nodes, and a row whose
--  delete was rolled back is searchable again.
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

echo BOTH "STARTED: vector index rollback undo\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'vru-32';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vru-32', 'rollback undo test model', 'internal:vru-32', 'test_embedding', 'embedding', '1,32', now (), now ());

drop index VRU_IDX;
drop table DB.DBA.VRU_T;
drop table DB.DBA.VRU_C;
create table DB.DBA.VRU_C (K varchar primary key, N integer);
create table DB.DBA.VRU_T (id integer not null primary key, content varchar);

CREATE VECTOR INDEX VRU_IDX ON DB.DBA.VRU_T (content) USING 'vru-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VRU_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Row ID gets the ID-th pair (a, b), a < b, so every row has its own vector.
create procedure DB.DBA.VRU_PAIR (in id integer, out a integer, out b integer)
{
  declare n integer;
  n := 0;
  for (a := 0; a < 32; a := a + 1)
    for (b := a + 1; b < 32; b := b + 1)
      {
        n := n + 1;
        if (n = id)
          return;
      }
  signal ('22023', 'VRU_PAIR: no pair for ' || cast (id as varchar));
}
;

create procedure DB.DBA.VRU_ADD (in first_id integer, in last_id integer)
{
  declare id, a, b integer;
  for (id := first_id; id <= last_id; id := id + 1)
    {
      DB.DBA.VRU_PAIR (id, a, b);
      __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRU_IDX', id, a, b);
    }
}
;

--  Is row ID in the graph at all: a broad search, since on tied pair vectors
--  a narrow one misses some rows of any graph (tvvec_packed_insert).
create procedure DB.DBA.VRU_FOUND (in id integer) returns integer
{
  declare a, b, i integer;
  declare res any;
  DB.DBA.VRU_PAIR (id, a, b);
  res := __VEC_INDEX_SEARCH_TEST_EMBEDDING ('VRU_IDX', a, b, 10, 128);
  for (i := 0; i < length (res); i := i + 1)
    if (cast (aref (aref (res, i), 0) as integer) = id)
      return 1;
  return 0;
}
;

--  How many of the committed rows (1..100 and 121) the broad search finds.
create procedure DB.DBA.VRU_FOUND_ALL () returns integer
{
  declare id, n integer;
  n := DB.DBA.VRU_FOUND (121);
  for (id := 1; id <= 100; id := id + 1)
    n := n + DB.DBA.VRU_FOUND (id);
  return n;
}
;

create procedure DB.DBA.VRU_KV (in k varchar) returns any
{
  return get_keyword (k, __VEC_INDEX_VALIDATE ('VRU_IDX'));
}
;

--  Inserts 20 rows and deletes row 5, then rolls all of it back.
create procedure DB.DBA.VRU_ROLLED_BACK ()
{
  DB.DBA.VRU_ADD (101, 120);
  __VEC_INDEX_DELETE_ROW ('VRU_IDX', 5);
  rollback work;
}
;

DB.DBA.VRU_ADD (1, 100);
commit work;
select __VEC_INDEX_REBUILD ('VRU_IDX', 'fast');
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild of 100 rows=" $LAST[1] "\n";
checkpoint;

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VRU_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": the fixture is packed, format=" $LAST[1] "\n";

DB.DBA.VRU_ROLLED_BACK ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": insert 20, delete 1, roll back STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.VRU_ADD (121, 121);
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": a committed insert after the rollback STATE=" $STATE "\n";

select DB.DBA.VRU_KV ('embedding_rows');
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
ECHO BOTH ": stored embeddings=" $LAST[1] " expected 101\n";

select DB.DBA.VRU_KV ('active_nodes');
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
ECHO BOTH ": graph nodes=" $LAST[1] " expected 101, no orphans from the rolled-back inserts\n";

select DB.DBA.VRU_KV ('consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent=" $LAST[1] "\n";

select __VEC_INDEX_HEALTH_RECHECK ('VRU_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": health=" $LAST[1] "\n";

select DB.DBA.VRU_FOUND (5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the row whose delete was rolled back is found=" $LAST[1] "\n";

select DB.DBA.VRU_FOUND (121);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the committed row is found=" $LAST[1] "\n";

--  Kept for after roll forward, which has to reproduce this graph exactly.
insert replacing DB.DBA.VRU_C values ('live', DB.DBA.VRU_FOUND_ALL ());
commit work;
select N from DB.DBA.VRU_C where K = 'live';
ECHO BOTH ": committed rows found live=" $LAST[1] " of 101\n";

echo BOTH "COMPLETED: vector index rollback undo\n";
