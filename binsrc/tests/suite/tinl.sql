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

echo both "Test inlining exists as dt\n";


-- Test for changing a subquery into a outer loop for joining.

select count (*) from t1 where string1 in (select string2 from t1 where row_no = 222);

select count (*) from t1 where string1 in (select string2 from t1 where row_no > 0);


update t1 set fi2 = fi2 + 2  where row_no in (select row_no from t1 where string1 = '11');

explain ('update t1 set fi2 = fi2 + 2  where row_no in (select row_no from t1 where string1 = ''11'')');
explain ('update t1 set fi2 = fi2 + 2  where row_no in (select row_no from t1 where string1 > ''11'')');


select count (*) from t1 a, t1 b where a.row_no between 100 and 110 and b.row_no in (select row_no from t1 where string1 = '11');

explain ('select count (*) from t1 a, t1 b where a.row_no between 100 and 110 and b.row_no in (select row_no from t1 where string1 = ''11'')  ', -5);

explain ('select count (*) from t1 a, t1 b, t1 c, t1 d, t1 e, t1 f, t1 g, t1 h where a.row_no <20 and b.row_no < 19 and c.row_no < 18 and d.row_no < 17 and e.row_no  < 16 and f.row_no < 15 and g.row_no < 14 and h.row_no < 13', -5);


select count (*) from t1 a, t1 b, t1 c where a.string1 = b.string2 and c.row_no in (select row_no from t1 s where  s.string1 = a.string1 and s.fi2  = b.fi2);

explain  ('select count (*) from t1 a, t1 b, t1 c where a..string1 = b.string 2 and c.row_no in (select row_no from t1 s where  s.string1 = a.string1 and s.fi2  = b.fi2)');


explain ('select count (*) from t1 a where exists (select 1 from t1 b where a.row_no = b.row_no and a.fi2 = b.fi2 and b.string1 = ''11'')');

explain ('select count (*) from t1 where (row_no, fi2) in (select row_no, fi2 from t1 where string1 = ''11'')');


-- VDB cases

explain ('select count (*) from t1 where string1 in (select string2 from r1..t1 where row_no = 222)');

select count (*) from t1 where string1 in (select string2 from r1..t1 where row_no = 222);
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": r1..t1 in r1..t1 \n";

explain ('select count (*) from t1 where string1 in (select string2 from r1..t1 where row_no = 222) option (do not loop exists)');

select count (*) from r1..t1 a, t1 b where a.string1 in (select string2 from r1..t1 where row_no = 222) and b.row_no = a.row_no;
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": r1..t1 in r1..t1, t1 \n";

select count (*) from r1..t1 a, t1 b where a.string1 in (select string2 from r1..t1 where row_no = 222) and b.row_no = a.row_no option (do not loop exists);
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": r1..t1 in r1..t1, t1  do not loop exists\n";

select count (*) from r1..t1 a, t1 b where a.string1 in (select string2 from r1..t1 where row_no = 222) and b.row_no = a.row_no option (loop exists);
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": r1..t1 in r1..t1, t1 loop exists\n";

select count (*) from r1..t1 a, t1 b where a.string1 in (select string2 from r1..t1 c where c.row_no = 222 and c.row_no = a.fi2) and b.row_no = a.row_no option ( loop exists);
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": r1..t1 in r1..t1, t1, 2 in join conds, loop exists\n";


update t1 set fi2 = fi2 + 2  where row_no in (select row_no from r1..t1 where string1 = '11');
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": update t1 in r1..t1\n";

update r1..t1 set fi2 = fi2 + 2  where row_no in (select row_no from r1..t1 where string1 = '11');
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": update t1 in r1..t1\n";


update r1..t1 set fi2 = fi2 + 2  where row_no in (select row_no from t1 where string1 = '11');
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": update r1..t1 in t1\n";

update r1..t1 set fi2 = fi2 + 2  where row_no in (select row_no from t1 where string1 > '11') and row_no = 411;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": update r1..t1 in t1 and row_no = 411\n";

