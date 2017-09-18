--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
--  WebDAV Virtuoso/PL API
--
-- DAV_ADD_USER         - create/update dav user
-- DAV_DELETE_USER      - remove dav user
-- DAV_HOME_DIR         - returns user's home collection
-- DAV_ADD_GROUP        - create group
-- DAV_DELETE_GROUP     - remove group
-- DAV_DIR_LIST         - simplest analog of dir command
-- DAV_SEARCH_PATH      - return full path string from id
-- DAV_SEARCH_ID        - return id from full path string
-- DAV_IS_LOCKED        - checks item for locks
-- DAV_LIST_LOCKS       - list all locks of an item
-- DAV_AUTHENTICATE     - checks authentication
-- DAV_COL_CREATE       - create collection
-- DAV_RES_UPLOAD       - create/update resource
-- DAV_DELETE           - remove dav item
-- DAV_COPY             - copy dav item
-- DAV_MOVE             - move/rename dav item
-- DAV_PROP_GET         - get custom dav property of an item (or all custom props at once)
-- DAV_PROP_LIST        - get vector of custom dav properties of an item (or all custom props at once)
-- DAV_PROP_SET         - set/update custom dav property
-- DAV_PROP_REMOVE      - remove custom dav property
--
-- XXX: IMPORTANT note: Full path string of:
--      1) collection MUST have a trailing slash,
--      2) resources MUST NOT have a trailing slash

create procedure DAV_VERSION ()
{
  return '1.0';
}
;

create function DAV_PERROR (in x any)
{
  declare errlist any;
  if (not isinteger (x))
    return NULL;
  if (x >= 0)
    return NULL;
  if (x = -44) -- __SQL_ERROR
    return sprintf ('(%d) %s', x, connection_get ('__sql_message'));
  if (x < -44) -- When you add a new error, change the limit value here!
    return sprintf ('(%d) Unspecified error', x);
  errlist := vector (
    '(-01) The path (target of operation) is not valid',
    '(-02) The destination (path) is not valid',
    '(-03) Overwrite flag is not set and destination exists',
    '(-04) The target is resource, but source is collection (in copy move operations)',
    '(-05) Permissions are not valid',
    '(-06) uid is not valid',
    '(-07) gid is not valid',
    '(-08) Target is locked',
    '(-09) Destination is locked',
    '(-10) Property name is reserved (protected or private)',
    '(-11) Property does not exist',
    '(-12) Authentication failed',
    '(-13) Operation is forbidden (the authenticated user does not have permissions for the action)',
    '(-14) The target type is not valid',
    '(-15) The umask is not valid',
    '(-16) The property already exists',
    '(-17) Invalid property value',
    '(-18) no such user',
    '(-19) no home directory',
    '(-20) The operation is not supported by a DET',
    '(-21) DET can not restore the full DAV path by id',
    '(-22) Corrupted id',
    '(-23) The id does not correspond to any resource that exists now',
    '(-24) Authentication failed and requested',
    '(-25) Can not create collection if a resource with same name exists',
    '(-26) Can not create resource if a collection with same name exists',
    '(-27) Target is not locked',
    '(-28) Unqualified error',
    '(-29) Transaction deadlock at the end of resource upload, after reading from session',
    '(-30) The target is nested into source',
    '(-31) Built-in system account can not be changed',
    '(-32) Property that can control execution of SQL statements can be changed only by SQL-enabled user',
    '(-33) The DET resource or collection ID is rejected, the operation supports only plain DAV',
    '(-34) The path (target of operation) is not valid: no parent collection exists',
    '(-35) Failed dependency on lock operation',
    '(-36) Appropriate property virt:Versioning-* has not been set',
    '(-37) Operation is not supported for resource of this type',
    '(-38) Semantics is violated',
    '(-39) Recursive operation on CatFilter is impossible',
    '(-40) The path (target of operation) does not match naming convention that is used by DET',
    '(-41) The size of DAV collection subtree is out of quota',
    '(-42) The resource is unavailable because resource owner is disabled',
    '(-43) Access to a home DAV collection of a disabled account is blocked'
    ); -- When you add a new error, change the limit value above!
  return errlist [-(x+1)];
}
;


create procedure
DAV_ADD_USER_INT (in uid varchar,
                  in pwd varchar,
                  in gid any,
                  in perms varchar,
                  in disable integer,
                  in home varchar,
                  in full_name varchar,
                  in email varchar)
{
  declare id, gd, rc integer;
  if (not exists (select 1 from WS.WS.SYS_DAV_USER where U_NAME = uid))
    {
      USER_CREATE (uid, pwd, vector ('SQL_ENABLE', 0, 'DAV_ENABLE', 1, 'PRIMARY_GROUP', gid,
            'HOME', home, 'E-MAIL', email, 'FULL_NAME', full_name, 'PERMISSIONS', perms, 'DISABLED', disable));
    }
  else
    {
      id := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uid), NULL);
      if (id < 100)
        return -31;
      if (isstring (gid))
        gd := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = gid), NULL);
      else if (isinteger (gid) and exists (select 1 from WS.WS.SYS_DAV_GROUP where G_ID = gid))
        gd := gid;
      else
        gd := NULL;
      if (gid = http_nogroup_gid ())
        return -31;

      if (id is not null)
        {
          update WS.WS.SYS_DAV_USER set
              U_GROUP = gd,
              U_DEF_PERMS = perms,
              U_FULL_NAME = full_name,
              U_PWD = pwd_magic_calc (uid, pwd),
              U_E_MAIL = email,
              U_ACCOUNT_DISABLED = disable,
              U_HOME = home
          where
            U_NAME = uid;
        }
    }
  return id;
}
;

--!AWK PUBLIC
create procedure
DAV_ADD_USER (in uid varchar, in pwd varchar, in gid varchar,
              in perms varchar, in disable integer,
              in home varchar, in full_name varchar, in email varchar,
              in auth_uname varchar := NULL,
              in auth_pwd varchar := NULL
              )
{
  declare rc, make_dir integer;

  if (DAV_CHECK_AUTH (auth_uname, auth_pwd, 1) < 0)
    return -12;

  make_dir := 0;

  if (not exists (select 1 from WS.WS.SYS_DAV_USER where U_NAME = uid))
    make_dir := 1;

  rc := DAV_ADD_USER_INT (uid, pwd, gid, perms, disable, home, full_name, email);
  if (rc < 0)
    return rc;

  if (make_dir)
    {
      if (isstring (home))
        {
          if (0 > (rc := DAV_COL_CREATE (home, perms, uid, gid, auth_uname, auth_pwd)))
            {
              rollback work;
              return rc;
            }
        }
    }
  return rc;
}
;

--!AWK PUBLIC
create procedure
DAV_DELETE_USER (in uid varchar, in auth_uname varchar := NULL, in auth_pwd varchar := NULL)
{
  declare known_u_id integer;
  if (DAV_CHECK_AUTH (auth_uname, auth_pwd, 1) < 0)
    return -12;
  known_u_id := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uid), NULL);
  if (known_u_id < 100)
    return -31;

  delete from WS.WS.SYS_DAV_TAG where DT_U_ID = known_u_id;
  delete from WS.WS.SYS_DAV_USER where U_NAME = uid;
  return 0;
}
;

--!AWK PUBLIC
create function DAV_REGEXP_PATTERN_FOR_PERM () returns varchar {
  return '^[01][01][01][01][01][01][01][01][01]([NTR-]([NMR-])?)?\044';
}
;

create function DAV_REGEXP_PATTERN_FOR_UNIX_PERM () returns varchar {
  return '^[r\\-][w\\-][x\\-][r\\-][w\\-][x\\-][r\\-][w\\-][x\\-]([NTR-]([NMR-])?)?\044';
}
;

--!AWK PUBLIC
create function
DAV_PERM_D2U (in perms varchar)
{
  declare res any;
  declare i int;
  res := perms;
  if (regexp_match (DAV_REGEXP_PATTERN_FOR_PERM (), res) is null)
    signal ('22023', 'Not valid permissions string');
  res := 'rwxrwxrwx' || upper (subseq (perms, 9));
  while (i < 9)
    {
      if (perms[i] = ascii('0'))
        aset (res, i, ascii ('-'));
      i := i + 1;
    }
  return lower(res);
}
;

--!AWK PUBLIC
create procedure
DAV_PERM_U2D (in perms varchar)
{
  declare res any;
  declare i int;
  res := perms;
  if (regexp_match (DAV_REGEXP_PATTERN_FOR_PERM (), res) is not null)
    return perms;
  res := perms;
  if (regexp_match (DAV_REGEXP_PATTERN_FOR_UNIX_PERM (), res) is null)
    signal ('22023', 'Not valid permissions string');
  res := '000000000' || upper (subseq (perms, 9));
  while (i < 9)
    {
      if (perms[i] <> ascii('-'))
        aset (res, i, ascii ('1'));
      i := i + 1;
    }
  return res;
}
;

create function
DAV_CHECK_AUTH (in auth_uname varchar := NULL, in auth_pwd varchar := NULL, in adm integer := 0) returns integer
{
  declare pwd varchar;
  declare uid integer;
  whenever not found goto nf;

  if (adm)
    select U_PWD, U_ID into pwd, uid from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid () and U_NAME = auth_uname;
  else
    select U_PWD, U_ID into pwd, uid from WS.WS.SYS_DAV_USER where U_NAME = auth_uname;

  -- dbg_obj_princ ('DAV_CHECK_AUTH (', auth_uname, auth_pwd, adm, ') found user id=', uid, ', pwd=', pwd);
  if (isstring (pwd))
    {
      if ((pwd[0] = 0 and pwd_magic_calc (auth_uname, auth_pwd) = pwd) or (pwd[0] <> 0 and pwd = auth_pwd))
        return uid;
    }

nf:
  -- dbg_obj_princ ('DAV_CHECK_AUTH (', auth_uname, auth_pwd, adm, ') did not found user name');
  if (auth_uname is null)
    {
-- TBD here: there must be a check for anonymous access to DAV.
      return 1;
    }
  if (auth_uname = 'nobody')
    {
      return http_nobody_uid();
    }
  if (ftp_anonymous_check (auth_uname))
    return 1; -- No such in WS.WS.SYS_DAV_USER: dav is smallest but it is #2.

  return -12;
}
;

--!AWK PUBLIC
create function
DAV_HOME_DIR (in uid varchar) returns any
{
  declare res any;
  whenever not found goto er;
  select U_HOME into res from WS.WS.SYS_DAV_USER where U_NAME = uid;
  return coalesce (res, -19);
er:
  return -18;
}
;

create function DAV_HOME_DIR_CREATE (
  in uid varchar) returns any
{
  declare rc, rc2 integer;
  declare path varchar;
  declare exit handler for sqlstate '*' { return -1; };

  for (select U_ID as _uid, U_GROUP as _gid, U_DEF_PERMS as _permissions, U_HOME from SYS_USERS where U_NAME = uid) do
  {
    if (uid = 'nobody')
    {
      _uid := http_dav_uid ();
      _gid := http_admin_gid ();
      _permissions := '110100100R';
    }
    path := '/DAV/home/';
    rc := DAV_MAKE_DIR (path, http_dav_uid (), http_admin_gid (), '110100100R');
    if (isnull (DAV_HIDE_ERROR (rc)))
      goto _end;

    path := path || uid || '/';
    rc := DAV_MAKE_DIR (path, _uid, _gid, _permissions);
    if (isnull (DAV_HIDE_ERROR (rc)))
      goto _end;

    path := path || 'rdf_sink/';
    rc2 := DAV_MAKE_DIR (path, _uid, _gid, _permissions);
    if (isnull (DAV_HIDE_ERROR (rc2)))
    {
      rc := rc2;
      goto _end;
    }
    rc2 := DB.DBA.DAV_DET_RDF_PARAMS_SET_INT ('rdfSink', rc2, vector ('graph', 'urn:dav:' || replace (subseq (rtrim (path, '/'), 5), '/', ':'), 'sponger', 'on'));
    if (isnull (DAV_HIDE_ERROR (rc2)))
    {
      rc := rc2;
      goto _end;
    }
  }
_end:;
  return rc;
}
;

create procedure
DAV_ADD_GROUP_INT (in gid varchar)
{
  declare gd integer;
  gd := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = gid), 0);
  if (not gd)
    {
      gd := USER_ROLE_CREATE (gid, 1);
    }
  return gd;
}
;

--!AWK PUBLIC
create procedure
DAV_ADD_GROUP (in gid varchar, in auth_uname varchar := NULL, in auth_pwd varchar := NULL)
{
  if (DAV_CHECK_AUTH (auth_uname, auth_pwd, 1) < 0)
    return -12;
  return DAV_ADD_GROUP_INT (gid);
}
;

--!AWK PUBLIC
create procedure
DAV_DELETE_GROUP (in gid varchar, in auth_uname varchar := NULL, in auth_pwd varchar := NULL)
{
  declare known_g_id integer;
  if (DAV_CHECK_AUTH (auth_uname, auth_pwd, 1) < 0)
    return -12;
  known_g_id := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = gid), NULL);
  if (known_g_id < 100)
    return -31;
  delete from WS.WS.SYS_DAV_GROUP where G_NAME = gid;
  return 0;
}
;


--!AWK PUBLIC
create procedure
DAV_DIR_LIST (in path varchar := '/DAV/', in recursive integer, in auth_uname varchar, in auth_pwd varchar) returns any
{
  declare auth_uid integer;
  auth_uid := DAV_CHECK_AUTH (auth_uname, auth_pwd, 0);
  if (auth_uid < 0)
    return -12;
  -- dbg_obj_princ ('DAV_DIR_LIST (', path, recursive, auth_uname, auth_pwd, auth_uid, ')');
  return DAV_DIR_LIST_INT (path, recursive, '%', auth_uname, auth_pwd, auth_uid);
}
;

--!AWK PUBLIC
create procedure
DAV_DIR_FILTER (in path varchar := '/DAV/', in recursive integer := 0, inout filter any, in auth_uname varchar, in auth_pwd varchar) returns any
{
  declare auth_uid integer;
  declare compilation any;
  -- dbg_obj_princ ('DAV_DIR_FILTER (', path, recursive, filter, auth_uname, auth_pwd, ')');
  auth_uid := DAV_CHECK_AUTH (auth_uname, auth_pwd, 0);
  if (auth_uid < 0)
    return -12;
  compilation := vector ('', filter, 'DAV', DAV_FC_PRINT_WHERE (filter, auth_uid));
  -- dbg_obj_princ ('DAV_DIR_FILTER has compiled the filter as ', compilation);
  return DAV_DIR_FILTER_INT (path, recursive, compilation, auth_uname, auth_pwd, auth_uid);
}
;


create function
DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
{
  st := upper (st);
  if (isinteger (id))
    {
      if ('R' = st)
        return coalesce ((select RES_COL from WS.WS.SYS_DAV_RES where RES_ID = id), -1);
      if ('C' = st)
        return coalesce ((select COL_PARENT from WS.WS.SYS_DAV_COL where COL_ID = id), -1);
      return -14;
    }
  return call (cast (id[0] as varchar) || '_DAV_GET_PARENT') (id, st, path);
}
;


create function
DAV_DIR_SINGLE_INT (
  in did any,
  in st char (0),
  in path varchar,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in auth_uid integer := null,
  in extern integer := 1) returns any
{
  -- dbg_obj_princ ('DAV_DIR_SINGLE_INT (', did, st, path, auth_uname, auth_pwd, auth_uid, ')');
  declare rc integer;

  if (extern)
    {
  rc := DAV_AUTHENTICATE (did, st, '1__', auth_uname, auth_pwd, auth_uid);
  if (rc < 0)
    {
      declare auth_parent any;
      auth_parent := DAV_GET_PARENT (did, st, path);
      rc := DAV_AUTHENTICATE (auth_parent, 'C', '1__', auth_uname, auth_pwd, auth_uid);
      if (rc < 0)
        {
          -- dbg_obj_princ ('DAV_DIR_SINGLE_INT has failed authorization: ', rc);
          return rc;
        }
    }
  if (auth_uid is null)
    auth_uid := rc;
    }
  if (isarray (did))
    {
      if ('R' = st)
        return call (cast (did[0] as varchar) || '_DAV_DIR_SINGLE') (did, st, path, auth_uid);
      else
        return call (cast (did[0] as varchar) || '_DAV_DIR_LIST') (did, vector (''), path, '%', -1, auth_uid);
    }
  if ('R' = st)
    {
      return coalesce ((select vector (RES_FULL_PATH, 'R', DAV_RES_LENGTH (RES_CONTENT, RES_SIZE), RES_MOD_TIME,
            RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME )
        from WS.WS.SYS_DAV_RES
        where
          RES_ID = did ));
    }
  else
    {
      return coalesce ((select vector (WS.WS.COL_PATH (COL_ID), 'C', 0, COL_MOD_TIME,
            COL_ID, COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME, 'dav/unix-directory', COL_NAME)
        from WS.WS.SYS_DAV_COL
        where COL_ID = did ));
    }
}
;


create function
DAV_DIR_LIST_INT (in path varchar := '/DAV/', in rec_depth integer := 0, in name_mask varchar, in auth_uname varchar := null, in auth_pwd varchar := null, inout auth_uid integer := null) returns any
{
  declare rc, t, id, l integer;
  declare path_string, st, det varchar;
  declare did, detcol_id, detcol_path, det_subpath, res any;
  -- dbg_obj_princ ('DAV_DIR_LIST_INT (', path, rec_depth, name_mask, auth_uname, auth_pwd, auth_uid, ')');
  -- DAV_OWNER_ID (auth_uname, 0, uid, gid);
  path_string := path;
  did := DAV_SEARCH_SOME_ID_OR_DET (path, st, det, detcol_id, detcol_path, det_subpath);
  if (DAV_HIDE_ERROR (did) is null)
    return did;
  rc := DAV_AUTHENTICATE (did, st, '1__', auth_uname, auth_pwd, auth_uid);
  if (rc < 0)
    {
      if (rec_depth = -1)
        {
          declare auth_parent any;
          auth_parent := DAV_GET_PARENT (did, st, path);
          rc := DAV_AUTHENTICATE (auth_parent, 'C', '1__', auth_uname, auth_pwd, auth_uid);
        }
      if (rc < 0)
        {
          -- dbg_obj_princ ('DAV_DIR_LIST_INT has failed authorization: ', rc);
          return rc;
        }
    }
  if (auth_uid is null)
    auth_uid := rc;
  if (isarray (did))
    {
      if (('R' = st) or (rec_depth = -1))
        res := vector (call (cast (did[0] as varchar) || '_DAV_DIR_SINGLE') (did, st, path, auth_uid));
      else
        res := call (cast (det as varchar) || '_DAV_DIR_LIST') (detcol_id, det_subpath, detcol_path, name_mask, rec_depth, auth_uid);
      return res;
    }
  vectorbld_init (res);
  if ('R' = st)
    {
      for select vector (RES_FULL_PATH, 'R', DAV_RES_LENGTH (RES_CONTENT, RES_SIZE), RES_MOD_TIME,
            RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME ) as i
        from WS.WS.SYS_DAV_RES
        where
          RES_NAME like name_mask and RES_FULL_PATH = DAV_CONCAT_PATH (path, null) do
          {
            vectorbld_acc (res, i);
          }
    }
  else if (rec_depth = -1)
    {
      for select vector (WS.WS.COL_PATH (COL_ID), 'C', 0, COL_MOD_TIME,
            COL_ID, COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME, 'dav/unix-directory', COL_NAME) as i
        from WS.WS.SYS_DAV_COL
        where
        COL_ID = did do
          {
            vectorbld_acc (res, i);
          }
    }
  else if (rec_depth > 0)
    {
      for select SUBCOL_FULL_PATH, SUBCOL_ID, SUBCOL_NAME, SUBCOL_PARENT, SUBCOL_DET
        from DB.DBA.DAV_PLAIN_SUBCOLS
        where (root_id = did) and (root_path = path_string) and recursive = rec_depth and subcol_auth_uid = auth_uid and subcol_auth_pwd = auth_pwd
        --and DAV_AUTHENTICATE (SUBCOL_ID, 'C', '1__', auth_uname, auth_pwd, auth_uid)
      do for select COL_MOD_TIME,
            COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME from WS.WS.SYS_DAV_COL
        where
        COL_PARENT = SUBCOL_PARENT and COL_NAME = SUBCOL_NAME
      do
          {
            vectorbld_acc (res, vector (SUBCOL_FULL_PATH, 'C', 0, COL_MOD_TIME,
                         SUBCOL_ID, COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME, 'dav/unix-directory', SUBCOL_NAME) );
            if (SUBCOL_DET is not NULL)
              vectorbld_concat_acc (res, call (SUBCOL_DET || '_DAV_DIR_LIST') (SUBCOL_ID, vector (''), SUBCOL_FULL_PATH, name_mask, rec_depth, auth_uid));
            for select vector (
--              0              1    2                     3
                RES_FULL_PATH, 'R', DAV_RES_LENGTH (RES_CONTENT, RES_SIZE), RES_MOD_TIME,
--              4       5          6          7          8            9         10
                RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME) as i
            from WS.WS.SYS_DAV_RES
            where
            RES_NAME like name_mask and RES_COL = SUBCOL_ID
            do
              {
                vectorbld_acc (res, i);
              }
          }
    }
  else if (det is null)
    {
      -- dbg_obj_princ ('Plain dir, auth_uid=', auth_uid, ', did=', did);
      for select vector (RES_FULL_PATH, 'R', DAV_RES_LENGTH (RES_CONTENT, RES_SIZE), RES_MOD_TIME,
            RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME) as i
        from WS.WS.SYS_DAV_RES
        where
--      (RES_OWNER = uid or uid = http_dav_uid() or DAV_CHECK_PERM (RES_PERMS, '1__', uid, gid, RES_GROUP, RES_OWNER)) and
          RES_NAME like name_mask and RES_COL = did do
          {
            vectorbld_acc (res, i);
          }
      for select vector (WS.WS.COL_PATH (COL_ID), 'C', 0, COL_MOD_TIME,
            COL_ID, COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME, 'dav/unix-directory', COL_NAME) as i
        from WS.WS.SYS_DAV_COL
        where
--      (COL_OWNER = uid or uid = http_dav_uid() or DAV_CHECK_PERM (COL_PERMS, '1__', uid, gid, COL_GROUP, COL_OWNER)) and
        COL_PARENT = did do
          {
            vectorbld_acc (res, i);
          }
    }
  else
    {
      vectorbld_concat_acc (res, call (cast (det as varchar) || '_DAV_DIR_LIST') (did, vector (''), path, name_mask, rec_depth, auth_uid));
    }
  vectorbld_final (res);
  return res;
}
;


create function
DAV_DIR_FILTER_INT (in path varchar := '/DAV/', in rec_depth integer := 0, in compilation any, in auth_uname varchar := null, in auth_pwd varchar := null, in auth_uid integer := null) returns any
{
  declare rc, t, id, uid, gid, l integer;
  declare path_string, st, det, qry_text varchar;
  declare did, detcol_id, detcol_path, det_subpath, res any;
  -- dbg_obj_princ ('DAV_DIR_FILTER_INT (', path, rec_depth, compilation, auth_uname, auth_pwd, auth_uid, ')');
  declare execstate, execmessage, execmeta, execrows any;
  declare davcond varchar;
  davcond := get_keyword ('DAV', compilation);
  if (davcond is null)
    {
      davcond := DAV_FC_PRINT_WHERE (get_keyword ('', compilation), auth_uid);
      compilation := vector_concat (compilation, vector ('DAV', davcond));
    }
  execstate := '00000';
  vectorbld_init (res);
  path_string := path;
  did := DAV_SEARCH_SOME_ID_OR_DET (path, st, det, detcol_id, detcol_path, det_subpath);
  if (isarray (did))
    {
      if (auth_uid is null)
        uid := call (cast (did[0] as varchar) || '_DAV_AUTHENTICATE') (did, st, '1__', auth_uname, auth_pwd, uid);
      else
        uid := auth_uid;
      if (uid < 0)
        {
          -- dbg_obj_princ ('DAV_DIR_FILTER_INT has failed authorization: ', uid);
          return res;
        }
      if ('R' = st)
        res := vector (call (cast (did[0] as varchar) || '_DAV_DIR_SINGLE') (did, st, path, uid));
      else
        res := call (cast (det as varchar) || '_DAV_DIR_FILTER') (detcol_id, det_subpath, detcol_path, compilation, rec_depth, uid);
      return res;
    }
  if (did < 0)
    {
      return did;
    }
  if (('R' = st) or (det is null) or DB.DBA.DAV_DET_IS_WEBDAV_BASED (det))
    {
      if (auth_uid is null)
        uid := DAV_AUTHENTICATE (did, st, '1__', auth_uname, auth_pwd, uid);
      else
        uid := auth_uid;
      if (uid < 0)
        {
          -- dbg_obj_princ ('DAV_DIR_FILTER_INT has failed authorization: ', uid);
          return res;
        }
      gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = uid), 0);
    }
  -- dbg_obj_princ ('DAV_DIR_FILTER_INT runs using uid=', uid, ', gid=', gid, ' because auth_uid=', auth_uid, ' auth_uname=', auth_uname);
  if ('R' = st)
    {
      qry_text := '
select _top.RES_FULL_PATH, ''R'', DAV_RES_LENGTH (_top.RES_CONTENT, _top.RES_SIZE), _top.RES_MOD_TIME,
  _top.RES_ID, _top.RES_PERMS, _top.RES_GROUP, _top.RES_OWNER, _top.RES_CR_TIME, _top.RES_TYPE, _top.RES_NAME
from WS.WS.SYS_DAV_RES as _top ' || davcond || ' and
  (_top.RES_FULL_PATH = DAV_CONCAT_PATH (?, null)) and
case (
  DAV_CHECK_PERM (_top.RES_PERMS, ''1__'', ?, ?, _top.RES_GROUP, _top.RES_OWNER) )
when 0 then WS.WS.ACL_IS_GRANTED (_top.RES_ACL, ?, DAV_REQ_CHARS_TO_BITMASK (''1__''))
else 1 end';
      -- dbg_obj_princ ('R case:\npath = ', path, '\ndavcond = ', davcond, '\nqry_text = ', qry_text);
      exec (qry_text, execstate, execmessage,
        vector (path, uid, gid, uid),
        100000000, execmeta, execrows );
      -- dbg_obj_princ ('R case: execstate = ', execstate, ', execmessage = ', execmessage);
      if ('00000' <> execstate)
        signal (execstate, execmessage || ' in ' || qry_text);
      vectorbld_concat_acc (res, execrows);
    }
  else if (rec_depth = -1)
    {
      for select vector (WS.WS.COL_PATH (COL_ID), 'C', 0, COL_MOD_TIME,
            COL_ID, COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME, 'dav/unix-directory', COL_NAME) as i
        from WS.WS.SYS_DAV_COL
        where
--      (COL_OWNER = uid or uid = http_dav_uid() or DAV_CHECK_PERM (COL_PERMS, '1__', uid, gid, COL_GROUP, COL_OWNER)) and
        COL_ID = did do
          {
            vectorbld_acc (res, i);
          }
    }
  else if (rec_depth > 0)
    {
      qry_text := '
select _top.RES_FULL_PATH, ''R'', DAV_RES_LENGTH (_top.RES_CONTENT, _top.RES_SIZE), _top.RES_MOD_TIME,
  _top.RES_ID, _top.RES_PERMS, _top.RES_GROUP, _top.RES_OWNER, _top.RES_CR_TIME, _top.RES_TYPE, _top.RES_NAME
from WS.WS.SYS_DAV_RES as _top ' || davcond || ' and (_top.RES_FULL_PATH between ? and ?) and
case (
  DAV_CHECK_PERM (_top.RES_PERMS, ''1__'', ?, ?, _top.RES_GROUP, _top.RES_OWNER) )
when 0 then WS.WS.ACL_IS_GRANTED (_top.RES_ACL, ?, DAV_REQ_CHARS_TO_BITMASK (''1__''))
else 1 end';
      -- dbg_obj_princ ('rec_depth C case:\npath = ', path, '\ndavcond = ', davcond, '\nqry_text = ', qry_text);
      exec (qry_text,
        execstate, execmessage,
        vector (path_string, DAV_COL_PATH_BOUNDARY (path_string), uid, gid, uid), 100000000, execmeta, execrows );
      -- dbg_obj_princ ('rec_depth C case: execstate = ', execstate, ', execmessage = ', execmessage);
      if ('00000' <> execstate)
        signal (execstate, execmessage || ' in ' || qry_text);
      vectorbld_concat_acc (res, execrows);

      for select SUBCOL_FULL_PATH, SUBCOL_ID, SUBCOL_DET
        from DB.DBA.DAV_PLAIN_SUBCOLS
        where SUBCOL_DET is not null and (not (SUBCOL_DET like '%Filter')) and not DB.DBA.DAV_DET_IS_WEBDAV_BASED (SUBCOL_DET) and recursive = rec_depth and (root_id = did) and (root_path = path_string) and subcol_auth_uid = null and subcol_auth_pwd = null
      do
          {
              vectorbld_concat_acc (res, call (SUBCOL_DET || '_DAV_DIR_FILTER') (SUBCOL_ID, vector (''), SUBCOL_FULL_PATH, compilation, rec_depth, auth_uid));
          }
    }
  else if (det is null)
    {
      qry_text := '
select _top.RES_FULL_PATH, ''R'', DAV_RES_LENGTH (_top.RES_CONTENT, _top.RES_SIZE), _top.RES_MOD_TIME,
  _top.RES_ID, _top.RES_PERMS, _top.RES_GROUP, _top.RES_OWNER, _top.RES_CR_TIME, _top.RES_TYPE, _top.RES_NAME
from WS.WS.SYS_DAV_RES as _top ' || davcond || ' and (RES_COL = ?) and
case (
  DAV_CHECK_PERM (_top.RES_PERMS, ''1__'', ?, ?, _top.RES_GROUP, _top.RES_OWNER) )
when 0 then WS.WS.ACL_IS_GRANTED (_top.RES_ACL, ?, DAV_REQ_CHARS_TO_BITMASK (''1__''))
else 1 end';
      -- dbg_obj_princ ('Plain dir, uid=', uid, ', gid=', gid, ', did=', did, ' qry_text = ', qry_text);
      exec (qry_text, execstate, execmessage,
        vector (did, uid, gid, uid),
        100000000, execmeta, execrows );
      -- dbg_obj_princ ('nonrecursive C case: execstate = ', execstate, ', execmessage = ', execmessage);
      if ('00000' <> execstate)
        signal (execstate, execmessage || ' in ' || qry_text);
      vectorbld_concat_acc (res, execrows);
    }
  else
    {
      if (auth_uid is null)
        uid := call (cast (did[0] as varchar) || '_DAV_AUTHENTICATE') (did, st, '1__', auth_uname, auth_pwd, uid);
      else
        uid := auth_uid;
      if (uid < 0)
        {
          -- dbg_obj_princ ('DAV_DIR_LIST_INT has failed authorization: ', uid);
          return res;
        }
      vectorbld_concat_acc (res, call (cast (det as varchar) || '_DAV_DIR_FILTER') (did, vector (''), path, compilation, rec_depth, uid));
    }
  vectorbld_final (res);
  return res;
}
;


--!AWK PUBLIC
create procedure
DAV_SEARCH_PATH (in id any, in what char (1)) returns any
{
  declare res varchar;
  what := upper (what);
 if (isarray(id) and not isstring(id))
    return call (cast (id[0] as varchar) || '_DAV_SEARCH_PATH') (id, what);
  if (id <= 0)
    {
      if (id = 0)
        return '/';
      return -22;
    }
  whenever not found goto en;
  if (what = 'C')
    {
      res :=  WS.WS.COL_PATH (id);
      if (res = '/')
        return -23;
      return res;
    }
  else if (what = 'R')
    {
      select RES_FULL_PATH into res from WS.WS.SYS_DAV_RES where RES_ID = id;
      return res;
    }
  else
    return -14;
en:
  return -23;
}
;


--!
-- \brief Search the internal ID for a given path.
--
-- \b Warning: In the case of DET folders the ID is not an integer but a vector! FIXME: containing what exactly?
--/
--!AWK PUBLIC
create function
DAV_SEARCH_ID (in path any, in what char (1)) returns any
{
  declare id integer;
  declare par any;
  id := -1;
  what := upper (what);
  -- dbg_obj_princ ('DAV_SEARCH_ID (', path, what, ')');
  if (isstring (path))
    {
      -- dbg_obj_princ ('path is string, tag (', __tag(path), ')');
      par := split_and_decode (path, 0, '\0\0/');
      -- dbg_obj_princ ('split_and_decode complete');
    }
  else
    {
      -- dbg_obj_princ ('path is not string, tag (', __tag(path), ')');
      par := path;
    }
  if (length (par) = 0)
    {
      -- dbg_obj_princ ('empty par');
      return -1;
    }
  if (aref (par, 0) <> '')
    {
      -- dbg_obj_princ ('bad par[0]');
      return -1;
    }
  if (what = 'P')
    {
      if (par [length (par) - 1] = '')
        {
          if (2 = length (par))
            return -1;
          if (3 = length (par))
            return 0;
          par := vector_concat (subseq (par, 0, length (par) - 2), vector (''));
        }
      else
        {
          if (2 = length (par))
            return 0;
          par := vector_concat (subseq (par, 0, length (par) - 1), vector (''));
        }
      path := null;
      what := 'C';
    }


  if (what = 'R')
    {
      if (aref (par, length (par) - 1) = '')
        {
          -- dbg_obj_princ ('bad par[last()] for R');
          return -1;
        }
      if (not isstring (path))
        path := DAV_CONCAT_PATH (par, null);
      id := coalesce ((select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path), -1);
      if ((id <> -1) and (connection_get ('dav_store') is null))
      {
        declare det, detcol_id, detcol_path any;

        detcol_id := cast (DAV_PROP_GET_INT (id, what, 'virt:DETCOL_ID', 0) as integer);
        if (DAV_HIDE_ERROR (detcol_id) is not null)
        {
          detcol_path := DB.DBA.DAV_SEARCH_PATH (detcol_id, 'C');
          if (path like detcol_path || '%')
          {
            det := cast (coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = detcol_id), '') as varchar);
            if ((det <> '') and __proc_exists ('DB.DBA.' || det || '_DAV_MAKE_ID'))
              return call (cast (det as varchar) || '_DAV_MAKE_ID') (detcol_id, id, 'R');
          }
        }
      }
    }
  else if (what = 'C')
    {
      if (aref (par, length (par) - 1) <> '')
        {
          -- dbg_obj_princ ('bad par[last()] for C');
          return -1;
        }
      if (not isstring (path))
        path := DAV_CONCAT_PATH (par, null);
      --id := coalesce ((select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = path), -1);
      id := -1;
    }
  else
    {
      -- dbg_obj_princ ('-14 ???');
      return -14;
    }
  if (id = -1)
    {
      declare det_ret, detcol_id, detcol_path_parts, unreached_path_parts any;
      return DAV_SEARCH_ID_OR_DET (par, what, det_ret, detcol_id, detcol_path_parts, unreached_path_parts);
    }
  return id;
}
;

--!AWK PUBLIC
create function
DAV_SEARCH_SOME_ID (in path any, out what char (1)) returns any
{
  declare id integer;
  declare par any;
  id := -1;
  -- dbg_obj_princ ('DAV_SEARCH_SOME_ID (', path, '... )\n');
  if (isstring (path))
    par := split_and_decode (path, 0, '\0\0/');
  else
    par := path;
  if (aref (par, 0) <> '')
    {
      -- dbg_obj_princ ('bad par[0]');
      return -1;
    }
  if (aref (par, length (par) - 1) <> '')
    {
      what := 'R';
      if (not isstring (path))
        path := DAV_CONCAT_PATH (par, null);
      id := coalesce ((select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path), -1);
    }
  else
    {
      what := 'C';
      if (not isstring (path))
        path := DAV_CONCAT_PATH (par, null);
      id := DAV_SEARCH_ID (path, 'C');
    }
  -- dbg_obj_princ ('Found ', id, ' of type ', what);
  if (id = -1)
    {
      declare det_ret, detcol_id, detcol_path_parts, unreached_path_parts any;
      return DAV_SEARCH_ID_OR_DET (par, what, det_ret, detcol_id, detcol_path_parts, unreached_path_parts);
    }
  return id;
}
;

--!AWK PUBLIC
create function
DAV_HIDE_ERROR (in res any, in dflt any := null) returns any
{
  if (not (isinteger (res)))
    return res;
  if (res >= 0)
    return res;
  return dflt;
}
;


