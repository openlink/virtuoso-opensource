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
-- DAV related procs
--
create function DB.DBA.DAV_DET_SPECIAL ()
{
  return vector ('IMAP', 'S3', 'RACKSPACE', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'FTP', 'LDP');
}
;

create function DB.DBA.DAV_DET_IS_SPECIAL (
  in det varchar)
{
  return case when position (det, DB.DBA.DAV_DET_SPECIAL ()) then 1 else 0 end;
}
;

create function DB.DBA.DAV_DET_WEBDAV_BASED ()
{
  return vector ('S3', 'RACKSPACE', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'FTP', 'LDP');
}
;

create function DB.DBA.DAV_DET_IS_WEBDAV_BASED (
  in det varchar)
{
  return case when (DB.DBA.is_empty_or_null (det) or position (det, DB.DBA.DAV_DET_WEBDAV_BASED ())) then 1 else 0 end;
}
;

create function DB.DBA.DAV_DET_NAME (
  in id any)
{
  if (isnull (id) or isinteger (id))
    return null;

  return cast (id[0] as varchar);
}
;

create function DB.DBA.DAV_DET_DETCOL_ID (
  in id any)
{
  if (isnull (id) or isinteger (id))
    return id;

  return cast (id[1] as integer);
}
;

create function DB.DBA.DAV_DET_DAV_ID (
  in id any)
{
  if (isnull (id) or isinteger (id))
    return id;

  return id[2];
}
;

create function DB.DBA.DAV_DET_NAME_FIX (
  in name varchar)
{
  declare N integer;
  declare S varchar;

  S := vector ('/', '\\', ':', '?', '#', '&', '\n');
  for (N := 0; N < length (S); N := N + 1)
  {
    name := replace (name, S[N], '_');
  }

  return name;
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
  declare pos, l integer;

  if (isvector (path))
  {
    l := length (path);
    if ((l > 1) and path[l-1] = '')
      return path[l-2];

    if (l > 0)
      return path[l-1];

    return null;
  }
  path := rtrim (path, '/');
  pos := strrchr (path, '/');
  if (isnull (pos))
    return path;

  return subseq (path, pos+1);
}
;

create function DB.DBA.DAV_DET_PATH_PARENT (
  in path varchar,
  in mode integer := 0) returns varchar
{
  declare pos integer;

  path := trim (path, '/');
  pos := strrchr (path, '/');
  if (isnull (pos))
    return case when mode then '/' else '' end;

  path := left (path, pos);
  return case when mode then '/' || path || '/' else path end;
}
;

create function DB.DBA.DAV_DET_PARENT (
   in id any,
   in what char(1))
{
  if (what = 'R')
    return coalesce ((select RES_COL from WS.WS.SYS_DAV_RES where RES_ID = DB.DBA.DAV_DET_DAV_ID (id)), -1);

  if (what = 'C')
    return coalesce ((select COL_PARENT from WS.WS.SYS_DAV_COL where COL_ID = DB.DBA.DAV_DET_DAV_ID (id)), -1);

  return -1;
}
;

create function DB.DBA.DAV_DET_PROPPATCH (
  in id any,
  in path varchar,
  in pa any,
  in auth_uid varchar,
  in auth_pwd varchar)
{
  declare retValue any;
  declare j, m integer;
  declare det varchar;
  declare det_props, det_params any;
  declare dpa, dpn, dpv any;

  det := trim (cast (xpath_eval ('[xmlns:V="http://www.openlinksw.com/virtuoso/webdav/1.0/"] ./V:name/text()', pa) as varchar));

  -- verify for DET properties
  --
  if      (det = 'DynamicResource' or det = 'DR')
  {
    det := 'DynRes';
  }
  else if (det = 'LinkedDataImport' or det = 'LDI')
  {
    det := 'rdfSink';
  }
  if ((det <> 'rdfSink') and (__proc_exists ('DB.DBA.' || det || '_DAV_AUTHENTICATE_HTTP') is null))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (400);
    return 1;
  }
  det_params := vector ();
  det_props := xpath_eval ('[xmlns:V="http://www.openlinksw.com/virtuoso/webdav/1.0/"] ./V:params/*', pa, 0);
  m := length (det_props);
  for (j := 0; j < m; j := j + 1)
  {
    dpa := det_props[j];
    dpn := cast (xpath_eval ('local-name(.)', dpa) as varchar);
    dpv := trim (cast (xpath_eval ('text()', dpa) as varchar));
    det_params := vector_concat (det_params, vector (dpn, dpv));
  }

  if (det in ('Box', 'Dropbox', 'SkyDrive', 'GDrive'))
  {
    declare expire_in integer;
    declare expire_time datetime;
    declare service_id, service_name, service_sid varchar;
    declare qry, st, msg, meta, rows any;

    -- check if OAuth connection exist
    service_id := get_keyword ('det_serviceId', det_params);
    if      (det = 'SkyDrive')
      service_name := 'windowslive';
    else if (det = 'GDrive')
      service_name := 'google';
    else if (det = 'Box')
      service_name := 'boxnet';
    else
      service_name := lcase (det);

    qry := 'select TOP 1 CS_SID                         \n' ||
           '  from OAUTH.DBA.CLI_SESSIONS,              \n' ||
           '       DB.DBA.WA_USER_OL_ACCOUNTS           \n' ||
           ' where CS_SID = WUO_OAUTH_SID               \n' ||
           '   and CS_SERVICE = ?                       \n' ||
           '   and ((? is null) or (CS_SERVICE_ID = ?)) \n' ||
           '   and position (\'dav\', CS_SCOPE) > 0     \n' ||
           '   and WUO_U_ID = ?                         \n' ||
           '   and WUO_TYPE = \'P\'';
    st := '00000';
    exec (qry, st, msg, vector (service_name, service_id, service_id, auth_uid), 0, meta, rows);
    if (('00000' <> st) or (length (rows) = 0))
    {
      DB.DBA.DAV_SET_HTTP_STATUS (400);
      return 1;
    }
    service_sid := rows[0][0];
    st := '00000';
    qry := 'select * from OAUTH.DBA.CLI_SESSIONS where CS_SID = ?';
    exec (qry, st, msg, vector (service_sid), 0, meta, rows);
    if (('00000' <> st) or (length (rows) = 0))
    {
      DB.DBA.DAV_SET_HTTP_STATUS (400);
      return 1;
    }
    det_params := vector_concat (det_params, vector ('Authentication', 'Yes'));
    -- Box, SkyDrive and GDrive - OAuth 2.0 params
    if (det in ('Box', 'SkyDrive', 'GDrive'))
    {
      expire_time := rows[0][0];
      if (isnull (expire_time) or (expire_time < now ()))
        expire_time := now ();

      expire_in := datediff ('second', now (), expire_time);
      det_params := vector_concat (det_params, vector ('access_token', rows[0][1]));
      det_params := vector_concat (det_params, vector ('refresh_token', rows[0][2]));
      det_params := vector_concat (det_params, vector ('expire_in', expire_in));
      det_params := vector_concat (det_params, vector ('access_timestamp', datestring (now ())));
    }
    -- Dropbox  - OAuth 1.0 params
    else if (det in ('Dropbox'))
    {
      det_params := vector_concat (det_params, vector ('sid', service_sid));
      det_params := vector_concat (det_params, vector ('access_token', rows[0][1]));
    }
  }

  -- verify input DET params
  retValue := null;
  if (__proc_exists ('DB.DBA.' || det || '_VERIFY') is not null)
  {
    -- set DET type parameters
    retValue := call ('DB.DBA.' || det || '_VERIFY') (path, det_params);
  }
  else if (__proc_exists ('WEBDAV.DBA.' || det || '_VERIFY') is not null)
  {
    retValue := call ('WEBDAV.DBA.' || det || '_VERIFY') (path, det_params);
  }
  if (not isnull (retValue))
  {
    return -17;
  }

  -- set DET type
  if (det <> 'rdfSink')
    retValue := DB.DBA.DAV_PROP_SET_INT (path, ':virtdet', det, null, null, 0, 0, 0, http_dav_uid ());

  if (DB.DBA.DAV_HIDE_ERROR (retValue) is not null)
  {
    if (__proc_exists ('DB.DBA.' || det || '_CONFIGURE') is not null)
    {
      -- set DET type parameters
      retValue := call ('DB.DBA.' || det || '_CONFIGURE') (id, det_params);
    }
    else if (__proc_exists ('WEBDAV.DBA.' || det || '_CONFIGURE') is not null)
    {
      retValue := call ('WEBDAV.DBA.' || det || '_CONFIGURE') (id, det_params);
    }
    if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
    {
      return -17;
    }
  }
  return 0;
}
;

