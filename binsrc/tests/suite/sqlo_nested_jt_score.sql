--
--  sqlo_nested_jt_score.sql
--
--  $Id$
--
--  A free-text SCORE read through a joined table nested in an outer join
--
--  A joined table on the right of an outer join is compiled as a derived
--  table selecting the real columns of its tables, and the contains () of
--  each is moved into that derived table.  A virtual column such as the
--  SCORE of the contains () was not among its columns, so reading it in the
--  enclosing query failed with SQ156 "unknown table for a column dfe".
--  Inside the derived table the optimizer may then join the text table into
--  the filler of a hash join (a hash fill join) -- OPTION (LOOP) on the
--  enclosing query does not reach it -- and such a filler cannot carry a
--  virtual column: SQ156 "col is not supposed to be virtual".  That a hash
--  join carries one at all is the fix of Bugzilla 19671, which this needs.
--  250 references, each with one link to a document; 200 documents, 50 of
--  them with 'pear'.  The query
--
--    TNJ_REF a LEFT OUTER JOIN (TNJ_LINK b JOIN TNJ_DOC c ON ...) ON ...
--
--  is compared with the same written with a derived table selecting the
--  score:
--
--    1. c.SCORE counted and summed, contains () in the WHERE, with OPTION
--       (LOOP) and without options.
--    2. c.SCORE in the select list: the result column's name, and the
--       score of each row.
--    3. c.SCORE in the ORDER BY.
--    4. The derived-table form without OPTION (LOOP), whose text table is
--       joined into a hash filler too.
--    5. Guards: the derived-table form with OPTION (LOOP), counted and
--       ordered by the score; the nested joined table not reading the
--       score; the joined table by an inner join.
--
--  With contains () in the ON condition of the joined table the query
--  fails before this, with SQ200 "No column c.SCORE", until the fix of
--  Bugzilla 19672 is in; it is not tested here.
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

echo BOTH "STARTED: free-text SCORE through a nested joined table (sqlo_nested_jt_score.sql)\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

create table DB.DBA.TNJ_DOC (id integer primary key, txt varchar);
create table DB.DBA.TNJ_REF (k integer primary key);
create table DB.DBA.TNJ_LINK (k integer primary key, doc integer);
create text index on DB.DBA.TNJ_DOC (txt);

create procedure DB.DBA.TNJ_FILL ()
{
  declare i integer;
  for (i := 1; i <= 250; i := i + 1)
    {
      if (i <= 200)
	insert into DB.DBA.TNJ_DOC values (i,
	    repeat ('apple ', 1 + mod (i, 7)) || case when mod (i, 4) = 0 then ' pear' else '' end);
      insert into DB.DBA.TNJ_REF values (i);
      insert into DB.DBA.TNJ_LINK values (i, i);
    }
}
;
DB.DBA.TNJ_FILL ();
DB.DBA.VT_INC_INDEX_DB_DBA_TNJ_DOC ();
select count (*) from DB.DBA.TNJ_DOC where contains (txt, 'pear');
ECHO BOTH $IF $EQU $LAST[1] 50 "PASSED" "***FAILED";
ECHO BOTH ": 50 documents found by 'pear': " $LAST[1] "\n";

--  'rows/scores/sum' of a query returning (count (*), count (x), sum (x)),
--  or the SQLSTATE, which never equals a result.
create procedure DB.DBA.TNJ_SIG (in q varchar) returns varchar
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

--  The name of the second result column of q, upper case whatever the
--  CaseMode, and 'k:score' of its first three rows, or the SQLSTATE.
create procedure DB.DBA.TNJ_ROWS (in q varchar) returns varchar
{
  declare st, msg, res varchar;
  declare md, rs any;
  declare inx integer;
  st := '00000';
  rs := null;
  exec (q, st, msg, vector (), 0, md, rs);
  if (st <> '00000')
    return sprintf ('error %s', st);
  res := upper (md[0][1][0]);
  for (inx := 0; inx < length (rs) and inx < 3; inx := inx + 1)
    res := res || sprintf (' %d:%d', rs[inx][0], coalesce (rs[inx][1], -1));
  return res;
}
;

-- ---------------------------------------------------------------------------
-- 1-3. SCORE through the nested joined table
-- ---------------------------------------------------------------------------