--!AWK PUBLIC
create function
DAV_HIDE_ERROR_OR_DET (in res any, in dflt_err any := null, in dflt_det any := -33) returns any
{
  if (not (isinteger (res)))
    return dflt_det;
  if (res >= 0)
    return res;
  return dflt_err;
}
;


--!AWK PUBLIC
create function DAV_CONCAT_PATH (in parts1 any, in parts2 any)
{
  declare strg1, strg2 varchar;
  declare len, ctr integer;
  if (parts1 is null)
    strg1 := '';
  else if (isstring (parts1))
    strg1 := parts1;
  else
    {
      len := length (parts1);
      if (len = 0)
        strg1 := '';
      else
        {
          strg1 := parts1 [0];
          ctr := 1;
          while (ctr < len)
            {
              strg1 := strg1 || '/' || parts1 [ctr];
              ctr := ctr + 1;
            }
        }
    }
  if (parts2 is null)
    strg2 := '';
  else if (isstring (parts2))
    strg2 := parts2;
  else
    {
      len := length (parts2);
      if (len = 0)
        strg2 := '';
      else
        {
          strg2 := parts2 [0];
          ctr := 1;
          while (ctr < len)
            {
              strg2 := strg2 || '/' || parts2 [ctr];
              ctr := ctr + 1;
            }
        }
    }
  if (strg1 = '')
    return strg2;
  if (strg2 = '')
    return strg1;
  if (strg1 [length(strg1) - 1] = 47)
    if (strg2 [0] = 47)
      return strg1 || subseq (strg2, 1);
    else
      return strg1 || strg2;
  else
    if (strg2 [0] = 47)
      return strg1 || strg2;
    else
      return strg1 || '/' || strg2;
}
;


create function
DAV_SEARCH_SOME_ID_OR_DET (inout path any, out what char (1), out det_ret varchar, out detcol_id integer, out detcol_path_parts any, out unreached_path_parts any) returns integer
{
  if (isstring (path))
    path := split_and_decode (path, 0, '\0\0/');
  else
    path := path;
  if (length (path) < 2)
    goto bad_path_arg;
  if (aref (path, 0) <> '')
    goto bad_path_arg;
  if (path [length (path) - 1] = '')
    what := 'C';
  else
    what := 'R';
  return DAV_SEARCH_ID_OR_DET (path, what, det_ret, detcol_id, detcol_path_parts, unreached_path_parts);

bad_path_arg:
  detcol_id := null;
  detcol_path_parts := null;
  unreached_path_parts := null;
  return -1;
}
;

create function
DAV_SEARCH_ID_OR_DET (in path any, in what char (1), out det_ret varchar, out detcol_id integer, out detcol_path_parts any, out unreached_path_parts any) returns integer
{
  declare id integer;
  declare par, left_par, right_par any;
  declare cname, det varchar;
  declare inx, depth, cur_id, parent_id integer;
  id := -1;
  what := upper (what);
  -- dbg_obj_princ ('DAV_SEARCH_ID_OR_DET (', path, what,')');
  if (isstring (path))
    par := split_and_decode (path, 0, '\0\0/');
  else
    par := path;
  if (length (par) < 2)
    goto bad_path_arg;
  if (aref (par, 0) <> '')
    goto bad_path_arg;
  if (what = 'P')
    {
      if (par [length (par) - 1] = '')
        {
          if (2 = length (par))
            goto bad_path_arg;
          if (3 = length (par))
            {
              detcol_id := null;
              detcol_path_parts := null;
              unreached_path_parts := null;
              return 0;
            }
          par := vector_concat (subseq (par, 0, length (par) - 2), vector (''));
        }
      else
        {
          if (2 = length (par))
            {
              detcol_id := null;
              detcol_path_parts := null;
              unreached_path_parts := null;
              return 0;
            }
          par := vector_concat (subseq (par, 0, length (par) - 1), vector (''));
        }
      path := null;
      what := 'C';
    }
  if (what = 'R')
    {
      if (aref (par, length (par) - 1) = '')
        goto bad_path_arg;
      if (not isstring (path))
        path := DAV_CONCAT_PATH (par, null);
      id := coalesce ((select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path), -1);
      if ((id <> -1) and (connection_get ('dav_store') is null))
      {
        detcol_id := cast (DAV_PROP_GET_INT (id, what, 'virt:DETCOL_ID', 0) as integer);
        if (DAV_HIDE_ERROR (detcol_id) is not null)
        {
          det_ret := cast (coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = detcol_id), '') as varchar);
          if ((det_ret <> '') and __proc_exists ('DB.DBA.' || det_ret || '_DAV_MAKE_ID'))
          {
            declare detcol_par any;

            detcol_par := split_and_decode (DAV_SEARCH_PATH (detcol_id, 'C'), 0, '\0\0/');
            inx := length (detcol_par)-2;
            detcol_path_parts := subseq (par, 0, inx + 1);
            par := subseq (par, inx + 1);
            unreached_path_parts := par;
            return call (cast (det_ret as varchar) || '_DAV_MAKE_ID') (detcol_id, id, 'R');
          }
        }
      }
     if (id > 0)
      goto found_plain_id;

    }
  else if (what = 'C')
    {
      if (aref (par, length (par) - 1) <> '')
        goto bad_path_arg;
      goto descending_col_search;
    }
  else
    return -14;

descending_col_search:

  inx := 1;
  cur_id := 0;
  parent_id := 0;
  depth := length (par) - 1;
  -- dbg_obj_princ ('554: path=', path, ' par=', par);
  whenever not found goto not_found;
  while (inx < depth)
    {
      cname := aref (par, inx);
      -- dbg_obj_princ ('select, cname =', cname, inx, parent_id);
      select COL_ID, COL_DET into cur_id, det from WS.WS.SYS_DAV_COL where COL_NAME = cname and COL_PARENT = parent_id;
      if ((det is not NULL) and (connection_get ('dav_store') is null))
        {
          det_ret := det;
          detcol_id := cur_id;
          detcol_path_parts := subseq (par, 0, inx + 1);
          par := subseq (par, inx + 1);
          unreached_path_parts := par;
          if ((what = 'C') and (inx = depth - 1))
            return cur_id;

          return call (cast (det as varchar) || '_DAV_SEARCH_ID') (cur_id, par, what);
        }
      parent_id := cur_id;
      inx := inx + 1;
    }
  if (what = 'R')
    {
      return -1; -- The collection is found but the resource is not.
    }
  id := cur_id;
  goto found_plain_id;

found_plain_id:
  det_ret := NULL;
  detcol_id := NULL;
  detcol_path_parts := null;
  unreached_path_parts := null;
  return id;

not_found:
  det_ret := NULL;
  detcol_id := null;
  detcol_path_parts := null;
  unreached_path_parts := null;
  return -1;

bad_path_arg:
  -- dbg_obj_princ ('bad_path_arg');
  det_ret := NULL;
  detcol_id := null;
  detcol_path_parts := null;
  unreached_path_parts := null;
  return -1;
}
;


create procedure
DAV_OWNER_ID (in uid any, in gid any, out _uid integer, out _gid integer)
{
  -- dbg_obj_princ ('DAV_OWNER_ID (', uid, gid, _uid, _gid, ')');
  if (uid is null)
    _uid := http_nobody_uid();
  else if (isinteger (uid))
    _uid := uid;
  else
    _uid := coalesce (
      (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uid),
      case (uid) when 'anonymous' then http_nobody_uid () else -12 end);

  if (gid is null)
    _gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = _uid), http_nogroup_gid ());
  else if (isinteger (gid))
    _gid := gid;
  else
    _gid := coalesce (
      (select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = gid),
      (select U_GROUP from WS.WS.SYS_DAV_USER where U_NAME = gid),
      -12 );
-- This must be
--  _gid := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = gid), -12);
  -- dbg_obj_princ ('DAV_OWNER_ID translated ', uid, ' -> ', _uid, ', and ', gid, ' -> ', _gid);
}
;


create procedure DAV_IS_LOCKED_INT (inout id any, inout type char, in owned_tokens varchar := '')
{
  declare pid, npid, res integer;
  declare scope varchar;
  type := upper (type);
  if (type <> 'C' and type <> 'R')
    return -14;
  if (exists (select 1 from WS.WS.SYS_DAV_LOCK where datediff ('second', LOCK_TIME, now()) > LOCK_TIMEOUT))
    {
      delete from WS.WS.SYS_DAV_LOCK where datediff ('second', LOCK_TIME, now()) > LOCK_TIMEOUT;
      --commit work;
    }
  if (isarray (id))
    {
      return call (cast (id[0] as varchar) || '_DAV_IS_LOCKED') (id, type, owned_tokens);
    }
  if (id <= 0)
    return -1;
  -- is there any locks
  if (not exists (select 1 from WS.WS.SYS_DAV_LOCK))
    {
    --dbg_printf ('DAV_IS_LOCKED: no locks');
      return 0;
    }
  -- check first on the target
  whenever not found goto nf_target_lock;
  select case (LOCK_SCOPE) when 'X' then 2 else 1 end into res from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = type and LOCK_PARENT_ID = id and strstr (owned_tokens, LOCK_TOKEN) is null;
  return res;

nf_target_lock:

  -- if target not locked : is there any collection locks
  if (not exists (select 1 from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'C' and strstr (owned_tokens, LOCK_TOKEN) is null))
    {
    --dbg_printf ('DAV_IS_LOCKED: no collection locks');
      return 0;
    }

  if (type = 'R')
    pid := coalesce ((select RES_COL from WS.WS.SYS_DAV_RES where RES_ID = id), -1);
  else if (type = 'C')
    pid := coalesce ((select COL_PARENT from WS.WS.SYS_DAV_COL where COL_ID = id), -1);

  if (pid < 0)
    return -1;

next_parent:

whenever not found goto nf_parent_lock;
  select case (LOCK_SCOPE) when 'X' then 2 else 1 end into res from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'C' and LOCK_PARENT_ID = pid and strstr (owned_tokens, LOCK_TOKEN) is null;
  id := pid;
  type := 'C';
  return res;

nf_parent_lock:
  whenever not found goto nf_parent;
  select COL_PARENT into npid from WS.WS.SYS_DAV_COL where COL_ID = pid;
  pid := npid;
  goto next_parent;
nf_parent:
--dbg_printf ('DAV_IS_LOCKED: no collection locks found');
  return 0;
}
;


--!AWK PUBLIC
create function DAV_IS_LOCKED (in id any, in type char, in owned_tokens any := 1) returns integer
{
  declare res integer;
  if (isstring (owned_tokens))
    res := DAV_IS_LOCKED_INT (id, type, owned_tokens);
  else
    res := DAV_IS_LOCKED_INT (id, type);
  if (res > 0)
    return -8;
  return res;
}
;

--!AWK PUBLIC
create function DAV_LIST_LOCKS (in id any, in type char) returns any
{
  return DAV_LIST_LOCKS_INT (id, type);
}
;

create function DAV_LIST_LOCKS_INT (in id any, in type char) returns any
{
  declare res any;
  type := upper (type);
  -- dbg_obj_princ ('DAV_LIST_LOCKS_INT (', id, type, ')');
  if (type <> 'C' and type <> 'R')
    return -14;
  if (isarray (id))
    {
      return call (cast (id[0] as varchar) || '_DAV_LIST_LOCKS') (id, type, 0);
    }
  if (id <= 0)
    return -1;
  res := vector ();
  for select LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO
    from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_ID = id and LOCK_PARENT_TYPE = type do {
      res := vector_concat (res, vector (vector (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO)));
    }
  return res;
}
;

create function DAV_LOCK (in path any, in locktype varchar, in scope varchar, in token varchar, in owner_name varchar, in owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid varchar, in auth_pwd varchar) returns any
{
  declare id any;
  declare st char (1);
  -- dbg_obj_princ ('DAV_LOCK (', path, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, auth_pwd, ')');
  id := null;
  st := null;
  return DAV_LOCK_INT (path, id, st, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, auth_pwd, NULL);
}
;

create function DAV_LOCK_INT (in path any, inout id any, inout st char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer) returns any
{
  declare p_id any;
  declare rc, id_is_bad integer;
  declare u_token, old_scope, p_st varchar;
  -- dbg_obj_princ ('DAV_LOCK_INT (', path, id, st, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uname, auth_pwd, auth_uid, ')');
  p_id := DAV_SEARCH_ID (path, 'P');
  if (DAV_HIDE_ERROR (p_id) is null)
    return case p_id when -1 then -34 else p_id end;
  if (id is null)
    id := DAV_SEARCH_SOME_ID (path, st);
  if (DAV_HIDE_ERROR (id) is null)
    {
      if (id <> -1)
        return -1;
      if ("RIGHT" (path, 1) = '/')
        return -1; -- Can't lock a future collection;
      st := 'R';
      id_is_bad := 1;
    }
  else
    id_is_bad := 0;
  if (id_is_bad)
    rc := DAV_AUTHENTICATE (p_id, 'C', '11_', auth_uname, auth_pwd, auth_uid);
  else
    rc := DAV_AUTHENTICATE (id, st, '11_', auth_uname, auth_pwd, auth_uid);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  if (auth_uid is null)
    auth_uid := rc;
  if (owned_tokens is null)
    owned_tokens := '';
  if (token is null)
    token := '';
  if (owner_name is null)
    owner_name := '';
  if (depth is null)
    {
      if (st = 'R')
        depth := '0';
      else
        depth := 'infinity';
    }
  if (timeout_sec is null or timeout_sec = 0)
    timeout_sec := 604800;  -- one week time out if is not supplied
  set isolation = 'serializable';
  p_st := 'C';
  rc := DAV_IS_LOCKED_INT (p_id, p_st, owned_tokens);
  if (0 <> rc)
    {
      if (rc < 0)
        return rc;
      return -8;
    }
  if (st = 'C')
    {
      for select LOCK_TOKEN as _ctoken from WS.WS.SYS_DAV_LOCK
        where
          LOCK_PARENT_TYPE = 'C' and
          isnull (strstr (owned_tokens, LOCK_TOKEN)) and
          ((id = LOCK_PARENT_ID) or DAV_COL_IS_ANCESTOR_OF (id, LOCK_PARENT_ID))
         do
          {
            return -8;
          }
    }
  -- find lock refreshing condition
  u_token := '';
  if (owned_tokens <> '')
    {
      declare tleft, tright integer;
      declare tmp varchar;
      if (isnull(strstr(owned_tokens, '(<opaquelocktoken:')))
        goto failed_parsing;
      tleft := strchr (owned_tokens, ':');
      --tright := strrchr (owned_tokens, '>');
      if (tleft is null)
        goto failed_parsing;
      tright := strchr (substring (owned_tokens, tleft + 1, length (owned_tokens)), '>');
      if (tright is null)
        goto failed_parsing;
      tright := tleft + tright;
      tmp := substring (owned_tokens, tleft + 2, tright - tleft - 1);
      u_token := trim(tmp);
    }
failed_parsing:
  if (u_token = '')
    u_token := token;

  -- dbg_obj_princ ('Before lock refresh: id = ', id, ', st = ', st, ', depth = ', depth, ', timeout_sec = ', timeout_sec, ' u_token = ', u_token);
  if (isarray (id))
    {
      token := u_token;
      rc := call (cast (id[0] as varchar) || '_DAV_LOCK') (path, id, st, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid);
      return rc;
    }
  if (id_is_bad)
    {
      declare parent_det, new_res_name varchar;
      parent_det := DAV_PROP_GET_INT (p_id, 'C', ':virtdet', 0);
      if (parent_det is not null)
        {
          token := u_token;
          rc := call (parent_det || '_DAV_LOCK') (path, id, st, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid);
          return rc;
        }
      new_res_name := subseq (path, strrchr (path, '/') + 1);
      if (exists (select top 1 1 from WS.WS.SYS_DAV_COL where COL_PARENT = p_id and COL_NAME = new_res_name))
        return -26;
      id := WS.WS.GETID ('R');
      insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_COL, RES_CR_TIME, RES_MOD_TIME, RES_OWNER, RES_PERMS, RES_GROUP, RES_FULL_PATH)
        values (id, new_res_name, p_id, now (), now (), auth_uid, '110000000NN', http_nogroup_gid(), path);
      old_scope := '';
    }
  else
    old_scope := coalesce ((select LOCK_SCOPE from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = st and LOCK_PARENT_ID = id), '');
  -- dbg_obj_princ ('Plain lock: rc = ', old_scope);
  if ((old_scope = 'S' or old_scope = 'X') and u_token <> '')
    {
      -- dbg_obj_princ ('Plain lock refresh');
      declare c cursor for select LOCK_OWNER_INFO from WS.WS.SYS_DAV_LOCK where LOCK_TOKEN = u_token and LOCK_PARENT_TYPE = st and LOCK_PARENT_ID = id for update;
      declare old_owner_name varchar;
      whenever not found goto nothing_to_refresh;
      open c;
      fetch c into old_owner_name;
      if (owner_name = '')
        owner_name := old_owner_name;
      scope := old_scope;
      update WS.WS.SYS_DAV_LOCK set LOCK_TIME = now (), LOCK_TIMEOUT = timeout_sec, LOCK_OWNER_INFO = owner_name where current of c;
      close c;
      return u_token;
nothing_to_refresh:
      close c;
      return -35;
    }
  if ((old_scope = '') or (old_scope = 'S' and scope = 'S'))
    {
      if (token = '')
        token := WS.WS.OPLOCKTOKEN();
      else
        {
          if (exists (select top 1 1 from WS.WS.SYS_DAV_LOCK where LOCK_TOKEN = token and (LOCK_PARENT_TYPE <> st or LOCK_PARENT_ID <> id)))
            return -35;
        }
      -- dbg_obj_princ ('Plain lock insert: token = ', token);
      insert into WS.WS.SYS_DAV_LOCK (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_PARENT_TYPE,
        LOCK_PARENT_ID, LOCK_TIME, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO)
        values (locktype, scope, token, st, id, now(), timeout_sec, auth_uid, owner_name);
      return token;
    }
  if (old_scope = 'X' or (old_scope = 'S' and scope = 'X'))
    return -8;
  return -35;
}
;

create function DAV_UNLOCK (in path varchar, in token varchar, in auth_uname varchar, in auth_pwd varchar) returns any
{
  declare id any;
  declare st char (1);
  id := DAV_SEARCH_SOME_ID (path, st);
  if (DAV_HIDE_ERROR (id) is null)
    return -1;
  return DAV_UNLOCK_INT (id, st, token, auth_uname, auth_pwd, null);
}
;


create function DAV_UNLOCK_INT (in id any, in st char(1), in token varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer) returns any
{
  declare rc, _left, _right integer;
  declare cur_token varchar;
  declare l_cur cursor for select LOCK_TOKEN from WS.WS.SYS_DAV_LOCK
      where LOCK_PARENT_ID = id and LOCK_PARENT_TYPE = st and LOCK_TOKEN = token;
  -- dbg_obj_princ ('DAV_UNLOCK_INT (', id, st, token, auth_uname, auth_pwd, auth_uid, ')');
  auth_uid := DAV_AUTHENTICATE (id, st, '11_', auth_uname, auth_pwd, auth_uid);
  if (auth_uid < 0)
    return auth_uid;
--                       0         1
--                       01234567890123456
  _left := strstr(token,'opaquelocktoken:');
  if (_left is not null)
    {
      _left := _left + 15;
      _right :=  strrchr(token,'>');
      if (_left < _right)
        token := trim (substring (token, _left + 2, _right - _left - 1));
    }
  if (isarray (id))
    {
      rc := call (cast (id[0] as varchar) || '_DAV_UNLOCK')(id, st, token, auth_uid);
      return rc;
    }
  whenever not found goto not_locked_t;
  open l_cur (exclusive, prefetch 1);
  fetch l_cur into cur_token;
  delete from WS.WS.SYS_DAV_LOCK where current of l_cur;
  close l_cur;
  return token;

not_locked_t:
  close l_cur;
  return -27;
}
;

--!AWK PUBLIC
create function
DAV_REQ_CHARS_TO_BITMASK (in req varchar) returns integer
{
  return 4 * equ (req[0], 49) + 2 * equ (req[1], 49) + equ (req[2], 49);
}
;

--!AWK PUBLIC
create function
DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null) returns integer
{
  declare rc, oid, ogid, puid, pgid integer;
  declare opwd, pperms varchar;
  declare pacl varbinary;

  what := upper (what);
  -- dbg_obj_princ ('DAV_AUTHENTICATE (', id, what, req, a_uname, a_pwd, a_uid, ')');
  if (length (req) <> 3)
    return -15;

  if (a_uid is null)
    a_uid := DAV_CHECK_AUTH (a_uname, a_pwd, 0);

  if (a_uid = 1) -- Anonymous FTP
  {
    oid := http_nobody_uid ();
    ogid := http_nogroup_gid ();
  }
  else if (a_uid >= 0)
  {
    if (a_uid = http_dav_uid())
      return a_uid;

    oid := a_uid;
    if (a_uid = http_nobody_uid ())
    {
      ogid := http_nogroup_gid ();
    }
    else
    {
      select U_GROUP into ogid from WS.WS.SYS_DAV_USER where U_ID = a_uid;
    }
  }

  -- Check authentication for DET folders for which the id is actually a vector of DET details
  -- Each DET implements its own authentication procedure which eventually comes back to this one with changed parameters
  if (isarray (id))
  {
    rc := call (cast (id[0] as varchar) || '_DAV_AUTHENTICATE') (id, what, req, a_uname, a_pwd, a_uid);
    if (rc = -20)
      rc := DAV_AUTHENTICATE (id[1], 'C', req, a_uname, a_pwd, a_uid);

    return rc;
  }

  whenever not found goto nf_col_or_res;
  if (what = 'R')
  {
    select RES_OWNER, RES_GROUP, RES_PERMS, RES_ACL into puid, pgid, pperms, pacl from WS.WS.SYS_DAV_RES where RES_ID = id;
    set isolation='committed';
    if (puid <> http_nobody_uid() and
        exists (select top 1 1 from SYS_USERS where U_ID = puid and U_ACCOUNT_DISABLED = 1))
    {
      return -42;
    }
    set isolation='serializable';
  }
  else if (what = 'C')
  {
    -- trueg: why do we not check if the collection owner account is disabled???
    select COL_OWNER, COL_GROUP, COL_PERMS, COL_ACL into puid, pgid, pperms, pacl from WS.WS.SYS_DAV_COL where COL_ID = id;
  }
  else
  {
    return -14;
  }

  if (a_uid >= 0)
  {
    if (DAV_CHECK_PERM (pperms, req, oid, ogid, pgid, puid))
    {
      -- dbg_obj_princ ('DAV_CHECK_PERM (', pperms, req, oid, ogid, pgid, puid, ') returns nonzero, DAV_AUTHENTICATE returns', a_uid);
      return a_uid;
    }
    if (WS.WS.ACL_IS_GRANTED (pacl, oid, DAV_REQ_CHARS_TO_BITMASK (req)))
    {
      -- dbg_obj_princ ('WS.WS.ACL_IS_GRANTED (', pacl, oid, DAV_REQ_CHARS_TO_BITMASK (req), ') returns nonzero, DAV_AUTHENTICATE returns', a_uid);
      return a_uid;
    }
  }


  declare _perms, a_gid any;
  declare webid, serviceId varchar;

  if (DAV_AUTHENTICATE_SSL (id, what, null, req, a_uid, a_gid, _perms, webid))
    return a_uid;

  if (__proc_exists ('VAL.DBA.authentication_details_for_connection') is not null) {
    if (DAV_AUTHENTICATE_WITH_VAL (id, what, null, req, a_uid, a_gid, _perms, serviceId))
      return a_uid;
  }

  -- Both DAV_AUTHENTICATE_SSL and DAV_AUTHENTICATE_WITH_VAL only check IRI ACLs
  -- However, service ids may map to ODS user accounts. This is what we check here
  a_uid := -1;

  -- A session ID might be connected to a normal user account, that is what we check first
  for (select top 1 U_ID from DB.DBA.SYS_USERS where U_NAME=serviceId and U_ACCOUNT_DISABLED=0) do
    a_uid := U_ID;

  if (a_uid = -1 and exists (select 1 from DB.DBA.SYS_KEYS where KEY_NAME='DB.DBA.WA_USER_OL_ACCOUNTS')) -- this check is only valid if table is accessed in a separate SP which is not precompiled
  {
    if (not DAV_GET_UID_BY_SERVICE_ID (serviceId, a_uid, a_gid, a_uname, _perms))
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

  -- dbg_obj_princ ('DAV_AUTHENTICATE (,', id, what, req, a_uname, a_pwd, ') returns -13');
  return -13;

nf_col_or_res:
  -- dbg_obj_princ ('DAV_AUTHENTICATE (,', id, what, req, a_uname, a_pwd, ') returns -1 due to bad id');
  return -1;
}
;

-- trueg: we maybe should check if the account is disabled??
create procedure DAV_GET_UID_BY_SERVICE_ID (in serviceId any, out a_uid int, out a_gid int, out a_uname varchar, out _perms int)
{
  declare st, msg, meta, rows any;

  a_uid := null;
  a_gid := null;
  a_uname := null;
  _perms := null;
  st := '00000';
  exec ('select WUO_U_ID, U_GROUP, U_NAME, U_DEF_PERMS from DB.DBA.WA_USER_OL_ACCOUNTS, DB.DBA.SYS_USERS where WUO_U_ID=U_ID and WUO_URL=?', st, msg, vector (serviceId), 0, meta, rows);
  if (('00000' <> st) or (length (rows) = 0))
    return 0;

  a_uid := rows[0][0];
  a_gid := rows[0][1];
  a_uname := rows[0][2];
  _perms := rows[0][3];

  return 1;
}
;

create procedure DAV_GET_UID_BY_WEBID (out a_uid int, out a_gid int)
{
  declare cert, st, msg, meta, rows any;

  if (not is_https_ctx ())
    return 0;

  cert := client_attr ('client_certificate');
  if (cert = 0)
    return 0;
  a_uid := null;
  a_gid := null;
  st := '00000';
  exec ('select U_ID, U_GROUP from DB.DBA.SYS_USERS, DB.DBA.WA_USER_CERTS where UC_FINGERPRINT = ? and UC_U_ID = U_ID', st, msg, vector (get_certificate_info (6, cert)), 0, meta, rows);
  if (('00000' <> st) or (length (rows) = 0))
    return 0;

  a_uid := rows[0][0];
  a_gid := rows[0][1];

  return 1;
}
;

create function
DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  -- dbg_obj_princ ('DAV_AUTHENTICATE_HTTP (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare rc integer;
  declare puid, pgid integer;
  declare u_password, pperms, resName, resPath varchar;
  declare allow_anon integer;
  declare pacl varbinary;

  -- used for error reporting in case of NetID or OAuth login
  declare webid, serviceId varchar;
  webid := null;
  serviceId := null;

  what := upper (what);
  if (length (req) <> 3)
    return -15;

  -- Check authentication for DET folders for which the id is actually a vector of DET details
  -- Each DET implements its own authentication procedure which eventually comes back to this one with changed parameters
  if (isarray (id))
  {
    declare d__perms varchar;

    rc := call (cast (id[0] as varchar) || '_DAV_AUTHENTICATE_HTTP') (id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);
    if (rc = -20)
      rc := DAV_AUTHENTICATE_HTTP (id[1], 'C', req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);

    return rc;
  }

  if (id is null)
  {
    pperms := '000000000?';
    allow_anon := 0;
  }
  else
  {
    declare anon_flags varchar;
    whenever not found goto nf_col_or_res;
    if (what = 'R')
    {
      select RES_NAME, RES_FULL_PATH, RES_OWNER, RES_GROUP, RES_PERMS, RES_ACL into resName, resPath, puid, pgid, pperms, pacl from WS.WS.SYS_DAV_RES where RES_ID = id;
    }
    else if (what = 'C')
    {
      select COL_OWNER, COL_GROUP, COL_PERMS, COL_ACL into puid, pgid, pperms, pacl from WS.WS.SYS_DAV_COL where COL_ID = id;
    }
    else
    {
      return -14;
    }
    anon_flags := substring (cast (pperms as varchar), 7, 3);
    allow_anon := WS.WS.PERM_COMP (anon_flags, req);
  }
  -- dbg_obj_princ ('DAV_AUTHENTICATE_HTTP has a_uid=', a_uid, ' allow_anon=', allow_anon, ' with path=', resPath);
  if (a_uid is null)
  {
    if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
    {
      rc := WS.WS.GET_DAV_AUTH (a_lines, allow_anon, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
      if (rc < 0)
      {
      check_more_auth:

        if (DAV_AUTHENTICATE_SSL (id, what, null, req, a_uid, a_gid, _perms, webid))
        {
          return a_uid;
        }
        if (__proc_exists ('VAL.DBA.authentication_details_for_connection') is not null) {
          if (DAV_AUTHENTICATE_WITH_VAL (id, what, null, req, a_uid, a_gid, _perms, serviceId))
          {
            return a_uid;
          }
        }

        -- Normalize the service variables for error handling in VAL
        if (not webid is null and serviceId is null)
        {
          serviceId := webid;
        }

        -- Both DAV_AUTHENTICATE_SSL and DAV_AUTHENTICATE_WITH_VAL only check IRI ACLs
        -- However, service ids may map to ODS user accounts. This is what we check here
        a_uid := -1;

        -- A session ID might be connected to a normal user account, that is what we check first
        for (select top 1 U_ID from DB.DBA.SYS_USERS where U_NAME=serviceId and U_ACCOUNT_DISABLED=0) do
          a_uid := U_ID;

        if (a_uid = -1 and exists (select 1 from DB.DBA.SYS_KEYS where KEY_NAME='DB.DBA.WA_USER_OL_ACCOUNTS')) -- this check is only valid if table is accessed in a separate SP which is not precompiled
        {
          if (not DAV_GET_UID_BY_SERVICE_ID (serviceId, a_uid, a_gid, a_uname, _perms))
            a_uid := -1;
        }

        -- If we were able to map the session or WebID to an existing user account, then check its permissions on the resource
        if (a_uid > 0)
        {
          if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
          {
            _perms := pperms;
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
      a_gid := http_admin_gid ();
      _perms := pperms;
      return a_uid;
    }
  }
  else
  {
    if (isnull (id))
    {
      a_uid := http_nobody_uid ();
      a_gid := http_nogroup_gid ();
    }
    else
    {
      a_uid := puid;
      a_gid := pgid;
    }
    _perms := '110110110--';
  }

  set isolation='committed';
  if ('R' = what and
      puid <> http_nobody_uid() and
      exists (select top 1 1 from SYS_USERS where U_ID = puid and U_ACCOUNT_DISABLED = 1 ))
  {
    return -42;
  }
  set isolation='serializable';
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
  {
    -- dbg_obj_princ ('DAV_AUTHENTICATE_HTTP returns ', a_uid, ' (that is made by DAV_CHECK_PERM (', pperms, req, a_uid, a_gid, pgid, puid, ')');
    _perms := pperms;
    return a_uid;
  }
  if (WS.WS.ACL_IS_GRANTED (pacl, a_uid, DAV_REQ_CHARS_TO_BITMASK (req)))
  {
    -- dbg_obj_princ ('WS.WS.ACL_IS_GRANTED (', pacl, a_uid, DAV_REQ_CHARS_TO_BITMASK (req), ') returns nonzero, DAV_AUTHENTICATE_HTTP returns', a_uid);
    return a_uid;
  }

  -- in case we had HTTP AUTH credentials without access in addition to SSL or VAL credentials (TODO: gotos are bad)
  rc := -13;
  goto check_more_auth;

  -- dbg_obj_princ ('DAV_AUTHENTICATE_HTTP returns -13 due to failed DAV_CHECK_PERM (', pperms, req, a_uid, a_gid, pgid, puid, ')');
  return -13;

nf_col_or_res:
  -- dbg_obj_princ ('DAV_AUTHENTICATE_HTTP returns -1');
  return -1;
}
;

create function
DAV_AUTHENTICATE_SSL_ITEM (
  inout id any,
  inout what char(1),
  inout path varchar) returns integer
{
  declare pos integer;

  if (isnull (path))
    path := DAV_SEARCH_PATH (id, what);

  if (isstring (path) and path like '%,acl')
  {
    path := regexp_replace (path, ',acl\x24', '');
    pos := strrchr (path, '/');
    if (not isnull (pos))
      what := 'C';
    id := DAV_SEARCH_ID (path, what);
  }
}
;

create function
DAV_AUTHENTICATE_SSL_CONDITION () returns integer
{
  if (is_https_ctx () and (__proc_exists ('SIOC.DBA.get_graph') is not null) and client_attr ('client_certificate') <> 0)
    return 1;

  return 0;
}
;


create function
DAV_AUTHENTICATE_SSL_SQL_PREPARE (
  inout _sql varchar,
  inout _sqlParams any,
  in _params any)
{
  declare _name, _value, _pattern, _char varchar;
  declare V any;

  _char := '?';
  if (_sql like 'sparql%')
    _char := '??';


  _pattern := '\\^\\{([a-zA-Z0-9])+\\}\\^';
  while (1)
  {
    V := regexp_parse (_pattern, _sql, 0);
    if (isnull (V))
      goto _exit;

    _name := subseq (_sql, V[0]+2, V[1]-2);
    _value := get_keyword (_name, _params);
    _sqlParams := vector_concat (_sqlParams, vector (_value));
    _sql := subseq (_sql, 0, V[0]) || _char || subseq (_sql, V[1]);
  }
_exit:;
  return;
}
;

create function
DAV_AUTHENTICATE_SSL_WEBID (
  inout webid varchar,
  inout webidGraph varchar)
{
  webid := connection_get ('__webid');
  webidGraph := connection_get ('__webidGraph');
  if (isnull (webid))
  {
    declare cert, fing, vtype any;

    cert := client_attr ('client_certificate');
    if (cert is null or cert = 0) {
      https_renegotiate (3);
      cert := client_attr ('client_certificate');
    }
    if (cert = 0)
      return null;

    fing := get_certificate_info (6, cert);
    webidGraph := 'http:' || replace (fing, ':', '');
    if (not DB.DBA.WEBID_AUTH_GEN_2 (cert, 0, null, 1, 1, webid, webidGraph, 0, vtype))
      webid := null;
  }
  connection_set ('__webid', coalesce (webid, ''));
  connection_set ('__webidGraph', webidGraph);

  webid := case when webid = '' then null else webid end;
  return webid;
}
;

create function
DAV_CHECK_ACLS_INTERNAL (
  in webid varchar,
  in webidGraph varchar,
  in graph varchar,
  in grpGraph varchar,
  inout IRIs any,
  inout reqMode any,
  inout realMode any)
{
  -- dbg_printf('DAV_CHECK_ACLS_INTERNAL (%s, %s, %s, %s, ...)', webid, webidGraph, graph, grpGraph);
  declare M, I integer;
  declare tmp, _cert, _commands, _command any;
  declare _filterMode, _filterValue, _filterCriteriaValue, _mode, _filter, _criteria, _operand, _condition, _value, _pattern, _statement, _params any;
  declare _sql, _state, _msg, _sqlParams, _meta, _rows any;

  if (not isnull (webid))
  {
  for (
    sparql
    define input:storage ""
    prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    prefix foaf: <http://xmlns.com/foaf/0.1/>
    prefix acl: <http://www.w3.org/ns/auth/acl#>
    select ?p1 ?p2 ?p3 ?mode
     where {
             {
               graph `iri(?:graph)`
               {
                 ?rule rdf:type acl:Authorization ;
                       acl:accessTo `iri(?:graph)` ;
                       acl:mode ?mode ;
                       acl:agent `iri(?:webid)` ;
                       acl:agent ?p1 .
               }
             }
             union
             {
               graph `iri(?:graph)`
               {
                 ?rule rdf:type acl:Authorization ;
                       acl:accessTo `iri(?:graph)` ;
                       acl:mode ?mode ;
                       acl:agentClass foaf:Agent ;
                       acl:agentClass ?p2 .
               }
             }
             union
             {
               graph `iri(?:graph)`
               {
                 ?rule rdf:type acl:Authorization ;
                       acl:accessTo `iri(?:graph)` ;
                       acl:mode ?mode ;
                       acl:agentClass ?p3 .
               }
               graph ?g
               {
                 ?p3 rdf:type foaf:Group ;
                 foaf:member `iri(?:webid)` .
               }
             }
           }
     order by ?p3 ?p2 ?p1 ?mode) do
  {
    if      (not isnull ("p1"))
      I := 0;
    else if (not isnull ("p2"))
      I := 1;
    else if (not isnull ("p3"))
      I := 2;
    else
      goto _skip;

    if (tmp <> coalesce ("p1", coalesce ("p2", "p3")))
    {
      tmp := coalesce ("p1", coalesce ("p2", "p3"));
      for (M := 0; M < length (IRIs[I]); M := M + 1)
      {
        if (tmp = IRIs[I][M])
          goto _skip;
      }
    }

    if ("mode" like '%#Read')
      realMode[0] := 1;
    else if ("mode" like '%#Write')
      realMode[1] := 1;
    else if ("mode" like '%#Execute')
      realMode[2] := 1;

    if ((reqMode[0] <= realMode[0]) and (reqMode[1] <= realMode[1]) and (reqMode[2] <= realMode[2]))
      goto _exit;

    IRIs[I] := vector_concat (IRIs[I], vector (tmp));

    _skip:;
  }
  }


_exit:;
}
;




create function
DAV_CHECK_ACLS (
  in id any,
  in webid varchar,
  in webidGraph varchar,
  in what char(1),
  in path varchar,
  in req varchar,
  inout a_uid integer,
  inout a_gid integer,
  inout _perms varchar) returns integer
{
  -- dbg_printf('DAV_CHECK_ACLS (_, %s, %s, %s, %s, ...)', webid, webidGraph, what, path);
  declare rc, N integer;
  declare graph, grpGraph, reqMode, realMode, IRIs any;
  declare cert, diArray, finger, digest, digestHash any;
  declare tmp, T, V any;

  rc := 0;
  req := replace (req, '_', '0');
  reqMode := vector (req[0]-48, req[1]-48, req[2]-48);
  realMode := vector (0, 0, 0);
  IRIs := vector (vector(), vector(), vector());

  set_user_id ('dba');
  tmp := '/';
  V := vector ();
  T := split_and_decode (trim (path, '/'), 0, '\0\0/');
  for (N := 0; N < length (T)-1; N := N + 1)
  {
    tmp := tmp || T[N] || '/';
    V := vector_concat (vector (tmp), V);
  }
  V := vector_concat (vector (path), V);
  for (N := 0; N < length (V); N := N + 1)
  {
    if (N <> 0)
    {
      what := 'C';
      id := DAV_SEARCH_ID (V[N], what);
    }
    if (
        (isinteger (id) and exists (select 1 from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = id and PROP_TYPE = what and PROP_NAME = 'virt:aci_meta_n3')) or
        (isarray (id) and (cast (id[0] as varchar) = 'IMAP')) or
        (isarray (id) and (cast (id[0] as varchar) = 'DynaRes'))
       )
    {
      tmp := null;
      graph := WS.WS.WAC_GRAPH (V[N]);
      grpGraph := SIOC.DBA.get_graph () || '/private/%';
      DAV_CHECK_ACLS_INTERNAL (webid, webidGraph, graph, grpGraph, IRIs, reqMode, realMode);
      if ((reqMode[0] <= realMode[0]) and (reqMode[1] <= realMode[1]) and (reqMode[2] <= realMode[2]))
        goto _exit;
    }
  }

_exit:;
  if ((reqMode[0] <= realMode[0]) and (reqMode[1] <= realMode[1]) and (reqMode[2] <= realMode[2]))
  {
    if (not DB.DBA.DAV_GET_UID_BY_WEBID (a_uid, a_gid))
    {
      a_uid := DB.DBA.DAV_GET_OWNER (id, what);
      if (DAV_HIDE_ERROR (a_uid) is null)
      {
        a_uid := http_nobody_uid ();
        a_gid := http_nogroup_gid ();
      }
      else
      {
        a_gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = a_uid), http_nogroup_gid ());
      }
    }
    rc := 1;
  }
  _perms := sprintf ('%d%d%d', realMode[0], realMode[1], realMode[2]);
  return rc;
}
;

create function
DAV_AUTHENTICATE_SSL (
  in id any,
  in what char(1),
  in path varchar,
  in req varchar,
  inout a_uid integer,
  inout a_gid integer,
  inout _perms varchar,
  out webid varchar) returns integer
{
  --dbg_printf('DAV_AUTHENTICATE_SSL (%d, %s, %s, ...)', id, what, path);
  declare rc integer;
  declare webidGraph any;

  rc := 0;
  if (DAV_AUTHENTICATE_SSL_CONDITION ())
  {
    DAV_AUTHENTICATE_SSL_ITEM (id, what, path);

    webidGraph := null;
    DB.DBA.DAV_AUTHENTICATE_SSL_WEBID (webid, webidGraph);

    _perms := '___';
    rc := DAV_CHECK_ACLS (id, webid, webidGraph, what, path, req, a_uid, a_gid, _perms);
    if (rc)
      {
	DAV_PERMS_FIX (_perms, '000000000TM');
	declare hdr, hstr any;
	hdr := http_header_array_get ();
	hstr := '';
	foreach (any h in hdr) do
	  {
	    if (h not like 'WWW-Authenticate:%')
	      hstr := hstr || h;
	  }
        http_header (hstr);
      }
  }
  return rc;
}
;

--!
-- Get authentication information via VAL and check ACLs.
--/
create function
DAV_AUTHENTICATE_WITH_VAL (
  in id any,
  in what char(1),
  in path varchar,
  in req varchar,
  inout a_uid integer,
  inout a_gid integer,
  inout _perms varchar,
  out serviceId varchar) returns integer
{
  --dbg_printf('DAV_AUTHENTICATE_WITH_VAL (%d, %s, %s, ...)', id, what, path);
  declare val_sid, val_sidRealm varchar;
  declare val_uname varchar;
  declare val_isRealUser integer;

  declare exit handler for sqlstate '*' {
    return 0;
  };

  val_sidRealm := null;
  if (not VAL.DBA.authentication_details_for_connection (
        val_sid,
        serviceId,
        val_uname,
        val_isRealUser,
        val_sidRealm,
        'sid')
     ) {
    return 0;
  }

  -- Finally verify the ACL rules
  DAV_AUTHENTICATE_SSL_ITEM (id, what, path);
  return DAV_CHECK_ACLS (id, serviceId, null, what, path, req, a_uid, a_gid, _perms);
}
;

--!AWK PUBLIC
create procedure
DAV_COL_CREATE (
    in path varchar,
    in permissions varchar := '110100000RR',
    in uid varchar := 'dav',
    in gid varchar := 'administrators',
    in auth_uid varchar := NULL,
    in auth_pwd varchar := NULL)
{
  return DAV_COL_CREATE_INT (
      path, permissions, uid, gid, auth_uid, auth_pwd, 1, 1, 1, null, null);
}
;

create procedure
DAV_COL_CREATE_INT (
    in path varchar,
    in permissions varchar,
    in uid any,
    in gid any,
    in auth_uname varchar,
    in auth_pwd varchar,
    in return_error_if_already_exists integer,  -- The most confusing thing in whole interface, and it can not be changed!
    in extern integer,
    in check_locks any,
    in ouid integer := null,
    in ogid integer := null )
{
  declare pid, puid, pgid, rc integer;
  declare pperms, name, det varchar;
  declare par any;
  -- dbg_obj_princ ('DAV_COL_CREATE_INT (', path, permissions, uid, gid, auth_uname, auth_pwd, return_error_if_already_exists, extern, check_locks, ouid, ogid, ')');
  rc := 0;
  par := split_and_decode (path, 0, '\0\0/');
  -- dbg_obj_princ ('slashes',par);
  if (aref (par, 0) <> '' or aref (par, length (par) - 1) <> '')
     return -1;
  -- dbg_obj_princ ('slashes OK');
  if (DAV_HIDE_ERROR ((pid := DAV_SEARCH_ID (path, 'P'))) is null)
    return pid;
  -- dbg_obj_princ ('parent OK', pid);
  if (extern and 0 > (rc := DAV_AUTHENTICATE (pid, 'C', '11_', auth_uname, auth_pwd)))
    {
      -- dbg_obj_princ ('authenticate OBLOM', rc);
        return rc;
    }
  if (DAV_HIDE_ERROR (DAV_SEARCH_ID (subseq (par, 0, length (par) - 1), 'R')) is not null)
    {
      -- dbg_obj_princ ('conflict');
      return -25;
    }
  if ((0 = return_error_if_already_exists) and (rc := DAV_HIDE_ERROR (DAV_SEARCH_ID (path, 'C'))) is not null)
    {
      -- dbg_obj_princ ('not overwrite and exists', rc);
        return rc;
    }
  if (check_locks and 0 <> (rc := DAV_IS_LOCKED (pid , 'C', check_locks)))
    {
      -- dbg_obj_princ ('lock OBLOM', rc);
        return rc;
    }

  if (isarray (pid))
    det := pid[0];
  else if ((pid > 0) and (connection_get ('dav_store') is null))
    det := coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID=pid), NULL);
  else
    det := null;
  if (det is not null)
    {
      declare auth_uid integer;
      declare detcol_id integer;
      declare detcol_path, unreached_path any;
      if (extern)
        {
          auth_uid := DAV_AUTHENTICATE (pid, 'C', '11_', auth_uname, auth_pwd);
          if (0 > auth_uid)
            return auth_uid;
        }
      else
        auth_uid := http_nobody_uid ();
      DAV_SEARCH_ID_OR_DET (par, 'C', det, detcol_id, detcol_path, unreached_path);
      return call (cast (det as varchar) || '_DAV_COL_CREATE') (detcol_id, unreached_path, permissions, ouid, ogid, auth_uid);
    }
  name := aref (par, length (par) - 2);
  rc := WS.WS.GETID ('C');
  if (ouid is null)
    DAV_OWNER_ID (uid, gid, ouid, ogid);

  {
    declare exit handler for sqlstate '*' {
      rc := -3;
    };
    -- dbg_obj_princ ('about to insert ', rc, name, pid, ouid, ogid, permissions, now(), now ());
    insert soft WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_OWNER, COL_GROUP, COL_PERMS, COL_CR_TIME, COL_MOD_TIME)
      values (rc, name, pid, ouid, ogid, permissions, now(), now ());

    if (not row_count())
      {
        rc := -3;
      }

    if (DB.DBA.LDP_ENABLED (pid))
      {
        declare uri any;
        uri := WS.WS.DAV_IRI (path);
        TTLP ('@prefix ldp: <http://www.w3.org/ns/ldp#> .  <> a ldp:BasicContainer, ldp:Container .', uri, uri);
        DB.DBA.LDP_CREATE (path);
      }
  }

  return rc;
}
;


