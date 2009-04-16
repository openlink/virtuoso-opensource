

create table load_list (
  ll_file varchar,
  ll_graph varchar,
  ll_state int default 0, -- 0 not started, 1 going, 2 done
  ll_started datetime,
  ll_done datetime,
  ll_host int,
  ll_work_time integer,
  ll_error varchar,
  primary key (ll_file))
alter index load_list on load_list partition (ll_file varchar)
;

create index ll_state on load_list (ll_state, ll_file, ll_graph) partition (ll_state int)
;


create table ldlock (id int primary key)
  alter index ldlock on ldlock partition (id int)
;

insert into ldlock values (0);


create procedure
ld_dir (in path varchar, in mask varchar, in graph varchar)
{
  declare ls any;
  declare inx int;
  ls := sys_dirlist (path, 1);
  for (inx := 0; inx < length (ls); inx := inx + 1)
    {
      if (ls[inx] like mask)
	{
	  set isolation = 'serializable';

	  if (not (exists (select 1 from DB.DBA.LOAD_LIST where LL_FILE = path || '/' || ls[inx] for update)))
	    {
	      insert into DB.DBA.LOAD_LIST (ll_file, ll_graph)
                     values (path || '/' || ls[inx], graph);
	    }

	  commit work;
	}
    }
}
;

create procedure
ld_add (in _fname varchar, in _graph varchar)
{
  --log_message (sprintf ('ld_add: %s, %s', _fname, _graph));

  set isolation = 'serializable';

  if (not (exists (select 1 from DB.DBA.LOAD_LIST where LL_FILE = _fname for update)))
    {
      insert into DB.DBA.LOAD_LIST (LL_FILE, LL_GRAPH) values (_fname, _graph);
    }
  commit work;
}
;

create procedure
ld_file (in f varchar, in graph varchar)
{
  declare is_gzip, gzip_name int;
  is_gzip := 0;
  declare exit handler for sqlstate '*' {
  if (is_gzip)
    file_delete (f);
    rollback work;
    update DB.DBA.LOAD_LIST
      set LL_STATE = 2,
          LL_DONE = curdatetime (),
          LL_ERROR = __sql_state || ' ' || __sql_message
      where LL_FILE = f;
    commit work;

    log_message (sprintf (' File %s error %s %s', f, __sql_state, __sql_message));
    return;
  };

  if (f like '%.gz')
    {
      gzip_name := f;
      f := regexp_replace (gzip_name, '\.gz\x24', '');
      gz_uncompress_file (gzip_name, f);
      is_gzip := 1;
    }

  if (f like '%.xml' or f like '%.owl' or f like '%.rdf')
    DB.DBA.RDF_LOAD_RDFXML (file_open (f), graph, graph);
  else
    TTLP (file_open (f), graph, graph, 185);

  if (is_gzip)
    file_delete (f);
  --log_message (sprintf ('loaded %s', f));
}
;
;

create procedure
rdf_load_dir (in path varchar,
              in mask varchar := '%.nt',
              in graph varchar := 'http://dbpedia.org')
{

  delete from DB.DBA.LOAD_LIST where LL_FILE = '##stop';
  commit work;

  ld_dir (path, mask, graph);

  rdf_loader_run ();
}
;
;

create procedure ld_array ()
{
  declare first, last, arr any;
  declare cr cursor for
      select top 100 LL_FILE, LL_GRAPH
        from DB.DBA.LOAD_LIST table option (index ll_state)
        where LL_STATE = 0
	for update;
  declare fill int;
  declare f, g varchar;
  declare r any;
  whenever not found goto done;
  first := 0;
  last := 0;
 arr := make_array (100, 'any');
  fill := 0;
  open cr;
  for (;;)
    {
      fetch cr into f, g;
      if (0 = first) first := f;
      last := f;
      arr[fill] := vector (f, g);
      fill := fill + 1;
      if (f not like '%triples%')
	goto done;
    }
 done:
  if (0 = first)
    return 0;
  update load_list set ll_state = 1, ll_started = curdatetime (),             LL_HOST = sys_stat ('cl_this_host')
    where ll_file >= first and ll_file <= last;
  return arr;
}
;

create procedure
rdf_loader_run (in max_files integer := null, in log_enable int := 2)
{
  declare sec_delay float;
  declare _f, _graph varchar;
  declare arr any;
  declare xx, inx, tx_mode, ld_mode int;
  ld_mode := log_enable;
  if (log_enable = 2 and cl_this_host () = 1)
    cl_exec ('__dbf_set (''cl_non_log_write_mode'')');
  tx_mode := bit_and (1, log_enable);
  log_message ('Loader started');

  delete from DB.DBA.LOAD_LIST where LL_FILE = '##stop';
  commit work;

  while (1)
    {
      set isolation = 'repeatable';
      declare exit handler for sqlstate '40001' {
	rollback work;
        sec_delay := rnd(1000)*0.001;
	log_message(sprintf('deadlock in loader, waiting %d milliseconds', cast (sec_delay * 1000 as integer)));
	delay(sec_delay);
	goto again;
      };

     again:;

      if (exists (select 1 from DB.DBA.LOAD_LIST where LL_FILE = '##stop'))
	{
	  log_message ('File load stopped by rdf_load_stop.');
	  return;
	}

      log_enable (tx_mode, 1);

      if (max_files is not null and max_files <= 0)
        {
	  commit work;
	  log_message ('Max_files reached. Finishing.');
          return;
	}

      whenever not found goto looks_empty;

      --      log_message ('Getting next file.');
      set isolation = 'serializable';
      select id into xx from ldlock where id = 0 for update;
      arr := ld_array ();
      commit work;
      if (0 = arr)
	goto looks_empty;
      log_enable (ld_mode, 1);

      for (inx := 0; inx < 100; inx := inx + 1)
	{
	  if (0 = arr[inx])
	    goto arr_done;
	  ld_file (arr[inx][0], arr[inx][1]);
	  update DB.DBA.LOAD_LIST set LL_STATE = 2, LL_DONE = curdatetime () where LL_FILE = arr[inx][0];
	}
    arr_done:
      log_enable (tx_mode, 1);


      if (max_files is not null) max_files := max_files - 100;

      commit work;
    }

 looks_empty:
  commit work;
  log_message ('No more files to load. Loader has finished,');
  return;

}
;

create procedure rdf_load_stop (in force int := 0)
{
  insert into DB.DBA.LOAD_LIST (LL_FILE) values ('##stop');
  commit work;
  if (force)
    cl_exec ('txn_killall (1)');
}
;


create procedure RDF_LOADER_RUN_1 (in x int, in y int)
{
  rdf_loader_run (x, y);
}
;

create procedure rdf_ld_srv (in log_enable int)
{
  declare aq any;
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.RDF_LOADER_RUN_1', vector (null, log_enable));
  aq_wait_all (aq);
}
;

-- cl_exec ('set lock_escalation_pct = 110');
-- cl_exec ('DB.DBA.RDF_LD_SRV (1)');


