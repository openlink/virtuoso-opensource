--
--  sqlo_row_hash_join.sql
--
--  $Id$
--
--  Hash joins without the column-store hash
--
--  A hash join is built as a column-store hash (chash).  With
--  enable_chash_join = 0, or compiled row by row (enable_vec = 0), it would
--  be the older row hash, which is no longer maintained, so the optimizer
--  joins by loop instead.  Each query asks for the hash join
--  (TABLE OPTION (HASH), OPTION (ORDER)) and is compared with the answer the
--  loop join gives:
--
--    1. Guards: the loop join and the default hash join of each query.
--    2. enable_chash_join = 0: a filler hashing the whole table, a filler
--       restricted by a key range, a free-text search in the filler -- each
--       returning a column of the hashed table and returning none -- and a
--       filler joining a second table (a hash fill join).  A procedure
--       compiled with enable_chash_join = 0 and run with 1, and the reverse.
--    3. enable_vec = 0: the same queries compiled row by row, and a
--       procedure compiled with enable_vec = 0 and run with 1.
--
--  The plans are checked: a hash join by default, none with either setting
--  off.  A plan compiled with a chash runs as one whatever the settings are
--  at run time.
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

echo BOTH "STARTED: hash joins without the column-store hash (sqlo_row_hash_join.sql)\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

--  3000 documents of 23 characters, every 100th of 30 with 'quince ' in
--  front; a third of them tagged t1, 10 of those with 'quince'.
create table DB.DBA.TRH_DOC (id integer primary key, txt varchar, tag varchar);
create table DB.DBA.TRH_REF (k integer primary key, doc integer);
create table DB.DBA.TRH_TAG (g varchar primary key);
create text index on DB.DBA.TRH_DOC (txt);

create procedure DB.DBA.TRH_FILL ()
{
  declare i integer;
  for (i := 1; i <= 3000; i := i + 1)
    {
      insert into DB.DBA.TRH_DOC values (i,
	  case when mod (i, 100) = 0 then 'quince ' else '' end || 'plain filler words here',
	  sprintf ('t%d', mod (i, 3)));
      insert into DB.DBA.TRH_REF values (i, i);
    }
  insert into DB.DBA.TRH_TAG values ('t0');
  insert into DB.DBA.TRH_TAG values ('t1');
  insert into DB.DBA.TRH_TAG values ('t2');
}
;
DB.DBA.TRH_FILL ();
DB.DBA.VT_INC_INDEX_DB_DBA_TRH_DOC ();
select count (*) from DB.DBA.TRH_DOC where contains (txt, 'quince');
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
ECHO BOTH ": 30 documents found by 'quince': " $LAST[1] "\n";

--  'count/sum' of a query returning two numbers, or the SQLSTATE, which
--  never equals a result.  The query is compiled with enable_chash_join
--  and enable_vec set as given, and both are put back before returning.
create procedure DB.DBA.TRH_SIG (in q varchar, in chash integer := 1, in vec integer := 1) returns varchar
{
  declare st, msg, res varchar;
  declare md, rs any;
  declare chash_save, vec_save integer;
  chash_save := __dbf_set ('enable_chash_join', chash);
  vec_save := __dbf_set ('enable_vec', vec);
  st := '00000';
  rs := null;
  exec (q, st, msg, vector (), 0, md, rs);
  __dbf_set ('enable_chash_join', chash_save);
  __dbf_set ('enable_vec', vec_save);
  if (st <> '00000')
    return sprintf ('error %s', st);
  if (not isarray (rs) or length (rs) <> 1)
    return 'no row';
  return sprintf ('%d/%d', rs[0][0], coalesce (rs[0][1], 0));
}
;

--  1 if the plan of q, compiled as TRH_SIG compiles it, probes a hash
--  (has a hash source), else 0.  The filler shows as 'hash filler' or as
--  'fork' depending on whether it may be shared, so it is not looked for.
create procedure DB.DBA.TRH_IS_HASH (in q varchar, in chash integer := 1, in vec integer := 1) returns integer
{
  declare st, msg, txt varchar;
  declare md, rs any;
  declare chash_save, vec_save, inx integer;
  chash_save := __dbf_set ('enable_chash_join', chash);
  vec_save := __dbf_set ('enable_vec', vec);
  st := '00000';
  rs := null;
  exec ('explain (?)', st, msg, vector (q), 0, md, rs);
  __dbf_set ('enable_chash_join', chash_save);
  __dbf_set ('enable_vec', vec_save);
  if (st <> '00000' or not isarray (rs))
    return 0;
  txt := '';
  for (inx := 0; inx < length (rs); inx := inx + 1)
    txt := txt || rs[inx][0] || '\n';
  if (strstr (txt, 'Hash source') is not null)
    return 1;
  return 0;
}
;

