--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
create procedure DB.DBA.RDF_EXEC_41000_I (in _expn varchar)
{
  declare _state, _message varchar;
  declare _retries integer;
  _state := '';
  _retries := 0;
  while(1)
    {
      exec (_expn, _state, _message);
      if (_state <> '41000')
        return;
      if (_retries > 10)
	signal ('41000', concat ('Continuous deadlocks in\n', _expn, '\n'));
      _retries := _retries+1;
    }
}
;

create procedure DB.DBA.RDF_EXEC_41000 (in _expn varchar)
{
  declare _state, _message varchar;
  declare _retries integer;
  _state := '';
  _retries := 0;
  while(1)
    {
      exec (_expn, _state, _message);
      if (_state = '')
	return;
      if (_state = '01W01')	-- "No WHENEVER statement provided for SQLCODE %d"
	return;
      if (_state <> '41000')
	signal (_state, concat (_message, ' in\n', _expn, '\n'));
      if (_retries > 10)
	signal ('41000', concat ('Continuous deadlocks in\n', _expn, '\n'));
      _retries := _retries+1;
    }
}
;

create procedure DB.DBA.RDF_ASSERT2 (in _val integer, in _text varchar)
{
  if (not _val)
    signal ('42RDF', _text);
}
;

create procedure DB.DBA.RDF_ASSERT (in _expn varchar)
{
  DB.DBA.RDF_EXEC_41000 (
    concat (
      'DB.DBA.RDF_ASSERT2((', _expn, '), concat (''Assertion failed: '', ',
      WS.WS.STR_SQL_APOS(_expn), '))' ) );
}
;

create procedure DB.DBA.RDF_DROP_TABLE (in _name varchar)
{
  if (not exists (select KEY_TABLE from DB.DBA.SYS_KEYS where KEY_TABLE = _name))
    return;
  DB.DBA.RDF_EXEC_41000_I (concat ('drop table ', _name));
  DB.DBA.RDF_EXEC_41000_I (concat ('drop table ', _name));
}
;

create procedure DB.DBA.RDF_RECREATE_TABLE (in _name varchar, in _text varchar)
{
  DB.DBA.RDF_DROP_TABLE (_name);
  DB.DBA.RDF_EXEC_41000 (concat ('create table ', _name, ' (', _text, ')'));
  commit work;
}
;

create procedure DB.DBA.RDF_RECREATE_NODEID_TABLE (in _name varchar)
{
  _name := concat(_name, '__NODE');
  DB.DBA.RDF_RECREATE_TABLE ( _name,
    concat(
	'	NAME		varchar not null, ',
	'	NODEID		integer not null, ',
	'	primary key (NAME) ' ) );
  DB.DBA.RDF_EXEC_41000 (
    concat('create index "', _name, '(NODEID)" on ', _name, ' (NODEID)')
    );
  DB.DBA.RDF_EXEC_41000 (
    concat(
	'create procedure ', _name, '_GET (in _name varchar)\n',
	'{\n',
	'  declare _nodeid integer;\n',
	'  if (_name is null)\n',
	'    return -9;\n',
	'  _name := cast (_name as varchar);',
	'  whenever sqlstate \'23000\' goto index_error;\n',
	'  whenever not found goto add_new;\n',
	'  select NODEID into _nodeid from ', _name ,' where NAME=_name;\n',
	'  return _nodeid;\n',
	'add_new:\n',
	'  _nodeid := sequence_next(\'_\');\n',
	'  while (exists (select 1 from ', _name, ' where NODEID=_nodeid))\n',
	'    _nodeid := sequence_next(\'_\');\n',
	'  insert into ', _name , ' (NAME, NODEID) values (_name, _nodeid);\n',
	'  return _nodeid;\n',
	'index_error:\n',
	'  signal(\'23000\', ',
	'    concat (',
	'      \'Index error in ', _name, '_GET (\', _name, \'), node_id=\', ',
	'      cast(_nodeid as varchar), \'\'));',
	'  }\n'
      ) );
  DB.DBA.RDF_EXEC_41000 (
    concat(
	'create procedure ', _name, '_CHECK (in _name varchar)\n',
	'{\n',
	'  declare _nodeid integer;\n',
	'  if (_name is null)\n',
	'    return 0;\n',
	'  _name := cast (_name as varchar);',
	'  whenever not found goto nfound;\n',
	'  select NODEID into _nodeid from ', _name ,' where NAME=_name;\n',
	'  return _nodeid;\n',
	'nfound:\n',
	'  return 0;\n',
	'  }\n'
      ) );
  commit work;
}
;

create procedure DB.DBA.RDF_RECREATE_XPER_TABLE (
  in _name varchar,
  in _has_text_index integer,
  in _text_index_batch varchar,
  in _batch_interval integer )
{
  DB.DBA.RDF_RECREATE_TABLE ( _name,
    concat(
	'	NODEID		integer, ',
	'	XPER		long varchar identified by NODEID, ',
	'	primary key (NODEID) ' ) );
  if (_has_text_index<>0)
    {
      DB.DBA.RDF_EXEC_41000_I (
        concat('create text xml index on ', _name, ' (XPER) with key NODEID')
        );
      DB.DBA.RDF_EXEC_41000_I (
        concat('DB.DBA.VT_BATCH_UPDATE(\'',_name,'\',\'',_text_index_batch,
        '\',',cast(_batch_interval as varchar),')' ) );
    }
  commit work;
}
;
