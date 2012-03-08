--
--  inprocess.sql
--
--  $Id$
--
--  inprocess client tests
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
echo BOTH "\nSTARTED: inprocess suite (inprocess.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure test_txn (in rn integer, in ct integer)
{
  insert into T1 (ROW_NO) values (rn);
  if (ct)
    commit work;
  else
    rollback work;
};

attach table T1 as T2 from ':in-process:$U{LOCALPORT}' user '' password '';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attaching T1 as T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from T2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from T2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table T2 contains " $LAST[1] " rows\n";

rexecute (':in-process:$U{LOCALPORT}', 'select test_txn (2001, 1)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert and commit : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from T1;
ECHO BOTH $IF $EQU $LAST[1] 1001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table T1 contains " $LAST[1] " rows\n";

rexecute (':in-process:$U{LOCALPORT}', 'select test_txn (2002, 0)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert and rollback : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from T1;
ECHO BOTH $IF $EQU $LAST[1] 1001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table T1 contains " $LAST[1] " rows\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: inprocess suite (inprocess.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