-- Common copy/move proceure
create function DB.DBA.DAV_DET_RES_UPLOAD_CM (
  in mode varchar,
  in det varchar,
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in auth_uname varchar,
  in auth_pwd varchar,
  in extern integer,
  in check_locks integer,
  inout source_entry any,
  inout source_path varchar,
  inout target_path varchar)
{
  -- dbg_obj_princ ('DAV_DET_RES_UPLOAD_CM (', mode, detcol_id, path_parts, source_id, what, ')');
  declare source_pid, source_content, source_type any;
  declare target_pid, target_id any;
  declare retValue, tmp any;

  retValue := -20;
  source_entry := DB.DBA.DAV_DIR_SINGLE_INT (source_id, what, '', null, null, http_dav_uid ());
  if (DB.DBA.DAV_HIDE_ERROR (source_entry) is null)
  {
    retValue := source_entry;
    goto _exit;
  }

  if (mode = 'move')
  {
    permissions := source_entry[5];
    uid := source_entry[7];
    gid := source_entry[6];
  }

  -- source parent ID
  source_path := source_entry[0];
  source_pid := DB.DBA.DAV_SEARCH_ID (source_path, 'P');

  -- targer parent ID
  target_path := DB.DBA.DAV_DET_PATH (detcol_id, path_parts);
  target_pid := DB.DBA.DAV_SEARCH_ID (target_path, 'P');
  if (DB.DBA.DAV_DET_DAV_ID (source_pid) <> DB.DBA.DAV_DET_DAV_ID (target_pid))
  {
    if (what = 'R')
    {
      source_content := string_output ();
      retValue := DB.DBA.DAV_RES_CONTENT_INT (source_id, source_content, source_type, 0, extern, auth_uname, auth_pwd);
      if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
        goto _exit;

      retValue := call (cast (det as varchar) || '_DAV_RES_UPLOAD') (detcol_id, path_parts, source_content, source_type, permissions, uid, gid, auth_uid);
      if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
        goto _exit;

      target_id := retValue;
      DB.DBA.DAV_COPY_PROPS (0, source_id, 'R', target_id, auth_uname, auth_pwd, extern, auth_uid);
      DB.DBA.DAV_COPY_TAGS (source_id, 'R', target_id);
      if (mode = 'move')
      {
        tmp := DB.DBA.DAV_DELETE_INT (source_path, 1, auth_uname, auth_pwd, extern, check_locks);
        if (DB.DBA.DAV_HIDE_ERROR (tmp) is null)
        {
          retValue := tmp;
          goto _exit;
        }
      }
    }
    else if ((what = 'C') and (cast (det as varchar) <> coalesce (DB.DBA.DAV_DET_NAME (source_id), '')))
    {
      target_id := call (cast (det as varchar) || '_DAV_COL_CREATE') (detcol_id, path_parts, permissions, uid, gid, auth_uid, extern);
      if (DB.DBA.DAV_HIDE_ERROR (target_id) is null)
      {
        rollback work;
        retValue := target_id;
        goto _exit;
      }
      DB.DBA.DAV_COPY_SUBTREE (source_id , target_id, source_path, target_path, 1, source_entry[7], source_entry[6], auth_uname, auth_pwd, extern, check_locks, auth_uid);
      if (mode = 'move')
      {
        tmp := DB.DBA.DAV_DELETE_INT (source_path, 1, auth_uname, auth_pwd, extern, check_locks);
        if (DB.DBA.DAV_HIDE_ERROR (tmp) is null)
        {
          rollback work;
          retValue := tmp;
          goto _exit;
        }
      }
      retValue := target_id;
    }
  }
_exit:;
  return retValue;
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
                      coalesce (RES_ADD_TIME, RES_CR_TIME),
                      RES_CREATOR) as I
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
                      coalesce (COL_ADD_TIME, COL_CR_TIME),
                      COL_CREATOR) as I
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
create function DB.DBA.DAV_DET_PROPS_REMOVE (
  in _det varchar,
  in _id any,
  in _what varchar)
{
  declare props any;

  if (isarray (_id))
    return;

  props := DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_PROP_LIST_INT (_id, _what, '%', 1), vector ());
  foreach (any prop in props) do
  {
    if ((prop[0] like ('virt:' || _det || '%')) or (prop[0] = 'virt:DETCOL_ID'))
    {
      DB.DBA.DAV_PROP_REMOVE_RAW (_id, _what, prop[0], 1, http_dav_uid());
    }
  }
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
  if (isnull (DB.DBA.DAV_HIDE_ERROR (activity)))
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
  DB.DBA.DAV_PROP_SET_INT (activityPath, ':virtpermissions', '110100000RR', null, null, 0, 0, 1, http_dav_uid());
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

