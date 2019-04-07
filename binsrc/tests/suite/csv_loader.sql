--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
--drop table csv_load_list;

create table csv_load_list (
    cl_file varchar,
    cl_file_in_zip varchar,
    cl_state int default 0,
    cl_error long varchar,
    cl_table varchar,
    cl_options any,
    cl_started datetime,
    cl_done datetime,
    primary key (cl_file, cl_file_in_zip))
create index cl_state on csv_load_list (cl_state)
;

create procedure csv_cols_cb (inout r any, in inx int, inout cbd any)
{
  if (cbd is null)
    cbd := vector ();
  cbd := vector_concat (cbd, vector (r));
}
;

create procedure  csv_get_cols_array (inout ss any, in hr int, in offs int, in opts any)
{
  declare h, res any;
  declare inx, j, ncols, no_head int;

  h := null;
  no_head := 0;
  if (hr < 0)
    {
      no_head := 1;
      hr := 0;
    }
  if (offs < 0)
    offs := 0;
  res := vector ();
  csv_parse (ss, 'DB.DBA.csv_cols_cb', h, 0, offs + 10, opts);
  if (h is not null and length (h) > offs)
    {
      declare _row any;
      _row := h[hr];
      for (j := 0; j < length (_row); j := j + 1)
        {
	  res := vector_concat (res, vector (vector (SYS_ALFANUM_NAME (cast (_row[j] as varchar)), null)));
        }
      for (inx := offs; inx < length (h); inx := inx + 1)
       {
	 _row := h[inx];
         for (j := 0; j < length (_row); j := j + 1)
	   {
	     if (res[j][1] is null and not (isstring (_row[j]) and _row[j] = '') and _row[j] is not null)
               res[j][1] := __tag (_row[j]);
             else if (__tag (_row[j]) <> res[j][1] and 189 = res[j][1] and (isdouble (_row[j]) or isfloat (_row[j])))
	       res[j][1] := __tag (_row[j]);
             else if (__tag (_row[j]) <> res[j][1] and isinteger (_row[j]) and (res[j][1] = 219 or 190 = res[j][1]))
	       ;
             else if (__tag (_row[j]) <> res[j][1])
               res[j][1] := -1;
	   }
       }
    }
  for (inx := 0; inx < length (res); inx := inx + 1)
    {
       if (not isstring (res[inx][0]) and not isnull (res[inx][0]))
         no_head := 1;
       else if (trim (res[inx][0]) = '' or isnull (res[inx][0]))
         res[inx][0] := sprintf ('COL%d', inx);
    }
  for (inx := 0; inx < length (res); inx := inx + 1)
    {
       if (res[inx][1] = -1 or res[inx][1] is null)
         res[inx][1] := 'VARCHAR';
       else
         res[inx][1] := dv_type_title (res[inx][1]);
    }
  if (no_head)
    {
      for (inx := 0; inx < length (res); inx := inx + 1)
	{
	   res[inx][0] := sprintf ('COL%d', inx);
	}
    }
  return res;
}
;

create procedure csv_get_table_def (in fn varchar, in f varchar, in opts any)
{
  declare arr any;
  declare s, r, ss any;
  declare i, offs, st int;

  if (__tag (f) = 185)
    s := f;
  else if (f like '%.gz')
    s := gz_file_open (f);
  else
    s := file_open (f);
  st := 0; offs := 1;
  if (isvector (opts) and mod (length (opts), 2) = 0)
    {
      st := atoi (get_keyword ('header', opts, '0'));
      offs := atoi (get_keyword ('offset', opts, '1'));
    }
  arr := csv_get_cols_array (s, st, offs, opts);
  ss := string_output ();
  http (sprintf ('CREATE TABLE %s ( \n', fn), ss);
  for (i := 0; i < length (arr); i := i + 1)
    {
       http (sprintf ('\t"%I" %s', arr[i][0], arr[i][1]), ss);
       if (i < length (arr) - 1)
         http (', \n', ss);
    }
  http (')', ss);
  return string_output_string (ss);
}
;

