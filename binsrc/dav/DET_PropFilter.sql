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

use DB
;

create function "PropFilter_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('PropFilter_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  if (auth_uid >= 0)
    return auth_uid;
  return -12;
}
;

create function "PropFilter_NORM" (in value any) returns varchar
{
  value := blob_to_string (value);
  if (('' = value) or (193 <> value[0]))
    return value;
  value := deserialize (value)[1];
  if (isstring (value))
    return value;
  return cast (xml_tree_doc(value) as varchar);
}
;

create function "PropFilter_GET_CONDITION" (in detcol_id integer, out pfc_spath varchar, out pfc_name varchar, out pfc_value varchar)
{
  -- dbg_obj_princ ('PropFilter_GET_CONDITION (', detcol_id, '...)');
  whenever not found goto nf;
  if (isarray (detcol_id))
    return -20;
  select "PropFilter_NORM" (PROP_VALUE) into pfc_spath from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:PropFilter-SearchPath' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "PropFilter_NORM" (PROP_VALUE) into pfc_name from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:PropFilter-PropName' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "PropFilter_NORM" (PROP_VALUE) into pfc_value from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:PropFilter-PropValue' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  return 0;
nf:
  return -1;
}
;


create function "PropFilter_FIT_INTO_CONDITION" (in id integer, in what char (1), in pfc_name varchar, in pfc_value varchar)
{
  declare old_value varchar;
  declare propid integer;
  if (__tag (pfc_value) = 193)
    pfc_value := serialize (pfc_value);
  else if (not isstring (pfc_value))
    return -17;
  whenever not found goto ins;
  select p.PROP_ID, "PropFilter_NORM" (p.PROP_VALUE) into propid, old_value from WS.WS.SYS_DAV_PROP p, WS.WS.SYS_DAV_RES r where p.PROP_NAME = pfc_name and p.PROP_PARENT_ID = id and p.PROP_TYPE = what and r.RES_ID = id;
  if (old_value <> pfc_value)
    update WS.WS.SYS_DAV_PROP set PROP_VALUE = pfc_value where PROP_ID = propid;
  return propid;

ins:
  propid := WS.WS.GETID ('P');
  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
      values (propid, pfc_name, pfc_value, id, what);
  return propid;
}
;

create function "PropFilter_LEAVE_CONDITION" (in id integer, in what char (1), in pfc_name varchar, in pfc_value varchar) returns integer
{
  delete from WS.WS.SYS_DAV_PROP where PROP_NAME = pfc_name and PROP_PARENT_ID = id and PROP_TYPE = what and "PropFilter_NORM" (PROP_VALUE) = pfc_value;
  return 0;
}
;

create function "PropFilter_FNMERGE" (in path any, in id integer) returns varchar
{
  declare pairs any;
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', path, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "PropFilter_FNMERGE" (%s, %d)', path, id));
  return sprintf ('%s-PfId%d%s', subseq (path, 0, pairs[5]), id, subseq (path, pairs[6]));
}
;

create procedure "PropFilter_FNSPLIT" (in path any, out colpath varchar, out orig_fnameext varchar, out id integer)
{
  declare pairs any;
  declare fname, fext varchar;
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', path, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "PropFilter_FNSPLIT" (%s)', path));
  colpath := subseq (path, 0, pairs[4]);
  fname := subseq (path, pairs[4], pairs[5]);
  fext := subseq (path, pairs[6], pairs[7]);
  -- dbg_obj_princ ('PropFilter_FNSPLIT: colpath = ', colpath, ', fname = ', fname, ', fext = ', fext);
  pairs := regexp_parse ('^(.*)-PfId([1-9][0-9]*)\044', fname, 0);
  if (pairs is null)
    {
      orig_fnameext := fname || fext;
      id := null;
    }
  else
    {
      orig_fnameext := subseq (fname, pairs[2], pairs[3]) || fext;
      id := cast (subseq (fname, pairs[4], pairs[5]) as integer);
    }
}
;


