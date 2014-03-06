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
-- DAV related procs
--
create function DB.DBA.DAV_DET_DETCOL_ID (
  in id any)
{
  if (isinteger (id))
    return id;

  return cast (id[1] as integer);
}
;

create function DB.DBA.DAV_DET_DAV_ID (
  in id any)
{
  if (isinteger (id))
    return id;

  return id[2];
}
;

create function DB.DBA.DAV_DET_DAV_LIST (
  in det varchar,
  inout detcol_id integer,
  inout colId integer)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_DAVLIST ()');
  declare retValue any;

  vectorbld_init (retValue);
  for (select vector (RES_FULL_PATH,
                      'R',
                      length (RES_CONTENT),
                      RES_MOD_TIME,
                      vector (det, detcol_id, RES_ID, 'R'),
                      RES_PERMS,
                      RES_GROUP,
                      RES_OWNER,
                      RES_CR_TIME,
                      RES_TYPE,
                      RES_NAME,
                      coalesce (RES_ADD_TIME, RES_CR_TIME)) as I
         from WS.WS.SYS_DAV_RES
        where RES_COL = DB.DBA.DAV_DET_DAV_ID (colId)) do
  {
    vectorbld_acc (retValue, i);
  }

  for (select vector (WS.WS.COL_PATH (COL_ID),
                      'C',
                      0,
                      COL_MOD_TIME,
                      vector (det, detcol_id, COL_ID, 'C'),
                      COL_PERMS,
                      COL_GROUP,
                      COL_OWNER,
                      COL_CR_TIME,
                      'dav/unix-directory',
                      COL_NAME,
                      coalesce (COL_ADD_TIME, COL_CR_TIME)) as I
        from WS.WS.SYS_DAV_COL
       where COL_PARENT = DB.DBA.DAV_DET_DAV_ID (colId)) do
  {
    vectorbld_acc (retValue, i);
  }

  vectorbld_final (retValue);
  return retValue;
}
;

--
-- Activity related procs
--
create function DB.DBA.DAV_DET_ACTIVITY (
  in det varchar,
  in id integer,
  in text varchar)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_ACTIVITY (', det, id, text, ')');
  declare pos integer;
  declare parent_id integer;
  declare parentPath varchar;
  declare activity_id integer;
  declare activity, activityName, activityPath, activityContent, activityType varchar;
  declare davEntry any;
  declare _errorCount integer;
  declare exit handler for sqlstate '*'
  {
    if (__SQL_STATE = '40001')
    {
      rollback work;
      if (_errorCount > 5)
        resignal;

      delay (1);
      _errorCount := _errorCount + 1;
      goto _start;
    }
    return;
  };

  _errorCount := 0;

_start:;
  activity := DB.DBA.DAV_PROP_GET_INT (id, 'C', sprintf ('virt:%s-activity', det), 0);
  if (isnull (DAV_HIDE_ERROR (activity)))
    return;

  if (activity <> 'on')
    return;

  davEntry := DB.DBA.DAV_DIR_SINGLE_INT (id, 'C', '', null, null, http_dav_uid ());
  if (DB.DBA.DAV_HIDE_ERROR (davEntry) is null)
    return;

  parent_id := DB.DBA.DAV_SEARCH_ID (davEntry[0], 'P');
  if (DB.DBA.DAV_HIDE_ERROR (parent_id) is null)
    return;

  parentPath := DB.DBA.DAV_SEARCH_PATH (parent_id, 'C');
  if (DB.DBA.DAV_HIDE_ERROR (parentPath) is null)
    return;

  activityContent := '';
  activityName := davEntry[10] || '_activity.log';
  activityPath := parentPath || activityName;
  activity_id := DB.DBA.DAV_SEARCH_ID (activityPath, 'R');
  if (DB.DBA.DAV_HIDE_ERROR (activity_id) is not null)
  {
    DB.DBA.DAV_RES_CONTENT_INT (activity_id, activityContent, activityType, 0, 0);
    if (activityType <> 'text/plain')
      return;

    activityContent := cast (activityContent as varchar);
    -- .log file size < 100KB
    if (length (activityContent) > 1024)
    {
      activityContent := right (activityContent, 1024);
      pos := strstr (activityContent, '\r\n20');
      if (not isnull (pos))
        activityContent := subseq (activityContent, pos+2);
    }
  }
  activityContent := activityContent || sprintf ('%s %s\r\n', subseq (datestring (now ()), 0, 19), text);
  activityType := 'text/plain';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (activityPath, activityContent, activityType, '110100000RR', DB.DBA.Dropbox__user (davEntry[6]), DB.DBA.Dropbox__user (davEntry[7]), extern=>0, check_locks=>0);

  -- hack for Public folders
  set triggers off;
  DAV_PROP_SET_INT (activityPath, ':virtpermissions', '110100000RR', null, null, 0, 0, 1, http_dav_uid());
  set triggers on;

  commit work;
}
;

