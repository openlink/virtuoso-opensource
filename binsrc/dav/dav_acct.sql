--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

create function DAV_SPACE_QUOTA_PARENT (in res_path varchar, out _u_id integer, out _above_hy datetime, out _dav_use numeric, out _total_use numeric, out _quota numeric) returns varchar
{
  declare head, tail, _home_path varchar;
  declare slash_pos integer;
  declare cr cursor for select DSQ_HOME_PATH, DSQ_U_ID, DSQ_ABOVE_HI_YELLOW, DSQ_DAV_USE, DSQ_TOTAL_USE, DSQ_QUOTA from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_HOME_PATH >= head and DSQ_HOME_PATH <= res_path;
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_PARENT (', res_path, ')');
  _home_path := '';
  head := '/';
  tail := subseq (res_path, 1);
  while (1)
    {
      open cr;
      whenever not found goto nf;
      fetch cr into _home_path, _u_id, _above_hy, _dav_use, _total_use, _quota;
      close cr;
      if (_home_path = "LEFT" (res_path, length (_home_path)))
        goto done;

nf:
      close cr;
      slash_pos := strchr (tail, '/');
      if (slash_pos is null)
        {
          _home_path := null;
          goto done;
        }
      head := head || "LEFT" (tail, slash_pos + 1);
      tail := subseq (tail, slash_pos + 1);
      if (head < _home_path)
        goto nf;
    }

done:
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_PARENT () fills ', _u_id, _above_hy, _dav_use, _total_use, _quota, ' returns ', _home_path);
  return _home_path;
}
;

create function DAV_ADD_SPACE_QUOTA (in _home_path varchar, in _u_id integer, in _quota numeric) returns integer
{
  declare home_id any;
  declare old_u_id integer;
  declare reloc_path varchar;
  declare reloc_dav_use, reloc_quota, old_dav_use, dav_use, old_app_use, old_max_dav_use, old_max_app_use numeric;
  declare reloc_above_hy, old_above_hy datetime;
  if (not exists (select top 1 1 from WS.WS.SYS_DAV_USER where U_ID = _u_id))
    return -6;
  home_id := DAV_SEARCH_ID (_home_path, 'C');
  if (DAV_HIDE_ERROR (home_id) is null)
    return home_id;
  if (not (isinteger (home_id)))
    return -33;
  if (_home_path <> '/')
    {
      declare parent_path varchar;
      declare parent_u_id integer;
      declare parent_above_hy datetime;
      declare parent_dav_use, parent_total_use, parent_quota numeric;
      parent_path := DAV_SPACE_QUOTA_PARENT (_home_path, parent_u_id, parent_above_hy, parent_dav_use, parent_total_use, parent_quota);
      if ((parent_path is not null) and (parent_path <> _home_path))
        return -38;
    }
  reloc_path := null;
  old_app_use := 0;
  old_max_app_use := 0;
  if (_u_id is null)
    goto no_old_home;
  whenever not found goto no_old_home;
  select DSQ_HOME_PATH	, DSQ_DAV_USE	, DSQ_APP_USE	, DSQ_MAX_APP_USE	, DSQ_QUOTA	, DSQ_ABOVE_HI_YELLOW
  into reloc_path	, reloc_dav_use	, old_app_use	, old_max_app_use	, reloc_quota	, reloc_above_hy
  from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_U_ID = _u_id;

no_old_home:
  whenever not found goto do_insert;
  select DSQ_U_ID, DSQ_ABOVE_HI_YELLOW, DSQ_DAV_USE, DSQ_MAX_DAV_USE into old_u_id, old_above_hy, old_dav_use, old_max_dav_use from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_HOME_PATH = _home_path;
  if (old_u_id is not null)
    {
      if (old_u_id <> _u_id)
        return -38;
      update WS.WS.SYS_DAV_SPACE_QUOTA set DSQ_QUOTA = _quota where DSQ_HOME_PATH = _home_path and DSQ_QUOTA <> _quota;
    }
  else
    {
      update WS.WS.SYS_DAV_SPACE_QUOTA set
        DSQ_U_ID = _u_id, DSQ_QUOTA = _quota,
        DSQ_APP_USE = old_app_use,
        DSQ_MAX_APP_USE = old_max_app_use,
        DSQ_MAX_TOTAL_USE = __max (DSQ_MAX_DAV_USE, DSQ_DAV_USE + DSQ_APP_USE),
        DSQ_ABOVE_HI_YELLOW = null, DSQ_LAST_WARNING = null
      where DSQ_HOME_PATH = _home_path;
      old_above_hy := null;
    }
  DAV_SPACE_QUOTA_YELLOW_TRACK (_home_path, _u_id, old_above_hy, old_dav_use + old_app_use, _quota);
  goto update_reloc_path;

do_insert:
  dav_use := coalesce (
    (select SUM (cast (length (RES_CONTENT) as numeric))
     from WS.WS.SYS_DAV_RES
     where RES_FULL_PATH between _home_path and DAV_COL_PATH_BOUNDARY (_home_path) ),
    0 );
  insert into WS.WS.SYS_DAV_SPACE_QUOTA
    (DSQ_U_ID		, DSQ_HOME_PATH		,
     DSQ_DAV_USE	, DSQ_APP_USE		, DSQ_TOTAL_USE			,
     DSQ_MAX_DAV_USE	, DSQ_MAX_APP_USE	, DSQ_MAX_TOTAL_USE		,
     DSQ_QUOTA		, DSQ_ABOVE_HI_YELLOW	, DSQ_LAST_WARNING	)
  values
    (_u_id		, _home_path		,
     dav_use		, old_app_use		, dav_use + old_app_use		,
     dav_use		, old_max_app_use	, dav_use + old_max_app_use	,
     _quota		, NULL			, NULL			);
  DAV_SPACE_QUOTA_YELLOW_TRACK (_home_path, _u_id, null, dav_use + old_app_use, _quota);

update_reloc_path:
  if ((reloc_path is not null) and (reloc_path <> _home_path))
    {
      update WS.WS.SYS_DAV_SPACE_QUOTA set
        DSQ_U_ID = null, DSQ_APP_USE = 0, DSQ_TOTAL_USE = DSQ_DAV_USE,
        DSQ_MAX_APP_USE = 0, DSQ_MAX_TOTAL_USE = DSQ_MAX_DAV_USE,
        DSQ_LAST_WARNING = null
      where DSQ_HOME_PATH = reloc_path;
      DAV_SPACE_QUOTA_YELLOW_TRACK (reloc_path, null, reloc_above_hy, reloc_dav_use, reloc_quota);
    }
  return home_id;
}
;

