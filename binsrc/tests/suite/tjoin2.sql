--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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


-- test all combinations of inlined dt's in froms and in join exps

echo both "Different dt inlining in join exps tjoin2.sql\n";

select count (*) from (select row_no as s from t1) f;

select count (*) from (select a.row_no + b.row_no as s from t1 a, t1 b where b.row_no = a.row_no + 1) f;

select count (*) from (select b.row_no  from t1 a, t1 b where b.row_no = a.row_no + 1) f inner join t1 c on c.row_no = f.row_no + 1;
echo both $if $equ $last[1] 18 "PASSED" "***FAILED";
echo both ": dt inline inner 1 \n";

select count (*) from (select b.row_no  from t1 a join t1 b on b.row_no = a.row_no + 1) f inner join t1 c on c.row_no = f.row_no + 1;
echo both $if $equ $last[1] 18 "PASSED" "***FAILED";
echo both ": dt inline inner 2 \n";



select count (*) from (select b.row_no  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join t1 c on c.row_no = f.row_no + 1;
-- XXX
--echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
--echo both ": dt inline outer 1\n";


select count (*) from (select b.row_no  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (select c.row_no from t1 c) g on g.row_no = f.row_no + 1;
-- XXX
--echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
--echo both ": dt inline outer single\n";

select count (f.r1), count (f.r2), count (g.r1), count (g.r2) from (select a.row_no as r1, b.row_no as r2  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (select c.row_no as r1, d.row_no as r2 from t1 c join t1 d on d.row_no = c.row_no + 1) g on g.r1 = f.r2 + 1;
echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
echo both ": dt inline outer dt 1\n";
echo both $if $equ $last[4] 17 "PASSED" "***FAILED";
echo both ": dt inline outer dt2\n";


select count (f.r1), count (f.r2), count (g.r1), count (g.r2) from (select a.row_no as r1, b.row_no as r2  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (select * from (select c.row_no as r1, d.row_no as r2 from t1 c join t1 d on d.row_no = c.row_no + 1) gp) g on g.r1 = f.r2 + 1;
echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
echo both ": dt inline outer dbl dt 1\n";
echo both $if $equ $last[4] 17 "PASSED" "***FAILED";
echo both ": dt inline outer dbl dt2\n";


select count (f.r1), count (f.r2), count (c.row_no), count (d.row_no) from (select a.row_no as r1, b.row_no as r2  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (t1 c join t1 d on d.row_no = c.row_no + 1) on c.row_no = f.r2 + 1;
echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
echo both ": dt inline outer outer join exp 1\n";
echo both $if $equ $last[4] 17 "PASSED" "***FAILED";
echo both ": dt inline outer join exp 2\n";


