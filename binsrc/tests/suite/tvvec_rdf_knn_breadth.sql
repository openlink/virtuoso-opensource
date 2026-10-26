--
--  tvvec_rdf_knn_breadth.sql
--
--  knnSimilar with a small k must search as widely as with a large one: its
--  answer is the best of that search, not the first local optimum.
--
--  The graph search keeps a candidate list of ef entries, and knnSimilar
--  searched with ef = k: with k = 1 the search was greedy and stopped at the
--  first node none of whose neighbours was closer, with k = 20 it could still
--  miss a literal that k = 100 ranked first.  bif:vector_search searches with
--  ef 100 unless told otherwise; knnSimilar now searches with at least that.
--  A larger k costs no more than before -- k = 100, knnSimilar's default,
--  already searched with 100.
--
--  Data: 20 groups of 20 literals.  To the in-core test embedding a literal
--  of group g is two hot positions: 500 + g, shared by the group, and one of
--  600 + 20 g .. 600 + 20 g + 19.  The query for group g is the vector of its
--  first literal: that literal scores 1, the rest of the group 0.75, every
--  other literal 0.5.  Vectors this sparse leave the graph little to follow
--  outside a group, which is what makes the width of the search show: in a
--  database like the suite's, before the change, k = 100 reached the query's
--  group for 10 groups of 20 and k = 1 for 5, and the two best scores agreed
--  for 15.
--
--  1 is the test of the change (it fails before it); 2 and 3 are guards and
--  hold on both sides:
--    1. For every group, the best literal knnSimilar finds with k = 1 scores
--       as high as the best it finds with k = 100.  Before: only where the
--       greedy search happened to reach it.
--    2. With k = 100 the search reaches the query's group for at least 5
--       groups, so 1 compares something: were it to reach none, both best
--       scores would be 0.5 everywhere and 1 would pass on any build.
--    3. knnSimilar without k (k = 100) returns the same best score as k = 100.
--
--  Run by tvvec_rdf_quad.sh after tvvec_rdf_quad.sql.  Self-contained: its own
--  graph, model and index, all removed at the end.
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

echo BOTH "STARTED: knnSimilar search breadth\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

delete from DB.DBA.ONNX_MODELS where model_name = 'tkb-1024';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tkb-1024', 'knnSimilar breadth test model', 'internal:tkb-1024', 'test_embedding', 'embedding', '1,1024', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tkb-1024 STATE=" $STATE "\n";

create procedure DB.DBA.TKB_FILL ()
{
  declare g, j integer;
  for (g := 1; g <= 20; g := g + 1)
    for (j := 0; j < 20; j := j + 1)
      ttlp (sprintf ('<urn:tkb:g%d_%d> <urn:tkb:text> "tkb literal %d %d of group %d, stored in RDF_OBJ" .',
                     g, j, 500 + g, 600 + 20 * g + j, g), '', 'urn:tkb:g');
}
;
DB.DBA.TKB_FILL ();
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tkb:g');
ECHO BOTH $IF $EQU $LAST[1] 400 "PASSED" "***FAILED";
ECHO BOTH ": 400 quads in urn:tkb:g: " $LAST[1] "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tkb:idx', 'tkb-1024', null, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create and build urn:tkb:idx STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- The best score knnSimilar finds for group G's query with k K (0: no k given),
-- times 1000; -1 when it finds nothing.
create procedure DB.DBA.TKB_BEST (in g integer, in k integer) returns integer
{
  declare st, msg, q, txt varchar;
  declare md, rs any;
  txt := sprintf ('tkb literal %d %d', 500 + g, 600 + 20 * g);
  if (k > 0)
    q := sprintf ('select max (SIMILARITY) from DB.DBA.RDF_QUAD where knnSimilar (O, ''%s'', ''urn:tkb:idx'', %d)', txt, k);
  else
    q := sprintf ('select max (SIMILARITY) from DB.DBA.RDF_QUAD where knnSimilar (O, ''%s'', ''urn:tkb:idx'')', txt);
  st := '00000';
  rs := null;
  exec (q, st, msg, vector (), 0, md, rs);
  if (st <> '00000' or not isarray (rs) or 0 = length (rs) or rs[0][0] is null)
    return -1;
  return cast (1000 * rs[0][0] + 0.5 as integer);
}
;

-- The number of groups for which TKB_BEST (g, k1) = TKB_BEST (g, k2).
create procedure DB.DBA.TKB_SAME (in k1 integer, in k2 integer) returns integer
{
  declare g, n integer;
  n := 0;
  for (g := 1; g <= 20; g := g + 1)
    if (DB.DBA.TKB_BEST (g, k1) = DB.DBA.TKB_BEST (g, k2) and DB.DBA.TKB_BEST (g, k1) > 0)
      n := n + 1;
  return n;
}
;

-- The number of groups a K search reaches: its best score is the group's, 0.75 or 1.
create procedure DB.DBA.TKB_REACHED (in k integer) returns integer
{
  declare g, n integer;
  n := 0;
  for (g := 1; g <= 20; g := g + 1)
    if (DB.DBA.TKB_BEST (g, k) >= 750)
      n := n + 1;
  return n;
}
;

-- ---------------------------------------------------------------------------
-- 1. k = 1 finds what k = 100 finds best
-- ---------------------------------------------------------------------------

select DB.DBA.TKB_SAME (1, 100);
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": groups whose best score with k = 1 is the best with k = 100: " $LAST[1] " of 20\n";

-- ---------------------------------------------------------------------------
-- 2, 3. Guards
-- ---------------------------------------------------------------------------

select case when DB.DBA.TKB_REACHED (100) >= 5 then 1 else 0 end, DB.DBA.TKB_REACHED (100);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": k = 100 reaches the query's group for some groups: " $LAST[2] " of 20\n";

select DB.DBA.TKB_SAME (0, 100);
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": groups whose best score without k is the best with k = 100: " $LAST[1] " of 20\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tkb:idx');
sparql clear graph <urn:tkb:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tkb-1024';
drop procedure DB.DBA.TKB_FILL;
drop procedure DB.DBA.TKB_BEST;
drop procedure DB.DBA.TKB_SAME;
drop procedure DB.DBA.TKB_REACHED;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: knnSimilar search breadth\n";
