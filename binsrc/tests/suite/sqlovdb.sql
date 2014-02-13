--
--  sqlovdb.sql
--
--  $Id$
--
--  SQLO Remote database testing part 1
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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
--

--
--  Start the test
--
echo BOTH "STARTED: SQLO Remote test (sqlovdb.sql) PORT=" $U{PORT} " LOCALPORT="$U{LOCALPORT}"\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

update t1 set fi2 = 1111;
delete from R1..T1;
insert into R1..T1 select * from T1;

-- on MS SQLServer driver the datetime is truncated
update T1 a set TIME1 = (select b.TIME1 from R1..T1 b where b.ROW_NO = a.ROW_NO);

drop procedure F;
drop view T1V;
drop view R1..T1V;
drop view T1UN;
drop view T1_111;
drop view T1_222;
create procedure F (in Q any) { return Q; }


select A.ROW_NO from R1..T1 A, R1..T1 B where B.ROW_NO < 111 and A.ROW_NO = B.ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through join returned " $ROWCNT " rows\n";


explain ('select ROW_NO  from (select * from R1..T1 where ROW_NO < 222) F where FI2 = 1111');
select ROW_NO  from (select * from R1..T1 where ROW_NO < 222) F where FI2 = 1111;
ECHO BOTH $IF $EQU $ROWCNT 122 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through subq with remote/remote conds in enclosing & inside " $ROWCNT " rows\n";

explain ('select ROW_NO  from (select * from R1..T1 where ROW_NO < 222) F where F (FI2) = 1111');
select ROW_NO  from (select * from R1..T1 where ROW_NO < 222) F where F (FI2) = 1111;
ECHO BOTH $IF $EQU $ROWCNT 122 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq with remote/local conds in enclosing & inside " $ROWCNT " rows\n";


explain ('select ROW_NO  from (select * from R1..T1 where ROW_NO < 222 union all select * from R1..T1 where ROW_NO > 333) F where F (FI2) = 1111');
select ROW_NO  from (select * from R1..T1 where ROW_NO < 222 union all select * from R1..T1 where ROW_NO > 333) F where F (FI2) = 1111;
ECHO BOTH $IF $EQU $ROWCNT 888 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote union all subq with remote/local conds in enclosing & inside " $ROWCNT " rows\n";

explain ('select ROW_NO  from (select * from R1..T1 where ROW_NO < 222 union select * from R1..T1 where ROW_NO > 333) F where F (FI2) = 1111');
select ROW_NO  from (select * from R1..T1 where ROW_NO < 222 union select * from R1..T1 where ROW_NO > 333) F where F (FI2) = 1111;
ECHO BOTH $IF $EQU $ROWCNT 888 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote union subq with remote/local conds in enclosing & inside " $ROWCNT " rows\n";


explain ('select b.ROW_NO from R1..T1 b where exists (select a.ROW_NO FROM R1..T1 A where b.ROW_NO = 1 + 1 + A.ROW_NO)');
select b.ROW_NO from R1..T1 b where exists (select a.ROW_NO FROM R1..T1 A where b.ROW_NO = 1 + 1 + A.ROW_NO);
ECHO BOTH $IF $EQU $ROWCNT 998 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exists pass-through " $ROWCNT " rows\n";

explain ('select ROW_NO  from (select * from R1..T1 where ROW_NO < 222) F where F (11) = FI2');
select ROW_NO  from (select * from R1..T1 where ROW_NO < 222) F where F (11) = FI2;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through expanded subq with mixed conds " $ROWCNT " rows\n";


explain ('select count (*) from R1..T1 where ROW_NO > (select avg (ROW_NO) from T1)');
select count (*) from R1..T1 where ROW_NO > (select avg (ROW_NO) from T1);
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count remote query with local subq " $LAST[1] " rows\n";

explain ('select count (*) from R1..T1 where ROW_NO > (select avg (ROW_NO) from R1..T1)');
select count (*) from R1..T1 where ROW_NO > (select avg (ROW_NO) from R1..T1);
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count pass-through - remote query with remote subq " $LAST[1] " rows\n";

