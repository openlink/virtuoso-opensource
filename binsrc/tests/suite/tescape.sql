--
--  $Id: tescape.sql,v 1.17.10.1 2013/01/02 16:15:05 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
ECHO BOTH "STARTED: String C escaping tests\n";

create procedure TEST_AREF()
{
  declare arr any;
  declare _one, _two, _three integer;
  arr := vector (1, vector (2, 3));
  _one := arr[0];
  _two := arr[1][0];
  _three := arr[_two - _one][_two / 2];
  result_names (_one, _two, _three);
  result (_one, _two, _three);
}
TEST_AREF();
ECHO BOTH $IF $NEQ $LAST[1] 1 "*** FAILED" $IF $NEQ $LAST[2] 2 "*** FAILED" $IF $NEQ $LAST[3] 3 "*** FAILED" "PASSED";
ECHO BOTH ": using the [] notation ON array variable STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table LIKE_ESCAPE;

create table LIKE_ESCAPE (DATA varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating the LIKE escapes table ON STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into LIKE_ESCAPE values ('%');
insert into LIKE_ESCAPE values ('_');
insert into LIKE_ESCAPE values ('ab%');
insert into LIKE_ESCAPE values ('%ab');
insert into LIKE_ESCAPE values ('ab%ab');
insert into LIKE_ESCAPE values ('ab_');
insert into LIKE_ESCAPE values ('_ab');
insert into LIKE_ESCAPE values ('ab_ab');

select count(*) from LIKE_ESCAPE where DATA like '%M%%' escape 'M';
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "*** FAILED";
ECHO BOTH ": 4 rows for LIKE with an M as escape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from LIKE_ESCAPE where DATA like '%\\%%';
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "*** FAILED";
ECHO BOTH ": 4 rows for LIKE with an unspecified (default) escape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from LIKE_ESCAPE where DATA like '%M%%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
ECHO BOTH ": 0 rows for LIKE with an unspecified M as escape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from LIKE_ESCAPE where DATA like 'M%' escape 'M' or DATA like 'G_' escape 'G';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "*** FAILED";
ECHO BOTH ": 2 rows for LIKE with or-ed escaped like STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table ESCAPES;

create table ESCAPES (ID integer not null primary key, DATA varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating the escapes table ON STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set NO_CHAR_C_ESCAPE off;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": setting the escape processing ON STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into ESCAPES (ID, DATA) values (1, '\ON');
select DATA from ESCAPES where ID=1;
ECHO BOTH $IF $EQU $LAST[1] 'ON' "PASSED" "*** FAILED";
ECHO BOTH ": insert with escape processing ON = " $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set NO_CHAR_C_ESCAPE on;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": setting the escape processing OFF STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into ESCAPES (ID, DATA) values (2, '\OFF');
select DATA from ESCAPES where ID=2;
ECHO BOTH $IF $EQU $LAST[1] '\\OFF' "PASSED" "*** FAILED";
ECHO BOTH ": insert with escape processing OFF = " $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure TESTESCAPES()
{
  --no_c_escapes-
  insert into ESCAPES (ID, DATA) values (3, '\ON');
  --no_c_escapes+
  insert into ESCAPES (ID, DATA) values (4, '\OFF');
};
TESTESCAPES();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating c_escapes comment using procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select P_NAME, locate ('--no_c_escapes+', P_TEXT), P_TEXT from DB.DBA.SYS_PROCEDURES where P_NAME like '%TESTESCAPES';
ECHO BOTH $IF $EQU $LAST[2] 2 "PASSED" "*** FAILED";
ECHO BOTH ": escape processing OFF resulting in marking the text in SYS_PROCEDURES STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DATA from ESCAPES where ID=3;
ECHO BOTH $IF $EQU $LAST[1] 'ON' "PASSED" "*** FAILED";
ECHO BOTH ": procedure results escape processing ON = " $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DATA from ESCAPES where ID=4;
ECHO BOTH $IF $EQU $LAST[1] '\\OFF' "PASSED" "*** FAILED";
ECHO BOTH ": procedure results escape processing OFF = " $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: String C escaping tests\n";
ECHO BOTH "STARTED: identifier double double-quotes tests\n";

create table test""quotes (with""quotes integer);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating a table with nonquoted double double-quoted names STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into test""quotes (with""quotes) values (1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting into table with nonquoted double double-quoted names STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table test""quotes;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dropping a table with nonquoted double double-quoted names STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create table "test""quotes" ("with""quotes" integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating a table with quoted double double-quoted names STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into "test""quotes" ("with""quotes") values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting into table with quoted double double-quoted names STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table "test""quotes";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dropping a table with quoted double double-quoted names STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 as """";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 2139: \"\"\"\" as an alias STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- test suite for bug #1165
use ellersk;
drop table spr2166;
create table spr2166 (id integer identity primary key, somedata varchar(20));
insert into spr2166 (somedata) values ('match_this');
insert into spr2166 (somedata) values ('_and in front');
insert into spr2166 (somedata) values ('and in back_');
insert into spr2166 (somedata) values ('but not this');
insert into spr2166 (somedata) values ('this_should_match');
insert into spr2166 (somedata) values ('this should not');
insert into spr2166 (somedata) values ('');
insert into spr2166 (somedata) values ('x');

set NO_CHAR_C_ESCAPE = 1;
select * from spr2166 where somedata like '%\_%' escape '\';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": as per the standard STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from spr2166 where somedata like '%\_%' escape '\\';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": double escape char STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from spr2166 where somedata like '%\_%' escape ?;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": non-char escape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set NO_CHAR_C_ESCAPE = 0;
select * from spr2166 where somedata like '%\\_%' escape '\\';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select with a explicit backslash escape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

exec ('select * from spr2166 where somedata like ''%\_%'' escape ''\''');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select with a single backslash escape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

---- ';
use DB;
ECHO BOTH "COMPLETED: identifier double double-quotes tests\n";

ECHO BOTH "STARTED: trace tests\n";

select trace_on ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select trace_on STATE=" $STATE "\n";

select get_keyword ('soap', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select trace_off ('soap');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select trace_off STATE=" $STATE "\n";

select get_keyword ('soap', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('user_log', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('failed_log', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('compile', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('ddl_log', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('client_sql', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('errors', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('dsn', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('sql_send', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('transact', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('remote_transact', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('exec', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'on' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select trace_off ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select trace_off STATE=" $STATE "\n";

select get_keyword ('soap', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('user_log', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('failed_log', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('compile', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('ddl_log', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('client_sql', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('errors', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('dsn', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('sql_send', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('transact', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('remote_transact', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

select get_keyword ('exec', trace_status ());
ECHO BOTH $IF $EQU $LAST[1] 'off' "PASSED" "*** FAILED";
ECHO BOTH ": get trace_status LAST=" $LAST[1] "\n";

ECHO BOTH "COMPLETED: trace tests\n";

select * from SYS_USERS; --- this is a comment
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": isql with comment after the ;  LAST=" $LAST[1] "\n";

select length (sprintf('1 %% 1'));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": BUG 3797: 1 %% 1 in sprintf return string of len=" $LAST[1] "\n";