create procedure csv_register (in path varchar, in mask varchar)
{
  declare ls any;
  declare inx int;
  ls := sys_dirlist (path, 1);
  for (inx := 0; inx < length (ls); inx := inx + 1)
    {
      if (ls[inx] like mask)
	{
	  if (not (exists (select 1 from DB.DBA.CSV_LOAD_LIST where CL_FILE = path || '/' || ls[inx] for update)))
	    {
	      declare tbfile, ofile, tb, f, tbname, mod varchar;
	      declare opts any;
	      tb := null;
	      f := ls[inx];
	      tbfile := path || '/' || regexp_replace (f, '(\\.csv(\\.gz)?)|(\\.zip)', '') || '.tb';
	      ofile :=  path || '/' || regexp_replace (f, '(\\.csv(\\.gz)?)|(\\.zip)', '') || '.cfg';

	      opts := null;
	      if (file_stat (ofile) <> 0)
		{
		  declare delim, quot, header, offs, enc varchar;
		  delim  := cfg_item_value (ofile, 'csv', 'csv-delimiter');
		  quot   := cfg_item_value (ofile, 'csv', 'csv-quote');
		  enc    := cfg_item_value (ofile, 'csv', 'encoding');
		  header := cfg_item_value (ofile, 'csv', 'header');
		  offs   := cfg_item_value (ofile, 'csv', 'offset');
		  mod   := cfg_item_value (ofile, 'csv', 'mode');

		  if (delim  is not null)
		    {
		      delim := replace (delim, 'tab', '\t');
		      delim := replace (delim, 'space', ' ');
		      opts := vector_concat (opts, vector ('csv-delimiter', delim));
		    }
		  if (quot   is not null) opts := vector_concat (opts, vector ('csv-quote', quot));
		  if (enc    is not null) opts := vector_concat (opts, vector ('encoding', enc));
		  if (header is not null) opts := vector_concat (opts, vector ('header', header));
		  if (offs   is not null) opts := vector_concat (opts, vector ('offset', offs));
		  if (mod    is not null) opts := vector_concat (opts, vector ('mode', atoi (mod)));
		}
	      opts := vector_concat (opts, vector ('log', 1));

	      if (file_stat (tbfile) <> 0)
		tbname := trim (file_to_string (tbfile), ' \r\n');
	      else
		tbname := complete_table_name ('CSV.DBA.'||SYS_ALFANUM_NAME (f), 1);

              if (exists (select 1 from SYS_KEYS where KEY_TABLE = tbname))
		{
		  tb := tbname;
		}
	      else
		{
		  if (f like '%.csv' or f like '%.csv.gz')
		    {
		      declare stat, msg any;
		      stat := '00000';
		      declare continue handler for sqlstate '*' {
	                log_message (sprintf ('Can not guess table name for file %s', f));
		      };
		      {
		        exec (csv_get_table_def (tbname, path||'/'||f, opts), stat, msg);
			if (stat = '00000')
		          tb := tbname;
			else
		          log_message (sprintf ('Can not guess table name for file %s', f));
	              }
		    }
		  else if (f like '%.zip')
		    {
		      declare ff, ss any;
		      ff := unzip_list (path || '/' || f);
		      foreach (any zf in ff) do
			{
			  if (zf[1] > 0 and zf[0] like '%.csv')
			    {
			      ss := unzip_file (path || '/' || f, zf[0]);
			      tbname := complete_table_name ('CSV.DBA.'||SYS_ALFANUM_NAME (zf[0]), 1);
			      declare stat, msg any;
			      tb := null;
			      stat := '00000';
			      declare continue handler for sqlstate '*' {
				log_message (sprintf ('Can not guess table name for zipped file %s', zf[0]));
			      };
			      {
				exec (csv_get_table_def (tbname, ss, opts), stat, msg);
				if (stat = '00000')
				  tb := tbname;
				else
				  log_message (sprintf ('Can not guess table name for zipped file %s', zf[0]));
				if (tb is not null)
				  insert into DB.DBA.CSV_LOAD_LIST (cl_file, cl_file_in_zip, cl_table, cl_options)
				      values (path || '/' || f, zf[0], tb, opts);
			      }
			    }
			}
		      tb := null;
		    }
		  else
		    log_message (sprintf ('Can not guess table name for file %s', f));
		}
              if (tb is not null)
                {
		  insert into DB.DBA.CSV_LOAD_LIST (cl_file, cl_file_in_zip, cl_table, cl_options)
		      values (path || '/' || f, '', tb, opts);
		}
	    }
	  commit work;
	}
    }
}
;