create procedure DB.DBA.IS_REDIRECT_REF (inout path any)
{
  for (select blob_to_string (PROP_VALUE) redirectRef
         from WS.WS.SYS_DAV_RES,
              WS.WS.SYS_DAV_PROP
        where RES_FULL_PATH = path
          and PROP_PARENT_ID = RES_ID
          and PROP_NAME = 'redirectref'
          and PROP_TYPE = 'R') do
  {
    path := redirectRef;
    return 1;
  }
--  return DC_IS_REDIRECT_REF(path);
  return 0;
}
;

create procedure is_rdf_type(in type varchar) returns integer
{
	if (
		strstr (type, 'text/n3') is not null or
		strstr (type, 'text/turtle') is not null or
		strstr (type, 'text/rdf+n3') is not null or
		strstr (type, 'text/rdf+ttl') is not null or
		strstr (type, 'text/rdf+turtle') is not null or
		strstr (type, 'application/rdf+xml') is not null or
		strstr (type, 'application/rdf+n3') is not null or
		strstr (type, 'application/rdf+turtle') is not null or
		strstr (type, 'application/turtle') is not null or
		strstr (type, 'application/x-turtle') is not null
	)
		return 1;
	return 0;
}
;

--!AWK PUBLIC
create procedure DAV_RES_UPLOAD (
    in path varchar,
    in content any,
    in type varchar := '',
    in permissions varchar := '110100000RR',
    in uid varchar := 'dav',
    in gid varchar := 'administrators',
  in auth_uid varchar := null,
  in auth_pwd varchar := null,
  in check_locks any := 1)
{
  if (not (isstring (check_locks)))
    check_locks := 1;

  return DAV_RES_UPLOAD_STRSES_INT (path, content, type, permissions, uid, gid, auth_uid, auth_pwd, 1, null, null, null, null, null, check_locks);
}
;

--!AWK PUBLIC
create procedure DAV_RES_UPLOAD_STRSES (
    in path varchar,
    inout content any,
    in type varchar := '',
    in permissions varchar := '110100000RR',
    in uid varchar := 'dav',
    in gid varchar := 'administrators',
  in auth_uid varchar := null,
  in auth_pwd varchar := null,
  in check_locks any := 1
)
{
  if (not (isstring (check_locks)))
    check_locks := 1;

  return DAV_RES_UPLOAD_STRSES_INT (path, content, type, permissions, uid, gid, auth_uid, auth_pwd, 1, null, null, null, null, null, check_locks);
}
;

create procedure DAV_RES_UPLOAD_STRSES_INT (
    in path varchar,
    inout content any,
    in type varchar := '',
    in permissions varchar := '110100000RR',
    in uid any := 'dav',
    in gid any := 'administrators',
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in extern integer := 1,
    in cr_time datetime := null,
    in mod_time datetime := null,
    in _rowguid varchar := null,
    in ouid integer := null,
    in ogid integer := null,
  in check_locks any := 1, -- must be here to match arg order for DAV replication.
  in dav_call integer := 0
    )
{
  declare id, rc, old_log_mode, new_log_mode any;

  -- clear previous uploaded data
  id := DAV_SEARCH_ID (path, 'R');
  if (not isnull (DAV_HIDE_ERROR (id)) and ('text/turtle' = (select RES_TYPE from WS.WS.SYS_DAV_RES where RES_ID = DB.DBA.DAV_DET_DAV_ID (id))))
    WS.WS.TTL_QUERY_POST_CLEAR (path);

  if (0 = dav_call)
    {
      if (type = 'application/sparql-query')
	{
	  WS.WS.SPARQL_QUERY_POST (path, content, uid, dav_call);
	}
      else if (type = 'text/turtle')
	{
	  rc := WS.WS.TTL_QUERY_POST (path, content, 1);
      if (isnull (DAV_HIDE_ERROR (rc)))
	    return rc;
	}
    }

  old_log_mode := log_enable (null);
  -- we disable row auto commit since there are triggers reading blobs, we do that even in atomic mode since this is vital for dav uploads
  new_log_mode := bit_and (old_log_mode, 1);
  old_log_mode := log_enable (bit_or (new_log_mode, 4), 1);
  rc := DAV_RES_UPLOAD_STRSES_INT_INNER (path, content, type, permissions, uid, gid, auth_uname, auth_pwd, extern, cr_time, mod_time, _rowguid, ouid, ogid, check_locks);
  log_enable (bit_or (old_log_mode, 4), 1);
  if (DAV_HIDE_ERROR (rc) is not null)
  {
    -- create LDP triple if needed
    DB.DBA.LDP_CREATE (path);
  }

  return rc;
}
;

create procedure DAV_RES_UPLOAD_STRSES_INT_INNER (
    in path varchar,
    inout content any,
    in type varchar := '',
    in permissions varchar := '110100000RR',
    in uid any := 'dav',
    in gid any := 'administrators',
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in extern integer := 1,
    in cr_time datetime := null,
    in mod_time datetime := null,
    in _rowguid varchar := null,
    in ouid integer := null,
    in ogid integer := null,
    in check_locks any := 1 -- must be here to match arg order for DAV replication.
    )
{
  -- dbg_obj_princ ('DAV_RES_UPLOAD_STRSES_INT_INNER (', path, content, type, permissions, uid, gid, auth_uname, auth_pwd, extern, cr_time, mod_time, _rowguid, ouid, ogid, check_locks, ')');
  declare auth_uid, pid, puid, pgid, rc, id integer;
  declare pperms, name varchar;
  declare par any;
  declare op char;
  declare det varchar;
  declare detcol_id, _is_xper_res, fake integer;
  declare detcol_path, unreached_path any;
  declare res_cr cursor for select RES_ID+1 from WS.WS.SYS_DAV_RES where RES_ID = id for update;
  declare auto_version varchar;
  declare locked int;

  if (IS_REDIRECT_REF (path)) -- This is called mostly for side effect on path.
    {
      ; -- do nothing.
    }

  par := split_and_decode (path, 0, '\0\0/');
  if (aref (par, 0) <> '' or aref (par, length (par) - 1) = '')
      return -1;

  locked := 0;
  op := 'i';
  rc := 0;
  if (ouid is null)
    {
    DAV_OWNER_ID (uid, gid, ouid, ogid);
    }
  id := DAV_SEARCH_ID (path, 'R');
  -- dbg_obj_princ ('existing id is ', id);
  if (isarray (id))
    {
      if (extern)
        {
          -- dbg_obj_princ ('will authenticate resource id', id);
          auth_uid := DAV_AUTHENTICATE (id, 'R', '11_', auth_uname, auth_pwd);
          if ((auth_uid < 0) and (auth_uid <> -1))
            return auth_uid;
        }
      else
        {
        auth_uid := ouid;
        }
      if (check_locks)
        {
          rc := DAV_IS_LOCKED (id , 'R', check_locks);
          if (0 <> rc)
            return rc;
        }
      DAV_SEARCH_ID_OR_DET (par, 'R', det, detcol_id, detcol_path, unreached_path);
      rc := call (cast (det as varchar) || '_DAV_RES_UPLOAD') (detcol_id, unreached_path, content, type, permissions, ouid, ogid, auth_uid);

      return rc;
    }

  if (0 > id)
    {
      pid := DAV_SEARCH_ID (path, 'P');
      if (isarray (pid))
    {
        det := pid[0];
    }
      else if (pid > 0)
    {
        det := coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID=pid and connection_get ('dav_store') is null), NULL);
    }
      else
        {
          -- dbg_obj_princ ('no parent, DAV_RES_UPLOAD_STRSES_INT returns ', pid);
          return pid;
        }

      if (extern)
        {
          -- dbg_obj_princ ('will authenticate collection id', pid);
          auth_uid := DAV_AUTHENTICATE (pid, 'C', '11_', auth_uname, auth_pwd);
          if (auth_uid < 0)
              return auth_uid;
            }
      else
    {
        auth_uid := ouid;
    }

      if (check_locks)
        {
          rc := DAV_IS_LOCKED (pid , 'C', check_locks);
          if (0 <> rc)
            return rc;
        }

      set isolation='committed';
      if ( auth_uid <> http_nobody_uid() and
        (http_dav_uid () <> coalesce (connection_get ('DAVBillingUserID'), -12)) and
        exists (select top 1 1 from SYS_USERS where U_ID = auth_uid and U_ACCOUNT_DISABLED = 1 ))
        return -42;

      set isolation='serializable';
      if (det is not null)
        {
          DAV_SEARCH_ID_OR_DET (par, 'R', det, detcol_id, detcol_path, unreached_path);
          rc := call (cast (det as varchar) || '_DAV_RES_UPLOAD') (detcol_id, unreached_path, content, type, permissions, ouid, ogid, auth_uid);

          return rc;
        }
      name := aref (par, length (par) - 1);
      rc := WS.WS.GETID ('R');
      op := 'i';
      if (cr_time is null)
        cr_time := now();
    }
  else
    {
      open res_cr (exclusive, prefetch 1);
      fetch res_cr into fake;
      if (extern)
        {
          -- dbg_obj_princ ('will authenticate resource id', id);
          auth_uid := DAV_AUTHENTICATE (id, 'R', '11_', auth_uname, auth_pwd);
          if (auth_uid < 0)
              return auth_uid;

          pid := DAV_SEARCH_ID (path, 'P');
          -- dbg_obj_princ ('will authenticate collection id', pid);
          auth_uid := DAV_AUTHENTICATE (pid, 'C', '1__', auth_uname, auth_pwd);
          if (auth_uid < 0)
              return auth_uid;
            }
      else
    {
        auth_uid := ouid;
    }
      auto_version := DAV_HIDE_ERROR (DB.DBA.DAV_PROP_GET_INT(DAV_SEARCH_ID (path, 'R'), 'R', 'DAV:auto-version', 0));
      if (check_locks)
        {
          rc := DAV_IS_LOCKED (id , 'R', check_locks);
      locked := case when (rc < 0) then 1 else 0 end;
          if (auto_version is not null)
            {
              declare vanilla_rc int;

              vanilla_rc := DAV_IS_LOCKED (id , 'R', 1);
              if (vanilla_rc < 0)
                locked := 1;

              if (vanilla_rc = -8 and (auto_version = 'DAV:checkout-unlocked-checkin'))
                rc := 0;
              else if (vanilla_rc = -8 and (auto_version = 'DAV:locked-checkout'))
                rc := 0;
            }
          if (0 <> rc)
              return rc;
            }
      rc := id;
      op := 'u';
      if (cr_time is null or _rowguid is null)
        {
          declare _cr_time datetime;
          declare __rowguid varchar;

      select RES_CR_TIME, ROWGUID into _cr_time, __rowguid from WS.WS.SYS_DAV_RES where RES_ID = id;
          if (cr_time is null)
            cr_time := _cr_time;

          if (_rowguid is null)
            _rowguid := __rowguid;
        }
    }

  if (DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (par, vector ('')), 'C')) is not null)
  {
    -- dbg_obj_princ ('conflict');
    return -26;
  }

  if (mod_time is null)
    mod_time := now();

  if (type = '')
    type := http_mime_type (path);

  --dbg_printf ('path [%s], type [%s], op [%s], perms [%s], rowguid [%s]', path, type, op, permissions, _rowguid);
  if (type = 'text/xml' and exists (select 1 from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = pid and PROP_TYPE = 'C' and PROP_NAME = 'xper'))
  {
    insert soft WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE)
      values (WS.WS.GETID ('P'), 'xper', 'R', id, '');
    _is_xper_res := 1;
  }
  else if (rc <> 0)
  {
    delete from WS.WS.SYS_DAV_PROP where PROP_NAME = 'xper' and PROP_TYPE = 'R' and PROP_PARENT_ID = id;
    _is_xper_res := 0;
  }

  whenever sqlstate '*' goto unhappy_upload;

  if (op = 'i')
  {
    -- dbg_obj_princ ('INSERT ', name);
    insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_COL, RES_OWNER, RES_GROUP, RES_PERMS, RES_CR_TIME, RES_MOD_TIME, RES_TYPE, RES_CONTENT, ROWGUID, RES_FULL_PATH)
      values (rc, name, pid, ouid, ogid, permissions, cr_time, mod_time, type, content, _rowguid, path);

    if (_is_xper_res)
      update WS.WS.SYS_DAV_RES set RES_CONTENT = xml_persistent (RES_CONTENT) where RES_ID = id;
  }
  else
  {
    if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (id, 'R', 'DAV:checked-in', 0)) is not null)
    {
      if (auto_version = 'DAV:checkout-checkin')
      {
        ;
      }
      else if ((locked and (auto_version = 'DAV:checkout-unlocked-checkin')) or (auto_version = 'DAV:checkout') or (locked and (auto_version = 'DAV:locked-checkout')))
      {
        return "Versioning_CHECKOUT_INT" (id, content, type, permissions, ouid, ogid);
      }
      else if (locked or (auto_version is null) or ((auto_version <> 'DAV:checkout-unlocked-checkin') and (auto_version <> 'DAV:checkout-checkin')))
      {
        return -38;
      }
    }
    -- dbg_obj_princ ('UPDATE ', name);
    if (sys_stat ('cl_run_local_only') = 1)
    {
      if (length (content) > 10485760)  -- 10MB
        log_enable (0, 1);

      update WS.WS.SYS_DAV_RES
         set RES_OWNER = ouid,
             RES_GROUP = ogid,
             RES_PERMS = permissions,
             RES_CR_TIME = cr_time,
             RES_MOD_TIME = mod_time,
             RES_TYPE = type,
             RES_CONTENT = content,
             ROWGUID = _rowguid,
             RES_SIZE = null
       where current of res_cr;
    }
    else -- when it is cluster do it by PK for now
    {
      update WS.WS.SYS_DAV_RES
         set RES_OWNER = ouid,
             RES_GROUP = ogid,
             RES_PERMS = permissions,
             RES_CR_TIME = cr_time,
             RES_MOD_TIME = mod_time,
             RES_TYPE = type,
             RES_CONTENT = content,
             ROWGUID = _rowguid,
             RES_SIZE = null
       where RES_ID = id;
    }
    if (_is_xper_res)
      update WS.WS.SYS_DAV_RES set RES_CONTENT = xml_persistent (RES_CONTENT) where current of res_cr;
  }
  return rc;

unhappy_upload:
  if (__SQL_STATE = 'HT507')
    return -41;

  if (__SQL_STATE = 'HT508')
    return -42;

  if (__SQL_STATE = 'HT509')
    return -43;

  return -29;
}
;

create procedure DAV_RDF_RES_NAME (in rdf_graph varchar)
{
   return replace ( replace ( replace ( replace ( replace ( replace ( replace (rdf_graph, '/', '_'), '\\', '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_') || '.RDF';
}
;

create procedure RDF_SINK_FUNC (
  in queue_id integer,
  in path varchar,
  in rc integer,
  in c_id integer,
  in rdf_graph any,
  in type any,
  in ouid int,
  in ogid int)
{
  -- dbg_obj_print ('RDF_SINK_FUNC', path);
  declare rdf_params, rdf_sponger, rdf_base, rdf_cartridges, rdf_metaCartridges any;
  declare rdf_graph_resource_id, rdf_graph_resource_name, rdf_graph_resource_path, host, content any;
  declare exit handler for sqlstate '*'
  {
    goto _bad_content;
  };

  -- get sponger parameters?
  content := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = rc);
  rdf_params := DB.DBA.DAV_DET_RDF_PARAMS_GET ('rdfSink', c_id);
  rdf_base := get_keyword ('base', rdf_params, '');
  rdf_sponger := get_keyword ('sponger', rdf_params, 'on');
  rdf_cartridges := get_keyword ('cartridges', rdf_params, '');
  rdf_metaCartridges := get_keyword ('metaCartridges', rdf_params, '');

  -- upload into first (rdf_sink) graph
  if (RDF_SINK_UPLOAD (path, content, type, rdf_graph, rdf_base, rdf_sponger, rdf_cartridges, rdf_metaCartridges))
  {
    rdf_graph_resource_name := DAV_RDF_RES_NAME (rdf_graph);
    rdf_graph_resource_name := replace (rdf_graph_resource_name, ' ', '_');
    rdf_graph_resource_path := WS.WS.COL_PATH (c_id) || rdf_graph_resource_name;
    if (isnull (DAV_HIDE_ERROR (DAV_SEARCH_ID (rdf_graph_resource_path, 'R'))))
    {
      -- RDF content
      host := WS.WS.DAV_HOST ();
      rdf_graph_resource_id := WS.WS.GETID ('R');
      insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_COL, RES_OWNER, RES_GROUP, RES_PERMS, RES_CR_TIME, RES_MOD_TIME, RES_TYPE, RES_CONTENT)
        values (rdf_graph_resource_id, rdf_graph_resource_name, c_id, ouid, ogid, '111101101NN', now (), now (), 'text/xml', '');

      DB.DBA.DAV_PROP_SET_INT (rdf_graph_resource_path, 'redirectref', sprintf ('%s/sparql?default-graph-uri=%U&query=%U&format=%U', host, rdf_graph,
        'CONSTRUCT { ?s ?p ?o} WHERE {?s ?p ?o}', 'application/rdf+xml'), null, null, 0, 0, 1);
    }
  }

_bad_content:;
  DB.DBA.DAV_QUEUE_UPDATE_FINAL (queue_id);
}
;

create procedure RDF_SINK_UPLOAD (
  in path varchar,
  inout _content any,
  in type varchar,
  in rdf_graph varchar,
  in rdf_base varchar,
  in rdf_sponger varchar,
  in rdf_cartridges varchar,
  in rdf_metaCartridges varchar,
  in rdf_private integer := 1)
{
  -- dbg_obj_princ ('RDF_SINK_UPLOAD (', path, type, ')');
  declare rdf_iri, rdf_graph2, rdf_base2 varchar;
  declare content any;

  if (length (_content) = 0)
    return 0;

  -- general case, should return false
  declare exit handler for sqlstate '*' {
     return 0;
  };

  if (path like '%.zip')
    {
      declare lst, tmp_file any;

      tmp_file := tmp_file_name ();
      declare exit handler for sqlstate '*' {
        file_delete (tmp_file, 1);
        return 0;
      };
      rdf_graph2 := WS.WS.WAC_GRAPH (path, '#ldiTemp');
      string_to_file (tmp_file, _content, -2);
      lst := unzip_list (tmp_file);
      foreach (any x in lst) do
        {
          declare fname, item_graph, ss any;
          ss := string_output ();
          fname := x[0];
          content := unzip_file (tmp_file, fname);
          http_dav_url (fname, null, ss);
          fname := string_output_string (ss);
          item_graph := WS.WS.DAV_IRI (path || '/' || fname);
          RDF_SINK_UPLOAD (concat (path, '/', fname), content, DAV_GUESS_MIME_TYPE_BY_NAME (fname), rdf_graph, rdf_base, rdf_sponger, rdf_cartridges, rdf_metaCartridges, 0);
          SPARQL insert in graph ?:rdf_graph2 { ?s ?p ?o } where { graph `iri(?:item_graph)` { ?s ?p ?o } };
          SPARQL clear graph ?:item_graph;
        }
      file_delete (tmp_file, 1);
      goto _private;
    }

  content := _content;
  if (path like '%.gz' and length (_content) > 2)
    {
      declare magic, html_start varchar;
      magic := subseq (_content, 0, 2);
      html_start := null;
      if (magic[0] = 0hex1f and magic[1] = 0hex8b)
        {
          content := gzip_uncompress (cast (_content as varchar));
          path := regexp_replace (path, '\.gz\x24', '');
          type := DAV_GUESS_MIME_TYPE (path, content, html_start);
        }
    }
  -- dbg_obj_print ('RDF_SINK_UPLOAD (', length (content), type, rdf_graph, rdf_graph2, rdf_sponger, rdf_cartridges, rdf_metaCartridges, ')');
  rdf_iri := WS.WS.DAV_IRI (path);
  rdf_graph2 := WS.WS.WAC_GRAPH (path, '#ldiTemp');
  if (is_empty_or_null (rdf_base))
  {
    rdf_base2 := WS.WS.DAV_HOST () || path;
  }
  else
  {
    declare name varchar;

    name := trim (path, '/');
    if (not isnull (strrchr (name, '/')))
      name := right (name, length (name)-strrchr (name, '/')-1);

    rdf_base2 := rtrim (rdf_base, '/') || '/' || name;
  }
  if (
       strstr (type, 'application/rdf+xml') is not null or
       strstr (type, 'application/foaf+xml') is not null
     )
  {
    {
      declare exit handler for sqlstate '*'
      {
        goto _grddl;
      };
    if (rdf_sponger = 'on')
    {
      declare xt any;

      xt := xtree_doc (content);
      if (xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt) is not null)
        goto _grddl;
    }
    DB.DBA.RDF_LOAD_RDFXML (blob_to_string (content), rdf_base2, rdf_graph2);
    }
    goto _exit;
  }
  if (is_rdf_type(type))
  {
    {
      declare exit handler for sqlstate '*'
      {
        goto _grddl;
      };
      DB.DBA.TTLP (blob_to_string (content), rdf_base2, rdf_graph2);
    }
    goto _exit;
  }

_grddl:;
  if (rdf_sponger = 'on')
  {
    declare rc, rcMeta integer;
    declare ret_body varchar;
    declare exit handler for sqlstate '*'
    {
      goto _exit;
    };

    ret_body := cast (content as varchar);
    -- dbg_obj_print ('extractor');
    rc := RDF_SINK_UPLOAD_CARTRIDGES (ret_body, type, 'select RM_ID, RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_OPTIONS from DB.DBA.SYS_RDF_MAPPERS where RM_ENABLED = 1 order by RM_ID', rdf_iri, rdf_graph2, rdf_cartridges);
    -- dbg_obj_print ('meta');
    rcMeta := RDF_SINK_UPLOAD_CARTRIDGES (ret_body, type, 'select MC_ID, MC_PATTERN, MC_TYPE, MC_HOOK, MC_KEY, MC_OPTIONS from DB.DBA.RDF_META_CARTRIDGES where MC_ENABLED = 1 order by MC_SEQ, MC_ID', rdf_iri, rdf_graph2, rdf_metaCartridges);
    if (rc or rcMeta)
      goto _exit;
  }
  return 0;

_exit:
  SPARQL insert in graph ?:rdf_graph { ?s ?p ?o } where { graph `iri(?:rdf_graph2)` { ?s ?p ?o } };

_private:
  {
    declare exit handler for sqlstate '*' {
      SPARQL clear graph ?:rdf_graph2;
      return 1;
    };

    if (exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs'))
      DB.DBA.RDF_GRAPH_GROUP_INS ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', rdf_graph2);
  }

  return 1;
}
;


create procedure RDF_SINK_UPLOAD_CARTRIDGES (
  inout content any,
  inout type varchar,
  in S varchar,
  in rdf_iri varchar,
  in rdf_graph varchar,
  in rdf_cartridges varchar)
{
  declare cnt, hasSelection integer;
  declare cname, pname varchar;
  declare cartridges, aq, ps any;
  declare xrc, val_match any;
  declare st, msg, meta, rows, opts any;

  if (DB.DBA.is_empty_or_null (rdf_cartridges))
    return 1;

  st := '00000';
  exec (S, st, msg, vector (), vector ('use_cache', 1), meta, rows);
  if ('00000' <> st)
    return 0;

  cartridges := split_and_decode (rdf_cartridges, 0, '\0\0,');
  ps := null;
  aq := null;
  foreach (any row in rows) do
  {
    cname := cast (row[0] as varchar);
    if (position (cname, cartridges))
      goto _try;

    goto _try_next;

  _try:
    val_match := case when (row[2] = 'MIME') then type else rdf_graph end;
    if (isstring (val_match) and regexp_match (row[1], val_match) is not null)
    {
      pname := row[3];
      if (__proc_exists (pname) is null)
        goto _try_next;

      declare exit handler for sqlstate '*'
      {
        goto _try_next;
      };
      opts := vector_concat (vector (), row[5]);
      xrc := call (pname) (rdf_graph, rdf_iri, null, content, aq, ps, row[4], opts);
      -- dbg_obj_print (pname, xrc, (select count(*) from rdf_quad where g = iri_to_id (rdf_graph)));
      -- when no selection we stop processing when a given cartridge indicate to stop
      if (not hasSelection and (__tag (xrc) = 193 or xrc < 0 or xrc > 0))
        return 1;
    }
  _try_next:;
  }
  return 1;
}
;

create procedure RDF_SINK_GRAPH_SEARCH (
  in _path varchar,
  inout _col_id integer)
{
  -- dbg_obj_princ ('RDF_SINK_GRAPH_SEARCH (', _path, ')');
  declare _col_parent, _depth integer;
  declare _inherit, _graph varchar;
  declare _params any;

  declare exit handler for not found
  {
    return null;
  };

 _depth := 0;

_again:;
  _params := DB.DBA.DAV_DET_RDF_PARAMS_GET ('rdfSink', _col_id);
  _graph := get_keyword ('graph', _params);
  if (length (_graph) and (_depth = 0))
  {
    return _graph;
  }
  select COL_PARENT, COL_INHERIT into _col_parent, _inherit from WS.WS.SYS_DAV_COL where COL_ID = _col_id;
  if (length (_graph) and ((_inherit = 'R') or (_depth = 1 and _inherit = 'M') or (_depth = 0)))
  {
    return _graph;
  }
  _col_id := _col_parent;
  _depth := _depth + 1;

  goto _again;

  return null;
}
;

create procedure RDF_SINK_INSERT (
  in _path varchar,
  in _res_id integer,
  in _col_id integer,
  in _res_type varchar,
  in _res_owner integer,
  in _res_group integer)
{
  -- dbg_obj_princ ('RDF_SINK_INSERT (', _path, ')');
  declare _graph varchar;

  _graph := RDF_SINK_GRAPH_SEARCH (_path, _col_id);
  if (length (_graph))
  {
    DB.DBA.DAV_QUEUE_ADD ('RDF_SINK_INSERT', _res_id, 'DB.DBA.RDF_SINK_FUNC', vector (_path, _res_id, _col_id, _graph, _res_type, _res_owner, _res_group));
    DB.DBA.DAV_QUEUE_INIT ();
  }
}
;

create procedure RDF_SINK_DELETE (
  in _path varchar,
  in _res_id integer,
  in _col_id integer)
{
  -- dbg_obj_princ ('RDF_SINK_DELETE (', _path, ')');
  declare _graph varchar;

  _graph := RDF_SINK_GRAPH_SEARCH (_path, _col_id);
  if (length (_graph))
  {
    DB.DBA.DAV_QUEUE_ADD ('RDF_SINK_DELETE', _res_id, 'DB.DBA.RDF_SINK_CLEAR', vector (_path, _graph));
    DB.DBA.DAV_QUEUE_INIT ();
  }
}
;

create procedure RDF_SINK_CLEAR (
  in queue_id integer,
  in path varchar,
  in rdf_graph varchar)
{
  -- dbg_obj_princ ('RDF_SINK_CLEAR (', path, rdf_graph, ')');
  declare rdf_group, rdf_graph2 varchar;
  declare g_iid, g2_iid any;

  rdf_group := 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs';
  if (path like '%.gz')
  {
    path := regexp_replace (path, '\.gz\x24', '');
  }
  rdf_graph2 := WS.WS.WAC_GRAPH (path, '#ldiTemp');
  g_iid := __i2idn (rdf_graph);
  g2_iid := __i2idn (rdf_graph2);
  for (select a.S as _s, a.P as _p, a.O as _o from DB.DBA.RDF_QUAD a where a.G = g2_iid) do
	{
	  delete from DB.DBA.RDF_QUAD where G = g_iid and S = _s and P = _p and O = _o;
	}
  delete from DB.DBA.RDF_QUAD where G = g2_iid;
  if (exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = rdf_group))
  {
    DB.DBA.RDF_GRAPH_GROUP_DEL (rdf_group, rdf_graph2);
  }

  DB.DBA.DAV_QUEUE_UPDATE_FINAL (queue_id);
}
;

--!AWK PUBLIC
create procedure DAV_DELETE (
  in path varchar,
  in silent integer := 0,
  in auth_uname varchar,
  in auth_pwd varchar
)
{
  return DAV_DELETE_INT (path, silent, auth_uname, auth_pwd);
}
;

create procedure DAV_DELETE_INT (
  in path varchar,
  in silent integer := 0,
  in auth_uname varchar,
  in auth_pwd varchar,
  in extern integer := 1,
  in check_locks any := 1
)
{
  declare id, id_meta, rc integer;
  declare what char;
  declare auth_uid integer;
  declare par, path_meta any;
  whenever sqlstate 'HT508' goto disabled_owner;
  whenever sqlstate 'HT509' goto disabled_home;

  par := split_and_decode (path, 0, '\0\0/');
  if (aref (par, 0) <> '')
    return -1;

  what := case when (aref (par, length (par) - 1) = '') then 'C' else 'R' end;
  id := DAV_SEARCH_ID (par, what);
  if (isinteger (id) and (0 > id))
    return (case when silent then 1 else id end);

  if (extern)
  {
    auth_uid := DAV_AUTHENTICATE (id, what, '11_', auth_uname, auth_pwd);
    if (auth_uid < 0)
      return (case when silent then 1 else auth_uid end);
  }
  else
    auth_uid := http_nobody_uid ();


  if (check_locks and (0 <> (rc := DAV_IS_LOCKED (id, what, check_locks))))
    return rc;

  if (isarray (id))
  {
    declare det varchar;
    declare detcol_id, detcol_path, unreached_path any;
    DAV_SEARCH_ID_OR_DET (par, what, det, detcol_id, detcol_path, unreached_path);
    return call (cast (det as varchar) || '_DAV_DELETE') (detcol_id, unreached_path, what, silent, auth_uid);
  }

  path_meta := rtrim (path, '/') || ',meta';
  id_meta := DAV_SEARCH_ID (path_meta, 'R');
  if (what = 'R')
  {
    delete from WS.WS.SYS_DAV_RES where RES_ID = id;
    DB.DBA.LDP_DELETE (path);

    -- delete *,meta
    if (not isnull (DB.DBA.DAV_HIDE_ERROR (id_meta)))
    {
      delete from WS.WS.SYS_DAV_RES where RES_ID = id_meta;
      DB.DBA.LDP_DELETE (path_meta);
    }
  }
  else if (what = 'C')
  {
    declare rrc integer;
    declare items any;
    declare det, proc, graph varchar;

    det := cast (coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = id), '') as varchar);
    if ((det = '') or DB.DBA.DAV_DET_IS_SPECIAL (det))
    {
      if (det = 'IMAP')
      {
        items := call (det || '_DAV_DIR_LIST') (id, vector (), path, 0, '%', http_dav_uid ());
        connection_set ('dav_store', 1);
        foreach (any item in items) do
        {
          rrc := call (det || '_DAV_DELETE') (id, split_and_decode (item[10] || case when (item[1] = 'C') then '/' else '' end, 0, '\0\0/'), item[1], silent, auth_uid);
          if (rrc <> 1)
          {
            connection_set ('dav_store', null);
            rollback work;
            return rrc;
          }
        }
        if (__proc_exists ('DB.DBA.IMAP__ownerErase') is not null)
        {
          DB.DBA.IMAP__ownerErase (id);
        }
        connection_set ('dav_store', null);
      }
      else
      {
        if (det <> '')
          connection_set ('dav_store', 1);

        for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = id do
        {
          rrc := DAV_DELETE_INT (RES_FULL_PATH, silent, auth_uname, auth_pwd, extern);
          if ((rrc <> 1) and (RES_FULL_PATH not like '%,acl'))
          {
            connection_set ('dav_store', null);
            rollback work;
            return rrc;
          }
        }
        for select COL_ID, COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = id do
        {
          rrc := DAV_DELETE_INT (WS.WS.COL_PATH(COL_ID), silent, auth_uname, auth_pwd, extern);
          if ((rrc <> 1) and (COL_NAME not like '%,acl'))
          {
            connection_set ('dav_store', null);
            rollback work;
            return rrc;
          }
        }
        if (det <> '')
          connection_set ('dav_store', null);
      }

      graph := DB.DBA.DAV_PROP_GET_INT (id, 'C', sprintf ('virt:%s-graph', det), 0);
      if (not isnull (DB.DBA.DAV_HIDE_ERROR (graph)) and (graph <> ''))
      {
        declare exit handler for sqlstate '*' {;};
        DB.DBA.RDF_GRAPH_GROUP_DEL ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', graph);
      }
    }
    delete from WS.WS.SYS_DAV_COL where COL_ID = id;
    DB.DBA.LDP_DELETE (path);

    -- delete *,meta
    if (not isnull (DB.DBA.DAV_HIDE_ERROR (id_meta)))
    {
      delete from WS.WS.SYS_DAV_RES where RES_ID = id_meta;
      DB.DBA.LDP_DELETE (path_meta);
    }
  }
  else if (not silent)
  {
    return -1;
  }

  return 1;

disabled_owner:
  return -42;

disabled_home:
  return -43;
}
;


