--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

create function DB.DBA.DAV_DET_PATH (
  in detcol_id any,
  in subPath_parts any)
{
  return DB.DBA.DAV_CONCAT_PATH (DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C'), subPath_parts);
}
;

create function DB.DBA.DAV_DET_PATH_NAME (
  in path varchar)
{
  path := trim (path, '/');
  if (isnull (strrchr (path, '/')))
    return path;

  return right (path, length (path)-strrchr (path, '/')-1);
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
                      DB.DBA.DAV_RES_LENGTH (RES_CONTENT, RES_SIZE),
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
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (activityPath, activityContent, activityType, '110100000RR', DB.DBA.DAV_DET_USER (davEntry[6]), DB.DBA.DAV_DET_USER (davEntry[7]), extern=>0, check_locks=>0);

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
  in user_id integer,
  in default_id integer := null)
{
  return coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = coalesce (user_id, default_id)), '');
}
;

create function DB.DBA.DAV_DET_PASSWORD (
  in user_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = user_id), '');
}
;

create function DB.DBA.DAV_DET_OWNER (
  in detcol_id any,
  in subPath_parts any,
  in uid any,
  in gid any,
  inout ouid integer,
  inout ogid integer)
{
  declare id any;
  declare path varchar;

  DB.DBA.DAV_OWNER_ID (uid, gid, ouid, ogid);
  if ((ouid = -12) or (ouid = 5))
  {
    path := DB.DBA.DAV_DET_PATH (detcol_id, subPath_parts);
    id := DB.DBA.DAV_SEARCH_ID (path, 'P');
    if (DAV_HIDE_ERROR (id))
    {
      select COL_OWNER, COL_GROUP
        into ouid, ogid
        from WS.WS.SYS_DAV_COL
       where COL_ID = id;
    }
  }
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

  if (DB.DBA.is_empty_or_null (_propValue))
  {
    DB.DBA.DAV_DET_PARAM_REMOVE (_det, _id, _what, _propName, _prefixed);
  }
  else
  {
    if (_serialized)
      _propValue := serialize (_propValue);

    if (_encrypt)
      _propValue := pwd_magic_calc (_password, _propValue);

    if (_prefixed)
      _propName := sprintf ('virt:%s-%s', _det, _propName);

    _id := DB.DBA.DAV_DET_DAV_ID (_id);
    retValue := DB.DBA.DAV_PROP_SET_RAW (_id, _what, _propName, _propValue, 1, http_dav_uid ());
  }
  commit work;

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
  commit work;
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
    if (not DB.DBA.DAV_DET_PRIVATE_GRAPH_CHECK (rdf_graph))
      return;
  }

  id := DB.DBA.DAV_DET_DAV_ID (id);
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