explain ('select ROW_NO  from R1..T1 where ROW_NO > (select avg (ROW_NO) from R1..T1)');
select ROW_NO  from R1..T1 where ROW_NO > (select avg (ROW_NO) from R1..T1);
ECHO BOTH $IF $EQU $ROWCNT 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through - remote query with remote subq " $ROWCNT " rows\n";

explain ('select sum (ROW_NO)  from R1..T1 where ROW_NO > (select avg (ROW_NO) from T1)');
select sum (ROW_NO)  from R1..T1 where ROW_NO > (select avg (ROW_NO) from T1);
ECHO BOTH $IF $EQU $LAST[1] 424750 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": sum remote query with remote subq " $LAST[1] " rows\n";


select ROW_NO  from (select * from R1..T1 where ROW_NO < 222 union all select * from R1..T1 where ROW_NO > 333) F where F (FI2) = 1111;
ECHO BOTH $IF $EQU $ROWCNT 888 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq union with local function where " $ROWCNT " rows\n";

create view T1V as select * from T1 where ROW_NO < 900;
create view R1..T1V as select * from R1..T1 where ROW_NO < 900;

select count (*) from (select * from T1V union select * from R1..T1) F;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq union with view & table returned " $LAST[1] " matching rows\n";

select count (*) from (select * from T1V) F;
ECHO BOTH $IF $EQU $LAST[1] 800 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq view returned " $LAST[1] " matching rows\n";

select count (*) from (select * from T1V FF) F;
ECHO BOTH $IF $EQU $LAST[1] 800 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq view with alias returned " $LAST[1] " matching rows\n";

create view T1UN as select * from T1 union all select * from R1..T1;

select count (T1UN.ROW_NO) from T1UN;
ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": union mixed view returned " $LAST[1] " matching rows\n";

select ROW_NO from T1UN where ROW_NO < 111;
ECHO BOTH $IF $EQU $ROWCNT 22 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": union mixed view with where returned " $ROWCNT " matching rows\n";



select count (ROW_NO) from T1UN B where exists (select 1 from T1UN A where A.ROW_NO = B.ROW_NO + 1);
ECHO BOTH $IF $EQU $LAST[1] 1998 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": union mixed view with exists the same union returned " $LAST[1] " matching rows\n";

select count (*) from R1..T1 where ROW_NO > (select avg (ROW_NO) from R1..T1);
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote/remote (pass-through) > ANY returned " $LAST[1] " matching rows\n";

select count (*) from R1..T1 where ROW_NO > (select avg (ROW_NO) from T1);
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote/local > ANY returned " $LAST[1] " matching rows\n";

create view T1_111 as select * from R1..T1 where STRING1 = '111';
create view T1_222 as select * from R1..T1 where STRING1 = '222';

select * from (select * from T1_111 union all select * from T1_222) b where b.STRING1 = '222';
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq on views union returned " $ROWCNT " rows\n";

select ROW_NO from R1..T1 where STRING2 < cast (111 as varchar) order by STRING2;
ECHO BOTH $IF $EQU $ROWCNT 52 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through oby " $ROWCNT " rows\n";
-- as the string1 is ordered the last result may differ
--ECHO BOTH $IF $EQU $LAST[1] 1090 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": pass-through oby last ROW_NO=" $LAST[1] "\n";

explain ('select  ROW_NO from T1 where ROW_NO >100 and ROW_NO >200');
select  ROW_NO from T1 where ROW_NO >100 and ROW_NO >200;

select  ROW_NO from R1..T1 where ROW_NO >100 and ROW_NO >200;
ECHO BOTH $IF $EQU $ROWCNT 899 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through where condition reduction (> 100 and > 200) returned " $ROWCNT " rows\n";

select  ROW_NO from T1 where ROW_NO <= 100 and ROW_NO <200;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local where condition reduction <= 100 /< 200 returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local where condition reduction <= 100 /< 200 last ROW_NO=" $LAST[1] "\n";

