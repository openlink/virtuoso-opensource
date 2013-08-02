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

create function "calendar_FIXNAME" (in mailname any) returns varchar
{
  return
      replace (
        replace (
          replace (
            replace (
              replace (
                replace (
                  replace (mailname, '/', '_'), '\\', '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_');
}
;

create function "calendar_COMPOSE_ICS_NAME" (in id integer, in title varchar, in startdate datetime, in enddate datetime) returns varchar
{
  if (title is null or title = '')
    return "calendar_FIXNAME"(sprintf('%d.ics', id));
  return "calendar_FIXNAME"(sprintf('%d - %s.ics', id, title));
}
;

create function "calendar_ACCESS_PARAMS" (in detcol_id any, out access varchar, out gid integer, out uid integer)
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
create function "calendar_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  --dbg_obj_princ ('calendar_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, http_dav_uid(), ')');
  if (auth_uid < 0)
    return -12;
  if (not ('100' like req))
  {
    --dbg_obj_princ ('a_uid2 is ', auth_uid, ', id[3] is ', id[2], ' mismatch');
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
create function "calendar_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
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
create function "calendar_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('calendar_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "calendar_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "calendar_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "calendar_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "calendar_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('calendar_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "calendar_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', content, type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "calendar_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('calendar_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "calendar_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "calendar_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('calendar_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "calendar_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('calendar_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "calendar_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
	declare kind_id, month_id, year_id, domain_id, tag_id integer;
	declare colname, fullpath, rightcol  varchar;
	declare maxrcvdate datetime;
	--dbg_obj_princ ('calendar_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
	kind_id := id[3];
	domain_id := id[4];
	year_id := id[5];
	month_id := id[6];
	tag_id := id[8];
	fullpath := '';
	rightcol := '';
	-- level of month for Dates only
	if (year_id <> 0 and month_id <> 0 and kind_id = 2)
	{
		if (maxrcvdate is null)
			maxrcvdate := coalesce ( (select max(E_UPDATED) from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and year(E_UPDATED) = year_id and month(E_UPDATED) = month_id),
				cast ('1980-01-01' as datetime));
		colname := (select monthname(D.E_UPDATED)
			from SYS_USERS A,
				WA_MEMBER B,
				WA_INSTANCE C,
				CAL.WA.EVENTS D
			where A.U_ID = id[2]
				and B.WAM_USER = A.U_ID
				and B.WAM_MEMBER_TYPE = 1
				and B.WAM_INST = C.WAI_NAME
				and C.WAI_TYPE_NAME = 'Calendar'
				and C.WAI_ID = domain_id
				and D.E_DOMAIN_ID = C.WAI_ID
				and month(D.E_UPDATED) = month_id
				and year(D.E_UPDATED) = year_id);
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	-- level of years for Dates only
	if (year_id <> 0 and kind_id = 2)
	{
		if (maxrcvdate is null)
			maxrcvdate := coalesce ( (select max(E_UPDATED) from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and year(E_UPDATED) = year_id),
				cast ('1980-01-01' as datetime));
		colname := (select cast(year(D.E_UPDATED) as varchar)
			from SYS_USERS A,
				WA_MEMBER B,
				WA_INSTANCE C,
				CAL.WA.EVENTS D
			where A.U_ID = id[2]
				and B.WAM_USER = A.U_ID
				and B.WAM_MEMBER_TYPE = 1
				and B.WAM_INST = C.WAI_NAME
				and C.WAI_TYPE_NAME = 'Calendar'
				and C.WAI_ID = domain_id
				and D.E_DOMAIN_ID = C.WAI_ID
				and year(D.E_UPDATED) = year_id);
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	if (kind_id >= 0)
	{
		if (kind_id = 0)
			colname := 'Events';
		else if (kind_id = 1)
			colname := 'Tasks';
		else if (kind_id = 2)
			colname := 'Date';
        else if (kind_id = 3)
            colname := 'Gems';
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	-- level of Domain name
	{
		if (maxrcvdate is null)
			maxrcvdate := coalesce ( (select max(E_UPDATED) from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id), cast ('1980-01-01' as datetime));
		if (cast(maxrcvdate as integer) = 0)
			maxrcvdate := cast ('1980-01-01' as datetime);
		colname := (select "calendar_FIXNAME"(C.WAI_NAME) as orig_name
			from SYS_USERS A,
				WA_MEMBER B,
				WA_INSTANCE C
			where A.U_ID = id[2]
				and B.WAM_USER = A.U_ID
				and B.WAM_MEMBER_TYPE = 1
				and B.WAM_INST = C.WAI_NAME
				and C.WAI_TYPE_NAME = 'Calendar'
				and C.WAI_ID = domain_id);
		if (DAV_HIDE_ERROR (colname) is null)
			return -1;
		if (rightcol = '')
			rightcol := colname;
		fullpath := colname || '/' || fullpath;
	}
	fullpath := DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), fullpath);	
	if ('C' = what)
	{
		if (id[7] > 0)
			return -1;
		return vector (fullpath, 'C', 0, maxrcvdate, id, '100000000NN', 0, id[2], maxrcvdate, 'dav/unix-directory', rightcol );
	}
    if (kind_id = 3 and 'R' = what)
    {
		if (id[7] = -1)
			return vector (fullpath || 'Calendar.rss', 'R', 1024, now(), id, '100000000NN', 0, id[2], now(), 'text/xml', 'Calendar.rss');
		if (id[7] = -2)
			return vector (fullpath || 'Calendar.atom', 'R', 1024, now(), id, '100000000NN', 0, id[2], now(), 'text/xml', 'Calendar.atom');
		if (id[7] = -3)
			return vector (fullpath || 'Calendar.rdf', 'R', 1024, now(), id, '100000000NN', 0, id[2], now(), 'text/xml', 'Calendar.rdf');
    }
    else
	{
	for select "calendar_COMPOSE_ICS_NAME"(E_ID, E_SUBJECT, E_EVENT_START, E_EVENT_END) as orig_mname,
		E_UPDATED
		from CAL.WA.EVENTS
		where E_ID = id[7]
	do
	{
		return vector (fullpath || orig_mname, 'R', 1024, E_UPDATED, id, '100000000NN', 0, id[2], E_UPDATED, 'text/calendar', orig_mname);
	}
	}
	return -1;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "calendar_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
	--dbg_obj_princ ('calendar_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid,  ')');
	declare kind_id, year_id, month_id, domain_id, ownergid, owner_uid integer;
	declare top_davpath, access varchar;
	declare res, grand_res any;
	declare top_id, descnames any;
	declare what char (1);
	"calendar_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
	if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
		what := 'C';
	else
		what := 'R';
	kind_id := -1;
	domain_id := 0;
	year_id := 0;
	month_id := 0;
	grand_res := vector();
	if ('C' = what and 1 = length(path_parts))
		top_id := vector (UNAME'calendar', detcol_id, owner_uid, -1, 0, 0, 0, 0, 0); -- may be a fake id because top_id[4] may be NULL
	else
		top_id := "calendar_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, kind_id, owner_uid, domain_id, year_id, month_id);
	if (DAV_HIDE_ERROR (top_id) is null)
		return vector();
	top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
	if ('R' = what)
		return vector ("calendar_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
	res := vector();
	if ('C' = what)
	{
		 -- Top level
		if (top_id[4] = 0)
		{
			for select "calendar_FIXNAME"(C.WAI_NAME) as orig_name,
				C.WAI_ID as dom_id
			from SYS_USERS A,
				WA_MEMBER B,
				WA_INSTANCE C
			where A.U_ID = owner_uid
				and B.WAM_USER = A.U_ID
				and B.WAM_MEMBER_TYPE = 1
				and B.WAM_INST = C.WAI_NAME
				and C.WAI_TYPE_NAME = 'Calendar'
			do
			{
				res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
					vector (UNAME'calendar', detcol_id, owner_uid, -1,  dom_id, 0, 0, 0, 0),
					'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
			return res;
		}
		if (top_id[4] <> 0 and top_id[3] = -1)
		{
			declare subs any;
			declare cur varchar;
			declare i integer;
			i := 0;
            subs := vector('Events', 'Tasks', 'Date', 'Gems');
            for (i := 0; i < 4; i := i + 1)
			{
				cur := cast(subs[i] as varchar);
				res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, cur) || '/', 'C', 0, now(),
                    vector (UNAME'calendar', detcol_id, owner_uid, i, top_id[4], 0, 0, 0, 0),
					'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', cur) ) );
			}
			return res;
		}
		if (top_id[3] = 2 and top_id[5] = 0 and top_id[6] = 0)  -- level of dates - only years
		{
			for select distinct cast(year(D.E_UPDATED) as varchar) as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  CAL.WA.EVENTS D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Calendar'
					  and C.WAI_ID = top_id[4]
					  and D.E_DOMAIN_ID = C.WAI_ID
			do
			{
			  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], 0, 0, 0),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
			return res;
		}
		if (top_id[3] = 2 and top_id[5] <> 0 and top_id[6] = 0)  -- level of dates/years
		{
			for select distinct monthname(D.E_UPDATED) as orig_name
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  CAL.WA.EVENTS D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Calendar'
					  and D.E_DOMAIN_ID = C.WAI_ID
					  and C.WAI_ID = top_id[4]
					  and year(D.E_UPDATED) = top_id[5]
			do
			{
			    res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
				vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], top_id[5], 0, 0),
				'100000000NN', ownergid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
			}
		}
		grand_res := res;
	}
	res := vector();
	if (top_id[3] = 0 or top_id[3] = 1)
	{
		for select "calendar_COMPOSE_ICS_NAME"(E_ID, E_SUBJECT, E_EVENT_START, E_EVENT_END) as orig_mname, E_ID, E_UPDATED
			from CAL.WA.EVENTS
			where E_DOMAIN_ID = top_id[4] and
			E_KIND = top_id[3]
		order by 1, 2
		do
		{
		  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, E_UPDATED,
			vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], 0, 0, E_ID, 0),
			'100000000NN', ownergid, owner_uid, E_UPDATED, 'text/calendar', orig_mname) ) );
		}
	}
	else if (top_id[3] = 2 and top_id[5] <> 0 and top_id[6] <> 0)
	{
		for select distinct "calendar_COMPOSE_ICS_NAME"(E_ID, E_SUBJECT, E_EVENT_START, E_EVENT_END) as orig_mname, E_ID, E_UPDATED
		from SYS_USERS A,
			WA_MEMBER B,
			WA_INSTANCE C,
			CAL.WA.EVENTS D
		where A.U_ID = owner_uid
			and B.WAM_USER = A.U_ID
			and B.WAM_MEMBER_TYPE = 1
			and B.WAM_INST = C.WAI_NAME
			and C.WAI_TYPE_NAME = 'Calendar'
			and D.E_DOMAIN_ID = top_id[4]
			and D.E_DOMAIN_ID = C.WAI_ID
			and year(D.E_UPDATED) = top_id[5] and month(D.E_UPDATED) = top_id[6]
		order by 1, 2
		do
		{	
		  res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, E_UPDATED,
			vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], top_id[6], E_ID, 0),
			'100000000NN', ownergid, owner_uid, E_UPDATED, 'text/calendar', orig_mname) ) );
		}
	}
    --- level of gems
    else if (top_id[3] = 3)
    {
          res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, 'Calendar.rss'), 'R', 1024, now(),
            vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], top_id[6], -1, 0),
            '100000000NN', ownergid, owner_uid, now(), 'text/xml', 'Calendar.rss') ) );
          res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, 'Calendar.atom'), 'R', 1024, now(),
            vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], top_id[6], -2, 0),
            '100000000NN', ownergid, owner_uid, now(), 'text/xml', 'Calendar.atom') ) );
          res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, 'Calendar.rdf'), 'R', 1024, now(),
            vector (UNAME'calendar', detcol_id, owner_uid, top_id[3], top_id[4], top_id[5], top_id[6], -3, 0),
            '100000000NN', ownergid, owner_uid, now(), 'text/xml', 'Calendar.rdf') ) );
    }
	grand_res := vector_concat (grand_res, res);
