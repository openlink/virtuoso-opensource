--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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
create procedure DB.DBA.SYS_INDEX_SPACE_STATS_PROC ()
{
  declare ISS_KEY_ID, ISS_NROWS, ISS_ROW_BYTES, ISS_BLOB_PAGES, ISS_ROW_PAGES integer;

  result_names (ISS_KEY_ID, ISS_NROWS, ISS_ROW_BYTES, ISS_BLOB_PAGES, ISS_ROW_PAGES);

  declare _res any;
  _res := sys_index_space_usage ();

  if (isarray (_res))
    {
      declare _inx, _len integer;
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
    ISS_NROWS integer,
    ISS_ROW_BYTES integer,
    ISS_BLOB_PAGES integer,
    ISS_ROW_PAGES integer) _tmp,
    DB.DBA.SYS_KEYS table option (order)
  where
    ISS_KEY_ID = KEY_ID
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
		  KEY_TABLE, "COLUMN", stat_cardinality, NULL, NULL,
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

