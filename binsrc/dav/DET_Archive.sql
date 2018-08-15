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

use DB
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "Archive_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Archive_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  if (auth_uid >= 0)
    return auth_uid;
  if (not ('100' like req))
    return -13;
  if (id[2] is null)
    return DAV_AUTHENTICATE (id[1], 'C', req, auth_uname, auth_pwd, auth_uid);
  return DAV_AUTHENTICATE (id[2], 'R', req, auth_uname, auth_pwd, auth_uid);
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "Archive_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  -- dbg_obj_princ ('Archive_DAV_AUTHENTICATE_HTTP (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  if (not ('100' like req))
    return -13;
  if (id[2] is null)
    return DAV_AUTHENTICATE_HTTP (id[1], 'C', req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);
  return DAV_AUTHENTICATE_HTTP (id[2], 'R', req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);
}
;


--| This should return ID of the collection that contains resource or collection with given ID,
--| Possible ambiguity (such as symlinks etc.) should be resolved by using path.
--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "Archive_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('Archive_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "Archive_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "Archive_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "Archive_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "Archive_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('Archive_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "Archive_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not (when an error in returned if name is system) is _not_ permitted.
--| It should delete any dead property even if the name looks like system name.
create function "Archive_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('Archive_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "Archive_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "Archive_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Archive_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "Archive_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Archive_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

create function "Archive_FIND_CAT_RECORD" (in cattree any, inout path_parts any, in cut_children integer := 0) returns any
{
  declare depth, max_depth, idx, len integer;
  -- dbg_obj_princ ('Archive_FIND_CAT_RECORD (', cattree, path_parts, cut_children, ')');
  max_depth := length (path_parts);
  for (depth := 0; depth < max_depth; depth := depth + 1)
    {
      declare locname varchar;
      locname := path_parts [depth];
      if (depth = max_depth - 1)
        {
          if (locname = '')
            {
              -- dbg_obj_princ ('will return collection ', cattree);
              if (cut_children)
                return subseq (cattree, 0, 4);
              return cattree;
            }
          len := length (cattree[5]);
          for (idx := 0; idx < len; idx := idx + 1)
            {
              if (cattree[5][idx][0] = locname)
                {
                  -- dbg_obj_princ ('will return resource ', cattree[5][idx]);
                  return cattree[5][idx];
                }
            }
          return null;
        }
      len := length (cattree[4]);
      for (idx := 0; idx < len; idx := idx + 1)
        {
          if (cattree[4][idx][0] = locname)
            {
              cattree := cattree[4][idx];
              -- dbg_obj_princ ('will search in collection ', cattree);
              goto sub_found;
            }
        }
      return null;
sub_found: ;
    }
}
;


create function "Archive_ID_TO_DIR_ENTRY" (in id any, inout path_parts any) returns any
{
  declare detcol_id any;
  declare parent_full_path, perms varchar;
  declare source_dir_single any;
  -- dbg_obj_princ ('Archive_ID_TO_DIR_ENTRY (', id, path_parts, ')');
  source_dir_single := DAV_DIR_SINGLE_INT (id[2], 'R', '/FAKE/');
  perms := source_dir_single[5];
  perms := sprintf ('%s00%s00%s00NN', chr (perms[0]), chr (perms[3]), chr (perms[6]));
  if ('C' = id[4][2])
    return vector (
      DAV_CONCAT_PATH ('', path_parts), 'C', 0, source_dir_single[3],
      id,
      perms, source_dir_single[6], source_dir_single[7], source_dir_single[8], 'dav/unix-directory', id[4][0]);
  else
    return vector (
      DAV_CONCAT_PATH ('', path_parts), 'R', 1000, source_dir_single[3],
      id,
      perms, source_dir_single[6], source_dir_single[7], source_dir_single[8], id[4][3], id[4][0]);
}
;

