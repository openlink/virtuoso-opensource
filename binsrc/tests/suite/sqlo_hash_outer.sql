--
--  sqlo_hash_outer.sql
--
--  An outer-joined table read through a hash join: the hash filler that
--  builds the hash table must not itself be outer.
--
--  The right side of an OPTIONAL (a left outer join) can be planned as a hash
--  join, the outer semantics then belonging to the hash source.  The filler
--  is generated as for any table and then told it is not outer -- but only
--  its first node was, on the assumption that the first node is the table
--  source.  When a free-text (bif:contains) or vector (bif:knnSimilar) search
--  drives the table, it comes first and the table source is second, and that
--  one stayed outer: for a search hit that the table source then rejected it
--  sent an "outer" row of nothing down the filler, and the hash fill refused
--  it with ZIN00 "cannot run on 0 inputs".  The whole query failed.
--
--  Data: twelve subjects with a text literal each, six of them with a note,
--  and 200 notes of other subjects.  One more note is inserted and its triple
--  deleted again: its literal stays in RDF_OBJ and in the free-text index, as
--  literals do, so a search can hit a literal that no triple uses.
--  'tho subject text 3' is, to the in-core test embedding, the vector of a
--  text, not of a note.
--
--  1 and 2 are tests of the change (each fails before it, with ZIN00);
--  3 to 5 are guards and hold on both sides:
--    1. OPTIONAL with bif:contains on the orphaned literal's word: twelve
--       rows, nothing bound.
--    2. OPTIONAL with bif:knnSimilar, limit 2, on a text's vector: the hits
--       are texts, which no note uses -- twelve rows, nothing bound.
--    3. The plans of 1 and 2 are the ones the change is about: the search is
--       the first node of a hash filler.  (If the optimizer stops choosing
--       them, 1 and 2 no longer test anything, and this says so.)
--    4. OPTIONAL with bif:contains "note": twelve rows, six notes bound.
--    5. OPTIONAL with bif:knnSimilar on a note's own vector: that note,
--       bound on its own subject only.
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

echo BOTH "STARTED: hash join filler of an outer table (sqlo_hash_outer.sql)\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'tho-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tho-64', 'outer hash filler test model', 'internal:tho-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tho-64 STATE=" $STATE "\n";

create procedure DB.DBA.THO_FILL ()
{
  declare i integer;
  for (i := 1; i <= 12; i := i + 1)
    {
      ttlp (sprintf ('<urn:tho:s%d> <urn:tho:text> "tho subject text %d, stored in RDF_OBJ" .', i, 40 + i), '', 'urn:tho:g');
      if (i <= 6)
        ttlp (sprintf ('<urn:tho:s%d> <urn:tho:note> "tho note %d %d, stored in RDF_OBJ" .', i, i, i + 20), '', 'urn:tho:g');
    }
  -- notes of other subjects, so that reading every note costs more than the search
  for (i := 1; i <= 200; i := i + 1)
    ttlp (sprintf ('<urn:tho:x%d> <urn:tho:note> "tho other note %d, stored in RDF_OBJ" .', i, 100 + i), '', 'urn:tho:g');
}
;
DB.DBA.THO_FILL ();
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tho:g');
ECHO BOTH $IF $EQU $LAST[1] 218 "PASSED" "***FAILED";
ECHO BOTH ": 218 quads in urn:tho:g: " $LAST[1] "\n";

DB.DBA.RDF_OBJ_FT_RULE_ADD (null, null, 'tho_all');
sparql insert data { graph <urn:tho:g> { <urn:tho:z> <urn:tho:note> "tho orphaned zzorphan literal, stored in RDF_OBJ" } };
DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();
sparql delete data { graph <urn:tho:g> { <urn:tho:z> <urn:tho:note> "tho orphaned zzorphan literal, stored in RDF_OBJ" } };
DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tho:idx', 'tho-64', null, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": free-text and vector indexes on the literals STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- 'rows/bound' of a query returning (count (*), count (?n)), or the SQLSTATE.
create procedure DB.DBA.THO_SIG (in q varchar) returns varchar
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
  return sprintf ('%d/%d', rs[0][0], rs[0][1]);
}
;

