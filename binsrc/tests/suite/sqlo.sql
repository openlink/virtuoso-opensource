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
--  Copyright (C) 1998-2024 OpenLink Software
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
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": emppty agg with data independent false cond inits data independent exps\n";


create table bug19085 (
    id              varchar not null,
    pos_start  integer,
    pos_end    integer,
    PRIMARY KEY(id)
);

insert into bug19085 values ('ID1', NULL, NULL);
insert into bug19085 values ('ID2', 10, 20);

sparql with <urn:b19410> insert { <#subj> <#pred> "data" };
sparql with <urn:b19410> insert { <#subj> <#pred> "data" };
select __box_flags ("u") from (sparql select (URI(CONCAT('http://host/',?o)) as ?u) from <urn:b19410> { ?s <#pred> ?o  } order by ?u) dt;
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": box flags are preserved on group by\n";


select id from bug19085 where 0 < (pos_end - pos_start) and 100 > (pos_end - pos_start);
echo both $if $equ $last[1] ID2 "PASSED" "***FAILED";
echo both ": table source with local test vec\n";

drop table b18907 if exists;
create table b18907 (id int primary key, depint int, depstr varchar);
create index depint18907 on b18907 (depint);
insert into b18907 values (1, 1, 1);
insert into b18907 values (2, 2, 2);
insert into b18907 values (3, 1, 3);
insert into b18907 values (4, 2, 4);
insert into b18907 values (5, 3, 5);
select tb.depstr, dt.maxa from b18907 tb, (select min(depint) as maxa from b18907) dt where coalesce (null,dt.maxa) = tb.depint order by 1;
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": derived table with aggregate exp in control exp in outer cond\n";

explain('select dt.maxa from b18907, (select min(depint) as maxa from b18907) dt where coalesce (dt.maxa) is not null');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": single fun ref in control exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain('select dt.maxa from b18907, (select min(depint) as maxa from b18907) dt where coalesce (dt.maxa,0) is not null');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": fun ref and const in control exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain('select dt.maxa, tb.depstr from b18907 tb, (select min(depint) as maxa from b18907) dt where coalesce (dt.maxa,tb.id) is not null');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": fun ref and outer col in control exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain('
sparql
PREFIX dbpedia-owl: <http://dbpedia.org/ontology/>
PREFIX nobel: <http://data.nobelprize.org/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?name (if(COUNT(?nobel)=3,"Yes", "No") AS ?HaveMoreThanThree)
WHERE
{
SERVICE <http://data.example.org/sparql>
{
SELECT ?name ?nobel
WHERE {
?persona foaf:name ?name .
?persona rdf:type foaf:Person .
?persona nobel:nobelPrize ?nobel .
}
}
}GROUP BY (?name)
HAVING (COUNT(?nobel) > 1)
ORDER BY ASC(?name)');
echo both $if $equ $state OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": Bug#18907 control exp with aggregate outside of dt\n";

sparql with <urn:b19410> insert { <#subj> <#pred> "data" };
sparql with <urn:b19410> insert { <#subj> <#pred> "data" };
select __box_flags ("u") from (sparql select (URI(CONCAT('http://host/',?o)) as ?u) from <urn:b19410> { ?s <#pred> ?o  } order by ?u) dt;
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
echo both ": box flags are preserved on group by\n";

drop table case1172;
CREATE TABLE case1172 ( v1 DECIMAL ) ;
  INSERT INTO case1172 VALUES ( 0 ) ;
  INSERT INTO case1172 ( v1 ) SELECT CASE v1 WHEN 49 THEN v1 ELSE -128 END FROM case1172 AS v2 , case1172 , case1172 AS v3 GROUP BY v1 , v1 ;
  UPDATE case1172 SET v1 = ( SELECT DISTINCT * FROM case1172 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Insert cast with case exp value STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1173;
CREATE TABLE case1173 ( v1 FLOAT UNIQUE , v2 INT ) ;
 INSERT INTO case1173 VALUES ( NULL , 57 ) ;
 INSERT INTO case1173 VALUES ( -1 , ( SELECT 60 , v2 FROM case1173 WHERE v2 = -1 ) ) ;
 UPDATE case1173 SET v1 = ( CASE WHEN v2 * v1 THEN 76 ELSE ( SELECT v2 FROM case1173 WHERE v1 = -2147483648 / CASE WHEN v2 = ( SELECT v1 FROM case1173 WHERE ( CASE WHEN v2 = v2 AND v2 = v2 AND v2 THEN v2 + v1 * -128 + 48100742.000000 END ) IN ( SELECT v1 FROM case1173 WHERE v2 BETWEEN 'x' AND 'x' OR ( CASE WHEN v2 = 16 THEN 46 ELSE v1 + ( 69175744.000000 , 10962973.000000 ) / 36 + 5 END ) GROUP BY 'x' ) ORDER BY v2 / 45 DESC ) THEN 32232158.000000 END ) END ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Insert cast on case exp value box_add crash STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1174;
CREATE TABLE case1174 ( v1 nvarchar ) ;
 INSERT INTO case1174 VALUES ( 1 ) ;
 INSERT INTO case1174 SELECT MAX ( DISTINCT v1 ) FROM case1174 ;
 INSERT INTO case1174 SELECT v1 FROM case1174 WHERE ( SELECT ( SELECT v1 FROM case1174 ) ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max distinct failed, any ssl ref changes after hash feed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1175;
CREATE TABLE case1175 ( v1 INT , v2 BIGINT PRIMARY KEY) ;
 INSERT INTO case1175 VALUES ( 20 , -1 ) ;
 SELECT v1 + 77 , v2 FROM case1175 UNION SELECT v2 , CASE WHEN 92 THEN 86 ELSE ( ( 32433852.000000 , 70038895.000000 ) , ( 64572024.000000 , 4442219.000000 ) ) END FROM case1175 ORDER BY v2 + -1 * 40 ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Assign from box dc is general case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1176;
CREATE TABLE case1176 ( v1 INTEGER NOT NULL PRIMARY KEY ) ;
  INSERT INTO case1176 VALUES ( 95 ) ;
  INSERT INTO case1176 VALUES ( ( SELECT ( -1 , -1 ) * ( 31 , 84 ) FROM case1176 WHERE v1 BETWEEN 'x' AND 'x' OR EXISTS ( SELECT v1 FROM case1176 WHERE v1 NOT IN ( SELECT 20 FROM case1176 WHERE ( v1 > 2147483647 AND v1 < 271514.000000 ) ) ) ) ) ;
  INSERT INTO case1176 SELECT v1 + v1 + v1 FROM case1176 ORDER BY v1 ;
  INSERT INTO case1176 VALUES ( ( SELECT ( 34 , 16 ) * ( 41 , -128 ) FROM case1176 WHERE v1 BETWEEN 'x' AND 'x' OR EXISTS ( SELECT v1 FROM case1176 WHERE v1 + v1 * 24 / 50820962.000000 - 0 / 86183090.000000 IN ( SELECT DISTINCT v1 FROM case1176 WHERE 'x' OR ( ( ( v1 / 0 ) ) [ 35 ] ) * 16 BETWEEN 'x' AND 'x' GROUP BY v1 , v1 ) ) ) ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Div/0 with searched case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1177;
CREATE TABLE case1177 ( v1 SMALLINT CHECK ( CONTAINS ( 'del' , 'reabbreviating' , 'diamonds' ) ) ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CONTAINS() in check constraint not allowed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1178;
CREATE TABLE case1178 ( v1 INT ) ;
  INSERT INTO case1178 VALUES ( 2147483647 ) ;
  INSERT INTO case1178 VALUES ( -1 ) ;
  INSERT INTO case1178 ( v1 , v1 , v1 ) SELECT 54 , v1 , -128 FROM case1178 AS v4 , case1178 , case1178 AS v3 NATURAL JOIN case1178 AS v2 ;
  UPDATE case1178 SET v1 = NULL WHERE ( v1 * 2147483647 , CASE WHEN v1 = 'x' THEN 75 WHEN DENSE_RANK ( 'x' ) THEN 25942677.000000 END + 16 * 127 ) IN ( SELECT v1 FROM case1178 WHERE v1 >= 127 AND ( v1 * 16 , v1 , ( SELECT v1 FROM case1178 WHERE ( v1 , v1 ) IN ( SELECT v1 , v1 AS v8 FROM case1178 AS v6 NATURAL JOIN case1178 AS v7 NATURAL JOIN case1178 AS v5 NATURAL JOIN case1178 WHERE v1 ) ORDER BY v1 ) ) - 'x' GROUP BY 48002391.000000 ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mutiply with numeric in assign via simple case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1179;
CREATE TABLE case1179 ( v1 INT ) ;
 INSERT INTO case1179 ( v1 , v1 , v1 ) VALUES ( 77 , -128 , -1 ) ;
 INSERT INTO case1179 VALUES ( 4 ) ;
 SELECT CASE -128 / 56 WHEN v1 THEN 20 ELSE v1 + -2147483648 END , v1 FROM case1179 UNION SELECT 19 , 0 * v1 FROM case1179 GROUP BY v1 ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  union on case exp w/ group STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1181 if exists;
CREATE TABLE case1181 ( v1 DOUBLE PRECISION ) ;
INSERT INTO case1181 VALUES ( -1 ) ;
INSERT INTO case1181 ( v1 ) SELECT CASE v1 WHEN 42 THEN v1 ELSE 95 END FROM case1181 AS v3 , case1181 AS v4 , case1181 , case1181 AS v2 GROUP BY v1 , v1 ORDER BY CASE WHEN v1 >= 2147483647 THEN 'x' + ( SELECT ( CASE WHEN v1 NOT IN ( SELECT ( v1 / ( - v1 ) ) FROM case1181 GROUP BY 'x' ) THEN v1 ELSE NULL END ) AS v5 ) WHEN 1 THEN 'x' ELSE ( 44 * v1 ) END ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  insert with subq case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1182 if exists;
drop view case1182v3 if exists;
CREATE TABLE case1182 ( v1 INT , v2 INT ) ;
CREATE VIEW case1182v3 AS SELECT * FROM case1182 GROUP BY 'x' ;
INSERT INTO case1182v3 VALUES ( -1 , 127 ) ;
SELECT v2 + v1 FROM case1182v3 WHERE v2 IN ( 127 ) AND v1 NOT IN ( SELECT DISTINCT v1 / 67 , 96 FROM case1182 GROUP BY NULL , 'x' , 'x' , 'x' ) ORDER BY 13647422.000000 / -1 / v2 + v1 + v2 ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  select with not/in on a grouping by const exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1183 if exists;
CREATE TABLE case1183 ( v1 DECIMAL NOT NULL PRIMARY KEY ) ;
INSERT INTO case1183 VALUES ( -2147483648 ) ;
INSERT INTO case1183 VALUES ( ( SELECT ALL CASE WHEN 0 THEN 77 / -128 WHEN 35 THEN -128 ELSE ( ( 30646101.000000 , 35055771.000000 ) , ( 91094082.000000 , 43147816.000000 ) ) / 0 END ) ) ;
INSERT INTO case1183 ( v1 , v1 , v1 ) SELECT v1 FROM case1183 WHERE 27 / - 76 / ( v1 + 53 ) + 8 / -1 IN ( v1 / 51 , 'x' , 'x' ) ORDER BY v1 / v1 + 2147483647 + 37190275.000000 + 87 ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  insert on different columns, subselect with volatile exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1184 if exists;
CREATE TABLE case1184 ( v1 INT NULL ) ;
UPDATE case1184 SET v1 = ( SELECT 2 AS zero_value ) + ( SELECT 2 AS zero_value ) WHERE v1 IN ( SELECT v1 FROM case1184 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  update with non vectored subq select with integer vectored exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1185 if exists;
drop table case1185v3 if exists;
CREATE TABLE case1185 ( v2 INTEGER UNIQUE , v1 INTEGER CHECK ( COALESCE ( v1 ) = v2 ) ) ;
INSERT INTO case1185 ( v1 ) VALUES ( 2 ) ;
CREATE TABLE case1185v3 ( v4 VARCHAR ( 255 ) ) ;
SELECT '%password%' FROM case1185v3 LEFT JOIN case1185 ON case1185v3 . v4 = case1185 . v2 GROUP BY COALESCE ( v2 ) , v1 , v1 option (hash);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  hash join with group by hash source on simple coalesce exp STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1190 if exists;
drop view case1190view if exists;
CREATE TABLE case1190 ( v1 FLOAT UNIQUE ) ;
CREATE VIEW case1190view AS SELECT * FROM case1190 WHERE v1 < -128 + 47355641.000000 / 32 * v1 + ( SELECT * FROM case1190 WHERE v1 = 71 AND ( 54571328.000000 [ -128 ] ) >= v1 AND v1 IS NULL ) + 66 + 29872388.000000 ORDER BY v1 DESC ;
SELECT * FROM case1190view WHERE 71883293.000000 < CASE WHEN ( SELECT CASE WHEN v1 [ 76 ] THEN v1 ELSE ( v1 / CASE WHEN v1 = -1 THEN v1 + 61 END , 'x' ) END FROM case1190view ) IS NULL THEN v1 ELSE 68 END AND v1 = -1 AND 0 >= v1 ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  bad plan loop in dfe STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE TABLE case1191 ( v1 FLOAT ) if not exists;
drop view case1191view if exists;
CREATE VIEW case1191view AS SELECT * FROM case1191 WHERE v1 IN ( SELECT * FROM case1191 WHERE v1 IN ( 'x' ) ORDER BY v1 , v1 / 61 ) ORDER BY v1;
UPDATE case1191 SET v1 = ( SELECT v1 FROM case1191view WHERE v1 / ( CASE WHEN v1 NOT IN ( 127 ) AND ( ( -1 , -1 ) , ( -1 , 30 ) ) THEN ( SELECT * FROM case1191view WHERE ( SELECT v1 , v1 FROM case1191 WHERE v1 = ( 15895325.000000 , 12364601.000000 ) / CASE 54 WHEN NULL THEN -128 END AND v1 = 36 ) ) ELSE v1 + -1 END ) ) + 16 + 67880893.000000 ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  bad plan loop in dfe (2) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE TABLE case1192 ( v1 INT , v2 NUMERIC NOT NULL CHECK ( v1 >= -32768 AND v1 <= 4 ) ) if not exists;
SELECT v2 FROM case1192 WHERE v1 NOT IN ( 0 ) AND v1 IN ( CASE WHEN v1 = 37 THEN -128 ELSE ( SELECT * , 0 + 16 FROM case1192 WHERE 'x' IS NOT NULL GROUP BY NULL * -128 ) END ) ORDER BY v2 / 33 ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  bad plan loop in dfe (3) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1193 if exists;
CREATE TABLE case1193 ( v1 BIGINT ) ; 
INSERT INTO case1193 VALUES ( 88 ) ; 
INSERT INTO case1193 ( v1 , v1 ) VALUES ( NULL , 31 ) ; 
INSERT INTO case1193 ( v1 ) SELECT ( SELECT -128 ) FROM ( SELECT 86 + 98371242.000000 AS v8 , 8 AS v9 , 'x' AS v7 FROM case1193 AS v11 , case1193 AS v10 ) AS v3 , case1193 AS v6 , case1193 AS v5 , case1193 AS v4 , case1193 , case1193 AS v2 ; 
UPDATE case1193 AS v15 SET v1 = ( SELECT ( CASE WHEN -1 THEN 14 ELSE CASE WHEN v1 IN ( SELECT v1 FROM case1193 WHERE v1 > 66 OR 75 OR v1 = ( SELECT -1 FROM case1193 , case1193 AS v14 , case1193 AS v13 WHERE v1 IN ( RANK ( v1 , v1 ) , 88 ) ) GROUP BY v1 ) THEN v1 ELSE NULL END END ) AS v12 ) ; 
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  not predicate on optimised predicate STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1194 if exists;
CREATE TABLE case1194 ( v1 NUMERIC UNIQUE );
INSERT INTO case1194 VALUES ( 127 ) ;
UPDATE case1194 SET v1 = CASE WHEN 16 THEN 2147483647 ELSE 89599554.000000 * ( SELECT v1 FROM case1194 WHERE v1 > 19 + 95868930.000000 ) END + CASE WHEN ( 'x' , v1 + v1 ) > 27 + v1 THEN -128 ELSE v1 + 0 END ;
SELECT DISTINCT NULL FROM case1194 UNION SELECT * FROM case1194 WHERE v1 < 0 + 88 AND -128 >= v1 AND NULL ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  numeric cast via subq/case STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1195 if exists;
CREATE TABLE case1195 ( v1 INTEGER CHECK ( ( SELECT ( SELECT v1 + v1 AS b_plus_one ) ) ) ); 
INSERT INTO case1195 SELECT TOP 4 1 FROM case1195 WHERE v1 = 1 GROUP BY CUBE ( v1 , v1 ) ; 
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert with fake cube with const in null slot STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1196 if exists;
drop view case1196view if exists;
CREATE TABLE case1196 ( v1 INTEGER NOT NULL PRIMARY KEY , v2 VARCHAR NOT NULL , v3 DECIMAL CHECK ( v1 > 65468526.000000 ) ) ; 
CREATE VIEW case1196view AS SELECT * FROM case1196 WHERE v2 IN ( CAST ( 27 AS FLOAT ) , CAST ( 96 / 66872209.000000 - -128 / 70 AS FLOAT ) ) ORDER BY CASE WHEN v1 IS NULL THEN v3 ELSE 9 END + 5182666.000000 * v1 ; 
UPDATE case1196view SET v3 = ( -1 , ( SELECT v2 FROM case1196 WHERE ( ( v1 [ 98 ] ) [ 82 ] ) * -2147483648 IN ( SELECT v1 , v3 FROM case1196view WHERE v2 IS NOT NULL OR 'x' IN ( 78431161.000000 , 88129736.000000 ) AND v1 = 'x' INTERSECT SELECT v3 , v1 FROM case1196view WHERE v2 > -128 ) ) ) - 66 , v2 = v3 ; 
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update with wrong plan crash handled STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1197 if exists;
CREATE TABLE case1197 ( v1 INT );
SELECT '{a: 1, b: [2, 3] }' AS negative_value FROM case1197 GROUP BY ROLLUP ( v1 , v1 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select with fake rollup with const in null slot STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1198 if exists;
CREATE TABLE case1198 ( v1 INT , v2 NUMERIC ) ;
INSERT INTO case1198 VALUES ( 
    ( SELECT v1 + ( 21073282.000000 , 71733063.000000 ) / 28 / -128 FROM case1198 ORDER BY 83232987.000000 + 81567665.000000 ASC ) , 
    127 * ( CASE WHEN 64 THEN -128 ELSE ( ( 84936941.000000 , 60617039.000000 ) , ( 56120940.000000 , 86634377.000000 ) ) END ) / -128 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": numeric cast from arith temp result needs cast STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1199 if exists;
CREATE TABLE case1199 ( v2 INT , v1 VARCHAR(80) PRIMARY KEY ) if not exists;
UPDATE case1199 SET v1 = 'abcf%' WHERE v1 IN ( SELECT 18018 / 6 FROM case1199 WHERE v2 = '%n' GROUP BY '%H:%M:%f' HAVING v2 < 64 ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": num cast message crash STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create table tleft2k (id int, k varchar, data varchar, primary key (id, k)) if not exists;
create table tright2k (rid int, rk varchar, rseq int, rdata varchar, primary key(rid, rk, rseq)) if not exists;
delete from tleft2k;
delete from tright2k;
insert into tleft2k (id,k,data) values (1,1, 'a');
insert into tleft2k (id,k,data) values (2,2, 'b');
insert into tleft2k (id,k,data) values (3,3, 'c');
insert into tright2k (rid, rk, rseq, rdata) values (2,2, 1, '231');
insert into tright2k (rid, rk, rseq, rdata) values (2,2, 2, '233');

create procedure tojoby_check (in q varchar, in ex any)
{
  declare rs, m any;
  declare i, j int;

  exec(q, null, null, vector(), 0, m, rs);
  for (i := 0; i < length (rs); i := i + 1)
    {
      declare elm any;
      elm := rs[i];
      for (j := 0; j < length(elm); j := j + 1)
        {
          dbg_obj_print (elm[j], ex[i][j]);
          if (not equ (elm[j], ex[i][j]) and elm[j] is not null and ex[i][j] is not null)
            signal ('OBOJX','Outer join w/ oby failed');
          if ((elm[j] is null and ex[i][j] is not null) or (ex[i][j] is null and ex[i][j] is not null))
            signal ('OBOJX','Outer join w/ oby failed');
        }
    }
  return 'OK';
};

select id, rdata from tleft2k left outer join tright2k on (id = rid and k = rk) order by id;

select tojoby_check ('select id, rdata from tleft2k left outer join tright2k on (id = rid and k = rk) order by id',
    vector (vector (1, NULL), vector (2, '231'), vector (2, '233'), vector (3, NULL)));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  outer join with oby on pk STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select id, rdata from tleft2k left outer join tright2k on (id = rid and k = rk) order by id desc;
select tojoby_check ('select id, rdata from tleft2k left outer join tright2k on (id = rid and k = rk) order by id desc',
    vector (vector (3, NULL), vector (2, '231'), vector (2, '233'), vector (1, NULL)));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  outer join with oby on pk desc STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure dist_top_ttl_ins ()
{
  declare i int;
  declare ses any;
  ses := string_output ();
  http ('@base <http://example.org/> .\n', ses);
  for (i:=0;i<255;i:=i+1)
    {
      http (sprintf ('<#s-x%d> <#pred> %d .\n', i, rnd (127)), ses);
    }
  return string_output_string (ses);
};

sparql clear graph <urn:bind:test> ;
ttlp (dist_top_ttl_ins (), 'http://example.org/', 'urn:bind:test');

sparql
PREFIX : <http://example.org/#>
SELECT DISTINCT ?id
WHERE {
    {
         SELECT DISTINCT ?id
         FROM <urn:bind:test>
         WHERE {
                ?x <http://example.org/#pred> ?s.
                BIND(replace (str(?s), '0', '-') AS ?id)
         }
         GROUP BY ?id
         ORDER BY ?id
    }
}
LIMIT 10 OFFSET 10;

ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select top 10 distinct from (select distinct ..) produced: " $ROWCNT " rows\n";

create table topksptb (g_uri varchar, g_defs varchar, g_host varchar primary key) if not exists; 
insert soft topksptb values ('g:1', null, '8890');
insert soft topksptb values ('g:2', null, '8891');

create procedure topksp ()
{
  for select top 1 g_uri, g_defs from topksptb where '8891' like g_host do
    {
      return g_uri;
    }
  return null;
};

select topksp ();
ECHO BOTH $IF $EQU $LAST[1] 'g:2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": cursor with top 1 return=" $LAST[1] "\n";
select top 1 g_uri, g_defs from topksptb where '8891' like g_host;
ECHO BOTH $IF $EQU $LAST[1] 'g:2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select top 1 return=" $LAST[1] "\n";


set U{caseno} case1204;
drop table case1204;
CREATE TABLE case1204 ( v1 DOUBLE PRECISION ) ;
  INSERT INTO case1204 VALUES ( 4 ) ;
  INSERT INTO case1204 VALUES ( 52 ) ;
  INSERT INTO case1204 ( v1 ) SELECT ( SELECT v1 ) FROM ( SELECT 17 + 17399826.000000 AS v7 , 46312780.000000 AS v8 , 'x' AS v6 ) AS v3 , case1204 AS v2 , case1204 AS v5 , case1204 , case1204 AS v4 ;
  SELECT v1 FROM case1204 AS v11 , case1204 AS v10 , case1204 AS v9 NATURAL JOIN case1204 WHERE v1 IN ( SELECT v1 FROM case1204 AS v13 , case1204 AS v12 , case1204 AS v14 , case1204 ) ORDER BY ( 67 , -128 ) DESC ;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1205;
drop table case1205 if exists;
CREATE TABLE case1205 ( v1 FLOAT ) ;
  INSERT INTO case1205 VALUES ( 30 ) ;
  INSERT INTO case1205 VALUES ( -1 ) ;
  SELECT v1 FROM case1205 WHERE EXISTS ( SELECT v1 FROM case1205 WHERE v1 IN ( SELECT v1 FROM case1205 WHERE v1 > 29 GROUP BY v1 , v1 ) ) ;
--  INSERT INTO case1205 VALUES ( ( SELECT v1 FROM case1205 WHERE v1 BETWEEN 'x' AND 'x' OR EXISTS ( SELECT v1 FROM case1205 WHERE v1 IN ( SELECT v1 , v1 FROM case1205 WHERE v1 > 29 GROUP BY v1 , 34500520.000000 , v1 ) ) ) ) ;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1206;
set macro_substitution=off;
drop TABLE case1206 ;
CREATE TABLE case1206 ( v1 DATE PRIMARY KEY ) ;
 INSERT INTO case1206 ( v1 , v1 ) VALUES ( 1237962480 , '$[*].datetime() ? (@ >= 10.03.2017 12:35 +1.datetime(dd.mm.yyyy HH24:MI TZH))' ) ;
 UPDATE case1206 SET v1 = 2 WHERE 'lax $[0].a' = ( SELECT v1 - ( SELECT v1 - 0 ) ) OR v1 < 9223372036854775807 ;

set macro_substitution=on;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1207;
drop table case1207;
CREATE TABLE case1207 ( v1 NUMERIC NOT NULL CHECK ( ( v1 , v2 ) - -1 + -1 + 32 + 13041968.000000 ) NOT NULL UNIQUE CHECK ( -1 ) , v2 FLOAT ) ;
  INSERT INTO case1207 VALUES ( 45 , ( ( 37506630.000000 , 6956091.000000 ) ) ) ;
  INSERT INTO case1207 VALUES ( -1 , 96 ) ;
  INSERT INTO case1207 ( v1 ) SELECT v2 FROM case1207 ;
  UPDATE case1207 SET v2 = 'x' WHERE CASE WHEN v1 - ( v1 + -1 ) > ( SELECT CASE WHEN 41 * - NULL + 46 + -1 + -128 + 96 + 0 THEN NULL ELSE 83 END FROM case1207 WHERE ( SELECT CASE WHEN 2147483647 THEN 51229361.000000 ELSE 0 END - v1 FROM case1207 WHERE ( CAST ( ( ( SELECT ALL CASE WHEN ( 13 , 'x' ) < ( 255 , 'x' ) THEN NULL ELSE 52 END * v2 FROM case1207 GROUP BY v1 , v2 , v2 , v1 , v2 , v2 ORDER BY v1 ) , 'x' , 'x' ) AS FLOAT ) ) / 80777295.000000 ) = ( 35 ) ) THEN NULL ELSE 46 / -128 END ;

ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1208;
drop TABLE case1208;
CREATE TABLE case1208 ( v1 REAL ) ;
 UPDATE case1208 SET v1 = v1 + ( SELECT 2 AS zero_value DATE ) WHERE v1 IN ( SELECT 2 - v1 FROM case1208 ) ;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1209;
drop table case1209;
CREATE TABLE case1209 ( v1 CHAR(1) NULL , v2 CHAR(1) NULL , v3 INT NULL ) ;
 SELECT 2 FROM case1209 WHERE 2 OR ST_Contains () ;

ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1210;
drop table case1210;
CREATE TABLE case1210 ( x FLOAT UNIQUE CHECK ( ( CASE WHEN 1.000000 = 1 THEN 1 ELSE ( 1.000000 , 1.000000 ) / 1 / 1 END ) AND ( SELECT CASE WHEN x < x AND x IS NULL THEN 1 ELSE ( SELECT x FROM case1210 WHERE ( CASE WHEN x = x AND x = x AND x THEN 1.000000 ELSE x + x * 1 + 1 END ) IN ( SELECT DISTINCT 1 FROM case1210 GROUP BY NULL , 'x' , 'x' , 'x' ) ORDER BY x / 1 DESC ) - CASE WHEN ( 1 ) AND x NOT IN ( SELECT DISTINCT x / 1 , 1 FROM case1210 GROUP BY CASE WHEN x = 1 THEN 'x' ELSE x - x * 1.000000 + 1 END ) THEN x + 1 WHEN 1 THEN 1 ELSE 1.000000 END / 1 + 1 END ) < x + x + x ) PRIMARY KEY ) ;

ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1211;
drop table case1211;
CREATE TABLE case1211 ( v3 CHAR(1) NULL , v2 CHAR(1) NULL , v1 INT NULL ) ;
 SELECT v3 ( 'arteriole' ) FROM case1211 WHERE v1 = '313233' OR v3 = 'xyzz ' ORDER BY count ( * ) , v2 ;

ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1212;
drop TABLE case1212 ;
drop VIEW case1212view;
CREATE TABLE case1212 ( v1 VARCHAR ( 500 ) ) ;
 CREATE VIEW case1212view AS SELECT TOP 5 ( CASE WHEN case1212 . v1 = 10 THEN 'High' ELSE 'Mary' END ) AS x , v1 FROM case1212 ORDER BY v1 DESC ;
 DELETE FROM case1212view WHERE NOT ( ( 1 ) IN ( SELECT REPEAT ( NULL , 10 ) FROM case1212 AS AutoVacuum LEFT JOIN case1212 ON v1 GROUP BY v1 ) ) ;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table case1214t0 if exists;
drop table case1214t1 if exists;
CREATE TABLE case1214t0(c0 INT);
CREATE TABLE case1214t1(c1 INT);
INSERT INTO case1214t1 (c1) VALUES (1);

SELECT * FROM case1214t0 RIGHT JOIN case1214t1 ON 1;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  roj on true rows=" $ROWCNT "\n";

SELECT * FROM case1214t0 RIGHT JOIN case1214t1 ON 1 WHERE (NULL IS NOT NULL);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  roj on true with filter false rows=" $ROWCNT "\n";

SELECT * FROM case1214t0 RIGHT JOIN case1214t1 ON 1 WHERE (NULL IS NULL);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  roj on true with filter true rows=" $ROWCNT "\n";


set U{caseno} case1216;
drop table case1216;
CREATE TABLE case1216 ( v1 INT PRIMARY KEY ) ;
 UPDATE case1216 SET v1 = 16 WHERE v1 <= ( CASE WHEN 127 THEN 96412681.000000 ELSE CAST ( ( SELECT v1 FROM case1216 WHERE ( CASE WHEN v1 IS NULL THEN 'x' WHEN 45 THEN 51012602.000000 ELSE 255 END ) = ( SELECT v1 FROM case1216 WHERE v1 = ( SELECT v1 FROM case1216 WHERE v1 = 'x' ) AND v1 = 'x' ORDER BY v1 ) ORDER BY v1 DESC ) AS FLOAT ) END ) AND ( v1 > 27 ) AND v1 = v1 AND v1 < 0 ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1217;
drop table case1217;
CREATE TABLE case1217 ( case1217 BIGINT UNIQUE CHECK ( CASE WHEN case1217 = ( SELECT case1217 FROM case1217 WHERE ( 1 / CASE WHEN case1217 = ( SELECT case1217 FROM case1217 WHERE case1217 IN ( 1 ) AND ( CASE WHEN case1217 = 1 THEN 1 ELSE case1217 + ( SELECT case1217 FROM case1217 WHERE ( CASE WHEN case1217 = case1217 AND case1217 = case1217 AND case1217 THEN 1.000000 ELSE case1217 + case1217 * 1 + 1 END ) IN ( SELECT DISTINCT case1217 / 1.000000 , 1 FROM case1217 GROUP BY NULL , 'case1217' , 'case1217' , 'case1217' ) ORDER BY case1217 / 1 DESC ) * 1 END ) NOT IN ( SELECT DISTINCT case1217 / 1 , 1 FROM case1217 ) ORDER BY 1.000000 + 1.000000 ASC ) THEN case1217 + case1217 * 1 + 1 END ) IN ( SELECT ( SELECT case1217 FROM case1217 WHERE 'case1217' AND 1.000000 LIKE 'case1217' * 'case1217' OR case1217 BETWEEN 'case1217' AND 1 ) [ 1 ] FROM case1217 WHERE ( case1217 / 1 ) = case1217 - 1.000000 * 1 * case1217 ORDER BY case1217 - case1217 * 1 + 1 ) ORDER BY case1217 / 1 DESC ) THEN case1217 + case1217 * 1 + 1.000000 END AND ( SELECT CASE WHEN case1217 = 1 THEN 1 ELSE ( SELECT case1217 FROM case1217 WHERE case1217 NOT IN ( 1 ) AND case1217 NOT IN ( 1 ) GROUP BY case1217 ) + case1217 / 1 + 1 END ) < case1217 + case1217 + case1217 ) PRIMARY KEY ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1218;
drop table case1218;
CREATE TABLE case1218 ( v1 INT ) ;

 UPDATE case1218 SET v1 = 16 WHERE v1 = v1 + ( SELECT v1 FROM case1218 WHERE v1 / ( CASE WHEN v1 NOT IN ( 59 ) AND ( ( 0 , 255 ) , ( 21 , 127 ) ) THEN ( SELECT * FROM case1218 WHERE v1 NOT IN ( SELECT v1 FROM case1218 WHERE v1 IN ( ( ( 82694108.000000 , 9307368.000000 ) , ( 77644510.000000 , 10822800.000000 ) ) , 0 , 'x' , 4 ) ORDER BY v1 [ 84 ] , v1 [ 84 ] ) ) ELSE v1 + 87 END ) ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1219;
drop table case1219;
CREATE TABLE case1219 ( v1 CHAR(1) NULL , v3 REAL NULL , v2 INT CHECK( ( v2 - v2 ) ) ) ;
 UPDATE case1219 SET v1 = count ( DISTINCT * ) + 1237962480 ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1220;
drop table case1220;
CREATE TABLE case1220 ( v1 SMALLINT CHECK ( CONTAINS ( 1 , v1 ) ) CHECK ( v1 >= 'green-iguana' AND v1 <= 'w:12B w:13* w:12,5,6 a:1,3* a:3 w asd:1dc asd' ) ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1221;
drop table case1221;
CREATE TABLE case1221 ( v1 FLOAT ) ;
 INSERT INTO case1221 ( v1 , v1 ) VALUES ( 'racketeers' , NULL ) ;
 INSERT INTO case1221 SELECT 100 FROM case1221 AS column_name LEFT JOIN case1221 ON v1 CROSS JOIN case1221 AS b_plus_one USING ( v1 , v1 ) ORDER BY 0 + 2 ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1222;
drop table case1222;
drop view case1222view;
CREATE TABLE case1222 ( v1 DECIMAL NOT NULL PRIMARY KEY CHECK ( v1 = v1 AND v1 = v1 AND v1 = v1 ) UNIQUE ) ;
  CREATE VIEW case1222view AS SELECT v1 FROM case1222 WHERE v1 = CASE -1 WHEN 84 THEN ( SELECT DISTINCT v1 FROM case1222 WHERE v1 < 35094152.000000 ORDER BY v1 ) END AND 9927111.000000 / ( 39 ) ;
  SELECT v1 FROM case1222 ORDER BY CASE WHEN v1 = 'x' AND ( SELECT v1 FROM case1222view WHERE 33 LIKE 'x' AND ( 0 ) ORDER BY v1 ) AND 'x' >= 0 AND v1 <= 0 THEN NULL ELSE -2147483648 END ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1223;
drop table case1223;
drop view case1223v4;
drop view case1223v7;
CREATE TABLE case1223 ( v1 INT NOT NULL NOT NULL NOT NULL CHECK ( v1 ) , v2 INT UNIQUE NOT NULL , v3 INT UNIQUE ) ;

 CREATE VIEW case1223v4 AS SELECT * FROM case1223 ORDER BY v1 + v3 , ( v2 + v2 ) / 2147483647 ;

 CREATE VIEW case1223v7 AS SELECT v2 FROM ( SELECT v2 FROM case1223 WHERE 8 IN ( 78222408.000000 ) GROUP BY v1 HAVING ( v3 >= 'x' AND v1 BETWEEN 6 AND 77 AND v2 = 23 ) ) AS v6 , case1223 AS v5 NATURAL JOIN case1223v4 WHERE v3 = 127 ;

 UPDATE case1223v4 SET v3 = 0 WHERE v1 = ( SELECT -2147483648 FROM case1223 AS v8 JOIN case1223v7 ON v3 < ( SELECT v2 FROM case1223 , case1223v7 ) JOIN case1223 USING ( v3 ) WHERE v2 = v3 ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1224;
drop table case1224;
CREATE TABLE case1224 ( v1 REAL NULL CHECK( 2 = 2 ) ) ;
 UPDATE case1224 SET v1 = 2 WHERE ( SELECT v1 v1 ) IN ( SELECT v1 FROM case1224 UNION SELECT v1 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1225;
drop table case1225;
CREATE TABLE case1225 ( v1 nvarchar ) ;
 UPDATE case1225 SET v1 = v1 + 1 WHERE v1 IN ( SELECT xmlagg ( ABS ( 9 ) ) FROM case1225 GROUP BY v1 ORDER BY v1 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1226;
drop table case1226;
 CREATE TABLE case1226 ( v3 INTEGER ) ;
 SELECT * FROM case1226 LEFT JOIN case1226 AS constraintdef ON case1226 . v3 = case1226 . v3 AND contains ( v3 , 'A/B-move/C-move' ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1227;
drop table case1227;
drop view case1227v3;
CREATE TABLE case1227 ( v1 BIGINT , v2 FLOAT ) ;
  CREATE VIEW case1227v3 AS SELECT v2 FROM case1227 WHERE v1 IN ( SELECT v2 FROM case1227 GROUP BY CASE WHEN v2 = -1 THEN 18934338.000000 WHEN -128 THEN 127 / 0 ELSE v1 + 44 END ORDER BY v1 + -1 ) ORDER BY ( CASE WHEN v2 THEN 94 ELSE v1 - - v1 / 25 END ) , v2 [ -1 ] ;
  UPDATE case1227v3 SET v2 = 'x' WHERE CASE ( 57612277.000000 , ( SELECT v2 FROM case1227v3 WHERE v2 IN ( SELECT v1 FROM case1227v3 WHERE v1 = 'x' + ( SELECT ( CASE WHEN v1 + v1 THEN - 55369777.000000 / -2147483648 ELSE v2 - - - v1 / - NULL END - 33 / 64325439.000000 ) , v1 [ 8 ] FROM case1227 ) ) ) ) WHEN -128 THEN -128 WHEN 36 * v1 THEN 58 END ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1228;
drop table case1228;
CREATE TABLE case1228 ( case1228 BIGINT UNIQUE CHECK ( CASE WHEN case1228 = ( SELECT case1228 FROM case1228 WHERE ( CASE WHEN case1228 = case1228 AND case1228 = case1228 AND case1228 THEN 'case1228' ELSE case1228 + case1228 * 1 + 1 END ) IN ( SELECT ( SELECT case1228 FROM case1228 WHERE 'case1228' AND 1.000000 LIKE 'case1228' * 'case1228' OR case1228 BETWEEN 'case1228' AND 1 ) [ 1 ] FROM case1228 WHERE ( case1228 / 1 ) = case1228 - 1.000000 * 1 ORDER BY case1228 - case1228 * 1 + 1 ) ORDER BY case1228 / 1 DESC ) THEN case1228 + case1228 * 1 + 1.000000 END AND ( SELECT CASE WHEN case1228 = 1 THEN 1 ELSE ( SELECT case1228 FROM case1228 WHERE case1228 NOT IN ( 1 ) AND case1228 NOT IN ( 1 ) GROUP BY CASE WHEN case1228 * case1228 THEN 1 ELSE ( SELECT case1228 FROM case1228 WHERE case1228 = 1 / CASE WHEN case1228 = ( SELECT case1228 FROM case1228 WHERE ( SELECT case1228 / CASE WHEN case1228 NOT IN ( 1 ) AND case1228 NOT IN ( 1 , ( ( NULL , 1.000000 ) , ( 1.000000 , ( SELECT case1228 + 1 , ( ( SELECT case1228 + 1 , ( 1.000000 , 1.000000 ) / 1 FROM case1228 WHERE case1228 = 1 / 1 ) ) / 1 FROM case1228 WHERE case1228 = 1 / 1 ) ) ) ) THEN ( CASE WHEN case1228 = 1 THEN 1 ELSE case1228 - case1228 * 1 + 1 END ) END ) = 1 * 1 ORDER BY case1228 / 1 DESC ) THEN case1228 + case1228 * 1 + 1.000000 END ) END ) + case1228 / 1 + 1 END ) < case1228 + case1228 + case1228 ) NOT NULL CHECK ( case1228 = 1 ) ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1229;
drop table case1229;
CREATE TABLE case1229 ( case1229 INT PRIMARY KEY CHECK ( CASE WHEN case1229 = ( SELECT case1229 FROM case1229 WHERE ( 'case1229' ) GROUP BY case1229 HAVING case1229 ( ) > 1 OR case1229 ( case1229 ) = case1229 ( case1229 ) ) THEN 'case1229' WHEN case1229 > 1 OR CASE WHEN ( SELECT 1 FROM ( SELECT case1229 ( case1229 ( case1229 ) , case1229 ) ISNULL FROM case1229 ORDER BY - case1229 , case1229 ) AS case1229 WHERE case1229 = 'case1229' OR case1229 ( case1229 ( ) ) = case1229 OR case1229 = 'case1229' GROUP BY case1229 , case1229 , case1229 ) THEN ( - case1229 ( 1 ) ) ELSE ( 1 * case1229 ) END AND - case1229 ( 1 ) >= case1229 OR ( SELECT case1229 FROM ( SELECT case1229 ) AS case1229 WHERE case1229 = ( SELECT case1229 FROM case1229 AS case1229 JOIN case1229 ON ( ( ( SELECT case1229 ( case1229 , CASE WHEN 1 THEN 'case1229' WHEN case1229 = 1 AND case1229 ( 1.000000 ) AND case1229 = 1 AND case1229 = 1 OR case1229 = 1 AND ( case1229 = 1 OR case1229 = 1 OR case1229 = 1 ) THEN 'case1229' ELSE 'case1229' END , CASE 1 WHEN 1 THEN 'case1229' WHEN 1 THEN 'case1229' ELSE 'case1229' END ) , 1 , 'case1229' ) ) , 1 ) = case1229 WHERE ( - 'case1229' >= case1229 AND case1229 = 1 * 1 ) ) ) THEN 'case1229' ELSE 'case1229' END ) ) ;
INSERT INTO case1229 ( case1229 ) VALUES ( 78 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1230;
drop table case1230;
CREATE TABLE case1230 ( v1 INTEGER CHECK ( ( SELECT ( SELECT v1 + v1 AS b_plus_one ) ) ) ) ;
 INSERT INTO case1230 SELECT TOP 0 1 FROM case1230 WHERE 'xwvutsr' < 0 GROUP BY CUBE ( v1 , 1 ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1231;
drop view case1231;
CREATE VIEW case1231 ( v1 ) AS SELECT CASE WHEN 1 THEN 10 WHEN 9223372036854775807 THEN 'wait/lock/table/sql/handler' ELSE 'ignored_db' END ;
 SELECT 0 , 'x' AS remain FROM case1231 ORDER BY * ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1232;
drop table case1232;
CREATE TABLE case1232 ( v1 DATE NULL ) ;
 UPDATE case1232 SET v1 = v1 + 2 WHERE v1 IN ( SELECT v1 , SUM ( v1 ) AS zero_value FROM case1232 AS negative_value CROSS JOIN case1232 ON ( '\$.datetime(HH24:MI:SS).type()' ) ) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1233;
drop table case1233;
CREATE TABLE case1233 ( v1 DATE NULL ) ;
 INSERT INTO case1233 ( v1 , v1 ) VALUES ( 72057594037927935 , '-675 seconds' ) ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


set U{caseno} case1235;
DROP TABLE case1235t0;

CREATE TABLE case1235t0(c0 INT, c1 INT, PRIMARY KEY(c0));
INSERT INTO case1235t0 (c0, c1) VALUES (1, 1);
INSERT INTO case1235t0 (c0) VALUES (-1);

SELECT * FROM case1235t0; -- -1 NULL, 1 1
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " total rows=" $ROWCNT  " \n";

SELECT * FROM case1235t0 WHERE SIGN(case1235t0.c1);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " filter on sign() rows=" $ROWCNT  " \n";

SELECT FLOOR(case1235t0.c1) FROM case1235t0; -- NULL, 1
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " ck floor() ret 1/null rows=" $ROWCNT  " \n";

SELECT * FROM case1235t0 WHERE FLOOR(case1235t0.c1);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " filter on int with nulls in set rows=" $ROWCNT  " \n";

set U{caseno} case1235;
DROP TABLE case1236t0;
DROP TABLE case1236t1;

CREATE TABLE case1236t0(c0 VARCHAR);
CREATE TABLE case1236t1(c1 INTEGER);
INSERT INTO case1236t1 (c1) VALUES (2);

SELECT * FROM case1236t1 LEFT  JOIN case1236t0 ON 1; -- 2 NULL
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " oj on true rows=" $ROWCNT  " \n";

SELECT * FROM case1236t1 LEFT  JOIN case1236t0 ON 1 WHERE case1236t0.c0; -- 2 NULL (unexpected)
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " oj on true with false filter rows=" $ROWCNT  " \n";

SELECT * FROM case1236t1 LEFT  JOIN case1236t0 ON 1 WHERE case1236t0.c0 IS NULL; -- 2 NULL
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " oj on true with true filter rows=" $ROWCNT  " \n";

set U{caseno} case1238;
DROP TABLE case1238t0;
DROP TABLE case1238t1;

CREATE TABLE case1238t0(c0 VARCHAR(500));
CREATE TABLE case1238t1(c0 INT, c1 INT);
INSERT INTO case1238t1 (c0) VALUES (1);
INSERT INTO case1238t1 (c1) VALUES (2);
INSERT INTO case1238t0 (c0) VALUES ('a');

SELECT case1238t1.c0 FROM case1238t1 LEFT  JOIN case1238t0 ON case1238t1.c1 WHERE (NOT NULL) UNION ALL SELECT case1238t1.c0 FROM case1238t1 LEFT  JOIN case1238t0 ON case1238t1.c1 WHERE ((NULL) IS NULL) order by 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH " $U{caseno} union on oj left with always true and null is rset last result " $last[1] "\n"; 


set U{caseno} case1239;
DROP TABLE case1239t0;
DROP TABLE case1239t1;
CREATE TABLE case1239t0(c0 INT, c1 VARCHAR(500), c2 INTEGER, PRIMARY KEY(c1));
CREATE TABLE case1239t1(c0 INTEGER);
--INSERT INTO case1239t0(c0, c1) VALUES ('x','');
INSERT INTO case1239t0(c0, c1) VALUES ('\x65\xe1\x8a\xa7', '');

SELECT * FROM case1239t1 LEFT  JOIN case1239t0 ON (CASE 1 WHEN 2 THEN A(case1239t0.c2) ELSE 3 END );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH " $U{caseno} union on oj left with always true simple case STATE=" $STATE " MESSAGE=" $MESSAGE "\n"; 


set U{caseno} case1241;
DROP TABLE case1241t0;
DROP TABLE case1241t1;
CREATE TABLE case1241t0(c0 INT);
CREATE TABLE case1241t1(c1 INT);
INSERT INTO case1241t1 (c1) VALUES (1);

SELECT case1241t0.c0 FROM case1241t1 LEFT  JOIN case1241t0 ON 1 ORDER BY 1 DESC;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH " $U{caseno} oj left on always true and oby produces " $LAST[1] "\n";

set U{caseno} case1249;
DROP TABLE case1249t0;
DROP TABLE case1249t1;

CREATE TABLE case1249t0(c0 VARCHAR(500), PRIMARY KEY(c0));
CREATE TABLE case1249t1(c0 INTEGER, PRIMARY KEY(c0));
INSERT INTO case1249t1(c0) VALUES (1);


SELECT * FROM case1249t1, case1249t0 WHERE ((case1249t0.c0)>((CASE case1249t1.c0 WHEN 'a' THEN NULL END )));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{caseno} case1250;
DROP TABLE case1250t0;
DROP TABLE case1250t1;

CREATE TABLE case1250t0(c0 INT);
CREATE TABLE case1250t1(c0 VARCHAR(500));
INSERT INTO case1250t0 (c0) VALUES (1);
INSERT INTO case1250t1 (c0) VALUES ('a');

SELECT * FROM case1250t0 LEFT  JOIN case1250t1 ON (NULL IN ('')); -- 1 NULL
SELECT * FROM case1250t0 LEFT  JOIN case1250t1 ON (NULL IN ('')) WHERE 1; -- 1 NULL
SELECT * FROM case1250t0 LEFT  JOIN case1250t1 ON (NULL IN ('')) WHERE 1 UNION ALL SELECT * FROM case1250t0 LEFT  JOIN case1250t1 ON (NULL IN ('')) WHERE (NOT 1);
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $U{caseno} " t1.c0=" $LAST[2]  " \n";

ECHO BOTH "COMPLETED: SQL Optimizer tests (sqlo.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";

