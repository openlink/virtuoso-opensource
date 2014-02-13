--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

create table DB.DBA.LOAD_LIST (
  ll_file varchar,
  ll_graph varchar,
  ll_state int default 0, -- 0 not started, 1 going, 2 done
  ll_started datetime,
  ll_done datetime,
  ll_host int,
  ll_work_time integer,
  ll_error varchar,
  primary key (ll_file))
alter index LOAD_LIST on DB.DBA.LOAD_LIST partition (ll_file varchar)
create index LL_STATE on DB.DBA.LOAD_LIST (ll_state, ll_file, ll_graph) partition (ll_state int)
;


create table LDLOCK (id int primary key)
alter index LDLOCK on LDLOCK partition (id int)
;

insert soft DB.DBA.LDLOCK values (0)
;


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
	      declare gfile, cgfile, ngraph varchar;
	      gfile := path || '/' || replace (ls[inx], '.gz', '') || '.graph';
	      cgfile := path || '/' || regexp_replace (replace (ls[inx], '.gz', ''), '\\-[0-9]+\\.n', '.n') || '.graph';
	      if (file_stat (gfile) <> 0)
		ngraph := trim (file_to_string (gfile), ' \r\n');
              else if (file_stat (cgfile) <> 0)
		ngraph := trim (file_to_string (cgfile), ' \r\n');
	      else if (file_stat (path || '/' || 'global.graph') <> 0)
		ngraph := trim (file_to_string (path || '/' || 'global.graph'), ' \r\n');
	      else
	        ngraph := graph;
              if (ngraph is not null)
                {
		  insert into DB.DBA.LOAD_LIST (ll_file, ll_graph) values (path || '/' || ls[inx], ngraph);
		}
	    }

	  commit work;
	}
    }
}
;


create procedure
rdf_read_dir (in path varchar, in mask varchar, in graph varchar)
{
  ld_dir (path, mask, graph);
}
;


create procedure
ld_dir_all (in path varchar, in mask varchar, in graph varchar)
{
  declare ls, ngraph any;
  declare inx int;
  ls := sys_dirlist (path, 0);
  if (file_stat (path || '/' || 'global.graph') <> 0)
    {
      ngraph := trim (file_to_string (path || '/' || 'global.graph'), ' \r\n');
      if (length (ngraph))
	graph := ngraph;
    }
  ld_dir (path, mask, graph);
  for (inx := 0; inx < length (ls); inx := inx + 1)
    {
      if (ls[inx] <> '.' and ls[inx] <> '..')
	{
	  ld_dir_all (path||'/'||ls[inx], mask, graph);
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

create procedure ld_ttlp_flags (in fname varchar, in opt varchar)
{
  if (fname like '%/btc-20%' or fname like '%.nq%' or fname like '%.n4')
{
      if (lower (opt) = 'with_delete')
	return 255 + 512 + 2048;
    return 255 + 512;
    }
   if (fname like '%.trig' or fname like '%.trig.gz')
     return 255 + 256;
  return 255;
}
;

create procedure ld_is_rdfxml (in f any)
{
  if (f like '%.xml' or f like '%.owl' or f like '%.rdf' or f like '%.rdfs')
    return 1;
  return 0;
}
;

create procedure
ld_file (in f varchar, in graph varchar)
{
  declare gzip_name varchar;
  declare exit handler for sqlstate '*' {
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

  connection_set ('ld_file', f);
  if (graph like 'sql:%')
    {
      exec (subseq (graph, 4), null, null, vector (f), vector ('max_rows', 0, 'use_cache', 1));
      return;
    }

  if (f like '%.grdf' or f like '%.grdf.gz')
    {
      load_grdf (f);
    }
  else if (f like '%.gz')
    {
      gzip_name := regexp_replace (f, '\.gz\x24', '');
      if (ld_is_rdfxml (gzip_name))
	DB.DBA.RDF_LOAD_RDFXML (gz_file_open (f), graph, graph);
      else
	TTLP (gz_file_open (f), graph, graph, ld_ttlp_flags (gzip_name, graph));
    }
  else
    {
      if (ld_is_rdfxml (f))
	DB.DBA.RDF_LOAD_RDFXML (file_open (f), graph, graph);
      else
	TTLP (file_open (f), graph, graph, ld_ttlp_flags (f, graph));
    }

  --log_message (sprintf ('loaded %s', f));
}
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


create procedure ld_array ()
{
  declare arr, fs, len, local any;
  declare cr cursor for
      select LL_FILE, LL_GRAPH
        from DB.DBA.LOAD_LIST table option (index ll_state)
        where LL_STATE = 0
	for update;
  declare fill int;
  declare f, g varchar;
  declare r any;
  whenever not found goto done;
 arr := make_array (100, 'any');
  fs  := make_array (100, 'any');
  fill := 0;
  len := 0;
  open cr;
  for (;;)
    {
      fetch cr into f, g;
      if (file_stat (f, 1) = 0)
	goto next;
      arr[fill] := vector (f, g);
      fs[fill] := f;
    len := len + cast (file_stat (f, 1) as int);
      fill := fill + 1;
      if (len > 2000000 or fill >= 100)
	goto done;
      next:;
    }
 done:
  if (0 = fill)
    return 0;
  if (1 <> sys_stat ('cl_run_local_only'))
    local := sys_stat ('cl_this_host');
  update load_list set ll_state = 1, ll_started = curdatetime (), LL_HOST = local where ll_file in (fs);
  close cr;
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
  if (0 = sys_stat ('cl_run_local_only'))
    {
      if (log_enable = 2 and cl_this_host () = 1)
	{
	  cl_exec ('checkpoint_interval (0)');
	  cl_exec ('__dbf_set (''cl_non_logged_write_mode'', 1)');
	}
      if (cl_this_host () = 1)
	cl_exec('__dbf_set(''cl_max_keep_alives_missed'',3000)');
    }
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
      set isolation = 'committed';

      for (inx := 0; inx < 100; inx := inx + 1)
	{
	  if (0 = arr[inx])
	    goto arr_done;
	  ld_file (arr[inx][0], arr[inx][1]);
	  update DB.DBA.LOAD_LIST set LL_STATE = 2, LL_DONE = curdatetime () where LL_FILE = arr[inx][0];
          if (max_files is not null) max_files := max_files - 1;
	}
    arr_done:
      log_enable (tx_mode, 1);

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

create procedure rdf_ld_srv (in log_enable int := 2)
{
  declare aq any;
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.RDF_LOADER_RUN_1', vector (null, log_enable));
  aq_wait_all (aq);
}
;


create procedure load_grdf (in f varchar)
{
  declare line any;
  declare inx int;
  declare ses any;
  declare gr varchar;

  if (f like '%.gz')
    ses := gz_file_open (f);
  else
    ses := file_open (f);
  inx := 0;
  line := '';
  while (line <> 0)
    {
      gr := ses_read_line (ses, 0, 0, 1);
      if (gr = 0) return;
      line := ses_read_line (ses, 0, 0, 1);
      if (line = 0) return;
      DB.DBA.RDF_LOAD_RDFXML (line, gr, gr);
      inx := inx + 1;
    }
}
;

