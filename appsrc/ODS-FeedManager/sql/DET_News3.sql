--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

create function "News3_FIXNAME" (in mailname any) returns varchar
{
  return replace(replace(replace (replace (replace (mailname, '/', '_'), '\\', '_'), ':', '_'), '+', '_'), '\"', '_') ;
}
;

create function "News3_COMPOSE_NAME" (in title varchar, in m_id int) returns varchar
{
  declare ctr, len integer;
  declare res varchar;
  if (title is null or trim(title) = '')
    title := '[No title]';
  res := sprintf ('%s - [%d]', title, m_id);
  return "News3_FIXNAME"(res);
}
;

create function "News3_GET_USER_ID" (in domain_id int) returns int
{
  declare user_id int;
  user_id := (select A.U_ID
  from SYS_USERS A,
       WA_MEMBER B,
       WA_INSTANCE C
 where B.WAM_USER = A.U_ID
   and B.WAM_MEMBER_TYPE = 1
   and B.WAM_INST = C.WAI_NAME
   and C.WAI_ID = domain_id);
   return user_id;
}
;

create function "News3_ACCESS_PARAMS" (in detcol_id any, out access varchar, out gid integer, out uid integer)
{
  declare access_tmp varchar;
  whenever not found goto ret;
  access := '000000000N';
  gid := http_nogroup_gid ();
  uid := http_nobody_uid ();
  if (isinteger (detcol_id))
  {
    select COL_PERMS, COL_GROUP, COL_OWNER into access_tmp, gid, uid from WS.WS.SYS_DAV_COL where COL_ID = detcol_id;
  }
  access[0] := access_tmp[0];
  access[3] := access_tmp[3];
  access[6] := access_tmp[6];
ret:
  ;
}
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "News3_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('News3_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, http_dav_uid(), ')');
  if (auth_uid < 0)
    return -12;
  if (not ('100' like req))
    return -13;
  if ((auth_uid <> id[3]) and (auth_uid <> http_dav_uid()))
  {
    -- dbg_obj_princ ('auth_uid is ', auth_uid, ', id[3] is ', id[3], ' mismatch');
    return -13;
  }
  -- dbg_obj_princ ('authenticated: auth_uid is ', auth_uid, ', id[3] is ', id[3], ', match');
  return auth_uid;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "News3_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare rc integer;
  declare puid, pgid integer;
  declare u_password, pperms varchar;
  declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'News3_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='News3'), '')
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
          a_uid := 0;
    a_gid := 0;
  }
    }
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return a_uid;
  return -13;

nf_col_or_res:
  return -1;
}
;


