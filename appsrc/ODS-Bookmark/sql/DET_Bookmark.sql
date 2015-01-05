--
--  $Id$
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

create function "bookmark_FIXNAME" (in mailname any) returns varchar
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

create function "bookmark_COMPOSE_XBEL_NAME" (in title varchar, in id integer) returns varchar
{
  if (title is null or title = '')
    return "bookmark_FIXNAME"(sprintf('%d.xbel', id));
  return "bookmark_FIXNAME"(sprintf('%s (%d).xbel', title, id));
}
;

create function "bookmark_COMPOSE_FOLDERS_PATH" (in domain_id_ integer, in bd_id_ integer)
{
    declare folder_id integer;
    declare folder_path varchar;
    folder_id := (select BD_FOLDER_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bd_id_ and BD_DOMAIN_ID =  domain_id_);
    if (folder_id is null)
        return '';
    else
       folder_path := (select F_PATH from BMK.WA.FOLDER where F_ID = folder_id);
    return folder_path;
}
;

create function "bookmark_ACCESS_PARAMS" (in detcol_id any, out access varchar, out gid integer, out uid integer)
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
create function "bookmark_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  --dbg_obj_princ ('bookmark_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, http_dav_uid(), ')');
  if (auth_uid < 0)
    return -12;
  if (not ('100' like req))
  {
    ---dbg_obj_princ ('a_uid2 is ', auth_uid, ', id[3] is ', id[2], ' mismatch');
    return -13;
  }
  if ((auth_uid <> id[2]) and (auth_uid <> http_dav_uid()))
  {
    --dbg_obj_princ ('a_uid is ', auth_uid, ', id[3] is ', id[2], ' mismatch');
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
create function "bookmark_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
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
	if ((a_uid <> id[2]) and (a_uid <> http_dav_uid()))
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
create function "bookmark_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "bookmark_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "bookmark_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "bookmark_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "bookmark_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('bookmark_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "bookmark_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', content, type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "bookmark_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('bookmark_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "bookmark_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "bookmark_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('bookmark_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "bookmark_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('bookmark_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "bookmark_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
	declare sub_id, folder_id, domain_id, smart_id integer;
	declare colname, fullpath, rightcol, tag_id varchar;
	declare maxrcvdate datetime;
    --dbg_obj_princ ('bookmark_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
	sub_id := id[3];
	domain_id := id[4];
	folder_id := id[5];
	tag_id := id[7];
	smart_id := id[8];
	fullpath := '';
	rightcol := '';
	if (folder_id <> 0)
	{
		if (sub_id = 1)
		{
			while (folder_id <> 0 and folder_id <> -1)
			{
				colname := (select "bookmark_FIXNAME" (F_NAME)
					from BMK.WA.FOLDER
					where F_DOMAIN_ID = domain_id and F_ID = folder_id);
				if (DAV_HIDE_ERROR (colname) is null)
					return -1;
				if (rightcol = '')
					rightcol := colname;
				fullpath := colname || '/' || fullpath;
				folder_id := coalesce((select F_PARENT_ID from BMK.WA.FOLDER where F_ID = folder_id), 0);
			}
		}
		else if (sub_id = 2)
		{
			if (maxrcvdate is null)
                maxrcvdate := coalesce ( (select max(BD_UPDATED) from BMK.WA.BOOKMARK_DOMAIN where year(BD_UPDATED) = domain_id),
					cast ('1980-01-01' as datetime));
            colname := (select monthname(D.BD_UPDATED)
				from SYS_USERS A,
					WA_MEMBER B,
					WA_INSTANCE C,
					BMK.WA.BOOKMARK_DOMAIN D
				where A.U_ID = id[2]
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Bookmark'
					and D.BD_DOMAIN_ID = C.WAI_ID
                    and month(D.BD_UPDATED) = folder_id
                    and year(D.BD_UPDATED) = domain_id);
			if (DAV_HIDE_ERROR (colname) is null)
				return -1;
			if (rightcol = '')
				rightcol := colname;
			fullpath := colname || '/' || fullpath;
		}
	}
	if (domain_id <> 0)
	{
		if (sub_id = 1)
		{
			if (maxrcvdate is null)
                maxrcvdate := coalesce ( (select max(BD_UPDATED) from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id),
					cast ('1980-01-01' as datetime));
			colname := (select "bookmark_FIXNAME"(C.WAI_NAME) as orig_name
				from SYS_USERS A,
					WA_MEMBER B,
					WA_INSTANCE C
				where A.U_ID = id[2]
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Bookmark'
					and C.WAI_ID = domain_id);
		}
		else if (sub_id = 2)
		{
			if (maxrcvdate is null)
                maxrcvdate := coalesce ( (select max(BD_UPDATED) from BMK.WA.BOOKMARK_DOMAIN where year(BD_UPDATED) = domain_id),
					cast ('1980-01-01' as datetime));
            colname := (select cast(year(D.BD_UPDATED) as varchar)
				from SYS_USERS A,
					WA_MEMBER B,
					WA_INSTANCE C,
					BMK.WA.BOOKMARK_DOMAIN D
				where A.U_ID = id[2]
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Bookmark'
					and D.BD_DOMAIN_ID = C.WAI_ID
                    and year(D.BD_UPDATED) = domain_id);
		}
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	if (tag_id is not null)
	{
		if (sub_id = 3)
		{
			if (maxrcvdate is null)
				maxrcvdate := coalesce ( (select max(T_LAST_UPDATE) from BMK.WA.TAGS where T_TAG = tag_id), cast ('1980-01-01' as datetime));
			colname := (select T_TAG
				from SYS_USERS A,
					WA_MEMBER B,
					WA_INSTANCE C,
					BMK.WA.TAGS T
				where A.U_ID = id[2]
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Bookmark'
					and T.T_DOMAIN_ID = C.WAI_ID
					and T.T_TAG = tag_id);
		}
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	if (smart_id > -1)
	{
		if (sub_id = 4)
		{
			if (maxrcvdate is null)
				maxrcvdate := now();
			colname := (select SF_NAME
				from SYS_USERS A,
					WA_MEMBER B,
					WA_INSTANCE C,
					BMK.WA.SFOLDER T
				where A.U_ID = id[2]
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Bookmark'
					and T.SF_DOMAIN_ID = C.WAI_ID
					and T.SF_ID = smart_id);
		}
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	if (sub_id <> 0)
	{
		if (sub_id = 1)
			colname := 'bookmark';
		else if (sub_id = 2)
			colname := 'date';
		else if (sub_id = 3)
			colname := 'tags';
		else if (sub_id = 4)
			colname := 'smart';
		else
			colname := 'bookmark';
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	fullpath := DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), fullpath);
	if ('C' = what)
	{
		if (id[6] >= 0)
			return -1;
		return vector (fullpath, 'C', 0, maxrcvdate, id, '100000000NN',
			0, id[2], maxrcvdate, 'dav/unix-directory', rightcol );
	}
	for select "bookmark_COMPOSE_XBEL_NAME"(BD_NAME, BD_ID) as orig_mname,
        BD_ID as m_id, BD_UPDATED
		from BMK.WA.BOOKMARK_DOMAIN
		where BD_ID = id[6]
	do
	{
        return vector (fullpath || orig_mname, 'R', 1024, BD_UPDATED, id, '100000000NN',
            0, id[2], BD_UPDATED, 'application/xbel+xml', orig_mname);
	}
	return -1;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "bookmark_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
	--dbg_obj_princ ('bookmark_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid,  ')');
	declare sub_id, folder_id, domain_id, ownergid, owner_uid integer;
	declare top_davpath, access varchar;
	declare res, grand_res any;
	declare top_id, descnames any;
	declare what char (1);
	"bookmark_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
	if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
	what := 'C';
	else
	what := 'R';
	sub_id := 0;
	domain_id := 0;
	folder_id := 0;
	grand_res := vector();
	if ('C' = what and 1 = length(path_parts))
	{
		top_id := vector (UNAME'bookmark', detcol_id, owner_uid, 0, 0, 0, -1, null, -1); -- may be a fake id because top_id[4] may be NULL
	}
	else
	{
		top_id := "bookmark_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, sub_id, owner_uid, domain_id, folder_id);
	}
	if (DAV_HIDE_ERROR (top_id) is null)
		return vector();
	top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
	if ('R' = what)
		return vector ("bookmark_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
	res := vector();
	if ('C' = what)
	{
		if (top_id[3] = 0) -- top level
		{
			declare subs any;
			declare cur varchar;
			declare i integer;
			i := 0;
			subs := vector('bookmark', 'date', 'tags', 'smart');
			for (i := 0; i < 4; i := i + 1)
			{
				cur := cast(subs[i] as varchar);
				res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, cur) || '/', 'C', 0, now(),
					vector (UNAME'bookmark', detcol_id, owner_uid, null, null, null, -1, null, -1),
					'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', cur) ) );
			}
			return res;
		}
		if (top_id[3] = 1 and top_id[4] = 0) -- level of bookmarks, list of Bookmark instances
		{
			for select "bookmark_FIXNAME"(C.WAI_NAME) as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
			do
			{
			  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, -1, null, -1),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
			return res;
		}
		if (top_id[3] = 2 and top_id[4] = 0)  -- level of dates
		{
            for select distinct cast(year(D.BD_UPDATED) as varchar) as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
			do
			{
			  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, -1, null, -1),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
			return res;
		}
		if (top_id[3] = 3 and top_id[4] = 0 and top_id[7] is null)  -- level of tags, lists of keywords
		{
			for select distinct T_TAG as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.TAGS D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.T_DOMAIN_ID = C.WAI_ID
					  and T_TAG <> ''
			do
			{
			  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, -1, null, -1),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
			return res;
		}
		if (top_id[3] = 4 and top_id[4] = 0 and top_id[8] = -1)  -- level of tags, lists of keywords
		{
			for select distinct SF_NAME as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.SFOLDER D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.SF_DOMAIN_ID = C.WAI_ID
					  and D.SF_ID > -1
			do
			{
			  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, -1, null, -1),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
			return res;
		}
		if (top_id[3] = 2 and top_id[4] <> 0 and top_id[5] = 0)  -- level of dates/years
		{
            for select distinct monthname(D.BD_UPDATED) as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
                      and year(D.BD_UPDATED) = top_id[4]
			do
			{
			    res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, -1, null, -1),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
		}
        if (top_id[3] = 1 and top_id[4] <> 0) -- and top_id[5] = 0) -- level of bookmark instance, list of bookmark folders
		{
		  	sub_id := top_id[5];
		  	if (top_id[5] = 0)
		  		sub_id := -1;
			for select F_ID, "bookmark_FIXNAME" (F_NAME) as orig_name
				from BMK.WA.FOLDER
				where F_DOMAIN_ID = top_id[4] and F_PARENT_ID = sub_id
				order by 1, 2
			do
			{
			  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], top_id[4], F_ID, -1, null, -1),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
		}
		grand_res := res;
	}
	res := vector();
	if (top_id[3] = 1)
	{
        for select "bookmark_COMPOSE_XBEL_NAME"(BD_NAME, BD_ID) as orig_mname, BD_ID as m_id, BD_UPDATED
		from BMK.WA.BOOKMARK_DOMAIN
		where BD_DOMAIN_ID = top_id[4] and
			((BD_FOLDER_ID  = top_id[5] and top_id[5] <> 0) or (BD_FOLDER_ID is null and top_id[5] = 0))
		order by 1, 2
		do
		{
          res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, BD_UPDATED,
			vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], m_id, null, -1),
            '100000000NN', ownergid, owner_uid, BD_UPDATED, 'application/xbel+xml', orig_mname) ) );
		}
	}
	else if (top_id[3] = 2)
	{
        for select distinct "bookmark_COMPOSE_XBEL_NAME"(BD_NAME, BD_ID) as orig_mname, BD_ID as m_id, BD_UPDATED
		from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
                      and year(D.BD_UPDATED) = top_id[4] and month(D.BD_UPDATED) = top_id[5]
		order by 1, 2
		do
		{
          res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, BD_UPDATED,
			vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], m_id, null, -1),
            '100000000NN', ownergid, owner_uid, BD_UPDATED, 'application/xbel+xml', orig_mname) ) );
		}
	}
	else if (top_id[3] = 3)
	{
        for select distinct "bookmark_COMPOSE_XBEL_NAME"(D.BD_NAME, D.BD_ID) as orig_mname, D.BD_ID as m_id, D.BD_UPDATED, D.BD_TAGS as tags
		from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
                   BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
               and D.BD_TAGS is not null and D.BD_TAGS <> ''
		order by 1, 2
		do
		{
			declare tags2 any;
			tags2 := split_and_decode (tags, 0, '\0\0,');
			foreach (any tag in tags2) do
			{
				tag := trim(tag);
				if (top_id[7] = tag)
				{
                  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, BD_UPDATED,
					vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, m_id, tag, -1),
                    '100000000NN', ownergid, owner_uid, BD_UPDATED, 'application/xbel+xml', orig_mname)));
				}
			}
		}
	}
	else if (top_id[3] = 4)
	{
        declare sql, state, msg, meta, rows any;
        if (exists (select 1 from BMK.WA.SFOLDER where SF_NAME = 'All bookmarks' and SF_ID = top_id[8]))
        {
            for select S.SF_DOMAIN_ID as cur_domain, S.SF_DATA as cur_data
                     from SYS_USERS A,
                          WA_MEMBER B,
                          WA_INSTANCE C,
                          BMK.WA.SFOLDER S
                    where A.U_ID = owner_uid
                      and B.WAM_USER = A.U_ID
                      and B.WAM_MEMBER_TYPE = 1
                      and B.WAM_INST = C.WAI_NAME
                      and C.WAI_TYPE_NAME = 'Bookmark'
                      and S.SF_DOMAIN_ID = C.WAI_ID do
            {
                  state := '00000';
                  sql := BMK.WA.sfolder_sql(cur_domain, owner_uid, cur_data);
                  exec(sql, state, msg, vector(), 0, meta, rows);
                  if (state = '00000')
                  {
                     foreach (any row in rows) do
                     {
                             res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath,
                             "bookmark_COMPOSE_XBEL_NAME"(row[3], row[1])), 'R', 1024, row[6],
                             vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, row[1], null, top_id[8]),
                             '100000000NN', ownergid, owner_uid, row[5], 'application/xbel+xml', 
                             "bookmark_COMPOSE_XBEL_NAME"(row[3], row[1]))));
                     }
                  }
            }
        }
        else
        {
		for select SF_DATA, SF_DOMAIN_ID from BMK.WA.SFOLDER where top_id[8] = SF_ID do
		{
			state := '00000';
			sql := BMK.WA.sfolder_sql(SF_DOMAIN_ID, owner_uid, SF_DATA);
			exec(sql, state, msg, vector(), 0, meta, rows);
			if (state = '00000')
			{
			foreach (any row in rows) do
			{
			        res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath,
                          "bookmark_COMPOSE_XBEL_NAME"(row[3], row[1])), 'R', 1024, row[6],
					vector (UNAME'bookmark', detcol_id, owner_uid, top_id[3], 0, 0, row[1], null, top_id[8]),
					'100000000NN', ownergid, owner_uid, row[5], 'application/xbel+xml', 
					"bookmark_COMPOSE_XBEL_NAME"(row[3], row[1]))));
			}
			}
		}
	}
    }
	grand_res := vector_concat (grand_res, res);
