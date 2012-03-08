--
--  tschema4.sql
--
--  $Id$
--
--  Test DDL functionality #4
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

create table sc_test (qq integer not null primary key,
		      primary key (qq));

ECHO BOTH $IF $EQU $STATE 42S11 "PASSED" "***FAILED";
ECHO BOTH ": Duplicate primary key decl state " $STATE "\n";


create table sc_test (id integer not null primary key identity references sc_test,
		      a integer default 16 not null,
		      b integer not null,
		      foreign key (id) references sc_test (id));

insert into sc_test (b) values (11);
select a from sc_test;
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
ECHO BOTH ": column default =" $LAST[1] "\n";

update sc_test set b = null;
ECHO BOTH $IF $EQU $STATE 23000 "PASSED" "***FAILED";
ECHO BOTH ": not null violation state " $STATE "\n";


-- test update_quick error w/ new len = old len and
-- new_len > old_len.

update sc_test set b = 'a';
ECHO BOTH $IF $EQU $STATE 22005 "PASSED" "***FAILED";
ECHO BOTH ": type violation state " $STATE "\n";

select b from sc_test;
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
ECHO BOTH ": column default =" $LAST[1] "\n";

create table many_tb (sc_test_id integer references sc_test (id));
drop table sc_test;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Drop FK ref'd table state " $STATE "\n";

drop table many_tb;
drop table sc_test;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Drop FK unref'd table state " $STATE "\n";


create table sc_test (id integer not null primary key identity);
insert into sc_test (id) values (1);

alter table sc_test add b integer not null default 16 identity;
-- b references sc_test; XXX not supposed to be FK as it seems from next steps
insert into sc_test (id) values (1);

alter table sc_test add c integer default 0;
alter table sc_test add d numeric (10,2) identity;
insert into sc_test (id) values (3);

select id, b, c from sc_test;
ECHO BOTH $IF $EQU $LAST[3] 0 "PASSED" "***FAILED";
ECHO BOTH ": last added defaulted col value " $LAST[3] "\n";

alter table sc_test drop b;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ":  drop column state " $STATE "\n";

drop table sc_test;

--- Test case for bug #776

use BUG776;
drop view COL_VIEW;
drop table COL_TB;

create table COL_TB (ID integer primary key, DATA varchar);
create view COL_VIEW (VID, VDATA) as select ID, DATA from COL_TB;

tables;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": tables (null table type) = " $ROWCNT "\n";

tables/"TABLE";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": tables (non-quoted table type TABLE) = " $ROWCNT "\n";

tables/"'TABLE'";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": tables (quoted table type TABLE) = " $ROWCNT "\n";

tables/" 'TABLE' ";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": tables (quoted table type TABLE w/spaces) = " $ROWCNT "\n";

tables/"VIEW";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": tables (non-quoted table type VIEW) = " $ROWCNT "\n";

tables/"SYSTEM TABLE";
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": tables (non-quoted table type SYSTEM TABLE) = " $ROWCNT "\n";


tables/"TABLE,VIEW";
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": tables (TABLE,VIEW) = " $ROWCNT "\n";

tables/" TABLE , VIEW ";
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": tables ( TABLE , VIEW ) = " $ROWCNT "\n";

tables/"'TABLE','VIEW'";
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": tables ('TABLE','VIEW') = " $ROWCNT "\n";

tables/" 'TABLE' , 'VIEW' ";
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": tables ( 'TABLE' , 'VIEW' ) = " $ROWCNT "\n";


-- suite for bug #270

use BUG270;

drop table ALTERTEST;
create table ALTERTEST (ID integer primary key, DATA varchar(20), DATA2 integer);
columns ALTERTEST/DATA;
ECHO BOTH $IF $EQU $LAST[7] 20 "PASSED" "***FAILED";
ECHO BOTH ": DATA varchar " $LAST[7] "\n";

alter table ALTERTEST modify DATA varchar (40);
columns ALTERTEST/DATA;
ECHO BOTH $IF $EQU $LAST[7] 40 "PASSED" "***FAILED";
ECHO BOTH ": DATA set to varchar " $LAST[7] "\n";

alter table ALTERTEST modify column DATA varchar (50);
columns ALTERTEST/DATA;
ECHO BOTH $IF $EQU $LAST[7] 50 "PASSED" "***FAILED";
ECHO BOTH ": modify column DATA set to varchar " $LAST[7] "\n";

alter table ALTERTEST modify column DATA integer;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": modify to an int STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

columns ALTERTEST/DATA;
ECHO BOTH $IF $EQU $LAST[7] 50 "PASSED" "***FAILED";
ECHO BOTH ": after modify DATA integer set to varchar " $LAST[7] "\n";

alter table ALTERTEST modify column DATA2 varchar(50);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ":  modify an int STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

columns ALTERTEST/DATA2;
ECHO BOTH $IF $EQU $LAST[6] INTEGER "PASSED" "***FAILED";
ECHO BOTH ": after modify DATA2 set to " $LAST[6] "\n";

-- test case for bug 1224
drop table AAA..TEST;

CREATE TABLE AAA..TEST (
  ID    INTEGER,
  CONTENT    LONG VARBINARY NOT NULL,

  PRIMARY KEY (ID)
);

INSERT INTO AAA..TEST (ID,CONTENT) VALUES(1,'abc');

ALTER TABLE AAA..TEST DROP CONTENT;

columns AAA..TEST;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG 1224: after drop long varbinary not null\n";

drop table B5799_1;
create table B5799_1 (ID int primary key, DATA varchar CHECK (DATI not like 'xxx%'));

select * from B5799_1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 5799: wrong CHECK doesn't leave the table behind STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5799_2;
create table B5799_2 (ID int primary key, DATA varchar references B5799_NONEX (DATA));
select * from B5799_2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 5799: wrong foreign key doesn't leave the table behind STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B7137..TB7137;
create table B7137..TB7137 (ID int primary key, DATA VARCHAR (50));

use B7137;

select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'TB7137';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-1: B7137.INFORMATION_SCHEMA.TABLES STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-2: B7137.INFORMATION_SCHEMA.TABLES returned " $ROWCNT " rows\n";
ECHO BOTH $IF $GT $COLCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-3: B7137.INFORMATION_SCHEMA.TABLES returned " $COLCNT " columns\n";

use DB;

select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'TB7137';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-4: DB.INFORMATION_SCHEMA.TABLES STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-5: DB.INFORMATION_SCHEMA.TABLES returned " $ROWCNT " rows\n";
ECHO BOTH $IF $GT $COLCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-6: DB.INFORMATION_SCHEMA.TABLES returned " $COLCNT " columns\n";

select * from B7137.INFORMATION_SCHEMA.TABLE_CONSTRAINTS where TABLE_NAME = 'TB7137';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-7: B7137.INFORMATION_SCHEMA.TABLES STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-8: B7137.INFORMATION_SCHEMA.TABLES returned " $ROWCNT " rows\n";
ECHO BOTH $IF $GT $COLCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG 7137-8: B7137.INFORMATION_SCHEMA.TABLES returned " $COLCNT " columns\n";

select * from INFORMATION_SCHEMA.SCHEMATA;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 9975: INFORMATION_SCHEMA.TABLES STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.INFORMATION_SCHEMA.CATALOGS;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": INFORMATION_SCHEMA nonexsistent table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