select  ROW_NO from T1 where ROW_NO < 100 and ROW_NO <200;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local where condition reduction < 100 /< 200 returned " $ROWCNT " rows\n";

select ROW_NO from R1..T1 where ROW_NO = 100 and ROW_NO = 200;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through where condition reduction = 100 /= 200 returned " $ROWCNT " rows\n";

select sum (ROW_NO) / count (*) from T1;
ECHO BOTH $IF $EQU $LAST[1] 599 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local sum(ROW_NO) /count (ROW_NO) returned " $LAST[1] "\n";

select sum (ROW_NO) / count (*) from T1 where ROW_NO =111 and ROW_NO = 222;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local sum(ROW_NO) /count (ROW_NO) on non-existant returned " $LAST[1] "\n";

select sum (ROW_NO) / count (*) from T1 where ROW_NO =111 and ROW_NO = 222 + 1;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local sum(ROW_NO) /count (*) on non-existant returned " $LAST[1] "\n";

select sum (ROW_NO) / count (*) from T1 where ROW_NO =223 and ROW_NO = 222 + 1;
ECHO BOTH $IF $EQU $LAST[1] 223 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local sum(ROW_NO) /count (*) on identical where's returned " $LAST[1] "\n";

select sum (ROW_NO) / count (*) from T1 where ROW_NO =223 and ROW_NO > 222 + 1;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local sum(ROW_NO) / count (*) on non-existant returned " $LAST[1] "\n";

select * from T1 where ROW_NO = 111 and ROW_NO = 222;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from identicaly false where returned " $ROWCNT " rows\n";

select ROW_NO from T1 where ROW_NO < 110 union select  ROW_NO from T1 where ROW_NO < 112 ;
ECHO BOTH $IF $EQU $ROWCNT 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": union with two where's returned " $ROWCNT " rows\n";

select ROW_NO, 1  from T1 where ROW_NO < 110 union select  ROW_NO, 2  from T1 where ROW_NO < 112 ;
ECHO BOTH $IF $EQU $ROWCNT 22 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": union with two where's and constant columns returned " $ROWCNT " rows\n";


select * from (select ROW_NO, 1 as XX  from T1 where ROW_NO < 110 union select  ROW_NO, 2  from T1 where ROW_NO < 112 ) F;
ECHO BOTH $IF $EQU $ROWCNT 22 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq union with two where's and constant columns returned " $ROWCNT " rows\n";


select * from (select * from T1 where ROW_NO = 111 union all select * from R1..T1 where ROW_NO = 222) F where ROW_NO = 444;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subq union with identicaly false condition returned " $ROWCNT " rows\n";


select A.ROW_NO, B.ROW_NO from T1 A left join R1..T1 B on A.ROW_NO = B.ROW_NO where B.ROW_NO < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local/remote eq join with remote where returned " $ROWCNT " rows\n";

ECHO BOTH "explain here \n";
explain ('select A.ROW_NO, B.ROW_NO from T1 A left join R1..T1 B on A.ROW_NO - 1 = B.ROW_NO where A.ROW_NO < 111');