finalize_res:
	return grand_res;
}
;

create procedure "bookmark_DAV_FC_PRED_METAS" (inout pred_metas any)
{
	pred_metas := vector(
    'BD_ID',					vector ('BOOKMARK_DOMAIN'		, 0, 'integer', 'BD_ID'   ),
	'BD_DOMAIN_ID',				vector ('BOOKMARK_DOMAIN'		, 0, 'integer', 'BD_DOMAIN_ID'   ),
    'BD_BOOKMARK_ID',			vector ('BOOKMARK_DOMAIN'		, 0, 'integer', 'BD_BOOKMARK_ID'     ),
    'BD_FOLDER_ID',		        vector ('BOOKMARK_DOMAIN'		, 0, 'integer'  , 'BD_FOLDER_ID' ),
    'RES_NAME',                 vector ('BOOKMARK_DOMAIN'             , 0, 'varchar'  , '"bookmark_COMPOSE_XBEL_NAME" (_top.BD_NAME, _top.BD_ID)'       ),
    'RES_FULL_PATH',            vector ('BOOKMARK_DOMAIN'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, ''bookmark''), "bookmark_FIXNAME" (WAI_NAME), ''/'', "bookmark_COMPOSE_XBEL_NAME" (_top.BD_NAME, _top.BD_ID)'       ),
    'RES_TYPE',                 vector ('BOOKMARK_DOMAIN'     , 0, 'varchar'  , '(''application/xbel+xml'')'    ),
    'RES_OWNER_ID',             vector ('SYS_USERS'       , 0, 'integer'  , 'U_ID'        ),
    'RES_OWNER_NAME',           vector ('SYS_USERS'       , 0, 'varchar'  , 'U_NAME'      ),
    'RES_GROUP_ID',             vector ('SYS_USERS'     , 0, 'integer'  , 'http_nogroup_gid()'  ),
    'RES_GROUP_NAME',           vector ('SYS_USERS'     , 0, 'varchar'  , '(''nogroup'')'       ),
    'RES_COL_FULL_PATH',        vector ('BOOKMARK_DOMAIN'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, ''bookmark''), "bookmark_FIXNAME" (WAI_NAME), ''/'')'      ),
    'RES_COL_NAME',             vector ('BOOKMARK_DOMAIN'     , 0, 'varchar'  , '"bookmark_FIXNAME" (WAI_NAME)'   ),
    'RES_CR_TIME',              vector ('BOOKMARK_DOMAIN'     , 0, 'datetime' , 'BD_UPDATED'        ),
    'RES_MOD_TIME',             vector ('BOOKMARK_DOMAIN'     , 0, 'datetime' , 'BD_UPDATED'  ),
    'RES_PERMS',                vector ('BOOKMARK_DOMAIN'     , 0, 'varchar'  , '(''110000000RR'')'   ),
    'RES_CONTENT',              vector ('BOOKMARK_DOMAIN'     , 0, 'text'     , 'BD_DESCRIPTION'   ),
    'PROP_NAME',		vector ('BOOKMARK_DOMAIN'	, 0, 'varchar'	, '(''BD_DESCRIPTION'')'	),
    'PROP_VALUE',		vector ('SYS_DAV_PROP'	, 1, 'text'	, 'BD_DESCRIPTION'	),
    'RES_TAGS',			vector ('all-tags'	, 0, 'varchar'  , 'BD_TAGS'	), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',		vector ('public-tags'	, 0, 'varchar'	, 'BD_TAGS'	), -- 'varchar', not 'text-tag' because there's no free-text in table!
    'RES_PRIVATE_TAGS',		vector ('private-tags'	, 0, 'varchar'	, 'BD_TAGS'	), -- 'varchar', not 'text-tag' because there's no free-text in table!
    'RDF_PROP',			vector ('fake-prop'	, 1, 'varchar'	, NULL	),
    'RDF_VALUE',		vector ('fake-prop'	, 2, 'XML'	, NULL	),
    'RDF_OBJ_VALUE',		vector ('fake-prop'	, 3, 'XML'	, NULL	)
    );
}
;

