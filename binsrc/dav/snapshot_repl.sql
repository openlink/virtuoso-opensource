--
-- $Id$
--
--  SNP replication support
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

create procedure repl_undot_name (in id varchar)
{
  declare last_dot_inx integer;
  last_dot_inx := strrchr(id, '.');
  if (last_dot_inx > 0)
    return subseq(sprintf('%s', id), last_dot_inx + 1);
  else
    return id;
}
;

--
-- _type = 0 -- _src is DSN
-- _type = 1 -- _src is table name
--
--!AWK PUBLIC
create procedure REPL_GETDATE (in _src varchar := null, in _type integer := 0)
  returns datetime
{
  if (_src is null)
    return cast (datestring_GMT(now()) as datetime);

  if (_type = 1)
    {
      declare exit handler for not found { return REPL_GETDATE(); };
      select RT_DSN into _src from SYS_REMOTE_TABLE where RT_NAME = _src;
    }

  declare _dbms_name varchar;
  declare _stmt varchar;
  _dbms_name := get_keyword (17, vdd_dsn_info(_src), '');
  if (strstr(_dbms_name, 'Virtuoso') is not null)
    _stmt := 'select cast (datestring_GMT(now()) as datetime)';
  else if (strstr (_dbms_name, 'SQL Server') is not null or
      strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
    _stmt := 'select getutcdate()';
  else if (strstr (upper(_dbms_name), 'ORACLE') is not null)
    _stmt := 'select OPL_GETUTCDATE() from SYS.DUAL';
  else if (strstr (_dbms_name, 'DB2') is not null)
    _stmt := 'values current timestamp - current timezone';
  else if (strstr (_dbms_name, 'Informix') is not null)
    _stmt := 'select current from informix.systables where tabname = ''systables''';
  else
    _stmt := 'select {fn gettime()}';

  declare _row any;
  declare _stat, _msg varchar;
  _stat := '00000';
  _msg := '';
  --dbg_printf('stmt: [%s]', _stmt);
  if (0 <> rexecute (_src, _stmt, _stat, _msg, null, 0, null, _row))
    signal (_stat, _msg);
  if (length (_row) <> 1 or length (_row[0]) <> 1)
    signal ('37000', 'Can''t get remote timestamp', 'TR103');
  return _row[0][0];
}
;

create procedure REPL_SERVER_NAME (in _dsn varchar)
  returns varchar
{
  declare _stmt, _stat, _msg varchar;
  declare _dbms_name varchar;
  _dbms_name := get_keyword (17, vdd_dsn_info(_dsn), '');

  if (strstr (_dbms_name, 'Virtuoso') is not null)
    _stmt := 'select repl_this_server()';
  else if (strstr (_dbms_name, 'SQL Server') is not null or
      strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
    _stmt := 'select @@servername';
  else if (strstr (upper (_dbms_name), 'ORACLE') is not null)
    _stmt := 'select global_name from global_name';
  else if (strstr (_dbms_name, 'DB2') is not null)
    _stmt := 'values current server';
  else
    {
      signal (
          '22023',
          sprintf ('Can''t get server name from database type ''%s''', _dbms_name),
          'TR141');
    }

  declare _row any;
  _stat := '00000';
  _msg := '';
  if (0 <> rexecute (_dsn, _stmt, _stat, _msg, null, 0, null, _row))
    signal (_stat, _msg);
  if (length (_row) <> 1 or length (_row[0]) <> 1)
    signal ('37000', 'Can''t get remote server name', 'TR142');
  return _row[0][0];
}
;

create procedure REPL_SNP_SERVER (
    in _dsn varchar, in _usr varchar := null, in _pwd varchar := null)
  returns varchar
{
  if (_usr is not null)
    REPL_ENSURE_RDS (_dsn, _usr, _pwd);

  declare _server varchar;
  _server := REPL_SERVER_NAME (_dsn);

  declare _dsn2 varchar;
  whenever not found goto create_server;
  select DB_ADDRESS into _dsn2 from DB.DBA.SYS_SERVERS
      where SERVER = _server;
  if (_dsn2 <> _dsn)
    {
      signal ('37000',
          sprintf ('Error: Replication server ''%s'' with different address (dsn %s) already defined.',
              _server, _dsn2),
          'TR143');
    }
  return _server;

create_server:
  -- do not overwrite DB_ADDRESS
  insert into DB.DBA.SYS_SERVERS (SERVER, DB_ADDRESS, REPL_ADDRESS)
      values (_server, _dsn, _dsn);
  return _server;
}
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

create procedure REPL_STARTTIME (in _last_ts datetime)
  returns datetime
{
  return REPL_OFFSET_TIME (_last_ts, 'snp_repl_tolerance_offset', 15);
}
;

create procedure REPL_PURGE_STARTTIME (in _last_ts datetime)
  returns datetime
{
  return REPL_OFFSET_TIME (_last_ts, 'snp_repl_purge_offset', 30);
}
;

create procedure REPL_FQNAME (in _tbl varchar)
{
  declare _parts any;
  _parts := vector ('', '', '');
  declare _ix, _len integer;
  _ix := 0;
  _len := length (_parts);
  while (_ix < _len)
    {
      declare _p any;
      _p := name_part (_tbl, _ix);
      if (_p <> 0)
        _parts[_ix] := sprintf ('"%I"', _p);
      _ix := _ix + 1;
    }
  return concat (_parts[0], '.', _parts[1], '.', _parts[2]);
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

--
-- Create snapshot log for MS SQL Server
create procedure REPL_CREATE_SL_MSSQL (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare _stat, _msg varchar;

  declare _pkcols, _rpkcols, _rpkcond, _rpkcond2, _pkeq varchar;
  declare _pkvars, _pkvars2, _declare_pkvars, _declare_pkvars2 varchar;
  _pkcols := '';
  _rpkcols := '';
  _rpkcond := '';
  _rpkcond2 := '';
  _pkeq := '';
  _pkvars := '';
  _pkvars2 := '';
  _declare_pkvars := '';
  _declare_pkvars2 := '';

  declare _col any;
  declare _col_name, _col_type, _rcol_name, _pkvar, _pkvar2 varchar;
  declare _ix, _len integer;
  _ix := 0;
  _len := length (_pk_cols);
  while (_ix < _len)
    {
      _col := _pk_cols[_ix];
      _col_name := quote_dotted (_dsn, _col[0]);
      _col_type := REPL_REMOTE_COLTYPE (_dbms_name, _col, _remote_types);
      _rcol_name := quote_dotted (_dsn, concat ('RLOG_', _col[0]));
      _pkvar := concat ('@_', _col[0]);
      _pkvar2 := concat ('@__', _col[0]);

      _pkcols := concat (_pkcols, _col_name);
      _rpkcols := concat (_rpkcols, _rcol_name);
      _rpkcond := concat (_rpkcond, _rcol_name, ' = ', _pkvar);
      _rpkcond2 := concat (_rpkcond2, _rcol_name, ' = ', _pkvar2);
      _pkeq := concat (_pkeq, _pkvar, ' = ', _pkvar2);
      _pkvars := concat (_pkvars, _pkvar);
      _pkvars2 := concat (_pkvars2, _pkvar2);
      _declare_pkvars := concat (_declare_pkvars,
          'declare ', _pkvar, ' ', _col_type);
      _declare_pkvars2 := concat (_declare_pkvars2,
          'declare ', _pkvar2, ' ', _col_type);

      if (_ix < _len - 1)
        {
          _pkcols := concat (_pkcols, ', ');
          _rpkcols := concat (_rpkcols, ', ');
          _rpkcond := concat (_rpkcond, ' and ');
          _rpkcond2 := concat (_rpkcond2, ' and ');
          _pkeq := concat (_pkeq, ' and ');
          _pkvars := concat (_pkvars, ', ');
          _pkvars2 := concat (_pkvars2, ', ');
          _declare_pkvars := concat (_declare_pkvars, ';\n');
          _declare_pkvars2 := concat (_declare_pkvars2, ';\n');
        }
      _ix := _ix + 1;
    }

  declare _trig_i, _trig_u, _trig_d varchar;
  _trig_i := quote_dotted (_dsn, concat (_tbl, '_I_log'));
  _trig_u := quote_dotted (_dsn, concat (_tbl, '_U_log'));
  _trig_d := quote_dotted (_dsn, concat (_tbl, '_D_log'));

  -- clean up
  declare _stmt varchar;
  declare _stmts any;
  _stmts := vector (
      'drop trigger <TRIG_I>',
      'drop trigger <TRIG_U>',
      'drop trigger <TRIG_D>');
  _ix := 0;
  _len := length (_stmts);
  while (_ix < _len)
    {
      _stmt := _stmts[_ix];
      _stmt := replace (_stmt, '<TRIG_I>', _trig_i);
      _stmt := replace (_stmt, '<TRIG_U>', _trig_u);
      _stmt := replace (_stmt, '<TRIG_D>', _trig_d);
      _stat := '00000';
      _msg := '';
      rexecute (_dsn, _stmt, _stat, _msg);
      _ix := _ix + 1;
    }

  -- create trigger
  _stmts := vector (
'create trigger <TRIG_I> on <TN> after insert as
begin
  set nocount on;
  <DECLARE_PKVARS>;
  declare @snaptime datetime;
  declare @rlog_rowguid varchar(255);
  set @snaptime = getutcdate();

  declare cr cursor local for select <PKCOLS> from inserted;
  open cr;
  fetch cr into <PKVARS>;
  while @@FETCH_STATUS = 0
    begin
      set @rlog_rowguid = cast (newid() as varchar(255));
      update <RLOG>
          set SNAPTIME = @snaptime, DMLTYPE = ''I'', RLOG_ROWGUID = @rlog_rowguid
          where <RPKCOND>;
      if @@ROWCOUNT = 0
        begin
          -\- print ''update: record does not exist'';
          insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
              values (<PKVARS>, @snaptime, ''I'', @rlog_rowguid);
        end
      fetch cr into <PKVARS>;
    end
  close cr;
  deallocate cr;
end',
'create trigger <TRIG_D> on <TN> after delete as
begin
  set nocount on;
  <DECLARE_PKVARS>;
  declare @snaptime datetime;
  declare @rlog_rowguid varchar(255);
  set @snaptime = getutcdate();

  declare cr cursor local for select <PKCOLS> from deleted;
  open cr;
  fetch cr into <PKVARS>;
  while @@FETCH_STATUS = 0
    begin
      set @rlog_rowguid = cast (newid() as varchar(255));
      update <RLOG>
          set SNAPTIME = @snaptime, DMLTYPE = ''D'', RLOG_ROWGUID = @rlog_rowguid
          where <RPKCOND>;
      if @@ROWCOUNT = 0
        begin
          -\- print ''delete: record does not exist'';
          insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
              values (<PKVARS>, @snaptime, ''D'', @rlog_rowguid);
        end
      fetch cr into <PKVARS>;
    end
  close cr;
  deallocate cr;
end',
'create trigger <TRIG_U> on <TN> after update as
begin
  set nocount on;
  <DECLARE_PKVARS>;
  <DECLARE_PKVARS2>;
  declare @snaptime datetime;
  declare @rlog_rowguid varchar(255);
  set @snaptime = getutcdate();

  declare cr cursor local for select <PKCOLS> from inserted;
  declare cr2 cursor local for select <PKCOLS> from deleted;
  open cr;
  open cr2;
  fetch cr into <PKVARS>;
  fetch cr2 into <PKVARS2>;
  while @@FETCH_STATUS = 0
    begin
      set @rlog_rowguid = cast (newid() as varchar(255));
      if <PKEQ>
        begin
          update <RLOG>
              set SNAPTIME = @snaptime, DMLTYPE = ''U'', RLOG_ROWGUID = @rlog_rowguid
              where <RPKCOND>;
          if @@ROWCOUNT = 0
            begin
              -\- print ''update: record does not exist'';
              insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
                values (<PKVARS>, @snaptime, ''U'', @rlog_rowguid);
            end
          goto next_row;
        end

      update <RLOG>
          set SNAPTIME = @snaptime, DMLTYPE = ''D'', RLOG_ROWGUID = @rlog_rowguid
          where <RPKCOND2>;
      if @@ROWCOUNT = 0
        begin
          -\- print ''update/delete: record does not exist'';
          insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
            values (<PKVARS2>, @snaptime, ''D'', @rlog_rowguid);
        end

      set @rlog_rowguid = cast (newid() as varchar(255));
      update <RLOG>
          set SNAPTIME = @snaptime, DMLTYPE = ''I'', RLOG_ROWGUID = @rlog_rowguid
          where <RPKCOND>;
      if @@ROWCOUNT = 0
        begin
          -\- print ''update/insert: record does not exist'';
          insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
            values (<PKVARS>, @snaptime, ''I'', @rlog_rowguid);
        end

next_row:
      fetch cr into <PKVARS>;
      fetch cr2 into <PKVARS2>;
    end
  close cr;
  deallocate cr;
  close cr2;
  deallocate cr2;
end');
  _ix := 0;
  _len := length (_stmts);
  while (_ix < _len)
    {
      _stmt := _stmts[_ix];
      _stmt := replace (_stmt, '<TRIG_I>', _trig_i);
      _stmt := replace (_stmt, '<TRIG_U>', _trig_u);
      _stmt := replace (_stmt, '<TRIG_D>', _trig_d);
      _stmt := replace (_stmt, '<DECLARE_PKVARS>', _declare_pkvars);
      _stmt := replace (_stmt, '<DECLARE_PKVARS2>', _declare_pkvars2);
      _stmt := replace (_stmt, '<PKVARS>', _pkvars);
      _stmt := replace (_stmt, '<PKVARS2>', _pkvars2);
      _stmt := replace (_stmt, '<PKCOLS>', _pkcols);
      _stmt := replace (_stmt, '<RPKCOLS>', _rpkcols);
      _stmt := replace (_stmt, '<RPKCOND>', _rpkcond);
      _stmt := replace (_stmt, '<RPKCOND2>', _rpkcond2);
      _stmt := replace (_stmt, '<PKEQ>', _pkeq);
      _stmt := replace (_stmt, '<RLOG>',
          quote_dotted (_dsn, concat ('RLOG_', _tbl)));
      _stmt := replace (_stmt, '<TN>', quote_dotted (_dsn, _tbl));
      --dbg_printf ('MSSQL: [%s]', _stmt);

      _stat := '00000';
      _msg := '';
      if (0 <> rexecute (_dsn, _stmt, _stat, _msg))
        signal (_stat, _msg);
      _ix := _ix + 1;
    }
}
;

--
-- Create snapshot log for Oracle
create procedure REPL_CREATE_SL_ORACLE (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare ix, len integer;
  declare stmt varchar;
  declare stat, msg varchar;
  declare col any;

  declare rpk, npk, npkcond, opk, opkcond, pkeq, rlog varchar;
  rpk := '';
  npk := '';
  npkcond := '';
  opk := '';
  opkcond := '';
  pkeq := '';
  rlog := quote_dotted (_dsn, concat ('RLOG_', _tbl));

  ix := 0;
  len := length (_pk_cols);
  declare colname, rcolname varchar;
  while (ix < len)
    {
      col := _pk_cols[ix];
      colname := quote_dotted (_dsn, col[0]);
      rcolname := quote_dotted (_dsn, concat ('RLOG_', col[0]));

      rpk := concat (rpk, rcolname);
      npk := concat (npk, ':new.', colname);
      npkcond := concat (npkcond, rcolname, ' = :new.', colname);
      opk := concat (opk, ':old.', colname);
      opkcond := concat (opkcond, rcolname, ' = :old.', colname);
      pkeq := concat (pkeq, ':old.', colname, ' = :new.', colname);

      if (ix < len - 1)
        {
          rpk := concat (rpk, ', ');
          npk := concat (npk, ', ');
          npkcond := concat (npkcond, ' and ');
          opk := concat (opk, ', ');
          opkcond := concat (opkcond, ' and ');
          pkeq := concat (pkeq, ' and ');
        }
      ix := ix + 1;
    }

  -- cleanup and prepare
  declare stmts any;
  stmts := vector (
      'create or replace function OPL_GETUTCDATE return date is
begin
  return cast (localtimestamp at time zone ''00:00'' as date);
end;');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stat := '00000';
      msg := '';
      rexecute (_dsn, stmt, stat, msg);
      ix := ix + 1;
    }

  -- create triggers;
  stmts := vector (
    'create or replace trigger "<TN>_I_log" after insert on "<TN>"
for each row
declare
  snaptime_ date := OPL_GETUTCDATE();
begin
  update <RLOG> set SNAPTIME = snaptime_, DMLTYPE = ''I'', RLOG_ROWGUID = sys_guid()
      where <NPKCOND>;
  if sql%rowcount = 0 then
    insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
        values(<NPK>, snaptime_, ''I'', sys_guid());
  end if;
end;',
    'create or replace trigger "<TN>_D_log" after delete on "<TN>"
for each row
declare
  snaptime_ date := OPL_GETUTCDATE();
begin
  update <RLOG> set SNAPTIME = snaptime_, DMLTYPE = ''D'', RLOG_ROWGUID = sys_guid()
      where <OPKCOND>;
  if sql%rowcount = 0 then
    insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
        values(<OPK>, snaptime_, ''D'', sys_guid());
  end if;
end;',
    'create or replace trigger "<TN>_U_log" after update on "<TN>"
for each row
declare
  snaptime_ date := OPL_GETUTCDATE();
begin
  if <PKEQ> then
    update <RLOG> set SNAPTIME = snaptime_, DMLTYPE = ''U'', RLOG_ROWGUID = sys_guid()
       where <OPKCOND>;
    if sql%rowcount = 0 then
      insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
          values(<OPK>, snaptime_, ''U'', sys_guid());
    end if;
    return;
  end if;
  update <RLOG> set SNAPTIME = snaptime_, DMLTYPE = ''D'', RLOG_ROWGUID = sys_guid()
      where <OPKCOND>;
  if sql%rowcount = 0 then
    insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
        values(<OPK>, snaptime_, ''D'', sys_guid());
  end if;
  update <RLOG> set SNAPTIME = snaptime_, DMLTYPE = ''I'', RLOG_ROWGUID = sys_guid()
      where <NPKCOND>;
  if sql%rowcount = 0 then
    insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, RLOG_ROWGUID)
        values(<NPK>, snaptime_, ''I'', sys_guid());
  end if;
end;');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace (stmt, '<TN>', _tbl);
      stmt := replace (stmt, '<RLOG>', rlog);
      stmt := replace (stmt, '<RPK>', rpk);
      stmt := replace (stmt, '<NPK>', npk);
      stmt := replace (stmt, '<NPKCOND>', npkcond);
      stmt := replace (stmt, '<OPK>', opk);
      stmt := replace (stmt, '<OPKCOND>', opkcond);
      stmt := replace (stmt, '<PKEQ>', pkeq);
      --dbg_printf ('stmt: [%s]', stmt);

      stat := '00000';
      msg := '';
      if (0 <> rexecute (_dsn, stmt, stat, msg))
        signal (stat, msg);
      ix := ix + 1;
    }
}
;

--
-- Create snapshot log for DB2
create procedure REPL_CREATE_SL_DB2 (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare ix, len integer;
  declare stmt varchar;
  declare stat, msg varchar;
  declare col any;

  declare rpk, npk, npkcond, opk, opkcond, pkeq, rlog varchar;
  rpk := '';
  npk := '';
  npkcond := '';
  opk := '';
  opkcond := '';
  pkeq := '';
  rlog := quote_dotted (_dsn, concat ('RLOG_', _tbl));

  ix := 0;
  len := length (_pk_cols);
  declare colname, rcolname varchar;
  while (ix < len)
    {
      col := _pk_cols[ix];
      colname := quote_dotted (_dsn, col[0]);
      rcolname := quote_dotted (_dsn, concat ('RLOG_', col[0]));

      rpk := concat (rpk, rcolname);
      npk := concat (npk, 'n_.', colname);
      npkcond := concat (npkcond, rcolname, ' = n_.', colname);
      opk := concat (opk, 'o_.', colname);
      opkcond := concat (opkcond, rcolname, ' = o_.', colname);
      pkeq := concat (pkeq, 'o_.', colname, ' = n_.', colname);

      if (ix < len - 1)
        {
          rpk := concat (rpk, ', ');
          npk := concat (npk, ', ');
          npkcond := concat (npkcond, ' and ');
          opk := concat (opk, ', ');
          opkcond := concat (opkcond, ' and ');
          pkeq := concat (pkeq, ' and ');
        }
      ix := ix + 1;
    }

  -- cleanup and prepare
  declare stmts any;
  stmts := vector (
    'drop trigger "<TN>_I"',
    'drop trigger "<TN>_D"',
    'drop trigger "<TN>_U"',
    'create sequence opl_seq_rowguid cycle');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace (stmt, '<TN>', _tbl);
      --dbg_printf ('stmt [%s]', stmt);
      stat := '00000';
      msg := '';
      rexecute (_dsn, stmt, stat, msg);
      ix := ix + 1;
    }

  -- create triggers;
  stmts := vector (
'create trigger "<TN>_I"
after insert on "<TN>"
referencing new as n_
for each row mode db2sql
begin atomic
  declare ts_ timestamp;
  declare rlog_rowguid_ varchar(255);
  declare rowcount_ integer;

  set ts_ = current timestamp - current timezone;
  set rlog_rowguid_ = current server concat ''@'' concat
      hex(current timestamp) concat hex(nextval for opl_seq_rowguid);

  update <RLOG> set DMLTYPE = ''I'', SNAPTIME = ts_, RLOG_ROWGUID = rlog_rowguid_
      where <NPKCOND>;
  get diagnostics rowcount_ = row_count;
  if rowcount_ = 0 then
    insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
        values (<NPK>, ''I'', ts_, rlog_rowguid_);
  end if;
end
',
'create trigger "<TN>_D"
after delete on "<TN>"
referencing old as o_
for each row mode db2sql
begin atomic
  declare ts_ timestamp;
  declare rlog_rowguid_ varchar(255);
  declare rowcount_ integer;

  set ts_ = current timestamp - current timezone;
  set rlog_rowguid_ = current server concat ''@'' concat
      hex(current timestamp) concat hex(nextval for opl_seq_rowguid);

  update <RLOG> set DMLTYPE = ''D'', SNAPTIME = ts_, RLOG_ROWGUID = rlog_rowguid_
      where <OPKCOND>;
  get diagnostics rowcount_ = row_count;
  if rowcount_ = 0 then
    insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
        values (<OPK>, ''D'', ts_, rlog_rowguid_);
  end if;
end',
'create trigger "<TN>_U"
after update on "<TN>"
referencing old as o_ new as n_
for each row mode db2sql
begin atomic
  declare ts_ timestamp;
  declare rlog_rowguid_ varchar(255);
  declare rowcount_ integer;

  set ts_ = current timestamp - current timezone;
  set rlog_rowguid_ = current server concat ''@'' concat
      hex(current timestamp) concat hex(nextval for opl_seq_rowguid);

  if <PKEQ> then
    update <RLOG> set DMLTYPE = ''U'', SNAPTIME = ts_, RLOG_ROWGUID = rlog_rowguid_
        where <NPKCOND>;
    get diagnostics rowcount_ = row_count;
    if rowcount_ = 0 then
      insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
          values (<NPK>, ''U'', ts_, rlog_rowguid_);
    end if;
  else
    update <RLOG> set DMLTYPE = ''D'', SNAPTIME = ts_, RLOG_ROWGUID = rlog_rowguid_
        where <OPKCOND>;
    get diagnostics rowcount_ = row_count;
    if rowcount_ = 0 then
      insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
          values (<OPK>, ''D'', ts_, rlog_rowguid_);
    end if;

    set rlog_rowguid_ = current server concat ''@'' concat
        hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    update <RLOG> set DMLTYPE = ''I'', SNAPTIME = ts_, RLOG_ROWGUID = rlog_rowguid_
        where <NPKCOND>;
    get diagnostics rowcount_ = row_count;
    if rowcount_ = 0 then
      insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
          values (<NPK>, ''I'', ts_, rlog_rowguid_);
    end if;
  end if;
end');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace (stmt, '<TN>', _tbl);
      stmt := replace (stmt, '<RLOG>', rlog);
      stmt := replace (stmt, '<RPK>', rpk);
      stmt := replace (stmt, '<NPK>', npk);
      stmt := replace (stmt, '<NPKCOND>', npkcond);
      stmt := replace (stmt, '<OPK>', opk);
      stmt := replace (stmt, '<OPKCOND>', opkcond);
      stmt := replace (stmt, '<PKEQ>', pkeq);
      --dbg_printf ('stmt: [%s]', stmt);

      stat := '00000';
      msg := '';
      if (0 <> rexecute (_dsn, stmt, stat, msg))
        signal (stat, msg);
      ix := ix + 1;
    }
}
;

--
-- Create snapshot log for Informix
create procedure REPL_CREATE_SL_INFORMIX (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare p_paramdef, p_oparamdef, p_param, p_oparam varchar;
  declare p_rpk, p_pkcond, p_pkeq, p_old, p_new varchar;
  p_paramdef := '';
  p_oparamdef := '';
  p_param := '';
  p_oparam := '';
  p_rpk := '';
  p_pkcond := '';
  p_pkeq := '';
  p_old := '';
  p_new := '';

  declare _col any;
  declare _ix, _len integer;
  declare param, oparam, rcol, systype varchar;
  _ix := 0;
  _len := length (_pk_cols);
  while (_ix < _len)
    {
      _col := _pk_cols[_ix];
      param := _col[0];
      oparam := concat ('old_', _col[0]);
      rcol := concat ('RLOG_', _col[0]);
      systype := REPL_REMOTE_COLTYPE (_dbms_name, _col, _remote_types);

      p_paramdef := concat (p_paramdef, param, ' ', systype);
      p_oparamdef := concat (p_oparamdef, oparam, ' ', systype);
      p_param := concat (p_param, param);
      p_oparam := concat (p_oparam, oparam);
      p_rpk := concat (p_rpk, rcol);
      p_pkcond := concat (p_pkcond, rcol, ' = ', param);
      p_pkeq := concat (p_pkeq, oparam, ' = ', param);
      p_old := concat (p_old, 'o.', param);
      p_new := concat (p_new, 'n.', param);

      if (_ix < _len - 1)
        {
          p_paramdef := concat (p_paramdef, ', ');
          p_oparamdef := concat (p_oparamdef, ', ');
          p_param := concat (p_param, ', ');
          p_oparam := concat (p_oparam, ', ');
          p_rpk := concat (p_rpk, ', ');
          p_pkcond := concat (p_pkcond, ' and ');
          p_pkeq := concat (p_pkeq, ' and ');
          p_old := concat (p_old, ', ');
          p_new := concat (p_new, ', ');
        }
      _ix := _ix + 1;
    }

  -- clean up
  declare stmt, _stat, _msg varchar;
  declare stmts any;
  stmts := vector (
'drop procedure <TN>_R_proc',
'drop trigger <TN>_I_log',
'drop trigger <TN>_D_log',
'drop procedure <TN>_U_proc',
'drop trigger <TN>_U_log',
'create sequence opl_seq_rowguid cycle');
  _ix := 0;
  _len := length (stmts);
  while (_ix < _len)
    {
      stmt := stmts[_ix];
      stmt := replace(stmt, '<TN>', _tbl);
      _stat := '00000';
      _msg := '';
      rexecute (_dsn, stmt, _stat, _msg);
      _ix := _ix + 1;
    }

  -- create replication triggers
  stmts := vector (
'create procedure <TN>_R_proc(<PARAMDEF>, p_dmltype char(1))
  define _rlog_rowguid varchar(255);
  select to_char(current) || ''-'' || opl_seq_rowguid.nextval into _rlog_rowguid
      from informix.systables where tabid = 1;
  update <RLOG> set DMLTYPE = p_dmltype, SNAPTIME = CURRENT,
      RLOG_ROWGUID = _rlog_rowguid
      where <PKCOND>;
  if dbinfo(''sqlca.sqlerrd2'') = 0 then
    insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
      values(<PARAM>, p_dmltype, CURRENT, _rlog_rowguid);
  end if;
end procedure',
'create trigger <TN>_I_log
insert on <TN>
referencing new as n
for each row
(execute procedure <TN>_R_proc(<NEW>, ''I''))',
'create trigger <TN>_D_log
delete on <TN>
referencing old as o
for each row
(execute procedure <TN>_R_proc(<OLD>, ''D''))',
'create procedure <TN>_U_proc(<OPARAMDEF>, <PARAMDEF>)
  if <PKEQ> then
    call <TN>_R_proc(<PARAM>, ''U'');
  else
    call <TN>_R_proc(<OPARAM>, ''D'');
    call <TN>_R_proc(<PARAM>, ''I'');
  end if;
end procedure',
'create trigger <TN>_U_log
update on <TN>
referencing old as o new as n
for each row
(execute procedure <TN>_U_proc(<OLD>, <NEW>))');
  _ix := 0;
  _len := length (stmts);
  while (_ix < _len)
    {
      stmt := stmts[_ix];
      stmt := replace(stmt, '<TN>', _tbl);
      stmt := replace(stmt, '<RLOG>',
          quote_dotted (_dsn, concat ('RLOG_', _tbl)));
      stmt := replace(stmt, '<PARAMDEF>', p_paramdef);
      stmt := replace(stmt, '<OPARAMDEF>', p_oparamdef);
      stmt := replace(stmt, '<PARAM>', p_param);
      stmt := replace(stmt, '<OPARAM>', p_oparam);
      stmt := replace(stmt, '<RPK>', p_rpk);
      stmt := replace(stmt, '<PKCOND>', p_pkcond);
      stmt := replace(stmt, '<PKEQ>', p_pkeq);
      stmt := replace(stmt, '<OLD>', p_old);
      stmt := replace(stmt, '<NEW>', p_new);
      --dbg_printf ('stmt: [%s]', stmt);

      _stat := '00000';
      _msg := '';
      if (0 <> rexecute (_dsn, stmt, _stat, _msg))
        signal (_stat, _msg);
      _ix := _ix + 1;
    }
}
;

create procedure repl_create_snapshot_log (in _src_table varchar)
{
  declare src_table, dest_table, _part2 varchar;
  declare n_rows integer;

  declare _col_name, _rcol_name, _col_type, pk_cols, rpk_col_names varchar;
  declare upd_condition, old_pk_col_names, new_pk_col_names, stmt varchar;
  declare inx, len integer;

  src_table := complete_table_name (_src_table, 1);
  _part2 := name_part (src_table, 2);
  dest_table := sprintf('%s.%s.RLOG_%s',
      name_part (src_table, 0), name_part (src_table, 1), _part2);

  select count(*) into n_rows from DB.DBA.SYS_COLS where upper("TABLE") = upper(dest_table);
  if (n_rows > 0)
    {
      if (n_rows < 4)
	signal('SLOG1', sprintf('Destination log table %s already exists and does not look like snapshot log', dest_table));
      else
	return;
    }

  declare _cols, _col any;
  _cols := REPL_PK_COLS (src_table);
  inx := 0;
  len := length (_cols);
  if (len = 0)
    signal('SLOG2', sprintf('The table ''%s'' does not exist or does not have primary key', src_table));

  -- check if source table is attached
  declare _dsn varchar;
  declare _dbms_name varchar;
  declare _remote_types any;
  _dsn := null;
  _dbms_name := null;
  _remote_types := null;
  whenever not found goto nf;
  select RT_DSN into _dsn from SYS_REMOTE_TABLE where RT_NAME = src_table;
  _dbms_name := get_keyword (17, vdd_dsn_info(_dsn), '');
  _remote_types := REPL_REMOTE_TYPES (_dsn, _dbms_name);
nf:

  pk_cols := '';
  rpk_col_names := '';
  old_pk_col_names := '';
  new_pk_col_names := '';
  upd_condition := '';
  while (inx < len)
    {
      _col := aref (_cols, inx);
      if (_col[1] = 128)
        _col := vector(_col[0], 211, _col[2], _col[3]);
      if (_dsn is null)
        {
          _col_name := sprintf ('"%I"', _col[0]);
          _rcol_name := sprintf ('"RLOG_%I"', _col[0]);
          _col_type := REPL_COLTYPE (_col);
        }
      else
        {
          _col_name := quote_dotted (_dsn, _col[0]);
          _rcol_name := quote_dotted (_dsn, concat ('RLOG_', _col[0]));
          _col_type := REPL_REMOTE_COLTYPE (_dbms_name, _col, _remote_types);
        }

      pk_cols := concat(pk_cols, _rcol_name, ' ', _col_type, ' not null');
      rpk_col_names := concat(rpk_col_names, _rcol_name);
      old_pk_col_names := concat(old_pk_col_names, '_O.', _col_name);
      new_pk_col_names := concat(new_pk_col_names, '_N.', _col_name);
      upd_condition := concat(upd_condition,
          '_O.', _col_name, ' = _N.', _col_name);

      if (inx + 1 < len)
	{
	  pk_cols := concat(pk_cols, ', ');
	  rpk_col_names := concat(rpk_col_names, ', ');
	  old_pk_col_names := concat(old_pk_col_names, ', ');
	  new_pk_col_names := concat(new_pk_col_names, ', ');
	  upd_condition := concat(upd_condition, ' and ');
	}
      inx := inx + 1;
    }

  declare _stat, _msg varchar;
  declare _stmt varchar;

  -- create rplog table
  declare _rptbl varchar;
  _rptbl := sprintf ('%s.%s.RPLOG_%s',
       name_part (src_table, 0), name_part (src_table, 1), _part2);
  _stmt := sprintf ('drop table %s', REPL_FQNAME (_rptbl));
  _stat := '00000';
  _msg := '';
  exec (_stmt, _stat, _msg);

  _stmt := sprintf ('create table %s (
    TARGET varchar,
    RLOG_ROWGUID varchar,
    SNAPTIME datetime,
    primary key (TARGET, RLOG_ROWGUID)
)',
      REPL_FQNAME (_rptbl));
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg))
    signal (_stat, _msg);

  -- create rlog table
  declare _dt_datetime, _dt_varchar varchar;
  declare _fq_tbl, _fq_dtbl varchar;
  declare _rc integer;
  declare commands any;

  if (_dsn is null)
    {
      _dt_datetime := 'datetime';
      _dt_varchar := 'varchar';
      _fq_tbl := REPL_FQNAME (src_table);
      _fq_dtbl := REPL_FQNAME (dest_table);
    }
  else
    {
      _dt_datetime := get_keyword(11, _remote_types);   -- SQL_DATETIME
      _dt_varchar := get_keyword(12, _remote_types);    -- SQL_VARCHAR
      _fq_tbl := quote_dotted (_dsn, _part2);
      _fq_dtbl := quote_dotted (_dsn, name_part (dest_table, 2));

      _stmt := concat ('drop table ', _fq_dtbl);
      --dbg_printf ('stmt: [%s]', _stmt);
      _stat := '00000';
      _msg := '';
      rexecute (_dsn, _stmt, _stat, _msg);
      --dbg_printf ('result: [%s] [%s]', _stat, _msg);
    }
  _stmt :=
'create table <RLOG> (
    <RPKDEF>,
    SNAPTIME <DATETIME>,
    DMLTYPE <VARCHAR>(1),
    RLOG_ROWGUID <VARCHAR>(255),
    primary key (<RPK>)
)';
  _stmt := replace (_stmt, '<RLOG>', _fq_dtbl);
  _stmt := replace (_stmt, '<RPKDEF>', pk_cols);
  _stmt := replace (_stmt, '<DATETIME>', _dt_datetime);
  _stmt := replace (_stmt, '<VARCHAR>', _dt_varchar);
  _stmt := replace (_stmt, '<RPK>', rpk_col_names);
  --dbg_printf ('stmt: [%s]', _stmt);
  _stat := '00000';
  _msg := '';
  if (_dsn is null)
    _rc := exec (_stmt, _stat, _msg);
  else
    {
      _rc := rexecute (_dsn, _stmt, _stat, _msg);
      if (_rc = 0)
        {
          REPL_ENSURE_TABLE_ATTACHED (
              _dsn, name_part (dest_table, 2), dest_table);
        }
    }
  if (_rc <> 0)
    signal (_stat, _msg);

  -- call DBMS-specific trigger generating procedure
  if (_dsn is null or strstr(_dbms_name, 'Virtuoso') is not null)
    goto local_or_native_tbl;
  else if (strstr (_dbms_name, 'SQL Server') is not null or
      strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
    REPL_CREATE_SL_MSSQL (_dsn, _part2, _cols, _dbms_name, _remote_types);
  else if (strstr (upper(_dbms_name), 'ORACLE') is not null)
    REPL_CREATE_SL_ORACLE (_dsn, _part2, _cols, _dbms_name, _remote_types);
  else if (strstr (_dbms_name, 'DB2') is not null)
    REPL_CREATE_SL_DB2 (_dsn, _part2, _cols, _dbms_name, _remote_types);
  else if (strstr (_dbms_name, 'Informix') is not null)
    REPL_CREATE_SL_INFORMIX (_dsn, _part2, _cols, _dbms_name, _remote_types);
  else
    {
      signal (
          '22023',
          sprintf ('Snapshot replication from remote database type ''%s'' is not supported', _dbms_name),
          'TR141');
    }
  return;

local_or_native_tbl:
  commands := vector (
'create trigger "<STB1>_<STB2>_<STB3>_I_log" before insert on <STB> order 1
    referencing new as _N
{
  insert replacing <DTB> (<DPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
      values (<STB_NEW_PK>, ''I'', DB.DBA.REPL_GETDATE(), uuid());
}',
'create trigger "<STB1>_<STB2>_<STB3>_D_log" before delete on <STB> order 1
    referencing old as _O
{
  insert replacing <DTB> (<DPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
      values (<STB_OLD_PK>, ''D'', DB.DBA.REPL_GETDATE(), uuid());
}',
'create trigger "<STB1>_<STB2>_<STB3>_U_log" before update on <STB> order 1
    referencing old as _O, new as _N
{
  if (<STB_OLD_NEW_PK_SAME>)
    {
      insert replacing <DTB> (<DPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
          values (<STB_NEW_PK>, ''U'', DB.DBA.REPL_GETDATE(), uuid());
    }
  else
    {
      insert replacing <DTB> (<DPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
          values (<STB_OLD_PK>, ''D'', DB.DBA.REPL_GETDATE(), uuid());
      insert replacing <DTB> (<DPK>, DMLTYPE, SNAPTIME, RLOG_ROWGUID)
          values (<STB_NEW_PK>, ''I'', DB.DBA.REPL_GETDATE(), uuid());
    }
}');
  inx := 0;
  len := length (commands);
  while (inx < len)
    {
       declare command varchar;
       command := aref (commands, inx);
       command := replace (command, '<DTB>', _fq_dtbl);
       command := replace (command, '<STB>', _fq_tbl);
       command := replace (command, '<STB1>', sprintf ('%I', name_part (src_table, 0)));
       command := replace (command, '<STB2>', sprintf ('%I', name_part (src_table, 1)));
       command := replace (command, '<STB3>', sprintf ('%I', _part2));
       command := replace (command, '<DPK>', rpk_col_names);
       command := replace (command, '<STB_OLD_NEW_PK_SAME>', upd_condition);
       command := replace (command, '<STB_OLD_PK>', old_pk_col_names);
       command := replace (command, '<STB_NEW_PK>', new_pk_col_names);
       --dbg_printf ('stmt: [%s]', command);

       _stat := '00000';
       _msg := '';
       if (_dsn is null)
         _rc := exec (command, _stat, _msg);
       else
         _rc := rexecute (_dsn, command, _stat, _msg);
       if (_rc <> 0)
         signal (_stat, _msg);
       inx := inx + 1;
    }
}
;


create procedure repl_drop_snapshot_log (in _src_table varchar)
{
  declare src_table, dest_table, _rptbl varchar;
  declare state, message varchar;
  declare n_rows integer;

  src_table := complete_table_name(_src_table, 1);
  dest_table := sprintf('%s.%s.RLOG_%s',
		  name_part(src_table, 0),
		  name_part(src_table, 1),
		  name_part(src_table, 2));
  _rptbl := sprintf('%s.%s.RPLOG_%s',
		  name_part(src_table, 0),
		  name_part(src_table, 1),
		  name_part(src_table, 2));

  select count(*) into n_rows from DB.DBA.SYS_COLS where upper("TABLE") = upper(dest_table);
  if (n_rows = 0)
    signal('DSL01', sprintf('The table ''%s'' does not have a snapshot log', src_table));

  select count(*) into n_rows from DB.DBA.SYS_REMOTE_TABLE where upper(RT_NAME) = upper(src_table);
  if (n_rows = 0)
    {

      exec (sprintf('drop trigger "%I_%I_%I_I_log"',
	    name_part(src_table, 0), name_part(src_table, 1), name_part(src_table, 2)),
	  state, message, vector(), 0, null, null);

      exec (sprintf('drop trigger "%I_%I_%I_U_log"',
	    name_part(src_table, 0), name_part(src_table, 1), name_part(src_table, 2)),
	  state, message, vector(), 0, null, null);

      exec (sprintf('drop trigger "%I_%I_%I_D_log"',
	    name_part(src_table, 0), name_part(src_table, 1), name_part(src_table, 2)),
	  state, message, vector(), 0, null, null);
    }
  commit work;
  exec (sprintf('drop table %s', REPL_FQNAME (dest_table)), state, message);
  exec (sprintf ('drop table %s', REPL_FQNAME (_rptbl)), state, message);
}
;


create procedure repl_refresh_noninc_snapshot (in _name varchar)
{
  declare _sn_query, _sn_target, _sn_src_table, _sn_last_upd_bm varchar;
  declare _sn_is_incremental, ret integer;
  declare name, upd_proc_cmd varchar;

  name := complete_table_name(_name, 1);

  whenever not found goto snapshot_not_found;
  declare cr cursor for select SN_QUERY, SN_NAME, SN_IS_INCREMENTAL, SN_SOURCE_TABLE, SN_LAST_UPD_BM
      from SYS_SNAPSHOT
      where upper(SN_NAME) = upper(name);

  open cr (exclusive, prefetch 1);
  fetch cr
      into _sn_query, _sn_target, _sn_is_incremental, _sn_src_table, _sn_last_upd_bm;

  if (_sn_last_upd_bm is not null)
    _sn_last_upd_bm := deserialize (_sn_last_upd_bm);
  whenever not found default;
  if (_sn_last_upd_bm is null)
    {
      exec (sprintf('delete from %s', REPL_FQNAME (_sn_target)),
	  null, null, vector(), 0, null, null);
    }

  upd_proc_cmd := sprintf ('select %s (?)', REPL_FQNAME (
      sprintf ('DB..REPL_GET_NEXT_CHUNK_%s_%s_%s',
          name_part (_sn_target, 0),
          name_part (_sn_target, 1),
          name_part (_sn_target, 2))));
  while (1)
    {
      --dbg_obj_print ('next bm', _sn_last_upd_bm);
      exec (upd_proc_cmd, NULL, NULL, vector (_sn_last_upd_bm), 1, NULL, ret);
      _sn_last_upd_bm := aref (aref (ret, 0), 0);
      if (_sn_last_upd_bm is not null)
        update DB.DBA.SYS_SNAPSHOT set SN_LAST_UPD_BM = serialize (_sn_last_upd_bm) where current of cr;
      else
        update DB.DBA.SYS_SNAPSHOT set SN_LAST_UPD_BM = NULL where current of cr;
      close cr;
      commit work;
      if (_sn_last_upd_bm is null)
	goto done;
      else
	{
	  open cr (exclusive, prefetch 1);
	  fetch cr into _sn_query, _sn_target, _sn_is_incremental, _sn_src_table, _sn_last_upd_bm;
	  if (_sn_last_upd_bm is not null)
	    _sn_last_upd_bm := deserialize (_sn_last_upd_bm);
	}
    }
done:

  registry_set(sprintf ('REPL_COUNT_%s_%s_%s',
      name_part (_sn_target, 0), name_part (_sn_target, 1), name_part (_sn_target, 2)),'');

  if (_sn_is_incremental is not null)
    {
      declare log_table varchar;
      declare max_rs any;
      log_table := sprintf('"%I"."%I"."RLOG_%I"',
	      name_part(_sn_src_table, 0),
	      name_part(_sn_src_table, 1),
	      name_part(_sn_src_table, 2));
      max_rs := null;
      exec(sprintf('select max(SNAPTIME) from %s', log_table),
	  null, null, vector(), 1, null, max_rs);
      if (isarray (max_rs))
        max_rs := aref(aref(max_rs, 0), 0);
      if (isnull (max_rs) or 0 = max_rs)
        max_rs := REPL_GETDATE(_sn_src_table, 1);
      --dbg_obj_print ('REFRESH_NONINC_SN', max_rs);
      UPDATE DB.DBA.SYS_SNAPSHOT set SN_LAST_TS = max_rs where current of cr;
    }
  close cr;
  return;
snapshot_not_found:
  signal('USN01', sprintf('The snapshot %s is not valid snapshot', name));
}
;


create procedure repl_create_update_proc (
    in _query varchar, in _cols any,
    in _target varchar, in _dsn varchar := null,
    in _how_many integer := 100)
  returns varchar
{
  -- create copy procedure
  declare _stmt varchar;
  declare _stat, _msg varchar;

  declare _pn, _dbms_name varchar;
  _pn := sprintf ('DB..REPL_GET_NEXT_CHUNK_%s_%s_%s',
      name_part (_target, 0), name_part (_target, 1), name_part (_target, 2));
  if (_dsn is null)
    {
      whenever not found goto nf;
      select RT_DSN into _dsn from SYS_REMOTE_TABLE where RT_NAME = _target;
nf:
      ;
    }
  if (_dsn is not null)
    _dbms_name := get_keyword (17, vdd_dsn_info(_dsn), '');
  else
    _dbms_name := null;

  declare _allcols, _allvars, _allvalues, _declare_allvars varchar;
  _allcols := '';
  _allvars := '';
  _allvalues := '';
  _declare_allvars := '';

  declare _col_name varchar;
  declare _col any;
  declare _ix, _len integer;
  _ix := 0;
  _len := length (_cols);
  while (_ix < _len)
    {
      _col := aref (_cols, _ix);
      _col_name := _col[0];
      -- timestamp, date and time become datetime
      if (_col[1] = 128)
        _col[1] := 211;
      -- MS SQL ODBC driver does not implement binding
      -- DATE and TIME values to DATETIME column
      if (_col[1] in (129, 210) and
          (strstr (_dbms_name, 'SQL Server') is not null or
           strstr (_dbms_name, 'S Q L   S e r v e r') is not null))
        _col[1] := 211;

      _allcols := concat (_allcols, sprintf ('"%I"', _col_name));
      _allvars := concat (_allvars, sprintf ('"_%I"', _col_name));
      _declare_allvars := concat (_declare_allvars,
          sprintf ('declare "_%I" ', _col_name), REPL_COLTYPE(_col));
      if (_col_name = 'ROWGUID')
        {
          _allvalues := concat (_allvalues,
              sprintf ('concat (''nolog:'', "_%I")', _col_name));
        }
      else
        _allvalues := concat (_allvalues, sprintf ('"_%I"', _col_name));
      if (_ix < _len - 1)
        {
          _allcols := concat (_allcols, ', ');
          _allvars := concat (_allvars, ', ');
          _allvalues := concat (_allvalues, ', ');
          _declare_allvars := concat (_declare_allvars, ';\n  ');
        }
      _ix := _ix + 1;
    }
  --dbg_obj_print (_allcols);

  _stmt := '
create procedure <FQPN> (in _bm integer, in _how_many integer := <HOW_MANY>)
  returns integer
{
  declare _ix integer;
  <DECLARE_ALLVARS>;
  declare cr dynamic cursor for <QUERY>;
  declare exit handler for not found { return null;  };

  open cr;
  if (_bm is null)
    {
      fetch cr first into <ALLVARS>;
      _ix := 1;
      registry_set(<REG_COUNT_KW>,cast(1 as varchar));
    }
  else
    {
      fetch cr bookmark _bm into <ALLVARS>;
      _ix := 0;
    }
  while (_ix < _how_many)
    {
      insert into <TARGET>(<ALLCOLS>) values(<ALLVALUES>);
      fetch cr into <ALLVARS>;
      _bm := bookmark (cr);
      _ix := _ix + 1;
      registry_set(<REG_COUNT_KW>,cast(cast(registry_get(<REG_COUNT_KW>) as integer) + 1  as varchar));
    }
  return _bm;
}';
  _stmt := replace (_stmt, '<FQPN>', REPL_FQNAME (_pn));
  _stmt := replace (_stmt, '<QUERY>', _query);
  _stmt := replace (_stmt, '<TARGET>', REPL_FQNAME (_target));
  _stmt := replace (_stmt, '<ALLCOLS>', _allcols);
  _stmt := replace (_stmt, '<ALLVARS>', _allvars);
  _stmt := replace (_stmt, '<ALLVALUES>', _allvalues);
  _stmt := replace (_stmt, '<DECLARE_ALLVARS>', _declare_allvars);
  _stmt := replace (_stmt, '<HOW_MANY>', sprintf ('%d', _how_many));
  _stmt := replace (_stmt, '<REG_COUNT_KW>', sprintf ('''REPL_COUNT_%s_%s_%s''',
      name_part (_target, 0), name_part (_target, 1), name_part (_target, 2)));
  --dbg_printf ('stmt: [%s]', _stmt);
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg))
    signal (_stat, _msg);

  return _pn;
}
;

create procedure repl_create_snapshot (in source varchar, in _target varchar)
{
  declare state, message, stmt varchar;
  declare src_comp, target_comp varchar;
  declare n_cols, inx integer;
  declare target varchar;

  target := complete_table_name(_target, 1);

  if (-1 = exec(source, state, message, vector(), 0, src_comp, null))
    signal(state, sprintf('create snapshot : checking source query : %s', message));
  if (aref(src_comp, 1) = 0)
    signal('CRSN1', 'Create snapshot : the source query is not an select statement');

  if (-1 = exec(sprintf('select * from %s where 1 = 0', REPL_FQNAME (target)),
	state, message, vector(), 0, target_comp, null))
    {
      declare _cols, _col any;
      declare _col_name varchar;

      stmt := sprintf('create table %s (', REPL_FQNAME (target));
      _cols := aref (src_comp, 0);
      inx := 0;
      n_cols := length(_cols);
      while (inx < n_cols)
	{
          _col := aref(_cols, inx);
          _col_name := repl_undot_name (aref(_col, 0));

          stmt := concat(stmt,
              sprintf('"%I" ', _col_name), REPL_COLTYPE (_col));

	  if (inx + 1 < n_cols)
	    stmt:= concat(stmt, ', ');
          inx := inx + 1;
	}
      stmt := concat(stmt, ')');
      exec(stmt, null, null, vector(), 0, null, null);
    }
  else if (length(aref(target_comp, 0)) < length(aref(src_comp, 0)))
      signal('CRSN1', 'Create snapshot : the destination table column count is smaller than source');

  repl_create_update_proc (source, src_comp[0], target);
  insert into SYS_SNAPSHOT (SN_NAME, SN_QUERY, SN_LAST_UPD_BM)
      values (target, source, NULL);

  repl_refresh_noninc_snapshot(target);
}
;


create procedure repl_drop_snapshot (in _name varchar, in do_table_delete integer)
{
  declare ss_count, state, message integer;
  declare name varchar;

  name := complete_table_name(_name, 1);
  select count(*) into ss_count from SYS_SNAPSHOT where upper(SN_NAME) = upper(name);

  if (ss_count <> 1)
    signal('DRSN1', sprintf('Drop snapshot : the %s is not a valid snapshot', name));

  --dbg_obj_print (sprintf ('drop procedure DB.."REPL_GET_NEXT_CHUNK_%I_%I_%I"',
--	name_part (name, 0), name_part (name, 1), name_part (name, 2)));
  exec (sprintf ('drop procedure %s', REPL_FQNAME (
              sprintf ('DB..REPL_GET_NEXT_CHUNK_%s_%s_%s',
                  name_part (name, 0),
                  name_part (name, 1),
                  name_part (name, 2)))),
      state, message);
  delete from SYS_SNAPSHOT where upper(SN_NAME) = upper(name);
  if (do_table_delete > 0)
    {
      commit work;
      exec(sprintf('drop table %s', REPL_FQNAME (name)),
	  null, null, vector(), 0, null, null);
    }
}
;


create procedure repl_refresh_inc_snapshot (in _name varchar)
{
  declare _sn_query, _sn_target, _sn_src_table varchar;
  declare _sn_is_incremental integer;
  declare _sn_last_ts datetime;
  declare resultset varchar;
  declare name, log_table, _rptbl varchar;
  declare inx, rc integer;

  name := complete_table_name(_name, 1);
  --dbg_obj_print ('REFRESH_INC', _name, name);

  whenever not found goto snapshot_not_found;

  select SN_QUERY, SN_NAME, SN_IS_INCREMENTAL, SN_LAST_TS, SN_SOURCE_TABLE
      into _sn_query, _sn_target, _sn_is_incremental, _sn_last_ts, _sn_src_table
      from SYS_SNAPSHOT
      where upper(SN_NAME) = upper(name);

  --dbg_obj_print ('START FOR  ', _sn_target);
  if (_sn_is_incremental is null)
    {
      repl_refresh_noninc_snapshot(_name);
      return;
    }

  log_table := sprintf('%s.%s.RLOG_%s',
	  name_part(_sn_src_table, 0),
	  name_part(_sn_src_table, 1),
	  name_part(_sn_src_table, 2));
  _rptbl := sprintf('%s.%s.RPLOG_%s',
	  name_part(_sn_src_table, 0),
	  name_part(_sn_src_table, 1),
	  name_part(_sn_src_table, 2));

  select count(*) into inx from DB.DBA.SYS_COLS where upper("TABLE") = upper(log_table);
  if (inx < 1)
    {
      repl_refresh_noninc_snapshot(_name);
      return;
    }

  declare update_stmt, select_stmt, src_cond varchar;
  declare pk_col_cond, _col_name, pk_cols, pk_col_param_cond, log_pk_cols, log_pk_col_param_cond varchar;
  declare delete_stmt, rplog_stmt varchar;
  declare log_cursor, n_pks, len integer;
  declare log_row, _dmltype, _rowguid varchar;
  declare _snaptime, _lastsnaptime datetime;
  declare insert_stmt, srcdata_select_stmt varchar;
  declare dest_meta, _dest_col_name varchar;
  declare state, message varchar;
  declare params_row, params_row1 varchar;
  declare _stmt varchar;
  declare _cols, _col any;
  declare _params any;

  _cols := REPL_PK_COLS (_sn_src_table);
  n_pks := length (_cols);
  pk_col_cond := '';
  pk_col_param_cond := '';
  log_pk_col_param_cond := '';
  pk_cols := '';
  log_pk_cols := '';
  inx := 0;
  while (inx < n_pks)
    {
      _col := aref (_cols, inx);
      _col_name := aref (_col, 0);

      pk_col_cond := concat(pk_col_cond, sprintf('"RLOG_%I" = "%s"', _col_name, _col_name));
      log_pk_col_param_cond := concat(log_pk_col_param_cond, sprintf('"RLOG_%I" = ?', _col_name));
      pk_col_param_cond := concat(pk_col_param_cond, sprintf('"%I" = ?', _col_name));
      pk_cols := concat(pk_cols, sprintf ('"%I"', _col_name));
      log_pk_cols := concat(log_pk_cols, sprintf('"RLOG_%I"', _col_name));

      if (inx + 1 < n_pks)
	{
	  pk_col_cond := concat(pk_col_cond, ' and ');
	  pk_col_param_cond := concat(pk_col_param_cond, ' and ');
	  log_pk_col_param_cond := concat(log_pk_col_param_cond, ' and ');
	  pk_cols := concat(pk_cols, ', ');
	  log_pk_cols := concat(log_pk_cols, ', ');
	}
      inx := inx + 1;
    }

  delete_stmt := sprintf ('delete from %s where %s',
      REPL_FQNAME (_sn_target), pk_col_param_cond);
  update_stmt := sprintf ('update %s set ',
      REPL_FQNAME (_sn_target));
  insert_stmt := sprintf('insert into %s (',
      REPL_FQNAME (_sn_target));
  _cols := REPL_ALL_COLS (_sn_target);
  declare dest_meta_len integer;
  inx := 0;
  len := length (_cols);
  while (inx < len)
    {
      _col := aref (_cols, inx);
      _col_name := aref (_col, 0);
      update_stmt := concat(update_stmt, sprintf ('"%I" = ?', _col_name));
      insert_stmt := concat(insert_stmt, sprintf ('"%I"', _col_name));
      if (inx + 1 < len)
       {
	  update_stmt := concat(update_stmt, ', ');
	  insert_stmt := concat(insert_stmt, ', ');
       }
      inx := inx + 1;
    }
  update_stmt := concat(update_stmt, ' WHERE (', pk_col_param_cond, ')');
  insert_stmt := concat (insert_stmt, ') values (', repeat('?, ', inx - 1), ' ?)');
  rplog_stmt := sprintf ('insert replacing %s(TARGET, RLOG_ROWGUID, SNAPTIME) values (?, ?, ?)',
      REPL_FQNAME (_rptbl));

  srcdata_select_stmt := _sn_query;

  if (strstr(srcdata_select_stmt, 'WHERE (') > 0)
    srcdata_select_stmt := concat(srcdata_select_stmt, ' and ( ', pk_col_param_cond, ')');
  else
    srcdata_select_stmt := concat(srcdata_select_stmt, ' WHERE ( ', pk_col_param_cond, ')');

  whenever sqlstate '40001' goto deadlock;

start_over:
  log_cursor := null;
  _stmt := sprintf ('select %s, SNAPTIME, DMLTYPE, RLOG_ROWGUID from %s where ',
      log_pk_cols, REPL_FQNAME (log_table));
  if (_sn_last_ts is not null)
    {
      _stmt := concat (_stmt, 'SNAPTIME >= ? and ');
      _params := vector (REPL_STARTTIME (_sn_last_ts));
    }
  else
    _params := vector ();
  _stmt := concat (_stmt,
      sprintf ('not exists (select 1 from %s where TARGET = ? and RLOG_ROWGUID = %s.RLOG_ROWGUID) order by SNAPTIME, %s',
          REPL_FQNAME (_rptbl), REPL_FQNAME (log_table), log_pk_cols));
  _params := vector_concat (_params, vector (_sn_target));
  state := '00000';
  message := '';
  if (0 <> exec (_stmt, state, message, _params, 0, null, null, log_cursor))
    {
      if (state = '40001')
	goto deadlock;
      else
	signal (state, message);
    }

  _lastsnaptime := null;
  while (exec_next(log_cursor, state, message, log_row) = 0)
    {
      _snaptime := log_row[n_pks];
      _dmltype := upper(log_row[n_pks + 1]);
      _rowguid := log_row[n_pks + 2];

      state := '00000';
      message := '';
      if (_lastsnaptime is null)
        {
         --dbg_obj_print ('STARTING with _snaptime= ', _snaptime);
	  _lastsnaptime := _snaptime;
        }
      else if (_lastsnaptime <> _snaptime)
	{
          --dbg_obj_print ('NEW _snaptime= ', _snaptime);
	  update DB.DBA.SYS_SNAPSHOT set SN_LAST_TS = _snaptime where SN_NAME = _sn_target;
	  _sn_last_ts := _snaptime;
          exec_close(log_cursor);
          log_cursor := null;
	  commit work;
	  goto start_over;
	}
      if (0 <> exec (rplog_stmt, state, message, vector (_sn_target, _rowguid, _snaptime)))
        {
	  exec_close (log_cursor);
	  rollback work;
	  return;
        }

      params_row := null;
      if (_dmltype = 'D')
	{
          --dbg_obj_print ('D encountered : ', delete_stmt, log_row);
          rc := exec(delete_stmt, null, null, log_row);
	}
      else if (_dmltype = 'I')
	{
          rc := exec(srcdata_select_stmt, null, null, log_row, 1, null, params_row1);

	  if (rc = 0 and length(params_row1) > 0)
	    {
	      params_row := aref(params_row1, 0);
              --dbg_obj_print (_dmltype , ' encountered : ', insert_stmt, params_row);
              rc := exec(insert_stmt, state, message, params_row);
              --dbg_obj_print (' INSERT returned : ', rc, ' stat=', state, ' message = ', message);
	      if (0 <> rc)
		{
		  if (state = '40001')
		    goto deadlock;
                  --dbg_obj_print ('I encountered a row in the destination for', log_row, '. Will delete it and restart');
      		  exec_close(log_cursor);
                  log_cursor := null;
                  rollback work;
                  exec(delete_stmt, null, null, log_row);
                  goto start_over;
		}
	    }
	}
      else if (_dmltype = 'U')
	{
          rc := exec(srcdata_select_stmt, null, null, log_row, 1, null, params_row1);

	  if (rc = 0 and length(params_row1) > 0)
	    {
              declare n_affected integer;
              n_affected := 0;
	      params_row := vector_concat(aref(params_row1, 0), log_row);
              --dbg_obj_print (_dmltype , ' encountered : ', update_stmt, params_row);
              exec (update_stmt, NULL, NULL, params_row, 0, NULL, n_affected);
              --dbg_obj_print ('U Updated ', n_affected, ' rows in the ', update_stmt, params_row);
              if (n_affected = 0)
                {
	          params_row := aref(params_row1, 0);
                  --dbg_obj_print (_dmltype , ' encountered : ', insert_stmt, params_row);
                  rc := exec(insert_stmt, NULL, NULL, params_row);
                  --dbg_obj_print ('U Inserted 1 rows in the ', insert_stmt, params_row);
                }
            }
	}
      else
	  signal('REPER', sprintf('Inconsistent snapshot log table. No DMLTYPE %s', _dmltype));
      if (rc <> 0 and rc <> 100)
	{
	  if (log_cursor is not null)
	    {
	      exec_close(log_cursor);
              log_cursor := null;
	      rollback work;
	      return;
	    }
	  if (state = '40001')
	      goto deadlock;
	  else
	      signal(state, message);
	}
next_r:
      ;
    }
  exec_close(log_cursor);
  log_cursor := null;
  --dbg_obj_print (' set last_ts = ', _snaptime, ' for ', _sn_target);
  update DB.DBA.SYS_SNAPSHOT
      set SN_LAST_TS = coalesce (_lastsnaptime, _sn_last_ts, REPL_GETDATE(_sn_src_table, 1))
      where SN_NAME = _sn_target;
  return;

snapshot_not_found:
  signal('UISN1', sprintf('The snapshot %s is not valid incremental snapshot', name));
deadlock:
  if (log_cursor is not null)
    {
      exec_close(log_cursor);
      log_cursor := null;
      rollback work;
      goto start_over;
    }
}
;


create procedure repl_create_inc_snapshot (in non_pk_cols varchar,
    in _source_table varchar, in _filter varchar, in _target varchar)
{
  declare state, message, stmt  varchar;
  declare src_comp, target_comp varchar;
  declare n_cols, inx integer;
  declare src_table, log_table varchar;
  declare target_table, pk_cols, pk_col_names varchar;
  declare _col_name varchar;
  declare source_query varchar;
  declare pk_cols_array, filter varchar;
  declare is_all_table_cols integer;

  src_table := complete_table_name(_source_table, 1);
  target_table := complete_table_name(_target, 1);
  log_table := sprintf('%s.%s.RLOG_%s',
		  name_part(src_table, 0),
		  name_part(src_table, 1),
		  name_part(src_table, 2));
  if (isstring (_filter))
    filter := _filter;
  else
    filter := '';
  select count(*) into n_cols from DB.DBA.SYS_COLS where upper("TABLE") = upper(src_table);
  if (n_cols = 0)
    signal('DISN1', sprintf('the source table %s does not exist', src_table));

  select count(*) into n_cols from DB.DBA.SYS_COLS where upper("TABLE") = upper(log_table);
  if (n_cols = 0)
    signal('DISN2', sprintf('The source table ''%s'' does not have log table %s', src_table, log_table));

  declare _cols, _col any;
  _cols := REPL_PK_COLS (src_table);
  inx := 0;
  n_cols := length (_cols);
  if (n_cols = 0)
    signal('DISN3', sprintf('The table ''%s'' does not exist or does not have primary key', src_table));

  pk_cols := '';
  pk_col_names := '';
  pk_cols_array := null;
  while (inx < n_cols)
    {
      _col := aref (_cols, inx);
      _col_name := aref (_col, 0);

      pk_cols := concat(pk_cols,
          sprintf ('"%I" ', _col_name), REPL_COLTYPE (_col));
      pk_col_names := concat(pk_col_names, sprintf ('"%I"', _col_name));
      if (pk_cols_array is null)
	pk_cols_array := vector(upper(_col_name));
      else
	pk_cols_array := vector_concat(pk_cols_array, vector(upper(_col_name)));

      if (inx + 1 < n_cols)
	{
	  pk_cols := concat(pk_cols, ', ');
	  pk_col_names := concat(pk_col_names, ', ');
	}
      inx := inx + 1;
    }

  if (non_pk_cols is null or isinteger(non_pk_cols) > 0 or strchr(non_pk_cols, '*') is not null)
    {
      is_all_table_cols := 1;
      repl_fill_non_pk_cols(src_table, pk_cols_array, non_pk_cols);
    }
  else
    is_all_table_cols := 0;

  if (is_all_table_cols = 0)
    {
      source_query := sprintf('SELECT %s %s FROM %s %s',
	  pk_col_names,
          either(length(non_pk_cols), sprintf(', %s', non_pk_cols), ''),
          REPL_FQNAME (src_table),
	  either(length(filter), sprintf('WHERE (%s)', filter), ''));
    }
  else
    {
      source_query := sprintf('SELECT * FROM %s %s',
          REPL_FQNAME (src_table),
	  either(length(filter), sprintf('WHERE (%s)', filter), ''));
    }

  exec(source_query, null, null, vector(), 0, src_comp, null);

  if (-1 = exec (sprintf ('select * from %s where 1 = 0', REPL_FQNAME (target_table)),
	state, message, vector(), 0, target_comp, null))
    {
      inx := 0;
      _cols := aref (src_comp, 0);
      n_cols := length(_cols);
      stmt := sprintf ('create table %s (', REPL_FQNAME (target_table));
      while (inx < n_cols)
	{
          _col := aref(_cols, inx);
          _col_name := repl_undot_name(aref(_col, 0));

          if (is_all_table_cols = 0 and
	    inx >= length(pk_cols_array) and
	    position(upper(_col_name), pk_cols_array) > 0)
	    signal('DISN4', sprintf('The column ''%s'' in the source query duplicates a primary key column', _col_name));
          stmt := concat(stmt,
              sprintf ('"%I" ', _col_name), REPL_COLTYPE (_col));

	  if (inx + 1 < n_cols)
	    stmt:= concat(stmt, ',');
          inx := inx + 1;
	}
      stmt := concat(stmt, sprintf(', primary key (%s))', pk_col_names));
      exec(stmt, null, null, vector(), 0, null, null);
    }
  else if (length(aref(target_comp, 0)) < length(aref(src_comp, 0)))
      signal('CRSN1', 'Create snapshot : the destination table column count is smaller than source');

  insert into SYS_SNAPSHOT (SN_NAME, SN_QUERY, SN_IS_INCREMENTAL, SN_SOURCE_TABLE)
      values (target_table, source_query, 1, src_table);

  repl_create_update_proc (source_query, src_comp[0], target_table);
  repl_refresh_noninc_snapshot(target_table);

  --
  -- init rplog
  declare _stmt, _stat, _msg varchar;
  declare _rplog_tbl, _rlog_tbl varchar;
  _rplog_tbl := sprintf ('"%I"."%I"."RPLOG_%I"',
      name_part (src_table, 0), name_part (src_table, 1), name_part (src_table, 2));
  _rlog_tbl := sprintf ('"%I"."%I"."RLOG_%I"',
      name_part (src_table, 0), name_part (src_table, 1), name_part (src_table, 2));

  declare _dsn varchar;
  _dsn := null;
  declare exit handler for not found { goto nf; };
  select RT_DSN into _dsn from SYS_REMOTE_TABLE where RT_NAME = src_table;
nf:

  _stmt := sprintf ('insert replacing %s(TARGET, RLOG_ROWGUID, SNAPTIME) select ?, RLOG_ROWGUID, SNAPTIME from %s where SNAPTIME > ?',
      _rplog_tbl, _rlog_tbl);
  --dbg_printf ('stmt: [%s]', _stmt);
  _stat := '';
  _msg := '00000';
  if (0 <> exec (_stmt, _stat, _msg, vector (target_table, REPL_PURGE_STARTTIME (REPL_GETDATE(_dsn)))))
    signal (_stat, _msg);

  if (not exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'purge_rplogs'))
    {
      insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
          values ('purge_rplogs', now (), 30, 'DB.DBA.REPL_PURGE_RPLOGS ()');
    }
}
;


create procedure repl_fill_non_pk_cols (in src_table varchar,
    inout pk_cols_array varchar, out non_pk_cols varchar)
{
  declare cr cursor for
      select
          sc."COLUMN"
      from
	  DB.DBA.SYS_COLS sc
      where
          upper(sc."TABLE") = upper(src_table) and
	  sc."COLUMN" <> '_IDN'
      order by
          sc.COL_ID;
  declare _column, _non_pk_cols varchar;

  whenever not found goto done;
  open cr;
  _non_pk_cols := '';
  while (1)
    {
      fetch cr into _column;
      if (0 = position(upper(_column), pk_cols_array))
	{
	  if (length(_non_pk_cols) > 0)
	    _non_pk_cols := concat(_non_pk_cols, ', ');

          _non_pk_cols := concat(_non_pk_cols, sprintf ('"%I"', _column));
	}
    }
done:
  close cr;
  non_pk_cols := _non_pk_cols;
}
;


create procedure repl_purge_snapshot_log (in _src_table varchar)
{
  declare src_table, dest_table, stmt varchar;
  declare _n_repls integer;
  declare _min_last_ts datetime;

  src_table := complete_table_name(_src_table, 1);
  dest_table := sprintf('%s.%s.RLOG_%s',
		  name_part(src_table, 0),
		  name_part(src_table, 1),
		  name_part(src_table, 2));

  select count(*), min(SN_LAST_TS)
      into _n_repls, _min_last_ts
      from SYS_SNAPSHOT
      where upper(SN_SOURCE_TABLE) = upper(src_table) and
            SN_LAST_TS is not null;

  if (_n_repls > 0 and _min_last_ts is not null)
    {
      stmt := sprintf('delete from %s where SNAPTIME < ?',
          REPL_FQNAME (dest_table));
      exec(stmt, null, null, vector(REPL_STARTTIME(_min_last_ts)));
    }
}
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

create procedure REPL_COLTYPE_PS (
    in _coltype varchar,
    in _col_dtp integer, in _col_prec integer, in _col_scale integer)
  returns varchar
{
  if ((_col_dtp = 181 or _col_dtp = 182 or _col_dtp = 192 or
       _col_dtp = 222 or _col_dtp = 225)
      and _col_prec is not null and _col_prec <> 0)
    {
      -- (length) for char or varchar
      declare _pos integer;
      declare _len_spec varchar;
      _pos := strstr (_coltype, '()');
      _len_spec := sprintf ('(%d)', _col_prec);
      if (_pos is null)
        _coltype := concat (_coltype, _len_spec);
      else
        {
          declare _prefix, _suffix varchar;
          _prefix := subseq (_coltype, 0, _pos);
          _suffix := subseq (_coltype, _pos + 2);
          _coltype := concat (_prefix, _len_spec, _suffix);
        }
    }
  else if (_col_dtp = 219)
    {
      -- (prec, scale) for numeric
      if (_col_prec < _col_scale)
        _col_scale := 0;
      _coltype := concat (_coltype, sprintf('(%d, %d)', _col_prec, _col_scale));
    }
  return _coltype;
}
;

create procedure REPL_COLTYPE (in _col any) returns varchar
{
  declare _col_dtp, _col_prec, _col_scale integer;
  _col_dtp := aref (_col, 1);
  _col_scale := aref (_col, 2);
  _col_prec := aref (_col, 3);

  if (_col_dtp = 219)
    {
      if (_col_scale > 15)
	_col_scale := 15;
      if (_col_prec > 40)
	_col_prec := 40;
    }
  return REPL_COLTYPE_PS (
      dv_type_title(_col_dtp), _col_dtp, _col_prec, _col_scale);
}
;

create procedure REPL_ENSURE_MAPPING (
    inout _remote_types any, in _sql_dtp integer, in _type_title varchar)
  returns integer
{
  if (get_keyword(_sql_dtp, _remote_types) is null)
    {
      _remote_types := vector_concat (_remote_types,
          vector (_sql_dtp, _type_title));
      return 1;
    }
  return 0;
}
;

create procedure REPL_OVERRIDE_MAPPING (
    inout _remote_types any, in _sql_dtp integer, in _type_title varchar)
{
  if (0 <> REPL_ENSURE_MAPPING (_remote_types, _sql_dtp, _type_title))
    return;

  declare _ix, _len integer;
  _ix := 0;
  _len := length (_remote_types);
  while (_ix < _len)
    {
      if (_sql_dtp = _remote_types[_ix])
        {
          _remote_types[_ix + 1] := _type_title;
          return;
        }
      _ix := _ix + 2;
    }
}
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
      REPL_ENSURE_MAPPING (_remote_types, _type_info[1], _type_info[0]);
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

create procedure REPL_REMOTE_COLTYPE (in _dbms_name varchar, in _col any, in _remote_types any)
{
  declare _col_type varchar;
  declare _col_dtp, _col_prec, _col_scale integer;
  _col_dtp := aref (_col, 1);
  _col_scale := aref (_col, 2);
  _col_prec := aref (_col, 3);

  -- Oracle number(38, 0) becomes integer
  --if (_col_dtp = 219 and
  --    _col_prec = 38 and (_col_scale is null or _col_scale = 0))
  --  _col_dtp := 189;
  -- timestamp becomes datetime
  if (_col_dtp = 128)
    _col_dtp := 211;

  declare _col_sql_type varchar;
  _col_sql_type := dv_to_sql_type (_col_dtp);
  _col_type := get_keyword (_col_sql_type, _remote_types);
  if (_col_type is null)
    {
      _col_dtp := 181;
      _col_type := 'char';
      _col_prec := 255;
    }
  if (_col_sql_type = 12 and _col_dtp not in (181, 182)) -- SQL_VARCHAR / DV_LONG_STRING / DV_SHORT_STRING_SERIAL
    { -- this is a catch-all type, so will map it to VARCHAR
      log_message (concat ('Changing column type ', dv_type_title (_col_dtp), ' to ', _col_type,
		' when creating the destination snapshot replication table on ', _dbms_name));
      _col_dtp := 181;
      _col_prec := 0;
    }
  -- specify length for char, varchar, nvarchar or varbinary without limit
  if ((_col_dtp = 181 or _col_dtp = 182 or _col_dtp = 192 or
       _col_dtp = 222 or _col_dtp = 225) and
      (_col_prec is null or _col_prec = 0))
    {
      if (strstr (_dbms_name, 'Virtuoso') is not null)
	{
          --dbg_printf ('col_prec: Virtuoso');
          ;
	}
      else if (strstr (_dbms_name, 'SQL Server') is not null or
          strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
        {
          if (_col_dtp = 222)
            {
              -- varbinary
              _col_prec := 8000;
            }
          else if (_col_dtp = 225)
            {
              -- nvarchar
              _col_prec := 4000;
            }
          else
            {
              -- char/varchar
              _col_prec := 8000;
            }
        }
      else if (strstr (upper (_dbms_name), 'ORACLE') is not null)
        {
          if (_col_dtp = 222)
            {
              -- raw
              _col_prec := 2000;
            }
          else if (_col_dtp = 225)
            {
              -- nvarchar2
              _col_prec := 4000;
            }
          else
            {
              -- varchar, 2000 for char
              _col_prec := 4000;
            }
        }
      else if (strstr (_dbms_name, 'DB2') is not null)
        {
          -- actual limit is 32672, but the whole limit on the row is 32677
          _col_prec := 32000; -- varchar, 254 for char
        }
      else if (strstr (_dbms_name, 'Informix') is not null)
        {
          if (_col_dtp = 222)
            {
              -- length is not needed for BLOB
              ;
            }
          else
            {
              -- nvarchar, varchar, 32767 for char
              _col_prec := 254;
            }
        }
      else
        {
          -- reasonable default
          _col_prec := 255;
          --dbg_printf ('col_prec: Non-Virtuoso: [%d]', _col_prec);
        }
    }
  -- length is not needed for Informix BLOB mapped from SQL_VARBINARY
  if (_col_dtp = 222 and strstr (_dbms_name, 'Informix') is not null)
    _col_prec := null;
  -- decimal
  if (_col_dtp = 219)
    {
      if (strstr (_dbms_name, 'Virtuoso') is not null)
        {
          if (_col_scale > 15)
	    _col_scale := 15;
          if (_col_prec > 40)
            _col_prec := 40;
        }
      else if (strstr (_dbms_name, 'SQL Server') is not null or
          strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
        {
          if (_col_prec > 38)
            _col_prec := 38;
        }
      else if (strstr (upper (_dbms_name), 'ORACLE') is not null)
        {
          if (_col_prec > 38)
            _col_prec := 38;
        }
      else if (strstr (_dbms_name, 'Informix') is not null)
        {
          if (_col_prec > 32)
            _col_prec := 32;
        }
      else if (strstr (_dbms_name, 'DB2') is not null)
        {
          if (_col_prec > 31)
            _col_prec := 31;
        }
    }
  return REPL_COLTYPE_PS (_col_type, _col_dtp, _col_prec, _col_scale);
}
;

create procedure REPL_PK_COLS (in _tbl varchar)
{
  declare cr_pk cursor for
      select
          sc."COLUMN",
          sc."COL_DTP",
	  sc."COL_SCALE",
	  sc."COL_PREC"
      from
          DB.DBA.SYS_KEYS k,
	  DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS sc
      where
          upper(k.KEY_TABLE) = upper(_tbl) and
	  __any_grants(k.KEY_TABLE) and
	  k.KEY_IS_MAIN = 1 and
	  k.KEY_MIGRATE_TO is NULL and
	  kp.KP_KEY_ID = k.KEY_ID and
	  kp.KP_NTH < k.KEY_DECL_PARTS and
	  sc.COL_ID = kp.KP_COL
          and sc."COLUMN" <> '_IDN'
      order by
          kp.KP_NTH;
  declare _pk_cols any;
  declare _col_name varchar;
  declare _col_dtp, _col_scale, _col_prec integer;

  _pk_cols := vector ();
  open cr_pk;
  whenever not found goto done;
  while (1)
    {
      fetch cr_pk into _col_name, _col_dtp, _col_scale, _col_prec;
      _col_name := repl_undot_name (_col_name);
      _pk_cols := vector_concat (
          _pk_cols, vector (vector (_col_name, _col_dtp, _col_scale, _col_prec)));
    }
done:
  close cr_pk;
  return _pk_cols;
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
  if (0 <> exec(_stmt, _stat, _msg, vector(), 0, _src_comp, null))
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
-- add ROWGUID varchar if publication is updateable and such
-- column does not exist yet
create procedure REPL_ENSURE_ROWGUID (
    in _tbl varchar, in _len integer, in _prepend_name integer,
    in _col_name varchar := 'ROWGUID')
{
  declare _stat, _msg varchar;

  declare _col_dtp, _col_prec integer;
  whenever not found goto alter_table;
  select "COL_DTP", "COL_PREC" into _col_dtp, _col_prec
      from DB.DBA.SYS_KEY_COLUMNS
      where upper("KEY_TABLE") = upper(_tbl) and
      upper("COLUMN") = upper(_col_name);
  if (_col_dtp <> 182)
    {
      signal ('37000',
          sprintf ('Table already has %s column of incompatible data type',
              _col_name),
          'TR081');
    }
  if (_col_prec > 0 and _col_prec < _len)
    {
      signal ('37000',
          sprintf ('Table already has %s column with insufficient width',
              _col_name),
          'TR082');
    }
  goto fill_data;

alter_table:
  declare alter_stmt varchar;
  alter_stmt := sprintf (
      'alter table %s add column %s varchar(%d)',
      REPL_FQNAME (_tbl), _col_name, _len);
  --dbg_obj_print('alter stmt: ', alter_stmt);
  _stat := '00000';
  _msg := '';
  if (0 <> exec (alter_stmt, _stat, _msg))
    signal (_stat, _msg);

fill_data:
  declare _val varchar;
  if (_prepend_name <> 0)
    _val := 'concat (repl_this_server(), ''@'', uuid())';
  else
    _val := 'uuid()';
  declare update_stmt varchar;
  update_stmt := sprintf (
      'update %s set %s = case when %s is null then %s else %s end WHERE %s is null',
      REPL_FQNAME (_tbl), _col_name, _col_name, _val, _col_name, _col_name);
  --dbg_printf('update stmt: [%s]', update_stmt);
  _stat := '00000';
  _msg := '';
  if (0 <> exec (update_stmt, _stat, _msg))
    signal (_stat, _msg);
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

--
-- Create updateable snapshot log for MS SQL Server
create procedure REPL_CREATE_USL_MSSQL (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare _part2 varchar;
  _part2 := name_part (_tbl, 2);

  declare _stat, _msg varchar;

  declare _pkcols, _rpkcols, _pkcond, _rpkcond varchar;
  declare _pkvars, _declare_pkvars, _updcol varchar;
  _pkcols := '';
  _rpkcols := '';
  _pkcond := '';
  _rpkcond := '';
  _pkvars := '';
  _declare_pkvars := '';
  _updcol := '';

  declare _col any;
  declare _col_name, _rcol_name, _pkvar varchar;
  declare _ix, _len integer;
  _ix := 0;
  _len := length (_pk_cols);
  while (_ix < _len)
    {
      _col := _pk_cols[_ix];
      _col_name := quote_dotted (_dsn, _col[0]);
      _rcol_name := quote_dotted (_dsn, concat ('RLOG_', _col[0]));
      _pkvar := concat ('@_', _col[0]);

      _pkcols := concat (_pkcols, _col_name);
      _rpkcols := concat (_rpkcols, _rcol_name);
      _pkcond := concat (_pkcond, _col_name, ' = ', _pkvar);
      _rpkcond := concat (_rpkcond, _rcol_name, ' = ', _pkvar);
      _pkvars := concat (_pkvars, _pkvar);
      _declare_pkvars := concat (_declare_pkvars,
          'declare ', _pkvar, ' ',
          REPL_REMOTE_COLTYPE (_dbms_name, _col, _remote_types));

      if (_ix < _len - 1)
        {
          _pkcols := concat (_pkcols, ', ');
          _rpkcols := concat (_rpkcols, ', ');
          _pkcond := concat (_pkcond, ' and ');
          _rpkcond := concat (_rpkcond, ' and ');
          _pkvars := concat (_pkvars, ', ');
          _declare_pkvars := concat (_declare_pkvars, ';\n');
        }
      _ix := _ix + 1;
    }

  declare _cols any;
  _cols := REPL_ALL_COLS(_tbl);
  _ix := 0;
  _len := length (_cols);
  while (_ix < _len)
    {
      _col := _cols[_ix];
      _col_name := quote_dotted (_dsn, _col[0]);
      if (_col[0] <> 'ROWGUID')
        {
          if (length (_updcol) <> 0)
            _updcol := concat (_updcol, ' or ');
          _updcol := concat (_updcol, sprintf (' update(%s)', _col_name));
        }
      _ix := _ix + 1;
    }

  declare _trig_i, _trig_u, _trig_d varchar;
  _trig_i := quote_dotted (_dsn, concat (_part2, '_I_log'));
  _trig_u := quote_dotted (_dsn, concat (_part2, '_U_log'));
  _trig_d := quote_dotted (_dsn, concat (_part2, '_D_log'));

  -- clean up
  declare _stmts any;
  declare _stmt varchar;
  _stmts := vector (
    'drop trigger <TRIG_I>',
    'drop trigger <TRIG_U>',
    'drop trigger <TRIG_D>');
  _ix := 0;
  _len := length (_stmts);
  while (_ix < _len)
    {
      _stmt := _stmts[_ix];
      _stmt := replace (_stmt, '<TRIG_I>', _trig_i);
      _stmt := replace (_stmt, '<TRIG_U>', _trig_u);
      _stmt := replace (_stmt, '<TRIG_D>', _trig_d);
      _stat := '00000';
      _msg := '';
      rexecute (_dsn, _stmt, _stat, _msg);
      _ix := _ix + 1;
    }

  _stmts := vector (
    -- insert trigger
'create trigger <TRIG_I> on <TN> after insert as
begin
  set nocount on;

  <DECLARE_PKVARS>;
  declare @rowguid varchar(255);
  declare @rlog_rowguid varchar(255);

  declare cr cursor local for select <PKCOLS>, ROWGUID from inserted;
  open cr;
  fetch cr into <PKVARS>, @rowguid;
  while @@FETCH_STATUS = 0
    begin
      if charindex(''nolog:'', @rowguid) = 1
        begin
          update <TN> set ROWGUID = substring(@rowguid, 7, 255)
              where <PKCOND>;
          goto next_row;
        end

      if charindex(''raw:'', @rowguid) = 1
        set @rowguid = substring(@rowguid, 5, 255);
      else
        set @rowguid = @@servername + ''@'' + cast (newid() as varchar(255));
      update <TN> set ROWGUID = @rowguid where <PKCOND>;

      set @rlog_rowguid = cast (newid() as varchar(255));
      update <RLOG> set SNAPTIME = getutcdate(), DMLTYPE = ''I'',
          OLD_ROWGUID = null, RLOG_ROWGUID = @rlog_rowguid
          where <RPKCOND>
      if @@ROWCOUNT = 0
        begin
          insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
    	      values (<PKVARS>, getutcdate(), ''I'', null, @rlog_rowguid);
        end

next_row:
      fetch cr into <PKVARS>, @rowguid;
    end
  close cr;
  deallocate cr;
end',
    -- update trigger
'create trigger <TRIG_U> on <TN> after update as
begin
  set nocount on;

  <DECLARE_PKVARS>;
  declare @rowguid varchar(255);
  declare @rlog_rowguid varchar(255);

  declare cr cursor local for select <PKCOLS>, ROWGUID from inserted;
  open cr;
  fetch cr into <PKVARS>, @rowguid;
  while @@FETCH_STATUS = 0
    begin
      if <UPDCOL>
        begin
          declare @old_rowguid varchar(255);

          if charindex(''nolog:'', @rowguid) = 1
            begin
              update <TN> set ROWGUID = substring(@rowguid, 7, 255)
                  where <PKCOND>;
              goto next_row;
            end

          if charindex(''raw:'', @rowguid) = 1
            set @rowguid = substring(@rowguid, 5, 255);
          else
            set @rowguid = @@servername + ''@'' + cast (newid() as varchar(255));
          update <TN> set ROWGUID = @rowguid where <PKCOND>;

          select @old_rowguid = ROWGUID from deleted WHERE <PKCOND>;
          set @rlog_rowguid = cast (newid() as varchar(255));
          update <RLOG> set SNAPTIME = getutcdate(), DMLTYPE = ''U'',
              OLD_ROWGUID = @old_rowguid, RLOG_ROWGUID = @rlog_rowguid
              where <RPKCOND>
          if @@ROWCOUNT = 0
            begin
              insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
      	        values (<PKVARS>, getutcdate(), ''U'', @old_rowguid, @rlog_rowguid);
            end
        end
      else if charindex(''delete:'', @rowguid) = 1
        delete from <TN> where <PKCOND>;

next_row:
      fetch cr into <PKVARS>, @rowguid;
    end
  close cr;
  deallocate cr;
end',
    -- delete trigger
'create trigger <TRIG_D> on <TN> after delete as
begin
  set nocount on;

  <DECLARE_PKVARS>;
  declare @rowguid varchar(255);
  declare @rlog_rowguid varchar(255);

  declare cr cursor local for select <PKCOLS>, ROWGUID from deleted;
  open cr;
  fetch cr into <PKVARS>, @rowguid;
  while @@FETCH_STATUS = 0
    begin
      if charindex(''delete:'', @rowguid) = 1
        begin
          set @rowguid = substring(@rowguid, 8, 255);
          if charindex(''nolog:'', @rowguid) = 1
            set @rowguid = null;
          else if charindex(''raw:'', @rowguid) = 1
            set @rowguid = substring(@rowguid, 5, 255);
          else
            set @rowguid = @@servername + ''@'' + cast (newid() as varchar(255));
        end
      if @rowguid is not null
        begin
          set @rlog_rowguid = cast (newid() as varchar(255));
          update <RLOG>
              set SNAPTIME = getutcdate(), DMLTYPE = ''D'',
              OLD_ROWGUID = @rowguid, RLOG_ROWGUID = @rlog_rowguid
              where <RPKCOND>;
          if @@ROWCOUNT = 0
            begin
              insert into <RLOG>(<RPKCOLS>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
                  values (<PKVARS>, getutcdate(), ''D'', @rowguid, @rlog_rowguid);
            end
        end
      fetch cr into <PKVARS>, @rowguid;
    end
  close cr;
  deallocate cr;
end');
  _ix := 0;
  _len := length (_stmts);
  while (_ix < _len)
    {
      _stmt := _stmts[_ix];
      _stmt := replace (_stmt, '<TRIG_I>', _trig_i);
      _stmt := replace (_stmt, '<TRIG_U>', _trig_u);
      _stmt := replace (_stmt, '<TRIG_D>', _trig_d);
      _stmt := replace (_stmt, '<DECLARE_PKVARS>', _declare_pkvars);
      _stmt := replace (_stmt, '<PKVARS>', _pkvars);
      _stmt := replace (_stmt, '<PKCOLS>', _pkcols);
      _stmt := replace (_stmt, '<RPKCOLS>', _rpkcols);
      _stmt := replace (_stmt, '<PKCOND>', _pkcond);
      _stmt := replace (_stmt, '<RPKCOND>', _rpkcond);
      _stmt := replace (_stmt, '<UPDCOL>', _updcol);
      _stmt := replace (_stmt, '<RLOG>',
          quote_dotted (_dsn, concat ('RLOG_', _part2)));
      _stmt := replace (_stmt, '<TN>', quote_dotted (_dsn, _part2));
      --dbg_printf ('MSSQL: [%s]', _stmt);

      _stat := '00000';
      _msg := '';
      if (0 <> rexecute (_dsn, _stmt, _stat, _msg))
        signal (_stat, _msg);
      _ix := _ix + 1;
    }
}
;

--
-- Create updateable snapshot log for Oracle
create procedure REPL_CREATE_USL_ORACLE (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare _part2 varchar;
  _part2 := name_part (_tbl, 2);

  declare ix, len integer;
  declare stmt varchar;
  declare stat, msg varchar;
  declare col any;

  declare pk, rpk, opk, opkcond, tpk, tpkcond, updcol, rlog, dlog varchar;
  pk := '';
  rpk := '';
  opk := '';
  opkcond := '';
  tpk := '';
  tpkcond := '';
  updcol := '';
  rlog := quote_dotted (_dsn, concat ('RLOG_', _part2));
  dlog := quote_dotted (_dsn, concat ('DLOG_', _part2));

  ix := 0;
  len := length (_pk_cols);
  declare colname, rcolname varchar;
  while (ix < len)
    {
      col := _pk_cols[ix];
      colname := quote_dotted (_dsn, col[0]);
      rcolname := quote_dotted (_dsn, concat ('RLOG_', col[0]));

      pk := concat (pk, colname);
      rpk := concat (rpk, rcolname);
      opk := concat (opk, ':old.', colname);
      opkcond := concat (opkcond, rcolname, ' = :old.', colname);
      tpk := concat (tpk, 't.', colname);
      tpkcond := concat (tpkcond, rcolname, ' = t.', colname);

      if (ix < len - 1)
        {
          pk := concat (pk, ', ');
          rpk := concat (rpk, ', ');
          opk := concat (opk, ', ');
          opkcond := concat (opkcond, ' and ');
          tpk := concat (tpk, ', ');
          tpkcond := concat (tpkcond, ' and ');
        }
      ix := ix + 1;
    }

  declare _cols any;
  _cols := REPL_ALL_COLS(_tbl);
  ix := 0;
  len := length (_cols);
  while (ix < len)
    {
      col := _cols[ix];
      colname := quote_dotted (_dsn, col[0]);
      -- skip DV_BLOB, DV_BLOB_BIN, DV_BLOB_WIDE, DV_BLOB_XPER
      -- because Oracle does not allows blob columns in UPDATE OF
      if (col[0] <> 'ROWGUID' and col[1] not in (125, 131, 132, 134))
        {
          if (length (updcol) <> 0)
            updcol := concat (updcol, ', ');
          updcol := concat (updcol, colname);
        }
      ix := ix + 1;
    }

  -- cleanup and prepare
  declare stmts any;
  stmts := vector (
      'drop table <DLOG>',
      'create or replace function OPL_GETUTCDATE return date is
begin
  return cast (localtimestamp at time zone ''00:00'' as date);
end;');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace(stmt, '<DLOG>', dlog);
      stat := '00000';
      msg := '';
      rexecute (_dsn, stmt, stat, msg);
      ix := ix + 1;
    }

  -- create triggers;
  stmts := vector (
    -- dlog
'create global temporary table <DLOG>(
    r ROWID,
    dmltype char(1),
    old_rowguid varchar2(255)
) on commit delete rows',
    -- insert(R) trigger
'create or replace trigger "<TN>_IR_log" after insert on "<TN>"
for each row
begin
  -\-dbms_output.put_line(''after insert trigger(R)'');
  insert into <DLOG>(r, dmltype) values(:new.rowid, ''I'');
end;',
    -- insert trigger
'create or replace trigger "<TN>_I_log" after insert on "<TN>"
declare
  cursor c is
      select <PK>, ROWGUID, d.r as ROWID_
      from "<TN>", <DLOG> d
      where "<TN>".rowid = d.r and d.dmltype = ''I'';
  r varchar2(255);
begin
  -\-dbms_output.put_line(''after insert trigger'');
  -\- read dlog
  for t in c loop
    -\- nolog
    if substr(t.ROWGUID, 1, 6) = ''nolog:'' then
      update "<TN>" set ROWGUID = substr(t.ROWGUID, 7) where rowid = t.ROWID_;
      goto next_t;
    end if;

    -\- raw
    if substr(t.ROWGUID, 1, 4) = ''raw:'' then
      r := substr(t.ROWGUID, 5);
    else
      select global_name || ''@'' || sys_guid() into r from global_name;
    end if;
    update "<TN>" set ROWGUID = r where rowid = t.ROWID_;

    -\- update rlog
    update <RLOG> set SNAPTIME = OPL_GETUTCDATE(), DMLTYPE = ''I'',
        OLD_ROWGUID = null, RLOG_ROWGUID = sys_guid()
        where <TPKCOND>;
    if sql%rowcount = 0 then
      insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
          values(<TPK>, OPL_GETUTCDATE(), ''I'', null, sys_guid());
    end if;

<<next_t>>
    null;
  end loop;

  -\- clean up dlog
  delete from <DLOG> where dmltype = ''I'';
end;',
    -- update(R) trigger
'create or replace trigger "<TN>_UR_log" after update of <UPDCOL> on "<TN>"
for each row
begin
  -\-dbms_output.put_line(''after update trigger(R)'');
  insert into <DLOG>(r, dmltype, old_rowguid)
      values(:new.rowid, ''U'', :old.ROWGUID);
end;',
    -- update trigger
'create or replace trigger "<TN>_U_log" after update of <UPDCOL> on "<TN>"
declare
  cursor c is
      select <PK>, ROWGUID, d.r as ROWID_, d.old_rowguid as OLD_ROWGUID_
      from "<TN>", <DLOG> d
      where "<TN>".rowid = d.r and d.dmltype = ''U'';
  r varchar2(255);
begin
  -\-dbms_output.put_line(''after update trigger'');
  -\- read dlog
  for t in c loop
    -\- nolog
    if substr(t.ROWGUID, 1, 6) = ''nolog:'' then
      update "<TN>" set ROWGUID = substr(t.ROWGUID, 7) where rowid = t.ROWID_;
      goto next_t;
    end if;

    -\- raw
    if substr(t.ROWGUID, 1, 4) = ''raw:'' then
      r := substr(t.ROWGUID, 5);
    else
      select global_name || ''@'' || sys_guid() into r from global_name;
    end if;
    update "<TN>" set ROWGUID = r where rowid = t.ROWID_;

    -\- update rlog
    update <RLOG> set SNAPTIME = OPL_GETUTCDATE(), DMLTYPE = ''U'',
        OLD_ROWGUID = t.OLD_ROWGUID_, RLOG_ROWGUID = sys_guid()
        where <TPKCOND>;
    if sql%rowcount = 0 then
      insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
          values(<TPK>, OPL_GETUTCDATE(), ''U'', t.OLD_ROWGUID_, sys_guid());
    end if;

<<next_t>>
    null;
  end loop;

  -\- clean up dlog
  delete from <DLOG> where dmltype = ''U'';
end;',
    -- update/delete(R) trigger
'create or replace trigger "<TN>_UDR_log" after update of ROWGUID on "<TN>"
for each row
begin
  -\-dbms_output.put_line(''after update/delete trigger(R)'');
  if substr(:new.ROWGUID, 1, 7) = ''delete:'' then
    insert into <DLOG>(r, dmltype) values(:new.rowid, ''R'');
  end if;
end;',
    -- update/delete trigger
'create or replace trigger "<TN>_UD_log" after update of ROWGUID on "<TN>"
declare
  cursor c is
      select <PK>, ROWGUID, d.r as ROWID_
      from "<TN>", <DLOG> d
      where "<TN>".rowid = d.r and d.dmltype = ''R'';
begin
  -\-dbms_output.put_line(''after update/delete trigger'');
  -\- read dlog
  for t in c loop
    delete from "<TN>" where rowid = t.ROWID_;
  end loop;

  -\- clean up dlog
  delete from <DLOG> where dmltype = ''R'';
end;',
    -- delete trigger
'create or replace trigger "<TN>_D_log" after delete on "<TN>"
for each row
declare
  r varchar2(255);
begin
  -\-dbms_output.put_line(''delete trigger'');
  r := :old.ROWGUID;
  if substr(r, 1, 7) = ''delete:'' then
    r := substr(r, 8);
    if substr(r, 1, 6) = ''nolog:'' then
      r := null;
    elsif substr(r, 1, 4) = ''raw:'' then
      r := substr(r, 5);
    else
      select global_name || ''@'' || sys_guid() into r from global_name;
    end if;
  end if;

  if r is not null then
    -\- update rlog
    update <RLOG> set SNAPTIME = OPL_GETUTCDATE(), DMLTYPE = ''D'',
       OLD_ROWGUID = r, RLOG_ROWGUID = sys_guid()
       where <OPKCOND>;
    if sql%rowcount = 0 then
      insert into <RLOG>(<RPK>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
          values(<OPK>, OPL_GETUTCDATE(), ''D'', r, sys_guid());
    end if;
  end if;
end;');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace (stmt, '<TN>', _part2);
      stmt := replace (stmt, '<RLOG>', rlog);
      stmt := replace (stmt, '<DLOG>', dlog);
      stmt := replace (stmt, '<PK>', pk);
      stmt := replace (stmt, '<OPK>', opk);
      stmt := replace (stmt, '<RPK>', rpk);
      stmt := replace (stmt, '<TPK>', tpk);
      stmt := replace (stmt, '<OPKCOND>', opkcond);
      stmt := replace (stmt, '<TPKCOND>', tpkcond);
      stmt := replace (stmt, '<UPDCOL>', updcol);
      --dbg_printf ('stmt: [%s]', stmt);

      stat := '00000';
      msg := '';
      if (0 <> rexecute (_dsn, stmt, stat, msg))
        signal (stat, msg);
      ix := ix + 1;
    }
}
;

--
-- Create updateable snapshot log for DB2
create procedure REPL_CREATE_USL_DB2 (
    in _dsn varchar, in _tbl varchar, in _pk_cols any,
    in _dbms_name varchar, in _remote_types any)
{
  declare _part2 varchar;
  _part2 := name_part (_tbl, 2);

  declare ix, len integer;
  declare stmt varchar;
  declare stat, msg varchar;
  declare col any;

  declare rpk, npk, npkcond, opk, opkcond, tnpkcond, updcol, rlog varchar;
  rpk := '';
  npk := '';
  npkcond := '';
  opk := '';
  opkcond := '';
  tnpkcond := '';
  updcol := '';
  rlog := quote_dotted (_dsn, concat ('RLOG_', _part2));

  ix := 0;
  len := length (_pk_cols);
  declare colname, rcolname varchar;
  while (ix < len)
    {
      col := _pk_cols[ix];
      colname := quote_dotted (_dsn, col[0]);
      rcolname := quote_dotted (_dsn, concat ('RLOG_', col[0]));

      rpk := concat (rpk, rcolname);
      npk := concat (npk, 'n_.', colname);
      npkcond := concat (npkcond, rcolname, ' = n_.', colname);
      opk := concat (opk, 'o_.', colname);
      opkcond := concat (opkcond, rcolname, ' = o_.', colname);
      tnpkcond := concat (tnpkcond, colname, ' = n_.', colname);

      if (ix < len - 1)
        {
          rpk := concat (rpk, ', ');
          npk := concat (npk, ', ');
          npkcond := concat (npkcond, ' and ');
          opk := concat (opk, ', ');
          opkcond := concat (opkcond, ' and ');
          tnpkcond := concat (tnpkcond, ' and ');
        }
      ix := ix + 1;
    }

  declare _cols any;
  _cols := REPL_ALL_COLS(_tbl);
  ix := 0;
  len := length (_cols);
  while (ix < len)
    {
      col := _cols[ix];
      colname := quote_dotted (_dsn, col[0]);
      if (col[0] <> 'ROWGUID')
        {
          if (length (updcol) <> 0)
            updcol := concat (updcol, ', ');
          updcol := concat (updcol, colname);
        }
      ix := ix + 1;
    }

  -- cleanup and prepare
  declare stmts any;
  stmts := vector (
    'drop trigger "<TN>_I"',
    'drop trigger "<TN>_U"',
    'drop trigger "<TN>_UD"',
    'drop trigger "<TN>_D"');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace (stmt, '<TN>', _part2);
      --dbg_printf ('stmt [%s]', stmt);
      stat := '00000';
      msg := '';
      rexecute (_dsn, stmt, stat, msg);
      ix := ix + 1;
    }

  -- create triggers;
  stmts := vector (
    -- insert trigger
'create trigger "<TN>_I"
after insert on "<TN>"
referencing new as n_
for each row mode db2sql
begin atomic
  declare ts_ timestamp;
  declare rowguid_ varchar(255);
  declare rlog_rowguid_ varchar(255);
  declare rowcount_ integer;

  if left(n_.ROWGUID, 6) = ''nolog:'' then
    update "<TN>" set ROWGUID = substr(n_.ROWGUID, 7) where <TNPKCOND>;
  else
    if left(n_.ROWGUID, 4) = ''raw:'' then
      set rowguid_ = substr(n_.ROWGUID, 5);
    else
      set rowguid_ = current server concat ''@'' concat
          hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    end if;
    update "<TN>" set ROWGUID = rowguid_ where <TNPKCOND>;

    set ts_ = current timestamp - current timezone;
    set rlog_rowguid_ = current server concat ''@'' concat
        hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    update <RLOG> set DMLTYPE = ''I'', SNAPTIME = ts_,
        OLD_ROWGUID = null, RLOG_ROWGUID = rlog_rowguid_
        where <NPKCOND>;
    get diagnostics rowcount_ = row_count;
    if rowcount_ = 0 then
      insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, OLD_ROWGUID, RLOG_ROWGUID)
          values (<NPK>, ''I'', ts_, null, rlog_rowguid_);
    end if;
  end if;
end',
    -- update trigger
'create trigger "<TN>_U"
after update of <UPDCOL> on "<TN>"
referencing old as o_ new as n_
for each row mode db2sql
begin atomic
  declare ts_ timestamp;
  declare rowguid_ varchar(255);
  declare rlog_rowguid_ varchar(255);
  declare rowcount_ integer;

  if left(n_.ROWGUID, 6) = ''nolog:'' then
    update "<TN>" set ROWGUID = substr(n_.ROWGUID, 7) where <TNPKCOND>;
  else
    if left(n_.ROWGUID, 4) = ''raw:'' then
      set rowguid_ = substr(n_.ROWGUID, 5);
    else
      set rowguid_ = current server concat ''@'' concat
          hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    end if;
    update "<TN>" set ROWGUID = rowguid_ where <TNPKCOND>;

    set ts_ = current timestamp - current timezone;
    set rlog_rowguid_ = current server concat ''@'' concat
        hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    update <RLOG> set DMLTYPE = ''U'', SNAPTIME = ts_,
        OLD_ROWGUID = o_.ROWGUID, RLOG_ROWGUID = rlog_rowguid_
        where <NPKCOND>;
    get diagnostics rowcount_ = row_count;
    if rowcount_ = 0 then
      insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, OLD_ROWGUID, RLOG_ROWGUID)
          values (<NPK>, ''U'', ts_, o_.ROWGUID, rlog_rowguid_);
    end if;
  end if;
end',
    -- update/delete trigger
'create trigger "<TN>_UD"
after update of ROWGUID on "<TN>"
referencing new as n_
for each row mode db2sql
begin atomic
  if left(n_.ROWGUID, 7) = ''delete:'' then
    delete from "<TN>" where <TNPKCOND>;
  end if;
end',
    -- delete trigger
'create trigger "<TN>_D"
after delete on "<TN>"
referencing old as o_
for each row mode db2sql
begin atomic
  declare ts_ timestamp;
  declare rowguid_ varchar(255);
  declare rlog_rowguid_ varchar(255);
  declare rowcount_ integer;

  set rowguid_ = o_.ROWGUID;
  if left(rowguid_, 7) = ''delete:'' then
    set rowguid_ = substr(rowguid_, 8);
    if left(rowguid_, 6) = ''nolog:'' then
      set rowguid_ = null;
    elseif left(rowguid_, 4) = ''raw:'' then
      set rowguid_ = substr(rowguid_, 5);
    else
      set rowguid_ = current server concat ''@'' concat
          hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    end if;
  end if;

  if rowguid_ is not null then
    set ts_ = current timestamp - current timezone;
    set rlog_rowguid_ = current server concat ''@'' concat
        hex(current timestamp) concat hex(nextval for opl_seq_rowguid);
    update <RLOG> set DMLTYPE = ''D'', SNAPTIME = ts_,
        OLD_ROWGUID = rowguid_, RLOG_ROWGUID = rlog_rowguid_
        where <OPKCOND>;
    get diagnostics rowcount_ = row_count;
    if rowcount_ = 0 then
      insert into <RLOG>(<RPK>, DMLTYPE, SNAPTIME, OLD_ROWGUID, RLOG_ROWGUID)
          values (<OPK>, ''D'', ts_, rowguid_, rlog_rowguid_);
    end if;
  end if;
end');
  ix := 0;
  len := length (stmts);
  while (ix < len)
    {
      stmt := stmts[ix];
      stmt := replace (stmt, '<TN>', _part2);
      stmt := replace (stmt, '<RLOG>', rlog);
      stmt := replace (stmt, '<RPK>', rpk);
      stmt := replace (stmt, '<NPK>', npk);
      stmt := replace (stmt, '<NPKCOND>', npkcond);
      stmt := replace (stmt, '<OPK>', opk);
      stmt := replace (stmt, '<OPKCOND>', opkcond);
      stmt := replace (stmt, '<TNPKCOND>', tnpkcond);
      stmt := replace (stmt, '<UPDCOL>', updcol);
      --dbg_printf ('stmt: [%s]', stmt);

      stat := '00000';
      msg := '';
      if (0 <> rexecute (_dsn, stmt, stat, msg))
        signal (stat, msg);
      ix := ix + 1;
    }
}
;

--
-- Create updateable snapshot for specified table
create procedure REPL_CREATE_UPDATEABLE_SNAPSHOT_LOG (in _tbl varchar)
{
  _tbl := complete_table_name(_tbl, 1);
  declare _cols any;
  declare _len integer;
  _cols := REPL_PK_COLS (_tbl);
  _len := length (_cols);
  if (_len = 0)
    {
      signal('22023',
          sprintf('The table ''%s'' does not exist or does not have primary key', _tbl),
          'TR129');
    }

  declare _col_name, _rcol_name, _col_type varchar;
  declare _rpk, _rpk_def, _npk, _npkcond, _opk varchar;
  declare _col any;
  declare _ix integer;
  declare _rc integer;
  declare _cmds any;

  -- check if source table is attached
  declare _dsn varchar;
  declare _dbms_name varchar;
  declare _remote_types any;
  _dsn := null;
  _dbms_name := null;
  _remote_types := null;
  whenever not found goto nf;
  select RT_DSN into _dsn from SYS_REMOTE_TABLE where RT_NAME = _tbl;
  _dbms_name := get_keyword (17, vdd_dsn_info(_dsn), '');
  _remote_types := REPL_REMOTE_TYPES (_dsn, _dbms_name);
  --dbg_printf ('remote types:');
  --dbg_obj_print (_remote_types);
nf:

  _ix := 0;
  _rpk := '';
  _rpk_def := '';
  _npk := '';
  _npkcond := '';
  _opk := '';
  while (_ix < _len)
    {
      _col := _cols[_ix];
      if (_col[1] = 128)
        {
          signal ('22023',
              sprintf ('Can not create updateable snapshot log for table ''%s'' because primary key column ''%s'' has ''timestamp'' datatype',
                  _tbl, _col[0]),
              'TR144');
        }

      if (_dsn is null)
        {
          _col_name := sprintf ('"%I"', _col[0]);
          _rcol_name := sprintf ('"RLOG_%I"', _col[0]);
          _col_type := REPL_COLTYPE (_col);
        }
      else
        {
          _col_name := quote_dotted (_dsn, _col[0]);
          _rcol_name := quote_dotted (_dsn, concat ('RLOG_', _col[0]));
          _col_type := REPL_REMOTE_COLTYPE (_dbms_name, _col, _remote_types);
        }
      _rpk := concat (_rpk, _rcol_name);
      _rpk_def := concat (_rpk_def, _rcol_name, ' ', _col_type, ' not null');
      _npk := concat (_npk, concat ('_N.', _col_name));
      _npkcond := concat (_npkcond, _col_name, ' = _N.', _col_name);
      _opk := concat (_opk, concat ('_O.', _col_name));
      if (_ix + 1 < _len)
	{
	  _rpk := concat(_rpk, ', ');
	  _rpk_def := concat(_rpk_def, ', ');
	  _npk := concat(_npk, ', ');
          _npkcond := concat (_npkcond, ' and ');
	  _opk := concat(_opk, ', ');
	}
      _ix := _ix + 1;
    }

  -- create rlog table
  declare _dt_datetime, _dt_varchar varchar;
  declare _stat, _msg varchar;
  declare _stmt varchar;
  declare _part2, _rlog_tbl, _fq_tbl, _fq_rlog_tbl varchar;
  _part2 := name_part (_tbl, 2);
  _rlog_tbl := sprintf ('%s.%s.RLOG_%s',
      name_part(_tbl, 0), name_part(_tbl, 1), _part2);
  if (_dsn is null)
    {
      _dt_datetime := 'datetime';
      _dt_varchar := 'varchar';
      _fq_tbl := REPL_FQNAME (_tbl);
      _fq_rlog_tbl := REPL_FQNAME (_rlog_tbl);

      REPL_ENSURE_ROWGUID (_tbl, 255, 1);
    }
  else
    {
      _dt_datetime := get_keyword(11, _remote_types);   -- SQL_DATETIME
      _dt_varchar := get_keyword(12, _remote_types);    -- SQL_VARCHAR
      _fq_tbl := quote_dotted (_dsn, _part2);
      _fq_rlog_tbl := quote_dotted (_dsn, name_part (_rlog_tbl, 2));

      _stmt := concat ('drop table ', _fq_rlog_tbl);
      --dbg_printf ('stmt: [%s]', _stmt);
      _stat := '00000';
      _msg := '';
      rexecute (_dsn, _stmt, _stat, _msg);
      --dbg_printf ('result: [%s] [%s]', _stat, _msg);
    }
  if (_dsn is not null or
      not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = _rlog_tbl))
    {
      _stmt :=
'create table <RLOG> (
    <RPKDEF>,
    SNAPTIME <DATETIME>,
    DMLTYPE <VARCHAR>(1),
    OLD_ROWGUID <VARCHAR>(255),
    RLOG_ROWGUID <VARCHAR>(255),
    primary key (<RPK>)
)';
      _stmt := replace (_stmt, '<RLOG>', _fq_rlog_tbl);
      _stmt := replace (_stmt, '<RPKDEF>', _rpk_def);
      _stmt := replace (_stmt, '<DATETIME>', _dt_datetime);
      _stmt := replace (_stmt, '<VARCHAR>', _dt_varchar);
      _stmt := replace (_stmt, '<RPK>', _rpk);
      --dbg_printf ('stmt: [%s]', _stmt);
      _stat := '00000';
      _msg := '';
      if (_dsn is null)
        _rc := exec (_stmt, _stat, _msg);
      else
        {
          _rc := rexecute (_dsn, _stmt, _stat, _msg);
          if (_rc = 0)
            {
              REPL_ENSURE_TABLE_ATTACHED (
                  _dsn, name_part (_rlog_tbl, 2), _rlog_tbl);
            }
        }
      if (_rc <> 0)
        signal (_stat, _msg);
    }
  else
    {
      REPL_ENSURE_ROWGUID (_rlog_tbl, 255, 0, 'RLOG_ROWGUID');
      REPL_ENSURE_ROWGUID (_rlog_tbl, 255, 0, 'OLD_ROWGUID');
    }

  -- call DBMS-specific trigger generating procedure
  if (_dsn is null or strstr (_dbms_name, 'Virtuoso') is not null)
    goto local_or_native_tbl;
  if (strstr (_dbms_name, 'SQL Server') is not null or
      strstr (_dbms_name, 'S Q L   S e r v e r') is not null)
    REPL_CREATE_USL_MSSQL (_dsn, _tbl, _cols, _dbms_name, _remote_types);
  else if (strstr (upper (_dbms_name), 'ORACLE') is not null)
    REPL_CREATE_USL_ORACLE (_dsn, _tbl, _cols, _dbms_name, _remote_types);
  else if (strstr (_dbms_name, 'DB2') is not null)
    REPL_CREATE_USL_DB2 (_dsn, _tbl, _cols, _dbms_name, _remote_types);
  else
    {
      signal (
          '22023',
          sprintf ('Bidirectional snapshot replication to remote database type ''%s'' is not supported', _dbms_name),
          'TR140');
    }
  return;

local_or_native_tbl:
  _cmds := vector (
      -- insert trigger
'create trigger "<TN1>_<TN2>_<TN3>_I_log" after insert on <FQTN> order 199
    referencing new as _N
{
  --dbg_printf(''SNP insert trigger, _N.ROWGUID: [%s]'', _N.ROWGUID);
  set triggers off;
  if (0 = strstr (_N.ROWGUID, ''nolog:''))
    {
      update <FQTN> set ROWGUID = subseq (_N.ROWGUID, 6) where <NPKCOND>;
      return;
    }
  if (0 = strstr (_N.ROWGUID, ''raw:''))
    _N.ROWGUID := subseq (_N.ROWGUID, 4);
  else
    _N.ROWGUID := concat (repl_this_server(), ''@'', uuid());
  --dbg_printf(''INSERT: _N.ROWGUID: [%s]'', _N.ROWGUID);
  update <FQTN> set ROWGUID = _N.ROWGUID where <NPKCOND>;
  insert replacing <RLOG> (<RPK>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
      values (<NPK>, DB.DBA.REPL_GETDATE(), ''I'', null, uuid());
}',
      -- update trigger
'create trigger "<TN1>_<TN2>_<TN3>_U_log" after update on <FQTN> order 199
    referencing old as _O, new as _N
{
  --dbg_printf(''SNP update trigger, _N.ROWGUID: [%s]'', _N.ROWGUID);
  if (0 = strstr (_N.ROWGUID, ''delete:''))
    {
      delete from <FQTN> where <NPKCOND>;
      return;
    }
  set triggers off;
  if (0 = strstr (_N.ROWGUID, ''nolog:''))
    {
      update <FQTN> set ROWGUID = subseq (_N.ROWGUID, 6) where <NPKCOND>;
      return;
    }
  declare _old_rowguid varchar;
  _old_rowguid := _O.ROWGUID;
  if (0 = strstr (_N.ROWGUID, ''raw:''))
    _N.ROWGUID := subseq (_N.ROWGUID, 4);
  else
    _N.ROWGUID := concat (repl_this_server(), ''@'', uuid());
  --dbg_printf(''UPDATE: _N.ROWGUID: [%s], _old_rowguid: [%s]'', _N.ROWGUID, _old_rowguid);
  update <FQTN> set ROWGUID = _N.ROWGUID where <NPKCOND>;
  insert replacing <RLOG> (<RPK>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
      values (<NPK>, DB.DBA.REPL_GETDATE(), ''U'', _old_rowguid, uuid());
}',
      -- delete trigger
'create trigger "<TN1>_<TN2>_<TN3>_D_log" after delete on <FQTN> order 199
    referencing old as _O
{
  declare _rowguid varchar;
  _rowguid := _O.ROWGUID;
  --dbg_printf(''SNP delete trigger: _rowguid: [%s]'', _rowguid);
  if (0 = strstr (_rowguid, ''delete:''))
    {
      _rowguid := subseq (_rowguid, 7);
      if (0 = strstr (_rowguid, ''nolog:''))
        _rowguid := null;
      else if (0 = strstr (_rowguid, ''raw:''))
        _rowguid := subseq (_rowguid, 4);
      else
        _rowguid := concat (repl_this_server(), ''@'', uuid());
    }
  --dbg_printf(''SNP delete trigger: _rowguid: [%s]'', _rowguid);
  if (_rowguid is not null)
    {
      insert replacing <RLOG> (<RPK>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID)
          values (<OPK>, DB.DBA.REPL_GETDATE(), ''D'', _rowguid, uuid());
    }
}');

  _ix := 0;
  _len := length (_cmds);
  while (_ix < _len)
    {
      declare _cmd varchar;
      _cmd := _cmds[_ix];
      _cmd := replace (_cmd, '<RLOG>', _fq_rlog_tbl);
      _cmd := replace (_cmd, '<RPK>', _rpk);
      _cmd := replace (_cmd, '<NPK>', _npk);
      _cmd := replace (_cmd, '<NPKCOND>', _npkcond);
      _cmd := replace (_cmd, '<OPK>', _opk);
      _cmd := replace (_cmd, '<TN1>', sprintf ('%I', name_part (_tbl, 0)));
      _cmd := replace (_cmd, '<TN2>', sprintf ('%I', name_part (_tbl, 1)));
      _cmd := replace (_cmd, '<TN3>', sprintf ('%I', name_part (_tbl, 2)));
      _cmd := replace (_cmd, '<FQTN>', _fq_tbl);
      --dbg_printf ('stmt: [%s]', _cmd);
      _stat := '00000';
      _msg := '';
      if (_dsn is null)
        _rc := exec (_cmd, _stat, _msg);
      else
        _rc := rexecute (_dsn, _cmd, _stat, _msg);
      if (_rc <> 0)
        signal (_stat, _msg);
      _ix := _ix + 1;
    }
}
;

DB.DBA.REPL_CREATE_UPDATEABLE_SNAPSHOT_LOG ('WS.WS.SYS_DAV_RES')
;

create table WS.WS.RPLOG_SYS_DAV_RES (
    SOURCE varchar,
    TARGET varchar,
    RLOG_ROWGUID varchar,
    SNAPTIME datetime,
    primary key (SOURCE, TARGET, RLOG_ROWGUID)
)
;

create procedure REPL_CREATE_SNAPSHOT_PUB (in _item varchar, in _type integer)
{
  if (_type = 1)
    _item := REPL_COMPLETE_COLNAME (_item);
  else if (_type = 2)
    _item := complete_table_name (_item, 1);

  --
  -- check that snapshot publication does not exist
  if (exists (select 1 from DB.DBA.SYS_SNAPSHOT_PUB
              where SP_ITEM = _item and SP_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot publication of ''%s'' already exists',
              _item),
          'TR104');
    }

  if (_type = 1)
    {
      -- check that collection exists
      declare _colid integer;
      _colid := DAV_SEARCH_ID (_item, 'c');
      if (_colid < 0)
        {
          signal ('37000',
              sprintf ('Collection ''%s'' does not exist', _item),
              'TR111');
        }
    }
  else if (_type = 2)
    {
      --
      -- create updateable snapshot log and updating procedure
      REPL_CREATE_UPDATEABLE_SNAPSHOT_LOG (_item);
      REPL_CREATE_UPDATE_TABLE_PROC (_item);
    }
  else
    {
      signal ('22023', sprintf ('Invalid type %d', _type), 'TR112');
    }

  --
  -- register snapshot publication
  insert into DB.DBA.SYS_SNAPSHOT_PUB (SP_ITEM, SP_TYPE)
      values (_item, _type);
}
;

create procedure REPL_DROP_SNAPSHOT_PUB (in _item varchar, in _type integer)
{
  if (_type = 1)
    _item := REPL_COMPLETE_COLNAME (_item);
  else if (_type = 2)
    _item := complete_table_name (_item, 1);

  --
  -- check that publication exists
  if (not exists (select 1 from DB.DBA.SYS_SNAPSHOT_PUB
		  where SP_ITEM = _item and SP_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot publication of ''%s'' does not exist',
              _item),
          'TR113');
    }

  --
  -- unsubscribe all the subscribers
  for select SS_SERVER as _server from DB.DBA.SYS_SNAPSHOT_SUB
      where SS_ITEM = _item and SS_TYPE = _type do
    {
      repl_drop_snapshot_sub (_server, _item, _type);
    }

  if (_type = 1)
    {
      ;
    }
  else if (_type = 2)
    {
      --
      -- drop snapshot log
      repl_drop_snapshot_log (_item);
    }
  else
    {
      signal ('22023', sprintf ('Invalid type %d', _type), 'TR114');
    }

  --
  -- unregister snapshot publication
  delete from DB.DBA.SYS_SNAPSHOT_PUB
      where SP_ITEM = _item and SP_TYPE = _type;

  --
  -- clean up scheduled updates
  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = _item;

  --
  -- clean up conflict resolvers
  declare _stat, _msg varchar;
  if (_type = 1)
    {
      for select CR_PROC as _cr_proc from DB.DBA.SYS_DAV_CR where strstr (CR_COL_NAME, _item) = 0 do
        {
          _stat := '00000';
          _msg := '';
          exec (sprintf ('drop procedure %s', REPL_FQNAME (_cr_proc)),
              _stat, _msg);
        }
      delete from DB.DBA.SYS_DAV_CR where strstr (CR_COL_NAME, _item) = 0;
    }
  else if (_type = 2)
    {
      for select CR_PROC as _cr_proc from DB.DBA.SYS_SNAPSHOT_CR where CR_TABLE_NAME = _item do
        {
          _stat := '00000';
          _msg := '';
          exec (sprintf ('drop procedure %s', REPL_FQNAME (_cr_proc)),
              _stat, _msg);
        }
      delete from DB.DBA.SYS_SNAPSHOT_CR where CR_TABLE_NAME = _item;
    }
}
;

create procedure REPL_CREATE_SNAPSHOT_SUB (
  in _server varchar, in _item varchar, in _type integer,
  in _usr varchar, in _pwd varchar)
{
  declare _stat, _msg varchar;

  if (_type = 1)
    _item := REPL_COMPLETE_COLNAME (_item);
  else if (_type = 2)
    _item := complete_table_name (_item, 1);

  --
  -- find dsn and ensure that remote data source is defined
  declare _dsn varchar;
  _dsn := REPL_DSN (_server);
  if (_dsn is null)
    {
      signal ('37000',
          sprintf ('The replication server ''%s'' does not exist',
              _server),
          'TR115');
    }
  if (0 <> REPL_ENSURE_RDS (_dsn, _usr, _pwd))
    {
      signal ('22023', 'User name and password should be supplied when creating subscription of new server', 'TR116');
    }
  if (_server = repl_this_server())
    {
      signal ('22023', 'Can''t replicate into the source server', 'TR117');
    }

  --
  -- check that the item is published
  if (not exists (select 1 from DB.DBA.SYS_SNAPSHOT_PUB
		  where SP_ITEM = _item and SP_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot publication of ''%s'' does not exist',
              _item),
          'TR105');
    }

  --
  -- check that subscription does not exist yet
  if (exists (select 1 from DB.DBA.SYS_SNAPSHOT_SUB
	      where SS_SERVER = _server and SS_ITEM = _item
              and SS_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot subscription of ''%s'' for ''%s'' already exists',
              _server, _item),
          'TR106');
    }

  if (_type = 1)
    {
      ;
    }
  else if (_type = 2)
    {
      --
      -- create a table on remote
      declare _dbms_name varchar;
      _dbms_name := get_keyword (17, vdd_dsn_info(_dsn), '');
      declare _remote_types any;
      _remote_types := REPL_REMOTE_TYPES (_dsn, _dbms_name);
      --dbg_obj_print ('_remote_types', _remote_types);

      declare _pk_cols, _pk_names, _cols, _col any;
      declare _ix, _len integer;
      declare _col_name varchar;
      declare _pk varchar;
      _pk_cols := REPL_PK_COLS (_item);
      _pk_names := vector ();
      _pk := '';
      _ix := 0;
      _len := length (_pk_cols);
      if (_len = 0)
        {
          signal ('22023',
            sprintf ('The table ''%s'' does not exist or does not have primary key', _item),
            'TR130');
        }
      while (_ix < _len)
        {
          _col := _pk_cols[_ix];
          _col_name := _col[0];

          _pk_names := vector_concat (_pk_names, vector (_col_name));
          _pk := concat (_pk, sprintf ('"%I"', _col_name));
          if (_ix < _len - 1)
            _pk := concat (_pk, ', ');
          _ix := _ix + 1;
        }

      _cols := REPL_ALL_COLS (_item);
      _ix := 0;
      _len := length (_cols);
      declare _stmt varchar;
      declare _part2 varchar;
      _part2 := name_part (_item, 2);
      _stmt := sprintf('create table %s (', quote_dotted (_dsn, _part2));
      while (_ix < _len)
        {
          _col := _cols[_ix];
          _col_name := _col[0];

          _stmt := concat (_stmt,
              quote_dotted (_dsn, _col_name),
              ' ',
              REPL_REMOTE_COLTYPE (_dbms_name, _col, _remote_types));
          if (position (_col_name, _pk_names) <> 0)
            _stmt := concat (_stmt, ' not null');
          if (_ix + 1 < _len)
            _stmt:= concat(_stmt, ', ');
          _ix := _ix + 1;
        }
      _stmt := concat(_stmt, sprintf(', primary key (%s))', _pk));
      --dbg_obj_print (_stmt);
      _stat := '00000';
      _msg := '';
      if (rexecute (_dsn, _stmt, _stat, _msg) <> 0)
        signal (_stat, _msg);
      declare _att_tbl varchar;
      _att_tbl := REPL_ENSURE_TABLE_ATTACHED (_dsn, _part2);
      REPL_CREATE_UPDATEABLE_SNAPSHOT_LOG (_att_tbl);
    }
  else
    {
      signal ('22023', sprintf ('Invalid type %d', _type), 'TR118');
    }

  --
  -- register this snapshot subscription
  insert into DB.DBA.SYS_SNAPSHOT_SUB (SS_SERVER, SS_ITEM, SS_TYPE)
      values (_server, _item, _type);
}
;

create procedure REPL_DROP_SNAPSHOT_SUB (
  in _server varchar, in _item varchar, in _type integer)
{
  if (_type = 1)
    _item := REPL_COMPLETE_COLNAME (_item);
  else if (_type = 2)
    _item := complete_table_name (_item, 1);

  declare _dsn varchar;
  _dsn := REPL_DSN (_server);
  if (_dsn is null)
    {
      signal ('37000',
          sprintf ('Replication server ''%s'' does not exist',
              _server),
          'TR119');
    }
  if (_server = repl_this_server())
    {
      signal ('22023', 'Can''t unsubscribe from self', 'TR131');
    }

  --
  -- check that subscription exists
  if (not exists (select 1 from DB.DBA.SYS_SNAPSHOT_SUB
		  where SS_SERVER = _server and SS_ITEM = _item
                  and SS_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot subscription of ''%s'' for ''%s'' already exists',
              _server, _item),
          'TR120');
    }

  if (_type = 1)
    {
      ;
    }
  else if (_type = 2)
    {
      --
      -- drop attached tables
      declare _local_tbl varchar;
      _local_tbl := att_local_name (_dsn, _item);
      --dbg_obj_print (_local_tbl);
      declare _stat, _msg varchar;
      _stat := '00000';
      _msg := '';
      if (0 <> exec (sprintf ('drop table %s', REPL_FQNAME (_local_tbl)),
                   _stat, _msg))
        signal (_stat, _msg);

      _local_tbl := att_local_name (_dsn,
          sprintf ('%s.%s.RLOG_%s',
              name_part (_item, 0), name_part (_item, 1), name_part (_item, 2)));
      --dbg_obj_print (_local_tbl);
      if (0 <> exec (sprintf ('drop table %s', REPL_FQNAME (_local_tbl)),
                   _stat, _msg))
        signal (_stat, _msg);
    }
  else
    {
      signal ('22023', sprintf ('Invalid type %d', _type), 'TR121');
    }

  --
  -- unregister snapshot subscription
  delete from DB.DBA.SYS_SNAPSHOT_SUB
      where SS_SERVER = _server and SS_ITEM = _item and SS_TYPE = _type;
}
;

create procedure REPL_ADD_SNAPSHOT_CR (
    in _tbl varchar,          -- table for which conflict resolver
                              -- is added
    in _name_suffix varchar,  -- resolver name suffix
    in _type char,            -- resolver type ('I', 'U' or 'D')
    in _order integer,        -- resolver order
    in _class varchar,        -- resolver class
    in _coln varchar := null) -- column
{
  -- check _tbl
  _tbl := complete_table_name (_tbl, 1);
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = _tbl))
    signal ('37000', concat ('The table \'' , _tbl, '\' does not exist'), 'TR107');

  -- check _name_suffix
  if (length (_name_suffix) = 0)
    signal ('22023', concat ('Empty resolver name suffix'), 'TR122');
  _name_suffix := SYS_ALFANUM_NAME (_name_suffix);

  -- check _type
  if (_type <> 'I' and _type <> 'U' and _type <> 'D')
    signal ('22023', concat ('Invalid resolver type \'', _type, '\''), 'TR123');

  -- build procedure name
  declare _cr_proc varchar;
  declare _cr_proc_name varchar;
  _cr_proc := sprintf ('"%I"."%I"."replcr_%s_%I_%s"',
      name_part (_tbl, 0), name_part (_tbl, 1),
      _type, name_part (_tbl, 2), _name_suffix);
  _cr_proc_name := sprintf ('%s.%s.replcr_%s_%s_%s',
      name_part (_tbl, 0), name_part (_tbl, 1),
      _type, name_part (_tbl, 2), _name_suffix);

  -- check that conflict resolver with such name does not exist
  if (exists (select 1 from DB.DBA.SYS_SNAPSHOT_CR
                 where CR_TABLE_NAME = _tbl and CR_PROC = _cr_proc_name))
    {
      signal ('37000',
        concat ('Conflict resolver for \'', _tbl, '\' with name ',
            _cr_proc_name, ' already exists'),
        'TR108');
    }

  declare _p, _allp, _allcols varchar;
  declare _coltemp, _colp, _coltype varchar;
  declare _pkcond, _pkp varchar;
  _p := '';
  _allp := '';
  _allcols := '';
  _coltemp := '';
  _colp := '';
  _coltype := '';
  _pkcond := '';
  _pkp := '';

  declare _col any;
  declare _ix, _len integer;
  declare _col_name varchar;
  declare _col_dtp integer;

  if (_class <> 'pub_wins' and _class <> 'sub_wins' and _class <> 'custom')
    {
      if (length (_coln) = 0)
        signal ('22023', 'Empty column name', 'TR076');
    }
  else
    _coln := '';

  -- build primary key WHERE condition
  declare _pk_cols any;
  _pk_cols := REPL_PK_COLS (_tbl);
  _ix := 0;
  _len := length (_pk_cols);
  while (_ix < _len)
    {
      _col := aref (_pk_cols, _ix);
      _col_name := aref (_col, 0);

      declare _ct varchar;
      _ct := REPL_COLTYPE (_col);
      _pkcond := concat (_pkcond,
          sprintf ('"%I" = "_%I"', _col_name, _col_name));
      _pkp := concat (_pkp, sprintf ('inout "_%I" ', _col_name), _ct);
      if (_ix + 1 < _len)
        {
          _pkcond := concat (_pkcond, ' and ');
          _pkp := concat (_pkp, ',\n  ');
        }
      _ix := _ix + 1;
    }

  -- build resolver params
  declare _cols any;
  _cols := REPL_ALL_COLS (_tbl);
  _ix := 0;
  _len := length (_cols);
  while (_ix < _len)
    {
      _col := aref (_cols, _ix);
      _col_name := aref (_col, 0);
      _col_dtp := aref (_col, 1);
      if (_col_dtp = 128)
        _col := vector(_col[0], 211, _col[2], _col[3]);

      declare _ct varchar;
      _ct := REPL_COLTYPE (_col);
      _p := concat (_p, sprintf ('inout "_%I" ', _col_name), _ct);
      _allp := concat (_allp, sprintf ('"_%I"', _col_name));
      _allcols:= concat (_allcols, sprintf ('"%I"', _col_name));
      if (_col_name = _coln)
        _coltype := _ct;

      if (_ix + 1 < _len)
        {
          _p := concat (_p, ',\n  ');
          _allp := concat (_allp, ', ');
          _allcols := concat (_allcols, ', ');
        }
      _ix := _ix + 1;
   }

  if (_class <> 'pub_wins' and _class <> 'sub_wins' and _class <> 'custom')
    {
      if (_coltype = '')
        {
          signal ('37000',
              concat ('No column \'', _coln, '\' in target table \'', _tbl, '\''),
              'TR077');
        }
      _coltemp := sprintf ('"__temp_%I"', _coln);
      _colp := sprintf ('"_%I"', _coln);
      _coln := sprintf ('"%I"', _coln);
     }

  -- generate resolver
  declare _stmt varchar;
  _stmt := 'create procedure <CR_PROC> (';
  if (_type = 'I')
    {
      _stmt := concat (_stmt, '
  <P>,');
    }
  else if (_type = 'U')
    {
      _stmt := concat (_stmt, '
  <P>,');
    }
  else
    {
      _stmt := concat (_stmt, '
  <PKP>,');
    }
  _stmt := concat (_stmt, '
  inout __origin varchar)
{');
  if (_class = 'min')
    {
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  if (<COLTEMP> < <COLP>)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'max')
    {
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  if (<COLTEMP> > <COLP>)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'ave')
    {
      -- current_value = (current_value + new_value) / 2
      _stmt := concat (_stmt, '
  declare <COLTEMP> <COLTYPE>;
  select <COLNAME> into <COLTEMP> from <FQTN> where <PKCOND>;
  <COLP> := (<COLTEMP> + <COLP>) / 2;
  return 2;   -\- "subscriber" wins, change origin');
    }
  else if (_class = 'pub_wins' or _class = 'custom')
    {
      _stmt := concat (_stmt, '
  return 3;   -\- publisher wins');
    }
  else if (_class = 'sub_wins')
    {
      _stmt := concat (_stmt, '
  return 1;   -\- subscriber wins');
    }
  else
    signal ('22023', concat ('Invalid resolver class \'', _class, '\''), 'TR078');
  _stmt := concat (_stmt, '
}');

  -- do substitutions
  _stmt := replace (_stmt, '<CR_PROC>', _cr_proc);
  _stmt := replace (_stmt, '<FQTN>', REPL_FQNAME (_tbl));
  _stmt := replace (_stmt, '<P>', _p);
  _stmt := replace (_stmt, '<PKP>', _pkp);
  _stmt := replace (_stmt, '<ALLP>', _allp);
  _stmt := replace (_stmt, '<ALLCOLS>', _allcols);
  _stmt := replace (_stmt, '<PKCOND>', _pkcond);
  _stmt := replace (_stmt, '<COLTEMP>', _coltemp);
  _stmt := replace (_stmt, '<COLP>', _colp);
  _stmt := replace (_stmt, '<COLTYPE>', _coltype);
  _stmt := replace (_stmt, '<COLNAME>', _coln);
  --dbg_printf ('stmt: [%s]', _stmt);

  -- create conflict resolver
  declare _stat, _msg varchar;
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg))
    signal (_stat, _msg);

  -- register conflict resolver
  _stat := '00000';
  _msg := '';
  _stmt := 'insert into DB.DBA.SYS_SNAPSHOT_CR (CR_ID, CR_TABLE_NAME, CR_TYPE, CR_PROC, CR_ORDER) values (coalesce ((select max(CR_ID) + 1 from DB.DBA.SYS_SNAPSHOT_CR), 0), ?, ?, ?, ?)';
  if (0 <> exec (_stmt, _stat, _msg, vector (_tbl, _type, _cr_proc_name, _order)))
    signal (_stat, _msg);

  return 0;
}
;

create procedure REPL_CREATE_UPDATE_TABLE_PROC (in _tbl varchar)
{
  _tbl := complete_table_name (_tbl, 1);

  declare _pkcols_array any;
  declare _jpkcond, _pkcond, _pk_var, _pkcondqm, _rlog_pk varchar;
  declare _allcols_decl, _allcols_var, _allcols, _qm, _setqm varchar;
  declare _fetch_allcols_var, _rlog_allcols, _rlog_allcols_noblob varchar;
  declare _blobcols, _fetch_blobs, _fetch_blobs_var varchar;
  declare _nots_qm, _nots_setqm, _nots_allcols_var, _nots_allcols varchar;
  declare _ncols varchar;
  declare _nblobs integer;
  declare _isblob integer;

  declare _cols, _col any;
  declare _col_name varchar;
  declare _col_dtp integer;
  declare _ix, _len integer;
  _cols := REPL_PK_COLS (_tbl);
  _len := length (_cols);
  _ix := 0;
  if (_len = 0)
    {
      signal ('22023',
          sprintf ('The table ''%s'' does not exist or does not have primary key', _tbl),
          'TR132');
    }

  _pkcols_array := null;
  _jpkcond := '';
  _pkcond := '';
  _pk_var := '';
  _pkcondqm := '';
  _rlog_pk := '';
  while (_ix < _len)
    {
      _col := _cols[_ix];
      _col_name := _col[0];

      if (_pkcols_array is null)
        _pkcols_array := vector (_col_name);
      else
        _pkcols_array := vector_concat (_pkcols_array, vector (_col_name));
      _jpkcond := concat (_jpkcond,
           sprintf ('"RLOG_%I" = "%I"', _col_name, _col_name));
      _pkcond := concat (_pkcond,
           sprintf ('"%I" = "_%I"', _col_name, _col_name));
      _pk_var := concat (_pk_var, sprintf ('"_%I"', _col_name));
      _pkcondqm := concat (_pkcondqm, sprintf ('"%I" = ?', _col_name));
      _rlog_pk := concat (_rlog_pk, sprintf ('"RLOG_%I"', _col_name));
      if (_ix + 1 < _len)
        {
          _jpkcond := concat (_jpkcond, ' and ');
          _pkcond := concat (_pkcond, ' and ');
          _pk_var := concat (_pk_var, ', ');
          _pkcondqm := concat (_pkcondqm, ' and ');
          _rlog_pk := concat (_rlog_pk, ', ');
        }
      _ix := _ix + 1;
    }

  _cols := REPL_ALL_COLS (_tbl);
  _ix := 0;
  _len := length (_cols);
  _ncols := sprintf ('%d', _len);
  _nblobs := 0;

  _allcols_decl := '';
  _allcols_var := '';
  _allcols := '';
  _qm := '';
  _setqm := '';
  _fetch_allcols_var := '';
  _rlog_allcols := '';
  _rlog_allcols_noblob := '';
  _nots_qm := '';
  _nots_setqm := '';
  _nots_allcols_var := '';
  _nots_allcols := '';
  _blobcols := '';
  _fetch_blobs := '';
  _fetch_blobs_var := '';
  while (_ix < _len)
    {
      _col := _cols[_ix];
      _col_name := _col[0];
      _col_dtp := _col[1];
      if (_col_dtp = 128)
        _col := vector(_col[0], 211, _col[2], _col[3]);
      if (_col_dtp = 125 or _col_dtp = 131 or _col_dtp = 132 or _col_dtp = 134)
        _isblob := 1;
      else
        _isblob := 0;

      _allcols_decl := concat (_allcols_decl,
          sprintf ('declare "_%I" ', _col_name), REPL_COLTYPE (_col));
      _allcols_var := concat (_allcols_var, sprintf ('"_%I"', _col_name));
      _allcols := concat (_allcols, sprintf ('"%I"', _col_name));
      _qm := concat (_qm, '?');
      _setqm := concat (_setqm, sprintf ('"%I" = ?', _col_name));
      _fetch_allcols_var := concat (_fetch_allcols_var,
          sprintf ('"_%I" := __row[%d]', _col_name, _ix));
      if (0 = position (_col_name, _pkcols_array))
        {
          _rlog_allcols := concat (_rlog_allcols, sprintf ('"%I"', _col_name));
          if (0 = _isblob)
            {
              _rlog_allcols_noblob := concat (
                  _rlog_allcols_noblob, sprintf ('"%I"', _col_name));
            }
          else
            _rlog_allcols_noblob := concat (_rlog_allcols_noblob, 'null');
        }
      else
        {
          _rlog_allcols := concat (_rlog_allcols,
              sprintf ('"RLOG_%I"', _col_name));
          _rlog_allcols_noblob := concat (
              _rlog_allcols_noblob, sprintf ('"RLOG_%I"', _col_name));
        }
      if (_col_dtp <> 128)
        {
          _nots_qm := concat (_nots_qm, '?');
          _nots_setqm := concat (_nots_setqm, sprintf ('"%I" = ?', _col_name));
          _nots_allcols_var := concat (_nots_allcols_var,
              sprintf ('"_%I"', _col_name));
          _nots_allcols := concat (_nots_allcols, sprintf ('"%I"', _col_name));
        }
      if (0 <> _isblob)
        {
          if (length (_blobcols) > 0)
            {
              _blobcols := concat (_blobcols, ', ');
              _fetch_blobs_var := concat (_fetch_blobs_var, ';\n              ');
            }
          _blobcols := concat (_blobcols, sprintf ('"%I"', _col_name));
          _fetch_blobs_var := concat (_fetch_blobs_var,
               sprintf ('"_%I" := __blobs[0][%d]', _col_name, _nblobs));
          _nblobs := _nblobs + 1;
        }
      if (_ix + 1 < _len)
        {
          _allcols_decl := concat (_allcols_decl, ';\n  ');
          _allcols_var := concat (_allcols_var, ', ');
          _allcols := concat (_allcols, ', ');
          _qm := concat (_qm, ', ');
          _setqm := concat (_setqm, ', ');
          _fetch_allcols_var := concat (_fetch_allcols_var, ';\n          ');
          _rlog_allcols := concat (_rlog_allcols, ', ');
          _rlog_allcols_noblob := concat (_rlog_allcols_noblob, ', ');
          if (_col_dtp <> 128)
            {
              _nots_qm := concat (_nots_qm, ', ');
              _nots_setqm := concat (_nots_setqm, ', ');
              _nots_allcols_var := concat (_nots_allcols_var, ', ');
              _nots_allcols := concat (_nots_allcols, ', ');
            }
        }
      _ix := _ix + 1;
    }

  if (0 <> _nblobs)
    {
      _fetch_blobs :=
'if (__dmltype in (''I'', ''U''))
            {
              __stmt := sprintf (''select <BLOBCOLS> from %s where <PKCONDQM>'',
                  REPL_FQNAME (__rtbl));
              __stat := ''00000'';
              __msg := '''';
              if (0 <> exec (__stmt, __stat, __msg, vector (<PK_VAR>), 0, null, __blobs))
                {
                  dbg_printf (''ERROR: %s: %s'', __stat, __msg);
                  goto err_subscriber;
                }
              if (length (__blobs) <> 1)
                {
                  dbg_printf (''ERROR: Can''''t fetch blobs'');
                  goto err_subscriber;
                }
              <FETCH_BLOBS_VAR>;
            }';
    }
  else
    _fetch_blobs := '';

  declare _stmt varchar;
  declare _stat, _msg varchar;

  declare _rplog_tbl varchar;
  _rplog_tbl := sprintf ('"%I"."%I"."RPLOG_%I"',
      name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2));

  -- clean up
  _stat := '00000';
  _msg := '';
  _stmt := sprintf ('drop table %s', _rplog_tbl);
  exec (_stmt, _stat, _msg);

  declare _stmts any;
  _stmts := vector (
'create table <RPLOG> (
    SOURCE varchar,
    TARGET varchar,
    RLOG_ROWGUID varchar,
    SNAPTIME datetime,
    primary key (SOURCE, TARGET, RLOG_ROWGUID)
)',
'create procedure "<TN1>"."<TN2>"."REPL_UPDATE_TABLE_<TN3>" ()
{
  <ALLCOLS_DECL>;
  declare __stat, __msg varchar;
  declare __stmt varchar;
  declare __params, __row, __blobs any;
  declare __cr integer;
  declare __snaptime, __lastsnaptime datetime;
  declare __dmltype varchar;
  declare __old_rowguid, __rlog_rowguid varchar;
  declare __dsn, __rtbl varchar;
  declare __res integer;

  for select SS_SERVER as __server, SS_LAST_PULL_TS as __last_ts
      from DB.DBA.SYS_SNAPSHOT_SUB
      where SS_ITEM = ''<TBL>'' and SS_TYPE = 2 do
    {
      --dbg_printf (''PULL: server [%s]'', __server);
      __dsn := REPL_DSN (__server);
      if (__dsn is null)
        {
          dbg_printf (''ERROR: %s: Replication server not found'', __server);
          goto next_subscriber;
        }

      declare __rlog_tbl varchar;
      __rtbl := att_local_name (__dsn, ''<TBL>'');
      __rlog_tbl := sprintf (''%s.%s.RLOG_%s'',
          name_part (__rtbl, 0), name_part (__rtbl, 1), name_part (__rtbl, 2));

restart_subscriber:
      __cr := null;
      __lastsnaptime := null;
      __stmt := sprintf (''select <RLOG_ALLCOLS_NOBLOB>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID from %s left join %s on (<JPKCOND>) where '',
          REPL_FQNAME (__rlog_tbl), REPL_FQNAME (__rtbl));
      if (__last_ts is not null)
        {
          __stmt := concat (__stmt, ''SNAPTIME >= ? and '');
          __params := vector (REPL_STARTTIME (__last_ts));
        }
      else
        __params := vector ();
      __stmt := concat (__stmt,
          sprintf (''not exists (select 1 from <RPLOG> where SOURCE = ? and TARGET = ? and RLOG_ROWGUID = %s.RLOG_ROWGUID) order by SNAPTIME, <RLOG_PK>'',
              REPL_FQNAME (__rlog_tbl)));
      __params := vector_concat (
          __params, vector (__server, repl_this_server()));
      __stat := ''00000'';
      __msg := '''';
      if (0 <> exec (__stmt, __stat, __msg, __params, 0, null, null, __cr))
        {
          dbg_printf (''ERROR: %s: %s'', __stat, __msg);
          goto next_subscriber;
        }

      while (0 = exec_next (__cr, __stat, __msg, __row))
        {
          <FETCH_ALLCOLS_VAR>;
          __snaptime := __row[<NCOLS>];
          __dmltype := __row[<NCOLS> + 1];
          __old_rowguid := __row[<NCOLS> + 2];
          __rlog_rowguid := __row[<NCOLS> + 3];

          if (__lastsnaptime is null)
            __lastsnaptime := __snaptime;
          else if (__lastsnaptime <> __snaptime)
            {
              __last_ts := __snaptime;
              exec_close (__cr);
              update DB.DBA.SYS_SNAPSHOT_SUB
                  set SS_LAST_PULL_TS = __snaptime
                  where SS_SERVER = __server and SS_ITEM = ''<TBL>''
                  and SS_TYPE = 2;
              commit work;
              goto restart_subscriber;
            }
          insert replacing <RPLOG> (SOURCE, TARGET, RLOG_ROWGUID, SNAPTIME)
              values (__server, repl_this_server(), __rlog_rowguid, __snaptime);

          -- stale log records have null _ROWGUID and are ignored
          declare __origin varchar;
          if (__dmltype in (''I'', ''U''))
            __origin := REPL_ORIGIN (_ROWGUID);
          else
            __origin := REPL_ORIGIN (__old_rowguid);
          if (__origin is null or __origin <> __server)
            goto next_rec;

          <FETCH_BLOBS>
          --dbg_printf (''PULL: dmltype: [%s], ROWGUID: [%s]'', __dmltype, _ROWGUID);
          if (__dmltype = ''I'')
            {
              if (not exists (select 1 from <FQTN> where <PKCOND>))
                {
                  --dbg_printf (''insert: no conflict'');
                  goto insert_apply;
                }

              for select CR_PROC as __proc from DB.DBA.SYS_SNAPSHOT_CR
                    where CR_TABLE_NAME = ''<TBL>'' and CR_TYPE = ''I''
                    order by CR_ORDER do
                {
                  --dbg_printf (''insert CR [%s]'', __proc);
                  __res := call (__proc) (<ALLCOLS_VAR>, __server);
                  if (__res = 5 or __res = 4)
                    {
                      --dbg_printf (''insert: ignore'');
                      goto next_rec;
                    }
                  else if (__res = 3)
                    {
                      --dbg_printf (''insert: publisher wins'');
                      goto insert_publisher_wins;
                    }
                  else if (__res = 2)
                    {
                      --dbg_printf (''insert: subscriber wins, change origin'');
                      _ROWGUID := REPL_SET_ORIGIN (_ROWGUID);
                      goto insert_apply;
                    }
                  else if (__res = 1)
                    {
                      --dbg_printf (''insert: subscriber wins'');
                      goto insert_apply;
                    }
                }
              --dbg_printf (''insert: publisher wins (default)'');

insert_publisher_wins:
              select <NOTS_ALLCOLS> into <NOTS_ALLCOLS_VAR> from <FQTN> where <PKCOND>;
insert_apply:
              _ROWGUID := concat (''raw:'', _ROWGUID);
              __stat := ''00000'';
              __msg := '''';
              if (0 <> exec (''insert replacing <FQTN> (<NOTS_ALLCOLS>) values (<NOTS_QM>)'', __stat, __msg, vector (<NOTS_ALLCOLS_VAR>)))
                {
                  dbg_printf (''ERROR: INSERT: %s: %s'', __stat, __msg);
                  goto err_subscriber;
                }
              goto next_rec;
            }
          else if (__dmltype = ''U'')
            {
              declare __guid varchar;
              declare exit handler for not found goto insert_apply;
              select ROWGUID into __guid from <FQTN> where <PKCOND>;
              if (__guid = __old_rowguid)
                {
                  --dbg_printf (''update: no conflict'');
                  goto update_apply;
                }
              --dbg_printf (''update conflict: rowguid [%s], old rowguid [%s]'',
              --    __guid, __old_rowguid);

              for select CR_PROC as __proc from DB.DBA.SYS_SNAPSHOT_CR
                  where CR_TABLE_NAME = ''<TBL>'' and CR_TYPE = ''U''
                  order by CR_ORDER do
                {
                  --dbg_printf (''update CR [%s]'', __proc);
                  __res := call (__proc) (<ALLCOLS_VAR>, __server);
                  if (__res = 5 or __res = 4)
                    {
                      --dbg_printf (''update: ignore'');
                      goto next_rec;
                    }
                  else if (__res = 3)
                    {
                      --dbg_printf (''update: publisher wins'');
                      goto update_publisher_wins;
                    }
                  else if (__res = 2)
                    {
                      --dbg_printf (''update: subscriber wins, change origin'');
                      _ROWGUID := REPL_SET_ORIGIN (_ROWGUID);
                      goto update_apply;
                    }
                  else if (__res = 1)
                    {
                      --dbg_printf (''update: subscriber wins'');
                      goto update_apply;
                    }
                }
              --dbg_printf (''update: publisher wins (default)'');

update_publisher_wins:
              select <NOTS_ALLCOLS> into <NOTS_ALLCOLS_VAR> from <FQTN> where <PKCOND>;
update_apply:
              _ROWGUID := concat (''raw:'', _ROWGUID);
              __stat := ''00000'';
              __msg := '''';
              if (0 <> exec (''update <FQTN> set <NOTS_SETQM> where <PKCONDQM>'',
                           __stat, __msg, vector (<NOTS_ALLCOLS_VAR>, <PK_VAR>)))
                {
                  dbg_printf (''ERROR: UPDATE: %s: %s'', __stat, __msg);
                  goto err_subscriber;
                }
              goto next_rec;
            }
          else
            {
              declare __guid varchar;
              declare exit handler for not found goto delete_conflict;
              select ROWGUID into __guid from <FQTN> where <PKCOND>;
              if (__guid = __old_rowguid)
                {
                  --dbg_printf (''delete: no conflict'');
                  goto delete_apply;
                }
              --dbg_printf (''delete conflict: rowguid [%s], old rowguid [%s]'',
              --    __guid, __old_rowguid);
delete_conflict:
              for select CR_PROC as __proc from DB.DBA.SYS_SNAPSHOT_CR
                  where CR_TABLE_NAME = ''<TBL>'' and CR_TYPE = ''D''
                  order by CR_ORDER do
                {
                  --dbg_printf (''delete CR [%s]'', __proc);
                  __res := call (__proc) (<PK_VAR>, __server);
                  if (__res = 5)
                    {
                      --dbg_printf (''delete: ignore'');
                      goto next_rec;
                    }
                  else if (__res = 1)
                    {
                      --dbg_printf (''delete: subscriber wins'');
                      goto delete_apply;
                    }
                }
              --dbg_printf (''delete: ignore (default)'');
              goto next_rec;
delete_apply:
              _ROWGUID := concat (''delete:raw:'', __old_rowguid);
              __stat := ''00000'';
              __msg := '''';
              if (0 <> exec (''update <FQTN> set ROWGUID = ? WHERE <PKCONDQM>'',
                           __stat, __msg, vector (_ROWGUID, <PK_VAR>)))
                {
                  dbg_printf (''ERROR: DELETE: %s: %s'', __stat, __msg);
                  goto err_subscriber;
                }
              goto next_rec;
            }
next_rec:
          ;
        }
      exec_close (__cr);
      update DB.DBA.SYS_SNAPSHOT_SUB
          set SS_LAST_PULL_TS = coalesce (__lastsnaptime, __last_ts, REPL_GETDATE(__dsn))
          where SS_SERVER = __server and SS_ITEM = ''<TBL>'' and SS_TYPE = 2;
      commit work;
      goto next_subscriber;
err_subscriber:
      exec_close (__cr);
      rollback work;
next_subscriber:
      ;
    }

  for select SS_SERVER as __server, SS_LAST_PUSH_TS as __last_ts
      from DB.DBA.SYS_SNAPSHOT_SUB
      where SS_ITEM = ''<TBL>'' and SS_TYPE = 2 do
    {
      --dbg_printf (''PUSH: server [%s]'', __server);
      __dsn := REPL_DSN (__server);
      if (__dsn is null)
        {
          dbg_printf (''ERROR: %s: Replication server not found'', __server);
          goto err_sub;
        }
      __rtbl := att_local_name (__dsn, ''<TBL>'');

restart_sub:
      __cr := null;
      __lastsnaptime := null;
      __stmt := ''select <RLOG_ALLCOLS>, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID from "<TN1>"."<TN2>"."RLOG_<TN3>" left join <FQTN> on (<JPKCOND>) where (? is null or SNAPTIME >= ?) and not exists (select 1 from <RPLOG> where SOURCE = ? and TARGET = ? and RLOG_ROWGUID = "<TN1>"."<TN2>"."RLOG_<TN3>".RLOG_ROWGUID) order by SNAPTIME, <RLOG_PK>'';
      __params := vector (
          __last_ts, REPL_STARTTIME (__last_ts), repl_this_server(), __server);
      __stat := ''00000'';
      __msg := '''';
      if (0 <> exec (__stmt, __stat, __msg, __params, 0, null, null, __cr))
        {
          dbg_printf (''ERROR: %s: %s'', __stat, __msg);
          goto next_sub;
        }

      while (0 = exec_next (__cr, __stat, __msg, __row))
        {
          <FETCH_ALLCOLS_VAR>;
          __snaptime := __row[<NCOLS>];
          __dmltype := __row[<NCOLS> + 1];
          __old_rowguid := __row[<NCOLS> + 2];
          __rlog_rowguid := __row[<NCOLS> + 3];

          if (__lastsnaptime is null)
            __lastsnaptime := __snaptime;
          else if (__lastsnaptime <> __snaptime)
            {
              __last_ts := __snaptime;
              exec_close (__cr);
              update SYS_SNAPSHOT_SUB
                  set SS_LAST_PUSH_TS = __snaptime
                  where SS_SERVER = __server and SS_ITEM = ''<TBL>''
                  and SS_TYPE = 2;
              commit work;
              goto restart_sub;
            }
          insert replacing <RPLOG> (SOURCE, TARGET, RLOG_ROWGUID, SNAPTIME)
              values (repl_this_server(), __server, __rlog_rowguid, __snaptime);

          --dbg_printf (''PUSH: dmltype: [%s], ROWGUID: [%s]'',
          --    __dmltype, _ROWGUID);
          --dbg_obj_print (__last_ts, __snaptime);

          -- stale log records have null _ROWGUID and are ignored
          declare __origin varchar;
          if (__dmltype in (''I'', ''U''))
            __origin := REPL_ORIGIN (_ROWGUID);
          else
            __origin := REPL_ORIGIN (__old_rowguid);
          if (__origin is null or __origin = __server)
            goto next_r;

          __stat := ''00000'';
          __msg := '''';
          if (__dmltype in (''I'', ''U''))
            {
              declare __d varchar;
              if (__dmltype = ''I'')
                __d := ''INSERT'';
              else
                __d := ''UPDATE'';
              _ROWGUID := concat (''nolog:'', _ROWGUID);
              declare __rowcount integer;
              __rowcount := 0;
              if (0 <> exec (
                  sprintf (''update %s set <SETQM> where <PKCONDQM>'',
                      REPL_FQNAME (__rtbl)),
                  __stat, __msg, vector (<ALLCOLS_VAR>, <PK_VAR>),
                  0, null, __rowcount))
                {
                  dbg_printf (''ERROR: %s: %s: %s: %s'',
                      __d, __server, __stat, __msg);
                  goto err_sub;
                }
              if (0 = __rowcount)
                {
                  --dbg_printf (''%s: do insert'', __d);
                  if (0 <> exec (
                      sprintf (''insert into %s (<ALLCOLS>) values (<QM>)'',
                          REPL_FQNAME (__rtbl)),
                      __stat, __msg, vector (<ALLCOLS_VAR>)))
                    {
                      dbg_printf (''ERROR: %s: %s: %s: %s'',
                          __d, __server, __stat, __msg);
                      goto err_sub;
                    }
                }
            }
          else
            {
              if (0 <> exec (
                  sprintf (''update %s set ROWGUID = ? where <PKCONDQM>'',
                      REPL_FQNAME (__rtbl)),
                  __stat, __msg,
                  vector (concat (''delete:nolog:'', __old_rowguid), <PK_VAR>)))
                {
                  dbg_printf (''ERROR: DELETE(UPDATE): %s: %s: %s'', __server, __stat, __msg);
                  goto err_sub;
                }
            }
next_r:
          ;
        }
      exec_close (__cr);
      update SYS_SNAPSHOT_SUB
          set SS_LAST_PUSH_TS = coalesce (__lastsnaptime, __last_ts, REPL_GETDATE())
          where SS_SERVER = __server and SS_ITEM = ''<TBL>''
          and SS_TYPE = 2;
      commit work;
      goto next_sub;
err_sub:
      exec_close (__cr);
      rollback work;
next_sub:
      ;
    }
  update SYS_SNAPSHOT_PUB set SP_LAST_TS = REPL_GETDATE()
      where SP_ITEM = ''<TBL>'' and SP_TYPE = 2;
}');

  _ix := 0;
  _len := length (_stmts);
  while (_ix < _len)
    {
      _stmt := _stmts[_ix];
      _stmt := replace (_stmt, '<FETCH_BLOBS>', _fetch_blobs);
      _stmt := replace (_stmt, '<TN1>', sprintf ('%I', name_part (_tbl, 0)));
      _stmt := replace (_stmt, '<TN2>', sprintf ('%I', name_part (_tbl, 1)));
      _stmt := replace (_stmt, '<TN3>', sprintf ('%I', name_part (_tbl, 2)));
      _stmt := replace (_stmt, '<TBL>', _tbl);
      _stmt := replace (_stmt, '<FQTN>', REPL_FQNAME (_tbl));
      _stmt := replace (_stmt, '<RPLOG>', _rplog_tbl);
      _stmt := replace (_stmt, '<JPKCOND>', _jpkcond);
      _stmt := replace (_stmt, '<PKCOND>', _pkcond);
      _stmt := replace (_stmt, '<PK_VAR>', _pk_var);
      _stmt := replace (_stmt, '<PKCONDQM>', _pkcondqm);
      _stmt := replace (_stmt, '<RLOG_PK>', _rlog_pk);
      _stmt := replace (_stmt, '<ALLCOLS_DECL>', _allcols_decl);
      _stmt := replace (_stmt, '<ALLCOLS_VAR>', _allcols_var);
      _stmt := replace (_stmt, '<ALLCOLS>', _allcols);
      _stmt := replace (_stmt, '<QM>', _qm);
      _stmt := replace (_stmt, '<SETQM>', _setqm);
      _stmt := replace (_stmt, '<RLOG_ALLCOLS>', _rlog_allcols);
      _stmt := replace (_stmt, '<RLOG_ALLCOLS_NOBLOB>', _rlog_allcols_noblob);
      _stmt := replace (_stmt, '<FETCH_ALLCOLS_VAR>', _fetch_allcols_var);
      _stmt := replace (_stmt, '<NOTS_ALLCOLS_VAR>', _nots_allcols_var);
      _stmt := replace (_stmt, '<NOTS_ALLCOLS>', _nots_allcols);
      _stmt := replace (_stmt, '<NOTS_QM>', _nots_qm);
      _stmt := replace (_stmt, '<NOTS_SETQM>', _nots_setqm);
      _stmt := replace (_stmt, '<NCOLS>', _ncols);
      _stmt := replace (_stmt, '<BLOBCOLS>', _blobcols);
      _stmt := replace (_stmt, '<FETCH_BLOBS_VAR>', _fetch_blobs_var);
      --dbg_printf ('stmt: [%s]', _stmt);
      _stat := '00000';
      _msg := '';
      if (0 <> exec (_stmt, _stat, _msg))
        signal (_stat, _msg);

      _ix := _ix + 1;
    }
}
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
      dbg_printf ('REPL_DAV_STORE_RES: %s: No such collection',
          _res_colname);
      return _res_col;
    }
  declare _res_rowguid varchar;
  _res_rowguid := _rowguid;

  --dbg_printf ('REPL_DAV_STORE_RES: _res_colname [%s], _res_name [%s], _cr_colname [%s]',
  --    _res_colname, _res_name, _cr_colname);

  -- check locks
  declare _locked_id integer;
  declare _locked_type char;
  _locked_id := DAV_SEARCH_ID (concat (_res_colname, _res_name), 'r');
  _locked_type := 'R';
  if (DAV_IS_LOCKED_INT (_locked_id, _locked_type) <> 0)
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

  --dbg_printf ('_res_name [%s], _res_type [%s], _res_perms [%s], _res_uname [%s], _res_gname [%s]',
  --    _res_name, _res_type, _res_perms, _res_uname, _res_gname);
  _rc := DAV_RES_UPLOAD_STRSES_INT (
      concat (_res_colname, _res_name), _res_content, _res_type, _res_perms,
      _res_uname, _res_gname, null, null, 0,
      _res_cr_time, _res_mod_time, _res_rowguid);
  if (_rc < 0)
    {
      --dbg_printf ('REPL_DAV_STORE_RES: DAV_RES_UPLOAD_STRSES_INT returned %d',
      --    _rc);
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

  --dbg_printf ('after DELETE on SYS_DAV_LOCK: LOCK_PARENT_TYPE: [%s], LOCK_PARENT_ID: %d',
  --    _O.LOCK_PARENT_TYPE, _O.LOCK_PARENT_ID);
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
              dbg_printf ('REPL_DAV_STORE_BACKUP: DAV_COL_CREATE_INT returned %d (colname [%s]',
                  _backup_colid, _backup_colname);
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
          dbg_printf ('REPL_DAV_STORE_BACKUP: DAV_RES_UPLOAD_STRSES_INT returned %d',
              _rc);
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
      --dbg_printf ('notify_email: [%s], notify_text: [%s]',
      --    _notify_email, _notify_text);

      declare _stat, _msg varchar;
      _stat := '00000';
      _msg := '';
      if (0 <> exec ('smtp_send (null, ?, ?, ?)', _stat, _msg,
                   vector (_notify_email, _notify_email, _notify_text)))
       {
          dbg_printf ('REPL_DAV_STORE_BACKUP: smtp_send: %s: %s',
              _stat, _msg);
          return 0;
        }
    }

  return 0;
}
;

