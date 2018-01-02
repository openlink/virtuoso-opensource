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

-- drop table WS.WS.DYNA_RES;

create table WS.WS.DYNA_RES (
  DR_RES_ID integer not null primary key,
  DR_DETCOL_ID integer not null,
  DR_NAME varchar not null,
  DR_PERMS varchar not null,
  DR_OWNER_UID integer not null,
  DR_OWNER_GID integer not null,
  DR_CREATED_DT datetime not null,
  DR_MODIFIED_DT datetime,
  DR_REFRESH_DT datetime,
  DR_DELETE_DT datetime,
  DR_REFRESH_SECONDS integer,
  DR_MIME varchar not null,
  DR_EXEC_STMT varchar,
  DR_EXEC_PARAMS long varchar,
  DR_EXEC_UNAME varchar,
  DR_LAST_LENGTH integer,
  DR_CONTENT long varchar,
  DR_ACL long varchar            -- ACL
)
create unique index DYNA_RES_DETCOL_NAME on WS.WS.DYNA_RES (DR_DETCOL_ID, DR_NAME)
create index DYNA_RES_REFRESH_DT on WS.WS.DYNA_RES (DR_REFRESH_DT)
create index DYNA_RES_DELETE_DT on WS.WS.DYNA_RES (DR_DELETE_DT)
;

alter table WS.WS.DYNA_RES add DR_ACL long varchar
;

create trigger DYNA_RES_WAC_I after insert on WS.WS.DYNA_RES order 100 referencing new as N
{
  if (DB.DBA.is_empty_or_null (N.DR_ACL))
    return;

  WS.WS.WAC_INSERT ("DynaRes__path" (N.DR_DETCOL_ID, N.DR_NAME), N.DR_ACL, N.DR_OWNER_UID, N.DR_OWNER_GID, 0);
}
;

create trigger DYNA_RES_WAC_U after update on WS.WS.DYNA_RES order 100 referencing new as N, old as O
{
  if (not DB.DBA.is_empty_or_null (O.DR_ACL))
    WS.WS.WAC_DELETE ("DynaRes__path" (O.DR_DETCOL_ID, O.DR_NAME), 0);

  if (DB.DBA.is_empty_or_null (N.DR_ACL))
    return;

  WS.WS.WAC_INSERT ("DynaRes__path" (N.DR_DETCOL_ID, N.DR_NAME), N.DR_ACL, N.DR_OWNER_UID, N.DR_OWNER_GID, 0);
}
;

create trigger DYNA_RES_WAC_D after delete on WS.WS.DYNA_RES order 100 referencing old as O
{
  if (DB.DBA.is_empty_or_null (O.DR_ACL))
    return;

  WS.WS.WAC_DELETE ("DynaRes__path" (O.DR_DETCOL_ID, O.DR_NAME), 0);
}
;

create function "DynaRes__detName" ()
{
  return UNAME'DynaRes';
}
;

create function "DynaRes__path" (
  in detcol_id any,
  in name varchar)
{
  return concat (DAV_SEARCH_PATH (detcol_id, 'C'), name);
}
;

