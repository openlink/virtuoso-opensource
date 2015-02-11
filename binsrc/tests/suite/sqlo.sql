--
--  sqlo.sql
--
--  $Id: sqlo.sql,v 1.35.6.9.4.5 2013/01/02 16:14:57 source Exp $
--
--  Various SQL optimized compiler tests.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

-- uses result of ins 1111 1000 20
echo BOTH "\nSTARTED: SQL Optimizer tests (sqlo.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop view T1_V;
drop index FI3 T1;
update T1 set FI3 = ROW_NO;
create unique index FI3 on T1 (FI3) partition (Fi3 int);


select KEY_TABLE from SYS_KEYS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": simple select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select zdravko (*) from SYS_USERS;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": simple wrong select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select 1 + 2 as CNST, KEY_ID, KEY_ID + 1 as exp from SYS_KEYS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": simple select with const columns & expressions STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select KEY_NAME from SYS_KEYS where KEY_TABLE > 'WS';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": simple select with varchar > constant WHERE clause STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select KEY_NAME, \COLUMN  from SYS_COLS, SYS_KEYS, SYS_KEY_PARTS where KEY_TABLE > 'WS' and KEY_ID = KP_KEY_ID and COL_ID = KP_COL;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FROM with multiple tables with composite WHERE clause STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 + 2 as cnst, a.ROW_NO from T1 a where ROW_NO between 20 and 40;
ECHO BOTH $IF $EQU $ROWCNT 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FROM with multiple tables with WHERE between returned " $ROWCNT " rows\n";


select STRING1, sum (1) from T1 group by STRING1;
ECHO BOTH $IF $EQU $ROWCNT 300 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STRING1, sum(1) group by STRING1 returned " $ROWCNT " rows\n";

select STRING1, sum (1) from t1 group by string1 having sum (1 + 0) = 3 and row_no < 100;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column in having compiled as being in where returned " $ROWCNT " rows\n";
-- this is equivalent to row_no < 100 being in the where with returns no rows in SQL server
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": column in having not mentioned in aggregate or group by STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select STRING1, sum (1), sum (ROW_NO) / sum (1) from T1 group by STRING1 having sum (1 + 0) = 3;
ECHO BOTH $IF $EQU $ROWCNT 200 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": sum(1) group by STRING1 having sum (1 + 0) = 3 returned " $ROWCNT " rows\n";


set maxrows 10;
select STRING1, FI2 from T1 order by STRING1 desc;
ECHO BOTH $IF $EQU $LAST[1] 97 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": order by STRING1 desc last row STRING1=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1111 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": order by STRING1 desc last row FI2=" $LAST[2] "\n";

select STRING1, FI2 from T1 where ROW_NO = 111 order by STRING1 desc;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": where ROW_NO = 111 order by STRING1 desc returned " $ROWCNT " rows\n";

select STRING1, FI2 from T1 where FI3 = 111 order by STRING1 desc;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": where FI3 = 111 order by STRING1 desc returned " $ROWCNT " rows\n";



select STRING1, FI2 from T1 where ROW_NO between 100 and 110  order by STRING1 desc;
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": where ROW_NO between 100 and 110  order by STRING1 desc last row STRING1=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1111 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": where ROW_NO between 100 and 110  order by STRING1 desc last row FI2=" $LAST[2] "\n";

select STRING1, FI2 from T1 where FI3 between 100 and 110  order by STRING1 desc;
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": where FI3 between 100 and 110  order by STRING1 desc last row STRING1=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1111 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": where FI3 between 100 and 110  order by STRING1 desc last row FI2=" $LAST[2] "\n";

select STRING1, FI2 from T1 where FI3 between 2000 and 2010  order by STRING1 desc;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": not exists and partitioned sort\n";

select top 2 FS1 from T1 order by 1 - ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top 2 FS1 order by 1 - ROW_NO returned " $ROWCNT " rows\n";

select top 2 with ties FS1 from T1;
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--- ECHO BOTH ": top 2 with ties FS1 no order by STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- Because the SQL Server returns an error here. Commented out are the tests that would check it if allowed.
-- that of course doesnt mean that we don't support that (for now).
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top 2 with ties FS1 no order by returned " $ROWCNT " rows\n";

select top 3 ROW_NO from T1 order by concat ('-', STRING1);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top 3 ROW_NO order by concat ('-', STRING1) returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 900 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top top 3 ROW_NO order by concat ('-', STRING1) last row ROW_NO=" $LAST[1] "\n";

select * from (select ROW_NO, ROW_NO + 1 as ff from T1 where ROW_NO < 30) f order by 1;
ECHO BOTH $IF $EQU $LAST[1] 29 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from subquery with where last row ROW_NO=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from subquery with where last row ff=" $LAST[2] "\n";

select ff from (select * from (select ROW_NO, ROW_NO + 1 as ff from T1 where ROW_NO < 30) f) qq order by ff;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from subquery select from a subquery with where last row ff=" $LAST[1] "\n";

set maxrows 0;

explain ('select * from (select ROW_NO, ROW_NO + 1 as x  from T1  union select ROW_NO, ROW_NO + 2 from T1) un where un.ROW_NO < 30');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": explain select from union subq with where clause in the topmost select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select * from (select ROW_NO, ROW_NO + 1 as x, 1 as setno  from T1  union select ROW_NO, ROW_NO + 2, 2 as setno  from t1) un where un.ROW_NO < 30 order by setno, 2;
ECHO BOTH $IF $EQU $LAST[1] 29 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from union subq with where clause in the topmost select last row ROW_NO=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 31 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from union subq with where clause in the topmost select last row x=" $LAST[2] "\n";