--
-- Pull DAV collection updates from specified DAV tables
create procedure REPL_DAV_PULL (
    in _server varchar, in _dsn varchar,
    in _colname varchar, in _colid integer, in _perms varchar,
    in _uname varchar, in _gname varchar,
    in _last_ts datetime, in _cr_colname varchar)
{
  declare _stat, _msg varchar;
  declare _stmt varchar;
  declare _params, _row any;
  declare _cr integer;
  declare _rc integer;
  declare _ix, _len integer;

  --dbg_printf ('REPL_DAV_PULL: _colname [%s], _colid [%d], _uname [%s], _gname [%s], _perms [%s]',
  --    _colname, _colid, _uname, _gname, _perms);
  declare _local_colid integer;
  _rc := DAV_COL_CREATE_INT (
      _colname, _perms, _uname, _gname, null, null, 0, 0, 0);
  if (_rc < 0)
    {
      dbg_printf ('REPL_DAV_PULL: DAV_COL_CREATE_INT returned %d', _rc);
      return 1;
    }
  _local_colid := _rc;

  --
  -- update collection used for conflict resolution
  -- (closest collection that has conflict resolvers defined)
  if (exists (select CR_PROC from DB.DBA.SYS_DAV_CR where CR_COL_NAME = _colname))
    _cr_colname := _colname;

  --
  -- read snapshot log
  _stmt := 'select RLOG_RES_NAME, RES_CONTENT, RES_PERMS, RES_TYPE,
    RES_CR_TIME, RES_MOD_TIME, U_NAME, G_NAME, U_E_MAIL,
    ROWGUID, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID
from WS.WS.RLOG_SYS_DAV_RES left join WS.WS.SYS_DAV_RES
on (RLOG_RES_NAME = RES_NAME and RLOG_RES_COL = RES_COL)
left join WS.WS.SYS_DAV_USER on (RES_OWNER = U_ID)
left join WS.WS.SYS_DAV_GROUP on (RES_GROUP = G_ID)
where RLOG_RES_COL = ? and (? is null or SNAPTIME >= ?)
order by SNAPTIME, RLOG_RES_COL, RLOG_RES_NAME';
  _params := vector (
      _colid, _last_ts, REPL_STARTTIME (_last_ts), _server, repl_this_server());
  _stat := '00000';
  _msg := '';
  _cr := null;
  if (0 <> rexecute (_dsn, _stmt, _stat, _msg, _params, 0, null, null, _cr))
    {
      dbg_printf ('REPL_DAV_PULL: %s: %s', _stat, _msg);
      return 1;
    }

  declare _snaptime datetime;
  declare _dmltype varchar;
  declare _res_name varchar;
  declare _res_uname, _res_gname, _res_perms, _res_type varchar;
  declare _res_cr_time, _res_mod_time datetime;
  declare _res_email varchar;
  declare _res_rowguid, _old_rowguid, _rlog_rowguid varchar;
  declare _backup_colid integer;
  _backup_colid := null;
  while (0 = rnext (_cr, _row))
    {
      _res_name := _row[0];
      _res_rowguid := _row[9];
      _snaptime := _row[10];
      _dmltype := _row[11];
      _old_rowguid := _row[12];
      _rlog_rowguid := _row[13];

      if (exists (select 1 from WS.WS.RPLOG_SYS_DAV_RES
              where SOURCE = _server and TARGET = repl_this_server()
              and RLOG_ROWGUID = _rlog_rowguid))
        goto next_rec;
      insert into WS.WS.RPLOG_SYS_DAV_RES (SOURCE, TARGET, RLOG_ROWGUID, SNAPTIME)
          values (_server, repl_this_server(), _rlog_rowguid, _snaptime);
      --dbg_printf ('REPL_DAV_PULL: _dmltype [%s], _res_name [%s]',
      --    _dmltype, _res_name);

      -- stale log records have null _res_rowguid and are ignored
      declare _origin varchar;
      if (_dmltype in ('I', 'U'))
        _origin := REPL_ORIGIN (_res_rowguid);
      else
        _origin := REPL_ORIGIN (_old_rowguid);
      if (_origin is null or _origin <> _server)
        goto next_rec;

      if (_dmltype in ('I', 'U'))
        {
          -- fetch content
          --declare _content any;
          --_stmt := sprintf ('select RES_CONTENT from %s WHERE RES_NAME = ? and RES_COL = ?',
          --    REPL_FQNAME (att_local_name (_dsn, 'WS.WS.SYS_DAV_RES')));
          --if (0 <> exec (_stmt, _stat, _msg, vector (_res_name, _colid),
          --        0, null, _content))
          --  {
          --    dbg_printf ('REPL_DAV_PULL: %s: %s', _stat, _msg);
          --    return 1;
          --  }
          --if (length (_content) <> 1 or length (_content[0]) <> 1)
          --  {
          --    dbg_printf ('REPL_DAV_PULL: Can''t fetch content (%d/%s)',
          --        _colid, _res_name);
          --    return 1;
          --  }

          --
          -- store resource
          _res_perms := _row[2];
          _res_type := _row[3];
          _res_cr_time := _row[4];
          _res_mod_time := _row[5];
          _res_uname := _row[6];
          _res_gname := _row[7];
          _res_email := _row[8];

          _rc := REPL_DAV_STORE_RES_INT (
              _colname, _res_name, _row[1], _res_type, _res_perms,
              _res_uname, _res_gname, _res_cr_time, _res_mod_time,
              _res_rowguid,
              _cr_colname, _res_email, _server, _old_rowguid,
              _local_colid, _backup_colid);
          if (_rc = 0)
            goto next_rec;
          else if (_rc < 0)
            {
              dbg_printf ('REPL_DAV_PULL: DAV_RES_UPLOAD_STRSES_INT returned %d', _rc);
              return 1;
            }
        }
      else
        {
          --
          -- delete resource
          update WS.WS.SYS_DAV_RES
              set ROWGUID = concat ('delete:raw:', _old_rowguid)
              where RES_COL = _local_colid and RES_NAME = _res_name;
        }
next_rec:
      ;
    }
  rclose (_cr);

  --
  -- dive into subcollections
  _stat := '00000';
  _msg := '';
  if (0 <> rexecute (_dsn, 'select COL_NAME, COL_ID, COL_PERMS, U_NAME, G_NAME
from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
where COL_PARENT = ? and COL_OWNER = U_ID and COL_GROUP = G_ID',
              _stat, _msg, vector(_colid), 0, null, _row))
    {
      dbg_printf ('REPL_DAV_PULL: %s: %s', _stat, _msg);
      return 1;
    }
  _ix := 0;
  _len := length (_row);
  while (_ix < _len)
    {
      if (_row[_ix][0] <> '_SYS_REPL_BACKUP')
        {
          if (0 <> REPL_DAV_PULL (
              _server, _dsn,
              concat (_colname, _row[_ix][0], '/'), _row[_ix][1], _row[_ix][2],
              _row[_ix][3], _row[_ix][4],
              _last_ts, _cr_colname))
            return 1;
        }
      _ix := _ix + 1;
    }
}
;

