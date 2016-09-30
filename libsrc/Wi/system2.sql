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
--

create table DB.DBA.SYS_COL_INFO (coi_table varchar, coi_index varchar, coi_nth int, coi_type int,
  primary key (coi_table, coi_index, coi_nth, coi_type),
  coi_column varchar,
  coi_pages bigint,
  coi_ces bigint,
  coi_values bigint,
  coi_bytes bigint)
;



create procedure coi_fill (in stats any)
{
  declare inx, n int;
 n := length (stats);
  delete from sys_col_info;
  for (inx := 0; inx < n; inx := inx + 1)
    {
      declare stat any;
      declare tb, kn, cname varchar;
      declare icol, ice, k_id int;
    stat := stats[inx];
    k_id := stat[0];
    stat := stat[6];
      if (not isstring (stat))
	goto next_key;
      select key_table, key_name into tb, kn from sys_keys where key_id = k_id;
    icol := 0;
      for (;;)
	{
	cname := (select "COLUMN" from sys_key_parts, sys_cols where kp_key_id = k_id and kp_nth = icol and col_id = kp_col);
	  if (cname is null)
	    goto next_key;
	  insert into sys_col_info (coi_table, coi_index, coi_nth, coi_type, coi_column,
				coi_pages, coi_ces, coi_values, coi_bytes)
	    values (tb, kn, icol, -1, cname,
		    __col_info (stat, icol, 'n_pages', 0), 0, __col_info (stat, icol, 'n_values', 0), __col_info (stat, icol, 'n_bytes', 0));
	  for (ice := 0; ice < 16; ice := ice + 1)
	    {
	      if (__col_info (stat, icol, 'ce_ces', ice))
		{
		  insert into sys_col_info (coi_table, coi_index, coi_nth, coi_type, coi_column,
					coi_pages, coi_ces, coi_values, coi_bytes)
		    values (tb, kn, icol, ice, cname,
			    0, __col_info (stat, icol, 'ce_ces', ice), __col_info (stat, icol, 'ce_values', ice), __col_info (stat, icol, 'ce_bytes', ice));

		}
	    }
	icol := icol + 1;
	}
    next_key: ;
    }
}
;

create procedure DB.DBA.SYS_INDEX_SPACE_STATS_PROC ()
{
  declare ISS_KEY_ID, ISS_NROWS, ISS_ROW_BYTES, ISS_BLOB_PAGES, ISS_ROW_PAGES integer;

  result_names (ISS_KEY_ID, ISS_NROWS, ISS_ROW_BYTES, ISS_BLOB_PAGES, ISS_ROW_PAGES);

  declare _res any;
  _res := sys_index_space_usage ();

  if (isarray (_res))
    {
      declare _inx, _len integer;
      coi_fill (_res);
      _inx := 0;
      _len := length (_res);

      while (_inx < _len)
	{
	  declare _row any;
	  _row := _res[_inx];

	  result (_row[0], _row[1], _row[2], _row[3], _row[4]);
	  _inx := _inx + 1;
	}
    }
}
;

create view DB.DBA.SYS_INDEX_SPACE_STATS as
  select
    KEY_TABLE as ISS_KEY_TABLE,
    KEY_NAME as ISS_KEY_NAME,
    ISS_KEY_ID,
    ISS_NROWS,
    ISS_ROW_BYTES,
    ISS_BLOB_PAGES,
    ISS_ROW_PAGES,
    ISS_ROW_PAGES + ISS_BLOB_PAGES as ISS_PAGES
  from
    DB.DBA.SYS_INDEX_SPACE_STATS_PROC () (
    ISS_KEY_ID integer,
    ISS_NROWS bigint,
    ISS_ROW_BYTES bigint,
    ISS_BLOB_PAGES bigint,
    ISS_ROW_PAGES bigint) _tmp,
    DB.DBA.SYS_KEYS table option (order)
  where
    ISS_KEY_ID = KEY_ID
;


create procedure SYS_EXTENT_MAP_STAT ()
{
  declare EM_KEY varchar(50);
  declare EM_N_PAGES, EM_N_FREE_PAGES, EM_N_REMAP_PAGES, EM_N_FREE_REMAP_PAGES, EM_REMAP_ON_HOLD, EM_N_BLOB_PAGES, EM_N_FREE_BLOB_PAGES, EM_C_FREE, EM_C_FREE_BLOB, EM_C_FREE_REMAP integer;
  declare arr any;
  result_names (EM_KEY, EM_N_PAGES, EM_N_FREE_PAGES, EM_N_REMAP_PAGES, EM_N_FREE_REMAP_PAGES, EM_REMAP_ON_HOLD, EM_N_BLOB_PAGES, EM_N_FREE_BLOB_PAGES);
  arr := sys_em_stat ();
  foreach (any x in arr) do
    {
      result (x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7]);
    }
}
;

--!AWK PUBLIC
create procedure DB.DBA.__VD_GET_SQLSTATS_COUNT (in _ds_dsn varchar, in _remote_name varchar)
{
  declare exit handler for sqlstate '*' { return NULL; };
  declare stats any;
  stats := sql_statistics (_ds_dsn,
     name_part (_remote_name, 0, NULL),
     name_part (_remote_name, 1, NULL),
     name_part (_remote_name, 2, NULL),
     1, --SQL_INDEX_ALL
     0);  --SQL_QUICK

  if (isarray (stats))
    {
      declare inx, len integer;
      len := length (stats);
      inx := 0;
      while (inx < len)
	{
	  declare stat any;
	  declare stat_type, stat_cardinality integer;
	  stat := stats[inx];

	  stat_type := stat[6];
	  stat_cardinality := stat[10];
	  if (stat_type = 0 and stat_cardinality is not null)
	    return stat_cardinality;
	  inx := inx + 1;
	}
    }
  return NULL;
}
;

--!AWK PUBLIC
create procedure DB.DBA.VD_STATISTICS (in _dsn varchar := '%', in vd_table_mask varchar := '%')
{
  declare _ds_dsn, _ds_conn_str any;
  declare changed_tables any;
  declare cr cursor for
    SELECT DS_DSN, deserialize (DS_CONN_STR) from DB.DBA.SYS_DATA_SOURCE where DS_DSN like _dsn;

  whenever NOT FOUND goto done;

  changed_tables := vector ();

  open cr (exclusive, prefetch 1);
  while (1 = 1)
    {
      declare _pos integer;
      declare _rpc_time float;

      fetch cr into _ds_dsn, _ds_conn_str;

      _rpc_time := vdd_measure_rpc_time (_ds_dsn);

      _pos := position (-200, _ds_conn_str, 0, 2);
      if (_pos > 0)
	aset (_ds_conn_str, _pos, _rpc_time);
      else
	_ds_conn_str := vector_concat (_ds_conn_str, vector (-200, _rpc_time));

      update DB.DBA.SYS_DATA_SOURCE set DS_CONN_STR = serialize (_ds_conn_str)
        where current of cr;

      for select RT_REMOTE_NAME, RT_NAME from SYS_REMOTE_TABLE
        where RT_DSN = _ds_dsn and RT_NAME like vd_table_mask do
	{
	  declare exit handler for sqlstate '*' { ; };
	  declare stats_updated integer;
	  declare stat_cardinality integer;

	  stats_updated := 0;

	  stat_cardinality := DB.DBA.__VD_GET_SQLSTATS_COUNT (_ds_dsn, RT_REMOTE_NAME);
	  if (stat_cardinality is not null)
	    { -- SQL_TABLE_STAT
	      insert replacing SYS_COL_STAT
		(CS_TABLE, CS_COL, CS_N_DISTINCT, CS_MIN, CS_MAX,
		CS_AVG_LEN,
		CS_N_VALUES, CS_N_ROWS)
		select
		  "TABLE", "COLUMN", stat_cardinality, NULL, NULL,
		  (case when COL_PREC = 0 then 30
			when dv_type_title (COL_DTP) like 'LONG %' then 30 else COL_PREC end),
		  stat_cardinality, stat_cardinality
		  from
		    SYS_COLS, SYS_KEYS, SYS_KEY_PARTS
		  where
		    KEY_IS_MAIN = 1 and
		    KEY_MIGRATE_TO is NULL and
		    KEY_SUPER_ID = KEY_ID and
		    KP_KEY_ID = KEY_ID and
		    KP_COL = COL_ID and
		    KEY_TABLE = RT_NAME;

	      if (row_count () > 0)
		stats_updated := 1;
	    }
	  if (stats_updated)
	    changed_tables := vector_concat (changed_tables, vector (RT_NAME));
	}
    }
done:
  close cr;
  declare inx, len integer;
  inx := 0;
  len := length (changed_tables);
  while (inx < len)
    {
      __ddl_changed (changed_tables[inx]);
      inx := inx + 1;
    }
}
;