select x from (select ROW_NO, ROW_NO + 1 as x  from T1  union select ROW_NO, ROW_NO + 2 from t1) un where un.ROW_NO < 30 order by 1;
ECHO BOTH $IF $EQU $LAST[1] 31 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from union subq with where clause in the topmost select last row x=" $LAST[1] "\n";


-- XXX
--select x from (select ROW_NO, ROW_NO + 1 as x  from T1  union corresponding by (x) select ROW_NO, ROW_NO + 2 from T1) un where un.ROW_NO < 30 order by x;
--ECHO BOTH $IF $EQU $LAST[1] 31 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": select * from union corresponding by (x) subq with where clause in the topmost select last row x=" $LAST[1] "\n";

select x from (select ROW_NO, ROW_NO + 1 as x  from T1  union corresponding by (x) select ROW_NO, ROW_NO + 2 from T1 union corresponding by (x) select ROW_NO, ROW_NO + 3 from T1) un where un.ROW_NO < 30 order by x;

select x from (select ROW_NO, ROW_NO + 1 as x  from T1  union all  select ROW_NO, ROW_NO + 2 from T1) un where un.ROW_NO < 30 order by x;
ECHO BOTH $IF $EQU $LAST[1] 31 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from union all subq with where clause in the topmost select last row x=" $LAST[1] "\n";

select sum (ROW_NO) / count (*) from T1;
ECHO BOTH $IF $EQU $LAST[1] 519 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select sum (ROW_NO) / count (*) returned " $LAST[1] "\n";

set maxrows 10;

select count (*) from T1 where ROW_NO > (select avg (ROW_NO) from T1);
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select count (*) where ROW_NO > (select avg (ROW_NO) from T1) returned " $LAST[1] "\n";

select count (*), max (FS4) from T1 where FI2 = 22;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count (*) of non-existant row returned " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max (FS4) of non-existant row returned " $LAST[2] "\n";

select STRING1, (select sum (ROW_NO) from T1 a where a.STRING1 = f.STRING1) from (select distinct STRING1 from T1) f order by 1;
ECHO BOTH $IF $EQU $LAST[1] 106 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STRING1 from (select distinct STRING1 from T1) order by string1 returned " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 2224 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": scalar subq from (select distinct STRING1 from T1) returned " $LAST[2] "\n";

select count (*) from T1 b where exists (select 1 from T1 a where a.ROW_NO = 1 + b.ROW_NO);
ECHO BOTH $IF $EQU $LAST[1] 999 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count where exists returned " $LAST[1] "\n";

select count (*) from T1 b where not exists (select 1 from T1 a where a.ROW_NO = 1 + b.ROW_NO);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count where not exists returned " $LAST[1] "\n";

select count (*) from T1 b where ROW_NO = (select 1 + a.ROW_NO from T1 a where a.ROW_NO = 1 + b.ROW_NO) - 1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count where ROW_NO = subq - 1 returned " $LAST[1] "\n";

select count (*) from T1 b where b.ROW_NO = (select  a.ROW_NO + 1 from T1 a where a.ROW_NO = b.ROW_NO + 1) - 2;
ECHO BOTH $IF $EQU $LAST[1] 999 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count where ROW_NO = subq - 2 returned " $LAST[1] "\n";

select count (*) from T1 b where b.ROW_NO = (select  a.ROW_NO + 1 from T1 a table option (loop) where a.ROW_NO = b.ROW_NO + 1) - 2;
ECHO BOTH $IF $EQU $LAST[1] 999 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count where ROW_NO = subq - 2 loop join returned " $LAST[1] "\n";


select count (*) from t1 where ROW_NO < 100 or ROW_NO > 999;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count where ROW_NO < 100 or ROW_NO > 999 returned " $LAST[1] "\n";

select count (case when 0 = mod (ROW_NO, 2) then null else 1 end) from T1;
ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count (case when 0 = mod (ROW_NO, 2) then null else 1 end)  returned " $LAST[1] "\n";
set maxrows 0;
set explain on;
select a.ROW_NO, b.ROW_NO from T1 a left join T1 b on b.ROW_NO = a.ROW_NO + 5 where a.ROW_NO > 1000;
set explain off;

select a.ROW_NO, b.ROW_NO from T1 a left join T1 b on b.ROW_NO = a.ROW_NO + 5 where a.ROW_NO > 1000 option (hash);
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": oj unique hash selecting hash key\n";

set maxrows 10;

select a.ROW_NO, b.ROW_NO from T1 a left join T1 b on b.ROW_NO = a.ROW_NO + 5 where a.ROW_NO > 1000;
ECHO BOTH $IF $EQU $LAST[1] 1010 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select a.ROW_NO from left join on b.ROW_NO = a.ROW_NO + 5 with where a.ROW_NO > 1000 returned " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1015 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select b.ROW_NO from left join on b.ROW_NO = a.ROW_NO + 5 with where a.ROW_NO > 1000 returned " $LAST[2] "\n";
select a.ROW_NO, b.ROW_NO from T1 a left join (select * from T1) b on b.ROW_NO = a.ROW_NO + 5 where a.ROW_NO > 1000;
ECHO BOTH $IF $EQU $LAST[1] 1010 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select a.ROW_NO from left join subq on b.ROW_NO = a.ROW_NO + 5 with where a.ROW_NO > 1000 returned " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1015 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select b.ROW_NO from left join subq on b.ROW_NO = a.ROW_NO + 5 with where a.ROW_NO > 1000 returned " $LAST[2] "\n";

