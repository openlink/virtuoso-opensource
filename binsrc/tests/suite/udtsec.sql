--
--  $Id: udtsec.sql,v 1.4.10.1 2013/01/02 16:15:37 source Exp $
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
echo BOTH "\nSTARTED: SQL200n user defined types security suite $U{TYPE} types (udtsec.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop type U1_T1;
drop type U1_T2;
drop type U1_T3;
drop type U1_T4;
drop type ERR_U1_T3;
drop type DBA_T1;

drop user U1;
drop user U2;

create user U1;
create user U2;

create type DBA_T1 as (ID int)
$U{UDTKIND}
method I1 () returns integer,
static method S1 () returns integer,
method I2 () returns integer,
static method S2 () returns integer
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1 declared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method I1 () for DBA_T1
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1's method i1 defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create static method S1 () for DBA_T1
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1's method s1 defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DBA_T1 ().ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1 instantiable STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect U1;

select new DBA_T1 ().ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1 not accessible for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type ERR_U1_T1;
create type ERR_U1_T1 under DBA_T1 as (ID2 int)
$U{UDTKIND}
;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": U1 unable to make subtype of DBA_T1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type DB.DBA.ERR_U1_T2;
create type DB.DBA.ERR_U1_T2 as (ID int)
;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": U1 unable to make DBA type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method I1 () for DBA_T1
{
  return 12;
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1's method I1 defined by U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

grant EXECUTE on DBA_T1 to U1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba grants execute to U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect U1;

select new DBA_T1 ().ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1 accessible for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type ERR_U1_T3;
create type ERR_U1_T3 under DBA_T1 as (ID2 int)
$U{UDTKIND}
;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": U1 unable to make subtype of DBA_T1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method I1 () for DBA_T1
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1's method I1 defined by U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

grant UNDER on DBA_T1 to U1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba grants under to U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect U1;

drop type U1_T4;
create type U1_T4 under DBA_T1 as (ID2 int)
$U{UDTKIND}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": U1 able to make subtype of DBA_T1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type U1_T4;

reconnect dba;

drop type DBA_T1;
create type DBA_T1 as (ID int)
$U{UDTKIND}
method I1 () returns integer,
static method S1 () returns integer,
method I2 () returns integer,
static method S2 () returns integer
;

reconnect U1;

select new DBA_T1 ().ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type DBA_T1 not accessible again for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- security over methods tests
reconnect dba;

drop type A;
create type A as (X varchar)
	method A1 () returns int,
	static method A2() returns int;

create constructor method A () for A
{
  return;
}
;

create method A1 () for A
{
  return 1;
}
;

create static method A2 () for A
{
  return 2;
}
;


select new A().A1();
select A::A2();



reconnect U1;


select new A().A1();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type A not accessible for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select A::A2();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method A2 not accessible for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new A().X;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type A not accessible for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


reconnect dba;
grant EXECUTE on A to U1;

reconnect U1;


select new A().A1();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A().A1 () is accessible for U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select A::A2();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A::A2() is accessible again U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new A().X;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type A is accessible again U1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED: SQL200n user defined types security suite $U{TYPE} types (udtsec.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