create function "PropFilter_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout pfc_spath varchar, inout pfc_name varchar, inout pfc_value varchar) returns any
{
  declare colpath, orig_fnameext varchar;
  declare orig_id integer;
  declare hitlist any;
  -- dbg_obj_princ ('PropFilter_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  if ('R' <> what)
    return -1;
  if (not (isstring (pfc_spath)))
    {
      if (0 > "PropFilter_GET_CONDITION" (detcol_id, pfc_spath, pfc_name, pfc_value))
  {
    -- dbg_obj_princ ('broken filter - no items');
    return -1;
  }
    }
  if (1 <> length(path_parts) or ('' = path_parts[0]))
    {
      -- dbg_obj_princ ('not a resource right inside detcol - no items');
      return -1;
    }
  "PropFilter_FNSPLIT" (path_parts[0], colpath, orig_fnameext, orig_id);
  -- dbg_obj_princ (path_parts, colpath, orig_fnameext, orig_id, pfc_spath, pfc_name, pfc_value);
  hitlist := vector();
  if (orig_id is null)
    {
      for select RES_ID from WS.WS.SYS_DAV_RES inner join WS.WS.SYS_DAV_PROP on (RES_ID = PROP_PARENT_ID)
      where RES_NAME = orig_fnameext and (RES_FULL_PATH between pfc_spath and DAV_COL_PATH_BOUNDARY (pfc_spath)) and
        PROP_NAME = pfc_name and PROP_TYPE = 'R' and "PropFilter_NORM" (PROP_VALUE) = pfc_value
      do
        {
    -- dbg_obj_princ ('hit (no fixed orig_id): ', RES_ID);
          hitlist := vector_concat (hitlist, vector (RES_ID));
        }
    }
  else
    {
      for select RES_ID from WS.WS.SYS_DAV_RES inner join WS.WS.SYS_DAV_PROP on (RES_ID = PROP_PARENT_ID)
      where RES_ID = orig_id and
        RES_NAME = orig_fnameext and (RES_FULL_PATH between pfc_spath and DAV_COL_PATH_BOUNDARY (pfc_spath)) and
        PROP_NAME = pfc_name and PROP_TYPE = 'R' and "PropFilter_NORM" (PROP_VALUE) = pfc_value
      do
        {
    -- dbg_obj_princ ('hit (fixed orig_id): ', RES_ID);
          hitlist := vector_concat (hitlist, vector (RES_ID));
        }
    }
  if (length (hitlist) <> 1)
    return -1;
  return hitlist[0];
}
;


create function "PropFilter_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare rc integer;
  declare puid, pgid, ruid, rgid integer;
  declare u_password, pperms varchar;
  declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'PropFilter_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='PropFilter'), '')
      ), puid+1);
  pperms := '110100100R';
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null)
    {
      if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
      rc := WS.WS.GET_DAV_AUTH (a_lines, allow_anon, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
      if (rc < 0)
        return rc;
    }
  if (isinteger (a_uid))
    {
      if (a_uid < 0)
  return a_uid;
     if (a_uid = 1) -- Anonymous FTP
  {
          a_uid := http_nobody_uid ();
    a_gid := http_nogroup_gid ();
  }
    }
  if (not DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return -13;

  if (isarray (id[2]))
    return -1;
  select RES_OWNER, RES_GROUP into ruid, rgid from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  if (not DAV_CHECK_PERM (pperms, req, a_uid, a_gid, rgid, ruid))
    return -13;

  return a_uid;

nf_col_or_res:
  return -1;
}
;


create function "PropFilter_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_GET_PARENT (', id, st, path, ')');
  if (st = 'R')
    return id [1];
  return -20;
}
;


create function "PropFilter_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "PropFilter_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "PropFilter_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_COL_MOUNT (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "PropFilter_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  declare rc, orig_id integer;
  declare pfc_spath, pfc_name, pfc_value varchar;
  -- dbg_obj_princ ('PropFilter_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  pfc_spath := null;
  orig_id := "PropFilter_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, pfc_spath, pfc_name, pfc_value);
  if (orig_id < 0)
    return orig_id;
  return "PropFilter_LEAVE_CONDITION" (orig_id, what, pfc_name, pfc_value);
}
;


create function "PropFilter_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "PropFilter_DAV_PROP_REMOVE" (in id any, in st char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('PropFilter_DAV_PROP_REMOVE (', id, st, propname, silent, auth_uid, ')');
  if (st <> 'R')
    return -1;
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_REMOVE') (id, st, propname, silent, auth_uid);
  return DAV_PROP_REMOVE_RAW (id, st, propname, silent, auth_uid);
}
;


create function "PropFilter_DAV_PROP_SET" (in id any, in st char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  declare pid integer;
  declare resv any;
  -- dbg_obj_princ ('PropFilter_DAV_PROP_SET (', id, st, propname, propvalue, overwrite, auth_uid, ')');
  if (st <> 'R')
    return -1;
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_SET') (id, st, propname, propvalue, overwrite, auth_uid);
  return DAV_PROP_SET_RAW (id, st, propname, propvalue, overwrite, auth_uid);
}
;


