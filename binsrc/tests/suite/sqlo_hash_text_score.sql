--
--  sqlo_hash_text_score.sql
--
--  A free-text SCORE read through a hash join must be each row's own score.
--
--  contains () writes SCORE -- and its other virtual columns, as knnSimilar
--  writes SIMILARITY and DISTANCE -- into a slot of its search node.  When
--  the optimizer made the searched table the build side of a hash join, the
--  search ran inside the hash filler, and the hash table kept only the real
--  columns the query read: every probe then read whatever score the filler
--  wrote last, so every joined row carried one and the same SCORE.  The rows
--  themselves were right.
--
--  Data: 200 documents with a text index, each with one to seven 'apple's,
--  so a search for 'apple' scores them at 7 levels; each document is
--  referenced by one row of TXH_REF, and each of its 3 tags by one row of
--  TXH_TAG.  For knnSimilar, 41 questions each with an answer text, scored by
--  the in-core test embedding at 3 levels (1, 0.75, 0.5).  Every join is
--  compared with the same search without it, or as a loop join.
--
--  1-6 are tests of the change (each fails before it); 7-11 are guards and
--  hold on both sides:
--    1. A unique hash join (on the document id), TABLE OPTION (HASH): rows,
--       distinct SCORE values and their sum are the loop join's.  Before:
--       one SCORE for every row.
--    2. A non-unique hash join (on the tag): the same.
--    3. A join test that reads SCORE and a column of the probe side, which
--       runs after the hash lookup: the loop join's count.
--    4. contains (..., SCORE, sc), the form SPARQL generates for
--       bif:contains option (score ?sc): the loop join's.
--    5. knnSimilar's SIMILARITY and DISTANCE through a hash join: the
--       search's own.  (Values only: the plan may be a loop join.)
--    6. A hash join whose filler would join the tag table, which restricts
--       the documents (a hash fill join): the loop join's.  Before: SQ156,
--       "col is not supposed to be virtual".
--    7. The search alone finds 200 documents at 7 score levels.
--    8. The loop join agrees with the search alone.
--    9. The plans of 1-4 are the ones this is about: the text search is the
--       first node of a hash filler.
--   10. A hash join that reads no score keeps the search's rows and its
--       hash plan.
--   11. The query of 6 reading no score keeps its hash fill join.
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

echo BOTH "STARTED: free-text SCORE through a hash join (sqlo_hash_text_score.sql)\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

create table DB.DBA.TXH_DOC (id integer primary key, txt varchar, tag varchar);
create table DB.DBA.TXH_REF (k integer primary key, doc integer);
create table DB.DBA.TXH_TAG (g varchar primary key);
create text index on DB.DBA.TXH_DOC (txt);

create procedure DB.DBA.TXH_FILL ()
{
  declare i integer;
  for (i := 1; i <= 200; i := i + 1)
    {
      insert into DB.DBA.TXH_DOC values (i,
	  repeat ('apple ', 1 + mod (i, 7)) || ' filler words here ' || repeat ('pear ', mod (i, 5)),
	  sprintf ('t%d', mod (i, 3)));
      insert into DB.DBA.TXH_REF values (i, i);
    }
  insert into DB.DBA.TXH_TAG values ('t0');
  insert into DB.DBA.TXH_TAG values ('t1');
  insert into DB.DBA.TXH_TAG values ('t2');
}
;
DB.DBA.TXH_FILL ();
DB.DBA.VT_INC_INDEX_DB_DBA_TXH_DOC ();
select count (*) from DB.DBA.TXH_DOC where contains (txt, 'apple');
ECHO BOTH $IF $EQU $LAST[1] 200 "PASSED" "***FAILED";
ECHO BOTH ": 200 documents with a text index found by 'apple': " $LAST[1] "\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'txh-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('txh-64', 'hash join score test model', 'internal:txh-64', 'test_embedding', 'embedding', '1,64', now (), now ());
create procedure DB.DBA.TXH_KNN_FILL ()
{
  declare i integer;
  for (i := 1; i <= 40; i := i + 1)
    ttlp (sprintf ('<urn:txh:q%d> <urn:txh:answer> <urn:txh:a%d> . <urn:txh:a%d> <urn:txh:text> "txh answer %d %d, stored in RDF_OBJ" .',
		   i, i, i, i, i + 20), '', 'urn:txh:g');
  ttlp ('<urn:txh:q41> <urn:txh:answer> <urn:txh:a41> . <urn:txh:a41> <urn:txh:text> "txh answer 5 6, stored in RDF_OBJ" .', '', 'urn:txh:g');
}
;
DB.DBA.TXH_KNN_FILL ();
DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:txh:idx', 'txh-64', null, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": 41 answer texts and their vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  'rows/distinct/sum' of a query returning (count, count distinct, sum), or
--  the SQLSTATE, which never equals a result.
create procedure DB.DBA.TXH_SIG (in q varchar) returns varchar
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

