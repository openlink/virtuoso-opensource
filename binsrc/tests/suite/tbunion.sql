--
--  $Id: tbunion.sql,v 1.9.10.1 2013/01/02 16:15:00 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

echo BOTH "STARTED: BEST UNION ALL & TOP tests\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table tbunion;
create table tbunion (key_id integer not null primary key);
foreach integer between 201 273 insert into tbunion (key_id) values (?);
foreach integer between 1001 1088 insert into tbunion (key_id) values (?);

select 2222, (U_ID + 1) / 0 from sys_users best union all select key_id, 1 / (1000 - key_id)  from tbunion;
ECHO BOTH $IF $EQU $ROWCNT 161 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": best union all w/h 1 / (1000 - key_id) return " $ROWCNT " lines\n";


select 2222, (U_ID + 1) / 0 from sys_users best union all select key_id, 1 / (1001 - key_id)  from tbunion;
ECHO BOTH $IF $EQU $ROWCNT 73 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": best union all w/h 1 / (1001 - key_id) return " $ROWCNT " lines\n";


select 2222, (U_ID + 1) / 0 from sys_users best union all select key_id, 1 / (1001 - key_id)  from tbunion where key_id > 0;
ECHO BOTH $IF $EQU $ROWCNT 73 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": best union all w/h 1 / (1001 - key_id) and key_id > 0 return " $ROWCNT " lines\n";




select '00000' as __sqlstate, '' as __message, NULL as __set_no, 2222, (U_ID + 1) / 0 from sys_users best union all select '00000' as __sqlstate, '' as __message, NULL as __set_no, key_id, 1 / (1001 - key_id)  from tbunion;
ECHO BOTH $IF $EQU $ROWCNT 75 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select '00000' as sql_st best union all w/h 1 / (1001 - key_id) return " $ROWCNT " lines\n";
ECHO BOTH $IF $NEQ $LAST[1] '00000' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bunion error row __SQLSTATE=" $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[2] '' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bunion error row __SQLMESSAGE=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bunion error row __SET_NO=" $LAST[3] "\n";


select * from (select '00000' as __sqlstate, '' as __message, 2222 as c1, (U_ID + 1) / 0 as c2 from sys_users best union all select '00000' as __sqlstate, '', key_id, 1 / (1001 - key_id)  from tbunion) f;
ECHO BOTH $IF $EQU $ROWCNT 75 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from '00000' as sql_st best union all w/h 1 / (1001 - key_id) return " $ROWCNT " lines\n";


select top 3 row_no from t1;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top 3 from T1 return " $ROWCNT " lines\n";

select * from (select top 3 row_no from t1) f;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from top 3 from T1 return " $ROWCNT " lines\n";


select top 3 row_no from t1 table option (index primary key) best union select top 3 row_no + 1 from t1 table option (index primary key);
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top 3 from T1 best union all top 3 row_no + 1 return " $ROWCNT " lines\n";


select * from (select top 3 row_no from t1 table option (index primary key)) f  best union select * from (select top 3 row_no + 1 as ff from t1 table option (index primary key)) f;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * top 3 from T1 best union all select * from top 3 row_no + 1 return " $ROWCNT " lines\n";

update t1 set fi6 = cast (row_no / 2 as integer);

select distinct top 3 fi6 from t1 order by fi6;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": distinct top 3 fi6 from T1 ordered by fi6 last row return " $LAST[1] "\n";


select top 3 fi6 from t1 order by fi6;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top 3 fi6 from T1 ordered by fi6 last row return " $LAST[1] "\n";


drop table t1_tmp;
create table t1_tmp (row_no integer not null primary key);

insert into t1_tmp select top 3 row_no from t1;

select count(*) from t1_tmp;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " rows from top 3 from T1 inserted into t1_tmp \n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: BEST UNION ALL & TOP tests\n";