-- 1 when, in the EXPLAIN of Q, the first node of a hash filler contains PAT.
create procedure DB.DBA.THO_FILLER_LEADS (in q varchar, in pat varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  declare inx integer;
  st := '00000';
  exec ('explain (?)', st, msg, vector (q), 0, md, rs);
  if (st <> '00000')
    return -1;
  for (inx := 0; inx < length (rs) - 1; inx := inx + 1)
    if (strstr (cast (rs[inx][0] as varchar), 'hash filler') is not null
        and strstr (cast (rs[inx + 1][0] as varchar), pat) is not null)
      return 1;
  return 0;
}
;

-- ---------------------------------------------------------------------------
-- 1, 2. A search hit the table source finds no row for
-- ---------------------------------------------------------------------------

select DB.DBA.THO_SIG ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s ?p ?n . ?n bif:contains "zzorphan" } }');
ECHO BOTH $IF $EQU $LAST[1] "12/0" "PASSED" "***FAILED";
ECHO BOTH ": OPTIONAL bif:contains hitting a literal no triple uses, rows/bound: " $LAST[1] "\n";

select DB.DBA.THO_SIG ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s <urn:tho:note> ?n . ?n bif:knnSimilar "tho subject text 3" option (index <urn:tho:idx>, limit 2) } }');
ECHO BOTH $IF $EQU $LAST[1] "12/0" "PASSED" "***FAILED";
ECHO BOTH ": OPTIONAL bif:knnSimilar on a text's vector, limit 2, rows/bound: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 3. Guard: the plans are the ones this is about
-- ---------------------------------------------------------------------------

select DB.DBA.THO_FILLER_LEADS ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s ?p ?n . ?n bif:contains "zzorphan" } }', 'CONTAINS');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the free-text search leads a hash filler: " $LAST[1] "\n";

select DB.DBA.THO_FILLER_LEADS ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s <urn:tho:note> ?n . ?n bif:knnSimilar "tho subject text 3" option (index <urn:tho:idx>, limit 2) } }', 'rdf_obj driving');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the vector search leads a hash filler: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 4, 5. Guards: hits the table source keeps
-- ---------------------------------------------------------------------------

select DB.DBA.THO_SIG ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s <urn:tho:note> ?n . ?n bif:contains "note" } }');
ECHO BOTH $IF $EQU $LAST[1] "12/6" "PASSED" "***FAILED";
ECHO BOTH ": OPTIONAL bif:contains on a word of the notes, rows/bound: " $LAST[1] "\n";

select DB.DBA.THO_SIG ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s <urn:tho:note> ?n . ?n bif:knnSimilar "tho note 3 23" option (index <urn:tho:idx>, limit 2) } }');
ECHO BOTH $IF $EQU $LAST[1] "12/1" "PASSED" "***FAILED";
ECHO BOTH ": OPTIONAL bif:knnSimilar on a note's own vector, rows/bound: " $LAST[1] "\n";

select DB.DBA.THO_SIG ('sparql select count (*), count (?n) where { graph <urn:tho:g> { ?s <urn:tho:text> ?t } optional { ?s <urn:tho:note> ?n . ?n bif:knnSimilar "tho note 3 23" option (index <urn:tho:idx>, limit 2) } filter (?s = <urn:tho:s3>) }');
ECHO BOTH $IF $EQU $LAST[1] "1/1" "PASSED" "***FAILED";
ECHO BOTH ": ... and it is bound on its own subject, rows/bound: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tho:idx');
DB.DBA.RDF_OBJ_FT_RULE_DEL (null, null, 'tho_all');
sparql clear graph <urn:tho:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tho-64';
drop procedure DB.DBA.THO_FILL;
drop procedure DB.DBA.THO_SIG;
drop procedure DB.DBA.THO_FILLER_LEADS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: hash join filler of an outer table (sqlo_hash_outer.sql)\n";