create function DB.DBA.DAV_DET_HTTP_MESSAGE (
  in _header any)
{
  return subseq (_header[0], 13);
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

create function DB.DBA.DAV_DET_USER_IRI (
  in user_id integer) returns varchar
{
  return sprintf ('%s/dataspace/person/%s#this',  WS.WS.DAV_HOST (), DB.DBA.DAV_DET_USER (user_id));
}
;

create function DB.DBA.DAV_DET_PASSWORD (
  in user_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_ID = user_id), '');
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
    if (DB.DBA.DAV_HIDE_ERROR (id))
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
  {
    propValue := null;
  }
  else
  {
    if (_serialized and not isnull (propValue))
      propValue := deserialize (propValue);

    if (_decrypt and not isnull (propValue))
      propValue := pwd_magic_calc (_password, propValue, 1);
  }

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
-- RDF related params functions
--
create function DB.DBA.DAV_DET_RDF_DEFAULT_KEYS ()
{
  return vector ('sponger', 'cartridges', 'metaCartridges', 'graph', 'graphSecurity', 'graphSecurityACL', 'graphSecurityACI');
}
;

create function DB.DBA.DAV_DET_RDF_PARAMS_SET (
  in _det varchar,
  in _id any,
  in _params any,
  in _keys any := null)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_PARAMS_SET (', _det, _id, _params, _keys, ')');
  declare N integer;
  declare _data any;

  if (isnull (_keys))
  {
    _keys := DB.DBA.DAV_DET_RDF_DEFAULT_KEYS ();
  }

  _data := vector ();
  for (N := 0; N < length (_keys); N := N + 1)
  {
    _data := vector_concat (_data, vector (_keys[N], get_keyword (_keys[N], _params)));
  }
  return DB.DBA.DAV_DET_RDF_PARAMS_SET_INT (_det, _id, _data);
}
;

create function DB.DBA.DAV_DET_RDF_PARAMS_SET_INT (
  in _det varchar,
  in _id any,
  in _data any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_PARAMS_SET_INT (', _det, _path, _data, ')');

  return DB.DBA.DAV_PROP_SET_INT (DB.DBA.DAV_SEARCH_PATH (_id, 'C'), sprintf ('virt:%s-rdf', _det), serialize (_data), null, null, 0, 0, 1, http_dav_uid ());
}
;

create function DB.DBA.DAV_DET_RDF_PARAMS_GET (
  in _det varchar,
  in _id any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_PARAMS_GET (', _det, _path, ')');
  declare retValue any;

  retValue := DB.DBA.DAV_PROP_GET_INT (_id, 'C', sprintf ('virt:%s-rdf', _det), 0);
  if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
  {
    return vector ('sponger', 'off', 'graphSecurity', 'off');
  }
  return deserialize (retValue);
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

  return dateadd ('minute', timezone (curdatetime_tz()), rs);
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
  }
  else
  {
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
  declare rdf_params any;
  declare aq any;

  rdf_params := DB.DBA.DAV_DET_RDF_PARAMS_GET (det, detcol_id);
  if (DB.DBA.is_empty_or_null (get_keyword ('graph', rdf_params)))
    return;

  set_user_id ('dba');
  aq := async_queue (1, 4);
  aq_request (aq, 'DB.DBA.DAV_DET_RDF_AQ', vector (det, detcol_id, id, what, rdf_params));
}
;

create function DB.DBA.DAV_DET_RDF_AQ (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_params any)
{
  set_user_id ('dba');
  DB.DBA.DAV_DET_RDF_DELETE (det, detcol_id, id, what, rdf_params);
  DB.DBA.DAV_DET_RDF_INSERT (det, detcol_id, id, what, rdf_params);
}
;

create function DB.DBA.DAV_DET_RDF_INSERT (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_params any := null)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_INSERT (', det, detcol_id, id, what, rdf_params, ')');
  declare permissions varchar;
  declare rdf_graph, rdf_sponger, rdf_cartridges, rdf_metaCartridges any;
  declare path, content, type any;
  declare exit handler for sqlstate '*'
  {
    return;
  };

  if (what <> 'R')
    return;

  if (isnull (rdf_params))
    rdf_params := DB.DBA.DAV_DET_RDF_PARAMS_GET (det, detcol_id);

  rdf_graph := get_keyword ('graph', rdf_params, '');
  if (rdf_graph = '')
    return;

  if (not DB.DBA.DAV_DET_IS_WEBDAV_BASED (det) and (__proc_exists ('DB.DBA.' || det || '__RDF_INSERT') is not null))
  {
    return call ('DB.DBA.' || det || '__rdf_insert') (detcol_id, id, 'R', rdf_params);
  }

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
  rdf_sponger := get_keyword ('sponger', rdf_params, 'off');
  rdf_cartridges := get_keyword ('cartridges', rdf_params);
  rdf_metaCartridges := get_keyword ('metaCartridges', rdf_params);

  DB.DBA.RDF_SINK_UPLOAD (path, content, type, rdf_graph, null, rdf_sponger, rdf_cartridges, rdf_metaCartridges);
}
;

create function DB.DBA.DAV_DET_RDF_DELETE (
  in det varchar,
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_params any := null)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_DELETE (', det, detcol_id, id, what, rdf_params, ')');
  declare path varchar;
  declare rdf_graph any;
  declare exit handler for sqlstate '*'
  {
    return;
  };

  if (what <> 'R')
    return;

  if (isnull (rdf_params))
    rdf_params := DB.DBA.DAV_DET_RDF_PARAMS_GET (det, detcol_id);

  rdf_graph := get_keyword ('graph', rdf_params, '');
  if (rdf_graph = '')
    return;

  if (not DB.DBA.DAV_DET_IS_WEBDAV_BASED (det) and (__proc_exists ('DB.DBA.' || det || '__RDF_DELETE') is not null))
  {
    return call ('DB.DBA.' || det || '__rdf_delete') (detcol_id, id, 'R', rdf_params);
  }

  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  DB.DBA.RDF_SINK_DELETE (-1, path, id, detcol_id, 1);
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
  if (DB.DBA.DAV_HIDE_ERROR (colId) is not null)
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
  if (DB.DBA.DAV_HIDE_ERROR (oldId) is not null)
  {
    update WS.WS.SYS_DAV_RES set RES_CONTENT = oldContent where RES_ID = DB.DBA.DAV_DET_DAV_ID (oldID);
  }
  else
  {
    DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0, 0);
  }
}
;