create function "PropFilter_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  declare ret varchar;
  -- dbg_obj_princ ('PropFilter_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
  if (propname[0] = 58)
    return DAV_PROP_GET_INT (id, what, propname, 0, null, null, auth_uid);
  whenever not found goto no_prop;
  select blob_to_string (PROP_VALUE) into ret from WS.WS.SYS_DAV_PROP where PROP_NAME = propname and PROP_PARENT_ID = id and PROP_TYPE = what;
  return ret;

no_prop:
    return -11;
}
;


create function "PropFilter_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  declare ret any;
  -- dbg_obj_princ ('PropFilter_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  id := id[2];
  ret := vector();
  for select PROP_NAME, PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME like propmask and PROP_PARENT_ID = id and PROP_TYPE = what do {
      ret := vector_concat (ret, vector (vector (PROP_NAME, blob_to_string (PROP_VALUE))));
    }
  return ret;
}
;


create function "PropFilter_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  if ('R' <> what)
    return -1;
  for select RES_FULL_PATH, RES_ID, length (RES_CONTENT) as clen, RES_MOD_TIME,
    RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME as r1_RES_NAME
  from WS.WS.SYS_DAV_RES r1
  where RES_ID = id[2]
  do
    {
      declare merged varchar;
      -- dbg_obj_princ ('About to return in DAV_DIR_LIST: ', r1_RES_NAME, RES_ID);
      if (regexp_parse ('^([^/][^./]*)-PfId([1-9][0-9]*)([^/]*)\044', r1_RES_NAME, 0)) -- Suspicious names should be qualified
        {
          merged := "PropFilter_FNMERGE" (r1_RES_NAME, RES_ID);
        }
      else
        {
    declare pfc_spath, pfc_name, pfc_value varchar;
          declare namesakes_no integer;
    if (0 > "PropFilter_GET_CONDITION" (id[1], pfc_spath, pfc_name, pfc_value))
      {
        -- dbg_obj_princ ('broken filter - bad id in DIR_SINGLE');
        return -1;
      }
          select count(1) into namesakes_no
    from WS.WS.SYS_DAV_RES r2 inner join WS.WS.SYS_DAV_PROP p2 on (r2.RES_ID = p2.PROP_PARENT_ID)
    where r2.RES_NAME = r1_RES_NAME and (r2.RES_FULL_PATH between pfc_spath and DAV_COL_PATH_BOUNDARY (pfc_spath)) and
      p2.PROP_NAME = pfc_name and p2.PROP_TYPE = 'R' and "PropFilter_NORM" (p2.PROP_VALUE) = pfc_value;
    if (0 = namesakes_no)
      return -1;
    if (1 < namesakes_no)
      merged := "PropFilter_FNMERGE" (r1_RES_NAME, RES_ID);
    else
      merged := r1_RES_NAME;
        }
--                   0                                                       1    2     3
      return vector (DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), merged), 'R', clen, RES_MOD_TIME,
--       4   5          6          7          8            9         10
   id, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, merged);
    }
  return -1;
}
;