--  The queries, by the filler of their hash join.
create procedure DB.DBA.TRH_Q (in shape varchar, in join_opt varchar := 'table option (hash)', in q_opt varchar := 'option (order)') returns varchar
{
  if (shape = 'table')
    return sprintf ('select count (*), sum (length (b.txt)) from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b %s where a.doc = b.id and b.tag = ''t1'' %s', join_opt, q_opt);
  if (shape = 'table, no column')
    return sprintf ('select count (*), 0 from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b %s where a.doc = b.id and b.tag = ''t1'' %s', join_opt, q_opt);
  if (shape = 'key range')
    return sprintf ('select count (*), sum (length (b.txt)) from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b %s where a.doc = b.id and b.id < 30 %s', join_opt, q_opt);
  if (shape = 'text')
    return sprintf ('select count (*), sum (length (b.txt)) from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b %s where a.doc = b.id and contains (b.txt, ''quince'') %s', join_opt, q_opt);
  if (shape = 'text, no column')
    return sprintf ('select count (*), 0 from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b %s where a.doc = b.id and contains (b.txt, ''quince'') %s', join_opt, q_opt);
  if (shape = 'fill join')
    return sprintf ('select count (*), sum (length (b.txt)) from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b %s, DB.DBA.TRH_TAG c where a.doc = b.id and b.tag = c.g and c.g = ''t1'' %s', join_opt, q_opt);
  signal ('22023', 'TRH_Q: no such shape');
}
;

--  The plans of all six queries, one digit each.
create procedure DB.DBA.TRH_PLANS (in chash integer, in vec integer) returns varchar
{
  declare res varchar;
  res := '';
  foreach (varchar shape in vector ('table', 'table, no column', 'key range', 'text', 'text, no column', 'fill join')) do
    res := res || cast (DB.DBA.TRH_IS_HASH (DB.DBA.TRH_Q (shape), chash, vec) as varchar);
  return res;
}
;

-- ---------------------------------------------------------------------------
-- 1. Guards: the loop join, and the default hash join
-- ---------------------------------------------------------------------------

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table', '', 'option (loop)')),
       DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('key range', '', 'option (loop)')),
       DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('text', '', 'option (loop)')),
       DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('fill join', '', 'option (loop)'));
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": loop join, whole table, count/sum: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "29/667" "PASSED" "***FAILED";
ECHO BOTH ": loop join, key range, count/sum: " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] "30/900" "PASSED" "***FAILED";
ECHO BOTH ": loop join, free-text search, count/sum: " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": loop join, joining a second table, count/sum: " $LAST[4] "\n";

select DB.DBA.TRH_PLANS (1, 1);
ECHO BOTH $IF $EQU $LAST[1] "111111" "PASSED" "***FAILED";
ECHO BOTH ": the six queries have a hash join by default: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table')),
       DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('key range')),
       DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('text')),
       DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('fill join'));
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": default hash join, whole table, count/sum: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "29/667" "PASSED" "***FAILED";
ECHO BOTH ": default hash join, key range, count/sum: " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] "30/900" "PASSED" "***FAILED";
ECHO BOTH ": default hash join, free-text search, count/sum: " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": default hash join, joining a second table, count/sum: " $LAST[4] "\n";

-- ---------------------------------------------------------------------------
-- 2. enable_chash_join = 0
-- ---------------------------------------------------------------------------

select DB.DBA.TRH_PLANS (0, 1);
ECHO BOTH $IF $EQU $LAST[1] "000000" "PASSED" "***FAILED";
ECHO BOTH ": the six queries have no hash join with enable_chash_join = 0: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table'), 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": enable_chash_join = 0, whole table, count/sum: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table, no column'), 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "1000/0" "PASSED" "***FAILED";
ECHO BOTH ": enable_chash_join = 0, whole table, no column of it, count: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('key range'), 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "29/667" "PASSED" "***FAILED";
ECHO BOTH ": enable_chash_join = 0, key range, count/sum: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('text'), 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "30/900" "PASSED" "***FAILED";
ECHO BOTH ": enable_chash_join = 0, free-text search, count/sum: " $LAST[1] "\n";

