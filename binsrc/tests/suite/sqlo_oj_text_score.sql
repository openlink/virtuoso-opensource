--
--  sqlo_oj_text_score.sql
--
--  A free-text SCORE read through an ON condition must compile.
--
--  contains () makes its SCORE -- and its other virtual columns, ranges,
--  offband columns -- columns of its table when the select's WHERE clause is
--  scoped.  An ON condition never made them: a query reading SCORE of a
--  contains () written in a JOIN's ON condition failed with SQ200 "No column
--  b.SCORE", inner join or outer.  A LEFT OUTER JOIN to a single-table
--  derived table selecting t.SCORE failed the same way, "No column t3.SCORE":
--  the derived table is inlined, its WHERE becomes the join's ON condition,
--  and the statement is scoped again.
--
--  Data: 200 documents with a text index, each with one to seven 'apple's
--  (7 score levels), one in four with a 'pear'; 250 rows of TOJ_REF, of
--  which the first 200 reference a document.  Every join is a loop join.
--
--  1-4 are tests of the change (each fails before it); 5-8 are guards and
--  hold on both sides:
--    1. JOIN ... ON (a.k = b.id and contains (b.txt, 'apple')) reading
--       b.SCORE: rows, scores and their sum are the WHERE form's.
--       Before: SQ200.
--    2. The same as a LEFT OUTER JOIN: 250 rows, 200 scores, the same sum.
--    3. LEFT OUTER JOIN to a derived table selecting t.SCORE: the same.
--    4. ... searching 'pear', which 50 documents have: 250 rows, 50 scores
--       -- the 200 rows without a match have no score -- and the inner
--       join's sum.
--    5. The WHERE form: 200 rows, 200 scores, sum 9614.
--    6. The derived table alone, and joined with an inner join.
--    7. The LEFT OUTER JOIN to the derived table, not reading the score.
--    8. The LEFT OUTER JOIN with contains () in the ON condition, not
--       reading the score.
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

echo BOTH "STARTED: free-text SCORE through an ON condition (sqlo_oj_text_score.sql)\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

create table DB.DBA.TOJ_DOC (id integer primary key, txt varchar);
create table DB.DBA.TOJ_REF (k integer primary key);
create text index on DB.DBA.TOJ_DOC (txt);

create procedure DB.DBA.TOJ_FILL ()
{
  declare i integer;
  for (i := 1; i <= 250; i := i + 1)
    {
      if (i <= 200)
	insert into DB.DBA.TOJ_DOC values (i,
	    repeat ('apple ', 1 + mod (i, 7)) || case when mod (i, 4) = 0 then ' pear' else '' end);
      insert into DB.DBA.TOJ_REF values (i);
    }
}
;
DB.DBA.TOJ_FILL ();
DB.DBA.VT_INC_INDEX_DB_DBA_TOJ_DOC ();
select count (*) from DB.DBA.TOJ_DOC where contains (txt, 'apple');
ECHO BOTH $IF $EQU $LAST[1] 200 "PASSED" "***FAILED";
ECHO BOTH ": 200 documents with a text index found by 'apple': " $LAST[1] "\n";

--  'rows/scores/sum' of a query returning (count (*), count (score), sum
--  (score)), or the SQLSTATE, which never equals a result.
create procedure DB.DBA.TOJ_SIG (in q varchar) returns varchar
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
  return sprintf ('%d/%d/%d', rs[0][0], rs[0][1], coalesce (rs[0][2], 0));
}
;

-- ---------------------------------------------------------------------------
-- 1-4. SCORE through an ON condition
-- ---------------------------------------------------------------------------

