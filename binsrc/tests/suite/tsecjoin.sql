--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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
-- Regression test for a SELECT-privilege bypass in the SQL optimizer's
-- unqualified-column resolution (Wi/sqlo.c, sco_is_defd()): the shared
-- `col` variable was reassigned by ot_is_defd() on every table in the
-- scope, not just a matching one, so a later table in the FROM list that
-- did not have the referenced column silently clobbered the match found
-- on an earlier, ungranted table and skipped the access check entirely.
-- SECPROBE has no grant at all for SECPROBE_USR; SECPROBE2/SECPROBE3 are
-- granted so a join with them cannot be refused for the wrong reason.
--

echo BOTH "STARTED: SELECT-privilege enforcement across joins/derived tables tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table SECPROBE;
drop table SECPROBE2;
drop table SECPROBE3;
drop user SECPROBE_USR;

create table SECPROBE  (ID  integer primary key, TXT    varchar);
create table SECPROBE2 (ID2 integer primary key, OTHER2 varchar);
create table SECPROBE3 (ID3 integer primary key, OTHER  varchar);

insert into SECPROBE  values (1, 'secret-alpha');
insert into SECPROBE  values (2, 'secret-beta');
insert into SECPROBE2 values (1, 'y1');
insert into SECPROBE3 values (1, 'z1');

create user SECPROBE_USR;
grant select on SECPROBE2 to SECPROBE_USR;
grant select on SECPROBE3 to SECPROBE_USR;

reconnect SECPROBE_USR;

--
-- Sanity: no grant at all on SECPROBE, so a direct single-table reference
-- must be denied. If this ever starts passing, the fixture is broken and
-- every check below is meaningless.
--
select TXT from SECPROBE;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE; (no grant, single table) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- These shapes were never broken; they guard against a fix that overcorrects.
--
select * from SECPROBE;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from SECPROBE; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from SECPROBE;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select count(*) from SECPROBE; (no column named) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from SECPROBE order by TXT;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE order by TXT; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from (select TXT from SECPROBE) x;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from (select TXT from SECPROBE) x; (derived table wrapping it) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (select top 1 TXT from SECPROBE) as d;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select (select top 1 TXT from SECPROBE) as d; (scalar subquery) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select s.TXT from SECPROBE s cross join SECPROBE3;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select s.TXT from SECPROBE s cross join SECPROBE3; (qualified ref, granted table after) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from SECPROBE3 cross join SECPROBE;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE3 cross join SECPROBE; (protected table LAST) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select OTHER from SECPROBE cross join SECPROBE3;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select OTHER from SECPROBE cross join SECPROBE3; (no column from the protected table) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- These are the shapes that used to leak: an unqualified reference to the
-- ungranted table's column, plus any second table (real or a trivial
-- derived table) anywhere in the FROM list.
--
select TXT from SECPROBE cross join SECPROBE3;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE cross join SECPROBE3; (unqualified, granted real table after) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select s.TXT from SECPROBE s cross join SECPROBE2 t;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select s.TXT from SECPROBE s cross join SECPROBE2 t; (qualified, granted table after) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from SECPROBE cross join (select 1 as v) qv;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE cross join (select 1 as v) qv; (unqualified, constant derived table) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from SECPROBE, (select 1 as v) qv;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE, (select 1 as v) qv; (comma join, constant derived table) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from SECPROBE inner join (select 1 as v) qv on (1=1);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE inner join (select 1 as v) qv on (1=1); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TXT from SECPROBE left join (select 1 as v) qv on (1=1);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select TXT from SECPROBE left join (select 1 as v) qv on (1=1); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from SECPROBE cross join (select 1 as v) qv;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select count(*) from SECPROBE cross join (select 1 as v) qv; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select qv.v from SECPROBE cross join (select 1 as v) qv where TXT = 'secret-alpha';
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select qv.v ... where TXT = 'secret-alpha'; (protected column in WHERE only) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Negative control: a join across two tables that ARE both granted must
-- still succeed -- the fix must not turn into a blanket denial.
--
select t2.OTHER2, t3.OTHER from SECPROBE2 t2 join SECPROBE3 t3 on (1=1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select t2.OTHER2, t3.OTHER from SECPROBE2 t2 join SECPROBE3 t3 on (1=1); (both granted) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " row(s) from the both-granted join\n";

select OTHER2 from SECPROBE2 cross join (select 1 as v) qv;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select OTHER2 from SECPROBE2 cross join (select 1 as v) qv; (granted table) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

drop table SECPROBE;
drop table SECPROBE2;
drop table SECPROBE3;
drop user SECPROBE_USR;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SELECT-privilege enforcement across joins/derived tables tests\n";
