--  
--  $Id$
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
connect;
dbg_obj_print('hello, ds1');

set DSN=$U{ds2};
reconnect;

dbg_obj_print('hello, ds2');

set DSN=$U{ds1};
reconnect;



ECHO BOTH "STARTED: freetext interaction with transaction log, part 1\n";

drop table TOFF;
create table TOFF (id integer not null primary key, dt long varchar, c_o_1 varchar, c_o_2 varchar);
insert into TOFF (id, dt, c_o_1, c_o_2) values (1,'abc','abc1', 'abc2');
insert into TOFF (id, dt, c_o_1, c_o_2) values (2,'cde','cde1', 'cde2');
insert into TOFF (id, dt, c_o_1, c_o_2) values (3,'efg','efg1', 'efg2');

create text index on TOFF (dt) clustered with (c_o_1, c_o_2);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEXT INDEX CREATED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TOFF (id, dt, c_o_1, c_o_2) values (4,'xyz','xyz1', 'xyz2');
insert into TOFF (id, dt, c_o_1, c_o_2) values (5,'xyzz','xyzz1', 'xyzz2');

select c_o_1 from TOFF where contains (dt, 'abc',  OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "abc1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abc' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from TOFF where contains (dt, 'abc', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "abc2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abc' produces offband data member 2 : " $LAST[1] "\n";

select c_o_1 from TOFF where contains (dt, 'cde', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "cde1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from TOFF where contains (dt, 'cde', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "cde2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 2 : " $LAST[1] "\n";




drop table FTTEST;
create table FTTEST (ID integer not null primary key, DATA long varchar);
create text index on FTTEST (DATA) WITH KEY ID language 'xxx';
vt_batch_update ('FTTEST', 'ON', NULL);

sequence_set ('FTTEST', 1, 0);
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/dbconcepts.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/intl.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/odbcimplementation.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/ptune.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/repl.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/server.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/sqlfunctions.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/sqlprocedures.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/sqlreference.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/tsales.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/user.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/vdbconcepts.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('FTTEST'),    file_to_string ('../docsrc/virtdocs.xml'));

vt_batch_update ('DB.DBA.FTTEST', 'ON', 0);
vt_inc_index_DB_DBA_FTTEST ();

select count(*) from FTTEST where contains (DATA, 'EXPLAIN');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in contains : EXPLAIN\n";
dbg_obj_print ('table & index created');


DROP TABLE FTT1;
CREATE TABLE FTT1 (ID INTEGER IDENTITY NOT NULL PRIMARY KEY, FILE varchar,  DT LONG VARCHAR IDENTIFIED BY FILE);
CREATE TEXT XML INDEX ON FTT1 (DT);
INSERT INTO FTT1 (FILE,DT) values ('/dbconcepts.xml',file_to_string ('../docsrc/dbconcepts.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/intl.xml',file_to_string ('../docsrc/intl.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/odbcimplementation.xml',file_to_string ('../docsrc/odbcimplementation.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/ptune.xml',file_to_string ('../docsrc/ptune.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/repl.xml',file_to_string ('../docsrc/repl.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/server.xml',file_to_string ('../docsrc/server.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/sqlfunctions.xml',file_to_string ('../docsrc/sqlfunctions.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/sqlprocedures.xml',file_to_string ('../docsrc/sqlprocedures.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/sqlreference.xml',file_to_string ('../docsrc/sqlreference.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/vdbconcepts.xml',file_to_string ('../docsrc/vdbconcepts.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/virtdocs.xml',file_to_string ('../docsrc/virtdocs.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/ce.xml',file_to_string ('../ce.xml'));

select t from FTT1 where xpath_contains (DT, '//title', t);
echo both $if $equ $rowcnt 792 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title\n";

select t from FTT1 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]', t);
echo both $if $equ $rowcnt 4 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]\n";
echo both $if $equ $last[1]  "<title>SQL_TXN_ISOLATION</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]\n";

select t from FTT1 where xpath_contains (DT, '//title [.=''ISOLATION'' ]', t);
echo both $if $equ $rowcnt 2 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]\n";

select t from FTT1 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 16 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from FTT1 where xpath_contains (DT, '//title [.=''ISOLATION'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]/ancestor::*/title\n";

select t from FTT1 where xpath_contains (DT, '//chapter/title', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title\n";

select t from FTT1 where xpath_contains (DT, '//chapter/title[position () = 1]', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title[position () = 1]\n";

select count (*) from FTT1 where xpath_contains (DT, '//chapter//para[position () > 10]', t);
echo both $if $equ $last[1] 6 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter//para[position () > 10]\n";

select count (*) from FTT1 where xpath_contains (DT, '//chapter/descendant::para[position () > 10]', t);
echo both $if $equ $last[1] 1630 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter/descendant::para[position () > 10]\n";

DROP TABLE FTT2;
CREATE TABLE FTT2 (ID INTEGER IDENTITY NOT NULL PRIMARY KEY, FILE varchar,  DT LONG VARCHAR IDENTIFIED BY FILE);
CREATE TEXT XML INDEX ON FTT2 (DT);
INSERT INTO FTT2 (FILE,DT) values ('/dbconcepts.xml', xml_persistent (file_to_string ('../docsrc/dbconcepts.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/intl.xml', xml_persistent (file_to_string ('../docsrc/intl.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/odbcimplementation.xml', xml_persistent (file_to_string ('../docsrc/odbcimplementation.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/ptune.xml', xml_persistent (file_to_string ('../docsrc/ptune.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/repl.xml', xml_persistent (file_to_string ('../docsrc/repl.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/server.xml', xml_persistent (file_to_string ('../docsrc/server.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/sqlfunctions.xml', xml_persistent (file_to_string ('../docsrc/sqlfunctions.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/sqlprocedures.xml', xml_persistent (file_to_string ('../docsrc/sqlprocedures.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/sqlreference.xml', xml_persistent (file_to_string ('../docsrc/sqlreference.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/vdbconcepts.xml', xml_persistent (file_to_string ('../docsrc/vdbconcepts.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/virtdocs.xml', xml_persistent (file_to_string ('../docsrc/virtdocs.xml')));
INSERT INTO FTT2 (FILE,DT) values ('/ce.xml', xml_persistent (file_to_string ('../ce.xml')));

select t from FTT2 where xpath_contains (DT, '//title', t);
echo both $if $equ $rowcnt 792 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title\n";

select t from FTT2 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]', t);
echo both $if $equ $rowcnt 4 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]\n";
echo both $if $equ $last[1]  "<title>SQL_TXN_ISOLATION</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]\n";

select t from FTT2 where xpath_contains (DT, '//title [.=''ISOLATION'' ]', t);
echo both $if $equ $rowcnt 2 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]\n";

select t from FTT2 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 16 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from FTT2 where xpath_contains (DT, '//title [.=''ISOLATION'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]/ancestor::*/title\n";

select t from FTT2 where xpath_contains (DT, '//chapter/title', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title\n";

select t from FTT2 where xpath_contains (DT, '//chapter/title[position () = 1]', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title[position () = 1]\n";

select count (*) from FTT1 where xpath_contains (DT, '//chapter//para[position () > 10]', t);
echo both $if $equ $last[1] 6 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter//para[position () > 10]\n";

select count (*) from FTT1 where xpath_contains (DT, '//chapter/descendant::para[position () > 10]', t);
echo both $if $equ $last[1] 1630 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter/descendant::para[position () > 10]\n";

--REPL_UNPUBLISH ('tbl');
REPL_PUBLISH ('tblx', 'tblx.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": tblx account created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('tblx', 'DB.DBA.FTTEST', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'FTTEST' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
dbg_obj_print ('text table published');

REPL_PUB_ADD ('tblx', 'DB.DBA.TOFF', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'TOFF' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
dbg_obj_print ('cluster table published');

REPL_PUB_ADD ('tblx', 'DB.DBA.FTT1', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'FTT1' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
dbg_obj_print ('xml table published');

REPL_PUB_ADD ('tblx', 'DB.DBA.FTT2', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'FTT2' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
dbg_obj_print ('xml table published');

set DSN=$U{ds2};
reconnect;

drop table FTTEST;
dbg_obj_print ('let''s subscribe');

select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

REPL_SERVER ('rep1', '$U{ds1}', 'localhost:$U{ds1}');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": server added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--REPL_UNSUBSCRIBE ('rep1', 'tbl', null);
REPL_SUBSCRIBE ('rep1', 'tblx', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": subscription 'tblx' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--checkpoint;
--SYNC_REPL();

select TI_TYPE as t, TI_ITEM as i, TI_OPTIONS as opt, TI_DAV_USER as dav_u, TI_DAV_GROUP as dav_g from DB.DBA.SYS_TP_ITEM   order by 1;

DB..REPL_INIT_COPY ('rep1', 'tblx');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": data from 'tblx' copied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from DB.DBA.FTTEST;
ECHO BOTH $IF $EQU $LAST[1] 13  "PASSED" "***FAILED";
ECHO BOTH ": definition for table 'FTTEST' added : rows=" $LAST[1] "\n";

select count(*) from FTTEST where contains (DATA, 'EXPLAIN');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in contains : EXPLAIN\n";



select c_o_1 from TOFF where contains (dt, 'abc',  OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "abc1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abc' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from TOFF where contains (dt, 'abc', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "abc2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'abc' produces offband data member 2 : " $LAST[1] "\n";

select c_o_1 from TOFF where contains (dt, 'cde', OFFBAND, c_o_1);
ECHO BOTH $IF $EQU $LAST[1] "cde1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 1 : " $LAST[1] "\n";

select c_o_2 from TOFF where contains (dt, 'cde', OFFBAND, c_o_2);
ECHO BOTH $IF $EQU $LAST[1] "cde2"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": query 'cde' produces offband data member 2 : " $LAST[1] "\n";


select t from FTT1 where xpath_contains (DT, '//title', t);
echo both $if $equ $rowcnt 792 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title\n";

select t from FTT1 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]', t);
echo both $if $equ $rowcnt 4 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]\n";
echo both $if $equ $last[1]  "<title>SQL_TXN_ISOLATION</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]\n";

select t from FTT1 where xpath_contains (DT, '//title [.=''ISOLATION'' ]', t);
echo both $if $equ $rowcnt 2 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]\n";

select t from FTT1 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 16 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from FTT1 where xpath_contains (DT, '//title [.=''ISOLATION'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]/ancestor::*/title\n";

select t from FTT1 where xpath_contains (DT, '//chapter/title', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title\n";

select t from FTT1 where xpath_contains (DT, '//chapter/title[position () = 1]', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title[position () = 1]\n";

select count (*) from FTT1 where xpath_contains (DT, '//chapter//para[position () > 10]', t);
echo both $if $equ $last[1] 6 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter//para[position () > 10]\n";

select count (*) from FTT1 where xpath_contains (DT, '//chapter/descendant::para[position () > 10]', t);
echo both $if $equ $last[1] 1630 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter/descendant::para[position () > 10]\n";


select t from FTT2 where xpath_contains (DT, '//title', t);
echo both $if $equ $rowcnt 792 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title\n";

select t from FTT2 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]', t);
echo both $if $equ $rowcnt 4 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]\n";
echo both $if $equ $last[1]  "<title>SQL_TXN_ISOLATION</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]\n";

select t from FTT2 where xpath_contains (DT, '//title [.=''ISOLATION'' ]', t);
echo both $if $equ $rowcnt 2 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]\n";

select t from FTT2 where xpath_contains (DT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 16 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from FTT2 where xpath_contains (DT, '//title [.=''ISOLATION'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]/ancestor::*/title\n";

select t from FTT2 where xpath_contains (DT, '//chapter/title', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title\n";

select t from FTT2 where xpath_contains (DT, '//chapter/title[position () = 1]', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title[position () = 1]\n";

select count (*) from FTT2 where xpath_contains (DT, '//chapter//para[position () > 10]', t);
echo both $if $equ $last[1] 6 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter//para[position () > 10]\n";

select count (*) from FTT2 where xpath_contains (DT, '//chapter/descendant::para[position () > 10]', t);
echo both $if $equ $last[1] 1630 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter/descendant::para[position () > 10]\n";

