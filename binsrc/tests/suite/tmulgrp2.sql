--
--  tmulgroup.sql
--
--  $Id$
--
--  Check multiple user group functions
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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

SET ARGV[0] 0;
SET ARGV[1] 0;

ECHO BOTH "STARTED: Multiple user group test\n";



reconnect WEB_USER;
set charset='IBM866';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected as WEB_USER. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from WEB_DATA;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from WEB_DATA (granted as secondary group). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB_DATA;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from DB_DATA (not granted as secondary group). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from WEB_USERS.TEST;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from WEB_USERS.TEST (owned by a secondary group). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect ADMIN;
set charset='IBM866';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected as ADMIN. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from WEB_DATA;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from WEB_DATA (granted as a secondary group 1). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB_DATA;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from DB_DATA (granted as a secondary group 2). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from WEB_USERS.TEST;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from WEB_USERS.TEST (owned by a secondary group 1). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect ACCOUNTANT;
set charset='IBM866';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connected as ACCOUNTANT. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from WEB_USERS.TEST;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from WEB_USERS.TEST (owned by the secondary group's secondary group) . STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from WEB_DATA;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from WEB_DATA (granted to the secondary group's secondary group). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;
delete user WEB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete group WEB_USERS (while still having it in WEB_USER). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect WEB_USER;
select * from WEB_DATA;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WEB_DATA unaccessible (as a result of a group drop). STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: Multiple user group test (tmulgrp.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n";