create function DAV_TAG_LIST (in id any, in st char (1), in uid_list any) returns any
{
  if (isarray (id))
    {
      whenever sqlstate '42001' goto unsupported;
      return call (cast (id[0] as varchar) || '_DAV_TAG_LIST')(id, st, uid_list);
unsupported:
      return -20;
    }
  if ('R' <> st)
    return vector ();
  if (uid_list is null)
    return (select VECTOR_AGG (vector (DT_U_ID, DT_TAGS)) from Ws.WS.SYS_DAV_TAG where DT_RES_ID = id);
  else
    return (select VECTOR_AGG (vector (DT_U_ID, DT_TAGS)) from Ws.WS.SYS_DAV_TAG where DT_RES_ID = id and position (DT_U_ID, uid_list));
}
;

create function DAV_TAG_SET (in id any, in st char (1), in uid integer, in tags varchar) returns integer
{
  if (not exists (select 1 from WS.WS.SYS_DAV_USER where U_ID = uid))
    return -18;
  if ('R' <> st)
    return -14;
  if (exists (select 1 from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = uid))
    {
      update WS.WS.SYS_DAV_TAG set DT_TAGS = tags where DT_RES_ID = id and DT_U_ID = uid;
    }
  else
    {
      insert into WS.WS.SYS_DAV_TAG (DT_RES_ID, DT_U_ID, DT_FT_ID, DT_TAGS)
      values (id, uid, WS.WS.GETID ('T'), tags);
    }
  return 0;
}
;


--!AWK PUBLIC
create procedure DAV_COPY (
  in path varchar,
  in destination varchar,
  in overwrite integer := 0,
  in permissions varchar := '110100000RR',
  in uid varchar := 'dav',
  in gid varchar := 'administrators',
  in auth_uname varchar,
  in auth_pwd varchar)
{
  return DAV_COPY_INT (path, destination, overwrite, permissions, uid, gid, auth_uname, auth_pwd, 1);
}
;


create procedure DAV_COPY_INT (
  in path varchar,
  in destination varchar,
  in overwrite integer := 0,
  in permissions varchar := '110100000RR',
  in uid varchar := 'dav',
  in gid varchar := 'administrators',
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1,
  in ouid integer := null,
  in ogid integer := null )
{
  declare id, d_id, dp_id, rc integer;
  declare auth_uid integer;
  declare st, dp_det char;
  declare sar, dar, prop_list, tag_list any;
  whenever sqlstate 'HT507' goto insufficient_storage;
  whenever sqlstate 'HT508' goto disabled_owner;
  whenever sqlstate 'HT509' goto disabled_home;
  -- dbg_obj_princ ('DAV_COPY_INT (', path, destination, overwrite, permissions, uid, gid, auth_uname, auth_pwd, extern, check_locks, ouid, ogid, ')');
  if (IS_REDIRECT_REF(path)) -- This is called mostly for side effect on path
    {
      -- dbg_obj_princ ('DAV_COPY_INT redirects to ', path);
      ;
    }

  sar := split_and_decode (path, 0, '\0\0/');
  dar := split_and_decode (destination, 0, '\0\0/');

  if (aref (sar, 0) <> '')
    return -1;

  if (aref (sar, length (sar) - 1) = '')
    st := 'C';
  else
    st := 'R';

  if (aref (dar, 0) <> '')
    return -2;

  if (aref (dar, length (dar) - 1) = '')
    {
      if (st = 'R')
        {
          destination := concat (destination, sar[length (sar)-1]);
          dar := split_and_decode (destination, 0, '\0\0/');
        }
    }
  else if (st = 'C')
    {
      return -4;
    }
  id := DAV_SEARCH_ID (sar, st);
  if (DAV_HIDE_ERROR (id) is null)
    return id;

  dp_id := DAV_SEARCH_ID (dar, 'P');
  d_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (dar, st));
  if (d_id is null)
    {
      if (DAV_HIDE_ERROR (dp_id) is null)
        return -2;
    }
  else
    {
      dp_id := DAV_SEARCH_ID (dar, 'P');
    }
  if (d_id is not null and not overwrite)
    return -3;

  if (d_id is not null and (id = d_id))
    return -2;

  -- get the ID's before authentication. This is to let proper 'auth_uid := ouid' if not extern.
  if (ouid is null)
    DAV_OWNER_ID (uid, gid, ouid, ogid);

  -- do authenticate & try locks
  if (extern)
    {
      if (0 > (auth_uid := DAV_AUTHENTICATE (id, st, '1__', auth_uname, auth_pwd)))
        return auth_uid;
      if (d_id is not null)
        {
          if (0 > (auth_uid := DAV_AUTHENTICATE (d_id, st, '11_', auth_uname, auth_pwd)))
            return auth_uid;
        }
      if (0 > (auth_uid := DAV_AUTHENTICATE (dp_id, 'C', '11_', auth_uname, auth_pwd)))
        return auth_uid;
    }
  else
    {
      auth_uid := ouid;
    }
  -- dbg_obj_princ ('st = ', st, ', dar = ', dar);
  if (('C' = st) and DAV_HIDE_ERROR (DAV_SEARCH_ID (subseq (dar, 0, length (dar) - 1), 'R')) is not null)
    {
      -- dbg_obj_princ ('conflict -25');
      return -25;
    }
  if (('R' = st) and DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (dar, vector ('')), 'C')) is not null)
    {
      -- dbg_obj_princ ('conflict -26');
      return -26;
    }
  if (('C' = st) and destination between path and DAV_COL_PATH_BOUNDARY (path))
    return -30;

  if (check_locks)
    {
      declare auto_version varchar;

      auto_version := case when (st = 'R') then DAV_HIDE_ERROR (DB.DBA.DAV_PROP_GET_INT(d_id, 'R', 'DAV:auto-version', 0)) else null end;
      if (auto_version <> 'DAV:locked-checkout')
        {
          if (0 <> (rc := DAV_IS_LOCKED (id , st, check_locks)))
            return rc;
          if (d_id is null)
            rc := DAV_IS_LOCKED (dp_id , 'C', check_locks);
          else
            rc := DAV_IS_LOCKED (d_id , st, check_locks);
          if (0 <> rc)
            return (case when rc = -8 then -9 else rc end);
        }
      else
        {
          rc := DAV_IS_LOCKED (d_id , st, check_locks);
          if (rc = -8)
             {
               rc := DAV_CHECKOUT_INT (d_id, null, null, 0);
               if (rc < 0)
                 return rc;
             }
          else if (0 <> rc)
             return rc;
        }
    }

  if (isarray (dp_id))
  {
    dp_det := dp_id[0];
  }
  else
  {
    dp_det := coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = dp_id), null);
  }
  if (dp_det is not null)
    {
      declare detcol_id integer;
      declare detcol_path, unreached_path any;

      DAV_SEARCH_ID_OR_DET (dar, st, dp_det, detcol_id, detcol_path, unreached_path);
      return call (cast (dp_det as varchar) || '_DAV_RES_UPLOAD_COPY') (detcol_id, unreached_path, id, st, overwrite, permissions, ouid, ogid, auth_uid, auth_uname, auth_pwd, extern, check_locks);
    }
  -- dbg_obj_princ ('DAV_COPY_INT will copy ', st, id, ' to ', d_id, ' in ', dp_id);
  if (st = 'R')
    {
      declare newid integer;

      if (d_id is not null) -- do update
        {
          if (isarray (id))
            {
              declare rt varchar;
              declare rcnt any;

              rcnt := string_output ();
              rc := call (cast (id[0] as varchar) || '_DAV_RES_CONTENT') (id, rcnt, rt, 1);
              if (DAV_HIDE_ERROR (rc) is null)
                return rc;

              update WS.WS.SYS_DAV_RES
                 set RES_CONTENT = rcnt,
                     RES_TYPE = rt,
                     RES_OWNER = ouid,
                     RES_GROUP = ogid,
                     RES_PERMS = permissions,
                     RES_MOD_TIME = now ()
               where RES_ID = d_id;

              DB.DBA.DAV_DET_PROPS_REMOVE (id[0], d_id, 'R');
            }
          else
            for select RES_TYPE as rt, RES_CONTENT as rcnt, RES_SIZE as rsize from WS.WS.SYS_DAV_RES where RES_ID = id do
              {
                update WS.WS.SYS_DAV_RES
                   set RES_CONTENT = rcnt,
                       RES_TYPE = rt, RES_OWNER = ouid,
                       RES_GROUP = ogid,
                       RES_PERMS = permissions,
                       RES_MOD_TIME = now (),
                       RES_SIZE = rsize
                 where RES_ID = d_id;
              }
          newid := d_id;
        }
      else -- do insert
        {
          declare rname varchar;

          rname := aref (dar, length (dar)-1);
          if (rname = '')
            return -2;
          if (isarray (id))
            {
              declare rt varchar;
              declare rcnt any;

              rcnt := string_output ();
              rc := call (cast (id[0] as varchar) || '_DAV_RES_CONTENT') (id, rcnt, rt, 1);
              if (DAV_HIDE_ERROR (rc) is null)
                return rc;

              newid := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (destination, rcnt, rt, permissions, ouid, ogid, extern=>0);
            }
          else
            {
              for (select RES_TYPE as rt, RES_CONTENT as rcnt, RES_NAME as mname from WS.WS.SYS_DAV_RES where RES_ID = id) do
                {
                  newid := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (destination, rcnt, rt, permissions, ouid, ogid, extern=>0);
                }
            }
        }
      DB.DBA.DAV_COPY_PROPS (0, id, 'R', destination, auth_uname, auth_pwd, extern, auth_uid);
      DB.DBA.DAV_COPY_TAGS (id, 'R', newid);
    }
  else if (st = 'C')
    {
      declare newid integer;

      if (dar[length (dar)-1] <> '')
        return -2;

      if (dar[length (dar)-2] = '')
        return -2;

      if (isarray (id) and (id[0] like '%CatFilter'))
        return -39;

      if (d_id is not null) -- do delete first
        {
          declare rrc integer;

          rrc := DAV_DELETE_INT (destination, 0, auth_uname, auth_pwd, 0);
          if (rrc <> 1)
            {
              rollback work;
              return rrc;
            }
        }
      newid := DAV_COL_CREATE_INT (destination, permissions, uid, gid, auth_uname, auth_pwd, 0, 0, 0, ouid, ogid);
      if (DAV_HIDE_ERROR (newid) is null)
        {
          rollback work;
          return newid;
        }
      DB.DBA.DAV_COPY_PROPS (0, id, 'C', destination, auth_uname, auth_pwd, extern, auth_uid);
      DB.DBA.DAV_COPY_SUBTREE (id , newid, sar, destination, 1, ouid, ogid, auth_uname, auth_pwd, extern, check_locks, auth_uid);
    }
  return 1;

insufficient_storage:
  return -41;
disabled_owner:
  return -42;
disabled_home:
  return -43;
}
;


-- copy all infinite with given col_id_src and col_id_dst
create procedure DAV_COPY_SUBTREE (
  in src any,
  in dst any,
  in sar any,
  in dar any,
  in overwrite integer,
  in ouid integer := null,
  in ogid integer := null,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1,
  in auth_uid integer ) returns any
{
  -- dbg_obj_princ ('DAV_COPY_SUBTREE (', src, dst, sar, dar, overwrite, auth_uname, auth_pwd, auth_uid, ')');
  declare dirlist, ret, rc any;

  vectorbld_init (ret);
  dirlist := DAV_DIR_LIST_INT (DAV_CONCAT_PATH ('/', sar), 0, '%', NULL, NULL, auth_uid);
  foreach (any res in dirlist) do
    {
      if ('R' = res[1])
        {
          declare target_path varchar;

          target_path := DAV_CONCAT_PATH (dar, res[10]);
          if (extern)
          {
            rc := DAV_AUTHENTICATE (res[4], 'R', '1__', auth_uname, auth_pwd, auth_uid);
            if (rc < 0)
              goto _r_error;
          }
          rc := DAV_COPY_INT (res[0], target_path, overwrite, res[5], res[7], res[6], auth_uname, auth_pwd, extern, check_locks, ouid, ogid );
        _r_error:;
          vectorbld_acc (ret, vector (res[0], target_path, rc));
        }
    }
  foreach (any res in dirlist) do
    {
      if ('C' = res[1])
        {
          declare target_path varchar;
          declare new_tgt_id integer;

          target_path := DAV_CONCAT_PATH (dar, res[10]) || '/';
          if (isarray (res[4]) and (res[4][0] like '%CatFilter'))
            {
              vectorbld_acc (ret, vector (res[0], target_path, -39));
            }
          else
          {
            if (extern)
            {
              rc := DAV_AUTHENTICATE (res[4], 'C', '1__', auth_uname, auth_pwd, auth_uid);
              if (rc < 0)
                goto _c_error;
            }
            new_tgt_id := DAV_COL_CREATE_INT (target_path, res[5], res[7], res[6], auth_uname, auth_pwd, 0, extern, check_locks, ouid, ogid);
            vectorbld_acc (ret, vector (res[0], target_path, new_tgt_id));
            if (DAV_HIDE_ERROR (new_tgt_id) is not null)
              {
                DB.DBA.DAV_COPY_PROPS (0, res[4], res[1], new_tgt_id, auth_uname, auth_pwd, extern, auth_uid);
              }
            rc := DAV_COPY_SUBTREE (res[4], new_tgt_id, res[0], target_path, overwrite, ouid, ogid, auth_uname, auth_pwd, extern, check_locks, auth_uid);
            vectorbld_concat_acc (ret, rc);
          }
        _c_error:;
        }
    }
  vectorbld_final (ret);
  return ret;
}
;


--!AWK PUBLIC
create procedure DAV_MOVE (
  in path varchar,
  in destination varchar,
  in overwrite integer := 0,
  in auth_uname varchar,
  in auth_pwd varchar)
{
  return DAV_MOVE_INT (path, destination, overwrite, auth_uname, auth_pwd, 1);
}
;


create procedure DAV_MOVE_INT (
  in path varchar,
  in destination varchar,
  in overwrite integer := 0,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1 )
{
  -- dbg_obj_princ ('DAV_MOVE_INT (', path, destination, overwrite, auth_uname, auth_pwd, extern, check_locks, ')');
  declare id, d_id, dp_id, rc integer;
  declare auth_uid integer;
  declare st, dp_det char;
  declare sar, dar, prop_list any;
  whenever sqlstate 'HT507' goto insufficient_storage;
  whenever sqlstate 'HT508' goto disabled_owner;
  whenever sqlstate 'HT509' goto disabled_home;

  sar := split_and_decode (path, 0, '\0\0/');
  dar := split_and_decode (destination, 0, '\0\0/');

  if (aref (sar, 0) <> '')
    return -1;

  if (aref (sar, length (sar) - 1) = '')
    st := 'C';
  else
    st := 'R';

  if (aref (dar, 0) <> '')
    return -2;

  if (aref (dar, length (dar) - 1) = '')
    {
      if (st = 'R')
        {
          destination := concat (destination, sar[length (sar)-1]);
          dar := split_and_decode (destination, 0, '\0\0/');
        }
    }
  else
    {
      if (st = 'C')
        return -4;
    }

  id := DAV_SEARCH_ID (sar, st);
  if (DAV_HIDE_ERROR (id) is null)
    return id;

  dp_id := DAV_SEARCH_ID (dar, 'P');
  d_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (dar, st));
  if (d_id is null)
    {
      if (DAV_HIDE_ERROR (dp_id) is null)
        return -2;
    }
  else
    {
      dp_id := DAV_SEARCH_ID (dar, 'P');
    }
  if (d_id is not null and not overwrite)
    return -3;

  if (d_id is not null and id = d_id)
    return -2;

  -- do authenticate & try locks
  if (extern)
    {
      if (0 > (auth_uid := DAV_AUTHENTICATE (id, st, '11_', auth_uname, auth_pwd)))
        return auth_uid;
      if (d_id is not null)
        {
          if (0 > (auth_uid := DAV_AUTHENTICATE (d_id, st, '11_', auth_uname, auth_pwd)))
            return auth_uid;
        }
      if (0 > (auth_uid := DAV_AUTHENTICATE (dp_id, 'C', '11_', auth_uname, auth_pwd)))
        return auth_uid;
    }
  else
    {
      auth_uid := http_nobody_uid ();
    }
  -- dbg_obj_princ ('st = ', st, ', dar = ', dar);
  if (('C' = st) and DAV_HIDE_ERROR (DAV_SEARCH_ID (subseq (dar, 0, length (dar) - 1), 'R')) is not null)
    {
      -- dbg_obj_princ ('conflict -25');
      return -25;
    }
  if (('R' = st) and (0 = overwrite) and DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (dar, vector ('')), 'C')) is not null)
    {
      -- dbg_obj_princ ('conflict -26');
      return -26;
    }
  if (('C' = st) and destination between path and DAV_COL_PATH_BOUNDARY (path))
    return -30;

  if (check_locks)
    {
      if (0 <> (rc := DAV_IS_LOCKED (id , st, check_locks)))
        return rc;
      if (d_id is null)
        rc := DAV_IS_LOCKED (dp_id , 'C', check_locks);
      else
        rc := DAV_IS_LOCKED (d_id , st, check_locks);
      if (0 <> rc)
        return (case when rc = -8 then -9 else rc end);
    }

  if (isarray (dp_id))
  {
    dp_det := dp_id[0];
  }
  else
  {
    dp_det := coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID=dp_id), NULL);
  }
  if (dp_det is not null)
    {
      declare detcol_id integer;
      declare detcol_path, unreached_path any;

      DAV_SEARCH_ID_OR_DET (dar, st, dp_det, detcol_id, detcol_path, unreached_path);
      return call (cast (dp_det as varchar) || '_DAV_RES_UPLOAD_MOVE') (detcol_id, unreached_path, id, st, overwrite, auth_uid, auth_uname, auth_pwd, extern, check_locks);
    }
  -- dbg_obj_princ ('DAV_MOVE_INT will move ', st, id, ' to ', d_id, ' in ', dp_id);
  if (st = 'R') -- XXX: in all cases we do not change the content type : it represents the content.
    {
      -- dbg_obj_princ ('DAV_MOVE_INT has a resource');
      if (d_id is not null) -- do update of destination and delete of source
        {
          -- dbg_obj_princ ('DAV_MOVE_INT has a resource');
          if (isarray (id))
            {
              declare rt varchar;
              declare rcnt any;
              declare dirsingle any;

              dirsingle := call (cast (id[0] as varchar) || '_DAV_DIR_SINGLE') (id, 'R', path, auth_uid);
              if (isinteger (dirsingle))
                {
                  signal ('.....', sprintf ('DAV_DIR_SINGLE failed during DAV_MOVE'));
                  return -100;
                }
              rcnt := string_output ();
              rc := call (cast (id[0] as varchar) || '_DAV_RES_CONTENT') (id, rcnt, rt, 1);
              if (DAV_HIDE_ERROR (rc) is null)
                return rc;

              update WS.WS.SYS_DAV_RES
                 set RES_CONTENT = rcnt,
                     RES_TYPE = rt,
                     RES_OWNER = dirsingle[7],
                     RES_GROUP = dirsingle[6],
                     RES_PERMS = dirsingle[5],
                     RES_MOD_TIME = now ()
               where RES_ID = d_id;

              rc := DAV_DELETE_INT (path, 1, null, null, 0);
              if (rc < 0)
                return rc;
            }
          else
            {
              declare pid integer;
              declare rname, rtype varchar;

              select RES_COL, RES_NAME, RES_TYPE into pid, rname, rtype from WS.WS.SYS_DAV_RES where RES_ID = d_id;
              delete from WS.WS.SYS_DAV_TAG where DT_RES_ID = d_id;
              delete from WS.WS.SYS_DAV_RES where RES_ID = d_id;
              update WS.WS.SYS_DAV_RES set RES_COL = dp_id, RES_NAME = rname, RES_MOD_TIME = now () where RES_ID = id;
              if (DB.DBA.DAV_DET_IS_WEBDAV_BASED (DB.DBA.DAV_DET_NAME (id)))
                {
                  delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = DB.DBA.DAV_DET_DAV_ID (id);
                }
              update WS.WS.SYS_DAV_LOCK set LOCK_PARENT_ID = id where LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = d_id;
              -- dbg_obj_princ ('DAV_MOVE_INT completed deleted destination and update source to set new RES_NAME = ', rname, ' and RES_COL = ', dp_id);
            }
        }
      else -- do update of source
        {
          declare rname varchar;

          rname := aref (dar, length (dar)-1);
          if (rname = '')
            return -3;

          if (isarray (id))
            {
              declare rt varchar;
              declare rcnt any;
              declare newid integer;
              declare dirsingle any;

              dirsingle := call (cast (id[0] as varchar) || '_DAV_DIR_SINGLE') (id, 'R', path, auth_uid);
              if (isinteger (dirsingle))
                {
                  signal ('.....', sprintf ('DAV_DIR_SINGLE failed during DAV_MOVE'));
                  return -100;
                }
              rcnt := string_output ();
              rc := call (cast (id[0] as varchar) || '_DAV_RES_CONTENT') (id, rcnt, rt, 1);
              if (DAV_HIDE_ERROR (rc) is null)
                return rc;

              newid := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (destination, rcnt, rt, dirsingle[5], dirsingle[7], dirsingle[6], extern=>0);
              rc := DAV_DELETE_INT (path, 1, null, null, 0);
              if (rc < 0)
                return rc;

              if (DB.DBA.DAV_DET_IS_WEBDAV_BASED (DB.DBA.DAV_DET_NAME (id)))
                {
                  delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = DB.DBA.DAV_DET_DAV_ID (id);
                }
            }
          else
            {
              update WS.WS.SYS_DAV_RES set RES_COL = dp_id, RES_NAME = rname, RES_MOD_TIME = now () where RES_ID = id;
              if (DB.DBA.DAV_DET_IS_WEBDAV_BASED (DB.DBA.DAV_DET_NAME (id)))
                delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = DB.DBA.DAV_DET_DAV_ID (id);
            }

          -- dbg_obj_princ ('DAV_MOVE_INT completed update source to set new RES_NAME = ', rname, ' and RES_COL = ', dp_id);
        }
      DB.DBA.DAV_COPY_PROPS (1, id, st, destination, auth_uname, auth_pwd, extern, auth_uid);
    }
  else if (st = 'C')
    {
      declare rname varchar;

      rname := aref (dar, length (dar)-1);
      if (rname <> '')
        return -3;

      rname := aref (dar, length (dar)-2);
      if (rname = '')
        return -3;

      if (not DB.DBA.DAV_DET_IS_WEBDAV_BASED (DB.DBA.DAV_DET_NAME (id)))
        return -20;

      if (d_id is not null) -- do delete first
        {
          declare rrc integer;
          rrc := DAV_DELETE_INT (destination, 0, auth_uname, auth_pwd, 0);
          if (rrc <> 1)
            {
              rollback work;
              return rrc;
            }
        }

      if (isarray (id))
        {
          declare dirsingle any;

          dirsingle := call (cast (id[0] as varchar) || '_DAV_DIR_SINGLE') (id, 'C', path, auth_uid);
          if (isinteger (dirsingle))
            {
              signal ('.....', sprintf ('DAV_DIR_SINGLE failed during DAV_MOVE'));
              return -100;
            }
          d_id := DAV_COL_CREATE_INT (destination, dirsingle[5], dirsingle[7], dirsingle[6], auth_uname, auth_pwd, 0, 0, 0);
          if (DAV_HIDE_ERROR (d_id) is null)
            {
              rollback work;
              return d_id;
            }
          DB.DBA.DAV_COPY_PROPS (0, id, 'C', destination, auth_uname, auth_pwd, extern, auth_uid);
          DB.DBA.DAV_COPY_SUBTREE (id , d_id, sar, destination, 1, dirsingle[7], dirsingle[6], auth_uname, auth_pwd, extern, check_locks, auth_uid);
        }
      else
        {
          update WS.WS.SYS_DAV_COL set COL_NAME = rname, COL_PARENT = dp_id, COL_MOD_TIME = now () where COL_ID = id;
        }

      rc := DAV_DELETE_INT (path, 1, null, null, 0);
      if (rc < 0)
        return rc;

      delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'C' and LOCK_PARENT_ID = DB.DBA.DAV_DET_DAV_ID (id);
      update WS.WS.SYS_DAV_LOCK set LOCK_PARENT_ID = id where LOCK_PARENT_TYPE = 'C' and LOCK_PARENT_ID = d_id;
    }
  return 1;

insufficient_storage:
  return -41;
disabled_owner:
  return -42;
disabled_home:
  return -43;
}
;

create procedure DAV_COPY_PROPS (
  in mode integer,
  in src any,
  in what char(1),
  in dst any,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in auth_uid integer := null)
{
  -- dbg_obj_princ ('DAV_COPY_PROPS (', mode, src, what, dst, ')');
  declare det varchar;
  declare props any;

  if (isstring (dst))
  {
    dst := DB.DBA.DAV_SEARCH_ID (dst, what);
  }
  det := case when (isarray (src)) then src[0] else '' end;
  props := DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_PROP_LIST_INT (src, what, '%', extern, auth_uname, auth_pwd), vector ());
  foreach (any prop in props) do
    {
      if (mode and (prop[0] in ('DAV:checked-in', 'DAV:checked-out', 'DAV:version-history')))
        goto _skip;

      if ((det <> '') and ((prop[0] like ('virt:' || det || '%')) or (prop[0] = 'virt:DETCOL_ID')))
        goto _skip;

      DB.DBA.DAV_PROP_SET_RAW (dst, what, prop[0], prop[1], 0, auth_uid);

    _skip:;
    }
}
;

create procedure DAV_COPY_TAGS (
  in src any,
  in what char(1),
  in dst any)
{
  -- dbg_obj_princ ('DAV_COPY_TAGS (', src, what, dst, ')');
  declare tags any;

  if (isarray (src))
    return;

  if (isstring (dst))
  {
    dst := DB.DBA.DAV_SEARCH_ID (dst, what);
  }
  tags := DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_TAG_LIST (src, what, null), vector ());
  foreach (any tag in tags) do
    {
      DB.DBA.DAV_TAG_SET (dst, what, tag[0], tag[1]);
    }
}
;

create function
DAV_GET_OWNER (in id any, in st char(1)) returns integer
{
  if (isarray (id))
    {
      declare diritm any;
      diritm := DAV_DIR_SINGLE_INT (id, st, '', null, null, http_dav_uid ());
      if (DAV_HIDE_ERROR (diritm) is null)
        return diritm;
      return diritm [7];
    }
  if ('C' = st)
    return coalesce ((select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = id), -1);
  if ('R' = st)
    return coalesce ((select RES_OWNER from WS.WS.SYS_DAV_RES where RES_ID = id), -1);
  return -14;
}
;


create function
DAV_PREPARE_PROP_WRITE (
  in path varchar,
  out id any,
  out st varchar,
  in propname varchar,
  in auth_uname varchar,
  in auth_pwd varchar,
  inout auth_uid integer,
  in extern integer,
  out auto_version varchar,
  inout check_locks any,
  out locked integer) returns integer
{
  declare rc integer;
  if ((path <> '') and (path[length(path)-1] = 47))
    st := 'C';
  else
    st := 'R';
  id := DAV_SEARCH_ID (path, st);
  -- dbg_obj_princ ('DAV_PREPARE_PROP_WRITE found id ', id, ' of st ', st);
  if (DAV_HIDE_ERROR (id) is null)
    {
      return id;
    }
  if (extern)
    {
      auth_uid := DAV_AUTHENTICATE (id, st, '11_', auth_uname, auth_pwd);
      if (auth_uid >= 0)
        goto auth_uid_ok;
      if ((auth_uid = -13) and (propname = ':virtprivatetags'))
        { -- It's enough to have read permission to set a private tag.
          auth_uid := DAV_AUTHENTICATE (id, st, '1__', auth_uname, auth_pwd);
          if (auth_uid >= 0)
            goto auth_uid_ok;
        }
      if ((auth_uid = -13) and (propname in (':virtpermissions', ':virtowneruid', ':virtownergid', ':virtacl')))
        { -- It's enough to be valid user, the real check is to be done by DAV_PROP_SET_RAW
          auth_uid := DAV_AUTHENTICATE (id, st, '___', auth_uname, auth_pwd);
          if (auth_uid >= 0)
            goto auth_uid_ok;
        }
      return auth_uid;
    }
  else if (auth_uid is null)
    auth_uid := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = auth_uname), http_nobody_uid());

auth_uid_ok:
  auto_version := DAV_HIDE_ERROR (DB.DBA.DAV_PROP_GET_INT(DAV_SEARCH_ID (path, 'R'), 'R', 'DAV:auto-version', 0));
  if (check_locks)
    {
      rc := DAV_IS_LOCKED (id , st, check_locks);
      if (rc < 0)
        locked := 1;
      else
        locked := 0;
      if (rc = -8 and (auto_version = 'DAV:checkout-unlocked-checkin'))
        rc := 0;
      else if (rc = -8 and (auto_version = 'DAV:locked-checkout'))
        rc := 0;
      if (0 <> rc)
        return rc;
    }
  if (
    ((propname like 'xml-stylesheet%') or (propname like 'xml-sql%')) and
    ((auth_uid <> 0) and (auth_uid <> http_dav_uid())) )
    {
      set isolation='committed';
      if (not exists (
          select top 1 1 from DB.DBA.SYS_USERS
          where U_ID = auth_uid and U_DAV_ENABLE and U_SQL_ENABLE
            and not U_ACCOUNT_DISABLED ) )
        return -32;
      if (DAV_GET_OWNER (id, st) <> auth_uid)
        return -32;
    }
  return 0;
}
;


--!AWK PUBLIC
create procedure
DAV_PROP_SET (
    in path varchar,
    in propname varchar,
    in propvalue any,
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in overwrite integer := 0 )
{
  return DAV_PROP_SET_INT (path, propname, propvalue, auth_uname, auth_pwd, 1, 1, overwrite);
}
;

