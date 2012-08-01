--
--  tdatefun.sql
--
--  $Id$
--
--  Test date and timestamp functions
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

--
-- This test module written by Antti Karttunen 5.November 1997
-- Tests and utilizes many new sqlbif.c functions, also such
-- vector and other specialties as one_of_these or position.
--

echo BOTH "STARTED: Timestamp and Date scalar functions test\n";

-- First clear the passed and failed counts:
SET U{0} 0;
SET U{1} 0;

create procedure testdatefuns(in ts timestamp)
{
    declare _now_ varchar(31);
    declare _curdate_ varchar(31);
    declare _curtime_ varchar(31);
    declare _curdatetime_ varchar(31);
    declare _datestring_ varchar(31);
-- The following are all SQL-92 standard functions:
    declare _dayname_ varchar(12);
    declare _monthname_ varchar(12);
    declare _dayofmonth_ integer;
    declare _dayofweek_ integer;
    declare _dayofyear_ integer;
    declare _month_ integer;
    declare _quarter_ integer;
    declare _week_ integer;
    declare _year_ integer;
    declare _hour_ integer;
    declare _minute_ integer;
    declare _second_ integer;

    result_names (_year_,
                  _month_,
                  _dayofmonth_,
                  _hour_,
                  _minute_,
                  _second_,
                  _dayname_,
                  _monthname_,
                  _dayofweek_,
                  _dayofyear_,
                  _quarter_,
                  _week_,
                  _datestring_,
                  _now_,
                  _curdate_,
                  _curtime_,
                  _curdatetime_);

          result (year(ts),
                  month(ts),
                  dayofmonth(ts),
                  hour(ts),
                  minute(ts),
                  second(ts),
                  dayname(ts),
                  monthname(ts),
                  dayofweek(ts),
                  dayofyear(ts),
                  quarter(ts),
                  week(ts),
                  datestring(ts),
                  datestring(now()),
                  datestring(curdate()),
                  datestring(curtime()),
                  datestring(curdatetime()));
};

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": create procedure testdatefuns: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call testdatefuns(stringdate('1997.11.05 03:54:47'));
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 1997 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 11 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 5 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 3 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 54 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 47 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Wednesday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "November" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 4 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 309 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 4 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

ECHO BOTH $IF $EQU $LAST[12] 45 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;
--
ECHO BOTH $IF $EQU $LAST[1] 1997 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 11 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 05 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 03 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 54 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 47 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring(stringdate({ts '" $U{DATESTRING} "'})) produces the
-- same answer.
--

call testdatefuns(stringdate('$U{DATESTRING}'));
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring(stringdate('" $U{DATESTRING} "')) is '" $LAST[13] "'\n";

--
-- In the middle of summer, to test daylight saving time's effects.
--

call testdatefuns({ts '1998.07.15 17:22:01'});
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 1998 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 7 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 15 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 17 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 22 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Wednesday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "July" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 4 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 196 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 3 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] 1998 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 07 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 15 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 17 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 22 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 01 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- This time try ODBC-standard "timestamp-literal", which is actually
-- converted by Virtuoso SQL-parser to similar call to stringdate as above
--

call testdatefuns({ts '1999.12.31 23:59:59'});
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 1999 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 12 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 31 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 23 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Friday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "December" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 6 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 365 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 4 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;
--
ECHO BOTH $IF $EQU $LAST[1] 1999 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 12 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 31 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 23 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- Add a second, should produce Y2K, but no problems.
--

call testdatefuns(dateadd('second',1,stringdate('$U{DATESTRING}')));
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 0 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 0 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 0 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Saturday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "January" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 7 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 01 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 01 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 00 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 00 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 00 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- Add 58 days and 86399 seconds, should produce 28-Feb-2000 23:59:59
--

call testdatefuns(dateadd('second',86399,
                           dateadd('day',58,stringdate('$U{DATESTRING}'))));
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 2 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 28 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 23 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Monday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "February" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 2 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 02 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 28 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 23 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 59 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- Add a second, should leap to 29th of February, as the year 2000
-- is a leap year in the gregorian calendar. (20%4 = 0)
--

call testdatefuns(dateadd('second',1,stringdate('$U{DATESTRING}')));
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 2 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 29 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 0 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 0 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 0 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Tuesday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "February" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 3 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 60 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 02 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 29 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 00 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 00 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 00 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- Mainly check that a leap year has 366 days.
--

