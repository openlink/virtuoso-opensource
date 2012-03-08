--
--  trepl_ddl.sql
--
--  $Id$
--
--  DDL replication suite
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
--  Start the test
--
echo BOTH "\nSTARTED: DDL replication tests (trepl_ddl.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;
--set echo on;

connect;
ECHO BOTH "DSNs for subscriber: " $U{ds2} " publisher: " $U{ds1}"\n";

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

create procedure REPL_TS_GET_SYNC_LEVEL (in srvr varchar, in acct varchar, out level integer, out stat integer)
  {
    repl_status (srvr, acct, level, stat);
  };

REPL_UNPUBLISH ('DDL');

REPL_PUBLISH ('DDL', 'ddl.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL pub created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table RDDL_T1;
create table RDDL_T1 (ID integer primary key, DATA varchar (20));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDDL_T1 table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T1 (ID, DATA) values (1, 'a');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 1 row inserted in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table RDDL_T2;
create table RDDL_T2 (ID integer primary key, DATA varchar (20), FK_ID integer, FK_ID2 integer);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDDL_T2 table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (1, 'a', 1, 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 1 row inserted in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table RDDL_OUT1;
create table RDDL_OUT1 (ID integer primary key, DATA varchar (20));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDDL_OUT table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_OUT1 (ID, DATA) values (1, 'a');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 1 row inserted in RDDL_OUT1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('DDL', 'DB.DBA.RDDL_T1', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDDL_T1 added to DDL pub : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('DDL', 'DB.DBA.RDDL_T2', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDDL_T2 added to DDL pub : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

create procedure WAIT_FOR_SYNC (in srv varchar, in acct varchar, in _uid varchar, in _pwd varchar)
{
  declare level, stat integer;
  stat := 0;
  REPL_SYNC (srv, acct, _uid, _pwd);
  declare rexec_params any;

  rexec_params := vector (acct,
    vector ('out', 'integer', 4),
    vector ('out', 'integer', 4));

  rexecute ('$U{ds1}', 'REPL_TS_GET_SYNC_LEVEL (repl_this_server (),?,?,?)',
          null, null, rexec_params);
  repl_status (srv, acct, level, stat);
  while (level < (rexec_params[2] - 1) or stat <> 2)
    {
      repl_status (srv, acct, level, stat);
      delay (2);
      if (stat = 3)
	{
	  dbg_obj_print ('The subscriber is disconnected!');
	  REPL_SYNC (srv, acct, _uid, _pwd);
          repl_status (srv, acct, level, stat);
	  if (stat = 3)
	    goto end_sync;
	}
    }
  return rexec_params[2];
end_sync:
  signal ('TRSYN', 'Replication sync failed');
};

REPL_UNSUBSCRIBE ('rep1', '$U{ds1}', null);
drop table RDDL_OUT1;
drop table RDDL_T2;
drop table RDDL_T1;

REPL_SERVER ('rep1', '$U{ds1}', 'localhost:$U{ds1}');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": pub server added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_SUBSCRIBE ('rep1', 'DDL', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subscription 'DDL' added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_INIT_COPY ('rep1', 'DDL', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subscription 'DDL' inited : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from DB.DBA.RDDL_T1;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DB.DBA.RDDL_T1 : rows=" $LAST[1] "\n";

select count(*) from DB.DBA.RDDL_T2;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DB.DBA.RDDL_T2 : rows=" $LAST[1] "\n";

select count(*) from DB.DBA.RDDL_OUT1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no DB.DBA.RDDL_OUT1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

-- ALTER TABLE ADD COL check

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

alter table RDDL_T1 add NEWCOL varchar (20);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL VC(20) added to RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update RDDL_T1 set NEWCOL = 'b';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL set in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select NEWCOL from RDDL_T1;
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL in RDDL_T1 : LAST[1]=" $LAST[1] "\n";

-- ALTER TABLE modify COL check

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

alter table RDDL_T1 modify NEWCOL varchar (40);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL VC(20) added to RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select COL_PREC from DB.DBA.SYS_COLS where "TABLE" = 'DB.DBA.RDDL_T1' and "COLUMN" = 'NEWCOL';
ECHO BOTH $IF $EQU $LAST[1] 40  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL is now VC(40) : " $LAST[1] "\n";

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select COL_PREC from DB.DBA.SYS_COLS where "TABLE" = 'DB.DBA.RDDL_T1' and "COLUMN" = 'NEWCOL';
ECHO BOTH $IF $EQU $LAST[1] 40  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL is now VC(40) : " $LAST[1] "\n";

-- ALTER TABLE drop COL check

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

alter table RDDL_T1 drop NEWCOL;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NEWCOL VC(20) removed from RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select NEWCOL from RDDL_T1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no NEWCOL in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select NEWCOL from RDDL_T1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no NEWCOL in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ALTER TABLE add constraint CUNQ1 UNIQUE (DATA)

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

alter table RDDL_T1 add constraint CUNQ UNIQUE (DATA);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CUNQ UNIQUE (DATA) added to RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T1 (ID, DATA) values (2, 'a');
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UNIQUE(DATA) violated in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SYS_CONSTRAINTS;
insert into RDDL_T1 (ID, DATA) values (2, 'a');
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UNIQUE(DATA) violated in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ALTER TABLE drop constraint CUNQ1 UNIQUE (DATA)

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

alter table RDDL_T1 drop constraint CUNQ;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CUNQ UNIQUE (DATA) dropped from RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T1 (ID, DATA) values (2, 'a');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no UNIQUE(DATA) in effect in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RDDL_T1 where ID = 2;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SYS_CONSTRAINTS;
insert into RDDL_T1 (ID, DATA) values (2, 'a');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no UNIQUE(DATA) in effect in RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RDDL_T1 where ID <> 1;

-- ALTER TABLE add foreign key

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

select * from RDDL_T2;
select * from RDDL_T1;
alter table RDDL_T2 add constraint CFK1 foreign key (FK_ID) references RDDL_T2 (ID);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CFK1 FK added to RDDL_T1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table RDDL_T2 add constraint CFK2 foreign key (FK_ID2) references RDDL_OUT1 (ID);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CFK2 FK added to RDDL_OUT1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (5, 'b', 2, 1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CFK1 violated in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (6, 'b', 1, 2);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CFK2 violated in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RDDL_T2 where ID <> 1;
checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (9, 'b', 2, 1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CFK1 violated in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (10, 'b', 1, 2);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no CFK2 in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RDDL_T2 where id <> 1;
checkpoint;

-- ALTER TABLE drop constraint CFK FOREIGN KEY

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the publisher : " $LAST[1] "\n";

alter table RDDL_T2 drop constraint CFK1;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CFK1 foreign key dropped from RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (50, 'b', 2, 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no CFK1 to violate in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RDDL_T1 where ID <> 1;

checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
select repl_this_server ();
ECHO BOTH $IF $EQU $LAST[1] rep2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected to the subscriber : " $LAST[1] "\n";

ECHO BOTH "Waiting for sync\n";
select WAIT_FOR_SYNC ('rep1', 'DDL', 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DDL sub synced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SYS_CONSTRAINTS;
insert into RDDL_T2 (ID, DATA, FK_ID, FK_ID2) values (500, 'b', 2, 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no CFK1 to violate in RDDL_T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from RDDL_T1 where ID <> 1;
--
-- End of test
--
ECHO BOTH "COMPLETED: DDL replication tests (trepl_ddl.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