--!AWK PUBLIC
create procedure DB.DBA.TABLE_SET_POLICY (in _tb varchar, in _proc varchar, in _type varchar := 'IDUS')
{
  declare tb_name, proc_name varchar;
  declare is_view integer;

  tb_name := complete_table_name (_tb, 1);
  if (1 <> (select count(*) from DB.DBA.SYS_KEYS
      where
       KEY_TABLE = tb_name and
       KEY_IS_MAIN = 1 and
       KEY_MIGRATE_TO is null))
    signal ('22023', sprintf ('No table or duplicate table %s in TABLE_SET_POLICY', _tb), 'SR382');

  if (name_part (tb_name, 1) <> user and user <> 'dba')
    signal ('42S02', sprintf ('Access denied for table %s in TABLE_SET_POLICY', _tb), 'SR383');

  proc_name := complete_proc_name (_proc, 1);
  if (not isstring (__proc_exists (proc_name)))
    signal ('22023', sprintf ('The procedure %s does not exist in TABLE_SET_POLICY', _proc), 'SR384');

  is_view := case when exists (select 1 from SYS_VIEWS where V_NAME = tb_name) then 1 else 0 end;

  declare _stat, _msg varchar;
  if (exec ('call (?) (?, ?)', _stat, _msg, vector (proc_name, tb_name, 'S')))
    {
      signal ('42000', sprintf ('Trying in TABLE_SET_POLICY the procedure %s yielded an error : [%s]%s', proc_name, _stat, _msg), 'SR385');
    }
  declare inx, len integer;

  len := length (_type);
  inx := 0;
  while (inx < len)
    {
      declare opt varchar;
      opt := upper (chr (_type[inx]));

      if (opt not in ('I', 'D', 'U', 'S'))
	signal ('22023', sprintf ('Invalid option %s specified in TABLE_SET_POLICY', opt), 'SR386');

      if (is_view and opt <> 'S')
	signal ('22023', sprintf (
          'insert/delete/update policies must be declared for an actual table, ' ||
	  'not a view %s in TABLE_SET_POLICY', tb_name), 'SR391');

      if (exists (select 1 from DB.DBA.SYS_RLS_POLICY where RLSP_TABLE = tb_name and RLSP_OP = proc_name))
	signal ('22023',
         sprintf ('Procedure for option %s for table %s already defined in TABLE_SET_POLICY. Drop it first',
	 opt, _tb), 'SR387');

      insert into DB.DBA.SYS_RLS_POLICY (RLSP_TABLE, RLSP_FUNC, RLSP_OP)
        values (tb_name, proc_name, opt);

      inx := inx + 1;
    }

  __ddl_changed (tb_name);
}
;

--!AWK PUBLIC
create procedure DB.DBA.TABLE_DROP_POLICY (in _tb varchar, in _type varchar := 'IUDS')
{
  declare tb_name varchar;

  tb_name := complete_table_name (_tb, 1);
  if (1 <> (select count(*) from DB.DBA.SYS_KEYS
      where
       KEY_TABLE = tb_name and
       KEY_IS_MAIN = 1 and
       KEY_MIGRATE_TO is null))
    signal ('22023', sprintf ('No table or duplicate table %s in TABLE_DROP_POLICY', _tb), 'SR388');

  if (name_part (tb_name, 1) <> user and user <> 'dba')
    signal ('42S02', sprintf ('Access denied for table %s in TABLE_DROP_POLICY', _tb), 'SR389');

  delete from DB.DBA.SYS_RLS_POLICY where RLSP_TABLE = tb_name and strchr (upper (_type), RLSP_OP) is not NULL;

  if (row_count () > 0)
    __ddl_changed (tb_name);
}
;

create view ALL_COL_STAT as
select * from DB.DBA.SYS_COL_STAT where __any_grants (CS_TABLE)
;

grant select on ALL_COL_STAT to public
;

create view USER_COL_STAT as
select * from DB.DBA.SYS_COL_STAT where name_part (CS_TABLE, 1, NULL) = case user when 'dba' then 'DBA' else user end
;

grant select on USER_COL_STAT to public
;

create view ALL_COL_HIST as
select * from DB.DBA.SYS_COL_HIST where __any_grants (CH_TABLE)
;

grant select on ALL_COL_HIST to public
;

create view USER_COL_HIST as
select * from DB.DBA.SYS_COL_HIST where name_part (CH_TABLE, 1, NULL) = case user when 'dba' then 'DBA' else user end
;

grant select on USER_COL_HIST to public
;

create procedure SINV_CREATE_INVERSE (in _SINVM_NAME_IN varchar, in _SINV_INVERSE any, in _SINVM_FLAGS integer)
{
  declare _SINVM_NAME varchar;
  if (isstring (_SINV_INVERSE))
    {
      _SINV_INVERSE := vector (_SINV_INVERSE);
    }
  else if (length (_SINV_INVERSE) > 1)
    _SINVM_FLAGS := 0;

  declare inx integer;
  inx := 0;

  _SINVM_NAME := fix_identifier_case (_SINVM_NAME_IN);
  _SINVM_NAME := __proc_exists (_SINVM_NAME, 2);
  if (not isstring (_SINVM_NAME))
    {
      _SINVM_NAME := __proc_exists (_SINVM_NAME_IN, 1);
      if (not isstring (_SINVM_NAME))
	signal ('22023', sprintf (
          'Non-existent function %s passed as argument 1 to SINV_CREATE_INVERSE', _SINVM_NAME_IN),
	  'SR456');
    }

  declare _inverse varchar;
  foreach (varchar _inverse_in in _SINV_INVERSE) do
    {
      _inverse := fix_identifier_case (_inverse_in);
      _inverse := __proc_exists (_inverse, 2);
      if (not isstring (_inverse))
	{
	  _inverse := fix_identifier_case (_inverse_in);
	  _inverse := __proc_exists (_inverse, 1);
	  if (not isstring (_inverse))
	    signal ('22023', sprintf (
	      'Non-existent function %s passed as %dth value in argument 2 to SINV_CREATE_INVERSE',
	      _SINVM_NAME_IN, inx + 1),
	      'SR457');
	}

      insert into SYS_SQL_INVERSE (SINV_FUNCTION, SINV_ARGUMENT, SINV_INVERSE, SINV_FLAGS)
        values (_SINVM_NAME, inx, _inverse, _SINVM_FLAGS);
      inx := inx + 1;
    }
  sinv_read_invers_sys (_SINVM_NAME);
  if (inx = 1)
    {
      insert into SYS_SQL_INVERSE (SINV_FUNCTION, SINV_ARGUMENT, SINV_INVERSE, SINV_FLAGS)
         values (_inverse, 0, _SINVM_NAME, _SINVM_FLAGS);
      sinv_read_invers_sys (_inverse);
    }
}
;

create procedure SINV_DROP_INVERSE (in _SINVM_NAME_IN varchar)
{
  declare _SINVM_NAME varchar;
  _SINVM_NAME := fix_identifier_case (_SINVM_NAME_IN);
  _SINVM_NAME := __proc_exists (_SINVM_NAME, 2);
  if (not isstring (_SINVM_NAME))
    {
      _SINVM_NAME := __proc_exists (_SINVM_NAME_IN, 1);
      if (not isstring (_SINVM_NAME))
	signal ('22023', sprintf (
          'Non-existent function %s passed as argument 1 to SINV_DROP_INVERSE', _SINVM_NAME_IN),
	  'SR458');
    }
  delete from SYS_SQL_INVERSE where SINV_FUNCTION = _SINVM_NAME;
  sinv_read_invers_sys (_SINVM_NAME);
}
;

