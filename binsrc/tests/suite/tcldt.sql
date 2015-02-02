--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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


-- Multistate dt and code vec




echo both "Cluster multistate derived tables\n";



cl_exec ('__dbf_set (''dc_batch_sz'', 7)');
cl_exec ('__dbf_set (''enable_dyn_batch_sz'', 0)');



create procedure DPINC (in q int)
{
  return vector (q + 1, 1);
}

create procedure L_INC (in q int)
{
  cl_idn (#i100); -- colocation break
  return q + 1;
}


create procedure L_INC_pass (in q int)
{
  return q + 1;
}

dpipe_define ('DPINC', 'DB.DBA.T1', 'FI2', 'DB.DBA.DPINC', 0);


explain ('select row_no, (select top 1  b.row_no as ct  from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) as cnt from t1 a');

explain ('select row_no, (select  b.row_no as ct  from t1 b table option (loop) where b.row_no = 1 + a.row_no) as cnt from t1 a');

select row_no, (select  b.row_no as ct  from t1 b table option (loop) where b.row_no = 1 + a.row_no) as cnt from t1 a order by row_no;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": single row scalar  subq\n";
echo both $if $equ $last[2] NULL "PASSED" "***FAILED";
echo both ": null as scalar subq when no match\n";

select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where b.fi2 >= 1 + a.fi2 and b.fi2 < 300 order by b.fi2) as cnt from t1 a where fi2 < 200 order by fi2;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": implied top 1 in range subq\n";

select top 1 fi2, (select  b.fi2 as ct  from t1 b table option (loop) where sqrt (b.fi2) > 0 and b.fi2 >= 1 + a.fi2 order by b.fi2) as cnt from t1 a order by fi2;
echo both $if $equ $last[2] 21  "PASSED" "***FAILED";
echo both ": double implied top 1\n";

select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where l_inc (b.fi2) > 0 and b.fi2 >= 1 + a.fi2 and b.fi2 < 300 order by b.fi2) as cnt from t1 a where a.fi2 < 200 order by fi2;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": no implied top 1 in subq with func\n";

select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where l_inc_pass (b.fi2) > 0 and b.fi2 >= 1 + a.fi2 and b.fi2 < 300 order by b.fi2) as cnt from t1 a where fi2 < 200 order by fi2;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ":With colocated sql func:  no implied top 1 in subq with func\n";


select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where dpinc (b.fi2) > 0 and b.fi2 >= 1 + a.fi2 order by b.fi2) as cnt from t1 a order by fi2;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": no implied top 1 in subq with dp func\n";


select fi2, (select  dpinc (b.fi2) as ct  from t1 b table option (loop) where  b.fi2 >= 1 + a.fi2 order by b.fi2) as cnt from t1 a order by fi2;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": skipping sets with dp node in value subq\n";

select dpinc (row_no), (select  b.row_no as ct  from t1 b table option (loop) where b.row_no in ( 1 + a.row_no, 3 + a.row_no)) as cnt from t1 a table option (index primary key);
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ":  scalar  subq with in and dp\n";


select row_no, (select top 1  b.row_no as ct  from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) as cnt from t1 a where row_no < 300 order by row_no;
echo both $if $equ $last[2] 119 "PASSED" "***FAILED";
echo both ": scalar subq with top and range\n";


select row_no, (select count (*) as ct  from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) as cnt from t1 a where row_no < 300 order by row_no;
echo both $if $equ $last[2] 2 "PASSED" "***FAILED";
echo both ": scalar subq with count\n";


select row_no, (select max (b.row_no) - 1 as ct  from t1 b where b.row_no = 140 - a.row_no) as cnt from t1 a where row_no + 0 < 90 order by row_no;
echo both $if $equ $last[2] 50 "PASSED" "***FAILED";
echo both ": scalar subq with exp on aggregate\n";


select row_no, case when mod (row_no, 2 ) = 1 then (select max (b.row_no) - 1 as ct  from t1 b where b.row_no = 140 - a.row_no) else 1 end  as cnt from t1 a where row_no + 0 < 90 order by row_no;
echo both $if $equ $last[2] 50 "PASSED" "***FAILED";
echo both ": cond scalar subq with exp on aggregate\n";

select row_no, case when mod (row_no, 2 ) = 1 then (select  (b.row_no) - 1 as ct  from t1 b table option (hash) where b.row_no = 140 - a.row_no) else 1 end  as cnt from t1 a where row_no + 0 < 90 order by row_no;
echo both $if $equ $last[2] 50 "PASSED" "***FAILED";
echo both ": cond scalar subq with exp on result, hash\n";

select row_no, case when mod (row_no, 2 ) = 1 then (select  (b.row_no) - 1 as ct  from t1 b table option (loop) where b.row_no = 140 - a.row_no) else 1 end  as cnt from t1 a where row_no + 0 < 90 order by row_no;
echo both $if $equ $last[2] 50 "PASSED" "***FAILED";
echo both ": cond scalar subq with exp on result, loop\n";