create function
DAV_PROP_SET_INT (
    in path varchar,
    in propname varchar,
    in propvalue any,
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in extern integer := 1,
    in check_locks any := 1,
    in overwrite integer := 0,
    in auth_uid integer := null ) returns integer
{
  declare id, rc, pid integer;
  declare st, det varchar;
  declare locked integer;
  declare auto_version varchar;
  -- dbg_obj_princ ('DAV_PROP_SET_INT (', path, propname, propvalue, auth_uname, auth_pwd, extern, check_locks, overwrite, auth_uid, ')');
  rc := DAV_PREPARE_PROP_WRITE (path, id, st, propname, auth_uname, auth_pwd, auth_uid, extern, auto_version, check_locks, locked);
  -- dbg_obj_princ ('DAV_PREPARE_PROP_WRITE returned ', rc);
  if (rc < 0)
    return rc;
  if (isarray (id))
    {
      pid := call (cast (id[0] as varchar) || '_DAV_PROP_SET') (id, st, propname, propvalue, overwrite, auth_uid);
      return pid;
    }
  return DAV_PROP_SET_RAW (id, st, propname, propvalue, overwrite, auth_uid, locked, auto_version);
}
;

create function
DAV_PROP_SET_RAW (
    inout id integer,
    in st char(0),
    inout propname varchar,
    inout propvalue any,
    in overwrite integer,
    in auth_uid integer,
    in locked int:=0,
    in auto_version varchar:=NULL
) returns integer
{
  declare rc, old_log_mode, new_log_mode any;
  old_log_mode := log_enable (null);
  -- we disable row auto commit since there are triggers reading blobs, we do that even in atomic mode since this is vital for dav uploads
  new_log_mode := bit_and (old_log_mode, 1);
  old_log_mode := log_enable (bit_or (new_log_mode, 4), 1);
  rc := DAV_PROP_SET_RAW_INNER (id, st, propname, propvalue, overwrite, auth_uid, locked, auto_version);
  log_enable (bit_or (old_log_mode, 4), 1);
  return rc;
}
;

create function
DAV_PROP_SET_RAW_INNER (
    inout id integer,
    in st char(0),
    inout propname varchar,
    inout propvalue any,
    in overwrite integer,
    in auth_uid integer,
    in locked int:=0,
    in auto_version varchar:=NULL
) returns integer
{
  declare pid integer;
  declare can_patch_access integer;
  if (58 = propname[0])
    { -- a special property, the first char is ':'
      if (':getlastmodified' = propname)
        {
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_MOD_TIME = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_MOD_TIME = propvalue where COL_ID = id;
          return 0;
        }
      if (':creationdate' = propname)
        {
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_CR_TIME = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_CR_TIME = propvalue where COL_ID = id;
          return 0;
        }
      if (':addeddate' = propname)
        {
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_ADD_TIME = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_ADD_TIME = propvalue where COL_ID = id;
          return 0;
        }
      if (':getcontenttype' = propname)
        {
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_TYPE = propvalue where RES_ID = id;
          else
            return -10;
          return 0;
        }
      if (auth_uid = http_dav_uid())
        can_patch_access := 2;
--      else if (auth_uid = 0)
--        can_patch_access := -1;
      else
        if ('R' = st)
          can_patch_access := coalesce ((select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = id and RES_OWNER = auth_uid), 0);
        else
          can_patch_access := coalesce ((select top 1 1 from WS.WS.SYS_DAV_COL where COL_ID = id and COL_OWNER = auth_uid), 0);
      if (':virtowneruid' = propname)
        {
          if (0 >= can_patch_access)
            return -13;
          if (not exists (select top 1 1 from WS.WS.SYS_DAV_USER where U_ID = propvalue))
            propvalue := 0;
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_OWNER = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_OWNER = propvalue where COL_ID = id;
          return 0;
        }
      if (':virtownergid' = propname)
        {
          if (0 >= can_patch_access)
            return -13;
          if (not exists (select top 1 1 from WS.WS.SYS_DAV_GROUP where G_ID = propvalue))
            propvalue := 0;
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_GROUP = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_GROUP = propvalue where COL_ID = id;
          return 0;
        }
      if (':virtpermissions' = propname)
        {
          if (0 >= can_patch_access)
            return -13;
          if ((propvalue like '__1%' or propvalue like '_____1%' or propvalue like '________1%') and auth_uid <> http_dav_uid ())
            return -10;
          if (regexp_match (DAV_REGEXP_PATTERN_FOR_PERM (), propvalue) is null)
            return -17;
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_PERMS = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_PERMS = propvalue where COL_ID = id;
          return 0;
        }
      if (':virtacl' = propname)
        {
          if (0 >= can_patch_access)
            return -13;
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_ACL = propvalue where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_ACL = propvalue where COL_ID = id;
          return 0;
        }
      if (':virtdet' = propname)
        {
          if (1 >= can_patch_access)
            return -13;
          if ('R' = st)
            return -10;
          else
            update WS.WS.SYS_DAV_COL set COL_DET = propvalue where COL_ID = id;
          return 0;
        }
      if (':virtdetmount' = propname)
        {
          if (1 >= can_patch_access)
            return -13;
          if ('R' = st)
            return -10;
          else
            update WS.WS.SYS_DAV_COL set COL_DET = propvalue where COL_ID = id;
          return 0;
        }
      if (':virtdetmountable' = propname)
        {
          return -10;
        }
      if (':virtprivatetags' = propname)
        {
          if ('R' <> st)
            return -14;
          if (auth_uid = http_nobody_uid())
            return -16;
          if (exists (select 1 from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = auth_uid))
            {
              if (not overwrite)
                return -16;
              update WS.WS.SYS_DAV_TAG set DT_TAGS = propvalue where DT_RES_ID = id and DT_U_ID = auth_uid;
            }
          else
            {
              insert into WS.WS.SYS_DAV_TAG (DT_RES_ID, DT_U_ID, DT_FT_ID, DT_TAGS)
              values (id, auth_uid, WS.WS.GETID ('T'), propvalue);
            }
          return 0;
        }
      if (':virtpublictags' = propname)
        {
          if ('R' <> st)
            return -14;
          if (exists (select 1 from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = http_nobody_uid()))
            {
              if (not overwrite)
                return -16;
              update WS.WS.SYS_DAV_TAG set DT_TAGS = propvalue where DT_RES_ID = id and DT_U_ID = http_nobody_uid();
            }
          else
            {
              insert into WS.WS.SYS_DAV_TAG (DT_RES_ID, DT_U_ID, DT_FT_ID, DT_TAGS)
              values (id, http_nobody_uid(), WS.WS.GETID ('T'), propvalue);
            }
          return 0;
        }
      return -16;
    }

  if ((not overwrite) and exists (select 1 from WS.WS.SYS_DAV_PROP where PROP_NAME = propname and PROP_PARENT_ID = id and PROP_TYPE = st))
    return -16;

  if (not isstring (propname) or (propname in ('creationdate', 'getcontentlength', 'getcontenttype', 'getetag', 'getlastmodified', 'lockdiscovery', 'resourcetype', 'activelock', 'supportedlock')))
    return -10;

  if (__tag (propvalue) = 193)
    propvalue := serialize (propvalue);
  else if (not isstring (propvalue))
    return -17;

  pid := WS.WS.GETID ('P');

  if ((propname not like 'DAV:%')
        and (propname not like 'virt:%')
        and (propname[0] <> 58)) -- first char <> ':'
    {
          if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (id, 'R', 'DAV:checked-in', 0)) is not null)
            {
                  -- dbg_obj_princ ('return -38 for ', propname, ',', propvalue);
                  return -38;
            }
          if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (id, 'R', 'DAV:checked-out', 0)) is not null)
            {
              if ((locked and (auto_version = 'DAV:checkout-unlocked-checkin')) or
                        (auto_version = 'DAV:checkout') or
                        (locked and (auto_version = 'DAV:locked-checkout')))
                {
                      declare _res int;
                      _res := DAV_CHECKOUT_INT (id, null, null, 0);
                      if (_res < 0)
                        return _res;
                    }
            }
    }
  update WS.WS.SYS_DAV_PROP set PROP_VALUE = propvalue where PROP_NAME = propname
      and PROP_PARENT_ID = id and PROP_TYPE = st;
  if (row_count() = 0)
    {
      insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
          values (pid, propname, propvalue, id, st);
    }
  return pid;
}
;

--!AWK PUBLIC
create procedure
DAV_PROP_REMOVE (
    in path varchar,
    in propname varchar,
    in auth_uname varchar := null,
    in auth_pwd varchar := null)
{
  return DAV_PROP_REMOVE_INT (path, propname, auth_uname, auth_pwd);
}
;

create function
DAV_PROP_REMOVE_INT (
    in path varchar,
    in propname varchar,
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in extern integer := 1,
    in check_locks any := 1,
    in ignore_if_missing integer := 0,
    in auth_uid integer := null ) returns integer
{
  declare id, rc, pid integer;
  declare st, det varchar;
  declare locked int;
  declare auto_version varchar;
  -- dbg_obj_princ ('DAV_PROP_REMOVE_INT (', path, propname, auth_uname, auth_pwd, extern, check_locks, ignore_if_missing, auth_uid, id, ')');
  rc := DAV_PREPARE_PROP_WRITE (path, id, st, propname, auth_uname, auth_pwd, auth_uid, extern, auto_version, check_locks, locked);
  -- dbg_obj_princ ('DAV_PREPARE_PROP_WRITE returned ', rc);
  if (rc < 0)
    return rc;
  if (isarray (id))
    {
      pid := call (cast (id[0] as varchar) || '_DAV_PROP_REMOVE') (id, st, propname, ignore_if_missing, auth_uid);
      return pid;
    }
  return DAV_PROP_REMOVE_RAW (id, st, propname, ignore_if_missing, auth_uid, locked, auto_version);
}
;


create function
DAV_PROP_REMOVE_RAW (
    inout id integer,
    in st char(0),
    inout propname varchar,
    in ignore_if_missing integer,
    in auth_uid integer,
    in locked int:=0,
    in auto_version varchar:=NULL
) returns integer
{
  declare pid integer;
  declare can_patch_access integer;
  if (58 = propname[0])
    { -- a special property, the first char is ':'
      if (propname in (':getlastmodified', ':creationdate', ':addeddate', ':getcontenttype', ':virtowneruid', ':virtownergid', ':virtpermissions', ':virtdetmountable', ':virtpubliclink'))
        return -10;
      if (auth_uid = http_dav_uid())
        can_patch_access := 2;
--      else if (auth_uid = 0)
--        can_patch_access := -1;
      else
        if ('R' = st)
          can_patch_access := coalesce ((select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = id and RES_OWNER = auth_uid), 0);
        else
          can_patch_access := coalesce ((select top 1 1 from WS.WS.SYS_DAV_COL where COL_ID = id and COL_OWNER = auth_uid), 0);
      if (':virtacl' = propname)
        {
          if (0 >= can_patch_access)
            return -13;
          if ('R' = st)
            update WS.WS.SYS_DAV_RES set RES_ACL = NULL where RES_ID = id;
          else
            update WS.WS.SYS_DAV_COL set COL_ACL = NULL where COL_ID = id;
          return 0;
        }
      if (':virtdet' = propname)
        {
          if (1 >= can_patch_access)
            return -13;
          if ('R' = st)
            return -10;
          else
            update WS.WS.SYS_DAV_COL set COL_DET = NULL where COL_ID = id;
          return 0;
        }
      if (':virtdetmount' = propname)
        {
          if (1 >= can_patch_access)
            return -13;
          if ('R' = st)
            return -10;
          else
            update WS.WS.SYS_DAV_COL set COL_DET = NULL where COL_ID = id;
          return 0;
        }
      if (':virtprivatetags' = propname)
        {
          if (('R' <> st) or (auth_uid = http_nobody_uid()) or (not exists (select 1 from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = auth_uid)))
            goto nosuchprop;
          delete from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = auth_uid;
          return 0;
        }
      if (':virtpublictags' = propname)
        {
          if (('R' <> st) or (not exists (select 1 from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = http_nobody_uid())))
            goto nosuchprop;
          delete from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = http_nobody_uid();
          return 0;
        }
      return -16;
    }

  if (not exists (select 1 from WS.WS.SYS_DAV_PROP where PROP_NAME = propname and PROP_PARENT_ID = id
        and PROP_TYPE = st))
    {
      goto nosuchprop;
    }
  delete from WS.WS.SYS_DAV_PROP where PROP_NAME = propname and PROP_PARENT_ID = id and PROP_TYPE = st;
  return 0;
nosuchprop:
  if (ignore_if_missing)
    return 0;
  else
    return -11;
}
;


--!AWK PUBLIC
create procedure
DAV_PROP_GET (
    in path varchar,
    in propname varchar,
    in auth_uname varchar := null,
    in auth_pwd varchar := null) returns any
{
  declare st varchar;
  if ((path <> '') and (path[length(path)-1] = 47))
    st := 'C';
  else
    st := 'R';
  return DAV_PROP_GET_INT (DAV_SEARCH_ID (path, st), st, propname, 1, auth_uname, auth_pwd);
}
;


create procedure
DAV_PROP_GET_INT (
    in id any,
    in what char(0),
    in propname varchar,
    in extern integer := 1,
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in auth_uid integer := null ) returns any
{
  declare rc integer;
  declare ret any;
  -- dbg_obj_princ ('DAV_PROP_GET_INT (', id, what, propname, extern, auth_uname, auth_pwd, auth_uid, ')');
  if (propname is null)
    return -11;
  if (not (isstring (propname)))
    propname := cast (propname as varchar);
  if ('' = propname)
    return -11;
  if (extern)
    {
      auth_uid := DAV_AUTHENTICATE (id, what, '1__', auth_uname, auth_pwd);
      if (auth_uid < 0)
        return auth_uid;
    }
  if (DAV_HIDE_ERROR (id) is null)
    return -1;
  if (propname[0] = 58)
    {
      declare idx integer;
      idx := get_keyword (propname,
        vector (
          ':getlastmodified', 3,
          ':creationdate', 8,
          ':lastaccessed', 3,
          ':addeddate', 10,
          ':getetag', -1,
          ':getcontenttype', 9,
          ':getcontentlength', 2,
          ':resourcetype', -1,
          ':virtowneruid', 7,
          ':virtownergid', 6,
          ':virtpermissions', 5,
          ':virtacl', -1,
          ':virtdet', -1,
          ':virtdetmount', -1,
          ':virtdetmountable', -1,
          ':virtpublictags', -1,
          ':virtprivatetags', -1,
          ':virttags', -1,
          ':virtpubliclink', -1 ) );
      if (idx is null)
        return -11;
      if (idx >= 0)
        {
          declare dirsingle any;
          dirsingle := DAV_DIR_SINGLE_INT (id, what, 'fake', auth_uname, auth_pwd, auth_uid, extern);
          if (isarray (dirsingle))
          {
            if ((propname = ':addeddate') and (length (dirsingle) <= 11))
              idx := 8;

            return dirsingle[idx];
          }
          return -1;
        }
      if (':getetag' = propname)
        {
          if ('R' = what)
            {
              if (isarray (id))
                {
                  declare dirsingle any;
                  declare path varchar;
                  path := DAV_SEARCH_PATH (id, 'R');
                  dirsingle := call (cast (id[0] as varchar) || '_DAV_DIR_SINGLE') (id, 'R', path, auth_uid);
                  return sprintf ('%s-%s-%d-%s', cast (id[1] as varchar), replace (cast (dirsingle[3] as varchar), ' ', 'T'), dirsingle[2], md5 (path));
                }
              else
                {
                  declare name varchar;
                  declare col_id integer;
		  declare modt any;
                  select RES_NAME, RES_COL, RES_MOD_TIME into name, col_id, modt from WS.WS.SYS_DAV_RES where RES_ID = id;
                  return WS.WS.ETAG (name, col_id, modt);
                }
            }
          else
            return null;
        }
      if (':resourcetype' = propname)
        {
          if (what = 'C')
            return xtree_doc ('<D:collection/>');
          else
            return null;
        }
      if (':virtacl' = propname)
        {
          if (isarray (id))
            {
              ret := call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
              if (isinteger (ret) and (ret = -20))
              return coalesce ((select COL_ACL from WS.WS.SYS_DAV_COL where COL_ID = id[1]));

              return ret;
            }
          else
            {
              if ('R' = what)
                return coalesce ((select RES_ACL from WS.WS.SYS_DAV_RES where RES_ID = id));
              else
                return coalesce ((select COL_ACL from WS.WS.SYS_DAV_COL where COL_ID = id));
            }
        }
      if (':virtdet' = propname)
        {
          if (isarray (id))
            {
              ret := call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
              return coalesce (DAV_HIDE_ERROR (ret), id[0]);
            }
          else
            {
              if ('R' = what)
                return null;
              else
                return coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = id));
            }
        }
      if (':virtdetmount' = propname)
        {
          if (isarray (id))
            {
              ret := call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
              return DAV_HIDE_ERROR (ret);
            }
          else
            {
              if ('R' = what)
                return null;
              else
                return coalesce ((select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = id));
            }
        }
      if (':virtdetmountable' = propname)
        {
          if (isarray (id))
            {
              ret := call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
              return DAV_HIDE_ERROR (ret);
            }
          else
            {
              if ('R' = what)
                return null;
              else
                return 'T';
            }
        }
      if (isarray (id))
        {
          ret := call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
          return ret;
        }
      if (':virtprivatetags' = propname)
        {
          if (('R' <> what) or (auth_uid = http_nobody_uid()))
            return null;
          return coalesce ((select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = auth_uid));
        }
      if (':virtpublictags' = propname)
        {
          if ('R' <> what)
            return null;
          return coalesce ((select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = http_nobody_uid()));
        }
      if (':virttags' = propname)
        {
          if ('R' <> what)
            return null;
          if (auth_uid = http_nobody_uid())
            {
              return coalesce ((select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = http_nobody_uid()));
            }
          else
            {
              declare pub, priv varchar;
              pub := coalesce ((select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = http_nobody_uid()), '');
              priv := coalesce ((select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_RES_ID = id and DT_U_ID = auth_uid), '');
              if (pub = '')
                return priv;
              if (priv = '')
                return pub;
              return pub || ', ' || priv;
            }
        }
      if (':virtpubliclink' = propname)
        {
          return WS.WS.DAV_HOST () || DAV_SEARCH_PATH (id, what);
        }
    }
  if (isarray (id))
    {
      ret := call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
      return ret;
    }
  if (id < 0)
    {
      return id;
    }
  whenever not found goto no_prop;
  select blob_to_string (PROP_VALUE) into ret from WS.WS.SYS_DAV_PROP where PROP_NAME = propname and PROP_PARENT_ID = id and PROP_TYPE = what;
  return ret;

no_prop:
    return -11;
}
;


--!AWK PUBLIC
create procedure
DAV_PROP_LIST (
    in path varchar,
    in propmask varchar,
    in auth_uname varchar := null,
    in auth_pwd varchar := null)
{
  declare st varchar;
  if ((path <> '') and (path[length(path)-1] = 47))
    st := 'C';
  else
    st := 'R';
  return DAV_PROP_LIST_INT (DAV_SEARCH_ID (path, st), st, propmask, 1, auth_uname, auth_pwd);
}
;

create procedure
DAV_PROP_LIST_INT (
    in id any,
    in what char(0),
    in propmask varchar,
    in extern integer := 1,
    in auth_uname varchar := null,
    in auth_pwd varchar := null)
{
  declare auth_uid, rc integer;
  declare ret any;
  -- dbg_obj_princ ('DAV_PROP_LIST_INT (', id, what, propmask, extern, auth_uname, auth_pwd, ')');
  if (extern)
    {
      auth_uid := DAV_AUTHENTICATE (id, what, '1__', auth_uname, auth_pwd);
      if (auth_uid < 0)
        return auth_uid;
    }
  -- rc := DAV_IS_LOCKED (id , what);
  --if (0 <> rc)
  --   return rc;
  if (isarray (id))
    {
      ret := call (cast (id[0] as varchar) || '_DAV_PROP_LIST') (id, what, propmask, auth_uid);
      return ret;
    }
  if (id < 0)
    {
      return id;
    }
  ret := vector ();
  for select PROP_NAME, PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME like propmask and PROP_PARENT_ID = id and PROP_TYPE = what do {
      ret := vector_concat (ret, vector (vector (PROP_NAME, blob_to_string (PROP_VALUE))));
    }
  return ret;
}
;


create procedure
DAV_MAKE_DIR (in path any, in own integer, in grp integer, in perms varchar)
{
  declare pat any;
  declare col, len, inx, t_col integer;

  pat := split_and_decode (path, 0, '\0\0/');

  if (length (pat) < 3)
    return NULL;

  if (pat[1] <> 'DAV' or pat[0] <> '')
    signal ('22023', 'Not valid path string');

  len := length (pat) - 1;
  inx := 2;
  t_col := 1;
  whenever not found goto nf;
  while (inx < len)
    {
      select COL_ID into col from WS.WS.SYS_DAV_COL where COL_PARENT = t_col and COL_NAME = pat[inx];
      t_col := col;
      inx := inx + 1;
    }
nf:
  while (inx < len)
    {
      col := WS.WS.GETID ('C');
      insert into WS.WS.SYS_DAV_COL
        (COL_ID, COL_NAME, COL_PARENT, COL_CR_TIME, COL_MOD_TIME, COL_OWNER, COL_GROUP, COL_PERMS)
        values (col, pat[inx], t_col, now (), now (), own, grp, perms);
      inx := inx + 1;
      t_col := col;
    }
  return col;
}
;

create procedure DAV_CHECK_PERM (in perm varchar, in req varchar, in oid integer,
                                 in ogid integer, in pgid integer, in puid integer)
{
  declare up, gp, pp varchar;
  -- dbg_obj_princ ('DAV_CHECK_PERM (', perm, req, oid, ogid, pgid, puid, ')');
  pp := substring (perm, 7, 3);
  if (pp like req)
    return 1;
  up := substring (perm, 1, 3);
  if (up like req and ((oid = puid) or (oid = 2)))
    return 1;
  gp := substring (perm, 4, 3);
  if (gp like req and ((ogid = pgid) or (exists (select top 1 1 from WS.WS.SYS_DAV_USER_GROUP where UG_UID = oid and UG_GID = pgid))))
    return 1;
  -- dbg_obj_princ ('DAV_CHECK_PERM (', perm, req, oid, ogid, pgid, puid, ') rejects!');
  return 0;
}
;


--!AWK PUBLIC
create procedure DAV_CHECK_USER (in uname varchar, in pwd any := null)
{
  declare rc int;
  declare pwd1 any;
  rc := 0;
  if (pwd is null)
    {
      rc := coalesce ((select 1 from WS.WS.SYS_DAV_USER where U_NAME = uname), 0);
    }
  else
    {
      whenever not found goto nf;
      select U_PWD into pwd1 from WS.WS.SYS_DAV_USER where U_NAME = uname with (prefetch 1);
      if ((pwd1[0] = 0 and pwd_magic_calc (uname, pwd) = pwd1) or (pwd1[0] <> 0 and pwd1 = pwd))
        rc := 1;
      nf:;
    }
  return rc;
}
;


--!AWK PUBLIC
create procedure DAV_RES_CONTENT (
    in path varchar,
    inout content any,
    out type varchar,
  in auth_uname varchar := null,
  in auth_pwd varchar := null)
{
  declare id any;

  id := DAV_SEARCH_ID (path, 'R');
  if ((DAV_HIDE_ERROR (id) is null) and (path like '%,meta'))
  {
    return DAV_RES_CONTENT_META (path, content, type, 0, 1, auth_uname, auth_pwd);
  }
  return DAV_RES_CONTENT_INT (id, content, type, 0, 1, auth_uname, auth_pwd);
}
;


--!AWK PUBLIC
create procedure DAV_RES_CONTENT_STRSES (
    in path varchar,
    inout content any,
    out type varchar,
  in auth_uname varchar := null,
  in auth_pwd varchar := null)
{
  declare id any;

  id := DAV_SEARCH_ID (path, 'R');
  if ((DAV_HIDE_ERROR (id) is null) and (path like '%,meta'))
  {
    return DAV_RES_CONTENT_META (path, content, type, 1, 1, auth_uname, auth_pwd);
  }
  return DAV_RES_CONTENT_INT (id, content, type, 1, 1, auth_uname, auth_pwd);
}
;

create procedure DAV_RES_CONTENT_INT (
    in id any,
    inout content any,
    out type varchar,
    in content_mode integer, -- 0 for set output to a string or blob, 1 for writing to content as to session, 2 for set output to whatever including XML, 3 for writing to http.
    in extern integer := 1,
    in auth_uname varchar := null,
    in auth_pwd varchar := null )
{
  declare rc, auth_uid integer;
  declare _value, _password any;
  declare cont any;
  -- dbg_obj_princ ('DAV_RES_CONTENT_INT (', id, ', [content], [type], ', content_mode, extern, auth_uname, auth_pwd, ')');
  if (extern)
  {
    auth_uid := DAV_AUTHENTICATE (id, 'R', '1__', auth_uname, auth_pwd);
    if (auth_uid < 0)
      return auth_uid;
  }
  else
  {
    auth_uid := null;
  }
  if (DAV_HIDE_ERROR (id) is null)
    return id;

  if (isarray (id))
  {
    return call (cast (id[0] as varchar) || '_DAV_RES_CONTENT') (id, content, type, content_mode);
  }

  rc := id;
  select RES_CONTENT, RES_TYPE into cont, type from WS.WS.SYS_DAV_RES where RES_ID = id;
  if ((content_mode = 0) or (content_mode = 2))
  {
    content := cont;
  }
  else if (content_mode = 1)
  {
    if (cont is not null)
      http (cont, content);
  }
  else if (content_mode = 3)
  {
    http (cont);
  }
  return rc;
}
;

create procedure DAV_RES_CONTENT_META (
  in path varchar,
  inout content any,
  out type varchar,
  in content_mode integer,
  in extern integer := 1,
  in auth_uname varchar := null,
  in auth_pwd varchar := null )
{
  -- dbg_obj_princ ('DAV_RES_CONTENT_META (', path, ', [content], [type], ', content_mode, extern, auth_uname, auth_pwd, ')');
  declare rc, auth_uid integer;
  declare id, cont any;

  if (path like '%,meta')
    path := subseq (path, 0, length (path) - length (',meta'));

  id := DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (id) is null)
    return id;

  if (extern)
  {
    auth_uid := DAV_AUTHENTICATE (id, 'R', '1__', auth_uname, auth_pwd);
    if (auth_uid < 0)
      return auth_uid;
  }
  else
  {
    auth_uid := null;
  }

  rc := id;
  cont := DAV_RES_CONTENT_META_N3 (path);
  if (DAV_HIDE_ERROR (cont) is null)
    return cont;

  if ((content_mode = 0) or (content_mode = 2))
  {
    content := cont;
  }
  else if (content_mode = 1)
  {
    if (cont is not null)
      http (cont, content);
  }
  else if (content_mode = 3)
  {
    http (cont);
  }
  return rc;
}
;

create procedure DAV_RES_CONTENT_META_N3 (
  in path varchar)
{
  declare item any;
  declare iri, creator_iri varchar;
  declare stream, dict, triples any;

  if (__proc_exists ('SIOC.DBA.get_graph') is null)
    return -1;

  dict := dict_new();
  item := DAV_DIR_LIST_INT (path, -1, '%', null, null, http_dav_uid ());
  if (DAV_HIDE_ERROR (item) is null)
    return -1;

  item := item[0];
  iri := iri_to_id (WS.WS.DAV_HOST () || path);

  -- creator
  creator_iri := SIOC..user_iri (item[7]);
	dict_put (dict, vector (iri, iri_to_id (SIOC..sioc_iri ('has_creator')), iri_to_id (creator_iri)), 0);
	dict_put (dict, vector (iri_to_id (creator_iri), iri_to_id (SIOC..sioc_iri ('creator_of')), iri), 0);
  dict_put (dict, vector (iri, SIOC..foaf_iri ('maker'), SIOC..person_iri (creator_iri)), 0);
  dict_put (dict, vector (iri_to_id (SIOC..person_iri (creator_iri)), SIOC..foaf_iri ('made'), iri), 0);

  -- name
  dict_put (dict, vector (iri, iri_to_id (SIOC..dc_iri ('title')), item[10]), 0);
  dict_put (dict, vector (iri, iri_to_id (SIOC..rdfs_iri ('label')), item[10]), 0);

  -- created
  dict_put (dict, vector (iri, iri_to_id (SIOC..dcterms_iri ('created')), item[8]), 0);

  -- modified
  dict_put (dict, vector (iri, iri_to_id (SIOC..dcterms_iri ('modified')), item[3]), 0);

  -- content type
  dict_put (dict, vector (iri, iri_to_id (SIOC..dc_iri ('format')), item[9]), 0);

  stream := string_output ();
 	triples := dict_list_keys (dict, 0);
  if (length (triples))
	  DB.DBA.RDF_TRIPLES_TO_NICE_TTL (triples, stream);

  return string_output_string (stream);
}
;

create function DAV_RES_LENGTH (
  in _content any,
  in _size integer)
{
  return case when (not isnull (_size)) then _size else length (_content) end;
}
;

create function DAV_COL_IS_ANCESTOR_OF (in a_id integer, in d_id integer) returns integer
{
  declare p_id integer;
  if (a_id = 0)
    return 1;
again:
-- The last '<' prevents from infinite loop in case of dead structure of the tree of collections.
  select COL_PARENT into p_id from WS.WS.SYS_DAV_COL where COL_ID = d_id and COL_PARENT < COL_ID;
  if (p_id = a_id)
    return 1;
  if (p_id = 0)
    return 0;
  d_id := p_id;
  goto again;
}
;

create function DAV_COL_PATH_BOUNDARY (in path varchar) returns varchar
{
  declare res varchar;
  declare len integer;
  res := path;
  len := length (res);
  if ((len = 0) or (res[len-1] <> 47))
    signal ('.....', sprintf ('Bad path in DAV_COL_PATH_BOUNDARY: %s', path));
  res := res || '\377\377\377\377';
  return res;
}
;

-- LDI triggers
--
create trigger SYS_DAV_RES_LDI_AI after insert on WS.WS.SYS_DAV_RES order 110 referencing new as N
{
  -- insert RDF data
  RDF_SINK_INSERT (N.RES_FULL_PATH, N.RES_ID, N.RES_COL, N.RES_TYPE, N.RES_OWNER, N.RES_GROUP);
}
;

create trigger SYS_DAV_RES_LDI_AU after update (RES_FULL_PATH, RES_ID, RES_COL, RES_TYPE, RES_OWNER, RES_GROUP) on WS.WS.SYS_DAV_RES order 110 referencing new as N, old as O
{
  declare c_id, _parent_co_id, depth integer;
  declare _inherit, rdf_graph varchar;
  declare rdf_params any;

  -- delete RDF data from separate (file) graph (if exists)
  RDF_SINK_DELETE (O.RES_FULL_PATH, O.RES_ID, O.RES_COL);

  -- insert RDF data
  RDF_SINK_INSERT (N.RES_FULL_PATH, N.RES_ID, N.RES_COL, N.RES_TYPE, N.RES_OWNER, N.RES_GROUP);
}
;

create trigger SYS_DAV_RES_LDI_AD after delete on WS.WS.SYS_DAV_RES order 110 referencing old as O
{
  -- delete RDF data from separate (file) graph (if exists)
  RDF_SINK_DELETE (O.RES_FULL_PATH, O.RES_ID, O.RES_COL);
}
;

-- Web Access Control
--
create trigger SYS_DAV_COL_WAC_U after update (COL_NAME, COL_PARENT) on WS.WS.SYS_DAV_COL order 100 referencing new as N, old as O
{
  declare aciContent, oldPath, newPath, update_acl any;

  if (connection_get ('dav_acl_sync') = 1)
    return;

  aciContent := (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = N.COL_ID and PROP_TYPE = 'C' and PROP_NAME = 'virt:aci_meta_n3');
  if (aciContent is null)
    return;

  oldPath := WS.WS.COL_PATH (O.COL_PARENT) || O.COL_NAME || '/';
  newPath := WS.WS.COL_PATH (N.COL_PARENT) || N.COL_NAME || '/';
  update_acl := 1;

  WS.WS.WAC_DELETE (oldPath, update_acl);
  WS.WS.WAC_INSERT (newPath, aciContent, N.COL_OWNER, N.COL_GROUP, update_acl);
}
;

create trigger SYS_DAV_COL_WAC_D after delete on WS.WS.SYS_DAV_COL order 100 referencing old as O
{
  declare update_acl integer;
  declare path varchar;

  if (connection_get ('dav_acl_sync') = 1)
    return;

  path := WS.WS.COL_PATH (O.COL_ID);
  update_acl := 1;

  WS.WS.WAC_DELETE (path, update_acl);
}
;

create trigger SYS_DAV_RES_WAC_I after insert on WS.WS.SYS_DAV_RES order 100 referencing new as N
{
  declare aciContent, oldPath, newPath, update_acl any;

  if (connection_get ('dav_acl_sync') = 1)
    return;

  if (N.RES_NAME like '%,acl')
  {
    declare rid int;
    newPath := WS.WS.COL_PATH (N.RES_COL) || N.RES_NAME;
    newPath := regexp_replace (newPath, ',acl\x24', '');
    aciContent := N.RES_CONTENT;
    rid := (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = newPath);
    set triggers off;
    insert into WS.WS.SYS_DAV_PROP (PROP_ID, PROP_PARENT_ID, PROP_NAME, PROP_TYPE, PROP_VALUE)
	values (WS.WS.GETID ('P'), rid, 'virt:aci_meta_n3', 'R', N.RES_CONTENT);
    set triggers on;
    update_acl := 0;
    WS.WS.WAC_INSERT (newPath, aciContent, N.RES_OWNER, N.RES_GROUP, update_acl);
  }
}
;

create trigger SYS_DAV_RES_WAC_U after update on WS.WS.SYS_DAV_RES order 100 referencing new as N, old as O
{
  declare aciContent, oldPath, newPath, update_acl any;

  if (connection_get ('dav_acl_sync') = 1)
    return;

  if (N.RES_NAME like '%,acl')
  {
    declare rid int;
    oldPath := WS.WS.COL_PATH (O.RES_COL) || O.RES_NAME;
    newPath := WS.WS.COL_PATH (N.RES_COL) || N.RES_NAME;
    oldPath := regexp_replace (oldPath, ',acl\x24', '');
    newPath := regexp_replace (newPath, ',acl\x24', '');
    aciContent := N.RES_CONTENT;
    rid := (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = oldPath);
    set triggers off;
    update WS.WS.SYS_DAV_PROP set PROP_VALUE = N.RES_CONTENT where PROP_TYPE = 'R' and PROP_NAME = 'virt:aci_meta_n3' and PROP_PARENT_ID = rid;
    set triggers on;
    update_acl := 0;
  }
  else
  {
    if ((O.RES_NAME = N.RES_NAME) and (O.RES_COL = N.RES_COL))
	    return;

    aciContent := (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = N.RES_ID and PROP_TYPE = 'R' and PROP_NAME = 'virt:aci_meta_n3');
    if (aciContent is null)
	    return;

    oldPath := WS.WS.COL_PATH (O.RES_COL) || O.RES_NAME;
    newPath := WS.WS.COL_PATH (N.RES_COL) || N.RES_NAME;
    update_acl := 1;
  }
  WS.WS.WAC_DELETE (oldPath, update_acl);
  WS.WS.WAC_INSERT (newPath, aciContent, N.RES_OWNER, N.RES_GROUP, update_acl);
}
;

create trigger SYS_DAV_RES_WAC_D after delete on WS.WS.SYS_DAV_RES order 100 referencing old as O
{
  declare update_acl int;
  declare path varchar;

  if (connection_get ('dav_acl_sync') = 1)
    return;

  if (O.RES_NAME like '%,acl')
  {
    update_acl := 0;
    path := regexp_replace (O.RES_FULL_PATH, ',acl\x24', '');
  }
  else
  {
    path := O.RES_FULL_PATH;
    update_acl := 1;
  }
  WS.WS.WAC_DELETE (path, update_acl);
}
;

create trigger SYS_DAV_PROP_WAC_I after insert on WS.WS.SYS_DAV_PROP order 100 referencing new as N
{
  if (N.PROP_NAME = 'virt:aci_meta_n3')
    WS.WS.WAC_INSERT_PROP (N.PROP_PARENT_ID, N.PROP_TYPE, N.PROP_VALUE);
}
;

create trigger SYS_DAV_PROP_WAC_U after update (PROP_NAME, PROP_VALUE) on WS.WS.SYS_DAV_PROP order 100 referencing new as N, old as O
{
  if (N.PROP_NAME = 'virt:aci_meta_n3')
  {
    declare _path any;

    _path := DB.DBA.DAV_SEARCH_PATH (O.PROP_PARENT_ID, O.PROP_TYPE);
    if (DAV_HIDE_ERROR (_path) is not null)
      WS.WS.WAC_DELETE (_path, 1);

    WS.WS.WAC_INSERT_PROP (N.PROP_PARENT_ID, N.PROP_TYPE, N.PROP_VALUE);
  }
}
;