create procedure SINV_CREATE_KEY_MAPPING (in map_name varchar,  in part_defs any, in do_drops integer := 1)
{
  declare inx, len_of_part_defs integer;

  declare col_def_list, col_list, ocol_list, where_cond, gen_col_list, proc_parm_list, inv_vector varchar;

  if (isstring (map_name))
    map_name := fix_identifier_case (map_name);
  col_def_list := '';
  col_list := '';
  ocol_list := '';
  where_cond := '';
  gen_col_list := '';
  proc_parm_list := '';
  inv_vector := '';

  for (inx := 0, len_of_part_defs := length (part_defs); inx < len_of_part_defs; inx := inx + 2)
    {
      declare var_name, var_type varchar;

      var_name := fix_identifier_case (part_defs[inx]);
      var_type := part_defs[inx + 1];

      col_def_list := concat (col_def_list, sprintf ('K%d %I', (inx/2) + 1, var_type));
      col_list := concat (col_list, sprintf ('K%d', (inx/2) + 1));
      ocol_list := concat (ocol_list, var_name);
      proc_parm_list := concat (proc_parm_list, sprintf ('in "%I" %s', var_name, var_type));
      where_cond := concat (where_cond, sprintf ('K%d = "%I"', (inx/2) + 1, var_name));
      inv_vector := concat (inv_vector, sprintf ('''%s_%s''', map_name, var_name));
      if (inx < len_of_part_defs - 2)
	{
	  col_def_list := concat (col_def_list, ',\n ');
	  col_list := concat (col_list, ', ');
	  ocol_list := concat (ocol_list, ', ');
	  proc_parm_list := concat (proc_parm_list, ', ');
	  where_cond := concat (where_cond, ' and ');
	  inv_vector := concat (inv_vector, ',');
	}
    }
  if (do_drops > 0)
    {
      declare stat, msg any;
      stat := NULL;
      exec (sprintf ('\nDB.DBA.SINV_DROP_INVERSE (''%s'')\n', map_name), stat, msg);
      if (stat is not null)
	{
	  sql_warning (stat, 'IN005', msg);
	  stat := NULL;
	}
      exec (sprintf ('\nsequence_remove (''%s'')\n', map_name), stat, msg);
      if (stat is not null)
	{
	  sql_warning (stat, 'INV01', msg);
	  stat := NULL;
	}
      exec (sprintf ('\ndrop function "%I"\n', map_name), stat, msg);
      if (stat is not null)
	{
	  sql_warning (stat, 'INV02', msg);
	  stat := NULL;
	}
      for (inx := 0, len_of_part_defs := length (part_defs); inx < len_of_part_defs; inx := inx + 2)
	{
	  declare var_name varchar;

	  var_name := fix_identifier_case (part_defs[inx]);
	  exec (sprintf ('\ndrop function "%I_%I"\n', map_name, var_name), stat, msg);
	  if (stat is not null)
	    {
	      sql_warning (stat, 'INV03', msg);
	      stat := NULL;
	    }
	}
      exec (sprintf ('\ndrop table "MAP_%I"\n', map_name), stat, msg);
      if (stat is not null)
	{
	  sql_warning (stat, 'INV04', msg);
	  stat := NULL;
	}
    }

  if (do_drops = 2)
    return;

  exec (sprintf (concat (
    '\ncreate table "MAP_%I" (\n',
    ' ID integer,\n',
    ' %s,\n',
    ' primary key (%s))\n'),
    map_name,
    col_def_list, col_list
    ));

  exec (sprintf (concat (
    'create index "MAP_%I_ID" on "MAP_%I" (ID)\n'),
    map_name, map_name));

  exec (sprintf (concat (
    '\ncreate function "%I" (%s) returns integer\n',
    '{\n',
    '  declare _ID integer;\n',
    '  set isolation = ''committed'';\n',
    '  whenever not found  goto none1;\n',
    '  select ID into _ID from "MAP_%I" where\n',
    '    %s;\n',
    '  return _ID;\n',
    'none1:\n',
    '  set isolation = ''serializable'';\n',
    '  whenever not found  goto none2;\n',
    '  select ID into _ID from "MAP_%I" where\n',
    '    %s;\n',
    '  return _ID;\n',
    'none2:\n',
    '  _ID := sequence_next (''%s'');\n',
    '  insert into "MAP_%I" (ID, %s) values (_ID, %s);\n',
    '  return _ID;\n',
    '}\n'),
      map_name, proc_parm_list,
      map_name, where_cond,
      map_name, where_cond,
      map_name,
      map_name, col_list, ocol_list));

  for (inx := 0, len_of_part_defs := length (part_defs); inx < len_of_part_defs; inx := inx + 2)
    {
      declare var_name, var_type varchar;

      var_name := fix_identifier_case (part_defs[inx]);
      var_type := part_defs[inx + 1];

      exec (sprintf (concat (
	'\ncreate function "%I_%I" (in _ID integer) returns %s\n',
	'{\n',
	'  return (select K%d from "MAP_%I" where ID = _ID);\n',
	'}\n'),
	map_name, var_name, var_type,
	(inx/2) + 1, map_name));
     }


  exec (sprintf (
    '\nDB.DBA.SINV_CREATE_INVERSE (''%s'', vector (%s), 0)\n',
      map_name, inv_vector));
}
;

create procedure SYS_CREATE_TABLE_AS (
	in tb_name varchar, in _parse_tree any, in with_data integer,
	in exec_it integer := 1)
{
   declare _desc, _rows any;
   declare _cols any;
   declare _n_cols, _inx integer;
   declare _stmt varchar;
-- MI: no more need as sql_ddl_node always set flag to replicate, thus tbdef & insert will be logged separately
--   declare log_is_on integer;
--   log_is_on := client_attr ('transaction_log');

   exec (_parse_tree, NULL, NULL, NULL, 1, _desc, _rows);

   _cols := _desc[0];
   _n_cols := length (_cols);

   _stmt := sprintf ('create table %s (', REPL_FQNAME (tb_name));
   for (_inx := 0; _inx < _n_cols; _inx := _inx + 1)
     {
       declare _col any;
       declare _col_name varchar;

       _col := aref(_cols, _inx);
       _col_name := repl_undot_name (aref(_col, 0));

       _stmt := concat(_stmt,
	  sprintf('"%I" ', _col_name), REPL_COLTYPE (_col));

       if (_inx + 1 < _n_cols)
         _stmt:= concat(_stmt, ', ');
     }
    _stmt := concat(_stmt, ')');
    --dbg_obj_print (_stmt);
    if (exec_it <> 0)
      {
        --if (log_is_on and 1 = sys_stat ('cl_run_local_only'))
	--  log_enable (0);
        {
	    declare exit handler for sqlstate '*'
            {
		rollback work;
--		if (log_is_on)
--		  log_enable (1);
		resignal;
	    };
	    exec (_stmt);
	    if (with_data <> 0)
	      {
		--dbg_obj_print ('before insert');
		declare _insert_stmt, _tb_dotted any;
                _tb_dotted :=
		   vector (
                     200, -- TABLE_DOTTED
                     tb_name,
                     NULL,
                     0, -- U_ID_DBA
                     0, -- G_ID_DBA
                     0
                   );
                 -- must set the appropriate members to binary 0
                 aref_set_0 (_tb_dotted, 3);
                 aref_set_0 (_tb_dotted, 4);
                 aref_set_0 (_tb_dotted, 5);

		_insert_stmt := vector (
		   110, -- INSERT_STMT
                   _tb_dotted,
		   0,
		   _parse_tree,
		   0, 0, 0 -- INS_NORMAL, 0 key, 0 opts
		);
                aref_set_0 (_insert_stmt, 2);
                aref_set_0 (_insert_stmt, 4);
		exec (_insert_stmt);
		--dbg_obj_print ('after insert');
	      }
        }
        --if (log_is_on and 1 = sys_stat ('cl_run_local_only'))
        --  log_enable (1);
	--if (1 = sys_stat ('cl_run_local_only'))
	--  {
	--    log_text ('DB.DBA.SYS_CREATE_TABLE_AS (?, ?, ?)', tb_name, _parse_tree, with_data);
	--  }
      }
    else
      return _stmt;
}
;

