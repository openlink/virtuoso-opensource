--
--  tobject.sql
--
--  $Id$
--
--  Object feature tests
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

echo BOTH "STARTED: Object Feature Test\n";

-- Test row_table and row_column.
-- Requires tschema1.sql to be loaded previously.
--

select A, row_table (_ROW) from T2;
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
ECHO BOTH ": Last A in T2 " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] DB.DBA.T2_2 "PASSED" "***FAILED";
ECHO BOTH ": Last table in T2 " $LAST[2] "\n";

select row_column (_ROW, 'DB.DBA.T2_2', 'E') from T2;
ECHO BOTH $IF $EQU $LAST[1] 5555 "PASSED" "***FAILED";
ECHO BOTH ": Last E (row_column) in T2 " $LAST[1] "\n";

select row_column (_ROW, 'DB.DBA.T2_2', 'C2_2') from T2 where A = 2;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
ECHO BOTH ": Non-existing row_column is " $LAST[1] "\n";

row_table ('   ');
ECHO BOTH  $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": State for bad row string " $STATE "\n";

select row_column (row_deref (row_identity (_ROW), 0), 'DB.DBA.T2', 'A'), row_table (row_identity (_ROW)) from T2;
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
ECHO BOTH ": Last A in T2 " $LAST[1] " refd by row_deref row_identity\n";

ECHO BOTH $IF $EQU $LAST[2] DB.DBA.T2_2 "PASSED" "***FAILED";
ECHO BOTH ": Last table in T2 " $LAST[2] " refd by row_table row_identity\n";


create procedure "indcall" (in q integer) { return q; };

create procedure indcaller (in p varchar, in a varchar)
{
  declare q integer; q :=  call (p) (a);
  result_names (q); result (q);
};

indcaller ('indcall', 11);

ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
ECHO BOTH ": indirect call returned " $LAST[1] "\n";

echo BOTH "COMPLETED: Object Feature Test\n";