create function DB.DBA.DAV_DET_SYNC (
  in det varchar,
  in id any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_SYNC (', id, ')');
  declare N integer;
  declare detcol_id, parts, subPath_parts, detcol_parts any;

  detcol_id := DB.DBA.DAV_DET_DETCOL_ID (id);
  parts := split_and_decode (DB.DBA.DAV_SEARCH_PATH (id, 'C'), 0, '\0\0/');
  detcol_parts := split_and_decode (DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C'), 0, '\0\0/');
  N := length (detcol_parts) - 2;
  detcol_parts := vector_concat (subseq (parts, 0, N + 1), vector (''));
  subPath_parts := subseq (parts, N + 1);

  call ('DB.DBA.' || det || '__load') (detcol_id, subPath_parts, detcol_parts, 1);
}
;

create function DB.DBA.DAV_DET_CONTENT_ROLLBACK (
  in oldId any,
  in oldContent any,
  in path varchar)
{
  if (DAV_HIDE_ERROR (oldId) is not null)
  {
    update WS.WS.SYS_DAV_RES set RES_CONTENT = oldContent where RES_ID = DB.DBA.DAV_DET_DAV_ID (oldID);
  }
  else
  {
    DAV_DELETE_INT (path, 1, null, null, 0, 0);
  }
}
;

create function DB.DBA.DAV_DET_CONTENT_MD5 (
  in id any)
{
  return md5 ((select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = DB.DBA.DAV_DET_DAV_ID (id)));
}
;

--
-- Private graphs
--

--!
-- \brief Default Virtuoso graph group
--/
create function DB.DBA.DAV_DET_PRIVATE_GRAPH ()
{
  return 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs';
}
;

--!
-- \brief Default Virtuoso graph group id
--/
create function DB.DBA.DAV_DET_PRIVATE_GRAPH_ID ()
{
  return iri_to_id (DB.DBA.DAV_DET_PRIVATE_GRAPH ());
}
;

--!
-- \brief Init private graph security
--/
create function DB.DBA.DAV_DET_PRIVATE_INIT ()
{
  declare exit handler for sqlstate '*' {return 0;};

  if (registry_get ('__DAV_DET_PRIVATE_INIT') = '1')
    return;

  -- private graph group (if not exists)
  DB.DBA.RDF_GRAPH_GROUP_CREATE (DB.DBA.DAV_DET_PRIVATE_GRAPH (), 1);

  DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('nobody', 0, 1);
  DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('dba', 1023, 1);

  registry_set ('__DAV_DET_PRIVATE_INIT', '1');

  return 1;
}
;

--!
-- \brief Make an RDF graph private.
--
-- \param graph_iri The IRI of the graph to make private. The graph will be private afterwards.
-- Without subsequent calls to DB.DBA.DAV_DET_PRIVATE_USER_ADD nobody can read or write the graph.
--
-- \return \p 1 on success, \p 0 otherwise.
--
-- \sa DB.DBA.DAV_DET_PRIVATE_GRAPH_REMOVE, DB.DBA.DAV_DET_PRIVATE_USER_ADD
--/
create function DB.DBA.DAV_DET_PRIVATE_GRAPH_ADD (
  in graph_iri varchar)
{
  declare exit handler for sqlstate '*' {return 0;};

  DB.DBA.RDF_GRAPH_GROUP_INS (DB.DBA.DAV_DET_PRIVATE_GRAPH (), graph_iri);

  return 1;
}
;

--!
-- \brief Make an RDF graph public.
--
-- \param The IRI of the graph to make public.
--
-- \sa DB.DBA.DAV_DET_PRIVATE_GRAPH_REMOVE, DB.DBA.DAV_DET_PRIVATE_USER_ADD
--/
create function DB.DBA.DAV_DET_PRIVATE_GRAPH_REMOVE (
  in graph_iri varchar)
{
  declare exit handler for sqlstate '*' {return 0;};

  DB.DBA.RDF_GRAPH_GROUP_DEL (DB.DBA.DAV_DET_PRIVATE_GRAPH (), graph_iri);

  return 1;
}
;

--!
-- \brief Check if an RDF graph is private or not.
--
-- Private graphs can still be readable or even writable by certain users,
-- depending on the configured rights.
--
-- \param graph_iri The IRI of the graph to check.
--
-- \return \p 1 if the given graph is private, \p 0 otherwise.
--
-- \sa DB.DBA.DAV_DET_PRIVATE_GRAPH_ADD, DB.DBA.DAV_DET_PRIVATE_USER_ADD
--/
create function DB.DBA.DAV_DET_PRIVATE_GRAPH_CHECK (
  in graph_iri varchar)
{
  declare tmp integer;
  declare private_graph varchar;
  declare private_graph_id any;

  private_graph := DB.DBA.DAV_DET_PRIVATE_GRAPH ();
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = private_graph))
    return 0;

  private_graph_id := DB.DBA.DAV_DET_PRIVATE_GRAPH_ID ();
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = private_graph_id and RGGM_MEMBER_IID = iri_to_id (graph_iri)))
    return 0;

  tmp := coalesce ((select top 1 RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i8192 and RGU_USER_ID = http_nobody_uid ()), 0);
  if (tmp <> 0)
    return 0;

  return 1;
}
;

--!
-- \brief Grant access to a private RDF graph.
--
-- Grants access to a certain RDF graph. There is no need to call DB.DBA.DAV_DET_private_graph_add before.
-- The given graph is made private automatically.
--
-- \param graph_iri The IRI of the graph to grant access to.
-- \param uid The numerical or string ID of the SQL user to grant access to \p graph_iri.
-- \param rights The rights to grant to \p uid:
-- - \p 1 - Read
-- - \p 2 - Write
-- - \p 3 - Read/Write
--
-- \return \p 1 on success, \p 0 otherwise.
--
-- \sa DB.DBA.DAV_DET_PRIVATE_GRAPH_ADD, DB.DBA.DAV_DET_PRIVATE_USER_ADD
--/
create function DB.DBA.DAV_DET_PRIVATE_USER_ADD (
  in graph_iri varchar,
  in uid any,
  in rights integer := 1023)
{
  declare exit handler for sqlstate '*' {return 0;};

  if (isinteger (uid))
    uid := (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid);

  DB.DBA.RDF_GRAPH_GROUP_INS (DB.DBA.DAV_DET_PRIVATE_GRAPH (), graph_iri);
  DB.DBA.RDF_GRAPH_USER_PERMS_SET (graph_iri, uid, rights);

  return 1;
}
;

