--
--  $Id$
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

-- Set the checkpoint interval to 100 hours -- enough to complete most of experiments.
checkpoint_interval (6000);

-- Uncomment to get records of load levels (for maintainers only).
-- load ldmeter.sql;

-- This table is used solely to collect statistics about loading progress, esp. to understand scalability issues.
create table LUBM_LOAD_LOG (
  THREAD integer not null,	-- Thread ID, -1 if threads are automatically dispatched by async queue.
  TIDX integer not null,	-- Task index, e.g. a serial number of file in sequence of created tasks.
  START datetime not null,	-- Time when the loading is started.
  FINISH datetime not null,	-- Time when the loading is finished.
  FILE varchar not null,	-- Source file name.
  STATE varchar not null,	-- Final error state.
  MSG varchar not null );	-- Final error message.

-- One loading -- one set of statistics.
delete from LUBM_LOAD_LOG;

-- There are two methods of loading, for different experiments:
--
-- LUBM_LOAD_MT_1() uses a multithreaded parser in order to load its set of files one after the other.
--   N multithreaded parsers, M loading threads each, can efficiently load about (2 + (N * (1+M))) CPU cores.
--
-- LUMB_LOAD_LOG2() creates an asynchronous queue of single-thread parsers.
--   N single-thread parsers can load about (2 + N) CPU cores.
--
-- Use LUMB_LOAD_LOG2() if you don't want to experiment and simply want to load data.
--
-- Function calls given below are OK for case of 8 CPU cores (say, 2 quad-core Xeons),
-- source files reside in subdirectories 'data-0', 'data-1' and 'data-2' of working directory
-- that reside on different hadr disks (so they're actually symlinks).
-- You may change number of threads and/or directories as appropriate for your number of CPU cores and HDDs.

-- First method: multithreaded parser.

create procedure LUBM_LOAD_MT_1 (in thread_no integer, in path varchar,
  in fctr_first integer := 0, in fctr_step integer := 1,
  in parsing_threads integer := 1 )
{
  declare dirlist any; -- list of files on source directory
  declare ctr, len integer; -- file counter and count
  dirlist := sys_dirlist (path, 1);
  len := length (dirlist);
  for (ctr := fctr_first; ctr < len; ctr := ctr + fctr_step)
    {
      declare sta datetime;
      rollback work;
      sta := now ();
      -- In case of error log it and continue with next file:
      declare continue handler for sqlstate '*' {
        rollback work;
        insert into LUBM_LOAD_LOG (THREAD, TIDX, START, FINISH, FILE, STATE, MSG)
        values (thread_no, ctr, sta, now(), dirlist[ctr], __SQL_STATE, __SQL_MESSAGE);
        commit work;
        };
      -- Start the multithreaded parser
      DB.DBA.RDF_LOAD_RDFXML_MT (file_to_string_output (path || '/' || dirlist[ctr]),
        'lubm', 'lubm', 0, parsing_threads );
      commit work;
      -- Log status
      insert into LUBM_LOAD_LOG (THREAD, TIDX, START, FINISH, FILE, STATE, MSG)
      values (thread_no, ctr, sta, now(), dirlist[ctr], '00000', '');
      commit work;
    }
}
;

-- That's how to launch a group of multithreaded parsers in parallel:

--checkpoint;
---- Note that procedures are started background, '&' instead of ';', except the last.
----                    thread IDs to distinguish threads in statistical analysis
----                   /        path to directory with files to load
----                  /        /   load only odd- or only even- numbered files
----                 /        /   /  fctr_step to stripe on odd/even
----                /        /   /  /  number of data loading threads
----               /        /   /  /  /
--LUBM_LOAD_MT_1 (0, 'data-0', 0, 2, 1) &
--LUBM_LOAD_MT_1 (1, 'data-1', 0, 2, 1) &
--LUBM_LOAD_MT_1 (2, 'data-2', 0, 2, 1) &
--LUBM_LOAD_MT_1 (3, 'data-0', 1, 2, 1) &
--LUBM_LOAD_MT_1 (4, 'data-1', 1, 2, 1) &
--LUBM_LOAD_MT_1 (5, 'data-2', 1, 2, 1) ; -- last procedure is started foreground
--WAIT_FOR_CHILDREN;
--checkpoint;
--checkpoint_interval (60);



-- Second method: queue of single-thread parsers

-- This procedure simply loads one file by one thread.
-- The procedure could be as short and simple as single call of DB.DBA.RDF_LOAD_RDFXML()
-- but we cheat with logging and free-text indexing to get identical behaviour of servers of different versions.
create procedure DB.DBA.RDF_LOAD_LUBM_RDFXML (in filename varchar, in ctr integer)
{
  declare sta datetime; -- start time
  declare ro_id_dict, app_env any;
  -- If data should be free-text indexed then we create a dictionary for 'graph keywords'
  if (__rdf_obj_ft_rule_count_in_graph (iri_to_id ('lubm')))
    ro_id_dict := dict_new (5000);
  else
    ro_id_dict := null;
  -- We create environment for callbacks:
  app_env := vector (null, ro_id_dict);
  rollback work;
  sta := now ();
  -- Prepare error handler to keep records of loading errrors:
  declare exit handler for sqlstate '*' {
    rollback work;
    log_enable (1, 1);
    insert into LUBM_LOAD_LOG (THREAD, TIDX, START, FINISH, FILE, STATE, MSG)
    values (-1, ctr, sta, now(), filename, __SQL_STATE, __SQL_MESSAGE);
    dbg_obj_princ (now(), ctr, filename, __SQL_STATE, __SQL_MESSAGE);
    commit work;
    return;
    };
  -- Enable auto-commit without transaction log
  log_enable (2, 1);
  -- Finally, we start the parser with callbacks that will place queds to database:
  DB.DBA.RDF_LOAD_RDFXML (file_to_string (filename), 'lubm', 'lubm');
  --rdf_load_rdfxml (file_to_string (filename), 0,
  --  'lubm',
  --   vector (
  --    'DB.DBA.TTLP_EV_NEW_GRAPH',
  --    'DB.DBA.TTLP_EV_NEW_BLANK',
  --    '!iri_to_id',
  --    'DB.DBA.TTLP_EV_TRIPLE',
  --    'DB.DBA.TTLP_EV_TRIPLE_L',
  --    '' ),
  --  app_env,
  --  'lubm' );
  -- Revert transactional behavior to "normal" and record statistics/state.
  log_enable (1, 1);
  insert into LUBM_LOAD_LOG (THREAD, TIDX, START, FINISH, FILE, STATE, MSG)
  values (-1, ctr, sta, now(), filename, '00000', '');
  if (0 = mod (ctr, 1000))
    dbg_obj_princ (now (), ctr, filename);
}
;

-- This procedure forms an asynchronous queue of parsers.
create procedure LUBM_LOAD_LOG2 (
  in dirnames any, -- Vector of names of directories with source files
  in thread_count integer, -- Maximum allowed number of parsers running at same time
  in decimation_ratio integer := 1) -- 1 to load all, 10 to load every second or tenth file etc.
{
  declare aq, -- queue of tasks; one file -> one parser call -> one task
    dirlists, -- vercor of vectors of filenames in source directories
    fctrs, -- vector, one file counter per directory
    dirlist_lens any; -- vector, one file count per directory
  declare serialctr, dirty, dirctr, dircount integer;
  dirlists := dirnames;
  dirlist_lens := dirnames;
  fctrs := dirnames;
  dircount := length (dirnames);
  -- Load all filenames in all directories.
  for (dirctr := 0; dirctr < dircount; dirctr := dirctr + 1)
    {
      dirlists[dirctr] := sys_dirlist (dirnames[dirctr], 1);
      dirlist_lens[dirctr] := length (dirlists[dirctr]);
      fctrs[dirctr] := 0;
    }
  -- Create queue of tasks with required "width".
  aq := async_queue (thread_count);
  serialctr := 0;
  -- In a loop for all directories and all files, form a queue of parsing tasks:
  while (1)
    {
      dirty := 0;
      for (dirctr := 0; dirctr < dircount; dirctr := dirctr + 1)
        {
          if (fctrs[dirctr] < dirlist_lens[dirctr])
            {
              aq_request (aq, 'DB.DBA.RDF_LOAD_LUBM_RDFXML',
                vector (concat (dirnames[dirctr], '/', dirlists[dirctr][fctrs[dirctr]]), serialctr) );
              fctrs[dirctr] := fctrs[dirctr] + decimation_ratio;
              serialctr := serialctr + 1;
              dirty := 1;
            }
        }
      if (not dirty)
        goto done;
    }
done:
  -- When there's no more files to queue for parsing, stay here and wait for completion of last task.
  aq_wait_all (aq);
}
;

-- That's how to launch a queue of single-thread parsers:
checkpoint;
-- Uncomment to get records of load levels (for maintainers only).
--ld_meter_run (600) &
--LUBM_LOAD_LOG2 (vector ('data-0', 'data-1', 'data-2'), 6); -- Three directories and 6 parsers
--checkpoint;
--checkpoint_interval (60);
--shutdown;
