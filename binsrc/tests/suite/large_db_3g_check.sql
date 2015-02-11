--
--  large_db_check.sql
--
--  $Id: large_db_3g_check.sql,v 1.3.10.1 2013/01/02 16:14:41 source Exp $
--
--  Large DB test
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

select count (*) from TEST;
ECHO BOTH $IF $EQU $LAST[1] '30000' "PASSED" "***FAILED";
ECHO BOTH " TEST table contains " $LAST[1] " rows\n";

backup '/dev/null';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": Travers all trees\n";


select check_sum();
ECHO BOTH $IF $EQU $LAST[1] "373" "PASSED" "***FAILED";
ECHO BOTH " CHECK SUM:" $LAST[1] "\n"