create function DAV_DEL_SPACE_QUOTA (in _home_path varchar) returns integer
{
  declare old_u_id integer;
  declare old_quota numeric;
  declare old_above_hy datetime;
  whenever not found goto nf;
  select DSQ_U_ID, DSQ_QUOTA, DSQ_ABOVE_HI_YELLOW into old_u_id, old_quota, old_above_hy
  from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_HOME_PATH = _home_path;
  DAV_SPACE_QUOTA_YELLOW_TRACK (_home_path, old_u_id, old_above_hy, 0, old_quota);
  delete from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_HOME_PATH = _home_path;
  return 0;

nf:
  return -1;
}
;

create procedure DAV_SPACE_QUOTA_YELLOW_TRACK (in _home_path varchar, in _u_id integer, in old_above_hy datetime, in total_use numeric, in _quota numeric)
{
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_YELLOW_TRACK (', _home_path, _u_id, old_above_hy, total_use, _quota, ')');
  set isolation='serializable';
  if (old_above_hy is not null)
    {
      if (total_use < (_quota * 0.75))
        {
          declare exit handler for sqlstate '*'
            {
              -- dbg_obj_princ ('Error in DAV_SPACE_QUOTA_LO_YELLOW_DOWN (', _home_path, '): ', __SQL_STATE, __SQL_MESSAGE);
              ;
            };
          DAV_SPACE_QUOTA_LO_YELLOW_DOWN (_home_path, _u_id, total_use, _quota);
          update WS.WS.SYS_DAV_SPACE_QUOTA set DSQ_ABOVE_HI_YELLOW = null where DSQ_HOME_PATH = _home_path;
        }
    }
  else
    {
      if (total_use > (_quota * 0.90))
        {
          update WS.WS.SYS_DAV_SPACE_QUOTA set DSQ_ABOVE_HI_YELLOW = now() where DSQ_HOME_PATH = _home_path;
          declare exit handler for sqlstate '*'
            {
              -- dbg_obj_princ ('Error in DAV_SPACE_QUOTA_HI_YELLOW_UP (', _home_path, '): ', __SQL_STATE, __SQL_MESSAGE);
              ;
            };
          DAV_SPACE_QUOTA_HI_YELLOW_UP (_home_path, _u_id, total_use, _quota);
        }
    }
}
;

