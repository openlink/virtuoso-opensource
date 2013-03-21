--  
--  $Id$
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
echo BOTH "STARTED: USER ROLE FILLING tests\n";
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

drop table "ROLE_TEST";

--exit 1;

create table "ROLE_TEST" (id integer primary key, dt varchar);

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
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": revoke D from B (should trigger revoke from A) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'A' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to A : " $LAST[1] "\n";

select count(*) from sys_role_grants, sys_users where gi_super = u_id and u_name = 'B' and u_is_role = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": roles granted to B : " $LAST[1] "\n";


grant select on "ROLE_TEST" to C;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant select on ROLE_TEST to C : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant B to RUSR with admin option;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant B to RUSR w/ admin option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH ": insert into ROLE_TEST table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: USER ROLE FILLING tests\n";
