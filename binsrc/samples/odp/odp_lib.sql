--  
--  $Id$
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
DB.DBA.RDF_ASSERT ('equ (ODP.ODP.CODE_VERSION(), ''0.1.001011A'')');

--! Configuration handling
create procedure ODP.ODP.GETCFG (in _param varchar) returns varchar
{
  declare _value varchar;
  whenever not found goto nf;
  select VALUE into _value from ODP.ODP.CONFIG where (PARAM = _param) and VALUE is not null;
  return _value;
nf:
  signal('42ODP', concat('Config variable "', _param, '" is missing or invalid'));
}
;

create procedure ODP.ODP.SETCFG (in _param varchar, in _value varchar) returns varchar
{
  declare _old_value varchar;
  declare _cfg cursor for
    select VALUE from ODP.ODP.CONFIG where (PARAM = _param)
    for update;
  whenever not found goto nf;
  open _cfg;
  fetch _cfg into _old_value;
  update ODP.ODP.CONFIG set VALUE = _value where current of _cfg;
  close _cfg;
  return _value;
nf:
  close _cfg;
  insert into ODP.ODP.CONFIG (PARAM, VALUE) values (_param, _value);
  return _value;
}

create procedure ODP.ODP.ADDCFG (in _param varchar, in _value varchar) returns varchar
{
  declare _old_value varchar;
  whenever not found goto nf;
  select VALUE into _old_value from ODP.ODP.CONFIG where (PARAM = _param) and VALUE is not null;
  return _old_value;
nf:
  return ODP.ODP.SETCFG (_param, _value);
}

--! Processing of SOURCE table
create procedure ODP.ODP.ADD_SOURCE (in _id integer, in _name varchar)
{
  declare _old_name, _old_version varchar;
  declare _src cursor for
    select NAME, VERSION from ODP.ODP.SOURCE where (ID = _id)
    for update;
  whenever not found goto nf;
  open _src;
  fetch _src into _old_name, _old_version;
  DB.DBA.RDF_ASSERT2 (equ (_name, _old_name), concat ('Unexpected NAME in table SOURCE, ID=', cast(_id as varchar)));
  close _src;
  return _old_version;
nf:
  close _src;
  insert into ODP.ODP.SOURCE
	( ID	, NAME	, LOADPATH		, VERSION	, REFILL_STATUS	, REFILL_ERROR	, ERROR_VERSION	)
    values
	(_id	, _name	, '(not yet loaded)'	, ''		, 'NO SOURCE'	, ''		, ''		);
  return '';
}
;

create procedure ODP.ODP.LOAD_RDF1 (in _id integer, in _name varchar, in _filename varchar)
{
  declare _loadpath varchar;
  declare _version varchar;
  declare _sqlcode varchar;
  declare _message varchar;
  if (not exists (select ID from ODP.ODP.SOURCE where (ID = _id) and (NAME = _name)))
    DB.DBA.RDF_ASSERT2 (0, concat ('No record in SOURCE with ID=', cast(_id as varchar), ' and NAME=', _name));
  _loadpath := concat (ODP.ODP.GETCFG ('RDF/URI'), '/', _filename);
  _version := ODP.ODP.GETCFG('Version/RDF');
  if (not exists (select ID from ODP.ODP.SOURCE where (ID = _id) and (VERSION < _version)))
    return;
  _sqlcode := '00000';
  _message := '';
  exec (
    concat (
	'update ODP.ODP.SOURCE',
	'  set',
	'	LOADPATH	= ', WS.WS.STR_SQL_APOS(_loadpath), ',',
	'	REFILL_STATUS	= ''PASS 1 OK'',',
	'	REFILL_ERROR	= ''XML OK'',',
	'	VERSION		= ', WS.WS.STR_SQL_APOS(_version), ',',
	'	ORIG_DATA	= xml_persistent(', WS.WS.STR_SQL_APOS(_loadpath), ')',
	'  where (ID = ', cast(_id as varchar), ')' ),
    _sqlcode,
    _message );
  update ODP.ODP.SOURCE
    set
	ERROR_VERSION	= _version,
	REFILL_ERROR	= _message
    where (ID = _id);
  commit work;
}
;

create procedure ODP.ODP.LOAD_RDF2 (in _id integer, in _load_eh varchar, in _old_status varchar, in _new_status varchar)
{
  if (not exists (select ID from ODP.ODP.SOURCE where (ID = _id) and (ORIG_DATA is not null) and (REFILL_STATUS = _old_status)))
    return concat ('No row with ID=', cast(_id as varchar), ' and REFILL_STATUS=', _old_status);
  exec(_load_eh);
  update ODP.ODP.SOURCE
    set
	REFILL_STATUS = _new_status
    where (ID = _id);
  if (_new_status = 'PUBLISHED')
    update ODP.ODP.SOURCE
      set
	VERSION = ERROR_VERSION
      where (ID = _id);
  commit work;
  return concat ('Done row with ID=', cast(_id as varchar), ' and REFILL_STATUS=', _old_status);
}
;

