--
--  $Id: DET_Rackspace.sql,v 1.7 2012/11/02 17:57:25 ddimitrov Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

use DB
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "RACKSPACE_DAV_AUTHENTICATE" (
  in id any,
  in what char(1),
  in req varchar,
  in auth_uname varchar,
  in auth_pwd varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('RACKSPACE_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  declare retValue any;

  retValue := DAV_AUTHENTICATE (id[2], what, req, auth_uname, auth_pwd, auth_uid);

  return retValue;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "RACKSPACE_DAV_AUTHENTICATE_HTTP" (
  in id any,
  in what char(1),
  in req varchar,
  in can_write_http integer,
  inout a_lines any,
  inout a_uname varchar,
  inout a_pwd varchar,
  inout a_uid integer,
  inout a_gid integer,
  inout _perms varchar) returns integer
{
  -- dbg_obj_princ ('RACKSPACE_DAV_AUTHENTICATE_HTTP (', id[2], what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare retValue any;

  retValue := DAV_AUTHENTICATE_HTTP (id[2], what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);

  return retValue;
}
;

--| This should return ID of the collection that contains resource or collection with given ID,
--| Possible ambiguity (such as symlinks etc.) should be resolved by using path.
--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "RACKSPACE_DAV_GET_PARENT" (
  in id any,
  in what char(1),
  in path varchar) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_GET_PARENT (', id, what, path, ')');
  declare retValue any;

  retValue := DAV_GET_PARENT (id[2], what, path);
  if (DAV_HIDE_ERROR (retValue) is not null)
    retValue := vector (DB.DBA.RACKSPACE__detName (), id[1], retValue, 'C');

  return retValue;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "RACKSPACE_DAV_COL_CREATE" (
  in detcol_id any,
  in path_parts any,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in extern integer := 0) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, extern, ')');
  declare ouid, ogid integer;
  declare path, serverPath, container, listItem varchar;
  declare retValue, retHeader, header, result, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.RACKSPACE__path (detcol_id, path_parts);
  if (save is null)
  {
    serverPath := DB.DBA.RACKSPACE__serverPath (detcol_id, path_parts);
    container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);
    if (not DB.DBA.is_empty_or_null (container) or (length (path_parts) <> 2))
      header := 'Content-Length: 0\r\nContent-Type: dav/unix-directory\r\n';

    result := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'PUT', serverPath, header);
    if (DAV_HIDE_ERROR (result) is null)
    {
      retValue := result;
      goto _exit;
    }
    listItem := DB.DBA.RACKSPACE__resource (detcol_id, serverPath);
    if (DAV_HIDE_ERROR (listItem) is null)
    {
      retValue := listItem;
      goto _exit;
    }
  }
  connection_set ('dav_store', 1);
  DB.DBA.RACKSPACE__owner (detcol_id, path_parts, DB.DBA.RACKSPACE__user (uid, auth_uid), DB.DBA.RACKSPACE__user (gid, auth_uid), ouid, ogid);
  retValue := DAV_COL_CREATE_INT (path, permissions, DB.DBA.RACKSPACE__user (uid, auth_uid), DB.DBA.RACKSPACE__user (gid, auth_uid), DB.DBA.RACKSPACE__user (http_dav_uid ()), DB.DBA.RACKSPACE__password (http_dav_uid ()), 1, 0, 1, ouid, ogid);

