--
--  rtest2.sql
--
--  $Id$
--
--  Remote database testing part 2
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

ECHO BOTH "VDB SQL TEST, NO ARRAY PARAMETERS\n";
set param_batch = 0;
load rtest2-1.sql;

ECHO BOTH "VDB SQL TEST, WITH ARRAY PARAMETERS\n";
set param_batch = 10;
load rtest2-1.sql;

select count (*) from T1 A where exists (select * from R1..T1 B where B.ROW_NO > A.ROW_NO - 2900  );
ECHO BOTH $IF $EQU $LAST[1] 999 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in remote select close timing test\n";