--!AWK PUBLIC
create procedure
encode_b32_num (in i integer) returns varchar
{
  declare s varchar;
  declare x integer;

  x := i;
  s := '';

  declare b32_s varchar;
  b32_s := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  while (1 = 1)
    {
      s := chr (aref (b32_s, mod(x, 32))) || s;
      x := floor (x / 32);
      if (x = 0) goto done;
    }
 done:
  return s;
}
;

--!AWK PUBLIC
create procedure
decode_b32_num (in s varchar) returns integer
{
  declare x integer; x := 0;
  declare y integer;

  declare b32_s, typo_s, corr_s varchar;

  b32_s := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  typo_s := '1089';
  corr_s := 'IOBG';

  declare i integer;
  declare c varchar;

  i := 0;

  while (i < length(s))
    {
      c := chr (aref (s, i));

      y := locate (c, typo_s);
      if (y > 0) c := chr(aref (corr_s, y - 1));

      y := locate (c, b32_s);

      if (y > 0)
	    x := (x * 32) + y - 1;
      else
        signal ('42000', 'Invalid character in decode_b32_num');

      i := i + 1;
	}
  return x;
}
;


-- add all known sequences created by DBA
add_protected_sequence ('/!URIQA/')
;
add_protected_sequence ('/!sparql/')
;
add_protected_sequence ('DAV_HOME_DIR_UPDATE')
;
add_protected_sequence ('DB.DBA.DAV_RDF_GRAPH_URI')
;
add_protected_sequence ('DB.DBA.RDF_QUAD_FT_UPGRADE')
;
add_protected_sequence ('DB.DBA.RDF_QUAD_FT_UPGRADE-tridgell32-2')
;
add_protected_sequence ('DB.DBA.__UPDATE_SOAP_USERS_ACCESS')
;
add_protected_sequence ('DB.DBA.virt_proxy_init_state')
;
add_protected_sequence ('DELAY_UPDATE_DB_DBA_RDF_OBJ')
;
add_protected_sequence ('DELAY_UPDATE_WS_WS_HOSTFS_RES_CACHE')
;
add_protected_sequence ('DELAY_UPDATE_WS_WS_HOSTFS_RES_META')
;
add_protected_sequence ('FK_UNIQUE_CHEK')
;
add_protected_sequence ('NNTP_SERVER_ID')
;
add_protected_sequence ('RDF_DATATYPE_TWOBYTE')
;
add_protected_sequence ('RDF_LANGUAGE_TWOBYTE')
;
add_protected_sequence ('RDF_PREF_SEQ')
;
add_protected_sequence ('RDF_RO_ID')
;
add_protected_sequence ('RDF_URL_IID_BLANK')
;
add_protected_sequence ('RDF_URL_IID_NAMED')
;
add_protected_sequence ('RDF_URL_IID_NAMED_BLANK')
;
add_protected_sequence ('UDDI_operator')
;
add_protected_sequence ('URIQADefaultHost')
;
add_protected_sequence ('URIQAFingerprint')
;
add_protected_sequence ('VAD_atomic')
;
add_protected_sequence ('VAD_errcount')
;
add_protected_sequence ('VAD_is_run')
;
add_protected_sequence ('VAD_msg')
;
add_protected_sequence ('VAD_wet_run')
;
add_protected_sequence ('WS.WS.SYS_DAV_INIT-status')
;
add_protected_sequence ('WSRMServerID')
;
add_protected_sequence ('__FTI_VERSION__')
;
add_protected_sequence ('__IRI8')
;
add_protected_sequence ('__IRI_MAX8')
;
add_protected_sequence ('__NEXT__vad_id')
;
add_protected_sequence ('__REPL_CREATE_UPDATABLE_SNAPSHOT_LOG_WS.WS.SYS_DAV_RES')
;
add_protected_sequence ('__http_vd_upgrade')
;
add_protected_sequence ('__nntp_from_header')
;
add_protected_sequence ('__nntp_organization_header')
;
add_protected_sequence ('__no_vspx_temp')
;
add_protected_sequence ('__repl_this_server')
;
add_protected_sequence ('__scheduler_do_now__')
;
add_protected_sequence ('__spam_filtering')
;
add_protected_sequence ('__wsrm_version__')
;
add_protected_sequence ('dbpump_id')
;
add_protected_sequence ('dbpump_temp')
;
add_protected_sequence ('uuid_state')
;
add_protected_sequence ('vad_id')
;
add_protected_sequence ('vad_tmp')
;
add_protected_sequence ('vdd_init')
;

create table SYS_X509_CERTIFICATES (
    	C_U_ID	int,			-- user id
    	C_ID varchar, 			-- key id
	C_DATA long varchar, 		-- certificate (and possibly key) pem format
	C_KIND integer, 		-- 1 : CA certificate, rest for future use
	C_NAME varchar,
	primary key (C_U_ID, C_KIND, C_ID))
;

create procedure X509_CA_CERTIFICATES_INIT ()
{
  for select C_DATA from SYS_X509_CERTIFICATES where C_U_ID = 0 and C_KIND = 1 do
    {
      x509_ca_cert_add (cast (C_DATA as varchar));
    }
}
;

--!AFTER
X509_CA_CERTIFICATES_INIT ()
;

create procedure X509_CERTIFICATES_ADD (in certs varchar, in kind int := 1)
{
  declare ki varchar;
  declare name, subj varchar;
  declare arr any;
  declare user_id int;

  arr := pem_certificates_to_array (certs);
  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = user);
  if (user_id <> 0 and kind = 1)
    signal ('39000', 'Only DBA can install CA roots');
  foreach (varchar cert in arr) do
    {
      ki := get_certificate_info (6, cert, 0, '');
      if (ki is null)
	signal ('22023', 'Can not get certificate id');
      subj := get_certificate_info (2, cert, 0, '');
      name := regexp_match ('/CN=[^/]+/?', subj);
      if (name is null or name like '/CN=http:%')
	name := regexp_match ('/O=[^/]+/?', subj);
      if (name is not null)
	{
	  declare pos int;
	  name := trim (name, '/');
	  pos := strchr (name, '=');
	  name := subseq (name, pos + 1);
	  name := split_and_decode (replace (name, '\\x', '%'))[0];
	}
      insert soft SYS_X509_CERTIFICATES (C_U_ID, C_ID, C_DATA, C_KIND, C_NAME) values (user_id, ki, cert, kind, name);
      x509_ca_cert_add (cert);
    }
}
;

create procedure X509_CERTIFICATES_DEL (in certs varchar, in kind int := 1)
{
  declare ki varchar;
  declare name, subj varchar;
  declare arr any;
  declare user_id int;

  arr := pem_certificates_to_array (certs);
  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = user);
  if (user_id <> 0 and kind = 1)
    signal ('39000', 'Only DBA can install CA roots');
  foreach (varchar cert in arr) do
    {
      ki := get_certificate_info (6, cert, 0, '');
      if (ki is null)
	signal ('22023', 'Can not get certificate id');
      delete from SYS_X509_CERTIFICATES where C_U_ID = user_id and C_KIND = kind and C_ID = ki;
    }
  x509_ca_certs_remove ();
  X509_CA_CERTIFICATES_INIT ();
}
;

create procedure X509_ROOT_CA_CERTS ()
{
  declare ret any;
  ret := (select vector_agg (C_DATA) from SYS_X509_CERTIFICATES where C_U_ID = 0 and C_KIND = 1);
  return ret;
}
;

create procedure uptime ()
{
  declare y,m,d,h,mn int;
  declare y1,m1,d1,h1,mn1, delta int;
  declare y2,m2,d2,h2,mn2 int;
  declare s, dt, meta, data any;
  declare uptime varchar;
  result_names (uptime);
  if (sys_stat ('st_started_since_year') = 0)
    exec ('status ()', null, null, vector (), 0, meta, data);

  y := sys_stat ('st_started_since_year');
  m := sys_stat ('st_started_since_month');
  d := sys_stat ('st_started_since_day');
  h := sys_stat ('st_started_since_hour');
  mn := sys_stat ('st_started_since_minute');

  dt := stringdate (sprintf ('%d-%d-%d %d:%d', y,m,d,h,mn));
  delta := datediff ('minute', dt, now ());

  mn2 := mod (delta, 60);
  h2 := mod (delta / 60, 24);
  d2 := delta / 60 / 24;

  s := '';
  if (d2) s := s || cast (d2 as varchar) || ' day(s), ';
  if (h2 or d2) s := s || cast (h2 as varchar) || ' hour(s), ';
  s := s || cast (mn2 as varchar) || ' minute(s)';
  result (s);
}
;