finalize_res:
	return grand_res;
}
;

create procedure "calendar_DAV_FC_PRED_METAS" (inout pred_metas any)
{
	pred_metas := vector(
    'E_ID',					vector ('EVENTS'		, 0, 'integer', 'E_ID'   ),
	'E_DOMAIN_ID',				vector ('EVENTS'		, 0, 'integer', 'E_DOMAIN_ID'   ),
    'RES_NAME',                 vector ('EVENTS'             , 0, 'varchar'  , '"calendar_COMPOSE_ICS_NAME"(_top.E_ID, _top.E_SUBJECT, _top.E_EVENT_START, _top.E_EVENT_END)'),
    'RES_FULL_PATH',            vector ('EVENTS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, ''calendar''), "calendar_FIXNAME" (WAI_NAME), ''/'', "calendar_COMPOSE_ICS_NAME" (_top.E_ID, _top.E_SUBJECT, _top.E_EVENT_START, _top.E_EVENT_END)'),
    'RES_TYPE',                 vector ('EVENTS'     , 0, 'varchar'  , '(''text/calendar'')'),
    'RES_OWNER_ID',             vector ('SYS_USERS'       , 0, 'integer'  , 'U_ID'        ),
    'RES_OWNER_NAME',           vector ('SYS_USERS'       , 0, 'varchar'  , 'U_NAME'      ),
    'RES_GROUP_ID',             vector ('SYS_USERS'     , 0, 'integer'  , 'http_nogroup_gid()'  ),
    'RES_GROUP_NAME',           vector ('SYS_USERS'     , 0, 'varchar'  , '(''nogroup'')'       ),
    'RES_COL_FULL_PATH',        vector ('EVENTS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, ''calendar''), "calendar_FIXNAME" (WAI_NAME), ''/'')'      ),
    'RES_COL_NAME',             vector ('EVENTS'     , 0, 'varchar'  , '"calendar_FIXNAME" (WAI_NAME)'   ),
    'RES_CR_TIME',              vector ('EVENTS'     , 0, 'datetime' , 'E_UPDATED'        ),
    'RES_MOD_TIME',             vector ('EVENTS'     , 0, 'datetime' , 'E_UPDATED'  ),
    'RES_PERMS',                vector ('EVENTS'     , 0, 'varchar'  , '(''110000000RR'')'   ),
    'RES_CONTENT',              vector ('EVENTS'     , 0, 'text'     , 'E_DESCRIPTION'   ),
    'PROP_NAME',		vector ('EVENTS'	, 0, 'varchar'	, '(''E_DESCRIPTION'')'	),
    'PROP_VALUE',		vector ('SYS_DAV_PROP'	, 1, 'text'	, 'E_DESCRIPTION'	),
    'RES_TAGS',			vector ('all-tags'	, 0, 'varchar'  , 'E_TAGS'	), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',		vector ('public-tags'	, 0, 'varchar'	, 'E_TAGS'	), -- 'varchar', not 'text-tag' because there's no free-text in table!
    'RES_PRIVATE_TAGS',		vector ('private-tags'	, 0, 'varchar'	, 'E_TAGS'	), -- 'varchar', not 'text-tag' because there's no free-text in table!
    'RDF_PROP',			vector ('fake-prop'	, 1, 'varchar'	, NULL	),
    'RDF_VALUE',		vector ('fake-prop'	, 2, 'XML'	, NULL	),
    'RDF_OBJ_VALUE',		vector ('fake-prop'	, 3, 'XML'	, NULL	)
    );
}
;