create function DB.DBA.DAV_DET_CONTENT_MD5 (
  in id any)
{
  return md5 (blob_to_string_output ((select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = DB.DBA.DAV_DET_DAV_ID (id))));
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
  DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('nobody', 1, 1);
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
  declare private_graph varchar;
  declare private_graph_id any;

  private_graph := DB.DBA.DAV_DET_PRIVATE_GRAPH ();
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = private_graph))
    return 0;

  private_graph_id := DB.DBA.DAV_DET_PRIVATE_GRAPH_ID ();
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = private_graph_id and RGGM_MEMBER_IID = iri_to_id (graph_iri)))
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
    uid := DB.DBA.DAV_DET_USER (uid);

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
    uid := DB.DBA.DAV_DET_USER (uid);

  DB.DBA.RDF_GRAPH_USER_PERMS_DEL (graph_iri, uid);

  return 1;
}
;

--!
-- \brief Compare 2 ACLs fo eqality
--/
create function DB.DBA.DAV_DET_PRIVATE_ACL_COMPARE (
  in acls_1 any,
  in acls_2 any)
{
  declare N integer;

  if (length (acls_1) <> length (acls_2))
    return 0;

  for (N := 0; N < length (acls_1); N := N + 1)
  {
    if (acls_1[N] <> acls_2[N])
      return 0;
  }
  return 1;
}
;

--!
-- \brief Add permissions based on ACLs
--/
create function DB.DBA.DAV_DET_PRIVATE_ACL_ADD (
  in graph varchar,
  in acls any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_PRIVATE_ACL_ADD (', graph, length (acls), ')');
  declare N, L integer;
  declare V, allow, denny any;

  allow := vector ();
  denny := vector ();
  L := length (acls);
  for (N := L-1; N >= 0; N := N - 1)
  {
    V := WS.WS.ACL_PARSE (acls[N], case when (N = L-1) then '01' else '12' end, 0);
    foreach (any acl in V) do
    {
      if (not position (acl[0], allow) and not position (acl[0], denny))
      {
        if (acl[1] = 1)
        {
          allow := vector_concat (allow, vector (acl[0]));
        }
        else
        {
          denny := vector_concat (denny, vector (acl[0]));
        }
      }
    }
  }

  for (N := 0; N < length (allow); N := N + 1)
  {
    DB.DBA.DAV_DET_PRIVATE_USER_ADD (graph, allow[N]);
  }

  for (N := 0; N < length (denny); N := N + 1)
  {
    DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (graph, denny[N]);
  }
}
;

--!
-- \brief Remove permissions based on ACLs
--/
create function DB.DBA.DAV_DET_PRIVATE_ACL_REMOVE (
  in graph varchar,
  in acls any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_PRIVATE_ACL_REMOVE (', graph, acls, ')');
  declare N, L integer;
  declare V, denny any;

  denny := vector ();
  L := length (acls);
  for (N := L-1; N >= 0; N := N - 1)
  {
    V := WS.WS.ACL_PARSE (acls[N], case when (N = L-1) then '01' else '12' end, 0);
    foreach (any acl in V) do
    {
      if ((acl[1] = 1) and not position (acl[0], denny))
        denny := vector_concat (denny, vector (acl[0]));
    }
  }

  for (N := 0; N < length (denny); N := N + 1)
  {
    DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (graph, denny[N]);
  }
}
;

create function DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (
  in id integer,
  in what varchar,
  inout oldAcls any,
  inout newAcls any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (', id, what, ')');
  declare _id integer;
  declare _acl any;
  declare exit handler for not found { return; };

  -- get acls
  while (1)
  {
    select COL_ACL, COL_PARENT into _id, _acl from WS.WS.SYS_DAV_COL where COL_ID = _id;
    if (length (_acl) > 8)
    {
      oldAcls := vector_concat (vector (_acl), oldAcls);
      newAcls := vector_concat (vector (_acl), newAcls);
    }
  }
}
;


--!
-- \brief Update graph permissions (collections only)
--/
create function DB.DBA.DAV_DET_GRAPH_UPDATE (
  in id integer,
  in oldOwner integer,
  in newOwner integer,
  in oldGroup integer,
  in newGroup integer,
  in oldPermissions varchar,
  in newPermissions varchar,
  in oldAcls any,
  in newAcls any,
  in oldRDFParams any,
  in newRDFParams any,
  in forceUpdate integer := 0,
  in forceChild integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_GRAPH_UPDATE (', id, oldOwner, newOwner, oldGroup, newGroup, oldPermissions, newPermissions, oldAcls, newAcls, oldRDFParams, newRDFParams, ')');
  declare N integer;
  declare det, path, graph varchar;
  declare oldGraph, newGraph varchar;
  declare aq, aci, acis, rdfParams any;

  oldGraph := get_keyword ('graph', oldRDFParams, '');
  newGraph := get_keyword ('graph', newRDFParams, '');

  -- update if needed
  if (
      (oldGraph                      = newGraph)                      and
      (coalesce (oldOwner, -1)       = coalesce (newOwner, -1))       and
      (coalesce (oldGroup, -1)       = coalesce (newGroup, -1))       and
      (coalesce (oldPermissions, '') = coalesce (newPermissions, '')) and
      (DB.DBA.DAV_DET_PRIVATE_ACL_COMPARE (oldAcls, newAcls))         and
      (forceUpdate = 0)
     )
  {
    return;
  }

  -- old col graph
  if (oldGraph <> '')
  {
    DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (id, 'C', oldGraph, oldOwner, oldGroup, oldAcls);
  }

  -- new col graph
  if (newGraph <> '')
  {
    DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (id, 'C', newGraph, newOwner, newGroup, newPermissions, newAcls, newRDFParams);
  }

  if (DB.DBA.DAV_DET_COL_RDF_PARAMS (id, det, rdfParams))
  {
    if (get_keyword ('graphSecurity', rdfParams, 'off') = 'off')
    {
      graph := get_keyword ('graph', rdfParams);
      newRDFParams := vector ('graph', graph, 'graphSecurityACI', get_keyword ('graphSecurityACI', newRDFParams));
      DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (id, 'C', graph, oldOwner, oldGroup, oldAcls);
      DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (id, 'C', graph, newOwner, newGroup, newPermissions, newAcls, newRDFParams);
    }
  }

  if (forceChild)
  {
    for (N := 0; N < length (oldAcls); N := N + 1)
      oldAcls[N] := cast (oldAcls[N] as varchar);

    for (N := 0; N < length (newAcls); N := N + 1)
      newAcls[N] := cast (newAcls[N] as varchar);

    aq := async_queue (1, 4);
    aq_request (aq, 'DB.DBA.DAV_DET_GRAPH_UPDATE_CHILD', vector (id, 'C', oldAcls, newAcls, oldRDFParams, newRDFParams, forceUpdate));
  }
}
;

