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


-- cluster recursive ops

select sys_stat ('cluster_enable');

#if $equ $last[1] 1




-- run against ins 1111 100000 100

update t1 set fi6 = 100100 - row_no, fi3 = 100 + rnd (100000 + fi3 - fi3);

create procedure rec (in i int, in wait real)
{
	  declare daq, res any;
  daq := daq (1);
  if (i < 256)
  return 0;
  daq_call (daq, 'DB.DBA.T1', 'T1', 'DB.DBA.REC', vector (i - 256, wait), 0);
  daq_send (daq);
  delay (wait);
  res := daq_next (daq);
  return 1 + res[2][1];
}

create procedure REC_FI (in i int, in n int)
{
  declare daq, res, res2 any;
  if (n < 2)
    return n;
  daq := daq (1);
  daq_call (daq, 'DB.DBA.T1', 'T1', 'DB.DBA.REC_FI', vector (rnd (102400), n - 1), 0);
  daq_call (daq, 'DB.DBA.T1', 'T1', 'DB.DBA.REC_FI', vector (rnd (102400), n - 2), 0);
  daq_send (daq);
  res := daq_next (daq);
 res2 := daq_next (daq);
  return  res[2][1] + res2[2][1];
}


select rec_fi (0, 10);
select rec_fi (0, 22);
echo both $if $equ $last[1]  17711 "PASSED" "***FAILED";
echo both ": rec fi 22\n";



select sum (rec (row_no, 0)) from t1 where row_no < 25600 and mod (row_no, 128) = 0;
echo both $if $equ $last[1] 9900  "PASSED" "***FAILED";
echo both ":  sum of rec daq in qf\n";

select sum (rec (row_no, 0)) from t1 where row_no < 25600 and mod (row_no, 128) = 0 for update;
echo both $if $equ $last[1] 9900  "PASSED" "***FAILED";
echo both ":  sum of rec daq in qf for upd\n";

select c.row_no from t1 a, t1 b, t1 c where a.row_no = 111 and b.row_no = a.row_no + 1 and c.row_no = b.row_no + 1 and c.row_no / 0 = 1 option (any order)  ;

select c.row_no from t1 a, t1 b, t1 c where a.row_no = 111 and b.row_no = a.row_no + 1 and c.row_no = b.row_no + 1 and c.row_no / 0 = 1;

select sum ((select count (*) from t1 b where b.row_no = a.row_no + 200)) from t1 a where row_no < 10000;
echo both $if $equ $last[1] 9900  "PASSED" "***FAILED";
echo both ":  sum qf in qf\n";


select  count (*)  from t1 a where row_no < 130000   and  (select count (*) from t1 b where b.row_no = a.row_no + 100) <>1;
echo both $if $equ $last[1] 100  "PASSED" "***FAILED";
echo both ":  count exists  qf in qf\n";

select top 120 a.row_no  from t1 a where row_no < 130000   and  (select count (*) from t1 b where b.row_no = a.row_no + 100) <>1;




select (select (select sum (c.row_no + d.row_no) from t1 c, t1 d where d.row_no = 256 + c.row_no and c.row_no = 512 + b.row_no) from t1 b where b.row_no = 256 + a.row_no) from t1 a where a.row_no = 111;

select (select (select sum (c.row_no + d.row_no) from t1 c, t1 d where d.row_no = 256 + c.row_no and c.row_no = 512 + b.row_no) from t1 b where b.row_no = 256 + a.row_no) from t1 a where a.row_no = 111 + 256;


select g, ct from t1 a, (select b.row_no as g, count (*) as ct from t1 b group by b.row_no) dt where g between a.row_no + 250 and a.row_no + 260 and a.row_no =  512;


select sum (cl_idn (1 + b.row_no - b.row_no)), count (*) from t1 a, t1 b where b.row_no = a.row_no + 256 option (order, loop);
echo both $if $equ $last[1]  99744 "PASSED" "***FAILED";
echo both ": sum with cl idn at end\n";