create trigger SYS_DAV_PROP_WAC_D after delete on WS.WS.SYS_DAV_PROP order 100 referencing old as O
{
  if (O.PROP_NAME = 'virt:aci_meta_n3')
  {
    declare _path any;

    _path := DB.DBA.DAV_SEARCH_PATH (O.PROP_PARENT_ID, O.PROP_TYPE);
    if (DAV_HIDE_ERROR (_path) is not null)
      WS.WS.WAC_DELETE (_path, 1);
  }
}
;

create procedure WS.WS.WAC_INSERT_PROP (
  in id any,
  in what char(1),
  in prop_value any)
{
  declare _path, _owner, _group any;
  declare exit handler for not found { return; };

  if (what = 'R')
  {
    select RES_FULL_PATH, RES_OWNER, RES_GROUP
      into _path, _owner, _group
      from WS.WS.SYS_DAV_RES
     where RES_ID = id;
  }
  else
  {
    select DAV_SEARCH_PATH (COL_ID, what), COL_OWNER, COL_GROUP
      into _path, _owner, _group
      from WS.WS.SYS_DAV_COL
     where COL_ID = id;
  }
  WS.WS.WAC_INSERT (_path, prop_value, _owner, _group, 1);
}
;

create procedure WS.WS.WAC_INSERT (
  in path varchar,
  in aciContent any,
  in uid integer,
  in gid integer,
  in update_acl integer)
{
  -- dbg_obj_print ('WAC_INSERT', path);
  declare what, graph, permissions varchar;
  declare giid, subj, nsubj any;

  graph := WS.WS.WAC_GRAPH (path);
  aciContent := cast (blob_to_string (aciContent) as varchar);
  what := case when (path[length (path)-1] <> ascii('/')) then 'R' else 'C' end;
  permissions := DB.DBA.DAV_PROP_GET_INT (DB.DBA.DAV_SEARCH_ID (path, what), what, ':virtpermissions', 0, null, null, http_dav_uid ());
  if (update_acl)
  {
    connection_set ('dav_acl_sync', 1);
    DAV_RES_UPLOAD_STRSES_INT (rtrim (path, '/') || ',acl', aciContent, 'text/turtle', permissions, uid, gid, null, null, 0);
    connection_set ('dav_acl_sync', null);
  }
  giid := iri_to_id (graph);
  subj := iri_to_id (WS.WS.DAV_LINK (path));
  DB.DBA.TTLP (aciContent, graph, graph);
  sparql insert into graph ?:giid { ?s ?p ?:giid } where { graph ?:giid { ?s ?p ?:subj  }};
  if (exists (sparql prefix foaf: <http://xmlns.com/foaf/0.1/>  prefix acl: <http://www.w3.org/ns/auth/acl#> ask where { graph ?:giid { [] acl:accessTo ?:giid ; acl:mode acl:Read  ; acl:agentClass foaf:Agent . }})) -- public read
    {
      set triggers off;
      permissions [6] := 49;
      DAV_PROP_SET_INT (path, ':virtpermissions', permissions, null, null, 0, 0, 1, http_dav_uid ());
      set triggers on;
    }
}
;

create procedure WS.WS.WAC_DELETE (
  in path varchar,
  in update_acl integer)
{
  -- dbg_obj_print ('WAC_DELETE', path);
  declare graph, st, msg varchar;

  graph := WS.WS.WAC_GRAPH (path);
  if (update_acl)
  {
    connection_set ('dav_acl_sync', 1);
    DAV_DELETE_INT (rtrim (path, '/') || ',acl', 1, null, null, 0, 0);
    connection_set ('dav_acl_sync', null);
  }
  set_user_id ('dba');
  for (select a.G as GG, a.S as SS
         from DB.DBA.RDF_QUAD a
        where	a.G = __i2idn (graph)
          and	a.P = __i2idn ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
          and	a.O = __i2idn ('http://www.w3.org/ns/auth/acl#Authorization')) do
	{
	  delete from DB.DBA.RDF_QUAD where G = GG and (S = SS or O = SS);
	}
  for (select a.G as GG, a.S as SS
         from DB.DBA.RDF_QUAD a
        where	a.G = __i2idn (graph)
          and a.P = __i2idn ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
          and a.O = __i2idn ('http://www.openlinksw.com/schemas/acl/filter#Filter')) do
	{
	  delete from DB.DBA.RDF_QUAD where G = GG and (S = SS or O = SS);
	}
  for (select a.G as GG, a.S as SS
         from DB.DBA.RDF_QUAD a
        where	a.G = __i2idn (graph)
          and a.P = __i2idn ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
          and a.O = __i2idn ('http://www.openlinksw.com/schemas/acl/filter#Criteria')) do
	{
	  delete from DB.DBA.RDF_QUAD where G = GG and (S = SS or O = SS);
	}
}
;

create procedure WS.WS.WAC_GRAPH (
  in path varchar,
  in suffix varchar := '')
{
  return rtrim (WS.WS.DAV_IRI (path), '/') || '/' || suffix;
}
;


create procedure WS.WS.DAV_HOST ()
{
  declare host any;

  host := virtuoso_ini_item_value ('URIQA', 'DefaultHost');
  if (host is null)
  {
    host := sys_stat ('st_host_name');
    if (server_http_port () <> '80')
      host := host ||':'|| server_http_port ();
  }
  return sprintf ('http://%s', host);
}
;

create procedure WS.WS.DAV_IRI (
  in path varchar)
{
  declare S any;

  S := string_output ();
  http_dav_url (path, null, S);
  S := string_output_string (S);

  return WS.WS.DAV_HOST () || S;
}
;

-- ACL - WebDAV Collection
create trigger SYS_DAV_COL_ACL_I after insert on WS.WS.SYS_DAV_COL order 9 referencing new as NC
{
  declare N, colID, parentID integer;
  declare aAcl, aParentAcl any;

  -- dbg_obj_princ ('trigger SYS_DAV_COL_ACL_I (', NC.COL_ID, ')');
  aAcl := WS.WS.ACL_PARSE (NC.COL_ACL, '01', 0);
  foreach (any acl in aAcl) do
  {
    insert replacing WS.WS.SYS_DAV_ACL_INVERSE (AI_FLAG, AI_PARENT_ID, AI_PARENT_TYPE, AI_GRANTEE_ID)
      values (either(equ(acl[1],0), 'R', 'G'), NC.COL_ID, 'C', acl[0]);
  }

  aParentAcl := (select WS.WS.ACL_PARSE (COL_ACL, '123', 0) from WS.WS.SYS_DAV_COL c where c.COL_ID = NC.COL_PARENT);
  if (isnull(aParentAcl))
    return;

  aAcl := WS.WS.ACL_PARSE (NC.COL_ACL, '012', 0);
  set triggers off;
  update WS.WS.SYS_DAV_COL
     set COL_ACL = WS.WS.ACL_COMPOSE (vector_concat (aAcl, WS.WS.ACL_MAKE_INHERITED(aParentAcl)))
   where COL_ID = NC.COL_ID;
  -- dbg_obj_princ ('trigger SYS_DAV_COL_ACL_I (', NC.COL_ID, ') done');
}
;

create function WS.WS.ACL_CONTAINS_GRANTEE_AND_FLAG (inout aAcl any, in grantee integer, in flag char(1)) returns integer
{
  foreach (any acl in aAcl) do
  {
    if ((grantee = acl[0]) and (flag = either(equ(acl[1],0), 'R', 'G')))
      return 1;
  }
  return 0;
}
;

create trigger SYS_DAV_COL_ACL_U after update (COL_ACL) on WS.WS.SYS_DAV_COL order 9 referencing new as N, old as O
{
  declare aAcl, aLog any;
  -- dbg_obj_princ (now(), 'trigger SYS_DAV_COL_ACL_U (', N.COL_ID, ')');

  aAcl := WS.WS.ACL_PARSE (O.COL_ACL, '01', 0);
  delete
    from WS.WS.SYS_DAV_ACL_INVERSE
   where AI_PARENT_ID = O.COL_ID
     and AI_PARENT_TYPE = 'C'
     and not WS.WS.ACL_CONTAINS_GRANTEE_AND_FLAG (aAcl, AI_GRANTEE_ID, AI_FLAG);

  aAcl := WS.WS.ACL_PARSE (N.COL_ACL, '01', 0);
  foreach (any acl in aAcl) do
  {
    insert replacing WS.WS.SYS_DAV_ACL_INVERSE (AI_FLAG, AI_PARENT_ID, AI_PARENT_TYPE, AI_GRANTEE_ID)
      values (either (equ (acl[1], 0), 'R', 'G'), N.COL_ID, 'C', acl[0]);
  }

  declare exit handler for sqlstate '*'
  {
    log_enable (aLog, 1);
    resignal;
  };

  set triggers off;

  aLog := log_enable (0, 1);
  WS.WS.ACL_UPDATE (N.COL_ID, WS.WS.ACL_PARSE (N.COL_ACL, '123', 0));
  log_enable (aLog, 1);
  log_text ('WS.WS.ACL_UPDATE (?, ?)', N.COL_ID, WS.WS.ACL_PARSE (N.COL_ACL, '123', 0));
}
;

create trigger SYS_DAV_COL_ACL_D after delete on WS.WS.SYS_DAV_COL order 9 referencing old as O
{
  -- dbg_obj_princ ('trigger SYS_DAV_COL_ACL_D (', O.COL_ID, ')');
  delete
    from WS.WS.SYS_DAV_ACL_INVERSE
   where AI_PARENT_TYPE = 'C'
     and AI_PARENT_ID = O.COL_ID;
  -- dbg_obj_princ ('trigger SYS_DAV_COL_ACL_D (', O.COL_ID, ') done');
}
;

-- ACL - WebDAV Resource
--
create trigger SYS_DAV_RES_ACL_I after insert on WS.WS.SYS_DAV_RES order 9 referencing new as N
{
  declare aAcl any;
  declare aParentAcl varbinary;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_ACL_I (', N.RES_ID, ')');

  aAcl := WS.WS.ACL_PARSE (N.RES_ACL, '0', 0);
  foreach (any acl in aAcl) do
  {
    insert replacing WS.WS.SYS_DAV_ACL_INVERSE (AI_FLAG, AI_PARENT_ID, AI_PARENT_TYPE, AI_GRANTEE_ID)
      values (either(equ(acl[1],0), 'R', 'G'), N.RES_ID, 'R', acl[0]);
  }

  aParentAcl := (select WS.WS.ACL_PARSE (COL_ACL, '123', 0) from WS.WS.SYS_DAV_COL where COL_ID = N.RES_COL);
  if (not isnull(aParentAcl))
  {
    set triggers off;
    update WS.WS.SYS_DAV_RES
       set RES_ACL = WS.WS.ACL_COMPOSE (vector_concat(aAcl, WS.WS.ACL_MAKE_INHERITED(aParentAcl)))
     where RES_ID = N.RES_ID;
  }
  -- dbg_obj_princ ('trigger SYS_DAV_RES_ACL_I (', N.RES_ID, ') done');
}
;

create trigger SYS_DAV_RES_ACL_U after update (RES_ACL) on WS.WS.SYS_DAV_RES order 9 referencing new as N, old as O
{
  declare aAcl any;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_ACL_U (', N.RES_ID, ')');

  aAcl := WS.WS.ACL_PARSE (O.RES_ACL, '0', 0);
  delete
    from WS.WS.SYS_DAV_ACL_INVERSE
   where AI_PARENT_ID = O.RES_ID
     and AI_PARENT_TYPE = 'R'
     and not WS.WS.ACL_CONTAINS_GRANTEE_AND_FLAG (aAcl, AI_GRANTEE_ID, AI_FLAG);

  aAcl := WS.WS.ACL_PARSE (N.RES_ACL, '0', 0);
  foreach (any acl in aAcl) do
  {
    insert replacing WS.WS.SYS_DAV_ACL_INVERSE (AI_FLAG, AI_PARENT_ID, AI_PARENT_TYPE, AI_GRANTEE_ID)
      values (either (equ (acl[1],0), 'R', 'G'), N.RES_ID, 'R', acl[0]);
  }
  -- dbg_obj_princ ('trigger SYS_DAV_RES_ACL_U (', N.RES_ID, ') done');
}
;

create trigger SYS_DAV_RES_ACL_D after delete on WS.WS.SYS_DAV_RES order 9 referencing old as O
{
  -- dbg_obj_princ ('trigger SYS_DAV_RES_ACL_D (', O.RES_ID, ')');
  delete
    from WS.WS.SYS_DAV_ACL_INVERSE
   where AI_PARENT_TYPE = 'R'
     and AI_PARENT_ID = O.RES_ID;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_ACL_D (', O.RES_ID, ') done');
}
;

create procedure WS.WS.ACL_UPDATE (in id integer, in parentAcl any)
{
  declare nAcl any;
  -- dbg_obj_princ ('procedure WS.WS.ACL_UPDATE (', id, ')');

  WS.WS.ACL_MAKE_INHERITED (parentAcl);
  for select RES_ID as resID, RES_ACL as aAcl from WS.WS.SYS_DAV_RES where RES_COL = id do
  {
    nAcl := WS.WS.ACL_COMPOSE (vector_concat (WS.WS.ACL_PARSE (aAcl, '0', 0), parentAcl));
    if (not ((nAcl = aAcl) or (isnull (nAcl) and isnull (aAcl))))
    {
      update WS.WS.SYS_DAV_RES
         set RES_ACL = nAcl
       where RES_ID = resID;
    }
  }
  for select COL_ID as colID, COL_ACL as aAcl from WS.WS.SYS_DAV_COL where COL_PARENT = id do
  {
    nAcl := WS.WS.ACL_COMPOSE (vector_concat (WS.WS.ACL_PARSE (aAcl, '012', 0), parentAcl));
    if (not ((nAcl = aAcl) or (isnull (nAcl) and isnull (aAcl))))
    {
      update WS.WS.SYS_DAV_COL
         set COL_ACL = nAcl
       where COL_ID = colID;
      WS.WS.ACL_UPDATE(colID, WS.WS.ACL_PARSE (nAcl, '123', 0));
    }
  }
}
;

create procedure WS.WS.ACL_MAKE_INHERITED (
  inout aAcl any)
{
  declare tmp any;
  declare N integer;

  for (N := 0; N < length (aAcl); N := N + 1)
  {
    tmp := aAcl[N];
    aset (tmp, 2, 3);
    aset (aAcl, N, tmp);
  }
  return aAcl;
}
;


create procedure WS.WS.ACL_DBG (
  in vb varbinary) returns varchar
{
  declare N integer;
  declare aResult varchar;

  aResult := '';
  vb := cast(vb as varchar);
  for (N := 0; N < length (vb); N := N + 1)
  {
    aResult := aResult || cast (vb[N] as varchar) || ', ';
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure WS.WS.ACL_SERIALIZE_INT (
  in I integer) returns varbinary
{
  declare N integer;
  declare retValue varchar;

  retValue := repeat ('\0', 4);

  N := bit_shift (I,-24);
  if (N)
    retValue[0] := N;

  N := bit_shift (bit_shift (I, 8),-24);
  if (N)
    retValue[1] := N;

  N := bit_shift(bit_shift (I,16),-24);
  if (N)
    retValue[2] := N;

  N := bit_shift(bit_shift (I, 24),-24);
  if (N)
    retValue[3] := N;

  return cast (retValue as varbinary);
}
;

-------------------------------------------------------------------------------
--
create procedure WS.WS.ACL_DESERIALIZE_INT (
  in _value any) returns integer
{
  if (__tag (_value) <> 189)
    _value := cast (_value as varchar);

  _value := right (repeat ('\0', 4) || _value, 4);
  return bit_or (bit_or (bit_or (bit_shift (_value[0], 24), bit_shift (_value[1], 16)), bit_shift (_value[2], 8)), _value[3]);
}
;

-------------------------------------------------------------------------------
--
create procedure WS.WS.ACL_GET_ACLLENGTH(in acl varbinary) returns integer
{
  return WS.WS.ACL_DESERIALIZE_INT (cast (substring( cast (acl as varchar), 1, 4) as varbinary));
}
;

-------------------------------------------------------------------------------
--
create procedure WS.WS.ACL_GET_ACESIZE(in acl varbinary) returns integer
{
  return WS.WS.ACL_DESERIALIZE_INT (cast (substring (cast (acl as varchar), 5, 4) as varbinary));
}
;

-------------------------------------------------------------------------------
--
-- Create new ACL object with only owner user
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_CREATE() returns varbinary
{
  return cast(concat(cast (WS.WS.ACL_SERIALIZE_INT (8) as varchar),
                     cast (WS.WS.ACL_SERIALIZE_INT (0) as varchar)) as varbinary);
}
;

-------------------------------------------------------------------------------
--
-- True if the ACL is syntactically valid.
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_IS_VALID (in acl varbinary) returns integer
{
  declare iAclLength, iAceSize integer;

  -- dbg_obj_princ ('WS.WS.ACL_IS_VALID (', sprintf('%U', cast (acl as varchar)), ')');
  if (internal_type_name(internal_type(acl)) <> 'VARBINARY')
    {
      -- dbg_obj_princ ('Failed ACL_IS_VALID: internal_type_name(internal_type(acl)) is ', internal_type_name(internal_type(acl)));
      return 0;
    }

  iAclLength := WS.WS.ACL_GET_ACLLENGTH(acl);
  if (iAclLength <> length(acl))
    {
      -- dbg_obj_princ ('Failed ACL_IS_VALID: WS.WS.ACL_GET_ACLLENGTH(acl) is ', iAclLength, ' length(acl) is ', length(acl));
      return 0;
    }

  iAceSize := WS.WS.ACL_GET_ACESIZE(acl);
  if ((iAceSize*8 + 8) <> length(acl))
    {
      -- dbg_obj_princ ('Failed ACL_IS_VALID: WS.WS.ACL_GET_ACESIZE(acl) is ', iAceSize, ' length(acl) is ', length(acl));
      return 0;
    }

  return 1;
}
;

-------------------------------------------------------------------------------
--
-- Adds a grant/revoke entry for a principal to an ACL.
-- Replaces a previously existing entry if the bits and uid are the same.
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_ADD_ENTRY(inout acl varbinary, in uid integer, in bitmask integer, in is_grant integer, in inheritance integer := 0) returns varbinary
{
  declare N, bFound integer;
  declare aAcl any;

  aAcl := WS.WS.ACL_PARSE (acl);

  bFound := 0;
  for (N := 0; N < length (aAcl); N := N + 1)
  {
    if ((aAcl[N][0] = uid) and (aAcl[N][2] = inheritance))
    {
      if (aAcl[N][1] = is_grant)
      {
        aset (aAcl, N, vector (aAcl[N][0], aAcl[N][1], aAcl[N][2], bitmask));
        bFound := 1;
      }
      else
      {
        aset (aAcl, N, vector (aAcl[N][0], aAcl[N][1], aAcl[N][2], bit_and(aAcl[N][3], bit_not(bitmask))));
      }
    }
  }

  if (not bFound)
    aAcl := vector_concat(aAcl, vector(vector(uid, is_grant, inheritance, bitmask)));

  acl := WS.WS.ACL_COMPOSE(aAcl);

  return acl;
}
;

-------------------------------------------------------------------------------
--
-- Removes an existing entry.
-- The grant flag is not given since the ACL will not simultaneously contain
-- an entry granting and revoking the exact same thing.
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_REMOVE_ENTRY(inout acl varbinary, in uid integer, in bitmask integer, in inheritance integer := 0) returns varbinary
{
  declare N integer;
  declare aAcl any;

  aAcl := WS.WS.ACL_PARSE (acl);
  for (N := 0; N < length(aAcl); N := N + 1)
  {
    if ((aAcl[N][0] = uid) and (aAcl[N][2] = inheritance))
    {
      if (aAcl[N][1])
      {
        aset(aAcl, N, vector(aAcl[N][0], aAcl[N][1], aAcl[N][2], bit_and(aAcl[N][3], bit_not(bitmask))));
      }
      else
      {
        aset(aAcl, N, vector(aAcl[N][0], aAcl[N][1], aAcl[N][2], bit_and(aAcl[N][3], bitmask)));
      }
    }
  }
  acl := WS.WS.ACL_COMPOSE(aAcl);

  return acl;
}
;

-------------------------------------------------------------------------------
--
-- True if all the operations in bitmask are granted to the uid in the ACL.
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_IS_GRANTED (in acl varbinary, in uid integer, in bitmask integer) returns integer
{
  declare N, lenAcl integer;
  declare aAcl any;
  declare ids any;
  declare or_acc integer;

  if (isnull(acl))
    return 0;

  aAcl := WS.WS.ACL_PARSE (acl);
  if (length(aAcl) = 0)
    return 0;
  ids := (select vector_concat (vector (uid), VECTOR_AGG (GI_SUB)) from DB.DBA.SYS_ROLE_GRANTS where GI_SUPER = uid);

  or_acc := 0;
  N := 0;
  lenAcl := length(aAcl);
  for (N := 0; N < lenAcl; N := N + 1)
  {
    if (position (aAcl[N][0], ids))
    {
      declare anded integer;
      anded := bit_and (aAcl[N][3], bitmask);
      if (anded <> 0)
      {
        if (aAcl[N][1])
        {
          or_acc := bit_or (or_acc, anded);
        }
        else
          return 0; -- revoke of any single bit invalidates the permission.
      }
    }
  }
  if (or_acc = bitmask)
    return or_acc;
  return 0;
}
;

-------------------------------------------------------------------------------
--
-- Set owner for the ACL
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_SET_OWNER(inout acl varbinary, in uid integer)
{
  return;
}
;

-------------------------------------------------------------------------------
--
-- Return owner for the ACL
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_OWNER(in acl varbinary) returns integer
{
  return;
}
;

-------------------------------------------------------------------------------
--
-- Returns an array with: (owner entry1, entry2,...) where each entry is (grantee is_grant bits).
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_PARSE (
  in acl varbinary,
  in inheritance varchar := '0123',
  in error integer := 1) returns any
{
  declare sAcl varchar;
  declare N, I, T, aclSize integer;
  declare aAcl any;

  if (acl is null)
    return vector ();

  if (internal_type_name(internal_type(acl)) = 'BLOB_HANDLE')
    acl := cast (blob_to_string (acl) as varbinary);
  else if (internal_type_name(internal_type(acl)) = 'VARCHAR')
    acl := cast (acl as varbinary);

  if (not WS.WS.ACL_IS_VALID (acl))
  {
    if (error)
      signal('ACL01', 'Bad ACL object');
    return vector ();
  }

  aclSize := WS.WS.ACL_GET_ACESIZE (acl);
  sAcl := cast (acl as varchar);

  vectorbld_init (aAcl);
  for (N := 1; N <= aclSize; N := N + 1)
  {
    T := WS.WS.ACL_DESERIALIZE_INT (cast (substring (sAcl, 8*N+5, 4) as varbinary));
    I := abs (bit_and (bit_shift (T, -29), 3));
    if (not isnull (strchr (inheritance, cast (I as varchar))))
      vectorbld_acc (aAcl, vector (WS.WS.ACL_DESERIALIZE_INT (cast (substring (sAcl, 8*N+1, 4) as varbinary)),
                                   abs(bit_shift (T, -31)),
                                   I,
                                   abs (bit_and (T, 536870911))));
  }
  vectorbld_final (aAcl);
  return aAcl;
}
;

-------------------------------------------------------------------------------
--
-- Returns an array with: (owner entry1, entry2,...) where each entry is (grantee is_grant bits).
--
-------------------------------------------------------------------------------
create procedure WS.WS.ACL_COMPOSE (
  in aAcl vector) returns varbinary
{
  declare sAcl varchar;
  declare bAcl varbinary;
  declare N, I, J integer;

  sAcl := '';
  for (I := 1; I < 4; I := I + 1)
  {
    for (J := 0; J < 2; J := J + 1)
    {
      foreach (any acl in aAcl) do
      {
        if ((acl[1]=J) and ((acl[2]=I) or ((acl[2]=0) and (I=1))) and acl[3])
          sAcl := concat(sAcl,
                         cast(WS.WS.ACL_SERIALIZE_INT(acl[0]) as varchar),
                         cast(WS.WS.ACL_SERIALIZE_INT(bit_shift(acl[1],31)+bit_shift(acl[2],29)+acl[3]) as varchar));
      }
    }
  }

  bAcl := cast(concat(cast(WS.WS.ACL_SERIALIZE_INT(length(sAcl)+8) as varchar),
                      cast(WS.WS.ACL_SERIALIZE_INT(length(sAcl)/8) as varchar),
                      sAcl) as varbinary);
  -- dbg_obj_princ ('WS.WS.ACL_COMPOSE(', aAcl, ') returns ', WS.WS.ACL_DBG (bAcl));
  return bAcl;
}
;

--
-- DAV filter and filter compiler (FC)
--

create function DAV_CAST_STRING_TO_INTEGER (in val varchar) returns integer
{
  if (val is null) return null;
  whenever sqlstate '*' goto ret_null;
  return cast (val as integer);
ret_null:
  return null;
}
;

create function DAV_CAST_STRING_TO_DATETIME (in val varchar) returns datetime
{
  if (val is null) return null;
  whenever sqlstate '*' goto ret_null;
  return cast (val as datetime);
ret_null:
  return null;
}
;

create function DAV_CAST_TEXT_TO_VARCHAR (in val varchar) returns varchar
{
  if (val is null) return null;
  whenever sqlstate '*' goto ret_null;
  return cast (val as varchar);
ret_null:
  return null;
}
;

create function DAV_CAST_TEXT_TO_INTEGER (in val varchar) returns integer
{
  if (val is null) return null;
  whenever sqlstate '*' goto ret_null;
  return cast (val as integer);
ret_null:
  return null;
}
;

create function DAV_CAST_TEXT_TO_DATETIME (in val varchar) returns datetime
{
  if (val is null) return null;
  whenever sqlstate '*' goto ret_null;
  return cast (val as datetime);
ret_null:
  return null;
}
;

create function DAV_FC_CONST_AS_SQL (inout val any)
{
  if (193 = __tag (val))
    {
      declare res varchar;
      res := '';
      foreach (any item in val) do
        res := concat (res, ', ', DAV_FC_CONST_AS_SQL(item));
      return subseq (res, 2);
    }
  if (182 = __tag (val))
    return replace (WS.WS.STR_SQL_APOS (val), '^{', '\\136{');
  if (189 = __tag (val))
    return sprintf ('%d', val);
  if (211 = __tag (val))
    return sprintf ('cast (''%s'' as datetime)', cast (val as varchar));
  signal ('.....', 'Internal error in DAV_DIR_FILTER: DAV_FC_CONST_AS_SQL has got bad value');
}
;

-- Every standard predicate has a description that is the vector of
-- table for value
-- count of additional arguments
-- type name of value ('varchar', 'integer', 'datetime', 'text', 'XML'),
-- column name for value

create procedure DAV_FC_PRED_METAS (inout pred_metas any)
{
  pred_metas := vector (
    'RES_ID',                   vector ('SYS_DAV_RES'   , 0, 'integer'  , 'RES_ID'      ),
    'RES_ID_SERIALIZED',        vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'serialize (RES_ID)'  ),
    'RES_NAME',                 vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_NAME'    ),
    'RES_FULL_PATH',            vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_FULL_PATH'       ),
    'RES_TYPE',                 vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_TYPE'    ),
    'RES_OWNER_ID',             vector ('SYS_DAV_RES'   , 0, 'integer'  , 'RES_OWNER'   ),
    'RES_OWNER_NAME',           vector ('SYS_DAV_USER'  , 0, 'varchar'  , 'U_NAME'      ),
    'RES_GROUP_ID',             vector ('SYS_DAV_RES'   , 0, 'integer'  , 'RES_GROUP'   ),
    'RES_GROUP_NAME',           vector ('SYS_DAV_GROUP' , 0, 'varchar'  , 'G_NAME'      ),
    'RES_COL_FULL_PATH',        vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'subseq (RES_FULL_PATH, 0, 1 + strrchr (RES_FULL_PATH, ''/''))'       ),
    'RES_COL_NAME',             vector ('SYS_DAV_COL'   , 0, 'varchar'  , 'COL_NAME'    ),
--    'RES_COL_ID',             vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_COL'     ),
    'RES_CR_TIME',              vector ('SYS_DAV_RES'   , 0, 'datetime' , 'RES_CR_TIME' ),
    'RES_MOD_TIME',             vector ('SYS_DAV_RES'   , 0, 'datetime' , 'RES_MOD_TIME'),
    'RES_PERMS',                vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_PERMS'   ),
    'RES_CONTENT',              vector ('SYS_DAV_RES'   , 0, 'text'     , 'RES_CONTENT' ),
    'PROP_NAME',                vector ('SYS_DAV_PROP'  , 0, 'varchar'  , 'PROP_NAME'   ),
    'PROP_VALUE',               vector ('SYS_DAV_PROP'  , 1, 'text'     , 'PROP_VALUE'  ),
    'RES_TAGS',                 vector ('all-tags'      , 0, 'varchar'  , 'DT_TAGS'     ), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',          vector ('public-tags'   , 0, 'text-tag' , 'DT_TAGS'     ),
    'RES_PRIVATE_TAGS',         vector ('private-tags'  , 0, 'text-tag' , 'DT_TAGS'     ),
    'RDF_PROP',                 vector ('SYS_DAV_PROP'  , 1, 'varchar'  , NULL  ),
    'RDF_VALUE',                vector ('SYS_DAV_PROP'  , 2, 'XML'      , NULL  ),
    'RDF_OBJ_VALUE',            vector ('SYS_DAV_PROP'  , 3, 'XML'      , NULL  )
    );
}
;

-- Every comparison has a description that is the vector of
-- 'scalar' or 'vector' indicating sort of the match pattern
-- data type of match ('varchar', 'sortable', 'any', 'text', 'XML')
-- 'never-match' value for safe cast (it's NULL for a while but can be non-NULL for some checks in future
-- SQL condition string that is formatting pattern with labels like '^{value}^', '^{pattern}^', '^{pattern0}^', '^{pattern1}^'
-- XPATH filter string, same syntax'

create procedure DAV_FC_CMP_METAS (inout cmp_metas any)
{
  cmp_metas := vector (
    '<',                        vector ('scalar', 'sortable'    , NULL, '(^{value}^ < ^{pattern}^)'     , '[sql-lt (^{value}^, ^{pattern}^)]'),
    '>',                        vector ('scalar', 'sortable'    , NULL, '(^{value}^ > ^{pattern}^)'     , '[sql-gt (^{value}^, ^{pattern}^)]'),
    '<=',                       vector ('scalar', 'sortable'    , NULL, '(^{value}^ <= ^{pattern}^)'    , '[sql-le (^{value}^, ^{pattern}^)]'),
    '>=',                       vector ('scalar', 'sortable'    , NULL, '(^{value}^ >= ^{pattern}^)'    , '[sql-ge (^{value}^, ^{pattern}^)]'),
    '=',                        vector ('scalar', 'sortable'    , NULL, '(^{value}^ = ^{pattern}^)'     , '[sql-equ (^{value}^, ^{pattern}^)]'),
    '<>',                       vector ('scalar', 'sortable'    , NULL, '(^{value}^ <> ^{pattern}^)'    , '[sql-neq (^{value}^, ^{pattern}^)]'),
    '!=',                       vector ('scalar', 'sortable'    , NULL, '(^{value}^ <> ^{pattern}^)'    , '[sql-neq (^{value}^, ^{pattern}^)]'),
    'between',                  vector ('vector', 'sortable'    , NULL, '(^{value}^ between ^{pattern0}^ and ^{pattern1}^)'     , '[sql-ge(^{value}^, ^{pattern0}^)][sql-le (^{value}^, ^{pattern0}^)]' ),
    'in',                       vector ('vector', 'sortable'    , NULL, '(^{value}^ in (^{pattern}^))'  , NULL  ),
    'member_of',                vector ('vector', 'sortable'    , NULL, '(^{value}^ in (^{pattern}^))'  , NULL  ),
    'like',                     vector ('scalar', 'varchar'     , NULL, '(^{value}^ like ^{pattern}^)'  , '[^{value}^ like ^{pattern}^]'),
    'regexp_match',             vector ('scalar', 'varchar'     , NULL, '(regexp_match (^{pattern}^, ^{value}^) is not null)'   , NULL  ),
    'is_substring_of',          vector ('scalar', 'varchar'     , NULL, '(strstr (^{pattern}^, ^{value}^) is not null)' ,'[contains (^{pattern}^, ^{value}^)]'),
    'contains_substring',       vector ('scalar', 'varchar'     , NULL, '(strstr (^{value}^, ^{pattern}^) is not null)' ,'[contains (^{value}^, ^{pattern}^)]'),
    'not_contains_substring',   vector ('scalar', 'varchar'     , NULL, '(strstr (^{value}^, ^{pattern}^) is null)'     ,'[not (contains (^{value}^, ^{pattern}^)]'     ),
    'starts_with',              vector ('scalar', 'varchar'     , NULL, '(^{value}^ between ^{pattern}^ and (^{pattern}^ || ''\\377\\377\\377\\377''))' , '[starts-with (^{value}^, ^{pattern}^)]'),
    'not_starts_with',          vector ('scalar', 'varchar'     , NULL, '(not (^{value}^ between ^{pattern}^ and (^{pattern}^ || ''\\377\\377\\377\\377'')))'   , '[not (starts-with (^{value}^, ^{pattern}^))]'        ),
    'ends_with',                vector ('scalar', 'varchar'     , NULL, '(case (sign (length (^{value}^) - length (^{pattern}^))) when -1 then 0 else equ (subseq (^{value}^, length (^{value}^) - length (^{pattern}^)), ^{pattern}^) end)'    , '[ends-with (^{value}^, ^{pattern}^)]'),
    'not_ends_with',            vector ('scalar', 'varchar'     , NULL, '(case (sign (length (^{value}^) - length (^{pattern}^))) when -1 then 1 else neq (subseq (^{value}^, length (^{value}^) - length (^{pattern}^)), ^{pattern}^) end)'    , '[not (ends-with (^{value}^, ^{pattern}^))]'),
    'is_null',                  vector ('no'    , 'any'         , NULL, '(^{value}^ is null)'           , null  ),
    'is_not_null',              vector ('no'    , 'any'         , NULL, '(^{value}^ is not null)'       , null  ),
    'contains_tags',            vector ('scalar', 'varchar'     , NULL, NULL, NULL ),
    'may_contain_tags',         vector ('scalar', 'varchar'     , NULL, NULL, NULL ),
    'contains_text',            vector ('scalar', 'text'        , NULL, NULL, '[text-contains (^{value}^, ^{pattern}^)]' ),
    'may_contain_text',         vector ('scalar', 'text'        , NULL, NULL, '[text-contains (^{value}^, ^{pattern}^)]' ),
--    'xpath_contains',         vector ('scalar', 'XML'         , NULL, NULL, NULL ),
    'xcontains',                vector ('scalar', 'XML'         , NULL, NULL, '[^{pattern}^]' )
    );
}
;

create procedure DAV_FC_TABLE_METAS (inout table_metas any)
{
  table_metas := vector (
    'SYS_DAV_RES'       , vector (      ''      ,
                                        ''      ,
                                                'RES_CONTENT'   , 'RES_CONTENT' , '[__quiet] /' ),
    'SYS_DAV_COL'       , vector (      '\n  inner join WS.WS.SYS_DAV_COL as ^{alias}^ on ((^{alias}^.COL_ID = _top.RES_COL)^{andpredicates}^)' ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_COL as ^{alias}^ where (^{alias}^.COL_ID = _top.RES_COL)^{andpredicates}^)'    ,
                                                NULL            , NULL          , NULL  ),
    'SYS_DAV_USER'      , vector (      '\n  left outer join WS.WS.SYS_DAV_USER as ^{alias}^ on ((^{alias}^.U_ID = _top.RES_OWNER)^{andpredicates}^)'   ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_USER as ^{alias}^ where (^{alias}^.U_ID = _top.RES_OWNER)^{andpredicates}^)'   ,
                                                NULL            , NULL          , NULL  ),
    'SYS_DAV_GROUP'     , vector (      '\n  left outer join WS.WS.SYS_DAV_GROUP as ^{alias}^ on ((^{alias}^.G_ID = _top.RES_GROUP)^{andpredicates}^)'  ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_GROUP as ^{alias}^ where (^{alias}^.G_ID = _top.RES_GROUP)^{andpredicates}^)'  ,
                                                NULL            , NULL          , NULL  ),
    'SYS_DAV_PROP'      , vector (      '\n  inner join WS.WS.SYS_DAV_PROP as ^{alias}^ on ((^{alias}^.PROP_PARENT_ID = _top.RES_ID) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'       ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_PROP as ^{alias}^ where (^{alias}^.PROP_PARENT_ID = _top.RES_ID) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'  ,
                                                'PROP_VALUE'    , 'PROP_VALUE'  , '[__quiet __davprop xmlns:virt="virt"] .'     ),
    'public-tags'       , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid())^{andpredicates}^)'   ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid())^{andpredicates}^)'      ,
                                                'DT_TAGS'       , 'DT_TAGS'     , NULL  ),
    'private-tags'      , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'     ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'        ,
                                                'DT_TAGS'       , 'DT_TAGS'     , NULL  ),
    'all-tags'          , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid() or ^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'    ,
                                        '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid() or ^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'       ,
                                                'DT_TAGS'       , 'DT_TAGS'     , NULL  )
    );
}
;