create procedure DAV_SPACE_QUOTA_SIGNAL (in res_path varchar, in home_path varchar, in _u_id integer, in _total_use numeric, in _quota numeric)
{
  declare u_descr, msg varchar;
  declare owner_u_id, home_col_id integer;
  if (http_dav_uid () = coalesce (connection_get ('DAVBillingUserID'), -12))
    return;
  if (_u_id is not null)
    u_descr := coalesce ((select 'quota of user "' || U_NAME || '"' from SYS_USERS where U_ID = _u_id), sprintf ('quota of user #%d', _u_id));
  else
    {
      home_col_id := DAV_SEARCH_ID (home_path, 'C');
      if (DAV_HIDE_ERROR (home_col_id) is null)
        signal ('HT500', sprintf ('DAV integrity violation: ancestor collection %s not found for resource %s', home_path, res_path));
      if (not isinteger (home_col_id))
        signal ('HT500', sprintf ('DAV integrity violation: collection %s is a DET subcollection, can not use DAV quotas for %s', home_path, res_path));
      owner_u_id := coalesce ((select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = home_col_id), http_nobody_uid());
    u_descr := coalesce ((select 'owner "' || U_NAME || '"' from SYS_USERS where U_ID = owner_u_id), sprintf ('owner #%d', owner_u_id));
    }
  rollback work;
  msg := sprintf ('DAV quota exceeded for collection %s (%s): only %s bytes allowed but %s required.',
    home_path, u_descr, cast (_quota as varchar), cast (_total_use as varchar) );
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_SIGNAL (', res_path, home_path, _u_id, _total_use, _quota, ') signals ', msg);
  signal ('HT507', msg);
}
;

create procedure DAV_OWNER_DISABLED_SIGNAL (in res_path varchar, in _u_id integer)
{
  declare u_descr, msg varchar;
  declare owner_u_id, home_col_id integer;
  if (_u_id = http_nobody_uid())
    return;
  if (http_dav_uid () = coalesce (connection_get ('DAVBillingUserID'), -12))
    return;
  u_descr := coalesce ((select '"' || U_NAME || '"' from SYS_USERS where U_ID = _u_id), sprintf ('#%d', _u_id));
  rollback work;
  msg := sprintf ('The resource %s is unavailable because resource owner %s is disabled.',
    res_path, u_descr );
  -- dbg_obj_princ ('DAV_OWNER_DISABLED_SIGNAL (', res_path, _u_id ') signals ', msg);
  signal ('HT508', msg);
}
;

create procedure DAV_HOME_DISABLED_SIGNAL (in res_path varchar, in home_path varchar, in _u_id integer)
{
  declare u_descr, msg varchar;
  declare owner_u_id, home_col_id integer;
  if (http_dav_uid () = coalesce (connection_get ('DAVBillingUserID'), -12))
    return;
  u_descr := coalesce ((select 'user "' || U_NAME || '"' from SYS_USERS where U_ID = _u_id), sprintf ('user #%d', _u_id));
  rollback work;
  msg := sprintf ('Access to a home DAV collection %s of a disabled account (%s) is blocked.',
    home_path, u_descr );
  -- dbg_obj_princ ('DAV_HOME_DISABLED_SIGNAL (', res_path, home_path, _u_id) signals ', msg);
  signal ('HT509', msg);
}
;

