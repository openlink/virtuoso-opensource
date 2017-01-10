--
--  $Id$
--
--  SNP replication support
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

create table SYS_SNAPSHOT (
    SN_NAME varchar(255) NOT NULL,
    SN_QUERY varchar(1024) NOT NULL,
    SN_LAST_TS datetime,
    SN_IS_INCREMENTAL integer,
    SN_SOURCE_TABLE varchar(255),
    SN_LAST_UPD_BM varchar,
    primary key (SN_NAME)
)
;

alter table SYS_SNAPSHOT add SN_LAST_UPD_BM varchar
;


create table SYS_SNAPSHOT_LOG (
    SNL_SOURCE	varchar (320) NOT NULL,
    SNL_RLOG	varchar (320) NOT NULL,
    SNL_RPLOG	varchar (320) NOT NULL,
    primary key (SNL_SOURCE)
)
create unique index SNL_RLOG on DB.DBA.SYS_SNAPSHOT_LOG (SNL_RLOG)
create unique index SNL_RPLOG on DB.DBA.SYS_SNAPSHOT_LOG (SNL_RPLOG)
;

create procedure REPL_OFFSET_TIME (
    in _last_ts datetime, in _reg_var varchar, in _default_offset integer)
  returns datetime
{
  if (_last_ts is null)
    return null;

  declare v any;
  v := registry_get (_reg_var);
  declare n integer;
  if (v = 0 or (n := atoi(v)) = 0)
    n := _default_offset;

  declare _starttime datetime;
  _starttime := dateadd ('minute', -n, _last_ts);
  --dbg_obj_print (_last_ts, _starttime);
  return _starttime;
}
;

create procedure REPL_ORIGIN (in _rowguid varchar)
{
  declare _delim_pos integer;

  _delim_pos := strchr (_rowguid, '@');
  if (_delim_pos is not null)
    return substring (_rowguid, 1, _delim_pos);
  return null;
}
;

create procedure REPL_SET_ORIGIN (
    in _rowguid varchar, in _origin varchar := null)
{
  if (_origin is null)
    _origin := repl_this_server();

  declare _delim_pos integer;
  _delim_pos := strchr (_rowguid, '@');
  if (_delim_pos is not null)
    _rowguid := subseq (_rowguid, _delim_pos + 1);
  return concat (_origin, '@', _rowguid);
}
;



















;



;


;

----------------------------------------------------------------------
-- bidirectional snapshot replication
--

create table DB.DBA.SYS_SNAPSHOT_PUB (
  SP_ITEM varchar,
  SP_TYPE integer,          -- 1 = dav, 2 = table
  SP_LAST_TS datetime,      -- time of last update

  primary key (SP_ITEM, SP_TYPE)
)
;

grant select on DB.DBA.SYS_SNAPSHOT_PUB to PUBLIC
;

create table DB.DBA.SYS_SNAPSHOT_SUB (
  SS_SERVER varchar,
  SS_ITEM varchar,
  SS_TYPE integer,          -- 1 = dav, 2 = table
  SS_LAST_PULL_TS datetime, -- time of last pull
  SS_LAST_PUSH_TS datetime, -- time of last push

  primary key (SS_SERVER, SS_ITEM, SS_TYPE)
)
;

grant select on DB.DBA.SYS_SNAPSHOT_SUB to PUBLIC
;

create table DB.DBA.SYS_SNAPSHOT_CR (
  CR_ID         integer,
  CR_TABLE_NAME varchar,    -- table
  CR_TYPE       char,       -- CR type ('I', 'U' or 'D')
  CR_PROC       varchar,    -- procedure to execute
  CR_ORDER      integer,    -- order

  primary key (CR_ID)
)
;

grant select on DB.DBA.SYS_SNAPSHOT_CR to PUBLIC
;

create table DB.DBA.SYS_DAV_CR (
  CR_ID         integer,
  CR_COL_NAME   varchar,    -- DAV collection
  CR_PROC       varchar,    -- procedure to execute
  CR_ORDER      integer,    -- order

  primary key (CR_ID)
)
;

