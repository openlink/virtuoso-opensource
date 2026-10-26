--
--  tvvec_rdf_knn_hash.sql
--
--  knnSimilar's SIMILARITY and DISTANCE must be each row's own score when the
--  table that carries the search is joined to another.
--
--  The vector search writes SIMILARITY and DISTANCE as virtual columns of its
--  RDF_QUAD table.  When the optimizer made that table the build side of a
--  hash join, the search ran inside the hash filler and the hash table kept
--  only real columns; every probe then read whatever score the filler wrote
--  last, so every joined row carried the same SIMILARITY and DISTANCE.  The
--  rows themselves were right.  A free-text contains () SCORE in the same
--  position is affected too; that is a separate, engine-wide matter.
--
--  Data: 41 questions, each with an accepted answer whose text the in-core
--  test model embeds as two hot positions (the text's first two numbers;
--  each is 20 characters or more, so it has an RDF_OBJ row to index).
--  Searching 'answer 5 6' scores one answer 1 (both positions), two 0.75
--  (one shared) and the rest 0.5 (none).  k is larger than the index, so the
--  search returns every literal it can reach; with this model's many exact
--  ties the graph can leave one unreachable, so the joins are compared with
--  the same search run without a join, not with fixed totals.
--
--  1-3 are tests of the change (each fails before it); 4-6 are guards and
--  hold on both sides:
--    1. The join, the hash join forced with TABLE OPTION (HASH): rows,
--       distinct SIMILARITY values and their sum are the search's own.
--       Before: one SIMILARITY for every row.
--    2. The same for DISTANCE.
--    3. The answer with both positions has SIMILARITY 1 in the join.
--    4. The search alone finds the three score levels and the exact answer.
--    5. A forced hash join that reads neither score still runs as a hash
--       join -- only a join that reads a score loses the hash plan --
--       and returns the search's rows.
--    6. The join as a loop join (the workaround) agrees with the search.
--
--  Run by tvvec_rdf_quad.sh after tvvec_rdf_quad.sql, which leaves no
--  RDF_OBJ vector index behind.  Self-contained: its own graph, model and
--  index, all removed at the end.
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

echo BOTH "STARTED: knnSimilar scores through a hash join\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

delete from DB.DBA.ONNX_MODELS where model_name = 'tkh-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tkh-64', 'knnSimilar hash join test model', 'internal:tkh-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tkh-64 STATE=" $STATE "\n";

create procedure DB.DBA.TKH_FILL ()
{
  declare i integer;
  for (i := 1; i <= 40; i := i + 1)
    ttlp (sprintf ('<urn:tkh:q%d> <urn:tkh:answer> <urn:tkh:a%d> . <urn:tkh:a%d> <urn:tkh:text> "tkh answer %d %d, stored in RDF_OBJ" .',
                   i, i, i, i, i + 20), '', 'urn:tkh:g');
  ttlp ('<urn:tkh:q41> <urn:tkh:answer> <urn:tkh:a41> . <urn:tkh:a41> <urn:tkh:text> "tkh answer 5 6, stored in RDF_OBJ" .', '', 'urn:tkh:g');
}
;
DB.DBA.TKH_FILL ();
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tkh:g');
ECHO BOTH $IF $EQU $LAST[1] 82 "PASSED" "***FAILED";
ECHO BOTH ": 82 quads in urn:tkh:g: " $LAST[1] "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tkh:idx', 'tkh-64', null, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create and build urn:tkh:idx STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- 'rows/distinct/sum' of a query returning (count, count distinct, sum); an
-- error is reported with the query's SQLSTATE, so it never equals a result.
create procedure DB.DBA.TKH_SIG (in q varchar) returns varchar
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  rs := null;
  exec (q, st, msg, vector (), 0, md, rs);
  if (st <> '00000')
    return sprintf ('error %s', st);
  if (not isarray (rs) or length (rs) <> 1)
    return 'no row';
  return sprintf ('%d/%d/%d', rs[0][0], rs[0][1], rs[0][2]);
}
;

-- 1 when the EXPLAIN of Q contains PAT.
create procedure DB.DBA.TKH_PLAN_HAS (in q varchar, in pat varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  declare inx integer;
  st := '00000';
  exec ('explain (?)', st, msg, vector (q), 0, md, rs);
  if (st <> '00000')
    return -1;
  for (inx := 0; inx < length (rs); inx := inx + 1)
    if (strstr (cast (rs[inx][0] as varchar), pat) is not null)
      return 1;
  return 0;
}
;

-- ---------------------------------------------------------------------------
-- 1-3. The join, hash join forced
-- ---------------------------------------------------------------------------

