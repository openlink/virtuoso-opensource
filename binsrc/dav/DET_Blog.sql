--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

EXEC_STMT ('create view BLOG.DBA.SYS_BLOG_OWNERS (U_ID, U_NAME, U_FULL_NAME, U_GROUP,
  WAI_ID, WAI_NAME, BI_BLOG_ID )
as select U_ID, U_NAME, U_FULL_NAME, U_GROUP, WAI_ID, WAI_NAME, BI_BLOG_ID
  from DB.DBA.SYS_USERS
  join WA_MEMBER on (WAM_USER = U_ID)
  join WA_INSTANCE on (WAI_NAME = WAM_INST)
  join BLOG.DBA.SYS_BLOG_INFO on (BI_WAI_NAME = WAI_NAME)
  where U_IS_ROLE = 0 and WAM_MEMBER_TYPE = 1 and WAI_TYPE_NAME = \'WEBLOG2\'', 0)
;

create function "Blog_FIXNAME" (in mailname any) returns varchar
{
  return
    replace (
      replace (
        replace (
          replace (
            replace (
              replace (
                replace (mailname, '/', '_'), '\\', '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_'); --"
}
;

create function "Blog_COMPOSE_HTML_NAME" (in title varchar, in id varchar) returns varchar
{
  declare ctr, len integer;
  declare res varchar;
  if (title is null or title = '')
    return sprintf ('[%s].html', id);
  return sprintf ('%s [%s].html', "Blog_FIXNAME"(title), id);
}
;

create function "Blog_COMPOSE_COMMENTS_NAME" (in title varchar, in id varchar) returns varchar
{
  declare ctr, len integer;
  declare res varchar;
  if (title is null or title = '')
    return sprintf ('[%s] Comments', id);
  return sprintf ('%s [%s] Comments', "Blog_FIXNAME"(title), id);
}
;

create procedure "Blog_PARSE_HTML_NAME" (in fullname varchar, out title_pattern varchar, out id varchar)
{
  declare split any;
  title_pattern := null;
  id := null;
  split := regexp_parse ('^([^[]*)\\[([A-Za-z0-9_.-]*)\\]\\.html\044', fullname, 0);
  if (split is null)
    {
      split := regexp_parse ('^([^[]*)\\.html\044', fullname, 0);
      if (split is null)
        return;
      id := null;
    }
  else
    id := subseq (fullname, split[4], split[5]);
  title_pattern := subseq (fullname, split[2], split[3]);
  if (title_pattern <> '')
    title_pattern := subseq (title_pattern, 0, length (title_pattern) - 1);
}
;

create procedure "Blog_PARSE_COMMENTS_NAME" (in fullname varchar, out title_pattern varchar, out id varchar)
{
  declare split any;
  title_pattern := null;
  id := null;
  split := regexp_parse ('^([^[]*)\\[([A-Za-z0-9_.-]*)\\] Comments\044', fullname, 0);
  if (split is null)
    return;
  id := subseq (fullname, split[4], split[5]);
  title_pattern := subseq (fullname, split[2], split[3]);
  if (title_pattern <> '')
    title_pattern := subseq (title_pattern, 0, length (title_pattern) - 1);
}
;

create function "Blog_CHANNEL_DESC_NAMES" () returns any
{
  return vector ('atom.xml', 'index.ocs', 'index.opml', 'index.rdf', 'rss.xml', 'xbel.xml');
}
;

create function "Blog_GET_USER_ID" (in domain_id int) returns int
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

create function "Blog_ACCESS_PARAMS" (in detcol_id any, out access varchar, out gid integer, out uid integer)
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
  access[1] := access_tmp[1];
--  access[3] := access_tmp[3];
ret:
  ;
}
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "Blog_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Blog_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, http_dav_uid(), ')');
  if (auth_uid < 0)
    return -12;
  if (not ('110' like req))
  {
    return -13;
  }
  if ((auth_uid <> id[3]) and (auth_uid <> http_dav_uid()))
  {
    -- dbg_obj_princ ('a_uid is ', auth_uid, ', id[3] is ', id[3], ' mismatch');
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
create function "Blog_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
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
      where G_NAME = 'Blog_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='Blog'), '')
      ), puid+1);
  pperms := '110100100NN';
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
create function "Blog_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('Blog_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "Blog_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "Blog_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "Blog_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "Blog_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('Blog_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "Blog_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', content, type, permissions, uid, gid, auth_uid, ')');
  declare post_title, post_title_pattern, post_id, comment_name, comment_name_pattern, comment_id, blog_id varchar;
  declare res_depth, rc int;
  whenever not found goto nf;
  res_depth := length (path_parts);
  if (res_depth < 2)
    return -40;
  if (res_depth > 3)
    return -40;
  if (res_depth = 2) -- Posts.
  {
    "Blog_PARSE_HTML_NAME" (path_parts[1], post_title_pattern, post_id);
    if (post_title_pattern is null)
      return -40;
    if (post_id is null)
      return -40; -- TBD: fix this by adding an ability of upload with no specified post id.
    select cast (C.B_TITLE as varchar), C.B_BLOG_ID into post_title, blog_id
      from BLOG.DBA.SYS_BLOG_INFO B, BLOG.DBA.SYS_BLOGS C
      where B.BI_WAI_NAME = path_parts[0] and B.BI_BLOG_ID = C.B_BLOG_ID and
      C.B_POST_ID = post_id;
    if (not (coalesce (post_title, '') like post_title_pattern))
      return -40; -- Id does not match an existing title.
    declare exit handler for sqlstate '*'
    {
      goto nf; -- TBD: fix this by adding an ability of upload with specified post id.
    };
    update BLOG.DBA.SYS_BLOGS set B_CONTENT = content where B_POST_ID = post_id and B_BLOG_ID = blog_id;
    return vector (UNAME_BLOG(), detcol_id, blog_id, uid, post_id, null);
  }
  if (res_depth = 3)
  {
    "Blog_PARSE_COMMENT_NAME" (path_parts[1], post_title_pattern, post_id);
    if (post_title_pattern is null)
      return -40;
    if (post_id is null)
      return -40;
    "Blog_PARSE_HTML_NAME" (path_parts[2], comment_name_pattern, comment_id);
    if (comment_name_pattern is null)
      return -40;
    if (comment_id is null)
      return -40; -- TBD: fix this by adding an ability of upload with no specified comment id.
    select cast (C.B_TITLE as varchar), C.B_BLOG_ID, D.BM_NAME into post_title, blog_id, comment_name
      from BLOG.DBA.SYS_BLOG_INFO B, BLOG.DBA.SYS_BLOGS C, BLOG.DBA.BLOG_COMMENTS D
      where B.BI_WAI_NAME = path_parts[0] and B.BI_BLOG_ID = C.B_BLOG_ID and
      C.B_BLOG_ID = D.BM_BLOG_ID and D.BM_POST_ID = C.B_POST_ID and C.B_POST_ID = post_id and D.BM_ID = comment_id;
    if (not (coalesce (post_title, '') like post_title_pattern))
      return -40; -- post id does not match an existing title.
    if (not (coalesce (comment_name, '') like comment_name_pattern))
      return -40; -- comment id does not match an existing name.
    declare exit handler for sqlstate '*'
    {
      goto nf;
    };
    update BLOG.DBA.BLOG_COMMENTS set BM_COMMENT = content where BM_POST_ID = post_id and BM_BLOG_ID = blog_id and BM_ID  = comment_id;
    return vector(UNAME_BLOG(), detcol_id, blog_id, uid, atoi(post_id), comment_id);
  }
  nf:;
  return -1;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "Blog_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('Blog_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "Blog_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "Blog_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Blog_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "Blog_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Blog_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Blog_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare fullpath, rightcol, resname varchar;
  declare access, title, title2 varchar;
  declare ownergid, owner_uid integer;
  fullpath := '';
  "Blog_ACCESS_PARAMS" (id[1], access, ownergid, owner_uid);
  title := coalesce ((select "Blog_FIXNAME" (WAI_NAME)
      from BLOG.DBA.SYS_BLOG_OWNERS
      where U_ID = owner_uid and BI_BLOG_ID = id[2]));
  if (title is null)
    return -1;
  fullpath := concat(DAV_SEARCH_PATH (id[1], 'C'), title);
  if ('C' = what)
    {
      declare maxrcvdate datetime;
      if (id[5] is not null)
        return -1;
      if (id[4] is not null)
        {
          whenever not found goto no_comments;
          select
            cast (SB.B_TITLE as varchar),
            (select max (BC.BM_TS)
              from BLOG.DBA.BLOG_COMMENTS BC
              where BC.BM_BLOG_ID = SB.B_BLOG_ID and BC.BM_POST_ID = SB.B_POST_ID )
          into title2, maxrcvdate
          from BLOG.DBA.SYS_BLOGS SB
          where SB.B_BLOG_ID = id[2] and SB.B_POST_ID = id[4];
          if (maxrcvdate is null)
            goto no_comments;
          title2 := "Blog_COMPOSE_COMMENTS_NAME" (title2, cast (id[4] as varchar));
          return vector (fullpath || '/' || title2 || '/', 'C', 0, maxrcvdate,
            id,
            --access,
            '100000000NN',
            ownergid, owner_uid, maxrcvdate, 'dav/unix-directory', title2);
no_comments:
          return -1;
        }
      maxrcvdate := coalesce (
        (select max(B_TS) from BLOG.DBA.SYS_BLOGS where B_BLOG_ID = id[2]),
        cast ('1980-01-01' as datetime));
      return vector (fullpath || '/', 'C', 0, maxrcvdate,
        id,
        --access,
        '100000000NN',
        ownergid, owner_uid, maxrcvdate, 'dav/unix-directory', title);
    }
-- The rest is for resources.
  if (id[4] is null) -- special resource for whole channel
    {
      if (position (id[5], "Blog_CHANNEL_DESC_NAMES" ()) = 0)
        return -1;
      return vector (fullpath || '/' || id[5], 'R', 1024, now(),
        id,
        --access,
        '100000000N',
        ownergid, owner_uid, now(), 'text/xml', id[5]);
    }
  if (id[5] is null) -- blog post;
    {
      for select "Blog_COMPOSE_HTML_NAME" (B_TITLE, B_POST_ID) as post_name,
        length(B_CONTENT) as DSIZE, B_TS, B_MODIFIED
      from BLOG.DBA.SYS_BLOGS SB
      where
        SB.B_POST_ID = id[4] and SB.B_BLOG_ID = id[2]
      do
        {
          return vector(fullpath || '/' || post_name, 'R', DSIZE, B_TS,
            id,
            --access,
            '110000000N',
            ownergid, owner_uid, B_MODIFIED, 'text/html', post_name );
        }
      return -1;
    }
  else -- blog comment
    {
      for select
        "Blog_COMPOSE_COMMENTS_NAME" (B_TITLE, B_POST_ID) as orig_mname,
        length(B_CONTENT) as DSIZE, B_TS, B_MODIFIED
      from BLOG.DBA.SYS_BLOGS SB
      where
        SB.B_POST_ID = id[4] and SB.B_BLOG_ID = id[2]
      do
        {
          return vector(fullpath || '/' || orig_mname, 'R', DSIZE, B_TS,
            id,
            --access,
            '110000000NN',
            ownergid, owner_uid, B_MODIFIED, 'text/html', orig_mname );
        }


      for select "Blog_COMPOSE_HTML_NAME" (D.BM_NAME, cast(D.BM_ID as varchar)) as comment_name,
         D.BM_TS as BM_TS, length(D.BM_COMMENT) as DSIZE
      from BLOG.DBA.BLOG_COMMENTS D
      where D.BM_BLOG_ID = id[2] and D.BM_POST_ID = id[4] and D.BM_ID = id[5]
      do
      {
        return vector (DAV_CONCAT_PATH (fullpath, comment_name), 'R', DSIZE, BM_TS,
          id,
          '110000000NN', ownergid, owner_uid, BM_TS, 'text/html', comment_name );
      }
      return -1;
    }
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Blog_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  declare mdomain_id, muser_id, mfolder_id integer;
  declare mnamefmt varchar;
  declare top_davpath varchar;
  declare res any;
  declare top_id, descnames any;
  declare what char (1);
  declare access varchar;
  declare ownergid, owner_uid, dn_ctr, dn_count integer;
  mnamefmt := null;
  vectorbld_init (res);
  "Blog_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
  if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
    what := 'C';
  else
    what := 'R';
  if ('C' = what and 1 = length(path_parts))
    top_id := vector (UNAME_BLOG(), detcol_id, null, owner_uid, null, null); -- may be a fake id because top_id[4] may be NULL
  else
    top_id := "Blog_DAV_SEARCH_ID" (detcol_id, path_parts, what);
  if (DAV_HIDE_ERROR (top_id) is null)
    {
      return vector();
    }
  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
    {
      return vector ("Blog_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
    }
  if (top_id[2] is null)
    {
      for select WAI_NAME as wai_orig_name, "Blog_FIXNAME" (WAI_NAME) as wai_fixed_name, WAI_ID as id, BI_BLOG_ID as blog_id
        from BLOG.DBA.SYS_BLOG_OWNERS
        where U_ID = owner_uid
      do
        {
          declare maxrcvdate datetime;
          maxrcvdate := coalesce (
            (select max(B_TS) from BLOG.DBA.SYS_BLOGS SB where SB.B_BLOG_ID = blog_id),
            cast ('1980-01-01' as datetime));;
          vectorbld_acc (res, vector (DAV_CONCAT_PATH (top_davpath, wai_fixed_name) || '/', 'C', 0, maxrcvdate,
            vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, null, null),
            access, ownergid, owner_uid, maxrcvdate, 'dav/unix-directory', wai_fixed_name) );
        }
      goto finalize_res;
    }
  if (top_id[4] is null)
    {
      for select
         "Blog_COMPOSE_HTML_NAME" (B_TITLE, B_POST_ID) as post_name,
         "Blog_COMPOSE_COMMENTS_NAME" (B_TITLE, B_POST_ID) as comments_name,
         B_BLOG_ID, B_POST_ID as m_id, B_TS, length(B_CONTENT) as DSIZE, B_MODIFIED as B_MODIFIED
         from BLOG.DBA.SYS_BLOGS
         where B_BLOG_ID = top_id[2]
      do
        {
          if (post_name like name_mask)
            vectorbld_acc (res, vector (DAV_CONCAT_PATH (top_davpath, post_name), 'R', DSIZE, B_TS,
                vector (UNAME_BLOG(), detcol_id, top_id[2], owner_uid, m_id, null),
                access, ownergid, owner_uid, B_MODIFIED, 'text/html', post_name ) );
          if (exists (select top 1 1 from BLOG.DBA.BLOG_COMMENTS where BM_POST_ID = m_id and BM_BLOG_ID = top_id[2]))
            {
              vectorbld_acc (res, vector (DAV_CONCAT_PATH (top_davpath, comments_name) || '/', 'C', 0, B_TS,
                vector (UNAME_BLOG(), detcol_id, top_id[2], owner_uid, m_id, null),
                access, ownergid, owner_uid, B_MODIFIED, 'dav/unix-directory', comments_name) );
            }
        }
      descnames := "Blog_CHANNEL_DESC_NAMES"();
      dn_count := length (descnames);
      for (dn_ctr := 0; dn_ctr < dn_count; dn_ctr := dn_ctr + 1)
        {
          declare dname varchar;
          dname := descnames[dn_ctr];
          vectorbld_acc (res, vector(DAV_CONCAT_PATH(top_davpath, dname), 'R', 1024, now(),
              vector(UNAME_BLOG(), detcol_id, top_id[2], owner_uid, null, dname),
              access, ownergid, owner_uid, now(), 'text/xml', dname ) );
        }
    }
  else
    {
      for select orig_mname, DSIZE, BM_TS, BM_ID
        from (select "Blog_COMPOSE_HTML_NAME" (BM_NAME, cast(BM_ID as varchar)) as orig_mname, BM_ID,
            BM_TS, length (BM_COMMENT) as DSIZE
          from BLOG.DBA.BLOG_COMMENTS
          where BM_BLOG_ID = top_id[2] and BM_POST_ID = top_id[4]) m1
        where orig_mname like name_mask
      do
        {
          vectorbld_acc (res, vector (DAV_CONCAT_PATH(top_davpath, orig_mname), 'R', DSIZE, BM_TS,
            vector (UNAME_BLOG(), detcol_id, top_id[2], owner_uid, top_id[4], BM_ID),
            access, ownergid, owner_uid, BM_TS, 'text/html', orig_mname ) );
        }
    }
finalize_res:
  vectorbld_final (res);
  return res;
}
;


create procedure "Blog_POST_DAV_FC_PRED_METAS" (inout pred_metas any)
{
  pred_metas := vector (
    'B_BLOG_ID',                vector ('SYS_BLOGS'     , 0, 'varchar'  , 'B_BLOG_ID'   ),
    'B_POST_ID',                vector ('SYS_BLOGS'     , 0, 'varchar'  , 'B_POST_ID'   ),
    'RES_ID',                   vector ('SYS_BLOGS'     , 0, 'any'      , 'vector (UNAME_BLOG(), B_BLOG_ID, U_ID, B_POST_ID, null)'     ),
    'RES_ID_SERIALIZED',        vector ('SYS_BLOGS'     , 0, 'varchar'  , 'serialize (vector (UNAME_BLOG(), B_BLOG_ID, U_ID, B_POST_ID, null))' ),
    'RES_NAME',                 vector ('SYS_BLOGS'             , 0, 'varchar'  , '"Blog_COMPOSE_HTML_NAME" (B_TITLE, B_POST_ID)'       ),
    'RES_FULL_PATH',            vector ('SYS_BLOGS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, "Blog_FIXNAME" (WAI_NAME)), ''/'', "Blog_COMPOSE_HTML_NAME" (B_TITLE, B_POST_ID))'       ),
    'RES_TYPE',                 vector ('SYS_BLOGS'     , 0, 'varchar'  , '(''text/plain'')'    ),
    'RES_OWNER_ID',             vector ('SYS_BLOG_OWNERS'       , 0, 'integer'  , 'U_ID'        ),
    'RES_OWNER_NAME',           vector ('SYS_BLOG_OWNERS'       , 0, 'varchar'  , 'U_NAME'      ),
    'RES_GROUP_ID',             vector ('SYS_BLOGS'     , 0, 'integer'  , 'http_nogroup_gid()'  ),
    'RES_GROUP_NAME',           vector ('SYS_BLOGS'     , 0, 'varchar'  , '(''nogroup'')'       ),
    'RES_COL_FULL_PATH',        vector ('SYS_BLOGS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, "Blog_FIXNAME" (WAI_NAME)), ''/'')'      ),
    'RES_COL_NAME',             vector ('SYS_BLOGS'     , 0, 'varchar'  , '"Blog_FIXNAME" (WAI_NAME)'   ),
--    'RES_COL_ID',             vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_COL'     ),
    'RES_CR_TIME',              vector ('SYS_BLOGS'     , 0, 'datetime' , 'B_TS'        ),
    'RES_MOD_TIME',             vector ('SYS_BLOGS'     , 0, 'datetime' , 'B_MODIFIED'  ),
    'RES_PERMS',                vector ('SYS_BLOGS'     , 0, 'varchar'  , '(''110000000RR'')'   ),
    'RES_CONTENT',              vector ('SYS_BLOGS'     , 0, 'text'     , 'B_CONTENT'   ),
    'PROP_NAME',                vector ('SYS_BLOGS'     , 0, 'varchar'  , '(''Content'')'       ),
    'PROP_VALUE',               vector ('SYS_BLOGS'     , 1, 'text'     , 'B_CONTENT'   ),
    'RES_TAGS',                 vector ('SYS_BLOGS'     , 0, 'varchar'  , '('''')'      ), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',          vector ('SYS_BLOGS'     , 0, 'varchar'  , '('''')'      ),
    'RES_PRIVATE_TAGS',         vector ('SYS_BLOGS'     , 0, 'varchar'  , '('''')'      ),
    'RDF_PROP',                 vector ('SYS_BLOGS'     , 1, 'varchar'  , NULL  ),
    'RDF_VALUE',                vector ('SYS_BLOGS'     , 2, 'XML'      , NULL  ),
    'RDF_OBJ_VALUE',            vector ('SYS_BLOGS'     , 3, 'XML'      , NULL  )
    );
}
;

create procedure "Blog_POST_DAV_FC_TABLE_METAS" (inout table_metas any)
{
  table_metas := vector (
    'SYS_BLOGS'         , vector (      '\n  inner join BLOG.DBA.SYS_BLOGS as ^{alias}^ on ((^{alias}^.B_BLOG_ID = _top.B_BLOG_ID) and (^{alias}^.B_POST_ID = _top.B_POST_ID)^{andpredicates}^)'        ,
                                        '\n  exists (select 1 from BLOG.DBA.SYS_BLOGS as ^{alias}^ where (^{alias}^.B_BLOG_ID = _top.B_BLOG_ID) and (^{alias}^.B_POST_ID = _top.B_POST_ID)^{andpredicates}^)'   ,
                                                'B_CONTENT'     , 'B_CONTENT'   , '[__quiet] /' ),
    'SYS_BLOG_OWNERS'   , vector (      ''      ,
                                        ''      ,
                                                NULL            , NULL          , NULL          )
--    'SYS_BLOG_OWNERS' , vector (      '\n  left outer join BLOG.DBA.SYS_BLOG_OWNERS as ^{alias}^ on ((^{alias}^.BI_BLOG_ID = _top.B_BLOG_ID)^{andpredicates}^)'       ,
--                                      '\n  exists (select 1 from BLOG.DBA.SYS_BLOG_OWNERS as ^{alias}^ where (^{alias}^.BI_BLOG_ID = _top.B_BLOG_ID)^{andpredicates}^)'       ,
--                                              NULL            , NULL          , NULL  )
--    'SYS_DAV_COL'     , vector (      '\n  inner join WS.WS.SYS_DAV_COL as ^{alias}^ on ((^{alias}^.COL_ID = _param.detcol)^{andpredicates}^)'        ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_COL as ^{alias}^ where (^{alias}^.COL_ID = _param.detcol)^{andpredicates}^)'   ,
--                                              NULL            , NULL          , NULL  ),
--    'SYS_DAV_GROUP'   , vector (      '\n  left outer join WS.WS.SYS_DAV_GROUP as ^{alias}^ on ((^{alias}^.G_ID = _top.RES_GROUP)^{andpredicates}^)'  ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_GROUP as ^{alias}^ where (^{alias}^.G_ID = _top.RES_GROUP)^{andpredicates}^)'  ,
--                                              NULL            , NULL          , NULL  )--,
--    'SYS_DAV_PROP'    , vector (      '\n  inner join WS.WS.SYS_DAV_PROP as ^{alias}^ on ((^{alias}^.PROP_PARENT_ID = _top.RES_ID) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'       ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_PROP as ^{alias}^ where (^{alias}^.PROP_PARENT_ID = _top.RES_ID) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'  ,
--                                              'PROP_VALUE'    , 'PROP_VALUE'  , '[__quiet __davprop xmlns:virt="virt"] .'     ),
--    'public-tags'     , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid())^{andpredicates}^)'   ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid())^{andpredicates}^)'      ,
--                                              'DT_TAGS'       , 'DT_TAGS'     , NULL  ),
--    'private-tags'    , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'     ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'        ,
--                                              'DT_TAGS'       , 'DT_TAGS'     , NULL  ),
--    'all-tags'                , vector (      '\n  inner join (select * from WS.WS.SYS_DAV_TAG ^{alias}^_pub where ^{alias}^_pub.DT_U_ID = http_nobody_uid() union select * from WS.WS.SYS_DAV_TAG ^{alias}^_prv where ^{alias}^_prv.DT_U_ID = ^{uid}^) as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID)^{andpredicates}^)'       ,
--                                      '\n  exists (select 1 from (select * from WS.WS.SYS_DAV_TAG ^{alias}^_pub where ^{alias}^_pub.DT_U_ID = http_nobody_uid() union select * from WS.WS.SYS_DAV_TAG ^{alias}^_prv where ^{alias}^_prv.DT_U_ID = ^{uid}^) as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID)^{andpredicates}^)'  ,
--                                              'DT_TAGS'       , 'DT_TAGS'     , NULL  )
    );
}
;


-- This prints the fragment that starts after 'FROM WS.WS.SYS_BLOGS' and contains the rest of FROM and whole 'WHERE'
create function "Blog_POST_DAV_FC_PRINT_WHERE" (inout filter any, in param_uid integer) returns varchar
{
  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;
  -- dbg_obj_princ ('Blog_POST_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
  "Blog_POST_DAV_FC_PRED_METAS" (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  "Blog_POST_DAV_FC_TABLE_METAS" (table_metas);
  used_tables := vector (
    'SYS_BLOGS', vector ('SYS_BLOGS', '_top', null, vector (), vector (), vector ()),
    'SYS_BLOG_OWNERS', vector ('SYS_BLOG_OWNERS', '_owners', null, vector (), vector (), vector ())
    );
  return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;


create procedure "Blog_COMMENT_DAV_FC_PRED_METAS" (inout pred_metas any)
{
  pred_metas := vector (
    'BM_BLOG_ID',               vector ('BLOG_COMMENTS' , 0, 'varchar'  , 'BM_BLOG_ID'  ),
    'BM_POST_ID',               vector ('BLOG_COMMENTS' , 0, 'varchar'  , 'BM_POST_ID'  ),
    'RES_ID',                   vector ('BLOG_COMMENTS' , 0, 'any'      , 'vector (UNAME_BLOG(), B_BLOG_ID, U_ID, B_POST_ID, BM_ID)'    ),
    'RES_ID_SERIALIZED',        vector ('BLOG_COMMENTS' , 0, 'varchar'  , 'serialize (vector (UNAME_BLOG(), B_BLOG_ID, U_ID, B_POST_ID, BM_ID))'        ),
    'RES_NAME',                 vector ('BLOG_COMMENTS' , 0, 'varchar'  , '"Blog_COMPOSE_HTML_NAME" (BM_NAME, cast (BM_ID as varchar))' ),
    'RES_FULL_PATH',            vector ('BLOG_COMMENTS' , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, "Blog_FIXNAME" (WAI_NAME)), ''/'', "Blog_COMPOSE_COMMENTS_NAME" (B_TITLE, B_POST_ID), ''/'', "Blog_COMPOSE_HTML_NAME" (BM_NAME, cast (BM_ID as varchar)))'       ),
    'RES_TYPE',                 vector ('BLOG_COMMENTS' , 0, 'varchar'  , '(''text/plain'')'    ),
    'RES_OWNER_ID',             vector ('SYS_BLOG_OWNERS'       , 0, 'integer'  , 'U_ID'        ),
    'RES_OWNER_NAME',           vector ('SYS_BLOG_OWNERS'       , 0, 'varchar'  , 'U_NAME'      ),
    'RES_GROUP_ID',             vector ('BLOG_COMMENTS' , 0, 'integer'  , 'http_nogroup_gid()'  ),
    'RES_GROUP_NAME',           vector ('BLOG_COMMENTS' , 0, 'varchar'  , '(''nogroup'')'       ),
    'RES_COL_FULL_PATH',        vector ('SYS_BLOGS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, "Blog_FIXNAME" (WAI_NAME)), ''/'', "Blog_COMPOSE_COMMENTS_NAME" (B_TITLE, B_POST_ID))'   ),
    'RES_COL_NAME',             vector ('SYS_BLOGS'     , 0, 'varchar'  , '"Blog_COMPOSE_COMMENTS_NAME" (B_TITLE, B_POST_ID)'   ),
--    'RES_COL_ID',             vector ('SYS_DAV_RES'   , 0, 'varchar'  , 'RES_COL'     ),
    'RES_CR_TIME',              vector ('BLOG_COMMENTS' , 0, 'datetime' , 'BM_TS'       ),
    'RES_MOD_TIME',             vector ('BLOG_COMMENTS' , 0, 'datetime' , 'BM_TS'  ),
    'RES_PERMS',                vector ('BLOG_COMMENTS' , 0, 'varchar'  , '(''110000000RR'')'   ),
    'RES_CONTENT',              vector ('BLOG_COMMENTS' , 0, 'text'     , 'BM_COMMENT'  ),
    'PROP_NAME',                vector ('BLOG_COMMENTS' , 0, 'varchar'  , '(''Content'')'       ),
    'PROP_VALUE',               vector ('BLOG_COMMENTS' , 1, 'text'     , 'BM_COMMENT'  ),
    'RES_TAGS',                 vector ('BLOG_COMMENTS' , 0, 'varchar'  , '('''')'      ), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',          vector ('BLOG_COMMENTS' , 0, 'varchar'  , '('''')'      ),
    'RES_PRIVATE_TAGS',         vector ('BLOG_COMMENTS' , 0, 'varchar'  , '('''')'      ),
    'RDF_PROP',                 vector ('BLOG_COMMENTS' , 1, 'varchar'  , NULL  ),
    'RDF_VALUE',                vector ('BLOG_COMMENTS' , 2, 'XML'      , NULL  ),
    'RDF_OBJ_VALUE',            vector ('BLOG_COMMENTS' , 3, 'XML'      , NULL  )
    );
}
;

create procedure "Blog_COMMENT_DAV_FC_TABLE_METAS" (inout table_metas any)
{
  table_metas := vector (
    'BLOG_COMMENTS'             , vector (      ''      ,
                                        ''      ,
                                                'BM_COMMENT'    , 'BM_COMMENT'  , '[__quiet] /' ),
    'SYS_BLOGS'         , vector (      ''      ,
                                        ''      ,
                                                'B_CONTENT'     , 'B_CONTENT'   , '[__quiet] /' ),
    'SYS_BLOG_OWNERS'   , vector (      ''      ,
                                        ''      ,
                                                NULL            , NULL          , NULL          )
--    'SYS_BLOG_OWNERS' , vector (      '\n  left outer join BLOG.DBA.SYS_BLOG_OWNERS as ^{alias}^ on ((^{alias}^.BI_BLOG_ID = _top.B_BLOG_ID)^{andpredicates}^)'       ,
--                                      '\n  exists (select 1 from BLOG.DBA.SYS_BLOG_OWNERS as ^{alias}^ where (^{alias}^.BI_BLOG_ID = _top.B_BLOG_ID)^{andpredicates}^)'       ,
--                                              NULL            , NULL          , NULL  )
--    'SYS_DAV_COL'     , vector (      '\n  inner join WS.WS.SYS_DAV_COL as ^{alias}^ on ((^{alias}^.COL_ID = _param.detcol)^{andpredicates}^)'        ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_COL as ^{alias}^ where (^{alias}^.COL_ID = _param.detcol)^{andpredicates}^)'   ,
--                                              NULL            , NULL          , NULL  ),
--    'SYS_DAV_GROUP'   , vector (      '\n  left outer join WS.WS.SYS_DAV_GROUP as ^{alias}^ on ((^{alias}^.G_ID = _top.RES_GROUP)^{andpredicates}^)'  ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_GROUP as ^{alias}^ where (^{alias}^.G_ID = _top.RES_GROUP)^{andpredicates}^)'  ,
--                                              NULL            , NULL          , NULL  )--,
--    'SYS_DAV_PROP'    , vector (      '\n  inner join WS.WS.SYS_DAV_PROP as ^{alias}^ on ((^{alias}^.PROP_PARENT_ID = _top.RES_ID) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'       ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_PROP as ^{alias}^ where (^{alias}^.PROP_PARENT_ID = _top.RES_ID) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'  ,
--                                              'PROP_VALUE'    , 'PROP_VALUE'  , '[__quiet __davprop xmlns:virt="virt"] .'     ),
--    'public-tags'     , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid())^{andpredicates}^)'   ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = http_nobody_uid())^{andpredicates}^)'      ,
--                                              'DT_TAGS'       , 'DT_TAGS'     , NULL  ),
--    'private-tags'    , vector (      '\n  inner join WS.WS.SYS_DAV_TAG as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'     ,
--                                      '\n  exists (select 1 from WS.WS.SYS_DAV_TAG as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID) and (^{alias}^.DT_U_ID = ^{uid}^)^{andpredicates}^)'        ,
--                                              'DT_TAGS'       , 'DT_TAGS'     , NULL  ),
--    'all-tags'                , vector (      '\n  inner join (select * from WS.WS.SYS_DAV_TAG ^{alias}^_pub where ^{alias}^_pub.DT_U_ID = http_nobody_uid() union select * from WS.WS.SYS_DAV_TAG ^{alias}^_prv where ^{alias}^_prv.DT_U_ID = ^{uid}^) as ^{alias}^ on ((^{alias}^.DT_RES_ID = _top.RES_ID)^{andpredicates}^)'       ,
--                                      '\n  exists (select 1 from (select * from WS.WS.SYS_DAV_TAG ^{alias}^_pub where ^{alias}^_pub.DT_U_ID = http_nobody_uid() union select * from WS.WS.SYS_DAV_TAG ^{alias}^_prv where ^{alias}^_prv.DT_U_ID = ^{uid}^) as ^{alias}^ where (^{alias}^.DT_RES_ID = _top.RES_ID)^{andpredicates}^)'  ,
--                                              'DT_TAGS'       , 'DT_TAGS'     , NULL  )
    );
}
;