create function "PropFilter_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare pfc_spath, pfc_name, pfc_value varchar;
  declare davpath, prev_raw_name varchar;
  declare files, filtered_files, res any;
  declare reslen, prev_is_patched integer;
  -- dbg_obj_princ ('PropFilter_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  if (0 > "PropFilter_GET_CONDITION" (detcol_id, pfc_spath, pfc_name, pfc_value))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return vector();
    }
  if (1 <> length(path_parts) or ('' <> path_parts[0]))
    {
      -- dbg_obj_princ ('nonempty path - no items');
      return vector();
    }
  res := vector();
  reslen := 0;
  prev_raw_name := '';
  prev_is_patched := 1; -- to prevent from patching minus-first elt of res
  for select RES_FULL_PATH, RES_ID, length (RES_CONTENT) as clen, RES_MOD_TIME,
    RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME
  from WS.WS.SYS_DAV_RES inner join WS.WS.SYS_DAV_PROP on (RES_ID = PROP_PARENT_ID)
  where RES_NAME like name_mask and (RES_FULL_PATH between pfc_spath and DAV_COL_PATH_BOUNDARY (pfc_spath)) and
    PROP_NAME = pfc_name and PROP_TYPE = 'R' and "PropFilter_NORM" (PROP_VALUE) = pfc_value
  order by RES_NAME, RES_ID
  do
    {
      declare merged varchar;
      -- dbg_obj_princ ('About to put in dir list: ', RES_NAME, RES_ID);
      if (regexp_parse ('^([^/][^./]*)-PfId([1-9][0-9]*)([^/]*)\044', RES_NAME, 0)) -- Suspicious names should be qualified
        {
          merged := "PropFilter_FNMERGE" (RES_NAME, RES_ID);
          prev_is_patched := 1; -- The current one is with merging for sure.
    -- dbg_obj_princ ('Suspicious -- made merged');
        }
      else if (RES_NAME = prev_raw_name)
        {
          merged := "PropFilter_FNMERGE" (RES_NAME, RES_ID);
          if (not prev_is_patched) -- The first record in a sequence of namesakes is written w/o merging, go fix it
            {
              declare prev_id integer;
        declare prev_merged varchar;
              prev_id := res[reslen-1][4][2];
              prev_merged := "PropFilter_FNMERGE" (RES_NAME, prev_id);
              res[reslen-1][10] := prev_merged;
              res[reslen-1][0] := DAV_CONCAT_PATH (detcol_path, prev_merged);
        -- dbg_obj_princ ('Both current and prev namesake are merged', RES_ID, prev_id);
            }
          prev_is_patched := 1; -- The current one is with merging for sure.
        }
      else
        {
          merged := RES_NAME;
          prev_is_patched := 0;
          -- dbg_obj_princ ('Current is not merged');
        }
--                                               0                                      1    2     3
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (detcol_path, merged), 'R', clen, RES_MOD_TIME,
--       4                                              5          6          7          8            9         10
   vector (UNAME'PropFilter', detcol_id, RES_ID), RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, merged ) ) );
      prev_raw_name := RES_NAME;
      reslen := reslen + 1;
    }
  return res;
}
;


create function "PropFilter_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  declare pfc_spath, pfc_name, pfc_value varchar;
  declare davpath, prev_raw_name varchar;
  declare reslen, prev_is_patched integer;
  declare execstate, execmessage, execmeta, execrows any;
  declare davcond varchar;
  -- dbg_obj_princ ('PropFilter_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  davcond := get_keyword ('DAV', compilation);
  if ('' <> davcond)
    davcond := ' and ' || davcond;
  execstate := '00000';
  if (0 > "PropFilter_GET_CONDITION" (detcol_id, pfc_spath, pfc_name, pfc_value))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return vector();
    }
  if (1 <> length(path_parts) or ('' <> path_parts[0]))
    {
      -- dbg_obj_princ ('nonempty path - no items');
      return vector();
    }
  exec ('select
--    0         1      2                     3
      RES_NAME, ''R'', length (RES_CONTENT), RES_MOD_TIME,
--    4       5          6          7          8            9         10
      RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME
    from WS.WS.SYS_DAV_RES inner join WS.WS.SYS_DAV_PROP on (RES_ID = PROP_PARENT_ID)
    where (RES_FULL_PATH between ? and ?) and
      (PROP_NAME = ?) and (PROP_TYPE = ''R'') and ("PropFilter_NORM" (PROP_VALUE) = ?)' || davcond || '
order by RES_NAME, RES_ID',
    execstate, execmessage, vector (pfc_spath, DAV_COL_PATH_BOUNDARY (pfc_spath), pfc_name, pfc_value), 100000000, execmeta, execrows );

  reslen := 0;
  prev_raw_name := '';
  prev_is_patched := 1; -- to prevent from patching minus-first elt of res
  foreach (any itm in execrows) do
    {
      declare orig_name varchar;
      declare orig_id integer;
      declare merged varchar;
      orig_name := itm[0];
      orig_id := itm[4];
      -- dbg_obj_princ ('About to patch in filter output: ', orig_name, orig_id);
      if (regexp_parse ('^([^/][^./]*)-PfId([1-9][0-9]*)([^/]*)\044', orig_name, 0)) -- Suspicious names should be qualified
        {
          merged := "PropFilter_FNMERGE" (orig_name, orig_id);
          prev_is_patched := 1; -- The current one is with merging for sure.
    -- dbg_obj_princ ('Suspicious -- made merged');
        }
      else if (orig_name = prev_raw_name)
        {
          merged := "PropFilter_FNMERGE" (orig_name, orig_id);
          if (not prev_is_patched) -- The first record in a sequence of namesakes is written w/o merging, go fix it
            {
              declare prev_id integer;
        declare prev_merged varchar;
              prev_id := execrows[reslen-1][4][2];
              prev_merged := "PropFilter_FNMERGE" (orig_name, prev_id);
              execrows[reslen-1][10] := prev_merged;
              execrows[reslen-1][0] := DAV_CONCAT_PATH (detcol_path, prev_merged);
        -- dbg_obj_princ ('Both current and prev namesake are merged', orig_id, prev_id);
            }
          prev_is_patched := 1; -- The current one is with merging for sure.
        }
      else
        {
          merged := orig_name;
          prev_is_patched := 0;
          -- dbg_obj_princ ('Current is not merged');
        }
      execrows[reslen][0] := DAV_CONCAT_PATH (detcol_path, merged);
      execrows[reslen][4] := vector (UNAME'PropFilter', detcol_id, orig_id);
      prev_raw_name := orig_name;
      reslen := reslen + 1;
    }
  -- dbg_obj_princ ('PropFilter_DAV_DIR_FILTER returns ', execrows);
  return execrows;
}
;