--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "News3_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('News3_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "News3_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "News3_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "News3_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "News3_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('News3_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "News3_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "News3_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('News3_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "News3_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "News3_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('News3_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "News3_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('News3_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "News3_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare fullpath, rightcol, resname varchar;
  declare access, title varchar;
  declare ownergid, owneruid integer;
  fullpath := '';
  "News3_ACCESS_PARAMS" (id[1], access, ownergid, owneruid);
  title := coalesce ((select EF_TITLE
      from ENEWS.WA.FEED A, ENEWS.WA.FEED_DOMAIN B,
       WA_MEMBER WAM, WA_INSTANCE WAI
      where
      B.EFD_FEED_ID = id[2] and
      A.EF_ID = id[2] and
      WAM.WAM_USER = owneruid and WAM.WAM_MEMBER_TYPE = 1 and WAM.WAM_INST = WAI.WAI_NAME and WAI.WAI_ID = B.EFD_DOMAIN_ID
   ));
  if (title is null)
    return -1;
  fullpath := concat(DAV_SEARCH_PATH (id[1], 'C'), title);
  if ('C' = what)
  {
    if (id[4] >= 0)
      return -1;
    declare maxrcvdate datetime;
    maxrcvdate := coalesce ((select max(EFI_LAST_UPDATE)
      from ENEWS.WA.FEED_ITEM
      where
      EFI_FEED_ID = id[2]),
      cast ('1980-01-01' as datetime) );
    return vector (fullpath || '/', 'C', 0, maxrcvdate,
      id, access, ownergid, owneruid, maxrcvdate, 'dav/unix-directory', "News3_FIXNAME" (title));
  }
  else
  {
    if (id[4] = -1)
    {
      declare maxrcvdate datetime;
      declare dlen int;
      dlen := 0;
      maxrcvdate := coalesce ((select max(EFI_LAST_UPDATE)
        from ENEWS.WA.FEED_ITEM
        where
        EFI_FEED_ID = id[2]),
        cast ('1980-01-01' as datetime) );
      dlen := 1024; -- length (DB.DBA.XML_URI_GET(id [2], ''));
      return vector (fullpath || '.xml', 'R', dlen, maxrcvdate,
        id, access, ownergid, owneruid, maxrcvdate, 'text/xml', "News3_FIXNAME" (title) || '.xml');
    }
    for (select "News3_COMPOSE_NAME" (EFI_TITLE, EFI_ID) as orig_mname,
      1024 as DSIZE, -- length (EFI_DESCRIPTION) as DSIZE,
      EFI_PUBLISH_DATE, EFI_LAST_UPDATE
      from ENEWS.WA.FEED_ITEM
      where
      EFI_ID = id[4] and EFI_FEED_ID = id[2])
    do
    {
      if (DAV_HIDE_ERROR (orig_mname) is null)
        return -1;
      return vector(fullpath || orig_mname || '.html', 'R', DSIZE, EFI_PUBLISH_DATE,
        id, access, ownergid, owneruid, EFI_LAST_UPDATE, 'text/html', orig_mname || '.html' );
    }
  }
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "News3_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  declare mdomain_id, muser_id, mfolder_id integer;
  declare mnamefmt varchar;
  declare top_davpath varchar;
  declare res, grand_res any;
  declare reslen integer;
  declare top_id any;
  declare what char (1);
  declare access varchar;
  declare ownergid, owneruid integer;
  mnamefmt := null;
  grand_res := vector();
  "News3_ACCESS_PARAMS" (detcol_id, access, ownergid, owneruid);
  if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
    what := 'C';
  else
    what := 'R';
  if (('C' = what) and (1 = length (path_parts)))
  {
    top_id := vector (UNAME'News3', detcol_id, null, owneruid, -1); -- may be a fake id because top_id[4] may be NULL
  }
  else
  {
    top_id := "News3_DAV_SEARCH_ID" (detcol_id, path_parts, what);
  }
  -- dbg_obj_princ ('found top_id ', top_id, ' of type ', what);
  if (DAV_HIDE_ERROR (top_id) is null)
  {
    -- dbg_obj_princ ('no top id - no items');
    return vector();
  }
  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
  {
    return vector ("News3_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
  }
  res := vector();
  reslen := 0;
  if (top_id[2] is null)
  {
    for select "News3_FIXNAME" (A.EF_TITLE) as orig_name, A.EF_ID as f_id
      from ENEWS.WA.FEED A, ENEWS.WA.FEED_DOMAIN B,
        WA_MEMBER WAM, WA_INSTANCE WAI
      where B.EFD_FEED_ID = A.EF_ID and
        WAM.WAM_USER = owneruid and WAM.WAM_MEMBER_TYPE = 1 and WAM.WAM_INST = WAI.WAI_NAME and WAI.WAI_ID = B.EFD_DOMAIN_ID
--      order by 1, 2 -- should be sorted by application!
    do
    {
      -- dbg_obj_princ ('about to put col to dir list: ', orig_name, ' for folder ', f_id, ' owned by ', owneruid);
      declare maxrcvdate datetime;
      maxrcvdate := coalesce ((select max(EFI_LAST_UPDATE)
        from ENEWS.WA.FEED_ITEM
        where
        EFI_FEED_ID = f_id),
        cast ('1980-01-01' as datetime) );
  --                                             0                                                1    2  3
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, maxrcvdate,
  --    4
        vector (UNAME'News3', detcol_id, f_id, owneruid, -1),
  --    5       6         7         8           9                     10
        access, ownergid, owneruid, maxrcvdate, 'dav/unix-directory', orig_name) ) );
    }
    for select "News3_FIXNAME" (A.EF_TITLE) as orig_name, A.EF_ID as f_id
      from ENEWS.WA.FEED A, ENEWS.WA.FEED_DOMAIN B,
        WA_MEMBER WAM, WA_INSTANCE WAI
      where B.EFD_FEED_ID = A.EF_ID and
