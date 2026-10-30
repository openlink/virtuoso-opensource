--
--  texec_cache.sql
--
--  exec () with the 'use_cache' option keeps the compiled statement in a
--  shared cache.  When a table the statement reads is dropped, or dropped and
--  re-created, the cached statement has to be recompiled, and when that fails
--  the caller must get the compile error and not run the old plan.
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

ECHO BOTH "STARTED: exec () statement cache after DDL\n";

create table EXC_T (ID integer primary key, V varchar);
insert into EXC_T values (1, 'a');
insert into EXC_T values (2, 'b');

--  The state of a failed exec (), or the single value of its single row.
--  With a user name, runs as that user, as the SPARQL endpoint does.
create procedure EXC_RUN (in txt varchar, in uname varchar := null)
{
  declare st, msg, md, rs any;
  if (uname is not null)
    set_user_id (uname, 1);
  st := '00000';
  exec (txt, st, msg, vector (), vector ('use_cache', 1), md, rs);
  if (st <> '00000')
    return st;
  return rs[0][0];
}
;

select EXC_RUN ('select count (*) from EXC_T');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": cached statement before the drop counts " $LAST[1] " rows\n";

drop table EXC_T;

select EXC_RUN ('select count (*) from EXC_T');
ECHO BOTH $IF $EQU $LAST[1] "S0002" "PASSED" "***FAILED";
ECHO BOTH ": the cached statement after its table is dropped fails with " $LAST[1] "\n";

select 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the server is still answering after that statement\n";

create table EXC_T (ID integer primary key, V varchar);
insert into EXC_T values (5, 'e');

select EXC_RUN ('select count (*) from EXC_T');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the same text after the table is re-created reads the new table: " $LAST[1] " rows\n";

--  The case from the report: a reader with a grant caches the statement, and
--  the table is dropped and re-created without the grant.
create user EXC_U;
grant select on EXC_T to EXC_U;

select EXC_RUN ('select count (*) from EXC_T', 'EXC_U');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a granted user's cached statement counts " $LAST[1] " rows\n";

drop table EXC_T;
create table EXC_T (ID integer primary key, V varchar);
insert into EXC_T values (6, 'f');

select EXC_RUN ('select count (*) from EXC_T', 'EXC_U');
ECHO BOTH $IF $EQU $LAST[1] "42000" "PASSED" "***FAILED";
ECHO BOTH ": the same user after the re-create without a grant gets " $LAST[1] "\n";

select 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the server is still answering\n";

grant select on EXC_T to EXC_U;

select EXC_RUN ('select count (*) from EXC_T', 'EXC_U');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": with the grant restored the user reads the new table: " $LAST[1] " rows\n";

drop table EXC_T;
drop user EXC_U;
drop procedure EXC_RUN;

ECHO BOTH "COMPLETED: exec () statement cache after DDL\n";