create procedure "calendar_DAV_FC_TABLE_METAS" (inout table_metas any)
{
  table_metas := vector (
    'EVENTS'             , vector (      ''      ,
                                        ''      ,
                                                'E_SUBJECT'    , 'E_SUBJECT'  , '[__quiet] /' ),
    'WA_INSTANCE'         , vector (      ''      ,
                                        ''      ,
                                                'WAI_NAME'     , 'WAI_NAME'   , '[__quiet] /' ),
    'WA_MEMBER'         , vector (      ''      ,
                                        ''      ,
                                                'WAM_INST'     , 'WAM_INST'   , '[__quiet] /' ),

    'SYS_USERS'   , vector (      ''      ,
                                        ''      ,
                                                NULL            , NULL          , NULL          ),
    'public-tags'	, vector (	'  '	,
									''	,
						'E_TAGS'	, 'E_TAGS'	, NULL	),
    'private-tags'	, vector (	' '	,
					' '	,
						'E_TAGS'	, 'E_TAGS'	, NULL	),
    'all-tags'		, vector (	' '	,
					' '	,
						'E_TAGS'	, 'E_TAGS'	, NULL	),
    'fake-prop'	, vector (	'\n  inner join WS.WS.SYS_DAV_PROP as ^{alias}^ on ((^{alias}^.PROP_PARENT_ID is null) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'	,
					'\n  exists (select 1 from WS.WS.SYS_DAV_PROP as ^{alias}^ where (^{alias}^.PROP_PARENT_ID is null) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'	,
						'PROP_VALUE'	, 'PROP_VALUE'	, '[__quiet __davprop xmlns:virt="virt"] fakepropthatprobablyneverexists'	)
	);
}
;

