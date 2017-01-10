--  
--  $Id$
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
echo BOTH "STARTED: freetext (qualifiers, hook function) tests\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table allow;
drop table deny;

--set echo on;

drop table "new"."demo"."q""tst";
create table "new"."demo"."q""tst" ("i""d" integer, "d""t" long varchar);

insert into "new"."demo"."q""tst" values (1, 'abc');
insert into "new"."demo"."q""tst" values (2, 'def');
insert into "new"."demo"."q""tst" values (3, 'ghi');

create text index on "new"."demo"."q""tst" ("d""t") with key "i""d";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": text index on new.demo.q\"test created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


insert into "new"."demo"."q""tst" values (4, 'efg');
update "new"."demo"."q""tst" set "d""t" = 'xyz' where "i""d" = 2;
delete from "new"."demo"."q""tst" where "i""d" = 1;

select "i""d" from "new"."demo"."q""tst" where contains ("d""t", 'abc');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": q\"tst contains 'abc' word in " $ROWCNT " rows \n";


select "i""d" from "new"."demo"."q""tst" where contains ("d""t", 'def');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": q\"tst contains 'def' word in " $ROWCNT " rows \n";

select "i""d" from "new"."demo"."q""tst" where contains ("d""t", 'efg');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": q\"tst contains 'efg' word in doc_id " $LAST[1] " \n";

select "i""d" from "new"."demo"."q""tst" where contains ("d""t", 'xyz');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": q\"tst contains 'xyz' word in doc_id " $LAST[1] " \n";

select "i""d" from "new"."demo"."q""tst" where contains ("d""t", 'ghi');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": q\"tst contains 'efg' word in doc_id " $LAST[1] " \n";


drop table "new"."demo"."q""tst_d""t_WORDS";

select P_NAME from SYS_PROCEDURES where P_NAME like 'new%demo%_log';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": freetext procedures cleared " $ROWCNT " (procs) \n";

select T_NAME from SYS_TRIGGERS where T_NAME like 'new%demo%_log';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": freetext triggers cleared " $ROWCNT " (procs) \n";


select "i""d" from "new"."demo"."q""tst" where contains ("d""t", 'ghi');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": text index on new.demo.q\"test dropped : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table fth;
create table fth (id integer not null primary key, dt varchar, c1 varchar);

create procedure fth_dt_index_hook (inout vtb any, inout d_id integer)
{
  declare data any;
  data := coalesce ((select concat (coalesce (dt, ''), ' ', c1) from fth where id = d_id), null);
--  dbg_obj_print ('ins: ', data);	
  if (data is null)
    return 0;
  vt_batch_feed (vtb, data, 0);
  return 1;  
}

create procedure fth_dt_unindex_hook (inout vtb any, inout d_id integer)
{
  declare data any;
  data := coalesce ((select concat (coalesce (dt, ''), ' ', c1) from fth where id = d_id), null);
--  dbg_obj_print ('del: ', data);	
  if (data is null)
    return 0;
  vt_batch_feed (vtb, data, 1);
  return 1;  
}

insert into fth values (1, 'abc', 'one');
insert into fth values (2, 'def', 'two');
insert into fth values (3, null, 'zero');

create text index on fth (dt) with key id using function;
--create text index on fth (dt);

insert into fth values (4, null, 'zeroize');

select id from fth where contains (dt, 'abc');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'abc' word in doc_id " $LAST[1] " \n";

select id from fth where contains (dt, 'def');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'def' word in doc_id " $LAST[1] " \n";

select id from fth where contains (dt, 'one');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'one' word in doc_id " $LAST[1] " \n";

select id from fth where contains (dt, 'two');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'two' word in doc_id " $LAST[1] " \n";

select id from fth where contains (dt, 'zero');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zero' word (the content is null) in doc_id " $LAST[1] " \n";

select id from fth where contains (dt, 'zeroize');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zeroize' word (the content is null) in doc_id " $LAST[1] " \n";


delete from fth where id = 1;
delete from fth where id = 4;

select id from fth where contains (dt, 'abc');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'abc' word in " $ROWCNT " rows after delete \n";

select id from fth where contains (dt, 'one');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'one' word in " $ROWCNT " rows after delete \n";

select id from fth where contains (dt, 'zeroize');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zeroize' word in " $ROWCNT " rows after delete \n";


update fth set dt = 'xyz' , c1 = 'bcd' where id = 2;

update fth set dt = null, c1 = 'upd zero' where id = 3;

select id from fth where contains (dt, 'def');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'def' word in " $ROWCNT " rows  after update \n";


select id from fth where contains (dt, 'xyz');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'xyz' word in doc_id " $LAST[1] " after update \n";

select id from fth where contains (dt, 'two');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'two' word in " $ROWCNT " rows after update \n";


select id from fth where contains (dt, 'bcd');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'bcd' word in doc_id " $LAST[1] " after update \n";

select id from fth where contains (dt, 'zero and upd');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zero and upd' (the content is null) word in doc_id " $LAST[1] " after update \n";


delete from fth;

ECHO BOTH "Testing hook functions in batch mode \n"

;

vt_batch_update ('fth', 'ON', 0);

insert into fth values (1, 'abc', 'one');
insert into fth values (2, 'def', 'two');
insert into fth values (3, null, 'zeroize');
delete from fth where id = 1;
update fth set dt = 'xyz' , c1 = 'bcd' where id = 2;
update fth set dt = null , c1 = 'zero' where id = 3;
VT_INC_INDEX_DB_DBA_fth ();



select id from fth where contains (dt, 'abc');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'abc' word in " $ROWCNT " rows after delete \n";

select id from fth where contains (dt, 'one');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'one' word in " $ROWCNT " rows after delete \n";

select id from fth where contains (dt, 'def');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'def' word in " $ROWCNT " rows  after update \n";

select id from fth where contains (dt, 'zeroize');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zeroize' word in " $ROWCNT " rows  after update \n";

select id from fth where contains (dt, 'zero');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zero' word in " $ROWCNT " rows  after update \n";


select id from fth where contains (dt, 'xyz');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'xyz' word in doc_id " $LAST[1] " after update \n";

select id from fth where contains (dt, 'two');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'two' word in " $ROWCNT " rows after update \n";


select id from fth where contains (dt, 'bcd');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'bcd' word in doc_id " $LAST[1] " after update \n";

delete from fth;

insert into fth values (1, 'abc', 'one');
VT_INC_INDEX_DB_DBA_fth ();
insert into fth values (2, 'def', 'two');
VT_INC_INDEX_DB_DBA_fth ();
delete from fth where id = 1;
VT_INC_INDEX_DB_DBA_fth ();
update fth set dt = 'xyz' , c1 = 'bcd' where id = 2;
VT_INC_INDEX_DB_DBA_fth ();



select id from fth where contains (dt, 'abc');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'abc' word in " $ROWCNT " rows after delete \n";

select id from fth where contains (dt, 'one');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'one' word in " $ROWCNT " rows after delete \n";

select id from fth where contains (dt, 'def');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'def' word in " $ROWCNT " rows  after update \n";

select id from fth where contains (dt, 'zero');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'zero' word in " $ROWCNT " rows  after delete \n";


select id from fth where contains (dt, 'xyz');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'xyz' word in doc_id " $LAST[1] " after update \n";

select id from fth where contains (dt, 'two');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'two' word in " $ROWCNT " rows after update \n";

select id from fth where contains (dt, 'bcd');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tfh contains 'bcd' word in doc_id " $LAST[1] " after update \n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: freetext (qualifiers, function hooks) tests\n";
