--  
--  $Id$
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



drop table tn;
create table tn  (s smallint , i int , r real , d double precision , n numeric );
create index si on tn (s);
create index ii on tn (i);
create index ri on tn (r);
create index di on tn (d);
create index n on tn (n);


insert into tn (s,i,r,d,n) values (1.2, 1.2, 2.2, 3.2, 4.2);

select * from tn where 
  s between 0 and 10 and 
  i between 0 and 10 and
  r between 0 and 10 and
  d between 0 and 10 and
  n between 0 and 10;

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": search cast 1\n";



select * from tn where 
  s between 0 and cast (10 as double precision) and 
  i between 0 and cast (10 as double precision) and
  r between 0 and cast (10 as double precision) and
  d between 0 and cast (10 as double precision) and
  n between 0 and cast (10 as double precision);

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": search cast 2\n";





select * from tn where 
  s between 0 and cast (10 as numeric) and 
  i between 0 and cast (10 as numeric) and
  r between 0 and cast (10 as numeric) and
  d between 0 and cast (10 as numeric) and
  n between 0 and cast (10 as numeric);

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": search cast 3\n";


select * from tn where 
  s between 0 and cast (10 as real) and 
  i between 0 and cast (10 as real) and
  r between 0 and cast (10 as real) and
  d between 0 and cast (10 as real) and
  n between 0 and cast (10 as real);

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": search cast 4\n";

select count (*) from tn where n between 1e-100 and 1e100;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": dbl and num range cmp.\n";



insert into tn (r,d, n)  values (1e36, 1e100, 999999999999999999999999999999999999999);


select count (*) from tn where r < 1e100;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": real-dbl comp\n";

select count (*) from tn where r < n;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": real- num comp\n";
