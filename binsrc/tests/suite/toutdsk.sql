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
echo BOTH "STARTED: Out of disk server tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

status ();

drop table tx;
drop table txv;

create table tx (id int, dt long varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tx table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table txv (id int, dt varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": txv table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure toutdsk (in n int, in l int := 10000)
{
  declare i int;
  i := 0;
  while (i < l)
    {
      insert into tx values (i, repeat ('x', n));
      commit work;
      i := i + 1;
    }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure to fill up to possible size created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure toutdsk1 (in n int)
{
  declare i, l int;
  i := 0;
  while (i < 10000)
    {
      insert into txv values (i, repeat ('x', n));
      commit work;
      i := i + 1;
    }
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure to fill up to possible size created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

toutdsk (7000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Out of disk : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Rows inserted in TX = " $LAST[1]  " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

registry_set ('tx', cast ((select count (*) from TX) as varchar));

checkpoint;

toutdsk1 (1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Out of disk : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

status ();

drop table TX;

create table tx (id int, dt long varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tx table created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX: cannot insert the same number of rows as pages are lost atm; must be fixed
-- ideally we should expect to insert the same number of rows
toutdsk (7000, atoi(registry_get ('tx')));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Out of disk : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

status ();

select count (*) from TX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Rows inserted in TX = " $LAST[1]  " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TXV;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Rows inserted in TXV = " $LAST[1]  " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX: hangs te server
--select distinct a.KEY_TABLE from SYS_KEYS a, SYS_KEYS b, SYS_KEYS c where a.KEY_ID <> b.KEY_ID and c.KEY_TABLE = a.KEY_TABLE  order by a.KEY_ID;
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": Out of disk : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Out of disk server tests\n";
