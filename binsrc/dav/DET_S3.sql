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
-- API link: http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html
--

use DB
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "S3_DAV_AUTHENTICATE" (
  in id any,
  in what char(1),
  in req varchar,
  in auth_uname varchar,
  in auth_pwd varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  declare retValue any;

  retValue := DAV_AUTHENTICATE (DB.DBA.DAV_DET_DAV_ID (id), what, req, auth_uname, auth_pwd, auth_uid);

  return retValue;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "S3_DAV_AUTHENTICATE_HTTP" (
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
  -- dbg_obj_princ ('S3_DAV_AUTHENTICATE_HTTP (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare retValue any;

  retValue := DAV_AUTHENTICATE_HTTP (DB.DBA.DAV_DET_DAV_ID (id), what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);

  return retValue;
}
;

--| This should return ID of the collection that contains resource or collection with given ID,
--| Possible ambiguity (such as symlinks etc.) should be resolved by using path.
--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "S3_DAV_GET_PARENT" (
  in id any,
  in what char(1),
  in path varchar) returns any
{
  -- dbg_obj_princ ('S3_DAV_GET_PARENT (', id, what, path, ')');
  declare retValue any;

  retValue := DAV_GET_PARENT (DB.DBA.DAV_DET_DAV_ID (id), what, path);
  if (DAV_HIDE_ERROR (retValue) is not null)
    retValue := vector (DB.DBA.S3__detName (), DB.DBA.DAV_DET_DETCOL_ID (id), retValue, 'C');

  return retValue;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "S3_DAV_COL_CREATE" (
  in detcol_id any,
  in path_parts any,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in extern integer := 0) returns any
{
  -- dbg_obj_princ ('S3_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, extern, ')');
  declare ouid, ogid integer;
  declare title, parentListID, listID, listItem varchar;
  declare url, body, header any;
  declare retValue, retHeader, result, save, parentID any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  if (save is null)
  {
    result := DB.DBA.S3__putObject (detcol_id, path_parts, 'C');
    if (DAV_HIDE_ERROR (result) is null)
    {
      retValue := result;
      goto _exit;
    }
    listItem := result;
    listID := get_keyword ('path', listItem);
  }
  connection_set ('dav_store', 1);
  DB.DBA.DAV_DET_OWNER (detcol_id, path_parts, DB.DBA.DAV_DET_USER (coalesce (uid, auth_uid)), DB.DBA.DAV_DET_USER (coalesce (gid, auth_uid)), ouid, ogid);
  retValue := DAV_COL_CREATE_INT (DB.DBA.DAV_DET_PATH (detcol_id, path_parts), permissions, DB.DBA.DAV_DET_USER (coalesce (uid, auth_uid)), DB.DBA.DAV_DET_USER (coalesce (gid, auth_uid)), DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()), 1, 0, 1, ouid, ogid);

_exit:;
  connection_set ('dav_store', save);
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    commit work;
    if (save is null)
    {
      DB.DBA.S3__paramSet (retValue, 'C', 'Entry', DB.DBA.S3__obj2xml (listItem), 0);
      DB.DBA.S3__paramSet (retValue, 'C', 'path', listID, 0);
    }
    DB.DBA.S3__paramSet (retValue, 'C', 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
    retValue := vector (DB.DBA.S3__detName (), detcol_id, retValue, 'C');
  }

  return retValue;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "S3_DAV_COL_MOUNT" (
  in detcol_id any,
  in path_parts any,
  in full_mount_path varchar,
  in mount_det varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "S3_DAV_COL_MOUNT_HERE" (
  in parent_id any,
  in full_mount_path varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "S3_DAV_DELETE" (
  in detcol_id any,
  in path_parts any,
  in what char(1),
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('S3_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  declare path varchar;
  declare retValue, id, id_acl, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.DAV_DET_PATH (detcol_id, path_parts);
  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (save is null)
  {
    retValue := DB.DBA.S3__deleteObject (detcol_id, id, what);
    if (DAV_HIDE_ERROR (retValue) is null)
      goto _exit;

    id_acl := DB.DBA.DAV_SEARCH_ID (path || ',acl', 'R');
    if (DAV_HIDE_ERROR (id_acl) is not null)
      DB.DBA.S3__deleteObject (detcol_id, id_acl, 'R');
  }
  DB.DBA.DAV_DET_RDF_DELETE (DB.DBA.S3__detName (), detcol_id, id, what);
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
create function "S3_DAV_RES_UPLOAD" (
  in detcol_id any,
  in path_parts any,
  inout content any,
  in type varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  declare ouid, ogid integer;
  declare name, path, oPath varchar;
  declare oldID, oldContent any;
  declare retValue, result, save, oEntry any;
  declare exit handler for sqlstate '*'
  {
    DB.DBA.DAV_DET_CONTENT_ROLLBACK (oldID, oldContent, path);
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.DAV_DET_PATH (detcol_id, path_parts);
  oldID := DB.DBA.DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (oldID) is not null)
    oldContent := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path);

  -- store in local DAV first
  connection_set ('dav_store', 1);
  DB.DBA.DAV_DET_OWNER (detcol_id, path_parts, DB.DBA.DAV_DET_USER (uid, auth_uid), DB.DBA.DAV_DET_USER (gid, auth_uid), ouid, ogid);
  retValue := DAV_RES_UPLOAD_STRSES_INT (path, content, type, permissions, DB.DBA.DAV_DET_USER (uid, auth_uid), DB.DBA.DAV_DET_USER (gid, auth_uid), DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()), 0, ouid=>ouid, ogid=>ogid, check_locks=>0);

  -- store next
  if ((DAV_HIDE_ERROR (retValue) is not null) and (save is null))
  {
    result := DB.DBA.S3__put (detcol_id, retValue);
    if (DAV_HIDE_ERROR (result) is null)
      retValue := result;
  }

  if (DAV_HIDE_ERROR (retValue) is null)
  {
    DB.DBA.DAV_DET_CONTENT_ROLLBACK (oldID, oldContent, path);
  }
  else
  {
    commit work;

    -- RDF Data
    DB.DBA.DAV_DET_RDF (DB.DBA.S3__detName (), detcol_id, retValue, 'R');

    DB.DBA.S3__paramSet (retValue, 'R', 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
    retValue := vector (DB.DBA.S3__detName (), detcol_id, retValue, 'R');
  }
  connection_set ('dav_store', save);
  return retValue;
}
;

--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not (when an error in returned if name is system) is _not_ permitted.
--| It should delete any dead property even if the name looks like system name.
create function "S3_DAV_PROP_REMOVE" (
  in id any,
  in what char(0),
  in propname varchar,
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('S3_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  declare retValue, md5Value any;

  if ((what = 'R') and (propName in ('virt:server-side-encryption', 'virt:server-side-encryption-password')))
    md5Value := DB.DBA.DAV_DET_CONTENT_MD5 (id);

  retValue := DAV_PROP_REMOVE_RAW (id[2], what, propname, silent, auth_uid);
  if (
      (what = 'R') and
      (DAV_HIDE_ERROR (retValue) is not null) and
      (propName in ('virt:server-side-encryption', 'virt:server-side-encryption-password')) and
      (md5Value <> DB.DBA.DAV_DET_CONTENT_MD5 (id))
     )
  {
    DB.DBA.S3__put (DB.DBA.DAV_DET_DETCOL_ID (id), id);
  }

  return retValue;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "S3_DAV_PROP_SET" (
  in id any,
  in what char(0),
  in propname varchar,
  in propvalue any,
  in overwrite integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  declare retValue, md5Value, tmp any;

  if ((propName = 'virt:s3-server-side-encryption') and (what = 'R'))
  {
    declare path, det_path, path_parts, item any;

    tmp := DB.DBA.S3_DAV_PROP_GET (id, what, propname, auth_uid);
    if (tmp <> propvalue)
    {
      connection_set ('s3-server-side-encryption', propvalue);
      det_path := DB.DBA.DAV_SEARCH_PATH (DB.DBA.DAV_DET_DETCOL_ID (id), 'C');
      path := DB.DBA.DAV_SEARCH_PATH (id, what);
      path_parts := split_and_decode (replace (path, det_path, ''), 0, '\0\0/');
      item := DB.DBA.S3__copyObject (DB.DBA.DAV_DET_DETCOL_ID (id), path_parts, id, what);
      if (DAV_HIDE_ERROR (item) is not null)
        DB.DBA.S3__paramSet (id, what, 'Entry', DB.DBA.S3__obj2xml (item), 0);
    }
  }

  if ((what = 'R') and (propName in ('virt:server-side-encryption', 'virt:server-side-encryption-password')))
    md5Value := DB.DBA.DAV_DET_CONTENT_MD5 (id);

  tmp := id[2];
  retValue := DB.DBA.DAV_PROP_SET_RAW (tmp, what, propname, propvalue, 1, http_dav_uid ());
  if (
      (what = 'R') and
      (DAV_HIDE_ERROR (retValue) is not null) and
      (propName in ('virt:server-side-encryption', 'virt:server-side-encryption-password')) and
      (md5Value <> DB.DBA.DAV_DET_CONTENT_MD5 (id))
     )
  {
    DB.DBA.S3__put (DB.DBA.DAV_DET_DETCOL_ID (id), id);
  }
  return retValue;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "S3_DAV_PROP_GET" (
  in id any,
  in what char(0),
  in propname varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  declare retValue any;

  if ((propName = 'virt:s3-server-side-encryption') and (what = 'R'))
  {
    declare oEntry any;

    retValue := null;
    oEntry := DB.DBA.S3__paramGet (id, what, 'Entry', 0);
    if (oEntry is not null)
    {
      oEntry := xtree_doc (oEntry);
      retValue := DB.DBA.DAV_DET_ENTRY_XPATH (oEntry, '/amz-server-side-encryption', 1);
    }
    if (is_empty_or_null (retValue))
      retValue := 'None';
  }
  else
  {
    retValue := DAV_PROP_GET_INT (DB.DBA.DAV_DET_DAV_ID (id), what, propname, 0);
  }
  return retValue;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "S3_DAV_PROP_LIST" (
  in id any,
  in what char(0),
  in propmask varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_LIST_INT (DB.DBA.DAV_DET_DAV_ID (id), what, propmask, 0);

  return retValue;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "S3_DAV_DIR_SINGLE" (
  in id any,
  in what char(0),
  in path any,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  retValue := DAV_DIR_SINGLE_INT (DB.DBA.DAV_DET_DAV_ID (id), what, null, DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()), http_dav_uid ());
  connection_set ('dav_store', save);
  if ((DAV_HIDE_ERROR (retValue) is not null) and (save is null))
    retValue[4] := vector (DB.DBA.S3__detName (), DB.DBA.DAV_DET_DETCOL_ID (id), retValue[4], what);

  return retValue;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "S3_DAV_DIR_LIST" (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  in name_mask varchar,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_DIR_LIST (', detcol_id, subPath_parts, detcol_parts, name_mask, recursive, auth_uid, ')');
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
    return DB.DBA.S3_DAV_DIR_SINGLE (detcol_id, what, null, auth_uid);

  colPath := DB.DBA.DAV_CONCAT_PATH (detcol_parts, subPath_parts);
  colId := DB.DBA.DAV_SEARCH_ID (colPath, 'C');

  DB.DBA.S3__load (detcol_id, subPath_parts, detcol_parts);
  retValue := DB.DBA.DAV_DET_DAV_LIST (DB.DBA.S3__detName (), detcol_id, colId);

  return retValue;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "S3_DAV_DIR_FILTER" (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  inout compilation any,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_DIR_FILTER (', detcol_id, subPath_parts, detcol_parts, compilation, recursive, auth_uid, ')');
  return vector();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "S3_DAV_SEARCH_ID" (
  in detcol_id any,
  in path_parts any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('S3_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  retValue := DAV_SEARCH_ID (DB.DBA.DAV_DET_PATH (detcol_id, path_parts), what);
  connection_set ('dav_store', save);
  if ((DAV_HIDE_ERROR (retValue) is not null))
  {
    if (isinteger (retValue) and (save is null))
      retValue := vector (DB.DBA.S3__detName (), detcol_id, retValue, what);

    else if (isarray (retValue) and (save = 1))
      retValue := DB.DBA.DAV_DET_DAV_ID (retValue);
  }
  return retValue;
}
;

create function "S3_DAV_MAKE_ID" (
  in detcol_id any,
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('S3_DAV_MAKE_ID (', id, what, ')');
  declare retValue any;

  retValue := vector (DB.DBA.S3__detName (), detcol_id, id, what);

  return retValue;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "S3_DAV_SEARCH_PATH" (
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('S3_DAV_SEARCH_PATH (', id, what, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := DB.DBA.DAV_DET_DAV_ID (id);
  retValue := DB.DBA.DAV_SEARCH_PATH (davId, what);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "S3_DAV_RES_UPLOAD_COPY" (
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
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  declare listID, oldName, newName varchar;
  declare url, header, body any;
  declare srcEntry, listItem any;
  declare retValue, retHeader, result, save any;

  retValue := -20;
  srcEntry := DB.DBA.DAV_DIR_SINGLE_INT (source_id, what, '', null, null, http_dav_uid ());
  if (DB.DBA.DAV_HIDE_ERROR (srcEntry) is null)
    return;

  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  if (save is null)
  {
    result := DB.DBA.S3__copyObject (detcol_id, path_parts, source_id, what);
    if (DAV_HIDE_ERROR (result) is null)
    {
      retValue := result;
      goto _exit;
    }
  }
  connection_set ('dav_store', 1);

_exit:;
  connection_set ('dav_store', save);

  return retValue;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "S3_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  declare listID, oldName, newName varchar;
  declare url, header, body any;
  declare srcEntry, listItem any;
  declare retValue, retHeader, result, save any;

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
      result := DB.DBA.S3__moveObject (detcol_id, path_parts, source_id, what);
      if (DAV_HIDE_ERROR (result) is null)
      {
        retValue := result;
        goto _exit;
      }
      listItem := result;
      listID := get_keyword ('path', listItem);
    }
    connection_set ('dav_store', 1);
    if (what = 'C')
    {
      update WS.WS.SYS_DAV_COL set COL_NAME = newName, COL_MOD_TIME = now () where COL_ID = DB.DBA.DAV_DET_DAV_ID (source_id);
    } else {
      update WS.WS.SYS_DAV_RES set RES_NAME = newName, RES_MOD_TIME = now () where RES_ID = DB.DBA.DAV_DET_DAV_ID (source_id);
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
create function "S3_DAV_RES_CONTENT" (
  in id any,
  inout content any,
  out type varchar,
  in content_mode integer) returns integer
{
  -- dbg_obj_princ ('S3_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare retValue any;

  retValue := DAV_RES_CONTENT_INT (DB.DBA.DAV_DET_DAV_ID (id), content, type, content_mode, 0);

  return retValue;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "S3_DAV_SYMLINK" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite integer,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "S3_DAV_DEREFERENCE_LIST" (
  in detcol_id any,
  inout report_array any) returns any
{
  -- dbg_obj_princ ('S3_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "S3_DAV_RESOLVE_PATH" (
  in detcol_id any,
  inout reference_item any,
  inout old_base varchar,
  inout new_base varchar) returns any
{
  -- dbg_obj_princ ('S3_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "S3_DAV_LOCK" (
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
  -- dbg_obj_princ ('S3_DAV_LOCK (', path, id, what, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := DB.DBA.DAV_DET_DAV_ID (id);
  retValue := DAV_LOCK_INT (path, davId, what, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, DB.DBA.DAV_DET_USER (auth_uid), DB.DBA.DAV_DET_PASSWORD (auth_uid), auth_uid);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "S3_DAV_UNLOCK" (
  in id any,
  in what char(1),
  in token varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_UNLOCK (', id, what, token, auth_uid, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := DB.DBA.DAV_DET_DAV_ID (id);
  retValue := DAV_UNLOCK_INT (davId, what, token, DB.DBA.DAV_DET_USER (auth_uid), DB.DBA.DAV_DET_PASSWORD (auth_uid), auth_uid);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "S3_DAV_IS_LOCKED" (
  inout id any,
  inout what char(1),
  in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('S3_DAV_IS_LOCKED (', id, what, owned_tokens, ')');
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := DB.DBA.DAV_DET_DAV_ID (id);
  retValue := DAV_IS_LOCKED_INT (davId, what, owned_tokens);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "S3_DAV_LIST_LOCKS" (
  in id any,
  in what char(1),
  in recursive integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_LIST_LOCKS" (', id, what, recursive);
  declare davId integer;
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  davId := DB.DBA.DAV_DET_DAV_ID (id);
  retValue := DAV_LIST_LOCKS_INT (davId, what, recursive);
  connection_set ('dav_store', save);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function "S3_DAV_SCHEDULER" (
  in queue_id integer,
  in detcol_id integer := null)
{
  -- dbg_obj_princ ('DB.DBA.S3_DAV_SCHEDULER (', queue_id, ')');
  declare detcol_parts any;

  connection_set ('S3_DAV_SCHEDULER', 1);
  for (select COL_ID from WS.WS.SYS_DAV_COL where COL_DET = cast (DB.DBA.S3__detName () as varchar) and (detcol_id is null or (detcol_id = COL_ID))) do
  {
    if (coalesce (DB.DBA.S3__paramGet (COL_ID, 'C', 'syncEnabled', 0), 'on') = 'on')
    {
      detcol_parts := split_and_decode (WS.WS.COL_PATH (COL_ID), 0, '\0\0/');
      DB.DBA.S3_DAV_SCHEDULER_FOLDER (queue_id, COL_ID, detcol_parts, COL_ID, vector (''));
    }
  }
  DB.DBA.DAV_QUEUE_UPDATE_STATE (queue_id, 2);
}
;

-------------------------------------------------------------------------------
--
create function "S3_DAV_SCHEDULER_FOLDER" (
  in queue_id integer,
  in detcol_id integer,
  in detcol_parts any,
  in cid integer,
  in path_parts any)
{
  -- dbg_obj_princ ('DB.DBA.S3_DAV_SCHEDULER_FOLDER (', queue_id, detcol_id, detcol_parts, cid, path_parts, ')');

  DB.DBA.DAV_QUEUE_UPDATE_TS (queue_id);
  DB.DBA.S3__load (detcol_id, path_parts, detcol_parts);
  for (select COL_ID, COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = cid) do
  {
    DB.DBA.S3_DAV_SCHEDULER_FOLDER (queue_id, detcol_id, detcol_parts, COL_ID, vector_concat (subseq (path_parts, 0, length (path_parts)-1), vector (COL_NAME, '')));
  }
}
;

-------------------------------------------------------------------------------
--
create function "S3_DAV_SCHEDULER_ROOT" (
  in detcol_id integer)
{
  -- dbg_obj_princ ('DB.DBA.S3_DAV_SCHEDULER_ROOT (', detcol_id, ')');

  set_user_id ('dba');
  DB.DBA.DAV_QUEUE_ADD (DB.DBA.S3__detName () || '_' || cast (detcol_id as varchar), 0, 'DB.DBA.S3_DAV_SCHEDULER', vector (detcol_id), 1);
  DB.DBA.DAV_QUEUE_INIT ();

  return 1;
}
;

-------------------------------------------------------------------------------
--
create function "S3_CONFIGURE" (
  in id integer,
  in params any)
{
  -- dbg_obj_princ ('S3_CONFIGURE (', id, params, ')');
  declare syncEnabled varchar;

  if (not isnull ("S3_VERIFY" (DB.DBA.DAV_SEARCH_PATH (id, 'C'), params)))
    return -38;

  -- Activity
  DB.DBA.S3__paramSet (id, 'C', 'activity',       get_keyword ('activity', params, 'off'), 0);

  -- Check Interval
  DB.DBA.S3__paramSet (id, 'C', 'checkInterval',  get_keyword ('checkInterval', params, '15'), 0);

  -- Enable/Disable sync
  syncEnabled := get_keyword ('syncEnabled', params, 'off');
  DB.DBA.S3__paramSet (id, 'C', 'syncEnabled',    syncEnabled, 0);

  -- RDF Graph & Sponger params
  DB.DBA.DAV_DET_RDF_PARAMS_SET ('S3', id, params);

  -- Access params
  DB.DBA.S3__paramSet (id, 'C', 'BucketName',     get_keyword ('BucketName', params), 0);
  DB.DBA.S3__paramSet (id, 'C', 'AccessKeyID',    get_keyword ('AccessKeyID', params), 0);
  DB.DBA.S3__paramSet (id, 'C', 'SecretKey',      get_keyword ('SecretKey', params), 0);

  -- Root Path
  DB.DBA.S3__paramSet (id, 'C', 'path',           get_keyword ('path', params), 0);

  -- set DET Type Value
  DB.DBA.S3__paramSet (id, 'C', ':virtdet', DB.DBA.S3__detName (), 0, 0, 0);

  -- start sync scheduler
  if (syncEnabled = 'on')
    DB.DBA."S3_DAV_SCHEDULER_ROOT" (id);
}
;

-------------------------------------------------------------------------------
--
create function "S3_VERIFY" (
  in path integer,
  in params any)
{
  -- dbg_obj_princ ('S3_VERIFY (', path, params, ')');
  declare detcol_id integer;
  declare _path, _params, _parts any;
  declare retValue, retHeader any;
  declare exit handler for sqlstate '*'
  {
    return __SQL_MESSAGE;
  };

  VALIDATE.DBA.validate (get_keyword ('checkInterval', params, '15'), vector ('name', 'Check Interval', 'class', 'integer', 'minValue', 1));
  VALIDATE.DBA.validate (get_keyword ('BucketName', params), vector ('name', 'S3 Bucker Name', 'class', 'varchar', 'minLength', 1, 'maxLength', 63));
  VALIDATE.DBA.validate (get_keyword ('AccessKeyID', params), vector ('name', 'S3 Access Key', 'class', 'varchar', 'minLength', 1, 'maxLength', 20));
  VALIDATE.DBA.validate (get_keyword ('SecretKey', params), vector ('name', 'S3 Secret Key', 'class', 'varchar', 'minLength', 1, 'maxLength', 40));

  _path := get_keyword ('path', params, '/');
  if (_path = '/')
    return null;

  _params := vector ('authentication', 'Yes',
                     'BucketName',     get_keyword ('BucketName', params),
                     'AccessKeyID',    get_keyword ('AccessKeyID', params),
                     'SecretKey',      get_keyword ('SecretKey', params)
                    );
  _parts := split_and_decode (ltrim (_path, '/'), 0, '\0\0/');
  retValue := DB.DBA.S3__headObject (0, _parts, 'C', params=>_params);
  if (DAV_HIDE_ERROR (retValue) is null)
    return 'Error: The path does not exists!';

  return null;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__encode (
 in S varchar)
{
  S := sprintf ('%U', S);
  S := replace(S, '''', '%27');
  S := replace(S, '%2F', '/');
  S := replace(S, '%2C', ',');
  return S;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__md5 (
 in S varchar)
{
  declare md5_ctx, my_digest any;

  md5_ctx := md5_init ();
  md5_ctx := md5_update (md5_ctx, S);
  my_digest := md5_final (md5_ctx, 0);

  return encode_base64 (my_digest);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__detName ()
{
  return UNAME'S3';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__folderSuffix ()
{
  return '/';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__folderOldSuffix ()
{
  return '_\$folder\$';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__parts2path (
  in bucket varchar,
  in rootPath varchar,
  in pathParts any,
  in what any)
{
  -- dbg_obj_princ ('DB.DBA.S3__parts2path (', bucket, rootPath, pathParts, what, ')');
  declare path varchar;

  path := DB.DBA.DAV_CONCAT_PATH (pathParts, null);
  if ((path <> '') and (chr (path[0]) <> '/'))
    path := '/' || path;

  path := case when (coalesce (rootPath, '/') <> '/') then rtrim (rootPath, '/') else '' end || path;

  if (bucket <> '')
    path := '/' || bucket || path;

  path := rtrim (path, '/') || case when (what = 'C') then '/' end;

  return path;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__workPath (
  in id any,
  in what any,
  in encode integer := 1)
{
  declare path varchar;

  path := DB.DBA.S3__paramGet (id, what, 'path', 0);
  if (encode)
  path := DB.DBA.S3__encode (path);

  if (trim (path, '/') <> DB.DBA.S3__bucketFromUrl (path))
    path := rtrim (path, '/') || case when (what = 'C') then DB.DBA.S3__folderSuffix () end;

  path := DB.DBA.S3__pathFromUrl (path);
  return path;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__params (
  in colId integer)
{
  declare params any;

  colId := DB.DBA.DAV_DET_DETCOL_ID (colId);
  params := vector (
    'authentication', 'Yes',
    'BucketName',     DB.DBA.S3__paramGet (colId, 'C', 'BucketName',  0),
    'AccessKeyID',    DB.DBA.S3__paramGet (colId, 'C', 'AccessKeyID', 0, 1, 0),
    'SecretKey',      DB.DBA.S3__paramGet (colId, 'C', 'SecretKey',   0, 1, 0),
    'path',           DB.DBA.S3__paramGet (colId, 'C', 'path', 0)
  );
  return params;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__paramSet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _propValue any,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _encrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.S3__paramSet', _propName, _propValue, ')');
  return DB.DBA.DAV_DET_PARAM_SET (DB.DBA.S3__detName(), 's3', _id, _what, _propName, _propValue, _serialized, _prefixed, _encrypt);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__paramGet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _decrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.S3__paramGet (', _id, _what, _propName, ')');
  return DB.DBA.DAV_DET_PARAM_GET (DB.DBA.S3__detName(), 's3', _id, _what, _propName, _serialized, _prefixed, _decrypt);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__paramRemove (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _prefixed integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.S3__paramRemove (', _id, _what, _propName, ')');
  return DB.DBA.DAV_DET_PARAM_REMOVE (DB.DBA.S3__detName(), _id, _what, _propName, _prefixed);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__obj2xml (
  in item any)
{
  return '<entry>' || DB.DBA.obj2xml (item, 10) || '</entry>';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__makeUrl (
  in path varchar,
  in isSecure integer := 1)
{
  declare bucket, dir varchar;

  path := ltrim (path, '/');
  bucket := DB.DBA.S3__bucketFromUrl (path);
    dir := case when (length (bucket) < length (path)) then subseq (path, length (bucket)+1) else '' end;
    if (bucket <> '')
      bucket := bucket || '/';

  return 'http://s3.amazonaws.com/' || bucket || dir;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__bucketFromUrl (
  in url varchar)
{
  declare parts any;

  parts := split_and_decode (trim (url, '/'), 0, '\0\0/');
  if (length (parts) <> 0)
    return parts[0];

  return '';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__nameFromUrl (
  in url varchar)
{
  declare parts any;

  parts := split_and_decode (trim (url, '/'), 0, '\0\0/');
  if (length (parts) <> 0)
    return parts[length (parts) - 1];

  return '';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__pathFromUrl (
  in url varchar)
{
  declare bucket any;

  bucket := DB.DBA.S3__bucketFromUrl (url);
  if (isnull (bucket))
    return '';

  return ltrim (subseq (url, length (bucket)+1), '/');
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__makeAWSHeader (
  in params any,
  in HTTPVerb varchar := null,
	in ContentMD5 varchar := null,
	in ContentType varchar := null,
	in RequestDate varchar := null,
	in CanonicalizedAmzHeaders any := null,
	in Encryption any := null,
	in CanonicalizedResource varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.S3__makeAWSHeader ()');
  declare S, hmacKey, secretKey, accessCode varchar;
  declare reqHeader, authHeader varchar;

  authHeader := '';
  authHeader := authHeader || coalesce (HTTPVerb, '') || '\n';
  authHeader := authHeader || coalesce (ContentMD5, '') || '\n';
  authHeader := authHeader || coalesce (ContentType, '') || '\n';
  authHeader := authHeader || coalesce (RequestDate, '') || '\n';
  if (not isnull (CanonicalizedAmzHeaders))
  {
    foreach (any amz in CanonicalizedAmzHeaders) do
      authHeader := authHeader || coalesce (amz, '') || '\n';
  }
  Encryption := coalesce (Encryption, 'None');
  if (Encryption = 'AES256')
    authHeader := authHeader || sprintf ('x-amz-server-side-encryption:%s\n', encryption);

  authHeader := authHeader || coalesce (CanonicalizedResource, '');

  accessCode := get_keyword ('AccessKeyID', params);
  secretKey := get_keyword ('SecretKey', params);
  hmacKey := xenc_key_RAW_read (null, encode_base64 (secretKey));
  S := xenc_hmac_sha1_digest (authHeader, hmacKey);
  xenc_key_remove (hmacKey);

  reqHeader := sprintf ('Authorization: AWS %s:%s\r\nDate: %s\r\n', accessCode, S, RequestDate);
  if (not isnull (ContentMD5))
    reqHeader := reqHeader|| sprintf ('Content-MD5: %s\r\n', ContentMD5);

  if (not isnull (ContentType))
    reqHeader := reqHeader || sprintf ('Content-Type: %s\r\n', ContentType);

  if (not isnull (CanonicalizedAmzHeaders))
  {
    foreach (any amz in CanonicalizedAmzHeaders) do
      reqHeader := reqHeader || coalesce (amz, '') || '\r\n' ;
  }
  if (Encryption = 'AES256')
    reqHeader := reqHeader || sprintf ('x-amz-server-side-encryption: %s\r\n', encryption);

  return reqHeader;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__put (
  in detcol_id any,
  in id any)
{
  declare type, path varchar;
  declare retValue, retHeader, content, pathParts any;

  path := DB.DBA.DAV_SEARCH_PATH (id, 'R');
  content := cast ((select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = DB.DBA.DAV_DET_DAV_ID (id)) as varchar);
  type := (select RES_TYPE from WS.WS.SYS_DAV_RES where RES_ID = DB.DBA.DAV_DET_DAV_ID (id));

  -- get parent edit-media link and next get new session
  pathParts := split_and_decode (trim (subseq (path, length (DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C'))), '/'), 0, '\0\0/');
  retValue := DB.DBA.S3__putObject (detcol_id, pathParts, 'R', content, type);
  if (DAV_HIDE_ERROR (retValue) is null)
    return retValue;

  DB.DBA.S3__paramSet (id, 'R', 'Entry', DB.DBA.S3__obj2xml (retValue), 0);
  DB.DBA.S3__paramSet (id, 'R', 'path', get_keyword ('path', retValue), 0);
  DB.DBA.S3__paramRemove (id, 'R', 'download');

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__sync (
  in id any)
{
  -- dbg_obj_princ ('DB.DBA.S3__sync (', id, ')');
  return DB.DBA.DAV_DET_SYNC (DB.DBA.S3__detName (), id);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__load (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  in forced integer := 0) returns any
{
  -- dbg_obj_princ ('DB.DBA.S3__load (', detcol_id, subPath_parts, detcol_parts, ')');
  declare colId, checkInterval integer;
  declare colPath varchar;
  declare retValue, save, downloads, listItems, davItems, colEntry, xmlItems, davEntry, listIds, listId any;
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

  if (not forced)
  {
    syncTime := DB.DBA.S3__paramGet (colId, 'C', 'syncTime');
    if (not isnull (syncTime))
    {
      checkInterval := atoi (coalesce (DB.DBA.S3__paramGet (detcol_id, 'C', 'checkInterval', 0), '15')) * 60;
      if (datediff ('second', syncTime, now ()) < checkInterval)
        goto _exit;
    }
  }
  listItems := DB.DBA.S3__list (detcol_id, detcol_parts, colId, subPath_parts);
  if (DAV_HIDE_ERROR (listItems) is null)
    goto _exit;

  if (isinteger (listItems))
    goto _exit;

  DB.DBA.S3__activity (detcol_id, 'Sync started');
  {
    declare _id, _what, _type, _content any;
    declare title varchar;
    {
      declare exit handler for sqlstate '*'
      {
        DB.DBA.S3__activity (detcol_id, 'Exec error: ' || __SQL_MESSAGE);
        goto _exitSync;
      };

      connection_set ('dav_store', 1);
      colEntry := DB.DBA.DAV_DIR_SINGLE_INT (colId, 'C', '', null, null, http_dav_uid ());

      listIds := vector ();
      davItems := DB.DBA.DAV_DET_DAV_LIST (DB.DBA.S3__detName (), detcol_id, colId);
      foreach (any davItem in davItems) do
      {
        connection_set ('dav_store', 1);
        listID := DB.DBA.S3__paramGet (davItem[4], davItem[1], 'path', 0);
        foreach (any listItem in listItems) do
        {
          title := get_keyword ('name', listItem);
          if ((listID = get_keyword ('path', listItem)) and (title = davItem[10]))
          {
            davEntry := DB.DBA.S3__paramGet (davItem[4], davItem[1], 'Entry', 0);
            if (davEntry is not null)
            {
              listIds := vector_concat (listIds, vector (listID));
              davEntry := xtree_doc (davEntry);
              if (DB.DBA.DAV_DET_ENTRY_XPATH (davEntry, '/updated', 1) <> datestring (get_keyword ('updated', listItem)))
              {
                set triggers off;
                DB.DBA.S3__paramSet (davItem[4], davItem[1], ':getlastmodified', DB.DBA.DAV_DET_STRINGDATE (get_keyword ('updated', listItem)), 0, 0);
                set triggers on;

                if (davItem[1] = 'R')
                {
                  declare item, path_parts any;

                  path_parts := subPath_parts;
                  path_parts[length(path_parts)-1] := title;
                  item := DB.DBA.S3__headObject (detcol_id, path_parts, 'R');
                  if (DAV_HIDE_ERROR (item) is not null)
                    listItem := item;
                }
                DB.DBA.S3__paramSet (davItem[4], davItem[1], 'Entry', DB.DBA.S3__obj2xml (listItem), 0);
              }
              if (davItem[1] = 'R')
              {
                if (DB.DBA.DAV_DET_ENTRY_XPATH (davEntry, '/etag', 1) <> get_keyword ('etag', listItem))
                {
                  DB.DBA.S3__paramSet (davItem[4], davItem[1], 'download', '0', 0);
                  downloads := vector_concat (downloads, vector (vector (davItem[4], davItem[1])));
                }
                else
                {
                  declare downloaded any;

                  downloaded := DB.DBA.S3__paramGet (davItem[4], davItem[1], 'download', 0);
                  if (downloaded is not null)
                    downloads := vector_concat (downloads, vector (vector (davItem[4], davItem[1])));
                }
              }
              goto _continue;
            }
          }
        }
        DB.DBA.DAV_DET_RDF_DELETE (DB.DBA.S3__detName (), detcol_id, davItem[4], davItem[1]);

        connection_set ('dav_store', 1);
        DAV_DELETE_INT (davItem[0], 1, null, null, 0, 0);

      _continue:;
        commit work;
      }
      foreach (any listItem in listItems) do
      {
        connection_set ('dav_store', 1);
        listID := get_keyword ('path', listItem);
        if (not position (listID, listIDs))
        {
          title := get_keyword ('name', listItem);
          connection_set ('dav_store', 1);
          if (get_keyword ('type', listItem) = 'C')
          {
            _id := DB.DBA.DAV_COL_CREATE (colPath || title || '/',  colEntry[5], colEntry[7], colEntry[6], DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));
            _what := 'C';
          }
          else
          {
            declare item, path_parts any;

            path_parts := subPath_parts;
            path_parts[length(path_parts)-1] := title;
            item := DB.DBA.S3__headObject (detcol_id, path_parts, 'R');
            if (DAV_HIDE_ERROR (item) is not null)
              listItem := item;

            _content := '';
            _type := get_keyword ('mimeType', listItem, http_mime_type (title));
            _id := DB.DBA.DAV_RES_UPLOAD (colPath || title,  _content, _type, colEntry[5], colEntry[7], colEntry[6], DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));
            _what := 'R';
          }
          if (DAV_HIDE_ERROR (_id) is not null)
          {
            commit work;
            set triggers off;
            DB.DBA.S3__paramSet (_id, _what, ':addeddate', now (), 0, 0);
            DB.DBA.S3__paramSet (_id, _what, ':creationdate', DB.DBA.DAV_DET_STRINGDATE (get_keyword ('updated', listItem)), 0, 0);
            DB.DBA.S3__paramSet (_id, _what, ':getlastmodified', DB.DBA.DAV_DET_STRINGDATE (get_keyword ('updated', listItem)), 0, 0);
            set triggers on;
            DB.DBA.S3__paramSet (_id, _what, 'path', listID, 0);
            DB.DBA.S3__paramSet (_id, _what, 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
            DB.DBA.S3__paramSet (_id, _what, 'Entry', DB.DBA.S3__obj2xml (listItem), 0);
            if (_what = 'R')
            {
              DB.DBA.S3__paramSet (_id, _what, 'download', '0', 0);
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
  DB.DBA.S3__activity (detcol_id, 'Sync ended');

_exit:;
  DB.DBA.S3__downloads (detcol_id, downloads);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__list (
  inout detcol_id any,
  inout detcol_parts varchar,
  inout col_id any,
  inout subPath_parts varchar)
{
  -- dbg_obj_princ ('DB.DBA.S3__list (', detcol_id, detcol_parts, subPath_parts, ')');
  declare bucket, rootPath varchar;
  declare retValue, retHeader, params any;

  params := DB.DBA.S3__params (detcol_id);
  bucket := get_keyword ('BucketName', params);
  rootPath := get_keyword ('path', params);
  if (is_empty_or_null (bucket) and (length (subPath_parts) = 1) and subPath_parts[0] = '')
  {
    retValue := DB.DBA.S3__listBuckets (detcol_id, params);
  }
  else
  {
    retValue := DB.DBA.S3__listBucket (detcol_id, params, DB.DBA.S3__parts2path (bucket, rootPath, subPath_parts, 'C'));
  }
  if (not isinteger (retValue))
    DB.DBA.S3__paramSet (col_id, 'C', 'syncTime', now ());

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__listBuckets (
  inout detcol_id any,
  in params any,
  in bucket varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.S3__listBuckets (', detcol_id, params, ')');
  declare dateUTC, authHeader, path, S varchar;
  declare reqHeader, retHeader varchar;
  declare xt, xtItems, buckets any;

  path := '/';
  dateUTC := date_rfc1123 (now());

  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'GET', null, null, dateUTC, null, null, path);
  xt := http_client_ext (
    DB.DBA.S3__makeUrl (path),
    http_method=>'GET',
    http_headers=>reqHeader,
    headers=>retHeader
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
  {
    DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || xt);
    return -28;
  }
  vectorbld_init (buckets);
  xt := xml_tree_doc (xt);
  xtItems := xpath_eval ('//Buckets/Bucket', xt, 0);
  foreach (any xtItem in xtItems) do
  {
    declare name, creationDate any;

    name := cast (xpath_eval ('./Name', xtItem) as varchar);
    if ((name = bucket) or isnull (bucket))
    {
      creationDate := stringdate (cast (xpath_eval ('./CreationDate', xtItem) as varchar));
      vectorbld_acc (
        buckets,
          vector_concat (
            DB.DBA.jsonObject (),
            vector ('path', '/' || name || '/',
                    'name', name,
                    'type', 'C',
                    'updated', creationDate,
                    'size', 0
                   )
          )
      );
    }
  }
  vectorbld_final (buckets);
  return buckets;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__listBucket (
  inout detcol_id any,
  in params any,
  in url varchar,
  in delimiter varchar := '/')
{
  -- dbg_obj_princ ('DB.DBA.S3__listBucket (', detcol_id, params, url, ')');
  declare N integer;
  declare dateUTC, authHeader, S, bucket, bucketPath varchar;
  declare reqHeader, retHeader varchar;
  declare xt, xtItems, buckets any;

  bucket := '/' || DB.DBA.S3__bucketFromUrl (url) || '/';
  bucketPath := DB.DBA.S3__pathFromUrl (url);
  dateUTC := date_rfc1123 (now());

  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'GET', null, null, dateUTC, null, null, bucket);
  xt := http_client_ext (
    url=>DB.DBA.S3__makeUrl (bucket) || sprintf ('?prefix=%U&marker=%s&delimiter=%s', bucketPath, '', delimiter),
    http_method=>'GET',
    http_headers=>reqHeader,
    headers=>retHeader
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
  {
    DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || xt);
    return -28;
  }
  vectorbld_init (buckets);
  xt := xml_tree_doc (xt);
  xtItems := xpath_eval ('//CommonPrefixes', xt, 0);
  foreach (any xtItem in xtItems) do
  {
    declare keyName, itemPath, itemName, itemType, lastModified, itemSize, itemETag, itemStorage any;

    keyName := serialize_to_UTF8_xml (xpath_eval ('string (./Prefix)', xtItem));
    itemName := replace (subseq (keyName, length (bucketPath)), DB.DBA.S3__folderSuffix (), '');
    itemType := 'C';
    itemPath := url || itemName || case when (itemType = 'C') then '/' end;
    lastModified := now ();
    itemSize := 0;
    vectorbld_acc (
      buckets,
        vector_concat (
        DB.DBA.jsonObject (),
          vector ('path', itemPath,
                  'name', itemName,
                  'type', itemType,
                  'updated', lastModified,
                  'size', itemSize
          )
        )
    );
  }
  xtItems := xpath_eval ('//Contents', xt, 0);
  foreach (any xtItem in xtItems) do
  {
    declare keyName, itemPath, itemName, itemType, lastModified, itemSize, itemETag, itemStorage any;

    keyName := serialize_to_UTF8_xml (xpath_eval ('string (./Key)', xtItem));
    keyName := replace (keyName, bucketPath, '');
    itemName := replace (keyName, DB.DBA.S3__folderOldSuffix (), '');
    if (itemName <> '')
    {
      itemType := case when (itemName <> keyName) then 'C' else 'R' end;
      itemPath := url || itemName || case when (itemType = 'C') then '/' end;
      lastModified := stringdate (cast (xpath_eval ('./LastModified', xtItem) as varchar));
      itemSize := cast (xpath_eval ('./Size', xtItem) as integer);
      itemETag := cast (xpath_eval ('./ETag', xtItem) as varchar);
      itemStorage := cast (xpath_eval ('./StorageClass', xtItem) as varchar);
      vectorbld_acc (
        buckets,
        vector_concat (
          DB.DBA.jsonObject (),
          vector ('path', itemPath,
                  'name', itemName,
                  'type', itemType,
                  'updated', lastModified,
                  'size', itemSize,
                  'etag', itemETag,
                  'storage', itemStorage
          )
          )
      );
    }
  }
  vectorbld_final (buckets);
  return buckets;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__putObject (
  in detcol_id any,
  in path_parts any,
  in what varchar,
  in content any := null,
  in type any := null)
{
  -- dbg_obj_princ ('DB.DBA.S3__putObject (', detcol_id, path_parts, what, ')');
  declare dateUTC, authHeader, S, path, s3Path, workPath varchar;
  declare reqHeader, retHeader, retValue, acl varchar;
  declare params, item any;
  declare encryption varchar;
  declare id, davEntry any;

  params := DB.DBA.S3__params (detcol_id);
  dateUTC := date_rfc1123 (now());
  s3Path := DB.DBA.S3__parts2path (get_keyword ('BucketName', params), get_keyword ('path', params), path_parts, what);

  workPath := DB.DBA.S3__encode (s3Path);
  if (trim (s3Path, '/') <> DB.DBA.S3__bucketFromUrl (s3Path))
    workPath := rtrim (workPath, '/') || case when (what = 'C') then DB.DBA.S3__folderSuffix () end;

  -- get ACL
  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'GET', null, null, dateUTC, null, null, workPath || '?acl');
  acl := http_client_ext (
    url=>DB.DBA.S3__makeUrl (workPath) || '?acl',
    http_method=>'GET',
    http_headers=>reqHeader,
    headers=>retHeader
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
    acl := null;

  -- put object
  encryption := connection_get ('s3-server-side-encryption');
  if (isnull (encryption))
  {
    path := DB.DBA.DAV_DET_PATH (detcol_id, path_parts);
    id := DB.DBA.DAV_SEARCH_ID (path, what);
    if (DAV_HIDE_ERROR (id) is not null)
      encryption := DB.DBA.S3_DAV_PROP_GET (id, what, 'virt:s3-server-side-encryption', http_dav_uid ());
  }

  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'PUT', null, type, dateUTC, null, encryption, workPath);
  if (not isnull (content))
    reqHeader := reqHeader || sprintf ('Content-Length: %d\r\n', length (content));

  retValue := http_client_ext (
    url=>DB.DBA.S3__makeUrl (workPath),
    http_method=>'PUT',
    http_headers=>reqHeader,
    headers=>retHeader,
    body=>content
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
  {
    DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || retValue);
    return -28;
  }

  -- put ACL
  if (not isnull (acl))
  {
    commit work;
    reqHeader := DB.DBA.S3__makeAWSHeader (params, 'PUT', null, null, dateUTC, null, null, workPath || '?acl');
    acl := http_client_ext (
      url=>DB.DBA.S3__makeUrl (workPath) || '?acl',
      http_method=>'PUT',
      http_headers=>reqHeader,
      headers=>retHeader,
      body=>acl
    );
  }

  -- get object info
  return DB.DBA.S3__headObject (detcol_id, path_parts, what);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__headObject (
  in detcol_id any,
  in path_parts any,
  in what varchar,
  in params any := null)
{
  -- dbg_obj_princ ('DB.DBA.S3__headObject (', detcol_id, path_parts, what, ')');
  declare dateUTC, authHeader, s3Path, workPath varchar;
  declare reqHeader, retHeader, retValue varchar;
  declare item any;

  if (isnull (params))
    params := DB.DBA.S3__params (detcol_id);

  dateUTC := date_rfc1123 (now());
  s3Path := DB.DBA.S3__parts2path (get_keyword ('BucketName', params), get_keyword ('path', params), path_parts, what);

  workPath := DB.DBA.S3__encode (s3Path);
  if (trim (s3Path, '/') <> DB.DBA.S3__bucketFromUrl (s3Path))
    workPath := rtrim (workPath, '/') || case when (what = 'C') then DB.DBA.S3__folderSuffix () end;

  -- get object info
  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'HEAD', null, null, dateUTC, null, null, workPath);
  retValue := http_client_ext (
    url=>DB.DBA.S3__makeUrl (workPath),
    http_method=>'HEAD',
    http_headers=>reqHeader,
    headers=>retHeader
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
  {
    if (detcol_id > 0)
      DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || retValue);

    return -28;
  }
  item := vector_concat (
    DB.DBA.jsonObject (),
    vector ('path', s3Path,
            'name', DB.DBA.S3__nameFromUrl (s3Path),
            'type', what,
            'etag', http_request_header (retHeader, 'ETag'),
            'size', cast (http_request_header (retHeader, 'Content-Length') as integer),
            'mimeType', http_request_header (retHeader, 'Content-Type'),
            'updated', http_string_date (coalesce (http_request_header (retHeader, 'Last-Modified', null, null), http_request_header (retHeader, 'Date', null, null))),
            'storage', 'STANDARD',
            'amz-server-side-encryption', http_request_header (retHeader, 'x-amz-server-side-encryption', null, null),
            'amz-request-id', http_request_header (retHeader, 'x-amz-request-id', null, null),
            'amz-id-2', http_request_header (retHeader, 'x-amz-id-2', null, null)
           )
  );
  return item;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__copyObject (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what varchar,
  in propName varchar := 'path')
{
  -- dbg_obj_princ ('DB.DBA.S3__copyObject (', detcol_id, path_parts, source_id, what, propName, ')');
  declare path, col_path, src_path, dst_path, det_path varchar;
  declare tmp, copy_id, retValue, copy_path_parts any;
  declare params any;

  params := DB.DBA.S3__params (detcol_id);
  if      (what = 'R')
  {
    retValue := DB.DBA.S3__copySingleObject (detcol_id, path_parts, source_id, what, params);

    tmp := DB.DBA.S3__paramSet (source_id, what, propName, get_keyword ('path', retValue), 0);
    if (DAV_HIDE_ERROR (tmp) is null)
      return tmp;

    tmp := DB.DBA.S3__paramSet (source_id, what, 'Entry', DB.DBA.S3__obj2xml (retValue), 0);
    if (DAV_HIDE_ERROR (tmp) is null)
      return tmp;
  }
  else if (what = 'C')
  {
    det_path := DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C');
    src_path := DB.DBA.DAV_SEARCH_PATH (source_id, what);
    dst_path := det_path || DB.DBA.DAV_CONCAT_PATH (null, path_parts);
    for (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) like src_path || '%') do
    {
      col_path := WS.WS.COL_PATH (COL_ID);
      path := dst_path || subseq (col_path, length (src_path));
      copy_path_parts := split_and_decode (subseq (path, length (det_path)), 0, '\0\0/');
      tmp := DB.DBA.S3__putObject (detcol_id, copy_path_parts, 'C');

      if (DAV_HIDE_ERROR (tmp) is null)
        return tmp;

      if (col_path = src_path)
        retValue := tmp;

      tmp := DB.DBA.S3__paramSet (COL_ID, 'C', propName, get_keyword ('path', tmp), 0);
      if (DAV_HIDE_ERROR (tmp) is null)
        return tmp;

      tmp := DB.DBA.S3__paramSet (COL_ID, 'C', 'Entry', DB.DBA.S3__obj2xml (tmp), 0);
      if (DAV_HIDE_ERROR (tmp) is null)
        return tmp;
    }
    for (select RES_ID, RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like src_path || '%') do
    {
      path := RES_FULL_PATH;
      path := dst_path || subseq (path, length (src_path));
      copy_path_parts := split_and_decode (subseq (path, length (det_path)), 0, '\0\0/');
      copy_id := source_id;
      copy_id[2] := RES_ID;;
      copy_id[3] := 'R';
      tmp := DB.DBA.S3__copySingleObject (detcol_id, copy_path_parts, copy_id, 'R', params);
      if (DAV_HIDE_ERROR (tmp) is null)
        return tmp;

      tmp := DB.DBA.S3__paramSet (RES_ID, 'R', propName, get_keyword ('path', tmp), 0);
      if (DAV_HIDE_ERROR (tmp) is null)
        return tmp;

      tmp := DB.DBA.S3__paramSet (RES_ID, 'R', 'Entry', DB.DBA.S3__obj2xml (tmp), 0);
      if (DAV_HIDE_ERROR (tmp) is null)
        return tmp;
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__copySingleObject (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what varchar,
  in params any := null)
{
  -- dbg_obj_princ ('DB.DBA.S3__copySingleObject (', detcol_id, path_parts, source_id, what, ')');
  declare dateUTC, s3Path, srcPath, dstPath varchar;
  declare reqHeader, retHeader, retValue, acl varchar;
  declare item, davEntry any;
  declare encryption varchar;

  if (isnull (params))
    params := DB.DBA.S3__params (detcol_id);

  dateUTC := date_rfc1123 (now());
  s3Path := DB.DBA.S3__parts2path (get_keyword ('BucketName', params), get_keyword ('path', params), path_parts, what);

  dstPath := DB.DBA.S3__encode (s3Path);
  if (trim (s3Path, '/') <> DB.DBA.S3__bucketFromUrl (s3Path))
    dstPath := rtrim (dstPath, '/') || case when (what = 'C') then DB.DBA.S3__folderSuffix () end;

  srcPath := DB.DBA.S3__paramGet (source_id, what, 'path', 0);

  -- acl
  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'GET', null, null, dateUTC, null, null, srcPath || '?acl');
  acl := http_client_ext (
    url=>DB.DBA.S3__makeUrl (srcPath) || '?acl',
    http_method=>'GET',
    http_headers=>reqHeader,
    headers=>retHeader
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
    acl := null;

  -- encryption
  encryption := connection_get ('s3-server-side-encryption');
  if (isnull (encryption))
    encryption := DB.DBA.S3__paramGet (source_id, what, 'virt:s3-server-side-encryption', 0, 0);

  -- copy
  commit work;
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'PUT', null, null, dateUTC, vector (sprintf ('x-amz-copy-source:%s', srcPath)), encryption, dstPath);
  retValue := http_client_ext (
    url=>DB.DBA.S3__makeUrl (dstPath),
    http_method=>'PUT',
    http_headers=>reqHeader,
    headers=>retHeader
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
  {
    DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || retValue);
    return -28;
  }

  -- put ACL
  if (not isnull (acl))
  {
    commit work;
    reqHeader := DB.DBA.S3__makeAWSHeader (params, 'PUT', null, null, dateUTC, null, null, dstPath || '?acl');
    acl := http_client_ext (
      url=>DB.DBA.S3__makeUrl (dstPath) || '?acl',
      http_method=>'PUT',
      http_headers=>reqHeader,
      headers=>retHeader,
      body=>acl
    );
  }

  -- get object info
  return DB.DBA.S3__headObject (detcol_id, path_parts, what);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__moveObject (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what varchar)
{
  -- dbg_obj_princ ('DB.DBA.S3__moveObject (', detcol_id, path_parts, what, ')');
  declare path, src_path varchar;
  declare retValue, tmp any;

  retValue := DB.DBA.S3__copyObject (detcol_id, path_parts, source_id, what, 'path_tmp');
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    tmp := DB.DBA.S3__deleteObject (detcol_id, source_id, what);
    if (DAV_HIDE_ERROR (tmp) is null)
      retValue := tmp;

    if      (what = 'R')
    {
      path := DB.DBA.S3__paramGet (source_id, what, 'path_tmp', 0);
      DB.DBA.S3__paramSet (source_id, what, 'path', path, 0);
      DB.DBA.S3__paramRemove (source_id, what, 'path_tmp');
    }
    else if (what = 'C')
    {
      src_path := DB.DBA.DAV_SEARCH_PATH (source_id, what);
      for (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) like src_path || '%') do
      {
        path := DB.DBA.S3__paramGet (COL_ID, 'C', 'path_tmp', 0);
        DB.DBA.S3__paramSet (COL_ID, 'C', 'path', path, 0);
        DB.DBA.S3__paramRemove (COL_ID, 'C', 'path_tmp');
      }
      for (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH like src_path || '%') do
      {
        path := DB.DBA.S3__paramGet (RES_ID, 'R', 'path_tmp', 0);
        DB.DBA.S3__paramSet (RES_ID, 'R', 'path', path, 0);
        DB.DBA.S3__paramRemove (RES_ID, 'R', 'path_tmp');
      }
    }

  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__deleteObject (
  in detcol_id any,
  in id any,
  in what varchar)
{
  -- dbg_obj_princ ('DB.DBA.S3__deleteObject (', detcol_id, id, what, ')');
  declare N integer;
  declare dateUTC, authHeader, S, path, s3Path, workPath varchar;
  declare reqHeader, retHeader, retValue, content varchar;
  declare params any;

  params := DB.DBA.S3__params (detcol_id);
  dateUTC := date_rfc1123 (now());
  s3Path := DB.DBA.S3__paramGet (id, what, 'path', 0);

  N := 0;
  content := '<?xml version="1.0" encoding="UTF-8"?><Delete><Quiet>false</Quiet>';
  if ((what = 'R') or (trim (s3Path, '/') <> DB.DBA.S3__bucketFromUrl (s3Path)))
  {
    N := N + 1;
    content := content || sprintf ('<Object><Key>%V</Key></Object>', DB.DBA.S3__workPath (id, what, 0));
  }
  if (what = 'C')
  {
    path := DB.DBA.DAV_SEARCH_PATH (id, what);
    for (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) like path || '%' and WS.WS.COL_PATH (COL_ID) <> path) do
    {
      N := N + 1;
      content := content || sprintf ('<Object><Key>%V</Key></Object>', DB.DBA.S3__workPath (COL_ID, 'C', 0));
    }
    for (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH like path || '%') do
    {
      N := N + 1;
      content := content || sprintf ('<Object><Key>%V</Key></Object>', DB.DBA.S3__workPath (RES_ID, 'R', 0));
    }
  }
  content := content || '</Delete>';
  if (N = 0)
    goto _skip;

  commit work;
  workPath := DB.DBA.S3__encode ('/' || DB.DBA.S3__bucketFromUrl (s3Path) || '/');
  reqHeader := DB.DBA.S3__makeAWSHeader (params, 'POST', DB.DBA.S3__md5 (content), 'text/xml', dateUTC, null, null, workPath || '?delete');
  reqHeader := reqHeader || sprintf ('Content-Length: %d\r\n', length (content));
  retValue := http_client_ext (
    url=>DB.DBA.S3__makeUrl (workPath) || '?delete',
    http_method=>'POST',
    http_headers=>reqHeader,
    headers=>retHeader,
    body=>content
  );
  if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
  {
    DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || retValue);
    return -28;
  }

_skip:;
  if ((what = 'C') and (trim (s3Path, '/') = DB.DBA.S3__bucketFromUrl (s3Path)))
  {
    -- delete bucket
    commit work;
    workPath := DB.DBA.S3__encode (s3Path);
    reqHeader := DB.DBA.S3__makeAWSHeader (params, 'DELETE', null, null, dateUTC, null, null, workPath);
    retValue := http_client_ext (
      url=>DB.DBA.S3__makeUrl (workPath),
      http_method=>'DELETE',
      http_headers=>reqHeader,
      headers=>retHeader
    );
    if (not DB.DBA.DAV_DET_HTTP_ERROR (retHeader, 1))
    {
      DB.DBA.S3__activity (detcol_id, 'HTTP error: ' || retValue);
      return -28;
    }
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__activity (
  in detcol_id integer,
  in text varchar)
{
  DB.DBA.DAV_DET_ACTIVITY (DB.DBA.S3__detName (), detcol_id, text);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__downloads (
  in detcol_id integer,
  in downloads any)
{
  if (length (downloads) = 0)
    return;

  if (connection_get ('S3_DAV_SCHEDULER') = 1)
  {
    DB.DBA.S3__downloads_aq (detcol_id, downloads);
  }
  else
  {
    declare aq any;

    set_user_id ('dba');
    aq := async_queue (1);
    aq_request (aq, 'DB.DBA.S3__downloads_aq', vector (detcol_id, downloads));
  }
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__downloads_aq (
  in detcol_id integer,
  in downloads any)
{
  -- dbg_obj_princ ('DB.DBA.S3__downloads_aq (', detcol_id, downloads, ')');
  declare id, downloaded integer;
  declare url, listID varchar;
  declare save, params, items, content, oEntry, davEntry any;
  declare retValue, authHeader, reqHeader, retHeader any;
  declare S, dateUTC, path varchar;

  set_user_id ('dba');
  save := connection_get ('dav_store');
  items := vector ();
  DB.DBA.S3__activity (detcol_id, sprintf ('Downloading %d file(s)', length (downloads)));
  params := DB.DBA.S3__params (detcol_id);
  foreach (any download in downloads) do
  {
    downloaded := DB.DBA.S3__paramGet (download[0], download[1], 'download', 0);
    if (downloaded is null)
      goto _continue;

    downloaded := cast (downloaded as integer);
    if (downloaded > 5)
      goto _continue;

    if (download[1] <> 'R')
      goto _continue;

    listID := DB.DBA.S3__paramGet (download[0], download[1], 'path', 0);
    if (listID is null)
      goto _continue;

    path := DB.DBA.S3__encode (listID);
    dateUTC := date_rfc1123 (now());

    commit work;
    reqHeader := DB.DBA.S3__makeAWSHeader (params, 'GET', null, null, dateUTC, null, null, path);
    content := http_client_ext (url=>DB.DBA.S3__makeUrl (path),
                                 http_method=>'GET',
                                 http_headers=>reqHeader,
                                 headers=>retHeader);
    if (DAV_HIDE_ERROR (content) is null)
      goto _error;

    id := DB.DBA.DAV_DET_DAV_ID (download[0]);
    davEntry := DB.DBA.DAV_DIR_SINGLE_INT (id, 'R', '', null, null, http_dav_uid ());
    connection_set ('dav_store', 1);
    retValue := DAV_RES_UPLOAD_STRSES_INT (davEntry[0], content, davEntry[9], davEntry[5], DB.DBA.DAV_DET_USER (davEntry[7]), DB.DBA.DAV_DET_USER (davEntry[6]), DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()), mod_time=>davEntry[3], extern=>0, check_locks=>0);
    connection_set ('dav_store', save);
    if (DAV_HIDE_ERROR (retValue) is null)
    {
      if ((retValue = -44) and (davEntry[9] = 'text/turtle'))
        DB.DBA.S3__activity (detcol_id, davEntry[0] || ': turtle content is wrong.');

      if (length (content) > 10485760)  -- 10MB
        log_enable (0, 1);

      update WS.WS.SYS_DAV_RES set RES_CONTENT = content where RES_ID = id;
      DB.DBA.S3__paramRemove (download[0], download[1], 'download');

      oEntry := DB.DBA.S3__paramGet (download[0], download[1], 'Entry', 0);
      if (oEntry is not null)
      {
        oEntry := xtree_doc (oEntry);
        DB.DBA.DAV_DET_ENTRY_XUPDATE (oEntry, 'amz-server-side-encryption', http_request_header (retHeader, 'x-amz-server-side-encryption', null, null));
        DB.DBA.DAV_DET_ENTRY_XUPDATE (oEntry, 'amz-request-id', http_request_header (retHeader, 'x-amz-request-id', null, null));
        DB.DBA.DAV_DET_ENTRY_XUPDATE (oEntry, 'amz-id-2', http_request_header (retHeader, 'x-amz-id-2', null, null));
        DB.DBA.DAV_DET_ENTRY_XUPDATE (oEntry, 'etag', http_request_header (retHeader, 'ETag', null, null));
        DB.DBA.S3__paramSet (download[0], download[1], 'Entry', DB.DBA.DAV_DET_XML2STRING (oEntry), 0);
      }
      items := vector_concat (items, vector (download));
      goto _continue;
    }

  _error:;
    downloaded := downloaded + 1;
    DB.DBA.S3__paramSet (download[0], download[1], 'download', cast (downloaded as varchar), 0);

  _continue:;
    commit work;
  }
  DB.DBA.S3__activity (detcol_id, sprintf ('Downloaded %d file(s)', length (items)));
  foreach (any item in items) do
  {
    DB.DBA.DAV_DET_RDF_DELETE (DB.DBA.S3__detName (), detcol_id, item[0], item[1]);
    DB.DBA.DAV_DET_RDF_INSERT (DB.DBA.S3__detName (), detcol_id, item[0], item[1]);
  }
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__refresh (
  in path varchar)
{
  return DB.DBA.DAV_DET_REFRESH (DB.DBA.S3__detName (), path);
}
;