--!
-- \brief Revoke access to a private RDF graph.
--
-- \param graph_iri The IRI of the private graph to revoke access to,
-- \param uid The numerical or string ID of the SQL user to revoke access from.
--
-- \sa DB.DBA.DAV_DET_PRIVATE_USER_ADD
--/
create function DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (
  in graph_iri varchar,
  in uid any)
{
  declare exit handler for sqlstate '*' {return 0;};

  if (isinteger (uid))
    uid := (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid);

  DB.DBA.RDF_GRAPH_USER_PERMS_DEL (graph_iri, uid);

  return 1;
}
;

create function DB.DBA.DAV_DET_PRIVATE_ACL_COMPARE (
  in acls_1 any,
  in acls_2 any)
{
  declare N integer;

  if (length (acls_1) <> length (acls_2))
  {
    return 0;
  }
  for (N := 0; N < length (acls_1); N := N + 1)
  {
    if (acls_1[N] <> acls_2[N])
    {
      return 0;
    }
  }
  return 1;
}
;

create function DB.DBA.DAV_DET_PRIVATE_ACL_ADD (
  in id integer,
  in graph varchar,
  in acls any)
{
  declare N integer;
  declare V any;

  for (N := 0; N < length (acls); N := N + 1)
  {
    V := WS.WS.ACL_PARSE (acls[N], case when (N = length (acls)-1) then '01' else '12' end, 0);
    foreach (any acl in V) do
    {
      if (acl[1] = 1)
      {
        DB.DBA.DAV_DET_PRIVATE_USER_ADD (graph, acl[0]);
      }
      else
      {
        DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (graph, acl[0]);
      }
    }
  }
}
;

create function DB.DBA.DAV_DET_PRIVATE_ACL_REMOVE (
  in id integer,
  in graph varchar,
  in acls any)
{
  declare N integer;
  declare V any;

  for (N := 0; N < length (acls); N := N + 1)
  {
    V := WS.WS.ACL_PARSE (acls[N], case when (N = length (acls)-1) then '01' else '12' end, 0);
    foreach (any acl in V) do
    {
      if (acl[1] = 1)
      {
        DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (graph, acl[0]);
      }
    }
  }
}
;

create function DB.DBA.DAV_DET_GRAPH_ACL_UPDATE (
  in id integer,
  in oldAcls any,
  in newAcls any)
{
  -- get parent acls
  DB.DBA.DAV_DET_GRAPH_ACL_PARENT (id, oldAcls, newAcls);

  -- child acls
  DB.DBA.DAV_DET_GRAPH_ACL_UPDATE_CHILD (id, oldAcls, newAcls);
}
;

create function DB.DBA.DAV_DET_GRAPH_ACL_PARENT (
  in id integer,
  inout oldAcls any,
  inout newAcls any)
{
  declare _col_id integer;
  declare _acl any;

  -- get parent acls
  _col_id := id;
  while (1)
  {
    _col_id := (select COL_PARENT from WS.WS.SYS_DAV_COL where COL_ID = _col_id);
    if (isnull (_col_id))
    {
      goto _break;
    }
    _acl := (select COL_ACL from WS.WS.SYS_DAV_COL where COL_ID = _col_id);
    oldAcls := vector_concat (vector (_acl), oldAcls);
    newAcls := vector_concat (vector (_acl), newAcls);
  }
_break:;
}
;

