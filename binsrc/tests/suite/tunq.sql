--
--  $Id: tunq.sql,v 1.8.10.1 2013/01/02 16:15:31 source Exp $
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
echo BOTH "STARTED: UNIQUE constraint tests\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table UNQ1;
drop table UNQ2;
drop table UNQ3;
drop table UNQ4;


create table UNQ1 (id integer primary key, uq integer unique);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table UNQ1 created with unique keyword : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table UNQ2 (id integer primary key, uq integer, unique (uq));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table UNQ2 created with unique constraint declaration (w/o constraint name) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table UNQ3 (id integer primary key, uq1 integer, uq2 integer, constraint uq3 unique (uq1, uq2));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table UNQ3 created with constraint name uq3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table UNQ4 (id integer primary key, uq1 integer, uq2 integer);


alter table UNQ4 add constraint uq4 unique (uq1, uq2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UNIQUE constraint uq4 added to the table UNQ4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

foreach integer between 1 100 insert into UNQ1 values (?, ?);
foreach integer between 1 100 insert into UNQ2 values (?, ?);
foreach integer between 1 100 insert into UNQ3 values (?, ?, ?);
foreach integer between 1 100 insert into UNQ4 values (?, ?, ?);

insert into UNQ1 values (101, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to duplicate a row in UNQ1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UNQ2 values (101, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to duplicate a row in UNQ2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UNQ3 values (101, 1, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to duplicate a row in UNQ3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UNQ4 values (101, 1, 1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to duplicate a row in UNQ4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update UNQ4 set uq1 = 1 , uq2 = 1 where id = 100;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to update a row in UNQ4 (duplicate a 1-st row) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from UNQ4 where id = 100;

insert into UNQ4 values (100, null, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Adding a NULL values to the table UNQ4 (the constraint columns declared w/o not null) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select count (*) from UNQ1;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table UNQ1 contains " $LAST[1] " rows after insert\n";

select count (*) from UNQ2;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table UNQ2 contains " $LAST[1] " rows after insert\n";

select count (*) from UNQ3;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table UNQ3 contains " $LAST[1] " rows after insert\n";

select count (*) from UNQ4;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - Table UNQ4 contains " $LAST[1] " rows after insert\n";

alter table UNQ4 drop constraint uq4;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UNIQUE constraint uq4 dropped from the table UNQ4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UNQ4 values (101, 1, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to duplicate a row in UNQ4 after constraint removal : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UNQ4;
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking constraint removal - Table UNQ4 (without unique constraint) contains " $LAST[1] " rows after insert\n";

alter table UNQ4 add constraint uq4 unique (uq1, uq2);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to create UNIQUE constraint on table UNQ4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table UNQ1 drop unique (uq);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UNIQUE constraint uq4 dropped from the table UNQ1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UNQ1 values (101, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Trying to duplicate a row in UNQ1 after constraint removal : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UNQ1;
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking constraint removal - Table UNQ1 (without unique constraint) contains " $LAST[1] " rows after insert\n";

drop table UNQ4;
create table UNQ4 (id integer primary key, uq1 integer, uq2 integer);

alter table UNQ4 add constraint uq4 unique (uq1, uq2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking - adding a UNIQUE constraint uq4 after table drop and recreate : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.OWN1.UNQ_1;
create table DB.OWN1.UNQ_1 (id integer primary key, uq integer unique);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table DB.OWN1.UNQ_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.OWN2.UNQ_1;
create table DB.OWN2.UNQ_1 (id integer primary key, uq integer unique);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Checking internal name of the constraint Table DB.OWN2.UNQ_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table DB.OWN2.UNQ_1 drop unique (uq);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping the constraint on table DB.OWN2.UNQ_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table DB.OWN1.UNQ_1 drop unique (uq);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping the constraint on table DB.OWN1.UNQ_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table DB.OWN2.UNQ_1 add unique (uq);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding the constraint on table DB.OWN2.UNQ_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


alter table DB.OWN1.UNQ_1 add unique (uq);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding the constraint on table DB.OWN1.UNQ_1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table TT1;
create table TT1 (I1 integer identity, VAR1 varchar (10), primary key (I1));
insert into TT1 (VAR1) values ('aa_1');

SET_IDENTITY_COLUMN ('DB.DBA.TT1', 'I1', 102);

insert into TT1 (VAR1) values ('aa_6');

select max (I1) from TT1;
ECHO BOTH $IF $EQU $LAST[1] 102 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SET_IDENTITY_COLUMN : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- bug #8385
drop table CUNQ4;
drop table CUNQ3;
drop table CUNQ2;
drop table CUNQ1;


create table CUNQ1 (pk1 integer primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table CUNQ1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table CUNQ2 (pk2 integer primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table CUNQ1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table CUNQ3 (pk3 integer primary key, fk integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table CUNQ3 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table CUNQ3 add constraint FK_CONSTRAINT foreign key (fk) references CUNQ1(pk1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FK FK_CONSTRAINT created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table CUNQ3 add constraint FK_CONSTRAINT foreign key (fk) references CUNQ2(pk2);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FK FK_CONSTRAINT not doubled : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table CUNQ3 add constraint FK_CONSTRAINT check (fk > 12);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check FK_CONSTRAINT not created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table CUNQ3 add constraint FK_CONSTRAINT unique (fk);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UNIQUE FK_CONSTRAINT not created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: UNIQUE constraint tests\n";
