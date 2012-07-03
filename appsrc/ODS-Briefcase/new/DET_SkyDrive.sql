--
--  $Id: DET_SkyDrive.sql,v 1.1 2012/06/04 16:33:18 ddimitrov Exp $
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

use DB
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "SkyDrive_DAV_AUTHENTICATE" (
  in id any,
  in what char(1),
  in req varchar,
  in auth_uname varchar,
  in auth_pwd varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('SkyDrive_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
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
create function "SkyDrive_DAV_AUTHENTICATE_HTTP" (
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
  -- dbg_obj_princ ('SkyDrive_DAV_AUTHENTICATE_HTTP (', id[2], what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare retValue any;

  retValue := DAV_AUTHENTICATE_HTTP (id[2], what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);

  return retValue;
}
;

--| This should return ID of the collection that contains resource or collection with given ID,
--| Possible ambiguity (such as symlinks etc.) should be resolved by using path.
--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "SkyDrive_DAV_GET_PARENT" (
  in id any,
  in what char(1),
  in path varchar) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_GET_PARENT (', id, what, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "SkyDrive_DAV_COL_CREATE" (
  in detcol_id any,
  in path_parts any,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in extern integer := 0) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, extern, ')');
  declare ouid, ogid integer;
  declare title, parentID, parentListID, listID, listItem varchar;
  declare url, body, header any;
  declare retValue, retHeader, result, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  if (save is null)
  {
    title := path_parts[length (path_parts)-2];
    parentListID := DB.DBA.SkyDrive__root ();
    if (length (path_parts) > 2)
    {
      parentID := DB.DBA.DAV_SEARCH_ID (DB.DBA.SkyDrive__path (detcol_id, path_parts), 'P');
      parentListID := DB.DBA.SkyDrive__paramGet (parentID, 'C', 'id', 0);
    }
    body := sprintf ('{name: "%s"}', title);
    header := sprintf (
      'Content-Length: %d\r\n' ||
      'Content-Type: application/json\r\n',
      length (body));
    url := sprintf ('https://apis.live.net/v5.0/%U', parentListID);
    result := DB.DBA.SkyDrive__exec (detcol_id, retHeader, 'POST', url, header, body);
    if (DAV_HIDE_ERROR (result) is null)
    {
      retValue := result;
      goto _exit;
    }
    listItem := ODS..json2obj (result);
    listID := get_keyword ('id', listItem);
  }
  connection_set ('dav_store', 1);
  DB.DBA.SkyDrive__owner (detcol_id, path_parts, DB.DBA.SkyDrive__user (uid, auth_uid), DB.DBA.SkyDrive__user (gid, auth_uid), ouid, ogid);
  retValue := DAV_COL_CREATE_INT (DB.DBA.SkyDrive__path (detcol_id, path_parts), permissions, DB.DBA.SkyDrive__user (uid, auth_uid), DB.DBA.SkyDrive__user (gid, auth_uid), DB.DBA.SkyDrive__user (http_dav_uid ()), DB.DBA.SkyDrive__password (http_dav_uid ()), 1, 0, 1, ouid, ogid);

_exit:;
  connection_set ('dav_store', save);
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    if (save is null)
    {
      DB.DBA.SkyDrive__paramSet (retValue, 'C', 'Entry', DB.DBA.SkyDrive__obj2xml (listItem), 0);
      DB.DBA.SkyDrive__paramSet (retValue, 'C', 'id', listID, 0);
    }
    DB.DBA.SkyDrive__paramSet (retValue, 'C', 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
    retValue := vector (DB.DBA.SkyDrive__detName (), detcol_id, retValue, 'C');
  }

  return retValue;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "SkyDrive_DAV_COL_MOUNT" (
  in detcol_id any,
  in path_parts any,
  in full_mount_path varchar,
  in mount_det varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "SkyDrive_DAV_COL_MOUNT_HERE" (
  in parent_id any,
  in full_mount_path varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "SkyDrive_DAV_DELETE" (
  in detcol_id any,
  in path_parts any,
  in what char(1),
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('SkyDrive_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  declare path, listId varchar;
  declare retValue, save any;
  declare id, url, header, retHeader, params any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.SkyDrive__path (detcol_id, path_parts);
  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (save is null)
  {
    listId := DB.DBA.SkyDrive__paramGet (id, what, 'id', 0);
    header := null;
    url := sprintf ('https://apis.live.net/v5.0/%s', listId);
    retValue := DB.DBA.SkyDrive__exec (detcol_id, retHeader, 'DELETE', url, header);
    if (DAV_HIDE_ERROR (retValue) is null)
      goto _exit;
  }
  connection_set ('dav_store', 1);
  if (what = 'R')
    DB.DBA.SkyDrive__rdf_delete (detcol_id, id, what);
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
create function "SkyDrive_DAV_RES_UPLOAD" (
  in detcol_id any,
  in path_parts any,
  inout content any,
  in type varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  declare ouid, ogid integer;
  declare name, path, parentID, parentListID, listID, listItem, rdf_graph varchar;
  declare url, body, header any;
  declare url, header, body, params any;
  declare retValue, retHeader, result, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  path := DB.DBA.SkyDrive__path (detcol_id, path_parts);
  if (save is null)
  {
    if (__tag (content) = 126)
    {
      declare real_content any;

      real_content := http_body_read (1);
      content := string_output_string (real_content);  -- check if bellow code can work with string session and if so remove this line
    }
    name := path_parts[length (path_parts)-1];
    parentListID := DB.DBA.SkyDrive__root ();
    if (length (path_parts) > 2)
    {
      parentID := DB.DBA.DAV_SEARCH_ID (DB.DBA.SkyDrive__path (detcol_id, path_parts), 'P');
      parentListID := DB.DBA.SkyDrive__paramGet (parentID, 'C', 'id', 0);
    }
    url := sprintf ('https://apis.live.net/v5.0/%s/files/%U', parentListID, name);
    result := DB.DBA.SkyDrive__exec (detcol_id, retHeader, 'PUT', url, null, blob_to_string (content));
    if (DAV_HIDE_ERROR (result) is null)
    {
      retValue := result;
      goto _exit;
    }
    listItem := ODS..json2obj (result);
    listID := get_keyword ('id', listItem);
  }
_skip_create:;
  connection_set ('dav_store', 1);
  DB.DBA.SkyDrive__owner (detcol_id, path_parts, DB.DBA.SkyDrive__user (uid, auth_uid), DB.DBA.SkyDrive__user (gid, auth_uid), ouid, ogid);
  retValue := DAV_RES_UPLOAD_STRSES_INT (path, content, type, permissions, DB.DBA.SkyDrive__user (uid, auth_uid), DB.DBA.SkyDrive__user (gid, auth_uid), DB.DBA.SkyDrive__user (http_dav_uid ()), DB.DBA.SkyDrive__password (http_dav_uid ()), 0, ouid=>ouid, ogid=>ogid, check_locks=>0);

_exit:;
  connection_set ('dav_store', save);
  if (DAV_HIDE_ERROR (retValue) is not null)
  {
    rdf_graph := DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'graph', 0);
    if (not DB.DBA.is_empty_or_null (rdf_graph))
      DB.DBA.SkyDrive__rdf (detcol_id, retValue, 'R');

    if (save is null)
    {
      DB.DBA.SkyDrive__paramSet (retValue, 'R', 'Entry', DB.DBA.SkyDrive__obj2xml (listItem), 0);
      DB.DBA.SkyDrive__paramSet (retValue, 'R', 'id', listID, 0);
    }
    DB.DBA.SkyDrive__paramSet (retValue, 'R', 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
    retValue := vector (DB.DBA.SkyDrive__detName (), detcol_id, retValue, 'C');
  }
  return retValue;
}
;

--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not (when an error in returned if name is system) is _not_ permitted.
--| It should delete any dead property even if the name looks like system name.
create function "SkyDrive_DAV_PROP_REMOVE" (
  in id any,
  in what char(0),
  in propname varchar,
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('SkyDrive_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_REMOVE_RAW (id[2], what, propname, silent, auth_uid);

  return retValue;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "SkyDrive_DAV_PROP_SET" (
  in id any,
  in what char(0),
  in propname varchar,
  in propvalue any,
  in overwrite integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  declare retValue any;

  id := id[2];
  retValue := DB.DBA.DAV_PROP_SET_RAW (id, what, propname, propvalue, 1, http_dav_uid ());

  return retValue;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "SkyDrive_DAV_PROP_GET" (
  in id any,
  in what char(0),
  in propname varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('SkyDrive_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_GET_INT (id[2], what, propname, 0);

  return retValue;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "SkyDrive_DAV_PROP_LIST" (
  in id any,
  in what char(0),
  in propmask varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('SkyDrive_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  declare retValue any;

  retValue := DAV_PROP_LIST_INT (id[2], what, propmask, 0);

  return retValue;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "SkyDrive_DAV_DIR_SINGLE" (
  in id any,
  in what char(0),
  in path any,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  retValue := DAV_DIR_SINGLE_INT (id[2], what, null, DB.DBA.SkyDrive__user (http_dav_uid ()), DB.DBA.SkyDrive__password (http_dav_uid ()), http_dav_uid ());
  connection_set ('dav_store', save);
  if ((DAV_HIDE_ERROR (retValue) is not null) and (save is null))
    retValue[4] := vector (DB.DBA.SkyDrive__detName (), id[1], retValue[4], what);

  return retValue;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "SkyDrive_DAV_DIR_LIST" (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  in name_mask varchar,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_DIR_LIST (', detcol_id, subPath_parts, detcol_parts, name_mask, recursive, auth_uid, ')');
  declare colId integer;
  declare what, colPath varchar;
  declare retValue, save, downloads, listItems, davItems, colEntry, xmlItems, davEntry, listIds, listId any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', null);
  what := case when ((length (subPath_parts) = 0) or (subPath_parts[length (subPath_parts) - 1] = '')) then 'C' else 'R' end;
  if ((what = 'R') or (recursive = -1))
    return DB.DBA.SkyDrive_DAV_DIR_SINGLE (detcol_id, what, null, auth_uid);

  colPath := DB.DBA.DAV_CONCAT_PATH (detcol_parts, subPath_parts);
  colId := DB.DBA.DAV_SEARCH_ID (colPath, 'C');

  downloads := vector ();
  listItems := DB.DBA.SkyDrive__list (detcol_id, detcol_parts, subPath_parts);
  if (DAV_HIDE_ERROR (listItems) is null)
    goto _exit;

  if (isinteger (listItems))
    goto _exit;

  DB.DBA.SkyDrive__activity (detcol_id, 'Sync started');
  {
    declare _id, _what, _type, _content any;
    declare title varchar;
    {
      declare exit handler for sqlstate '*'
      {
        DB.DBA.SkyDrive__activity (detcol_id, 'Exec error: ' || __SQL_MESSAGE);
        goto _exitSync;
      };

      connection_set ('dav_store', 1);
      colEntry := DB.DBA.DAV_DIR_SINGLE_INT (colId, 'C', '', null, null, http_dav_uid ());
      listItems := subseq (ODS..json2obj (listItems), 2);
      listItems := get_keyword ('data', listItems);
      listIds := vector ();
      davItems := DB.DBA.SkyDrive__davList (detcol_id, colId);
      foreach (any davItem in davItems) do
      {
        listID := DB.DBA.SkyDrive__paramGet (davItem[4], davItem[1], 'id', 0);
        foreach (any listItem in listItems) do
        {
          title := get_keyword ('name', listItem);
          if ((listID = get_keyword ('id', listItem)) and (title = davItem[10]))
          {
            davEntry := DB.DBA.SkyDrive__paramGet (davItem[4], davItem[1], 'Entry', 0);
            if (davEntry is not null)
            {
              listIds := vector_concat (listIds, vector (listID));
              davEntry := xtree_doc (davEntry);
              if (DB.DBA.SkyDrive__entryXPath (davEntry, '/updated_time', 1) <> get_keyword ('updated_time', listItem))
              {
                set triggers off;
                DB.DBA.SkyDrive__paramSet (davItem[4], davItem[1], ':getlastmodified', DB.DBA.SkyDrive__stringdate (get_keyword ('updated_time', listItem)), 0, 0);
                set triggers on;
                DB.DBA.SkyDrive__paramSet (davItem[4], davItem[1], 'Entry', DB.DBA.SkyDrive__obj2xml (listItem), 0);
                if (davItem[1] = 'R')
                {
                  DB.DBA.SkyDrive__paramSet (davItem[4], davItem[1], 'download', '0', 0);
                  downloads := vector_concat (downloads, vector (vector (davItem[4], davItem[1])));
                }
              }
              else
              {
                declare downloaded integer;

                downloaded := DB.DBA.SkyDrive__paramGet (davItem[4], davItem[1], 'download', 0);
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
          DB.DBA.SkyDrive__rdf_delete (detcol_id, davItem[4], davItem[1]);
        DAV_DELETE_INT (davItem[0], 1, null, null, 0, 0);

      _continue:;
        commit work;
      }
      foreach (any listItem in listItems) do
      {
        listID := get_keyword ('id', listItem);
        if (not position (listID, listIDs))
        {
          title := get_keyword ('name', listItem);
          connection_set ('dav_store', 1);
          if (get_keyword ('type', listItem) in ('folder', 'album'))
          {
            _id := DB.DBA.DAV_COL_CREATE (colPath || title || '/',  colEntry[5], colEntry[7], colEntry[6], DB.DBA.SkyDrive__user (http_dav_uid ()), DB.DBA.SkyDrive__password (http_dav_uid ()));
            _what := 'C';
          }
          else
          {
            _content := '';
            _type := http_mime_type (title);
            _id := DB.DBA.DAV_RES_UPLOAD (colPath || title,  _content, _type, colEntry[5], colEntry[7], colEntry[6], DB.DBA.SkyDrive__user (http_dav_uid ()), DB.DBA.SkyDrive__password (http_dav_uid ()));
            _what := 'R';
          }
          if (DAV_HIDE_ERROR (_id) is not null)
          {
            set triggers off;
            DB.DBA.SkyDrive__paramSet (_id, _what, ':creationdate', DB.DBA.SkyDrive__stringdate (get_keyword ('created_time', listItem)), 0, 0);
            DB.DBA.SkyDrive__paramSet (_id, _what, ':getlastmodified', DB.DBA.SkyDrive__stringdate (get_keyword ('updated_time', listItem)), 0, 0);
            set triggers on;
            DB.DBA.SkyDrive__paramSet (_id, _what, 'virt:DETCOL_ID', cast (detcol_id as varchar), 0, 0);
            DB.DBA.SkyDrive__paramSet (_id, _what, 'id', listID, 0);
            DB.DBA.SkyDrive__paramSet (_id, _what, 'Entry', DB.DBA.SkyDrive__obj2xml (listItem), 0);
            if (_what = 'R')
            {
              DB.DBA.SkyDrive__paramSet (_id, _what, 'download', '0', 0);
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
  DB.DBA.SkyDrive__activity (detcol_id, 'Sync ended');

_exit:;
  retValue := DB.DBA.SkyDrive__davList (detcol_id, colId);
  DB.DBA.SkyDrive__downloads (detcol_id, downloads);

  return retValue;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "SkyDrive_DAV_DIR_FILTER" (
  in detcol_id any,
  in subPath_parts any,
  in detcol_parts varchar,
  inout compilation any,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_DIR_FILTER (', detcol_id, subPath_parts, detcol_parts, compilation, recursive, auth_uid, ')');
  return vector();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "SkyDrive_DAV_SEARCH_ID" (
  in detcol_id any,
  in path_parts any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  declare retValue, save any;
  declare exit handler for sqlstate '*'
  {
    connection_set ('dav_store', save);
    resignal;
  };

  save := connection_get ('dav_store');
  connection_set ('dav_store', 1);
  retValue := DAV_SEARCH_ID (DB.DBA.SkyDrive__path (detcol_id, path_parts), what);
  connection_set ('dav_store', save);
  if ((DAV_HIDE_ERROR (retValue) is not null))
  {
    if (isinteger (retValue) and (save is null))
      retValue := vector (DB.DBA.SkyDrive__detName (), detcol_id, retValue, what);

    else if (isarray (retValue) and (save = 1))
      retValue := retValue[2];
  }
  return retValue;
}
;

create function "SkyDrive_DAV_MAKE_ID" (
  in detcol_id any,
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_MAKE_ID (', id, what, ')');
  declare retValue any;

  retValue := vector (DB.DBA.SkyDrive__detName (), detcol_id, id, what);

  return retValue;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "SkyDrive_DAV_SEARCH_PATH" (
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_SEARCH_PATH (', id, what, ')');
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
create function "SkyDrive_DAV_RES_UPLOAD_COPY" (
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
  -- dbg_obj_princ ('SkyDrive_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "SkyDrive_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "SkyDrive_DAV_RES_CONTENT" (
  in id any,
  inout content any,
  out type varchar,
  in content_mode integer) returns integer
{
  -- dbg_obj_princ ('SkyDrive_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare retValue any;

  retValue := DAV_RES_CONTENT_INT (id[2], content, type, content_mode, 0);

  return retValue;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "SkyDrive_DAV_SYMLINK" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite integer,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "SkyDrive_DAV_DEREFERENCE_LIST" (
  in detcol_id any,
  inout report_array any) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "SkyDrive_DAV_RESOLVE_PATH" (
  in detcol_id any,
  inout reference_item any,
  inout old_base varchar,
  inout new_base varchar) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "SkyDrive_DAV_LOCK" (
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
  -- dbg_obj_princ ('SkyDrive_DAV_LOCK (', path, id, what, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
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
  retValue := DAV_LOCK_INT (path, davId, what, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, DB.DBA.SkyDrive__user (auth_uid), DB.DBA.SkyDrive__password (auth_uid), auth_uid);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "SkyDrive_DAV_UNLOCK" (
  in id any,
  in what char(1),
  in token varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('SkyDrive_DAV_UNLOCK (', id, what, token, auth_uid, ')');
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
  retValue := DAV_UNLOCK_INT (davId, what, token, DB.DBA.SkyDrive__user (auth_uid), DB.DBA.SkyDrive__password (auth_uid), auth_uid);
  connection_set ('dav_store', save);

  return retValue;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "SkyDrive_DAV_IS_LOCKED" (
  inout id any,
  inout what char(1),
  in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('SkyDrive_DAV_IS_LOCKED (', id, what, owned_tokens, ')');
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
create function "SkyDrive_DAV_LIST_LOCKS" (
  in id any,
  in what char(1),
  in recursive integer) returns any
{
  -- dbg_obj_princ ('SkyDrive_DAV_LIST_LOCKS" (', id, what, recursive);
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
create function DB.DBA.SkyDrive__root ()
{
  return 'me/skydrive';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__fileDebug (
  in value any,
  in mode integer := -1)
{
  string_to_file ('skydrive.txt', cast (value as varchar) || '\r\n', mode);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__detcolId (
  in id any)
{
  if (isinteger (id))
    return id;

  return id[1];
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__davId (
  in id any)
{
  if (isinteger (id))
    return id;

  return id[2];
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__stringdate (
  in dt varchar)
{
	declare N integer;
	declare rs, tzone, tzone_z, tzone_h, tzone_m any;

	rs := stringdate (subseq (dt, 0, 19));
	if (length (dt) > 19)
	{
		tzone   := subseq (dt, 19);
		tzone_z := substring (tzone, 1, 1);
		tzone_h := atoi (substring (tzone, 2, 2));
		tzone_m := atoi (substring (tzone, 4, 2));
	  if (tzone_z = '+')
	  {
	    tzone_h := tzone_h - 2 * tzone_h;
	    tzone_m := tzone_m - 2 * tzone_m;
		}
	  rs := dateadd ('hour',   tzone_h, rs);
	  rs := dateadd ('minute', tzone_m, rs);
	}
	return rs;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__user (
  in user_id integer,
  in default_id integer := null)
{
  return coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = coalesce (user_id, default_id)), '');
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__password (
  in user_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = user_id), '');
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__owner (
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
    path := DB.DBA.SkyDrive__path (detcol_id, subPath_parts);
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
create function DB.DBA.SkyDrive__detName ()
{
  return UNAME'SkyDrive';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__xml2string (
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
create function DB.DBA.SkyDrive__path (
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
create function DB.DBA.SkyDrive__params (
  in colId integer)
{
  declare tmp, params any;

  colId := DB.DBA.SkyDrive__detcolId (colId);
  tmp := DB.DBA.SkyDrive__paramGet (colId, 'C', 'Authentication', 0);
  if (tmp = 'Yes')
  {
    params := vector (
      'authentication',       tmp,
      'access_timestamp',     stringdate (DB.DBA.SkyDrive__paramGet (colId, 'C', 'access_timestamp', 0)),
      'access_token',         DB.DBA.SkyDrive__paramGet (colId, 'C', 'access_token', 0, 1, 1),
      'token_type',           DB.DBA.SkyDrive__paramGet (colId, 'C', 'token_type', 0),
      'expires_in',           cast (DB.DBA.SkyDrive__paramGet (colId, 'C', 'expires_in', 0) as integer),
      'refresh_token',        DB.DBA.SkyDrive__paramGet (colId, 'C', 'refresh_token', 0, 1, 1),
      'authentication_token', DB.DBA.SkyDrive__paramGet (colId, 'C', 'authentication_token', 0, 1, 1),
      'graph',                DB.DBA.SkyDrive__paramGet (colId, 'C', 'graph', 0)
    );
  }
  else
  {
    params := vector ('authentication', 'No');
  }
  return params;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__paramSet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _propValue any,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _encrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__paramSet', _propName, _propValue, ')');
  declare retValue any;

  if (_serialized)
    _propValue := serialize (_propValue);

  if (_encrypt)
    _propValue := pwd_magic_calc ('skydrive', _propValue);

  if (_prefixed)
    _propName := 'virt:SkyDrive-' || _propName;

  _id := DB.DBA.SkyDrive__davId (_id);
  retValue := DB.DBA.DAV_PROP_SET_RAW (_id, _what, _propName, _propValue, 1, http_dav_uid ());

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__paramGet (
  in _id integer,
  in _what varchar,
  in _propName varchar,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _decrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__paramGet (', _id, _what, _propName, ')');
  declare propValue any;

  if (_prefixed)
    _propName := 'virt:SkyDrive-' || _propName;

  propValue := DB.DBA.DAV_PROP_GET_INT (DB.DBA.SkyDrive__davId (_id), _what, _propName, 0, DB.DBA.Dropbox__user (http_dav_uid ()), DB.DBA.Dropbox__password (http_dav_uid ()), http_dav_uid ());
  if (isinteger (propValue))
    propValue := null;

  if (_serialized and not isnull (propValue))
    propValue := deserialize (propValue);

  if (_decrypt and not isnull (propValue))
    propValue := pwd_magic_calc ('skydrive', propValue, 1);

  return propValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__paramRemove (
  in _id integer,
  in _what varchar,
  in _propName varchar,
  in _prefixed integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__paramRemove (', _id, _what, _propName, ')');
  if (_prefixed)
    _propName := 'virt:SkyDrive-' || _propName;

  DB.DBA.DAV_PROP_REMOVE_RAW (DB.DBA.SkyDrive__davId (_id), _what, _propName, 1, http_dav_uid());
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__obj2xml (
  in item any)
{
  return '<entry>' || ODS..obj2xml (item, 10) || '</entry>';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__entryXPath (
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
create function DB.DBA.SkyDrive__exec_error (
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
create function DB.DBA.SkyDrive__exec_code (
  in _header any)
{
  return subseq (_header[0], 9, 12);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__exec (
  inout detcol_id integer,
  inout retHeader varchar,
  in method varchar,
  in url varchar,
  in header varchar := '',
  in content varchar := '')
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__exec', detcol_id, method, url, header, ')');
  declare retValue, params any;
  declare _client_id, _client_secret, _return_url varchar;
  declare _expires_in, _access_timestamp, _token_type, _refresh_token any;
  declare tmp, _json, _prefix, _reqHeader, _resHeader, _body any;
  declare exit handler for sqlstate '*'
  {
    DB.DBA.SkyDrive__activity (detcol_id, 'Exec error: ' || __SQL_MESSAGE);
    return -28;
  };

  params := DB.DBA.SkyDrive__params (detcol_id);
  if (get_keyword ('authentication', params) <> 'Yes')
  {
    DB.DBA.SkyDrive__activity (detcol_id, 'Error: Not authenticated');
    return -28;
  }

  _expires_in := get_keyword ('expires_in', params);
  _access_timestamp := get_keyword ('access_timestamp', params);
  if (dateadd ('second', _expires_in, _access_timestamp) < now ())
  {
    -- refresh token first

    _client_id := (select a_key from OAUTH..APP_REG where a_name = 'SkyDrive API' and a_owner = 0);
    _client_secret := (select a_secret from OAUTH..APP_REG where a_name = 'SkyDrive API' and a_owner = 0);
    _return_url := sprintf ('http://%{WSHost}s/ods/access_skydrive.vsp', http_path());
    _refresh_token := get_keyword ('refresh_token', params);
    _reqHeader := null;
    _resHeader := null;
    _body := sprintf ('client_id=%U&client_secret=%U&redirect_uri=%U&refresh_token=%U&grant_type=%U', _client_id, _client_secret, _return_url, _refresh_token, 'refresh_token');
    _json := http_client_ext (url=>'https://login.live.com/oauth20_token.srf', http_method=>'POST', http_headers=>_reqHeader, headers =>_resHeader, body=>_body, n_redirects=>15);
    if (not DB.DBA.SkyDrive__exec_error (_resHeader, 1))
      return -28;

    tmp := subseq (ODS..json2obj(_json), 2);
    DB.DBA.SkyDrive__paramSet (detcol_id, 'C', 'access_timestamp', datestring (now ()), 0);
    DB.DBA.SkyDrive__paramSet (detcol_id, 'C', 'access_token', get_keyword ('access_token', tmp), 0, 1, 1);
    DB.DBA.SkyDrive__paramSet (detcol_id, 'C', 'token_type', get_keyword ('token_type', tmp), 0);
    DB.DBA.SkyDrive__paramSet (detcol_id, 'C', 'expires_in', cast (get_keyword ('expires_in', tmp) as varchar), 0);
    params := DB.DBA.SkyDrive__params (detcol_id);
  }

  _reqHeader := sprintf ('Authorization: %s %s\r\n', initcap (get_keyword ('token_type', params, 'bearer')), get_keyword ('access_token', params));
  if (header <> '')
    _reqHeader :=  _reqHeader || header;

  retHeader := null;
  retValue := http_client_ext (url=>url, http_method=>method, http_headers=>_reqHeader, headers =>retHeader, body=>content, n_redirects=>15);
  -- dbg_obj_print ('retValue', DB.DBA.SkyDrive__exec_code (retHeader), url, method);
  if (not DB.DBA.SkyDrive__exec_error (retHeader, 1))
  {
    DB.DBA.SkyDrive__activity (detcol_id, 'HTTP error: ' || retValue);
    return -28;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__davList (
  inout detcol_id integer,
  inout colId integer)
{
  declare retValue any;

  vectorbld_init (retValue);
  for (select vector (RES_FULL_PATH,
                      'R',
                      length (RES_CONTENT),
                      RES_MOD_TIME,
                      vector (DB.DBA.SkyDrive__detName (), detcol_id, RES_ID, 'R'),
                      RES_PERMS,
                      RES_GROUP,
                      RES_OWNER,
                      RES_CR_TIME,
                      RES_TYPE,
                      RES_NAME ) as I
         from WS.WS.SYS_DAV_RES
        where RES_COL = DB.DBA.SkyDrive__davId (colId)) do
  {
    vectorbld_acc (retValue, i);
  }

  for (select vector (WS.WS.COL_PATH (COL_ID),
                      'C',
                      0,
                      COL_MOD_TIME,
                      vector (DB.DBA.SkyDrive__detName (), detcol_id, COL_ID, 'C'),
                      COL_PERMS,
                      COL_GROUP,
                      COL_OWNER,
                      COL_CR_TIME,
                      'dav/unix-directory',
                      COL_NAME) as I
        from WS.WS.SYS_DAV_COL
       where COL_PARENT = DB.DBA.SkyDrive__davId (colId)) do
  {
    vectorbld_acc (retValue, i);
  }

  vectorbld_final (retValue);
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__list (
  inout detcol_id any,
  inout detcol_parts varchar,
  inout subPath_parts varchar)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__list (', detcol_id, detcol_parts, subPath_parts, ')');
  declare colId integer;
  declare colPath, listId varchar;
  declare syncTime datetime;
  declare retValue, retHeader, value, entry any;

  colPath := DB.DBA.DAV_CONCAT_PATH (detcol_parts, subPath_parts);
  colId := DB.DBA.SkyDrive__davId (DB.DBA.DAV_SEARCH_ID (colPath, 'C'));
  if (DAV_HIDE_ERROR (colId) is null)
    return -28;

  syncTime := DB.DBA.SkyDrive__paramGet (colId, 'C', 'syncTime');
  if (not isnull (syncTime) and (datediff ('second', syncTime, now ()) < 300))
    return 0;

  if (length (subPath_parts) = 1)
  {
    listId := DB.DBA.SkyDrive__root ();
  }
  else
  {
    listId := DB.DBA.SkyDrive__paramGet (colId, 'C', 'id', 0);
    if (isnull (listId))
      return -28;
  }
  retValue := DB.DBA.SkyDrive__exec (detcol_id, retHeader, 'GET', sprintf ('https://apis.live.net/v5.0/%s/files', listId));
  -- dbg_obj_print ('retValue', retValue);
  if (not isinteger (retValue))
    DB.DBA.SkyDrive__paramSet (colId, 'C', 'syncTime', now ());

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__activity (
  in detcol_id integer,
  in text varchar)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__activity (', detcol_id, text, ')');
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
  activity := DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'activity', 0);
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
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (activityPath, activityContent, activityType, '110100000RR', DB.DBA.SkyDrive__user (davEntry[6]), DB.DBA.SkyDrive__user (davEntry[7]), extern=>0, check_locks=>0);
  commit work;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__downloads (
  in detcol_id integer,
  in downloads any)
{
  declare aq any;

  if (length (downloads) = 0)
    return;

  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.SkyDrive__downloads_aq', vector (detcol_id, downloads));
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__downloads_aq (
  in detcol_id integer,
  in downloads any)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__downloads_aq (', detcol_id, downloads, ')');
  declare N, downloaded integer;
  declare url, listID varchar;
  declare items any;
  declare retValue, retHeader any;

  set_user_id ('dba');
  N := 0;
  items := vector ();
  DB.DBA.SkyDrive__activity (detcol_id, sprintf ('Downloading %d file(s)', length (downloads)));
  foreach (any download in downloads) do
  {
    downloaded := DB.DBA.SkyDrive__paramGet (download[0], download[1], 'download', 0);
    if (downloaded is null)
      goto _continue;

    downloaded := cast (downloaded as integer);
    if (downloaded > 5)
      goto _continue;

    listID := DB.DBA.SkyDrive__paramGet (download[0], download[1], 'id', 0);
    if (listID is null)
      goto _continue;

    url := sprintf ('https://apis.live.net/v5.0/%s/content', listID);
    retValue := DB.DBA.SkyDrive__exec (detcol_id, retHeader, 'GET', url);
    if (DAV_HIDE_ERROR (retValue) is null)
    {
      downloaded := downloaded + 1;
      DB.DBA.SkyDrive__paramSet (download[0], download[1], 'download', cast (downloaded as varchar), 0);
    }
    else
    {
      update WS.WS.SYS_DAV_RES set RES_CONTENT = retValue where RES_ID = DB.DBA.SkyDrive__davId (download[0]);
      DB.DBA.SkyDrive__paramRemove (download[0], download[1], 'download');
      items := vector_concat (items, vector (download));
      N := N + 1;
    }
    commit work;

  _continue:;
  }
  DB.DBA.SkyDrive__activity (detcol_id, sprintf ('Downloaded %d file(s)', N));
  foreach (any item in items) do
  {
    DB.DBA.SkyDrive__rdf_delete (detcol_id, item[0], item[1]);
    DB.DBA.SkyDrive__rdf_insert (detcol_id, item[0], item[1]);
  }
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__rdf (
  in detcol_id integer,
  in id any,
  in what varchar)
{
  declare aq any;

  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.SkyDrive__rdf_aq', vector (detcol_id, id, what));
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__rdf_aq (
  in detcol_id integer,
  in id any,
  in what varchar)
{
  DB.DBA.SkyDrive__rdf_delete (detcol_id, id, what);
  DB.DBA.SkyDrive__rdf_insert (detcol_id, id, what);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__rdf_insert (
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_graph varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__rdf_insert (', detcol_id, id, what, rdf_graph, ')');
  declare permissions, rdf_graph2 varchar;
  declare rdf_sponger, rdf_cartridges, rdf_metaCartridges any;
  declare path, content, type any;
  declare exit handler for sqlstate '*'
  {
    return;
  };

  if (isnull (rdf_graph))
    rdf_graph := DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'graph', 0);

  if (DB.DBA.is_empty_or_null (rdf_graph))
    return;

  permissions := DB.DBA.SkyDrive__paramGet (detcol_id, 'C', ':virtpermissions', 0, 0);
  if (permissions[6] = ascii('0'))
  {
    -- add to private graphs
    if (not SIOC..private_graph_check (rdf_graph))
      return;
  }

  id := DB.DBA.SkyDrive__davId (id);
  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  content := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = id);
  type := (select RES_TYPE from WS.WS.SYS_DAV_RES where RES_ID = id);
  rdf_sponger := coalesce (DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'sponger', 0), 'on');
  rdf_cartridges := coalesce (DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'cartridges', 0), '');
  rdf_metaCartridges := coalesce (DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'metaCartridges', 0), '');

  RDF_SINK_UPLOAD (path, content, type, rdf_graph, rdf_sponger, rdf_cartridges, rdf_metaCartridges);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SkyDrive__rdf_delete (
  in detcol_id integer,
  in id any,
  in what varchar,
  in rdf_graph varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.SkyDrive__rdf_delete (', detcol_id, id, what, rdf_graph, ')');
  declare rdf_graph2 varchar;
  declare path varchar;

  if (isnull (rdf_graph))
    rdf_graph := DB.DBA.SkyDrive__paramGet (detcol_id, 'C', 'graph', 0);

  if (DB.DBA.is_empty_or_null (rdf_graph))
    return;

  path := DB.DBA.DAV_SEARCH_PATH (id, what);
  if (path like '%.gz')
    path := regexp_replace (path, '\.gz\x24', '');

  rdf_graph2 := 'http://local.virt' || path;
  SPARQL delete from graph ?:rdf_graph { ?s ?p ?o } where { graph `iri(?:rdf_graph2)` { ?s ?p ?o } };
  SPARQL clear graph ?:rdf_graph2;
}
;
