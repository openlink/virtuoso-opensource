


--  Measure aggregate throughput of a cluster interconnect.
-- Every node runs a thing that sends a req to every other, then it waits for all, then sends another.
  --  Every node does this on n threads for n messages, each message is a batch of so many rpc's, each passes and returns a string of so many bytes.
-- The result is round trips per second, i.e. served single messages and a total throughput in M bytes per second.
--
-- net_meter (n-threads, n-batches, bytes-per-rpc, rpcs-per-batch) 



--
--


create procedure _NMSRV (in str varchar)
{
  return str;
}

create procedure nm_run (in n_batches int, in bytes int, in ops_per_batch int)
{
  declare daq any;
  declare i, h, n, nh int;
  nh := sys_stat ('cl_n_hosts');
  set vdb_timeout = 2000;
  daq := daq (0);
  for (n:=0; n<n_batches; n := n + 1)
    {
      for (i:= 0; i < ops_per_batch; i:= i + 1)
	{
	  for (h := 1; h <= nh; h:= h + 1)
	    {
	      if (h <> sys_stat ('cl_this_host'))
		daq_call (daq, '__ALL', vector (h), 'DB.DBA._NMSRV', vector (make_string (bytes)), 0);
	    }  
	}
      declare exit handler for sqlstate '*' {
	log_message (sprintf ('In net_meter %s %ss', __sql_state, __sql_message));
	signal (__sql_state, __sql_message);
      };
      daq_results (daq);
    }
}


create procedure nm_start (in n_threads int, in n_batches int, in bytes int, in ops_per_batch int)
{
  declare aq any;
  declare c int;
 aq := async_queue (n_threads, 4);
  for (c:= 0; c < n_threads; c:= c + 1)
    {
      aq_request (aq, 'DB.DBA.NM_RUN', vector (n_batches, bytes, ops_per_batch));
    }
  aq_wait_all (aq);
}

create procedure nm_run_srv (in n_threads int, in  n_batches int, in bytes int, in ops_per_batch int)
{
  declare aq any;
 aq := async_queue (1, 4);
  aq_request (aq, 'DB.DBA.NM_START', vector  (n_threads, n_batches, bytes, ops_per_batch));
  aq_wait_all (aq);
}



create procedure net_meter (in n_threads int, in n_batches int, in bytes int, in ops_per_batch int)
{
  declare st, en, bs, msgs int;
  declare secs, round_trips, MBps real;
 st := msec_time ();
  cl_exec ('nm_run_srv (?,?,?,?)', vector (n_threads, n_batches, bytes, ops_per_batch));
 en := msec_time ();
 msgs := 2 * n_threads * n_batches * (sys_stat ('cl_n_hosts') - 1) * (sys_stat ('cl_n_hosts') - 1);
 bs := msgs * 32 + (msgs * ops_per_batch * (bytes + 16)); 
 secs := (en - st) / 1000.0;
  result_names (round_trips, mbps);
  result((msgs / 2) / secs, (bs / (1024.0 * 1024)) / secs);
}