_exit:;
  connection_set ('dav_store', save);
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    if (save is null)
      DB.DBA.RACKSPACE__paramSet (retValue, 'C', 'Entry', DB.DBA.RACKSPACE__obj2xml (listItem), 0);

    DB.DBA.RACKSPACE__paramSet (retValue, 'C', 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
    retValue := vector (DB.DBA.RACKSPACE__detName (), detcol_id, retValue, 'C');
  }

  return retValue;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "RACKSPACE_DAV_COL_MOUNT" (
  in detcol_id any,
  in path_parts any,
  in full_mount_path varchar,
  in mount_det varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "RACKSPACE_DAV_COL_MOUNT_HERE" (
  in parent_id any,
  in full_mount_path varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "RACKSPACE_DAV_DELETE" (
  in detcol_id any,
  in path_parts any,
  in what char(1),
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('RACKSPACE_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  declare container, path, serverPath varchar;
  declare retValue, save any;
  declare id, id_acl, retHeader any;
  declare detcol_parts, server_parts, listItems any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.RACKSPACE__path (detcol_id, path_parts);
  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (save is null)
  {
    if (what = 'C')
    {
      container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);
      if (DB.DBA.is_empty_or_null (container))
        container := path_parts[0];

      detcol_parts := split_and_decode (rtrim (DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C'), '/'), 0, '\0\0/');
      listItems := DB.DBA.RACKSPACE__list (detcol_id, detcol_parts, id, path_parts, '');
      foreach (any listItem in listItems) do
      {
        server_parts := split_and_decode (get_keyword ('name', listItem), 0, '\0\0/');
        serverPath := '/' || container || DB.DBA.RACKSPACE__serverPath (detcol_id, server_parts);
        retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'DELETE', serverPath);
        if (DAV_HIDE_ERROR (retValue) is null)
          goto _exit;
      }
    }
    serverPath := DB.DBA.RACKSPACE__serverPath (detcol_id, path_parts);
    retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'DELETE', serverPath);
    if (DAV_HIDE_ERROR (retValue) is null)
      goto _exit;

    id_acl := DB.DBA.DAV_SEARCH_ID (path || ',acl', 'R');
    if ((DAV_HIDE_ERROR (id_acl) is not null) and length (path_parts))
    {
      path_parts[length (path_parts) - 1] := path_parts[length (path_parts) - 1] || ',acl';
      serverPath := DB.DBA.RACKSPACE__serverPath (detcol_id, path_parts);
      DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'DELETE', serverPath);
    }
  }
  connection_set ('dav_store', 1);
  if (what = 'R')
    DB.DBA.RACKSPACE__rdf_delete (detcol_id, id, what);

  retValue := DAV_DELETE_INT (path, 1, null, null, 0, 0);

_exit:;
  connection_set ('dav_store', save);

  return retValue;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "RACKSPACE_DAV_RES_UPLOAD" (
  in detcol_id any,
  in path_parts any,
  inout content any,
  in type varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  declare ouid, ogid integer;
  declare path, serverPath, rdf_graph varchar;
  declare header any;
  declare V, retValue, retHeader, result, listItem, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.RACKSPACE__path (detcol_id, path_parts);
  if (save is null)
  {
    if (__tag (content) = 126)
    {
      declare real_content any;

      real_content := http_body_read (1);
      content := string_output_string (real_content);  -- check if bellow code can work with string session and if so remove this line
    }
    serverPath := DB.DBA.RACKSPACE__serverPath (detcol_id, path_parts);
    header := sprintf (
      'Content-Length: %d\r\n' ||
      'Content-Type: %s\r\n' ||
      'ETag: %s\r\n',
      length (content),
      type,
      md5 (content));
    result := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'PUT', serverPath, header, blob_to_string (content));
    if (DAV_HIDE_ERROR (result) is null)
    {
      retValue := result;
      goto _exit;
    }
    listItem := DB.DBA.RACKSPACE__resource (detcol_id, serverPath);
    if (DAV_HIDE_ERROR (listItem) is null)
    {
      retValue := listItem;
      goto _exit;
    }
  }
_skip_create:;
  connection_set ('dav_store', 1);
  DB.DBA.RACKSPACE__owner (detcol_id, path_parts, DB.DBA.RACKSPACE__user (uid, auth_uid), DB.DBA.RACKSPACE__user (gid, auth_uid), ouid, ogid);
  retValue := DAV_RES_UPLOAD_STRSES_INT (path, content, type, permissions, DB.DBA.RACKSPACE__user (uid, auth_uid), DB.DBA.RACKSPACE__user (gid, auth_uid), DB.DBA.RACKSPACE__user (http_dav_uid ()), DB.DBA.RACKSPACE__password (http_dav_uid ()), 0, ouid=>ouid, ogid=>ogid, check_locks=>0);

_exit:;
  connection_set ('dav_store', save);
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    rdf_graph := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'graph', 0);
    if (not DB.DBA.is_empty_or_null (rdf_graph))
      DB.DBA.RACKSPACE__rdf (detcol_id, retValue, 'R');

    if (save is null)
      DB.DBA.RACKSPACE__paramSet (retValue, 'R', 'Entry', DB.DBA.RACKSPACE__obj2xml (listItem), 0);

    DB.DBA.RACKSPACE__paramSet (retValue, 'R', 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
    retValue := vector (DB.DBA.RACKSPACE__detName (), detcol_id, retValue, 'R');
  }
  return retValue;
}
;