create function "PropFilter_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare pfc_spath, pfc_name, pfc_value varchar;
  declare orig_id integer;
  -- dbg_obj_princ ('PropFilter_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  pfc_spath := null;
  orig_id := "PropFilter_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, pfc_spath, pfc_name, pfc_value);
  if (orig_id < 0)
    return orig_id;
  return vector (UNAME'PropFilter', detcol_id, orig_id);
}
;


create function "PropFilter_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_SEARCH_PATH (', id, what, ')');
  return coalesce ((select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_ID = id[2]), null);
}
;


create function "PropFilter_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  declare pfc_spath, pfc_name, pfc_value varchar;
  declare rc integer;
  -- dbg_obj_princ ('PropFilter_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite, permissions, uid, gid, auth_uid, ')');
  if (0 > "PropFilter_GET_CONDITION" (detcol_id, pfc_spath, pfc_name, pfc_value))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return -2;
    }
  if (1 <> length (path_parts))
    return -2;
  if ('R' <> what)
    return -2;
  if ('' = path_parts[0])
    return -2;
  if (isinteger (source_id) and
     exists (select 1 from WS.WS.SYS_DAV_RES
         where RES_ID = source_id and RES_NAME = path_parts[0] and (RES_FULL_PATH between pfc_spath and DAV_COL_PATH_BOUNDARY (pfc_spath)) ) )
    {
      "PropFilter_FIT_INTO_CONDITION" (source_id, what, pfc_name, pfc_value);
    }
  else
    {
      declare new_full_path varchar;
      new_full_path := DAV_CONCAT_PATH (pfc_spath, path_parts[0]);
      rc := DAV_COPY_INT (DAV_SEARCH_PATH (source_id, what), new_full_path, overwrite, permissions,
         coalesce ((select U_NAME from WS.WS.SYS_DAV_USER where U_ID = uid), ''),
         coalesce ((select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = gid), ''),
         null, null, 0);
      if (DAV_HIDE_ERROR (rc) is null)
        return rc;
      source_id := DAV_SEARCH_ID (new_full_path, what);
      if (DAV_HIDE_ERROR (source_id) is null)
        return source_id;
      "PropFilter_FIT_INTO_CONDITION" (source_id, what, pfc_name, pfc_value);
    }
  return 1;
}
;

create function "PropFilter_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in auth_uid integer) returns any
{
  declare pfc_spath, pfc_name, pfc_value varchar;
  declare rc integer;
  -- dbg_obj_princ ('PropFilter_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite, auth_uid, ')');
  if (0 > "PropFilter_GET_CONDITION" (detcol_id, pfc_spath, pfc_name, pfc_value))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return -2;
    }
  if (1 <> length (path_parts))
    return -2;
  if ('R' <> what)
    return -2;
  if ('' = path_parts[0])
    return -2;
  if (isinteger (source_id) and
    exists (select 1 from WS.WS.SYS_DAV_RES
        where RES_ID = source_id and RES_NAME = path_parts[0] and (RES_FULL_PATH between pfc_spath and DAV_COL_PATH_BOUNDARY (pfc_spath))))
    {
      "PropFilter_FIT_INTO_CONDITION" (source_id, what, pfc_name, pfc_value);
    }
  else
    {
      declare new_full_path varchar;
      new_full_path := DAV_CONCAT_PATH (pfc_spath, path_parts[0]);
      rc := DAV_MOVE_INT (DAV_SEARCH_PATH (source_id, what),  new_full_path, overwrite, null, null, 0, 1);
      if (DAV_HIDE_ERROR (rc) is null)
        return rc;
      source_id := DAV_SEARCH_ID (new_full_path, what);
      if (DAV_HIDE_ERROR (source_id) is null)
        return source_id;
      "PropFilter_FIT_INTO_CONDITION" (source_id, what, pfc_name, pfc_value);
    }
  return 1;
}
;