--
-- Push updates for specified DAV collection to specified DAV tables
create procedure REPL_DAV_PUSH (
    in _server varchar, in _dsn varchar,
    in _colname varchar, in _colid integer, in _perms varchar,
    in _uname varchar, in _gname varchar,
    in _last_ts datetime)
{
  declare _stat, _msg varchar;
  declare _stmt varchar;
  declare _params, _row any;
  declare _cr integer;
  declare _rc integer;
  declare _remote_colid integer;

  --dbg_printf ('REPL_DAV_PUSH: _colname [%s], _colid [%d], _uname [%s], _gname [%s], _perms [%s]',
  --    _colname, _colid, _uname, _gname, _perms);

  --
  -- ensure the column exists on remote
  _stat := '00000';
  _msg := '';
  _row := vector (
      vector ('out', 'integer', 0),
      _colname,
      _perms,
      _uname,
      _gname);
  if (0 <> rexecute (_dsn, '{? = call DB.DBA.DAV_COL_CREATE_INT (?, ?, ?, ?, null, null, 0, 0, 0)}',
               _stat, _msg, _row))
    {
      dbg_printf ('REPL_DAV_PUSH: %s: %s', _stat, _msg);
      return 1;
    }
  if (_row[0] < 0)
    {
      dbg_printf ('REPL_DAV_PUSH: DAV_COL_CREATE_INT returned %d', _row[0]);
      return 1;
    }
  _remote_colid := _row[0];
  --dbg_printf ('REPL_DAV_PUSH: remote colid %d', _remote_colid);

  --
  -- read snapshot log
  _stmt := 'select RLOG_RES_NAME, RES_CONTENT, RES_PERMS, RES_TYPE,
    RES_CR_TIME, RES_MOD_TIME, U_NAME, G_NAME, NULL,
    ROWGUID, SNAPTIME, DMLTYPE, OLD_ROWGUID, RLOG_ROWGUID
from WS.WS.RLOG_SYS_DAV_RES left join WS.WS.SYS_DAV_RES
on (RLOG_RES_NAME = RES_NAME and RLOG_RES_COL = RES_COL)
left join WS.WS.SYS_DAV_USER on (RES_OWNER = U_ID)
left join WS.WS.SYS_DAV_GROUP on (RES_GROUP = G_ID)
where RLOG_RES_COL = ? and (? is null or SNAPTIME >= ?)
and not exists (select 1 from WS.WS.RPLOG_SYS_DAV_RES
    where SOURCE = ? and TARGET = ?
    and WS.WS.RLOG_SYS_DAV_RES.RLOG_ROWGUID = RLOG_ROWGUID)
order by SNAPTIME, RLOG_RES_COL, RLOG_RES_NAME';
  _params := vector (
      _colid, _last_ts, REPL_STARTTIME (_last_ts), repl_this_server(), _server);
  _stat := '00000';
  _msg := '';
  _cr := null;
  if (0 <> exec (_stmt, _stat, _msg, _params, 0, null, null, _cr))
    {
      dbg_printf ('REPL_DAV_PUSH: %s: %s', _stat, _msg);
      return 1;
    }

  declare _snaptime datetime;
  declare _dmltype varchar;
  declare _res_name varchar;
  declare _res_uname, _res_gname, _res_perms, _res_type varchar;
  declare _res_cr_time, _res_mod_time datetime;
  declare _origin, _rowguid, _old_rowguid, _rlog_rowguid varchar;
  while (0 = exec_next (_cr, _stat, _msg, _row))
    {
      _res_name := _row[0];
      _rowguid := _row[9];
      _snaptime := _row[10];
      _dmltype := _row[11];
      _old_rowguid := _row[12];
      _rlog_rowguid := _row[13];

      insert replacing WS.WS.RPLOG_SYS_DAV_RES (SOURCE, TARGET, RLOG_ROWGUID, SNAPTIME)
          values (repl_this_server(), _server, _rlog_rowguid, _snaptime);
      --dbg_printf ('REPL_DAV_PUSH: _dmltype [%s], _res_name [%s]',
      --    _dmltype, _res_name);

      -- stale log records have null _rowguid and are ignored
      if (_dmltype in ('I', 'U'))
        _origin := REPL_ORIGIN (_rowguid);
      else
        _origin := REPL_ORIGIN (_old_rowguid);
      if (_origin is null or _origin = _server)
        goto next_rec;

      if (_dmltype in ('I', 'U'))
        {
          --
          -- create resource
          _res_perms := _row[2];
          _res_type := _row[3];
          _res_cr_time := _row[4];
          _res_mod_time := _row[5];
          _res_uname := _row[6];
          _res_gname := _row[7];

          -- store resource
          _row := vector(
              _colname,
              _res_name,
              blob_to_string (_row[1]),
              _res_type,
              _res_perms,
              _res_uname,
              _res_gname,
              _res_cr_time,
              _res_mod_time,
              concat ('nolog:', _rowguid),
              _origin);
          _stat := '00000';
          _msg := '';
          if (0 <> rexecute (_dsn, 'select DB.DBA.REPL_DAV_STORE_RES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, null)',
                       _stat, _msg, _row, null, null, _row))
            {
              dbg_printf ('REPL_DAV_PUSH: %s: %s', _stat, _msg);
              return 1;
            }
          if (length (_row) <> 1 or length (_row[0]) <> 1)
            {
              dbg_printf ('REPL_DAV_PUSH: no result from DAV_REPL_STORE_RES');
              return 1;
            }
          _rc := cast (_row[0][0] as integer);
          if (_rc < 0)
            {
              dbg_printf ('REPL_DAV_PUSH: DAV_REPL_STORE_RES returned %d',
                  _rc);
              return 1;
            }
        }
      else
        {
          --
          -- delete resource
          _stat := '00000';
          _msg := '';
          if (0 <> rexecute (_dsn, 'update WS.WS.SYS_DAV_RES set ROWGUID = ? where RES_COL = ? and RES_NAME = ?',
                       _stat, _msg, vector (
                           concat ('delete:nolog:', _old_rowguid),
                           _remote_colid, _res_name)))
            {
              dbg_printf ('REPL_DAV_PUSH: UPDATE(DELETE): %s: %s',
                  _stat, _msg);
              return 1;
            }
        }
next_rec:
      ;
    }
done:
  exec_close (_cr);

  --
  -- dive into subcollections
  --dbg_printf ('colid [%d]', _colid);
  for select COL_NAME, COL_ID, COL_PERMS, U_NAME, G_NAME
      from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
      where COL_PARENT = _colid and COL_OWNER = U_ID and COL_GROUP = G_ID do
    {
      if (COL_NAME <> '_SYS_REPL_BACKUP')
        {
          if (0 <> REPL_DAV_PUSH (
                   _server, _dsn,
                   concat (_colname, COL_NAME, '/'), COL_ID, COL_PERMS,
                   U_NAME, G_NAME,
                   _last_ts))
            return 1;
        }
    }
  return 0;
}
;