--!
-- \brief Update graph permissions (collections only)
--/
create function DB.DBA.DAV_DET_RDF_GRAPH_UPDATE (
  in id integer,
  in oldRDFParams any,
  in newRDFParams any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_GRAPH_UPDATE (', id, oldRDFParams, newRDFParams, ')');
  declare path, detType varchar;
  declare oldGraph, newGraph, oldGraphSecurity, newGraphSecurity, oldSponger, newSponger, oldCartridges, newCartridges, oldMetaCartridges, newMetaCartridges varchar;
  declare oldAcls, newAcls any;
  declare aq any;

  oldGraphSecurity := get_keyword ('graphSecurity', oldRDFParams, 'off');
  newGraphSecurity := get_keyword ('graphSecurity', newRDFParams, 'off');

  oldGraph := get_keyword ('graph', oldRDFParams, '');
  newGraph := get_keyword ('graph', newRDFParams, '');

  oldSponger := get_keyword ('sponger', oldRDFParams, 'off');
  newSponger := get_keyword ('sponger', newRDFParams, 'off');

  oldCartridges := get_keyword ('cartridges', oldRDFParams, '');
  newCartridges := get_keyword ('cartridges', newRDFParams, '');

  oldMetaCartridges := get_keyword ('metaCartridges', oldRDFParams, '');
  newMetaCartridges := get_keyword ('metaCartridges', newRDFParams, '');

  oldAcls := vector ();
  if (oldGraphSecurity <> 'off')
  {
    oldAcls := vector (get_keyword ('graphSecurityACL', oldRDFParams));
  }

  newAcls := vector ();
  if (newGraphSecurity <> 'off')
  {
    newAcls := vector (get_keyword ('graphSecurityACL', newRDFParams));
  }

  -- update graph if needed
  if (
      (oldGraphSecurity  <> newGraphSecurity)                     or
      (oldGraph          <> newGraph)                             or
      (oldSponger        <> newSponger)                           or
      (oldCartridges     <> newCartridges)                        or
      (oldMetaCartridges <> newMetaCartridges)                    or
      (not DB.DBA.DAV_DET_PRIVATE_ACL_COMPARE (oldAcls, newAcls))
     )
  {
    -- old graph
    if (oldGraph <> '')
    {
      DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (id, 'C', oldGraph, null, null, oldAcls);
    }

    -- new graph
    if (newGraph <> '')
    {
      DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (id, 'C', newGraph, null, null, '000000000', newAcls, newRDFParams);
    }
  }

  if (
      (oldGraph          <> newGraph)          or
      (oldSponger        <> newSponger)        or
      (oldCartridges     <> newCartridges)     or
      (oldMetaCartridges <> newMetaCartridges)
     )
  {
    oldRDFParams := vector (
      'graph', oldGraph,
      'sponger', oldSponger,
      'cartridges', oldCartridges,
      'metaCartridges', oldMetaCartridges
    );
    newRDFParams := vector (
      'graph', newGraph,
      'sponger', newSponger,
      'cartridges', newCartridges,
      'metaCartridges', newMetaCartridges
    );

    path := DB.DBA.DAV_SEARCH_PATH (id, 'C');
    detType := DB.DBA.DAV_DET_COL_DET (id);
    aq := async_queue (1, 4);
    aq_request (aq, 'DB.DBA.DAV_DET_RDF_GRAPH_UPDATE_AQ', vector (path, cast (detType as varchar), oldRDFParams, newRDFParams));
  }
}
;

--!
-- \brief Thread for update RDF sponger data
--/
create function DB.DBA.DAV_DET_RDF_GRAPH_UPDATE_AQ (
  in path varchar,
  in det varchar,
  in oldRDFParams any,
  in newRDFParams any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RDF_GRAPH_UPDATE_AQ (', path, det, oldRDFParams, newRDFParams, ')');
  declare N, detcol_id integer;
  declare oldGraph, newGraph varchar;
  declare V, filter any;

  oldGraph := get_keyword ('graph', oldRDFParams, '');
  newGraph := get_keyword ('graph', newRDFParams, '');
  if ((oldGraph = '') and (newGraph = ''))
    return;

  detcol_id := DB.DBA.DAV_SEARCH_ID (path, 'C');
  filter := vector (vector ('RES_FULL_PATH', 'like', path || '%'));
  V := DB.DBA.DAV_DIR_FILTER (path, 1, filter, 'dav', DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));
  if (oldGraph <> '')
  {
    for (N := 0; N < length (V); N := N + 1)
    {
      DB.DBA.DAV_DET_RDF_DELETE (det, detcol_id, V[N][4], 'R', oldRDFParams);
    }
  }

  if (newGraph <> '')
  {
    for (N := 0; N < length (V); N := N + 1)
    {
      DB.DBA.DAV_DET_RDF_INSERT (det, detcol_id, V[N][4], 'R', newRDFParams);
    }
  }
}
;

--!
-- \brief Update graph permissions (collections only) (LDP change)
--/
create function DB.DBA.DAV_DET_LDP_GRAPH_UPDATE (
  in id integer)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_LDP_GRAPH_UPDATE (', id, ')');

  for (select COL_ACL    as _acl,
              COL_OWNER  as _owner,
              COL_GROUP  as _group,
              COL_PERMS  as _perms,
              COL_PARENT as _parent_id
         from WS.WS.SYS_DAV_COL
        where COL_ID = id) do
  {
    declare _oldAcls, _newAcls, _rdfParams any;

    -- ACLs
    _oldAcls := vector (_acl);
    _newAcls := vector (_acl);
    DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (_parent_id, 'C', _oldAcls, _newAcls);

    _rdfParams := vector ('graph', WS.WS.DAV_IRI (DB.DBA.DAV_SEARCH_PATH (id, 'C')));

    -- check for graph
    DB.DBA.DAV_DET_GRAPH_UPDATE (
      id,
      _owner,
      _owner,
      _group,
      _group,
      _perms,
      _perms,
      _oldAcls,
      _newAcls,
      _rdfParams,
      _rdfParams,
      1,
      1
    );
  }
}
;

