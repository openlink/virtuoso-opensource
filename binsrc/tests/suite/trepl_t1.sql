--  
--  $Id$
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
-- PUBLISHER
connect;
ECHO BOTH "DSNs for subscriber: " $U{ds2} " publisher: " $U{ds1}"\n"
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1 "PASSED" "***FAILED";
ECHO BOTH ": Connected to publisher : " $LAST[1] "\n";


checkpoint;
create table DB.DBA.TEST (id integer, name varchar, tm	datetime, content long varchar, primary key (id, name));
insert into DB.DBA.TEST values (1, 'a', now(), 'xxx');
insert into DB.DBA.TEST values (1, 'b', now(), 'xxx');
insert into DB.DBA.TEST values (1, 'c', now(), 'xxx');
insert into DB.DBA.TEST values (1, 'd', now(), 'xxx');


create table "ab ""cd" ("id key" integer, "ef ""gh" varchar, primary key ("id key"));
insert into "ab ""cd" values (1,'1');

REPL_PUBLISH ('dav', 'dav.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": dav account created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('dav', '/DAV/repl/', 1, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": dav item added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUBLISH ('tbl', 'tbl.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": tbl account created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('tbl', 'DB.DBA.TEST', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'TEST' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('tbl', 'DB.DBA.ab "cd', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'ab ""cd' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

create table B7157 (
  ID integer,
  X long xml,
  primary key (ID)
);
insert into B7157 (ID, X) values (1, xmlelement('node'));

select __tag(X) from B7157;
ECHO BOTH $IF $EQU $LAST[1] 230 "PASSED" "***FAILED";
ECHO BOTH ": B7157 : LAST[1]=" $LAST[1] " (XML ENTITY)\n";

REPL_PUBLISH ('B7157', 'B7157.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": B7157 account created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('B7157', 'DB.DBA.B7157', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'B7157' added to B7157 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

create table B7260 (
  ID integer,
  X long varchar,
  primary key (ID)
);
foreach blob IN words.esp insert into B7260 (ID, X) values (1, ?);

select length(X) from B7260;
ECHO BOTH $IF $EQU $LAST[1] 835106 "PASSED" "***FAILED";
ECHO BOTH ": B7260 : length (X)=" $LAST[1] " (words.esp)\n";

REPL_PUBLISH ('B7260', 'B7260.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": B7260 account created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('B7260', 'DB.DBA.B7260', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": table 'B7260' added to B7260 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";


REPL_SERVER ('rep1', '$U{ds1}', 'localhost:$U{ds1}');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": server added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_SUBSCRIBE ('rep1', 'dav', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": subscription 'dav' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'dav');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": WebDAV content for 'dav' copied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_SUBSCRIBE ('rep1', 'tbl', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": subscription 'tbl' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'tbl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": data from 'tbl' copied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select count(*) from TEST;
ECHO BOTH $IF $EQU $LAST[1] 4  "PASSED" "***FAILED";
ECHO BOTH ": definition for table 'TEST' added : rows=" $LAST[1] "\n";

select count(*) from "ab ""cd";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": definition for table 'ab ""cd' added : rows=" $LAST[1] "\n";

REPL_SUBSCRIBE ('rep1', 'B7157', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": subscription 'B7157' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'B7157');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": data for 'B7157' copied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_SUBSCRIBE ('rep1', 'B7260', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": subscription 'B7260' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'B7260');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": data for 'B7260' copied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
SYNC_REPL();

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

insert into DB.DBA.TEST values (7,'a',now(), repeat('x',1000000));
select count (*) from DB.DBA.TEST;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " rows in test table\n";

insert into "ab ""cd" values (2,'2');
insert into "ab ""cd" values (3,'3');
insert into "ab ""cd" values (4,'4');
delete from "ab ""cd" where "id key" = 4;
update "ab ""cd" set "ef ""gh" = '4' where "id key" = 3;

select count(*) from "ab ""cd";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": Table 'ab ""cd' data changed : rows=" $LAST[1] "\n";


-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";


create procedure WAIT_FOR_SYNC (in srv varchar, in acct varchar)
{
  declare level, stat integer;
  stat := 0;
  while (level < 8)
    {
      delay (2);
      repl_status (srv, acct, level, stat);
      if (stat = 3)
	SYNC_REPL ();
    }
};

WAIT_FOR_SYNC ('rep1', 'tbl');

select count (*) from DB.DBA.TEST;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " rows replicated\n";

select count (*) from DB.DBA.SYS_REPL_ACCOUNTS where SERVER <> repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " replications subscribed\n";

select count (*) from DB.DBA.SYS_TP_ITEM;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " items subscribed\n";

select count (*) from DB."$U{ds1}".TP_ITEM;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " items published from "$U{ds1}"\n";

select count(*) from "ab ""cd";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " rows from ab ""cd replicated\n";

select "ef ""gh" from "ab ""cd" where "id key" = 3;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "*** FAILED";
ECHO BOTH ": 1 row updated with value " $LAST[1] "\n";

select count(*) from "ab ""cd" where "id key" = 4;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " rows from ab ""cd with pk = 4 (1 row deleted)\n";

select __tag(X) from B7157;
ECHO BOTH $IF $EQU $LAST[1] 230 "PASSED" "***FAILED";
ECHO BOTH ": B7157 : LAST[1]=" $LAST[1] " (XML ENTITY)\n";

select length(X) from B7260;
ECHO BOTH $IF $EQU $LAST[1] 835106 "PASSED" "***FAILED";
ECHO BOTH ": B7260 : length (X)=" $LAST[1] " (words.esp)\n";