create view T1_V as select * from T1 where ROW_NO < 100;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create view as select with where < STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- aggregate subqueries expansion (ALL PRED)
select row_no from t1 where row_no < all (select row_no from t1 where row_no > 22);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALL subq made into exists returned " $ROWCNT " rows\n";

select row_no from t1 where row_no < all (select min (row_no) from t1 where row_no > 22);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALL subq/aggregates made into exists returned " $ROWCNT " rows\n";

select row_no from t1 where atoi (STRING1) < all (select atoi (STRING1) from t1 where row_no > 22 and row_no < 50 group by STRING1) and row_no < 101;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ALL subq/group by made into exists returned " $ROWCNT " rows\n";

-- XXX
select row_no from t1 where row_no < all (select min (row_no) from t1 where row_no > 22 and row_no < 100 group by STRING1);
--ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": ALL subq/aggregates/group by made into exists returned " $ROWCNT " rows\n";


-- aggregate subqueries expansion (ANY PRED)
select row_no from t1 where row_no < any (select row_no from t1 where row_no < 24);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ANY subq made into exists returned " $ROWCNT " rows\n";

select row_no from t1 where row_no < any (select max (row_no) from t1 where row_no < 24);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ANY subq/aggregates made into exists returned " $ROWCNT " rows\n";

select row_no from t1 where atoi (string1) < any (select atoi (string1) from t1 where row_no < 24 group by string1) and row_no < 100;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ANY subq/group by made into exists returned " $ROWCNT " rows\n";

select row_no from t1 where row_no < any (select max (row_no) from t1 where row_no < 24 group by string1);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ANY subq/aggregates/group by made into exists returned " $ROWCNT " rows\n";

-- The derived table expansion suite

select * from (select row_no as a from T1 where row_no < 25) a where a > 20;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Expanding a nested where only DT returned " $ROWCNT "rows\n";

select * from (select row_no as a from (select row_no from T1 where row_no > 20) b where row_no < 25) a where a > 20;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Expanding a nested where only DT in two levels returned " $ROWCNT "rows\n";

select * from (select sum (row_no) as a from T1 where row_no < 25) a where a > 20;
ECHO BOTH $IF $EQU $LAST[1] 110 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Expanding a nested sum where only DT in the having clause = " $LAST[1] "\n";

select * from (select row_no as a from (select a.row_no from T1 a join T1 b on a.row_no = b.row_no where b.row_no > 20) b where row_no < 25) a where a > 20;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Expanding a nested where only DT with join returned " $ROWCNT "rows\n";

set maxrows 0;
select a.ROW_NO, b.ROW_NO from T1 a join T1 b on b.ROW_NO between a.ROW_NO - 1 and a.ROW_NO + 1 where a.ROW_NO < 40 order by a.ROW_NO desc;
ECHO BOTH $IF $EQU $ROWCNT 59 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": selecting a table order by preferred over a sorted order by on a join returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": selecting a table order by preferred over a sorted order by on a join a.ROW_NO=" $LAST[1] "\n";

select a.ROW_NO, b.ROW_NO from T1 b join T1 a on b.ROW_NO between a.ROW_NO - 1 and a.ROW_NO + 1 where a.ROW_NO < 40 order by a.ROW_NO desc;
ECHO BOTH $IF $EQU $ROWCNT 59 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": after join generation for table sources returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": after join generation for table sources returned a.ROW_NO=" $LAST[1] "\n";

select a.ROW_NO, b.ROW_NO from T1 a join T1 b on b.ROW_NO between a.ROW_NO - 1 and a.ROW_NO + 1 where a.ROW_NO < 40 order by a.FI3 desc;
ECHO BOTH $IF $EQU $ROWCNT 59 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": joined select in sorted order by over FI3 desc returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": joined select in sorted order by over FI3 desc returned a.ROW_NO=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": joined select in sorted order by over FI3 desc returned b.ROW_NO=" $LAST[2] "\n";

