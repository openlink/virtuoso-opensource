


-- multithread transactions 


__dbf_set ('enable_mt_txn', 1); 
__dbf_set ('qp_thread_min_usec', 0); 

drop index fi2;
drop index fi6;
drop index time1;

update t1 set fi2 = 0;


create procedure T1L (in r int, in delay float := null)
{
  if (delay is not null)
    delay (delay);
  return (select fi2 from t1 where row_no = r for update);
}


create table t1incs (seq int identity primary key, row int, w_id int, rc_w_id int, ts timestamp);

create procedure T1INC (in r int, in delay float := null) 
{ 
  declare w_id, rc_w_id int; 
 rc_w_id := bit_and (0hexfffffff, lt_rc_w_id ()); 
 w_id := bit_and (0hexfffffff, lt_w_id ()); 

  if (delay is not null) 
    delay (delay); 
  update t1 set fi2 = fi2 +1, fi6 = w_id, fi7 = rc_w_id where row_no = r; 
  insert into t1incs (row, w_id, rc_w_id) values (r, w_id, rc_w_id); 
  return (select fi2 from t1 where row_no = r for update); 
} 

create procedure mtt1 () 
{ 
  declare aq1, aq2 any; 
 aq1 := async_queue (1, 9); 
  aq_request (aq1, 'DB.DBA.T1L', vector (100, 0)); 
  aq_request (aq1, 'DB.DBA.T1L', vector (101, 1)); 
  delay (0.1); 
  T1L (100, 0); 
  T1L (105); 

  commit work; 
  aq_wait_all (aq1); 
} 


create procedure t1dl (in r1 int, in r2 int) 
{ 
  declare aq1, aq2 any; 
 aq1 := async_queue (1, 9); 
  aq_request (aq1, 'DB.DBA.T1INC', vector (r1, 0)); 
  aq_request (aq1, 'DB.DBA.T1INC', vector (r2, 0.1)); 
  delay (0.2); 
  commit work; 
} 

create procedure mte (in f varchar, in a int) 
{ 
  declare aq any; 
 aq := async_queue (2, 9); 
  aq_request (aq, f, vector (a, 0)); 
  aq_wait_all (aq); 
} 


t1dl (110, 120) & 
t1dl (120, 110); 






create table txns (seq int primary key, ts timestamp); 

create procedure mtdltxn (in rows int, in locks int, in spacing int) 
{ 
  declare inx, seq int; 
  declare aq, dict  any; 
 dict := dict_new (23); 
 seq := sequence_next ('txno'); 
 aq := async_queue (2, 9); 
  for (inx := 0; inx < locks; inx := inx + 1) 
    { 
      declare r int; 
    r := bit_or (rnd (rows), rnd (rows)); 
      while (dict_get (dict, r)) 
      r := r + 1; 
      dict_put (dict, r, 1); 
      aq_request (aq, 'DB.DBA.T1INC', vector (100 + r * spacing, 0)); 
      if (-1 = rnd (100)) 
	{ 
	  rollback work; 
	  signal ('40001', 'fake deadl'); 
	} 
    } 
  aq_wait_all (aq); 
  insert into txns values (seq, now ()); 
  commit work; 
} 


create procedure mtdl (in repeats int, in rows int, in locks int) 
{ 
  declare ctr, spacing  int; 
  if (sys_stat ('enable_col_by_default'))
  spacing := 1000;
  else 
  spacing := 1;
  for (ctr := 0; ctr < repeats; ctr := ctr + 1) 
    { 
      declare exit handler for sqlstate '40001' { rollback work; goto again;}; 
    again: 
      mtdltxn (rows, locks, spacing); 
    } 
} 



mtdl (1000, 1000, 10) &
mtdl (1000, 1000, 10) &
mtdl (1000, 1000, 10) &
mtdl (1000, 1000, 10) &
wait_for_children;

select (select sum (fi2) from t1) - (select count (*) from t1incs);
echo both $if $equ $last[1] 0 "PASSED"  "***FAILED";
echo both ": counts in updated/inserted m,match\n";




select w_id, rc_w_id, count (*) from t1incs a where not exists (select 1 from txns b where a.ts = b.ts) group by w_id, rc_w_id order by 3;
echo both $if $equ $rowcntt 0 "PASSED"  "***FAILED";
echo both ": no unrecorded txn timestamps\n";

select row_no, fi2, cnt from (select row_no, fi2, (select  count (*) from t1incs where row = row_no) as cnt   from t1) f where fi2 <> cnt;
echo both $if $equ $rowcnt 0 "PASSED"  "***FAILED";
echo both ": mt insert incs and counts match\n";


update t1 set fi2 = fi2 + 1 where row_no in (select row_no from t1 where row_no < 1000); 