create procedure
csv_register_all (in path varchar, in mask varchar)
{
  declare ls any;
  declare inx int;
  ls := sys_dirlist (path, 0);
  csv_register (path, mask);
  for (inx := 0; inx < length (ls); inx := inx + 1)
    {
      if (ls[inx] <> '.' and ls[inx] <> '..')
	{
	  csv_register_all (path||'/'||ls[inx], mask);
	}
    }
}
;

create procedure
csv_ld_file (in f varchar, in zf varchar, in tb varchar, in ld_mode int, in opts any)
{
  declare ss, ret any;
  declare offs, st int;
  st := 0; offs := 1;
  declare exit handler for sqlstate '*' {
    rollback work;
    update DB.DBA.CSV_LOAD_LIST set CL_STATE = 2, CL_DONE = now (), CL_ERROR = __SQL_STATE || ' ' || __SQL_MESSAGE
		where CL_FILE = f and CL_FILE_IN_ZIP = zf;
    commit work;
    log_message (sprintf (' File %s error %s %s', f, __SQL_STATE, __SQL_MESSAGE));
    return;
  };
  if (isvector (opts) and mod (length (opts), 2) = 0)
    {
      st := atoi (get_keyword ('header', opts, '0'));
      offs := atoi (get_keyword ('offset', opts, '1'));
    }
  if (f like '%.zip' and length (zf) = 0)
    {
      declare ff any;
      ff := unzip_list (f);
      foreach (any zzf in ff) do
	{
	  if (zzf[1] > 0 and zzf[0] like '%.csv')
	    {
	      ss := unzip_file (f, zzf[0]);
	      ret := csv_load (ss, offs, null, tb, ld_mode, opts);
	    }
	}
    }
  else if (f like '%.zip' and length (zf) > 0)
    {
      ss := unzip_file (f, zf);
      ret := csv_load (ss, offs, null, tb, ld_mode, opts);
    }
  else if (f like '%.gz')
    {
      ss := gz_file_open (f);
      ret := csv_load (ss, offs, null, tb, ld_mode, opts);
    }
  else
    ret := csv_load_file (f, offs, null, tb, ld_mode, opts);

  if (length (ret) = 2 and length (ret[1]))
    update DB.DBA.CSV_LOAD_LIST set CL_ERROR = ret[1] where CL_FILE = f and CL_FILE_IN_ZIP = zf;
}
;

create procedure csv_ld_array ()
{
  declare first, last, zfirst, zlast, arr, len, local, opt, zf any;
  declare cr cursor for
      select top 100 CL_FILE, CL_TABLE, CL_OPTIONS, CL_FILE_IN_ZIP from DB.DBA.CSV_LOAD_LIST table option (index cl_state) where CL_STATE = 0
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
  len := 0;
  for (;;)
    {
      fetch cr into f, g, opt, zf;
      if (0 = first) { first := f; zfirst := zf; }
      last := f; zlast := zf;
      arr[fill] := vector (f, g, opt, zf);
      len := len + cast (file_stat (f, 1) as int);
      fill := fill + 1;
      if (len > 2000000)
	goto done;
    }
 done:
  if (0 = first)
    return 0;
  update CSV_LOAD_LIST set cl_state = 1, cl_started = now () where cl_file >= first and cl_file <= last and CL_FILE_IN_ZIP >= zfirst and CL_FILE_IN_ZIP <= zlast;
  return arr;
}
;


create procedure csv_loader_run (in max_files integer := null, in log_enable int := 2)
{
  declare sec_delay float;
  declare _f, _graph varchar;
  declare arr any;
  declare xx, inx, tx_mode, ld_mode int;
  ld_mode := log_enable;
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

      if (exists (select 1 from DB.DBA.CSV_LOAD_LIST where CL_FILE = '##stop'))
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
      arr := csv_ld_array ();
      commit work;
      if (0 = arr)
	goto looks_empty;
      log_enable (ld_mode, 1);

      for (inx := 0; inx < 100; inx := inx + 1)
	{
	  if (0 = arr[inx])
	    goto arr_done;
	  csv_ld_file (arr[inx][0], arr[inx][3], arr[inx][1], ld_mode, arr[inx][2]);
	  update DB.DBA.CSV_LOAD_LIST set CL_STATE = 2, CL_DONE = curdatetime () where CL_FILE = arr[inx][0] and CL_FILE_IN_ZIP = arr[inx][3];
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