create function DB.DBA.DAV_DET_GRAPH_ACL_UPDATE_CHILD (
  in id integer,
  in oldAcls any,
  in newAcls any)
{
  declare _col_owner, _col_group integer;
  declare _col_perms, _graph_iri, _det varchar;

  for (select COL_ID as _col_id,
              COL_ACL as _acl
         from WS.WS.SYS_DAV_COL
        where COL_PARENT = id) do
  {
    oldAcls := vector_concat (oldAcls, vector (_acl));
    newAcls := vector_concat (newAcls, vector (_acl));

    -- check for graph
    if (DB.DBA.DAV_DET_COL_GRAPH (_col_id, _det, _graph_iri))
    {
      select COL_OWNER,
             COL_GROUP,
             COL_PERMS
        into _col_owner,
             _col_group,
             _col_perms
        from WS.WS.SYS_DAV_COL
       where COL_ID = _col_id;

      DB.DBA.DAV_DET_GRAPH_UPDATE (
        _col_id,
        _det,
        _col_owner,
        _col_owner,
        _col_group,
        _col_group,
        _col_perms,
        _col_perms,
        oldAcls,
        newAcls,
        _graph_iri,
        _graph_iri
      );
    }
    else
    {
      DB.DBA.DAV_DET_GRAPH_ACL_UPDATE_CHILD (_col_id, oldAcls, newAcls);
    }
  }
}
;

create function DB.DBA.DAV_DET_GRAPH_UPDATE (
  in id integer,
  in detType varchar,
  in oldOwner integer,
  in newOwner integer,
  in oldGroup integer,
  in newGroup integer,
  in oldPermissions varchar,
  in newPermissions varchar,
  in oldAcls any,
  in newAcls any,
  in oldGraph varchar,
  in newGraph varchar,
  in force integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_GRAPH_UPDATE (', oldOwner, newOwner, oldGroup, newGroup, oldPermissions, newPermissions, oldAcls, newAcls, oldGraph, newGraph, ')');
  declare path varchar;
  declare permissions varchar;
  declare aq, owner any;

  path := DB.DBA.DAV_SEARCH_PATH (id, 'C');
  if (isnull (DAV_HIDE_ERROR (path)))
  {
    return;
  }

  if (
      (coalesce (oldOwner, -1) = coalesce (newOwner, -1))             and
      (coalesce (oldGroup, -1) = coalesce (newGroup, -1))             and
      (coalesce (oldPermissions, '') = coalesce (newPermissions, '')) and
      (DB.DBA.DAV_DET_PRIVATE_ACL_COMPARE (oldAcls, newAcls))         and
      (coalesce (oldGraph, '') = coalesce (newGraph, ''))             and
      (force = 0)
     )
  {
    return;
  }

  -- old graph
  if (not DB.DBA.is_empty_or_null (oldGraph))
  {
    DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (oldGraph, oldOwner);
    DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (oldGraph, oldGroup);
    DB.DBA.DAV_DET_PRIVATE_ACL_REMOVE (id, oldGraph, oldAcls);
    DB.DBA.DAV_DET_PRIVATE_GRAPH_REMOVE (oldGraph);
  }

  -- new graph
  if (not DB.DBA.is_empty_or_null (newGraph))
  {
    if (newPermissions[6] = ascii('0'))
    {
      -- add to private graphs
      DB.DBA.DAV_DET_PRIVATE_INIT ();
      DB.DBA.DAV_DET_PRIVATE_GRAPH_ADD (newGraph);
      DB.DBA.DAV_DET_PRIVATE_USER_ADD (newGraph, newOwner);
      if (newPermissions[3] = ascii('1'))
      {
        DB.DBA.DAV_DET_PRIVATE_USER_ADD (newGraph, newGroup);
      }
      DB.DBA.DAV_DET_PRIVATE_ACL_ADD (id, newGraph, newAcls);
    }
    else
    {
      -- remove from private graphs
      DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (newGraph, newOwner);
      DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (newGraph, newGroup);
      DB.DBA.DAV_DET_PRIVATE_ACL_REMOVE (id, newGraph, newAcls);
      DB.DBA.DAV_DET_PRIVATE_GRAPH_REMOVE (newGraph);
    }
  }

  -- update graph if needed
  if (oldGraph <> newGraph)
  {
    aq := async_queue (1);
    aq_request (aq, 'DB.DBA.DAV_DET_GRAPH_UPDATE_AQ', vector (path, cast (detType as varchar), oldGraph, newGraph));
  }
}
;

