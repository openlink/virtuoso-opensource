--
--  tlogft1.sql
--
--  $Id: tlogft1.sql,v 1.6.10.1 2013/01/02 16:15:13 source Exp $
--
--  Test freetext interaction with transaction log #1
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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

ECHO BOTH "STARTED: freetext interaction with transaction log, part 1\n";
drop table FTTEST;
create table FTTEST (ID integer not null primary key, DATA long varchar);
create text index on FTTEST (DATA) WITH KEY ID;
vt_batch_update ('FTTEST', 'ON', NULL);

sequence_set ('fts', 0, 0);
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/dbconcepts.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/intl.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/odbcimplementation.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/ptune.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/repl.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/server.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/sqlfunctions.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/sqlprocedures.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/sqlreference.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/tsales.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/user.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/vdbconcepts.xml'));
INSERT INTO FTTEST (ID, DATA) values (sequence_next ('fts'),    file_to_string ('docsrc/virtdocs.xml'));

vt_inc_index_DB_DBA_FTTEST ();

select count(*) from FTTEST where contains (DATA, 'EXPLAIN');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in contains : EXPLAIN\n";

ECHO BOTH "COMPLETED: freetext interaction with transaction log, part 1\n";

ECHO BOTH "STARTED: XML_ENTITY interaction with transaction log, part 1\n";
drop table XTLOG;
create table XTLOG (ID INTEGER PRIMARY KEY, DT LONG VARCHAR);
insert into XTLOG values (1, xml_tree_doc ('<document/>'));
insert into XTLOG values (2, xml_tree_doc ('<document2/>'));
select count(*) from XTLOG;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in XTLOG with serialized XML_ENTITY\n";
ECHO BOTH "COMPLETED: XML_ENTITY  interaction with transaction log, part 1\n";
