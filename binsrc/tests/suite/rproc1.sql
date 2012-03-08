--
--  rproc1.sql
--
--  $Id$
--
--  procedure attachment testsuite
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
echo BOTH "\nSTARTED: remote procedure suite (rproc1.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure RPROC_RETCODE (in PARAM1 integer) returns integer
{
  return PARAM1 + 10;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retcode test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure RPROC_INOUT (inout PARAM1 integer)
{
   PARAM1 := PARAM1 + 10;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure RPROC_TEST2 (in P1 varchar, inout P2 varchar, out P3 varchar) returns varchar
{
  P2 := concat (P2, 'O2');
  P3 := concat (P1, 'O3');
  return concat (P1, 'ORET');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- DBEV_DSN_LOGIN test
drop table DBEV_DSN_LOGIN;

delete user U1;
create user U1;
reconnect U1;
create table DBEV_DSN_LOGIN (DATA varchar primary key);
insert into DBEV_DSN_LOGIN values ('INITITAL');
reconnect dba;
--
-- End of test
--
ECHO BOTH "COMPLETED: remote procedure suite (rproc1.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
