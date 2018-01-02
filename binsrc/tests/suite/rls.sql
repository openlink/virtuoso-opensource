--
--  rls.sql
--
--  $Id: rls.sql,v 1.4.10.2 2013/01/02 16:14:53 source Exp $
--
--  Row level security tests
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

echo BOTH "\nSTARTED: SQL Row level security tests (rls.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure RLS_P1 (in TB_NAME varchar, in OP varchar) { return ''; };
create procedure RLS_PERR () { return ''; };
create procedure RLS_PPROT (in TB_NAME varchar, in IN_OP varchar) { return 'exists (select 1 from DB.DBA.RLS_PROT) and DATA is not null'; };
create user RLS_USR;

reconnect RLS_USR;

create procedure RLS_P2 (in TB_NAME varchar, in OP varchar) { return 'DATA is not null'; };
create procedure RLS_PERR2 () { return ''; };

create procedure RLS_PVP () { declare ID INTEGER; declare DATA1 varchar; result_names (ID, DATA1); result (1,'a'); result (2, 'b'); };
create procedure RLS_SV_POL (in TB varchar, in OP varchar) { return 'ID = 1'; };

reconnect dba;

DB.DBA.TABLE_SET_POLICY ('RLS_T11', 'RLS_P1', 'S');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS no table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('RLS_T1', 'RLS_P11', 'S');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS no procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('RLS_T1', 'RLS_P1', 'Z');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS wrong option STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('RLS_T1', 'RLS_PERR', 'S');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS wrong procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.SYS_RLS_POLICY;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS no RLS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('RLS_T1', 'RLS_P1', 'IUDS');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS IDUS defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.SYS_RLS_POLICY;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_DROP_POLICY ('RLS_T11');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS wrong table on drop STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_DROP_POLICY ('RLS_T1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS drop STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.SYS_RLS_POLICY;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS table empty after drop STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect RLS_USR;

DB.DBA.TABLE_SET_POLICY ('RLS_T1', 'RLS_P2', 'IDUS');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS policy on non-owned table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('RLS_T2', 'RLS_P2', 'IDUS');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS policy defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;
select * from DB.DBA.SYS_RLS_POLICY;

delete from RLS_T2;
insert into RLS_T2 (ID, DATA) values (1, NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS ignored for dba on insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update RLS_T2 set DATA = 'DBA' where ID = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS ignored for dba on update 1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update RLS_T2 set DATA = NULL where ID = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS ignored for dba on update 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RLS_T2 where DATA is NULL;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS ignored for dba on delete STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RLS_T2 (ID, DATA) values (1, NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS ignored for dba on insert 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from RLS_T2;
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS has a RLS violating row STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect RLS_USR;

select * from RLS_T2;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS in effect for non-DBA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from RLS_T2 where ID = 1;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS in effect for non-DBA even w/ violating row STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RLS_T2 (ID, DATA) values (2, NULL);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS in effect for non-DBA insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RLS_T2 (ID, DATA) values (2, 'RLS_USR');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS insert valid allowed w/ RLS in effect for non-DBA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from RLS_T2;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS select hides RLS protected rows for non-DBA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

UPDATE RLS_T2 set DATA = NULL where ID = 2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS prevents restricted updates for non-DBA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from RLS_T2 where ID = 2;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS merges to where for non-DBA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DELETE from RLS_T2 where ID = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS searched delete w/o error because of select RLS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from RLS_T2;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS unproteced row still here after delete RLS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DELETE from RLS_T2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS searched delete w/o cond pass w/o error because of select RLS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table RLS_T3 (ID integer primary key, DATA varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS table RLS_T3 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.RLS_PPROT ('DB.RLS_USR.RLS_T3', 'S');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS_USR cannot call the DB.DBA.RLS_PPROT procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.RLS_PROT;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS_USR cannot access the DB.DBA.RLS_PROT table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('RLS_T3', 'DB.DBA.RLS_PPROT', 'IDUS');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS_USR cannot make the DB.DBA.RLS_PPROT a policy procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

grant execute on DB.DBA.RLS_PPROT to RLS_USR;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba grants exec on DB.DBA.RLS_PPROT to RLS_USR STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect RLS_USR;

DB.DBA.TABLE_SET_POLICY ('DB.RLS_USR.RLS_T3', 'DB.DBA.RLS_PPROT', 'IDUS');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS_USR can make the DB.DBA.RLS_PPROT a policy procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


insert into DB.RLS_USR.RLS_T3 (ID, DATA) values (1, 'A');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS_USR can insert into RLS_T3 w/ DBA policy procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.RLS_USR.RLS_T3 (ID, DATA) values (2, NULL);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBA policy works for RLS_USR@RLS_T3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

select * from RLS_T2;
-- XXX
--ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": RLS protected row still here after non-DBA delete RLS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- user_has_role stuff
drop role HAS_ROLE_STAFF;
drop role HAS_ROLE_SECURITY_AUDITOR;
Create role HAS_ROLE_STAFF;
Create role HAS_ROLE_SECURITY_AUDITOR;
Grant HAS_ROLE_STAFF to HAS_ROLE_SECURITY_AUDITOR;

select user_has_role ('HAS_ROLE_SECURITY_AUDITOR', 'HAS_ROLE_STAFF');
-- XXX
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": user_has_role 1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select user_has_role ('HAS_ROLE_SECURITY_AUDITOR', 'HAS_ROLE_STAFF2');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user_has_role 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect RLS_USR;
-- RLS & views

explain ('select * from RLS_SV');
explain ('select * from RLS_PV');
select * from RLS_SV;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS 2 rows in a VIEW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select * from RLS_PV;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS 2 rows in a proc VIEW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('DB.RLS_USR.RLS_SV', 'DB.RLS_USR.RLS_SV_POL', 'S');
DB.DBA.TABLE_SET_POLICY ('DB.RLS_USR.RLS_PV', 'DB.RLS_USR.RLS_SV_POL', 'S');

DB.DBA.TABLE_SET_POLICY ('DB.RLS_USR.RLS_SV', 'DB.RLS_USR.RLS_SV_POL', 'U');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no update policy for views STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TABLE_SET_POLICY ('DB.RLS_USR.RLS_PV', 'DB.RLS_USR.RLS_SV_POL', 'D');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no update policy for proc views STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select * from RLS_SV');
explain ('select * from RLS_PV');
select * from RLS_SV;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS 1 rows in a RLS VIEW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from RLS_PV;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RLS 1 rows in a RLS proc VIEW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- End of test
--
ECHO BOTH "COMPLETED: SQL Row level security tests (rls.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