create procedure DB.DBA.CL_MEM_SRV ()
{
  return vector (sys_stat ('st_sys_ram'), sys_stat ('st_host_name'));
}
;

create procedure mem_info_cl ()
{
  declare daq, r, dict, vec any;
  declare s int;
  if (1 = sys_stat ('cl_run_local_only'))
    {
      return sys_stat ('st_sys_ram');
    }
  commit work;
  daq := daq (0);
  daq_call (daq, 'DB.DBA.SYS_COLS', 'SYS_COLS_BY_NAME', 'DB.DBA.CL_MEM_SRV', vector (), 1);
  dict := dict_new (10);
  while (r:= daq_next (daq))
    {
      if (length (r) > 2 and isarray (r[2]) and r[2][0] = 3)
	{
	  declare err any;
	  err := r[2][1];
	  if (isarray (err))
	    signal (err[1], err[2]);
	}
      if (dict_get (dict, r[2][1][1]) is null)
	{
	  dict_put (dict, r[2][1][1], 1);
	  s := s + r[2][1][0];
	}
    }
  return s;
}
;

create procedure
mem_hum_size (in sz integer) returns varchar
{
  if (sz = 0)
    return ('unknown');
  if (sz < 1024)
    return (sprintf ('%d B', cast (sz as integer)));
  if (sz < 102400)
    return (sprintf ('%d kB', sz/1024));
  if (sz < 1048576)
    return (sprintf ('%d kB', cast (sz/1024 as integer)));
  if (sz < 104857600)
    return (sprintf ('%d MB', sz/1048576));
  if (sz < 1073741824)
    return (sprintf ('%d MB', cast (sz/1048576 as integer)));
  return (sprintf ('%d GB', sz/1073741824));
}
;

--
-- Object 2 JSON functions
--
create procedure DB.DBA.jsonObject ()
{
  return subseq (soap_box_structure ('x', 1), 0, 2);
}
;

create procedure DB.DBA.isJsonObject (
  inout o any)
{
  if (isarray (o) and (length (o) > 1) and (__tag (o[0]) = 255))
    return 1;
  return 0;
}
;

create procedure DB.DBA.array2obj (
  in V any)
{
  return vector_concat (DB.DBA.jsonObject (), V);
}
;

create procedure DB.DBA.obj2json (
  in o any,
  in d integer := 10,
  in nsArray any := null,
  in attributePrefix varchar := null)
{
  declare N, M integer;
  declare R, T any;
  declare S, retValue any;

  if (d = 0)
    return '[maximum depth achieved]';

  T := vector ('\b', '\\b', '\t', '\\t', '\n', '\\n', '\f', '\\f', '\r', '\\r', '"', '\\"', '\\', '\\\\');
  retValue := '';
  if (isnull (o))
  {
    retValue := 'null';
  }
  else if (isnumeric (o))
  {
    retValue := cast (o as varchar);
  }
  else if (isstring (o))
  {
    for (N := 0; N < length(o); N := N + 1)
    {
      R := chr (o[N]);
      for (M := 0; M < length(T); M := M + 2)
      {
        if (R = T[M])
          R := T[M+1];
      }
      retValue := retValue || R;
    }
    retValue := '"' || retValue || '"';
  }
  else if (isarray (o) and (length (o) > 1) and ((__tag (o[0]) = 255) or (o[0] is null and (o[1] = '<soap_box_structure>' or o[1] = 'structure'))))
  {
    retValue := '{';
    for (N := 2; N < length (o); N := N + 2)
    {
      S := o[N];
      if (chr (S[0]) = attributePrefix)
        S := subseq (S, length (attributePrefix));
      if (not isnull (nsArray))
      {
        for (M := 0; M < length (nsArray); M := M + 1)
        {
          if (S like nsArray[M]||':%')
            S := subseq (S, length (nsArray[M])+1);
        }
      }
      retValue := retValue || '"' || S || '":' || obj2json (o[N+1], d-1, nsArray, attributePrefix);
      if (N <> length(o)-2)
        retValue := retValue || ', ';
    }
    retValue := retValue || '}';
  }
  else if (isarray (o))
  {
    retValue := '[';
    for (N := 0; N < length(o); N := N + 1)
    {
      retValue := retValue || obj2json (o[N], d-1, nsArray, attributePrefix);
      if (N <> length(o)-1)
        retValue := retValue || ',\n';
    }
    retValue := retValue || ']';
  }
  return retValue;
}
;

create procedure DB.DBA.params2json (
  in o any)
{
  return obj2json (array2obj(o));
}
;

create procedure DB.DBA.json2obj (
  in o any)
{
  return json_parse (o);
}
;

--
-- Object 2 XML functions
--
create procedure DB.DBA.obj2xml (
  in o any,
  in d integer := 10,
  in tag varchar := null,
  in nsArray any := null,
  in attributePrefix varchar := '')
{
  declare N, M integer;
  declare R, T any;
  declare S, nsValue, retValue any;

  if (d = 0)
    return '[maximum depth achieved]';

  nsValue := '';
  if (not isnull (nsArray))
  {
    for (N := 0; N < length(nsArray); N := N + 2)
      nsValue := sprintf ('%s xmlns%s="%s"', nsValue, case when nsArray[N]='' then '' else ':'||nsArray[N] end, nsArray[N+1]);
  }
  retValue := '';
  if (isnumeric (o))
  {
    retValue := cast (o as varchar);
  }
  else if (isstring (o))
  {
    retValue := sprintf ('%V', o);
  }
  else if (__tag (o) = 211)
  {
    retValue := datestring (o);
  }
  else if (DB.DBA.isJsonObject (o))
  {
    for (N := 2; N < length(o); N := N + 2)
    {
      if (not DB.DBA.isJsonObject (o[N+1]) and isarray (o[N+1]) and not isstring (o[N+1]))
      {
        retValue := retValue || obj2xml (o[N+1], d-1, o[N], nsArray, attributePrefix);
      } else {
        if (chr (o[N][0]) <> attributePrefix)
        {
          nsArray := null;
          S := '';
          if ((attributePrefix <> '') and DB.DBA.isJsonObject (o[N+1]))
          {
            for (M := 2; M < length(o[N+1]); M := M + 2)
            {
              if (chr (o[N+1][M][0]) = attributePrefix)
                S := sprintf ('%s %s="%s"', S, subseq (o[N+1][M], length (attributePrefix)), obj2xml (o[N+1][M+1]));
            }
          }
	  if (o[N] = '#text')
	    retValue := retValue || obj2xml (o[N+1], d-1, o[N], nsArray, attributePrefix);
	  else
	    retValue := retValue || sprintf ('<%s%s%s>%s</%s>\n', o[N], S, nsValue, obj2xml (o[N+1], d-1, null, nsArray, attributePrefix), o[N]);
        }
      }
    }
  }
  else if (isarray (o))
  {
    for (N := 0; N < length(o); N := N + 1)
    {
      if (isnull (tag))
      {
        retValue := retValue || obj2xml (o[N], d-1, tag, nsArray, attributePrefix);
      } else {
        nsArray := null;
        S := '';
        if (not isnull (attributePrefix) and DB.DBA.isJsonObject (o[N]))
        {
          for (M := 2; M < length(o[N]); M := M + 2)
          {
            if (chr (o[N][M][0]) = attributePrefix)
              S := sprintf ('%s %s="%s"', S, subseq (o[N][M], length (attributePrefix)), obj2xml (o[N][M+1]));
          }
        }
        retValue := retValue || sprintf ('<%s%s%s>%s</%s>\n', tag, S, nsValue, obj2xml (o[N], d-1, null, nsArray, attributePrefix), tag);
      }
    }
  }
  return retValue;
}
;

create procedure xml2json (in str any)
{
  declare js varchar;
  declare xt any;

  if (__tag (str) <> __tag of XML)
    xt := xtree_doc (str);
  else
    xt := str;
  js := xslt ('http://local.virt/xml2json', xt);
  return serialize_to_UTF8_xml (js);
}
;