explain ('
select ROW_NO, 1 from T1 union all select ROW_NO + 1, 1 from T1
', -4);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying a sql optimizer with SQLC_TRY_SQLO (-4) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select STRING1, (select sum (ROW_NO) from T1 a where a.STRING1 = f.STRING1) from (select distinct STRING1 from T1) f;
ECHO BOTH $IF $EQU $ROWCNT 300 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": scalar subq and a dt in select returned " $ROWCNT " rows\n";

select * from (select row_no as a from (select a.row_no from T1 a join T1 b on a.row_no = b.row_no where b.row_no > 20) b where row_no < 25) a where a > 20;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Expanding a nested where only DT with join returned " $ROWCNT "rows\n";

select C.COL_ID, C.COL_CHECK from SYS_COLS C where upper("TABLE") = upper('WS.WS.SYS_DAV_RES') AND upper("COLUMN") = upper('RES_CONTENT') order by "TABLE", "COLUMN", "COL_ID" ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding the oby cols as out cols in indexed order by case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
--select _ROW, ROW_NO from T1;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": select _ROW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table G1;
drop table G2;

create table G1 (ID integer primary key, DATA varchar (50));
create table G2 (ID integer primary key, DATA varchar (50));
insert into G1 (ID, DATA) values (1, 'a');
insert into G2 (ID, DATA) values (2, 'a');

select isnull (b.ID, 0, 1) as b_id from G1 a left join G2 b on a.DATA = b.DATA order by a.DATA;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Determinig the dependansies of a sort node returned " $ROWCNT "rows\n";

explain ('select RES_FULL_PATH from WS..SYS_DAV_RES where RES_COL = 1 and RES_NAME = 2 and contains (RES_FULL_PATH, 3)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Explain of a non-driving text index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- suite for bug #1614 (old compiler)
drop table A1614;
drop table B1614;
create table A1614 (ID integer primary key, DATA varchar (50));
create table B1614 (ID integer primary key, DATA varchar (50));
create index A1614_DATA on A1614(DATA);
create index B1614_DATA on B1614(DATA);

insert into A1614 (ID, DATA) values (1, 'a');
insert into A1614 (ID, DATA) values (2, 'b');

insert into B1614 (ID, DATA) values (1, 'a');

select A1614.ID from A1614 join B1614 on A1614.ID = B1614.ID order by B1614.DATA;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1614: disable tb order switch if JOIN returned " $ROWCNT "rows\n";

select A1614.ID from A1614 join B1614 on A1614.ID = B1614.ID order by B1614.DATA;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1614: new compiler: disable tb order switch if JOIN returned " $ROWCNT "rows\n";

explain ('select distinct a.U_NAME from SYS_USERS a left outer join (select * from SYS_USERS d join SYS_USERS e on d.U_ID = e.U_ID) b  on a.U_ID = b.U_ID');
---ECHO BOTH $IF $EQU $ROWCNT 9 "PASSED" "***FAILED";
---SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
---ECHO BOTH ": Distinct join on a DT discards it's right\n";

explain ('select distinct d.U_ID from SYS_USERS d left outer join SYS_USERS e on d.U_ID = e.U_ID');
---ECHO BOTH $IF $EQU $ROWCNT 9 "PASSED" "***FAILED";
---SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
---ECHO BOTH ": Distinct join on a table discards it's right\n";

use BUG148;
drop table AUTHORS;
drop table TITLEAUTHOR;
drop view AUTHORSV;
drop view TITLEAUTHORV;
drop view AUTHORSTITLESV;

create table AUTHORS (AU_ID int primary key, AU_FNAME varchar, AU_LNAME varchar);
create table TITLEAUTHOR (AU_ID int primary key, TITLE_ID varchar);

create view AUTHORSV as select AU_ID, AU_FNAME, AU_LNAME from AUTHORS;

create view TITLEAUTHORV as select AU_ID, TITLE_ID from TITLEAUTHOR;

create view AUTHORSTITLESV as
select A.AU_ID, A.AU_FNAME, A.AU_LNAME, T.TITLE_ID
from AUTHORSV A left outer join TITLEAUTHORV T on (A.AU_ID = T.AU_ID);

explain ('select distinct AU_ID, AU_FNAME, AU_LNAME from AUTHORSTITLESV');
--ECHO BOTH $IF $EQU $ROWCNT 18 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
---ECHO BOTH ": BUG 148: Distinct join in a view drops it joined table if distinct returned " $ROWCNT "\n";

explain ('select AU_ID, AU_FNAME, AU_LNAME from AUTHORSTITLESV');
--ECHO BOTH $IF $EQU $ROWCNT 30 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG148: join in a view doesn't drop it's joined table returned " $ROWCNT "\n";


-- BUG 1301:
use BUG1301;
drop table TESTSPR3901B;
drop table TESTSPR3901A;

CREATE TABLE TESTSPR3901A (
    COL_ID INTEGER NOT NULL,
    NAME VARCHAR(256) NOT NULL,
    PRIMARY KEY (COL_ID)
);
CREATE TABLE TESTSPR3901B (
    ICOL_ID INTEGER NOT NULL,
    COL_ID INTEGER NOT NULL,
    SEQ_NUM INTEGER NOT NULL,
    PRIMARY KEY (ICOL_ID),
    FOREIGN KEY (COL_ID)
    REFERENCES TESTSPR3901A
);
INSERT INTO TESTSPR3901A (COL_ID, NAME) VALUES (1, 'A');
INSERT INTO TESTSPR3901A (COL_ID, NAME) VALUES (2, 'B');
INSERT INTO TESTSPR3901A (COL_ID, NAME) VALUES (3, 'C');
INSERT INTO TESTSPR3901A (COL_ID, NAME) VALUES (4, 'D');
INSERT INTO TESTSPR3901A (COL_ID, NAME) VALUES (5, 'E');

INSERT INTO TESTSPR3901B (ICOL_ID, COL_ID, SEQ_NUM) VALUES (1, 1, 5);
INSERT INTO TESTSPR3901B (ICOL_ID, COL_ID, SEQ_NUM) VALUES (2, 2, 4);
INSERT INTO TESTSPR3901B (ICOL_ID, COL_ID, SEQ_NUM) VALUES (3, 3, 3);
INSERT INTO TESTSPR3901B (ICOL_ID, COL_ID, SEQ_NUM) VALUES (4, 4, 2);
INSERT INTO TESTSPR3901B (ICOL_ID, COL_ID, SEQ_NUM) VALUES (5, 5, 1);

-- XXX
select count (distinct NAME) from (select NAME from TESTSPR3901A, TESTSPR3901B
	where TESTSPR3901B.COL_ID = TESTSPR3901A.COL_ID
	order by TESTSPR3901B.SEQ_NUM) x;
--ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG1301: order by returns correct resultset\n";

use DB;

-- bug 1286
-- XXX
--explain ('select * from WS..SYS_DAV_RES a, WS..SYS_DAV_RES b where contains (b.RES_CONTENT, ''a'')');
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG1286: contains on a non-driving table\n";



SELECT COUNT ( 1) FROM DBA.T1 t1 , (SELECT t3.ROW_NO AS ROW_NO, COUNT ( 1) AS CT FROM DBA.T1 t3  GROUP BY t3.ROW_NO) dt2  where 1 + t1.ROW_NO = dt2.ROW_NO;
ECHO BOTH $IF $EQU $LAST[1] 999 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 2 same counts in different scopes \n";


select distinct b.row_no from t1 a left join t1 b on b.row_no between a.row_no - 2 and a.row_no + 2;
select distinct a.row_no from t1 a left join t1 b on b.row_no between a.row_no - 2 and a.row_no + 2;
select distinct a.row_no from t1 a right join t1 b on b.row_no between a.row_no - 2 and a.row_no + 2;
select distinct b.row_no from t1 a right join t1 b on b.row_no between a.row_no - 2 and a.row_no + 2;

-- test suite for bug #1453
select distinct concat(name_part("TABLE",1,''), '.', name_part("TABLE", 2, ''))
   as tableName, "COLUMN" as columnName
   from SYS_COLS
    JOIN SYS_KEY_PARTS ON (SYS_COLS.COL_ID=SYS_KEY_PARTS.KP_COL)
    JOIN SYS_KEYS ON (SYS_KEY_PARTS.KP_KEY_ID=SYS_KEYS.KEY_ID)
   where "COLUMN" <> '_IDN'
    and KEY_MIGRATE_TO is null
    and KEY_IS_MAIN = 1
   order by COL_ID;
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1453: indexed OBY not tried with no OBY cols\n";


select distinct concat(name_part("TABLE",1,''), '.', name_part("TABLE", 2, ''))
   as tableName, "COLUMN" as columnName
   from SYS_COLS
    JOIN SYS_KEY_PARTS ON (SYS_COLS.COL_ID=SYS_KEY_PARTS.KP_COL)
    JOIN SYS_KEYS ON (SYS_KEY_PARTS.KP_KEY_ID=SYS_KEYS.KEY_ID)
   where "COLUMN" <> '_IDN'
    and KEY_MIGRATE_TO is null
    and KEY_IS_MAIN = 1
   order by COL_ID, KP_KEY_ID, KP_NTH, KEY_ID;
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1453: OUT cols not deleted with indexed OBY\n";


-- suite for bug #1499
select distinct X1  from (
   select cast ('a' as varchar) as X1 from SYS_KEYS
   union all
   select cast ('b' as varchar) as X1 from SYS_KEYS
    ) y;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1499: union cols not generated as aliases, but copied\n";

drop table B1982;
create table B1982 (ID integer primary key);
insert into B1982 (ID) values (1);
select coalesce (max (ID), 12) from B1982;
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1982: coalesce (max)\n";

-- suite for bug #2000
explain ('select * from DB.DBA.SYS_USERS where U_ID in (select top 1 U_ID from DB.DBA.SYS_USERS)');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2000: TOP in IN subquery STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- suite for bug #2142
drop index IDX_REFENTRY_CATS;
drop table DB.DBA.FUNCTIONS;
drop table DB.DBA.REFENTRY;
CREATE TABLE DB.DBA.REFENTRY (
 ID VARCHAR(50) NOT NULL,
 TITLE VARCHAR(100),
 CATEGORY VARCHAR(50),
 PURPOSE VARCHAR(255),
 DESCRIPTION LONG VARCHAR,
 CONSTRAINT PK_REFENTRY PRIMARY KEY (ID)
 );
CREATE INDEX IDX_REFENTRY_CATS on DB.DBA.REFENTRY(CATEGORY);

CREATE TABLE DB.DBA.FUNCTIONS (
 FUNCTIONNAME VARCHAR(100) NOT NULL,
 REFENTRYID VARCHAR(50) NOT NULL,
 RETURN_TYPE VARCHAR(50),
 RETURN_DESC VARCHAR(255),
 CONSTRAINT PK_FUNCTION PRIMARY KEY (FUNCTIONNAME),
 CONSTRAINT FK_FUNC_REFENTRY FOREIGN KEY (REFENTRYID) REFERENCES DB.DBA.REFENTRY(ID)
 );

insert into DB.DBA.REFENTRY (ID, TITLE, CATEGORY) values ('1', 'AA', 'A');
insert into DB.DBA.REFENTRY (ID, TITLE, CATEGORY) values ('2', 'BB', 'B');

insert into DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID) values ('1AA', '1');
insert into DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID) values ('2AA', '1');
insert into DB.DBA.FUNCTIONS (FUNCTIONNAME, REFENTRYID) values ('1BB', '2');
--the following SELECT SQL doesn't do sorting on CATEGORY field:

