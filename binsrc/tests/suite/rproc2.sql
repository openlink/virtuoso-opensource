--
--  rproc2.sql
--
--  $Id: rproc2.sql,v 1.8.10.2 2013/01/02 16:14:53 source Exp $
--
--  procedure attachment testsuite destination part
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

--
--  Start the test
--
echo BOTH "\nSTARTED: remote procedure suite (rproc2.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

DB.DBA.vd_remote_data_source ('$U{LOCALPORT}', '', 'dba', 'dba');

attach procedure RPROC_RETCODE (in PARAM1 integer) returns integer from '$U{LOCALPORT}';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attaching retcode test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

attach procedure RPROC_INOUT (inout PARAM1 integer) from '$U{LOCALPORT}';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attaching inout params test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

attach procedure RPROC_TEST2 (in P1 varchar, inout P2 varchar, out P3 varchar) returns varchar
  from '$U{LOCALPORT}';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attaching mixed test varchar procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure RPROC_INOUT_WRAP (in PARAM1 integer)
{
  RPROC_INOUT (PARAM1);
  return PARAM1;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure wrapper : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure RPROC_TEST2_VARCHAR (in PARAM varchar)
{
  declare P2, P3, RETCODE varchar;
  P2 := 'P2';
  P3:= NULL;
  RETCODE := RPROC_TEST2 (PARAM, P2, P3);
  result_names (RETCODE, P2, P3);
  result (RETCODE, P2, P3);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure wrapper : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select RPROC_RETCODE (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retcode test procedure with NULL param : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 'NULL' "PASSED" $IF $EQU $U{DO_RPROC} "NO" "SKIPPED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retcode test procedure with NULL param return NULL : RETURN=" $LAST[1] "\n";

select RPROC_RETCODE (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" $IF $EQU $U{DO_RPROC} "NO" "SKIPPED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retcode test procedure with 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" $IF $EQU $U{DO_RPROC} "NO" "SKIPPED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retcode test procedure with 1 param return 11 : RETURN=" $LAST[1] "\n";


select sum (rproc_retcode (row_no) - 10) from t1;
echo both $if $equ $last[1] 599500  "PASSED" "***FAILED";
echo both ":  rproc_retcode on vector\n";


select RPROC_INOUT_WRAP (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure with NULL param : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure with NULL param return NULL : RETURN=" $LAST[1] "\n";

select RPROC_INOUT_WRAP (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure with 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout test procedure with 1 param return 11 : RETURN=" $LAST[1] "\n";

RPROC_TEST2_VARCHAR ('P1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] P1ORET "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed test procedure : RETURN=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] P2O2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed test procedure : INOUT=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] P1O3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed test procedure : OUT=" $LAST[3] "\n";

-- DBEV_DSN_LOGIN test
drop table R1..DBEV_DSN_LOGIN;
attach table U1.DBEV_DSN_LOGIN as R1..DBEV_DSN_LOGIN from '$U{LOCALPORT}';

rexecute ('$U{LOCALPORT}', 'update U1.DBEV_DSN_LOGIN set DATA = user');
select DATA from R1..DBEV_DSN_LOGIN;
ECHO BOTH $IF $EQU $LAST[1] "dba" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBEV_DSN_LOGIN: accessing normal dba table returned " $LAST[1] "\n";

create procedure "DB"."DBA"."DBEV_DSN_LOGIN"
(inout dsn varchar,
 inout user_id varchar,
 inout pwd varchar)
{
  if (user_id = 'dba' and pwd = 'dba')
    {
      -- map U1 to U2
      dbg_obj_print ('mapping dba to u1');
      user_id := 'U1';
      pwd := 'U1';
    }
   dbg_obj_print (dsn, user_id, pwd);
};

rexecute ('$U{LOCALPORT}', 'update U1.DBEV_DSN_LOGIN set DATA = user');
select DATA from R1..DBEV_DSN_LOGIN;
ECHO BOTH $IF $EQU $LAST[1] "U1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBEV_DSN_LOGIN: accessing U1 table returned " $LAST[1] "\n";

drop procedure "DB"."DBA"."DBEV_DSN_LOGIN";
rexecute ('$U{LOCALPORT}', 'update U1.DBEV_DSN_LOGIN set DATA = user');
select DATA from R1..DBEV_DSN_LOGIN;
ECHO BOTH $IF $EQU $LAST[1] "dba" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBEV_DSN_LOGIN: accessing again DBA table returned " $LAST[1] "\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: remote procedure suite (rproc2.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
