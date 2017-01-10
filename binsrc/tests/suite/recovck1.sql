--
--  recovck1.sql
--
--  $Id: recovck1.sql,v 1.15.10.1 2013/01/02 16:14:52 source Exp $
--
--  Recovery check test
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

ECHO BOTH "STARTED: Recovery Check Test\n";

select registry_get ('11') from SYS_USERS;
ECHO BOTH $IF $EQU $LAST[1] ++ "PASSED" "***FAILED";
ECHO BOTH ": Registry 11 = " $LAST[1] "\n";

load recovck1_noreg.sql;

ECHO BOTH "COMPLETED: Recovery Check Test\n";