--
-- HTTP related procs
--
create function DB.DBA.DAV_DET_HTTP_ERROR (
  in _header any,
  in _silent integer := 0)
{
  if ((_header[0] like 'HTTP/1._ 4__ %') or (_header[0] like 'HTTP/1._ 5__ %'))
  {
    if (not _silent)
      signal ('22023', trim (_header[0], '\r\n'));

    return 0;
  }
  return 1;
}
;

create function DB.DBA.DAV_DET_HTTP_CODE (
  in _header any)
{
  return subseq (_header[0], 9, 12);
}
;

--
-- User related procs
--
create function DB.DBA.DAV_DET_USER (
  in user_id integer)
{
  return coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id), '');
}
;

create function DB.DBA.DAV_DET_PASSWORD (
  in user_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = user_id), '');
}
;

--
-- Params related procs
--
create function DB.DBA.DAV_DET_PARAM_SET (
  in _det varchar,
  in _password varchar,
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _propValue any,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _encrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_paramSet', _propName, _propValue, ')');
  declare retValue, save any;

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  if (_serialized)
    _propValue := serialize (_propValue);

  if (_encrypt)
    _propValue := pwd_magic_calc (_password, _propValue);

  if (_prefixed)
    _propName := sprintf ('virt:%s-%s', _det, _propName);

  _id := DB.DBA.DAV_DET_DAV_ID (_id);
  retValue := DB.DBA.DAV_PROP_SET_RAW (_id, _what, _propName, _propValue, 1, http_dav_uid ());

  connection_set ('dav_store', save);
  return retValue;
}
;

create function DB.DBA.DAV_DET_PARAM_GET (
  in _det varchar,
  in _password varchar,
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _decrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_paramGet (', _id, _what, _propName, ')');
  declare propValue any;

  if (_prefixed)
    _propName := sprintf ('virt:%s-%s', _det, _propName);

  propValue := DB.DBA.DAV_PROP_GET_INT (DB.DBA.DAV_DET_DAV_ID (_id), _what, _propName, 0, DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()), http_dav_uid ());
  if (isinteger (propValue))
    propValue := null;

  if (_serialized and not isnull (propValue))
    propValue := deserialize (propValue);

  if (_decrypt and not isnull (propValue))
    propValue := pwd_magic_calc (_password, propValue, 1);

  return propValue;
}
;

create function DB.DBA.DAV_DET_PARAM_REMOVE (
  in _det varchar,
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _prefixed integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_paramRemove (', _id, _what, _propName, ')');
  if (_prefixed)
    _propName := sprintf ('virt:%s-%s', _det, _propName);

  DB.DBA.DAV_PROP_REMOVE_RAW (DB.DBA.DAV_DET_DAV_ID (_id), _what, _propName, 1, http_dav_uid());
}
;

--
-- Date related procs
--
create function DB.DBA.DAV_DET_STRINGDATE (
  in dt varchar)
{
	declare rs any;
  declare exit handler for sqlstate '*' { return now ();};

  rs := dt;
  if (isstring (rs))
	  rs := stringdate (rs);

	return dateadd ('minute', timezone (now()), rs);
}
;

--
-- XML related procs
--
create function DB.DBA.DAV_DET_XML2STRING (
  in _xml any)
{
  declare stream any;

  stream := string_output ();
  http_value (_xml, null, stream);
  return string_output_string (stream);
}
;

