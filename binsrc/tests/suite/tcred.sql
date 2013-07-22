--  
--  $Id$
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

echo BOTH "STARTED: __set_user_id tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

drop user TEST_USER;

create user TEST_USER;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create user TEST_USER STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('TEST_USER');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBA: __set_user_id ('TEST_USER') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('TEST_USER', 1, 'TEST_USER');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBA: __set_user_id ('TEST_USER', 1) STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('TEST_USER', 1, 'wrong_pass');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBA: __set_user_id ('TEST_USER', 1, 'wrong_pass') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

reconnect 'TEST_USER';

select __set_user_id ('TEST_USER');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER: __set_user_id ('TEST_USER') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('TEST_USER', 0);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER: __set_user_id ('TEST_USER', 0) STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('TEST_USER', 1, 'TEST_USER');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER: __set_user_id ('TEST_USER', 1, 'TEST_USER') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('TEST_USER', 1, 'wrong_pass');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create user TEST_USER STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

drop user TEST_USER;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop user TEST_USER STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

USER_CREATE ('TEST_USER', 'TEST_USER', vector ('DISABLED', 1));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop user TEST_USER STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

create user TEST_USER_L;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create user TEST_USER_L STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

reconnect 'TEST_USER_L';

select __set_user_id ('test_user');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER_L: __set_user_id ('test_user') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('test_user', 0);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER_L: __set_user_id ('test_user', 0) STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('test_user', 1, 'test_user');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER_L: __set_user_id ('test_user', 1, 'test_user') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

select __set_user_id ('test_user', 1, 'wrong_pass');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TEST_USER_L: __set_user_id ('test_user', 1, 'test_user') STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: __set_user_id tests\n";
