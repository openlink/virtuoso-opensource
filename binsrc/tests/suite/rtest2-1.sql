--
--  rtest2-1.sql
--
--  $Id$
--
--  Remote database testing
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Remote test 2 (rtest2.sql)\n";

select * from R1..T1 where ROW_NO < 130;
ECHO BOTH $IF $EQU $ROWCNT 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from remote " $ROWCNT " rows\n";

insert into R1..T1 (ROW_NO) values (1);
select ROW_NO from R1..T1 where ROW_NO = 1;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select row_no = 1 from remote " $ROWCNT " rows\n";

update R1..T1 set FS1 = 'r99' where ROW_NO = 1;
select FS1 from R1..T1 where ROW_NO = 1;
ECHO BOTH $IF $EQU $LAST[1] r99  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update fs1 = " $LAST[1] " \n";

delete from R1..T1 where ROW_NO = 1;
select FS1 from R1..T1 where ROW_NO = 1;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": after delete " $ROWCNT " rows with row no 1.\n";

create procedure n_identity (in q integer) { return q; };

select max (ROW_NO) from R1..T1 where ROW_NO < 130;
ECHO BOTH $IF $EQU $LAST[1] 129 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Max under 130 = " $LAST[1] "\n";

select count (*) from R1..T1 where ROW_NO < 130;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count under 130 = " $LAST[1] "\n";

-- access modes, autocommit
set ro;
select count (*) from R1..T1 where ROW_NO < 130;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count under 130 = " $LAST[1] "\n";

set autocommit on;
select count (*) from R1..T1 where ROW_NO < 130;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count under 130 = " $LAST[1] "\n";

set autocommit off;
set rw;

select count (*) from R1..T1 where ROW_NO < 130 and n_identity (ROW_NO) = ROW_NO;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count under 130 where proc = " $LAST[1] "\n";

select R.* from R1..T1 L, R1..T1 R where L.ROW_NO < 130 and R.ROW_NO = L.ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from remote join " $ROWCNT " rows\n";

select R.* from R1..T1 L, R1..T1 R where n_identity (L.ROW_NO) < 130 and R.ROW_NO = L.ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from remote join w/ local proc " $ROWCNT " rows\n";


-------------- Distributed statements

update R1..T1 set FI2 = FI2 + 1 where n_identity (ROW_NO) < 200;
ECHO BOTH $IF $EQU $ROWCNT 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updated remote rows w local proc " $ROWCNT " rows\n";

insert into R1..T1 (ROW_NO, STRING1, STRING2, FS1, FI2) select ROW_NO, STRING1, STRING2, FS1, FI2 from DB..T1 where ROW_NO BETWEEN 3000 AND 3030;
ECHO BOTH $IF $EQU $ROWCNT 31 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert remote, select local " $ROWCNT " rows\n";

insert into R1..T1 (ROW_NO, STRING1, STRING2, FS1, FI2) select ROW_NO, STRING1, STRING2, FS1, FI2 from DB..T1 L where ROW_NO between 3000 and 3300 and not exists (select 1 from R1..T1 C where C.ROW_NO = L.ROW_NO);
ECHO BOTH $IF $EQU $ROWCNT 270 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert remote, select local not exists remote " $ROWCNT " rows\n";

delete from R1..T1 where ROW_NO > 2999 and n_identity (FI2) > 0;
ECHO BOTH $IF $EQU $ROWCNT 301 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete remote, local proc " $ROWCNT " rows\n";

select count (*) from R1..T1 O  where not exists (select 1 from R1..T1 S where S.ROW_NO = O.ROW_NO);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass through subquery\n";

--- ******
select count (*) from R1..T1 O  where not exists (select 1 from R1..T1 S where S.ROW_NO = O.ROW_NO) and ROW_NO = n_identity (ROW_NO);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rts subquery predicate\n";

select count (*) from R1..T1 O  where not exists (select 1 from R1..T1 S where S.ROW_NO = O.ROW_NO and S.ROW_NO = n_identity (O.ROW_NO));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rts with subq with local proc\n";

insert into DB..T1 (ROW_NO, STRING1, STRING2, FS1, FI2) select ROW_NO, STRING1, STRING2, FS1, FI2 from R1..T1 R where  not exists (select 1 from DB..T1 L where R.ROW_NO = L.ROW_NO);
ECHO BOTH $IF $EQU $ROWCNT 1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert local select remote not exists local " $ROWCNT " rows.\n";

insert into DB..T1 (ROW_NO, STRING1, STRING2, FS1, FI2) select ROW_NO, STRING1, STRING2, FS1, FI2 from R1..T1 R where  not exists (select 1 from DB..T1 L where R.ROW_NO = L.ROW_NO);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert local select remote not exists local " $ROWCNT " rows.\n";

delete from DB..T1 where ROW_NO < 3000;

select ROW_NO, STRING1 FROM R1..T1 where ROW_NO < 200 order by STRING1 desc;
ECHO BOTH $IF $EQU $ROWCNT 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pass through order by " $ROWCNT " rows.\n";