--!
-- \brief Update graph permissions (resources only)
--/
create function DB.DBA.DAV_DET_RES_GRAPH_UPDATE (
  in id integer,
  in mode varchar,
  in oldMimeType varchar,
  in newMimeType varchar,
  in oldOwner integer,
  in newOwner integer,
  in oldGroup integer,
  in newGroup integer,
  in oldPermissions varchar,
  in newPermissions varchar,
  in oldAcls any,
  in newAcls any,
  in oldRDFParams any,
  in newRDFParams any,
  in forceUpdate integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_RES_GRAPH_UPDATE (', id, mode, oldMimeType, newMimeType, oldRDFParams, newRDFParams, ')');
  declare oldGraph, newGraph varchar;
  declare aci, acis any;

  oldMimeType := coalesce (oldMimeType, '');
  newMimeType := coalesce (newMimeType, '');
  if ((mode = 'I') and (newMimeType <> 'text/turtle'))
    return;

  if ((mode = 'D') and (oldMimeType <> 'text/turtle'))
    return;

  if ((mode = 'U') and (oldMimeType <> 'text/turtle') and (newMimeType <> 'text/turtle'))
    return;

  oldGraph := get_keyword ('graph', oldRDFParams, '');
  newGraph := get_keyword ('graph', newRDFParams, '');

  -- update if needed
  if (
      (oldGraph                      = newGraph)                      and
      (coalesce (oldOwner, -1)       = coalesce (newOwner, -1))       and
      (coalesce (oldGroup, -1)       = coalesce (newGroup, -1))       and
      (coalesce (oldPermissions, '') = coalesce (newPermissions, '')) and
      (DB.DBA.DAV_DET_PRIVATE_ACL_COMPARE (oldAcls, newAcls))         and
      (forceUpdate = 0)
     )
  {
    return;
  }

  -- old graph
  if (oldGraph <> '')
  {
    DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (id, 'R', oldGraph, oldOwner, oldGroup, oldAcls);
  }

  -- new graph
  if (newGraph <> '')
  {
    DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (id, 'R', newGraph, newOwner, newGroup, newPermissions, newAcls, newRDFParams);
  }

}
;

create function DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (
  in id any,
  in what varchar,
  in newGraph varchar,
  in newOwner integer,
  in newGroup integer,
  in newPermissions varchar,
  in newAcls any,
  in newRDFParams any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (', id, what, newGraph, newOwner, newGroup, newPermissions, newAcls, newRDFParams, ')');

  -- Public permissions
  if (newPermissions[6] = ascii ('1'))
    return;

  -- Add to private graph
  -- graph
  DB.DBA.DAV_DET_PRIVATE_GRAPH_ADD (newGraph);
  -- owner
  if (not isnull (newOwner))
    DB.DBA.DAV_DET_PRIVATE_USER_ADD (newGraph, newOwner);

  -- group
  if ((not isnull (newGroup)) and (newOwner <> newGroup) and (newPermissions[3] = ascii ('1')))
    DB.DBA.DAV_DET_PRIVATE_USER_ADD (newGraph, newGroup);

  -- ACLs
  DB.DBA.DAV_DET_PRIVATE_ACL_ADD (newGraph, newAcls);

}
;

--!
-- \brief Remove private permissions, ACLs and ACIs
--/
create function DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (
  in id integer,
  in what varchar,
  in oldGraph varchar,
  in oldOwner integer,
  in oldGroup integer,
  in oldAcls any)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (', id, what, oldGraph, oldOwner, oldGroup, oldAcls, ')');

  -- Remove from private graphs
  -- owner
  if (not isnull (oldOwner))
    DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (oldGraph, oldOwner);

  -- group
  if ((not isnull (oldGroup)) and (oldOwner <> oldGroup))
    DB.DBA.DAV_DET_PRIVATE_USER_REMOVE (oldGraph, oldGroup);

  -- ACLs
  DB.DBA.DAV_DET_PRIVATE_ACL_REMOVE (oldGraph, oldAcls);


  -- graph
  DB.DBA.DAV_DET_PRIVATE_GRAPH_REMOVE (oldGraph);
}
;

create function DB.DBA.DAV_DET_GRAPH_UPDATE_CURRENT (
  in id integer,
  in what varchar,
  in mode varchar)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_GRAPH_UPDATE_CURRENT (', id, what, ')');
  declare _oldAcls, _newAcls any;
  declare _acis any;
  declare _rdfParams any;

  if (what = 'R')
  {
    for (select RES_ID        as _id,
                RES_TYPE      as _type,
                RES_ACL       as _acl,
                RES_OWNER     as _owner,
                RES_GROUP     as _group,
                RES_PERMS     as _perms,
                RES_FULL_PATH as _path,
                RES_COL       as _parent_id
           from WS.WS.SYS_DAV_RES
          where RES_ID = id and RES_TYPE = 'text/turtle') do
    {
      -- ACLs
      _oldAcls := vector (_acl);
      _newAcls := vector (_acl);
      DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (_parent_id, 'C', _oldAcls, _newAcls);


      _rdfParams := vector ('graph', WS.WS.DAV_IRI (_path), 'graphSecurityACI', _acis);
      DB.DBA.DAV_DET_RES_GRAPH_UPDATE (
        _id,
        '',
        _type,
        _type,
        _owner,
        _owner,
        _group,
        _group,
        _perms,
        _perms,
        _oldAcls,
        _newAcls,
        _rdfParams,
        _rdfParams,
        1
      );
    }
  }

  if (what = 'C')
  {
    for (select COL_ID     as _id,
                COL_ACL    as _acl,
                COL_OWNER  as _owner,
                COL_GROUP  as _group,
                COL_PERMS  as _perms,
                COL_PARENT as _parent_id
           from WS.WS.SYS_DAV_COL
          where COL_ID = id) do
    {
      declare _path varchar;

      _path := DB.DBA.DAV_SEARCH_PATH (_id, 'C');

      -- ACLs
      _oldAcls := vector (_acl);
      _newAcls := vector (_acl);
      DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (_parent_id, 'C', _oldAcls, _newAcls);


      _rdfParams := vector ('graph', WS.WS.DAV_IRI (_path), 'graphSecurityACI', _acis);
      DB.DBA.DAV_DET_GRAPH_UPDATE (
        _id,
        _owner,
        _owner,
        _group,
        _group,
        _perms,
        _perms,
        _oldAcls,
        _newAcls,
        _rdfParams,
        _rdfParams,
        1,
        1
      );
    }
  }
}
;

