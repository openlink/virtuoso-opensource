--  
--  $Id$
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

use DB
;

create function "nntp_FIXNAME" (in mailname any) returns varchar
{
  return
    replace (
      replace (
        replace (
          replace (
            replace (
              replace (
                replace (
                  replace (mailname, '/', '_'), '\\', '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_'), '\'', '_');
}
;

create procedure "nntp_PARSE_SERVER_NAME"(in fullname varchar, out server varchar, out port integer)
{
  declare pos integer;
  pos := strrchr(fullname, '_');
  server := subseq(fullname, 0, pos);
  port := atoi(subseq(fullname, pos + 1));
}
;

create function "nntpf_display_message_text2"(in _text varchar, in ct varchar := 'text/plain', in ses any)
{
   _text := nntpf_replace_at (_text);
   if (ct = 'text/plain')
     http ('<pre class="artbody"> <br/>', ses);
   else
     http ('<div class="artbody">', ses);

   http (_text, ses);

   if (ct = 'text/plain')
     http ('</pre>', ses);
   else
     http ('</div>', ses);
}
;

create function "nntp_COMPOSE_HTML_NAME" (in title varchar, in id varchar) returns varchar
{
  if (title is null or title = '')
    return "nntp_FIXNAME"(sprintf('%s', id));
  return "nntp_FIXNAME"(sprintf('%s %s', title, id));
}
;

create function "nntp_COMPOSE_COMMENTS_NAME" (in title varchar, in id varchar) returns varchar
{
  if (title is null or title = '')
    return "nntp_FIXNAME"(sprintf('%s Comments', id));
  return "nntp_FIXNAME"(sprintf('%s %s Comments', title, id));
}
;

create procedure "nntp_PARSE_HTML_NAME" (in fullname varchar, out title varchar, out id varchar)
{
  declare pos integer;
  pos := strrchr(fullname, ' ');
  if (pos is NULL)
    id := fullname;
  else
  {
    title := subseq(fullname, 0, pos);
    id := subseq(fullname, pos + 1);
  }
}
;

create procedure "nntp_PARSE_COMMENTS_NAME" (in fullname varchar, out title varchar, out id varchar)
{
  declare pos integer;
  declare real_part, comment_part varchar;
  pos := strrchr(fullname, ' ');
  comment_part := subseq(fullname, pos + 1);  
  if (comment_part = 'Comments')
  {
    real_part := subseq(fullname, 0, pos);
    pos := strrchr(real_part, ' ');
    if (pos is NULL)
      id := real_part;
    else
    {
      title := subseq(real_part, 0, pos);
      id := subseq(real_part, pos + 1);
    }    
  }
}
;

create function "nntp_CHANNEL_DESC_NAMES" () returns any
{
  return vector ('atom.xml', 'foaf.xml', 'index.ocs', 'index.opml', 'index.rdf', 'rss.xml', 'xbel.xml');
}
;

create function "nntp_ACCESS_PARAMS" (in detcol_id any, out access varchar, out gid integer, out uid integer)
{
  declare access_tmp varchar;
  whenever not found goto ret;
  access := '100000000NN';
  gid := http_nogroup_gid ();
  uid := http_nobody_uid ();
  if (isinteger (detcol_id))
  {
    select COL_PERMS, COL_GROUP, COL_OWNER into access_tmp, gid, uid from WS.WS.SYS_DAV_COL where COL_ID = detcol_id;
  }
  access[0] := access_tmp[0];
  access[1] := access_tmp[1];
--  access[3] := access_tmp[3];
ret:
  ;
}
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "nntp_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('nntp_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, http_dav_uid(), ')');
  if (auth_uid < 0)
    return -12;
  if (not ('110' like req))
  {
    --dbg_obj_princ ('a_uid2 is ', auth_uid, ', id[3] is ', id[3], ' mismatch');
    return -13;
  }
  if ((auth_uid <> id[3]) and (auth_uid <> http_dav_uid()))
  {
    --dbg_obj_princ ('a_uid is ', auth_uid, ', id[3] is ', id[3], ' mismatch');
    return -13;
  }
  return auth_uid;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "nntp_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare rc integer;
  declare puid, pgid, ruid, rgid integer;
  declare u_password, pperms varchar;
  -- anon are never allowed for mails! declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  -- allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null)
    {
      -- if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
      rc := WS.WS.GET_DAV_AUTH (a_lines, 0, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
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
  if ((a_uid <> id[3]) and (a_uid <> http_dav_uid()))
    {
      -- dbg_obj_princ ('a_uid is ', a_uid, ', id[3] is ', id[3], ' mismatch');
      return -13;
    }
  if (not ('100' like req))
    return -13;
  return a_uid;

nf_col_or_res:
  return -1;
}
;


--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "nntp_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('nntp_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "nntp_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "nntp_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "nntp_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "nntp_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('nntp_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "nntp_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', content, type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "nntp_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('nntp_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "nntp_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "nntp_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('nntp_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "nntp_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('nntp_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "nntp_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  declare mnamefmt varchar;
  declare folder_id, server_id varchar;
  declare fullpath, rightcol, resname varchar;
  declare maxrcvdate datetime;
  declare colname varchar;
  --dbg_obj_princ ('nntp_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  server_id := cast(id[4] as varchar);
  folder_id := cast(id[5] as varchar);
  fullpath := '';
  rightcol := NULL;  
  if (atoi(folder_id) = 0)
  {
    maxrcvdate := (select FTHR_DATE from DB.DBA.NNFE_THR where FTHR_MESS_ID = folder_id);
    while (folder_id is not null)
    {
      colname := (select "nntp_COMPOSE_COMMENTS_NAME"(FTHR_SUBJ, FTHR_MESS_ID)
        from DB.DBA.NNFE_THR where FTHR_MESS_ID = folder_id);
      if (DAV_HIDE_ERROR (colname) is null)
        return -1;
      if (rightcol is null)
        rightcol := colname;
      fullpath := colname || '/' || fullpath;
      folder_id := coalesce ((select FTHR_REFER from DB.DBA.NNFE_THR where FTHR_MESS_ID = folder_id));
    }
    folder_id := cast((select FTHR_GROUP from DB.DBA.NNFE_THR where FTHR_MESS_ID = id[5]) as varchar);    
  }
  if ((server_id = '0' or server_id is null) and folder_id is not null)
  {
    server_id := folder_id;
    folder_id := null;
  }
  if (folder_id is not null)
  {
    if (maxrcvdate is null)
      maxrcvdate := (select NG_UP_TIME from DB.DBA.NEWS_GROUPS where NG_GROUP = folder_id);
    colname := (select "nntp_FIXNAME"(NG_NAME) from DB.DBA.NEWS_GROUPS where NG_GROUP = atoi(folder_id));
    if (DAV_HIDE_ERROR (colname) is null)
      return -1;
    if (rightcol is null)
      rightcol := colname;
    fullpath := colname || '/' || fullpath;
  }
  if (server_id is not null)
  {
    if (maxrcvdate is null)
      maxrcvdate := coalesce ((select max(NG_UP_TIME) from DB.DBA.NEWS_GROUPS where NG_SERVER = atoi(folder_id)),
      cast ('1980-01-01' as datetime) );
    colname := (select "nntp_FIXNAME" (concat(NS_SERVER, ':', cast(NS_PORT as varchar)))
      from DB.DBA.NEWS_SERVERS where NS_ID = atoi(server_id));
    if (DAV_HIDE_ERROR (colname) is null)
      return -1;
    if (rightcol is null)
      rightcol := colname;
    fullpath := colname || '/' || fullpath;
  }
  fullpath := DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), fullpath);
  if ('C' = what)
  {
    if (id[6] >= 0)
      return -1;
    return vector (fullpath, 'C', 0, maxrcvdate,
      id, '100000000NN', 0, id[3], maxrcvdate, 'dav/unix-directory', rightcol );
  }
  for select "nntp_COMPOSE_HTML_NAME"(FTHR_SUBJ, FTHR_MESS_ID) as orig_mname,
        FTHR_MESS_ID as m_id, FTHR_DATE
      from DB.DBA.NNFE_THR
      where FTHR_MESS_ID = id[6]
    do
    {
      return vector (fullpath || orig_mname, 'R', 1024, FTHR_DATE,
        id, 
        '100000000NN', 0, id[3], FTHR_DATE, 'text/plain', orig_mname);
    }
  return -1;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "nntp_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  --dbg_obj_princ ('nntp_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  declare mgroup_id, muser_id integer;
  declare mfolder_id, mserver_id varchar;
  declare top_davpath varchar;
  declare res, grand_res any;
  declare top_id, descnames any;
  declare reslen integer;
  declare what char (1);
  declare access varchar;
  declare ownergid, owner_uid, dn_ctr, dn_count integer;
  "nntp_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
  if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
    what := 'C';
  else
    what := 'R';
  mgroup_id := 0;
  mserver_id := NULL;
  mfolder_id := NULL;
  grand_res := vector();
  if ('C' = what and 1 = length(path_parts))
    top_id := vector (UNAME'nntp', detcol_id, mgroup_id, owner_uid, null, null, -1); -- may be a fake id because top_id[4] may be NULL
  else
    top_id := "nntp_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, mgroup_id, muser_id, mserver_id, mfolder_id);
  if (DAV_HIDE_ERROR (top_id) is null)
    return vector();
  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
    return vector ("nntp_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
  res := vector();
  reslen := 0;
  if ('C' = what and 1 = length(path_parts))
  {
    for select "nntp_FIXNAME" (concat(NS_SERVER, ':', cast(NS_PORT as varchar))) as orig_name, cast(NS_ID as varchar) as f_id
      from DB.DBA.NEWS_SERVERS
      order by 1, 2
    do
    {
      declare maxrcvdate datetime;
      maxrcvdate := coalesce((select max(NG_UP_TIME)
        from DB.DBA.NEWS_GROUPS
        where
        NG_SERVER = atoi(f_id)),
        cast('1980-01-01' as datetime));
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, maxrcvdate,
        vector (UNAME'nntp', detcol_id, mgroup_id, owner_uid, mserver_id, f_id, -1),
        '100000000NN', ownergid, owner_uid, maxrcvdate, 'dav/unix-directory', orig_name) ) );
    }
    grand_res := res;
  }
  if ('C' = what and length(path_parts) = 2)
  {
    for select "nntp_FIXNAME" (NG_NAME) as orig_name, NG_UP_TIME as maxrcvdate, cast(NG_GROUP as varchar) as f_id
      from DB.DBA.NEWS_GROUPS
      where NG_SERVER = top_id[5]
      order by 1, 2
    do
    { 
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, maxrcvdate,
        vector (UNAME'nntp', detcol_id, mgroup_id, owner_uid, mserver_id, f_id, -1),
        '100000000NN', ownergid, owner_uid, maxrcvdate, 'dav/unix-directory', orig_name) ) );
    }
    grand_res := res;    
  }
  if ('C' = what and length(path_parts) > 2)
  {
    for select distinct FTHR_REFER as f_ref
      from DB.DBA.NNFE_THR
      where FTHR_GROUP = atoi(top_id[5]) and FTHR_REFER is not null
    do
    {
      for select "nntp_COMPOSE_COMMENTS_NAME"(FTHR_SUBJ, FTHR_MESS_ID) as orig_name, FTHR_MESS_ID as f_id, FTHR_DATE
        from DB.DBA.NNFE_THR
        where f_ref = FTHR_MESS_ID and FTHR_TOP = 1 and FTHR_SUBJ like name_mask
        order by 1, 2
      do
      {
        res := vector_concat(res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, FTHR_DATE,
          vector (UNAME'nntp', detcol_id, mgroup_id, owner_uid,  mserver_id, f_id, -1),
          '100000000NN', ownergid, owner_uid, FTHR_DATE, 'dav/unix-directory', orig_name) ) );
        reslen := reslen + 1;
      }
    }
    for select distinct FTHR_MESS_ID as f_ref2
      from DB.DBA.NNFE_THR
      where FTHR_REFER = top_id[5]
    do
    {
      for select "nntp_COMPOSE_COMMENTS_NAME"(FTHR_SUBJ, FTHR_MESS_ID) as orig_name,
          FTHR_MESS_ID as f_id, FTHR_DATE
        from DB.DBA.NNFE_THR
        where f_ref2 = FTHR_MESS_ID
          and FTHR_SUBJ like name_mask
        order by 1, 2
      do
      {
        res := vector_concat(res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, FTHR_DATE,
          vector (UNAME'nntp', detcol_id, mgroup_id, owner_uid,  mserver_id, f_id, -1),
          '100000000NN', ownergid, owner_uid, FTHR_DATE, 'dav/unix-directory', orig_name) ) );
        reslen := reslen + 1;
      }
    }
    grand_res := res;
    reslen := 0;
    res := vector();
    for select "nntp_COMPOSE_HTML_NAME"(FTHR_SUBJ, FTHR_MESS_ID) as orig_mname,
        FTHR_MESS_ID as m_id, FTHR_DATE
      from DB.DBA.NNFE_THR
      where ((FTHR_GROUP = atoi(top_id[5]) and FTHR_TOP=1) or FTHR_REFER = top_id[5])
        and FTHR_SUBJ like name_mask
      order by 1, 2
    do
    {
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, FTHR_DATE,
        vector (UNAME'nntp', detcol_id, mgroup_id, owner_uid, mserver_id, top_id[5], m_id),
        '100000000NN', ownergid, owner_uid, FTHR_DATE, 'text/plain', orig_mname) ) );
      reslen := reslen + 1;
    }
    grand_res := vector_concat (grand_res, res);
  }
