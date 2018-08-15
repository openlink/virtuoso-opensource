--
--  $Id: tcheck.sql,v 1.3.10.1 2013/01/02 16:15:00 source Exp $
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
echo BOTH "STARTED: CHECK constraint tests\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table TCHKC1;
drop table TCHKC2;
drop table TCHKC3;
drop table TCHKC4;


create table TCHKC1 (ID integer primary key, CK integer check (CK <> 10));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table TCHKC1 created with CHECK keyword : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table TCHKC2 (ID integer primary key, CK integer, check (CK <> 10));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table TCHKC2 created with CHECK constraint declaration (w/o constraint name) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table TCHKC3 (ID integer primary key, CK1 integer, CK2 integer, constraint CK3 CHECK (CK1 <> 10 and CK2 <> 10));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table TCHKC3 created with constraint name CK3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table TCHKC4 (ID integer primary key, CK1 integer, CK2 integer);


alter table TCHKC4 add constraint CK4 check (CK1 <> 10 and CK2 <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CHECK constraint CK4 added to the table TCHKC4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- success inserts tests
insert into TCHKC1 values (100, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC2 values (100, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC3 values (100, 1, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC4 values (100, 1, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- failure inserts tests
insert into TCHKC1 values (101, 10);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC2 values (101, 10);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC3 values (101, 10, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC3 values (101, 1, 10);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC3 col 2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC4 values (101, 10, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC4 values (101, 1, 10);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to violate check in TCHKC4 col 2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--failure updates
update TCHKC4 set CK1 = 10 , CK2 = 1 where ID = 100;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to update a row in TCHKC4 violate CHECK : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHKC4 set CK1 = 1 , CK2 = 10 where ID = 100;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to update a row in TCHKC4 violate CHECK col 2: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--success updates
update TCHKC4 set CK1 = 2 , CK2 = 2 where ID = 100;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to update a row in TCHKC4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TCHKC1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table TCHKC1 contains " $LAST[1] " rows after insert\n";

select count (*) from TCHKC2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table TCHKC2 contains " $LAST[1] " rows after insert\n";

select count (*) from TCHKC3;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table TCHKC3 contains " $LAST[1] " rows after insert\n";

select count (*) from TCHKC4;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table TCHKC4 contains " $LAST[1] " rows after insert\n";

alter table TCHKC4 drop constraint CK4;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CHECK constraint CK4 dropped from the table TCHKC4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select C_TABLE, C_TEXT from SYS_CONSTRAINTS;
select * from TCHKC4;

insert into TCHKC4 values (101, 10, 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to insert 10, 10 in TCHKC4 after constraint removal : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TCHKC4;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking constraint removal - Table TCHKC4 (without CHECK constraint) contains " $LAST[1] " rows after insert\n";

alter table TCHKC4 add constraint CK4 check (CK1 <> 10 and CK2 <> 10);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to create CHECK constraint on table TCHKC4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table TCHKC1 drop CHECK (CK <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CHECK constraint CK4 dropped from the table TCHKC1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHKC1 values (101, 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to insert 10 in TCHKC1 after constraint removal : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TCHKC1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking constraint removal - Table TCHKC1 (without check constraint) contains " $LAST[1] " rows after insert\n";

drop table TCHKC4;
create table TCHKC4 (ID integer primary key, CK1 integer, CK2 integer);

alter table TCHKC4 add constraint CK4 check (CK1 <> 10 and CK2 <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - adding a CHECK constraint CK4 after table drop and recreate : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.OWN1.TCHKC_1;
create table DB.OWN1.TCHKC_1 (ID integer primary key, CK integer check (CK <> 10));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table DB.OWN1.TCHKC_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.OWN2.TCHKC_1;
create table DB.OWN2.TCHKC_1 (ID integer primary key, CK integer check (CK <> 10));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking internal name of the constraint Table DB.OWN2.TCHKC_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table DB.OWN2.TCHKC_1 drop check (CK <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping the constraint on table DB.OWN2.TCHKC_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table DB.OWN1.TCHKC_1 drop check (CK <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping the constraint on table DB.OWN1.TCHKC_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table DB.OWN2.TCHKC_1 add check (CK <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding the constraint on table DB.OWN2.TCHKC_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


alter table DB.OWN1.TCHKC_1 add check (CK <> 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding the constraint on table DB.OWN1.TCHKC_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: CHECK constraint tests\n";