select ROW_NO, STRING1 from R1..T1 where ROW_NO < 200 and n_identity (ROW_NO) = ROW_NO order by STRING1 desc;
ECHO BOTH $IF $EQU $ROWCNT 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote table order by " $ROWCNT " rows.\n";

select ROW_NO, STRING1 from R1..T1 where ROW_NO < 200 and n_identity (ROW_NO) = ROW_NO order by 2 desc;
ECHO BOTH $IF $EQU $ROWCNT 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote table sorted order by " $ROWCNT " rows.\n";

select A.ROW_NO, B.ROW_NO from R1..T1 A left outer join R1..T1 B on  B.ROW_NO between A.ROW_NO + 10 and A.ROW_NO + 12   where A.ROW_NO > 1080 and A.ROW_NO < 1095;
ECHO BOTH $IF $EQU $ROWCNT 29 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": remote outer join " $ROWCNT " rows.\n";


create procedure incfi2 (in n1 integer, in n2 integer)
{
  declare f, i integer;
  declare cr cursor for select FS1, FI2 from R1..T1 where ROW_NO between n1 and n2;
  whenever not found goto done;
  open cr;
  while (1) {
    fetch cr into f, i;
    update R1..T1 set FI2 = i + 1 where current of cr;
  }
 done: return;
};

create procedure delt1 (in n1 integer, in n2 integer)
{
  declare f, i integer;
  declare cr cursor for select FS1, FI2 from R1..T1 where ROW_NO between n1 and n2;
  whenever not found goto done;
  open cr;
  while (1) {
    fetch cr into f, i;
    delete from R1..T1 where current of cr;
  }
 done: return;
};

incfi2 (100, 120);


insert into R1..T1 (ROW_NO, STRING1, STRING2, FS1, FI2) select ROW_NO, STRING1, STRING2, FS1, FI2 from DB..T1 L where ROW_NO between 3000 and 3299;
ECHO BOTH $IF $EQU $ROWCNT 300 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert remote, select local not exists remote " $ROWCNT " rows\n";

delt1 (3000, 3300);
select count (*) from R1..T1 where ROW_NO between 3000 and 3300;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " rows delete OK by current of in proc\n";

create view T1_UN as select * from DB..T1 union select * from R1..T1;
select count (*) from T1_UN;
ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " rows in local / remote union\n";

select count (*) from R1..T1 a natural join R1..T1 b;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " rows in remote x remote natural join\n";


select (select count (*) from R1..T1 where ROW_NO < 110) from R1..T1 where ROW_NO < 110;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count of remote scalar subq #1.\n";

select (select count (*) from R1..T1 where ROW_NO < n_identity (110)) from R1..T1 where ROW_NO < 110;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count of remote scalar subq #2.\n";

create view TU as select ROW_NO, FI2 from T1 union all select ROW_NO, FI2 from R1..T1;

select count (*) from TU A where ROW_NO < 300 and exists (select 1 from TU B where A.ROW_NO = B.ROW_NO);
ECHO BOTH $IF $EQU $LAST[1] 200 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " from union view as an existence predicate\n";




select ROW_NO, T1_UN.ROW_NO, DBA.T1_UN.ROW_NO, DB.DBA.T1_UN.ROW_NO  from T1_UN where ROW_NO = 111;
ECHO BOTH $IF $EQU $LAST[1] 111 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " from funny correlated ref to union view col\n";

create view T1_FR3 as
       select ROW_NO, STRING1, STRING2, FI2  from R1..T1 where ROW_NO < 120
       union all select ROW_NO, STRING1, STRING2, FI2 from T1 where ROW_NO >= 3100 and ROW_NO <= 3120
       union all select ROW_NO, STRING1, STRING2, FI2 from R1..T1 where ROW_NO > 1079;


select ROW_NO from T1_FR3 where ROW_NO < 1200;
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT  " rows  in t1_fr3 < 1200\n";

select count (*) from T1_FR3;
ECHO BOTH $IF $EQU$LAST[1] 61 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count of t1_fr3\n";

select max (ROW_NO) as xx from T1_FR3 where ROW_NO < 1200;
ECHO BOTH $IF $EQU $LAST[1] 1099 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " max row_no  of t1_fr3 where row_no < 1200 \n";

select FI2, max (ROW_NO) from T1_FR3 group by FI2 order by FI2 desc;
ECHO BOTH $IF $EQU$LAST[1] 1111 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "  fi2 from t1_fr3 gb, ob fi2 desc\n";


select FI2, max (ROW_NO) as xx from T1_FR3 group by FI2 having xx > 3000 order by FI2 desc;
ECHO BOTH $IF $EQU$LAST[1] 1111 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "  fi2 from t1_fr3 gb,having max > 3000  ob fi2 desc\n";



--
-- End of test
--
ECHO BOTH "COMPLETED: Remote test 2 (rtest2.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