create procedure DAV_SPACE_QUOTA_RES_INSERT (in newr_path varchar, in newr_len integer)
{
  declare parent_path varchar;
  declare parent_u_id integer;
  declare parent_above_hy datetime;
  declare parent_dav_use, parent_total_use, parent_quota numeric;
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_INSERT (', newr_path, newr_len, ')');
  parent_path := DAV_SPACE_QUOTA_PARENT (newr_path, parent_u_id, parent_above_hy, parent_dav_use, parent_total_use, parent_quota);
  if (parent_path is null)
    goto done;
  set isolation='committed';
  if (parent_u_id is not null and
    exists (
      select top 1 1 from SYS_USERS
      where U_ID = parent_u_id and U_ACCOUNT_DISABLED ) )
    DAV_HOME_DISABLED_SIGNAL (newr_path, parent_path, parent_u_id);
  set isolation='serializable';
  parent_dav_use := parent_dav_use + newr_len;
  parent_total_use := parent_total_use + newr_len;
  if (parent_total_use > parent_quota)
    DAV_SPACE_QUOTA_SIGNAL (newr_path, parent_path, parent_u_id, parent_total_use, parent_quota);
  update WS.WS.SYS_DAV_SPACE_QUOTA set
    DSQ_DAV_USE = parent_dav_use,
    DSQ_TOTAL_USE = parent_total_use,
    DSQ_MAX_DAV_USE = __max (DSQ_MAX_DAV_USE, parent_dav_use),
    DSQ_MAX_TOTAL_USE = __max (DSQ_MAX_TOTAL_USE, parent_total_use)
  where DSQ_HOME_PATH = parent_path;
  DAV_SPACE_QUOTA_YELLOW_TRACK (parent_path, parent_u_id, parent_above_hy, parent_total_use, parent_quota);

done:
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_INSERT (', newr_path, newr_len, ') done');
  ;
}
;

create procedure DAV_SPACE_QUOTA_RES_DELETE (in oldr_path varchar, in oldr_len integer)
{
  declare parent_path varchar;
  declare parent_u_id integer;
  declare parent_above_hy datetime;
  declare parent_dav_use, parent_total_use, parent_quota numeric;
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_DELETE (', oldr_path, oldr_len, ')');
  parent_path := DAV_SPACE_QUOTA_PARENT (oldr_path, parent_u_id, parent_above_hy, parent_dav_use, parent_total_use, parent_quota);
  if (parent_path is null)
    goto done;
  set isolation='committed';
  if (parent_u_id is not null and
    exists (
      select top 1 1 from SYS_USERS
      where U_ID = parent_u_id and U_ACCOUNT_DISABLED ) )
    DAV_HOME_DISABLED_SIGNAL (oldr_path, parent_path, parent_u_id);
  set isolation='serializable';
  parent_dav_use := parent_dav_use - oldr_len;
  parent_total_use := parent_total_use - oldr_len;
  if ((parent_dav_use < 0) or (parent_total_use < 0))
    {
      -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_DELETE: negative use! DSQ_DAV_USE = ', parent_dav_use, ', DSQ_TOTAL_USE = ', parent_total_use);
      parent_dav_use := coalesce (
        (select SUM (cast (length (RES_CONTENT) as numeric))
          from WS.WS.SYS_DAV_RES
          where RES_FULL_PATH between parent_path and DAV_COL_PATH_BOUNDARY (parent_path) ),
        0 );
      parent_total_use := parent_dav_use + (select __max (DSQ_APP_USE, 0) from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_HOME_PATH = parent_path);
    }
  update WS.WS.SYS_DAV_SPACE_QUOTA set
    DSQ_DAV_USE = parent_dav_use,
    DSQ_TOTAL_USE = parent_total_use
  where DSQ_HOME_PATH = parent_path;
  DAV_SPACE_QUOTA_YELLOW_TRACK (parent_path, parent_u_id, parent_above_hy, parent_total_use, parent_quota);

done:
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_DELETE (', oldr_path, oldr_len, ') done');
  ;
}
;