--!AWK PUBLIC
create procedure
DB.DBA.JSON_ESC_TEXT (in txt varchar)
{
  --no_c_escapes+
  txt := replace (txt, '\r', '\\r');
  txt := replace (txt, '\n', '\\n');
  txt := replace (txt, '"', '\\"');
  return txt;
}
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES ('http://www.openlinksw.com/virtuoso/xslt/:json-esc-text',
'DB.DBA.JSON_ESC_TEXT')
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:json-esc-text', 'DB.DBA.JSON_ESC_TEXT', 0)
;


create procedure json2xml (in str varchar)
{
  return obj2xml (json_parse (str), 100, null, null, '-');
}
;


create procedure
qt_record (in file varchar, in text varchar, in params any := null, in comment varchar, in check_order int := 1,
in check_col_names int := 1, in check_da_below int := 0,
in check_plan int := 1, in plan_xpath varchar := null, in addp int := 0, in ref_result varchar := null)
{
  declare stat, msg, meta, data, xp, xd, ss, axp, da, meta1, data1 any;
  declare daseq, darnd int;

  ss := string_output ();
  xp := explain (text, -1, 1);
  xd := xtree_doc (xp);

  --axp := cast (xslt ('file:/qt.xsl', xd) as varchar);
  axp := qt_xpath_gen (xd);

  if (check_plan and plan_xpath is not null and xpath_eval (plan_xpath, xd) = 0)
    signal ('.....', 'The spcified check do not match execution plan');

  if (check_plan and axp is not null and xpath_eval (axp, xd) is null)
    signal ('.....', 'The auto generated xpath check cannot be generated');
--  dbg_obj_print (axp);
--  dbg_obj_print (xpath_eval (axp, xd));

  if (plan_xpath is null)
    plan_xpath := '';
  if (plan_xpath = '' and axp is not null)
    plan_xpath := axp;

  exec (text, stat, msg, params, 0, meta, data);
  da := db_activity (1);
  if (check_da_below)
    {
      darnd := (da[0] * (check_da_below + 100)) / 100;
      daseq := (da[1] * (check_da_below + 100)) / 100;
    }

  http (sprintf ('<test>\n'), ss);
  http (sprintf ('    <comment>%V</comment>\n', comment), ss);
  http (sprintf ('    <query><![CDATA['), ss);
  http (text, ss);
  http (sprintf ('    ]]></query>\n'), ss);
  http (sprintf ('    <plans>\n'), ss);
  http (sprintf ('	<plan>\n'), ss);
  http (sprintf ('	    <verify result-order="%d" col-names="%d" plan-xpath="%V">\n', check_order, check_col_names, plan_xpath), ss);
  http (sprintf ('		<da-below rnd="%d" seq="%d" same-seg="" />\n', darnd, daseq), ss);
  http (sprintf ('	    </verify>\n'), ss);
  exec ('explain (?)', stat, msg, vector (text), 0, meta1, data1);
  http ('<text><![CDATA[', ss);
  foreach (any c in data1) do
    {
      http (c[0], ss);
      http ('\n', ss);
    }
  http (']]></text>\n', ss);
  http (sprintf ('	    <xmlplan>\n'), ss);
  http (xp, ss);
  http (sprintf ('	    </xmlplan>\n'), ss);
  http (sprintf ('	</plan>\n'), ss);
  http (sprintf ('    </plans>\n'), ss);

  http (sprintf ('    <columns>\n'), ss);
  foreach (any c in meta[0]) do
    {
      --dbg_obj_print (c);
      http (sprintf ('         <column name="%V"/>\n', c[0]), ss);
    }
  http (sprintf ('    </columns>\n'), ss);
  http (sprintf ('    <result cnt="%d">\n', length (data)), ss);
  if (check_order = 0)
    gvector_sort (data, 1, 0, 1);
  foreach (any c in data) do
    {
      declare i int;
      http ('<row>\n', ss);
      for (i := 0; i < length (c); i := i + 1)
        {
	  declare tag int;
	  tag := __tag (c[i]);
	  if (tag = 246)
	    tag := __tag (rdf_box_data (c[i]));
	  http (sprintf ('    <col dtp="%d">%V</col>\n', tag, cast (c[i] as varchar)), ss);
        }
      http ('</row>\n', ss);
    }
  http (sprintf ('    </result>\n'), ss);
  http (sprintf ('</test>'), ss);
  string_to_file (file, ss, -2);
  return axp;
}
;


create procedure
qt_check (in file varchar, out message varchar, in record_new integer := 0) returns int
{
  declare xt, qr, xp_test, expl, da any;
  declare stat, msg, meta, data, r, check_order, cnt any;
  declare daseq, darnd, plan_diff int;
  declare refs, idx any;

  plan_diff := 0;
  declare exit handler for sqlstate '*' {
    message := message || ' : ' || __SQL_MESSAGE;
    return 0;
  };

  xt := qt_source (file);
  message := xpath_eval ('/test/comment/text()', xt);
  qr := charset_recode (xpath_eval ('string (/test/query)', xt), '_WIDE_', 'UTF-8');
  check_order := atoi (charset_recode (xpath_eval ('/test/plans/plan/verify/@result-order', xt), '_WIDE_', 'UTF-8'));
  xp_test := charset_recode (xpath_eval ('/test/plans/plan/verify/@plan-xpath', xt), '_WIDE_', 'UTF-8');
  darnd := atoi (charset_recode (xpath_eval ('/test/plans/plan/verify/da-below/@rnd', xt), '_WIDE_', 'UTF-8'));
  daseq := atoi (charset_recode (xpath_eval ('/test/plans/plan/verify/da-below/@seq', xt), '_WIDE_', 'UTF-8'));
  --dbg_obj_print (qr);
  expl := xtree_doc (explain (qr, -1, 1));
  if (xpath_eval (xp_test, expl) is null)
    {
      message := message || ' : Different plan';
      plan_diff := 1;
    }
  cnt := atoi (charset_recode (xpath_eval ('/test/result/@cnt', xt), '_WIDE_', 'UTF-8'));
  exec (qr, stat, msg, vector (), 0, meta, data);
  da := db_activity (1);
  if ((darnd and darnd < da[0]) or (daseq and daseq < da[1]))
    {
      message := message || sprintf (' : DA is over the limit rnd %d<%d seq %d<%d', darnd, da[0], daseq, da[1]);
      return 0;
    }
  r := 0;
  if (check_order = 0)
    gvector_sort (data, 1, 0, 1);
  if (cnt <> length (data))
      message := message || ' : result count differs';
  refs := xpath_eval ('/test/result/row', xt, 0);
  idx := 0;
  foreach (any rr in refs) do
    {
      declare vals, c any;
      declare dtps any;
      declare i, l1, l2 int;
      vals := xpath_eval ('./col/text()', rr, 0);
      dtps := xpath_eval ('./col/@dtp', rr, 0);
      c := data[idx];
      l1 := length (c);
      l2 := length (vals);
      if (l1 <> l2)
	message := message || sprintf (' : results at row %d have different number of columns', idx);
      l1 := __min (l1, l2);	
      for (i := 0; i < l1; i := i + 1)
        {
	  declare t any;
	  t := cast (vals[i] as varchar);
	  if (__tag(c[i]) in (191, 190, 219))
	    {
	      declare delta float;
	      t := cast (t as double precision);
	      delta := 1 - (t / c[i]);
	      if (delta < 0)
		delta := -1 * delta;
	      if (delta > 1e-6)
		{
		  message := message || sprintf (' : value at #%d %s <> %s', i,
		  	cast (t as varchar),  cast (c[i] as varchar));
		  return 0;
		}
	    }
	  else if (t <>  cast (c[i] as varchar) or cast (dtps[i] as int) <> __tag(c[i]))
	    {
	      message := message || sprintf (' : value at %d #%d %s <> %s', idx + 1, i, t,  cast (c[i] as varchar));
	      return 0;
	    }
	}
      idx := idx + 1;
    }
  if (plan_diff <> 0 and record_new = 1)
    {
      qt_record (file || '.new', qr, comment => message, check_order => check_order);
    }
  return 1;
}
;