create procedure "bookmark_DAV_FC_TABLE_METAS" (inout table_metas any)
{
	table_metas := vector (
		'BOOKMARK_DOMAIN'             , vector (      ''      ,
                                        ''      ,
                                                'BD_NAME'    , 'BD_NAME'  , '[__quiet] /' ),
    'WA_INSTANCE'         , vector (      ''      ,
                                        ''      ,
                                                'WAI_NAME'     , 'WAI_NAME'   , '[__quiet] /' ),
    'WA_MEMBER'         , vector (      ''      ,
                                        ''      ,
                                                'WAM_INST'     , 'WAM_INST'   , '[__quiet] /' ),

    'SYS_USERS'   , vector (      ''      ,
                                        ''      ,
                                                NULL            , NULL          , NULL          ),
    'public-tags'     , vector ( ''           ,
                                 ''           ,
						'BD_TAGS'	, 'BD_TAGS'	, NULL	),
    'private-tags'    , vector ( ''           ,
                                 ''           ,
						'BD_TAGS'	, 'BD_TAGS'	, NULL	),
    'all-tags'        , vector ( ''           ,
                                 ''           ,
						'BD_TAGS'	, 'BD_TAGS'	, NULL	),
    'fake-prop'	, vector (	'\n  inner join WS.WS.SYS_DAV_PROP as ^{alias}^ on ((^{alias}^.PROP_PARENT_ID is null) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'	,
					'\n  exists (select 1 from WS.WS.SYS_DAV_PROP as ^{alias}^ where (^{alias}^.PROP_PARENT_ID is null) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'	,
						'PROP_VALUE'	, 'PROP_VALUE'	, '[__quiet __davprop xmlns:virt="virt"] fakepropthatprobablyneverexists'	)
	);
}
;