select sum (cl_idn (1)), count (*) from t1 a, t1 b where b.row_no = a.row_no + 256 option (order, loop);
echo both $if $equ $last[1]  99744 "PASSED" "***FAILED";
echo both ": sum with cl idn at start\n";


select count (*) from t1 a where exists (select 1 from t1 b where b.row_no between a.row_no - 300 and a.row_no + 300) and row_no < 10100;
echo both $if $equ $last[1] 10000 "PASSED" "***FAILED";
echo both ": count qf w exists of large range\n";

select count (*) from t1 a where exists (select 1 from t1 b, t1 c where b.row_no = a.row_no + 256 and c.row_no = b.row_no + 768 option (loop, order));
echo both $if $equ $last[1] 98976 "PASSED" "***FAILED";
echo both ": count qf w exists dfg\n";


select count (*) from t1 a table option (index t1) where exists (select 1 from t1 b, t1 c where b.row_no = a.row_no + 200 and c.row_no = b.row_no + 800 option (loop, order));
echo both $if $equ $last[1] 99000  "PASSED" "***FAILED";
echo both ": count qf w exists dfg 2, dfg scattered\n";

select count (*) from t1 a table option (index t1) where exists (select 1 from t1 b, t1 c, t1 d where b.row_no = a.row_no + 200 and c.row_no = b.row_no + 800 and d.row_no = c.row_no / 3 option (loop, order));
echo both $if $equ $last[1] 99000  "PASSED" "***FAILED";
echo both ": count qf w exists dfg 2, 3 dfg converge\n";


select count (*) from t1 a table option (index t1) where exists (select 1 from t1 b, t1 c, t1 d where b.row_no = a.row_no + 200 and c.row_no = b.row_no + 800 and d.row_no = c.row_no / 3 option (loop, order));


select count (*) from t1 a table option (index t1), (select b.row_no as r, count (*) as ct from t1 b, t1 c, t1 d where  c.row_no = b.row_no + 800 and d.row_no = c.row_no / 3 group by r option (loop, order)) dt where 1 <= ct and dt.r = a.row_no + 200  option (loop, order);
echo both $if $equ $last[1] 99000  "PASSED" "***FAILED";
echo both ": count qf w 3 dfg gby\n";



create procedure dbl (in i innt) returns int
{
  vectored;
  return (select b.row_no from t1 a, t1 b where a.row_no = i and b.row_no = a.row_no * 2 option (loop, order));
}


create procedure dbl_dfg (in i innt) returns int
{
  vectored;
  return (select b.row_no from t1 a, t1 b where a.row_no = i and b.row_no = a.row_no * 2 option (loop, order, any order));
}


create procedure dbl_dfg3 (in i innt) returns int
{
  vectored;
  return (select b.row_no from t1 a, t1 b, t1 c  where a.row_no = i and b.row_no = a.row_no * 2 and c.row_no = b.row_no / 3 option (loop, order, any order));
}

create procedure add512 (in i innt) returns int
{
  vectored;
  return (select b.row_no from t1 a, t1 b where a.row_no = i + 256  and b.row_no = a.row_no + 256 option (loop, order));
}

create procedure add1k (in i innt) returns int
{
  vectored;
  return (select b.row_no from t1 a, t1 b where a.row_no = i + 256  and b.row_no = a.row_no + 768 option (loop, order));
}

create procedure t1cr (in r1 int, in r2 int)
{
  declare c, d int;
  declare cr cursor for select row_no from t1 where row_no between r1 and r2;
  whenever not found goto done;
 c := 0;
  open cr;
  for (;;)
    {
      fetch cr into d;
    c := c + 1;
    }
 done:
  return c;
}


cl_exec ('__dbf_set (''dc_batch_sz'', 50)');
cl_exec ('__dbf_set (''qp_thread_min_usec'', 0)');