SELECT DB.DBA.REFENTRY.CATEGORY, DB.DBA.FUNCTIONS.FUNCTIONNAME
FROM DB.DBA.REFENTRY INNER  JOIN DB.DBA.FUNCTIONS ON DB.DBA.REFENTRY.ID = DB.DBA.FUNCTIONS.REFENTRYID
ORDER BY DB.DBA.REFENTRY.CATEGORY, DB.DBA.FUNCTIONS.FUNCTIONNAME;
ECHO BOTH $IF $NEQ $LAST[1] 'B' "***FAILED" $IF $NEQ $LAST[2] '1BB' "***FAILED" "PASSED";
ECHO BOTH ": bug 2142: no inx oby on non-driving table returned LAST[1]=" $LAST[1] "\n";


  SELECT
    U2.U_NAME,
    U2.U_ID
    FROM DB.DBA.SYS_USERS U2
UNION ALL
  SELECT
    U_NAME as a,
    NULL as a
    FROM DB.DBA.SYS_USERS;
ECHO BOTH $IF $NEQ $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1964: dt wrap of unions STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select distinct * from (
  select distinct
    U_NAME as A,
    null as A
  from DB.DBA.SYS_USERS) X;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1964: dt with equally named cols STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- suite for bug #2178
select
        U_ID + 1,
	U_NAME
