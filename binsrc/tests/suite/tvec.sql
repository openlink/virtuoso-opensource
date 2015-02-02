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



-- extpect 1000000 rows in t1

select count (*) from t1;
echo both $if equ $last[1] 1000000 "PASSED" "***FAILED";
echo both ":  Starting tvec\n";


-- vectored query basic tests

select row_no from t1 where row_no < 110;

select a.row_no, b.row_no, c.row_no from t1 a, t1 b, t1 c  where a.row_no < 110 and b.row_no between a.row_no - 1 and a.row_no + 1 and c.row_no =a.row_no option (loop, order);

select row_no  from t1 a where not exists (select 1 from t1 b table option (loop) where b.row_no = a.row_no + 10) or not exists (select 1 from t1 c table option (loop) where c.row_no = a.row_no - 10);

select row_no  from t1 a where not exists (select 1 from t1 b table option (loop) where b.row_no = a.row_no + 10) or not exists (select 1 from t1 c table option (loop)where c.row_no = a.row_no - 10);


select a.row_no, a.row_no + b.row_no from t1 a, t1 b where b.row_no = a.row_no + 1;


explain ('select row_no + 1 from t1 union select row_no from t1');

explain ('select * from (select distinct row_no from t1) f');

explain ('
select a.row_no from t1 a, (select fi2 as fi2 from (select fi2 from t1 union select fi3 from t1) s)  b where b.fi2 = a.row_no +1 option (order)
');

explain ('select (select b.row_no from t1 b where b.row_no = a.row_no + 1) from t1 a');

select top 10 fi2, count (*) from t1 group by fi2 order by 2 desc;


create procedure p () { return (select count (*) from t1);}');


update t1 set fi6 = rnd (1000 - fi6 + fi6);
create index fi6 on t1 (fi6);

select count (*) from t1 a table option (index t1), t1 b where a.fi6 =b.row_no option (order, loop);
select a.row_no, b.row_no, b.ct from t1 a, (select row_no, count (*) as ct from t1 group by row_no) b where a.row_no = b.row_no and a.row_no < 110 option (loop, order);

explain ('select 1 + (select count (*) from t1 b where b.row_no > a.row_no) from t1 a where a.row_no < 110');

explain ('select 1 + case when a.row_no < 100 then (select count (*) from t1 b where b.row_no > a.row_no) else (select count (*) from t1 b where b.row_no < a.row_no) end from t1 a where a.row_no < 110');


create procedure plt ()
{
  declare cnt int;
  declare cn varchar;
  declare cr cursor for select key_name from sys_keys;
  open cr;
  fetch cr into cn;
  close cr;
  cnt := (select count (*) from sys_cols);
  for select "COLUMN" from sys_cols do {
    cnt := cnt + 1;
  }
  return cn;
}


create procedure n1 (in n int)
{
  if (mod (n, 2) = 1)
    return n * 2;
  else
    return -n * 2;
}


create procedure modv (in x int, in y int)
{
  vectored;
  return mod (x, y);
}

create procedure n1v (in n int)
{
  vectored;
  if (modv (n, 2) = 1)
    return n * 2;
  else
    return -n * 2;
}


update t1 set fi6 = mod (row_no, 13);
create bitmap index fi6 on t1 (fi6);

delete from t1 table option (index fi6) where fi6 = 8;


create procedure vec_ex (in stmt varchar)
{
  declare st, msg, md, rows any;
  exec (stmt, st, msg, vector (), 0, md, rows);
  return rows;
}


-- error on main thread with branches unscheduled - see how stuff is freed

__dbf_set ('aq_max_threads', 2);
__dbf_set ('enable_qp', 16);
select count (*) from t1 where row_no / (case when __qi_is_branch (row_no) then 1 else  0 end) = -1;

__dbf_set ('aq_max_threads', 20);
__dbf_set ('enable_qp', 8);

select row_no, (select max (row_no) from t1 b where b.row_no = a.row_no) from t1 a where row_no + 0 between  900 and 1100 and mod (row_no, 2) = 1 and (select max (c.row_no) from t1 c where c.row_no = a.row_no)  > 950;



__dbf_set ('enable_qp', 8);
__dbf_set ('enable_split_range', 0);
__dbf_set ('qp_thread_min_usec', 0);

-- make conditional subqs split in parallel, check that the results are gathered right
select row_no, case when mod (row_no, 2) = 1 then (select top 1 b.row_no from t1 b where b.row_no between a.row_no - 1 and a .row_no + 1 order by 1 asc) else (select top 1 b.row_no from t1 b where b.row_no between a.row_no - 1 and a .row_no + 1 order by 1 desc) end from  t1 a where row_no between 200 and 300;
select row_no, (select sum (b.row_no) from t1 b where b.row_no between a.row_no - 1 and a.row_no + 1) from t1 a where  row_no between 100 and 110;
select row_no, (select sum (b.row_no) from t1 b where b.row_no between a.row_no - 1 and a.row_no + 1) from t1 a where  row_no between 100 and 110 and row_no * 3 = (select sum (b.row_no) from t1 b where b.row_no between a.row_no - 1 and a.row_no + 1) ;

__dbf_set ('enable_split_range', 1);
__dbf_set ('qp_thread_min_usec', 5000);