--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not (when an error in returned if name is system) is _not_ permitted.
--| It should delete any dead property even if the name looks like system name.
create function "RACKSPACE_DAV_PROP_REMOVE" (
  in id any,
  in what char(0),
  in propname varchar,
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('RACKSPACE_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_REMOVE_RAW (id[2], what, propname, silent, auth_uid);

  return retValue;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "RACKSPACE_DAV_PROP_SET" (
  in id any,
  in what char(0),
  in propname varchar,
  in propvalue any,
  in overwrite integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  declare retValue any;

  id := id[2];
  retValue := DB.DBA.DAV_PROP_SET_RAW (id, what, propname, propvalue, 1, http_dav_uid ());

  return retValue;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "RACKSPACE_DAV_PROP_GET" (
  in id any,
  in what char(0),
  in propname varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('RACKSPACE_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_GET_INT (id[2], what, propname, 0);

  return retValue;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "RACKSPACE_DAV_PROP_LIST" (
  in id any,
  in what char(0),
  in propmask varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('RACKSPACE_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_LIST_INT (id[2], what, propmask, 0);

  return retValue;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "RACKSPACE_DAV_DIR_SINGLE" (
  in id any,
  in what char(0),
  in path any,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  retValue := DAV_DIR_SINGLE_INT (id[2], what, null, DB.DBA.RACKSPACE__user (http_dav_uid ()), DB.DBA.RACKSPACE__password (http_dav_uid ()), http_dav_uid ());
  connection_set ('dav_store', save);
  if ((DAV_HIDE_ERROR (retValue) is not null) and (save is null))
    retValue[4] := vector (DB.DBA.RACKSPACE__detName (), id[1], retValue[4], what);

  return retValue;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "RACKSPACE_DAV_DIR_LIST" (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  in name_mask varchar,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_DIR_LIST (', detcol_id, subPath_parts, detcol_parts, name_mask, recursive, auth_uid, ')');
  declare colId integer;
  declare what, colPath varchar;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  what := case when ((length (subPath_parts) = 0) or (subPath_parts[length (subPath_parts) - 1] = '')) then 'C' else 'R' end;
  if ((what = 'R') or (recursive = -1))
    return DB.DBA.RACKSPACE_DAV_DIR_SINGLE (detcol_id, what, null, auth_uid);

  colPath := DB.DBA.DAV_CONCAT_PATH (detcol_parts, subPath_parts);
  colId := DB.DBA.DAV_SEARCH_ID (colPath, 'C');

  DB.DBA.RACKSPACE__load (detcol_id, subPath_parts, detcol_parts);
  retValue := DB.DBA.RACKSPACE__davList (detcol_id, colId);

  return retValue;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "RACKSPACE_DAV_DIR_FILTER" (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  inout compilation any,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_DIR_FILTER (', detcol_id, subPath_parts, detcol_parts, compilation, recursive, auth_uid, ')');
  return vector();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "RACKSPACE_DAV_SEARCH_ID" (
  in detcol_id any,
  in path_parts any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  retValue := DAV_SEARCH_ID (DB.DBA.RACKSPACE__path (detcol_id, path_parts), what);
  connection_set ('dav_store', save);
  if ((DAV_HIDE_ERROR (retValue) is not null))
  {
    if (isinteger (retValue) and (save is null))
      retValue := vector (DB.DBA.RACKSPACE__detName (), detcol_id, retValue, what);

    else if (isarray (retValue) and (save = 1))
      retValue := retValue[2];
  }
  return retValue;
}
;

create function "RACKSPACE_DAV_MAKE_ID" (
  in detcol_id any,
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_MAKE_ID (', id, what, ')');
  declare retValue any;

  retValue := vector (DB.DBA.RACKSPACE__detName (), detcol_id, id, what);

  return retValue;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "RACKSPACE_DAV_SEARCH_PATH" (
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_SEARCH_PATH (', id, what, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := id[2];
  retValue := DB.DBA.DAV_SEARCH_PATH (davId, what);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "RACKSPACE_DAV_RES_UPLOAD_COPY" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "RACKSPACE_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  declare oldName, newName varchar;
  declare header any;
  declare srcEntry, container, davPath, detPath, detcol_parts, sourcePath, source_parts, targetPath, sourcePath2, source_parts2, targetPath2, listItems any;
  declare retValue, retHeader, save any;

  retValue := -20;
  srcEntry := DB.DBA.DAV_DIR_SINGLE_INT (source_id, what, '', null, null, http_dav_uid ());
  if (DB.DBA.DAV_HIDE_ERROR (srcEntry) is null)
    return;

  oldName := srcEntry[10];
  newName := case when what = 'C' then path_parts[length (path_parts)-2] else path_parts[length (path_parts)-1] end;
  if (oldName <> newName)
  {
    declare exit handler for sqlstate '*'
    {
      connection_set ('dav_store', save);
      resignal;
    };

    save := connection_get ('dav_store');
    if (save is null)
    {
      container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);
      detPath := DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C');
      davPath := DB.DBA.DAV_SEARCH_PATH (source_id, what);
      sourcePath := subseq (davPath, length (detPath)-1);
      source_parts := split_and_decode (ltrim (sourcePath, '/'), 0, '\0\0/');
      if (not DB.DBA.is_empty_or_null (container))
        sourcePath := '/' || container || sourcePath;

      targetPath := DB.DBA.RACKSPACE__serverPath (detcol_id, path_parts);
      if (what = 'C')
      {
        if (DB.DBA.is_empty_or_null (container))
          container := path_parts[0];

        detcol_parts := split_and_decode (rtrim (detPath, '/'), 0, '\0\0/');
        listItems := DB.DBA.RACKSPACE__list (detcol_id, detcol_parts, source_id, source_parts, '');
        foreach (any listItem in listItems) do
        {
          source_parts2 := split_and_decode (get_keyword ('name', listItem), 0, '\0\0/');
          sourcePath2 := '/' || container || DB.DBA.RACKSPACE__serverPath (detcol_id, source_parts2);
          targetPath2 := targetPath || subseq (sourcePath2, length (sourcePath));
          retValue := DB.DBA.RACKSPACE__rename (detcol_id, sourcePath2, targetPath2);
          if (DAV_HIDE_ERROR (retValue) is null)
            goto _exit;
        }
      }
      retValue := DB.DBA.RACKSPACE__rename (detcol_id, sourcePath, targetPath);
      if (DAV_HIDE_ERROR (retValue) is null)
        goto _exit;
    }
    connection_set ('dav_store', 1);
    if (what = 'C')
    {
      update WS.WS.SYS_DAV_COL set COL_NAME = newName, COL_MOD_TIME = now () where COL_ID = source_id[2];
    } else {
      update WS.WS.SYS_DAV_RES set RES_NAME = newName, RES_MOD_TIME = now () where RES_ID = source_id[2];
    }
    retValue := source_id;

  _exit:;
    connection_set ('dav_store', save);
  }
  return retValue;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "RACKSPACE_DAV_RES_CONTENT" (
  in id any,
  inout content any,
  out type varchar,
  in content_mode integer) returns integer
{
  -- dbg_obj_princ ('RACKSPACE_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare retValue any;

  retValue := DAV_RES_CONTENT_INT (id[2], content, type, content_mode, 0);

  return retValue;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "RACKSPACE_DAV_SYMLINK" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite integer,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "RACKSPACE_DAV_DEREFERENCE_LIST" (
  in detcol_id any,
  inout report_array any) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "RACKSPACE_DAV_RESOLVE_PATH" (
  in detcol_id any,
  inout reference_item any,
  inout old_base varchar,
  inout new_base varchar) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "RACKSPACE_DAV_LOCK" (
  in path any,
  in id any,
  in what char(1),
  inout locktype varchar,
  inout scope varchar,
  in token varchar,
  inout owner_name varchar,
  inout owned_tokens varchar,
  in depth varchar,
  in timeout_sec integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_LOCK (', path, id, what, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := id[2];
  retValue := DAV_LOCK_INT (path, davId, what, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, DB.DBA.RACKSPACE__user (auth_uid), DB.DBA.RACKSPACE__password (auth_uid), auth_uid);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "RACKSPACE_DAV_UNLOCK" (
  in id any,
  in what char(1),
  in token varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('RACKSPACE_DAV_UNLOCK (', id, what, token, auth_uid, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := id[2];
  retValue := DAV_UNLOCK_INT (davId, what, token, DB.DBA.RACKSPACE__user (auth_uid), DB.DBA.RACKSPACE__password (auth_uid), auth_uid);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "RACKSPACE_DAV_IS_LOCKED" (
  inout id any,
  inout what char(1),
  in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('RACKSPACE_DAV_IS_LOCKED (', id, what, owned_tokens, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := id[2];
  retValue := DAV_IS_LOCKED_INT (davId, what, owned_tokens);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "RACKSPACE_DAV_LIST_LOCKS" (
  in id any,
  in what char(1),
  in recursive integer) returns any
{
  -- dbg_obj_princ ('RACKSPACE_DAV_LIST_LOCKS" (', id, what, recursive);
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := id[2];
  retValue := DAV_LIST_LOCKS_INT (davId, what, recursive);
  connection_set ('dav_store', save);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function "RACKSPACE_DAV_SCHEDULER" (
  in queue_id integer)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE_DAV_SCHEDULER (', queue_id, ')');
  declare detcol_parts any;

  for (select COL_ID from WS.WS.SYS_DAV_COL where COL_DET = cast (DB.DBA.RACKSPACE__detName () as varchar)) do
  {
    detcol_parts := split_and_decode (WS.WS.COL_PATH (COL_ID), 0, '\0\0/');
    DB.DBA.RACKSPACE_DAV_SCHEDULER_FOLDER (queue_id, COL_ID, detcol_parts, COL_ID, vector (''));
  }
  DB.DBA.DAV_QUEUE_UPDATE_STATE (queue_id, 2);
}
;

-------------------------------------------------------------------------------
--
create function "RACKSPACE_DAV_SCHEDULER_FOLDER" (
  in queue_id integer,
  in detcol_id integer,
  in detcol_parts any,
  in cid integer,
  in path_parts any)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE_DAV_SCHEDULER_FOLDER (', queue_id, detcol_id, detcol_parts, cid, path_parts, ')');

  DB.DBA.RACKSPACE__load (detcol_id, path_parts, detcol_parts);

  for (select COL_ID, COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = cid) do
  {
    DB.DBA.RACKSPACE_DAV_SCHEDULER_FOLDER (queue_id, detcol_id, detcol_parts, COL_ID, vector_concat (subseq (path_parts, 0, length (path_parts)-1), vector (COL_NAME, '')));
  }
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__fileDebug (
  in value any,
  in mode integer := -1)
{
  string_to_file ('rackspace.txt', cast (value as varchar) || '\r\n', mode);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__detcolId (
  in id any)
{
  if (isinteger (id))
    return id;

  return id[1];
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__davId (
  in id any)
{
  if (isinteger (id))
    return id;

  return id[2];
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__user (
  in user_id integer,
  in default_id integer := null)
{
  return coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = coalesce (user_id, default_id)), '');
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__password (
  in user_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = user_id), '');
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__owner (
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
    path := DB.DBA.RACKSPACE__path (detcol_id, subPath_parts);
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

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__detName ()
{
  return UNAME'RACKSPACE';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__xml2string (
  in _xml any)
{
  declare stream any;

  stream := string_output ();
  http_value (_xml, null, stream);
  return string_output_string (stream);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__path (
  in detcol_id any,
  in subPath_parts any)
{
  declare N integer;
  declare path varchar;

  path := rtrim (DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C'), '/');
  for (N := 0; N < length (subPath_parts); N := N + 1)
    path := path  || '/' || subPath_parts[N];

  return path;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__serverPath (
  in detcol_id any,
  in subPath_parts any)
{
  declare N integer;
  declare path, container varchar;

  path := '/' || DB.DBA.DAV_CONCAT_PATH (null, subPath_parts);
  container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);
  if (not DB.DBA.is_empty_or_null (container))
    path := '/' || container || path;

  return path;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__title (
  in path varchar)
{
  path := rtrim (path, '/');
  if (isnull (strrchr (path, '/')))
    return path;

  return subseq (path, strrchr (path, '/')+1);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__params (
  in colId integer)
{
  declare tmp, params any;

  colId := DB.DBA.RACKSPACE__detcolId (colId);
  tmp :=  DB.DBA.RACKSPACE__paramGet (colId, 'C', 'access_timestamp', 0);
  if (not isnull (tmp))
    tmp := stringdate (tmp);
  params := vector (
    'authentication',     'Yes',
    'type',             DB.DBA.RACKSPACE__paramGet (colId, 'C', 'Type', 0),
    'user',             DB.DBA.RACKSPACE__paramGet (colId, 'C', 'User', 0),
    'key',              DB.DBA.RACKSPACE__paramGet (colId, 'C', 'API_Key', 0),
    'container',        DB.DBA.RACKSPACE__paramGet (colId, 'C', 'Container', 0),
    'graph',            DB.DBA.RACKSPACE__paramGet (colId, 'C', 'graph', 0),
    'storageUrl',       DB.DBA.RACKSPACE__paramGet (colId, 'C', 'storageUrl', 0),
    'managementUrl',    DB.DBA.RACKSPACE__paramGet (colId, 'C', 'managementUrl', 0),
    'access_token',     DB.DBA.RACKSPACE__paramGet (colId, 'C', 'access_token', 0),
    'access_timestamp', tmp
  );
  return params;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__paramSet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _propValue any,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _encrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__paramSet', _propName, _propValue, ')');
  declare retValue any;

  if (_serialized)
    _propValue := serialize (_propValue);

  if (_encrypt)
    _propValue := pwd_magic_calc ('rackspace', _propValue);

  if (_prefixed)
    _propName := 'virt:RACKSPACE-' || _propName;

  _id := DB.DBA.RACKSPACE__davId (_id);
  retValue := DB.DBA.DAV_PROP_SET_RAW (_id, _what, _propName, _propValue, 1, http_dav_uid ());

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__paramGet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _decrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__paramGet (', _id, _what, _propName, ')');
  declare propValue any;

  if (_prefixed)
    _propName := 'virt:RACKSPACE-' || _propName;

  propValue := DB.DBA.DAV_PROP_GET_INT (DB.DBA.RACKSPACE__davId (_id), _what, _propName, 0, DB.DBA.RACKSPACE__user (http_dav_uid ()), DB.DBA.RACKSPACE__password (http_dav_uid ()), http_dav_uid ());
  if (isinteger (propValue))
    propValue := null;

  if (_serialized and not isnull (propValue))
    propValue := deserialize (propValue);

  if (_decrypt and not isnull (propValue))
    propValue := pwd_magic_calc ('rackspace', propValue, 1);

  return propValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__paramRemove (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _prefixed integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__paramRemove (', _id, _what, _propName, ')');
  if (_prefixed)
    _propName := 'virt:RACKSPACE-' || _propName;

  DB.DBA.DAV_PROP_REMOVE_RAW (DB.DBA.RACKSPACE__davId (_id), _what, _propName, 1, http_dav_uid());
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__obj2xml (
  in item any)
{
  return '<entry>' || ODS..obj2xml (item, 10) || '</entry>';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__entryXPath (
  in _xml any,
  in _xpath varchar,
  in _cast integer := 0)
{
  declare retValue any;

  if (_cast)
  {
    retValue := serialize_to_UTF8_xml (xpath_eval (sprintf ('[ xmlns="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] string (//entry%s)', _xpath), _xml, 1));
  } else {
    retValue := xpath_eval ('[ xmlns="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] //entry' || _xpath, _xml, 1);
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__propertyXPath (
  in _xml any,
  in _xpath varchar,
  in _cast integer := 0)
{
  declare retValue any;

  if (_cast)
  {
    retValue := serialize_to_UTF8_xml (xpath_eval (sprintf ('[__enc "UTF-8" xmlns:D="DAV:"] string (//D:response/D:propstat[D:status = "HTTP/1.1 200 OK"]/D:prop/%s)', _xpath), _xml, 1));
  } else {
    retValue := xpath_eval ('[__enc "UTF-8" xmlns:D="DAV:"] //D:response/D:propstat[D:status = "HTTP/1.1 200 OK"]/D:prop' || _xpath, _xml, 1);
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__exec_error (
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

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__exec_code (
  in _header any)
{
  return subseq (_header[0], 9, 12);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__exec (
  inout detcol_id integer,
  inout retHeader varchar,
  in method varchar,
  in path varchar := '',
  in header varchar := '',
  in content varchar := '')
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__exec', detcol_id, method, path, header, ')');
  declare retValue, params any;
  declare _expires_in, _refreshed integer;
  declare _type, _url varchar;
  declare _access_timestamp datetime;
  declare _reqHeader, _resHeader any;
  declare exit handler for sqlstate '*'
  {
    DB.DBA.RACKSPACE__activity (detcol_id, 'Exec error: ' || __SQL_MESSAGE);
    return -28;
  };

  params := DB.DBA.RACKSPACE__params (detcol_id);
  if (get_keyword ('authentication', params) <> 'Yes')
  {
    DB.DBA.RACKSPACE__activity (detcol_id, 'Error: Not authenticated');
    return -28;
  }

  _type := get_keyword ('type', params);
  _expires_in := 24 * 3600;
  _refreshed := 0;
  _access_timestamp := get_keyword ('access_timestamp', params);
  if (isnull (_access_timestamp) or (dateadd ('second', _expires_in, _access_timestamp) < now ()))
  {
  _refresh:
    -- refresh token first

    _url := case when (_type = 'USA') then 'https://auth.api.rackspacecloud.com/v1.0' else 'https://lon.auth.api.rackspacecloud.com/v1.0' end;
    _reqHeader := sprintf (
      'X-Auth-User: %s\r\n' ||
      'X-Auth-Key: %s\r\n',
      get_keyword ('user', params),
      get_keyword ('key', params)
    );
    _resHeader := null;
    http_client_ext (url=>_url, http_method=>'GET', http_headers=>_reqHeader, headers =>_resHeader, n_redirects=>15);
    if (not DB.DBA.RACKSPACE__exec_error (_resHeader, 1))
      return -28;

    _refreshed := 1;
    DB.DBA.RACKSPACE__paramSet (detcol_id, 'C', 'storageUrl', http_request_header (_resHeader, 'X-Storage-Url', null, null), 0);
    DB.DBA.RACKSPACE__paramSet (detcol_id, 'C', 'managementUrl', http_request_header (_resHeader, 'X-CDN-Management-Url', null, null), 0);
    DB.DBA.RACKSPACE__paramSet (detcol_id, 'C', 'access_token', http_request_header (_resHeader, 'X-Auth-Token', null, null), 0);
    DB.DBA.RACKSPACE__paramSet (detcol_id, 'C', 'access_timestamp', datestring (now ()), 0);
    params := DB.DBA.RACKSPACE__params (detcol_id);
  }

  _reqHeader := sprintf ('X-Auth-Token: %s\r\n', get_keyword ('access_token', params));
  if (header <> '')
    _reqHeader :=  _reqHeader || header;

  _url := get_keyword ('storageUrl', params) || path;
  retHeader := null;
  retValue := http_client_ext (url=>_url, http_method=>method, http_headers=>_reqHeader, headers =>retHeader, body=>content, n_redirects=>15);
  -- dbg_obj_print ('retHeader', retHeader);
  if ((DB.DBA.RACKSPACE__exec_code (retHeader) = '401') and (_refreshed = 0))
    goto _refresh;

  if (not DB.DBA.RACKSPACE__exec_error (retHeader, 1))
  {
    DB.DBA.RACKSPACE__activity (detcol_id, 'HTTP error: ' || retValue);
    return -28;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__davList (
  inout detcol_id integer,
  inout colId integer)
{
  declare retValue any;

  vectorbld_init (retValue);
  for (select vector (RES_FULL_PATH,
                      'R',
                      length (RES_CONTENT),
                      RES_MOD_TIME,
                      vector (DB.DBA.RACKSPACE__detName (), detcol_id, RES_ID, 'R'),
                      RES_PERMS,
                      RES_GROUP,
                      RES_OWNER,
                      RES_CR_TIME,
                      RES_TYPE,
                      RES_NAME ) as I
         from WS.WS.SYS_DAV_RES
        where RES_COL = DB.DBA.RACKSPACE__davId (colId)) do
  {
    vectorbld_acc (retValue, i);
  }

  for (select vector (WS.WS.COL_PATH (COL_ID),
                      'C',
                      0,
                      COL_MOD_TIME,
                      vector (DB.DBA.RACKSPACE__detName (), detcol_id, COL_ID, 'C'),
                      COL_PERMS,
                      COL_GROUP,
                      COL_OWNER,
                      COL_CR_TIME,
                      'dav/unix-directory',
                      COL_NAME) as I
        from WS.WS.SYS_DAV_COL
       where COL_PARENT = DB.DBA.RACKSPACE__davId (colId)) do
  {
    vectorbld_acc (retValue, i);
  }

  vectorbld_final (retValue);
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__load (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar) returns any
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__load (', detcol_id, subPath_parts, detcol_parts, ')');
  declare colId integer;
  declare what, colPath, colHref, modified varchar;
  declare retValue, save, downloads, listIDs, listID, listItems, davItems, colEntry, davEntry any;
  declare syncTime datetime;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  downloads := vector ();

  colPath := DB.DBA.DAV_CONCAT_PATH (detcol_parts, subPath_parts);
  colId := DB.DBA.DAV_SEARCH_ID (colPath, 'C');
  if (DAV_HIDE_ERROR (colId) is null)
    goto _exit;

  syncTime := DB.DBA.RACKSPACE__paramGet (colId, 'C', 'syncTime');
  if (not isnull (syncTime) and (datediff ('second', syncTime, now ()) < 300))
    goto _exit;

  listItems := DB.DBA.RACKSPACE__list (detcol_id, detcol_parts, colId, subPath_parts);
  if (DAV_HIDE_ERROR (listItems) is null)
    goto _exit;

  if (isinteger (listItems))
    goto _exit;

  DB.DBA.RACKSPACE__activity (detcol_id, 'Sync started');
  {
    declare _id, _what, _type, _content any;
    declare title varchar;
    {
      declare exit handler for sqlstate '*'
      {
        DB.DBA.RACKSPACE__activity (detcol_id, 'Exec error: ' || __SQL_MESSAGE);
        goto _exitSync;
      };

      connection_set ('dav_store', 1);
      colEntry := DB.DBA.DAV_DIR_SINGLE_INT (colId, 'C', '', null, null, http_dav_uid ());

      listIds := vector ();
      davItems := DB.DBA.RACKSPACE__davList (detcol_id, colId);
      foreach (any davItem in davItems) do
      {
        connection_set ('dav_store', 1);
        davEntry := DB.DBA.RACKSPACE__paramGet (davItem[4], davItem[1], 'Entry', 0);
        if (davEntry is not null)
        {
          davEntry := xtree_doc (davEntry);
          foreach (any listItem in listItems) do
          {
            listID := get_keyword ('name', listItem);
            if (isnull (listID))
            {
              listID := get_keyword ('subdir', listItem);
              listItem := vector_concat (ODS..jsonObject (), vector ('name', listID));
            }
            if (DB.DBA.RACKSPACE__entryXPath (davEntry, '/name', 1) = listID)
            {
              listIds := vector_concat (listIds, vector (listID));
              if (DB.DBA.RACKSPACE__entryXPath (davEntry, '/hash', 1) <> get_keyword ('hash', listItem))
              {
                modified := get_keyword ('last_modified', listItem, datestring (now ()));
                set triggers off;
                DB.DBA.RACKSPACE__paramSet (davItem[4], davItem[1], ':getlastmodified', stringdate (modified), 0, 0);
                set triggers on;
                DB.DBA.RACKSPACE__paramSet (davItem[4], davItem[1], 'Entry', DB.DBA.RACKSPACE__obj2xml (listItem), 0);
                if (davItem[1] = 'R')
                {
                  DB.DBA.RACKSPACE__paramSet (davItem[4], davItem[1], 'download', '0', 0);
                  downloads := vector_concat (downloads, vector (vector (davItem[4], davItem[1])));
                }
              }
              else if (davItem[1] = 'R')
              {
                declare downloaded integer;

                downloaded := DB.DBA.RACKSPACE__paramGet (davItem[4], davItem[1], 'download', 0);
                if (downloaded is not null)
                {
                  downloaded := cast (downloaded as integer);
                  if (downloaded <= 5)
                    downloads := vector_concat (downloads, vector (vector (davItem[4], davItem[1])));
                }
              }
              goto _continue;
            }
          }
        }
        if (davItem[1] = 'R')
          DB.DBA.RACKSPACE__rdf_delete (detcol_id, davItem[4], davItem[1]);

        connection_set ('dav_store', 1);
        DAV_DELETE_INT (davItem[0], 1, null, null, 0, 0);

      _continue:;
        commit work;
      }
      foreach (any listItem in listItems) do
      {
        connection_set ('dav_store', 1);
        listID := get_keyword ('name', listItem);
        if (isnull (listID))
          listID := get_keyword ('subdir', listItem);
        if (not position (listID, listIDs))
        {
          title := DB.DBA.RACKSPACE__title (listID);
          connection_set ('dav_store', 1);
          if ((listID[length (listID)-1] = ascii('/')) or not isnull (get_keyword ('count', listItem)))
          {
            _id := DB.DBA.DAV_COL_CREATE (colPath || title || '/',  colEntry[5], colEntry[7], colEntry[6], DB.DBA.RACKSPACE__user (http_dav_uid ()), DB.DBA.RACKSPACE__password (http_dav_uid ()));
            _what := 'C';
          }
          else
          {
            _content := '';
            _type := get_keyword ('content_type', listItem);
            if (isnull (_type))
              _type := http_mime_type (title);
            _id := DB.DBA.DAV_RES_UPLOAD (colPath || title,  _content, _type, colEntry[5], colEntry[7], colEntry[6], DB.DBA.RACKSPACE__user (http_dav_uid ()), DB.DBA.RACKSPACE__password (http_dav_uid ()));
            _what := 'R';
          }
          if (DAV_HIDE_ERROR (_id) is not null)
          {
            set triggers off;
            DB.DBA.RACKSPACE__paramSet (_id, _what, ':creationdate', get_keyword ('last_modified', listItem, now ()), 0, 0);
            DB.DBA.RACKSPACE__paramSet (_id, _what, ':getlastmodified', get_keyword ('last_modified', listItem, now ()), 0, 0);
            set triggers on;
            DB.DBA.RACKSPACE__paramSet (_id, _what, 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
            DB.DBA.RACKSPACE__paramSet (_id, _what, 'Entry', DB.DBA.RACKSPACE__obj2xml (listItem), 0);
            if (_what = 'R')
            {
              DB.DBA.RACKSPACE__paramSet (_id, _what, 'download', '0', 0);
              downloads := vector_concat (downloads, vector (vector (_id, _what)));
            }
          }
          commit work;
        }
      }
    }
  _exitSync:
    connection_set ('dav_store', save);
  }
  DB.DBA.RACKSPACE__activity (detcol_id, 'Sync ended');

_exit:;
  DB.DBA.RACKSPACE__downloads (detcol_id, downloads);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__list (
  inout detcol_id any,
  inout detcol_parts varchar,
  inout col_id any,
  inout subPath_parts varchar,
  in delimiter varchar := '/')
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__list (', detcol_id, detcol_parts, col_id, subPath_parts, ')');
  declare path, prefix, header varchar;
  declare listID, listItems any;
  declare container, V, retValue, retHeader any;

  container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);
  path := '';
  V := vector ();
  if (not DB.DBA.is_empty_or_null (container))
  {
    path := '/' || container;
    if (length (subPath_parts) > 1)
      V := subPath_parts;
  }
  else if (length (subPath_parts) > 1)
  {
    path := '/' || subPath_parts[0];
    V := subseq (subPath_parts, 1);
  }
  prefix := '';
  path := path || '?format=json';
  if (delimiter <> '')
    path := path || '&delimiter=' || delimiter;
  if (length (V))
  {
    prefix := ltrim (DB.DBA.DAV_CONCAT_PATH (null, V), '/');
    path := path || sprintf ('&prefix=%s', prefix);
  }

  retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'GET', path);
  if (not isinteger (retValue))
  {
    if (delimiter = '/')
      DB.DBA.RACKSPACE__paramSet (col_id, 'C', 'syncTime', now ());

    listItems := ODS..json2obj (retValue);
    if (prefix <> '')
    {
      retValue := vector ();
      foreach (any listItem in listItems) do
      {
        connection_set ('dav_store', 1);
        listID := get_keyword ('name', listItem);
        if (isnull (listID))
          listID := get_keyword ('subdir', listItem);

        if (listID <> prefix)
          retValue := vector_concat (retValue, vector (listItem));
      }
    }
    else
    {
      retValue := listItems;
    }
  }
  -- dbg_obj_print ('retValue', retValue);
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__resource (
  inout detcol_id any,
  inout path any)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__resource (', detcol_id, path, ')');
  declare tmp, retValue, retHeader any;

  retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'HEAD', path);
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    tmp := ltrim (path, '/');
    if (not isnull (strchr (tmp, '/')))
       tmp := subseq (tmp, strchr (tmp, '/')+1);

    retValue := vector_concat (
      ODS..jsonObject (),
      vector
      (
        'name', tmp,
        'hash', http_request_header (retHeader, 'ETag'),
        'size', cast (http_request_header (retHeader, 'Content-Length') as integer),
        'content_type', http_request_header (retHeader, 'Content-Type'),
        'last_modified', http_string_date (coalesce (http_request_header (retHeader, 'Last-Modified', null, null), http_request_header (retHeader, 'Date', null, null)))
      )
    );
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__rename (
  in detcol_id any,
  in sourcePath varchar,
  in targetPath varchar)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__rename (', detcol_id, sourcePath, targetPath, ')');
  declare source_id any;
  declare container, detcolPath, what varchar;
  declare header any;
  declare retValue, retHeader, source_parts any;

  header := sprintf ('Destination: %s\r\n', targetPath);
  retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'COPY', sourcePath, header);
  if (DAV_HIDE_ERROR (retValue) is null)
    goto _exit;

  retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'DELETE', sourcePath);
  if (DAV_HIDE_ERROR (retValue) is null)
    goto _exit;

  detcolPath := DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C');
  container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);
  sourcePath := ltrim (sourcePath, '/');
  if (not DB.DBA.is_empty_or_null (container))
    sourcePath := subseq (sourcePath, length (container)+1);

  sourcePath := detcolPath || sourcePath;
  what := case when (sourcePath[length (sourcePath)-1] <> ascii('/')) then 'R' else 'C' end;
  source_id := DB.DBA.DAV_SEARCH_ID (sourcePath, what);
  if (DAV_HIDE_ERROR (source_id) is not null)
  {
    retValue := DB.DBA.RACKSPACE__resource (detcol_id, targetPath);
    if (DAV_HIDE_ERROR (retValue) is null)
      goto _exit;

    DB.DBA.RACKSPACE__paramSet (source_id, what, 'Entry', DB.DBA.RACKSPACE__obj2xml (retValue), 0);
  }

_exit:;
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__activity (
  in detcol_id integer,
  in text varchar)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__activity (', detcol_id, text, ')');
  declare parentId integer;
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
  activity := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'activity', 0);
  if (activity is null)
    return;

  if (activity <> 'on')
    return;

  davEntry := DB.DBA.DAV_DIR_SINGLE_INT (detcol_id, 'C', '', null, null, http_dav_uid ());
  if (DB.DBA.DAV_HIDE_ERROR (davEntry) is null)
    return;

  parentId := DB.DBA.DAV_SEARCH_ID (davEntry[0], 'P');
  if (DB.DBA.DAV_HIDE_ERROR (parentId) is null)
    return;

  parentPath := DB.DBA.DAV_SEARCH_PATH (parentId, 'C');
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
  }
  activityContent := activityContent || sprintf ('%s %s\r\n', subseq (datestring (now ()), 0, 19), text);
  activityType := 'text/plain';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (activityPath, activityContent, activityType, '110100000RR', DB.DBA.RACKSPACE__user (davEntry[6]), DB.DBA.RACKSPACE__user (davEntry[7]), extern=>0, check_locks=>0);
  commit work;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__downloads (
  in detcol_id integer,
  in downloads any)
{
  declare aq any;

  if (length (downloads) = 0)
    return;

  set_user_id ('dba');
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.RACKSPACE__downloads_aq', vector (detcol_id, downloads));
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__downloads_aq (
  in detcol_id integer,
  in downloads any)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__downloads_aq (', detcol_id, downloads, ')');
  declare N, downloaded integer;
  declare path, container, davPath, detPath varchar;
  declare items any;
  declare retValue, retHeader any;

  set_user_id ('dba');

  detPath := WS.WS.COL_PATH (detcol_id);
  container := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'Container', 0);

  N := 0;
  items := vector ();
  DB.DBA.RACKSPACE__activity (detcol_id, sprintf ('Downloading %d file(s)', length (downloads)));
  foreach (any download in downloads) do
  {
    downloaded := DB.DBA.RACKSPACE__paramGet (download[0], download[1], 'download', 0);
    if (downloaded is null)
      goto _continue;

    downloaded := cast (downloaded as integer);
    if (downloaded > 5)
      goto _continue;

    davPath := DB.DBA.DAV_SEARCH_PATH (download[0], download[1]);
    path := subseq (davpath, length (detPath)-1);
    if (not DB.DBA.is_empty_or_null (container))
      path := '/' || container || path;

    retValue := DB.DBA.RACKSPACE__exec (detcol_id, retHeader, 'GET', path);
    if (DAV_HIDE_ERROR (retValue) is null)
    {
      downloaded := downloaded + 1;
      DB.DBA.RACKSPACE__paramSet (download[0], download[1], 'download', cast (downloaded as varchar), 0);
    }
    else
    {
      update WS.WS.SYS_DAV_RES set RES_CONTENT = retValue where RES_ID = DB.DBA.RACKSPACE__davId (download[0]);
      DB.DBA.RACKSPACE__paramRemove (download[0], download[1], 'download');
      items := vector_concat (items, vector (download));
      N := N + 1;
    }
    commit work;

  _continue:;
  }
  DB.DBA.RACKSPACE__activity (detcol_id, sprintf ('Downloaded %d file(s)', N));
  foreach (any item in items) do
  {
    DB.DBA.RACKSPACE__rdf_delete (detcol_id, item[0], item[1]);
    DB.DBA.RACKSPACE__rdf_insert (detcol_id, item[0], item[1]);
  }
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__rdf (
  in detcol_id integer,
  in id any,
  in what varchar)
{
  declare aq any;

  set_user_id ('dba');
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.RACKSPACE__rdf_aq', vector (detcol_id, id, what));
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__rdf_aq (
  in detcol_id integer,
  in id any,
  in what varchar)
{
  set_user_id ('dba');
  DB.DBA.RACKSPACE__rdf_delete (detcol_id, id, what);
  DB.DBA.RACKSPACE__rdf_insert (detcol_id, id, what);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__rdf_insert (
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_graph varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__rdf_insert (', detcol_id, id, what, rdf_graph, ')');
  declare permissions, rdf_graph2 varchar;
  declare rdf_sponger, rdf_cartridges, rdf_metaCartridges any;
  declare path, content, type any;
  declare exit handler for sqlstate '*'
  {
    return;
  };

  if (isnull (rdf_graph))
    rdf_graph := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'graph', 0);

  if (DB.DBA.is_empty_or_null (rdf_graph))
    return;

  permissions := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', ':virtpermissions', 0, 0);
  if (permissions[6] = ascii('0'))
  {
    -- add to private graphs
    if (not SIOC..private_graph_check (rdf_graph))
      return;
  }

  id := DB.DBA.RACKSPACE__davId (id);
  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  content := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = id);
  type := (select RES_TYPE from WS.WS.SYS_DAV_RES where RES_ID = id);
  rdf_sponger := coalesce (DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'sponger', 0), 'on');
  rdf_cartridges := coalesce (DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'cartridges', 0), '');
  rdf_metaCartridges := coalesce (DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'metaCartridges', 0), '');

  RDF_SINK_UPLOAD (path, content, type, rdf_graph, rdf_sponger, rdf_cartridges, rdf_metaCartridges);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__rdf_delete (
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_graph varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__rdf_delete (', detcol_id, id, what, rdf_graph, ')');
  declare rdf_graph2 varchar;
  declare path varchar;

  if (isnull (rdf_graph))
    rdf_graph := DB.DBA.RACKSPACE__paramGet (detcol_id, 'C', 'graph', 0);

  if (DB.DBA.is_empty_or_null (rdf_graph))
    return;

  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  DB.DBA.RDF_SINK_CLEAR (path, rdf_graph);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.RACKSPACE__refresh (
  in path varchar)
{
  -- dbg_obj_princ ('DB.DBA.RACKSPACE__refresh (', path, ')');
  declare colId any;

  colId := DB.DBA.DAV_SEARCH_ID (path, 'C');
  if (DAV_HIDE_ERROR (colId) is not null)
    DB.DBA.RACKSPACE__paramRemove (colId, 'C', 'syncTime');
}
;