from	DB.DBA.SYS_USERS
where
	(1 or U_ID + 1 > 0);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2178: placing an exp allready placed in code_vec returned " $LAST[1] "\n";

-- suite for bug #2176
DROP TABLE B2176;
CREATE TABLE B2176(
 ID            integer PRIMARY KEY,
 XML_DATA            LONG VARCHAR     NULL
);

CREATE TEXT XML INDEX ON B2176(XML_DATA) WITH KEY ID;

INSERT INTO B2176 (ID,XML_DATA) VALUES( 1,'<name>test  1 </name>');
INSERT INTO B2176 (ID,XML_DATA) VALUES( 2,'<name>test  2 </name>');

-- XXX
--SELECT ID, XML_DATA FROM B2176 WHERE xcontains (XML_DATA,sprintf('/name'));
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG2176: placing the xcontains args correctly STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select * from NEWS_MESSAGES', 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2423: keyset and sqlo_expand_dt with 2 tables in the dt STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain('
    select
      case
	when ( u_id = 6 ) then 2
      end ,
      u_id *
        (
	 case
	   when ( u_id = 6 ) then 2
	   when ( u_id = 0 ) then 0
	 end
	)
    from
      DB.DBA.SYS_USERS
');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1804: box_equal not comparing correctly STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select U_ID, U_NAME from DB.DBA.SYS_USERS group by U_ID');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2156: box_equal not comparing correctly STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select U_ID from DB.DBA.SYS_USERS group by U_ID, U_PASSWORD order by U_NAME');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2156: order by superset of group by STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- bug in KWD_PARAM
drop procedure KWD_PARAM_PROC;
create procedure KWD_PARAM_PROC (in x any) { return x; };

