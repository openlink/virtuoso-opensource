--
--  $Id: trepl_p1.sql,v 1.10.10.1 2013/01/02 16:15:21 source Exp $
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
-- We are in DS1

create table p_test (id integer, dt varchar, primary key (id));

insert into  p_test values (1, '1');
insert into  p_test values (2, '2');
insert into  p_test values (3, '3');
insert into  p_test values (4, '4');
insert into  p_test values (5, '5');

select count(*) from p_test;
ECHO BOTH $IF $EQU $LAST[1] 5  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " table for procedure replication test filled\n";

create procedure t_proc1 (in i integer)
{
  declare d varchar;
  declare n integer;
  n := 128;
  while (n > 0)
    {
      insert into p_test (id, dt) values (n + 128, cast (n as varchar));
      n := n - 1;
    }
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": test procedure created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure t_proc (in i integer)
{
  declare d varchar;
  select dt into d from p_test where id = i;
  d := concat (d, d);
  update p_test set dt = d where id = i;
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": test procedure 2 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure t_proc_def (in i integer := 6)
{
  declare d varchar;
  select dt into d from p_test where id = i;
  d := concat (d, d);
  update p_test set dt = d where id = i;
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": test procedure def created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

REPL_PUBLISH ('proc', 'proc.log');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": account 'proc' published : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('proc', 'DB.DBA.t_proc', 3, 0, 3);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": procedure added to the publication : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('proc', 'DB.DBA.t_proc1', 3, 0, 3);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": second procedure added to the publication : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

REPL_PUB_ADD ('proc', 'DB.DBA.t_proc_def', 3, 0, 3);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": third procedure added to the publication : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

-- We are in DS2
set DSN=$U{ds2};
reconnect;
create table p_test (id integer, dt varchar, primary key (id));

insert into  p_test values (1, '1');
insert into  p_test values (2, '2');
insert into  p_test values (3, '3');
insert into  p_test values (4, '4');
insert into  p_test values (5, '5');
insert into  p_test values (6, '6');

REPL_SUBSCRIBE ('rep1', 'proc', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": subscription added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'proc');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": definition copied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SYNC_REPL();

-- We are in DS1
set DSN=$U{ds1};
reconnect;

t_proc(1);
t_proc(2);
t_proc(3);
t_proc(4);
t_proc(5);
t_proc_def ();

-- We are in DS2
set DSN=$U{ds2};
reconnect;

create procedure WAIT_FOR_SYNC (in srv varchar, in acct varchar, in n integer)
{
  declare level, stat integer;
  stat := 0;
  while (level < n)
    {
      delay (2);
      repl_status (srv, acct, level, stat);
      if (stat = 3)
	SYNC_REPL ();
    }
};

WAIT_FOR_SYNC ('rep1', 'proc', 7);

select count(*) from p_test where length (dt) = 2;
ECHO BOTH $IF $EQU $LAST[1] 6  "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " procedure calls replicated\n";

-- We are in DS1
set DSN=$U{ds1};
reconnect;

create procedure t_proc (in i integer)
{
  declare d varchar;
  declare n integer;
  n := 128;
  while (n > 6)
    {
      insert into p_test (id, dt) values (n, cast (n as varchar));
      n := n - 1;
    }
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": definition of procedure changed : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

t_proc (1);
t_proc1 (i=>1);

-- We are in DS2
set DSN=$U{ds2};
reconnect;

WAIT_FOR_SYNC ('rep1', 'proc', 10);

select count(*) from p_test;
ECHO BOTH $IF $EQU $LAST[1] 256 "PASSED" "*** FAILED";
ECHO BOTH ": " $LAST[1] " entries in test table replicated with 2 calls (one is keyword parameter call)\n";


