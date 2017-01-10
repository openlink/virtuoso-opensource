--
--  tsecu3-1.sql
--
--  $Id$
--
--  Security test #3
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
--

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Get the username (everybody should have access to SYS_KEYS):
select distinct USER from SYS_KEYS;
-- Set ARGV[2] to the USER name used on this connection:
SET ARGV[2] $LAST[1];

-- And only then print the starting banner:
echo BOTH "STARTED: " $ARGV[4] "  -- Privileges of user " $ARGV[2] ", part 1\n";

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT distinct USER from SYS_KEYS; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " lines with SELECT distinct USER from SYS_KEYS;\n";

select * from sec_test_1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT * FROM sec_test_1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " lines with SELECT * FROM sec_test_1;\n";

ECHO BOTH $IF $EQU $COLCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $COLCNT " columns with SELECT * FROM sec_test_1;\n";

--
-- Should produce for u3: *** Error 42000: Access denied for column a.
--
select a from sec_test_2;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT a FROM sec_test_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce: *** Error 42000: Access denied for column b.
--
select * from sec_test_2;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT * FROM sec_test_2; (WITHOUT permission) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce: *** Error 42000: _ROW requires select grant on the entire table.
--
select row_table(_ROW) from sec_test_2;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SELECT row_table(_ROW) FROM sec_test_2; (WITHOUT permission) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work for all users:
--
call secp_1 (-33);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling secp_1(-33), which has been granted for public: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Note!
-- $RETVAL doesn't work with ISQLODBC in Windows NT because Microsoft's
-- ODBC driver manager doesn't let SQL_RETURN_VALUE parameters pass
-- through it. Use directly linked ISQL instead!

ECHO BOTH $IF $EQU $RETVAL -363 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Result of which was=" $RETVAL "\n";

--
-- Should work only for users u1 and u5:
-- For others should produce:
-- *** Error 42000: No permission to execute procedure secp_2.
--
call secp_2 (11);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling secp_2(11), which has been granted for u1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ECHO BOTH $IF $EQU $RETVAL 242 "PASSED" "***FAILED";
-- SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
-- ECHO BOTH ": Result of which was=" $RETVAL "\n";

--
-- Should work only for this user and users with dba privileges:
-- For others should produce:
-- *** Error 42000: No permission to execute procedure sec_u1proc.
--
call sec_u1proc (-2);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling sec_u1proc(-2), which has been created by u1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ECHO BOTH $IF $EQU $RETVAL -66 "PASSED" "***FAILED";
-- SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
-- ECHO BOTH ": Result of which was=" $RETVAL "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: No insert or insert/delete permission for insert / insert replacing
--
insert into sec_test_3 values (1661, 1661, 1661);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting WITHOUT permission into sec_test_3: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should succeed for u1 and u5:
--
insert into sec_test_4 values (14641, 14641, 14641);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting WITHOUT permission into sec_test_4: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users *** Error 42000: Access denied for column a.
--
delete from sec_test_4 where a = 5;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleting from sec_test_4 WITHOUT permission to column a: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work for u1, u2 and u5:
--
delete from sec_test_4;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleting from sec_test_4 WITHOUT permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: Permission denied for delete.
--
delete from sec_test_1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleting from sec_test_1 WITHOUT permission to do it: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: Update of a not allowed
--
update sec_test_3 set a = 111;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating column a of sec_test_3 WITHOUT permission to that column: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should work for u1, u3, u4 and u5:
--
update sec_test_3 set b = 1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating sec_test_3 WITH permission to column b: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- Should produce for all ordinary users:
-- *** Error 42000: Update of b not allowed
--
update sec_test_4 set b = 1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating sec_test_4 WITHOUT permission to do it: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

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
COLUMNPRIVILEGES SEC_TEST_3;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Doing SQLColumnPrivileges as ordinary user: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " column grants on table sec_test_3 found.\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] "B" "PASSED" $IF $EQU $LAST[4] "C" "PASSED" "***FAILED";
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
grant select on sec_test_4 to u1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granting privileges WITHOUT permission: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: " $ARGV[4] "  -- Privileges of user " $ARGV[2] ", part 1\n";

select ROW_NO from U1_T1;
-- XXX
--echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
--echo both ": U1_T1 view granted to U3\n";

select * from U1_T2;
echo both $if $equ $rowcnt 13 "PASSED" "***FAILED";
echo both ": U1_T2 view granted to U3\n";


update U1_T1_V set STRING1 = concat ('--', STRING1);
-- XXX
--echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
--echo both $rowcnt " update of U1_T1_V by U3 \n";

update SEC_T1 set STRING1 = '111';
echo both $if $equ $state 42000 "PASSED" "***FAILED";
echo both $state " for ungranted update of SEC_T1\n";

update u1_tt set d = 31;

select d2 from u1_tt;
echo both $if $equ $last[1] 31 "PASSED" "***FAILED";
echo both ": u1 granted update on non-granted trigger action = " $last[1] "\n";
