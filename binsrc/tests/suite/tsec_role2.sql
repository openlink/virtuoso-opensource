--
--  $Id: tsec_role2.sql,v 1.3.10.1 2013/01/02 16:15:23 source Exp $
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
echo BOTH "STARTED: USER ROLE tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;


reconnect RUSR;

select USER;
ECHO BOTH $IF $EQU $LAST[1] RUSR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": connected as : " $LAST[1] "\n";

select * from "ROLE_TEST";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select to ROLE_TEST table is granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update "ROLE_TEST" set ID = ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update to ROLE_TEST table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into "ROLE_TEST" (id) values (1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into "ROLE_TEST" table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from "ROLE_TEST";
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete from ROLE_TEST table is not granted to RUSR : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

select USER;
ECHO BOTH $IF $EQU $LAST[1] dba "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": connected as : " $LAST[1] "\n";

grant CYCL to C with admin option;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": grant CYCL to C with admin option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: USER ROLE tests\n";
