--
--  tsecu5-1.sql
--
--  $Id: tsecu5-1.sql,v 1.5.10.2 2013/01/02 16:15:25 source Exp $
--
--  Security test #5
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
-- This is run with user u5, for whom should have been granted full
-- administrator access either with the command GRANT ALL PRIVILEGES TO u5;
-- or SET USER GROUP u5 dba;
--

echo BOTH "STARTED: " $ARGV[4] "  -- Changing and Revoking User Privileges\n";

SET ARGV[0] 0;
SET ARGV[1] 0;


revoke select(a),update(c,b) on SEC_TEST_3 from u3,u1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REVOKE update(c,b) ON SEC_TEST_3 FROM u3,u1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

COLUMNPRIVILEGES SEC_TEST_3;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COLUMNPRIVILEGES SEC_TEST_3 after REVOKE update(c,b) ON SEC_TEST_3 FROM u3,u1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- 6 (2*3) - 4 (2*2) should be 2 (2 columns granted for one user):
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " column grants remaining on SEC_TEST_2.\n";

ECHO BOTH $IF $EQU $LAST[6] "U4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The remaining privileges are granted to " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "UPDATE" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[7] "\n";

-- These are for new tests in tsecu3-2.sql:
grant insert on SEC_TEST_3 to u1;
grant select on SEC_TEST_3 to u3;
grant update(a) on SEC_TEST_3 to u1;

--
-- never granted.
-- Should produce: *** Error 01006: Privilege has not been granted.
--
revoke insert on SEC_TEST_2 from public;
ECHO BOTH $IF $EQU $STATE "42S32" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REVOKE insert ON SEC_TEST_2 FROM public; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

revoke execute on secp_1 from public;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REVOKE execute ON secp_1 FROM public; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SELECT * from SYS_GRANTS where G_OBJECT = 'SECP_1';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT * from SYS_GRANTS where G_OBJECT = 'SECP_1'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on any object like 'secp_1' after the revoke above.\n";

revoke select on SEC_TEST_1 from public;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REVOKE select ON SEC_TEST_1 FROM public; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

TABLEPRIVILEGES SEC_TEST_1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLEPRIVILEGES SEC_TEST_1 after REVOKE select ON SEC_TEST_1 FROM public; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants remaining on SEC_TEST_1.\n";

select v2.U_NAME from SYS_USERS v1, SYS_USERS v2
       where v1.U_NAME = 'U3' and v2.U_ID = v1.U_GROUP;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": selecting from SYS_USERS, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Got " $ROWCNT " rows.\n";

ECHO BOTH $IF $EQU $LAST[1] "U3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Name of the user group of u3=" $LAST[1] " before SET USER GROUP u3 u1;\n";

set user group u3 u1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SET USER GROUP u3 u1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select v2.U_NAME from SYS_USERS v1, SYS_USERS v2
       where v1.U_NAME = 'U3' and v2.U_ID = v1.U_GROUP;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": selecting from SYS_USERS, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Got " $ROWCNT " rows.\n";

ECHO BOTH $IF $EQU $LAST[1] "U1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Name of the user group of u3=" $LAST[1] " after SET USER GROUP u3 u1;\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: " $ARGV[4] "  -- Changing and Revoking User Privileges\n";
