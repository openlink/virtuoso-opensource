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
create procedure "DB"."DBA"."VAD_VERSION" () returns varchar
{
  return '1.0.010505A';
}
;

create procedure "DB"."DBA"."VAD_EXEC_RETRYING" (in _expn varchar)
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

create procedure "DB"."DBA"."VAD_ASSERT2" (in _val integer, in _text varchar)
{
  if (not _val)
    signal ('42VAD', _text);
}
;

create procedure "DB"."DBA"."VAD_ASSERT" (in _expn varchar)
{
  "DB"."DBA"."VAD_EXEC_RETRYING" (
    concat (
      '"DB"."DBA"."VAD_ASSERT2"((', _expn, '), concat (''Assertion failed: '', ',
      "WS"."WS"."STR_SQL_APOS"(_expn), '))' ) );
}
;

create procedure "DB"."DBA"."VAD_NAME_MERGE" (in _db varchar, in _user varchar, in _name varchar, in _col varchar := null)
{
  declare _res varchar;
  _res := concat ('"',_db,'"."',_user,'"."',_name,'"');
  if (_col is not null)
    _res := concat (_res,'."',_col,'"');
  return _res;
}
;

create procedure "DB"."DBA"."VAD_DROP_TABLE" (in _db varchar, in _user varchar, in _name varchar)
{
  declare _tblname varchar;
  _tblname := "DB"."DBA"."VAD_NAME_MERGE" (_db, _user, _name);
  if (not exists (select KEY_TABLE from "DB"."DBA"."SYS_KEYS" where "KEY_TABLE" = _tblname))
    return;
  "DB"."DBA"."VAD_EXEC_RETRYING" (concat ('drop table ', _tblname));
  "DB"."DBA"."VAD_EXEC_RETRYING" (concat ('drop table ', _tblname));
}
;

create procedure "DB"."DBA"."VAD_CREATE_TABLE" (in _db varchar, in _user varchar, in _name varchar, in _text varchar)
{
  declare _tblname varchar;
  _tblname := "DB"."DBA"."VAD_NAME_MERGE" (_db, _user, _name);
  if (not exists (select "KEY_TABLE" from "DB"."DBA"."SYS_KEYS" where "KEY_TABLE" = _tblname))
    {
      "DB"."DBA"."VAD_EXEC_RETRYING" (concat ('create table ', _tblname, ' ', _text));
    }
}
;

create procedure "DB"."DBA"."VAD_RECREATE_TABLE" (in _db varchar, in _user varchar, in _name varchar, in _text varchar)
{
  "DB"."DBA"."VAD_DROP_TABLE" (_db, _user, _name);
  "DB"."DBA"."VAD_CREATE_TABLE" (_db, _user, _name, _text);
  commit work;
}
;

"DB"."DBA"."VAD_CREATE_TABLE" ('DB', 'DBA', 'VAD_REGISTRY',
  '(
	R_KEY	varchar,
	R_TYPE	varchar,
	R_VALUE	varchar,
	primary key (R_KEY) )' )
;

create procedure "DB"."DBA"."VAD_RSAVE" (in _key varchar, in _type varchar, in _value any)
{
  declare _oldtype varchar;
  if (not exists (select 1 from "DB"."DBA"."VAD_REGISTRY" where R_KEY=_key))
    {
      if (_value is null)
	return;
      insert into "DB"."DBA"."VAD_REGISTRY"
		( R_KEY		, R_TYPE	, R_VALUE	)
      values	( _key		, _type		, _value	);
    }
  else
    {
      if (_value is null)
	{
	  delete from "DB"."DBA"."VAD_REGISTRY" where R_KEY=_key;
	  return;
	}
      select R_TYPE into _oldtype from "DB"."DBA"."VAD_REGISTRY" where R_KEY=_key;
      if (_type <> _oldtype)
	signal ('42VAD',
	  concat ('Attempt to overwrite VAD Registry key ',
	    "WS"."WS"."STR_SQL_APOS"(_key), ' of type ', _oldtype,
	    ' by value of type ', _type, '.' ) );
      update "DB"."DBA"."VAD_REGISTRY" set R_VALUE = cast (_value as varchar)
      where R_KEY=_key;
    }
}
;

create procedure "DB"."DBA"."VAD_RGET" (in _key varchar) returns any
{
  declare _type varchar;
  declare _value long varchar;
  if (not exists (select 1 from "DB"."DBA"."VAD_REGISTRY" where R_KEY=_key))
    return null;
  select "R_TYPE", "R_VALUE" into _type, _value
    from "DB"."DBA"."VAD_REGISTRY" where R_KEY=_key;
  if ('STRING' = _type)
    return cast (_value as varchar);
  if ('INTEGER' = _type)
    return cast (_value as integer);
  if ('KEY' = _type)
    {
      declare _res varchar;
      _res := cast (_value as varchar);
      if (_res = '')
	return _key;
      if (aref(_res,0) = '/')
	return _res;
      return concat (_key,'/',_res);
    }
  if ('URL' = _type)
    return cast (_value as varchar);
  if ('XML' = _type)
    return xml_tree_doc (xml_tree (_value));
  signal ('42VAD', 
    concat ('VAD Registry key ',
      "WS"."WS"."STR_SQL_APOS"(_key), ' contains value of unsupported type ', _type, '.' ) );
}
;

