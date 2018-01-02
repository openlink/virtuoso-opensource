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


-- test cluster partitioned group by + order by


echo both "Cluster partitioned oby and gby/oby\n";


__dbf_set ('enable_setp_partition', 1);
cl_exec ('__dbf_set (''dc_batch_sz'', 7)');


explain ('select row_no, string2 from t1 table option (index str2) where row_no < 100 order by row_no + 1');


cl_exec ('__dbf_set (''cl_req_batch_size'', 3)');
cl_exec ('__dbf_set (''cl_res_buffer_bytes'', 100)');
__dbf_set ('enable_setp_partition', 1);

select row_no, string1 from t1 table option (index str1) where row_no < 1100 and string1 > ''order by row_no + 1;
echo both $if $equ $last[1] 121 "PASSED" "***FAILED";
echo both ": single partitioned oby\n";



select a.fi2, b.fi2 from t1 a, (select fi2 from t1 order by fi2 + 1) b where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 30 option (order);
echo both $if $equ $rowcnt 47 "PASSED" "***FAILED";
echo both ": partitioned oby in dt\n";

select a.fi2, b.fi2, dfi2 from t1 a, (select c.fi2, d.fi2 as dfi2 from t1 c, t1 d where d.fi2 = c.fi2 - 1  order by fi2 + 1) b where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 30 option (order);
echo both $if $equ $rowcnt 44 "PASSED" "***FAILED";
echo both ": partitioned oby in dfg dt\n";

-- the 2 below commented out since dt changed not to import join preds inside a top dt
select a.fi2, b.fi2 from t1 a, (select top 3 fi2 from t1 order by fi2 + 1) b where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 30 option (order);
--echo both $if $equ $rowcnt 30 "PASSED" "***FAILED";
--echo both ": partitioned oby in top dt\n";


select a.fi2, b.fi2, dfi2 from t1 a, (select top 4 c.fi2, d.fi2 as dfi2 from t1 c, t1 d where d.fi2 = c.fi2 - 1  order by fi2 + 1) b where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 30 option (order);
--echo both $if $equ $rowcnt 37 "PASSED" "***FAILED";
--echo both ": partitioned oby in top dfg dt\n";






