--
--  tvvec_rdf_knn_optional.sql
--
--  bif:knnSimilar inside OPTIONAL: the optional part binds only what it
--  matched, and its score can be read.
--
--  Two faults, both in how the engine treats the vector search node next to
--  the free-text node it is modelled on:
--
--    * `score ?x` inside OPTIONAL did not compile: SQ200, "No column
--      t7.SIMILARITY".  The OPTIONAL becomes a left outer join, the right
--      side's search predicate an ON condition, and SIMILARITY and DISTANCE
--      are created from a WHERE clause only, never from an ON condition.
--    * a row the optional part did not match kept the values the search node
--      last wrote.  The outer join resets to NULL every value its right side
--      assigns, and learns which those are from qn_refd_slots, which had no
--      entry for the vector search node: a subject without a match carried
--      the last literal the search returned (when the search leads the right
--      side) or the last score.
--
--  Data: ten subjects with a text literal each, six of them with a note, and
--  40 literals of other subjects.  The in-core test embedding of a note is
--  two hot positions, 600 and one of 641-646, and of each of the 40 other
--  literals 600 and one of 701-740; no other literal of the suite's database
--  has position 600.  Searching note 1's text finds note 1 (score 1) and
--  then literals of the 46 that share 600 (0.75): the shared position is
--  what lets the graph search reach them among the database's other
--  literals, which all score 0.5.  The searches that must find notes use a
--  k larger than the index; with these sparse vectors a smaller one stops
--  among the 40.

--  Joins are run as loop joins (define sql:select-option "loop"), the plan
--  in which an OPTIONAL's right side is an outer section of the query; the
--  hash join form has its own tests (tvvec_rdf_knn_hash.sql and the outer
--  hash filler test of tsqlo).
--
--  1-3 are tests of the change (each fails before it); 4-6 are guards and
--  hold on both sides:
--    1. score ?x inside OPTIONAL compiles and returns every subject.
--       Before: SQ200.
--    2. ... and, as a loop join, binds ?n and ?x on the matched subjects
--       only: rows, bound ?n, bound ?x are 10, R, R, where R is the number of
--       rows of the same search without OPTIONAL.  Before: SQ200; with the
--       first fault fixed alone, every subject had a score.
--    3. With limit 1 the search leads the optional part: the subjects it
--       does not match have no ?n.  Before: every subject had the literal.
--    4. The plan of 3 has the search leading the outer section.
--    5. The required pattern finds notes with k larger than the index
--       (R >= 1): the data is right.
--    6. OPTIONAL without a score, k larger than the index: rows 10, bound R.
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

echo BOTH "STARTED: knnSimilar inside OPTIONAL\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

delete from DB.DBA.ONNX_MODELS where model_name = 'tkq-1024';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tkq-1024', 'knnSimilar OPTIONAL test model', 'internal:tkq-1024', 'test_embedding', 'embedding', '1,1024', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tkq-1024 STATE=" $STATE "\n";

create procedure DB.DBA.TKQ_FILL ()
{
  declare i integer;
  for (i := 1; i <= 10; i := i + 1)
    {
      ttlp (sprintf ('<urn:tkq:s%d> <urn:tkq:text> "tkq subject text %d, stored in RDF_OBJ" .', i, 800 + i), '', 'urn:tkq:g');
      if (i <= 6)
        ttlp (sprintf ('<urn:tkq:s%d> <urn:tkq:note> "tkq note 600 %d, stored in RDF_OBJ" .', i, 640 + i), '', 'urn:tkq:g');
    }
  -- literals of other subjects near the notes, giving the graph search a way in
  for (i := 1; i <= 40; i := i + 1)
    ttlp (sprintf ('<urn:tkq:f%d> <urn:tkq:other> "tkq neighbour 600 %d, stored in RDF_OBJ" .', i, 700 + i), '', 'urn:tkq:g');
}
;
DB.DBA.TKQ_FILL ();
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tkq:g');
ECHO BOTH $IF $EQU $LAST[1] 56 "PASSED" "***FAILED";
ECHO BOTH ": 56 quads in urn:tkq:g: " $LAST[1] "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tkq:idx', 'tkq-1024', null, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create and build urn:tkq:idx STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Each column's count of non-NULL values, '/'-joined; or the SQLSTATE.
create procedure DB.DBA.TKQ_SIG (in q varchar) returns varchar
{
  declare st, msg, res varchar;
  declare md, rs any;
  declare r, c, n integer;
  st := '00000';
  rs := null;
  exec (q, st, msg, vector (), 0, md, rs);
  if (st <> '00000')
    return sprintf ('error %s', st);
  if (not isarray (rs))
    return '0';
  res := sprintf ('%d', length (rs));
  if (0 = length (rs))
    return res;
  for (c := 0; c < length (rs[0]); c := c + 1)
    {
      n := 0;
      for (r := 0; r < length (rs); r := r + 1)
        if (rs[r][c] is not null)
          n := n + 1;
      res := res || sprintf ('/%d', n);
    }
  return res;
}
;