select DB.DBA.TNJ_SIG ('select count (*), count (c.SCORE), sum (c.SCORE) from DB.DBA.TNJ_REF a left outer join (DB.DBA.TNJ_LINK b join DB.DBA.TNJ_DOC c on (b.doc = c.id)) on (a.k = b.k) where contains (c.txt, ''pear'') option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/50/585" "PASSED" "***FAILED";
ECHO BOTH ": c.SCORE through a joined table in a LEFT OUTER JOIN, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TNJ_SIG ('select count (*), count (c.SCORE), sum (c.SCORE) from DB.DBA.TNJ_REF a left outer join (DB.DBA.TNJ_LINK b join DB.DBA.TNJ_DOC c on (b.doc = c.id)) on (a.k = b.k) where contains (c.txt, ''pear'')');
ECHO BOTH $IF $EQU $LAST[1] "250/50/585" "PASSED" "***FAILED";
ECHO BOTH ": ... without options, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TNJ_ROWS ('select a.k, c.SCORE from DB.DBA.TNJ_REF a left outer join (DB.DBA.TNJ_LINK b join DB.DBA.TNJ_DOC c on (b.doc = c.id)) on (a.k = b.k) where contains (c.txt, ''pear'') and a.k in (3, 4, 8) order by a.k option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "SCORE 3:-1 4:11 8:13" "PASSED" "***FAILED";
ECHO BOTH ": c.SCORE in the select list, its name and rows k:score (-1 for none): " $LAST[1] "\n";

select DB.DBA.TNJ_ROWS ('select top 3 a.k, c.SCORE from DB.DBA.TNJ_REF a left outer join (DB.DBA.TNJ_LINK b join DB.DBA.TNJ_DOC c on (b.doc = c.id)) on (a.k = b.k) where contains (c.txt, ''pear'') order by c.SCORE desc, a.k option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "SCORE 28:14 56:14 84:14" "PASSED" "***FAILED";
ECHO BOTH ": c.SCORE in the ORDER BY, the first rows k:score: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 4. The derived-table form without OPTION (LOOP)
-- ---------------------------------------------------------------------------

select DB.DBA.TNJ_SIG ('select count (*), count (d.s), sum (d.s) from DB.DBA.TNJ_REF a left outer join (select b.k as k, c.SCORE as s from DB.DBA.TNJ_LINK b, DB.DBA.TNJ_DOC c where b.doc = c.id and contains (c.txt, ''pear'')) d on (a.k = d.k)');
ECHO BOTH $IF $EQU $LAST[1] "250/50/585" "PASSED" "***FAILED";
ECHO BOTH ": a derived table selecting the score, without options, rows/scores/sum: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 5. Guards
-- ---------------------------------------------------------------------------

select DB.DBA.TNJ_SIG ('select count (*), count (d.s), sum (d.s) from DB.DBA.TNJ_REF a left outer join (select b.k as k, c.SCORE as s from DB.DBA.TNJ_LINK b, DB.DBA.TNJ_DOC c where b.doc = c.id and contains (c.txt, ''pear'') option (loop)) d on (a.k = d.k) option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/50/585" "PASSED" "***FAILED";
ECHO BOTH ": the same with a derived table selecting the score, rows/scores/sum: " $LAST[1] "\n";

select DB.DBA.TNJ_ROWS ('select top 3 a.k, d.s from DB.DBA.TNJ_REF a left outer join (select b.k as k, c.SCORE as s from DB.DBA.TNJ_LINK b, DB.DBA.TNJ_DOC c where b.doc = c.id and contains (c.txt, ''pear'') option (loop)) d on (a.k = d.k) order by d.s desc, a.k option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "S 28:14 56:14 84:14" "PASSED" "***FAILED";
ECHO BOTH ": ... ordered by the score, the first rows k:score: " $LAST[1] "\n";

select DB.DBA.TNJ_SIG ('select count (*), count (c.id), 0 from DB.DBA.TNJ_REF a left outer join (DB.DBA.TNJ_LINK b join DB.DBA.TNJ_DOC c on (b.doc = c.id)) on (a.k = b.k) where contains (c.txt, ''pear'') option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "250/50/0" "PASSED" "***FAILED";
ECHO BOTH ": the nested joined table, not reading the score, rows/matches: " $LAST[1] "\n";

select DB.DBA.TNJ_SIG ('select count (*), count (c.SCORE), sum (c.SCORE) from DB.DBA.TNJ_REF a join (DB.DBA.TNJ_LINK b join DB.DBA.TNJ_DOC c on (b.doc = c.id)) on (a.k = b.k) where contains (c.txt, ''pear'') option (loop)');
ECHO BOTH $IF $EQU $LAST[1] "50/50/585" "PASSED" "***FAILED";
ECHO BOTH ": the joined table by an inner join, rows/scores/sum: " $LAST[1] "\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: free-text SCORE through a nested joined table (sqlo_nested_jt_score.sql)\n";
