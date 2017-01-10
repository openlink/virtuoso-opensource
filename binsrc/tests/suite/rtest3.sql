--
--  rtest3.sql
--
--  $Id: rtest3.sql,v 1.11.10.1 2013/01/02 16:14:55 source Exp $
--
--  Remote database testing part 3
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

--
--  Start the test
--
SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Remote test 3 (rtest3.sql)\n";

--- remote db access errors

DB..vd_remote_table ('$U{PORT}', 'R1.DBA.T1', 'DB.DBA.notT1');

select  count (*) from R1..T1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bad remote table " $STATE " " $MESSAGE "\n";

DB..vd_remote_table ('$U{PORT}', 'R1.DBA.T1', 'DB.DBA.T1');

select FI2 / 0 from R1..T1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Remote /0 " $STATE " " $MESSAGE "\n";


select top 1 6 / (2 * 3) from R1..T1;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG #1939: Remote 6 / (2 * 3)= " $LAST[1] "\n";


attach table VIEWANDTEST from '$U{PORT}';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Attached the remote table VIEWANDTEST STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create view VIEWANDTEST_VIEW as select TOWN from VIEWANDTEST where STATE='PV' or STATE='BU';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Created view with OR clause VIEWANDTEST_VIEW STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from VIEWANDTEST_VIEW where TOWN='Sofia';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Select from VIEWANDTEST_VIEW where TOWN='Sofia' returned " $LAST[1] " rows\n";

create view VANDT_V1 (ID, STATE) as select ID, STATE from VIEWANDTEST;
create view VANDT_V2 (ID, TOWN) as select ID, TOWN from VIEWANDTEST;

create view VANDT_V3 (ID, TOWN, STATE) as
	select V1.ID, V1.STATE, V2.TOWN
	  from VANDT_V1 V1 left outer join VANDT_V2 V2 on (V1.ID = V2.ID);

select * from VANDT_V3;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Select * from VANDT_V3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select * from VANDT_V1');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": explain select * from VANDT_V1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select * from VANDT_V2');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": explain select * from VANDT_V2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select * from VANDT_V3');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": explain select * from VANDT_V3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure TEST_COMMIT ()
{
  commit work;
  insert into R1..B3202 values (1);
  sql_transact('$U{PORT}');
  insert into R1..B3202 values (2);
  rollback work;
};

delete from R1..B3202;
commit work;
TEST_COMMIT();
select MIN (ID) from R1..B3202;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": B3202: sql_transact bif commited the row before a rollback ID=" $LAST[1] " \n";


create procedure TEST_ROLLBACK ()
{
  commit work;
  insert into R1..B3202 values (1);
  sql_transact('$U{PORT}', 1);
  insert into R1..B3202 values (2);
  commit work;
};

delete from R1..B3202;
commit work;
TEST_ROLLBACK();
select MIN (ID) from R1..B3202;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": B3202: sql_transact (SQL_ROLLBACK) bif rolled back the row before a commit ID=" $LAST[1] " \n";

-- bug #9860
drop procedure B9680_PL_CURSOR;
create procedure B9680_PL_CURSOR ()
{
  declare cr cursor for select ID from B9680_TB order by ID;

  declare _ID integer;

  ;

  {
    declare exit handler for not found { ; };
    open cr;

    result_names (_ID);
    fetch cr into _ID;
    if (_ID <> 1)
      signal ('42000', sprintf ('unordered set : %d', _ID));
    result (_ID);

    fetch cr into _ID;
    if (_ID <> 2)
      signal ('42000', sprintf ('unordered set second row : %d', _ID));
    result (_ID);

    commit work;

    fetch cr into _ID;
    result (_ID);
    if (_ID <> 3)
      signal ('42000', sprintf ('unordered set after commit row', _ID));

    rollback work;

    fetch cr into _ID;
    result (_ID);
    if (_ID <> 4)
      signal ('42000', sprintf ('unordered set after rollback row : %d', _ID));

  }
  close cr;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B9860-1: B9860_PL_CURSOR procedure created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

B9680_PL_CURSOR ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B9860-2: B9860_PL_CURSOR procedure executed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure B9680_REXEC_CURSOR;
create procedure B9680_REXEC_CURSOR (in _dsn varchar)
{
  declare cr cursor for select ID from B9680_TB order by ID;

  declare _ID integer;
  declare _handle, _row any;
  declare _rc integer;

  if (0 <> (_rc := rexecute (_dsn, 'select ID from B9680_TB order by ID',
    NULL, NULL, NULL, NULL, NULL, NULL, _handle)))
    signal ('42000', sprintf ('invalid rexec return code : %d', _rc));

  result_names (_ID);
  if (0 <> (_rc := rnext (_handle, _row, NULL, NULL)))
    signal ('42000', sprintf ('invalid rnext return code : %d', _rc));
  _ID := cast (_row[0] as integer);
  if (_ID <> 1)
    signal ('42000', sprintf ('unordered set : %d', _ID));
  result (_ID);

  if (0 <> (_rc := rnext (_handle, _row, NULL, NULL)))
    signal ('42000', sprintf ('invalid rnext return code : %d', _rc));
  _ID := cast (_row[0] as integer);
  if (_ID <> 2)
    signal ('42000', sprintf ('unordered set second row : %d', _ID));
  result (_ID);

  commit work;

  if (0 <> (_rc := rnext (_handle, _row, NULL, NULL)))
    signal ('42000', sprintf ('invalid rnext return code : %d', _rc));
  _ID := cast (_row[0] as integer);
  result (_ID);
  if (_ID <> 3)
    signal ('42000', sprintf ('unordered set after commit row', _ID));

  rollback work;

  if (0 <> (_rc := rnext (_handle, _row, NULL, NULL)))
    signal ('42000', sprintf ('invalid rnext return code : %d', _rc));
  _ID := cast (_row[0] as integer);
  result (_ID);
  if (_ID <> 4)
    signal ('42000', sprintf ('unordered set after rollback row : %d', _ID));

  rclose (_handle);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B9860-3: B9860_REXEC_CURSOR procedure created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

B9680_REXEC_CURSOR ('$U{PORT}');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B9860-4: B9860_REXEC_CURSOR procedure called STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
--
-- End of test
--
ECHO BOTH "COMPLETED: Remote test 3 (rtest3.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
