--  
--  $Id$
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
create table ROLL_TEST (id integer, dt varchar);

SET AUTOCOMMIT=ON;
FOREACH INTEGER BETWEEN 1 10000 
  insert into ROLL_TEST (id, dt) values (?, repeat ('a', 1000));
SET AUTOCOMMIT=OFF;

select count (*) from ROLL_TEST;
ECHO BOTH $IF $EQU $LAST[1] 10000  "PASSED" "***FAILED";
ECHO BOTH ": CHECK TABLE : COUNT=" $LAST[1] "\n";

drop table ROLL_TEST;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from ROLL_TEST;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK AFTER DROP : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table PK_TEST modify primary key (id);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MODIFICATION OF PRIMARY KEY : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

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
ECHO BOTH ": PRIMARY KEY ALTERED : COUNT=" $LAST[1] "\n";

select count(id) from PK_TEST;
ECHO BOTH $IF $EQU $LAST[1] 5  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY TEST TABLE : COUNT=" $LAST[1] "\n";