explain ('select a.row_no, b.row_no from t1 a left join (select row_no from t1) b on b.row_no in (a.row_no + 1, a.row_no + 2)');

select a.row_no, b.row_no from t1 a left join (select row_no from t1) b on b.row_no in (a.row_no + 1, a.row_no + 2) where a.row_no < 300;
echo both $if $equ $rowcnt 199 "PASSED" "***FAILED";
echo both ": oj of dt 199 rows\n";


select a.row_no, b.row_no from t1 a left join (select row_no from t1) b on b.row_no in (a.row_no + 199, a.row_no + 299);
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": oj of dt no hit 101 rows\n";




-- implicit top in value subq

select a.row_no, (select count (*) from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) from t1 a;

select a.row_no, (select b.row_no from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) from t1 a  ;
-- other partition with fi2 inx
select a.row_no, (select b.row_no from t1 b where b.fi2 between a.row_no - 2 and a.row_no + 2 order by b.fi2) from t1 a where row_no < 300     order by row_no;
echo both $if $equ $last[2] 119 "PASSED" "***FAILED";
echo both ": scalar subq with multivalue range\n";



select a.row_no, (select b.row_no from t1 b, t1 d  where b.fi2 between a.row_no - 2 and a.row_no + 2 and d.fi2 > b.row_no) from t1 a  ;


select a.row_no, (select d.row_no from t1 b, t1 d  where b.fi2 between a.row_no - 2 and a.row_no + 2 and d.fi2 > b.row_no - 2 and d.fi2 < 400 order by b.fi2, d.fi2) from t1 a where row_no < 300     order by row_no;
echo both $if $equ $last[2] 118 "PASSED" "***FAILED";
echo both ": scalar subq with joined multivalue range\n";


-- top and skip of derived table
-- Note that a dt with a top cannot import predicates.
select a.row_no, b.row_no from t1 a, (select top 3 c.row_no from t1 c) b where b.row_no > a.row_no and a.row_no < 300 option (loop, order);



--select a.row_no, b.row_no from t1 a table option (index t1), (select  top 3  c.row_no from t1 c ) b where b.row_no in ( a.row_no, a.row_no + 1)  option (loop, order);
--echo both $if $equ $rowcnt 200 "PASSED" "***FAILED";
--echo both ": dt with in\n";


-- group by

update t1 set fi6 = row_no / 10;
create index fi6 on t1 (fi6) partition (fi6 int);

select fi6, count (*) from t1 where row_no < 300 group by fi6 order by 2 desc;
echo both $if $equ $last[2] 1 "PASSED" "***FAILED";
echo both ": simple group by\n";


select a.fi6, b.* from (select distinct fi6 from t1) a, (select fi6, count (*) as ct from t1 group by fi6) b where b.fi6 = a.fi6 and a.fi6 < 400 order by a.fi6 option (order);
echo both $if $equ $last[3] 1 "PASSED" "***FAILED";
echo both ": multistate  group by dt\n";


select a.fi6, b.* from (select distinct fi6 from t1) a, (select fi6, count (*) as ct from t1 group by fi6) b where b.fi6 between  a.fi6 - 1 and a.fi6 + 1 and a.fi6 < 40 order by 1, 2 option (order);
echo both $if $equ $last[3] 1 "PASSED" "***FAILED";
echo both ": multistate  group by dt with range, gb partitioned\n";

select  a.fi6, b.* from (select distinct fi6 from t1) a, (select fi6, fi6 + 0 as dum, count (*) as ct from t1 group by fi6, fi6 + 0) b where b.fi6 between  a.fi6 - 1 and a.fi6 + 1 and a.fi6 < 40 order by 1, 2 option (order);
echo both $if $equ $last[4] 1 "PASSED" "***FAILED";
echo both ": multistate  group by dt with range, gb not partitioned\n";



-- existence

select a.row_no from t1 a where not exists (select 1 from t1 b where b.row_no > a.row_no + 30) and not exists (select 1 from t1 c where c.row_no < a.row_no - 30);
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": not exists and not exists empty\n";


select a.row_no from t1 a where not exists (select 1 from t1 b where b.row_no > a.row_no + 60) and not exists (select 1 from t1 c where c.row_no < a.row_no - 60);
echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
echo both ": not exists and not exists 20\n";

select a.fi2 from t1 a where not exists (select 1 from t1 b where b.fi2 > a.fi2 + 60) and not exists (select 1 from t1 c where c.fi2 < a.fi2 - 60);

select a.fi2 from t1 a where exists (select 1 from t1 b where b.fi2 > a.fi2 + 60) and exists (select 1 from t1 c where c.fi2 < a.fi2 - 60);
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ":  exists and  exists 2 0\n";