grant select on DB.DBA.SYS_DAV_CR to PUBLIC
;

create table DB.DBA.SYS_REPL_POSTPONED_RES (
    POSTPONED_RES_ID integer identity primary key,
    POSTPONED_RES_TS timestamp,

    LOCKED_COL_ID integer,
    LOCKED_RES_ID integer,

    RES_COLPATH varchar,
    RES_NAME varchar,
    RES_CONTENT long varbinary,
    RES_TYPE varchar,
    RES_PERMS varchar,
    RES_UNAME varchar,
    RES_GNAME varchar,
    RES_CR_TIME datetime,
    RES_MOD_TIME datetime,
    RES_ROWGUID varchar,

    RES_CR_COLNAME varchar,   -- conflict resolving collection,
                              -- if null conflict resolution will not be done
    RES_EMAIL varchar,
    RES_ORIGIN varchar,
    RES_OLD_ROWGUID varchar)
create index SYS_REPL_POSTPONED_LOCKED_COL_ID on DB.DBA.SYS_REPL_POSTPONED_RES (LOCKED_COL_ID)
create index SYS_REPL_POSTPONED_LOCKED_RES_ID on DB.DBA.SYS_REPL_POSTPONED_RES (LOCKED_RES_ID)
;

create procedure REPL_REMOTE_TYPES_RAW (in _dsn varchar)
  returns any
{
  declare _remote_types, _remote_types_info any;
  _remote_types := vector ();
  _remote_types_info := sql_gettypeinfo (_dsn);

  declare _type_info any;
  declare _sql_dtp integer;
  declare _type_title varchar;
  declare _idx, _len integer;
  _idx := 0;
  _len := length (_remote_types_info);
  while (_idx < _len)
    {
      _type_info := _remote_types_info[_idx];
      _sql_dtp := _type_info[1];
      _type_title := _type_info[0];
      REPL_ENSURE_MAPPING (_remote_types, _type_info[1], _type_info[0], _type_info);
      _idx := _idx + 1;
    }
  return _remote_types;
}
;