create function "Archive_CAT_RECORD_TO_DIR_ENTRY" (in detcol_id any, in orig_id any, inout unarch_path_parts any, inout cat_path_parts any, inout cattree any)
{
  declare parent_full_path, perms varchar;
  declare source_dir_single any;
  -- dbg_obj_princ ('Archive_CAT_RECORD_TO_DIR_ENTRY (', detcol_id, orig_id, unarch_path_parts, cat_path_parts, cattree, ')');
  if (cattree is null)
    return null;
  parent_full_path := DAV_CONCAT_PATH (unarch_path_parts, cat_path_parts);
  source_dir_single := DAV_DIR_SINGLE_INT (orig_id, 'R', '/FAKE/');
  perms := source_dir_single[5];
  perms := sprintf ('%s00%s00%s00NN', chr (perms[0]), chr (perms[3]), chr (perms[6]));
  if ('C' = cattree[2])
    return vector (
      DAV_CONCAT_PATH (parent_full_path, '/'),
      'C', 0, source_dir_single[3],
      vector (UNAME'Archive', detcol_id, orig_id, cat_path_parts, subseq (cattree, 0, 4)),
      perms, source_dir_single[6], source_dir_single[7], source_dir_single[8], 'dav/unix-directory',
      cast (cattree[0] as varchar) );
  else
    return vector (
      DAV_CONCAT_PATH (parent_full_path, cast (cattree[0] as varchar)),
      'R', 1000, source_dir_single[3],
      vector (UNAME'Archive', detcol_id, orig_id, cat_path_parts, subseq (cattree, 0, 4)),
      perms, source_dir_single[6], source_dir_single[7], source_dir_single[8], cattree[3],
      cast (cattree[0] as varchar) );
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Archive_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  if (id[2] is null)
    {
      if ('C' <> what)
        return -1;
      return vector (DAV_CONCAT_PATH ('', path), 'C', 0, now(),
        id,
        '100100100NN', http_nogroup_gid(), http_nobody_uid(),
        now (), 'dav/unix-directory', id[3][0] );
    }
  return "Archive_ID_TO_DIR_ENTRY" (id, path);
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Archive_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare col_path, orig_path varchar;
  declare orig_id, adir any;
  declare len_path_parts integer;
  declare acc any;
  -- dbg_obj_princ ('Archive_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  if (length (path_parts) < 3)
    {
      vectorbld_init (acc);
      if (length (path_parts) = 1)
        {
          if (path_parts[0] <> '')
            return vector ();
          for (select P_NAME from SYS_PROCEDURES where P_NAME like fix_identifier_case ('DB.DBA.%_ARCHIVE_DIR')) do
            {
              declare lname varchar;
              lname := subseq (P_NAME, 7, length (P_NAME) - 12);
              vectorbld_acc (acc, vector (DAV_CONCAT_PATH (detcol_path, lname || '/'), 'C', 0, now(),
                vector (UNAME'Archive', detcol_id, null, vector (lname), null),
                '100100100NN', http_nogroup_gid(), http_nobody_uid(),
                now (), 'dav/unix-directory', lname ) );
            }
        }
      else if (length (path_parts) = 2)
        {
          declare filter, compilation any;
          declare parent_path varchar;
          declare parent_path_len integer;
          declare hits any;
          declare root_lp any;
          if (path_parts[1] <> '')
            return vector ();
          filter := vector (
            vector ('RDF_VALUE', '=', path_parts[0], 'http://local.virt/DAV-RDF', 'http://www.openlinksw.com/virtdav#dynArchiver') );
          compilation := vector ('', filter, 'DAV', DAV_FC_PRINT_WHERE (filter, auth_uid));
          parent_path := DAV_SEARCH_PATH (DAV_GET_PARENT (detcol_id, 'C', ''), 'C');
          if (DAV_HIDE_ERROR (parent_path) is null)
            {
              -- dbg_obj_princ ('bad parent path: ', parent_path);
              return vector ();
            }
          -- dbg_obj_princ ('parent_path = ', parent_path);
          hits := DAV_DIR_FILTER_INT (parent_path, 1, compilation, null, null, auth_uid);
          -- dbg_obj_princ ('hits = ', hits);
          parent_path_len := length (parent_path);
          root_lp := xml_get_logical_path (xpath_eval ('/xbel', xtree_doc ('<xbel/>')));
          foreach (any hit in hits) do
            {
              declare source_sub varchar;
              source_sub := hit[0];
              if ((length (source_sub) > parent_path_len) and ("LEFT" (source_sub, parent_path_len) = parent_path))
                source_sub := replace (subseq (source_sub, parent_path_len), '/', '|');
              else
                source_sub := replace (source_sub, '/', '|');
              hit[0] := DAV_CONCAT_PATH (detcol_path, path_parts[0] || '/' || source_sub || '/');
              hit[1] := 'C';
              hit[2] := 0;
              hit[4] := vector (UNAME'Archive', detcol_id, hit[4], vector (path_parts[0], source_sub), vector ('', root_lp, 'C', null));
              hit[5] := sprintf ('%s00%s00%s00NN', chr (hit[5][0]), chr (hit[5][3]), chr (hit[5][6]));
              hit[9] := 'dav/unix-directory';
              hit[10] := source_sub;
              vectorbld_acc (acc, hit);
            }
        }
      vectorbld_final (acc);
      -- dbg_obj_princ ('after special case, acc = ', acc);
      return acc;
    }
  orig_path := "Archive_GET_ORIG_PATH" (detcol_id, path_parts);
  orig_id := DAV_SEARCH_ID (orig_path, 'R');
  if (DAV_HIDE_ERROR (orig_id) is null)
    return orig_id;
  {
    declare exit handler for sqlstate '*' {
        -- dbg_obj_princ ('Archive_DAV_DIR_LIST has failed to get a dir item: ', __SQL_STATE, __SQL_MESSAGE);
        return vector ();
      };
    adir := call (concat ('DB.DBA.', path_parts[0], '_ARCHIVE_DIR'))(orig_id,
      subseq (path_parts, 2),
      case (path_parts[length (path_parts) - 1]) when '' then 'C' else 'R' end,
      recursive );
  }
  -- dbg_obj_princ ('adir = ', adir);
  if (adir is null)
    return vector ();
  if (-1 = recursive)
    {
      return vector (
        "Archive_CAT_RECORD_TO_DIR_ENTRY" (detcol_id, orig_id, detcol_path,
          subseq (path_parts, 0, length (path_parts) - 1),
          path_parts, adir));
    }
  if ('C' <> adir[2])
    return vector ();
  vectorbld_init (acc);
  if (0 = recursive)
    {
      declare idx, len, patch_pos integer;
      declare sub_path any;
      sub_path := path_parts;
      patch_pos := length (sub_path) - 1;
      len := length (adir[4]);
      for (idx := 0; idx < len; idx := idx + 1)
        {
          sub_path [patch_pos] := cast (adir[4][idx][0] as varchar);
          vectorbld_acc (acc,
            "Archive_CAT_RECORD_TO_DIR_ENTRY" (detcol_id, orig_id, detcol_path,
              sub_path, adir[4][idx] ) );
        }
      sub_path := subseq (sub_path, 0, patch_pos);
      len := length (adir[5]);
      for (idx := 0; idx < len; idx := idx + 1)
        {
          vectorbld_acc (acc,
            "Archive_CAT_RECORD_TO_DIR_ENTRY" (detcol_id, orig_id, detcol_path,
              sub_path, adir[5][idx] ) );
        }
    }
  vectorbld_final (acc);
  -- dbg_obj_princ ('acc = ', acc);
  return acc;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "Archive_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector();
}
;

create function "Archive_GET_ORIG_PATH" (in detcol_id any, inout path_parts any) returns varchar
{
  if (path_parts[1][0] = '|'[0])
    return replace (path_parts[1], '|', '/');
  else
    {
      declare detcol_path varchar;
      detcol_path := DAV_SEARCH_PATH (DAV_GET_PARENT (detcol_id, 'C', ''), 'C');
      return DAV_CONCAT_PATH (detcol_path, replace (path_parts[1], '|', '/'));
    }
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Archive_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare col_path, orig_path varchar;
  declare orig_id, adir any;
  declare len_path_parts integer;
  -- dbg_obj_princ ('Archive_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  len_path_parts := length (path_parts);
  if (len_path_parts < 3)
    {
      if ('C' <> what)
        return -1;
      if (len_path_parts = 2)
        {
          if (exists (select top 1 1 from SYS_PROCEDURES where P_NAME = fix_identifier_case ('DB.DBA.' || path_parts[0] || '_ARCHIVE_DIR')))
            return vector (UNAME'Archive', detcol_id, null, vector (path_parts[0]), null);
        }
      return -1;
    }
  orig_path := "Archive_GET_ORIG_PATH" (detcol_id, path_parts);
  orig_id := DAV_SEARCH_ID (orig_path, 'R');
  if (DAV_HIDE_ERROR (orig_id) is null)
    return orig_id;
  declare exit handler for sqlstate '*' {
    -- dbg_obj_princ ('Archive_DAV_SEARCH_ID has failed to get a dir item: ', __SQL_STATE, __SQL_MESSAGE);
    return -1;
    };
  adir := call (concat ('DB.DBA.', path_parts[0], '_ARCHIVE_DIR'))(orig_id, subseq (path_parts, 2), what, -1);
  -- dbg_obj_princ ('adir = ', adir);
  if (adir is null)
    return -1;
  return vector (UNAME'Archive', detcol_id, orig_id, path_parts, subseq (adir, 0, 4));
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "Archive_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('Archive_DAV_SEARCH_PATH (', id, what, ')');
  return NULL;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "Archive_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in orig_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, orig_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "Archive_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in orig_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, orig_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "Archive_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('Archive_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
--  declare exit handler for sqlstate '*' {
--    -- dbg_obj_princ ('Archive_DAV_SEARCH_ID has failed to get a dir item: ', __SQL_STATE, __SQL_MESSAGE);
--    return -1;
--    };
  return call ('DB.DBA.' || id[3][0] || '_ARCHIVE_RES_CONTENT')(id, content, type, content_mode);
}
;

--| This adds an extra access path to the existing resource or collection.
create function "Archive_DAV_SYMLINK" (in detcol_id any, in path_parts any, in orig_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_SYMLINK (', detcol_id, path_parts, orig_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "Archive_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('Archive_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "Archive_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('Archive_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "Archive_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "Archive_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Archive_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "Archive_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('Archive_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "Archive_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('Archive_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;

create function DB.DBA.XBEL_ARCHIVE_DIR_EXTRACT (in ent any) returns any
{
  declare res, folders, bookmarks, e any;
  declare ctr, len integer;
  folders := xpath_eval ('folder', ent, 0);
  len := length (folders);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      e := folders [ctr];
      folders [ctr] := DB.DBA.XBEL_ARCHIVE_DIR_EXTRACT (e);
    }
  bookmarks := xpath_eval ('bookmark', ent, 0);
  len := length (bookmarks);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      e := bookmarks [ctr];
      bookmarks [ctr] := vector (
        xpath_eval ('string (title)', e),	-- 0
	xml_get_logical_path (e),		-- 1
	'R',					-- 2
	'application/xbel+xml',			-- 3
	NULL );					-- 4
    }
  res := vector (
    xpath_eval ('string (title)', ent),	-- 0
    xml_get_logical_path (ent),		-- 1
    'C',				-- 2
    NULL,				-- 3
    folders,				-- 4
    bookmarks );			-- 5
  return res;
}
;


create function DB.DBA.XBEL_ARCHIVE_DIR (inout id any, inout path_parts any, in what char(1), in recursive integer := -1)
{
  declare cont, rc, parsed, cattree any;
  declare mtype varchar;
  -- dbg_obj_princ ('DB.DBA.XBEL_ARCHIVE_DIR (', id, path_parts, what, recursive, ')');
  cont := string_output ();
  rc := DAV_RES_CONTENT_INT (id, cont, mtype, 1, 0);
  parsed := xtree_doc (cont, 0);
  -- dbg_obj_princ ('parsed = ', parsed);
  parsed := xpath_eval ('xbel', parsed);
  if (parsed is null)
    return null;
  cattree := DB.DBA.XBEL_ARCHIVE_DIR_EXTRACT (parsed);
  -- dbg_obj_princ ('cattree = ', cattree);
  return "Archive_FIND_CAT_RECORD" (cattree, path_parts, case (recursive) when -1 then 1 else 0 end);
}
;

create function XBEL_ARCHIVE_RES_CONTENT (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  declare cont, rc, parsed, mtype any;
  -- dbg_obj_princ ('XBEL_ARCHIVE_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  cont := string_output ();
  rc := DAV_RES_CONTENT_INT (id[2], cont, mtype, 1, 0);
  parsed := xtree_doc (cont, 0);
  -- dbg_obj_princ ('parsed = ', parsed);
  parsed := xpath_eval ('xbel', parsed);
  if (parsed is null)
    return -37;
  parsed := xml_follow_logical_path (xpath_eval ('/', parsed), id[4][1]);
  if (parsed is null)
    return -23;
  parsed := XMLELEMENT ('xbel', null, parsed);
  -- dbg_obj_princ ('resulting fragment = ', parsed);
  type := 'application/xbel+xml';
  if (content_mode = 0)
    content := serialize_to_UTF8_xml (parsed);
  else if (content_mode = 1)
    http_value (parsed, 0, content);
  else if (content_mode = 2)
    content := parsed;
  else if (content_mode = 3)
    http_value (parsed);
  return id;
}
;
