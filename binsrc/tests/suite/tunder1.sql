--
--  tschema1.sql
--
--  $Id: tunder1.sql,v 1.5.10.1 2013/01/02 16:15:31 source Exp $
--
--  Test DDL functionality #1
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

ECHO BOTH "STARTED: Schema Evolution Test, part 1\n";

--- test schema evolution


drop table T2;

create table T2 (A integer, B integer, primary key (A));
create table T2_1 (under T2, C2_1 integer);
create table T2_2 (under T2, C2_2 integer);
create index C2_1 on T2_1 (C2_1);
create index C2_2 on T2_2 (C2_2);
create table T2_1_1 (under T2_1, D2_1_1 integer);
create index D2_1_1 on T2_1_1 (D2_1_1);

insert into T2 values (1, 2);
insert into T2 values (2, 2);
insert into T2 values (3, 02);

insert into T2_1 (A, B, C2_1) values (4, 2, 1);
insert into T2_1 (A, B, C2_1) values (5, 2, 1);
insert into T2_1 (A, B, C2_1) values (6, 2, 1);
insert into T2_1 (A, B, C2_1) values (7, 2, 1);
insert into T2_1 (A, B, C2_1) values (8, 2, 1);

insert into T2_2 (A, B, C2_2) values (10, 2, 1);
insert into T2_2 (A, B, C2_2) values (11, 2, 1);
insert into T2_2 (A, B, C2_2) values (12, 2, 1);
insert into T2_2 (A, B, C2_2) values (13, 2, 1);
insert into T2_2 (A, B, C2_2) values (14, 2, 1);

insert into T2_1_1 (A, B, C2_1, D2_1_1) values (20, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (21, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (22, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (23, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (24, 1, 2, 3);

alter table T2_1 add D2_1 integer;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2 after ALTER TABLE of T2_1.\n";

alter table T2 add E integer;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2 after ALTER TABLE of T2.\n";

-- suite for bug #3506
CREATE TABLE B3506 (
      TEST_FIELD_1 CHAR(2)
    );

CREATE TABLE B3506_2 (
      UNDER B3506
    );

create procedure B3506_PROC ()
{
    declare _a char(2);

      SELECT TEST_FIELD_1 INTO _a FROM B3506_2;
        return;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Bug 3506.\n";


ECHO BOTH "COMPLETED: Schema Evolution Test, part 1\n";
