--  
--  $Id: tdrop.sql,v 1.5.10.1 2013/01/02 16:15:05 source Exp $
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
create procedure atomic_drop (in tbl varchar)
{
  declare n1, n2, n3 varchar;
  declare fname, stat, msg varchar;
  if (not isstring (tbl))
    signal ('.....', 'atomic_drop ()  function needs string as argument');
  n1 := name_part (tbl, 0);
  n2 := name_part (tbl, 1);
  n3 := name_part (tbl, 2);
  if (not exists (select 1 from SYS_KEYS where name_part (KEY_TABLE, 0) = n1 
	                                 and name_part (KEY_TABLE, 1) = n2
	                                 and name_part (KEY_TABLE, 2) = n3 ))     
    signal ('.....', sprintf ('The table ''%s'' not exist', tbl));
  stat := '00000';
  msg := '';
  -- Fresh transaction       
  commit work;     
  __atomic (1);
  exec (sprintf ('drop table "%s"."%s"."%s"', n1, n2, n3), stat, msg);
  __atomic (0);
  if (stat <> '00000')
    signal (stat, msg);
}

checkpoint;

select count(*) from WAREHOUSE;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
ECHO BOTH ": WAREHOUSE TABLE : COUNT=" $LAST[1] "\n";

select count(*) from DISTRICT;
ECHO BOTH $IF $EQU $LAST[1] 10  "PASSED" "***FAILED";
ECHO BOTH ": DISTRICT TABLE : COUNT=" $LAST[1] "\n";

select count(*) from CUSTOMER;
ECHO BOTH $IF $EQU $LAST[1] 30000  "PASSED" "***FAILED";
ECHO BOTH ": CUSTOMER TABLE : COUNT=" $LAST[1] "\n";

select count(*) from HISTORY;
ECHO BOTH $IF $EQU $LAST[1] 30000  "PASSED" "***FAILED";
ECHO BOTH ": HISTORY TABLE : COUNT=" $LAST[1] "\n";

select count(*) from ORDERS;
ECHO BOTH $IF $EQU $LAST[1] 30000  "PASSED" "***FAILED";
ECHO BOTH ": ORDERS TABLE : COUNT=" $LAST[1] "\n";

select count(*) from NEW_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 9000  "PASSED" "***FAILED";
ECHO BOTH ": NEW ORDERS TABLE : COUNT=" $LAST[1] "\n";

select count(*) from ITEM;
ECHO BOTH $IF $EQU $LAST[1] 100000  "PASSED" "***FAILED";
ECHO BOTH ": ITEMS TABLE : COUNT=" $LAST[1] "\n";

select count(*) from STOCK;
ECHO BOTH $IF $EQU $LAST[1] 100000  "PASSED" "***FAILED";
ECHO BOTH ": STOCK TABLE : COUNT=" $LAST[1] "\n";

checkpoint;


CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from STOCK &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from STOCK &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from ITEM &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from ITEM &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from CUSTOMER &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from CUSTOMER &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from ORDERS &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from ORDERS &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from ORDER_LINE &
CONNECT; SET DEADLOCK_RETRIES 100000; FOREACH INTEGER BETWEEN 1 10000 select count (*) from ORDER_LINE &

atomic_drop ('WAREHOUSE');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP WAREHOUSE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('DISTRICT');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP DISTRICT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('CUSTOMER');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP CUSTOMER : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('HISTORY');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP HISTORY : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('NEW_ORDER');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP NEW_ORDER : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('ORDERS');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP ORDERS : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('ORDER_LINE');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP ORDER_LINE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('STOCK');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP STOCK : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

atomic_drop ('ITEM');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DROP ITEM : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


checkpoint;

select count(*) from WAREHOUSE;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK WAREHOUSE TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from DISTRICT;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK DISTRICT TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from CUSTOMER;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK CUSTOMER TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from HISTORY;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK HISTORY TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from ORDERS;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK ORDERS TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from ORDER_LINE;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK ORDER_LINE TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select count(*) from NEW_ORDER;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK NEW_ORDER TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from ITEM;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK ITEM TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from STOCK;
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": CHECK STOCK TABLE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO "ALTER PRIMARY KEY TESTS"

drop table PK_TEST; 

create table PK_TEST (id integer, dt varchar);

insert into PK_TEST (id, dt) values (1, '1');
insert into PK_TEST (id, dt) values (2, '2');
insert into PK_TEST (id, dt) values (3, '3');
insert into PK_TEST (id, dt) values (4, '4');
insert into PK_TEST (id, dt) values (5, '5');

select count(*) from PK_TEST;
ECHO BOTH $IF $EQU $LAST[1] 5  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY TEST TABLE : COUNT=" $LAST[1] "\n";

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
	    
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY DOES NOT EXIST : COUNT=" $LAST[1] "\n";

alter table PK_TEST modify primary key (id);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MODIFICATION OF PRIMARY KEY : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select count(id) from PK_TEST;
ECHO BOTH $IF $EQU $LAST[1] 5  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY TEST TABLE : COUNT=" $LAST[1] "\n";


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


alter table PK_TEST modify primary key (id, dt);
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
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY ALTERED : COUNT=" $LAST[1] "\n";

select count(id) from PK_TEST;
ECHO BOTH $IF $EQU $LAST[1] 5  "PASSED" "***FAILED";
ECHO BOTH ": PRIMARY KEY TEST TABLE : COUNT=" $LAST[1] "\n";