create function DB.DBA.DAV_DET_GRAPH_UPDATE_CHILD (
  in id integer,
  in what varchar,
  in oldAcls any,
  in newAcls any,
  in oldRDFParams any,
  in newRDFParams any,
  in forceUpdate integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_DET_GRAPH_UPDATE_CHILD (', id, what, oldAcls, newAcls, ')');
  declare _oldAcls, _newAcls any;
  declare _aci, _acis, _rdfParams any;

  for (select RES_ID    as _id,
              RES_TYPE  as _type,
              RES_ACL   as _acl,
              RES_OWNER as _owner,
              RES_GROUP as _group,
              RES_PERMS as _perms,
              RES_FULL_PATH as _path
         from WS.WS.SYS_DAV_RES
        where RES_COL = id and RES_TYPE = 'text/turtle') do
  {
    -- ACLs
    if (length (_acl) > 8)
    {
      _oldAcls := vector_concat (oldAcls, vector (_acl));
      _newAcls := vector_concat (newAcls, vector (_acl));
    }
    else
    {
      _oldAcls := oldAcls;
      _newAcls := newAcls;
    }


    _rdfParams := vector ('graph', WS.WS.DAV_IRI (_path), 'graphSecurityACI', _acis);
    DB.DBA.DAV_DET_RES_GRAPH_UPDATE (
      _id,
      '',
      _type,
      _type,
      _owner,
      _owner,
      _group,
      _group,
      _perms,
      _perms,
      _oldAcls,
      _newAcls,
      _rdfParams,
      _rdfParams,
      forceUpdate
    );
  }

  for (select COL_ID    as _id,
              COL_ACL   as _acl,
              COL_OWNER as _owner,
              COL_GROUP as _group,
              COL_PERMS as _perms
         from WS.WS.SYS_DAV_COL
        where COL_PARENT = id) do
  {
    declare _path varchar;

    _path := DB.DBA.DAV_SEARCH_PATH (_id, 'C');

    -- ACLs
    if (length (_acl) > 8)
    {
      _oldAcls := vector_concat (oldAcls, vector (_acl));
      _newAcls := vector_concat (newAcls, vector (_acl));
    }
    else
    {
      _oldAcls := oldAcls;
      _newAcls := newAcls;
    }


    -- check for graph
    _rdfParams := vector ('graph', WS.WS.DAV_IRI (_path), 'graphSecurityACI', _acis);
    DB.DBA.DAV_DET_GRAPH_UPDATE (
      _id,
      _owner,
      _owner,
      _group,
      _group,
      _perms,
      _perms,
      _oldAcls,
      _newAcls,
      _rdfParams,
      _rdfParams,
      forceUpdate,
      0
    );

    DB.DBA.DAV_DET_GRAPH_UPDATE_CHILD (
      _id,
      'C',
      _oldAcls,
      _newAcls,
      _rdfParams,
      _rdfParams,
      forceUpdate
    );
  }
}
;

create function DB.DBA.DAV_DET_COL_DET (
  in _id integer,
  in _mode integer := 1)
{
  declare _det varchar;

  _det := '';
  if (_mode)
  {
    _det := coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = _id), '');
  }
  if (_det = '')
  {
    if (DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_PROP_GET_INT (_id, 'C', 'virt:rdfSink-rdf', 0)) is not null)
      _det := 'rdfSink';
  }

  return _det;
}
;

create function DB.DBA.DAV_DET_COL_RDF_PARAMS (
  in _id integer,
  out _det varchar,
  out _rdfParams any)
{
  declare _prop_name, _prop_value, V any;
  declare exit handler for not found { return; };

  _det := DB.DBA.DAV_DET_COL_DET (_id);
  if (_det = '')
    return 0;

  _rdfParams := DB.DBA.DAV_DET_RDF_PARAMS_GET (_det, _id);

  return length ( _rdfParams);
}
;


--
-- Private Graph Triggers
--

-- WS.WS.SYS_DAV_COL
create trigger SYS_DAV_COL_PRIVATE_GRAPH_I after insert on WS.WS.SYS_DAV_COL order 111 referencing new as N
{
  -- dbg_obj_print ('SYS_DAV_COL_PRIVATE_GRAPH_I ---------------');
  declare _newPath varchar;
  declare _oldAcls, _newAcls any;
  declare _acis, _rdfParams any;

  -- Paths
  _newPath := DB.DBA.DAV_SEARCH_PATH (N.COL_ID, 'C');

  -- ACLs
  _oldAcls := vector ();
  _newAcls := vector (N.COL_ACL);
  DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (N.COL_PARENT, 'C', _oldAcls, _newAcls);


  _rdfParams := vector ('graph', WS.WS.DAV_IRI (_newPath), 'graphSecurityACI', _acis);
  DB.DBA.DAV_DET_GRAPH_PERMISSIONS_SET (
    N.COL_ID,
    'C',
    WS.WS.DAV_IRI (_newPath),
    N.COL_OWNER,
    N.COL_GROUP,
    N.COL_PERMS,
    _newAcls,
    _rdfParams
  );
}
;

create trigger SYS_DAV_COL_PRIVATE_GRAPH_U after update (COL_NAME, COL_OWNER, COL_GROUP, COL_PERMS, COL_ACL) on WS.WS.SYS_DAV_COL order 111 referencing old as O, new as N
{
  -- dbg_obj_print ('SYS_DAV_COL_PRIVATE_GRAPH_U ---------------');
  declare _oldPath, _newPath varchar;
  declare _oldAcls, _newAcls any;
  declare _acis, _oldRDFParams, _newRDFParams any;

  -- Pahs
  _oldPath := DB.DBA.DAV_SEARCH_PATH (N.COL_PARENT, 'C') || O.COL_NAME || '/';
  _newPath := DB.DBA.DAV_SEARCH_PATH (N.COL_ID, 'C');

  -- ACLs
  _oldAcls := vector (O.COL_ACL);
  _newAcls := vector (N.COL_ACL);
  DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (N.COL_PARENT, 'C', _oldAcls, _newAcls);


  _oldRDFParams := vector ('graph', WS.WS.DAV_IRI (_oldPath), 'graphSecurityACI', _acis);
  _newRDFParams := vector ('graph', WS.WS.DAV_IRI (_newPath), 'graphSecurityACI', _acis);
  DB.DBA.DAV_DET_GRAPH_UPDATE (
    N.COL_ID,
    O.COL_OWNER,
    N.COL_OWNER,
    O.COL_GROUP,
    N.COL_GROUP,
    O.COL_PERMS,
    N.COL_PERMS,
    _oldAcls,
    _newAcls,
    _oldRDFParams,
    _newRDFParams,
    0,
    1
  );
}
;