select count (*) from t1 a where a.row_no < 1400 and case when mod (a.row_no / 256, 32) < 20 then   (case when 1000 = t1cr (a.row_no - 500, a.row_no + 499) then 1 else 0 end) else (case when 100 = t1cr (a.row_no - 50, a.row_no + 49) then 1 else 0 end) end;
echo both $if $equ $last[1] 800  "PASSED" "***FAILED";
echo both ": count qf w nested cr proc\n";





select count (*) from t1 a, t1 b where b.row_no = dbl (a.row_no) option (loop, order);
echo both $if $equ $last[1] 49950  "PASSED" "***FAILED";
echo both ": count dfg with nested dbl qf\n";


select count (*) from t1 a, t1 b where b.row_no = dbl_dfg (a.row_no) option (loop, order);
echo both $if $equ $last[1] 49950  "PASSED" "***FAILED";
echo both ": count dfg with nested dbl dfg\n";


select count (*) from t1 a, t1 b where b.row_no = dbl_dfg3 (a.row_no) option (loop, order);

select count (*) from t1 a, t1 b where b.row_no = dbl_dfg3 (a.row_no) option (loop, order);
echo both $if $equ $last[1] 49900  "PASSED" "***FAILED";
echo both ": count dfg with nested dbl dfg 3\n";

select count (*) from t1 a, t1 b, t1 c where c.row_no = dbl_dfg3 (b.row_no) and b.row_no = 256 + a.row_no option (loop, order);
echo both $if $equ $last[1] 49694   "PASSED" "***FAILED";
echo both ": count dfg 3 with nested dbl dfg 3\n";

select count (*) from t1 a, t1 b, (select d.row_no as r, count (*) as ct from t1 d, t1 e where e.row_no = d.fi3 group by r option (loop, order))  dt where r = b.row_no + 200 and b.row_no = a.row_no + 200 option (loop, order);
echo both $if $equ $last[1] 99600   "PASSED" "***FAILED";
echo both ": count dfg with nested dfg gby\n";

select top 20 a.row_no, r, ct from t1 a, t1 b, (select d.row_no as r, max (e.row_no) as ct from t1 d, t1 e where e.row_no = d.row_no + 200 group by r option (loop, order))  dt where r = b.row_no + 200 and b.row_no = a.row_no + 200 order by 0 + a.row_no option (loop, order);


select count (*) from t1 a where exists (select 1 from t1 b where b.row_no = a.fi6 * 2 and dbl_dfg (b.row_no) = b.row_no * 2  option (loop));
echo both $if $equ $last[1] 24975   "PASSED" "***FAILED";
echo both ": qf qf with inner rec dfg\n";



create procedure dp_fi2 (in r int) returns any array
{
  vectored;
  return vector ((select fi2 from t1 where row_no = r), 1);
}

create procedure dp_fi2e (in r int) returns any array
{
  vectored;
  return vector ((select fi2 from t1 where row_no = r for update), 1);
}

dpipe_define ('DB.DBA.T1FI2', 'DB.DBA.T1', 'T1', 'DB.DBA.DP_FI2', 128);
dpipe_define ('DB.DBA.T1FI2E', 'DB.DBA.T1', 'T1', 'DB.DBA.DP_FI2E', 128 + 1);

select count (T1fi2 (b.row_no + 200)) from t1 a, t1 b where b.row_no = a.row_no + 200 and a.row_no < 256 option (loop, order);
select count (T1fi2e (b.row_no + 200)) from t1 a, t1 b where b.row_no = a.row_no + 200 and a.row_no in (100, 220) option (loop, order);

select count (T1_fi2 (b.row_no + 200)) from t1 a, t1 b where b.row_no = a.row_no + 200 and a.row_no in (part_keys (0, 1000)) = 0 option (loop, order);





select count (*) from t1 a where exists (select 1 from t1 b where b.row_no = a.fi6 and exists (select 1 from t1 c, t1 d where c.row_no = b.row_no + 300 and d.row_no = c.row_no * 2 option (loop)) option (loop));





set autocommit manual;

insert into t1 (row_no, string1, string2) select row_no + 102400 + 200, string1, string2  from t1 where row_no = 111;

rollback work;

#endif