create function "DynaRes__acl" (
  in detcol_id any)
{
  declare acl any;

  acl := (select WS.WS.ACL_PARSE (COL_ACL, '123', 0) from WS.WS.SYS_DAV_COL where COL_ID = detcol_id);
  if (not isnull (acl))
    acl := WS.WS.ACL_COMPOSE (WS.WS.ACL_MAKE_INHERITED (acl));

  return acl;
}
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "DynaRes_DAV_AUTHENTICATE" (
  in id any,
  in what char(1),
  in req varchar,
  in a_uname varchar,
  in a_pwd varchar,
  in a_uid integer)
{
  -- dbg_obj_princ ('DynaRes_DAV_AUTHENTICATE (', id, what, req, auth_uname, a_pwd, a_uid, http_dav_uid(), ')');
  declare pgid, puid integer;
  declare pperms varchar;
  declare pacl any;
  whenever not found goto _exit;

  select DR_PERMS, DR_OWNER_UID, DR_OWNER_GID into pperms, puid, pgid from WS.WS.DYNA_RES where DR_DETCOL_ID = id[1] and DR_RES_ID = id[3];

  set isolation='committed';
  if (puid <> http_nobody_uid() and exists (select top 1 1 from SYS_USERS where U_ID = puid and U_ACCOUNT_DISABLED = 1))
    return -42;

  set isolation='serializable';

  if (a_uid >= 0)
  {
  if (DAV_CHECK_PERM (pperms, req, a_uid, http_nogroup_gid(), pgid, puid))
    return a_uid;

  pacl := "DynaRes__acl" (id[1]);
  if (not isnull (pacl) and WS.WS.ACL_IS_GRANTED (pacl, a_uid, DAV_REQ_CHARS_TO_BITMASK (req)))
    return a_uid;
  }

    declare _perms, a_gid any;
  declare webid, serviceId varchar;

  if (DAV_AUTHENTICATE_SSL (id, what, null, req, a_uid, a_gid, _perms, webid))
      return a_uid;

  if (DAV_AUTHENTICATE_WITH_SESSION_ID (id, what, null, req, a_uid, a_gid, _perms, serviceId))
    return a_uid;

  -- Both DAV_AUTHENTICATE_SSL and DAV_AUTHENTICATE_WITH_SESSION_ID only check IRI ACLs
  -- However, service ids may map to ODS user accounts. This is what we check here
  a_uid := -1;

  -- A session ID might be connected to a normal user account, that is what we check first
  for (select top 1 U_ID from DB.DBA.SYS_USERS where U_NAME=serviceId and U_ACCOUNT_DISABLED=0) do
    a_uid := U_ID;

  if (a_uid = -1 and exists (select 1 from DB.DBA.SYS_KEYS where KEY_NAME='DB.DBA.WA_USER_OL_ACCOUNTS')) -- this check is only valid if table is accessed in a separate SP which is not precompiled
  {
    if (not DAV_GET_UID_BY_SERVICE_ID (serviceId, a_uid, a_gid))
      a_uid := -1;
  }

  -- If we were able to map the session or WebID to an existing user account, then check its permissions on the resource
  if (a_uid > 0)
  {
    if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    {
      return a_uid;
    }
    if (WS.WS.ACL_IS_GRANTED (pacl, a_uid, DAV_REQ_CHARS_TO_BITMASK (req)))
    {
      return a_uid;
    }
  }

  return -13;

_exit:
  return -1;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "DynaRes_DAV_AUTHENTICATE_HTTP" (
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
  -- dbg_obj_princ ('DynaRes_DAV_AUTHENTICATE_HTTP (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare rc integer;
  declare puid, pgid integer;
  declare pacl any;
  declare u_password, pperms varchar;
  declare allow_anon integer;

  -- used for error reporting in case of NetID or OAuth login
  declare webid, serviceId varchar;
  whenever not found goto _exit;

  webid := null;
  serviceId := null;

  what := upper (what);
  if ((what <> 'R') and (what <> 'C'))
    return -14;

  select DR_PERMS, DR_OWNER_UID, DR_OWNER_GID into pperms, puid, pgid from WS.WS.DYNA_RES where DR_DETCOL_ID = id[1] and DR_RES_ID = id[3];
  if (pperms is null)
    return -1;

  allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null)
  {
    if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
      rc := WS.WS.GET_DAV_AUTH (a_lines, allow_anon, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);

    if (rc < 0)
    {
      if (DAV_AUTHENTICATE_SSL (id, what, null, req, a_uid, a_gid, _perms, webid))
        return a_uid;

      if (DAV_AUTHENTICATE_WITH_SESSION_ID (id, what, null, req, a_uid, a_gid, _perms, serviceId))
      {
        http_rewrite ();
        return a_uid;
      }

      -- Normalize the service variables for error handling in VAL
      if (not webid is null and serviceId is null)
      {
        serviceId := webid;
      }

      a_uid := -1;

      -- A session ID might be connected to a normal user account, that is what we check first
      for (select top 1 U_ID from DB.DBA.SYS_USERS where U_NAME=serviceId and U_ACCOUNT_DISABLED=0) do
        a_uid := U_ID;

      if (a_uid = -1 and exists (select 1 from DB.DBA.SYS_KEYS where KEY_NAME='DB.DBA.WA_USER_OL_ACCOUNTS')) -- this check is only valid if table is accessed in a separate SP which is not precompiled
      {
        if (not DAV_GET_UID_BY_SERVICE_ID (serviceId, a_uid, a_gid))
          a_uid := -1;
      }

      -- If we were able to map the session or WebID to an existing user account, then check its permissions on the resource
      if (a_uid > 0)
      {
        if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
        {
          return a_uid;
        }
        if (WS.WS.ACL_IS_GRANTED (pacl, a_uid, DAV_REQ_CHARS_TO_BITMASK (req)))
        {
        return a_uid;
        }
      }

      -- If the user already provided some kind of credentials we return a 403 code
      if (not serviceId is null)
      {
        connection_set ('deniedServiceId', serviceId);
        rc := -13;
      }

      return rc;
    }
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
    else if (a_uid = http_dav_uid())
    {
      return a_uid;
    }
  }
  else
  {
    a_uid := http_nobody_uid ();
    a_gid := http_nogroup_gid ();
    _perms := '110110110--';
  }
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return a_uid;

  pacl := "DynaRes__acl" (id[1]);
  if (not isnull (pacl) and WS.WS.ACL_IS_GRANTED (pacl, a_uid, DAV_REQ_CHARS_TO_BITMASK (req)))
    return a_uid;

  return -13;

_exit:
  return -1;
}
;

--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "DynaRes_DAV_GET_PARENT" (
  in id any,
  in what char(1),
  in path varchar) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_GET_PARENT (', id, st, path, ')');
  if ('R' <> what)
    return -1; -- no subdirs ATM

  return id[1];
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "DynaRes_DAV_COL_CREATE" (
  in detcol_id any,
  in path_parts any,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "DynaRes_DAV_COL_MOUNT" (
  in detcol_id any,
  in path_parts any,
  in full_mount_path varchar,
  in mount_det varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "DynaRes_DAV_COL_MOUNT_HERE" (
  in parent_id any,
  in full_mount_path varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "DynaRes_DAV_DELETE" (
  in detcol_id any,
  in path_parts any,
  in what char(1),
  in silent integer,
  in auth_uid integer) returns integer
{
  declare id any;
  -- dbg_obj_princ ('DynaRes_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  if ('R' <> what)
    return -20;

  id := "DynaRes_DAV_SEARCH_ID" (detcol_id, path_parts, what);
  if (DAV_HIDE_ERROR (id) is null)
    return id;

  delete from WS.WS.DYNA_RES where DR_RES_ID = id[3] and DR_DETCOL_ID = id[1];
  return 0;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "DynaRes_DAV_RES_UPLOAD" (
  in detcol_id any,
  in path_parts any,
  inout content any,
  in type varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', content, type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "DynaRes_DAV_PROP_REMOVE" (
  in id any,
  in what char(0),
  in propname varchar,
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('DynaRes_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  if (propname = 'virt:aci_meta')
  {
    if (length (id) = 5)
      return 1;

    update WS.WS.DYNA_RES
       set DR_ACL = null
     where DR_RES_ID = id[3];

    return 1;
  }
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "DynaRes_DAV_PROP_SET" (
  in id any,
  in what char(0),
  in propname varchar,
  in propvalue any,
  in overwrite integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if ('R' = what)
  {
    if (':getcontenttype' = propname)
    {
      update WS.WS.DYNA_RES set DR_MIME = propvalue where DR_RES_ID = id[3];
      return 0;
    }
    if (':virtowneruid' = propname)
    {
      if (not exists (select top 1 1 from WS.WS.SYS_DAV_USER where U_ID = propvalue))
        propvalue := 0;

      update WS.WS.DYNA_RES set DR_OWNER_UID = propvalue where DR_RES_ID = id[3];
      return 0;
    }
    if (':virtownergid' = propname)
    {
      if (not exists (select top 1 1 from WS.WS.SYS_DAV_GROUP where G_ID = propvalue))
        propvalue := 0;

      update WS.WS.DYNA_RES set DR_OWNER_GID = propvalue where DR_RES_ID = id[3];
      return 0;
    }
    if (':virtpermissions' = propname)
    {
      if (regexp_match (DAV_REGEXP_PATTERN_FOR_PERM (), propvalue) is null)
        return -17;

      update WS.WS.DYNA_RES set DR_PERMS = propvalue where DR_RES_ID = id[3];
      return 0;
    }
    if (propname = 'virt:aci_meta_n3')
    {
      if (length (id) = 5)
        return 0;

      update WS.WS.DYNA_RES set DR_ACL = propvalue where DR_RES_ID = id[3];
      return 0;
    }
  }
  if (propname[0] = 58)
    return -16;

  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "DynaRes_DAV_PROP_GET" (
  in id any,
  in what char(0),
  in propname varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('DynaRes_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  if ('R' = what)
  {
    if (':getcontenttype' = propname)
    {
      return (select DR_MIME from WS.WS.DYNA_RES where DR_RES_ID = id[3]);
    }
    if (':virtowneruid' = propname)
    {
      return (select DR_OWNER_UID from WS.WS.DYNA_RES where DR_RES_ID = id[3]);
    }
    if (':virtownergid' = propname)
    {
      return (select DR_OWNER_GID from WS.WS.DYNA_RES where DR_RES_ID = id[3]);
    }
    if (':virtpermissions' = propname)
    {
      return (select DR_PERMS from WS.WS.DYNA_RES where DR_RES_ID = id[3]);
    }
    if ('virt:aci_meta_n3' = propname)
  {
    return (select DR_ACL from WS.WS.DYNA_RES where DR_RES_ID = id[3]);
  }
  }
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "DynaRes_DAV_PROP_LIST" (
  in id any,
  in what char(0),
  in propmask varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('DynaRes_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "DynaRes_DAV_DIR_SINGLE" (
  in id any,
  in what char(0),
  in path any,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');

  if ('R' = what)
  {
    for (select DR_NAME, DR_LAST_LENGTH, DR_CREATED_DT, DR_PERMS, DR_OWNER_UID, DR_OWNER_GID, DR_MODIFIED_DT, DR_MIME, DR_ACL
           from WS.WS.DYNA_RES
          where DR_RES_ID = id[3] and DR_DETCOL_ID = id[1] and DR_NAME is not null) do
    {
      if (length (id) = 4)
        return vector (DAV_SEARCH_PATH (id[1], 'C') || DR_NAME, 'R', coalesce (DR_LAST_LENGTH, 1024), DR_CREATED_DT, id, DR_PERMS, DR_OWNER_GID, DR_OWNER_UID, DR_MODIFIED_DT, DR_MIME, DR_NAME);

      if ((length (id) = 5) and not DB.DBA.is_empty_or_null (DR_ACL))
        return vector (DAV_SEARCH_PATH (id[1], 'C') || DR_NAME || ',acl', 'R', coalesce (DR_LAST_LENGTH, 1024), DR_CREATED_DT, id, DR_PERMS, DR_OWNER_GID, DR_OWNER_UID, DR_MODIFIED_DT, 'text/n3', DR_NAME || ',acl');
    }
  }
  return -1;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "DynaRes_DAV_DIR_LIST" (
  in detcol_id any,
  in path_parts any,
  in detcol_path varchar,
  in name_mask varchar,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  declare top_davpath varchar;
  declare res any;
  declare top_id any;
  declare what char (1);

  if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
    what := 'C';
  else
    what := 'R';

  if ('C' = what and 1 = length(path_parts))
    top_id := vector (DynaRes__detName (), detcol_id, null);
  else
    top_id := "DynaRes_DAV_SEARCH_ID" (detcol_id, path_parts, what);

  if (DAV_HIDE_ERROR (top_id) is null)
    return vector();

  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
    return vector ("DynaRes_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));

  vectorbld_init (res);
  if (top_id[2] is null)
  {
    for (select DR_RES_ID, DR_NAME, DR_LAST_LENGTH, DR_CREATED_DT, DR_PERMS, DR_OWNER_UID, DR_OWNER_GID, DR_MODIFIED_DT, DR_MIME, DR_ACL
           from WS.WS.DYNA_RES
          where DR_DETCOL_ID = detcol_id) do
    {
      vectorbld_acc (res, vector (top_davpath || DR_NAME, 'R', coalesce (DR_LAST_LENGTH, 1024), DR_CREATED_DT,
        vector (DynaRes__detName (), detcol_id, null, DR_RES_ID), DR_PERMS, DR_OWNER_GID, DR_OWNER_UID, DR_MODIFIED_DT, DR_MIME, DR_NAME ) );

      if (not DB.DBA.is_empty_or_null (DR_ACL))
        vectorbld_acc (res, vector (top_davpath || DR_NAME || ',acl', 'R', length (DR_ACL), DR_CREATED_DT,
          vector (DynaRes__detName (), detcol_id, null, DR_RES_ID), DR_PERMS, DR_OWNER_GID, DR_OWNER_UID, DR_MODIFIED_DT, 'text/n3', DR_NAME || ',acl') );
    }
  }
  vectorbld_final (res);

  return res;
}
;

create procedure "DynaRes_DAV_FC_PRED_METAS" (
  inout pred_metas any)
{
  pred_metas := vector (
    'RES_ID',           vector ('DYNA_RES'  , 0, 'any'      , 'vector (UNAME''DynaRes'', DR_DETCOL_ID, null, DR_RES_ID)'  ),
    'RES_ID_SERIALIZED',vector ('DYNA_RES'  , 0, 'varchar'  , 'serialize (vector (UNAME''DynaRes'', DR_DETCOL_ID, null, DR_RES_ID))' ),
    'RES_NAME',         vector ('DYNA_RES'  , 0, 'varchar'  , 'DR_NAME'  ),
    'RES_FULL_PATH',    vector ('DYNA_RES'  , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, null), DR_NAME)'  ),
    'RES_TYPE',         vector ('DYNA_RES'  , 0, 'varchar'  , 'DR_MIME'  ),
    'RES_OWNER_ID',     vector ('DYNA_RES'  , 0, 'integer'  , 'DR_OWNER_UID'  ),
    'RES_OWNER_NAME',   vector ('DYNA_RES'  , 0, 'varchar'  , '(select U_NAME from DB.DBA.SYS_USERS where U_ID=DR_OWNER_UID)'  ),
    'RES_GROUP_ID',     vector ('DYNA_RES'  , 0, 'integer'  , 'DR_OWNER_GID'  ),
    'RES_GROUP_NAME',   vector ('DYNA_RES'  , 0, 'varchar'  , '(select U_NAME from DB.DBA.SYS_USERS where U_ID=DR_OWNER_GID)'  ),
    'RES_COL_FULL_PATH',vector ('DYNA_RES'  , 0, 'varchar'  , '(_param.detcolpath'  ),
    'RES_COL_NAME',     vector ('DYNA_RES'  , 0, 'varchar'  , 'null'  ),
     -- 'RES_COL_ID',   vector ('SYS_DAV_RES'  , 0, 'varchar'  , 'RES_COL'  ),
    'RES_CR_TIME',      vector ('DYNA_RES'  , 0, 'datetime' , 'DR_CREATED_DT'  ),
    'RES_MOD_TIME',     vector ('DYNA_RES'  , 0, 'datetime' , 'DR_MODIFIED_DT'  ),
    'RES_PERMS',        vector ('DYNA_RES'  , 0, 'varchar'  , 'DR_PERMS'  ),
    'RES_CONTENT',      vector ('DYNA_RES'  , 0, 'text'     , 'coalesce (DR_CONTENT, ''(dynamic)'')'  ),
    'PROP_NAME',        vector ('DYNA_RES'  , 0, 'varchar'  , '(''Content'')'  ),
    'PROP_VALUE',       vector ('DYNA_RES'  , 1, 'text'     , 'coalesce (DR_CONTENT, ''(dynamic)'')'  ),
    'RES_TAGS',         vector ('DYNA_RES'  , 0, 'varchar'  , '('''')'  ), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',  vector ('DYNA_RES'  , 0, 'varchar'  , '('''')'  ),
    'RES_PRIVATE_TAGS', vector ('DYNA_RES'  , 0, 'varchar'  , '('''')'  ),
    'RDF_PROP',         vector ('DYNA_RES'  , 1, 'varchar'  , NULL  ),
    'RDF_VALUE',        vector ('DYNA_RES'  , 2, 'XML'  , NULL  ),
    'RDF_OBJ_VALUE',    vector ('DYNA_RES'  , 3, 'XML'  , NULL  )
    );
}
;

create procedure "DynaRes_DAV_FC_TABLE_METAS" (
  inout table_metas any)
{
  table_metas := vector (
    'DYNA_RES', vector ('\n  inner join WS.WS.DYNA_RES as ^{alias}^ on ((^{alias}^.DR_RES_ID = _top.DR_RES_ID)^{andpredicates}^)', 'DR_CONTENT'  , 'DR_CONTENT'  , '[__quiet] /' )
  );
}
;

-- This prints the fragment that starts after 'FROM WS.WS.DYNA_RES' and contains the rest of FROM and whole 'WHERE'
create function "DynaRes_DAV_FC_PRINT_WHERE" (
  inout filter any,
  in param_uid integer) returns varchar
{
  -- dbg_obj_princ ('DynaRes_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;

  "DynaRes_DAV_FC_PRED_METAS" (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  "DynaRes_DAV_FC_TABLE_METAS" (table_metas);
  used_tables := vector (
    'DYNA_RES', vector ('DYNA_RES', '_top', null, vector (), vector (), vector ())
    );
  return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "DynaRes_DAV_DIR_FILTER" (
  in detcol_id any,
  in path_parts any,
  in detcol_path any,
  inout compilation any,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  declare st, qry_text, execstate, execmessage varchar;
  declare res any;
  declare cond_list, execmeta, execrows any;
  declare condtext, cond_key varchar;

  vectorbld_init (res);
  cond_list := get_keyword ('', compilation);
  condtext := "DynaRes_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
  compilation := vector_concat (compilation, vector (cond_key, condtext));
  execstate := '00000';
  qry_text :=
    ' select DAV_CONCAT_PATH (?, _top.DR_NAME), ''R'', _top.DR_LAST_LENGTH, coalesce (_top.DR_MODIFIED_DT, now ()), vector (UNAME''DynaRes'', _top.DR_DETCOL_ID, null, _top.DR_RES_ID), _top.DR_PERMS, _top.DR_OWNER_GID, _top.DR_OWNER_UID, _top.DR_CREATED_DT, _top.DR_MIME, _top.DR_NAME' ||
    '   from WS.WS.DYNA_RES as _top ' ||
    condtext ||
    '    and _top.DR_DETCOL_ID = ? ';
  exec (qry_text, execstate, execmessage, vector (detcol_path, detcol_id), 100000000, execmeta, execrows);
  if ('00000' <> execstate)
    signal (execstate, execmessage || ' in ' || qry_text);

  vectorbld_concat_acc (res, execrows);

  qry_text :=
    ' select DAV_CONCAT_PATH (?, _top.DR_NAME, '',acl''), ''R'', _top.DR_LAST_LENGTH, coalesce (_top.DR_MODIFIED_DT, now ()), vector (UNAME''DynaRes'', _top.DR_DETCOL_ID, null, _top.DR_RES_ID, 1), _top.DR_PERMS, _top.DR_OWNER_GID, _top.DR_OWNER_UID, _top.DR_CREATED_DT, ''text/n3'', concat (_top.DR_NAME, '',acl'')' ||
    '   from WS.WS.DYNA_RES as _top ' ||
    condtext ||
    '    and _top.DR_ACL is not null and _top.DR_DETCOL_ID = ? ';
  exec (qry_text, execstate, execmessage, vector (detcol_path, detcol_id), 100000000, execmeta, execrows);
  if ('00000' <> execstate)
    signal (execstate, execmessage || ' in ' || qry_text);

  vectorbld_concat_acc (res, execrows);

finalize:
  vectorbld_final (res);
  return res;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "DynaRes_DAV_SEARCH_ID" (
  in detcol_id any,
  in path_parts any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  declare _name varchar;
  declare _res_id, _length integer;

  if (path_parts[0] = '' or path_parts[0] is null)
    return -1;

  _length := length (path_parts);
  if (0 = _length)
  {
    if ('C' <> what)
      return -1;

    return vector (DynaRes__detName (), detcol_id, null, null);
  }
  _name := path_parts[_length - 1];
  if ('' = _name)
  {
    if ('C' <> what)
      return -1;
  }
  else
  {
    if ('R' <> what)
      return -1;
  }
  if (_name like '%,acl')
  {
    _name := subseq (_name, 0, length (_name)-4);
    _res_id := (select DR_RES_ID from WS.WS.DYNA_RES where DR_DETCOL_ID = detcol_id and DR_NAME = _name);
    if (_res_id is not null)
      return vector (DynaRes__detName (), detcol_id, null, _res_id, 1);
  }
  else
  {
    _res_id := (select DR_RES_ID from WS.WS.DYNA_RES where DR_DETCOL_ID = detcol_id and DR_NAME = _name);
    if (_res_id is not null)
      return vector (DynaRes__detName (), detcol_id, null, _res_id);
  }
  return -1;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "DynaRes_DAV_SEARCH_PATH" (
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_SEARCH_PATH (', id, what, ')');
  if (what <> 'R')
    return null;

  for select DR_NAME from WS.WS.DYNA_RES where DR_RES_ID = id[3] and DR_DETCOL_ID = id[1] do
  {
    if (length (id) = 4)
      return concat (DAV_SEARCH_PATH (id[1], 'C'), DR_NAME);

    return concat (DAV_SEARCH_PATH (id[1], 'C'), DR_NAME || ',acl');
  }

  return null;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "DynaRes_DAV_RES_UPLOAD_COPY" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "DynaRes_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "DynaRes_DAV_RES_CONTENT" (
  in id any,
  inout content any,
  out type varchar,
  in content_mode integer) returns integer
{
  -- dbg_obj_princ ('DynaRes_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare c cursor for select
    DR_NAME, DR_PERMS, DR_OWNER_UID, DR_OWNER_GID, DR_CREATED_DT, DR_MODIFIED_DT, DR_REFRESH_DT, DR_DELETE_DT,
    DR_REFRESH_SECONDS, DR_MIME, DR_EXEC_STMT, deserialize (DR_EXEC_PARAMS), DR_EXEC_UNAME, DR_CONTENT
    from WS.WS.DYNA_RES where DR_RES_ID = id[3] and DR_DETCOL_ID = id[1] for update;
  declare c_name, c_perms varchar;
  declare c_owner_uid, c_owner_gid integer;
  declare c_created_dt, c_modified_dt, c_refresh_dt, c_delete_dt datetime;
  declare c_refresh_seconds integer;
  declare c_mime, c_exec_stmt varchar;
  declare c_exec_params any;
  declare c_exec_uname varchar;
  declare c_last_length integer;
  declare c_content any;
  declare stat, msg varchar;
  declare mdta, rset any;

  if (length (id) = 4)
  {
    set isolation = 'committed';
    for (select DR_MIME, DR_CONTENT
           from WS.WS.DYNA_RES
          where DR_RES_ID = id[3]
            and DR_DETCOL_ID = id[1]
            and DR_MODIFIED_DT is not null
            and (DR_REFRESH_DT is null or DR_REFRESH_DT > now())
            and (DR_DELETE_DT is null or DR_DELETE_DT > now())) do
    {
      type := DR_MIME;
      if ((content_mode = 0) or (content_mode = 2))
        content := DR_CONTENT;

      else if (content_mode = 1)
        http (DR_CONTENT, content);

      else if (content_mode = 3)
        http (DR_CONTENT);

      return 0;
    }

    set isolation = 'serializable';
    whenever not found goto nf;
    open c;
    fetch c into c_name, c_perms, c_owner_uid, c_owner_gid, c_created_dt, c_modified_dt, c_refresh_dt, c_delete_dt,
      c_refresh_seconds, c_mime, c_exec_stmt, c_exec_params, c_exec_uname, c_content;
    if (c_modified_dt is not null
      and (c_refresh_dt is null or c_refresh_dt > now())
      and (c_delete_dt is null or c_delete_dt > now()) )
      {
        -- dbg_obj_princ ('content is fresh');
        type := c_mime;
        close c;
        goto content_ready;
      }
    if (c_delete_dt is not null and c_delete_dt <= now())
      {
        -- dbg_obj_princ ('should be deleted');
        delete from WS.WS.DYNA_RES where current of c;
        return -1;
      }
    update WS.WS.DYNA_RES set DR_MODIFIED_DT = null where current of c;
    set_user_id (c_exec_uname, 1);
    stat := '00000';
    -- dbg_obj_princ ('About to exec (', c_exec_stmt, stat, msg, c_exec_params, 1, '[mdta], [rset])');
    exec (c_exec_stmt, stat, msg, c_exec_params, 1, mdta, rset);
    if (stat <> '00000')
      {
        update WS.WS.DYNA_RES set DR_MODIFIED_DT = c_modified_dt where current of c;
        commit work;
        signal (stat, msg);
      }
    c_content := rset[0][0];
    update WS.WS.DYNA_RES set DR_MODIFIED_DT = now(), DR_REFRESH_DT = dateadd ('second', c_refresh_seconds, now()),
      DR_LAST_LENGTH=length (c_content), DR_CONTENT=c_content
    where current of c;
    commit work;
    type := c_mime;
    close c;
  }
  else
  {
    select DR_ACL into c_content from WS.WS.DYNA_RES where DR_RES_ID = id[3] and DR_DETCOL_ID = id[1];
    type := 'text/n3';
  }

content_ready:
  if ((content_mode = 0) or (content_mode = 2))
    content := c_content;
  else if (content_mode = 1)
    http (c_content, content);
  else if (content_mode = 3)
    http (c_content);
  return 0;

nf:
  return -1;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "DynaRes_DAV_SYMLINK" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite integer,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "DynaRes_DAV_DEREFERENCE_LIST" (
  in detcol_id any,
  inout report_array any) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "DynaRes_DAV_RESOLVE_PATH" (
  in detcol_id any,
  inout reference_item any,
  inout old_base varchar,
  inout new_base varchar) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "DynaRes_DAV_LOCK" (
  in path any,
  in id any,
  in type char(1),
  inout locktype varchar,
  inout scope varchar,
  in token varchar,
  inout owner_name varchar,
  inout owned_tokens varchar,
  in depth varchar,
  in timeout_sec integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;

--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "DynaRes_DAV_UNLOCK" (
  in id any,
  in type char(1),
  in token varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('DynaRes_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "DynaRes_DAV_IS_LOCKED" (
  inout id any,
  inout type char(1),
  in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('DynaRes_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "DynaRes_DAV_LIST_LOCKS" (
  in id any,
  in type char(1),
  in recursive integer) returns any
{
  -- dbg_obj_princ ('DynaRes_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;


create procedure "DynaRes_CF_PROPNAME_TO_COLNAME" (
  in prop varchar)
{
  return null;
}
;

create procedure "DynaRes_CF_FEED_FROM_AND_WHERE" (
  in detcol_id integer,
  in cfc_id integer,
  inout rfc_list_cond any,
  inout filter_data any,
  in distexpn varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('DynaRes_CF_FEED_FROM_AND_WHERE (', detcol_id, cfc_id, rfc_list_cond, filter_data, distexpn, auth_uid, ')');
  declare where_clause, from_clause varchar;
  declare proppos, filter_len, filter_idx integer;

  from_clause := '
  from
    WS.WS.DYNA_RES as DR
';
  where_clause := 'DR.DETCOL_ID = ' || cast (detcol_id as varchar);
  filter_len := length (filter_data);
  for (filter_idx := 0; filter_idx < (filter_len - 3); filter_idx := filter_idx + 4)
  {
    declare mode integer;
    declare cmp_col, cmp_val varchar;

    cmp_col := "DynaRes_CF_PROPNAME_TO_COLNAME" (filter_data [filter_idx]);
    cmp_val := filter_data [filter_idx + 2];
    if (cmp_col is null)
      {
        if ('' <> cmp_val)
          {
            where_clause := '1 = 2';
            goto where_clause_complete;
          }
        goto where_oper_complete;
      }
    if (where_clause <> '')
      where_clause := where_clause || ' and ';
    mode := filter_data [filter_idx + 3];
    if (mode = 0)
      where_clause := where_clause || sprintf ('(%s = %s)', cmp_col, WS.WS.STR_SQL_APOS (cmp_val));
    else if (mode = 4)
      where_clause := where_clause || sprintf ('(%s is null)', cmp_col);
    else -- truncation
      where_clause := where_clause || sprintf ('(%s between %s and %s)', cmp_col, WS.WS.STR_SQL_APOS (cmp_val), WS.WS.STR_SQL_APOS (cmp_val || '\377\377\377\377'));
where_oper_complete:
      ;
  }

where_clause_complete:
  if (where_clause <> '')
    return from_clause || ' where ' || where_clause;

  return from_clause;
}
;

create procedure "DynaRes_CF_LIST_PROP_DISTVALS" (
  in detcol_id integer,
  in cfc_id integer,
  in rfc_spath varchar,
  inout rfc_list_cond any,
  in schema_uri varchar,
  inout filter_data any,
  inout distval_dict any,
  in auth_uid integer)
{
  -- dbg_obj_princ ('DynaRes_CF_LIST_PROP_DISTVALS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, distval_dict, auth_uid, ')');
  declare distprop, distexpn varchar;
  declare from_and_where_text, qry_text varchar;
  declare execstate, execmessage varchar;
  declare execmeta, execrows any;

  if (schema_uri = 'http://purl.org/rss/1.0/')
  {
    -- channel description
    distprop := filter_data[length (filter_data) - 2];
    distexpn := "DynaRes_CF_PROPNAME_TO_COLNAME" (distprop);
    if (distexpn is null)
    {
      dict_put (distval_dict, '! empty property value !', 1);
      return;
    }
    from_and_where_text := Blog_CF_FEED_FROM_AND_WHERE (detcol_id, cfc_id, rfc_list_cond, filter_data, distexpn, auth_uid);
    qry_text := 'select distinct ' || distexpn || from_and_where_text;
    execstate := '00000';
    execmessage := 'OK';
    exec (qry_text, execstate, execmessage, vector (), 100000000, execmeta, execrows );
    if (isarray (execrows))
      foreach (any execrow in execrows) do
      {
        dict_put (distval_dict, "CatFilter_ENCODE_CATVALUE" (execrow[0]), 1);
      }
  }
}
;

create function "DynaRes_CF_GET_RDF_HITS" (
  in detcol_id integer,
  in cfc_id integer,
  in rfc_spath varchar,
  inout rfc_list_cond any,
  in schema_uri varchar,
  inout filter_data any,
  in detcol_path varchar,
  in make_diritems integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('\n\n\nDynaRes_CF_GET_RDF_HITS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ')');
  declare from_and_where_text, qry_text varchar;
  declare execstate, execmessage varchar;
  declare acc_len, acc_ctr integer;
  declare execmeta, acc any;
  declare owner_uid integer;

  acc := vector ();
  acc_len := 0;
  if (schema_uri = 'http://purl.org/rss/1.0/')
  {
    -- channel description
    from_and_where_text := Blog_CF_FEED_FROM_AND_WHERE (detcol_id, cfc_id, rfc_list_cond, filter_data, 'DR.DR_NAME', auth_uid);
    qry_text := 'select DR.DR_NAME' || from_and_where_text;
    execstate := '00000';
    execmessage := 'OK';
    exec (qry_text, execstate, execmessage, vector (), 100000000, execmeta, acc );
    acc_len := length (acc);
    acc_ctr := 0;
    owner_uid := (select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = detcol_id);
    while (acc_ctr < acc_len)
    {
      declare r_id integer;
      declare fullname varchar;
      declare full_id, diritm any;

      r_id := acc[acc_ctr][0];
      full_id := vector (DynaRes__detName (), detcol_id, r_id, owner_uid, null, null);
      if (make_diritems = 1)
      {
        diritm := "DynaRes_DAV_DIR_SINGLE" (full_id, 'R', '(fake path)', auth_uid);
        if (DAV_HIDE_ERROR (diritm) is not null)
        {
          diritm [0] := DAV_CONCAT_PATH (detcol_path, diritm[10]); -- now we can remove the fake path.
          acc [acc_ctr] := diritm;
          acc_ctr := acc_ctr + 1;
        }
        else --collision in the air: someone just removed the resource from the disk :(
        {
          if (acc_len > 1)
          {
            acc [acc_ctr] := acc [acc_len - 1];
            acc_len := acc_len - 1;
          }
        }
      }
      else
      {
        acc [acc_ctr] := full_id;
        acc_ctr := acc_ctr + 1;
      }
    }
  }
  if (acc_len < length (acc)) -- There were collisions in the air
    acc := subseq (acc, 0, acc_len);

  return acc;
}
;

create function "DynaRes_INSERT_RESOURCE" (
  in detcol_id integer,
  inout content any,
  in fname varchar := null,
  in perms varchar := null,
  in owner_uid integer := null,
  in owner_gid integer := null,
  in refresh_seconds integer := null,
  in ttl_seconds integer := 172800,
  in mime varchar := null,
  in exec_stmt varchar := null,
  in exec_params any := null,
  in exec_uname varchar := 'nobody')
{
  if (refresh_seconds is not null and exec_stmt is null)
    signal ('DR001', 'Can not refresh a resource without some statement specified to execute');
  if ((exec_uname <> USER) and (USER <> 'dba'))
    signal ('DR002', 'Only dba can set UID of other user for refreshing statement of a dynamic resource');
  if (refresh_seconds is not null and refresh_seconds < 5)
    signal ('DR003', 'The refresh interfal should be not less than 5 seconds');
  if (ttl_seconds is not null and ttl_seconds < 180)
    signal ('DR004', 'The time to live interfal should be not less than 180 seconds');
  if (exec_stmt is null and content is null)
    signal ('DR005', 'No content and no statement to execute, so nothing to create');
  if (not exists (select top 1 1 from WS.WS.SYS_DAV_COL where COL_ID = detcol_id and COL_DET='DynaRes'))
    signal ('DR006', 'The DET collection ID is not valid');
  if (fname is not null and exists (select top 1 1 from WS.WS.DYNA_RES where DR_NAME = fname and DR_DETCOL_ID = detcol_id))
    signal ('DR007', sprintf ('The dynamic resource "%.500s" already exists', fname));
  if (content is null)
  {
    declare stat, msg varchar;
    declare mdta, rset any;

    stat := '00000';
    exec (exec_stmt, stat, msg, exec_params, 1, mdta, rset);
    if (stat <> '00000')
      signal (stat, msg);

    content := rset[0][0];
    if (content is null)
      signal ('DR007', 'No content and the statement returns NULL, so nothing to create');
  }
  insert replacing WS.WS.DYNA_RES (
    DR_RES_ID,
    DR_DETCOL_ID,
    DR_NAME,
    DR_PERMS,
    DR_OWNER_UID,
    DR_OWNER_GID,
    DR_CREATED_DT,
    DR_MODIFIED_DT,
    DR_REFRESH_DT,
    DR_DELETE_DT,
    DR_REFRESH_SECONDS,
    DR_MIME,
    DR_EXEC_STMT,
    DR_EXEC_PARAMS,
    DR_EXEC_UNAME,
    DR_LAST_LENGTH,
    DR_CONTENT)
  values (
    sequence_next ('WS.WS.DYNA_RES_ID'),
    detcol_id,
    coalesce (fname, sprintf ('%.100s - untitled resource - made by %.100s', cast (now() as varchar), USER)),
    coalesce (perms, '110000000N'),
    coalesce (owner_uid, http_dav_uid()),
    coalesce (owner_gid, http_nogroup_gid()),
    now(),
    now(),
    case when (refresh_seconds is null) then null else dateadd ('second', refresh_seconds, now()) end,
    case when (ttl_seconds is null) then null else dateadd ('second', ttl_seconds, now()) end,
    refresh_seconds,
    coalesce (mime, 'text/plain'),
    exec_stmt,
    serialize (exec_params),
    exec_uname,
    length (content),
    content );
}
;
