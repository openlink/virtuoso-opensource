--
--  tvvec_packed_insert.sql
--
--  Rows written into a vector index AFTER a fast rebuild.
--
--  The fast bulk builder writes the graph in the packed format: several nodes
--  per page, each a compact record with exactly as many neighbour slots as it
--  uses.  'auto' picks it for any index of 10,000 rows or more, so every large
--  index that has ever been rebuilt is packed -- and ordinary inserts then link
--  new nodes into it one at a time.  Linking a node adds it to its neighbours'
--  lists (the backlinks), and that step read and wrote every neighbour as if
--  it were a one-node legacy page: on a packed page it wrote into another
--  node's record at the wrong offset and followed garbage references until the
--  server died with "Reference to page with free remap".  The first insert did
--  it, on a graph of any size.
--
--  So: build packed, insert, replace, search -- and check the graph the
--  builder wrote is still intact afterwards.
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

echo BOTH "STARTED: inserts into a packed (fast-built) vector graph\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'tpi-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tpi-64', 'packed insert test model', 'internal:tpi-64', 'test_embedding', 'embedding', '1,64', now (), now ());

create table DB.DBA.TPI_T (ID integer not null primary key, TXT varchar);
CREATE VECTOR INDEX TPI_IDX ON DB.DBA.TPI_T (TXT) USING 'tpi-64' WITH (dimensions = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TPI_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Every vector the test writes, so a search for it can be checked.
create table DB.DBA.TPI_V (ID integer not null primary key, V long any);

create procedure DB.DBA.TPI_VEC () returns any
{
  declare v any;
  declare j integer;
  v := make_array (64, 'float');
  for (j := 0; j < 64; j := j + 1)
    aset (v, j, (rnd (20000) - 10000) / 10000.0);
  return v;
}
;

create procedure DB.DBA.TPI_STAGE (in n integer)
{
  declare ids, vecs, v any;
  declare i, b integer;
  b := 0;
  ids := make_array (500, 'any');
  vecs := make_array (500, 'any');
  for (i := 1; i <= n; i := i + 1)
    {
      v := DB.DBA.TPI_VEC ();
      insert replacing DB.DBA.TPI_V values (i, v);
      aset (ids, b, i);
      aset (vecs, b, v);
      b := b + 1;
      if (b = 500)
        {
          __VEC_INDEX_STAGE_BATCH ('TPI_IDX', ids, vecs);
          commit work;
          b := 0;
        }
    }
  if (b > 0)
    __VEC_INDEX_STAGE_BATCH ('TPI_IDX', subseq (ids, 0, b), subseq (vecs, 0, b));
  commit work;
}
;

create procedure DB.DBA.TPI_FAST_REBUILD () returns varchar
{
  declare prev_mode integer;
  declare err varchar;
  err := '';
  prev_mode := log_enable (null);
  log_enable (2, 1);
  {
    declare exit handler for sqlstate '*' { err := __SQL_STATE || ' ' || __SQL_MESSAGE; goto done; };
    __VEC_INDEX_REBUILD ('TPI_IDX', 'fast', 2);
    commit work;
  }
done:
  log_enable (prev_mode, 1);
  return err;
}
;

--  Insert or replace rows LO..HI one at a time, the way a trigger or an
--  incremental refresh does.
create procedure DB.DBA.TPI_INSERT (in lo integer, in hi integer) returns integer
{
  declare i integer;
  declare v any;
  for (i := lo; i <= hi; i := i + 1)
    {
      v := DB.DBA.TPI_VEC ();
      insert replacing DB.DBA.TPI_V values (i, v);
      __VEC_INDEX_INSERT_EMBEDDING ('TPI_IDX', i, v);
      commit work;
    }
  return hi - lo + 1;
}
;

--  How many of rows LO..HI a search for their own vector finds in its top 5.
create procedure DB.DBA.TPI_SELF_FOUND (in lo integer, in hi integer) returns integer
{
  declare i, j, n_found, hit integer;
  declare res any;
  n_found := 0;
  for (i := lo; i <= hi; i := i + 1)
    {
      res := __VEC_INDEX_SEARCH ('TPI_IDX', (select V from DB.DBA.TPI_V where ID = i), 5, 128);
      hit := 0;
      for (j := 0; j < length (res); j := j + 1)
        if (cast (res[j][0] as integer) = i)
          hit := 1;
      n_found := n_found + hit;
    }
  return n_found;
}
;

create procedure DB.DBA.TPI_M (in k varchar) returns integer
{
  return cast (get_keyword (k, __VEC_INDEX_METRICS ('TPI_IDX'), -1) as integer);
}
;

DB.DBA.TPI_STAGE (1000);
select DB.DBA.TPI_FAST_REBUILD ();
ECHO BOTH ": fast rebuild of 1000 staged vectors, error=" $LAST[1] "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('TPI_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the graph is packed, format=" $LAST[1] "\n";

--  The fast builder's own reach, before anything is inserted.  It is not
--  perfect: measured, 3 to 5 of these 1000 random vectors are not found in
--  their own top 5, where a replay-built graph finds all of them.  What the
--  inserts must not do is make it worse, so this is the yardstick.
create table DB.DBA.TPI_M2 (K varchar primary key, N integer);
insert into DB.DBA.TPI_M2 values ('before', DB.DBA.TPI_SELF_FOUND (21, 1000));
commit work;
select N from DB.DBA.TPI_M2 where K = 'before';
ECHO BOTH ": the builder's nodes 21..1000 found by their own vectors before any insert: " $LAST[1] " of 980\n";

-- ===========================================================================
-- 1. New rows linked into the packed graph
-- ===========================================================================

select DB.DBA.TPI_INSERT (1001, 1050);
ECHO BOTH $IF $EQU $LAST[1] 50 "PASSED" "***FAILED";
ECHO BOTH ": inserted " $LAST[1] " rows into the packed graph one at a time\n";

select DB.DBA.TPI_M ('graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 1050 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes=" $LAST[1] " (expect 1050)\n";

select DB.DBA.TPI_SELF_FOUND (1001, 1050);
ECHO BOTH $IF $EQU $LAST[1] 50 "PASSED" "***FAILED";
ECHO BOTH ": every inserted row is found by its own vector, found=" $LAST[1] " of 50\n";

--  The builder's nodes: their records sit on the same pages the backlinks were
--  written into, so these are the ones a misplaced write would damage.  Each
--  backlink into a packed record takes the place of that record's farthest
--  neighbour -- a compact record has no free slot -- so an edge can go; allow
--  two nodes of slack against the yardstick, and no more.
select DB.DBA.TPI_SELF_FOUND (21, 1000),
       case when DB.DBA.TPI_SELF_FOUND (21, 1000) + 2 >= (select N from DB.DBA.TPI_M2 where K = 'before') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": the packed nodes are found as well as before the inserts, found=" $LAST[1] " of 980\n";

-- ===========================================================================
-- 2. Rows replaced: the packed node is retired, a new one linked
-- ===========================================================================

select DB.DBA.TPI_INSERT (1, 20);
select DB.DBA.TPI_M ('deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": replacing 20 packed rows retires their nodes, deleted_nodes=" $LAST[1] "\n";

select DB.DBA.TPI_M ('graph_nodes') - DB.DBA.TPI_M ('deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 1050 "PASSED" "***FAILED";
ECHO BOTH ": live nodes=" $LAST[1] " (expect 1050)\n";

select DB.DBA.TPI_SELF_FOUND (1, 20);
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": the replaced rows answer with their new vectors, found=" $LAST[1] " of 20\n";

select get_keyword ('consistent', __VEC_INDEX_VALIDATE ('TPI_IDX'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": validate reports the graph consistent=" $LAST[1] "\n";

-- ===========================================================================
-- 3. Rebuild again, and insert again: the second packed graph takes rows too
-- ===========================================================================

select DB.DBA.TPI_FAST_REBUILD ();
select DB.DBA.TPI_INSERT (1051, 1060);
select DB.DBA.TPI_SELF_FOUND (1051, 1060);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": after a second fast rebuild the next inserts are found too, found=" $LAST[1] " of 10\n";

select get_keyword ('consistent', __VEC_INDEX_VALIDATE ('TPI_IDX'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": and the graph validates, consistent=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
--  Equal distances.  Each row below is a pair of unit coordinates, so many
--  distances tie, and a packed neighbour list replaces its farthest link only
--  for a strictly nearer node: every backlink of a new row can be refused,
--  leaving it with no way in.  An ordinary search must still find it.
delete from DB.DBA.ONNX_MODELS where model_name = 'tpi-32';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tpi-32', 'packed insert tie test model', 'internal:tpi-32', 'test_embedding', 'embedding', '1,32', now (), now ());

create table DB.DBA.TPI_P (ID integer not null primary key, TXT varchar);
CREATE VECTOR INDEX TPI_P_IDX ON DB.DBA.TPI_P (TXT) USING 'tpi-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TPI_P_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Row ID gets the ID-th pair (a, b), a < b.
create procedure DB.DBA.TPI_PAIR (in id integer, out a integer, out b integer)
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
  signal ('22023', 'TPI_PAIR: no pair for ' || cast (id as varchar));
}
;

create procedure DB.DBA.TPI_P_ADD (in lo integer, in hi integer)
{
  declare id, a, b integer;
  for (id := lo; id <= hi; id := id + 1)
    {
      DB.DBA.TPI_PAIR (id, a, b);
      __VEC_INDEX_INSERT_TEST_EMBEDDING ('TPI_P_IDX', id, a, b);
      commit work;
    }
}
;

--  How many of rows LO..HI are the nearest neighbour of their own vector.
create procedure DB.DBA.TPI_P_TOP (in lo integer, in hi integer) returns integer
{
  declare id, a, b, n integer;
  declare res any;
  n := 0;
  for (id := lo; id <= hi; id := id + 1)
    {
      DB.DBA.TPI_PAIR (id, a, b);
      res := __VEC_INDEX_SEARCH_TEST_EMBEDDING ('TPI_P_IDX', a, b, 1, 64);
      if (length (res) > 0 and cast (res[0][0] as integer) = id)
        n := n + 1;
    }
  return n;
}
;

DB.DBA.TPI_P_ADD (1, 100);
select __VEC_INDEX_REBUILD ('TPI_P_IDX', 'fast');
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild of 100 pair vectors=" $LAST[1] "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('TPI_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the graph is packed, format=" $LAST[1] "\n";

DB.DBA.TPI_P_ADD (101, 110);
select DB.DBA.TPI_P_TOP (101, 110);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": rows inserted into the packed graph are found by their own vectors, found=" $LAST[1] " of 10\n";

--  Not asserted: how many fast-built rows a narrow search finds on tied
--  distances is the builder's quality, not an insert's.
select DB.DBA.TPI_P_TOP (1, 100);
ECHO BOTH ": diagnostic -- packed rows found by their own vectors=" $LAST[1] " of 100\n";

drop table DB.DBA.TPI_P;
delete from DB.DBA.ONNX_MODELS where model_name = 'tpi-32';

drop table DB.DBA.TPI_T;
drop table DB.DBA.TPI_V;
drop table DB.DBA.TPI_M2;
delete from DB.DBA.ONNX_MODELS where model_name = 'tpi-64';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: inserts into a packed (fast-built) vector graph\n";
