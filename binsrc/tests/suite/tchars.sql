--
--  tchars.sql
--
--  $Id: tchars.sql,v 1.3.10.1 2013/01/02 16:15:00 source Exp $
--
--  strict chars testing
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
echo BOTH "\nSTARTED: strict char columns suite (tchars.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop table TCHARS;
create table TCHARS (
    ID 	INTEGER NOT NULL PRIMARY KEY,
    CU 	char,
    C0 	char(0),
    C50	char(50),
    VU	varchar,
    V0	varchar(0),
    V50	varchar (50),
    AU	any);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating table TCHARS: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TCHARS (ID) values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert all NULLs in the char cols: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- char with no length test
update TCHARS set CU = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CU = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set CU = 'ab';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CU = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set CU = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CU = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(CU))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CU = 1 saved as " $LAST[1] "\n";

update TCHARS set CU = 12;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CU = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- char with zero length test
update TCHARS set C0 = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set C0 = 'ab';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set C0 = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(C0))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 = 1 saved as " $LAST[1] "\n";

update TCHARS set C0 = 12;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set C0 = '123456789012345678901234567890123456789012345678901234567890';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 = 123456789012345678901234567890123456789012345678901234567890: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- char with length 50 test
update TCHARS set C50 = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C50 = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set C50 = 'ab';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C50 = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set C50 = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C50 = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(C50))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C50 = 1 saved as " $LAST[1] "\n";

update TCHARS set C50 = 12;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C50 = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set C50 = '123456789012345678901234567890123456789012345678901234567890';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C50 = 123456789012345678901234567890123456789012345678901234567890: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- varchar with no length test
update TCHARS set VU = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VU = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set VU = 'ab';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VU = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set VU = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VU = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(VU))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VU = 1 saved as " $LAST[1] "\n";

update TCHARS set VU = 12;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VU = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set VU = '123456789012345678901234567890123456789012345678901234567890';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VU = 123456789012345678901234567890123456789012345678901234567890: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- varchar with zero length test
update TCHARS set V0 = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V0 = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set V0 = 'ab';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V0 = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set V0 = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V0 = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(V0))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V0 = 1 saved as " $LAST[1] "\n";

update TCHARS set V0 = 12;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V0 = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set V0 = '123456789012345678901234567890123456789012345678901234567890';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V0 = 123456789012345678901234567890123456789012345678901234567890: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- varchar with length 50 test
update TCHARS set V50 = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V50 = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set V50 = 'ab';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V50 = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set V50 = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V50 = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(V50))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V50 = 1 saved as " $LAST[1] "\n";

update TCHARS set V50 = 12;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V50 = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set V50 = '123456789012345678901234567890123456789012345678901234567890';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": V50 = 123456789012345678901234567890123456789012345678901234567890: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- any test
update TCHARS set AU = 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": AU = 'a': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set AU = 'ab';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": AU = 'ab': STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set AU = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": AU = 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select upper (dv_type_title (__tag(AU))) from TCHARS;
ECHO BOTH $IF $EQU $LAST[1] INTEGER "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": AU = 1 saved as " $LAST[1] "\n";

update TCHARS set AU = 12;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": AU = 12: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TCHARS set AU = '123456789012345678901234567890123456789012345678901234567890';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": AU = 123456789012345678901234567890123456789012345678901234567890: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


--
-- End of test
--
ECHO BOTH "COMPLETED: strict char columns suite (tchars.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
