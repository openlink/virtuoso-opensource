--
--  rtest5.sql
--
--  $Id: rtest5.sql,v 1.4.10.1 2013/01/02 16:14:55 source Exp $
--
--  Remote database testing part 5
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

--
--  Start the test
--
SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Remote test 5 (rtest5.sql)\n";

select count (*) from R1..T1 where ROW_NO < 130;
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Remote reconnect -- count under 130 = " $LAST[1] "\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: Remote test 5 (rtest5.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