-- This prints the fragment that starts after 'FROM WS.WS.SYS_BLOGS' and contains the rest of FROM and whole 'WHERE'
create function "Blog_COMMENT_DAV_FC_PRINT_WHERE" (inout filter any, in param_uid integer) returns varchar
{
  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;
  -- dbg_obj_princ ('Blog_POST_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
  "Blog_COMMENT_DAV_FC_PRED_METAS" (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  "Blog_COMMENT_DAV_FC_TABLE_METAS" (table_metas);
  used_tables := vector (
    'BLOG_COMMENTS', vector ('BLOG_COMMENTS', '_top', null, vector (), vector (), vector ()),
    'SYS_BLOGS', vector ('SYS_BLOGS', '_blogs', null, vector (), vector (), vector ()),
    'SYS_BLOG_OWNERS', vector ('SYS_BLOG_OWNERS', '_owners', null, vector (), vector (), vector ())
    );
  return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;


--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "Blog_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path any, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  declare st, access, qry_text, execstate, execmessage varchar;
  declare res any;
  declare cond_list, execmeta, execrows any;
  declare blog_id, blog_colname, post_id, condtext, cond_key varchar;
  declare ownergid, owner_uid integer;
  -- dbg_obj_princ ('Blog_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  "Blog_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
  vectorbld_init (res);
  blog_id := null;
  post_id := null;

  if (((length (path_parts) <= 1) and (recursive <> 1)) or (length (path_parts) > 2))
    {
      -- dbg_obj_princ ('\r\nGoto skip_post_level\r\n');
      goto skip_post_level;
    }
  if (length (path_parts) >= 2)
    {
      blog_id := coalesce ((select BI_BLOG_ID from BLOG.DBA.SYS_BLOG_OWNERS where U_ID = owner_uid and "Blog_FIXNAME" (WAI_NAME) = path_parts[0]));
      if (blog_id is null)
        {
          -- dbg_obj_princ ('\r\nGoto finalize\r\n');
          goto finalize;
        }
    }
  cond_key := sprintf ('Blog_POST&%V', coalesce (blog_id, ''));
  condtext := get_keyword (cond_key, compilation);
  -- dbg_obj_princ ('Cached condtext is ', condtext);
  if (condtext is null)
    {
      cond_list := get_keyword ('', compilation);
      -- dbg_obj_princ ('cond_list is ', cond_list);
      if (blog_id is not null)
        cond_list := vector_concat (cond_list, vector ( vector ('B_BLOG_ID', '=', blog_id)));
      condtext := "Blog_POST_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
      -- dbg_obj_princ ('\r\ncondtext2 ', condtext, '\r\n');
      compilation := vector_concat (compilation, vector (cond_key, condtext));
      -- dbg_obj_princ ('\r\ncompilation ', compilation, '\r\n');
    }
  execstate := '00000';
  qry_text := 'select concat (DAV_CONCAT_PATH (_param.detcolpath, "Blog_FIXNAME" (WAI_NAME)), ''/'', "Blog_COMPOSE_HTML_NAME" (B_TITLE, B_POST_ID)),
  ''R'', length (_top.B_CONTENT), _top.B_MODIFIED,
  vector (UNAME_BLOG(), ?, B_BLOG_ID, U_ID, B_POST_ID, null),
  ''110000000RR'', http_nogroup_gid(), U_ID, _top.B_TS, ''text/plain'', "Blog_COMPOSE_HTML_NAME" (B_TITLE, B_POST_ID)
from
  (select top 1 ? as detcolpath from WS.WS.SYS_DAV_COL) as _param,
  BLOG.DBA.SYS_BLOGS as _top
  join BLOG.DBA.SYS_BLOG_OWNERS as _owners on (BI_BLOG_ID = B_BLOG_ID and U_ID = ?)
  ' || condtext;
      -- dbg_obj_princ ('Collection of blog posts, blog_id=', blog_id, ', qry_text = ', qry_text);
      exec (qry_text, execstate, execmessage,
        vector (detcol_id, detcol_path, owner_uid),
        100000000, execmeta, execrows );
      -- dbg_obj_princ ('Collection of blog posts: execstate = ', execstate, ', execmessage = ', execmessage);
      if ('00000' <> execstate)
        signal (execstate, execmessage || ' in ' || qry_text);
      vectorbld_concat_acc (res, execrows);

skip_post_level:

  if (((length (path_parts) <= 2) and (recursive <> 1)) or (length (path_parts) > 3))
    goto skip_post_level;
  if (length (path_parts) >= 3)
    {
      declare post_title_pattern varchar;
      "Blog_PARSE_COMMENTS_NAME" (path_parts[1], post_title_pattern, post_id);
      if (post_id is null)
        goto finalize;
      if (not exists (select top 1 1 from BLOG.DBA.SYS_BLOGS where B_BLOG_ID = blog_id and B_POST_ID = post_id and B_TITLE like post_title_pattern))
        goto finalize;
    }
  cond_key := sprintf ('Blog_COMMENT&%V&%V', coalesce (blog_id, ''), coalesce (post_id, ''));
  condtext := get_keyword (cond_key, compilation);
  if (condtext is null)
    {
      cond_list := get_keyword ('', compilation);
      if (blog_id is not null)
        cond_list := vector_concat (cond_list, vector ( vector ('BM_BLOG_ID', '=', blog_id)));
      if (post_id is not null)
        cond_list := vector_concat (cond_list, vector ( vector ('BM_POST_ID', '=', post_id)));
      condtext := "Blog_COMMENT_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
      compilation := vector_concat (compilation, vector (cond_key, condtext));
    }
  execstate := '00000';
  qry_text := '
select
  concat (DAV_CONCAT_PATH (_param.detcolpath, "Blog_FIXNAME" (_owners.WAI_NAME)), ''/'', "Blog_COMPOSE_COMMENTS_NAME" (_blogs.B_TITLE, _blogs.B_POST_ID), ''/'', "Blog_COMPOSE_HTML_NAME" (_top.BM_NAME, cast (_top.BM_ID as varchar))),
  ''R'', length (_top.BM_COMMENT), _top.BM_TS,
  vector (UNAME_BLOG(), ?, _top.BM_BLOG_ID, _owners.U_ID, _top.BM_POST_ID, _top.BM_ID),
  ''110000000RR'', http_nogroup_gid(), _owners.U_ID, _top.BM_TS, ''text/plain'', "Blog_COMPOSE_HTML_NAME" (_top.BM_NAME, cast (_top.BM_ID as varchar))
from
  (select top 1 ? as detcolpath from WS.WS.SYS_DAV_COL) as _param,
  BLOG.DBA.BLOG_COMMENTS as _top
  join BLOG.DBA.SYS_BLOGS as _blogs on (B_BLOG_ID = BM_BLOG_ID and B_POST_ID = BM_POST_ID)
  join BLOG.DBA.SYS_BLOG_OWNERS as _owners on (BI_BLOG_ID = B_BLOG_ID and U_ID = ?)
  ' || condtext;
      -- dbg_obj_princ ('Collection of blog comments, blog_id=', blog_id, ', post_id=', post_id, ', qry_text = ', qry_text);
      exec (qry_text, execstate, execmessage,
        vector (detcol_id, detcol_path, owner_uid),
        100000000, execmeta, execrows );
      -- dbg_obj_princ ('Collection of blog comments: execstate = ', execstate, ', execmessage = ', execmessage);
      if ('00000' <> execstate)
        signal (execstate, execmessage || ' in ' || qry_text);
      vectorbld_concat_acc (res, execrows);

finalize:
  vectorbld_final (res);
  return res;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Blog_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  -- dbg_obj_princ ('Blog_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  if (path_parts[0] = '' or path_parts[0] is null)
    return -1;
  declare blog_id, colpath, merged_fnameext, orig_fnameext varchar;
  declare orig_id, ctr, len integer;
  declare hitlist any;
  declare access varchar;
  declare ownergid, owner_uid integer;
  "Blog_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
  len := length (path_parts);
  if (0 = len)
    {
      if ('C' <> what)
        {
          -- dbg_obj_princ ('resource with empty path - no items');
          return -1;
        }
      return vector (UNAME_BLOG(), detcol_id, null, owner_uid, null, null);
    }
  if ('' = path_parts[length(path_parts) - 1])
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
  blog_id := coalesce ((select BI_BLOG_ID
    from BLOG.DBA.SYS_BLOG_OWNERS
    where U_ID = owner_uid and "Blog_FIXNAME" (WAI_NAME) = path_parts[0]));
  if (blog_id is null)
    return -1;
  if ('C' = what)
    {
      if (2 = len)
        return vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, null, null);
      if (3 = len)
        {
          declare post_title_pattern, post_id varchar;
          "Blog_PARSE_COMMENTS_NAME" (path_parts[1], post_title_pattern, post_id);
          if (post_title_pattern is null or post_id is null)
            return -1;
          if (exists (select top 1 1
              from BLOG.DBA.SYS_BLOGS join BLOG.DBA.SYS_BLOG_OWNERS on (B_BLOG_ID = BI_BLOG_ID)
              where U_ID = owner_uid and
              cast (B_TITLE as varchar) like post_title_pattern and B_POST_ID = post_id))
            return vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, post_id, null);
        }
      return -1;
    }
  if (len = 2)
    {
      declare post_title_pattern, post_id varchar;
      if (position (path_parts[1], "Blog_CHANNEL_DESC_NAMES" ()))
        return vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, null, path_parts[1]);
      "Blog_PARSE_HTML_NAME" (path_parts[1], post_title_pattern, post_id);
      if (post_title_pattern is null or post_id is null)
        return -1;
      if (exists (select top 1 1
        from  BLOG.DBA.SYS_BLOGS join BLOG.DBA.SYS_BLOG_OWNERS on (B_BLOG_ID = BI_BLOG_ID)
        where U_ID = owner_uid and
        cast (B_TITLE as varchar) like post_title_pattern and B_POST_ID = post_id))
      return vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, post_id, null);
   }
  if (len = 3)
    {
      declare post_title_pattern, post_id, comment_title_pattern, comment_id varchar;
      "Blog_PARSE_COMMENTS_NAME" (path_parts[1], post_title_pattern, post_id);
      if (post_title_pattern is null or post_id is null)
        return -1;
      "Blog_PARSE_HTML_NAME" (path_parts[2], comment_title_pattern, comment_id);
      if (comment_title_pattern is null or comment_id is null)
        return -1;
      if (exists (select top 1 1
        from BLOG.DBA.SYS_BLOG_OWNERS
        join BLOG.DBA.SYS_BLOGS on (B_BLOG_ID = BI_BLOG_ID)
        join BLOG.DBA.BLOG_COMMENTS on ((BM_BLOG_ID = B_BLOG_ID) and (BM_POST_ID = B_POST_ID))
        where U_ID = owner_uid and
          cast (B_TITLE as varchar) like post_title_pattern and B_POST_ID = post_id and
          BM_NAME like comment_title_pattern and BM_ID = comment_id ) )
      return vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, post_id, cast (comment_id as integer));
    }
  return -1;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "Blog_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('Blog_DAV_SEARCH_PATH (', id, what, ')');
  return NULL;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "Blog_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "Blog_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "Blog_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('Blog_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare cont any;
  declare len int;
  if (id[4] is null and id[5] is not null)
  {
    declare hdr any;
    type := 'text/xml';
    for (select BI_HOME
      from BLOG.DBA.SYS_BLOG_INFO
      where BI_BLOG_ID = id[2])
    do
    {
      declare doc_base varchar;
      declare uri, host, olduri varchar;
      host := http_request_header (http_request_header (), 'Host', null);
      if (isstring (host) and strchr (host, ':') is null)
      {
        declare hp varchar;
        declare hpa any;
        hp := sys_connected_server_address ();
        hpa := split_and_decode (hp, 0, '\0\0:');
        host := host || ':' || hpa[1];
      }
      if (host is null)
        host := sys_connected_server_address ();
      uri := 'http://' || host || BI_HOME || 'gems/';
      if (position (id[5], "Blog_CHANNEL_DESC_NAMES" ()))
        uri := uri || id[5];
      olduri := uri;
      again:
      -- dbg_obj_princ(uri);
      commit work;
      content := http_get(uri, hdr);
      if (hdr[0] not like 'HTTP/1._ 200 %')
      {
        if (hdr[0] like 'HTTP/1._ 30_ %')
        {
          uri := http_request_header (hdr, 'Location');
          if (isstring (uri))
            goto again;
        }
        signal ('22023', trim(hdr[0], '\r\n'), 'BLOG0');
        return 0;
      }
    }
    return 0;
  }
  type := 'text/html';
  if (id[5] is null)
    {
      for (select B_CONTENT from BLOG.DBA.SYS_BLOGS SB where SB.B_BLOG_ID = id[2] and SB.B_POST_ID = id[4])
      do
        {
          if ((content_mode = 0) or (content_mode = 2))
            content := B_CONTENT;
          else if (content_mode = 1)
            http (B_CONTENT, content);
          else if (content_mode = 3)
            http (B_CONTENT);
        }
    }
  else
    {
      for (select BM_COMMENT
        from BLOG.DBA.BLOG_COMMENTS BC
        where BC.BM_BLOG_ID = id[2] and BC.BM_POST_ID = id[4] and BC.BM_ID = id[5]
        )
      do
        {
          if ((content_mode = 0) or (content_mode = 2))
            content := BM_COMMENT;
          else if (content_mode = 1)
            http (BM_COMMENT, content);
          else if (content_mode = 3)
            http (BM_COMMENT);
        }
    }
  return 0;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "Blog_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "Blog_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('Blog_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "Blog_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('Blog_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "Blog_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "Blog_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Blog_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "Blog_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('Blog_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "Blog_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('Blog_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;


create procedure "Blog_CF_PROPNAME_TO_COLNAME" (in prop varchar)
{
  return get_keyword (prop, vector (
        'http://purl.org/rss/1.0/title', 'BLOG_INFO.BI_TITLE',
        'http://purl.org/rss/1.0/copyright', 'BLOG_INFO.BI_COPYRIGHT',
        'http://purl.org/rss/1.0/description', 'BLOG_INFO.BI_ABOUT',
        'http://purl.org/rss/1.0/link', '"Blog_CF_COMPOSE_BLOG_LINK" (BLOG_INFO.BI_BLOG_ID)',
        'http://purl.org/rss/1.0/lastBuildDate', 'cast (BLOG_INFO.BI_LAST_UPDATE as varchar)' ) );
}
;

create procedure "Blog_CF_FEED_FROM_AND_WHERE" (in detcol_id integer, in cfc_id integer, inout rfc_list_cond any, inout filter_data any, in distexpn varchar, in auth_uid integer)
{
  declare where_clause, from_clause varchar;
  declare access varchar;
  declare ownergid, owner_uid, proppos, filter_len, filter_idx integer;
  -- dbg_obj_princ ('Blog_CF_FEED_FROM_AND_WHERE (', detcol_id, cfc_id, rfc_list_cond, filter_data, distexpn, auth_uid, ')');
  "Blog_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
  -- dbg_obj_princ ('"Blog_ACCESS_PARAMS" (', detcol_id, ',...) reports ', access, ownergid, owner_uid );
  from_clause := '
  from
    BLOG.DBA.SYS_BLOG_INFO as BLOG_INFO
';
  where_clause := 'BLOG_INFO.BI_OWNER = ' || cast (owner_uid as varchar);
  filter_len := length (filter_data);
  for (filter_idx := 0; filter_idx < (filter_len - 3); filter_idx := filter_idx + 4)
    {
      declare mode integer;
      declare cmp_col, cmp_val varchar;
      cmp_col := "Blog_CF_PROPNAME_TO_COLNAME" (filter_data [filter_idx]);
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


create procedure "Blog_CF_LIST_PROP_DISTVALS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, in schema_uri varchar, inout filter_data any, inout distval_dict any, in auth_uid integer)
{
  declare distprop, distexpn varchar;
  declare from_and_where_text, qry_text varchar;
  declare execstate, execmessage varchar;
  declare execmeta, execrows any;
  -- dbg_obj_princ ('Blog_CF_LIST_PROP_DISTVALS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, distval_dict, auth_uid, ')');
  if (schema_uri = 'http://purl.org/rss/1.0/')
    { -- channel description
      distprop := filter_data[length (filter_data) - 2];
      distexpn := "Blog_CF_PROPNAME_TO_COLNAME" (distprop);
      if (distexpn is null)
        {
          dict_put (distval_dict, '! empty property value !', 1);
          return;
        }
      from_and_where_text := Blog_CF_FEED_FROM_AND_WHERE (detcol_id, cfc_id, rfc_list_cond, filter_data, distexpn, auth_uid);
      qry_text := 'select distinct ' || distexpn || from_and_where_text;
      execstate := '00000';
      execmessage := 'OK';
      -- dbg_obj_princ ('Will exec: ', qry_text);
      exec (qry_text,
        execstate, execmessage,
        vector (), 100000000, execmeta, execrows );
      -- dbg_obj_princ ('exec returns: ', execstate, execmessage, execrows);
      if (isarray (execrows))
        foreach (any execrow in execrows) do
          {
            dict_put (distval_dict, "CatFilter_ENCODE_CATVALUE" (execrow[0]), 1);
          }
      return;
    }
}
;

create function "Blog_CF_GET_RDF_HITS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, in schema_uri varchar, inout filter_data any, in detcol_path varchar, in make_diritems integer, in auth_uid integer) returns any
{
  declare from_and_where_text, qry_text varchar;
  declare execstate, execmessage varchar;
  declare acc_len, acc_ctr integer;
  declare execmeta, acc any;
  declare access varchar;
  declare ownergid, owner_uid integer;
  -- dbg_obj_princ ('\n\n\nBlog_CF_GET_RDF_HITS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ')');
  acc := vector ();
  acc_len := 0;
  if (schema_uri = 'http://purl.org/rss/1.0/')
    { -- channel description
      "Blog_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
      from_and_where_text := Blog_CF_FEED_FROM_AND_WHERE (detcol_id, cfc_id, rfc_list_cond, filter_data, 'CHANNEL_DETAILS.ECD_CHANNEL_URI', auth_uid);
      qry_text := 'select CHANNEL_DETAILS.ECD_CHANNEL_URI' || from_and_where_text;
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
    full_id := vector (UNAME_BLOG(), detcol_id, r_id, owner_uid, null, null);
    if (make_diritems = 1)
      {
        diritm := "Blog_DAV_DIR_SINGLE" (full_id, 'R', '(fake path)', auth_uid);
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
  -- dbg_obj_princ ('Blog_CF_GET_RDF_HITS_RES_IDS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ') returns ', acc);
  return acc;
}
;

create function "Blog_RF_ID2SUFFIX" (in id any, in what char(1)) returns varchar
{
  -- dbg_obj_princ ('Blog_RF_ID2SUFFIX (', id, what, ')');
  if ((id[4] is null) and (what='R'))
    {
      return sprintf ('BlogFeed-%d-%d', id[1], coalesce ((select WAI_ID from BLOG.DBA.SYS_BLOG_OWNERS where BI_BLOG_ID = id[2])));
    }
  signal ('OBLOM', 'Blog_RF_ID2SUFFIX supports only feeds for a while');
}
;

create procedure "BlogFeed_RF_SUFFIX2ID" (in suffix varchar, in what char(1))
{
  declare pairs any;
  declare detcol_id, wainst_id, owner_uid integer;
  declare blog_id varchar;
  -- dbg_obj_princ ('BlogFeed_RF_SUFFIX2ID (', suffix, what, ')');
  pairs := regexp_parse ('^([1-9][0-9]*)-([1-9][0-9]*)\044', suffix, 0);
  if (pairs is null)
    {
      ;
      -- dbg_obj_princ ('BlogFeed_RF_SUFFIX2ID (', suffix, what, ') failed to parse the argument');
    }
  detcol_id := cast (subseq (suffix, pairs[2], pairs[3]) as integer);
  wainst_id := cast (subseq (suffix, pairs[4], pairs[5]) as integer);
  whenever not found goto oblom;
  select U_ID, BI_BLOG_ID into owner_uid, blog_id
    from BLOG.DBA.SYS_BLOG_OWNERS
    where WAI_ID = wainst_id;
  return vector (UNAME_BLOG(), detcol_id, blog_id, owner_uid, null, null);
oblom:
  return NULL;
}
;

create function UNAME_BLOG() returns any { return UNAME'Blog'; };
