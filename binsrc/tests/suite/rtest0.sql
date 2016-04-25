--
--  rtest0.sql
--
--  $Id: rtest0.sql,v 1.1.2.2 2013/01/02 16:14:54 source Exp $
--
--  Remote database testing part 2
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

set param_batch = 0;

SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Remote test 0 (rtest0.sql)\n";

-- simple remote
select * from R1..T1 where ROW_NO = 100;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select * from remote " $ROWCNT " rows\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: Remote test 0 (rtest0.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
