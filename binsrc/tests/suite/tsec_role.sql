--
--  $Id$
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
echo BOTH "STARTED: USER ROLE tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop role A;
drop role B;
drop role C;
drop role D;
drop role CYCL;
drop role F;

delete user RUSR;

drop table ROLE_TEST;

--exit 1;

create table ROLE_TEST (id integer primary key, dt varchar);

create role A;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role A : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create role B;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role B : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create role B;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role B (duplicate) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create role C;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role C : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create role D;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role D : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create role F;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role F : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create role CYCL;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create role CYCL : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create user RUSR;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create user RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


grant C, D to B with admin option;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant C, D to B with admin option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant C, D to CYCL with admin option;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant C, D to CYCL with admin option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant B to A;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant B to A (w/o admin option) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant A to F;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant A to F (w/o admin option) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'A' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to A : " $LAST[1] "\n";


select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'B' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to B : " $LAST[1] "\n";

select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'F' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to F : " $LAST[1] "\n";

revoke D from B;
-- XXX
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": revoke D from B (should trigger revoke from A) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'A' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to A : " $LAST[1] "\n";

select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'B' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to B : " $LAST[1] "\n";


grant select on ROLE_TEST to C;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant select on ROLE_TEST to C : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant B to RUSR with admin option;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant B to RUSR w/ admin option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect RUSR;

select USER;
ECHO BOTH $IF $EQU $LAST[1] RUSR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": connected as : " $LAST[1] "\n";

select * from ROLE_TEST;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select to ROLE_TEST table is granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update ROLE_TEST set ID = ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update to ROLE_TEST table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into ROLE_TEST (id) values (1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into ROLE_TEST table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from ROLE_TEST;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete from ROLE_TEST table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

select USER;
ECHO BOTH $IF $EQU $LAST[1] dba "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": connected as : " $LAST[1] "\n";

grant CYCL to C with admin option;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant CYCL to C with admin option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

USER_CREATE('WebCal', '991f5070ad647438986fd5d19c83123e', vector('LOGIN_QUALIFIER', 'WebCal',
	    'FULL_NAME', 'PHP WebCalendar Demo user'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #4604 create user : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select u_name, u_group, adm_users_def_qual(u_data) from sys_users;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #4604 select from sys_user : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: USER ROLE tests\n";

echo BOTH "STARTED: USER ROLE indirect tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

reconnect dba;

drop role A;
drop role B;
drop role C;
drop role D;
drop role CYCL;
drop role F;

select * from SYS_ROLE_GRANTS;
SET U{CNT} $+ $ROWCNT 3;
ECHO BOTH "U_CNT=" $U{CNT} "\n";

create user a;
create role b;
create role c;
grant b to a;
grant c to b;

select * from SYS_ROLE_GRANTS;
ECHO BOTH $IF $EQU $ROWCNT $U{CNT} "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SYS_ROLE_GRANTS cnt:" $ROWCNT "\n";

revoke b from a;
revoke c from b;

grant c to b;
grant b to a;

select * from SYS_ROLE_GRANTS;
ECHO BOTH $IF $EQU $ROWCNT $U{CNT} "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SYS_ROLE_GRANTS cnt:" $ROWCNT "\n";

revoke b from a;
revoke c from b;
drop role c;
drop role b;
drop user a;

-- public as a role suite
drop role PUBLIC_ROLE_XU;
delete user PUBLIC_ROLE_U1;
drop table PUBLIC_ROLE_X;

create table PUBLIC_ROLE_X (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": public as role 1 : table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create user PUBLIC_ROLE_U1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": public as role 2 : user created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create role PUBLIC_ROLE_XU;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": public as role 3 : role created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant select on PUBLIC_ROLE_X to PUBLIC_ROLE_XU;
-- XXX
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": public as role 4 : select granted to role : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant PUBLIC_ROLE_XU to public;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": public as role 5 : role granted to public : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect PUBLIC_ROLE_U1;
select * from PUBLIC_ROLE_X;
-- XXX
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": public as role 6 : user has access : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;
revoke PUBLIC_ROLE_XU from public;
-- XXX
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": public as role 7 : role revoked from public : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect PUBLIC_ROLE_U1;
select * from PUBLIC_ROLE_X;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": public as role 8 : user has no access : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;
drop role PUBLIC_ROLE_XU;
drop user PUBLIC_ROLE_U1;
drop table PUBLIC_ROLE_X;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: USER ROLE tests\n";
