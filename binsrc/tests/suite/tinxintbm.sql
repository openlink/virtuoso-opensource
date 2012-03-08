--  
--  $Id$
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



echo both "Index intersecction tests with bitmap index\n";


update t1 set fi3 = mod (row_no, 11), fi2 = mod (row_no, 7);

create bitmap index fi2 on t1 (fi2) partition (fi2 int);
create bitmap index fi3 on t1 (fi3) partition (fi3 int);


select count (*) from t1 where fi2 = 3 and fi3 = 3;
echo both $if $equ $last[1] 130 "PASSED" "*** FAILED";
echo both " t1 inx int count\n";

select count (*) from t1 table option (index fi2) where fi2 = 3 and fi3 = 3;
echo both $if $equ $last[1] 130 "PASSED" "*** FAILED";
echo both " t1 inx fi2  count\n";

select count (*) from t1 table option (index primary key) where fi2 = 3 and fi3 = 3;
echo both $if $equ $last[1] 130 "PASSED" "*** FAILED";
echo both " t1 pk  count\n";



select sum  (fi6) from t1 where fi2 = 3 and fi3 = 3;
echo both $if $equ $last[1] 866580 "PASSED" "*** FAILED";
echo both ": ti inx int fi6 sum.\n";



update t1 set fi6 = 11 where fi2 = 4 and fi3 = 5;
echo both $if $equ $rowcnt 130 "PASSED" "*** FAILED";
echo both " t1 inx int update 1\n";


update t1 set fi6 = 11 where fi2 = 4 and fi3 = 5 and fi6 = 11;
echo both $if $equ $rowcnt 130 "PASSED" "*** FAILED";
echo both " t1 inx int update 2\n";


update t1 set fi6 = 11 where fi2 = 4 and fi3 = 5 and fi6 = 22;
echo both $if $equ $rowcnt 0 "PASSED" "*** FAILED";
echo both " t1 inx int update 3\n";

create procedure f (in a any) {return a;};

select count (*) from t1 a, t1 b where a.fi2 = 3 and b.fi3 = 4 and a.row_no = b.row_no;
echo both $if $equ $last[1] 130 "PASSED" "***FAILED";
echo both ": inx int join 1\n";


select count (*) from t1 a, t1 b where a.fi2 = 3 and b.fi3 = 4 and a.row_no = b.row_no and f(a.row_no) < 2000;
echo both $if $equ $last[1] 25 "PASSED" "***FAILED";
echo both ": inx int join 2\n";

select count (*) from t1 a, t1 b where a.fi2 = 3 and b.fi3 = 4 and a.row_no = b.row_no and f(a.row_no + b.row_no) < 4000;
echo both $if $equ $last[1] 25 "PASSED" "***FAILED";
echo both ": inx int join 3\n";

select count (*) from t1 a, t1 b, t1 c where a.fi2 = 4 and b.fi2 = 4 and c.fi3 = 3 and a.row_no = b.row_no and b.row_no = c.row_no and f(a.fi2) is not null and f(c.fs1) is not null;
echo both $if $equ $last[1] 130  "PASSED" "***FAILED";
echo both ": inx int join 3 tables\n";


create procedure  t1bm1 ()
{
	declare n int;
for (n := 100; n < 11000; n:= n+1)
  {
    if (n = 5398)
      dbg_obj_print ('bing');
    delete from t1 where  row_no = n;
    if (exists (select 1 from t1 table  option (index fi2) where fi2 = 1 and f (row_no) = 8195))
      {
	dbg_obj_print (n);
	rollback work;
	return 1;
      }
  }
return 0;
}


drop table t1;
-- the next test tjoin needs to fill this from scratch


