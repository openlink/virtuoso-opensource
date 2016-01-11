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

-- Test for async queue


echo both "Async Queue Tests\n";


drop table aqi;
create table aqi (n int);

create procedure INS1 (in n int)
{
  --dbg_obj_print ('ins1 ', n);
  insert into AQI (N) values (n);
  commit work;
  return '22';
}

create procedure taq1 (in x int, in thrs int := 1, in flags int := 0)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs, flags);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
  return (aq_wait (aq, res, 1, err));
}

taq1 (1000, 1);



create procedure taq1t (in x int, in thrs int := 1, in flags int := 0)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs, flags);
  for (n:= 0; n < x; n:=n+1)
    {
      ins1 (n);
    }
}

create procedure taq_drop (in x int, in thrs int := 1, in flags int := 0)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs, flags);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
}

taq_drop (2000, 5);


create procedure taq_all (in x int, in thrs int := 1, in flags int := 0)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs, flags);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
  aq_wait_all (aq);
}

taq_all (1000, 10);


create procedure taq1err(in x int, in thrs int := 1)
{
  declare aq, res, err, v  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1_ERR', vector (n));
    }
 v := (aq_wait (aq, res, 1, err));
	dbg_obj_print (err);
	return v;
}

taq1err (1);

create procedure INS1_ERR (in q int, in w int)
{
  return 0;
}

taq1err (1);


create procedure fi (in i int)
{
  if (i < 2) return i;
  else return fi (i - 1) + fi (i - 2);
}


create procedure FIAQ (in i int)
{
  if (i < 20)
  return fi (i);
  declare aq, n1, n2 any;
  aq := async_queue (2, 1);
  n1 := aq_request (aq, 'DB.DBA.FIAQ', vector (i - 1));
  n2 := aq_request (aq, 'DB.DBA.FIAQ', vector (i - 2));
  return aq_wait (aq, n1, 1) + aq_wait (aq, n2, 1);
}

select fiaq (29);
echo both $if $equ $last[1] 514229 "PASSED" "***FAILED";
echo both ": aq fi\n";

create procedure taq_atomic ()
{
  __atomic (1);
  taq1 (1000, 10, 1);
  taq_drop (2000, 5, 1);
  taq_all (1000, 0, 1);
  __atomic (0);
}
;

taq_atomic ();


create procedure AQ_TEST (in i int)
{
  return i;
}

create procedure aql (in n int, in qo int)
{
  declare ctr int;
  declare aq any;
 aq := async_queue (16, 1);
  for (ctr := 0; ctr <n; ctr := ctr + 1)
    {
      if (qo) aq_queue_only (aq);
      aq_request (aq, 'DB.DBA.AQ_TEST', vector (1));
      aq_wait_all (aq);
    }
}

create procedure aql_no (in n int)
{
  declare ctr int;
  declare aq any;
 aq := async_queue (16);
  for (ctr := 0; ctr <n; ctr := ctr + 1)
    {
      aq_test (1);
    }
}




create procedure AQ_RT (in i int)
{
  return rdtsc ();
}


create procedure aq_rdtsc (in n int)
{
  declare ctr, mint, maxt, tm int;
  declare aq, arr any;
 aq := async_queue (16);
 arr := make_array (n, 'any');
  for (ctr := 0; ctr <n; ctr := ctr + 1)
    {
      arr[ctr] := aq_request (aq, 'DB.DBA.AQ_RT', vector (1));
    }
  for (ctr := 0; ctr < n; ctr := ctr + 1)
    {
    tm := aq_wait (aq, arr[ctr], 1);
      if (0 = ctr)
      mint := maxt := tm;
      else if (tm > maxt)
      maxt := tm;
      else if (tm < mint)
      mint := tm;
    }
  return maxt - mint;
}