select a.fi2 from t1 a where exists (select 1 from t1 b where b.fi2 > a.fi2 + 40) and exists (select 1 from t1 c where c.fi2 < a.fi2 - 40);
echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
echo both ":  exists and  exists 20\n";

select a.fi2 from t1 a where exists (select 1 from t1 b where b.fi2 in (a.fi2 + 40, a.fi2 + 41)) and exists (select 1 from t1 c where c.fi2 in ( a.fi2 - 40, a.fi2 - 41));
echo both $if $equ $rowcnt 22 "PASSED" "***FAILED";
echo both ":  exists and  exists 22\n";

select fi2 from t1 a where mod (fi2, 2) = 1 and exists (select 1 from t1 b table option (loop)where b.fi2 = 1 + a.fi2)  ;
echo both $if $equ $rowcnt 49 "PASSED" "***FAILED";
echo both ":sparse   exists loop\n";

select fi2 from t1 a where mod (fi2, 2) = 1 and exists (select 1 from t1 b table option (hash)where b.fi2 = 1 + a.fi2)  ;
echo both $if $equ $rowcnt 49 "PASSED" "***FAILED";
echo both ":sparse   exists hash\n";


select fi2, s.string1 from (select distinct string1 from t1) s, t1 where row_no = (select max (row_no) from t1 where string1 = s.string1);


-- both after code and after test are multistate
select row_no, (select count (*) from t1 b where b.string1 = a.string1) from t1 a where not exists (select 1 from t1 c table option (loop) where c.row_no = a.row_no + 10);

-- unions

select a.fi2, b.fi2 from t1 a, (select fi2 from t1 union select row_no from t1) b where a.fi2 + 1 = b.fi2 option (order);
echo both $if $equ $rowcnt 99 "PASSED" "***FAILED";
echo both ": union\n";


select a.fi2, b.fi2 from t1 a, (select fi2 from t1 union all select
row_no from t1) b where a.fi2 + 1 = b.fi2 option (order);
echo both $if $equ $rowcnt 198 "PASSED" "***FAILED";
echo both ": union all dt\n";





-- multistate except not supported
-- select a.fi2, b.fi2 from t1 a, (select fi2 from t1 except select row_no from t1) b where a.fi2 + 1 = b.fi2 option (order);
-- echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
-- echo both ": except \n";

select fi2 from t1 a where a.fi2 in (select b.fi2 from t1 b where b.fi2 = a.fi2 group by b.fi2 having sum (b.fi2) > 80) option (do not loop exists);
echo both $if $equ $rowcnt 40 "PASSED" "***FAILED";
echo both ": having over group by agg in existence subq, the gb is done by the partitions, no looping of exists\n";

select fi2 from t1 a where a.fi2 in (select b.row_no - 1 from t1 b where b.fi2 >= a.fi2 + 1 and b.fi2 < a.fi2 + 2 group by b.row_no - 1 having sum (b.row_no) > 80) option (do not loop exists);
echo both $if $equ $rowcnt 39 "PASSED" "***FAILED";
echo both ": having over group by agg in existence subq, the gb is summed on coordinator, no looping of exists\n";


select c.fi2, sum (c.row_no) from t1 a, t1 b table option (hash), t1 c table option (loop) where b.fi2 = a.fi2 + 1 and c.fi2 = b.fi2  group by c.fi2 order by 2 desc option (order);
echo both $if $equ $rowcnt 99 "PASSED" "***FAILED";
echo both ": final partitioned gb oby, many batches, one set\n";

select c.fi2, sum (c.row_no) from t1 a, t1 b table option (hash), t1 c table option (hash) where b.fi2 = a.fi2 + 1 and c.fi2 = b.fi2  group by c.fi2 order by 2 desc option (order);
echo both $if $equ $rowcnt 99 "PASSED" "***FAILED";
echo both ": final partitioned gb oby, many batches, one set, hash \n";



select c.fi2, sum (c.row_no) from t1 a, t1 b table option (hash), t1 d, t1 c where b.fi2 = a.fi2 + 1 and d.fi2 = b.fi2 and c.fi2 = d.fi2 + 1 group by c.fi2 order by 2 desc option (order);
echo both $if $equ $rowcnt 98 "PASSED" "***FAILED";
echo both ": final dfg w partitioned gb oby, many batches, one set\n";



-- vectored special cases of oby/gb

cl_exec ('__dbf_set (''qp_thread_min_usec'', 0)');
cl_exec ('__dbf_set (''enable_qp'', 8)');

select top 10 a.row_no from t1 a table option (index t1), t1 b  where b.row_no = a.row_no and 0 + a.row_no between 80 and 90 order by a.row_no + 0 option (order, loop);

