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
ECHO BOTH "STARTED: FREETEXT TRIGGERS TESTS\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

DROP TABLE FTT;
CREATE TABLE FTT (ID INTEGER IDENTITY NOT NULL PRIMARY KEY, DT LONG VARCHAR);
DROP TABLE FTT1;
CREATE TABLE FTT1 (ID INTEGER IDENTITY NOT NULL PRIMARY KEY, FILE varchar,  DT LONG VARCHAR IDENTIFIED BY FILE);
CREATE TEXT INDEX ON FTT (DT);
CREATE TEXT TRIGGER ON FTT;
CREATE TEXT XML INDEX ON FTT1 (DT);
CREATE TEXT TRIGGER ON FTT1;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEXT TRIGGER CREATED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from FTT_DT_HIT;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HITS TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from FTT_DT_QUERY;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": QUERY TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from FTT_DT_USER;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": USER TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA."TT_QUERY_FTT" ('ZARDOZ AND YEAR AND VIRTUOSO', 1, '1', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": QUERY 'ZARDOZ AND YEAR AND VIRTUOSO' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA."TT_QUERY_FTT" ('ZARDOZ AND XYZ', 1, '2', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": QUERY 'ZARDOZ AND XYZ' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DB.DBA."TT_QUERY_FTT" ('ZARDOZ OR XYZ', 1, '3', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": QUERY 'ZARDOZ OR XYZ' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DB.DBA."TT_XPATH_QUERY_FTT1" ('/chapter[@label = ''XI'']', 1, 'x1', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XPATH QUERY '/chapter[@label = ''XI'']' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA."TT_XPATH_QUERY_FTT1" ('/chapter[@label = ''XVI'']', 1, 'x2', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XPATH QUERY '/chapter[@label = ''XVI'']' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA."TT_XPATH_QUERY_FTT1" ('/chapter/sect1[@id = ''OSI'']', 1, 'x3', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XPATH QUERY '/chapter/sect1[@id = ''OSI'']' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA."TT_XPATH_QUERY_FTT1" ('//title [. like ''%ISOLATION%'' ]', 1, 'x4', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XPATH QUERY '//title [. like ''%ISOLATION%'' ]' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA."TT_XPATH_QUERY_FTT1" ('//title [.=''ISOLATION'' ]', 1, 'x5', '');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XPATH QUERY '//title [.=''ISOLATION'' ]' ADDED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


INSERT INTO FTT (DT) values (file_to_string ('docsrc/dbconcepts.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/intl.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/odbcimplementation.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/ptune.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/repl.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/server.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/sqlfunctions.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/sqlprocedures.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/sqlreference.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/tsales.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/user.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/vdbconcepts.xml'));
INSERT INTO FTT (DT) values (file_to_string ('docsrc/virtdocs.xml'));

INSERT INTO FTT1 (FILE,DT) values ('/dbconcepts.xml',file_to_string ('docsrc/dbconcepts.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/intl.xml',file_to_string ('docsrc/intl.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/odbcimplementation.xml',file_to_string ('docsrc/odbcimplementation.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/ptune.xml',file_to_string ('docsrc/ptune.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/repl.xml',file_to_string ('docsrc/repl.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/server.xml',file_to_string ('docsrc/server.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/sqlfunctions.xml',file_to_string ('docsrc/sqlfunctions.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/sqlprocedures.xml',file_to_string ('docsrc/sqlprocedures.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/sqlreference.xml',file_to_string ('docsrc/sqlreference.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/tsales.xml',file_to_string ('docsrc/tsales.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/user.xml',file_to_string ('docsrc/user.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/vdbconcepts.xml',file_to_string ('docsrc/vdbconcepts.xml'));
INSERT INTO FTT1 (FILE,DT) values ('/virtdocs.xml',file_to_string ('docsrc/virtdocs.xml'));

SELECT COUNT(*) FROM FTT;
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains count(*) " $LAST[1] " lines\n";

SELECT COUNT(*) from FTT_DT_HIT where TTH_T_ID = (select TT_ID from FTT_DT_QUERY where TT_COMMENT = '1');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains ZARDOZ AND YEAR AND VIRTUOSO " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT_DT_HIT where TTH_T_ID = (select top 1 TT_ID from FTT_DT_QUERY where TT_COMMENT = '2');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains ZARDOZ AND XYZ " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT_DT_HIT where TTH_T_ID = (select top 1 TT_ID from FTT_DT_QUERY where TT_COMMENT = '3');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains ZARDOZ OR XYZ " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT1_DT_HIT where TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x1');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains /chapter[@label = 'XI'] " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT1_DT_HIT where TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x2');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains /chapter[@label = 'XVI'] " $LAST[1] " hits\n";

SELECT FILE from FTT1 where ID = (select TTH_D_ID from  FTT1_DT_HIT where TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x3'));
ECHO BOTH $IF $EQU $LAST[1] '/server.xml' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains /chapter/sect1[@id = 'OSI']  at document " $LAST[1] "\n";

SELECT FILE from FTT1, FTT1_DT_HIT where ID = TTH_D_ID and TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x4');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains '//title [. like ''%ISOLATION%'' ]' in " $ROWCNT " documents\n";

-- the xpath_contains give 2 documents, but in only one batch have ISOLATION
SELECT FILE from FTT1, FTT1_DT_HIT where ID = TTH_D_ID and TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x5');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains '//title [.=''ISOLATION'' ]' in " $ROWCNT " documents\n";


INSERT INTO FTT (DT) values ('ZARDOZ XYZ');

INSERT INTO FTT1 (FILE,DT) values ('/intl.xml',file_to_string ('docsrc/intl.xml'));
UPDATE FTT1 SET DT = '<a></a>' where FILE = '/virtdocs.xml';

SELECT COUNT(*) from FTT_DT_HIT where TTH_T_ID = (select top 1 TT_ID from FTT_DT_QUERY where TT_COMMENT = '2');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains ZARDOZ AND XYZ " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT_DT_HIT where TTH_T_ID = (select top 1 TT_ID from FTT_DT_QUERY where TT_COMMENT = '3');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains ZARDOZ OR XYZ " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT1_DT_HIT where TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x1');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains /chapter[@label = 'XI'] " $LAST[1] " hits\n";

SELECT COUNT(*) from FTT1_DT_HIT where TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x2');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains /chapter[@label = 'XVI'] " $LAST[1] " hits\n";

SELECT FILE from FTT1, FTT1_DT_HIT where ID = TTH_D_ID and TTH_T_ID = (select TT_ID from FTT1_DT_QUERY where TT_COMMENT = 'x4');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT1 contains '//title [. like ''%ISOLATION%'' ]' in " $ROWCNT " documents\n";


DROP TEXT TRIGGER ON FTT;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEXT TRIGGER DROPPED : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

INSERT INTO FTT (DT) values ('ZARDOZ XYZ');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": INSERT AFTER TRIGGER DROP : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from FTT where contains (DT, 'ZARDOZ AND XYZ');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table FTT contains ZARDOZ AND XYZ " $LAST[1] " hits\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: FREETEXT TRIGGERS TESTS\n";