create function DB.DBA.DAV_DET_GRAPH_UPDATE_AQ (
  in path varchar,
  in detType varchar,
  in oldGraph varchar,
  in newGraph varchar)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_graph_update_aq (', path, detType, oldGraph, newGraph, ')');
  declare N, detcol_id integer;
  declare V, filter any;

  V := null;
  detcol_id := DB.DBA.DAV_SEARCH_ID (path, 'C');
  filter := vector (vector ('RES_FULL_PATH', 'like', path || '%'));
  if ((coalesce (oldGraph, '') <> '') and (__proc_exists ('DB.DBA.' || detType || '__rdf_delete') is not null))
  {
    V := DB.DBA.DAV_DIR_FILTER (path, 1, filter, 'dav', DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));
    for (N := 0; N < length (V); N := N + 1)
    {
      call ('DB.DBA.' || detType || '__rdf_delete') (detcol_id, V[N][4], 'R', oldGraph);
    }
  }

  if ((coalesce (newGraph, '') <> '')  and (__proc_exists ('DB.DBA.' || detType || '__rdf_insert') is not null))
  {
    if (isnull (V))
      V := DB.DBA.DAV_DIR_FILTER (path, 1, filter, 'dav', DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));

    for (N := 0; N < length (V); N := N + 1)
    {
      call ('DB.DBA.' || detType || '__rdf_insert') (detcol_id, V[N][4], 'R', newGraph);
    }
  }
}
;

create function DB.DBA.DAV_DET_COL_GRAPH (
  in _id integer,
  out _det varchar,
  out _graph_iri varchar)
{
  declare _prop_name, _prop_value, V any;
  declare exit handler for not found { return; };

  select TOP 1
         PROP_NAME,
         PROP_VALUE
    into _prop_name,
         _prop_value
    from WS.WS.SYS_DAV_PROP
   where PROP_PARENT_ID = _id
     and PROP_TYPE = 'C'
     and PROP_NAME like 'virt:%-graph';

  V := sprintf_inverse (_prop_name, 'virt:%s-graph', 1);
  if (length (V) = 1)
  {
    _det := V[0];
    _graph_iri := _prop_value;

    return 1;
  }

  return 0;
}
;

create function DB.DBA.DAV_DET_COL_FIELDS (
  in id integer,
  in prop_name varchar,
  out _det varchar,
  out _owner integer,
  out _group integer,
  out _permissions varchar,
  out _acl any,
  out _graph any)
{
  select COL_DET,
         COL_OWNER,
         COL_GROUP,
         COL_PERMS,
         COL_ACL
    into _det,
        _owner,
        _group,
        _permissions,
        _acl
   from WS.WS.SYS_DAV_COL
  where COL_ID = id;

  if (not DB.DBA.is_empty_or_null (_det))
  {
    _det := subseq (prop_name, strchr (prop_name, ':')+1, strchr (prop_name, '-'));
  }
  _graph := null;
  if (prop_name not like 'virt:%-graph')
  {
    _graph := DB.DBA.DAV_PROP_GET_INT (id, 'C', sprintf ('virt:%s-activity', _det), 0);
    if (isnull (DAV_HIDE_ERROR (_graph)))
    {
      _graph := null;
      return;
    }
  }
  _acl := vector (_acl);
}
;

create function DB.DBA.DAV_DET_ACL2VAL_TRANSFORM_OR_CHILDS (
  in mode varchar,
  in from_id integer,
  in id integer,
  in what varchar)
{
  declare _det, _graph_iri varchar;

  if (DB.DBA.DAV_DET_COL_GRAPH (id, _det, _graph_iri))
  {
    return;
  }
  for (select COL_ID from WS.WS.SYS_DAV_COL where COL_PARENT = id) do
  {
    DB.DBA.DAV_DET_ACL2VAL_TRANSFORM_OR_CHILDS (
      mode,
      from_id,
      COL_ID,
      what
    );
  }
}
;

create function DB.DBA.DAV_DET_ACL2VAL_NEED (
  in id integer,
  in what varchar)
{
  while (1)
  {
    if (exists (select TOP 1 1 from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = id and PROP_TYPE = what and PROP_NAME = 'virt:aci_meta_n3'))
    {
      return id;
    }
    id := (select COL_PARENT from WS.WS.SYS_DAV_COL where COL_ID = id);
    if (isnull (id))
    {
      return 0;
    }
  }
  return 0;
}
;


--
-- Migrate old DAV ACL rules to the new one using VAL ACL API
--
create function DB.DBA.DAV_DET_ACL2VAL_TRANSFORM (
  in from_id integer,
  in id integer,
  in what varchar,
  in oldOwner integer,
  in newOwner integer,
  in oldGraph varchar,
  in newGraph varchar)
{
  return;
}
;


--
-- Private Graph Triggers
--