select top 10 row_no, (select c.row_no from t1 c table option (loop) where c.row_no = 1 + a.row_no) from t1 a where row_no + 1 = (select b.row_no from t1 b table option (loop) where b.row_no = 1 + a.row_no);

select a.string1, count (*) from t1 a, t1 b where b.row_no = 1000 + a.row_no group by a.string1 order by a.string1 option (order, hash);
select a.string1, count (*) from t1 b, t1 a where b.row_no = 1000 + a.row_no group by a.string1 order by a.string1 option (order, hash);
select a.string1, count (*) from t1 a, t1 b where b.row_no = 1000 + a.row_no group by a.string1 having count (*) <> 3330 order by a.string1 option (order, loop);


select a.row_no, c.row_no, ct from t1 a, (select b.row_no, count (*) as ct from t1 b group by b.row_no ) c where c.row_no between a.row_no - 1 and a.row_no + 1 and ct <> 1;


-- test aliasing of out cols to search params
select a.fi2, b.fi2, c.fi2, d.fi2 from t1 a, (select distinct b1.fi2, b2.fi2 as fixx from t1 b1, t1 b2 where b1.fi2 = b2.fi2) b, t1 c left join t1 d on c.fi2 = d.fi2 where b.fi2 = a.fi2 and c.fi2 = a.fi2 option (loop, order);


-- scalar and ref param partition
create procedure refdfg (inout i int)
{
  return (select count (*) from t1 a, t1 b where a.row_no = i and b.row_no = i +256);
}

create procedure refqf (inout i int)
{
  return (select count (*) from t1 a, t1 b where a.row_no = i and b.row_no = a.row_no);
}

select refdfg (100 + 1);
select refqf (100 + 1);



--- ship partitioned oby+reader in subq
select row_no, (select top 1  b.fi2 as ct  from t1 b where b.fi2 between a.row_no - 2 and a.row_no + 2 order by b.fi2 + 1) as cnt from t1 a;
echo both $if $equ $rowcnt 101 "PASSED" "***FAILED";
echo both ": sorted partitioned oby shipped in scalar subq\n";



create procedure idnany (in i int) returns any array {return i;}


select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = a.fi2 * 2 order by b.fi2 + 1 desc;
 echo both $if $equ $last[2] "40" "PASSED" "***FAILED";
echo both ": dfg partitioned  oby\n";

select top 10 a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = a.fi2 * 2 order by b.fi2 + 1 desc;
 echo both $if $equ $last[2] "100" "PASSED" "***FAILED";
echo both ": dfg partitioned top oby\n";

select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = a.fi2  order by b.fi2 + 1 desc option (loop);
 echo both $if $equ $last[2] "20" "PASSED" "***FAILED";
echo both ": qf partitioned top oby\n";

select top 10 a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = a.fi2  order by b.fi2 + 1 desc option (loop);
 echo both $if $equ $last[2] "111" "PASSED" "***FAILED";
echo both ": qf partitioned oby\n";


-- bad alias of sll in below
--select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = a.fi2  order by b.fi2 + 1 desc option (hash);
-- echo both $if $equ $last[2] "20" "PASSED" "***FAILED";
--echo both ": qf partitioned top oby hash\n";

--select top 10 a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = a.fi2  order by b.fi2 + 1 desc option (hash);
-- echo both $if $equ $last[2] "111" "PASSED" "***FAILED";
--echo both ": qf partitioned oby hash\n";

select a.fi2, count (*) from t1 a, t1 b where b.fi2 = a.fi2 + 1 group by a.fi2 order by 1 option (loop, order);
echo both $if $equ $last[1] 118 "PASSED" "***FAILED";
echo both ": dfg gby oby merged\n";


select b.fi2, count (*) from t1 a, t1 b where b.fi2 = a.fi2 + 1 group by b.fi2 order by 1 option (loop, order);
echo both $if $equ $last[1] 119 "PASSED" "***FAILED";
echo both ": dfg gby oby partition on group key, local partitioned gby, oby\n";

select a.fi2, sum (idnany (b.fi2)) from t1 a, t1 b where b.fi2 = a.fi2 + 1 group by a.fi2 order by 1 option (loop, order);
echo both $if $equ $last[1] 118 "PASSED" "***FAILED";
echo both ": dfg untyped gby oby merged\n";


select b.fi2, sum (idnany (b.fi2)) from t1 a, t1 b where b.fi2 = a.fi2 + 1 group by b.fi2 order by 1 option (loop, order);
echo both $if $equ $last[1] 119 "PASSED" "***FAILED";
echo both ": dfg untyped gby oby partition on group key, local partitioned gby, oby\n";



select a.fi2, sum (idnany (b.fi2)) from t1 a, t1 b where b.fi2 = a.fi2 + 1 group by a.fi2 order by 1 option (loop,order);