select A.ROW_NO, B.ROW_NO from T1 A left join R1..T1 B on A.ROW_NO - 1 = B.ROW_NO where A.ROW_NO < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F1: local/remote non-eq join with local where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A left join R1..T1 B on A.ROW_NO - 1 = B.ROW_NO where B.ROW_NO < 111 and B.FI3 < 110;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F2: local/remote non-eq join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from R1..T1 A left join R1..T1 B on A.ROW_NO - 1 = B.ROW_NO where B.ROW_NO < 111 and B.FI3 < 110;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F4: remote/remote non-eq join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A left join (select * from T1 B where ROW_NO > 0) B on A.ROW_NO = B.ROW_NO where B.ROW_NO < 111 and B.FI3 < 110;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F5: local/subq_where remote eq join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from R1..T1 A left join (select * from R1..T1 B where ROW_NO > 0) B on A.ROW_NO - 1 = B.ROW_NO where B.ROW_NO < 111 and B.FI3 < 110;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F6: remote/subq_where remote non-eq join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from R1..T1 A left join (select * from R1..T1 B where ROW_NO > 0) B on A.ROW_NO = B.ROW_NO where B.ROW_NO < 111 and B.FI3 < 110;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F6: remote/subq_where remote eq join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from R1..T1 A, (select * from R1..T1 B where ROW_NO > 0) B where A.ROW_NO = B.ROW_NO and  B.ROW_NO < 111 and B.FI3 < 222;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote/subq_where remote table join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from R1..T1 A, (select *, FI3 + 11 as EXP from R1..T1 B where ROW_NO > 0) B where  A.ROW_NO = B.ROW_NO and  B.ROW_NO < 111 and EXP < 222;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote/subq_exp_where remote table join with remote composite where returned " $ROWCNT " rows\n";

select A.ROW_NO, B.ROW_NO from T1 A, (select * from R1..T1 B where ROW_NO > 0) B where  A.ROW_NO = B.ROW_NO and B.ROW_NO < 111 and B.FI3 < 222;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local/subq_where remote table join with remote composite where returned " $ROWCNT " rows\n";

select STRING1, (select sum (ROW_NO) from R1..T1 A where A.STRING1 = F.STRING1) from (select distinct STRING1 from T1) F;
ECHO BOTH $IF $EQU $ROWCNT 300 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote value subq from local_distinct_subq returned " $ROWCNT " rows\n";

select STRING1, (select sum (ROW_NO) from R1..T1 A where A.STRING1 = F.STRING1) from (select distinct STRING1 from R1..T1) F;
ECHO BOTH $IF $EQU $ROWCNT 300 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote value subq from remote_distinct_subq returned " $ROWCNT " rows\n";


select count (distinct cast ((ROW_NO / 2) as integer)) from R1..T1;
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote count (distinct expr) returned " $LAST[1] "\n";

select count (distinct ROW_NO / 2) from T1;
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": local count (distinct expr) returned " $LAST[1] "\n";

--- suite for bug 1018
create procedure test_vdb_pars1(in n integer)
{
  declare rs any;
  declare _id integer;
  declare _data integer;
  exec ('delete from R1..PUPD_TEST');
  if (n = 1)
    {
      exec ('insert into R1..PUPD_TEST (ID, DATA) values (?, ?)', null, null, vector (1, '1'));
      return;
    }
  else if (n = 2)
    {
       _id := 2;
       _data := '2';
       insert into R1..PUPD_TEST (ID, DATA) values (_id, _data);
    }
};

explain ('select * from R1..PUPD_TEST');
--ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": Select from remote pass-through\n";

explain ('update R1..PUPD_TEST set ID = ID + ? where DATA = ?');
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update remote pass-through\n";

explain ('insert into R1..PUPD_TEST (ID, DATA) values (?, ?)');
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update remote pass-through\n";

explain ('delete from R1..PUPD_TEST where ID = ?');
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete remote pass-through\n";

test_vdb_pars1 (1);
select * from R1..PUPD_TEST;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through insert with ? params\n";


test_vdb_pars1 (2);
select * from R1..PUPD_TEST;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass-through insert with proc variable params\n";



create procedure leq (in a any, in b any)
{
  return (case when a = b then 1 else 0 end);
}

select count (*) from r1..t1 a left join r1..t1 b on a.row_no = b.row_no;

select count (*) from r1..t1 a left join r1..t1 b on a.row_no = b.row_no and leq (1 + a.row_no, b.row_no);
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "***FAILED";
ECHO BOTH ": left oj with proc false cond.\n";


select count (*) from r1..t1 a left join r1..t1 b on a.row_no = b.row_no and a.row_no + 1 = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "***FAILED";
ECHO BOTH ": left oj with pass through  false cond.\n";

