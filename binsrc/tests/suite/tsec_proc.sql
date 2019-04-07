--
--  tsec_proc.sql
--
--  $Id: tsec_proc.sql,v 1.5.10.1 2013/01/02 16:15:23 source Exp $
--
--  Procedures security tests
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

drop procedure DBA_PROC;
drop procedure DBA_PROC1;
drop procedure P_SEC.P_SEC_PROC;
drop procedure P_SEC.P_SEC_PROC1;
drop procedure P_SEC.P_SEC_PROC_H;

echo BOTH "\nSTARTED: procedure security test suite (tsec_proc.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create user P_SEC;

create procedure DBA_PROC ()
{
  return 'DBA';
};

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by DBA created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DBA_PROC1 ()
{
  return 'DBA1-1';
};

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by DBA to be replaced created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DBA_PROC1 ()
{
  return 'DBA1-2';
};

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by DBA is replaced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select DBA_PROC1 ();

ECHO BOTH $IF $EQU $LAST[1] DBA1-2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by DBA successfully replaced  result : " $LAST[1] "\n";


RECONNECT P_SEC;

CREATE PROCEDURE DBA.DBA_PROC ()
{
  return 'P_SEC1';
};

ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by DBA cannot be replaced by P_SEC : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DBA.DBA_PROC ();

ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by DBA cannot be called by PSEC : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


CREATE PROCEDURE DBA.DBA_PROC2 ()
{
  return 'P_SEC1-1';
};

ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": P_SEC unable to create DBA owned procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


CREATE PROCEDURE P_SEC.P_SEC_PROC ()
{
  return 'P_SEC2';
};

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": qualified procedure owned by P_SEC created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


CREATE PROCEDURE P_SEC.P_SEC_PROC ()
{
  return 'P_SEC2-1';
};

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": qualified procedure owned by P_SEC replaced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select P_SEC_PROC ();
ECHO BOTH $IF $EQU $LAST[1] P_SEC2-1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": qualified procedure owned by P_SEC replaced  successfully result :" $LAST[1] "\n";


CREATE PROCEDURE P_SEC_PROC1 ()
{
  return 'P_SEC3';
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": un-qualified procedure owned by P_SEC created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


CREATE PROCEDURE P_SEC_PROC1 ()
{
  return 'P_SEC3-1';
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": un-qualified procedure owned by P_SEC replaced : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select P_SEC_PROC1 ();
ECHO BOTH $IF $EQU $LAST[1] P_SEC3-1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": un-qualified procedure owned by P_SEC replaced successfully result :" $LAST[1] "\n";

CREATE PROCEDURE P_SEC_PROC_H ()
{
  return DB.DBA.DBA_PROC ();
};

P_SEC_PROC_H ();
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": own procedure cannot call a non-granted : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

RECONNECT dba;


CREATE PROCEDURE P_SEC.P_SEC_PROC ()
{
  return 'P_SEC2-DBA';
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by P_SEC replaced by DBA : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select P_SEC.P_SEC_PROC ();

ECHO BOTH $IF $EQU $LAST[1] P_SEC2-DBA  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure owned by P_SEC replaced successfully by DBA result :" $LAST[1] "\n";


CREATE TABLE SEC_DBA (ID INTEGER, ID2 INTEGER);

CREATE TRIGGER TRIG_SEC_DBA AFTER INSERT ON SEC_DBA {

  DECLARE _ID INTEGER;
  _ID := ID;
  UPDATE SEC_DBA SET ID2 = _ID WHERE ID = _ID;
};

INSERT INTO SEC_DBA (ID) VALUES (12);

SELECT ID2 FROM SEC_DBA WHERE ID = 12;
ECHO BOTH $IF $EQU $LAST[1] 12  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trigger owned by DBA created and tested result: " $LAST[1] "\n";


CREATE PROCEDURE SEC_DBA_PROC ()
{
  RETURN;
}
;


RECONNECT P_SEC;

CREATE TABLE P_SEC_DBA (PID INTEGER, PID1 INTEGER);

CREATE TRIGGER TRIG_P_SEC_DBA AFTER INSERT ON SEC_DBA {

  INSERT INTO P_SEC_DBA (PID) VALUES (ID);

};
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trigger owned by P_SEC cannot be created over DBA table : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



CREATE TRIGGER TRIG_P_SEC_DBA_PROC AFTER INSERT ON P_SEC_DBA {

  SEC_DBA_PROC ();

};
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trigger owned by P_SEC created over own table (with trojan) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


INSERT INTO P_SEC_DBA VALUES (1,1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invoking trigger action to got access to the dba procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DROP TRIGGER TRIG_P_SEC_DBA_PROC;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": P_SEC can drop own trigger : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



ECHO BOTH "COMPLETED: procedures security test suite (tsec_proc.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