--  A procedure compiled with enable_chash_join = 0, run with the default.
select __dbf_set ('enable_chash_join', 0);
create procedure DB.DBA.TRH_P_ROW () returns varchar
{
  declare c, s integer;
  select count (*), sum (length (b.txt)) into c, s from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b table option (hash)
      where a.doc = b.id and b.tag = 't1' option (order);
  return sprintf ('%d/%d', c, coalesce (s, 0));
}
;
select __dbf_set ('enable_chash_join', 1);
select DB.DBA.TRH_P_ROW ();
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": compiled with enable_chash_join = 0, run with 1, count/sum: " $LAST[1] "\n";

--  These three have crashed the server.
select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('text, no column'), 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "30/0" "PASSED" "***FAILED";
ECHO BOTH ": enable_chash_join = 0, free-text search, no column of the table, count: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('fill join'), 0, 1);
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": enable_chash_join = 0, joining a second table, count/sum: " $LAST[1] "\n";

--  A procedure compiled with the default, run with enable_chash_join = 0.
create procedure DB.DBA.TRH_P_CHASH () returns varchar
{
  declare c, s integer;
  select count (*), sum (length (b.txt)) into c, s from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b table option (hash)
      where a.doc = b.id and b.tag = 't1' option (order);
  return sprintf ('%d/%d', c, coalesce (s, 0));
}
;
select __dbf_set ('enable_chash_join', 0);
select DB.DBA.TRH_P_CHASH ();
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": compiled with enable_chash_join = 1, run with 0, count/sum: " $LAST[1] "\n";
select __dbf_set ('enable_chash_join', 1);

-- ---------------------------------------------------------------------------
-- 3. enable_vec = 0
-- ---------------------------------------------------------------------------

select DB.DBA.TRH_PLANS (1, 0);
ECHO BOTH $IF $EQU $LAST[1] "000000" "PASSED" "***FAILED";
ECHO BOTH ": the six queries have no hash join with enable_vec = 0: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table'), 1, 0);
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0, whole table, count/sum: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table, no column'), 1, 0);
ECHO BOTH $IF $EQU $LAST[1] "1000/0" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0, whole table, no column of it, count: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('key range'), 1, 0);
ECHO BOTH $IF $EQU $LAST[1] "29/667" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0, key range, count/sum: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('text'), 1, 0);
ECHO BOTH $IF $EQU $LAST[1] "30/900" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0, free-text search, count/sum: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('text, no column'), 1, 0);
ECHO BOTH $IF $EQU $LAST[1] "30/0" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0, free-text search, no column of the table, count: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('fill join'), 1, 0);
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0, joining a second table, count/sum: " $LAST[1] "\n";

select DB.DBA.TRH_SIG (DB.DBA.TRH_Q ('table'), 0, 0);
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": enable_vec = 0 and enable_chash_join = 0, whole table, count/sum: " $LAST[1] "\n";

--  A procedure compiled with enable_vec = 0, run with the default.
select __dbf_set ('enable_vec', 0);
create procedure DB.DBA.TRH_P_NOVEC () returns varchar
{
  declare c, s integer;
  select count (*), sum (length (b.txt)) into c, s from DB.DBA.TRH_REF a, DB.DBA.TRH_DOC b table option (hash)
      where a.doc = b.id and b.tag = 't1' option (order);
  return sprintf ('%d/%d', c, coalesce (s, 0));
}
;
select __dbf_set ('enable_vec', 1);
select DB.DBA.TRH_P_NOVEC ();
ECHO BOTH $IF $EQU $LAST[1] "1000/23070" "PASSED" "***FAILED";
ECHO BOTH ": compiled with enable_vec = 0, run with 1, count/sum: " $LAST[1] "\n";

select __dbf_set ('enable_chash_join', 1), __dbf_set ('enable_vec', 1);

--
-- End of test
--
ECHO BOTH "COMPLETED: hash joins without the column-store hash (sqlo_row_hash_join.sql)\n";