create procedure
qt_check_dir (in dir varchar, in file_mask varchar := '%', in record_new integer := 0)
{
  declare ls, inx, f, msg, stat, file, report any;
  ls := sys_dirlist (dir, 1);
  result_names (stat, file, report);
  for (inx := 0; inx < length (ls); inx := inx + 1)
    {
      if (ls[inx] like '%.xml' and ls[inx] like file_mask)
	{
	  f := qt_check (dir || '/' || ls[inx], msg, record_new);
	  result (case f when 1 then 'PASSED: ' else '***FAILED: ' end,ls[inx], msg);
	}
    }
}
;

create procedure
qt_source (in file varchar)
{
  declare t any;
  t := file_to_string (file);
  return xtree_doc (t);
}
;

create procedure
qt_xpath_gen (in xt any, in s any := null, in ck int := 0)
{
  declare xp, ss any;
  declare qn, qns, ret varchar;
  declare i int;
  if (s is null)
    {
      ss := string_output ();
      http ('/report[', ss);
      xp := xpath_eval ('/report/*', xt, 0);
      qt_xpath_gen (xp, ss);
      http (']', ss);
      ret := string_output_string (ss);
      if (ck and xpath_eval (ret, xt) is null)
        return null;
      return ret;
    }
  qn := 'ts|sel|hs|hf|union|setp|subq|fref|iter|qf|stn';
  qns := split_and_decode (qn, 0, '\0\0|');
  ss := s;
  i := 0;
  foreach (any x in xt) do
    {
      declare n any;
      x := xml_cut (x);
      n := cast (xpath_eval ('local-name(.)', x) as varchar);
--      dbg_obj_print (n);
      if (n in (qns))
	{
	  if (i > 0)
	    http (sprintf ('[following::%s', n), ss);
          else
            http (n, ss);
	  if (0 and n = 'ts')
	    {
	      http (sprintf ('[@key="%s"]', cast (xpath_eval ('@key', x) as varchar)), ss);
	    }
          xp := xpath_eval (qn, x, 0);
	  if (length (xp)) http ('[', ss);
	  qt_xpath_gen (xp, ss);
	  if (length (xp)) http (']', ss);
	  i := i + 1;
	}
    }
  for (i := i - 1; i > 0; i := i - 1)
    http (']', ss);
}
;




create procedure
qt_diff_dir (in dir varchar, in dir2 any, in file_mask varchar := '%')
{
  declare ls, inx, f, msg, stat, file, report varchar;
  ls := sys_dirlist (dir, 1);
  result_names (stat, file, report);
  for (inx := 0; inx < length (ls); inx := inx + 1)
    {
      if (ls[inx] like '%.xml' and ls[inx] like file_mask)
	{
	  f := qt_diff (dir || '/' || ls[inx], dir2 || '/' || ls[inx], msg);
	  result (case f when 1 then 'PASSED: ' else '***FAILED: ' end, ls[inx], msg);
	}
    }
}
;

create procedure
qt_make_array (inout arr any)
{
  declare i, idx, l int;
  idx := 0;
  foreach (any r in arr) do
    {
      declare vals any;
      declare dtps any;
      vals := xpath_eval ('./col/text()', r, 0);
      dtps := xpath_eval ('./col/@dtp', r, 0);
      for (i := 0; i < length (vals); i := i + 1)
        {
	  declare dtp int;
	  dtp := cast (dtps[i] as int);
	  if (dtp = 246)
	    dtp := 182;
	  if (dtp = 219)
	    vals[i] := _cvt (vector (dtp, 40, 15), cast (vals[i] as varchar));
	  else
	    vals[i] := _cvt (vector (dtp, 0), cast (vals[i] as varchar));
	}
      arr[idx] := vals;
      idx := idx + 1;
    }
  gvector_sort (arr, 1, 0, 1);
}
;

create procedure 
qt_diff (in file varchar, in target varchar, out message varchar) returns int
{
  declare xt, xt2, qr, xp_test, expl, da any;
  declare stat, msg, meta, data, r, check_order, cnt, cnt2 any;
  declare daseq, darnd, plan_diff, rcnt int;
  declare refs, refs2, idx any;

  plan_diff := 0;
  declare exit handler for sqlstate '*' {
    message := message || ' : ' || __SQL_MESSAGE;
    return 0;
  };

  xt := qt_source (file);
  xt2 := qt_source (target);
  message := ''; --xpath_eval ('/test/comment/text()', xt);
  cnt := atoi (charset_recode (xpath_eval ('/test/result/@cnt', xt), '_WIDE_', 'UTF-8'));
  cnt2 := atoi (charset_recode (xpath_eval ('/test/result/@cnt', xt2), '_WIDE_', 'UTF-8'));
  r := 0;
  if (cnt <> cnt2)
      message := message || ' : result count differs';
  refs := xpath_eval ('/test/result/row', xt, 0);
  refs2 := xpath_eval ('/test/result/row', xt2, 0);
  qt_make_array (refs);
  qt_make_array (refs2);
  rcnt := __min (length (refs), length (refs2));
  for (idx := 0; idx < rcnt; idx := idx + 1)
    {
      declare v1, v2 any;
      declare i, l1, l2 int;
      v1 := refs[idx];
      v2 := refs2[idx];
      l1 := length (v1);
      l2 := length (v2);
      if (l1 <> l2)
	message := message || sprintf (' : results at row %d have different number of columns', idx);
      l1 := __min (l1, l2);	
      for (i := 0; i < l1; i := i + 1)
        {
	  declare t1, t2, dtp1, dtp2 any;
	  t1 := v1[i];
	  t2 := v2[i];
	  dtp1 := __tag (t1);
	  dtp2 := __tag (t2);
	  if (dtp1 in (191, 190, 219) and dtp2 in (191, 190, 219))
	    dtp1 := dtp2 := __max (dtp1, dtp1);
	  if (dtp1 = dtp2 and dtp1 in (191, 190, 219))
	    {
	      declare delta float;
	      t1 := cast (t1 as double precision);
	      t2 := cast (t2 as double precision);
	      delta := 1 - (t1 / t2);
	      if (delta < 0)
		delta := -1 * delta;
	      if (delta > 1e-6)	
		{
		  message := message || sprintf (' : value at #%d %s <> %s', i, 
		  	cast (t1 as varchar),  cast (t2 as varchar));
		  return 0;
		}
	    }
	  else if (t1 <>  t2 or dtp1 <> dtp2)
	    {
	      message := message || sprintf (' : value at %d #%d [%s] <> [%s] dtp%d dtp%d', idx + 1, i, 
	      cast (t1 as varchar), cast (t2 as varchar), dtp1, dtp2);
	      return 0;
	    }
	}
    }
  return 1;
}
;
--
-- Validate functions
--
create procedure VALIDATE.DBA.clear (
  in S any)
{
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
}
;