create function DB.DBA.DAV_DET_ENTRY_XPATH (
  in _xml any,
  in _xpath varchar,
  in _cast integer := 0)
{
  declare retValue any;

  if (_cast)
  {
    retValue := serialize_to_UTF8_xml (xpath_eval (sprintf ('string (//entry%s)', _xpath), _xml, 1));
  } else {
    retValue := xpath_eval ('//entry' || _xpath, _xml, 1);
  }
  return retValue;
}
;

create function DB.DBA.DAV_DET_ENTRY_XUPDATE (
  inout _xml any,
  in _tag varchar,
  in _value any)
{
  declare _entity any;

  _xml := XMLUpdate (_xml, '//entry/' || _tag, null);
  if (isnull (_value))
    return;

  _entity := xpath_eval ('//entry', _xml);
  XMLAppendChildren (_entity, xtree_doc (sprintf ('<%s>%V</%s>', _tag, cast (_value as varchar), _tag)));
}
;

--
-- RDF related proc
--
create function DB.DBA.DAV_DET_RDF (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar)
{
  declare aq any;

  set_user_id ('dba');
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.DAV_DET_RDF_AQ', vector (det, detcol_id, id, what));
}
;

create function DB.DBA.DAV_DET_RDF_AQ (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar)
{
  set_user_id ('dba');
  DB.DBA.DAV_DET_RDF_DELETE (det, detcol_id, id, what);
  DB.DBA.DAV_DET_RDF_INSERT (det, detcol_id, id, what);
}
;

create function DB.DBA.DAV_DET_RDF_INSERT (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_graph varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_rdf_insert (', det, detcol_id, id, what, rdf_graph, ')');
  declare permissions, rdf_graph2 varchar;
  declare rdf_sponger, rdf_cartridges, rdf_metaCartridges any;
  declare path, content, type any;
  declare exit handler for sqlstate '*'
  {
    return;
  };

  if (isnull (rdf_graph))
    rdf_graph := DB.DBA.DAV_DET_PARAM_GET (det, null, detcol_id, 'C', 'graph', 0);

  if (DB.DBA.is_empty_or_null (rdf_graph))
    return;

  permissions := DB.DBA.DAV_DET_PARAM_GET (det, null, detcol_id, 'C', ':virtpermissions', 0, 0);
  if (permissions[6] = ascii('0'))
  {
    -- add to private graphs
    if (not SIOC..private_graph_check (rdf_graph))
      return;
  }

  id := DB.DBA.DAV_DET_davId (id);
  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  content := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = id);
  type := (select RES_TYPE from WS.WS.SYS_DAV_RES where RES_ID = id);
  rdf_sponger := coalesce (DB.DBA.DAV_DET_PARAM_GET (det, null, detcol_id, 'C', 'sponger', 0), 'on');
  rdf_cartridges := coalesce (DB.DBA.DAV_DET_PARAM_GET (det, null, detcol_id, 'C', 'cartridges', 0), '');
  rdf_metaCartridges := coalesce (DB.DBA.DAV_DET_PARAM_GET (det, null, detcol_id, 'C', 'metaCartridges', 0), '');

  DB.DBA.RDF_SINK_UPLOAD (path, content, type, rdf_graph, null, rdf_sponger, rdf_cartridges, rdf_metaCartridges);
}
;

create function DB.DBA.DAV_DET_RDF_DELETE (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_graph varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_DELETE (', det, detcol_id, id, what, rdf_graph, ')');
  declare rdf_graph2 varchar;
  declare path varchar;

  if (isnull (rdf_graph))
    rdf_graph := DB.DBA.DAV_DET_PARAM_GET (det, null, detcol_id, 'C', 'graph', 0);

  if (DB.DBA.is_empty_or_null (rdf_graph))
    return;

  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  DB.DBA.RDF_SINK_CLEAR (path, rdf_graph);
}
;

--
-- Misc procs
--
create function DB.DBA.DAV_DET_REFRESH (
  in det varchar,
  in path varchar)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_REFRESH (', path, ')');
  declare colId any;

  colId := DB.DBA.DAV_SEARCH_ID (path, 'C');
  if (DAV_HIDE_ERROR (colId) is not null)
    DB.DBA.DAV_DET_PARAM_REMOVE (det, colId, 'C', 'syncTime');
}
;
