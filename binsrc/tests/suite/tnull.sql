--
--  tnull.sql
--
--  $Id$
--
--  Test NULL handling
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

ECHO BOTH "schema integrity \n";

select * from sys_key_parts;
select * from sys_cols;
select * from sys_keys;

select * from sys_key_parts where not exists (select 1 from sys_keys where key_id = kp_key_id);
select * from sys_key_parts where not exists (select 1 from sys_cols where col_id = kp_col);



drop table nt;
create table nt (a integer, b varchar (10));

insert into nt values (null, null);
insert into nt values (1, 'a');
insert into nt values (2, 'b');
insert into nt values (3, 'c');
insert into nt values (null, null);
insert into nt values (5, null);

-- create index n on nt (a);

select count (*) from nt;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " in nt\n";

select count (*) from nt where a < 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " < 2 in nt\n";

select count (*) from nt where a > 2;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " > 2 in nt\n";

select count (*) from nt where a = null;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " a = null in nt\n";

select count (*) from nt where b = null;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " b = null in nt\n";

select count (*) from nt where a is null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " a is null in nt\n";

select max (a) from nt;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " max a  in nt\n";

select min (a) from nt;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " min a  in nt\n";

select count (*) from nt where not (a = null);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " not a = null in nt\n";

select count (*) from nt where a = 2 or a = null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " a = null or xx in nt\n";

select count (*) from nt where not (a = 2 or a = null);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " not (xx or a = null)  in nt\n";

select count (*) from nt where a = 2 and a <> null;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " a = null and xx in nt\n";

select count (*) from nt;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count (*)\n";

select count (a) from nt;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count (a)\n";

select count (distinct a) from nt;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count (a)\n";

select count (*) from (select distinct a from nt) f;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count (*) of distinct derived table\n";

select min (a), max (a), count (a), '--' from nt group by 4;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " min in group \n";
ECHO BOTH $IF $EQU $LAST[2] 5 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " max in group \n";
ECHO BOTH $IF $EQU $LAST[3] 4 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " count in group \n";



select a + 1 from nt;
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " count (*) of distinct derived table\n";

select sum (a) from nt;

select avg (a) from nt;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " avg (a)\n";

select avg (coalesce (a, 0)) from nt;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " avg (coalesce (a, 0))\n";

select avg (cast (a as numeric)), '--' from nt group by 2;
ECHO BOTH $IF $EQU $LAST[1] 2.75 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " avg ( a) group by const)\n";

select sum (cast (a as numeric)) / count (a), '--' from nt group by 2;
ECHO BOTH $IF $EQU $LAST[1] 2.75 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " sum/count ( a) group by const)\n";


-- raw_exit ();

-- gpf -- select * from nt order by b, a, b;
-- gpf -- select * from nt order by b;
