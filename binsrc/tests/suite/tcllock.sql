
--- cluster waits for ins and serializable 

drop table CLLK;
create table CLLK (id int primary key, dt varchar, ct int default 0)
alter index CLLK on CLLK partition (id int);


create procedure sread (in i int)
{
  set isolation = 'serializable';
  return (select dt from cllk where id >= i for update);
}

create procedure srcount (in i int)
{
  set isolation = 'serializable';
  return (select count (*) from cllk where id >= i for update);
}


create procedure sread_c (in i int)
{
  set isolation = 'committed';
  return (select dt from cllk where id >= i for update);
}

create procedure sread_ser (in i int)
{
  set isolation = 'serializable';
  return (select top 1 dt from cllk where id >= i for update);
}



set autocommit manual;
insert into cllk (id) values (10);
sread (10);

insert into cllk (id) values (11) &
insert into cllk (id) values (12) &
insert into cllk (id) values (13) &
insert into cllk (id) values (14) &

sleep (0.2);

select count (*) from cllk;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": cl serializable insert 1\n";

commit work;

delay (0.2);

select count (*) from cllk;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": cl serializable insert 2\n";


sread (10);
sread (14) &
sread (14) &
sread (14) &
sread (14) &
sread (14) &
sleep (0.2);
commit work;




create procedure dbllk (in i1 int, in i2 int)
{
  update cllk set dt = 'dd', ct = ct + 1 where id = i1;
  delay (0.6);
  update cllk set dt = 'dd', ct = ct + 1 where id = i2;
  commit work;
}

insert into cllk  (id) values (24);
insert into cllk  (id) values (25);
insert into cllk  (id) values (26);
insert into cllk  (id) values (27);
insert into cllk  (id) values (28);
insert into cllk  (id) values (29);
insert into cllk  (id) values (30);
insert into cllk  (id) values (31);


commit work;
set autocommit off;

dbllk (24, 25) &
dbllk (25, 24) &
wait_for_children;

-- deadlock with different combinations of local and distr detection and running on master and non-master.


create procedure upd_1 (in r int, in tm double precision)
{
  delay (tm);
  update cllk set dt = 'xx' where id = r;
}


create procedure dbllk_daq (in n1 int, in n2 int)
{
  declare daq any;
 daq := daq (1);
  daq_call (daq, 'DB.DBA.CLLK', 'CLLK', 'DB.DBA.UPD_1', vector (n1, 0), 1);
  daq_call (daq, 'DB.DBA.CLLK', 'CLLK', 'DB.DBA.UPD_1', vector (n1, 0), 1);
  daq_call (daq, 'DB.DBA.CLLK', 'CLLK', 'DB.DBA.UPD_1', vector (n2, 0.3), 1);
  daq_results (daq);
  commit work;
}

create procedure AQ_EXEC_SRV (in cmd varchar)
{
  declare st, msg any;
  st := '00000';
  exec (cmd, st, msg, vector ());
  if ('00000' <> st)
    signal (st, msg);
}


create procedure exec_from_daq (in cmd varchar)
{
  declare aq any;
 aq := async_queue (1);
  aq_request (aq, 'DB.DBA.AQ_EXEC_SRV', vector (cmd));
  aq_wait_all (aq);
}

create procedure ASYNC_daq_srv (in host int, in args any)
{
  declare daq any;
  if (host = sys_stat ('cl_this_host'))
    {
      exec (args);
      return;
    }
  daq := daq (1);
  daq_call (daq, '__ALL', vector (host), 'DB.DBA.CL_EXEC_SRV', vector (sprintf ('exec_from_daq (''%s'')', args), vector ()), 0);
  daq_results (daq);
}

create procedure test_deadlock (in n1 int, in n2 int, in host1 int, in host2 int, in f varchar := 'DB.DBA.DBLLK')
{
  declare str1, str2 varchar;
  str1 := sprintf ('%s (%d, %d)', f, n1, n2);
  str2 := sprintf ('%s (%d, %d)', f, n2, n1);
  declare exit handler for sqlstate '40001' {
    rollback work;
    return;
  };
  declare aq any;
  aq := async_queue (2);

  aq_request (aq, 'DB.DBA.ASYNC_DAQ_SRV', vector (host1, str1));
  delay (0.01);
  aq_request (aq, 'DB.DBA.ASYNC_DAQ_SRV', vector (host2, str2));
  aq_wait_all (aq);
  signal ('TXXXX', 'No deadlock even though  one is expected');
}

-- Different combinations of executing thread, place of deadlock.  The host that detects the deadlock is the one of the 1st arg of test_deadlock.

-- local detection on master 
  test_deadlock (24, 28, 1, 1);
  test_deadlock (24, 28, 2, 3);

-- local detection on non master 
  test_deadlock (25, 29, 1, 1);
  test_deadlock (25, 29, 4, 4);

-- distr detection, signal to master, then non-master
  test_deadlock (25, 26, 1, 1);
  test_deadlock (25, 26, 4, 4);
test_deadlock (25, 26, 1, 1, 'DB.DBA.DBLLK');
test_deadlock (25, 26, 4, 4, 'DB.DBA.DBLLK');



-- now deadlock with no distr wait notify, see if wiat query catches it 
cl_exec ('__dbf_set (''dbf_cl_skip_wait_notify'', 1)');
dbllk (24, 25) &
dbllk (25, 24) &
sleep 2;
__cl_wait_query ();
wait_for_children;
cl_exec ('__dbf_set (''dbf_cl_skip_wait_notify'', 0)');




---  A little thing with delld serializable rl getting acquired 

set autocommit manual;
insert into cllk  (id) values (64);
insert into cllk  (id) values (68);
insert into cllk  (id) values (72);
insert into cllk  (id) values (76);
commit work;


set autocommit manual;

delete from cllk where id = 68;
srcount (64) &
sleep 1;
srcount (68) &
sleep 1;
commit work;

insert into cllk  (id) values (68);
commit work;
delete from cllk where id = 68;

srcount (68) &
sleep 1;
srcount (64) &
sleep 1;
commit work;