--
-- Construct sql_type, type_name array for lookup with get_keyword
-- in REPL_REMOTE_COLTYPE().
--
-- dv_to_sql_type() can return the following values:
--     -10 (SQL_WLONGVARCHAR)
--      -9 (SQL_WVARCHAR)
--      -4 (SQL_LONGVARBINARY)
--      -3 (SQL_VARBINARY)
--      -2 (SQL_BINARY)
--      -1 (SQL_LONGVARCHAR)
--       2 (SQL_NUMERIC)
--       4 (SQL_INTEGER)
--       5 (SQL_SMALLINT)
--       7 (SQL_REAL)
--       8 (SQL_DOUBLE)
--       9 (SQL_DATE/SQL_DATETIME)
--      10 (SQL_TIME)
--      11 (SQL_TIMESTAMP)
--      12 (SQL_VARCHAR)
--
-- Note that SQL_CHAR is never returned.
-- SQL_BINARY is returned only for DV_TIMESTAMP which is always converted
-- to DV_DATETIME in REPL_REMOTE_COLTYPE().
-- So mappings for all values except SQL_BINARY must exist.
--
create procedure REPL_REMOTE_TYPES (
    in _dsn varchar, in _dbms_name varchar := null)
  returns any
{
  declare _remote_types any;
  _remote_types := REPL_REMOTE_TYPES_RAW (_dsn);

  -- add missing mappings
  if (_dbms_name is null)
    _dbms_name := get_keyword (17, vdd_dsn_info(_dsn), '');
  if (strstr (_dbms_name, 'SQL Server') is not null or
      strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
    {
      REPL_ENSURE_MAPPING (_remote_types, 8, 'float');      -- SQL_DOUBLE
      REPL_ENSURE_MAPPING (_remote_types, 9, 'datetime');   -- SQL_DATE
      REPL_ENSURE_MAPPING (_remote_types, 10, 'datetime');  -- SQL_TIME
    }
  else if (strstr (upper (_dbms_name), 'ORACLE') is not null)
    {
      REPL_ENSURE_MAPPING (_remote_types, -10, 'NCLOB');    -- SQL_WLONGVARCHAR
      REPL_ENSURE_MAPPING (_remote_types, -9, 'NVARCHAR2'); -- SQL_WVARCHAR
      REPL_ENSURE_MAPPING (_remote_types, 2, 'NUMERIC');    -- SQL_NUMERIC
      REPL_ENSURE_MAPPING (_remote_types, 4, 'INTEGER');    -- SQL_INTEGER
      REPL_ENSURE_MAPPING (_remote_types, 5, 'SMALLINT');   -- SQL_SMALLINT
      REPL_ENSURE_MAPPING (_remote_types, 7, 'FLOAT');      -- SQL_SINGLE_FLOAT
      REPL_ENSURE_MAPPING (_remote_types, 9, 'DATE');       -- SQL_DATE
      REPL_ENSURE_MAPPING (_remote_types, 10, 'DATE');      -- SQL_TIME
    }
  else if (strstr (_dbms_name, 'DB2') is not null)
    {
      REPL_ENSURE_MAPPING (_remote_types, -10, 'DBCLOB');   -- SQL_WLONGVARCHAR
      REPL_ENSURE_MAPPING (_remote_types, -9, 'VARCHAR () FOR MIXED DATA');
                                                            -- SQL_WVARCHAR
      REPL_OVERRIDE_MAPPING (_remote_types, -4, 'BLOB');    -- SQL_LONGBINARY
      REPL_OVERRIDE_MAPPING (_remote_types, -1, 'CLOB');    -- SQL_LONGVARCHAR
    }
  else if (strstr (_dbms_name, 'Informix') is not null)
    {
      -- XXX DML fails for SQL_WLONGVARCHAR and SQL_LONGVARCHAR (text)
      REPL_ENSURE_MAPPING (_remote_types, -10, 'TEXT');     -- SQL_WLONGVARCHAR
      REPL_ENSURE_MAPPING (_remote_types, -9, 'NVARCHAR');  -- SQL_WVARCHAR
      REPL_ENSURE_MAPPING (_remote_types, -3, 'BYTE');      -- SQL_VARBINARY
      REPL_ENSURE_MAPPING (_remote_types, 2, 'DECIMAL');    -- SQL_NUMERIC
    }
  return _remote_types;
}
;

create procedure REPL_ALL_COLS (in _tbl varchar)
{
  declare _stmt varchar;
  declare _stat, _msg varchar;
  declare _src_comp any;
  _stmt := sprintf ('select * from %s where 1 = 0', REPL_FQNAME (_tbl));
  _stat := '00000';
  _msg := '';
  if (0 <> exec(_stmt, _stat, _msg, vector(), 1, _src_comp, null))
    signal ('37000', concat ('The table ''', _tbl, ''' does not exist'), 'TR044');

  declare _cols, _col any;
  declare _ix, _len integer;
  _cols := vector();
  _ix := 0;
  _len := length (_src_comp[0]);
  while (_ix < _len)
    {
      _col := _src_comp[0][_ix];
      _cols := vector_concat (_cols,
          vector (vector (repl_undot_name (_col[0]), _col[1], _col[2], _col[3])));
      _ix := _ix + 1;
    }

  return _cols;
}
;

create procedure REPL_TBL_COLS (in _tbl varchar)
{
  declare _cols, _col any;
  declare _col_name varchar;
  declare _tbl_cols varchar;
  declare _ix, _len integer;
  _cols := REPL_ALL_COLS (_tbl);
  _tbl_cols := '';
  _ix := 0;
  _len := length (_cols);
  while (_ix < _len)
    {
      _col := aref (_cols, _ix);
      _col_name := aref (_col, 0);

      _tbl_cols := concat (_tbl_cols, sprintf ('"%I"', _col_name));
      if (_ix + 1 < _len)
        _tbl_cols := concat (_tbl_cols, ', ');
      _ix := _ix + 1;
    }
  return _tbl_cols;
}
;

--
-- append trailing '/'
create procedure REPL_COMPLETE_COLNAME (in _colname varchar)
    returns varchar
{
  declare _len integer;
  _len := length (_colname);
  if (_len > 0 and subseq (_colname, _len - 1) <> '/')
    _colname := concat (_colname, '/');
  return _colname;
}
;


;

;

create table WS.WS.RPLOG_SYS_DAV_RES (
    SOURCE varchar,
    TARGET varchar,
    RLOG_ROWGUID varchar,
    SNAPTIME datetime,
    primary key (SOURCE, TARGET, RLOG_ROWGUID)
)
;








;

;

--
-- store resource
-- if resource is locked save it in SYS_REPL_POSTPONED_RES table
create procedure REPL_DAV_STORE_RES_INT (
    in _res_colname varchar, in _res_name varchar, inout _res_content any,
    in _res_type varchar, in _res_perms varchar,
    in _res_uname varchar, in _res_gname varchar,
    in _res_cr_time datetime, in _res_mod_time datetime, in _rowguid varchar,
    in _cr_colname varchar, in _res_email varchar,
    in _origin varchar, in _old_rowguid varchar,
    in _res_col integer, inout _backup_colid integer)
{
  declare _rc integer;
  -- fetch parent col id
  if (_res_col is null and (_res_col := DAV_SEARCH_ID (_res_colname, 'c')) < 0)
    {
      --dbg_printf ('REPL_DAV_STORE_RES: %s: No such collection', _res_colname);
      return _res_col;
    }
  declare _res_rowguid varchar;
  _res_rowguid := _rowguid;

  --dbg_printf ('REPL_DAV_STORE_RES: _res_colname [%s], _res_name [%s], _cr_colname [%s]', _res_colname, _res_name, _cr_colname);

  -- check locks
  declare _locked_id integer;
  declare _locked_type char;
  _locked_id := DAV_SEARCH_ID (concat (_res_colname, _res_name), 'r');
  _locked_type := 'R';
  if (DAV_IS_LOCKED_INT (_locked_id, _locked_type) > 0)
    {
      --dbg_printf ('REPL_DAV_STORE_RES: resource is locked');
      declare _locked_col_id integer;
      declare _locked_res_id integer;
      if (_locked_type = 'R')
        {
          _locked_col_id := null;
          _locked_res_id := _locked_id;
        }
      else
        {
          _locked_col_id := _locked_id;
          _locked_res_id := null;
        }
      -- save it
      delete from DB.DBA.SYS_REPL_POSTPONED_RES where RES_COLPATH = _res_content and RES_NAME = _res_name;
      insert into DB.DBA.SYS_REPL_POSTPONED_RES (
          LOCKED_COL_ID, LOCKED_RES_ID,
          RES_COLPATH, RES_NAME, RES_CONTENT, RES_TYPE, RES_PERMS,
          RES_UNAME, RES_GNAME, RES_CR_TIME, RES_MOD_TIME, RES_ROWGUID,
          RES_CR_COLNAME, RES_EMAIL, RES_ORIGIN, RES_OLD_ROWGUID)
      values (_locked_col_id, _locked_res_id, _res_colname, _res_name,
          _res_content, _res_type, _res_perms, _res_uname, _res_gname,
          _res_cr_time, _res_mod_time, _rowguid,
          _cr_colname, _res_email, _origin, _old_rowguid);
      return 0;
    }

  if (_cr_colname is not null)
    {
      -- do conflict resolution
      declare _loc_content any;
      declare _loc_perms, _loc_type, _loc_rowguid varchar;
      declare _loc_cr_time, _loc_mod_time datetime;
      declare _loc_uname, _loc_email, _loc_gname varchar;
      declare _notify_email varchar;

      declare _do_backup, _do_notify integer;
      declare _notify_text varchar;
      _do_backup := null;
      _do_notify := null;
      _notify_email := null;
      _notify_text := null;

      whenever not found goto store_resource;
      select RES_CONTENT, RES_PERMS, RES_TYPE, RES_CR_TIME, RES_MOD_TIME,
             ROWGUID, U_NAME, U_E_MAIL, G_NAME
          into _loc_content, _loc_perms, _loc_type,
              _loc_cr_time, _loc_mod_time, _loc_rowguid,
              _loc_uname, _loc_email, _loc_gname
          from WS.WS.SYS_DAV_RES
          left join WS.WS.SYS_DAV_USER on (RES_OWNER = U_ID)
          left join WS.WS.SYS_DAV_GROUP on (RES_GROUP = G_ID)
          where RES_COL = _res_col and RES_NAME = _res_name;
      --dbg_printf ('REPL_DAV_STORE_RES: %s: Resource exists', _res_name);
      if (_loc_rowguid = _old_rowguid)
        {
          --dbg_printf ('REPL_DAV_STORE_RES: %s: No conflict', _res_name);
          goto store_resource;
        }
      --dbg_printf ('REPL_DAV_STORE_RES: %s: Conflict detected', _res_name);
      for select CR_PROC as _cr_proc from DB.DBA.SYS_DAV_CR
          where CR_COL_NAME = _cr_colname order by CR_ORDER do
        {
          --dbg_printf ('REPL_DAV_STORE_RES: conflict resolver [%s]', _cr_proc);
          _rc := call (_cr_proc) (
             _res_col, _res_name, _res_email,
             _res_content, _res_type, _res_cr_time, _res_mod_time,
             _res_uname, _res_gname,
             _do_backup, _do_notify, _notify_email, _notify_text);
          if (_rc = 5 or _rc = 4)
            {
              -- ignore
              --dbg_printf ('REPL_DAV_STORE_RES: ignore');
              if (_notify_email is null)
                _notify_email := _res_email;
              if (0 <> REPL_DAV_SAVE_BACKUP (
                           _do_backup, _do_notify, _notify_email, _notify_text,
                           _backup_colid, _res_colname,
                           _res_name, _res_content, _res_type, _res_perms,
                           _res_uname, _res_gname,
                           _res_cr_time, _res_mod_time, _res_rowguid))
                return -20;
              return 0;
            }
          else if (_rc = 3)
            {
              --dbg_printf ('REPL_DAV_STORE_RES: publisher wins');
              goto publisher_wins;
            }
          else if (_rc = 2)
            {
              --dbg_printf ('REPL_DAV_STORE_RES: subscriber wins, change origin');
              _res_rowguid := REPL_SET_ORIGIN (_res_rowguid);
              goto subscriber_wins;
            }
          else if (_rc = 1)
            {
              --dbg_printf ('REPL_DAV_STORE_RES: subscriber wins');
              goto subscriber_wins;
            }
        }

      --dbg_printf ('REPL_DAV_STORE_RES: publisher wins (default)');
      if (_do_backup is null)
        _do_backup := 1;
      if (_do_notify is null)
        _do_notify := 1;

publisher_wins:
      if (_notify_email is null)
        _notify_email := _res_email;
      if (0 <> REPL_DAV_SAVE_BACKUP (
                   _do_backup, _do_notify, _notify_email, _notify_text,
                   _backup_colid, _res_colname,
                   _res_name, _res_content, _res_type, _res_perms,
                   _res_uname, _res_gname, _res_cr_time, _res_mod_time,
                   _res_rowguid))
            return -20;
      _res_content := _loc_content;
      _res_type := _loc_type;
      _res_perms := _loc_perms;
      _res_uname := _loc_uname;
      _res_gname := _loc_gname;
      _res_cr_time := _loc_cr_time;
      _res_mod_time := _loc_mod_time;
      _res_rowguid := _loc_rowguid;
      goto store_resource;

subscriber_wins:
      if (_notify_email is null)
        _notify_email := _loc_email;
      if (0 <> REPL_DAV_SAVE_BACKUP (
                   _do_backup, _do_notify, _loc_email, _notify_text,
                   _backup_colid, _res_colname,
                   _res_name, _loc_content, _loc_type, _loc_perms,
                   _loc_uname, _loc_gname, _loc_cr_time, _loc_mod_time,
                   _loc_rowguid))
            return -20;

store_resource:
      _res_rowguid := concat ('raw:', _rowguid);
    }

  --dbg_printf ('_res_name [%s], _res_type [%s], _res_perms [%s], _res_uname [%s], _res_gname [%s]', _res_name, _res_type, _res_perms, _res_uname, _res_gname);
  _rc := DAV_RES_UPLOAD_STRSES_INT (
      concat (_res_colname, _res_name), _res_content, _res_type, _res_perms,
      _res_uname, _res_gname, null, null, 0,
      _res_cr_time, _res_mod_time, _res_rowguid);
  if (_rc < 0)
    {
      --dbg_printf ('REPL_DAV_STORE_RES: DAV_RES_UPLOAD_STRSES_INT returned %d', _rc);
      return _rc;
    }
  return 0;
}
;

create procedure REPL_DAV_STORE_RES (
    in _res_colname varchar, in _res_name varchar, in _res_content any,
    in _res_type varchar, in _res_perms varchar,
    in _res_uname varchar, in _res_gname varchar,
    in _res_cr_time datetime, in _res_mod_time datetime, in _rowguid varchar,
    in _origin varchar, in _old_rowguid varchar)
{
  declare _backup_colid integer;
  _backup_colid := null;
  return REPL_DAV_STORE_RES_INT (
      _res_colname, _res_name, _res_content, _res_type, _res_perms,
      _res_uname, _res_gname, _res_cr_time, _res_mod_time, _rowguid,
      null, null, null, null, null, _backup_colid);
}
;

create trigger SYS_DAV_LOCK_PROCESS_POSTPONED
    after delete on WS.WS.SYS_DAV_LOCK order 200 referencing old as _O
{
  declare _colid integer;
  declare _backup_colid integer;
  _backup_colid := null;

  --dbg_printf ('after DELETE on SYS_DAV_LOCK: LOCK_PARENT_TYPE: [%s], LOCK_PARENT_ID: %d', _O.LOCK_PARENT_TYPE, _O.LOCK_PARENT_ID);
  declare _res_colpath, _res_name varchar;
  declare _res_content varchar;
  declare _res_type, _res_perms, _res_uname, _res_gname varchar;
  declare _res_cr_time, _res_mod_time datetime;
  declare _res_rowguid varchar;
  declare _res_cr_colname, _res_email, _res_origin, _res_old_rowguid varchar;

  declare cr cursor for
      select RES_COLPATH, RES_NAME,
          cast (RES_CONTENT as varchar), RES_TYPE, RES_PERMS,
          RES_UNAME, RES_GNAME, RES_CR_TIME, RES_MOD_TIME, RES_ROWGUID,
          RES_CR_COLNAME, RES_EMAIL, RES_ORIGIN, RES_OLD_ROWGUID
      from DB.DBA.SYS_REPL_POSTPONED_RES
      where (_O.LOCK_PARENT_TYPE = 'C' and LOCKED_COL_ID = _O.LOCK_PARENT_ID)
      or (_O.LOCK_PARENT_TYPE = 'R' and LOCKED_RES_ID = _O.LOCK_PARENT_ID);
--      order by POSTPONED_RES_TS;
  open cr (exclusive);
  whenever not found goto nf;
  while (1)
    {
      fetch cr into _res_colpath, _res_name,
          _res_content, _res_type, _res_perms,
          _res_uname, _res_gname, _res_cr_time, _res_mod_time, _res_rowguid,
          _res_cr_colname, _res_email, _res_origin, _res_old_rowguid;
      _colid := DAV_SEARCH_ID (_res_colpath, 'c');
      if (_colid < 0)
        goto next;
      --dbg_printf ('_res_content: [%s]', _res_content);
      if (DB.DBA.REPL_DAV_STORE_RES_INT (_res_colpath, _res_name,
              _res_content, _res_type, _res_perms, _res_uname, _res_gname,
              _res_cr_time, _res_mod_time, _res_rowguid,
              _res_cr_colname, _res_email, _res_origin, _res_old_rowguid,
              _colid, _backup_colid) >= 0)
        {
          -- successfully stored
          delete from DB.DBA.SYS_REPL_POSTPONED_RES where current of cr;
        }
next:
      ;
    }
nf:
  close cr;
}
;

--
-- Save backup copy of resource that lost conflict resolution
create procedure REPL_DAV_SAVE_BACKUP (
    in _do_backup integer, in _do_notify integer,
    in _notify_email varchar, in _notify_text varchar,
    inout _backup_colid integer, in _colname varchar,
    in _res_name varchar, inout _res_content any,
    in _res_type varchar, in _res_perms varchar,
    in _res_uname varchar, in _res_gname varchar,
    in _res_cr_time datetime, in _res_mod_time datetime,
    in _res_rowguid varchar)
{
  if (_do_backup is null)
    _do_backup := 0;
  if (_do_backup <> 0)
    {
      -- ensure that backup collection exists
      declare _backup_colname varchar;
      _backup_colname := concat (_colname, '_SYS_REPL_BACKUP/');
      if (_backup_colid is null)
        {
          declare _uname, _gname varchar;
          declare exit handler for not found goto nf;
          select U_NAME, G_NAME
              into _uname, _gname
              from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
            where COL_ID = DB.DBA.DAV_SEARCH_ID (_colname, 'c')
            and COL_OWNER = U_ID and COL_GROUP = G_ID;
          goto create_backup_col;
nf:
          _uname := 'dav';
          _gname := 'administrators';
create_backup_col:
          _backup_colid := DAV_COL_CREATE_INT (
              _backup_colname, '110100000R', _uname, _gname,
              null, null, 0, 0, 0);
          if (_backup_colid < 0)
            {
              --dbg_printf ('REPL_DAV_STORE_BACKUP: DAV_COL_CREATE_INT returned %d (colname [%s]', _backup_colid, _backup_colname);
              return _backup_colid;
            }
        }

      -- store backup copy
      declare _max_id integer;
      select coalesce (max (RES_ID) + 1, 0) into _max_id from WS.WS.SYS_DAV_RES
          where RES_COL = _backup_colid;
      _res_name := concat (
         _backup_colname, _res_name, '.', sprintf ('%d', _max_id));
      --dbg_printf ('REPL_DAV_STORE_BACKUP: _res_name [%s]', _res_name);
      _res_rowguid := concat ('nolog:', _res_rowguid);

      declare _rc integer;
      _rc := DAV_RES_UPLOAD_STRSES_INT (
          _res_name, _res_content, _res_type, _res_perms,
          _res_uname, _res_gname, null, null, 0,
          _res_cr_time, _res_mod_time, _res_rowguid);
      if (_rc < 0)
        {
          --dbg_printf ('REPL_DAV_STORE_BACKUP: DAV_RES_UPLOAD_STRSES_INT returned %d', _rc);
          return _rc;
        }
    }

  if (_do_notify is null)
    _do_notify := 0;
  if (_do_notify <> 0)
    {
      if (_notify_text is null)
        {
          if (_do_backup <> 0)
            {
              _notify_text := sprintf (
'Backup copy of your file saved in
''%s''
(server ''%s'')',
                  _res_name, repl_this_server());
            }
          else
            {
              _notify_text := sprintf (
'Your file ''%s''
conflicted with another one and was replaced according to conflict
resolution policy (server ''%s'')',
                  concat (_colname, _res_name), repl_this_server());
            }
        }
      --dbg_printf ('notify_email: [%s], notify_text: [%s]', _notify_email, _notify_text);

      declare _stat, _msg varchar;
      _stat := '00000';
      _msg := '';
      if (0 <> exec ('smtp_send (null, ?, ?, ?)', _stat, _msg,
                   vector (_notify_email, _notify_email, _notify_text)))
       {
          --dbg_printf ('REPL_DAV_STORE_BACKUP: smtp_send: %s: %s', _stat, _msg);
          return 0;
        }
    }

  return 0;
}
;

--
-- Pull DAV collection updates from specified DAV tables