select count (2) from r1..t1 a left join (select row_no, count (*) as ct  from r1..t1 group by row_no) b on a.row_no = b.row_no and a.row_no + 1 = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "***FAILED";
ECHO BOTH ": left oj with dt with pass through  false cond.\n";


select count (*) from r1..t1 a  join (select row_no, count (*) as ct  from r1..t1 group by row_no) b on 1 + a.row_no = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 999  "PASSED" "***FAILED";
ECHO BOTH ": qual inner join  with dt with pass through  true cond.\n";

select count (*) from r1..t1 a, (select row_no, count (*) as ct  from r1..t1 group by row_no) b where 1 + a.row_no = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 999  "PASSED" "***FAILED";
ECHO BOTH ": join  with dt with pass through  true cond.\n";


select count (2) from t1 a left join (select row_no, count (*) as ct  from r1..t1 group by row_no) b on a.row_no = b.row_no and a.row_no + 1 = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 1000  "PASSED" "***FAILED";
ECHO BOTH ": MIX left oj with dt with pass through  false cond.\n";


select count (*) from t1 a  join (select row_no, count (*) as ct  from r1..t1 group by row_no) b on 1 + a.row_no = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 999  "PASSED" "***FAILED";
ECHO BOTH ": MIX qual inner join  with dt with pass through  true cond.\n";

select count (*) from r1..t1 a, (select row_no, count (*) as ct  from t1 group by row_no) b where 1 + a.row_no = b.row_no;
ECHO BOTH $IF $EQU $LAST[1] 999  "PASSED" "***FAILED";
ECHO BOTH ": join  with dt with pass through  true cond.\n";


select sum (fi2), string1 from r1..t1 a group by string1 having sum (fi2) > (select min (s) from (select sum (fi2) as s, string1  from t1 b group by b.string1) c);
ECHO BOTH $IF $EQU $ROWCNT 100  "PASSED" "***FAILED";
ECHO BOTH ": MIX grou with having with group \n";


select sum (fi2), string1 from r1..t1 a group by string1 having sum (fi2) > (select min (s) from (select sum (fi2) as s, string1  from r1..t1 b group by b.string1) c);
ECHO BOTH $IF $EQU $ROWCNT 100  "PASSED" "***FAILED";
ECHO BOTH ": grou with having with group \n";



select sum (fi2), string1 from r1..t1 a group by string1 having sum (fi2) >= (select min (s) from (select sum (fi2) as s, string1  from t1 b group by b.string1) c);
ECHO BOTH $IF $EQU $ROWCNT 300  "PASSED" "***FAILED";
ECHO BOTH ": group with sum >= min of same sum grouped \n";



select count (*) from t1 a, t1 b where a.row_no = b.row_no and a.row_no < 111 and b.row_no < 109;
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH ": t1 inner t1 b.row_no < 109 \n";


select count (*) from t1 a join t1 b on a.row_no = b.row_no where b.row_no < 111;
ECHO BOTH $IF $EQU $LAST[1]  11 "PASSED" "***FAILED";
ECHO BOTH ": t1 inner t1 b.row_no < 111 \n";


create view t1_g as select a.row_no as r1, b.row_no as r2, sum (a.row_no) as sm from t1 a join t1 b on a.row_no = b.row_no group by a.row_no, b.row_no;
create view r1..t1_g as select a.row_no as r1, b.row_no as r2, sum (a.row_no) as sm from r1..t1 a join r1..t1 b on a.row_no = b.row_no group by a.row_no, b.row_no;

select row_no, r1, sm from t1 join t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": t1 x t1_g \n";

select row_no, r1, sm from t1 join r1..t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": t1 x t1_g \n";


select row_no, r1, sm from r1..t1 join r1..t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": r1..t1 x r1..t1_g \n";

select row_no, r1, sm from r1..t1 join t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": r1..t1 x t1_g \n";



select row_no, r1, sm from r1..t1,  r1..t1_g  where r1 = row_no and r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": r1..t1 x t1_g \n";


select row_no, r1, sm from t1 left join t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": t1 left x t1_g \n";