--      order by 1, 2 -- should be sorted by application
        WAM.WAM_USER = owneruid and WAM.WAM_MEMBER_TYPE = 1 and WAM.WAM_INST = WAI.WAI_NAME and WAI.WAI_ID = B.EFD_DOMAIN_ID

    do
    {
      -- dbg_obj_princ ('about to put rss to dir list: ', orig_name, ' for folder ', f_id, ' owned by ', owneruid);
      declare maxrcvdate datetime;
      declare dlen int;
      maxrcvdate := coalesce ((select max(EFI_LAST_UPDATE)
        from ENEWS.WA.FEED_ITEM
        where
        EFI_FEED_ID = f_id),
        cast ('1980-01-01' as datetime) );

      dlen := 1024; --length (DB.DBA.XML_URI_GET(f_id, ''));
  --                                             0                                                   1    2     3
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '.xml', 'R', dlen, maxrcvdate,
  --    4
        vector (UNAME'News3', detcol_id, f_id, owneruid, -1),
  --    5       6         7         8           9           10
        access, ownergid, owneruid, maxrcvdate, 'text/xml', orig_name || '.xml') ) );
    }
  }
  grand_res := res;
-- retrieval of mails
  if (top_id[2] is null)
    goto end_of_mails; -- there are no mails in root.
  res := vector();
  reslen := 0;
  for
    select orig_mname, m_id, EFI_PUBLISH_DATE, DSIZE, EFI_LAST_UPDATE
    from (
      select "News3_COMPOSE_NAME" (A.EFI_TITLE, A.EFI_ID) as orig_mname,
        A.EFI_ID as m_id, EFI_PUBLISH_DATE,
          1024 as DSIZE, --length (A.EFI_DESCRIPTION) as DSIZE,
          EFI_LAST_UPDATE
      from ENEWS.WA.FEED_ITEM A, ENEWS.WA.FEED_DOMAIN B,
        WA_MEMBER WAM, WA_INSTANCE WAI
      where B.EFD_FEED_ID = top_id[2] and A.EFI_FEED_ID = top_id[2] and
        WAM.WAM_USER = owneruid and WAM.WAM_MEMBER_TYPE = 1 and WAM.WAM_INST = WAI.WAI_NAME and WAI.WAI_ID = B.EFD_DOMAIN_ID ) m1
    where orig_mname like name_mask
--    order by 1, 2 should be sorted by application!
  do
  {
    -- dbg_obj_princ ('About to put in dir list: ', orig_mname);
--                                             0                                                     1    2      3
    res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname) || '.html', 'R', DSIZE, EFI_PUBLISH_DATE,
--    4
      vector (UNAME'News3', detcol_id, top_id[2], owneruid, m_id),
--    5       6         7         8         9             10
      access, ownergid, owneruid, EFI_LAST_UPDATE, 'text/html', orig_mname || '.html' ) ) );
    reslen := reslen + 1;
  }
  grand_res := vector_concat (grand_res, res);
