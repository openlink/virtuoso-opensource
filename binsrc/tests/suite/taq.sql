



--  Test for async queue 


ECHO BOTH "Async Queue Tests\n";


drop table aqi;
create table aqi (n int);

create procedure INS1 (in n int)
{
  --dbg_obj_print ('ins1 ', n);
  insert into AQI (N) values (n);
  commit work;
  return '22';
}

create procedure taq1 (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
  return (aq_wait (aq, res, 1, err));
}

taq1 (1000, 1);



create procedure taq1t (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      ins1 (n);
    }
}

create procedure taq_drop (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
}

taq_drop (2000, 5);


create procedure taq_all (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
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
ECHO BOTH $IF $EQU $LAST[1] 514229 "PASSED" "***FAILED";
ECHO BOTH ": aq fi\n";
