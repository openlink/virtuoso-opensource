--
--  $Id: tft_offband.sql,v 1.6.10.1 2013/01/02 16:15:09 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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
ECHO BOTH "STARTED: TEXT INDEX OFFBAND DATA TESTS\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;
drop table toff;
create table toff (id integer not null primary key, dt long varchar, c_o_1 varchar, c_o_2 varchar);
insert into toff (id, dt, c_o_1, c_o_2) values (1,'abc','abc1', 'abc2');
insert into toff (id, dt, c_o_1, c_o_2) values (2,'cde','cde1', 'cde2');
insert into toff (id, dt, c_o_1, c_o_2) values (3,'efg','efg1', 'efg2');

create text index on toff (dt) clustered with (c_o_1, c_o_2);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEXT INDEX CREATED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into toff (id, dt, c_o_1, c_o_2) values (4,'xyz','xyz1', 'xyz2');
insert into toff (id, dt, c_o_1, c_o_2) values (5,'xyzz','xyzz1', 'xyzz2');

select c_o_1 from toff where contains (dt, 'abc',  OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "abc1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abc' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from toff where contains (dt, 'abc', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "abc2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abc' produces offband data member 2 : " $LAST[1] "\n";

select c_o_1 from toff where contains (dt, 'cde', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "cde1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from toff where contains (dt, 'cde', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "cde2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 2 : " $LAST[1] "\n";

select c_o_1 from toff where contains (dt, 'efg', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "efg1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'efg' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from toff where contains (dt, 'efg', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "efg2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'efg' produces offband data member 2 : " $LAST[1] "\n";

select c_o_1 from toff where contains (dt, 'xyz', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "xyz1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'xyz' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from toff where contains (dt, 'xyz', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "xyz2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'xyx' produces offband data member 2 : " $LAST[1] "\n";

select c_o_1 from toff where contains (dt, 'xyzz', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "xyzz1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'xyzz' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from toff where contains (dt, 'xyzz', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "xyzz2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'xyzz' produces offband data member 2 : " $LAST[1] "\n";


update toff set dt = 'abra' where id = 1;
select c_o_1 from toff where contains (dt, 'abra', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "abc1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abra' produces offband data member 1 : " $LAST[1] " after update\n";

select c_o_2 from toff where contains (dt, 'abra', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "abc2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abra' produces offband data member 2 : " $LAST[1] " after update\n";


delete from toff where id = 5;
select c_o_1 from toff where contains (dt, 'xyzz', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'xyzz' produces " $ROWCNT " rows after delete\n";

select c_o_2 from toff where contains (dt, 'xyzz', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'xyzz' produces " $ROWCNT " rows after delete\n";


update toff set c_o_1 = 'c_o_1' where id = 2;
update toff set c_o_2 = 'c_o_2' where id = 3;
select c_o_1 from toff where contains (dt, 'cde', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "c_o_1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 1 : " $LAST[1] " after offband data update\n";

select c_o_2 from toff where contains (dt, 'cde', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "cde2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 2 : " $LAST[1] " after offband data update\n";

select c_o_1 from toff where contains (dt, 'efg', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "efg1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'efg' produces offband data member 1 : " $LAST[1] " after offband data update\n";

select c_o_2 from toff where contains (dt, 'efg', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "c_o_2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'efg' produces offband data member 2 : " $LAST[1] " after offband data update\n";

insert into toff (id, dt, c_o_1, c_o_2) values (99,'abc cde','abccde1', 'abccde2');
select c_o_1 from toff where contains (dt, 'cde and not abc', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "c_o_1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde and not abc' produces offband data member 1 : " $LAST[1] "\n";



vt_batch_update ('DB.DBA.TOFF', 'ON', 0);
update toff set c_o_1 = concat (c_o_1, 'qq');
vt_inc_index_db_dba_toff ();
select c_o_1 from toff where contains (dt, 'abc', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "abccde1qq"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $last[1] " as offband after batch update\n";



ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: TEXT INDEX OFFBAND DATA TEST\n";