create procedure ODP.ODP.LOAD_RDF (in _id integer, in _name varchar, in _filename varchar, in _load_eh varchar)
{
  ODP.ODP.LOAD_RDF1(_id,_name,_filename,_load_eh);
  ODP.ODP.LOAD_RDF2(_id,_load_eh,'','PUBLISHED');
}
;

-- This procedure should be capable to import 600 Mb of data.
-- It is impossible without intermediate 'commit work' statements:
-- even if transaction log is large enough to hold gigabytes of transaction
-- log, 32-bit memory addressing space will not be enough to store current
-- transaction in virtual memory. Thus 'commit work' is invoked after import
-- of some small number of records.
create procedure ODP.ODP.REFILL_CONTENT ()
{
  declare _frag any;
  declare _tag any;
  declare _nodeid any;
  declare _r_id varchar;
  declare _about, _title, _description varchar;
  declare CurTime varchar;
  declare Frags, Inserts, Pos, Length integer;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Content' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Content" is empty');
  Length := xper_length(_frag);
  Frags := 0;
  Inserts := 0;
  result_names (CurTime, Frags, Inserts, Pos, Length);
  whenever sqlstate '40001' goto next_frag;
next_frag:
  if (mod(Frags,10000) = 0)
    {
      CurTime := cast(now() as varchar);
      Pos := xper_tell(_frag);
      result (CurTime, Frags, Inserts, Pos, Length);
    }
  _tag := xpath_eval('local-name()', _frag);
  if (_tag = 'Topic')
    {
      _r_id := xpath_eval('@id', _frag);
      _nodeid := ODP.ODP.TOPIC__NODE_GET(_r_id);
      Frags := Frags+1;
      if (not exists (select 1 from ODP.ODP.TOPIC_CONTENT where NODEID=_nodeid))
        {
	  Inserts := Inserts+1;
          insert into ODP.ODP.TOPIC_CONTENT
		( NODEID	, XPER			)
            values
		( _nodeid	, xper_cut (_frag)	);
	}
      else
        update ODP.ODP.TOPIC_CONTENT
          set XPER = xper_cut (_frag) where NODEID=_nodeid;
      goto advance;
    }
  if (_tag = 'ExternalPage')
    {
      _about := cast (xpath_eval('@about', _frag) as varchar);
      _title := cast (xpath_eval('.//Title', _frag) as varchar);
      _description := cast (xpath_eval('.//Description', _frag) as varchar);
      _nodeid := ODP.ODP.PAGE__NODE_GET(_about);
      Frags := Frags+1;
      if (not exists (select 1 from ODP.ODP.PAGE_TITLE where NODEID=_nodeid))
        {
	  Inserts := Inserts+1;
          insert into ODP.ODP.PAGE_TITLE
		( NODEID	, TEXT		)
           values
		( _nodeid	, _title	);
	}
      else
        update ODP.ODP.PAGE_TITLE
          set TEXT = _title where NODEID=_nodeid;
      if (not exists (select 1 from ODP.ODP.PAGE_DESCRIPTION where NODEID=_nodeid))
        {
	  Inserts := Inserts+1;
          insert into ODP.ODP.PAGE_DESCRIPTION
		( NODEID	, TEXT		)
           values
		( _nodeid	, _description	);
	}
      else
        update ODP.ODP.PAGE_DESCRIPTION
          set TEXT = _description where NODEID=_nodeid;
      goto advance;
    }
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
  CurTime := cast(now() as varchar);
  result (CurTime, Frags, Inserts, Length, Length);
}
;

-- For very weak computers, running of ODP.ODP.REFILL_PAGE may be hard
-- even after all optimizations. For such cases, two separate procedures may
-- be used, with additional checkpoint between them: 
-- ODP.ODP.REFILL_PAGE_CONTENT and ODP.ODP.REFILL_TOPIC_CONTENT. Each of them
-- imports only half of data.
create procedure ODP.ODP.REFILL_PAGE_CONTENT ()
{
  declare _frag any;
  declare _tag any;
  declare _nodeid any;
  declare _r_id varchar;
  declare _about, _title, _description varchar;
  declare CurTime varchar;
  declare Frags, Inserts, Pos, Length integer;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Content' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Content" is empty');
  Length := xper_length(_frag);
  Frags := 0;
  Inserts := 0;
  result_names (CurTime, Frags, Inserts, Pos, Length);
  whenever sqlstate '40001' goto next_frag;