-- 1 when the EXPLAIN of Q has PAT inside an outer section.
create procedure DB.DBA.TKQ_IN_OUTER (in q varchar, in pat varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  declare inx, in_outer integer;
  st := '00000';
  exec ('explain (?)', st, msg, vector (q), 0, md, rs);
  if (st <> '00000')
    return -1;
  in_outer := 0;
  for (inx := 0; inx < length (rs); inx := inx + 1)
    {
      if (strstr (cast (rs[inx][0] as varchar), 'outer {') is not null)
        in_outer := 1;
      if (strstr (cast (rs[inx][0] as varchar), 'end of outer') is not null)
        in_outer := 0;
      if (in_outer and strstr (cast (rs[inx][0] as varchar), pat) is not null)
        return 1;
    }
  return 0;
}
;

-- R: the rows of the search without OPTIONAL, as a 'rows/bound/bound' signature.
create procedure DB.DBA.TKQ_REQUIRED (in lim integer) returns varchar
{
  declare n integer;
  n := (select count (*) from DB.DBA.RDF_QUAD
         where G = iri_to_id ('urn:tkq:g') and P = iri_to_id ('urn:tkq:note')
           and knnSimilar (O, 'tkq note 600 641', 'urn:tkq:idx', lim));
  return sprintf ('10/%d/%d', n, n);
}
;

-- ---------------------------------------------------------------------------
-- 1, 2. score inside OPTIONAL
-- ---------------------------------------------------------------------------

select case when DB.DBA.TKQ_SIG ('sparql select ?s ?n ?x where { graph <urn:tkq:g> { ?s <urn:tkq:text> ?t } optional { ?s <urn:tkq:note> ?n . ?n bif:knnSimilar "tkq note 600 641" option (index <urn:tkq:idx>, limit 20, score ?x) } }') like '10/10/%' then 1 else 0 end,
       DB.DBA.TKQ_SIG ('sparql select ?s ?n ?x where { graph <urn:tkq:g> { ?s <urn:tkq:text> ?t } optional { ?s <urn:tkq:note> ?n . ?n bif:knnSimilar "tkq note 600 641" option (index <urn:tkq:idx>, limit 20, score ?x) } }');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": score ?x inside OPTIONAL compiles and returns every subject; rows/s/n/x bound: " $LAST[2] "\n";

select DB.DBA.TKQ_SIG ('sparql define sql:select-option "loop" select ?n ?x where { graph <urn:tkq:g> { ?s <urn:tkq:text> ?t } optional { ?s <urn:tkq:note> ?n . ?n bif:knnSimilar "tkq note 600 641" option (index <urn:tkq:idx>, limit 100000, score ?x) } }'), DB.DBA.TKQ_REQUIRED (100000);
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": loop join, rows/n/x bound " $LAST[1] " = " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 3, 4. limit 1: the search leads the optional part
-- ---------------------------------------------------------------------------

select DB.DBA.TKQ_SIG ('sparql define sql:select-option "loop" select ?n ?n where { graph <urn:tkq:g> { ?s <urn:tkq:text> ?t } optional { ?s <urn:tkq:note> ?n . ?n bif:knnSimilar "tkq note 600 641" option (index <urn:tkq:idx>, limit 1) } }'), DB.DBA.TKQ_REQUIRED (1);
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": limit 1, loop join, rows/n bound " $LAST[1] " = " $LAST[2] "\n";

select DB.DBA.TKQ_IN_OUTER ('sparql define sql:select-option "loop" select ?n where { graph <urn:tkq:g> { ?s <urn:tkq:text> ?t } optional { ?s <urn:tkq:note> ?n . ?n bif:knnSimilar "tkq note 600 641" option (index <urn:tkq:idx>, limit 1) } }', 'rdf_obj driving');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the plan of the limit 1 query has the search leading its outer section: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 5, 6. Guards
-- ---------------------------------------------------------------------------

select case when DB.DBA.TKQ_REQUIRED (100000) <> '10/0/0' then 1 else 0 end, DB.DBA.TKQ_REQUIRED (100000);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the required pattern finds notes with k larger than the index: " $LAST[2] "\n";

select DB.DBA.TKQ_SIG ('sparql select ?n ?n where { graph <urn:tkq:g> { ?s <urn:tkq:text> ?t } optional { ?s <urn:tkq:note> ?n . ?n bif:knnSimilar "tkq note 600 641" option (index <urn:tkq:idx>, limit 100000) } }'), DB.DBA.TKQ_REQUIRED (100000);
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": OPTIONAL without a score, k larger than the index, rows/n bound " $LAST[1] " = " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tkq:idx');
sparql clear graph <urn:tkq:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tkq-1024';
drop procedure DB.DBA.TKQ_FILL;
drop procedure DB.DBA.TKQ_SIG;
drop procedure DB.DBA.TKQ_IN_OUTER;
drop procedure DB.DBA.TKQ_REQUIRED;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: knnSimilar inside OPTIONAL\n";