select KWD_PARAM_PROC (x=>1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED" ;
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": kwd const param in select list =" $LAST[1] "\n";

select KWD_PARAM_PROC (x=>aref (vector (1, 2), 0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED" ;
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": kwd function param in select list =" $LAST[1] "\n";

select KWD_PARAM_PROC (x=>(select distinct 12 from SYS_KEYS));
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED" ;
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": kwd subq param in select list =" $LAST[1] "\n";

-- suite for bug 3513
drop table B3513_1;
drop table B3513_2;
CREATE TABLE B3513_1 (
	ID        CHAR(1) NOT NULL,
	NAME      VARCHAR(255) NOT NULL,

	PRIMARY KEY (ID));

CREATE TABLE B3513_2 (
	ID        INTEGER NOT NULL,
	FK        CHAR(1) NOT NULL,

	PRIMARY KEY (ID));

INSERT INTO B3513_1 (ID,NAME) VALUES ('A','test 1');
INSERT INTO B3513_1 (ID,NAME) VALUES ('B','test 2');
INSERT INTO B3513_1 (ID,NAME) VALUES ('C','test 3');
INSERT INTO B3513_1 (ID,NAME) VALUES ('D','test 4');

INSERT INTO B3513_2 (ID,FK) VALUES (1,'A');
INSERT INTO B3513_2 (ID,FK) VALUES (2,'B');
INSERT INTO B3513_2 (ID,FK) VALUES (3,'C');

explain ('SELECT NAME FROM B3513_1 WHERE ID IN (SELECT FK FROM B3513_2)', 3);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG23513: making the correct scroll continuations 1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure temp()
{
  declare _cnt varchar;

  declare cr STATIC cursor for SELECT NAME FROM B3513_1 WHERE ID IN (SELECT FK
FROM B3513_2);
--  you can try with other types of cursors like DYNAMIC;

  whenever not found goto done;

  result_names (_cnt);

      open cr;

      while (1){
        declare exit handler for not found goto done;
        fetch cr next into _cnt;
        result(_cnt);
      };

done:

      close cr;
      return;

};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3513_2: making the correct scroll continuations 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- suite for bug #3577
--
drop table B3577;
create table B3577( ID     integer primary key, PARENT integer null);

insert into B3577(ID,PARENT) values(1001,null);

explain ('delete from B3577
 where ID = 1001
   and not exists (select ID from B3577 where PARENT = 1001)', -5);

delete from B3577 where ID = 1001 and not exists (select ID from B3577 where PARENT = 1001);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3577: not qualifying a BOP for a hash cond STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from B3577;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3577-2: " $LAST[1] " rows in B3577\n";

-- suite for bug #3601
drop view B3601_V1;
drop table B3601_T1;
drop table B3601_T2;

create table B3601_T1(
  ID integer primary key
);
create table B3601_T2(
  ID  integer not null,
  VAL integer not null,
  constraint B3601_T2_PK primary key(ID,VAL)
);

create view B3601_V1(ID,VAL) as
  select ID, (case when VAL > 0 then (case when VAL > 10 then 1 else VAL end)
else -1 end) VAL
    from B3601_T2;

-- this statement craches the server
select A.ID  from B3601_T1 A inner join B3601_V1 B on A.ID = B.ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3601: not-placed control exp crashes the generator STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- bug in compiling nested exp dfes from a subq to go to the parent dt dfe
drop Table ZDR..DISCUSSION;
CREATE TABLE ZDR..DISCUSSION (
    ITEM_ID int IDENTITY NOT NULL,
    DISPLAY_ORDER varchar NULL,
    PRIMARY KEY (ITEM_ID)
);
INSERT INTO ZDR..DISCUSSION (DISPLAY_ORDER) VALUES ('2001-12-20 14:10:36.317');

SELECT
   right (DISPLAY_ORDER, 12),
   (SELECT (COUNT(*) -1)
     FROM ZDR..DISCUSSION DISC2
     WHERE
        LEFT(DISC2.DISPLAY_ORDER, length( RTRIM(cast (DISC.DISPLAY_ORDER as varchar)))) =
        DISC.DISPLAY_ORDER
   )
  from ZDR..DISCUSSION DISC;
ECHO BOTH $IF $EQU $LAST[2] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG: not skipping exp dfes when going up placing subq dfe ret=" $LAST[2] "\n";

drop table B3741;
create table B3741(
    ID integer primary key,
    DT datetime not null
  );
insert into B3741(ID,DT) values(1,stringdate('2002.12.1'));
insert into B3741(ID,DT) values(2,stringdate('2002.12.2'));
insert into B3741(ID,DT) values(3,stringdate('2002.12.3'));

select top 1 ID,DT from B3741 order by DT desc;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3471: desc oby w/ TOP ret=" $LAST[1] "\n";


drop table B3815_1;
create table B3815_1 (ID integer primary key, D2 integer);

insert into b3815_1 values (1, 11);
insert into b3815_1 values (2, 101);

select null as IVAL from b3815_1 A union select D2 from B3815_1 B order by IVAL;
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3815 : union col dtp returned LAST[1]=" $LAST[1] "\n";

drop table B3736;
create table B3736 (ID integer primary key, DATA integer);

explain ('select DATA from B3736 group by DATA order by count(DATA)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3736: OBY w/FUN REF not from SELECT list crashes the generator STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--bug #3999
select KEY_TABLE AS TABLE_NAME
from SYS_KEYS, SYS_KEY_PARTS
where KEY_IS_MAIN = 0
  and KP_KEY_ID = KEY_ID
  and KEY_TABLE = 'WS.WS.VFS_URL'
group by 1;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3999: OBY w/ col num to AS exp in join returned " $ROWCNT " rows\n";

SELECT 2 A FROM DB.DBA.SYS_KEYS ORDER BY A;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4099 : OBY w/ 2 AS x  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- End of test
--

--bug #5357
use B5357;
DROP TABLE TH1;

CREATE TABLE TH1(BI_BLOG_ID VARCHAR,BI_E_MAIL VARCHAR, BI_READERS ANY, PRIMARY KEY(BI_BLOG_ID));

INSERT INTO TH1(BI_BLOG_ID,BI_E_MAIL,BI_READERS) VALUES('*weblog-root*','',NULL);
INSERT INTO TH1(BI_BLOG_ID,BI_E_MAIL,BI_READERS) VALUES('103','xxxxxx@xxxxx.xxx',NULL);

DROP TABLE TH2;

CREATE TABLE TH2(BD_BLOG_ID VARCHAR, BD_E_MAIL VARCHAR, PRIMARY KEY(BD_BLOG_ID));

INSERT INTO TH2(BD_BLOG_ID,BD_E_MAIL) VALUES('*weblog-root*',NULL);
INSERT INTO TH2(BD_BLOG_ID,BD_E_MAIL) VALUES('103',NULL);

select BI_READERS, coalesce (BD_E_MAIL,BI_E_MAIL) from TH2 table option (hash),  TH1 table option (hash)  where BD_BLOG_ID = BI_BLOG_ID option (order);

ECHO BOTH $IF $EQU $LAST[2] 'xxxxxx@xxxxx.xxx' "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Hash join with any containing NULL " $LAST[2] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
use DB;

DROP TABLE B9401_2;
DROP TABLE B9401_1;
CREATE TABLE B9401_1(
  ORG_ID           INTEGER        NOT NULL,
  OBJ_ID           INTEGER        NOT NULL,
  FREETEXT_ID      INTEGER        NOT NULL IDENTITY,
  DATA             LONG VARCHAR   NOT NULL,

  CONSTRAINT B9401_1_PK PRIMARY KEY(ORG_ID,OBJ_ID)
);

CREATE TABLE B9401_2(
  ID       INTEGER    NOT NULL,
  DATA       NVARCHAR(30),

  CONSTRAINT B9401_2_PK PRIMARY KEY(ID)
);

CREATE TABLE B9401_3(
  ID       INTEGER    NOT NULL,
  DATA       NVARCHAR(30),

  CONSTRAINT B9401_2_PK PRIMARY KEY(ID)
);

CREATE TEXT INDEX ON B9401_1(DATA) WITH KEY FREETEXT_ID;

INSERT INTO B9401_1 (ORG_ID,OBJ_ID,DATA)
          VALUES (1000,  1,    'sd asdf test asdsdf');
INSERT INTO B9401_1 (ORG_ID,OBJ_ID,DATA)
          VALUES (1000,  2,    'sd asdf test asdsdf');
INSERT INTO B9401_1 (ORG_ID,OBJ_ID,DATA)
          VALUES (1000,  3,    'sd asdf test asdsdf');

INSERT INTO B9401_2 (ID,DATA)
          VALUES (1, 'name');
INSERT INTO B9401_2 (ID,DATA)
          VALUES (2, 'name 2');

INSERT INTO B9401_3 (ID,DATA)
          VALUES (1, 'name');
INSERT INTO B9401_3 (ID,DATA)
          VALUES (2, 'name 2');

-- XXX
--SELECT T2.DATA
--  FROM B9401_1 T TABLE OPTION (INDEX TEXT KEY)
--  left JOIN B9401_2 T2 on T.OBJ_ID = T2.ID
--  left JOIN B9401_3 T3 on T.OBJ_ID = T3.ID
-- WHERE contains(T.DATA,'asdf')
--   AND ORG_ID = 1000;
--ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "*** FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B9401: nested OJ and contains returns " $ROWCNT " rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table BUG_TBLOB;
drop table BUG_TB_STAT;
create table BUG_TBLOB (k integer not null primary key,
		    B1 long varchar,
                    B2 long varchar,
                    B3 long varbinary,
                    B4 long nvarchar,
                    E1 varchar,
                    E2 varchar,
                    EN varchar,
                    ED datetime);

insert into BUG_TBLOB (k,B1,B2,B3,B4, E1, E2, EN,ED)
values (914,make_string (803), make_string (1213), make_string (918), charset_recode (file_to_string ('bug_tblob_utf8.txt'), 'UTF-8', '_WIDE_'), make_string (515), make_string (508), null, null);

create table BUG_TB_STAT (k integer not null primary key,
		     B1_L integer, B2_L integer, B3_L integer, B4_L integer,
		     E1 varchar, E2 varchar);

insert into BUG_TB_STAT (k, B1_L, B2_L, B3_L, B4_L, E1, E2)
  values (914, 803, 1213, 918, 2000, make_string (515), make_string (508));

__dbf_set ('enable_mem_hash_join', 0);


select __tag (B1), __tag (B2), __tag (B3), __tag (B4) from BUG_TBLOB b, BUG_TB_STAT c where c.k = b.k
  and lENgth (B1) = B1_L and lENgth (B2) = B2_L and lENgth (B3) = B3_L
  and lENgth (B4) = B4_L and b. E1 = c. E1 and b. E2 = c. E2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": hash with row longer than the table w/ inline blobs crash STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table BUG_MAX_ROW;
create table BUG_MAX_ROW (id int primary key, data varchar);


create procedure BUG_MAX_ROW_F (in x any) { return repeat ('x', 9000); };

insert replacing BUG_MAX_ROW values (1, repeat (' ', 4071));
-- XXX: disabled as it is not already the case
--select 1 from BUG_MAX_ROW B1, BUG_MAX_ROW B2 where B1.ID = B2.ID and BUG_MAX_ROW_F (B1.DATA) = BUG_MAX_ROW_F (B2.DATA) option (order, hash);
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": error path of the max row in hash STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

__dbf_set ('enable_mem_hash_join', 1);


create procedure f (in x any)
{
  return x;
};

-- XXX
select count (*) from t1 a, t1 b where a.fi2 = b.fi2 and f(a.row_no) = f(b.row_no) and  f(b.row_no) < 1000  option (order, hash);
--ECHO BOTH $IF $EQU $LAST[1] 980 "PASSED" "*** FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--echo both ": count with hash j with expression hash  key reused in after join test\n";


select count (*) from (select distinct row_no from t1) f where f.row_no is null or f.row_no is null;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": count of dt with inported false const preds\n";


select count (*) from (select distinct row_no from t1) f where not (f.row_no is null or f.row_no is null);
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": count of dt with inported true const preds\n";

-- XXX
select a.row_no, b.row_no from t1 a, (select top 4 row_no from t1) b where a.row_no = b.row_no option (order) ;
--echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
--echo both ": dt with top does not import preds\n";

select __max (__min (1000), count (1)) from sys_users where u_id = 1111;
echo both $if $equ $last[1] 1000 "PASSED" "***FAILED";
echo both ": emppty agg with data independent false cond inits data independent exps\n";



ECHO BOTH "COMPLETED: SQL Optimizer tests (sqlo.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";