next_frag:
  if (mod(Frags,10000) = 0)
    {
      CurTime := cast(now() as varchar);
      Pos := xper_tell(_frag);
      result (CurTime, Frags, Inserts, Pos, Length);
    }
  _tag := xpath_eval('local-name()', _frag);
  if (_tag = 'ExternalPage')
    {
      _about := cast (xpath_eval('@about', _frag) as varchar);
      _title := cast (xpath_eval('.//Title', _frag) as varchar);
      _description := cast (xpath_eval('.//Description', _frag) as varchar);
      _nodeid := ODP.ODP.PAGE__NODE_GET(_about);
      Frags := Frags+1;
      if (not exists (select 1 from ODP.ODP.PAGE_TITLE where NODEID=_nodeid))
        {
	  Inserts := Inserts+1;
          insert into ODP.ODP.PAGE_TITLE
		( NODEID	, TEXT		)
           values
		( _nodeid	, _title	);
	}
      else
        update ODP.ODP.PAGE_TITLE
          set TEXT = _title where NODEID=_nodeid;
      if (not exists (select 1 from ODP.ODP.PAGE_DESCRIPTION where NODEID=_nodeid))
        {
	  Inserts := Inserts+1;
          insert into ODP.ODP.PAGE_DESCRIPTION
		( NODEID	, TEXT		)
           values
		( _nodeid	, _description	);
	}
      else
        update ODP.ODP.PAGE_DESCRIPTION
          set TEXT = _description where NODEID=_nodeid;
      goto advance;
    }
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
  CurTime := cast(now() as varchar);
  result (CurTime, Frags, Inserts, Length, Length);
}
;

create procedure ODP.ODP.REFILL_TOPIC_CONTENT ()
{
  declare _frag any;
  declare _tag any;
  declare _nodeid any;
  declare _r_id varchar;
  declare _about varchar;
  declare CurTime varchar;
  declare Frags, Inserts, Pos, Length integer;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Content' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Content" is empty');
  Length := xper_length(_frag);
  Frags := 0;
  Inserts := 0;
  result_names (CurTime, Frags, Inserts, Pos, Length);
  whenever sqlstate '40001' goto next_frag;
next_frag:
  if (mod(Frags,10000) = 0)
    {
      CurTime := cast(now() as varchar);
      Pos := xper_tell(_frag);
      result (CurTime, Frags, Inserts, Pos, Length);
    }
  _tag := xpath_eval('local-name()', _frag);
  if (_tag = 'Topic')
    {
      _r_id := xpath_eval('@id', _frag);
      _nodeid := ODP.ODP.TOPIC__NODE_GET(_r_id);
      Frags := Frags+1;
      if (not exists (select 1 from ODP.ODP.TOPIC_CONTENT where NODEID=_nodeid))
        {
	  Inserts := Inserts+1;
          insert into ODP.ODP.TOPIC_CONTENT
		( NODEID	, XPER			)
            values
		( _nodeid	, xper_cut (_frag)	);
	}
      else
        update ODP.ODP.TOPIC_CONTENT
          set XPER = xper_cut (_frag) where NODEID=_nodeid;
      goto advance;
    }
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
  CurTime := cast(now() as varchar);
  result (CurTime, Frags, Inserts, Length, Length);
}
;

create procedure ODP.ODP.REFILL_PROFILES ()
{
  declare _frag any;
  declare _r_id varchar;
  declare _nodeid integer;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Profiles' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Profiles" is empty');
  whenever sqlstate '40001' goto next_frag;
next_frag:
  _r_id := cast (xpath_eval('@id', _frag) as varchar);
  _nodeid := ODP.ODP.EDITOR__NODE_GET(_r_id);
  if (not exists (select 1 from ODP.ODP.EDITOR_PROFILE where NODEID=_nodeid))
    insert into ODP.ODP.EDITOR_PROFILE
            ( NODEID	, XPER			)
      values
            ( _nodeid	, xper_cut (_frag)	);
  else
    update ODP.ODP.EDITOR_PROFILE
      set XPER = xper_cut (_frag) where NODEID=_nodeid;
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
-- The following code is just a sample how you can import data up to
-- 100 Mb by using simple 'for' statement, without xper_right_sibling
-- and intermediate 'commit work' statements. This code is much more simple,
-- but the size of transaction may become prohibitively large.
  return; -- to bypass this sample code :)
  for
    select
      _frag,
      xpath_eval('@id', _frag) as _r_id
    from ODP.ODP.SOURCE
    where NAME = 'Profiles' and xpath_contains (ORIG_DATA, '/RDF/Profile', _frag)
  do
  {
    _nodeid := ODP.ODP.EDITOR__NODE_GET(_r_id);
    if (not exists (select 1 from ODP.ODP.EDITOR_PROFILE where NODEID=_nodeid))
      insert into ODP.ODP.EDITOR_PROFILE
              ( NODEID	, XPER			)
        values
              ( _nodeid	, xper_cut (_frag)	);
    else
      update ODP.ODP.EDITOR_PROFILE
        set XPER = xper_cut (_frag) where NODEID=_nodeid;
  }
}
;