-- WS.WS.SYS_DAV_COL
create trigger SYS_DAV_COL_PRIVATE_GRAPH_U after update (COL_OWNER, COL_GROUP, COL_PERMS, COL_ACL) on WS.WS.SYS_DAV_COL order 111 referencing old as O, new as N
{
  declare _id integer;
  declare _graph_iri, _det varchar;
  declare _oldAcl, _newAcl any;

  if (DB.DBA.DAV_DET_COL_GRAPH (O.COL_ID, _det, _graph_iri))
  {
    _oldAcl := vector (O.COL_ACL);
    _newAcl := vector (N.COL_ACL);
    DB.DBA.DAV_DET_GRAPH_UPDATE (
      N.COL_ID,
      _det,
      O.COL_OWNER,
      N.COL_OWNER,
      O.COL_GROUP,
      N.COL_GROUP,
      O.COL_PERMS,
      N.COL_PERMS,
      _oldAcl,
      _newAcl,
      _graph_iri,
      _graph_iri
    );
    if (O.COL_OWNER <> N.COL_OWNER)
    {
      _id := N.COL_ID;
      _id := DB.DBA.DAV_DET_ACL2VAL_NEED (_id, 'C');
      if (_id)
      {
        DB.DBA.DAV_DET_ACL2VAL_TRANSFORM (
          _id,
          'C',
          O.COL_OWNER,
          N.COL_OWNER,
          _graph_iri,
          _graph_iri
        );
      }
    }
  }
  else if (O.COL_ACL <> N.COL_ACL)
  {
    DB.DBA.DAV_DET_GRAPH_ACL_UPDATE (
      N.COL_ID,
      vector (O.COL_ACL),
      vector (N.COL_ACL)
    );
  }
}
;

-- WS.WS.SYS_DAV_PROP
create trigger SYS_DAV_PROP_PRIVATE_GRAPH_I after insert on WS.WS.SYS_DAV_PROP order 111 referencing new as N
{
  declare _id, _det, _owner, _group, _permissions, _acls, _graph, _graph_iri any;

  -- Only collections
  if (N.PROP_TYPE <> 'C')
  {
    return;
  }

  if ((N.PROP_NAME like 'virt:%-sponger') or (N.PROP_NAME like 'virt:%-cartridges') or (N.PROP_NAME like 'virt:%-metaCartridges'))
  {
    DB.DBA.DAV_DET_COL_FIELDS (N.PROP_PARENT_ID, N.PROP_NAME, _det, _owner, _group, _permissions, _acls, _graph);
    if (not isnull (_graph))
    {
      DB.DBA.DAV_DET_GRAPH_UPDATE (
        N.PROP_PARENT_ID,
        _det,
        _owner,
        _owner,
        _group,
        _group,
        _permissions,
        _permissions,
        _acls,
        _acls,
        _graph,
        _graph,
        1
      );
    }
  }
  else if (N.PROP_NAME like 'virt:%-graph')
  {
    DB.DBA.DAV_DET_COL_FIELDS (N.PROP_PARENT_ID, N.PROP_NAME, _det, _owner, _group, _permissions, _acls, _graph);
    DB.DBA.DAV_DET_GRAPH_UPDATE (
      N.PROP_PARENT_ID,
      _det,
      _owner,
      _owner,
      _group,
      _group,
      _permissions,
      _permissions,
      _acls,
      _acls,
      null,
      N.PROP_VALUE
    );
    _id := N.PROP_PARENT_ID;
    _id := DB.DBA.DAV_DET_ACL2VAL_NEED (_id, 'C');
    if (_id)
    {
      DB.DBA.DAV_DET_ACL2VAL_TRANSFORM (
        N.PROP_PARENT_ID,
        _id,
        'C',
        _owner,
        _owner,
        null,
        N.PROP_VALUE
      );
    }
  }
  else if (N.PROP_NAME = 'virt:aci_meta_n3')
  {
    DB.DBA.DAV_DET_ACL2VAL_TRANSFORM_OR_CHILDS ('I', N.PROP_PARENT_ID, N.PROP_PARENT_ID, 'C');
  }
}
;