--
-- do initial copy of specified DAV snapshot collection
-- to specified DSN
create procedure REPL_INIT_DAV_SNAPSHOT (
    in _dsn varchar, in _colname varchar,
    in _colid integer, in _perms varchar,
    in _uname varchar, in _gname varchar)
{
  declare _row any;
  declare _rc integer;
  declare _stat, _msg varchar;

  _stat := '00000';
  _msg := '';
  _row := vector (
      vector ('out', 'integer', 0),
      _colname,
      _perms,
      _uname,
      _gname);
  if (0 <> rexecute (_dsn, '{? = call DB.DBA.DAV_COL_CREATE_INT (?, ?, ?, ?, null, null, 0, 0, 0)}',
               _stat, _msg, _row))
    signal (_stat, _msg);
  _rc := _row[0];
  if (_rc < 0)
    {
      signal ('37000',
          sprintf ('DAV_COL_CREATE_INT returned %d', _rc),
          'TR138');
    }

  declare _res_name, _res_content, _res_perms, _res_type, _rowguid varchar;
  declare _res_uname, _res_gname varchar;
  declare _res_cr_time, _res_mod_time datetime;
  declare _cr cursor for
      select RES_NAME, cast (RES_CONTENT as varchar), RES_PERMS, RES_TYPE,
          RES_CR_TIME, RES_MOD_TIME, ROWGUID,
          U_NAME, G_NAME
      from WS.WS.SYS_DAV_RES
      left join WS.WS.SYS_DAV_USER on (RES_OWNER = U_ID)
      left join WS.WS.SYS_DAV_GROUP on (RES_GROUP = G_ID)
      where RES_COL = _colid;
  --dbg_printf ('_colname: [%s], _colid: %d', _colname, _colid);
  open _cr;
  declare exit handler for not found goto done;
  while (1)
    {
      fetch _cr into _res_name, _res_content, _res_perms, _res_type,
          _res_cr_time, _res_mod_time, _rowguid, _res_uname, _res_gname;
      --dbg_printf ('_res_name: [%s]', _res_name);

      _stat := '00000';
      _msg := '';
      _row := vector (
          concat (_colname, _res_name),
          _res_content,
          _res_type,
          _res_perms,
          _res_uname,
          _res_gname,
          _res_cr_time,
          _res_mod_time,
          concat ('nolog:', _rowguid));
      if (0 <> rexecute (_dsn, 'select DAV_RES_UPLOAD_STRSES_INT (?, ?, ?, ?, ?, ?, null, null, 0, ?, ?, ?)',
               _stat, _msg, _row, null, null, _row))
        signal (_stat, _msg);
      if (length (_row) <> 1 or length (_row[0]) <> 1)
        {
          signal ('37000',
              sprintf ('No result from DAV_RES_UPLOAD_STRSES_INT %d', _rc),
              'TR138');
        }
      _rc := cast (_row[0][0] as integer);
      if (_rc < 0)
        {
          signal ('37000',
              sprintf ('DAV_RES_UPLOAD_STRSES_INT returned %d', _rc),
              'TR139');
        }
      commit work;
    }
done:

  --
  -- dive into subcollections
  for select COL_NAME, COL_ID, COL_PERMS, U_NAME, G_NAME
      from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
      where COL_PARENT = _colid and COL_OWNER = U_ID and COL_GROUP = G_ID do
    {
      if (COL_NAME <> '_SYS_REPL_BACKUP')
        {
          REPL_INIT_DAV_SNAPSHOT (
              _dsn, concat (_colname, COL_NAME, '/'),
              COL_ID, COL_PERMS, U_NAME, G_NAME);
        }
    }
  return 0;
}
;