create procedure ODP.ODP.REFILL_REDIRECT ()
{
  declare _frag any;
  declare _r_id varchar;
  declare _nodeid integer;
  declare _jumpto integer;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Redirect' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Redirect" is empty');
  whenever sqlstate '40001' goto next_frag;
next_frag:
  _r_id := cast (xpath_eval('@id', _frag) as varchar);
  _nodeid := ODP.ODP.TOPIC__NODE_GET(_r_id);
  _jumpto := ODP.ODP.TOPIC__NODE_GET(cast (xpath_eval('.//redirect/@resource', _frag) as varchar));
  if (not exists (select 1 from ODP.ODP.TOPIC_REDIRECT where NODEID=_nodeid))
    insert into ODP.ODP.TOPIC_REDIRECT
            ( NODEID	, JUMPTO	)
      values
            ( _nodeid	, _jumpto	);
  else
    update ODP.ODP.TOPIC_REDIRECT
      set JUMPTO = _jumpto where NODEID=_nodeid;
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
}
;

create procedure ODP.ODP.REFILL_STRUCTURE ()
{
  declare _frag any;
  declare _tag any;
  declare _nodeid integer;
  declare _r_id varchar;
  declare _title varchar;
  declare _jumpto integer;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Structure' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Structure" is empty');
  whenever sqlstate '40001' goto next_frag;
next_frag:
  _tag := xpath_eval('local-name()', _frag);
  if (_tag = 'Topic')
    {
      _r_id := cast (xpath_eval('@id', _frag) as varchar);
      _nodeid := ODP.ODP.TOPIC__NODE_GET(_r_id);
      if (not exists (select 1 from ODP.ODP.TOPIC_STRUCTURE where NODEID=_nodeid))
        insert into ODP.ODP.TOPIC_STRUCTURE
                ( NODEID	, XPER			)
          values
                ( _nodeid	, xper_cut (_frag)	);
      else
        update ODP.ODP.TOPIC_STRUCTURE
          set XPER = xper_cut (_frag) where NODEID=_nodeid;
      goto advance;
    }
  if (_tag = 'Alias')
    {
      _r_id := cast (xpath_eval('@id', _frag) as varchar);
      _nodeid := ODP.ODP.ALIAS__NODE_GET(_r_id);
      _title := cast (xpath_eval('.//Title', _frag) as varchar);
      _jumpto := ODP.ODP.TOPIC__NODE_GET(cast (xpath_eval('.//Target/@resource', _frag) as varchar));
      if (not exists (select 1 from ODP.ODP.ALIAS_STRUCTURE where NODEID=_nodeid))
        insert into ODP.ODP.ALIAS_STRUCTURE
                ( NODEID	, TITLE		, JUMPTO	)
          values
                ( _nodeid	, _title	, _jumpto	);
      else
        update ODP.ODP.ALIAS_STRUCTURE
          set TITLE = _title, JUMPTO = _jumpto where NODEID=_nodeid;
      goto advance;
    }
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
}
;

create procedure ODP.ODP.REFILL_TERMS ()
{
  declare _frag any;
  declare _r_id varchar;
  declare _nodeid any;
  select _frag1 into _frag
    from ODP.ODP.SOURCE
    where NAME = 'Terms' and xpath_contains (ORIG_DATA, '/RDF/*', _frag1);
  if (not isentity(_frag))
    signal('42ODP', 'XML source "Terms" is empty');
  whenever sqlstate '40001' goto next_frag;
next_frag:
  _r_id := cast (xpath_eval('@id', _frag) as varchar);
  _nodeid := ODP.ODP.TOPIC__NODE_GET(_r_id);
  if (not exists (select 1 from ODP.ODP.TOPIC_TERM where NODEID=_nodeid))
    insert into ODP.ODP.TOPIC_TERM
            ( NODEID	, XPER			)
      values
            ( _nodeid	, xper_cut (_frag)	);
  else
    update ODP.ODP.TOPIC_TERM
      set XPER = xper_cut (_frag) where NODEID=_nodeid;
  goto advance;
advance:
  commit work;
nocommit_advance:
  _frag := xper_right_sibling(_frag);
  if (isentity(_frag))
    goto next_frag;
}
;
