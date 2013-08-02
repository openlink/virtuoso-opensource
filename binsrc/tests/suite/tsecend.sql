--
--  tsecend.sql
--
--  $Id: tsecend.sql,v 1.6.10.2 2013/01/02 16:15:23 source Exp $
--
--  Test Security
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

ECHO BOTH "STARTED: " $ARGV[4] "  -- Ending and Cleanup\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

delete user u1;
-- XXX
--ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DELETE USER u1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select U_GROUP from SYS_USERS where U_NAME = 'U1';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select U_GROUP from SYS_USERS where U_NAME = 'U1'; after DELETE USER u1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U1' after DELETE USER u1;\n";

-- Use tableprivileges or columnprivileges instead of list_grants:
TABLEPRIVILEGES SEC_TEST_2;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLEPRIVILEGES SEC_TEST_2 after DELETE USER u1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
--ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_2 after DELETE USER u1;\n";

ECHO BOTH $IF $EQU $LAST[5] "U2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The remaining privilege is granted to " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] "SELECT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[6] "\n";


--
-- This should delete the remaining grant on SEC_TEST_2 from SYS_GRANTS:
--

drop table SEC_TEST_2;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DROP TABLE SEC_TEST_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

TABLEPRIVILEGES SEC_TEST_2;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLEPRIVILEGES SEC_TEST_2 after DROP TABLE SEC_TEST_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_2 after DROP TABLE SEC_TEST_2;\n";

delete user u2;
-- XXX
--ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DELETE USER u2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select U_GROUP from SYS_USERS where U_NAME = 'U2';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select U_GROUP from SYS_USERS where U_NAME = 'U2'; after DELETE USER u2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U2' after DELETE USER u2;\n";

-- Because grants on SEC_TEST_4 were granted for u1 and u2 only and now
-- that the both users have been deleted, it means that there should be
-- no grants anymore on table SEC_TEST_4:
TABLEPRIVILEGES SEC_TEST_4;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLEPRIVILEGES SEC_TEST_4 after DELETE USER u2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
--ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_4 after DELETE USER u2;\n";

--
-- no user, should produce: *** Error 42000: No user to delete
--
delete user u99;
ECHO BOTH $IF $NEQ $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DELETE USER u99; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete user u4;
-- XXX
--ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DELETE USER u4; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select U_GROUP from SYS_USERS where U_NAME = 'U4';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select U_GROUP from SYS_USERS where U_NAME = 'U4'; after DELETE USER u4; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U4' after DELETE USER u4;\n";

delete user u3;
-- XXX
--ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DELETE USER u3; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select U_GROUP from SYS_USERS where U_NAME = 'U3';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select U_GROUP from SYS_USERS where U_NAME = 'U3'; after DELETE USER u3; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U3' after DELETE USER u3;\n";

delete user u5;
-- XXX
--ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DELETE USER u5; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select U_GROUP from SYS_USERS where U_NAME = 'U5';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select U_GROUP from SYS_USERS where U_NAME = 'U5'; after DELETE USER u5; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U5' after DELETE USER u5;\n";

--
-- There should be no grants on any of the tables SEC_TEST_% anymore:
--
TABLEPRIVILEGES SEC_TEST_%;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLEPRIVILEGES SEC_TEST_% after all grantees have been deleted; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
--ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $ROWCNT " grants on tables like 'SEC_TEST_%' after all grantees have been deleted.\n";

--
-- Neither there should be any grants left on any procedure like secp_1
-- secp_2 or sec_u1proc:
--
SELECT * from SYS_GRANTS where G_OBJECT like 'sec%';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT * from SYS_GRANTS where G_OBJECT like 'sec%'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on any object like 'sec%' after all grantees have been deleted.\n";

drop table SEC_TEST_4;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DROP TABLE SEC_TEST_4; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table SEC_TEST_1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DROP TABLE SEC_TEST_1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table SEC_TEST_3;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DROP TABLE SEC_TEST_3; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- There should not be any tables left in SYS_KEYS with
-- name like 'SEC_TEST_%';

-- SELECT * from SYS_KEYS where KEY_TABLE like 'SEC_TEST_%';
-- Well, use SQL API-function instead:
TABLES SEC_TEST_%/TABLE;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLES SEC_TEST_%/TABLE; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " tables with name like 'SEC_TEST_%' in SYS_KEYS after all test tables have been dropped.\n";


-- suite for bug 1319
delete user B1319;
create user B1319;
reconnect B1319;

drop table B1319..TEST_TABLE;
CREATE TABLE B1319..TEST_TABLE (
      ID    INTEGER,
        NAME  VARCHAR(10) NOT NULL,

	  PRIMARY KEY (ID)
    );


ALTER TABLE B1319..TEST_TABLE MODIFY NAME VARCHAR(255) NOT NULL;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1319: alter table modify of non-DBA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
reconnect dba;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: " $ARGV[4] "  -- Cleanup & Ending\n";