create function "bookmark_DAV_FC_PRINT_WHERE" (inout filter any, in param_uid integer) returns varchar
{
	declare pred_metas, cmp_metas, table_metas any;
	declare used_tables any;
	-- dbg_obj_princ ('Blog_POST_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
	"bookmark_DAV_FC_PRED_METAS" (pred_metas);
	DAV_FC_CMP_METAS (cmp_metas);
	"bookmark_DAV_FC_TABLE_METAS" (table_metas);
	used_tables := vector(
		'BOOKMARK_DOMAIN', vector ('BOOKMARK_DOMAIN', '_top', null, vector (), vector (), vector ()),
		'WA_INSTANCE', vector ('WA_INSTANCE', '_instances', null, vector (), vector (), vector ()),
		'WA_MEMBER', vector ('WA_MEMBER', '_members', null, vector (), vector (), vector ()),
		'SYS_USERS', vector ('SYS_USERS', '_users', null, vector (), vector (), vector ())
	);
	return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "bookmark_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path any, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
	-- dbg_obj_princ ('bookmark_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
	declare st, access, qry_text, execstate, execmessage varchar;
	declare res any;
	declare cond_list, execmeta, execrows any;
	declare sub, post_id, condtext, cond_key varchar;
	declare ownergid, owner_uid, domain_id integer;
	"bookmark_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
	vectorbld_init (res);
	sub := null;
	post_id := null;
	if (((length (path_parts) <= 1) and (recursive <> 1)) or (length (path_parts) > 2))
	{
	  -- dbg_obj_princ ('\r\nGoto skip_post_level\r\n');
	  goto finalize;
	}
	if (length (path_parts) >= 2)
	{
		sub := path_parts[0];
		if (sub = 'bookmark')
		{
			domain_id := coalesce ((select C.WAI_ID
				from SYS_USERS A,
				WA_MEMBER B,
				WA_INSTANCE C
			where A.U_ID = owner_uid
			  and B.WAM_USER = A.U_ID
			  and B.WAM_MEMBER_TYPE = 1
			  and B.WAM_INST = C.WAI_NAME
			  and C.WAI_TYPE_NAME = 'Bookmark'
			  and "bookmark_FIXNAME"(C.WAI_NAME) = path_parts[1]));
			if (domain_id is null)
				goto finalize;
		}
		else
			goto finalize;
	}
	cond_key := sprintf ('Bookmark&%d', coalesce (domain_id, 0));
	condtext := get_keyword (cond_key, compilation);
    if (condtext is null and 0)
	{
	  cond_list := get_keyword ('', compilation);
	  if (sub is not null)
		cond_list := vector_concat (cond_list, vector ( vector ('BD_DOMAIN_ID', '=', domain_id)));
	  condtext := "bookmark_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
	  compilation := vector_concat (compilation, vector (cond_key, condtext));
	}
	execstate := '00000';
    qry_text := 'select concat (DAV_CONCAT_PATH (_param.detcolpath, ''bookmark''), ''/'', "bookmark_FIXNAME" (WAI_NAME), "bookmark_COMPOSE_FOLDERS_PATH" (_top.BD_DOMAIN_ID, _top.BD_ID), ''/'', "bookmark_COMPOSE_XBEL_NAME" (_top.BD_NAME, _top.BD_ID)),
        ''R'', 1024, _top.BD_UPDATED,
                vector (UNAME_BOOKMARK(), ?, _users.U_ID, 3, _top.BD_DOMAIN_ID, _top.BD_FOLDER_ID, null, null),
                ''110000000RR'', http_nogroup_gid(), _users.U_ID, _top.BD_UPDATED, ''application/xbel+xml'', "bookmark_COMPOSE_XBEL_NAME" (_top.BD_NAME, _top.BD_ID)
		from
		(select top 1 ? as detcolpath from WS.WS.SYS_DAV_COL) as _param,
		BMK.WA.BOOKMARK_DOMAIN as _top
		join DB.DBA.WA_INSTANCE as _instances on (WAI_ID = BD_DOMAIN_ID and WAI_TYPE_NAME = ''Bookmark'')
                join DB.DBA.WA_MEMBER as _members on (WAM_MEMBER_TYPE = 1 and WAM_INST = WAI_NAME)
                join DB.DBA.SYS_USERS as _users on (WAM_USER = U_ID and U_ID = ?)
		' || condtext;
	  exec (qry_text, execstate, execmessage,
		vector (detcol_id, detcol_path, owner_uid),
		100000000, execmeta, execrows );
	  if ('00000' <> execstate)
		signal (execstate, execmessage || ' in ' || qry_text);
	  vectorbld_concat_acc (res, execrows);
finalize:
	vectorbld_final (res);
	return res;
}
;

create function UNAME_BOOKMARK() returns any
{
	return UNAME'Bookmark';
}
;

create function "bookmark_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout sub_id integer, inout muser_id integer, inout domain_id integer, inout folder_id integer) returns any
{
	--dbg_obj_princ ('bookmark_DAV_SEARCH_ID_IMPL (', detcol_id, path_parts, what, sub_id, muser_id, domain_id, folder_id, ')');
	declare ownergid, owner_uid, ctr, len, smart_id integer;
	declare hitlist any;
	declare access, colpath, tag_id, sub varchar;
	tag_id := null;
	smart_id := -1;
	"bookmark_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
	if (0 = length(path_parts))
	{
		if ('C' <> what)
			return -1;
		return vector (UNAME'bookmark', detcol_id, owner_uid, sub_id, domain_id, folder_id, -1, null, -1);
	}
	if ('' = path_parts[length(path_parts) - 1])
	{
		if ('C' <> what)
			return -1;
	}
	else
	{
		if ('R' <> what)
			return -1;
	}
	len := length (path_parts) - 1;
	ctr := 0;
	sub := trim(cast(path_parts[0] as varchar));
	while (ctr < len)
	{
		if (ctr = 0)
		{
			if (equ(sub, 'date'))
				sub_id := 2;
			else if (equ(sub, 'bookmark'))
				sub_id := 1;
			else if (equ(sub, 'tags'))
				sub_id := 3;
			else if (equ(sub, 'smart'))
				sub_id := 4;
			else
				sub_id := 1;
		}
		else if (ctr = 1)
		{
		  hitlist := vector ();
		  if (sub_id = 1)
		  {
			  for select C.WAI_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and "bookmark_FIXNAME"(C.WAI_NAME) = path_parts[ctr]
			  do
			  {
				hitlist := vector_concat (hitlist, vector (D_ID));
			  }
		  }
		  else if (sub_id = 2)
		  {
            for select distinct year(D.BD_UPDATED) as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
                      and year(D.BD_UPDATED) = atoi(path_parts[ctr])
			  do
			  {
				hitlist := vector_concat (hitlist, vector (D_ID));
			  }
		  }
		  else if (sub_id = 3)
		  {
			for select distinct D.T_TAG as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.TAGS D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.T_DOMAIN_ID = C.WAI_ID
					  and D.T_TAG = path_parts[ctr]
			do
			{
				hitlist := vector_concat (hitlist, vector (D_ID));
			}
			if (length (hitlist) <> 1)
				return -1;
			tag_id := hitlist[0];
		  }
		  else if (sub_id = 4)
		  {
			for select distinct D.SF_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.SFOLDER D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.SF_DOMAIN_ID = C.WAI_ID
					  and D.SF_NAME = path_parts[ctr]
			do
			{
				hitlist := vector_concat (hitlist, vector (D_ID));
			}
            if (length (hitlist) < 1)
				return -1;
			smart_id := hitlist[0];
		  }
		  if (sub_id <> 3 and sub_id <> 4)
		  {
			  if (length (hitlist) <> 1)
				return -1;
			  domain_id := hitlist[0];
		  }
		}
		else
		{
			if (sub_id <> 3)
			{
				hitlist := vector();
				if (sub_id = 1)
				{
					for select F_ID
						from BMK.WA.FOLDER
						where "bookmark_FIXNAME"(F_NAME) = path_parts[ctr] and
						F_DOMAIN_ID = domain_id and
						((F_PARENT_ID = folder_id and folder_id <> 0) or (F_PARENT_ID = -1 and folder_id = 0))
					do
					{
						hitlist := vector_concat (hitlist, vector (F_ID));
					}
				}
				else if (sub_id = 2)
				{
                    for select distinct month(D.BD_UPDATED) as D_ID
						 from SYS_USERS A,
							  WA_MEMBER B,
							  WA_INSTANCE C,
							  BMK.WA.BOOKMARK_DOMAIN D
						where A.U_ID = owner_uid
						  and B.WAM_USER = A.U_ID
						  and B.WAM_MEMBER_TYPE = 1
						  and B.WAM_INST = C.WAI_NAME
						  and C.WAI_TYPE_NAME = 'Bookmark'
						  and D.BD_DOMAIN_ID = C.WAI_ID
                          and monthname(D.BD_UPDATED) = path_parts[ctr]
				  do
				  {
					hitlist := vector_concat (hitlist, vector (D_ID));
				  }
				}
				if (length (hitlist) <> 1)
					return -1;
				folder_id := hitlist[0];
			}
			else
				return -1;
		}
		ctr := ctr + 1;
	}
	if ('C' = what)
	{
		return vector (UNAME'bookmark', detcol_id, owner_uid, sub_id, domain_id, folder_id, -1, tag_id, smart_id);
	}
	hitlist := vector ();
	if (sub_id = 1)
	{
		for select distinct BD_ID
			from BMK.WA.BOOKMARK_DOMAIN
			where ((BD_FOLDER_ID = folder_id and folder_id <> 0) or (folder_id = 0 and BD_FOLDER_ID is null))and
			"bookmark_COMPOSE_XBEL_NAME" (BD_NAME, BD_ID) = path_parts[ctr] and
			BD_DOMAIN_ID = domain_id
		do
		{
			hitlist := vector_concat (hitlist, vector (BD_ID));
		}
	}
	else if (sub_id = 2)
	{
		for select distinct D.BD_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
                      and month(D.BD_UPDATED) = folder_id
                      and year(D.BD_UPDATED) = domain_id
					  and "bookmark_COMPOSE_XBEL_NAME" (D.BD_NAME, D.BD_ID) = path_parts[ctr]
		do
		{
			hitlist := vector_concat (hitlist, vector (D_ID));
		}
	}
	else if (sub_id = 3)
	{
		for select distinct D.BD_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
					  and "bookmark_COMPOSE_XBEL_NAME" (D.BD_NAME, D.BD_ID) = path_parts[ctr]
		do
		{
			hitlist := vector_concat (hitlist, vector (D_ID));
		}
	}
	else if (sub_id = 4)
	{
		for select distinct D.BD_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  BMK.WA.BOOKMARK_DOMAIN D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Bookmark'
					  and D.BD_DOMAIN_ID = C.WAI_ID
					  and "bookmark_COMPOSE_XBEL_NAME" (D.BD_NAME, D.BD_ID) = path_parts[ctr]
		do
		{
			hitlist := vector_concat (hitlist, vector (D_ID));
		}
	}

	if (length (hitlist) <> 1)
		return -1;
	return vector (UNAME'bookmark', detcol_id, owner_uid, sub_id, domain_id, folder_id, hitlist[0], tag_id, smart_id);
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "bookmark_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare sub_id, u_id, folder_id, domain_id integer;
  --dbg_obj_princ ('bookmark_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  return "bookmark_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, sub_id, u_id, domain_id, folder_id);
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "bookmark_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  --dbg_obj_princ ('bookmark_DAV_SEARCH_PATH (', id, what, ')');
  return NULL;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "bookmark_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "bookmark_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "bookmark_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
	--dbg_obj_princ ('bookmark_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
	whenever not found goto endline;
	if (id[6] is not null)
	{
		declare link, title, last_date varchar;
		if (id[3] = 1)
		{
            select D.BD_NAME, cast(D.BD_UPDATED as varchar), B.B_URI into title, last_date, link
				from BMK.WA.BOOKMARK_DOMAIN D, BMK.WA.BOOKMARK B
				where D.BD_DOMAIN_ID = id[4] and
					((D.BD_FOLDER_ID  = id[5] and id[5] <> 0) or (D.BD_FOLDER_ID is null and id[5] = 0)) and
					D.BD_ID = id[6] and
					B.B_ID = D.BD_BOOKMARK_ID;
		}
		else if (id[3] = 2 or id[3] = 3 or id[3] = 4)
		{
            select D.BD_NAME, cast(D.BD_UPDATED as varchar), B.B_URI into title, last_date, link
					 from BMK.WA.BOOKMARK_DOMAIN D,
						  BMK.WA.BOOKMARK B
					where D.BD_ID = id[6] and B.B_ID = D.BD_BOOKMARK_ID;
		}
		type := 'application/xbel+xml';
		content := '<?xml version="1.0" encoding="UTF-8"?>\n';
		content := concat(content, '<!DOCTYPE xbel PUBLIC "+//IDN python.org//DTD XML Bookmark Exchange Language 1.0//EN//XML" "http://pyxml.sourceforge.net/topics/dtds/xbel-1.0.dtd">\n');
		content := concat(content, '<xbel>\n');
		content := concat(content, sprintf('  <bookmark href="%s">\n', link));
		content := concat(content, sprintf('    <title>%s</title>\n', title));
		content := concat(content, '  </bookmark>\n');
		content := concat(content, '</xbel>\n');
	}
endline:
	return 0;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "bookmark_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "bookmark_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "bookmark_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "bookmark_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "bookmark_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('bookmark_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "bookmark_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('bookmark_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "bookmark_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('bookmark_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;