end_of_mails:
  return grand_res;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "News3_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "News3_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  -- dbg_obj_princ ('News3_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  if (path_parts[0] = '' or path_parts[0] is null)
    return -1;
  declare colpath, merged_fnameext, orig_fnameext varchar;
  declare orig_id, ctr, len integer;
  declare hitlist any;
  declare access varchar;
  declare ownergid, owneruid integer;
  "News3_ACCESS_PARAMS" (detcol_id, access, ownergid, owneruid);
  if (0 = length (path_parts))
  {
    if ('C' <> what)
    {
      -- dbg_obj_princ ('resource with empty path - no items');
      return -1;
    }
    return vector (UNAME'News3', detcol_id, null, owneruid, -1);
  }
  if ('' = path_parts[length (path_parts) - 1])
  {
    if ('C' <> what)
    {
      -- dbg_obj_princ ('resource without a name - no items');
      return -1;          
    }
  }
  else
  {
    if ('R' <> what)
    {
      -- dbg_obj_princ ('non-resource with a name - no items');
      return -1;
    }
  }
  len := length (path_parts) - 1;
  declare f_id, xml_file integer;
  -- dbg_obj_princ ('path_parts is ', path_parts);
  if (('R' = what) and (length (path_parts) = 1))
    f_id := coalesce ((select EF_ID
      from ENEWS.WA.FEED A, ENEWS.WA.FEED_DOMAIN B,
        WA_MEMBER WAM, WA_INSTANCE WAI
      where B.EFD_FEED_ID = A.EF_ID and
        WAM.WAM_USER = owneruid and WAM.WAM_MEMBER_TYPE = 1 and WAM.WAM_INST = WAI.WAI_NAME and WAI.WAI_ID = B.EFD_DOMAIN_ID and
      "News3_FIXNAME" (A.EF_TITLE) || '.xml' = path_parts[0]));
  else
    f_id := coalesce ((select EF_ID
      from ENEWS.WA.FEED A, ENEWS.WA.FEED_DOMAIN B,
        WA_MEMBER WAM, WA_INSTANCE WAI
      where B.EFD_FEED_ID = A.EF_ID and
        WAM.WAM_USER = owneruid and WAM.WAM_MEMBER_TYPE = 1 and WAM.WAM_INST = WAI.WAI_NAME and WAI.WAI_ID = B.EFD_DOMAIN_ID and
      "News3_FIXNAME" (A.EF_TITLE) = path_parts[0]));
  if (f_id is null)
    {
      -- dbg_obj_princ ('f_id is null');
      return -1;
    }
  if ('C' = what)
  {
    if (not exists (select 1 from ENEWS.WA.FEED_ITEM where EFI_FEED_ID = f_id))
      {
        -- dbg_obj_princ ('f_id is not in FEED_ITEM');
        return -1;
      }
    if ((path_parts[0] like '%.xml') or (path_parts[1] <> ''))
      {
        -- dbg_obj_princ ('invalid depth, no collections can have extension .xml or extra name.');
        return -1;
      }
    return vector (UNAME'News3', detcol_id, f_id, owneruid, -1);
  }
  if (what = 'R' and length (path_parts) = 1)
  {
    xml_file := (select EF_ID from ENEWS.WA.FEED where "News3_FIXNAME" (EF_TITLE) || '.xml' = path_parts[0]);
    return vector (UNAME'News3', detcol_id, xml_file, owneruid, -1);
  }
  for (select EFI_FEED_ID, EFI_ID from ENEWS.WA.FEED_ITEM
      where EFI_FEED_ID = f_id and
      "News3_COMPOSE_NAME" (EFI_TITLE, EFI_ID) || '.html' = path_parts[1])
  do
  {
    return vector (UNAME'News3', detcol_id, f_id, owneruid, EFI_ID);
  }
  return -1;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "News3_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('News3_DAV_SEARCH_PATH (', id, what, ')');
  return NULL;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "News3_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "News3_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "News3_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('News3_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare cont any;
  type := 'text/html';
  if (id[4] = -1)
  {
    declare hdr, ext_content any;
    declare new_tag, typef, newUri, oldUri varchar;
    type := 'text/xml';
    newUri := coalesce ((select EF_URI from ENEWS.WA.FEED where EF_ID = id[2]));
    if (newUri is null)
      return -1;
    again:
    oldUri := newUri;
    ext_content := http_get (newUri, hdr);
    if (hdr[0] not like 'HTTP/1._ 200 %')
    {
      if (hdr[0] like 'HTTP/1._ 30_ %')
      {
        newUri := http_request_header (hdr, 'Location');
        if (newUri <> oldUri)
          goto again;
      }
      signal('22023', trim(hdr[0], '\r\n'), 'EN000');
      return 0;
    }
    if ((content_mode = 0) or (content_mode = 2))
      content := ext_content;
    else if (content_mode = 1)
      http (ext_content, content);
    else if (content_mode = 3)
      http (ext_content);
--  content := DB.DBA.XML_URI_GET(id[2], '');
    return 0;
  }
  for (select EFI_DESCRIPTION from ENEWS.WA.FEED_ITEM
     where EFI_FEED_ID = id[2] and EFI_ID = id[4]) do
    {
      if (content_mode = 0)
        content := xpath_eval ('serialize (.)', EFI_DESCRIPTION);
      else if (content_mode = 1)
        http_value (EFI_DESCRIPTION, content);
      else if (content_mode = 2)
        content := EFI_DESCRIPTION;
      else if (content_mode = 3)
        http_value (EFI_DESCRIPTION);
      return 0;
    }
  return -1;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "News3_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "News3_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('News3_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "News3_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('News3_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "News3_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "News3_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('News3_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "News3_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('News3_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "News3_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('News3_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;


create procedure "News3_CF_PROPNAME_TO_COLNAME" (in prop varchar)
{
  return get_keyword (prop, vector (
        'http://purl.org/rss/1.0/title', 'CHANNEL_DETAILS.EF_TITLE',
        'http://purl.org/rss/1.0/link', 'CHANNEL_DETAILS.EF_URI',
        'http://purl.org/rss/1.0/lastBuildDate', 'cast (CHANNEL_DETAILS.EF_LAST_UPDATE as varchar)' ) );
}
;

create procedure "News3_CF_FEED_FROM_AND_WHERE" (in detcol_id integer, in cfc_id integer, inout rfc_list_cond any, inout filter_data any, in distexpn varchar, in auth_uid integer)
{
  declare where_clause, from_clause varchar;
  declare access varchar;
  declare ownergid, owneruid, proppos, filter_len, filter_idx integer;
  -- dbg_obj_princ ('News3_CF_FEED_FROM_AND_WHERE (', detcol_id, cfc_id, rfc_list_cond, filter_data, distexpn, auth_uid, ')');
  "News3_ACCESS_PARAMS" (detcol_id, access, ownergid, owneruid);
  -- dbg_obj_princ ('"News3_ACCESS_PARAMS" (', detcol_id, ',...) reports ', access, ownergid, owneruid );
  from_clause := '
  from
    (select distinct FD.EFD_FEED_ID
       from ENEWS.WA.FEED_DOMAIN as FD
         join WA_INSTANCE as WAI on (WAI.WAI_ID = FD.EFD_DOMAIN_ID)
         join WA_MEMBER as WAM on (WAM.WAM_INST=WAI.WAI_NAME)
       where WAM.WAM_USER = ' || cast (owneruid as varchar) || ' and WAM.WAM_MEMBER_TYPE = 1 )
    as DIST_CHANNELS
    join ENEWS.WA.FEED as CHANNEL_DETAILS on (DIST_CHANNELS.EFD_FEED_ID = CHANNEL_DETAILS.EF_ID)
';
  where_clause := '';
  filter_len := length (filter_data);
  for (filter_idx := 0; filter_idx < (filter_len - 3); filter_idx := filter_idx + 4)
    {
      declare mode integer;
      declare cmp_col, cmp_val varchar;
      cmp_col := "News3_CF_PROPNAME_TO_COLNAME" (filter_data [filter_idx]);
      cmp_val := filter_data [filter_idx + 2];
      -- dbg_obj_princ ('cmp_col=', cmp_col, ', cmp_val=', cmp_val);
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


create procedure "News3_CF_LIST_PROP_DISTVALS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, in schema_uri varchar, inout filter_data any, inout distval_dict any, in auth_uid integer)
{
  declare distprop, distexpn varchar;
  declare from_and_where_text, qry_text varchar;
  declare execstate, execmessage varchar;
  declare execmeta, execrows any;
  -- dbg_obj_princ ('News3_CF_LIST_PROP_DISTVALS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, distval_dict, auth_uid, ')');
  if (schema_uri = 'http://purl.org/rss/1.0/')
    { -- channel description
      distprop := filter_data[length (filter_data) - 2];
      distexpn := "News3_CF_PROPNAME_TO_COLNAME" (distprop);
      if (distexpn is null)
        {
          dict_put (distval_dict, '! empty !', 1);
          return;
        }
      from_and_where_text := News3_CF_FEED_FROM_AND_WHERE (detcol_id, cfc_id, rfc_list_cond, filter_data, distexpn, auth_uid);
      qry_text := 'select distinct ' || distexpn || from_and_where_text;
      execstate := '00000';
      execmessage := 'OK';
      -- dbg_obj_princ ('Will exec: ', qry_text);
      exec (qry_text,
        execstate, execmessage,
        vector (), 100000000, execmeta, execrows );
      -- dbg_obj_princ ('exec returns: ', execstate, execmessage, execrows);
      foreach (any execrow in execrows) do
        {
          dict_put (distval_dict, "CatFilter_ENCODE_CATVALUE" (execrow[0]), 1);
        }
      return;
    }
}
;

create function "News3_CF_GET_RDF_HITS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, in schema_uri varchar, inout filter_data any, in detcol_path varchar, in make_diritems integer, in auth_uid integer) returns any
{
  declare from_and_where_text, qry_text varchar;
  declare execstate, execmessage varchar;
  declare acc_len, acc_ctr integer;
  declare execmeta, acc any;
  declare access varchar;
  declare ownergid, owneruid integer;
  -- dbg_obj_princ ('\n\n\nNews3_CF_GET_RDF_HITS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ')');
  acc := vector ();
  acc_len := 0;
  if (schema_uri = 'http://purl.org/rss/1.0/')
    { -- channel description
      "News3_ACCESS_PARAMS" (detcol_id, access, ownergid, owneruid);
      from_and_where_text := News3_CF_FEED_FROM_AND_WHERE (detcol_id, cfc_id, rfc_list_cond, filter_data, 'CHANNEL_DETAILS.EF_ID', auth_uid);
      qry_text := 'select CHANNEL_DETAILS.EF_ID' || from_and_where_text;
      execstate := '00000';
      execmessage := 'OK';
      -- dbg_obj_princ ('Will exec: ', qry_text);
      exec (qry_text,
        execstate, execmessage,
        vector (), 100000000, execmeta, acc );
      -- dbg_obj_princ ('exec returns: ', execstate, execmessage, acc);
      acc_len := length (acc);
      acc_ctr := 0;
      while (acc_ctr < acc_len)
	{
	  declare r_id integer;
	  declare fullname varchar;
	  declare full_id, diritm any;
	  r_id := acc[acc_ctr][0];
	  full_id := vector (UNAME'News3', detcol_id, r_id, owneruid, -1);
	  if (make_diritems = 1)
	    {
	      diritm := "News3_DAV_DIR_SINGLE" (full_id, 'R', '(fake path)', auth_uid);
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
		      -- no need in acc_ctr := acc_ctr + 1;
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
    {
      acc := subseq (acc, 0, acc_len);
    }
  -- dbg_obj_princ ('News3_CF_GET_RDF_HITS_RES_IDS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ') returns ', acc);
  return acc;
}
;

create procedure "News3_RF_ID2SUFFIX" (in id any, in what char(1))
{
  if ((id[4] = -1) and (what='R'))
    {
      declare use_id integer;
      use_id :=
        coalesce ((
          select FD.EFD_ID
          from ENEWS.WA.FEED_DOMAIN as FD
            join WA_INSTANCE as WAI on (WAI.WAI_ID = FD.EFD_DOMAIN_ID)
            join WA_MEMBER as WAM on (WAM.WAM_INST=WAI.WAI_NAME)
          where WAM.WAM_USER = id[3] and WAM.WAM_MEMBER_TYPE = 1 and FD.EFD_FEED_ID = id[2] ));
      if (use_id is null)
        {
          use_id := sequence_next ('ENEWS.WA.FEED_DOMAIN.EFD_ID') + 1;
          update ENEWS.WA.FEED_DOMAIN set EFD_ID = use_id
          where EFD_FEED_ID = id[2] and
            EFD_DOMAIN_ID in (
              select WAI.WAI_ID from WA_INSTANCE as WAI
              join WA_MEMBER as WAM on (WAM.WAM_INST=WAI.WAI_NAME)
              where WAM.WAM_USER = id[3] and WAM.WAM_MEMBER_TYPE = 1 );
        }
      return sprintf ('News3Feed-%d-%d', id[1], use_id);
    }
  signal ('OBLOM', 'News3_RF_ID2SUFFIX supports only feeds for a while');
}
;

create procedure "News3Feed_RF_SUFFIX2ID" (in suffix varchar, in what char(1))
{
  declare pairs any;
  declare r_id integer;
  declare detcol_id, use_id, owneruid integer;
  pairs := regexp_parse ('^([1-9][0-9]*)-([1-9][0-9]*)\044', suffix, 0);
  if (pairs is null)
    {
      -- dbg_obj_princ ('News3Feed_RF_SUFFIX2ID (', suffix, what, ') failed to parse the argument');
      ;
    }
  detcol_id := cast (subseq (suffix, pairs[2], pairs[3]) as integer);
  whenever not found goto oblom;
  select FD.EFD_FEED_ID, WAM.WAM_USER into r_id, owneruid
    from ENEWS.WA.FEED_DOMAIN as FD
    join WA_INSTANCE as WAI on (WAI.WAI_ID = FD.EFD_DOMAIN_ID)
    join WA_MEMBER as WAM on (WAM.WAM_INST=WAI.WAI_NAME)
  where FD.EFD_ID = cast (subseq (suffix, pairs[4], pairs[5]) as integer);
  return vector (UNAME'News3', detcol_id, r_id, owneruid, -1);
oblom:
  return NULL;
}
;
