--
--  $Id$
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

use JAVA;

drop type "my_finances";
drop type "Point";
drop table Employee;
drop table Supplier;

db..import_jar (NULL, vector ('my_finances', 'Point'));

create table Employee (name varchar primary key, salary double precision not null);
insert into Employee (name, salary) values ('John Dow', 35000);
insert into Employee (name, salary) values ('John Smith', 100000);
insert into Employee (name, salary) values ('John Little', 300000);
select name from Employee where "my_finances"::"tax" (salary) > 20;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": taxes " $ROWCNT " rows\n";

create table Supplier (id integer primary key, name varchar (20), location "Point");
insert into Supplier (id, name, location) values (1, 'S1', new "Point" (1, 1));
insert into Supplier (id, name, location) values (2, 'S2', new "Point" (5, 5));

select s.name from Supplier s
  where s.location."distance" ("Point" (4, 4)) < 3;
ECHO BOTH $IF $EQU $LAST[1] S2 "PASSED" "***FAILED";
ECHO BOTH ": distance < 3 s.name=" $LAST[1]"\n";

select s.name from Supplier s
  where s.location."x"  < 3;
ECHO BOTH $IF $EQU $LAST[1] S1 "PASSED" "***FAILED";
ECHO BOTH ": x < 3 s.name=" $LAST[1]"\n";

drop table Employee;
drop table Supplier;
db..unimport_jar (NULL, vector ('my_finances', 'Point'));

select __tag (new "Point" (1, 1));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": type dropped by unimport_jar STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

db..import_jar (NULL, vector ('my_finances', 'Point'));

create table Employee (name varchar primary key, salary double precision not null);
insert into Employee (name, salary) values ('John Dow', 35000);
insert into Employee (name, salary) values ('John Smith', 100000);
insert into Employee (name, salary) values ('John Little', 300000);
select name from Employee where "my_finances"::"tax" (salary) > 20;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": taxes " $ROWCNT " rows\n";

create table Supplier (id integer primary key, name varchar (20), location "Point");
insert into Supplier (id, name, location) values (1, 'S1', new "Point" (1, 1));
insert into Supplier (id, name, location) values (2, 'S2', new "Point" (5, 5));
select s.name from Supplier s
  where s.location."distance" ("Point" (4, 4)) < 3;
ECHO BOTH $IF $EQU $LAST[1] S2 "PASSED" "***FAILED";
ECHO BOTH ": distance < 3 s.name=" $LAST[1]"\n";
