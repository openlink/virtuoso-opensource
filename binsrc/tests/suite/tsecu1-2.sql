--
--  tsecu1-2.sql
--
--  $Id: tsecu1-2.sql,v 1.4.10.1 2013/01/02 16:15:24 source Exp $
--
--  Security test #2
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
-- Security Test, check privileges of an individual user, part2
-- (Actually we just check that the new password works)
-- And maybe we can restore the original password, and do something
-- else we forgot to do in tsecu1-1.sql
--

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Get the username (everybody should have access to SYS_KEYS):
select distinct USER from SYS_KEYS;
-- Set ARGV[2] to the USER name used on this connection:
SET ARGV[2] $LAST[1];

-- And only then print the starting banner:
echo BOTH "STARTED: " $ARGV[4] "  -- Privileges of user " $ARGV[2] ", part 2\n";

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT distinct USER from SYS_KEYS; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work only for the user u1 and users with dba privileges:
--
call sec_u1proc (-3);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling sec_u1proc(-3), which has been created by u1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $RETVAL -99 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Result of which was=" $RETVAL "\n";

--
-- Similarly should be FORBIDDEN:
-- create table anyname(etc...)
--
-- (As long as we have not really implemented TABLE_OWNER field
-- in SYS_KEYS and other tables.)
--
-- AND:
-- create index anyname on another_users_table(col1,etc...) ???
--  (If there is no specific grant (SELECT? REFERENCES?) on that
--   table (specific columns) for public or this specific user???)
-- drop index another_users_index;
-- And also should be forbidden creating new procedures with reserved
-- names, etc.
-- To be implemented in Virtuoso!
--

--
-- Should produce: *** Error 42000: No permission to execute procedure droptable.
--
drop table sec_test_1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Dropping tables WITHOUT permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce: *** Error 42000: Permission denied. Must be member of dba group.
--
delete user u2;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Deleting users WITHOUT permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- And finally, password changing and related tests:
--

--
-- Should produce: *** Error 42000: Incorrect old password in set password
--
set password u1 mot_de_passe;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Changing password with incorrect old password: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work:
--
set password u1pass u1new;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Changing password with correct old password: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: " $ARGV[4] "  -- Privileges of user " $ARGV[2] ", part 2\n";
