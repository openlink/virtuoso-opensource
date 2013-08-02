--
--  tview.sql
--
--  $Id: tview.sql,v 1.14.10.2 2013/01/02 16:15:33 source Exp $
--
--  UNION and VIEW tests
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

select ROW_NO from T1 union select ROW_NO + 5 from T1 union all select ROW_NO from T1;
ECHO BOTH $IF $EQU $ROWCNT 45 "PASSED" "***FAILED";
ECHO BOTH ": UNION / UNION ALL " $ROWCNT " rows\n";

select R, RR from (select ROW_NO as R from T1) X, (select ROW_NO as RR from T1) Y where R < 200 and RR = R;
select R, RR from (select ROW_NO as R from T1) X, (select ROW_NO as RR from T1) Y where X.R < 200 and Y.RR = X.R;
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": Join 2 derived tables " $ROWCNT " rows\n";

drop view T1_LOW;
create view T1_LOW (R, STRING1, STRING2) as select ROW_NO, STRING1, STRING2 from T1 where ROW_NO < 500;
select ROW_NO from (select ROW_NO from T1 union select ROW_NO + 10 from T1) f;
ECHO BOTH $IF $EQU $ROWCNT 30 "PASSED" "***FAILED";
ECHO BOTH ": UNION derived table " $ROWCNT " rows\n";


select ROW_NO from (select ROW_NO from T1 union all select ROW_NO + 10 from T1) f order by ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": UNION ALL derived table ORDER BY " $ROWCNT " rows\n";

select V1.R, V2.R from T1_LOW V1 left outer join T1_LOW V2 on (V2.R = V1.R + 5);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": Outer join of view " $ROWCNT " rows\n";

select a.r,  b.r from t1_low a left join (select distinct c.r from t1_low c table option (hash)) b on b.r = a.r + 5 option (hash, order);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": Outer join of view in distinct dt " $ROWCNT " rows\n";


select V1.R, V2.R from T1_LOW V1 left outer join T1_LOW V2 on (V2.R = V1.R + 5) where V2.R is NULL;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": Outer join of view " $ROWCNT " rows\n";

update T1_LOW set STRING1 = 'fff' where R = 100;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": View update " $ROWCNT " rows\n";

drop view T1_EXP;
create view T1_EXP (R1, R2, R3) as select ROW_NO, ROW_NO + 1, ROW_NO + 2 from T1;
update T1_EXP set R1 = 100 where R3 = 102;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": View update w/ exp column " $ROWCNT " rows\n";

update T1_EXP set R1 = 100, R2 = 101 where R3 = 102;
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";
ECHO BOTH ": Update expression column. State " $STATE "\n";

select * from T1_EXP A left outer join T1_EXP B on A.R1 + 12 = B.R1;
select B.* from T1_EXP A left outer join T1_EXP B on A.R1 + 12 = B.R1;
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": View outer join " $ROWCNT " rows\n";

select * from (select * from T1_EXP union all  select * from T1_EXP) F;
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": View union " $ROWCNT " rows\n";


select 1 as no  from T1 union select 2 from T1;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": union of 2 constants  " $ROWCNT " rows\n";

insert into T1 (ROW_NO, STRING1, STRING2) select ROW_NO + 200, STRING1, STRING2 from T1 where ROW_NO < 200;
drop view T1_HIGH;
create view T1_HIGH (ROW_NO, STRING1, STRING2) as select ROW_NO, STRING1, STRING2 from T1 where ROW_NO > 200;
delete from T1_HIGH where ROW_NO = 300;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": View delete " $ROWCNT " rows\n";

delete from T1_HIGH;
ECHO BOTH $IF $EQU $ROWCNT 19 "PASSED" "***FAILED";
ECHO BOTH ": View delete " $ROWCNT " rows\n";

drop view T1_F_L;
create view T1_F_L as select * from T1 where ROW_NO < 200 union select * from T1 where ROW_NO >= 200;
select * from T1_F_L;
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": select * from union select * view " $ROWCNT " rows\n";

delete from T1_F_L;
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";
ECHO BOTH ": Delete of union. State " $STATE "\n";

drop view words_v;
create view words_v as select * from words where word between 'v' and 'w';
select count (*) from words_v where len <> 6;
ECHO BOTH $IF $EQU $LAST[1] 1738 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " words in words_v with len <> 6\n";

select count (*) from words_v where len = 6;
ECHO BOTH $IF $EQU $LAST[1] 241 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " words in words_v with len = 6\n";

select *, 1 from T1 union all select *, 2 from T1 order by ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": sorted union all " $rowcnt "  rows\n";

drop table TVUPDATE;
create table TVUPDATE (ROW_NO integer not null primary key, STRING1 varchar, STRING2 varchar);
drop view TVUPDATE_LOW;
create view TVUPDATE_LOW (R, STRING1, STRING2) as select ROW_NO, STRING1, STRING2 from TVUPDATE where ROW_NO < 500;
drop view TVUPDATE_LOW_10;
create view TVUPDATE_LOW_10 as select R, R + 10 as R2 from TVUPDATE_LOW;

insert into TVUPDATE (ROW_NO) values (199);

insert into TVUPDATE_LOW  values (200, 's1', 's2');

insert into TVUPDATE_LOW_10 values (300, 310);
insert into TVUPDATE_LOW_10 (R) values (310);

select * from TVUPDATE_LOW_10;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": inserted into view  " $ROWCNT "  rows\n";

delete from TVUPDATE_LOW_10 where R >= 200;
select * from TVUPDATE_LOW_10;
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED" "***FAILED";
ECHO BOTH ": deld from inserted view, now " $rowcnt "  rows\n";

drop view TVUPDATE;
select * from TVUPDATE_LOW_10;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": trying to select from a view on a non-existent object STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create view TEST_ALIASES as select TVUPDATE.* from DB.DBA.SYS_USERS TVUPDATE;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": view with alias name equal to existent table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- test suite for bug 1243
use BUG1243;

drop table TB;
create table TB (ID int not null primary key, DATA varchar);
insert into TB (ID, DATA) values (1, 'A');

drop view V1;
drop view V2;

create view V1 as select ID, DATA from TB;

alter table V1 rename V2;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG1243: rename a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table V1 add DATA2 varchar;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG1243: add column to a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table V1 drop DATA;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG1243: drop column from a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table V1 modify DATA varchar (10);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG1243: rename a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

columns V1;
select * from V1;
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED" "***FAILED";
ECHO BOTH ": BUG1243: view unmodified STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

use DB;

select * from (select U_NAME, U_NAME as name from SYS_USERS where lower (U_NAME) = 'dba') x;
ECHO BOTH $IF $EQU $LAST[2] $LAST[1]  "PASSED" "***FAILED";
ECHO BOTH ": BUG1377: aliased column in a DT = " $LAST[2] "\n";


drop view BUG1709V;
drop view BUG1709_BASE;
create view BUG1709_BASE as select U_NAME, U_GROUP from SYS_USERS where U_ID < 50;
create view BUG1709V as select U_GROUP, count (U_NAME) as U_NAMEC from BUG1709_BASE group by U_GROUP order by U_NAMEC;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG1709: expanding COUNT() in AS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop view B5167;
drop procedure B5167;
CREATE VIEW B5167(TEST_ID) AS SELECT 0;
create procedure B5167(){DELETE FROM B5167 WHERE TEST_ID = 0;};
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG5167: delete from non-table_exp view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