call testdatefuns({ts '2000.12.31 11:02:03'});
SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 12 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 31 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 11 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 2 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 3 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Sunday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "December" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 366 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 4 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] 2000 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 12 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 31 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 11 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 02 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 03 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- call testdatefuns({ts '2038.01.19 03:14:07'});
-- is the last value which works in Central European (UT+1) timezone.
-- We could have a timezone like UT-12 or UT-13 somewhere in Alaska,
--  Polynesia???
--

call testdatefuns({ts '2038.01.18 13:14:07'});

SET U{DATESTRING}=$LAST[13];
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[1] 2038 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 18 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 13 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 14 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 7 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "Monday" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname({ts '" $U{DATESTRING} "'}) is  " $LAST[7] "\n";

ECHO BOTH $IF $EQU $LAST[8] "January" "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] 2 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek({ts '" $U{DATESTRING} "'}) is (Sun=1) " $LAST[9] "\n";

ECHO BOTH $IF $EQU $LAST[10] 18 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofyear({ts '" $U{DATESTRING} "'}) is (Jan. First=1) " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter({ts '" $U{DATESTRING} "'}) is (Jan 1 - Mar 31 = 1) " $LAST[11] "\n";

-- ECHO BOTH $IF $EQU $LAST[12] xx "PASSED" "***FAILED";
-- SET U{$LIF} $+ $U{$LIF} 1;
-- ECHO BOTH ": week({ts '" $U{DATESTRING} "'}) is " $LAST[12];
-- ECHO BOTH " (CURRENTLY CALCULATED WITH INCORRECT FORMULA, MIGHT JUST WORK ACCIDENTALLY AS ISO 8601 ON SOME YEARS, E.G. ON 1997 and 1998)\n";

--
-- Check the datestring's result.
--

select LEFT('$U{DATESTRING}',4),
       substring('$U{DATESTRING}',6,2),
       substring('$U{DATESTRING}',9,2),
       substring('$U{DATESTRING}',12,2),
       substring('$U{DATESTRING}',15,2),
       substring('$U{DATESTRING}',18,2)
       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] 2038 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year part of datestring({ts '" $U{DATESTRING} "'}) is  " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 01 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month part is " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 18 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": day part is " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 13 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour part is " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 14 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute part is " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] 07 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second part is " $LAST[6] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

--
-- Back to the moment.
--

call testdatefuns(now());

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

SET U{YEAR}       = $LAST[1];
SET U{MONTH}      = $LAST[2];
SET U{DAYOFMONTH} = $LAST[3];
SET U{HOUR}       = $LAST[4];
SET U{MINUTE}     = $LAST[5];
SET U{SECOND}     = $LAST[6];
SET U{DAYNAME}    = $LAST[7];
SET U{MONTHNAME}  = $LAST[8];
SET U{DAYOFWEEK}  = $LAST[9];
SET U{DAYOFYEAR}  = $LAST[10];
SET U{QUARTER}    = $LAST[11];
SET U{WEEK}       = $LAST[12];
SET U{DATESTRING} = $LAST[13];
SET U{NOW}        = $LAST[14];

ECHO BOTH $IF $EQU $LAST[13] $LAST[14] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": {ts '" $U{DATESTRING} "'} is now() " $LAST[14] "\n";

--
-- Check that various SQL-92 datetime part extraction functions return
-- the same results from current timestamp as what datestring will show.
--

