
-- test of distr query frags 
-- int state is ../ins 1111 100 20


cl_exec ('__dbf_set (''dc_batch_sz'', 7)');
cl_exec ('__dbf_set (''enable_dyn_batch_sz'', 0)');
cl_exec ('__dbf_set (''cl_res_buffer_bytes'', 100)');
cl_exec ('__dbf_set (''qp_thread_min_usec'', 0)');
cl_exec ('__dbf_set (''enable_qp'', 8)');


explain ('select a.fi2, b.fi2 from t1 a, t1 b where a.fi3 = b.fi3 order by a.fi3 option (loop)');


explain ('select b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and a.fi2 = 1 order by 1 + b.fi2 option (loop)');

select b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and a.fi2 = 21 order by 1 + b.fi2 option (loop);

select b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and a.fi2 = 21 order by 1 + b.fi2 option (loop);

select b.fi2 from t1 a, t1 b where b.fi2 between  a.fi2 - 2 and a.fi2 + 2  and a.fi2 = 21 order by 1 + b.fi2 option (loop);

select count (*) from t1 a, t1 b where b.fi2 = 1+ a.fi2 and a.fi2 in ( 21,  22) option (loop);
-- XXX
--echo both $if $equ $last[1] 2 "PASSED" "***FAILED";
--echo both ": select count  with in \n";
 

select count (*) from t1 a, t1 b where b.fi2 = 1+ a.fi2 and a.fi2 in ( 21,  22) option (loop);
-- XXX
--echo both $if $equ $last[1] 2 "PASSED" "***FAILED";
--echo both ": select count  with in\n";


select count (*) from t1 a, t1 b where b.fi2 = 1+ a.fi2 option (loop);
-- XXX
--echo both $if $equ $last[1] 99 "PASSED" "***FAILED";
--echo both ": select count f2 = f2 + 1 \n";


select count (*) from t1 a, t1 b where b.fi2 between   a.fi2 - 200 and a.fi2 + 200  option (loop);
-- XXX
--echo both $if $equ $last[1] 10201 "PASSED" "***FAILED";
--echo both ": select count f2 = f2 + 1 \n";


select a.fi2, (select count (*) from t1 b, t1 c where c.fi2 = b.fi2 + 1 and b.fi2 = a.fi2 + 1) from t1 a where a.fi2 < 40;
-- XXX
--echo both $if $equ $last[2] 1 "PASSED" "***FAILED";
--echo both ": dfg multistate count subq\n";

select a.fi2, c.fi2, c from t1 a, (select b.fi2, count (*) as c from t1 b group by b.fi2) c where c.fi2 between a.fi2 - 2 and a.fi2 + 2 option (loop, order);




select count (*) from ct a, ct b where b.row_no = a.row_no + 1 option (loop);


select count (*) from t1 a where exists (select 1 from t1 b table option (loop) where a.fi2 = b.fi2);

select count (*) from t1 a where exists (select 1 from t1 b table option (loop) where a.fi3 = b.fi2);

explain ('select count (*) from t1 a table option (index fi2) where exists (select 1 from t1 b table option (loop) where a.fi3 = b.fi2 and b.fi2 + 2 > 0)');

explain ('select count (*) from t1 a table option (index fi2) where exists (select 1 from t1 b table option (loop) where a.fi3 = b.fi2 and b.fi2 + 2 > 0) option (do not loop exists)');


set autocommit on;
-- dfg has a for update part, must enlist from the start.
select count (*) from t1 a where exists (select 1 from t1 b where b.fi2 = 1 + a.fi2 for update);



create procedure dfgp ()
{
  declare i int;
  for (i:=0; i < 10; i:=i + 1)
    {
      dbg_obj_princ ('ts 1 ', (select count (*) from t1 a, t1 b where a.fi2 > i + 20 and b.fi2 = a.fi2 + 1 option (loop)));
      for  select b.fi2 from t1 a, t1 b where a.fi2 between  i + 20and i + 30  and b.fi2 = a.fi2 + 1 order by b.fi2 + 0 do
		     {
		       dbg_obj_princ (fi2);
		     }
    }
}

create procedure iso_qf ()
{
  update t1 set fi2 = row_no where row_no in (100, 1024 + 100);
  select count (*) from t1 where row_no  in (100, 1024 + 100);
}