create function "calendar_DAV_FC_PRINT_WHERE" (inout filter any, in param_uid integer) returns varchar
{
	declare pred_metas, cmp_metas, table_metas any;
	declare used_tables any;
	-- dbg_obj_princ ('Blog_POST_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
	"calendar_DAV_FC_PRED_METAS" (pred_metas);
	DAV_FC_CMP_METAS (cmp_metas);
	"calendar_DAV_FC_TABLE_METAS" (table_metas);
	used_tables := vector(
		'EVENTS', vector ('EVENTS', '_top', null, vector (), vector (), vector ()),
		'WA_INSTANCE', vector ('WA_INSTANCE', '_instances', null, vector (), vector (), vector ()),
		'WA_MEMBER', vector ('WA_MEMBER', '_members', null, vector (), vector (), vector ()),
		'SYS_USERS', vector ('SYS_USERS', '_users', null, vector (), vector (), vector ())
	);
	return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "calendar_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path any, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
	-- dbg_obj_princ ('calendar_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
	declare st, access, qry_text, execstate, execmessage varchar;
	declare res any;
	declare cond_list, execmeta, execrows any;
	declare sub, post_id, condtext, cond_key varchar;
	declare ownergid, owner_uid, domain_id integer;
	"calendar_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
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
		if (sub = 'calendar')
		{
			domain_id := coalesce ((select C.WAI_ID
				from SYS_USERS A,
				WA_MEMBER B,
				WA_INSTANCE C
			where A.U_ID = owner_uid
			  and B.WAM_USER = A.U_ID
			  and B.WAM_MEMBER_TYPE = 1
			  and B.WAM_INST = C.WAI_NAME
			  and C.WAI_TYPE_NAME = 'Calendar'
			  and "calendar_FIXNAME"(C.WAI_NAME) = path_parts[1]));
			if (domain_id is null)
				goto finalize;
		}
		else
			goto finalize;
	}
	cond_key := sprintf ('Calendar&%d', coalesce (domain_id, 0));
	condtext := get_keyword (cond_key, compilation);
    if (condtext is null and 0)
	{
	  cond_list := get_keyword ('', compilation);
	  if (sub is not null)
		cond_list := vector_concat (cond_list, vector ( vector ('E_DOMAIN_ID', '=', domain_id)));
	  condtext := "calendar_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
	  compilation := vector_concat (compilation, vector (cond_key, condtext));
	}
	execstate := '00000';
        qry_text := 'select concat (DAV_CONCAT_PATH (_param.detcolpath, ''calendar''), ''/'', "calendar_FIXNAME" (WAI_NAME), ''/'', "calendar_COMPOSE_ICS_NAME" (_top.E_ID, _top.E_SUBJECT, _top.E_EVENT_START, _top.E_EVENT_END)),
		''R'', 1024, _top.E_UPDATED,
                vector (UNAME_CALENDAR(), ?, _users.U_ID, 3, _top.E_DOMAIN_ID, 0, 0, 0, 0),
                ''110000000RR'', http_nogroup_gid(), _users.U_ID, _top.E_UPDATED, ''text/calendar'', "calendar_COMPOSE_ICS_NAME" (_top.E_ID, _top.E_SUBJECT, _top.E_EVENT_START, _top.E_EVENT_END)
		from
		(select top 1 ? as detcolpath from WS.WS.SYS_DAV_COL) as _param,
		CAL.WA.EVENTS as _top
		join DB.DBA.WA_INSTANCE as _instances on (WAI_ID = E_DOMAIN_ID and WAI_TYPE_NAME = ''Calendar'')
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

create function UNAME_CALENDAR() returns any
{
	return UNAME'calendar';
}
;

create function "calendar_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout kind_id integer, inout muser_id integer, inout domain_id integer, inout year_id integer, inout month_id integer) returns any
{
	--dbg_obj_princ ('calendar_DAV_SEARCH_ID_IMPL (', detcol_id, path_parts, what, kind_id, muser_id, domain_id, year_id, month_id, ')');
	declare ownergid, owner_uid, ctr, len integer;
	declare hitlist any;
	declare access, colpath, tag_id varchar;
	tag_id := null;
	"calendar_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);
	if (0 = length(path_parts))
	{
		if ('C' <> what)
			return -1;
		return vector (UNAME'calendar', detcol_id, owner_uid, kind_id, domain_id, year_id, month_id, 0, 0);
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
	while (ctr < len)
	{
		if (ctr = 0)
		{
			hitlist := vector ();
			for select C.WAI_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Calendar'
					  and "calendar_FIXNAME"(C.WAI_NAME) = path_parts[ctr]
			do
			{
				hitlist := vector_concat (hitlist, vector (D_ID));
			}
            if (length (hitlist) <> 1)
				return -1;
			domain_id := hitlist[0];
		}
		else if (ctr = 1)
		{
			if (equ(path_parts[1], 'Date'))
				kind_id := 2;
			else if (equ(path_parts[1], 'Events'))
				kind_id := 0;
			else if (equ(path_parts[1], 'Tasks'))
				kind_id := 1;
            else if (equ(path_parts[1], 'Gems'))
                kind_id := 3;
            if ((kind_id = 1 or kind_id = 0 or kind_id = 3) and len > 2)
				return -1;
			if (kind_id = 2 and len > 4)
				return -1;
		}
		else if (ctr = 2 and kind_id = 2)
		{				
			hitlist := vector ();
			for select distinct year(D.E_UPDATED) as D_ID
					from SYS_USERS A,
						WA_MEMBER B,
						WA_INSTANCE C,
						CAL.WA.EVENTS D
				where A.U_ID = owner_uid
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Calendar'
					and D.E_DOMAIN_ID = C.WAI_ID
					and D.E_DOMAIN_ID = domain_id
					and year(D.E_UPDATED) = atoi(path_parts[ctr])
			do
			{
				hitlist := vector_concat (hitlist, vector (D_ID));
			}
			if (length (hitlist) <> 1)
				return -1;
			year_id := hitlist[0];
		}
		else if (ctr = 3 and kind_id = 2)
		{				
			hitlist := vector ();
			for select distinct month(D.E_UPDATED) as D_ID
				from SYS_USERS A,
					WA_MEMBER B,
					WA_INSTANCE C,
					CAL.WA.EVENTS D
				where A.U_ID = owner_uid
					and B.WAM_USER = A.U_ID
					and B.WAM_MEMBER_TYPE = 1
					and B.WAM_INST = C.WAI_NAME
					and C.WAI_TYPE_NAME = 'Calendar'
					and D.E_DOMAIN_ID = C.WAI_ID
					and D.E_DOMAIN_ID = domain_id
					and monthname(D.E_UPDATED) = path_parts[ctr]
			do
			{
				hitlist := vector_concat (hitlist, vector (D_ID));
			}
			if (length (hitlist) <> 1)
				return -1;
			month_id := hitlist[0];
		}
		ctr := ctr + 1;
	}
	if ('C' = what)
		return vector (UNAME'calendar', detcol_id, owner_uid, kind_id, domain_id, year_id, month_id, 0, 0);
	hitlist := vector ();
	if (kind_id = 0 or kind_id = 1)
	{
		for select distinct E_ID
			from CAL.WA.EVENTS
			where "calendar_COMPOSE_ICS_NAME" (E_ID, E_SUBJECT, E_EVENT_START, E_EVENT_END) = path_parts[ctr] and E_DOMAIN_ID = domain_id
		do
		{
			hitlist := vector_concat (hitlist, vector (E_ID));
		}
	}
    else if (kind_id = 3)
    {
		if ('Calendar.rss' = path_parts[ctr])
			hitlist := vector_concat (hitlist, vector (-1));
		if ('Calendar.atom' = path_parts[ctr])
			hitlist := vector_concat (hitlist, vector (-2));
		if ('Calendar.rdf' = path_parts[ctr])
			hitlist := vector_concat (hitlist, vector (-3));
    }
	else if (kind_id = 2)
	{
		for select distinct D.E_ID as D_ID
					 from SYS_USERS A,
						  WA_MEMBER B,
						  WA_INSTANCE C,
						  CAL.WA.EVENTS D
					where A.U_ID = owner_uid
					  and B.WAM_USER = A.U_ID
					  and B.WAM_MEMBER_TYPE = 1
					  and B.WAM_INST = C.WAI_NAME
					  and C.WAI_TYPE_NAME = 'Calendar'
					  and D.E_DOMAIN_ID = C.WAI_ID
					  and D.E_DOMAIN_ID = domain_id
					  and month(D.E_UPDATED) = month_id
					  and year(D.E_UPDATED) = year_id
					  and "calendar_COMPOSE_ICS_NAME" (E_ID, E_SUBJECT, E_EVENT_START, E_EVENT_END) = path_parts[ctr]
		do
		{
			hitlist := vector_concat (hitlist, vector (D_ID));
		}
	}
	if (length (hitlist) <> 1)
		return -1;
	return vector (UNAME'calendar', detcol_id, owner_uid, kind_id, domain_id, year_id, month_id, hitlist[0], 0);
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "calendar_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare kind_id, u_id, year_id, month_id, domain_id integer;
  kind_id := -1;
  --dbg_obj_princ ('calendar_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  return "calendar_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, kind_id, u_id, domain_id, year_id, month_id);
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "calendar_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  --dbg_obj_princ ('calendar_DAV_SEARCH_PATH (', id, what, ')');
  return NULL;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "calendar_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "calendar_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;

create procedure CAL.WA.det_export_vcal (
  in domain_id integer,
  in tz integer,
  in event_id integer)
{
  declare S, url, tzID, tzName varchar;
  declare sStream any;

  tzID := sprintf ('GMT%s%04d', case when cast (tz as integer) < 0 then '-' else '+' end,  tz);
  tzName := sprintf ('GMT %s%02d:00', case when cast (tz as integer) < 0 then '-' else '+' end,  abs(floor (tz / 60)));

  sStream := string_output();

  -- start
  http ('BEGIN:VCALENDAR\r\n', sStream);
  http ('VERSION:2.0\r\n', sStream);
  http ('BEGIN:VTIMEZONE\r\n', sStream);
  http (sprintf ('TZID:%s\r\n', tzID), sStream);
  http ('BEGIN:STANDARD\r\n', sStream);
  http (sprintf ('TZOFFSETTO:%s\r\n', CAL.WA.tz_string (tz)), sStream);
  http (sprintf ('TZNAME:%s\r\n', tzName), sStream);
  http ('END:STANDARD\r\n', sStream);
  http ('END:VTIMEZONE\r\n', sStream);

  -- events
  for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 0 and E_ID = event_id) do {
      http ('BEGIN:VEVENT\r\n', sStream);
    url := sprintf ('http://%s%s/%U/calendar/%U/Event/', SIOC.DBA.get_cname(), SIOC.DBA.get_base_path (), CAL.WA.domain_owner_name (domain_id), CAL.WA.domain_name (domain_id));
    CAL.WA.export_vcal_line ('URL', url || cast (E_ID as varchar), sStream);
    CAL.WA.export_vcal_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
    CAL.WA.export_vcal_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
    CAL.WA.export_vcal_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
    CAL.WA.export_vcal_line ('SUMMARY', E_SUBJECT, sStream);
    CAL.WA.export_vcal_line ('DESCRIPTION', E_DESCRIPTION, sStream);
    CAL.WA.export_vcal_line ('LOCATION', E_LOCATION, sStream);
    CAL.WA.export_vcal_line ('CATEGORIES', replace (E_TAGS, ',', ';'), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTSTART;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_START, tz)), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTEND;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_END, tz)), sStream);
    CAL.WA.export_vcal_line ('RRULE', CAL.WA.vcal_recurrence2str (E_REPEAT, E_REPEAT_PARAM1, E_REPEAT_PARAM2, E_REPEAT_PARAM3, E_REPEAT_UNTIL), sStream);
    --CAL.WA.export_vcal_line ('DALARM', CAL.WA.vcal_reminder2str (E_REMINDER), sStream);
      http ('END:VEVENT\r\n', sStream);
    }

  -- tasks
  for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 1 and E_ID = event_id) do {
      http ('BEGIN:VTODO\r\n', sStream);
    url := sprintf ('http://%s%s/%U/calendar/%U/Task/', SIOC.DBA.get_cname(), SIOC.DBA.get_base_path (), CAL.WA.domain_owner_name (domain_id), CAL.WA.domain_name (domain_id));
    CAL.WA.export_vcal_line ('URL', url || cast (E_ID as varchar), sStream);
    CAL.WA.export_vcal_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
    CAL.WA.export_vcal_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
    CAL.WA.export_vcal_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
    CAL.WA.export_vcal_line ('SUMMARY', E_SUBJECT, sStream);
    CAL.WA.export_vcal_line ('DESCRIPTION', E_DESCRIPTION, sStream);
    CAL.WA.export_vcal_line ('CATEGORIES', replace (E_TAGS, ',', ';'), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTSTART;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_START, tz)), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTEND;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_END, tz)), sStream);
    CAL.WA.export_vcal_line ('PRIORITY', E_PRIORITY, sStream);
    CAL.WA.export_vcal_line ('STATUS', E_STATUS, sStream);
      http ('END:VTODO\r\n', sStream);
    }

  -- end
  http ('END:VCALENDAR\r\n', sStream);

  return string_output_string(sStream);
}
;