select DB.DBA.TOJ_SIG ('select count (*), count (b.SCORE), sum (b.SCORE) from DB.DBA.TOJ_REF a join DB.DBA.TOJ_DOC b on (a.k = b.id and contains (b.txt, ''apple'')) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "200/200/9614" "PASSED" "***FAILED";
ECHO BOTH ": JOIN with contains () in the ON condition, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TOJ_SIG ('select count (*), count (b.SCORE), sum (b.SCORE) from DB.DBA.TOJ_REF a left outer join DB.DBA.TOJ_DOC b on (a.k = b.id and contains (b.txt, ''apple'')) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/200/9614" "PASSED" "***FAILED";
ECHO BOTH ": LEFT OUTER JOIN with contains () in the ON condition, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TOJ_SIG ('select count (*), count (b.x), sum (b.x) from DB.DBA.TOJ_REF a left outer join (select t.id as id, t.SCORE as x from DB.DBA.TOJ_DOC t where contains (t.txt, ''apple'')) b on (a.k = b.id) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/200/9614" "PASSED" "***FAILED";
ECHO BOTH ": LEFT OUTER JOIN to a derived table selecting t.SCORE, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TOJ_SIG ('select count (*), count (b.x), sum (b.x) from DB.DBA.TOJ_REF a left outer join (select t.id as id, t.SCORE as x from DB.DBA.TOJ_DOC t where contains (t.txt, ''pear'')) b on (a.k = b.id) option (loop)'),
       DB.DBA.TOJ_SIG ('select count (*), count (b.x), sum (b.x) from DB.DBA.TOJ_REF a join (select t.id as id, t.SCORE as x from DB.DBA.TOJ_DOC t where contains (t.txt, ''pear'')) b on (a.k = b.id) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/50/585" "PASSED" "***FAILED";
ECHO BOTH ": ... searching 'pear', rows/scores/sum: " $LAST[1] " (inner join: " $LAST[2] ")\n";

-- ---------------------------------------------------------------------------
-- 5-8. Guards
-- ---------------------------------------------------------------------------

select DB.DBA.TOJ_SIG ('select count (*), count (b.SCORE), sum (b.SCORE) from DB.DBA.TOJ_REF a, DB.DBA.TOJ_DOC b where a.k = b.id and contains (b.txt, ''apple'') option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "200/200/9614" "PASSED" "***FAILED";
ECHO BOTH ": contains () in the WHERE, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TOJ_SIG ('select count (*), count (b.x), sum (b.x) from (select t.id as id, t.SCORE as x from DB.DBA.TOJ_DOC t where contains (t.txt, ''apple'')) b'),
       DB.DBA.TOJ_SIG ('select count (*), count (b.x), sum (b.x) from DB.DBA.TOJ_REF a join (select t.id as id, t.SCORE as x from DB.DBA.TOJ_DOC t where contains (t.txt, ''apple'')) b on (a.k = b.id) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "200/200/9614" "PASSED" "***FAILED";
ECHO BOTH ": the derived table alone, rows/scores/sum: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "200/200/9614" "PASSED" "***FAILED";
ECHO BOTH ": the derived table by an inner join, rows/scores/sum: " $LAST[2] "\n";

select DB.DBA.TOJ_SIG ('select count (*), count (b.id), 0 from DB.DBA.TOJ_REF a left outer join (select t.id as id, t.SCORE as x from DB.DBA.TOJ_DOC t where contains (t.txt, ''apple'')) b on (a.k = b.id) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/200/0" "PASSED" "***FAILED";
ECHO BOTH ": LEFT OUTER JOIN to the derived table, not reading the score, rows/matches: " $LAST[1] "\n";

select DB.DBA.TOJ_SIG ('select count (*), count (b.id), 0 from DB.DBA.TOJ_REF a left outer join DB.DBA.TOJ_DOC b on (a.k = b.id and contains (b.txt, ''apple'')) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/200/0" "PASSED" "***FAILED";
ECHO BOTH ": LEFT OUTER JOIN with contains () in the ON condition, not reading the score, rows/matches: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

drop table DB.DBA.TOJ_REF;
drop table DB.DBA.TOJ_DOC;
drop procedure DB.DBA.TOJ_FILL;
drop procedure DB.DBA.TOJ_SIG;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: free-text SCORE through an ON condition (sqlo_oj_text_score.sql)\n";