--
-- update specified DAV snapshot publication
create procedure REPL_UPDATE_DAV_SNAPSHOT (in _colname varchar)
{
  declare _dsn, _perms varchar;
  declare _colid integer;
  declare _uname, _gname varchar;

  --
  -- pull updates from subscribers
  for select SS_SERVER as _server, SS_LAST_PULL_TS as _last_ts
      from DB.DBA.SYS_SNAPSHOT_SUB
      where SS_ITEM = _colname and SS_TYPE = 1 do
    {
      _dsn := REPL_DSN (_server);
      if (_dsn is null)
        {
          dbg_printf ('ERROR: %s: Replication server not found', _server);
          goto next_subscriber;
        }
      --dbg_printf ('REPL_UPDATE_DAV_SNAPSHOT: pull updates from ''%s''', _server);

      declare _row any;
      declare _stat, _msg varchar;
      _stat := '00000';
      _msg := '';
      if (0 <> rexecute (_dsn, 'select COL_ID, COL_PERMS, U_NAME, G_NAME
from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
where COL_ID = DB.DBA.DAV_SEARCH_ID (?, ''c'')
and COL_OWNER = U_ID and COL_GROUP = G_ID',
              _stat, _msg, vector (_colname), 1, null, _row))
        {
          dbg_printf ('REPL_UPDATE_DAV_SNAPSHOT: %s: %s', _stat, _msg);
          goto next_subscriber;
          return 1;
        }
      if (length (_row) <> 1 or length (_row[0]) <> 4)
        {
          dbg_printf ('REPL_UPDATE_DAV_SNAPSHOT: %s: Can''t get remote DAV collection info', _colname);
          goto next_subscriber;
        }
      _colid := _row[0][0];
      _perms := _row[0][1];
      _uname := _row[0][2];
      _gname := _row[0][3];
      if (0 = REPL_DAV_PULL (
              _server, _dsn, _colname, _colid, _perms, _uname, _gname,
              _last_ts, _colname))
        {
          update DB.DBA.SYS_SNAPSHOT_SUB set SS_LAST_PULL_TS = REPL_GETDATE(_dsn)
              where SS_SERVER = _server and SS_ITEM = _colname and SS_TYPE = 1;
          commit work;
        }
      else
        {
          rollback work;
        }
next_subscriber:
      ;
    }

  --
  -- push updates from publisher to subscribers
  for select SS_SERVER as _server, SS_LAST_PUSH_TS as _last_ts
      from DB.DBA.SYS_SNAPSHOT_SUB
      where SS_ITEM = _colname and SS_TYPE = 1 do
    {
      _dsn := REPL_DSN (_server);
      if (_dsn is null)
        {
          dbg_printf('ERROR: %s: Replication server not found', _server);
          goto next_sub;
        }
      --dbg_printf ('REPL_UPDATE_DAV_SNAPSHOT: push updates to ''%s''', _server);

      declare exit handler for not found
        {
          dbg_printf ('REPL_UPDATE_DAV_SNAPSHOT: %s: Collection not found',
            _colname);
          goto next_sub;
        };
      select COL_ID, COL_PERMS, U_NAME, G_NAME
          into _colid, _perms, _uname, _gname
          from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
          where COL_ID = DB.DBA.DAV_SEARCH_ID (_colname, 'c')
          and COL_OWNER = U_ID and COL_GROUP = G_ID;
      if (0 = REPL_DAV_PUSH (
                  _server, _dsn, _colname, _colid, _perms, _uname, _gname,
                  _last_ts))
        {
          update SYS_SNAPSHOT_SUB set SS_LAST_PUSH_TS = REPL_GETDATE()
             where SS_SERVER = _server and SS_ITEM = _colname and SS_TYPE = 1;
          commit work;
        }
      else
        {
          rollback work;
        }
next_sub:
      ;
    }
  update SYS_SNAPSHOT_PUB set SP_LAST_TS = REPL_GETDATE()
      where SP_ITEM = _colname and SP_TYPE = 1;
}
;

