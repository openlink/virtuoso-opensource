--
--  tdate.sql
--
--  $Id: tdate.sql,v 1.15.10.2 2013/01/02 16:15:01 source Exp $
--
--  Some simple date checking functions
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

--
--  Start the test
--
CONNECT;
SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Date tests (tdate.sql)\n";

--
--  Create the test table
--
drop table tdate;
create table tdate (id integer not null primary key, val date);
create index tdateix1 on tdate (val);

--
--  Fill it with some test data
--
insert into tdate values (0, {d '1997/12/31'});
insert into tdate values (1, {d '1998/01/01'});
insert into tdate values (2, {d '1998/01/02'});
insert into tdate values (3, {d '1998/01/03'});
insert into tdate values (4, {d '1998/01/04'});
insert into tdate values (5, {d '1998/01/05'});
insert into tdate values (6, {d '1998/01/06'});
insert into tdate values (7, {d '1998/01/07'});
insert into tdate values (8, {d '1998/01/08'});
insert into tdate values (9, {d '1998/01/09'});
insert into tdate values (10, {d '1998/01/10'});

--
--  Check 31 December
--
ECHO BOTH "Checking 31 december 1997\n";
select * from tdate where val = {d '1997-12-31'};
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select * from tdate where val = {ts '1997-12-31 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select * from tdate where val = {ts '1997-12-31 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
--  Check 1 January
--
ECHO BOTH "Checking 1 january 1998\n";
select * from tdate where val = {d '1998-01-01'};
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select * from tdate where val = {ts '1998-01-01 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select * from tdate where val = {ts '1998-01-01 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
--  Check 2 January
--
ECHO BOTH "Checking 2 january 1998\n";
select * from tdate where val = {d '1998-01-02'};
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select * from tdate where val = {ts '1998-01-02 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select * from tdate where val = {ts '1998-01-02 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
--  Check < 4 January
--
ECHO BOTH "Checking < 4 january 1998\n";
select count(*) from tdate where val < {d '1998-01-04'};
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select count(*) from tdate where val < {ts '1998-01-04 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select count(*) from tdate where val < {ts '1998-01-04 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
--  Check > 4 January
--
ECHO BOTH "Checking > 4 january 1998\n";
select count(*) from tdate where val > {d '1998-01-04'};
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select count(*) from tdate where val > {ts '1998-01-04 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select count(*) from tdate where val > {ts '1998-01-04 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
-- Check <= 4 January
--
ECHO BOTH "Checking <= 4 january 1998\n";
select count(*) from tdate where val <= {d '1998-01-04'};
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select count(*) from tdate where val <= {ts '1998-01-04 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select count(*) from tdate where val <= {ts '1998-01-04 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
-- Check >= 4 January
--
ECHO BOTH "Checking >= 4 january 1998\n";
select count(*) from tdate where val >= {d '1998-01-04'};
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select count(*) from tdate where val >= {ts '1998-01-04 00:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 00:00:00\n";

select count(*) from tdate where val >= {ts '1998-01-04 12:00:00.0000'};
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 12:00:00\n";

--
-- Check some GPF errors fixed now
--
insert into tdate values (11, cast ('1974/12/14' as datetime));
insert into tdate values (12, '');
insert into tdate values (13, null);

--
-- Error which didn't take care about hours
--
insert into tdate values (14, cast ('1999/1/2 3:4:5' as datetime));

ECHO BOTH "Checking 2 january 1999\n";
select id from tdate where val = {d '1999-01-02'};
ECHO BOTH $IF $EQU $rowcnt 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using date escape\n";

select id from tdate where val = {ts '1999-01-02 03:04:05.0000'};
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select using timestamp escape at 03:04:05\n";

--
-- Bugzilla bug #
--

create procedure
cmp_date (in d1 any, in d2 any)
{

  if (__tag (d1) = 211)
    d1 := datestring (d1);

  if (__tag (d2) = 211)
    d2 := datestring (d2);

  d1 := LEFT (d1, 19);
  d2 := LEFT (d2, 19);

  if (d1 = d2)
    return 1;

  return 0;
}


create procedure
test_sec ()
{
  declare time_p, time_n datetime;
  declare idx integer;

  idx := 0;
  time_p := stringdate ('2002.09.29 00:01:00');
  time_n := stringdate ('1972.09.29 00:01:00');

  while (idx < 180)
    {
      time_p := dateadd ('second', 1, time_p);
      time_n := dateadd ('second', -1, time_n);
      idx := idx + 1;
    }

  if (not cmp_date (time_n, '1972-09-28 23:58:00'))
    return 0;

  if (not cmp_date (time_p, '2002-09-29 00:04:00'))
    return 0;

  if (not cmp_date (time_n, (dateadd ('minute', -3, stringdate ('1972.09.29 00:01:00')))))
    return 0;

  if (not cmp_date (time_p, (dateadd ('minute', 3, stringdate ('2002.09.29 00:01:00')))))
    return 0;

return 1;
}
;


create procedure
test_min ()
{
  declare time_p, time_n datetime;
  declare idx integer;

  idx := 0;
  time_p := stringdate ('2002.09.29 00:00:00');
  time_n := stringdate ('1972-10-04 00:00:00');

  while (idx < 7200)
    {
      time_p := dateadd ('minute', 100, time_p);
      time_n := dateadd ('minute', -100, time_n);
      idx := idx + 100;
    }

  if (not cmp_date (time_p, '2002-10-04 00:00:00'))
    return 0;

  if (not cmp_date (time_n, '1972-09-29 00:00:00'))
    return 0;

  if (not cmp_date (time_n, (dateadd ('minute', -7200, stringdate ('1972-10-04 00:00:00')))))
    return 0;

  if (not cmp_date (time_p, (dateadd ('minute', 7200, stringdate ('2002.09.29 00:00:00')))))
    return 0;

  if (not cmp_date (time_n, (dateadd ('hour', -120, stringdate ('1972-10-04 00:00:00')))))
    return 0;

  if (not cmp_date (time_p, (dateadd ('hour', 120, stringdate ('2002.09.29 00:00:00')))))
    return 0;

  if (not cmp_date (time_n, (dateadd ('day', -5, stringdate ('1972-10-04 00:00:00')))))
    return 0;

  if (not cmp_date (time_p, (dateadd ('day', 5, stringdate ('2002.09.29 00:00:00')))))
    return 0;

return 1;
}
;


create procedure
test_hour ()
{
  declare time_p, time_n datetime;
  declare idx integer;

  idx := 0;
  time_p := stringdate ('2002.09.29 00:01:00');
  time_n := stringdate ('1972.09.29 00:01:00');

  while (idx < 168)
    {
      time_p := dateadd ('hour', 1, time_p);
      time_n := dateadd ('hour', -1, time_n);
      idx := idx + 1;
    }

  if (not cmp_date (time_n, '1972-09-22 00:01:00'))
    return 0;

  if (not cmp_date (time_p, '2002-10-06 00:01:00'))
    return 0;

  if (not cmp_date (time_n, (dateadd ('day', -7, stringdate ('1972.09.29 00:01:00')))))
    return 0;

  if (not cmp_date (time_p, (dateadd ('day', 7, stringdate ('2002.09.29 00:01:00')))))
    return 0;

return 1;
}
;


select test_sec();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":Test dateadd second : STATE=" $STATE "\n";

select test_min();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":Test dateadd minute : STATE=" $STATE "\n";

select test_hour();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":Test dateadd hour : STATE=" $STATE "\n";

select dayname(cast('10.21.1968' as date));
ECHO BOTH $IF $EQU $LAST[1] Monday "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":Test dayname before 1970 : STATE=" $STATE "\n";

select monthname(cast('10.21.1968' as date));
ECHO BOTH $IF $EQU $LAST[1] October "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":Test monthname before 1970 : STATE=" $STATE "\n";

select cast (aref (vector ({d '1972-09-27'}), 0) as varchar);
ECHO BOTH $IF $EQU $LAST[1] '1972-09-27' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 2874: DT caries a DATE subtype : STATE=" $STATE "\n";

--select cast (aref (vector ({t '19:30'}), 0) as varchar)
--ECHO BOTH $IF $EQU $LAST[1] '19:30.000000' "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DT caries a TIME subtype : STATE=" $STATE "\n";
--

drop table b4159;
create table b4159 (id integer, event_date datetime);
insert into b4159 values(1, cast('10/1/2001' as datetime));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4159: inserting varchar into a datetime column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- End of test
--
ECHO BOTH "COMPLETED: Date tests (tdate.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n";