create function DAV_FC_PRINT_COMPARISON (inout pred any, inout pred_metas any, inout cmp_metas any, in varname varchar, in nonsql integer) returns varchar
{
  declare pred_meta any;
  declare cmp_meta, pattern_sample, cuts any;
  declare var_expn, cmp_type, pattern_type, cond_format varchar;
  declare res varchar;
  pred_meta := get_keyword (pred[0], pred_metas);
  cmp_meta := get_keyword (pred[1], cmp_metas);
  cond_format := cmp_meta [3 + nonsql];
  if (cond_format is null)
    signal ('.....', 'Internal error in DAV_DIR_FILTER: DAV_FC_PRINT_COMPARISON on non-comparison predicate');
  cmp_type := cmp_meta[1];
  pattern_sample := pred[2];
  if ('scalar' = cmp_meta[0])
    {
      if (not (__tag (pattern_sample) in (182, 189, 211)))
        goto bad_pattern_datatype;
    }
  else if ('vector' = cmp_meta[0])
    {
      if (193 <> __tag (pattern_sample))
        goto bad_pattern_datatype;
      if (0 = length (pattern_sample))
        goto empty_array_pattern;
      pattern_sample := pattern_sample[0];
      if (not (__tag (pattern_sample) in (182, 189, 211)))
        goto bad_pattern_datatype;
      foreach (any itm in pred[2]) do
        {
          if (__tag (itm) <> __tag(pred[2][0]))
            goto mixed_array_pattern;
        }
    }
  else if ('no' = cmp_meta[0])
    {
      pattern_sample := '';
    }
  else signal ('.....', 'Internal error in DAV_DIR_FILTER: DAV_FC_CMP_META forms bad sort of match pattern');
  if (isstring (pattern_sample))
    pattern_type := 'varchar';
  else if (isinteger (pattern_sample))
    pattern_type := 'integer';
  else if (211 = __tag (pattern_sample)) -- datetime
    pattern_type := 'datetime';
  else
    goto bad_pattern_datatype;
  if ('sortable' = cmp_type)
    {
--      if (pred_meta[2] not in ('varchar', 'text'))
--        goto type_mismatch;
      cmp_type := pattern_type;
    }
  else if ('any' = cmp_type)
    {
      pattern_type := pred_meta[2];
    }
  else if (
    (1 = nonsql) and
    ('varchar' = pattern_type) and
    (('text' = cmp_type) or ('XML' = cmp_type)) )
    {
      pattern_type := pred_meta[2];
    }
  else if (pattern_type <> cmp_type)
    goto bad_pattern_datatype;
  if (pred_meta[2] = pattern_type)
    {
      var_expn := varname;
    }
  else if (1 = nonsql)
    {
      if (('text' = cmp_meta) or ('XML' = cmp_meta))
        var_expn := varname;
      else if ('varchar' = pattern_type)
        var_expn := sprintf ('string (%s)', varname);
      else if ('integer' = pattern_type)
        var_expn := sprintf ('number (%s)', varname);
      else if ('datetime' = pattern_type)
        var_expn := sprintf ('dateTime (%s, 1)', varname);
      else
        goto type_mismatch;
    }
  else
    {
      if ('varchar' = pred_meta[2])
        var_expn := sprintf ('DB.DBA.DAV_CAST_STRING_TO_%s (%s)', upper (cmp_type), varname);
      else if ('text' = pred_meta[2])
        var_expn := sprintf ('DB.DBA.DAV_CAST_TEXT_TO_%s (%s)', upper (cmp_type), varname);
      else
        goto type_mismatch;
    }
  if (('like' = pred[1]) and ('%' = pred[2]))
    return null;
  if (('starts_with' = pred[1]) and ('' = pred[2]))
    return null;
  if (('ends_with' = pred[1]) and ('' = pred[2]))
    return null;
  res := '';
  cuts := split_and_decode (cond_format, 0, '\0\0^');
  foreach (varchar cut in cuts) do
    {
      if (cut = '' or (cut[0] <> '{'[0]))
        res := res || cut;
      else if (cut = '{value}')
        res := res || var_expn;
      else if (cut = '{pattern}')
        res := res || DAV_FC_CONST_AS_SQL (pred[2]);
      else if (cut = '{pattern0}')
        {
          res := res || DAV_FC_CONST_AS_SQL (pred[2][0]);
        }
      else if (cut = '{pattern1}')
        {
          if (length (pred[2]) < 2)
            goto tooshort_array_pattern;
          res := res || DAV_FC_CONST_AS_SQL (pred[2][1]);
        }
      else signal ('.....', 'Internal error in DAV_DIR_FILTER: DAV_FC_CMP_META forms bad formatting pattern');
    }
  return res;

bad_pattern_datatype:
  signal ('.....', sprintf ('Bad data type (%d) of pattern value in predicate ''%s'' (operation ''%s'') in filter of DAV_DIR_FILTER, ', __tag (pattern_sample), pred[0], pred[1]));
empty_array_pattern:
  signal ('.....', sprintf ('The pattern is an empty vector in predicate ''%s'' (operation ''%s'') in filter of DAV_DIR_FILTER, ', pred[0], pred[1]));
tooshort_array_pattern:
  signal ('.....', sprintf ('The pattern vector is too short in predicate ''%s'' (operation ''%s'') in filter of DAV_DIR_FILTER, ', pred[0], pred[1]));
mixed_array_pattern:
  signal ('.....', sprintf ('All items of the pattern vector must have same datatype in predicate ''%s'' (operation ''%s'') in filter of DAV_DIR_FILTER, ', pred[0], pred[1]));
type_mismatch:
  signal ('.....', sprintf ('Can not compile comparison ''%s %s %s'' due to type mismatch in predicate ''%s'' in filter of DAV_DIR_FILTER, ', pred_meta[2], pred[1], pattern_type, pred[0]));
}
;

-- This prints the fragment that starts after 'FROM WS.WS.SYS_DAV_RES' and contains the rest of FROM and whole 'WHERE'
create function DAV_FC_PRINT_WHERE (inout filter any, in param_uid integer) returns varchar
{
  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;
  -- dbg_obj_princ ('DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
  DAV_FC_PRED_METAS (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  DAV_FC_TABLE_METAS (table_metas);
  used_tables := vector ('SYS_DAV_RES', vector ('SYS_DAV_RES', '_top', null, vector (), vector (), vector ()));
  return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;

create function DAV_FC_PRINT_WHERE_INT (in filter any, inout pred_metas any, inout cmp_metas any, inout table_metas any, inout used_tables any, in param_uid integer) returns varchar
{
-- used_tables is get_keyword list of tables, get_keyword will return vector of
-- [0] table name,
-- [1] alias prefix,
-- [2] text of join conditions,
-- [3] vector of plain conditions,
-- [4] vector of free-text terms,
-- [5] vector of xcontains terms.
  declare pred_count, pred_idx, need_and, need_top_and integer;
  declare table_count, table_idx, fixed_used_tables, first_ft_table_idx integer;
  declare table_of_pred, ses any;
  declare res_strg varchar;
  pred_count := length (filter);
  fixed_used_tables := length (used_tables);
  if ((0 = pred_count) and (2 = fixed_used_tables))
    return '\nwhere\n(1=1)\n';
  -- dbg_obj_princ ('pred_count = ', pred_count, ' length (used_tables) = ', length (used_tables));
  table_of_pred := make_array (pred_count, 'any');
  pred_idx := 0;
  while (pred_idx < pred_count)
    {
      declare pred, pred_meta, cmp_meta any;
      declare pred_table_key, optext, cmp_text, ftc_text, xc_text varchar;
      declare join_with_prop_name, used_table_pos integer;
      pred := filter[pred_idx];
      pred_meta := get_keyword (pred[0], pred_metas);
      if (pred_meta is null)
        {
          signal ('.....', sprintf ('Invalid predicate type ''%s'' in filter of DAV_DIR_FILTER', cast (pred[0] as varchar)));
        }
      if (length (pred) <> 3 + pred_meta[1])
        signal ('.....', sprintf ('Predicate with type ''%s'' should be a vector of length %d in filter of DAV_DIR_FILTER', pred[0], (3 + pred_meta[1])));
      cmp_meta := get_keyword (pred[1], cmp_metas);
      if (cmp_meta is null)
        signal ('.....', sprintf ('Invalid operation name ''%s'' in filter of DAV_DIR_FILTER', pred[1]));
      join_with_prop_name := 0;
      if (('PROP_VALUE' = pred[0]) or ('RDF_PROP' = pred[0]) or ('RDF_VALUE' = pred[0]) or ('RDF_OBJ_VALUE' = pred[0]))
        {
          if (get_keyword (pred_meta[0], used_tables) is null)
            join_with_prop_name := 1;
          else
            {
              filter := vector_concat (filter, vector (vector ('PROP_NAME', '=', pred[3])));
              table_of_pred := vector_concat (table_of_pred, vector (null));
              pred_count := pred_count + 1;
            }
        }
      if (join_with_prop_name)
        {
          if (not isstring (pred[3]))
            signal ('.....', sprintf ('The DAV property name in predicate of type ''%s'' is not a string in filter of DAV_DIR_FILTER', pred[0]));
          pred_table_key := concat (pred_meta[0], ', PROP_NAME=', pred[3]);
        }
      else
        pred_table_key := pred_meta[0];
      used_table_pos := position (pred_table_key, used_tables, 1, 2);
      if (0 = used_table_pos) -- new key, thus new exists (select ...) should be created.
        {
          declare cmp_checks any;
          declare new_alias varchar;
          used_table_pos := length (used_tables) + 1;
          new_alias := sprintf ('_sub%d', pred_idx);
          if (join_with_prop_name)
            cmp_checks := sprintf ('(%s.PROP_NAME = %s)', new_alias, WS.WS.STR_SQL_APOS (pred[3]));
          else
            cmp_checks := null;
          used_tables := vector_concat (used_tables, vector (pred_table_key, vector (pred_meta[0], new_alias, cmp_checks, vector (), vector (), vector ())));
        }
      table_of_pred [pred_idx] := used_table_pos;
      cmp_text := null;
      ftc_text := null;
      xc_text := null;
      if (pred_meta[3] = '') -- unsupported predicate
        {
          if (('may_contain_text' = pred[1]) or ('may_contain_tags' = pred[1]))
            {
            ; -- silently ignore the problem, that's why 'MAY_contain_text' and 'MAY_contain_tags'.
            }
          else if ('is_null' = pred[1])
            {
            ; -- yes, that's null :)
            }
          else
            return '1=2'; -- one 'AND'ed term is never true hence there's no need to check anything else.
        }
      else
      if (pred_meta[3] is not null and cmp_meta[3] is not null)
        {
          declare varname varchar;
          if (strchr (pred_meta[3], '(') is not null)
            varname := pred_meta[3];
          else
            {
              varname := concat (used_tables[used_table_pos][1], '.', pred_meta[3]);
            }
          cmp_text := DAV_FC_PRINT_COMPARISON (pred, pred_metas, cmp_metas, varname, 0);
        }
      else if ('RDF_PROP' = pred[0])
        {
          optext := DAV_FC_PRINT_COMPARISON (pred, pred_metas, cmp_metas, 'name(.)', 1);
          if (optext is null)
            xc_text := '[virt:rdf/virt:top-res[virt:prop]]';
          else
            xc_text := '[virt:rdf/virt:top-res/virt:prop/*[1]' || optext || ']';
        }
      else if ('RDF_VALUE' = pred[0])
        {
          optext := DAV_FC_PRINT_COMPARISON (pred, pred_metas, cmp_metas, '.', 1);
          if (optext is null)
            xc_text := sprintf ('[virt:rdf/virt:top-res/virt:prop[*[1][self::(!%s!)]][virt:value]]', pred[4]);
          else
            xc_text := sprintf ('[virt:rdf/virt:top-res/virt:prop[*[1][self::(!%s!)]]/virt:value%s]', pred[4], optext);
        }
      else if ('RDF_OBJ_VALUE' = pred[0])
        {
          optext := DAV_FC_PRINT_COMPARISON (pred, pred_metas, cmp_metas, '.', 1);
          if (optext is null)
            xc_text := sprintf ('[virt:rdf/virt:top-res/virt:prop[*[1][self::(!%s!)]]/virt:res/virt:prop[*[1][self::(!%s!)]][virt:value]]', pred[4], pred[5]);
          else
            xc_text := sprintf ('[virt:rdf/virt:top-res/virt:prop[*[1][self::(!%s!)]]/virt:res/virt:prop[*[1][self::(!%s!)]]/virt:value%s]', pred[4], pred[5], optext);
        }
      else if (('contains_text' = pred[1]) or ('may_contain_text' = pred[1]))
        {
          if (not (isstring (pred[2])))
            signal ('.....', sprintf ('Free text pattern in predicate of type ''%s'' is not a string in filter of DAV_DIR_FILTER', pred[0]));
          ftc_text := '(' || pred[2] || ')';
        }
      else if (('contains_tags' = pred[1]) or ('may_contain_tags' = pred[1]))
        {
          if (not (isstring (pred[2])))
            signal ('.....', sprintf ('String of tags in predicate of type ''%s'' is not a string in filter of DAV_DIR_FILTER', pred[0]));
          ftc_text := '("' || replace (WS.WS.DAV_TAG_NORMALIZE (pred[2]), ' ', '" and "') || '")';
          if ('RES_TAGS' = pred[0])
            ftc_text := '(("UID^{uid}^" or "UID^{nobodyuid}^") and ' || ftc_text || ')';
          else if ('RES_PUBLIC_TAGS' = pred[0])
            ftc_text := '("UID^{nobodyuid}^" and ' || ftc_text || ')';
          else if ('RES_PRIVATE_TAGS' = pred[0])
            ftc_text := '("UID^{uid}^" and ' || ftc_text || ')';
        }
      else if ('xcontains' = pred[1])
        {
          if (not (isstring (pred[2])))
            signal ('.....', sprintf ('Free text pattern in predicate of type ''%s'' is not a string in filter of DAV_DIR_FILTER', pred[0]));
          -- xpath_explain ('[xmlns:virt="virt"] ' || pred[2]);
          -- xpath_explain ('[xmlns:virt="virt"] .[' || pred[2] || ']');
          xc_text := '[' || pred[2] || ']';
        }
      else
        signal ('.....', 'Internal error in DAV_DIR_FILTER: no condition text generated for a predicate');
      if (cmp_text is not null and (0 = position (cmp_text, used_tables[used_table_pos][3])))
        used_tables[used_table_pos][3] := vector_concat (used_tables[used_table_pos][3], vector (cmp_text));
      if (ftc_text is not null and (0 = position (ftc_text, used_tables[used_table_pos][4])))
        used_tables[used_table_pos][4] := vector_concat (used_tables[used_table_pos][4], vector (ftc_text));
      if (xc_text is not null and (0 = position (xc_text, used_tables[used_table_pos][5])))
        used_tables[used_table_pos][5] := vector_concat (used_tables[used_table_pos][5], vector (xc_text));
      pred_idx := pred_idx + 1;
    }
  if ((2 = length (used_tables)) and
     (0 = length (used_tables[1][3])) and
     (0 = length (used_tables[1][4])) and
     (0 = length (used_tables[1][5])) )
    return '\nwhere\n(1=1)\n';
  -- dbg_obj_princ ('DAV_FC_PRINT_WHERE has made list of used tables: ', used_tables);
  ses := string_output();
  table_count := length (used_tables);
  first_ft_table_idx := null;
  for (table_idx := 1; (table_idx < table_count) and first_ft_table_idx is null ; table_idx := table_idx + 2)
    {
      declare tbl any;
      tbl := used_tables [table_idx];
      if ((length (tbl[4]) > 0) or (length (tbl[5]) > 0))
        first_ft_table_idx := table_idx;
    }
  for (table_idx := 1; table_idx < table_count; table_idx := table_idx + 2)
    {
      declare tbl, new_tbl any;
      declare has_ft, has_xc integer;
      tbl := used_tables [table_idx];
      has_ft := length (tbl[4]);
      has_xc := length (tbl[5]);
      if ((has_ft and has_xc) or
        ((table_idx > first_ft_table_idx) and
         (table_idx < fixed_used_tables) and
         (has_ft or has_xc) ) )
        {
          declare cmp_checks any;
          declare new_alias varchar;
          new_alias := sprintf ('%s_%d', tbl[1], table_idx);
          if (tbl[2] like '(%.PROP_NAME = %)')
            cmp_checks := sprintf ('(%s.PROP_NAME = %s.PROP_NAME)', new_alias, tbl[1]);
          else
            cmp_checks := null;
          new_tbl := vector (tbl[0], new_alias, cmp_checks, vector (), vector (), vector ());
          if ((table_idx > first_ft_table_idx) and
            (table_idx < fixed_used_tables) and
            (has_ft or has_xc) )
            {
              new_tbl[4] := tbl[4];
              new_tbl[5] := tbl[5];
              tbl[4] := null;
              tbl[5] := null;
            }
          else if (has_xc)
            {
              new_tbl[5] := tbl[5];
              tbl[5] := null;
            }
          else if (has_ft)
            {
              new_tbl[4] := tbl[4];
              tbl[4] := null;
            }
          else
            signal ('.....', 'Internal error in DAV_DIR_FILTER: cannot handle a combination of free-text and xcontain predicates');
          used_tables := vector_concat (used_tables,
            vector (used_tables [table_idx-1], new_tbl) );
          table_count := table_count + 2;
        }
    }
  if (first_ft_table_idx is null)
    first_ft_table_idx := table_count;
  -- dbg_obj_princ ('DAV_FC_PRINT_WHERE has set first_ft_table_idx to ', first_ft_table_idx);
  for (table_idx := fixed_used_tables + 1; table_idx < table_count ; table_idx := table_idx + 2)
    {
      declare tbl, tbl_meta any;
      --http (sprintf ('\n-- tbl %d join\n', table_idx), ses);
      tbl := used_tables [table_idx];
      tbl_meta := get_keyword (tbl[0], table_metas);
      if (tbl_meta is null)
        signal ('.....', sprintf ('Internal error in DAV_DIR_FILTER: bad table %s', tbl[0]));
      if ((table_idx <= first_ft_table_idx) or ((length (tbl[4]) = 0) and (length (tbl[5]) = 0)))
        {
          declare andpredicates, join_code varchar;
          if (length (tbl[2]) > 0)
            andpredicates := ' AND ' || tbl[2];
          else
            andpredicates := '';
          join_code := replace (replace (tbl_meta[0], '^{alias}^', tbl[1]), '^{andpredicates}^', andpredicates);
          http (join_code, ses);
        }
    }
  http ('\nwhere\n', ses);
  need_top_and := 0;
  for (table_idx := 1; table_idx < table_count ; table_idx := table_idx + 2)
    {
      declare tbl, tbl_meta, subses any;
      declare subses_strg varchar;
      --http (sprintf ('\n-- tbl %d conds\n', table_idx), ses);
      tbl := used_tables [table_idx];
      tbl_meta := get_keyword (tbl[0], table_metas);
      subses := string_output ();
      need_and := 0;
      if (length (tbl[4]) > 0)
        {
          declare ft_field, varname, ft_pattern varchar;
          declare need_ft_and integer;
          ft_field := tbl_meta[2];
          if (ft_field is null)
            signal ('.....', sprintf ('Internal error in DAV_DIR_FILTER: bad table %s for free text search', tbl[0]));
          varname := concat (tbl[1], '.', ft_field);
          need_ft_and := 0;
          ft_pattern := '';
          foreach (varchar ft_term in tbl[4]) do
            {
              if (need_ft_and)
                ft_pattern := ft_pattern || ' and ';
              else
                need_ft_and := 1;
              ft_pattern := ft_pattern || ft_term;
            }
          if (need_and)
            http (' and\n  ', subses);
          else
            need_and := 1;
          http (sprintf ('contains (%s, ', varname), subses);
          http (WS.WS.STR_SQL_APOS (ft_pattern), subses);
          http (')', subses);
        }
      if (length (tbl[5]) > 0)
        {
          declare ft_field, varname, ft_pattern varchar;
          ft_field := tbl_meta[3];
          if (ft_field is null)
            signal ('.....', sprintf ('Internal error in DAV_DIR_FILTER: bad table %s for xcontains search', tbl[0]));
          varname := concat (tbl[1], '.', ft_field);
          ft_pattern := tbl_meta[4];
          if (length (tbl[5]) = 1)
            {
              ft_pattern := ft_pattern || tbl[5][0];
            }
          else
            {
              foreach (varchar ft_term in tbl[5]) do
                {
                  ft_pattern := ft_pattern || ft_term;
                }
            }
          if (need_and)
            http (' and\n  ', subses);
          else
            need_and := 1;
          http (sprintf ('xcontains (%s, ', varname), subses);
          http (WS.WS.STR_SQL_APOS (ft_pattern), subses);
          http (')', subses);
        }
      foreach (varchar cond in tbl[3]) do
        {
          if (need_and)
            http (' and\n  ', subses);
          else
            need_and := 1;
          http (cond, subses);
        }
      subses_strg := string_output_string (subses);
      if (subses_strg <> '')
        {
          if (need_top_and)
            http (' and\n  ', ses);
          else
            need_top_and := 1;
          if ((table_idx <= first_ft_table_idx) or ((length (tbl[4]) = 0) and (length (tbl[5]) = 0)))
            http (subses_strg, ses);
          else
            {
              declare exists_code varchar;
              exists_code := replace (replace (tbl_meta[1], '^{alias}^', tbl[1]), '^{andpredicates}^', ' and\n  ' || subses_strg);
              http (exists_code, ses);
            }
        }
    }
  if (not need_top_and)
    http ('(1=1) ', ses);
  res_strg := string_output_string (ses);
  res_strg := replace (res_strg, '^{uid}^', cast (param_uid as varchar));
  res_strg := replace (res_strg, '^{nobodyuid}^', cast (http_nobody_uid() as varchar));
  return res_strg;
}
;


-- RDF Schemas for properties of DAV resources.


create procedure
DAV_REGISTER_RDF_SCHEMA (in schema_uri varchar, in location varchar, in local_addon varchar, in mode varchar)
{
  mode := lower (mode);
  if (exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schema_uri))
    {
      if ('into' = mode)
        signal ('23000', sprintf ('Uniqueness violation: RDF schema ''%s'' is already registered', schema_uri));
      else if ('replacing' = mode)
        insert replacing WS.WS.SYS_RDF_SCHEMAS (RS_URI, RS_LOCATION, RS_LOCAL_ADDONS, RS_DEPRECATED)
        values (schema_uri, location, local_addon, 0);
      else if ('soft' = mode)
        update WS.WS.SYS_RDF_SCHEMAS set RS_LOCAL_ADDONS = local_addon, RS_DEPRECATED = 0 where RS_URI = schema_uri and RS_LOCAL_ADDONS is null;
    }
  else
    insert replacing WS.WS.SYS_RDF_SCHEMAS (RS_URI, RS_LOCATION, RS_LOCAL_ADDONS, RS_DEPRECATED)
    values (schema_uri, location, local_addon, 0);
  DAV_GET_RDF_SCHEMA_N3 (schema_uri);
}
;


--!AWK PUBLIC
create function DAV_RDF_SCHEMA_N3_LIST_PROPERTIES (inout schema_n3 any, in classname varchar)
{
  if (classname is null)
    {
      return xpath_eval ('
let ("excl",
  distinct (
    for ("dom",
      /N3
      [@N3P="http://www.openlinksw.com/schemas/virtrdf#domain"],
      string (\044dom/@N3S) ) ),
  /N3
  [@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  [@N3O="http://www.w3.org/1999/02/22-rdf-syntax-ns#Property"]
  [not (@N3S = \044excl)]
  /@N3S )',
        schema_n3, 1 );
    }
  return xpath_eval ('
let ("incl",
  distinct (
    for ("dom",
      /N3
      [@N3P="http://www.openlinksw.com/schemas/virtrdf#domain"]
      [@N3O=\044classname],
      string (\044dom/@N3S) ) ),
  /N3
  [@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  [@N3O="http://www.w3.org/1999/02/22-rdf-syntax-ns#Property"]
  [@N3S=\044incl]
  /@N3S )',
        schema_n3, 1, vector ('classname', classname) );
}
;


create procedure
DAV_CROP_URI_TO_CATNAME (in uri varchar)
{
  declare res varchar;
  declare slash integer;
  uri := replace (uri, '#', '/');
again:
  if (uri like '%/')
    {
      uri := subseq (uri, 0, length (uri) - 1);
      goto again;
    }
  if (uri like 'http://%')
    {
      uri := subseq (uri, 7);
      goto again;
    }
  slash := strrchr (uri, '/');
  if (slash is not null)
    return subseq (uri, slash + 1);
  return uri;
}
;


--!AWK PUBLIC
create procedure
DAV_GET_RDF_SCHEMA_N3 (in schema_uri varchar)
{
  for (select RS_LOCATION, RS_LOCAL_ADDONS, RS_PRECOMPILED from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schema_uri) do
    {
      declare std_schema, local_addon, mix any;
      declare schema_catname varchar;
      declare prop_list, prop_catnames, prop_catnames_hash any;
      if (RS_PRECOMPILED is not null)
        return RS_PRECOMPILED;
      if (RS_LOCATION is null)
        std_schema := NULL;
      else
        {
          std_schema := xtree_doc (XML_URI_GET_AND_CACHE (RS_LOCATION), 0, RS_LOCATION);
          std_schema := xslt ('http://local.virt/rdfxml2n3xml', std_schema);
        }
      if (RS_LOCAL_ADDONS is null)
        local_addon := NULL;
      else
        {
          local_addon := xtree_doc (XML_URI_GET ('', RS_LOCAL_ADDONS), 0, RS_LOCAL_ADDONS);
          local_addon := xslt ('http://local.virt/rdfxml2n3xml', local_addon);
        }
        mix := DAV_RDF_MERGE (std_schema, local_addon, null, -1);
      -- Composing best possible catname for schema URI.
      -- dbg_obj_princ ('SCHEMA META: ', xpath_eval ('/N3[@N3S=\044schema-uri]', mix, 0, vector (UNAME'schema-uri', schema_uri)));
      schema_catname := xpath_eval ('/N3[@N3S=\044schema-uri][@N3P="http://www.openlinksw.com/schemas/virtrdf#catName"]', mix, 1, vector (UNAME'schema-uri', schema_uri));
      if (schema_catname is not null)
        {
          schema_catname := replace (replace (cast (schema_catname as varchar), '#', '/') , '/', '-' || '-');
          if (not exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = schema_catname and RS_URI <> schema_uri))
            goto schema_catname_complete;
        }
      schema_catname := xpath_eval ('/N3[@N3S=\044schema-uri][@N3P="http://www.w3.org/2000/01/rdf-schema#label"]', mix, 1, vector (UNAME'schema-uri', schema_uri));
      if (schema_catname is not null)
        {
          schema_catname := replace (replace (cast (schema_catname as varchar), '#', '/') , '/', '-' || '-');
          if (not exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = schema_catname and RS_URI <> schema_uri))
            goto schema_catname_complete;
        }
      schema_catname := DAV_CROP_URI_TO_CATNAME (schema_uri);
      schema_catname := replace (schema_catname, '/', '-' || '-');
      if (not exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = schema_catname and RS_URI <> schema_uri))
        goto schema_catname_complete;
      schema_catname := replace (replace (schema_uri, '#', '/') , '/', '-' || '-');
      while (exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = schema_catname and RS_URI <> schema_uri))
        schema_catname := sprintf ('%s--%d', (replace (schema_uri, '#', '/') , '/', '-' || '-'), 10000 + rnd (90000));

schema_catname_complete:
      -- Composing best possible catnames for top properties.
      vectorbld_init (prop_catnames);
      prop_catnames_hash := dict_new ();
      prop_list := DAV_RDF_SCHEMA_N3_LIST_PROPERTIES (mix, NULL);
      foreach (varchar propname in prop_list) do
        {
          declare catname varchar;
          declare catid integer;
          catname := xpath_eval ('/N3[@N3S=\044propname][@N3P="http://www.openlinksw.com/schemas/virtrdf#catName"]', mix, 1, vector (UNAME'propname', propname));
          propname := cast (propname as varchar);
          if (catname is not null)
            {
              catname := replace (replace (cast (catname as varchar), '#', '/') , '/', '-' || '-');
              if (0 = dict_get (prop_catnames_hash, catname, 0))
                goto prop_catname_complete;
            }
          catname := DAV_CROP_URI_TO_CATNAME (propname);
          catname := replace (catname, '/', '-' || '-');
          if (0 = dict_get (prop_catnames_hash, catname, 0))
            goto prop_catname_complete;
          catname := replace (replace (propname, '#', '/') , '/', '-' || '-');
          while (dict_get (prop_catnames_hash, catname, 0))
            catname := sprintf ('%s--%d', replace (replace (propname, '#', '/') , '/', '-' || '-'), 10000 + rnd (90000));

prop_catname_complete:
          catid := coalesce ((select RPN_CATID from WS.WS.SYS_RDF_PROP_NAME where RPN_URI = propname));
          if (catid is null)
            {
              catid := WS.WS.GETID ('RPN');
              insert into WS.WS.SYS_RDF_PROP_NAME (RPN_URI, RPN_CATID) values (propname, catid);
            }
          vectorbld_acc (prop_catnames, propname, catname, catid, 0, 0, 0);
          dict_put (prop_catnames_hash, catname, catid);
        }
      vectorbld_final (prop_catnames);
      update WS.WS.SYS_RDF_SCHEMAS
      set
        RS_PRECOMPILED = mix,
        RS_COMPILATION_DATE = now (),
        RS_CATNAME = schema_catname,
        RS_PROP_CATNAMES = serialize (prop_catnames)
      where RS_URI = schema_uri;
      return mix;
    }
-- TODO: implement some guess for reading schemas
  return xtree_doc ('<stub/>');
}
;


create procedure
DAV_DEPRECATE_RDF_SCHEMA (in schema_uri varchar)
{
  update WS.WS.SYS_RDF_SCHEMAS set RS_DEPRECATED = 1 where RS_URI = schema_uri;
  if (exists (select top 1 1 from WS.WS.SYS_MIME_RDFS where MR_RDF_URI = schema_uri))
    {
      update WS.WS.SYS_MIME_RDFS set MR_DEPRECATED = 1 where MR_RDF_URI = schema_uri;
      return;
    }
--TBD: prematurely return if any property of the schema is used for any resources
  delete from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schema_uri and RS_LOCAL_ADDONS is null;
}
;

create procedure
DAV_REGISTER_MIME_TYPE (in m_ident varchar, in descr varchar, in dflt_ext varchar, in badmagic varchar, in mode varchar)
{
-- Argument mode is one of 'soft', 'into' or 'replacing'.
-- This adds a record into WS.WS.SYS_MIME_TYPES but it also can add an dflt_ext into WS.WS.SYS_DAV_RES_TYPES.
  mode := lower (mode);
  if (exists (select top 1 1 from WS.WS.SYS_MIME_TYPES where MT_IDENT = m_ident))
    {
      if ('into' = mode)
        signal ('23000', sprintf ('Uniqueness violation: MIME type ''%s'' is already registered', m_ident));
      else if ('replacing' = mode)
        insert replacing WS.WS.SYS_MIME_TYPES (MT_IDENT, MT_DESCRIPTION, MT_DEFAULT_EXT, MT_BADMAGIC_IDENT)
        values (m_ident, descr, dflt_ext, badmagic);
      else if ('soft' = mode)
        return;
    }
  else
    insert replacing WS.WS.SYS_MIME_TYPES (MT_IDENT, MT_DESCRIPTION, MT_DEFAULT_EXT, MT_BADMAGIC_IDENT)
    values (m_ident, descr, dflt_ext, badmagic);
  insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values (m_ident, dflt_ext);
}
;

create procedure
DAV_REGISTER_MIME_RDF (in m_ident varchar, in schema_uri varchar)
{
  insert replacing WS.WS.SYS_MIME_RDFS (MR_MIME_IDENT, MR_RDF_URI, MR_DEPRECATED)
  values (m_ident, schema_uri, 0);
}
;

create procedure
DAV_DEPRECATE_MIME_RDF (in m_ident varchar, in schema_uri varchar)
{
  update WS.WS.SYS_MIME_RDFS set MR_DEPRECATED = 1 where MR_MIME_IDENT = m_ident and MR_RDF_URI = schema_uri;
}
;

--!AWK PUBLIC
create function
DAV_RDF_PROP_SET (
    in path varchar,                    -- Path to the resource or collection
    in single_schema varchar,           -- Name of single RDF schema to filter out redundant records or NULL to compose any number of properties.
    in rdf any,                         -- RDF XML
    in auth_uname varchar := null,
    in auth_pwd varchar := null) returns integer
{
  return DAV_RDF_PROP_SET_INT (path, single_schema, rdf, auth_uname, auth_pwd);
}
;


--!AWK PUBLIC
create procedure
DAV_RDF_PROP_GET (
    in path varchar,                    -- Path to the resource or collection
    in single_schema varchar,           -- Name of single RDF schema to filter out redundant records or NULL to return all non-deprecated schemas associated in WS.WS.SYS_MIME_RDFS with the resource.
    in auth_uname varchar := null,
    in auth_pwd varchar := null) returns any
{
  declare st varchar;
  if ((path <> '') and (path[length(path)-1] = 47))
    st := 'C';
  else
    st := 'R';
  return DAV_RDF_PROP_GET_INT (DAV_SEARCH_ID (path, st), st, single_schema, 1, auth_uname, auth_pwd);
}
;


create function
DAV_RDF_PREPROCESS_RDFXML_SUB (inout n3_subj_dict any, in main_res nvarchar, in mode integer, inout firsttime_subj_list any) returns any
{
-- mode 0 = no nesting, 1 = extra level for nodeID resources, 2 = main_res is the described document.
  declare top_props, top_acc, top_head, top_tag any;
  declare firsttime_use integer;
  declare isdupe varchar;
  top_props := dict_get (n3_subj_dict, main_res, 0);
  xte_nodebld_init (top_acc);
  firsttime_use := position (main_res, firsttime_subj_list);
  if (firsttime_use > 0)
    {
      firsttime_subj_list [firsttime_use-1] := '';
      isdupe := null;
    }
  else
    isdupe := 'Y';
  if (mode = 2)
    top_tag := UNAME'virt:top-res';
  else
    top_tag := UNAME'virt:res';
  if (main_res like N'nodeID://%')
    {
      top_head := xte_head (top_tag, UNAME'N3S', main_res, UNAME'N3DUPE', isdupe);
    }
  else
    {
      top_head := xte_head (top_tag, UNAME'N3DUPE', isdupe);
      xte_nodebld_acc (top_acc, xte_node (xte_head (main_res)));
    }
  if (not (isinteger (top_props)))
    {
      if (isinteger (top_props[0])) -- trick, this means that this in a vectorbld, not a vector
        {
          vectorbld_final (top_props);
          dict_put (n3_subj_dict, main_res, top_props);
        }
      foreach (any n3 in top_props) do
        {
          declare obj_res nvarchar;
          declare obj_subtree any;
          obj_res := xpath_eval ('@N3O', n3);
          if (obj_res is null)
            {
              obj_subtree := xte_node (
                xte_head ( UNAME'virt:value',
                  UNAME'N3DT', xpath_eval ('@N3DT', n3),
                  UNAME'xml:lang', xpath_eval ('@xml:lang', n3)),
                xpath_eval ('node()', n3) );
            }
          else if (not (obj_res like N'nodeID://%'))
            obj_subtree := xte_node (xte_head (UNAME'virt:res'), xte_node (xte_head (obj_res)));
          else if (mode > 0)
            obj_subtree := DAV_RDF_PREPROCESS_RDFXML_SUB (n3_subj_dict, obj_res, 0, firsttime_subj_list);
          else
            obj_subtree := xte_node (xte_head (UNAME'virt:res', UNAME'N3S', obj_res));
          xte_nodebld_acc (top_acc,
            xte_node (
              xte_head (UNAME'virt:prop', UNAME'N3ID', xpath_eval('@N3ID', n3)),
              xte_node (xte_head (xpath_eval ('@N3P', n3))),
              obj_subtree ) );
        }
    }
  xte_nodebld_final (top_acc, top_head);
  return top_acc;
}
;


