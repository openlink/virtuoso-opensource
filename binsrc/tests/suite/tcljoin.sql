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

-- Test cluster outer join and quietcast and nulls
-- test batched dt, subquery, existence

-- suppose start state of ins 1111 100 20

update t1 set fi2 = row_no, fi3 = row_no;

create index fi2 on t1 (fi2) partition (fi2 int);
create unique index fi3 on t1 (fi3) partition (fi3 int);

echo both "Cluster outer join\n";

explain ('insert into t1 (row_no, fi2, string1) values (121, 121, ''121'')');

checkpoint;
insert into t1 (row_no, fi2, string1) values (121, 121, '121');
__dbf_set ('cl_req_batch_size', 5);

select a.fi2, b.fi2 from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": cl oj 1: " $rowcnt " rows\n";


select count (a.fi2), count (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $last[2] 5 "PASSED" "***FAILED";
echo both ": cl oj 2\n";

-- f is a colocation sequence break because of id to iri.  f_pass is safely colocatable
create procedure f (in q any) { id_to_iri (#i100); return q;};
create procedure f_pass (in q any) { return q;};

select f (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 and b.fi2 - b.fi2 = 0 option (loop, any order);
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": outer dfg with after join test\n";

select f (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 and b.fi2 - b.fi2 = 0 option (loop);
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": outer dfg with after join test\n";


select count (a.fi2), count (f (b.fi2)) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": cl oj 2\n";

echo both $if $equ $last[2] 5 "PASSED" "***FAILED";
echo both ": cl oj 2\n";


select count (a.fi2), count (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": cl oj 3-1\n";
echo both $if $equ $last[2] 5 "PASSED" "***FAILED";
echo both ": cl oj 3-2\n";



select a.fi2, b.fi2, b.string1  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": cl oj 2nd key 1: " $rowcnt " rows\n";



select count (a.fi2), count (b.fi2), count (b.string1)  from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": cl oj 2nd key 3-1\n";
echo both $if $equ $last[2] 5 "PASSED" "***FAILED";
echo both ": cl oj 2nd key 3-2\n";


select count (a.fi2), count (b.fi2), count (b.string1)  from t1 a left join t1 b table option (index t1) on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": cl oj flood key 1-1\n";
echo both $if $equ $last[2] 5 "PASSED" "***FAILED";
echo both ": cl oj flood join key 1-2\n";



select a.fi2, b.fi2, b.string1  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (a.fi2 + 5, a.fi2 + 6)  where a.fi2 > 110 option (loop);
echo both $if $equ $rowcnt 13 "PASSED" "***FAILED";
echo both ": cl oj 2nd key in pred 1: " $rowcnt " rows\n";


select a.fi2, b.fi2, b.string1  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (sprintf ('bad%d', a.fi2 + 5), a.fi2 + 6)  where a.fi2 > 110 option (loop, quietcast);
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": cl oj 2nd key quietcast in pred 1: " $rowcnt " rows\n";


select a.fi2, b.fi2  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (sprintf ('bad%d', a.fi2 + 5), a.fi2 + 6)  where a.fi2 > 110 option (loop, quietcast);



select a.fi2, b.fi2  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 = sprintf ('bad%d', a.fi2 + 5)  where a.fi2 > 110 option (loop, quietcast);
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": cl oj 1st  key quietcast in pred 1: " $rowcnt " rows\n";


select count (a.fi2), count (b.fi2), count (b.string1)  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (a.fi2 + 5, a.fi2 + 6)  where a.fi2 > 110 option (loop);
echo both $if $equ $last[1] 13 "PASSED" "***FAILED";
echo both ": cl oj 2nd key in pred 3-1\n";
echo both $if $equ $last[2] 9 "PASSED" "***FAILED";
echo both ": cl oj 2nd key in pred 3-2\n";

select c.fi2, a.fi2, b.fi2, b.string1  from t1 c join t1 a on a.fi2 > c.fi2 left join t1 b table option (loop, index fi2) on b.fi2 in (a.fi2 + 5, a.fi2 + 6)  where c.fi2 in (110, 111) option (order, loop);
echo both $if $equ $rowcnt 24 "PASSED" "***FAILED";
echo both ": cl 3 table oj 2nd key in pred 1: " $rowcnt " rows\n";

select count (*) from t1 a left join t1 b  table option (loop) on b.row_no = a.row_no + 100 where b.row_no is null;
echo both $if $equ $last[1] 100 "PASSED" "***FAILED";
echo both ": outer unordered 1\n";

select count (*) from t1 a left join t1 b  table option (loop) on b.row_no = a.row_no + 100 where f (b.row_no) is null;
echo both $if $equ $last[1] 100 "PASSED" "***FAILED";
echo both ": outer unordered 2\n";


select count (*) from (select top 1000 b.row_no from t1 a left join t1 b table option (loop) on b.row_no = a.row_no + 100) c where f (c.row_no) is null;
-- XXX
-- echo both $if $equ $last[1] 100 "PASSED" "***FAILED";
-- echo both ": outer unordered 3\n";


create procedure cl_oj ()
{
  declare i int;
  for select a.fi2 as n1, b.fi2 as n2 from t1 a left join (select distinct fi2 from t1) b on b.fi2 = a.fi2 + 2 where a.fi2 > 1080 do
	       {
		 dbg_obj_princ (n1, ' ', n2);
	       }
}

-- a non join outer, the outer subq will go first since card known to be 0
select a.row_no, b.row_no from t1 a left join (select distinct row_no, o  from t1, rdf_quad where fi2 = -1 and s = iri_to_id ('ff', 0)) b on 1=1 where a.fi2 < 30;

-- other oj where optional comes first in join order
select top 10 a.row_no, b.row_no from t1 a left join t1 b on b.row_no = 111 where a.row_no between 10 and 1000;

select top 10 a.row_no, b.row_no from t1 a left join (select distinct row_no from t1 c) b on b.row_no = 111 where a.row_no between 10 and 1000;

select b.row_no, VECTOR_AGG (a.row_no) from t1 a left outer join t1 b on (a.row_no = b.row_no + 90) where a.row_no = 50 group by b.row_no;
echo both $if $equ $last[1] NULL "PASSED" "***FAILED";
echo both ": null in gby\n";

select b.string1, VECTOR_AGG (a.row_no) from t1 a left outer join t1 b on (a.row_no = b.row_no + 90) where a.row_no = 50 group by b.row_no;
echo both $if $equ $last[1] NULL "PASSED" "***FAILED";
echo both ": null in gby on string\n";