create procedure CAL.WA.export_rss_sqlx_for_det (
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;
  declare qry_text any;
  retValue := string_output ();

  http ('<?xml version ="1.0" encoding="UTF-8"?>\n', retValue);
  http ('<rss version="2.0">\n', retValue);
  http ('<channel>\n', retValue);

  qry_text := (select 
   XMLELEMENT('title', CAL.WA.utf2wide(CAL.WA.domain_name (domain_id))), 
   XMLELEMENT('description', CAL.WA.utf2wide(CAL.WA.domain_description (domain_id))), 
   XMLELEMENT('managingEditor', U_E_MAIL), 
   XMLELEMENT('pubDate', CAL.WA.dt_rfc1123(now ())), 
   XMLELEMENT('generator', 'Virtuoso Universal Server ' || sys_stat('st_dbms_ver')), 
   XMLELEMENT('webMaster', U_E_MAIL), 
   XMLELEMENT('link', CAL.WA.calendar_url (domain_id)) 
  from DB.DBA.SYS_USERS where U_ID = account_id);

  http (serialize_to_UTF8_xml(qry_text), retValue);
  
  qry_text := (select 
   XMLAGG(XMLELEMENT('item', 
     XMLELEMENT('title', CAL.WA.utf2wide (E_SUBJECT)), 
     XMLELEMENT('description', CAL.WA.utf2wide (E_DESCRIPTION)), 
     XMLELEMENT('guid', E_ID), 
     XMLELEMENT('link', CAL.WA.event_url (domain_id, E_ID)), 
     XMLELEMENT('pubDate', CAL.WA.dt_rfc1123 (E_UPDATED)), 
     (select XMLAGG (XMLELEMENT ('category', TV_TAG)) from CAL..TAGS_VIEW where tags = E_TAGS), 
     XMLELEMENT('http://www.openlinksw.com/ods/:modified', CAL.WA.dt_iso8601 (E_UPDATED)))) 
 from (select top 15  
         E_SUBJECT, 
         E_DESCRIPTION, 
         E_UPDATED, 
         E_TAGS, 
         E_ID 
       from 
         CAL.WA.EVENTS 
       where E_DOMAIN_ID = domain_id 
       order by E_UPDATED desc) x );
       
  http (serialize_to_UTF8_xml(qry_text), retValue);

  http ('</channel>\n', retValue);
  http ('</rss>\n', retValue);

  retValue := string_output_string (retValue);
  return retValue;
}
;