create trigger SYS_DAV_PROP_PRIVATE_GRAPH_U after update on WS.WS.SYS_DAV_PROP order 111 referencing old as O, new as N
{
  declare _id, _det, _owner, _group, _permissions, _acls, _graph, _graph_iri any;

  -- Only collections
  if (N.PROP_TYPE <> 'C')
  {
    return;
  }

  if (O.PROP_VALUE = N.PROP_VALUE)
  {
    return;
  }

  if ((N.PROP_NAME like 'virt:%-sponger') or (N.PROP_NAME like 'virt:%-cartridges') or (N.PROP_NAME like 'virt:%-metaCartridges'))
  {
    DB.DBA.DAV_DET_COL_FIELDS (N.PROP_PARENT_ID, N.PROP_NAME, _det, _owner, _group, _permissions, _acls, _graph);
    if (not isnull (_graph))
    {
      DB.DBA.DAV_DET_GRAPH_UPDATE (
        N.PROP_PARENT_ID,
        _det,
        _owner,
        _owner,
        _group,
        _group,
        _permissions,
        _permissions,
        _acls,
        _acls,
        _graph,
        _graph,
        1
      );
    }
  }
  else if (N.PROP_NAME like 'virt:%-graph')
  {
    DB.DBA.DAV_DET_COL_FIELDS (N.PROP_PARENT_ID, N.PROP_NAME, _det, _owner, _group, _permissions, _acls, _graph);
    DB.DBA.DAV_DET_GRAPH_UPDATE (
      N.PROP_PARENT_ID,
      _det,
      _owner,
      _owner,
      _group,
      _group,
      _permissions,
      _permissions,
      _acls,
      _acls,
      O.PROP_VALUE,
      N.PROP_VALUE
    );
    _id := N.PROP_PARENT_ID;
    _id := DB.DBA.DAV_DET_ACL2VAL_NEED (_id, 'C');
    if (_id)
    {
      DB.DBA.DAV_DET_ACL2VAL_TRANSFORM (
        N.PROP_PARENT_ID,
        _id,
        'C',
        _owner,
        _owner,
        O.PROP_VALUE,
        N.PROP_VALUE
      );
    }
  }
  else if (N.PROP_NAME = 'virt:aci_meta_n3')
  {
    DB.DBA.DAV_DET_ACL2VAL_TRANSFORM_OR_CHILDS ('U', N.PROP_PARENT_ID, N.PROP_PARENT_ID, 'C');
  }
}
;

create trigger SYS_DAV_PROP_PRIVATE_GRAPH_D before delete on WS.WS.SYS_DAV_PROP order 111 referencing old as O
{
  declare _id, _det, _owner, _group, _permissions, _acls, _graph, _graph_iri any;

  -- Only collections
  if (O.PROP_TYPE <> 'C')
  {
    return;
  }

  if ((O.PROP_NAME like 'virt:%-sponger') or (O.PROP_NAME like 'virt:%-cartridges') or (O.PROP_NAME like 'virt:%-metaCartridges'))
  {
    DB.DBA.DAV_DET_COL_FIELDS (O.PROP_PARENT_ID, O.PROP_NAME, _det, _owner, _group, _permissions, _acls, _graph);
    if (not isnull (_graph))
    {
      DB.DBA.DAV_DET_GRAPH_UPDATE (
        O.PROP_PARENT_ID,
        _det,
        _owner,
        _owner,
        _group,
        _group,
        _permissions,
        _permissions,
        _acls,
        _acls,
        _graph,
        _graph,
        1
      );
    }
  }
  else if (O.PROP_NAME like 'virt:%-graph')
  {
    DB.DBA.DAV_DET_COL_FIELDS (O.PROP_PARENT_ID, O.PROP_NAME, _det, _owner, _group, _permissions, _acls, _graph);
    DB.DBA.DAV_DET_GRAPH_UPDATE (
      O.PROP_PARENT_ID,
      _det,
      _owner,
      _owner,
      _group,
      _group,
      _permissions,
      _permissions,
      _acls,
      _acls,
      O.PROP_VALUE,
      null
    );
    _id := O.PROP_PARENT_ID;
    _id := DB.DBA.DAV_DET_ACL2VAL_NEED (_id, 'C');
    if (_id)
    {
      DB.DBA.DAV_DET_ACL2VAL_TRANSFORM (
        O.PROP_PARENT_ID,
        _id,
        'C',
        _owner,
        _owner,
        O.PROP_VALUE,
        null
      );
    }
  }
  else if (O.PROP_NAME = 'virt:aci_meta_n3')
  {
    DB.DBA.DAV_DET_ACL2VAL_TRANSFORM_OR_CHILDS ('D', O.PROP_PARENT_ID, O.PROP_PARENT_ID, 'C');
  }
}
;