create procedure REPL_ADD_DAV_CR (
    in _colname varchar,      -- dav collection for which conflict resolver
                              -- is added
    in _name_suffix varchar,  -- resolver name suffix
    in _order integer,        -- resolver order
    in _class varchar)        -- resolver class
{
  -- check _colname
  _colname := REPL_COMPLETE_COLNAME (_colname);
  declare _colid integer;
  _colid := DAV_SEARCH_ID (_colname, 'c');
  if (_colid < 0)
    signal ('37000', concat ('The collection \'' , _colname, '\' does not exist'), 'TR109');

  -- check _name_suffix
  if (length (_name_suffix) = 0)
    signal ('22023', concat ('Empty resolver name suffix'), 'TR124');
  _name_suffix := SYS_ALFANUM_NAME (_name_suffix);

  -- build procedure name
  declare _cr_proc_name varchar;
  _cr_proc_name := sprintf ('DB.DBA.replcr_%s_%s',
      _colname, _name_suffix);

  -- check that conflict resolver with such name does not exist
  if (exists (select 1 from DB.DBA.SYS_DAV_CR
                 where CR_COL_NAME = _colname and CR_PROC = _cr_proc_name))
    {
      signal (
        '37000',
        concat ('Conflict resolver for \'', _colname, '\' with name ',
            _cr_proc_name, ' already exists'),
        'TR110');
    }

  -- generate resolver
  declare _stmt varchar;
  _stmt := sprintf (
'create procedure DB.DBA."replcr_%I_%s" (
  in _res_col integer,
  in _res_name varchar,
  in _res_email varchar,
  inout _res_content any,
  inout _res_type varchar,
  inout _res_ctime datetime,
  inout _res_mtime datetime,
  inout _res_uname varchar,
  inout _res_gname varchar,
  inout _do_backup integer,
  inout _do_notify integer,
  inout _notify_email varchar,
  inout _notify_text varchar)
{',
      _colname, _name_suffix);
  if (_class = 'max_mtime')
    {
      _stmt := concat (_stmt, '
  declare _loc_mtime datetime;
  select RES_MOD_TIME into _loc_mtime from WS.WS.SYS_DAV_RES
      where RES_COL = _res_col and RES_NAME = _res_name;
  if (_loc_mtime > _res_mtime)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'min_mtime')
    {
      _stmt := concat (_stmt, '
  declare _loc_mtime datetime;
  select RES_MOD_TIME into _loc_mtime from WS.WS.SYS_DAV_RES
      where RES_COL = _res_col and RES_NAME = _res_name;
  if (_loc_mtime < _res_mtime)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'max_ctime')
    {
      _stmt := concat (_stmt, '
  declare _loc_ctime datetime;
  select RES_CR_TIME into _loc_ctime from WS.WS.SYS_DAV_RES
      where RES_COL = _res_col and RES_NAME = _res_name;
  if (_loc_ctime > _res_ctime)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'min_ctime')
    {
      _stmt := concat (_stmt, '
  declare _loc_ctime datetime;
  select RES_CR_TIME into _loc_ctime from WS.WS.SYS_DAV_RES
      where RES_COL = _res_col and RES_NAME = _res_name;
  if (_loc_ctime < _res_ctime)
    return 3; -\- publisher wins
  return 1;   -\- subscriber wins');
    }
  else if (_class = 'backup')
    {
      _stmt := concat (_stmt, '
  _do_backup := 1;');
    }
  else if (_class = 'notify')
    {
      _stmt := concat (_stmt, '
  _do_notify := 1;');
    }
  else if (_class = 'pub_wins' or _class = 'custom')
    {
      _stmt := concat (_stmt, '
  return 3;   -\- publisher wins');
    }
  else if (_class = 'sub_wins')
    {
      _stmt := concat (_stmt, '
  return 1;   -\- subscriber wins');
    }
  else
    signal ('22023', concat ('Invalid resolver class \'', _class, '\''), 'TR125');
  _stmt := concat (_stmt, '
}');
  --dbg_printf ('REPL_ADD_DAV_CR:\n%s', _stmt);

  -- create conflict resolver
  declare _stat, _msg varchar;
  _stat := '00000';
  _msg := '';
  if (0 <> exec (_stmt, _stat, _msg))
    signal (_stat, _msg);

  -- register conflict resolver
  _stat := '00000';
  _msg := '';
  _stmt := 'insert into DB.DBA.SYS_DAV_CR (CR_ID, CR_COL_NAME, CR_PROC, CR_ORDER) values (coalesce ((select max(CR_ID) + 1 from DB.DBA.SYS_DAV_CR), 0), ?, ?, ?)';
  if (0 <> exec (_stmt, _stat, _msg, vector (_colname, _cr_proc_name, _order)))
    signal (_stat, _msg);

  return 0;
}
;

--
-- init rplog
create procedure REPL_INIT_RPLOG (
    in _server varchar, in _dsn varchar, in _tbl varchar)
{
  declare _stmt, _stat, _msg varchar;
  declare _rplog_tbl, _rlog, _rlog_tbl varchar;
  _rplog_tbl := sprintf ('"%I"."%I"."RPLOG_%I"',
      name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2));
  _rlog := att_local_name (_dsn, _tbl);
  _rlog_tbl := sprintf ('"%I"."%I"."RLOG_%I"',
      name_part (_rlog, 0), name_part (_rlog, 1), name_part (_rlog, 2));

  --
  -- local to remote
  _stmt := sprintf ('insert replacing %s(SOURCE, TARGET, RLOG_ROWGUID, SNAPTIME) select ?, ?, RLOG_ROWGUID, SNAPTIME from %s where SNAPTIME > ?',
      _rplog_tbl, _rlog_tbl);
  --dbg_printf ('stmt: [%s]', _stmt);
  _stat := '';
  _msg := '00000';
  if (0 <> exec (_stmt, _stat, _msg, vector (repl_this_server(), _server, REPL_PURGE_STARTTIME (REPL_GETDATE()))))
    signal (_stat, _msg);

  --
  -- remote to local
  _stmt := sprintf ('insert replacing %s(SOURCE, TARGET, RLOG_ROWGUID, SNAPTIME) select ?, ?, RLOG_ROWGUID, SNAPTIME from %s where SNAPTIME > ?',
      _rplog_tbl, _rlog_tbl);
  --dbg_printf ('stmt: [%s]', _stmt);
  _stat := '';
  _msg := '00000';
  if (0 <> exec (_stmt, _stat, _msg, vector (_server, repl_this_server(), REPL_PURGE_STARTTIME (REPL_GETDATE(_dsn)))))
    signal (_stat, _msg);

  if (not exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'purge_urplogs'))
    {
      insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
          values ('purge_urplogs', now (), 30, 'DB.DBA.REPL_PURGE_URPLOGS ()');
    }
}
;

--
-- init bidirectional snapshot
create procedure REPL_INIT_SNAPSHOT (
    in _server varchar, in _item varchar, in _type integer,
    in _how_many integer := 100)
{
  if (_type = 1)
    _item := REPL_COMPLETE_COLNAME (_item);
  else if (_type = 2)
    _item := complete_table_name (_item, 1);

  --
  -- check that publication exists
  if (not exists (select 1 from DB.DBA.SYS_SNAPSHOT_PUB
		  where SP_ITEM = _item and SP_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot publication of ''%s'' does not exist',
              _item),
          'TR133');
    }

  --
  -- check that subscription exists
  if (not exists (select 1 from DB.DBA.SYS_SNAPSHOT_SUB
		  where SS_SERVER = _server and SS_ITEM = _item
                  and SS_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot subscription of ''%s'' for ''%s'' does not exist',
              _server, _item),
          'TR134');
    }

  declare _dsn varchar;
  _dsn := REPL_DSN (_server);
  if (_dsn is null)
    {
      signal ('37000',
          sprintf ('The replication server ''%s'' does not exist',
              _server),
          'TR135');
    }

  declare _stat, _msg varchar;
  if (_type = 1)
    {
      declare exit handler for not found {
        signal ('37000', sprintf ('Collection ''%s'' not found', _item),
            'TR138');
      };
      declare _colid integer;
      declare _perms, _uname, _gname varchar;
      select COL_ID, COL_PERMS, U_NAME, G_NAME
          into _colid, _perms, _uname, _gname
          from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_USER, WS.WS.SYS_DAV_GROUP
          where COL_ID = DB.DBA.DAV_SEARCH_ID (_item, 'c')
          and COL_OWNER = U_ID and COL_GROUP = G_ID;

      declare _row any;
      _row := vector (_item);
      if (0 <> rexecute (_dsn, 'select DAV_DELETE_INT (?, 0, null, null, 0)',
                    _stat, _msg, _row, null, null, _row))
        signal (_stat, _msg);
      if (length (_row) <> 1 or length (_row[0]) <> 1)
        signal ('37000', 'No result from DAV_DELETE', 'TR136');
      declare _rc integer;
      _rc := cast (_row[0][0] as integer);
      if (_rc < 0 and _rc <> -1)
        {
          signal ('37000',
              sprintf ('DAV_DELETE returned %d', _rc),
              'TR137');
        }

      REPL_INIT_DAV_SNAPSHOT (_dsn, _item, _colid, _perms, _uname, _gname);
      declare _rlog varchar;
      _rlog := REPL_ENSURE_TABLE_ATTACHED (_dsn, 'WS.WS.RLOG_SYS_DAV_RES');
      --dbg_printf ('rlog: [%s]', _rlog);
      REPL_INIT_RPLOG (_server, _dsn, 'WS.WS.SYS_DAV_RES');
      _stat := '00000';
      _msg := '';
      exec (sprintf ('drop table %s', REPL_FQNAME (_rlog)), _stat, _msg);
    }
  else if (_type = 2)
    {
      declare _remote_tbl varchar;
      _remote_tbl := att_local_name (_dsn, _item);

      -- delete rows in target table
      _stat := '00000';
      _msg := '';
      if (0 <> exec (sprintf ('delete from %s', REPL_FQNAME (_remote_tbl)),
              _stat, _msg))
        signal (_stat, _msg);
      commit work;

      -- generate update proc
      declare _pn varchar;
      _pn := repl_create_update_proc (
          sprintf ('select <ALLCOLS> from %s', REPL_FQNAME (_item)),
          REPL_ALL_COLS (_item), _remote_tbl, _dsn, _how_many);

      -- copy data incrementally
      declare _bm integer;
      _bm := null;
      while (1)
        {
          --dbg_printf ('Calling [%s]', _pn);
          _bm := call (_pn) (_bm, _how_many);
          if (_bm is null)
            goto done;
          commit work;
        }

done:
      -- cleanup
      _stat := '00000';
      _msg := '';
      exec (sprintf ('drop procedure %s', REPL_FQNAME (_pn)), _stat, _msg);

      REPL_INIT_RPLOG (_server, _dsn, _item);
    }

  update DB.DBA.SYS_SNAPSHOT_SUB
      set SS_LAST_PULL_TS = REPL_GETDATE(_dsn), SS_LAST_PUSH_TS = REPL_GETDATE()
      where SS_SERVER = _server and SS_ITEM = _item and SS_TYPE = _type;
  update DB.DBA.SYS_SNAPSHOT_PUB
      set SP_LAST_TS = REPL_GETDATE()
      where SP_ITEM = _item and SP_TYPE = _type;
}
;

--
-- update bidirectional snapshot
create procedure REPL_UPDATE_SNAPSHOT (in _item varchar, in _type integer)
{
  if (_type = 1)
    _item := REPL_COMPLETE_COLNAME (_item);
  else if (_type = 2)
    _item := complete_table_name (_item, 1);

  --
  -- check that publication exists
  if (not exists (select 1 from DB.DBA.SYS_SNAPSHOT_PUB
		  where SP_ITEM = _item and SP_TYPE = _type))
    {
      signal ('37000',
          sprintf ('The snapshot publication of ''%s'' does not exist',
              _item),
          'TR126');
    }

  if (_type = 1)
    REPL_UPDATE_DAV_SNAPSHOT (_item);
  else if (_type = 2)
    {
      declare _update_proc varchar;
      _update_proc := sprintf ('%s.%s.REPL_UPDATE_TABLE_%s',
          name_part (_item, 0), name_part (_item, 1), name_part (_item, 2));
      call (_update_proc) ();
    }
}
;

create procedure REPL_PURGE_RPLOGS ()
{
  --dbg_printf ('REPL_PURGE_RPLOGS: start');
  for select distinct (SN_SOURCE_TABLE) as _src from DB.DBA.SYS_SNAPSHOT
      where SN_IS_INCREMENTAL is not null do
    {
      declare _rplog_tbl varchar;
      _rplog_tbl := sprintf ('"%I"."%I"."RPLOG_%I"',
          name_part (_src, 0), name_part (_src, 1), name_part (_src, 2));
      declare _stmt, _stat, _msg varchar;
      _stmt := sprintf ('delete from %s where TARGET = ? and SNAPTIME < ?',
          _rplog_tbl);
      --dbg_printf ('REPL_PURGE_RPLOGS: tbl [%s], stmt [%s]', _src, _stmt);

      for select SN_NAME as _dst, REPL_PURGE_STARTTIME(SN_LAST_TS) as _starttime
          from DB.DBA.SYS_SNAPSHOT
          where SN_IS_INCREMENTAL is not null
          and SN_SOURCE_TABLE = _src
          and SN_LAST_TS is not null do
        {
          _stat := '00000';
          _msg := '';
          if (0 <> exec (_stmt, _stat, _msg, vector (_dst, _starttime)))
            dbg_printf ('REPL_PURGE_RPLOGS: ERROR: %s: %s', _stat, _msg);
          else
            {
              --dbg_printf ('REPL_PURGE_RPLOGS: dst [%s] (%d records purged)',
              --    _dst, row_count ());
              ;
            }
        }
    }
  --dbg_printf ('REPL_PURGE_RPLOGS: end');
}
;

create procedure REPL_PURGE_URPLOGS ()
{
  --dbg_printf ('REPL_PURGE_URPLOGS: start');
  for select SP_ITEM as _src from DB.DBA.SYS_SNAPSHOT_PUB where SP_TYPE = 2 do
    {
      declare _rplog_tbl varchar;
      _rplog_tbl := sprintf ('"%I"."%I"."RPLOG_%I"',
          name_part (_src, 0), name_part (_src, 1), name_part (_src, 2));
      declare _stmt, _stat, _msg varchar;
      _stmt := sprintf ('delete from %s where SOURCE = ? and TARGET = ? and SNAPTIME < ?',
          _rplog_tbl);
      --dbg_printf ('REPL_PURGE_URPLOGS: tbl [%s], stmt [%s]', _src, _stmt);

      --
      -- remote -> local
      for select SS_SERVER as _dst, REPL_PURGE_STARTTIME(SS_LAST_PULL_TS) as _starttime
          from DB.DBA.SYS_SNAPSHOT_SUB
          where SS_ITEM = _src and SS_TYPE = 2
          and SS_LAST_PULL_TS is not null do
        {
          _stat := '00000';
          _msg := '';
          if (0 <> exec (_stmt, _stat, _msg, vector (repl_this_server(), _dst, _starttime)))
            dbg_printf ('REPL_PURGE_URPLOGS: ERROR: %s: %s', _stat, _msg);
          else
            {
              --dbg_printf ('REPL_PURGE_URPLOGS: src [%s] (%d records purged)',
              --    _dst, row_count ());
              ;
            }
        }

      --
      -- local -> remote
      for select SS_SERVER as _dst, REPL_PURGE_STARTTIME(SS_LAST_PUSH_TS) as _starttime
          from DB.DBA.SYS_SNAPSHOT_SUB
          where SS_ITEM = _src and SS_TYPE = 2
          and SS_LAST_PUSH_TS is not null do
        {
          _stat := '00000';
          _msg := '';
          if (0 <> exec (_stmt, _stat, _msg, vector (_dst, repl_this_server(), _starttime)))
            dbg_printf ('REPL_PURGE_URPLOGS: ERROR: %s: %s', _stat, _msg);
          else
            {
              --dbg_printf ('REPL_PURGE_URPLOGS: dst [%s] (%d records purged)',
              --    _dst, row_count());
              ;
            }
        }
    }
  --dbg_printf ('REPL_PURGE_URPLOGS: end');
}
;