finalize_res:
  return grand_res;
}
;
                         
--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "nntp_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path any, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector();
}
;

create function "nntp_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout group_id integer, inout muser_id integer, inout mserver_id varchar, inout mfolder_id varchar) returns any
{
  declare colpath, merged_fnameext, orig_fnameext varchar;
  declare orig_id varchar;
  declare ctr, len integer;
  declare hitlist any;
  declare access varchar;
  declare ownergid, owner_uid integer;
  --dbg_obj_princ ('nntp_DAV_SEARCH_ID_IMPL (', detcol_id, path_parts, what, group_id, muser_id, mfolder_id, ')');
  "nntp_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
  if (0 = length(path_parts))
  {
    if ('C' <> what)
    {
      return -1;
    }
    return vector (UNAME'nntp', detcol_id, group_id, owner_uid, mserver_id, mfolder_id, -1);
  }
  if ('' = path_parts[length(path_parts) - 1])
  {
    if ('C' <> what)
    {
      return -1;
    }
  }
  else
  {
    if ('R' <> what)
    {
      return -1;
    }
  }
  len := length (path_parts) - 1;
  ctr := 0;
  while (ctr < len)
  {
    if (ctr = 0)
    {
      hitlist := vector ();
      for select NS_ID
        from DB.DBA.NEWS_SERVERS
        where "nntp_FIXNAME"(concat(NS_SERVER, ':', cast(NS_PORT as varchar))) = path_parts[ctr]
      do 
      {
        hitlist := vector_concat (hitlist, vector (NS_ID));
      }
      if (length (hitlist) <> 1)
        return -1;
      mfolder_id := cast(hitlist[0] as varchar);
      if (len > 1)
        mserver_id := cast(hitlist[0] as varchar);
    }
    if (ctr = 1)
    {
      hitlist := vector ();
      for select NG_GROUP
        from DB.DBA.NEWS_GROUPS
        where "nntp_FIXNAME"(NG_NAME) = path_parts[ctr]
      do 
      {
        hitlist := vector_concat (hitlist, vector (NG_GROUP));
      }
      if (length (hitlist) <> 1)
        return -1;
      mfolder_id := cast(hitlist[0] as varchar);
    }
    if (ctr > 1)
    {
      hitlist := vector ();
      for select FTHR_MESS_ID from DB.DBA.NNFE_THR
        where "nntp_COMPOSE_COMMENTS_NAME"(FTHR_SUBJ, FTHR_MESS_ID) = path_parts[ctr]
      do 
      {
        hitlist := vector_concat (hitlist, vector (FTHR_MESS_ID));
      }
      if (length (hitlist) <> 1)
        return -1;
      mfolder_id := cast(hitlist[0] as varchar);
    }
    ctr := ctr + 1;
  }
  if ('C' = what)
    return vector (UNAME'nntp', detcol_id, group_id, owner_uid, mserver_id, mfolder_id, -1);

  len := length (path_parts);
  while (ctr < len)
  {
    hitlist := vector ();
    for select FTHR_MESS_ID
      from DB.DBA.NNFE_THR
      where (FTHR_GROUP = atoi(mfolder_id) or (FTHR_REFER = mfolder_id)) and
      ("nntp_COMPOSE_HTML_NAME" (FTHR_SUBJ, FTHR_MESS_ID) = path_parts[ctr])
    do 
    {
      hitlist := vector_concat (hitlist, vector (FTHR_MESS_ID));
    }
    if (length (hitlist) <> 1)
      return -1;
    ctr := ctr + 1;
  }  
  return vector (UNAME'nntp', detcol_id, group_id, owner_uid, mserver_id, mfolder_id, hitlist[0]);
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "nntp_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare mgroup_id,  muser_id integer;
  declare mfolder_id, mserver_id varchar;
  --dbg_obj_princ ('nntp_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  return "nntp_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, mgroup_id, muser_id, mserver_id, mfolder_id);
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "nntp_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  --dbg_obj_princ ('nntp_DAV_SEARCH_PATH (', id, what, ')');
  return NULL;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "nntp_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "nntp_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "nntp_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  --dbg_obj_princ ('nntp_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare str_out any;
  str_out := string_output();
  content := '';
  if (id[6] is not null)
  {
    type := 'text/plain';
    
   declare _date, _from, _subj, _grps, _print_body, d_name varchar;
   declare _body, _head, parsed_message any;
   declare idx integer;

   set isolation='committed';

   select NM_HEAD, blob_to_string (NM_BODY)
     into parsed_message, _body
     from DB.DBA.NEWS_MSG
     where NM_ID = id[6];

   for (select NM_GROUP
          from DB.DBA.NEWS_MULTI_MSG
          where NM_KEY_ID = id[6]) do
     {
        if (ns_rest_rate_read (NM_GROUP) > 0)
          {
             content := '<h3>Excessive read detected, please try again later.</h3>';
             return 0;
          }
     }

   if (__tag (parsed_message) <> 193)
     parsed_message := mime_tree (_body);

   _head := parsed_message[0];
   _subj := coalesce (get_keyword_ucase ('Subject', _head), '');
   _from := coalesce (get_keyword_ucase ('From', _head), '');
   _grps := coalesce (get_keyword_ucase ('Newsgroups', _head), '');
   _date := coalesce (get_keyword_ucase ('Date', _head), '');

   nntpf_decode_subj (_subj);

   nntpf_decode_subj (_from);
   _from := nntpf_replace_at (_from);

   http ('<div class="artheaders">', str_out);
   http (sprintf ('<span class="header">From:</span>%V<br/>', _from), str_out);
   http (sprintf ('<span class="header">Subject:</span>%s<br/>', _subj), str_out);
   http (sprintf ('<span class="header">Newsgroups:</span>%s<br/>', _grps), str_out);
   http (sprintf ('<span class="header">Date:</span>%s<br/>', _date), str_out);
   http ('</div><br/>', str_out);


   --if (parsed_message[2] <> 0)
   --  return nntpf_display_article_multi_part (parsed_message, _body, id, sid);

   --nntpf_display_message_reply (sid, id);

    _print_body := subseq (_body, parsed_message[1][0], parsed_message[1][1]);
    if (length (_print_body) > 3)
       _print_body := subseq (_print_body, 0, (length (_print_body) - 3));

   -- CLEAR THIS

   parsed_message := nntpf_get_mess_attachments (_print_body, 0);

   _print_body := parsed_message[0];
   
   "nntpf_display_message_text2" (_print_body, get_keyword_ucase ('Content-Type', _head), str_out);

   http ('<br/>', str_out);
   idx := 1;
   while (idx < length (parsed_message))
     {
        d_name := parsed_message[idx];
        http (sprintf ('Download attachment : <a href="http://%s/INLINEFILE/%s?VSP=/nntpf/attachment.vsp&id=%U&part=%i&fn=%s"> %s </a><br/>',
                       nntpf_get_host (vector ()),
                       d_name,
                       encode_base64 (id),
                       idx,
                       d_name,
                       d_name), str_out);

        if (d_name like '%.jpg' or d_name like '%.gif')
          {
             http (sprintf ('<img alt="attachment" src="http://%s/INLINEFILE/%s?VSP=/nntpf/attachment.vsp&id=%U&part=%i&fn=%s">',
                   nntpf_get_host (vector()),
                   d_name,
                   encode_base64 (id),
                   idx,
                   d_name), str_out);
             http ('<br/><br/><br/>', str_out);
          }

        idx := idx + 1;
     }
  }
  content := string_output_string(str_out);
  return 0;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "nntp_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "nntp_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('nntp_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "nntp_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('nntp_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "nntp_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "nntp_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('nntp_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "nntp_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('nntp_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "nntp_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('nntp_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;