create procedure DAV_SPACE_QUOTA_RES_UPDATE (in oldr_path varchar, in oldr_len integer, in newr_path varchar, in newr_len integer)
{
  declare src_path, tgt_path varchar;
  declare src_u_id, tgt_u_id integer;
  declare src_above_hy, tgt_above_hy datetime;
  declare src_dav_use, src_total_use, src_quota, tgt_dav_use, tgt_total_use, tgt_quota numeric;
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_UPDATE (', oldr_path, oldr_len, newr_path, newr_len, ')');
  src_path := DAV_SPACE_QUOTA_PARENT (oldr_path, src_u_id, src_above_hy, src_dav_use, src_total_use, src_quota);
  set isolation = 'committed';
  if (src_path is not null and src_u_id is not null and
    exists (
      select top 1 1 from SYS_USERS
      where U_ID = src_u_id and U_ACCOUNT_DISABLED ) )
    DAV_HOME_DISABLED_SIGNAL (oldr_path, src_path, src_u_id);
  set isolation='serializable';
  if ((oldr_path = newr_path) or (src_path = "LEFT" (newr_path, length (src_path))))
    {
      -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_UPDATE: local move');
      if (src_path is null)
        goto done; -- tgt_path will be the same RES_FULL_PATH, hence both source and target are not accounted.
      if (oldr_len = newr_len)
        goto done; -- Move inside subtree and same size, hence nothing to do.
      -- at this point we know that src_path = tgt_path and both are not null,
      tgt_path := src_path;
      tgt_above_hy := src_above_hy;
      tgt_dav_use := src_dav_use;
      tgt_total_use := src_total_use;
      tgt_quota := src_quota;
      if (oldr_len < newr_len)
        { -- this is an equivalent of adding difference length to tgt from outside of subtree
          newr_len := newr_len - oldr_len;
          src_path := null;
        }
      else
        { -- this is an equivalent of removing difference length from src to outside of subtree
          oldr_len := oldr_len - newr_len;
          tgt_path := null;
        }
    }
  else
    {
      -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_UPDATE: non-local move');
      tgt_path := DAV_SPACE_QUOTA_PARENT (newr_path, tgt_u_id, tgt_above_hy, tgt_dav_use, tgt_total_use, tgt_quota);
      if (src_path is null and tgt_path is null)
        goto done; -- Move outside any subrtees with quotas.
      set isolation='committed';
      if (tgt_u_id is not null and
        exists (
	  select top 1 1 from SYS_USERS
	  where U_ID = tgt_u_id and U_ACCOUNT_DISABLED ) )
        DAV_HOME_DISABLED_SIGNAL (newr_path, tgt_path, tgt_u_id);
      set isolation='serializable';
    }
  if (tgt_path is not null)
    {
      tgt_dav_use := tgt_dav_use + newr_len;
      tgt_total_use := tgt_total_use + newr_len;
      if (tgt_total_use > tgt_quota)
        DAV_SPACE_QUOTA_SIGNAL (newr_path, tgt_path, tgt_u_id, tgt_total_use, tgt_quota);
      update WS.WS.SYS_DAV_SPACE_QUOTA set
        DSQ_DAV_USE = tgt_dav_use,
        DSQ_TOTAL_USE = tgt_total_use,
        DSQ_MAX_DAV_USE = __max (DSQ_MAX_DAV_USE, tgt_dav_use),
        DSQ_MAX_TOTAL_USE = __max (DSQ_MAX_TOTAL_USE, tgt_total_use)
      where DSQ_HOME_PATH = tgt_path;
      DAV_SPACE_QUOTA_YELLOW_TRACK (tgt_path, tgt_u_id, tgt_above_hy, tgt_total_use, tgt_quota);
    }
  if (src_path is not null)
    {
      src_dav_use := src_dav_use - oldr_len;
      src_total_use := src_total_use - oldr_len;
      if ((src_dav_use < 0) or (src_total_use < 0))
        {
          -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_UPDATE: negative use! DSQ_DAV_USE = ', src_dav_use, ', DSQ_TOTAL_USE = ', src_total_use);
          src_dav_use :=  coalesce (
            (select SUM (cast (length (RES_CONTENT) as numeric))
              from WS.WS.SYS_DAV_RES
              where RES_FULL_PATH between src_path and DAV_COL_PATH_BOUNDARY (src_path) ),
            0 );
          src_total_use := src_dav_use + (select __max (DSQ_APP_USE, 0) from WS.WS.SYS_DAV_SPACE_QUOTA where DSQ_HOME_PATH = src_path);
        }
      update WS.WS.SYS_DAV_SPACE_QUOTA set
        DSQ_DAV_USE = src_dav_use,
        DSQ_TOTAL_USE = src_total_use
      where DSQ_HOME_PATH = src_path;
      DAV_SPACE_QUOTA_YELLOW_TRACK (src_path, src_u_id, src_above_hy, src_total_use, src_quota);
    }

done:
  -- dbg_obj_princ ('DAV_SPACE_QUOTA_RES_UPDATE (', oldr_path, oldr_len, newr_path, newr_len, ') done');
  ;
}
;
