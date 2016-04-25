--
--  $Id: tdrop2.sql,v 1.3.10.1 2013/01/02 16:15:05 source Exp $
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

select count (*) from ROLL_TEST;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK AFTER ROLL FORWARD : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(sc."COLUMN")
	    from  DB.DBA.SYS_KEYS k,  DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS sc
	    where
	      upper(k.KEY_TABLE) = upper('DB.DBA.PK_TEST') and
	      __any_grants(k.KEY_TABLE) and
	      k.KEY_IS_MAIN = 1 and
	      k.KEY_MIGRATE_TO is NULL and
	      kp.KP_KEY_ID = k.KEY_ID and
	      kp.KP_NTH < k.KEY_DECL_PARTS and
	      sc.COL_ID = kp.KP_COL and
	      sc."COLUMN" <> '_IDN'
	    order by sc.COL_ID;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
ECHO BOTH ": CHECK PRIMARY KEY AFTER ROLL FORWARD : COUNT=" $LAST[1] "\n";

select count(id) from PK_TEST;
ECHO BOTH $IF $EQU $LAST[1] 5  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY TEST TABLE CHECK AFTER ROLL FORWARD : COUNT=" $LAST[1] "\n";
