--
--  tfref.sql
--
--  $Id$
--
--  Function reference tests
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

create procedure tfref (in q integer)
{
  declare ctr, c, s, mi, ma, av integer;
  ctr := 0;
  while (ctr < q) {
    select count (*), sum (A), avg (A), min (A), max (A)
      into c, s, av, mi, ma from T2;
    if (s <> 96 or c <> 13 or mi <> 1 or ma <> 14 or av <> 7)
      goto failed;
    select count (*), sum (A), avg (A), min (A), max (A)
      into c, s, av, mi, ma  from T2 where A > 100;
    if (s <> null or c <> 0 or mi <> null or ma <> null or av <> null)
      goto failed;

    ctr := ctr + 1;
  }
  result_names (s);
  result (1);
  return;
  return;
 failed:
  result (0);
}

call tfref (4);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fun ref test\n";

select A.* from T2 A where 3 > (select count (*) from T2 B where B.A > A.A);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": Subquery < count (*)\n";

select A.* from T2 A where A.A > all (select B.A from T2 B where B.A < 10);

select A from T2 where A in (1, 2, 1+2);
select A from T2 where A not in (1, 2, 1+2);

select A.A from T2 A where A.A = some (select B.A from T2 B where B.A < 10);
select A.A from T2 A where A.A > all (select B.A from T2 B where B.A < 10);

select A.A from T2 A where A.A in (select B.A from T2 B where B.A < 10);
select A.A from T2 A where A.A not in (select B.A from T2 B where B.A < 10);

create procedure upd1 (in no integer)
{
  declare r integer;
  update T2 set E = (r := B, E + 1) where A = 11;
  return r;
}

select case 3 when 1 then 2 when 3 then 4 else -1 end from SYS_USERS;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": CASE exp 1\n";

select case 33 when 1 then 2 when 3 then 4 else -1 end from SYS_USERS;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
ECHO BOTH ": CASE exp 2\n";

select case 33 when 1 then 2 when 3 then 4  end from SYS_USERS;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
ECHO BOTH ": CASE exp 3\n";

select case when 2 > 3 then -1 when 3 < 4 then 1 else 0 end from SYS_USERS;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": CASE exp 4\n";

select coalesce (null, 1, 2) from SYS_USERS;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": COALESCE exp 1\n";

drop table ALLSOME1;
drop table ALLSOME2;
create table ALLSOME1 (ID integer primary key, DATA varchar (50));
create table ALLSOME2 (ID integer primary key, DATA varchar (50));

insert into ALLSOME1 (ID, DATA) values (1, 'a');
insert into ALLSOME1 (ID, DATA) values (2, 'b');

insert into ALLSOME2 (ID, DATA) values (1, 'a');
insert into ALLSOME2 (ID, DATA) values (2, 'c');

select * from ALLSOME1 where (ID, DATA) <> all (select ID, DATA from ALLSOME2);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <> all returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <> all returned ID=" $LAST[1] "\n";

select * from ALLSOME1 where (ID, DATA) = all (select ID, DATA from ALLSOME2);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": = all returned " $ROWCNT " rows\n";

select * from ALLSOME1 where (ID, DATA) = some (select ID, DATA from ALLSOME2);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": = some returned " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": = some returned ID=" $LAST[1] "\n";

select * from ALLSOME1 where (ID, DATA) <> some (select ID, DATA from ALLSOME2);
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <> some returned " $ROWCNT " rows\n";