create function
DAV_RDF_PREPROCESS_RDFXML (in rdfxml any, in main_res nvarchar, in already_n3 integer := 0)
{
  declare n3xml, n3_list, n3_subj_dict, rdf_acc, subj_list, firsttime_subj_list any;
  declare tmp varchar;
  if (already_n3)
    n3xml := rdfxml;
  else
    n3xml := xslt ('http://local.virt/rdfxml2n3xml', rdfxml);
  n3_subj_dict := dict_new ();
  n3_list := xpath_eval ('/N3', n3xml, 0);
  foreach (any n3 in n3_list) do
    {
      declare pred_acc any;
      declare subj varchar;
      subj := xpath_eval ('@N3S', n3);
      pred_acc := dict_get (n3_subj_dict, subj, 0);
      if (isinteger (pred_acc))
        vectorbld_init (pred_acc);
      vectorbld_acc (pred_acc, n3);
      dict_put (n3_subj_dict, subj, pred_acc);
    }
  subj_list := dict_list_keys (n3_subj_dict, 0);
  firsttime_subj_list := subj_list;
  xte_nodebld_init (rdf_acc);
  xte_nodebld_acc (rdf_acc, DAV_RDF_PREPROCESS_RDFXML_SUB (n3_subj_dict, main_res, 2, firsttime_subj_list));
  --xte_nodebld_acc (rdf_acc, xte_node (xte_head (UNAME' comment'), 'Other named resources'));
  foreach (nvarchar subj in subj_list) do
    {
      if ((subj <> main_res) and not (subj like N'nodeID://%'))
        {
          xte_nodebld_acc (rdf_acc, DAV_RDF_PREPROCESS_RDFXML_SUB (n3_subj_dict, subj, 1, firsttime_subj_list));
        }
    }
  --xte_nodebld_acc (rdf_acc, xte_node (xte_head (UNAME' comment'), 'Trash'));
  foreach (nvarchar subj in subj_list) do
    {
      declare subj_props any;
      subj_props := dict_get (n3_subj_dict, subj, 0);
      if (isinteger (subj_props[0])) -- trick, this means that this in a vectorbld, not a vector
        xte_nodebld_acc (rdf_acc, DAV_RDF_PREPROCESS_RDFXML_SUB (n3_subj_dict, subj, 0, firsttime_subj_list));
    }
  xte_nodebld_final (rdf_acc, xte_head (UNAME'virt:rdf'));
  return rdf_acc;
}
;


create function
DAV_RDF_PROP_SET_INT (
    in path varchar,            -- Path to the resource or collection
    in single_schema varchar,   -- Name of single RDF schema to filter out redundant records or NULL to compose any number of properties.
    in rdf any,                 -- RDF XML
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in extern integer := 1,
    in check_locks any := 1,
    in overwrite integer := 0,
    in auth_uid integer := null
    ) returns integer
{
  declare n3xml, davtree any;
  declare top_subj nvarchar;
  if (single_schema is null)
    return -20;
  n3xml := xslt ('http://local.virt/rdfxml2n3xml', rdf);
  top_subj := null;
  if (xpath_eval ('/N3[@N3S=\044path]', n3xml, 1, vector (UNAME'path', path)) is null)
    top_subj := coalesce (xpath_eval ('/N3[1]/@N3S', n3xml), cast (path as nvarchar));
  else
    top_subj := cast (path as nvarchar);
  davtree := DAV_RDF_PREPROCESS_RDFXML (n3xml, top_subj, 1);
  return DAV_PROP_SET_INT (path, single_schema, davtree, auth_uname, auth_pwd, extern, check_locks, overwrite, auth_uid);
}
;


create procedure
DAV_RDF_PROP_GET_INT (
    in id any,
    in what char(0),
    in single_schema varchar,
    in extern integer := 1,
    in auth_uname varchar := null,
    in auth_pwd varchar := null,
    in auth_uid integer := null ) returns any
{
  declare davtree any;
  davtree := DAV_PROP_GET_INT (id, what, single_schema, extern, auth_uname, auth_pwd, auth_uid);
  if (isinteger (davtree))
    return davtree;
  if (isentity (davtree))
    return davtree;
  davtree := xml_tree_doc (deserialize (davtree));
  return davtree;
}
;


create function DAV_RDF_MERGE (
  in old_n3 any,
  in patch_n3 any,
  in sch_n3 any,
  in wipe_old_lists integer -- -1 = never, 0 = only when new nonempty list comes, 1 = all opt_lists listed in schema
  ) returns any
{
  declare n3_tmp_list, new_dict, card_dict, merge_acc any;
  if (old_n3 is null)
    return patch_n3;
  if (patch_n3 is null)
    return old_n3;
  card_dict := dict_new ();
  if (sch_n3 is not null)
    {
      n3_tmp_list := xpath_eval ('/N3[@N3P="http://local.virt/rdf#cardinality"]', sch_n3, 0);
      foreach (any n3 in n3_tmp_list) do
        dict_put (card_dict, xpath_eval ('@N3S', n3), cast (n3 as varchar));
    }
  new_dict := dict_new ();
  n3_tmp_list := xpath_eval ('/N3', patch_n3, 0);
  foreach (any n3 in n3_tmp_list) do
    {
      declare dkey, dacc any;
      dkey := xpath_eval ('vector (string (@N3S), string (@N3P), string(@xml:lang))', n3);
      dacc := dict_get (new_dict, dkey);
      if (dacc is null)
        vectorbld_init (dacc);
      vectorbld_acc (dacc, n3);
      dict_put (new_dict, dkey, dacc);
    }
  xte_nodebld_init (merge_acc);
  n3_tmp_list := xpath_eval ('/N3', old_n3, 0);
  foreach (any n3 in n3_tmp_list) do
    {
      declare pred, card nvarchar;
      declare dkey, new_set any;
      declare stale, is_single integer;
      dkey := xpath_eval ('vector (string (@N3S), string (@N3P), string(@xml:lang))', n3);
      pred := xpath_eval ('string (@N3P)', n3);
      card := dict_get (card_dict, pred);
      new_set := dict_get (new_dict, dkey);
      stale := 0;
      if (N'single' = card)
        is_single := 1;
      else if (N'list' = card)
        is_single := 0;
      else -- by default strings are assumed to be 'single' and nodes are probably 'list'
        is_single := xpath_eval ('not (exists (@N3O))', n3);
      if (is_single)
        {
          if (new_set is not null)
            stale := 10;
        }
      else
        {
          if (wipe_old_lists > 0)
            stale := 11;
          else if (new_set is not null)
            {
              if (wipe_old_lists = 0)
                stale := 12;
              else
                {
                  declare ctr integer;
                  for (ctr := new_set[0]; (ctr > 0) and not stale; ctr := ctr - 1) -- Trick: loop over internals of vectorbld structure
                    {
                      if (xpath_eval ('deep-equal (., \044old)', new_set[ctr], 1, vector ('old', n3)))
                        stale := 13;
                    }
                }
            }
        }
      -- dbg_obj_princ ('DAV_RDF_MERGE set stale ', stale, ' to (', dkey, ') because new_set is ', new_set);
      if (not stale)
        xte_nodebld_acc (merge_acc, n3);
    }
  n3_tmp_list := xpath_eval ('/N3', patch_n3, 0);
  foreach (any n3 in n3_tmp_list) do
    {
        xte_nodebld_acc (merge_acc, n3);
    }
  xte_nodebld_final (merge_acc, xte_head (UNAME' root'));
  return xml_tree_doc (merge_acc);
}
;


create function DAV_RDF_SUBTRACT (
  in old_n3 any,
  in sub_n3 any
  ) returns any
{
  declare n3_tmp_list, sub_dict, res_acc any;
  sub_dict := dict_new ();
  n3_tmp_list := xpath_eval ('/N3', sub_n3, 0);
  foreach (any n3 in n3_tmp_list) do
    {
      declare dkey, dacc any;
      dkey := xpath_eval ('vector (string (@N3S), string (@N3P), string (@N3O), string(@xml:lang))', n3);
      dacc := dict_get (sub_dict, dkey);
      if (dacc is null)
        vectorbld_init (dacc);
      vectorbld_acc (dacc, xpath_eval('node()[1]', n3));
      dict_put (sub_dict, dkey, dacc);
    }
  xte_nodebld_init (res_acc);
  n3_tmp_list := xpath_eval ('/N3', old_n3, 0);
  foreach (any n3 in n3_tmp_list) do
    {
      declare pred, card nvarchar;
      declare dkey, sub_set any;
      declare stale integer;
      dkey := xpath_eval ('vector (string (@N3S), string (@N3P), string (@N3O), string(@xml:lang))', n3);
      sub_set := dict_get (sub_dict, dkey);
      stale := 0;
      if (sub_set is not null)
        {
          declare obj_val any;
          declare ctr integer;
          obj_val := xpath_eval('node()[1]', n3);
          for (ctr := sub_set[0]; (ctr > 0) and not stale; ctr := ctr - 1) -- Trick: loop over internals of vectorbld structure
            {
              if (xpath_eval ('deep-equal (., \044old)', sub_set[ctr], 1, vector ('old', obj_val)))
                stale := 13;
            }
        }
      -- dbg_obj_princ ('DAV_RDF_SUBTRACT set stale ', stale, ' to (', dkey, ') because sub_set is ', sub_set);
      if (not stale)
        xte_nodebld_acc (res_acc, n3);
    }
  xte_nodebld_final (res_acc, xte_head (UNAME' root'));
  return xml_tree_doc (res_acc);
}
;


create trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_I after insert on WS.WS.SYS_DAV_RES order 20 referencing new as NEWR
{
  whenever sqlstate '*' goto no_op;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_I (', NEWR.RES_ID, NEWR.RES_PERMS, ')');
  if (length (NEWR.RES_PERMS) < 11)
    goto no_op;
  if (not (NEWR.RES_PERMS[10] in (ascii ('R'), ascii ('M'))))
    goto no_op;
  DAV_EXTRACT_AND_SAVE_RDF_INT (NEWR.RES_ID, NEWR.RES_NAME, NEWR.RES_TYPE, NEWR.RES_CONTENT);
no_op:
  -- dbg_obj_princ ('trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_I (', NEWR.RES_ID, NEWR.RES_PERMS, ') done');
  ;
}
;

create trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_U1 after update (RES_ID, RES_NAME, RES_TYPE, RES_PERMS) on WS.WS.SYS_DAV_RES order 20 referencing new as NEWR, old as OLDR
{
  -- dbg_obj_princ ('trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_U1 (', OLDR.RES_ID, '=->', NEWR.RES_ID, OLDR.RES_TYPE, '=->', NEWR.RES_TYPE, OLDR.RES_PERMS, '=->', NEWR.RES_PERMS, ')');
  if (length (NEWR.RES_PERMS) < 11)
    goto no_op;
  if (not (NEWR.RES_PERMS[10] in (ascii ('R'), ascii ('M'))))
    goto no_op;
  if ((OLDR.RES_ID <> NEWR.RES_ID) or (OLDR.RES_TYPE <> NEWR.RES_TYPE))
    goto ignore_old_res_perms;
  if ((OLDR.RES_NAME <> NEWR.RES_NAME) and (DAV_GUESS_MIME_TYPE_BY_NAME (OLDR.RES_NAME) <> DAV_GUESS_MIME_TYPE_BY_NAME (NEWR.RES_NAME)))
    goto ignore_old_res_perms;
  if ((length (OLDR.RES_PERMS) >= 11) and (OLDR.RES_PERMS[10] in (ascii ('R'), ascii ('M'))))
    goto no_op; -- Do nothing because no actual change happened.
ignore_old_res_perms:
  whenever sqlstate '*' goto no_op;
  DAV_EXTRACT_AND_SAVE_RDF_INT (NEWR.RES_ID, NEWR.RES_NAME, NEWR.RES_TYPE, NEWR.RES_CONTENT);
no_op:
  -- dbg_obj_princ ('trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_U1 (', OLDR.RES_ID, '=->', NEWR.RES_ID, OLDR.RES_TYPE, '=->', NEWR.RES_TYPE, OLDR.RES_PERMS, '=->', NEWR.RES_PERMS, ') done');
  ;
}
;

create trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_U2 after update (RES_ID, RES_NAME, RES_TYPE, RES_CONTENT) on WS.WS.SYS_DAV_RES order 21 referencing new as NEWR, old as OLDR
{
  -- dbg_obj_princ ('trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_U2 (', OLDR.RES_ID, '=->', NEWR.RES_ID, OLDR.RES_TYPE, '=->', NEWR.RES_TYPE, OLDR.RES_PERMS, '=->', NEWR.RES_PERMS, ')');
  if (length (NEWR.RES_PERMS) < 11)
    goto no_op;
  if (not (NEWR.RES_PERMS[10] in (ascii ('R'), ascii ('M'))))
    goto no_op;
  if ((OLDR.RES_ID <> NEWR.RES_ID) or (OLDR.RES_TYPE <> NEWR.RES_TYPE))
    goto no_op; -- Do nothing because data are extracted already by SYS_DAV_RES_CONTENT_EXTRACT_RDF_U1 trigger.
  if ((OLDR.RES_NAME <> NEWR.RES_NAME) and (DAV_GUESS_MIME_TYPE_BY_NAME (OLDR.RES_NAME) <> DAV_GUESS_MIME_TYPE_BY_NAME (NEWR.RES_NAME)))
    goto no_op; -- Do nothing because data are extracted already by SYS_DAV_RES_CONTENT_EXTRACT_RDF_U1 trigger.
  if (not ((length (OLDR.RES_PERMS) >= 11) and (OLDR.RES_PERMS[10] in (ascii ('R'), ascii ('M')))))
    goto no_op; -- Do nothing because data are extracted already by SYS_DAV_RES_CONTENT_EXTRACT_RDF_U1 trigger.
  whenever sqlstate '*' goto no_op;
  DAV_EXTRACT_AND_SAVE_RDF_INT (NEWR.RES_ID, NEWR.RES_NAME, NEWR.RES_TYPE, NEWR.RES_CONTENT);
no_op:
  -- dbg_obj_princ ('trigger SYS_DAV_RES_CONTENT_EXTRACT_RDF_U2 (', OLDR.RES_ID, '=->', NEWR.RES_ID, OLDR.RES_TYPE, '=->', NEWR.RES_TYPE, OLDR.RES_PERMS, '=->', NEWR.RES_PERMS, ') done');
  ;
}
;

create procedure DAV_EXTRACT_AND_SAVE_RDF (in resid integer)
{
  declare resname, restype varchar;
  declare rescontent any;
  -- dbg_obj_princ ('DAV_EXTRACT_AND_SAVE_RDF (', resid, ')');
  select RES_NAME, RES_TYPE, RES_CONTENT into resname, restype, rescontent from WS.WS.SYS_DAV_RES where RES_ID = resid;
  DAV_EXTRACT_AND_SAVE_RDF_INT (resid, resname, restype, rescontent);
  -- dbg_obj_princ ('DAV_EXTRACT_AND_SAVE_RDF (', resid, ') done');
}
;

create procedure DAV_GET_RES_TYPE_URI_BY_MIME_TYPE(in mime_type varchar) returns varchar
{
        if (mime_type = 'application/bpel+xml')
                return 'http://www.openlinksw.com/schemas/WSDL#';
        if (mime_type = 'application/doap+rdf')
                return 'http://www.openlinksw.com/schemas/doap#';
        if (mime_type = 'application/foaf+xml')
                return 'http://xmlns.com/foaf/0.1/';
        --if (mime_type = 'application/google-kinds+xml')
        --        return 'http://www.openlinksw.com/schemas/google-kinds#';
        if (mime_type = 'application/google-base+xml')
                return 'http://www.openlinksw.com/schemas/google-base#';
        if (mime_type = 'application/license')
                return 'http://www.openlinksw.com/schemas/opllic#';
        if (mime_type = 'application/mods+xml')
                return 'http://www.openlinksw.com/schemas/MODS#';
        if (mime_type = 'application/msexcel')
                return 'http://www.openlinksw.com/schemas/Office#';
        if (mime_type = 'application/mspowerpoint')
                return 'http://www.openlinksw.com/schemas/Office#';
        if (mime_type = 'application/msproject')
                return 'http://www.openlinksw.com/schemas/Office#';
        if (mime_type = 'application/msword')
                return 'http://www.openlinksw.com/schemas/Office#';
        if (mime_type = 'application/msword+xml')
                return 'http://www.openlinksw.com/schemas/Office#';
        if (mime_type = 'application/opml+xml')
                return 'http://www.openlinksw.com/schemas/OPML#';
        if (mime_type = 'application/pdf')
                return 'http://www.openlinksw.com/schemas/Office#';
        if (mime_type = 'application/rdf+xml')
                return 'http://www.openlinksw.com/schemas/RDF#';
        if (mime_type = 'application/rss+xml')
                return 'http://purl.org/rss/1.0/';
        if (mime_type = 'application/wsdl+xml')
                return 'http://www.openlinksw.com/schemas/WSDL#';
        if (mime_type = 'application/x-openlink-image')
                return 'http://www.openlinksw.com/schemas/Image#';
        if (mime_type = 'application/x-openlink-photo')
                return 'http://www.openlinksw.com/schemas/Photo#';
        if (mime_type = 'application/x-openlinksw-vad')
                return 'http://www.openlinksw.com/schemas/VAD#';
        if (mime_type = 'application/x-openlinksw-vsp')
                return 'http://www.openlinksw.com/schemas/VSPX#';
        if (mime_type = 'application/x-openlinksw-vspx+xml')
                return 'http://www.openlinksw.com/schemas/VSPX#';
        if (mime_type = 'application/xbel+xml')
                return 'http://www.python.org/topics/xml/xbel/';
        if (mime_type = 'application/xbrl+xml')
                return 'http://www.openlinksw.com/schemas/xbrl#';
        if (mime_type = 'application/xddl+xml')
                return 'http://www.openlinksw.com/schemas/XDDL#';
        if (mime_type = 'application/zip')
                return 'http://www.openlinksw.com/schemas/Archive#';
        if (mime_type = 'text/directory')
                return 'http://www.w3.org/2001/vcard-rdf/3.0#';
        if (mime_type = 'text/eml')
                return 'http://www.openlinksw.com/schemas/Email#';
        if (mime_type = 'text/html')
                return 'http://www.openlinksw.com/schemas/XHTML#';
        if (mime_type = 'text/wiki')
                return 'http://www.openlinksw.com/schemas/Wiki#';
	return NULL;
}
;

-- /* extracting metadata */
create procedure DAV_EXTRACT_AND_SAVE_RDF_INT (inout resid integer, inout resname varchar, in restype varchar, inout _rescontent any)
{
  declare rescontent any;
  rescontent := subseq (_rescontent, 0, 10000000-1);
  if ((length (_rescontent) < 262144) or (registry_get ('DAV_EXTRACT_RDF_ASYNC') <> '1'))
    {
      DAV_EXTRACT_AND_SAVE_RDF_INT2 (resid, resname, restype, rescontent);
    }
  else
    {
      declare aq any;
      aq := async_queue (1, 4);
      if (not isstring (rescontent))
	rescontent := cast (rescontent as varchar);
      aq_request (aq, 'DB.DBA.DAV_EXTRACT_AND_SAVE_RDF_INT2', vector (resid, resname, restype, rescontent));
    }
}
;

-- /* extracting metadata */
create procedure DAV_EXTRACT_AND_SAVE_RDF_INT2 (in resid integer, in resname varchar, in restype varchar, in rescontent any)
{
  -- dbg_obj_princ ('DAV_EXTRACT_AND_SAVE_RDF_INT (', resid, resname, restype, rescontent, ')');
  declare resttype, res_type_uri, full_name varchar;
  declare old_prop_id integer;
  declare html_start, full_xml, type_tree any;
  declare old_n3, addon_n3, spotlight_addon_n3 any;
  html_start := null;
  full_xml := null;
  spotlight_addon_n3 := null;
  addon_n3 := null;
  --if (restype is null)
  restype := DAV_GUESS_MIME_TYPE (resname, rescontent, html_start);
  -- dbg_obj_princ ('restype is ', restype);
  if (restype is not null)
    {
      declare p_name varchar;
      declare exit handler for sqlstate '*'
        {
          -- dbg_obj_princ ('Failed to call DB.DBA.DAV_EXTRACT_RDF_' || restype, '(', resname, ',... ): ', __SQL_STATE, __SQL_MESSAGE);
          goto addon_n3_set;
        };
        select RES_FULL_PATH into full_name from WS.WS.SYS_DAV_RES where RES_ID = resid;
        if (full_name is null)
            full_name := resname;
	p_name := 'DB.DBA.DAV_EXTRACT_RDF_' || restype;
	if (__proc_exists (p_name) is not null)
	  {
	    addon_n3 := call (p_name) (full_name, rescontent, html_start);
	    res_type_uri := DAV_GET_RES_TYPE_URI_BY_MIME_TYPE(restype);
	    if (res_type_uri is not null)
	      {
		type_tree := xtree_doc ('<N3 N3S="http://local.virt/this" N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type" N3O="' || res_type_uri || '"/>' );
		addon_n3 := DAV_RDF_MERGE (addon_n3, type_tree, null, 0);
	      }
	  }
          --dbg_obj_princ ('test:', addon_n3);
addon_n3_set: ;
    }
  -- dbg_obj_princ ('addon_n3 is', addon_n3);
  if (__proc_exists ('SPOTLIGHT_METADATA',2) is not null)
    spotlight_addon_n3 := DAV_EXTRACT_SPOTLIGHT (resname, rescontent);
  -- dbg_obj_princ ('spotlight_addon_n3 is', spotlight_addon_n3);
  if (addon_n3 is null and spotlight_addon_n3 is null)
    goto no_op;
  whenever not found goto no_old;
  select xml_tree_doc (deserialize (blob_to_string (PROP_VALUE))), PROP_ID
  into old_n3, old_prop_id
  from WS.WS.SYS_DAV_PROP
  where PROP_NAME = 'http://local.virt/DAV-RDF' and PROP_TYPE = 'R' and PROP_PARENT_ID = resid;
  old_n3 := xslt ('http://local.virt/davxml2n3xml', old_n3);
  --dbg_obj_princ ('old_n3 is', old_n3);
  if (addon_n3 is not null)
    old_n3 := DAV_RDF_MERGE (old_n3, addon_n3, null, 0);
  if (spotlight_addon_n3 is not null)
    old_n3 := DAV_RDF_MERGE (old_n3, spotlight_addon_n3, null, 0);
  --dbg_obj_princ ('will update: ', old_n3);
  update WS.WS.SYS_DAV_PROP set PROP_VALUE = serialize (DAV_RDF_PREPROCESS_RDFXML (old_n3, N'http://local.virt/this', 1))
  where PROP_ID = old_prop_id;
  goto no_op;

no_old:
  if (spotlight_addon_n3 is not null)
    {
      if (addon_n3 is not null)
        addon_n3 := DAV_RDF_MERGE (addon_n3, spotlight_addon_n3, null, 0);
      else
        addon_n3 := spotlight_addon_n3;
    }
  --dbg_obj_princ ('will insert: ', addon_n3);
  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE)
  values
    (WS.WS.GETID ('P'), 'http://local.virt/DAV-RDF', 'R', resid,
      serialize (DAV_RDF_PREPROCESS_RDFXML (addon_n3, N'http://local.virt/this', 1)) );
  goto no_op;

no_op:
  -- dbg_obj_princ ('DAV_EXTRACT_AND_SAVE_RDF_INT (', resid, resname, restype, rescontent, ') done');
  ;
}
;

create function DAV_HOME_DIR_UPDATE ()
{
  if (isstring (registry_get ('DAV_HOME_DIR_UPDATE')))
    return;

  for (select U_NAME from SYS_USERS where U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and U_NAME <> 'nobody' and U_NAME <> '__rdf_repl') do
    DAV_HOME_DIR_CREATE (U_NAME);

  registry_set ('DAV_HOME_DIR_UPDATE', 'done');
}
;

--!AFTER
DAV_HOME_DIR_UPDATE ()
;

create function DAV_NOBODY_DIR_UPDATE ()
{
  declare changed integer;

  if (isstring (registry_get ('DAV_NOBODY_DIR_UPDATE')))
    return;

  for (select COL_ID as cid, COL_OWNER as uid, COL_GROUP as gid from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) like '/DAV/home/nobody/%') do
  {
    changed := 0;
    if (uid = http_nobody_uid())
    {
      changed := 1;
      uid := http_dav_uid();
    }
    if (gid = http_nogroup_gid())
    {
      changed := 1;
      gid := http_admin_gid();
    }
    if (changed)
    {
      update WS.WS.SYS_DAV_COL
         set COL_OWNER = uid,
             COL_GROUP = gid
       where COL_ID = cid;
    }
  }

  for (select RES_ID as rid, RES_OWNER as uid, RES_GROUP as gid from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/home/nobody/%') do
  {
    changed := 0;
    if (uid = http_nobody_uid())
    {
      changed := 1;
      uid := http_dav_uid();
    }
    if (gid = http_nogroup_gid())
    {
      changed := 1;
      gid := http_admin_gid();
    }
    if (changed)
    {
      update WS.WS.SYS_DAV_RES
         set RES_OWNER = uid,
             RES_GROUP = gid
       where RES_ID = rid;
    }
  }

  registry_set ('DAV_NOBODY_DIR_UPDATE', 'done');
}
;

--!AFTER
DAV_NOBODY_DIR_UPDATE ()
;

-------------------------------------------------------------------------------
--
-- DAV QUEUE API
--
-------------------------------------------------------------------------------
create table WS.WS.SYS_DAV_QUEUE (
  DQ_ID integer identity,
  DQ_CLASS varchar not null,
  DQ_CLASS_ID any not null,
  DQ_PROCEDURE varchar not null,
  DQ_PARAMS any not null,
  DQ_PRIORITY integer default 0,
  DQ_STATE integer default 0,
  DQ_TS datetime not null,

  PRIMARY KEY (DQ_ID)
)
create index SYS_DAV_QUEUE_STATE ON WS.WS.SYS_DAV_QUEUE (DQ_STATE)
;

create table WS.WS.SYS_DAV_QUEUE_LCK (DQL_ID int primary key)
;

insert soft WS.WS.SYS_DAV_QUEUE_LCK values (0)
;

create procedure DB.DBA.DAV_QUEUE_ADD (
  in _class varchar,
  in _class_id any,
  in _procedure varchar,
  in _params any,
  in _priority integer := 0,
  in _insertMode integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.DAV_QUEUE_ADD (', _class, _class_id, _procedure, _params, _priority, ')');
  declare _id, _count integer;

  _count := 0;
  _id := (select TOP 1 DQ_ID from WS.WS.SYS_DAV_QUEUE where DQ_CLASS = _class and DQ_CLASS_ID = _class_id for update);
  if (isnull (_id) or _insertMode)
  {
    insert into WS.WS.SYS_DAV_QUEUE (DQ_CLASS, DQ_CLASS_ID, DQ_PROCEDURE, DQ_PARAMS, DQ_PRIORITY, DQ_TS)
      values (_class, _class_id, _procedure, _params, _priority, now ());

    _count := 1;
  }
  else
  {
    update WS.WS.SYS_DAV_QUEUE
       set DQ_PRIORITY = _priority,
           DQ_TS = now ()
     where DQ_ID = _id
       and DQ_PRIORITY < _priority;
  }
  commit work;

  return _count;
}
;

create procedure DB.DBA.DAV_QUEUE_UPDATE_STATE (
  in _queue_id integer,
  in _state integer := 1,
  in _commit integer := 1)
{
  update WS.WS.SYS_DAV_QUEUE
     set DQ_STATE = _state,
         DQ_TS = now ()
   where DQ_ID = _queue_id
     and ((DQ_STATE <> _state) or (DQ_TS < dateadd ('minute', -1, now())));

  if (_commit)
    commit work;
}
;

create procedure DB.DBA.DAV_QUEUE_UPDATE_TS (
  in _queue_id integer,
  in _commit integer := 1)
{
  DB.DBA.DAV_QUEUE_UPDATE_STATE (_queue_id, 1, _commit);
}
;

create procedure DB.DBA.DAV_QUEUE_UPDATE_FINAL (
  in _queue_id integer)
{
  delete from WS.WS.SYS_DAV_QUEUE where DQ_ID = _queue_id;
  commit work;
}
;

create procedure DB.DBA.DAV_QUEUE_CLEAR ()
{
  delete from WS.WS.SYS_DAV_QUEUE where DQ_STATE = 2;
  commit work;
}
;

create procedure DB.DBA.DAV_QUEUE_GET (
  in _count integer)
{
  declare dummy, items any;

  if (_count <= 0)
    return vector ();

  vectorbld_init (items);

  set isolation = 'serializable';

  select DQL_ID into dummy from WS.WS.SYS_DAV_QUEUE_LCK where DQL_ID = 0;
  for (select TOP (_count) DQ_ID, DQ_PROCEDURE, DQ_PARAMS
         from WS.WS.SYS_DAV_QUEUE
        where DQ_STATE = 0
        order by DQ_PRIORITY desc, DQ_TS) do
  {
    DB.DBA.DAV_QUEUE_UPDATE_STATE (DQ_ID, 1, 0);
    vectorbld_acc (items, vector (DQ_ID, DQ_PROCEDURE, DQ_PARAMS));
  }
  commit work;
  set isolation = 'committed';

  vectorbld_final (items);
  return items;
}
;

create procedure DB.DBA.DAV_QUEUE_ACTIVE ()
{
  declare retValue integer;
  declare dt datetime;
  declare dummy any;

  retValue := 0;
  if (is_atomic ())
  {
    retValue := 1;
  }
  else
  {
    set isolation = 'serializable';

    dt := dateadd ('minute', -5, now());
    select DQL_ID into dummy from WS.WS.SYS_DAV_QUEUE_LCK where DQL_ID = 0;
    update WS.WS.SYS_DAV_QUEUE
       set DQ_STATE = 0,
           DQ_TS    = now ()
     where DQ_STATE = 1
       and DQ_TS    < dt;

    retValue := coalesce ((select top 1 1 from WS.WS.SYS_DAV_QUEUE where DQ_STATE = 1), 0);
    commit work;

    set isolation = 'committed';
  }
  return retValue;
}
;

create procedure DB.DBA.DAV_QUEUE_INIT ()
{
  -- dbg_obj_princ ('DB.DBA.DAV_QUEUE_INIT ()');
  declare aq any;

  if (not DB.DBA.DAV_QUEUE_ACTIVE ())
  {
    set_user_id ('dba');
    aq := async_queue (1, 4);
    aq_request (aq, 'DB.DBA.DAV_QUEUE_RUN', vector (0));
  }
}
;

create procedure DB.DBA.DAV_QUEUE_RUN (
  in _notInit integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.DAV_QUEUE_RUN ()');
  declare N, L, waited, threads integer;
  declare retValue, error any;
  declare aq, item, items, threadsArray any;
  declare exit handler for sqlstate '*'
  {
    log_message (sprintf ('%s exit handler:\n %s', current_proc_name (), __SQL_MESSAGE));
    resignal;
  };

  set isolation = 'committed';
  if (_notInit and DB.DBA.DAV_QUEUE_ACTIVE ())
    return;

  aq := null;
  threads := atoi (coalesce (virtuoso_ini_item_value ('Parameters', 'AsyncQueueMaxThreads'), '10')) / 2;
  if (threads <= 0)
    threads := 1;

_new_batch:;
  items := DB.DBA.DAV_QUEUE_GET (threads);
  L := length (items);
  if (not L)
    goto _exit;


  if (isnull (aq))
  {
    if (L + 1 < threads)
    {
      threads := length (items) + 1;
    }
    aq := async_queue (threads, 4);
  }

  threadsArray := make_array (threads, 'any');
  for (N := 0; N < threads; N := N + 1)
  {
    if (N < L)
    {
      threadsArray[N] := aq_request (aq, items[N][1], vector_concat (vector (items[N][0]), items[N][2]));
    }
    else
    {
      threadsArray[N] := -1;
    }
  }

_again:;
  commit work;

  waited := 0;
  for (N := 0; N < threads; N := N + 1)
  {
    if (threadsArray[N] >= 0)
	  {
      error := 0;
	    retValue := aq_wait (aq, threadsArray[N], 0, error);
	    if (retValue = 100 or error = 100) -- done
        threadsArray[N] := -1;
    }
    if (threadsArray[N] < 0)
	  {
      item := DB.DBA.DAV_QUEUE_GET (1);
      if (length (item) = 1)
     	  threadsArray[N] := aq_request (aq, item[0][1], vector_concat (vector (item[0][0]), item[0][2]));
    }
    if (threadsArray[N] >= 0)
    {
      waited := 1;
    }
  }
  if (waited)
  {
    delay (1);
    goto _again;
  }

  goto _new_batch;

_exit:;
  DB.DBA.DAV_QUEUE_CLEAR ();
}
;

-------------------------------------------------------------------------------
--
-- DAV SCHEDULER
--
-------------------------------------------------------------------------------
create function DB.DBA.DAV_EXPIRE_SCHEDULER (
  in queue_id integer)
{
  -- dbg_obj_princ ('DB.DBA.DAV_EXPIRE_SCHEDULER (', queue_id, ')');
  declare _now, _today datetime;

  _now := curdatetime ();
  _today := cast (stringdate (sprintf ('%d.%d.%d', year (_now), month (_now), dayofmonth (_now))) as date);
  for (select PROP_TYPE, PROP_PARENT_ID from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:expireDate' and cast (PROP_VALUE as date) <= _today) do
  {
    DB.DBA.DAV_DELETE_INT (DB.DBA.DAV_SEARCH_PATH (PROP_PARENT_ID, PROP_TYPE), 1, null, null, 0);
    DB.DBA.DAV_QUEUE_UPDATE_TS (queue_id);
  }

  DB.DBA.DAV_QUEUE_UPDATE_FINAL (queue_id);
}
;

create procedure DB.DBA.DAV_SCHEDULER ()
{
  -- dbg_obj_princ ('DB.DBA.DAV_SCHEDULER');
  declare DETs any;

  set_user_id ('dba');

  -- Added expire date task
  DB.DBA.DAV_QUEUE_ADD ('EXPIRED', 0, 'DB.DBA.DAV_EXPIRE_SCHEDULER', vector ());

  DETs := DB.DBA.DAV_DET_SPECIAL ();
  foreach (any det in DETs) do
  {
    if (__proc_exists ('DB.DBA.' || det || '_DAV_SCHEDULER'))
      DB.DBA.DAV_QUEUE_ADD (det, 0, 'DB.DBA.' || det || '_DAV_SCHEDULER', vector (null));
  }
  DB.DBA.DAV_QUEUE_RUN ();
  return 1;
}
;

insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
  values('WebDAV Scheduler', now(), 'DB.DBA.DAV_SCHEDULER ()', 5)
;

-------------------------------------------------------------------------------
--
-- RDF SINK Update Internal Graph Name
--
-------------------------------------------------------------------------------
create procedure DB.DBA.DAV_RDF_SINK_UPDATE (
  in queue_id integer := null)
{
  -- dbg_obj_princ ('DB.DBA.DAV_RDF_SINK_UPDATE (', queue_id, ')');
  declare path, old_graph, new_graph varchar;
  declare old_mode int;

  if (registry_get ('__dav_rdf_sink_update') = '1')
    return;

  if (isnull (queue_id))
  {
    DB.DBA.DAV_QUEUE_ADD ('RDF_SINK', 0, 'DB.DBA.DAV_RDF_SINK_UPDATE', vector ());
    DB.DBA.DAV_QUEUE_INIT ();
    return;
  }

  old_mode := log_enable (3, 1);
  for (select PROP_PARENT_ID from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'C' and PROP_NAME = 'virt:rdfSink-rdf') do
  {
    path := DB.DBA.DAV_SEARCH_PATH (PROP_PARENT_ID, 'C');
    for (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like (path || '%')) do
    {
      old_graph := 'http://local.virt' || RES_FULL_PATH;
      new_graph := WS.WS.DAV_IRI (RES_FULL_PATH);
      SPARQL insert in graph ?:new_graph { ?s ?p ?o } where { graph `iri(?:old_graph)` { ?s ?p ?o } };
      SPARQL clear graph ?:old_graph;
    }
  }

  log_enable (old_mode, 1);
  registry_set ('__dav_rdf_sink_update', '1');
  DB.DBA.DAV_QUEUE_UPDATE_FINAL (queue_id);
}
;

--!AFTER
DB.DBA.DAV_RDF_SINK_UPDATE ()
;