create function "PropFilter_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('PropFilter_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare cont any;
  if ((content_mode = 0) or (content_mode = 2))
    select RES_CONTENT, RES_TYPE into content, type from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  else if (content_mode = 1)
    select http (RES_CONTENT, content), RES_TYPE into cont, type from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  else if (content_mode = 3)
    select http (RES_CONTENT), RES_TYPE into cont, type from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  return id[2];
}
;

create function "PropFilter_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('PropFilter_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "PropFilter_DAV_LOCK" (in path any, inout id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  declare rc, u_token, new_token varchar;
  -- dbg_obj_princ ('PropFilter_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  if ('R' <> type)
    return -20;
  if (DAV_HIDE_ERROR (id) is null)
    return -20;
  if (isarray (id))
    return DAV_LOCK_INT (path, id[2], type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, null, null, auth_uid);
  return -20;
}
;

create function "PropFilter_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('PropFilter_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  if (isarray (id))
    id := id [2];
  return DAV_UNLOCK_INT (id, type, token, null, null, auth_uid);
}
;

create function "PropFilter_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  declare rc integer;
  declare orig_id any;
  declare orig_type char(1);
  -- dbg_obj_princ ('PropFilter_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  orig_id := id;
  id := orig_id[2];
  rc := DAV_IS_LOCKED_INT (id, type, owned_tokens);
  if (rc <> 0)
    return rc;
  id := orig_id[1];
  orig_type := type;
  type := 'C';
  rc := DAV_IS_LOCKED_INT (id, type, owned_tokens);
  if (rc <> 0)
    return rc;
  id := orig_id;
  type := orig_type;
  return 0;
}
;

create function "PropFilter_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  declare res any;
  -- dbg_obj_princ ('PropFilter_DAV_LIST_LOCKS" (', id, type, recursive);
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_LIST_LOCKS') (id, type, recursive);
  res := vector();
  for select LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO
    from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_ID = id and LOCK_PARENT_TYPE = type do {
      res := vector_concat (res, vector (vector (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO)));
    }
  return res;
}
;

create function "PropFilter_CONFIGURE" (
  in id integer,
  in params any)
{
  if (not isnull ("PropFilter_VERIFY" (DB.DBA.DAV_SEARCH_PATH (id, 'C'), params)))
    return -38;

  DB.DBA.PropFilter__paramSet (id, 'C', 'SearchPath', get_keyword ('SearchPath', params), 0);
  DB.DBA.PropFilter__paramSet (id, 'C', 'PropName', get_keyword ('PropName', params), 0);
  DB.DBA.PropFilter__paramSet (id, 'C', 'PropValue', get_keyword ('PropValue', params), 0);

  -- set DET Type Value
  DB.DBA.PropFilter__paramSet (id, 'C', ':virtdet', DB.DBA.PropFilter__detName (), 0, 0, 0);
}
;

create function "PropFilter_VERIFY" (
  in path varchar,
  in params any)
{
  -- dbg_obj_princ ('PropFilter_VARIFY (', path, params, ')');
  declare exit handler for sqlstate '*'
  {
    return __SQL_MESSAGE;
  };

  VALIDATE.DBA.validate (get_keyword ('SearchPath', params), vector ('name', 'Search Path', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  VALIDATE.DBA.validate (get_keyword ('PropName', params), vector ('name', 'Property Name', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  VALIDATE.DBA.validate (get_keyword ('PropValue', params), vector ('name', 'Property Value', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));

  return null;
}
;

create function DB.DBA.PropFilter__detName ()
{
  return UNAME'PropFilter';
}
;

create function DB.DBA.PropFilter__paramSet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _propValue any,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _encrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.PropFilter__paramSet', _propName, _propValue, ')');
  declare retValue any;

  if (_serialized)
    _propValue := serialize (_propValue);

  if (_encrypt)
    _propValue := pwd_magic_calc (DB.DBA.PropFilter__detName (), _propValue);

  if (_prefixed)
    _propName := 'virt:PropFilter-' || _propName;

  retValue := DB.DBA.DAV_PROP_SET_RAW (_id, _what, _propName, _propValue, 1, http_dav_uid ());

  return retValue;
}
;