select LEFT('$U{DATESTRING}',4), $U{YEAR},
       substring('$U{DATESTRING}',6,2), sprintf('%02d',$U{MONTH}),
       substring('$U{DATESTRING}',9,2), sprintf('%02d',$U{DAYOFMONTH}),
       substring('$U{DATESTRING}',12,2), sprintf('%02d',$U{HOUR}),
       substring('$U{DATESTRING}',15,2), sprintf('%02d',$U{MINUTE}),
       substring('$U{DATESTRING}',18,2), sprintf('%02d',$U{SECOND}),

       aref(vector('No-Zero-Day!','Sunday','Monday','Tuesday','Wednesday',
                   'Thursday','Friday','Saturday'),$U{DAYOFWEEK}),
        '$U{DAYNAME}',

       position ('$U{DAYNAME}', vector ('Sunday','Monday','Tuesday','Wednesday',
                                  'Thursday','Friday','Saturday')),
        $U{DAYOFWEEK},

       aref(vector('No-Zero-Month!','January','February','March','April',
             'May','June','July','August',
             'September','October','November','December'),
               $U{MONTH}),
        '$U{MONTHNAME}',

       position('$U{MONTHNAME}',
                vector('January','February','March','April','May','June',
              'July','August','September','October','November','December')),
        $U{MONTH},

       (($U{MONTH}-1)/3)+1, $U{QUARTER},

       get_keyword('$U{MONTHNAME}',
          vector('September',9,'October',10,'November',11,'December',12,
                 'May',5,'June',6,'July',7,'August',8,
                 'April',4,'March',3,'February',2,'January',1),
                 'MONTHNAME-NOT-FOUND!'),
        $U{MONTH},

       get_keyword($U{MONTH},
          vector(9,'September',10,'October',11,'November',12,'December',
                 5,'May',6,'June',7,'July',8,'August',
                 4,'April',3,'March',2,'February',1,'January'),
                 'MONTHNUMBER-NOT-FOUND!'),
        '$U{MONTHNAME}'


       from SYS_USERS where U_ID = 0;

ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": year({ts '" $U{DATESTRING} "'}) is  " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] $LAST[4] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month({ts '" $U{DATESTRING} "'}) is  " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] $LAST[6] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofmonth({ts '" $U{DATESTRING} "'}) is  " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] $LAST[8] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": hour({ts '" $U{DATESTRING} "'}) is  " $LAST[8] "\n";

ECHO BOTH $IF $EQU $LAST[9] $LAST[10] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": minute({ts '" $U{DATESTRING} "'}) is  " $LAST[10] "\n";

ECHO BOTH $IF $EQU $LAST[11] $LAST[12] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": second({ts '" $U{DATESTRING} "'}) is  " $LAST[12] "\n";

ECHO BOTH $IF $EQU $LAST[13] $LAST[14] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayofweek(X) is  " $U{DAYOFWEEK} " -> " $LAST[13] " = " $LAST[14] "\n";

ECHO BOTH $IF $EQU $LAST[15] $LAST[16] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": dayname(X) is  " $U{DAYNAME} " -> " $LAST[15] " = " $LAST[16] "\n";

ECHO BOTH $IF $EQU $LAST[17] $LAST[18] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": month(X) is  " $U{MONTH} " -> " $LAST[17] " = " $LAST[18] "\n";

ECHO BOTH $IF $EQU $LAST[19] $LAST[20] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": monthname(X) is  " $U{MONTHNAME} " -> " $LAST[19] " = " $LAST[20] "\n";

ECHO BOTH $IF $EQU $LAST[21] $LAST[22] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": quarter(X) is  " $LAST[21] " = " $LAST[22] "\n";

ECHO BOTH $IF $EQU $LAST[23] $LAST[24] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": get_keyword(monthname(X),vector(...)) produces " $U{MONTHNAME} " -> " $LAST[23] " = " $LAST[24] "\n";

ECHO BOTH $IF $EQU $LAST[25] $LAST[26] "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": get_keyword(month(X),vector(...)) produces " $U{MONTH} " -> " $LAST[25] " = " $LAST[26] "\n";

--
-- Check that datestring({ts 'X'}) produces the same answer.
--

call testdatefuns({ts '$U{DATESTRING}'});
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": " $ROWCNT " result row from testdatefuns\n";

ECHO BOTH $IF $EQU $LAST[13] $U{DATESTRING} "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": datestring({ts '" $U{DATESTRING} "'}) is '" $LAST[13] "'\n";

select CURRENT_DATE, CURRENT_TIME, CURRENT_TIMESTAMP, CURRENT_TIME (1), CURRENT_TIMESTAMP (1);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": BUG 1142: SQL-92 date/time functions\n";

select cast ('22:22:22' as time);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": BUG 2453: cast VARCHAR as TIME\n";

select cast (now() as time);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": BUG 3180: Cast as TIME\n";

select datediff ('millisecond', {ts '1970-01-01 00:00:00.1000'}, {ts '1970-01-01 00:00:01.2000'});
ECHO BOTH $IF $EQU $LAST[1] 1100 "PASSED" "***FAILED";
SET U{$LIF} $+ $U{$LIF} 1;
ECHO BOTH ": BUG 7145: millisecond datediff returned : " $LAST[1] "\n";

ECHO BOTH "COMPLETED: Timestamp and Date scalar functions test ";
ECHOLN BOTH "WITH " $U{0} " FAILED, " $U{1} " PASSED";
