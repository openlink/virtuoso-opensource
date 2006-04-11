sequence_next ('_xbm');
create function XBM_DURA (in _fun varchar, in _param any) returns varchar
{
  declare _beg, _end integer;
  declare _metric double precision;
  exec('checkpoint');
  _beg := msec_time();
  _metric := call (_fun)(_param);
  _end := msec_time();
  return _fun || ' -- ' || cast (_metric as varchar) || ' in ' || cast ((_end - _beg) as varchar) || ' msec.';
}
;

drop table XBM_TREE;
drop table XBM_XPER;
drop table XBM_LXML;
drop table XBM_XMLTYPE;

create table XBM_TREE		(ID integer primary key, FULLNAME varchar, DOC long varchar identified by FULLNAME);
create table XBM_XPER		(ID integer primary key, FULLNAME varchar, DOC long varchar identified by FULLNAME);
create table XBM_LXML		(ID integer primary key, FULLNAME varchar, DOC long xml identified by FULLNAME);
create table XBM_XMLTYPE	(ID integer primary key, FULLNAME varchar, DOC XMLType identified by FULLNAME);

create procedure XBM_PREPARE (in _dummy any)
{
  declare _ctr integer;
  DBV.DBV.READ_DIRINFO();
  _ctr := 1;
  for select ID, FULLNAME, ORIG_TEXT from DBV.DBV.SOURCE where TYPE='xml' and REFILL_ERROR is NULL and REFILL_STATUS is NULL do
    {
      DBV.DBV.LOAD_TEXT (FULLNAME);
      _ctr := _ctr + 1;
    }
  return _ctr;
}

-- Fill

create procedure XBM_TREE_FILL (in _scale any)
{
  declare _ctr integer;
  _ctr := 1000 + _scale;
  while (_ctr > 1000)
    {
      for select ID, FULLNAME, ORIG_TEXT from DBV.DBV.SOURCE where TYPE='xml' and REFILL_STATUS='TEXT LOADED' and GRP <> 'DocBook' do
	insert into XBM_TREE values (sequence_next('_xbm'), sprintf ('%d%s', _ctr, FULLNAME), ORIG_TEXT);
      _ctr := _ctr - 1;
    }
  return coalesce ((select COUNT(*) from XBM_TREE));
}
;

create procedure XBM_XPER_FILL (in _scale any)
{
  declare _ctr integer;
  _ctr := 1000 + _scale;
  while (_ctr > 1000)
    {
      for select ID, FULLNAME, ORIG_TEXT from DBV.DBV.SOURCE where TYPE='xml' and REFILL_STATUS='TEXT LOADED' and GRP <> 'DocBook' do
	insert into XBM_XPER values (sequence_next('_xbm'), sprintf ('%d%s', _ctr, FULLNAME), xper_doc (ORIG_TEXT, 16, FULLNAME, 'LATIN-1', 'x-any', 'Include=IGNORE'));
      _ctr := _ctr - 1;
    }
  return coalesce ((select COUNT(*) from XBM_XPER));
}
;

create procedure XBM_LXML_FILL (in _scale any)
{
  declare _ctr integer;
  _ctr := 1000 + _scale;
  while (_ctr > 1000)
    {
      for select ID, FULLNAME, ORIG_TEXT from DBV.DBV.SOURCE where TYPE='xml' and REFILL_STATUS='TEXT LOADED' and GRP <> 'DocBook' do
	insert into XBM_LXML values (sequence_next('_xbm'), sprintf ('%d%s', _ctr, FULLNAME), ORIG_TEXT);
      _ctr := _ctr - 1;
    }
  return coalesce ((select COUNT(*) from XBM_LXML));
}
;

create procedure XBM_XMLTYPE_FILL (in _scale any)
{
  declare _ctr integer;
  _ctr := 1000 + _scale;
  while (_ctr > 1000)
    {
      for select ID, FULLNAME, ORIG_TEXT from DBV.DBV.SOURCE where TYPE='xml' and REFILL_STATUS='TEXT LOADED' and GRP <> 'DocBook' do
	insert into XBM_XMLTYPE values (sequence_next('_xbm'), sprintf ('%d%s', _ctr, FULLNAME), ORIG_TEXT);
      _ctr := _ctr - 1;
    }
  return coalesce ((select COUNT(*) from XBM_XMLTYPE));
}
;

-- xpath_contains

create procedure XBM_TREE_XPATH_CONTAINS_SERIALIZE (in _xp any)
{
  return coalesce ((select SUM(length(xpath_eval('serialize(.)', FRAG))) from XBM_TREE where xpath_contains (DOC, _xp, FRAG)));
}
;

create procedure XBM_XPER_XPATH_CONTAINS_SERIALIZE (in _xp any)
{
  return coalesce ((select SUM(length(xpath_eval('serialize(.)', FRAG))) from XBM_XPER where xpath_contains (DOC, _xp, FRAG)));
}
;

create procedure XBM_LXML_XPATH_CONTAINS_SERIALIZE (in _xp any)
{
  return coalesce ((select SUM(length(xpath_eval('serialize(.)', FRAG))) from XBM_LXML where xpath_contains (DOC, _xp, FRAG)));
}
;

create procedure XBM_XMLTYPE_XPATH_CONTAINS_SERIALIZE (in _xp any)
{
  return coalesce ((select SUM(length(xpath_eval('serialize(.)', FRAG))) from XBM_XMLTYPE where xpath_contains (DOC, _xp, FRAG)));
}
;


set verbose off;
set banner off;

select XBM_DURA('XBM_PREPARE',0);

select XBM_DURA('XBM_TREE_FILL',1);
select XBM_DURA('XBM_XPER_FILL',1);
select XBM_DURA('XBM_LXML_FILL',1);
select XBM_DURA('XBM_XMLTYPE_FILL',1);

select XBM_DURA('XBM_TREE_XPATH_CONTAINS_SERIALIZE','/');
select XBM_DURA('XBM_XPER_XPATH_CONTAINS_SERIALIZE','/');
select XBM_DURA('XBM_LXML_XPATH_CONTAINS_SERIALIZE','/');
select XBM_DURA('XBM_XMLTYPE_XPATH_CONTAINS_SERIALIZE','/');

