--
--  tlogft2.sql
--
--  $Id$
--
--  Test freetext interaction with transaction log #2
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

ECHO BOTH "STARTED: freetext interaction with transaction log, part 2\n";

select count(*) from FTTEST where contains (DATA, 'EXPLAIN');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in contains : EXPLAIN\n";

ECHO BOTH "COMPLETED: freetext interaction with transaction log, part 2\n";

ECHO BOTH "STARTED: XML_ENTITY interaction with transaction log, part 2\n";
select count(*) from XTLOG;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in XTLOG with serialized XML_ENTITY\n";
ECHO BOTH "COMPLETED: XML_ENTITY  interaction with transaction log, part 1\n";
