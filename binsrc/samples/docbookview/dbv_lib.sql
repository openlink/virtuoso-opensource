DB.DBA.RDF_ASSERT ('equ (DBV.DBV.CODE_VERSION(), ''0.1.010316A'')');

--! Configuration handling
create procedure DBV.DBV.GETCFG (in _param varchar) returns varchar
{
  declare _value varchar;
  whenever not found goto nf;
  select VALUE into _value from DBV.DBV.CONFIG where (PARAM = _param) and VALUE is not null;
  return _value;
nf:
  signal('42DBV', concat('Config variable "', _param, '" is missing or invalid'));
}
;

create procedure DBV.DBV.SETCFG (in _param varchar, in _value varchar) returns varchar
{
  insert replacing DBV.DBV.CONFIG (PARAM, VALUE) values (_param, _value);
}

create procedure DBV.DBV.ADDCFG (in _param varchar, in _value varchar) returns varchar
{
  declare _old_value varchar;
  whenever not found goto nf;
  select VALUE into _old_value from DBV.DBV.CONFIG where (PARAM = _param) and VALUE is not null;
  return _old_value;
nf:
  return DBV.DBV.SETCFG (_param, _value);
}

create procedure DBV.DBV.READ_DIRINFO ()
{
  declare _dirinfo varchar;
  declare _fullname, _path, _name, _ext, _type, _grp, _dtdname varchar;
  declare _orig_text long varchar;
  _dirinfo := DB.DBA.XML_URI_GET(
    DBV.DBV.GETCFG('DBV/Sources/DirInfo/BaseUri'),
    DBV.DBV.GETCFG('DBV/Sources/DirInfo/LocalName') );
  delete from DBV.DBV.SOURCE;
  insert into DBV.DBV.SOURCE
	( ID			, FULLNAME	, TYPE		, ORIG_TEXT	, ORIG_XML			)
  values
	( sequence_next('_')	, '(DirInfo)'	, '(DirInfo)'	, _dirinfo	, xml_persistent(_dirinfo)	);
  commit work;
  for select frag from DBV.DBV.SOURCE where TYPE='(DirInfo)' and xpath_contains (ORIG_XML, '//file', frag) do
    {
      _name := xpath_eval('@name', frag);
      _ext :=  xpath_eval('@ext', frag);
      _type :=  xpath_eval('@type', frag);
      _grp :=  xpath_eval('@group', frag);
      _dtdname :=  xpath_eval('@dtd', frag);
      _path := xpath_eval('../@path', frag);
      if (_path <> '')     
        _fullname := concat ('/', _path, '/', _name, '.', _ext);
      else
        _fullname := concat ('/', _name, '.', _ext);
      _orig_text := '';
      delete from DBV.DBV.SOURCE where FULLNAME=_fullname;
      insert into DBV.dBV.SOURCE
	( ID			, FULLNAME	, PATH	, NAME	, EXT	, TYPE	, GRP	, DTDNAME	, ORIG_TEXT	)
      values
	( sequence_next('_')	, _fullname	, _path	, _name	, _ext	, _type	, _grp	, _dtdname	, _orig_text	);
    }
  commit work;
}

create procedure DBV.DBV.LOAD_TEXT (in _fullname varchar)
{
  declare _loadpath varchar;
  declare _sqlcode varchar;
  declare _type varchar;
  declare _message varchar;
  if (not exists (select FULLNAME from DBV.DBV.SOURCE where (FULLNAME= _fullname)))
    DB.DBA.RDF_ASSERT2 (0, concat ('No record in SOURCE with FULLNAME=', _fullname));
  _loadpath := concat (DBV.DBV.GETCFG (concat ('DBV/Sources')), '/', _fullname);
  _sqlcode := '00000';
  _message := '';
  exec (
    concat (
	'update DBV.DBV.SOURCE',
	'  set',
	'	REFILL_STATUS	= ''TEXT LOADED'',',
	'	REFILL_ERROR	= ''TEXT OK'',',
	'	ORIG_TEXT	= file_to_string(', WS.WS.STR_SQL_APOS(_loadpath), ')',
	'  where (FULLNAME = ', WS.WS.STR_SQL_APOS(_fullname), ')' ),
    _sqlcode,
    _message );
  update DBV.DBV.SOURCE
    set
	REFILL_ERROR	= _message
    where (FULLNAME = _fullname);
  commit work;
}
;

create procedure DBV.DBV.PARSE_XML (in _fullname varchar)
{
  declare _sqlcode varchar;
  declare _message varchar;
  if (not exists (select FULLNAME from DBV.DBV.SOURCE where (FULLNAME= _fullname)))
    DB.DBA.RDF_ASSERT2 (0, concat ('No record in SOURCE with FULLNAME=', _fullname));
  _sqlcode := '00000';
  _message := '';
  exec (
    concat (
	'update DBV.DBV.SOURCE',
	'  set',
	'	REFILL_STATUS	= ''XML PARSED'',',
	'	REFILL_ERROR	= ''XML OK'',',
	'	ORIG_XML	= xml_persistent(ORIG_TEXT)',
	'  where (FULLNAME = ', WS.WS.STR_SQL_APOS(_fullname), ')' ),
    _sqlcode,
    _message );
  update DBV.DBV.SOURCE
    set
	REFILL_ERROR	= _message
    where (FULLNAME = _fullname);
  commit work;
}
;

create procedure DBV.DBV.PARSE_ALL (in _fullname varchar)
{
  declare _sqlcode varchar;
  declare _message varchar;
  declare _path varchar;
  declare _base varchar;
  if (not exists (select FULLNAME from DBV.DBV.SOURCE where (FULLNAME= _fullname)))
    DB.DBA.RDF_ASSERT2 (0, concat ('No record in SOURCE with FULLNAME=', _fullname));
  select PATH into _path from DBV.DBV.SOURCE where FULLNAME=_fullname;

  _base := DBV.DBV.GETCFG ('DBV/Validation/BaseUri');
  if (_path <> '')
    _base := concat (_base, '/', _path);
  else
    _base := concat (_base, _path);
  _base := cast (_base as varchar);

  _sqlcode := '00000';
  _message := '';
  exec (
    concat (
	'update DBV.DBV.SOURCE',
	'  set',
	'	REFILL_STATUS	= ''XML PARSED'',',
	'	REFILL_ERROR	= ''XML OK'',',
	'	ORIG_XML	= xml_persistent(ORIG_TEXT, ', WS.WS.STR_SQL_APOS(_base), ', ''x-any'', ''Validation=OFF FsaBadWs=IGNORE BuildStandalone=ENABLE'')',
	'  where (FULLNAME = ', WS.WS.STR_SQL_APOS(_fullname), ')' ),
    _sqlcode,
    _message );
  update DBV.DBV.SOURCE
    set
	REFILL_ERROR	= _message
    where (FULLNAME = _fullname);
  commit work;
}
;