create procedure CAL.WA.export_atom_sqlx_for_det (
  in domain_id integer,
  in account_id integer)
{
  declare xml_entity, xsltTemplate any;
  xsltTemplate := CAL.WA.xslt_full ('rss2atom03.xsl');
  if (CAL.WA.settings_atomVersion (CAL.WA.settings (account_id)) = '1.0')
    xsltTemplate := CAL.WA.xslt_full ('rss2atom.xsl');
  
  xml_entity := xtree_doc(CAL.WA.export_rss_sqlx_for_det (domain_id, account_id));
    
  xml_entity := xslt(xsltTemplate, xml_entity);
  return serialize_to_UTF8_xml(xml_entity);
}
;

create procedure CAL.WA.export_rdf_sqlx_for_det (
  in domain_id integer,
  in account_id integer)
{
	declare xml_entity, xsltTemplate any;
	xsltTemplate := CAL.WA.xslt_full ('rss2rdf.xsl');	
	xml_entity := xtree_doc(CAL.WA.export_rss_sqlx_for_det (domain_id, account_id));
	xml_entity := xslt(xsltTemplate, xml_entity);
	return serialize_to_UTF8_xml(xml_entity);
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "calendar_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
	--dbg_obj_princ ('calendar_DAV_RES_CONTENT (', id, ', content, type, ', content_mode, ')');
    if (id[7] < 0)
    {
		type := 'text/xml';
		if (id[7] = -1)
			content := CAL.WA.export_rss_sqlx_for_det (id[4], id[2]);
		if (id[7] = -2)
			content := CAL.WA.export_atom_sqlx_for_det (id[4], id[2]);
		if (id[7] = -3)
			content := CAL.WA.export_rdf_sqlx_for_det (id[4], id[2]);
		return 0;
    }
	declare tz integer;
    type := 'text/calendar';
	whenever not found goto endline;
	tz := timezone(now());
	if (id[7] is not null)
	{
        content := CAL.WA.det_export_vcal (id[4], tz, id[7]);
	}
endline:
	return 0;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "calendar_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "calendar_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('calendar_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "calendar_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('calendar_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "calendar_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "calendar_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('calendar_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "calendar_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('calendar_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "calendar_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('calendar_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;
