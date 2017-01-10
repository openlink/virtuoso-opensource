--
--  tsecu3-2.sql
--
--  $Id$
--
--  Security test #3 part 2
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
-- Security Test, check privileges of an individual user.
-- This version should be run as u3 after u3 has been switched to
-- the group of u1 with SET USER GROUP u3 u1;
-- in the file tsecu5-1.sql
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

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " lines with SELECT distinct USER from SYS_KEYS;\n";

--
-- Should not work anymore as select privilege was revoked from public
-- in the previous file:
--
select * from SEC_TEST_1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT * FROM SEC_TEST_1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Now this should work for u3 as (s)he belongs to the same group as u1:
--
select a from SEC_TEST_2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT a FROM SEC_TEST_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " lines with SELECT a FROM SEC_TEST_2;\n";

ECHO BOTH $IF $EQU $COLCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $COLCNT " columns with SELECT a FROM SEC_TEST_2;\n";

ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column  a  contains value " $LAST[1] "\n";

--
-- Should produce: *** Error 42000: Access denied for column c.
--
select a from SEC_TEST_2 order by c;

ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT a FROM SEC_TEST_2 ORDER BY c; (WITHOUT permission to c) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce: *** Error 42000: _ROW requires select grant on the entire table.
--
select row_table(_ROW) from SEC_TEST_2;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT row_table(_ROW) FROM SEC_TEST_2; (WITHOUT permission) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Shouldn't work anymore because of revoking of the execute grant from
-- public:
--
call secp_1 (909);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling secp_1(909), which has been granted for public: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work only for users u1 and u5: (now also for u3)
-- For others should produce:
-- *** Error 42000: No permission to execute procedure secp_2.
--
call secp_2 (9009);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling secp_2(9009), which has been granted for u1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $RETVAL 198198 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Result of which was=" $RETVAL "\n";

--
-- Should work only for the user u1 and users in the same group (now u3)
-- or with dba privileges, for others should produce:
  -- *** Error 42000: No permission to execute procedure sec_u1proc.
-- If this fails here for u3, then the bug is in Virtuoso, not here!
-- (At least this fails with server version 0.96b G13d3 Win32 Apr 17 1997.
--
call sec_u1proc (-303);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling as " $ARGV[2] " sec_u1proc(-303), which has been created by u1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $RETVAL -9999 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Result of which was=" $RETVAL "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: No insert or insert/delete permission for insert / insert replacing
-- Except now works for u1 and u3 because of
-- grant insert on SEC_TEST_3 to u1;  in tsecu5-1.sql:
--
insert into SEC_TEST_3 values (1661, 1661, 1661);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting WITH permission into SEC_TEST_3: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SEC_TEST_3 order by a, b, c;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": selecting WITH permission from SEC_TEST_3: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " lines with SELECT * FROM SEC_TEST_3;\n";

ECHO BOTH $IF $EQU $COLCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $COLCNT " columns with SELECT * FROM SEC_TEST_3;\n";

--
-- The row that was inserted there first is: 121 242 363 and is
-- later modified to: 121 1 363, so this row that is now inserted is
-- anyway sorted later:
--
ECHO BOTH $IF $EQU $LAST[1] 1661 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column  a  contains value " $LAST[1] "\n";

--
-- Should succeed for u1 and u5: (and now for u3)
--
insert into SEC_TEST_4 values (1478741, 1478741, 1478741);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting WITH permission into SEC_TEST_4: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users *** Error 42000: Access denied for column a.
--
delete from SEC_TEST_4 where a = 5;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleting from SEC_TEST_4 WITHOUT permission to column a: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work for u1, u2 and u5: (and now also u3)
--
delete from SEC_TEST_4;
-- XXX
--ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": deleting from SEC_TEST_4 WITH permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: Permission denied for delete.
--
delete from SEC_TEST_1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleting from SEC_TEST_1 WITHOUT permission to do it: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: Update of a not allowed
-- But now work for us because new update(a) grant on SEC_TEST_3 for u1:
--
update SEC_TEST_3 set a = c + 1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UPDATE SEC_TEST_3 SET a = c + 1; WITH permission to that column: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select a,c from SEC_TEST_3;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": selecting WITH permission from SEC_TEST_3: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " lines with SELECT a,c FROM SEC_TEST_3;\n";

ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $COLCNT " columns with SELECT a,c FROM SEC_TEST_3;\n";

ECHO BOTH $IF $EQU $LAST[1] 1662 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column  a  of last row is " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[1] $+ 1 $LAST[2] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column  a  (" $LAST[1] ") " $IF $LIF "==" "!=" " 1+column c (" $LAST[2] ")\n";

--
-- Should not work anymore, except for u4 and u5:
--
update SEC_TEST_3 set b = 1;

ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating SEC_TEST_3 WITHOUT permission to column b: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: Update of b not allowed
--
update SEC_TEST_4 set b = 1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating SEC_TEST_4 WITHOUT permission to do it: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Check that SQLTablePrivileges and SQLColumnPrivileges work also
-- for ordinary users (i.e. that internal procedures table_privileges
-- and column_privileges has been permitted for public:
-- Note that the implementation might later restrict grants shown
-- only to the calling user's own grants, so we doesn't check here
-- the rowcounts returned and other fields as thoroughly as in
-- tsec-ini.sql
--
TABLEPRIVILEGES;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Doing SQLTablePrivileges as ordinary user: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " table grants found.\n";

--
-- Same with SQLColumnPrivileges:
--
COLUMNPRIVILEGES SEC_TEST_2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Doing SQLColumnPrivileges as ordinary user: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " column grants on table SEC_TEST_2 found.\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] A "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on column " $LAST[4] "\n";

--
-- And finally, password changing and related tests:
--

--
-- Should produce: *** Error 42000:  Access denied for column U_PASSWORD
--
select U_PASSWORD from SYS_USERS;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Selecting WITHOUT permission from SYS_USERS: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce: *** Error 42000: Permission denied. Must be member of dba group.
--
set user group u1 dba;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting own user group WITHOUT permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce: *** Error 42000: Permission denied. Must be member of dba group.
--
grant select on SEC_TEST_4 to u1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granting privileges WITHOUT permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: " $ARGV[4] "  -- Privileges of user " $ARGV[2] ", part 2\n";


select * from U1_T2;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": select U1_t2 after view owner's base table perm revoked: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