create trigger SYS_DAV_COL_PRIVATE_GRAPH_D after delete on WS.WS.SYS_DAV_COL order 111 referencing old as O
{
  -- dbg_obj_print ('SYS_DAV_COL_PRIVATE_GRAPH_D ---------------');
  declare _acl, _oldAcls, _newAcls any;

  -- ACLs
  _oldAcls := vector (O.COL_ACL);
  _newAcls := vector ();
  DB.DBA.DAV_DET_PRIVATE_ACL_CHAIN (O.COL_PARENT, 'C', _oldAcls, _newAcls);

  DB.DBA.DAV_DET_GRAPH_PERMISSIONS_REMOVE (
    O.COL_ID,
    'C',
    WS.WS.DAV_IRI (DB.DBA.DAV_SEARCH_PATH (O.COL_ID, 'C')),
    O.COL_OWNER,
    O.COL_GROUP,
    _oldAcls
  );
}
;

-- WS.WS.SYS_DAV_PROP
create trigger SYS_DAV_PROP_PRIVATE_GRAPH_I after insert on WS.WS.SYS_DAV_PROP order 111 referencing new as N
{
  -- dbg_obj_princ ('SYS_DAV_PROP_PRIVATE_GRAPH_I ---------------', N.PROP_TYPE, N.PROP_NAME);
  if (N.PROP_NAME = 'virt:aci_meta_n3')
  {
    DB.DBA.DAV_DET_GRAPH_UPDATE_CURRENT (N.PROP_PARENT_ID, N.PROP_TYPE, 'I');
  }
  else if ((N.PROP_TYPE = 'C') and (N.PROP_NAME = 'LDP'))
  {
    DB.DBA.DAV_DET_LDP_GRAPH_UPDATE (N.PROP_PARENT_ID);
  }
  else if ((N.PROP_TYPE = 'C') and (N.PROP_NAME like 'virt:%-rdf'))
  {
    -- Only collections
    declare _newRDFParams any;

    _newRDFParams := deserialize (N.PROP_VALUE);
    DB.DBA.DAV_DET_RDF_GRAPH_UPDATE (N.PROP_PARENT_ID, null, _newRDFParams);
  }
}
;

create trigger SYS_DAV_PROP_PRIVATE_GRAPH_U after update (PROP_VALUE) on WS.WS.SYS_DAV_PROP order 111 referencing old as O, new as N
{
  -- dbg_obj_princ ('SYS_DAV_PROP_PRIVATE_GRAPH_U ---------------', N.PROP_NAME);
  if (N.PROP_NAME = 'virt:aci_meta_n3')
  {
    DB.DBA.DAV_DET_GRAPH_UPDATE_CURRENT (N.PROP_PARENT_ID, N.PROP_TYPE, 'U');
  }
  else if ((N.PROP_TYPE = 'C') and (N.PROP_NAME = 'LDP'))
  {
    DB.DBA.DAV_DET_LDP_GRAPH_UPDATE (N.PROP_PARENT_ID);
  }
  else if ((N.PROP_TYPE = 'C') and (N.PROP_NAME like 'virt:%-rdf'))
  {
    -- Only collections
    declare _oldRDFParams, _newRDFParams any;

    _oldRDFParams := deserialize (O.PROP_VALUE);
    _newRDFParams := deserialize (N.PROP_VALUE);
    DB.DBA.DAV_DET_RDF_GRAPH_UPDATE (N.PROP_PARENT_ID, _oldRDFParams, _newRDFParams);
  }
}
;

create trigger SYS_DAV_PROP_PRIVATE_GRAPH_D before delete on WS.WS.SYS_DAV_PROP order 111 referencing old as O
{
  -- dbg_obj_princ ('SYS_DAV_PROP_PRIVATE_GRAPH_D ---------------', O.PROP_NAME);
  if (O.PROP_NAME = 'virt:aci_meta_n3')
  {
    DB.DBA.DAV_DET_GRAPH_UPDATE_CURRENT (O.PROP_PARENT_ID, O.PROP_TYPE, 'D');
  }
  else if ((O.PROP_TYPE = 'C') and (O.PROP_NAME = 'LDP'))
  {
    DB.DBA.DAV_DET_LDP_GRAPH_UPDATE (O.PROP_PARENT_ID);
  }
  else if ((O.PROP_TYPE = 'C') and (O.PROP_NAME like 'virt:%-rdf'))
  {
    -- Only collections
    declare _oldRDFParams any;

    _oldRDFParams := deserialize (O.PROP_VALUE);
    DB.DBA.DAV_DET_RDF_GRAPH_UPDATE (O.PROP_PARENT_ID, _oldRDFParams, null);
  }
}
;

create procedure DB.DBA.DAV_DET_RDF_UPDATE ()
{
  declare N integer;
  declare tmp, keys, rdf_params any;

  if (isstring (registry_get ('DAV_DET_RDF_UPDATE')))
    return;

  keys := vector ('sponger', 'off', 'cartridges', '', 'metaCartridges', '', 'graph', '', 'base', '');
  for (select COL_ID, COL_DET from WS.WS.SYS_DAV_COL where coalesce (COL_DET, '') <> '') do
  {
    if (DB.DBA.DAV_DET_IS_SPECIAL (COL_DET))
    {
      rdf_params := vector ();
      for (N := 0; N < length (keys); N := N + 2)
      {
        tmp := DB.DBA.DAV_PROP_GET_INT (COL_ID, 'C', sprintf ('virt:%s-%s', COL_DET, keys[N]), 0);
        if (DB.DBA.DAV_HIDE_ERROR (tmp) is not null)
        {
          if (tmp <> keys[N+1])
          {
            rdf_params := vector_concat (rdf_params, vector (keys[N], tmp));
          }
          DB.DBA.DAV_DET_PARAM_REMOVE (COL_DET, COL_ID, 'C', keys[N]);
        }
      }
      if (length (rdf_params))
      {
        set triggers off;
        DB.DBA.DAV_DET_RDF_PARAMS_SET_INT (COL_DET, COL_ID, rdf_params);
        set triggers on;
      }
    }
  }

  registry_set ('DAV_DET_RDF_UPDATE', 'done');
}
;

--!AFTER
DB.DBA.DAV_DET_RDF_UPDATE ()
;