select row_no, r1, sm from t1 left join r1..t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": t1 left x t1_g \n";


select row_no, r1, sm from r1..t1 left join r1..t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": r1..t1 left x r1..t1_g \n";

select row_no, r1, sm from r1..t1 left join t1_g  on r1 = row_no where r2 < 111;
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH  ": r1..t1 left x t1_g \n";





-----
select * from (select 't1' as xx , row_no from r1..t1 where row_no < 105 union all select 't2' as xx, row_no  from t1 where row_no < 105) ff;
select * from (select 't1' as xx , row_no from r1..t1 where row_no < 105 union all select 't2' as xx, row_no  from t1 where row_no < 105) ff where xx = 't1';
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": union filter on term const\n";

select * from (select 't1' as xx , row_no from r1..t1 where row_no < 105 union all select 't2' as xx, row_no  from t1 where row_no < 105) ff where xx = 'xx';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": union filter on term const\n";



select r, ct from (select count (n_nationkey) as ct, n_regionkey as r from nation group by n_regionkey) f where ct = (select max (mct) from (select count (n_name) as mct, n_regionkey from nation group by n_regionkey) f);

-- test suite for bug #1500
create procedure g (in g any) { return g; };

create procedure g1 (in g any) { return g; };

explain ('
    SELECT
      O1.Total
    FROM
      R1..T1 O
      inner join
        (SELECT
	  (O.ROW_NO + 0) as ROW_NO,
	  sum(g1(O.FI3)) as Total
	 FROM
	     R1..T1 O
	 WHERE O.ROW_NO < 110
	 GROUP BY O.ROW_NO + 0) O1
        on (O.ROW_NO = O1.ROW_NO)
    where O.ROW_NO < 110 and O1.ROW_NO < 110');

explain ('
    SELECT
      O1.Total
    FROM
      R1..T1 O
      inner join
        (SELECT
	  g (O.ROW_NO) as ROW_NO,
	  sum(g1(O.FI3)) as Total
	 FROM
	     R1..T1 O
	 WHERE O.ROW_NO < 110
	 GROUP BY g (O.ROW_NO)) O1
        on (O.ROW_NO = O1.ROW_NO)
	where O.ROW_NO < 110');

SELECT
  O1.Total
FROM
  R1..T1 O
  inner join
    (SELECT
      (O.ROW_NO + 0) as ROW_NO,
      sum(g1(O.FI3)) as Total
     FROM
         R1..T1 O
     WHERE O.ROW_NO < 110
     GROUP BY O.ROW_NO + 0) O1
    on (O.ROW_NO = O1.ROW_NO)
where O.ROW_NO < 110 and O1.ROW_NO < 110;
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1500 : correct remote stmts with a join test\n";


SELECT
  O1.Total
FROM
  R1..T1 O
  inner join
    (SELECT
      cast (g (O.ROW_NO) as int) as ROW_NO,
      sum(g1(O.FI3)) as Total
     FROM
         R1..T1 O
     WHERE O.ROW_NO < 110
     GROUP BY g (O.ROW_NO)) O1
    on (O.ROW_NO = O1.ROW_NO)
where O.ROW_NO < 110;
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1500 : correct remote stmts with a vdb join test\n";

-- testcase for bug #3082
drop view B3082V;
create view B3082V as select ROW_NO, -551196 as FakeColumn from R1..T1;

explain ('select 1 from B3082V where FakeColumn not in (select ROW_NO from T1)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3082 : local exists/in subq invariant predicate in pass-trough DT\n";

explain ('select 1 from B3082V where FakeColumn = (select TOP 1 ROW_NO from T1)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3082-2 : local scalar subq invariant predicate in pass-trough DT\n";

explain ('select 1 from B3082V where FakeColumn = F((select TOP 1 ROW_NO from T1))');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 3082-3 : local function in invariant predicate in pass-trough DT\n";

explain ('create procedure xx () { declare cr cursor for select count (*) from R1..T1; open cr; }');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VDB select count (*) in a cursor STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



create view t1order as select row_no, string1, string2 from r1..t1 order by row_no;

select top 2 * from t1order where row_no is null or row_no > 111;

ECHO BOTH $IF $EQU $LAST[1] 113 "PASSED" "***FAILED";
ECHO BOTH ": or of known false in dt predf import\n";

-- *** the 2 below do not work.  Bad locus after import of preds into the dt.
select top 2 * from t1order a where row_no is null or exists (select 1 from t1order b where a.row_no = 1 + b.row_no);
select top 2 * from t1order a where  exists (select 1 from t1order b where a.row_no = 1 + b.row_no);

-- testcase bug #7866
select X1.FI3 from R1..T1 X1 where X1.ROW_NO in (select distinct X2.ROW_NO from R1..T1 X2);
ECHO BOTH $IF $EQU $ROWCNT 1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 7866 : VDB IN pred with a distinct\n";

explain ('SELECT 1 as x3
  FROM
  (
    SELECT
      12 as C
    FROM
      R1..T1
    UNION ALL
    SELECT
      12
    FROM
      R1..T1
  ) x2
 WHERE (C = 12)
    ');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug importing identical preds into different locuses\n";

select XMLELEMENT('Info', XMLFOREST (ROW_NO as "No", STRING1 as "Name")) from R1..T1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B8669-1: pass-through of SQLX statements\n";

select XMLELEMENT('Info', XMLATTRIBUTES (ROW_NO as "No", STRING1 as "Name")) from R1..T1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B8669-2: pass-through of SQLX statements\n";

select XMLELEMENT('Info', XMLAGG (XMLELEMENT ('x'))) from R1..T1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B8669-3: pass-through of SQLX statements\n";


-- hash fillers nested 
select count (*) from t1 a, r1..t1 b where a.row_no = b.row_no and exists (select * from r1..t1 c table option (hash) where c.row_no = b.row_no and c.string1 like '1%') option (order, hash);
ECHO BOTH $IF $EQU $LAST[1] 433 "PASSED" "***FAILED";
ECHO BOTH ": vdb hash join with filter with hash filler with hashed exists\n";

select count (*) from t1 a, r1..t1 b where a.row_no = b.row_no and exists (select * from r1..t1 c table option (loop) where c.row_no = b.row_no and c.string1 like '1%') option (order, loop, loop exists);
ECHO BOTH $IF $EQU $LAST[1] 433 "PASSED" "***FAILED";
ECHO BOTH ": ibid verify with loop\n";

select count (*) from t1 a, r1..t1 b where a.row_no = b.row_no and exists (select * from r1..t1 c table option (loop) where c.row_no = b.row_no and c.string1 like '1%') option (order, loop, do not loop exists);
ECHO BOTH $IF $EQU $LAST[1] 433 "PASSED" "***FAILED";
ECHO BOTH ": ibid verify with loop\n";



select top 101 a.row_no , (select b.row_no from r1..t1 b where  b.row_no between case when 0 = mod (a.row_no, 5) then cast (a.row_no - 1 as varchar) else a.row_no - 1 end  and a.row_no + 1) from t1 a order by 1;
--ECHO BOTH $IF $EQU $LAST[2] 199 "PASSED" "***FAILED";
--ECHO BOTH ": vdb array params with changing types\n";

select fi2, ct from (select fi2, count (*) as ct from r1..t1 group by fi2) xx where ct = (select max (ct2) from (select fi2, count (*) as ct2 from r1..t1 group by fi2) qq);
ECHO BOTH $IF $EQU $LAST[2] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count gb where count  is max count gb\n";

select fi2, ct from (select fi2, count (*) as ct from r1..t1 group by fi2) xx where ct = f ((select max (ct2) from (select fi2, count (*) as ct2 from r1..t1 group by fi2) qq));
ECHO BOTH $IF $EQU $LAST[2] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count gb where count  is max count gb break with f\n";



--
-- End of test
--
ECHO BOTH "COMPLETED: SQLO Remote test (sqlovdb.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