create procedure VALIDATE.DBA.validate (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;
  declare exit handler for SQLSTATE '*'
  {
    if (not is_empty_or_null(valueMessage))
      signal ('NV001', valueMessage);

    if (__SQL_STATE = 'EMPTY')
      signal ('NV011', sprintf('Field ''%s'' cannot be empty!<>', valueName));

    if (__SQL_STATE = 'CLASS') {
      if (valueType in ('free-text', 'tags'))
        signal ('NV021', sprintf('Field ''%s'' contains invalid characters or noise words!<>', valueName));

      signal ('NV022', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
    }

    if (__SQL_STATE = 'TYPE')
      signal ('NV023', sprintf('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));

    if (__SQL_STATE = 'MIN')
      signal ('NV031', sprintf('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));

    if (__SQL_STATE = 'MAX')
      signal ('NV032', sprintf('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));

    if (__SQL_STATE = 'MINLENGTH')
      signal ('NV033', sprintf('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));

    if (__SQL_STATE = 'MAXLENGTH')
      signal ('NV034', sprintf('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));

    signal ('NV099', 'Unknown validation error!<>');
  };

  if (isstring (value))
    value := trim (value);

  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce (get_keyword ('class', params), get_keyword ('type', params));
  valueType := coalesce (get_keyword ('type', params), get_keyword ('class', params));
  valueName := get_keyword ('name', params, 'Field');
  valueMessage := get_keyword ('message', params, '');
  tmp := get_keyword ('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params)))
    {
      tmp := 0;
    }
    else if (get_keyword ('minLength', params, 0) <> 0)
    {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null(value))
  {
    signal('EMPTY', '');
  }
  else if (is_empty_or_null(value))
  {
    return value;
  }

  value := VALIDATE.DBA.validate_internal (valueClass, cast (value as varchar));
  if (valueType = 'integer')
  {
    tmp := get_keyword ('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'float')
  {
    tmp := get_keyword ('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
    tmp := get_keyword ('minLength', params);
    if (not isnull (tmp) and (length (value) < tmp))
      signal('MINLENGTH', cast (tmp as varchar));

    tmp := get_keyword ('maxLength', params);
    if (not isnull (tmp) and (length (value) > tmp))
      signal('MAXLENGTH', cast (tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure VALIDATE.DBA.validate_internal (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*'
  {
    if (__SQL_STATE = 'CLASS')
      resignal;

    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean')
  {
    if (propertyValue not in ('Yes', 'No'))
      goto _error;
  }
  else if (propertyType = 'integer')
  {
    if (isnull (regexp_match('^[-+]?[0-9]+\$', propertyValue)))
      goto _error;

    return cast (propertyValue as integer);
  }
  else if (propertyType = 'float')
  {
    if (isnull (regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;

    return cast (propertyValue as float);
  }
  else if (propertyType = 'dateTime')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
        goto _error;

    return cast (propertyValue as datetime);
  }
  else if (propertyType = 'dateTime2')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;

    return cast (propertyValue as datetime);
  }
  else if (propertyType = 'date')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;

    return cast (propertyValue as datetime);
  }
  else if (propertyType = 'date2')
  {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;

    return VALIDATE.DBA.dt_deformat (propertyValue, 'D.M.Y');
  }
  else if (propertyType = 'date-dd.MM.yyyy')
  {
    if (isnull (regexp_match('^(0[1-9]|[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;

    return VALIDATE.DBA.dt_deformat (propertyValue, 'D.M.Y');
  }
  else if (propertyType = 'date-MM/dd/yyyy')
  {
    if (isnull (regexp_match('^(0[1-9]|[1-9]|1[012])[- /.](0[1-9]|[1-9]|[12][0-9]|3[01])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;

    return VALIDATE.DBA.dt_deformat (propertyValue, 'M.D.Y');
  }
  else if (propertyType = 'date-yyyy/MM/dd')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|[1-9]|1[012])[- /.](0[1-9]|[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;

    return VALIDATE.DBA.dt_deformat (propertyValue, 'Y.M.D');
  }
  else if (propertyType = 'time')
  {
    if (isnull (regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;

    return cast (propertyValue as time);
  }
  else if (propertyType = 'folder')
  {
    if (isnull (regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  }
  else if ((propertyType = 'uri') or (propertyType = 'anyuri'))
  {
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:~]*)?\$', propertyValue)))
      goto _error;
  }
  else if (propertyType = 'email')
  {
    if (isnull (regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  }
  else if (propertyType = 'free-text')
  {
    if (length (propertyValue) and (not VALIDATE.DBA.validate_ftexts (propertyValue)))
      goto _error;
  }
  else if (propertyType = 'free-text-expression')
  {
    if (length (propertyValue) and (not VALIDATE.DBA.validate_ftext (propertyValue)))
      goto _error;
  }
  else if (propertyType = 'tags')
  {
    if (not VALIDATE.DBA.validate_tags (propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal ('CLASS', propertyType);
}
;

create procedure VALIDATE.DBA.validate_ftext (
  in S varchar)
{
  declare st, msg varchar;

  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (S));
  if ('00000' = st)
    return 1;

  return 0;
}
;

create procedure VALIDATE.DBA.validate_ftexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null)
  {
    w := trim (w, '"'' ');
    if (not VALIDATE.DBA.validate_ftext (w))
      return 0;

    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

create procedure VALIDATE.DBA.validate_tag (
  in S varchar)
{
  S := replace (trim(S), '+', '_');
  S := replace (trim(S), ' ', '_');
  if (not VALIDATE.DBA.validate_ftext(S))
    return 0;

  if (not isnull (strstr(S, '"')))
    return 0;

  if (not isnull (strstr(S, '''')))
    return 0;

  if (length (S) < 2)
    return 0;

  if (length (S) > 50)
    return 0;

  return 1;
}
;

create procedure VALIDATE.DBA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  if (is_empty_or_null(S))
    return 1;

  V := split_and_decode (trim (S, ','), 0, '\0\0,');
  if (is_empty_or_null(V))
    return 0;

  if (length(V) <> length(VALIDATE.DBA.validate_tags2unique (V)))
    return 0;

  for (N := 0; N < length(V); N := N + 1)
    if (not WEBDAV.DBA.validate_tag (V[N]))
      return 0;

  return 1;
}
;

create procedure VALIDATE.DBA.validate_tags2unique(
  inout aVector any)
{
  declare retValue any;
  declare N, M integer;

  retValue := vector ();
  for (N := 0; N < length (aVector); N := N + 1)
  {
    for (M := 0; M < length (retValue); M := M + 1)
      if (trim(lcase(retValue[M])) = trim(lcase(aVector[N])))
        goto _next;

    retValue := vector_concat (retValue, vector (trim(aVector[N])));
  _next:;
  }
  return retValue;
}
;


create procedure VALIDATE.DBA.dt_deformat (
  in pString varchar,
  in pFormat varchar := 'D.M.Y')
{
  declare y, m, d integer;
  declare N, I integer;
  declare ch varchar;

  N := 1;
  I := 0;
  d := 0;
  m := 0;
  y := 0;
  while (N <= length (pFormat))
  {
    ch := upper (substring (pFormat, N, 1));
    if (ch = 'M')
      m := VALIDATE.DBA.dt_deformat_tmp (pString, I);
    else if (ch = 'D')
      d := VALIDATE.DBA.dt_deformat_tmp (pString, I);
    else if (ch = 'Y')
    {
      y := VALIDATE.DBA.dt_deformat_tmp (pString, I);
      if (y < 50)
        y := 2000 + y;
      else if (y < 100)
        y := 1900 + y;
    }
    N := N + 1;
  }
  return stringdate (concat (cast (m as varchar), '.', cast (d as varchar), '.', cast (y as varchar)));
}
;

create procedure VALIDATE.DBA.dt_deformat_tmp (
  in S varchar,
  inout N integer)
{
  declare V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length (V) > 1)
  {
    N := V[1];
    return atoi (subseq (S, V[0], V[1]));
  }
  N := N + 1;
  return 0;
}
;

create procedure DPIPE_DEFINE_SRV (in n varchar, in tb varchar, in k varchar, in srv varchar, in is_upd int, in cproc varchar := null, in cbif varchar := null, in extra any := null)
{
  dpipe_define_1 (n, tb, k, srv, is_upd, cproc, cbif, extra);
  log_text ('dpipe_define_1 (?,?,?,?,?,?,?,?)', n, tb, k, srv, is_upd, cproc, cbif, extra);
}
;

create procedure dpipe_define (in n varchar, in tb varchar, in k varchar, in srv varchar, in is_upd int, in cproc varchar := null, in cbif varchar := null, in extra any := null)
{
  delete from SYS_DPIPE where DP_NAME = n;
  insert into SYS_DPIPE (DP_NAME, DP_PART_TABLE, DP_PART_KEY, DP_SRV_PROC, DP_IS_UPD, DP_CALL_PROC, DP_CALL_BIF, DP_EXTRA)
  values (n, tb, k, srv, is_upd, cproc, cbif, extra);
  cl_exec ('DB.DBA.DPIPE_DEFINE_SRV (?, ?, ?, ?, ?, ?, ?, ?)',
        vector (n, tb, k, srv, is_upd, cproc, cbif, extra));
}
;

create procedure DPIPE_DROP_SRV (in n varchar)
{
  dpipe_drop_1 (n);
  log_text ('dpipe_drop_1 (?)', n);
}
;

create procedure dpipe_drop (in n varchar)
{
  delete from SYS_DPIPE where DP_NAME = n;
  cl_exec ('DB.DBA.DPIPE_DROP_SRV (?)', vector (n));
}
;