create procedure "DB"."DBA"."VAD_RKEY_PATH_COMPONENTS" (in _key varchar) returns any
{
  declare _res any;
  declare _pos integer;
  _res := vector();
  _pos := strchr (_key,'#');
  if (_pos is not null)
   _key := left (_key, _pos);
  _pos := strchr (_key,'?');
  if (_pos is not null)
   _key := left (_key, _pos);
  if (_key = '')
    return null;
  if (_key = '/')
    return _res;
  if (left (_key, 1) <> '/')
    return null;
  if (right (_key, 1) = '/')
    return null;
  _key := right (_key, length (_key)-1);
again:
  _pos := strchr (_key,'/');
  if (_pos is null)
    goto done;
  _res := vector_concat (_res, vector (left (_key, _pos)));
  _key := right (_key, length (_key)-(_pos+1));
  goto again;
done:
  _res := vector_concat (_res, vector (_key));
  return _res;
}
;

create procedure "DB"."DBA"."VAD_RKEY_ANCHOR" (in _key varchar) returns varchar
{
  declare _pos integer;
  _pos := strchr (_key,'#');
  if (_pos is null)
    return null;
  _key := right (_key, length (_key)-(_pos+1));
  return _key;
}
;

create procedure "DB"."DBA"."VAD_RKEY_PARAMS" (in _key varchar) returns varchar
{
  declare _pos integer;
  _pos := strchr (_key,'?');
  if (_pos is null)
    return null;
  _key := right (_key, length (_key)-(_pos+1));
  _pos := strchr (_key,'#');
  if (_pos is not null)
   _key := left (_key, _pos);
  return _key;
}
;

create procedure "DB"."DBA"."VAD_RKEY_PATH_COMPONENTS" (in _key varchar) returns any
{
  declare _res any;
  declare _pos integer;
  _res := vector();
  _pos := strchr (_key,'#');
  if (_pos is not null)
   _key := left (_key, _pos);
  _pos := strchr (_key,'?');
  if (_pos is not null)
   _key := left (_key, _pos);
  if (_key = '')
    return null;
  if (_key = '/')
    return _res;
  if (left (_key, 1) <> '/')
    return null;
  if (right (_key, 1) = '/')
    return null;
  _key := right (_key, length (_key)-1);
again:
  _pos := strchr (_key,'/');
  if (_pos is null)
    goto done;
  _res := vector_concat (_res, vector (left (_key, _pos)));
  _key := right (_key, length (_key)-(_pos+1));
  goto again;
done:
  _res := vector_concat (_res, vector (_key));
  return _res;
}
;


"DB"."DBA"."VAD_RSAVE" ('/DOCS?help=doc'	, 'STRING'	, 'Virtuoso Application Deployment - Administrator''s Guide#vad_registry_DOCS');
"DB"."DBA"."VAD_RSAVE" ('/DOCS?help=hint'	, 'STRING'	, 'Directory of all available documents about your Virtuoso Server and Virtuoso-based applications');
"DB"."DBA"."VAD_RSAVE" ('/FILES?help=doc'	, 'STRING'	, 'Virtuoso Application Deployment - Administrator''s Guide#vad_registry_FILES');
"DB"."DBA"."VAD_RSAVE" ('/FILES?help=hint'	, 'STRING'	, 'Information about various files in working directories of Virtuoso');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA?help=doc'	, 'STRING'	, 'Virtuoso Application Deployment - Administrator''s Guide#vad_registry_SCHEMA');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA?help=hint'	, 'STRING'	, 'Descriptions of PL/SQL procedures and various objects of your database schema');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA/DB?help=hint'	, 'STRING'	, 'Default database');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA/DB/DBA?help=hint'	, 'STRING'	, 'Database Administrator');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA/DB/DBA/VAD_REGISTRY+(table)?help=hint'	, 'STRING'	, 'Table of configuration parameters for various applications, mostly for VAD packages');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA/DB/DBA/VAD_REGISTRY+(table)#Created+by'	, 'KEY'		, '/VAD/vad');
"DB"."DBA"."VAD_RSAVE" ('/SCHEMA/DBV?help=hint'	, 'STRING'	, 'DocBookView database');
"DB"."DBA"."VAD_RSAVE" ('/VAD?help=doc'		, 'STRING'	, 'Virtuoso Application Deployment - Administrator''s Guide#vad_registry_VAD');
"DB"."DBA"."VAD_RSAVE" ('/VAD?help=hint'	, 'STRING'	, 'Collection ov various application-specific data');
"DB"."DBA"."VAD_RSAVE" ('/VAD/vad#Current+version'	, 'KEY'	, "DB"."DBA"."VAD_VERSION" ());
"DB"."DBA"."VAD_RSAVE" (concat ('/VAD/vad/', "DB"."DBA"."VAD_VERSION" (),'/Sticker/Current+status')	, 'STRING'	, 'Installed');