--  1 when, in the EXPLAIN of Q, the first node of a hash filler contains PAT.
create procedure DB.DBA.TXH_FILLER_LEADS (in q varchar, in pat varchar) returns integer
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
-- 1-4. Free-text SCORE through a hash join
-- ---------------------------------------------------------------------------

select DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'') option (order)'),
       DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b where a.doc = b.id and contains (b.txt, ''apple'') option (order, loop)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": unique hash join, rows/distinct/sum of SCORE " $LAST[1] " = the loop join's " $LAST[2] "\n";

select DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_TAG a, DB.DBA.TXH_DOC b table option (hash) where a.g = b.tag and contains (b.txt, ''apple'') option (order)'),
       DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_TAG a, DB.DBA.TXH_DOC b where a.g = b.tag and contains (b.txt, ''apple'') option (order, loop)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": non-unique hash join, rows/distinct/sum of SCORE " $LAST[1] " = the loop join's " $LAST[2] "\n";

select DB.DBA.TXH_SIG ('select count (*), 0, 0 from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'') and b.SCORE > mod (a.k, 50) option (order)'),
       DB.DBA.TXH_SIG ('select count (*), 0, 0 from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b where a.doc = b.id and contains (b.txt, ''apple'') and b.SCORE > mod (a.k, 50) option (order, loop)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": a join test on SCORE after the hash lookup, rows " $LAST[1] " = the loop join's " $LAST[2] "\n";

select DB.DBA.TXH_SIG ('select count (*), count (distinct sc), sum (sc) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'', SCORE, sc) option (order)'),
       DB.DBA.TXH_SIG ('select count (*), count (distinct sc), sum (sc) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b where a.doc = b.id and contains (b.txt, ''apple'', SCORE, sc) option (order, loop)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": contains (..., SCORE, sc) through a hash join, rows/distinct/sum " $LAST[1] " = the loop join's " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 5. knnSimilar's SIMILARITY and DISTANCE through a hash join
-- ---------------------------------------------------------------------------

select DB.DBA.TXH_SIG ('select count (*), count (distinct t.SIMILARITY), cast (1000 * sum (t.SIMILARITY) + 0.5 as integer) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash) where q.G = iri_to_id (''urn:txh:g'') and q.P = iri_to_id (''urn:txh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:txh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:txh:idx'', 100000) option (order)'),
       DB.DBA.TXH_SIG ('select count (*), count (distinct t.SIMILARITY), cast (1000 * sum (t.SIMILARITY) + 0.5 as integer) from DB.DBA.RDF_QUAD t where t.G = iri_to_id (''urn:txh:g'') and t.P = iri_to_id (''urn:txh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:txh:idx'', 100000)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": knnSimilar SIMILARITY through a hash join " $LAST[1] " = the search's " $LAST[2] "\n";

select DB.DBA.TXH_SIG ('select count (*), count (distinct t.DISTANCE), cast (1000 * sum (t.DISTANCE) + 0.5 as integer) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_QUAD t table option (hash) where q.G = iri_to_id (''urn:txh:g'') and q.P = iri_to_id (''urn:txh:answer'') and t.S = q.O and t.P = iri_to_id (''urn:txh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:txh:idx'', 100000) option (order)'),
       DB.DBA.TXH_SIG ('select count (*), count (distinct t.DISTANCE), cast (1000 * sum (t.DISTANCE) + 0.5 as integer) from DB.DBA.RDF_QUAD t where t.G = iri_to_id (''urn:txh:g'') and t.P = iri_to_id (''urn:txh:text'') and knnSimilar (t.O, ''answer 5 6'', ''urn:txh:idx'', 100000)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": knnSimilar DISTANCE through a hash join " $LAST[1] " = the search's " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 6. A hash join whose filler would join another table
-- ---------------------------------------------------------------------------

select DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash), DB.DBA.TXH_TAG c where a.doc = b.id and b.tag = c.g and c.g = ''t1'' and contains (b.txt, ''apple'') option (order)'),
       DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b, DB.DBA.TXH_TAG c where a.doc = b.id and b.tag = c.g and c.g = ''t1'' and contains (b.txt, ''apple'') option (order, loop)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": hash join with a restricting table, rows/distinct/sum of SCORE " $LAST[1] " = the loop join's " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 7, 8. Guards: the search alone, and the loop join
-- ---------------------------------------------------------------------------

select DB.DBA.TXH_SIG ('select count (*), count (distinct SCORE), sum (SCORE) from DB.DBA.TXH_DOC where contains (txt, ''apple'')');
ECHO BOTH $IF $EQU $LAST[1] "200/7/9614" "PASSED" "***FAILED";
ECHO BOTH ": the search alone, rows/distinct/sum of SCORE: " $LAST[1] "\n";

select DB.DBA.TXH_SIG ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b where a.doc = b.id and contains (b.txt, ''apple'') option (order, loop)');
ECHO BOTH $IF $EQU $LAST[1] "200/7/9614" "PASSED" "***FAILED";
ECHO BOTH ": the loop join, rows/distinct/sum of SCORE: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 9. Guard: the plans are the ones this is about
-- ---------------------------------------------------------------------------

select DB.DBA.TXH_FILLER_LEADS ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'') option (order)', 'CONTAINS'),
       DB.DBA.TXH_FILLER_LEADS ('select count (*), count (distinct b.SCORE), sum (b.SCORE) from DB.DBA.TXH_TAG a, DB.DBA.TXH_DOC b table option (hash) where a.g = b.tag and contains (b.txt, ''apple'') option (order)', 'CONTAINS'),
       DB.DBA.TXH_FILLER_LEADS ('select count (*) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'') and b.SCORE > mod (a.k, 50) option (order)', 'CONTAINS'),
       DB.DBA.TXH_FILLER_LEADS ('select count (*), count (distinct sc), sum (sc) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'', SCORE, sc) option (order)', 'CONTAINS');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the unique hash join's filler leads with the text search: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": the non-unique hash join's filler leads with the text search: " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": the join-test query's filler leads with the text search: " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] 1 "PASSED" "***FAILED";
ECHO BOTH ": the SCORE, sc query's filler leads with the text search: " $LAST[4] "\n";

-- ---------------------------------------------------------------------------
-- 10, 11. Guards: hash joins that read no score
-- ---------------------------------------------------------------------------

select DB.DBA.TXH_SIG ('select count (*), 0, 0 from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'') option (order)'),
       DB.DBA.TXH_FILLER_LEADS ('select count (*) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash) where a.doc = b.id and contains (b.txt, ''apple'') option (order)', 'CONTAINS');
ECHO BOTH $IF $EQU $LAST[1] "200/0/0" "PASSED" "***FAILED";
ECHO BOTH ": a hash join reading no score, rows: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": ... and still a hash join led by the text search: " $LAST[2] "\n";

select DB.DBA.TXH_SIG ('select count (*), 0, 0 from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash), DB.DBA.TXH_TAG c where a.doc = b.id and b.tag = c.g and c.g = ''t1'' and contains (b.txt, ''apple'') option (order)'),
       DB.DBA.TXH_FILLER_LEADS ('select count (*) from DB.DBA.TXH_REF a, DB.DBA.TXH_DOC b table option (hash), DB.DBA.TXH_TAG c where a.doc = b.id and b.tag = c.g and c.g = ''t1'' and contains (b.txt, ''apple'') option (order)', 'Subquery');
ECHO BOTH $IF $EQU $LAST[1] "67/0/0" "PASSED" "***FAILED";
ECHO BOTH ": the hash join with a restricting table reading no score, rows: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": ... and its filler a hash fill join (a subquery): " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:txh:idx');
sparql clear graph <urn:txh:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'txh-64';
drop table DB.DBA.TXH_TAG;
drop table DB.DBA.TXH_REF;
drop table DB.DBA.TXH_DOC;
drop procedure DB.DBA.TXH_FILL;
drop procedure DB.DBA.TXH_KNN_FILL;
drop procedure DB.DBA.TXH_SIG;
drop procedure DB.DBA.TXH_FILLER_LEADS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: free-text SCORE through a hash join (sqlo_hash_text_score.sql)\n";