create procedure brk (in n int)
{
  cl_idn (#i1);
  return n;
}

create procedure no_brk (in n int)
{
  return n;
}



select a.fi2, b.fi2 from t1 a, (select fi2 from t1 order by brk (fi2) + 1) b where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 120 option (order);

select a.fi2, b.fi2 from t1 a, (select fi2 from t1 order by no_brk (fi2) + 1) b where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 120 option (order);



create procedure sc_init (inout env any)
{
  env := '';
}

create procedure sc_acc (inout env any, in s varchar)
{
  env := env || s;
}

create procedure sc_fin (inout env any)
{
  env := 'f' || env;
  return env;
}


create procedure sc_merge (inout e1 any, inout e2 any)
{
  e1 := e1 || e2;
}


create aggregate strconc (in str varchar) returns varchar
  from sc_init, sc_acc, sc_fin, sc_merge;



create procedure uc_init (inout env any)
{
  env := 0;
}

create procedure uc_acc (inout env any, in s any array)
{
  env := env + 1;
}

create procedure uc_fin (inout env any) returns int
{
  return env;
}


create procedure uc_merge (inout e1 any, inout e2 any)
{
  e1 := e1 + e2;
}


create aggregate u_count (in n any) returns varchar
  from uc_init, uc_acc, uc_fin, uc_merge;


select a.string2, b.string1, sm from t1 a,
  (select string1, sum (row_no) as sm from t1 group by string1 order by 2) b
where b.string1  = a.string2;

select a.fi2, b.fi2, sm from t1 a,
  (select c.fi2, sum (c.row_no) as sm from t1 c  group by fi2 order by 2) b
where b.fi2 between a.fi2 - 2 and a.fi2 + 2 and a.fi2 < 30 option (order);



update t1 set fi6 = row_no / 10;
update t1 set fs4 = sprintf ('fs4 - %d', row_no);

explain ('select fi6, strconc (fs4) from t1 group by fi6');

select fi6, strconc (fs4) from t1 group by fi6;
echo both $if $equ $rowcnt 11 "PASSED" "***FAILED";
echo both ": ua with gb\n";

select fi6, strconc (fs4) from t1 group by fi6 order by length (strconc (fs4)) desc;
echo both $if $equ $rowcnt 11 "PASSED" "***FAILED";
echo both ": ua with gb and oby\n";

select top 5 fi6, strconc (fs4) from t1 group by fi6 order by length (strconc (fs4)) desc;
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": ua with gb and top oby\n";



select fi6, strconc (fs4 || make_string (500)) from t1 group by fi6 order by length (strconc (fs4)) desc;
echo both $if $equ $sqlstate 22026 "PASSED" "***FAILED";
echo both ": row too long in ua temp\n";

select fi6, strconc (fs4) from t1 table option (index str1) where fi2 <  0 group by fi6 order by length (strconc (fs4)) desc;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": part ua, no rows\n";


-- validate the result of the next
select count (*) from (select a.fi6, b.fi6 from t1 a, (select distinct fi6 from t1) b where b.fi6 between a.fi6 - 1 and a.fi6 + 1) q;
echo both $if $equ $last[1] 292 "PASSED" "***FAILED";
echo both ": 292 for fi6 x distinct fi6 range\n";


select a.fi6, b.fi6, ff
from t1 a, (select fi6, strconc (fs4) as ff from t1 table option (index str1) where string1 > ''group by fi6 order by (strconc (fs4)) || ' ' desc) b
where b.fi6 between a.fi6 - 1 and a.fi6 + 1 option (order);

echo both $if $equ $rowcnt 292 "PASSED" "***FAILED";
echo both ": part ua,multistate dfg dt with gb/oby\n";

update t1 set fi6 = row_no;
select a.fi6, b.fi6, ff
from t1 a, (select fi6, strconc (fs4) as ff from t1 table option (index str1) where string1 > ''group by fi6 order by  (strconc (fs4)) || ' '  desc) b
where b.fi6 between a.fi6 - 1 and a.fi6 + 1 option (order);

echo both $if $equ $rowcnt 299 "PASSED" "***FAILED";
echo both ": part ua,multistate dfg dt with gb/oby - 2\n";



-- anytimes with dfg and partitioned ua

cl_exec ('__dbf_set (''timeout_resolution_usec'', 200000)');
cl_exec ('__dbf_set (''timeout_resolution_sec'', 0)');

set result_timeout = 500;
-- timeout between the ssa iters
select top 20 a.fi2, u_count (b.fi2) from t1 a, t1 b where b.fi2 > a.fi2 group by a.fi2 order by u_count (b.fi2) + delay (0.05 + u_count (b.fi2) - u_count (b.fi2)) desc;

-- timeout before the 1st ssa iter
select top 20 a.fi2, u_count (b.fi2) from t1 a, t1 b where b.fi2 > a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.01)group by a.fi2 order by u_count (b.fi2) desc;



select top 100 a.fi2, u_count (b.fi2) from t1 a, t1 b where b.fi2 = a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.02)group by a.fi2 order by u_count (b.fi2) desc  ;


select top 100 a.fi2, b.fi2, u_count (b.fi2) from t1 a, t1 b where b.fi2 = a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.02)group by a.fi2 order by u_count (b.fi2) desc, b.fi2;

set result_timeout = 0;


-- error below, b.fi2 not in select or gby but is in oby.
select top 100 a.fi2, u_count (b.fi2) from t1 a, t1 b where b.fi2 = a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.02)group by a.fi2 order by u_count (b.fi2), b.fi2 desc  ;


select top 100 a.fi2, b.fi2, u_count (b.fi2) from t1 a, t1 b where b.fi2 = a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.02)group by a.fi2 order by u_count (b.fi2) desc, b.fi2;
echo both $if $equ $last[2] 119 "PASSED" "***FAILED";
echo both ": gby/obby on user aggr\n";


select  a.fi2, (select s from (select top 1 strconc (cast (b.fi2 as varchar) || ' ') as s, b.fi2 from t1 b table option (loop) where b.fi2 = a.fi2 + 1 group by b.fi2 order by s)  dt) from  t1 a;
