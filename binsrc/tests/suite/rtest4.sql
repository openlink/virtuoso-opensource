--
--  rtest4.sql
--
--  $Id: rtest4.sql,v 1.4.10.1 2013/01/02 16:14:55 source Exp $
--
--  Remote database testing part 4
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
--  Start the test
--
SET TIMEOUT 10
SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Remote test 4 (rtest4.sql)\n";

select count (*) from R1..T1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bad remote DS off " $STATE " " $MESSAGE "\n";

select * from R1..T1;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Remote DS still  off " $STATE " " $MESSAGE "\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: Remote test 4 (rtest4.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
