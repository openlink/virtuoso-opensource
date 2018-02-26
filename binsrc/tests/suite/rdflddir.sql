--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
alter index load_list on load_list partition (ll_file varchar);

create index ll_state on load_list (ll_state, ll_file, ll_graph) partition (ll_state int);

set DEADLOCK_RETRIES = 400;

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
	  if (not (exists (select 1 from load_list where ll_file = ls[inx] for update)))
	    {
	      insert into load_list (ll_file, ll_graph) values (ls[inx], graph);
	    }
	  commit work;
	}
    }
}

create procedure
ld_add (in _fname varchar, in _graph varchar)
{
  --log_message (sprintf ('ld_add: %s, %s', _fname, _graph));

  set isolation = 'serializable';
  if (not (exists (select 1 from load_list where ll_file = _fname for update)))
    {
      insert into load_list (ll_file, ll_graph) values (_fname, _graph);
    }
  commit work;
}

create procedure
ld_file (in path varchar, in f varchar, in graph varchar, in del_after int)
{
  declare exit handler for sqlstate '*' {
    rollback work;
    update load_list
      set ll_state = 2,
          ll_done = curdatetime (),
          ll_error = __SQL_STATE || ' ' || __SQL_MESSAGE
      where ll_file = f;
    commit work;
    log_message (sprintf (' File %s error %s %s', f, __SQL_STATE, __SQL_MESSAGE));
    return;
  };
  ttlp (file_to_string_output (path || '/' || f), '', graph);
  --log_message (sprintf ('Loaded %s', f));
  if (del_after)
    file_delete (path || '/' || f);
}


create procedure rdf_load_stop ()
{
  insert into load_list (ll_file) values ('##stop');
  commit work;
  cl_exec ('txn_killall (1)');
}



create procedure
rdf_load_dir (in path varchar,
	      in thread integer,
	      in max_thread integer,
              in mask varchar := '%.nt',
              in graph varchar := 'http://dbpedia.org',
              in del_after int := 1)
{
  declare f, _graph, _ll_file varchar;
  declare my_list, br, t_begin any;

  set isolation = 'repeatable';

  prepare_my_list (my_list, thread, max_thread);

  br := 0;

  declare exit handler for sqlstate '40001' {
    rollback work;


  for (declare x any, x := 0; x < length (my_list) ; x := x + 1)
    {
--	dbg_obj_print (my_list [x]);
again:;
	_ll_file := my_list[x];
--	if (exists (select 1 from load_list where ll_state = 0 and _ll_file = ll_file))
	if (not isinteger (_ll_file))
	  {
             log_enable (0, 1);

             select top 1 ll_graph into _graph from load_list where ll_state = 0 and ll_file = _ll_file;
--	     update load_list set ll_state = 1, ll_started = curdatetime () where ll_file = _ll_file and ll_state = 0;
             commit work;

             --log_message (sprintf ('Start ld of %s', _ll_file));
             log_enable (2, 1);
	     t_begin := msec_time();
             ld_file (path, _ll_file, _graph, del_after);
             log_enable (0, 1);

             update load_list set ll_state = 2, ll_work_time = msec_time() - t_begin,
			ll_done = curdatetime () where ll_file = _ll_file;
             commit work;
	     br := br + 1;
	  }
    }

  dbg_obj_print ('Finish thread ', thread, ' count = ', br);


      if (not (exists (select 1 from load_list where ll_state = 0 for update)))
        {
          commit work;
          log_message (sprintf ('Dir %s has no unprocessed files matching %s.  Load exits.', path, mask));
          return;
        }

return;

dead:
rollback work;
dbg_obj_print ('dead in ', thread);
goto again;
}
;

create procedure
prepare_my_list (inout my_list any, in thread integer, in max_thread integer)
{
   declare all_files, my_files, br, cur any;

   set isolation = 'repeatable';

   select count (*) into all_files from load_list where ll_state = 0;

   my_files := all_files / max_thread + 1;

   my_list := make_array (my_files, 'any');

   br := 1; cur := 0;

--   dbg_obj_print ('all_files ', all_files);
--   dbg_obj_print ('my_files ', my_files);

--   for (declare x any, x := thread; x <= all_files ; x := x + max_thread)
--     {
--	aset (my_list, x/max_thread, x);
--     }

   for (select ll_file from load_list where ll_state = 0) do
     {
	if (mod ((br + thread), max_thread) = 0)
	  {
	     aset (my_list, cur, ll_file);
	     cur := cur + 1;
	  }
	br := br + 1;
     }

--   dbg_obj_print ('my_list ', my_list);
}
;

create procedure gogo (in coff any)
{
  declare aq, n, res any;

  for (n:= 1; n <= coff; n:=n+1)
    {
       aq := async_queue (n);
       res := aq_request (aq, 'DB.DBA.RDF_LOAD_DIR', vector ('/home/virtuoso/b3s/geonames/data', n, coff, '%.nt', '', 0));
    }

  dbg_obj_print ('Finish gogo.');
}
;