select DB.DBA.TKH_SIG ('select count (*), count (distinct t.SIMILARITY), cast (1000 * sum (t.SIMILARITY) + 0.5 as integer) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash) where q.G = iri_to_id (''urn:tkh:g'') and q.P = iri_to_id (''urn:tkh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000) option (order)'), DB.DBA.TKH_SIG ('select count (*), count (distinct t.SIMILARITY), cast (1000 * sum (t.SIMILARITY) + 0.5 as integer) from DB.DBA.RDF_QUAD t where t.G = iri_to_id (''urn:tkh:g'') and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": hash join SIMILARITY " $LAST[1] " = the search's " $LAST[2] "\n";

select DB.DBA.TKH_SIG ('select count (*), count (distinct t.DISTANCE), cast (1000 * sum (t.DISTANCE) + 0.5 as integer) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash) where q.G = iri_to_id (''urn:tkh:g'') and q.P = iri_to_id (''urn:tkh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000) option (order)'), DB.DBA.TKH_SIG ('select count (*), count (distinct t.DISTANCE), cast (1000 * sum (t.DISTANCE) + 0.5 as integer) from DB.DBA.RDF_QUAD t where t.G = iri_to_id (''urn:tkh:g'') and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": hash join DISTANCE " $LAST[1] " = the search's " $LAST[2] "\n";

select cast (1000 * t.SIMILARITY + 0.5 as integer)
  from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash)
 where q.G = iri_to_id ('urn:tkh:g') and q.P = iri_to_id ('urn:tkh:answer')
   and t.S = q.O and t.P = iri_to_id ('urn:tkh:text')
   and knnSimilar (t.O, 'answer 5 6', 'urn:tkh:idx', 100000)
   and q.S = iri_to_id ('urn:tkh:q41')
option (order);
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": hash join, 1000 * SIMILARITY of the exact answer: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 4. Guard: the search alone
-- ---------------------------------------------------------------------------

select count (distinct SIMILARITY), max (cast (1000 * SIMILARITY + 0.5 as integer)), count (*)
  from DB.DBA.RDF_QUAD
 where G = iri_to_id ('urn:tkh:g') and P = iri_to_id ('urn:tkh:text')
   and knnSimilar (O, 'answer 5 6', 'urn:tkh:idx', 100000);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": no join, distinct SIMILARITY values: " $LAST[1] " of " $LAST[3] " rows\n";
ECHO BOTH $IF $EQU $LAST[2] 1000 "PASSED" "***FAILED";
ECHO BOTH ": no join, 1000 * best SIMILARITY: " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 5. Guard: a hash join that reads no score keeps its hash plan
-- ---------------------------------------------------------------------------

select DB.DBA.TKH_PLAN_HAS ('select count (*) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash) where q.G = iri_to_id (''urn:tkh:g'') and q.P = iri_to_id (''urn:tkh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000) option (order)', 'hash filler');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a join reading no score is still a hash join: " $LAST[1] "\n";

select DB.DBA.TKH_SIG ('select count (*), 0, 0 from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash) where q.G = iri_to_id (''urn:tkh:g'') and q.P = iri_to_id (''urn:tkh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000) option (order)'), DB.DBA.TKH_SIG ('select count (*), 0, 0 from DB.DBA.RDF_QUAD t where t.G = iri_to_id (''urn:tkh:g'') and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": the hash join reading no score, rows " $LAST[1] " = the search's " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 6. Guard: the loop join
-- ---------------------------------------------------------------------------

select DB.DBA.TKH_SIG ('select count (*), count (distinct t.SIMILARITY), cast (1000 * sum (t.SIMILARITY) + 0.5 as integer) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t where q.G = iri_to_id (''urn:tkh:g'') and q.P = iri_to_id (''urn:tkh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000) option (order, loop)'), DB.DBA.TKH_SIG ('select count (*), count (distinct t.SIMILARITY), cast (1000 * sum (t.SIMILARITY) + 0.5 as integer) from DB.DBA.RDF_QUAD t where t.G = iri_to_id (''urn:tkh:g'') and t.P = iri_to_id (''urn:tkh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:tkh:idx'', 100000)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": loop join SIMILARITY " $LAST[1] " = the search's " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tkh:idx');
sparql clear graph <urn:tkh:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tkh-64';
drop procedure DB.DBA.TKH_FILL;
drop procedure DB.DBA.TKH_PLAN_HAS;
drop procedure DB.DBA.TKH_SIG;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: knnSimilar scores through a hash join\n";
