--
--  tschema1.sql
--
--  $Id$
--
--  Test DDL functionality #1
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

ECHO BOTH "STARTED: Schema Evolution Test, part 2\n";


insert into T2_1_1 (A, B, C2_1, D2_1_1) values (4, 1, 2, 3);
ECHO BOTH $IF $EQU $STATE 23000 "PASSED" "***FAILED";
ECHO BOTH ": primary key in subtable conflicts with super table.\n";

select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2.\n";

#alter table T2_1 add D2_1 integer;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2 after ALTER TABLE of T2_1.\n";

#alter table T2 add E integer;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2 after ALTER TABLE of T2.\n";

update T2_1 set E = 11;
select count (*) from T2 where E = 11;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in T2 with E = 11\n";

update T2 set E = 5555 where E is null;
select count (*) from T2 where E = 5555;
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in T2 with E = 5555\n";

alter table T2_1 add F varchar;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": Cached statement gives " $LAST[1] " in T2 after alter of T2_1\n";

select  count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": Recompiled statement gives " $LAST[1] " in T2 after alter of T2_1\n";

update T2_1_1 set F = 'T2_1_1';
update T2_1 set F = 'T2_1' where F is null;
select count (*) from T2;
drop table T2_1_1;
select count (*)  from T2;
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
ECHO BOTH ": Recompiled statement gives " $LAST[1] " in T2 after drop of T2_1_1\n";

select K1. KEY_NAME, K2.KEY_NAME from SYS_KEY_SUBKEY, SYS_KEYS K1, SYS_KEYS K2 WHERE K1.KEY_ID = SUPER AND K2.KEY_ID = SUB;

--suite for bug #3614
DROP TABLE B3614_2;
DROP TABLE B3614_1;

CREATE TABLE B3614_1(
 ID INTEGER
);

CREATE TABLE B3614_2(
 ID INTEGER,
 UNDER B3614_1
);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 3614: duplicate columns from supertable in subtable\n";

--suite for bug #3668
drop table B3668_2;
drop table B3668;
CREATE TABLE B3668(
  ID               varchar    NOT NULL,
  DATA             LONG VARCHAR       NULL,

  CONSTRAINT B3668_PK PRIMARY KEY(ID)
);

CREATE TABLE B3668_2(
  NAME1      VARCHAR    NOT NULL,
  NAME2      VARCHAR        NULL,

  UNDER B3668
);

INSERT INTO B3668(ID, DATA) VALUES ('Note', null);

ALTER TABLE B3668
  ADD  DATA2 LONG VARCHAR NULL;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 3668: invalid reading order of the changed tables STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

UPDATE B3668 SET DATA2 = '';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 3668-2: invalid reading order of the changed tables STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

UPDATE B3668 SET DATA2 = '';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 3668-3: invalid reading order of the changed tables STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DROP TABLE B4472;
CREATE TABLE B4472(
  ID        INTEGER       NOT NULL    PRIMARY KEY,
  ST        VARCHAR       NOT NULL,
  DATA      VARCHAR       NULL
);

INSERT INTO B4472 (ID,ST,DATA) VALUES(1,'ST','DATA');

ALTER TABLE B4472 ADD DATA2 LONG VARCHAR;
UPDATE B4472 SET DATA2 = DATA;
ALTER TABLE B4472 DROP DATA;

UPDATE B4472 SET ST = 'ID';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 4472: invalid key used in outlining the blobs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B4678;
CREATE TABLE B4678 (
  ID INTEGER NOT NULL PRIMARY KEY,
  NAME VARCHAR);

CREATE TABLE B4678_2 (
  UNDER B4678);

CREATE INDEX B4678_SK01 ON B4678(ID,NAME);


DROP INDEX B4678_SK01 B4678_2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 4678: drop of an inherited key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DROP INDEX B4678_SK01;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 4678_2: drop index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE INDEX B4678_SK01 ON B4678(ID,NAME);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 4678_3: drop of a key from a table w/ subtable STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: Schema Evolution Test, part 2\n";
