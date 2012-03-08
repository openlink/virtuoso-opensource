--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

create table WS.WS.HOSTFS_COL
(
  COL_ID		integer not null primary key,
  COL_FULL_PATH		varchar not null,
  COL_PARENT_ID		integer,
  COL_CR_TIME		datetime,
  COL_MOD_TIME		datetime,
  COL_SCAN_TIME		datetime,
  COL_NEXT_SCAN_TIME	datetime,
  COL_NAME		varchar not null
  )
create index HOSTFS_COL_PARENT_ID on WS.WS.HOSTFS_COL (COL_PARENT_ID)
create index HOSTFS_COL_FULL_PATH on WS.WS.HOSTFS_COL (COL_FULL_PATH)
create index HOSTFS_COL_NEXT_SCAN_TIME on WS.WS.HOSTFS_COL (COL_NEXT_SCAN_TIME)
;

alter table WS.WS.HOSTFS_COL add COL_NAME varchar not null
;

create table WS.WS.HOSTFS_RES
(
  RES_ID 		integer not null primary key,
  RES_NAME 		varchar (256),
  RES_COL 		integer,
  RES_TYPE 		varchar,
  RES_FT_MODE		char (1), -- 'x' file XML, 't' file text, 'X' cached XML, 'T' cached text, 'N' no text data (so RES_NAME is indexed as text).
  RES_LENGTH		integer,
  RES_CR_TIME		datetime,	-- creation time
  RES_MOD_TIME		datetime,	-- modification time
  RES_SCAN_TIME		datetime,	-- last file scan time
  RES_NEXT_SCAN_TIME	datetime,
  RES_PERMS 		char (11)
)
create index HOSTFS_RES_COL on WS.WS.HOSTFS_RES (RES_COL, RES_NAME)
create index HOSTFS_RES_NEXT_SCAN_TIME on WS.WS.HOSTFS_RES (RES_NEXT_SCAN_TIME)
;

create table WS.WS.HOSTFS_RES_CACHE
(
  RESC_ID		integer not null primary key,
  RESC_MOD_SCAN_TIME	datetime,	-- time of the last scan such that it has detected change in the resource.
  RESC_DATA		long varchar,
  RESC_TOPCOL_ID	integer not null
)
create index HOSTFS_RES_CACHE_TOPCOL_ID on WS.WS.HOSTFS_RES_CACHE (RESC_TOPCOL_ID)
;

alter table WS.WS.HOSTFS_RES_CACHE add RESC_TOPCOL_ID integer not null
;

create table WS.WS.HOSTFS_RES_META
(
  RESM_ID		integer not null primary key,
  RESM_DATA		long XML,
  RESM_TOPCOL_ID	integer not null
)
create index HOSTFS_RES_META_TOPCOL_ID on WS.WS.HOSTFS_RES_META (RESM_TOPCOL_ID)
;

alter table WS.WS.HOSTFS_RES_META add RESM_TOPCOL_ID integer not null
;

create table WS.WS.HOSTFS_RDF_INVERSE
(
  HRI_TOPCOL_ID integer not null,
  HRI_PROP_CATID integer not null,
  HRI_CATVALUE varchar not null,
  HRI_RES_ID integer not null,
  primary key (HRI_TOPCOL_ID, HRI_PROP_CATID, HRI_CATVALUE, HRI_RES_ID)
)
;

create procedure WS.WS.HOSTFS_FEED_RDF_INVERSE (inout propval any, in r_id integer, in is_del integer, in topcol_id integer)
{
  declare resfullpath, path_head, pv varchar;
  declare triplets any;
  triplets := xpath_eval ('[xmlns:virt="virt"] /virt:rdf/virt:top-res/virt:prop[virt:value]', propval, 0);
  foreach (any prop in triplets) do
    {
      declare propname varchar;
      declare prop_catid integer;
      propname := cast (xpath_eval ('name(*[1])', prop) as varchar);
      prop_catid := coalesce ((select RPN_CATID from WS.WS.SYS_RDF_PROP_NAME where RPN_URI = propname));
      if (prop_catid is null)
        {
          prop_catid := WS.WS.GETID ('RPN');
          -- dbg_obj_princ ('HOSTFS_FEEDV_RDF_INVERSE: insert into WS.WS.SYS_RDF_PROP_NAME (RPN_URI, RPN_CATID) values (', propname, prop_catid, ')');
          insert into WS.WS.SYS_RDF_PROP_NAME (RPN_URI, RPN_CATID) values (propname, prop_catid);
        }
      if (is_del)
        delete from WS.WS.HOSTFS_RDF_INVERSE
        where
          (HRI_TOPCOL_ID = topcol_id) and (HRI_PROP_CATID = prop_catid) and
          (HRI_CATVALUE = "CatFilter_ENCODE_CATVALUE" (cast (xpath_eval ('[xmlns:virt="virt"] virt:value', prop) as varchar))) and
          (HRI_RES_ID = r_id);
      else
        insert soft WS.WS.HOSTFS_RDF_INVERSE (HRI_TOPCOL_ID, HRI_PROP_CATID, HRI_CATVALUE, HRI_RES_ID)
        values (
          topcol_id,
          prop_catid,
          "CatFilter_ENCODE_CATVALUE" (cast (xpath_eval ('[xmlns:virt="virt"] virt:value', prop) as varchar)),
          r_id );
    }
}
;


create trigger HOSTFS_RES_META_I after insert on WS.WS.HOSTFS_RES_META referencing new as NP
{
  if (NP.RESM_DATA is not null)
    WS.WS.HOSTFS_FEED_RDF_INVERSE (NP.RESM_DATA, NP.RESM_ID, 0, NP.RESM_TOPCOL_ID);
}
;


create trigger HOSTFS_RES_META_D before delete on WS.WS.HOSTFS_RES_META referencing old as OP
{
  if (OP.RESM_DATA is not null)
    WS.WS.HOSTFS_FEED_RDF_INVERSE (OP.RESM_DATA, OP.RESM_ID, 1, OP.RESM_TOPCOL_ID);
}
;


create trigger HOSTFS_RES_META_U after update on WS.WS.HOSTFS_RES_META referencing old as OP, new as NP
{
  if (OP.RESM_DATA is not null)
    WS.WS.HOSTFS_FEED_RDF_INVERSE (OP.RESM_DATA, OP.RESM_ID, 1, OP.RESM_TOPCOL_ID);
  if (NP.RESM_DATA is not null)
    WS.WS.HOSTFS_FEED_RDF_INVERSE (NP.RESM_DATA, NP.RESM_ID, 0, NP.RESM_TOPCOL_ID);
}
;


--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
--#ENDIF
DB.DBA.vt_create_text_index (fix_identifier_case ('WS.WS.HOSTFS_RES_META'), fix_identifier_case ('RESM_DATA'), fix_identifier_case ('RESM_ID'), 2, 0, NULL, 0, '*ini*', '*ini*')
;

--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
--#ENDIF
DB.DBA.vt_batch_update (fix_identifier_case ('WS.WS.HOSTFS_RES_META'), 'ON', 1)
;

create function WS.WS.HOSTFS_RES_TOPCOL_ID (in r_id integer) returns integer
{
  declare res, parent integer;
  whenever not found goto nf;
  res := parent := (select RES_COL from WS.WS.HOSTFS_RES where RES_ID = r_id);
  while (parent is not null)
    {
      res := parent;
      parent := (select COL_PARENT_ID from WS.WS.HOSTFS_COL where COL_ID = res);
    }
  return res;
nf:
  return 0;
}
;

create procedure WS.WS.HOSTFS_EXTRACT_AND_SAVE_RDF (in resid integer, in resname varchar, in restype varchar, inout rescontent any, in topcol_id integer)
{
  declare resttype varchar;
  declare old_prop_id integer;
  declare html_start, full_xml any;
  declare old_n3, addon_n3 any;
  -- dbg_obj_princ ('DAV_EXTRACT_AND_SAVE_RDF_INT (', resid, resname, restype, rescontent, ')');
  html_start := null;
  full_xml := null;
  --if (restype is null)
    restype := DAV_GUESS_MIME_TYPE (resname, rescontent, html_start);
  -- dbg_obj_princ ('restype is ', restype);
  if (restype is null)
    return;
  addon_n3 := call ('DAV_EXTRACT_RDF_' || restype)(resname, rescontent, html_start);
  -- dbg_obj_princ ('addon_n3 is', addon_n3);
  if (addon_n3 is null)
    return;
  insert replacing WS.WS.HOSTFS_RES_META (RESM_ID, RESM_DATA, RESM_TOPCOL_ID)
  values
    (resid, xml_tree_doc (DAV_RDF_PREPROCESS_RDFXML (addon_n3, N'http://local.virt/this', 1)), topcol_id);
  return;

no_op:
  ;
}
;

create procedure WS.WS.HOSTFS_TEST_RDF (in d_id integer)
{
  -- dbg_obj_princ ('WS.WS.HOSTFS_TEST_RDF (', d_id, ')');
  for select RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE from WS.WS.HOSTFS_RES where RES_ID = d_id do
    {
      -- dbg_obj_princ ('Found (RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE) = (', RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE, ')');
      if ('N' = RES_FT_MODE)
        {
          return 1;
        }
      else if (('T' = RES_FT_MODE) or ('X' = RES_FT_MODE))
        {
          for select RESC_DATA, RESC_TOPCOL_ID from WS.WS.HOSTFS_RES_CACHE where RESC_ID = d_id do
            {
              WS.WS.HOSTFS_EXTRACT_AND_SAVE_RDF (d_id, RES_NAME, RES_TYPE, RESC_DATA, RESC_TOPCOL_ID);
            }
          return 1;
        }
      else if (('t' = RES_FT_MODE) or ('x' = RES_FT_MODE))
        {
          for select COL_FULL_PATH from WS.WS.HOSTFS_COL where COL_ID = RES_COL do
            {
              declare ses any;
	      -- dbg_obj_princ ('Found COL_FULL_PATH = ', COL_FULL_PATH);
              ses := file_to_string_output (COL_FULL_PATH || RES_NAME);
              WS.WS.HOSTFS_EXTRACT_AND_SAVE_RDF (d_id, RES_NAME, RES_TYPE, ses, WS.WS.HOSTFS_RES_TOPCOL_ID (d_id));
            }
          return 1;
        }
    }
  return 0;
}
;

create function
WS.WS.HOSTFS_RES_CACHE_RESC_DATA_INDEX_HOOK (inout vtb any, inout d_id integer) returns integer
{
  -- dbg_obj_princ ('WS.WS.HOSTFS_RES_CACHE_RESC_DATA_INDEX_HOOK ( [], ', d_id, ')');
  whenever sqlstate '*' goto done;
  for select RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE from WS.WS.HOSTFS_RES where RES_ID = d_id do
    {
      -- dbg_obj_princ ('Found (RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE) = (', RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE, ')');
      if ('N' = RES_FT_MODE)
        {
          vt_batch_feed (vtb, RES_NAME, 0, 0);
          return 1;
        }
      else if (('T' = RES_FT_MODE) or ('X' = RES_FT_MODE))
        {
          for select RESC_DATA, RESC_TOPCOL_ID from WS.WS.HOSTFS_RES_CACHE where RESC_ID = d_id do
            {
              vt_batch_feed (vtb, RESC_DATA, 0, case (RES_FT_MODE) when 'X' then 2 else 0 end);
              WS.WS.HOSTFS_EXTRACT_AND_SAVE_RDF (d_id, RES_NAME, RES_TYPE, RESC_DATA, RESC_TOPCOL_ID);
            }
          return 1;
        }
      else if (('t' = RES_FT_MODE) or ('x' = RES_FT_MODE))
        {
          for select COL_FULL_PATH from WS.WS.HOSTFS_COL where COL_ID = RES_COL do
            {
              declare ses any;
	      -- dbg_obj_princ ('Found COL_FULL_PATH = ', COL_FULL_PATH);
              ses := file_to_string_output (COL_FULL_PATH || RES_NAME);
              vt_batch_feed (vtb, ses, 0, case (RES_FT_MODE) when 'x' then 2 else 0 end);
              WS.WS.HOSTFS_EXTRACT_AND_SAVE_RDF (d_id, RES_NAME, RES_TYPE, ses, WS.WS.HOSTFS_RES_TOPCOL_ID (d_id));
            }
          return 1;
        }
    }
done:
  -- dbg_obj_princ ('Failed WS.WS.HOSTFS_RES_CACHE_RESC_DATA_INDEX_HOOK (', d_id, ') :', __SQL_STATE, __SQL_MESSAGE);
  return 1;
}
;

create function
WS.WS.HOSTFS_RES_CACHE_RESC_DATA_UNINDEX_HOOK (inout vtb any, inout d_id integer) returns integer
{
  whenever sqlstate '*' goto done;
  for select RES_COL, RES_NAME, RES_TYPE, RES_FT_MODE from WS.WS.HOSTFS_RES where RES_ID = d_id do
    {
      if ('N' = RES_FT_MODE)
        {
          vt_batch_feed (vtb, RES_NAME, 1, 0);
          return 1;
        }
      else if (('T' = RES_FT_MODE) or ('X' = RES_FT_MODE))
        {
          for select RESC_DATA from WS.WS.HOSTFS_RES_CACHE where RESC_ID = d_id do
            vt_batch_feed (vtb, RESC_DATA, 1, case (RES_FT_MODE) when 'X' then 2 else 0 end);
          return 1;
        }
    }
done:
  return 1;
}
;

--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
--#ENDIF
DB.DBA.vt_create_text_index (fix_identifier_case ('WS.WS.HOSTFS_RES_CACHE'), fix_identifier_case ('RESC_DATA'), fix_identifier_case ('RESC_ID'), 2, 0, NULL, 1, '*ini*', '*ini*')
;

--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
--#ENDIF
DB.DBA.vt_batch_update (fix_identifier_case ('WS.WS.HOSTFS_RES_CACHE'), 'ON', 5)
;

create function
WS.WS.HOSTFS_FIND_COL (in full_path varchar) returns integer
{
  declare slash_pos, parent, len, res integer;
  declare parent_path, cname, tmp varchar;
  declare cr_time datetime;
  len := length (full_path);
  if ((len > 0) and full_path[len-1] = 47)
    full_path := subseq (full_path, 0, len-1);
  whenever not found goto not_found;
  select COL_ID into res from WS.WS.HOSTFS_COL where COL_FULL_PATH = full_path || '/';
  return res;
not_found:
  slash_pos := strrchr (full_path, '/');
  if (slash_pos is null)
    {
      parent := null;
      cname := full_path;
    }
  else
    {
      parent := WS.WS.HOSTFS_FIND_COL (subseq (full_path, 0, slash_pos));
      cname := subseq (full_path, slash_pos + 1);
    }
  tmp := file_stat (full_path);
  if (isstring (tmp))
    cr_time := cast (tmp as datetime);
  else
    cr_time := null;
  res := sequence_next ('WS.WS.HOSTFS_COL_ID') + 1;
  insert into WS.WS.HOSTFS_COL
    (COL_ID	, COL_FULL_PATH		, COL_PARENT_ID	, COL_CR_TIME	, COL_MOD_TIME	, COL_SCAN_TIME	, COL_NEXT_SCAN_TIME	, COL_NAME	)
  values
    (res	, full_path || '/'	, parent	, cr_time	, cr_time	, NULL		, now ()		, cname		);
  return res;
}
;

create procedure
WS.WS.HOSTFS_COL_DISAPPEARS (in full_path varchar)
{
  declare len integer;
  len := length (full_path);
  if ((len > 0) and full_path[len-1] = 47)
    full_path := subseq (full_path, 0, len-1);
  for select COL_ID from WS.WS.HOSTFS_COL where COL_FULL_PATH between full_path || '/' and full_path || '0' do
    {
      for select RES_ID from WS.WS.HOSTFS_RES where RES_COL = COL_ID do
        {
          delete from WS.WS.HOSTFS_RES_META where RESM_ID = RES_ID;
          delete from WS.WS.HOSTFS_RES_CACHE where RESC_ID = RES_ID;
        }
      delete from WS.WS.HOSTFS_RES where RES_COL = COL_ID;
    }
  delete from WS.WS.HOSTFS_COL where COL_FULL_PATH between full_path || '/' and full_path || '0';
}
;

create procedure
WS.WS.HOSTFS_HANDLE_RES_SCAN (in full_path varchar, in c_id integer, in flen integer, in cr_time datetime, in mod_time datetime, in mimetype varchar, in ft_mode varchar)
{
  declare len, slash_pos integer;
  declare r_id integer;
  len := length (full_path);
  if ((len = 0) or (full_path[len-1] = 47))
    return; -- There's no resource with empty name, for sure
  slash_pos := strrchr (full_path, '/');
  if (c_id is null)
    {
      if (slash_pos is null)
	c_id := WS.WS.HOSTFS_FIND_COL ('');
      else
	c_id := WS.WS.HOSTFS_FIND_COL (subseq (full_path, 0, slash_pos));
    }
  r_id := coalesce ((select RES_ID from WS.WS.HOSTFS_RES where RES_NAME = subseq (full_path, slash_pos + 1) and RES_COL = c_id));
  if (r_id is null)
    {
      r_id := sequence_next ('WS.WS.HOSTFS_RES_ID') + 1;
      insert into WS.WS.HOSTFS_RES
        (RES_ID	, RES_NAME, RES_COL, RES_TYPE, RES_FT_MODE, RES_LENGTH, RES_CR_TIME, RES_MOD_TIME, RES_SCAN_TIME, RES_NEXT_SCAN_TIME, RES_PERMS)
      values
        (r_id	, subseq (full_path, slash_pos + 1), c_id, mimetype, ft_mode, flen, cr_time, mod_time, now(), null, null);
-- TODO: add real support for 'X' and 'T' modes here.
      insert replacing WS.WS.HOSTFS_RES_CACHE
        (RESC_ID	, RESC_MOD_SCAN_TIME	, RESC_DATA	, RESC_TOPCOL_ID			)
      values
        (r_id		, now()			, null		, WS.WS.HOSTFS_RES_TOPCOL_ID (r_id)	);
    }
  else
    {
      if (exists (select top 1 1 from WS.WS.HOSTFS_RES
         where RES_ID = r_id and
           ((RES_LENGTH <> flen) or (RES_MOD_TIME <> mod_time) or (RES_TYPE <> mimetype) or (RES_FT_MODE <> ft_mode)) ) )
        {
          update WS.WS.HOSTFS_RES set RES_LENGTH = flen, RES_MOD_TIME = mod_time, RES_TYPE = mimetype, RES_FT_MODE = ft_mode, RES_SCAN_TIME = now() where RES_ID = r_id;
-- TODO: add real support for 'X' and 'T' modes here.
          update WS.WS.HOSTFS_RES_CACHE set RESC_MOD_SCAN_TIME = now();
        }
      else
        {
          update WS.WS.HOSTFS_RES set RES_SCAN_TIME = now() where (RES_ID = r_id) and RES_SCAN_TIME <> now ();
        }
    }
}
;

create procedure
WS.WS.HOSTFS_RES_DISAPPEARS (in full_path varchar)
{
  declare len, slash_pos integer;
  declare c_id, r_id integer;
  len := length (full_path);
  if ((len = 0) or full_path[len-1] = 47)
    return; -- There's no resource with empty name, for sure
  slash_pos := strrchr (full_path, '/');
  c_id := coalesce ((select COL_ID from WS.WS.HOSTFS_COL where COL_FULL_PATH = subseq (full_path, 0, slash_pos + 1)));
  if (c_id is null)
    return;
  r_id := coalesce ((select RES_ID from WS.WS.HOSTFS_RES where RES_NAME = subseq (full_path, slash_pos + 1) and RES_COL = c_id));
  if (r_id is null)
    return;
  delete from WS.WS.HOSTFS_RES_CACHE where RESC_ID = r_id;
  delete from WS.WS.HOSTFS_RES where RES_ID = r_id;
  update WS.WS.HOSTFS_COL set COL_MOD_TIME = now() where COL_ID = c_id and COL_MOD_TIME < now();
}
;

create function
WS.WS.HOSTFS_TOUCH_RES (in ospath varchar) returns integer
{
  declare mimetype, ft_mode varchar;
  declare cr_time, mod_time datetime;
  declare flen, rc integer;
  -- dbg_obj_princ ('WS.WS.HOSTFS_TOUCH_RES (', ospath, ')');
  rc := WS.WS.HOSTFS_PATH_STAT (ospath, flen, cr_time, mod_time);
  if (rc < 0)
    {
      WS.WS.HOSTFS_RES_DISAPPEARS (ospath);
      return -1;
    }
  WS.WS.HOSTFS_READ_TYPEINFO (ospath, mimetype, ft_mode);
  WS.WS.HOSTFS_HANDLE_RES_SCAN (ospath, null, flen, cr_time, mod_time, mimetype, ft_mode);
  return 0;
}
;

create procedure
WS.WS.HOSTFS_GLOBAL_RESET ()
{
  set isolation = 'serializable';
  delete from WS.WS.HOSTFS_RES_META;
  delete from WS.WS.HOSTFS_RES_CACHE;
  delete from WS.WS.HOSTFS_RES;
  delete from WS.WS.HOSTFS_COL;
  sequence_set ('WS.WS.HOSTFS_COL_ID', 0, 0);
  sequence_set ('WS.WS.HOSTFS_RES_ID', 0, 0);
}
;

create function
WS.WS.HOSTFS_PATH_STAT (in full_path varchar, out flen integer, out cr_time datetime, out mod_time datetime) returns integer
{
  declare tmp varchar;
  tmp := file_stat (full_path);
  if (not isstring (tmp))
    return -1;
  cr_time := mod_time := cast (tmp as datetime);
  flen := cast (file_stat (full_path, 1) as integer);
  return 0;
}
;

create procedure
WS.WS.HOSTFS_READ_TYPEINFO (in full_path varchar, out mimetype varchar, out ft_mode varchar)
{
  declare mt varchar;
  mt := http_mime_type (full_path);
  mimetype := mt;
  if ('text/html' = mt)
    ft_mode := 'x';
  else if ('text/xml' = mt)
    ft_mode := 'x';
  else if ('text/xhtml' = mt)
    ft_mode := 'x';
  else if ('%+xml' = mt)
    ft_mode := 'x';
  else if (mt like 'text/%')
    ft_mode := 't';
  else
    ft_mode := 'N';
}
;


create function "HostFs_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('HostFs_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  declare puid, pgid integer;
  declare pperms varchar;
  if (auth_uid < 0)
    return auth_uid;
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'HostFs_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='HostFs'), '')
      ), http_admin_gid() );
  pperms := '110100100RR';
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  if (DAV_CHECK_PERM (pperms, req, auth_uid, null, pgid, puid))
    return auth_uid;
  return -13;
}
;

create function "HostFs_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
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
      where G_NAME = 'HostFs_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='HostFs'), '')
      ), http_admin_gid() );
  pperms := '110100100RR';
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
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return a_uid;
  return -13;

nf_col_or_res:
  return -1;
}
;

create function "HostFs_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

create function "HostFs_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  declare ospath varchar;
  -- dbg_obj_princ ('HostFs_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  -- dbg_obj_princ ('cmd=', sprintf ('mkdir ''%s''', ospath));
  system (sprintf ('mkdir ''%s''', ospath));
  WS.WS.HOSTFS_FIND_COL (ospath);
  return vector (UNAME'HostFs', detcol_id, ospath);
}
;

create function "HostFs_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "HostFs_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_COL_MOUNT (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "HostFs_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  declare ospath varchar;
  -- dbg_obj_princ ('HostFs_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  -- dbg_obj_princ ('cmd=', sprintf ('rm -rf ''%s''', ospath));
  system (sprintf ('rm -rf ''%s''', ospath));
  return 1;
}
;

create table "HostFs_DAV_RES_UPLOAD" (ID varchar primary key, DT datetime, CNT long varchar)
;

create function "HostFs_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  declare ospath varchar;
  declare rc integer;
  -- dbg_obj_princ ('HostFs_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  if (__tag (content) = 126)
    {
      declare p varchar;
      p := '[' || serialize (now()) || '][' || serialize (detcol_id) || '][' || serialize (path_parts) || ']';
      insert into "HostFs_DAV_RES_UPLOAD" values (p, now(), content);
-- in the next string, '1' is an invalid argument for string_to_file to guarantee 'Internal Server Error' visible by client
      string_to_file (ospath, coalesce ((select CNT from "HostFs_DAV_RES_UPLOAD" where ID=p), 1), -2);
    }
  else
    string_to_file (ospath, content, -2);
  rc := WS.WS.HOSTFS_TOUCH_RES (ospath);
  if (rc < 0)
    return -28;
  return vector (UNAME'HostFs', detcol_id, ospath);
}
;

create function "HostFs_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('HostFs_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

create function "HostFs_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

create function "HostFs_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  declare ospath varchar;
  ospath := id[2];
  -- dbg_obj_princ ('HostFs_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  if (not isstring (file_stat (ospath)))
    {
      WS.WS.HOSTFS_COL_DISAPPEARS (ospath);
      WS.WS.HOSTFS_RES_DISAPPEARS (ospath);
      return -1;
    }
  return -11;
}
;

create function "HostFs_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  declare ospath varchar;
  ospath := id[2];
  -- dbg_obj_princ ('HostFs_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  if (not isstring (file_stat (ospath)))
    {
      WS.WS.HOSTFS_COL_DISAPPEARS (ospath);
      WS.WS.HOSTFS_RES_DISAPPEARS (ospath);
      return -1;
    }
  return vector ();
}
;

create function "HostFs_ID_TO_OSPATH" (in col any)
{
  declare res varchar;
  declare ctr, len integer;
  if (isinteger (col))
    return coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = col), ' no such ');
  return col[2];
}
;

create function "HostFs_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  declare fullname, name, tmp, mimetype, ft_mode varchar;
  declare cr_time, mod_time datetime;
  declare puid, pgid, flen, rc integer;
  -- dbg_obj_princ ('HostFs_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  fullname := id[2];
  rc := WS.WS.HOSTFS_PATH_STAT (fullname, flen, cr_time, mod_time);
  if (rc < 0)
    {
      if ('R' = what)
	WS.WS.HOSTFS_RES_DISAPPEARS (fullname);
      else
	WS.WS.HOSTFS_COL_DISAPPEARS (fullname);
      return -1;
    }
  name := subseq (fullname, strrchr (fullname, '/') + 1);
  if (path is null)
    path := "HostFs_DAV_SEARCH_PATH" (id, what);
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'HostFs_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='HostFs'), '')
      ), puid+1);
  if ('R' = what)
    {
      WS.WS.HOSTFS_READ_TYPEINFO (fullname, mimetype, ft_mode);
      WS.WS.HOSTFS_HANDLE_RES_SCAN (fullname, null, flen, cr_time, mod_time, mimetype, ft_mode);
      return vector (path, 'R',	flen, mod_time, id, '110000000RR', pgid, puid, cr_time, mimetype, name);
    }
  if ('C' = what)
    {
      return vector (DAV_CONCAT_PATH (path, '/'), 'C', flen, mod_time, id, '110000000RR', pgid, puid, cr_time, 'dav/unix-directory', name);
    }
  return -20;
}
;

create function "HostFs_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare ospath, name, fullname, top_davpath varchar;
  declare stale_files, files, stale_dirs, dirs, res any;
  declare ctr, len integer;
  declare tmp, mimetype, ft_mode varchar;
  declare cr_time, mod_time datetime;
  declare puid, pgid, flen, rc, parent_c_id, r_id integer;
  -- dbg_obj_princ ('HostFs_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  whenever sqlstate '39000' goto no_dir;
  dirs := sys_dirlist (ospath, 0);
  parent_c_id := WS.WS.HOSTFS_FIND_COL (ospath);
  if (parent_c_id is null)
    select VECTOR_AGG (COL_FULL_PATH) into stale_dirs from WS.WS.HOSTFS_COL where COL_PARENT_ID is null and 0 = position (COL_NAME, dirs);
  else
    select VECTOR_AGG (COL_FULL_PATH) into stale_dirs from WS.WS.HOSTFS_COL where COL_PARENT_ID = parent_c_id and 0 = position (COL_NAME, dirs);
  foreach (varchar stale_fullname in stale_dirs) do
    WS.WS.HOSTFS_COL_DISAPPEARS (stale_fullname);
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'HostFs_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = detcol_id and COL_DET='HostFs'), '')
      ), puid+1);
  vectorbld_init (res);
  len := length (dirs);
  ctr := 0;
  while (ctr < len)
    {
      name := dirs [ctr];
      if ((name <> '.') and (name <> '..'))
        {
	  fullname := DAV_CONCAT_PATH (ospath, name);
	  -- dbg_obj_princ ('HostFs_DAV_DIR_LIST makes ', fullname);
	  rc := WS.WS.HOSTFS_PATH_STAT (fullname, flen, cr_time, mod_time);
	  if (rc < 0)
	    {
	      WS.WS.HOSTFS_COL_DISAPPEARS (fullname);
	    }
          else
            {
              vectorbld_acc (res, vector (
		DAV_CONCAT_PATH (top_davpath, name) || '/', 'C',
		flen,
		mod_time,
		vector (UNAME'HostFs', detcol_id, fullname),
		'110100000RR', pgid, puid,
		cr_time,
		'dav/unix-directory',
		name ) );
	      if (recursive > 0)
	        vectorbld_concat_acc (res,
		  "HostFs_DAV_DIR_LIST" (detcol_id,
		  vector_concat (subseq (path_parts, 0, length (path_parts)-1), vector (name, '')),
		  concat (DAV_CONCAT_PATH (detcol_path, name), '/'), name_mask, recursive, auth_uid) );
	    }
	}
      ctr := ctr + 1;
    }
  files := sys_dirlist (ospath, 1);
  if (parent_c_id is null)
    select VECTOR_AGG (RES_NAME) into stale_files from WS.WS.HOSTFS_RES where RES_COL is null and 0 = position (RES_NAME, files);
  else
    select VECTOR_AGG (RES_NAME) into stale_files from WS.WS.HOSTFS_RES where RES_COL = parent_c_id and 0 = position (RES_NAME, files);
  foreach (varchar stale_name in stale_files) do
    {
      r_id := coalesce ((select RES_ID from WS.WS.HOSTFS_RES where RES_COL = parent_c_id and RES_NAME = stale_name));
      delete from WS.WS.HOSTFS_RES_META where RESM_ID = r_id;
      delete from WS.WS.HOSTFS_RES_CACHE where RESC_ID = r_id;
      delete from WS.WS.HOSTFS_RES where RES_ID = r_id;
    }
  len := length (files);
  ctr := 0;
  while (ctr < len)
    {
      name := files [ctr];
      fullname := DAV_CONCAT_PATH (ospath, name);
      rc := WS.WS.HOSTFS_PATH_STAT (fullname, flen, cr_time, mod_time);
      if (rc < 0)
	{
	  delete from WS.WS.HOSTFS_RES_META where RESM_ID = r_id;
	  delete from WS.WS.HOSTFS_RES_CACHE where RESC_ID = r_id;
	  delete from WS.WS.HOSTFS_RES where RES_ID = r_id;
	}
      else
        {
	  WS.WS.HOSTFS_READ_TYPEINFO (fullname, mimetype, ft_mode);
	  WS.WS.HOSTFS_HANDLE_RES_SCAN (fullname, parent_c_id, flen, cr_time, mod_time, mimetype, ft_mode);
          if (name like name_mask)
	    {
	      -- dbg_obj_princ ('HostFs_DAV_DIR_LIST makes ', fullname);
	      vectorbld_acc (res, vector (
		DAV_CONCAT_PATH (top_davpath, name), 'R',
		flen,
		mod_time,
		vector (UNAME'HostFs', detcol_id, fullname),
		'110100000RR', pgid, puid,
		cr_time,
		mimetype,
		name ) );
	    }
         }
      ctr := ctr + 1;
    }
  update WS.WS.HOSTFS_COL set COL_MOD_TIME = now() where COL_ID = parent_c_id and COL_MOD_TIME < now();
  vectorbld_final (res);
  -- dbg_obj_princ ('HostFs_DAV_DIR_LIST returns ', res);
  return res;

no_dir:
  WS.WS.HOSTFS_COL_DISAPPEARS (ospath);
  return vector();
}
;


create function "HostFs_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, in compilation varchar, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector ();
}
;


create function "HostFs_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare ospath, stat varchar;
  -- dbg_obj_princ ('HostFs_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  stat := file_stat (ospath, 2);
  if (not isstring (stat))
    {
      -- dbg_obj_princ ('ospath=',ospath,', stat=',stat, ', stat is not a string');
      WS.WS.HOSTFS_COL_DISAPPEARS (ospath);
      WS.WS.HOSTFS_RES_DISAPPEARS (ospath);
      return -1;
    }
  if (what = 'R')
    {
      if (0 = bit_and (32768, cast (stat as integer)))
	{
	  -- dbg_obj_princ ('ospath=',ospath,', stat=',stat, ', stat is not a resource');
	  WS.WS.HOSTFS_RES_DISAPPEARS (ospath);
	  return -1;
	}
    }
  else -- what = 'C'
    {
      if (0 = bit_and (16384, cast (stat as integer)))
	{
	  -- dbg_obj_princ ('ospath=',ospath,', stat=',stat, ', stat is not a collection');
	  WS.WS.HOSTFS_COL_DISAPPEARS (ospath);
	  return -1;
	}
    }
  -- dbg_obj_princ ('ospath=',ospath,', stat=',stat, ', hit of type ', what);
  return vector (UNAME'HostFs', detcol_id, ospath);
}
;

create function "HostFs_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  declare ospath varchar;
  declare slash_pos, detcol_fullpath integer;
  -- dbg_obj_princ ('HostFs_DAV_SEARCH_PATH (', id, what, ')');
  ospath := id[2];
  slash_pos := strchr (ospath, '/');
  detcol_fullpath := coalesce ((select WS.WS.COL_PATH (COL_ID) from WS.WS.SYS_DAV_COL where COL_ID = id[1] and COL_DET='HostFs'));
  if (detcol_fullpath is null)
    return -23;
  if (not isstring (file_stat (ospath)))
    {
      WS.WS.HOSTFS_COL_DISAPPEARS (ospath);
      WS.WS.HOSTFS_RES_DISAPPEARS (ospath);
      return -23;
    }
  return detcol_fullpath || subseq (ospath, slash_pos + 1);
}
;

create function "HostFs_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  declare ospath varchar;
  -- dbg_obj_princ ('HostFs_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite, permissions, uid, gid, auth_uid, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  if (what = 'R')
    {
      declare cnt any;
      declare mime_type varchar;
      declare rc integer;
      rc := DAV_RES_CONTENT_INT (source_id, cnt, mime_type, 0, 0);
      if (rc < 0)
        {
          -- dbg_obj_princ ('DAV_RES_CONTENT_INT (', source_id, cnt, mime_type, 0, 0, ') returns ', rc);
          return rc;
        }
      string_to_file (ospath, case (__tag (cnt)) when 126 then blob_to_string (cnt) else cnt end, -2);
      rc := WS.WS.HOSTFS_TOUCH_RES (ospath);
      if (rc < 0)
	return -28;
      return vector (UNAME'HostFs', detcol_id, ospath);
    }
  return -20;
}
;

create function "HostFs_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in auth_uid integer) returns any
{
  declare ospath, src_path varchar;
  -- dbg_obj_princ ('HostFs_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite, auth_uid, ')');
  ospath := DAV_CONCAT_PATH ("HostFs_ID_TO_OSPATH" (detcol_id), path_parts);
  if (what = 'R')
    {
      declare cnt any;
      declare mime_type varchar;
      declare rc integer;
      rc := DAV_RES_CONTENT_INT (source_id, cnt, mime_type, 0, 0);
      if (rc < 0)
        {
          -- dbg_obj_princ ('DAV_RES_CONTENT_INT (', source_id, cnt, mime_type, 0, 0, ') returns ', rc);
          return rc;
        }
      string_to_file (ospath, case (__tag (cnt)) when 126 then blob_to_string (cnt) else cnt end, -2);
      rc := WS.WS.HOSTFS_TOUCH_RES (ospath);
      if (rc < 0)
	return -28;
      src_path := DAV_SEARCH_PATH (source_id, 'R');
      if (src_path is not null)
        DAV_DELETE_INT (src_path, 1, null, null, 0);
      return vector (UNAME'HostFs', detcol_id, ospath);
    }
  return -20;
}
;

create function "HostFs_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('HostFs_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  whenever sqlstate '*' goto no_res;
  declare ft_mode varchar;
  if ((content_mode = 0) or (content_mode = 2))
    content := file_to_string (id[2]);
  else if (content_mode = 1)
    file_append_to_string_output (id[2], content);
  else if (content_mode = 3)
    http_file (id[2]);
  WS.WS.HOSTFS_READ_TYPEINFO (id[2], type, ft_mode);
  return 0;

no_res:
  -- dbg_obj_princ ('HostFs_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ') caught an error ', __SQL_STATE, __SQL_MESSAGE);
  WS.WS.HOSTFS_RES_DISAPPEARS (id[2]);
  return -1;
}
;

create function "HostFs_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "HostFs_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  return -20;
}
;

create function "HostFs_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('HostFs_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

create function "HostFs_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  declare rc integer;
  declare orig_id any;
  declare orig_type char(1);
  -- dbg_obj_princ ('HostFs_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  orig_id := id;
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

create function "HostFs_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('HostFs_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;

create procedure "HostFs_CF_LIST_PROP_DISTVALS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, in schema_uri varchar, inout filter_data any, inout distval_dict any, in auth_uid integer)
{
  declare topcol_name varchar;
  declare topcol_id integer;
  declare filter_length, p0_id, p1_id, p2_id, p3_id, p4_id, res0_id, res1_id, res2_id, res3_id, res4_id, res_last_id, res_id_max integer;
  declare plast_id integer;
  declare p0_val, p1_val, p2_val, p3_val, p4_val, v_last, v_max varchar;
  --declare auth_gid integer;
  --declare acl_bits any
  declare hit_ids any;
  declare c_last1 cursor for select             HRI_CATVALUE from WS.WS.HOSTFS_RDF_INVERSE
    where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = plast_id and (v_max is null or HRI_CATVALUE > v_max)
--    No per-resource security for a while, so there's nothing like this: and
--      exists (select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = HRI_RES_ID and case (DAV_CHECK_PERM (RES_PERMS, '1__', auth_uid, auth_gid, RES_GROUP, RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (RES_ACL, auth_uid, acl_bits) else 1 end)
    ;
  declare c_last2 cursor for select HRI_RES_ID, HRI_CATVALUE from WS.WS.HOSTFS_RDF_INVERSE
    where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = plast_id and (v_max is null or HRI_CATVALUE > v_max)
--    No per-resource security for a while, so there's nothing like this:and
--      exists (select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = HRI_RES_ID and case (DAV_CHECK_PERM (RES_PERMS, '1__', auth_uid, auth_gid, RES_GROUP, RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (RES_ACL, auth_uid, acl_bits) else 1 end)
    ;
  declare c0 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p0_id and HRI_CATVALUE = p0_val and HRI_RES_ID >= res_id_max;
  declare c1 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p1_id and HRI_CATVALUE = p1_val and HRI_RES_ID >= res_id_max;
  declare c2 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p2_id and HRI_CATVALUE = p2_val and HRI_RES_ID >= res_id_max;
  declare c3 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p3_id and HRI_CATVALUE = p3_val and HRI_RES_ID >= res_id_max;
  declare c4 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p4_id and HRI_CATVALUE = p4_val and HRI_RES_ID >= res_id_max;
  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, auth_uid, ')');
  topcol_name := coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = detcol_id and COL_DET = 'HostFs'));
  if (topcol_name is null)
    {
      -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: can not find the specified mount point', detcol_id);
      return;
    }
  topcol_id := coalesce ((select COL_ID from WS.WS.HOSTFS_COL where COL_PARENT_ID is null and COL_NAME = topcol_name), WS.WS.HOSTFS_FIND_COL (topcol_name));
  filter_length := length (filter_data);
  plast_id := filter_data [filter_length - 1];
  res_id_max := 0;
  v_max := null;
  --auth_gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = auth_uid), 0);
  --acl_bits := DAV_REQ_CHARS_TO_BITMASK ('1__');

  if (filter_length = 2) -- distinct propvals with no filtering in front -- a special case
    {
      whenever not found goto nf_c_last1;
      -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: distinct propvals of ', plast_id, ' in ', cfc_id);
      open c_last1 (prefetch 1);
      while (1)
        {
          fetch c_last1 into v_last;
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: v_last is ', v_last, ' v_max is ', v_max);
          if (v_max is null or (v_last > v_max))
            {
              v_max := v_last; -- note that vectorbld_acc() will destroy the value of v_last so this assignment should be before vectorbld_acc().
              dict_put (distval_dict, v_last, 1);
            }
        }
nf_c_last1:
      close c_last1;
      return;
    }

  res0_id := 0;
  res1_id := 0;
  res2_id := 0;
  res3_id := 0;
  res4_id := 0;
  hit_ids := dict_new ();

  p0_id := filter_data [1];
  p0_val := "CatFilter_ENCODE_CATVALUE" (filter_data [2]);
  if (filter_length = 6) -- distinct propvals with 1 fixed property
    {
      whenever not found goto get_distincts_0;
      open c0 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max)
            fetch c0 into res0_id;
          res_id_max := res0_id;
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: put hit ', res_id_max);
          dict_put (hit_ids, res_id_max, 1);
        }
    }

  p1_id := filter_data [4+1];
  p1_val := "CatFilter_ENCODE_CATVALUE" (filter_data [4+2]);
  if (filter_length = 10) -- distinct propvals with 2 fixed property
    {
      whenever not found goto get_distincts_1;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max) fetch c0 into res0_id;
          if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
          if (res1_id > res_id_max) res_id_max := res1_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: put hit ', res_id_max);
              dict_put (hit_ids, res_id_max, 1);
            }
          else
            res_id_max := res_id_max + 1;

        }
    }

  p2_id := filter_data [8+1];
  p2_val := "CatFilter_ENCODE_CATVALUE" (filter_data [8+2]);
  if (filter_length = 14) -- distinct propvals with 3 fixed property
    {
      whenever not found goto get_distincts_2;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      while (1)
        {
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: res_id_max is ', res_id_max);
--        res_id_max := 0;
          while (res0_id <= res_id_max) fetch c0 into res0_id;
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: res0_id is ', res0_id);
	  if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: res1_id is ', res1_id);
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: res2_id is ', res2_id);
	  if (res2_id > res_id_max) res_id_max := res2_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: put hit ', res_id_max);
              dict_put (hit_ids, res_id_max, 1);
            }
        }
    }

  p3_id := filter_data [12+1];
  p3_val := "CatFilter_ENCODE_CATVALUE" (filter_data [12+2]);
  if (filter_length = 18) -- distinct propvals with 4 fixed property
    {
      whenever not found goto get_distincts_3;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: put hit ', res_id_max);
              dict_put (hit_ids, res_id_max, 1);
            }
        }
    }

  p4_id := filter_data [16+1];
  p4_val := "CatFilter_ENCODE_CATVALUE" (filter_data [16+2]);
  if (filter_length = 22) -- distinct propvals with 5 fixed property
    {
      whenever not found goto get_distincts_4;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      open c4 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          while (res4_id < res_id_max) fetch c4 into res4_id;
	  if (res4_id > res_id_max) res_id_max := res4_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max) and (res4_id = res_id_max))
            dict_put (hit_ids, res_id_max, 1);
        }
    }

get_distincts_4:
  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: close c4');
  close c4;
get_distincts_3:
  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: close c3');
  close c3;
get_distincts_2:
  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: close c2');
  close c2;
get_distincts_1:
  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: close c1');
  close c1;
get_distincts_0:
  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: close c0');
  close c0;

  -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: now search in all values of ', plast_id);
  whenever not found goto nf_c_last2;
  open c_last2 (prefetch 1);
  while (1)
    {
      fetch c_last2 into res_last_id, v_last;
      if (v_max is null or (v_last > v_max))
        {
          -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: next value ', v_last, ' at ', res_last_id);
          if (dict_get (hit_ids, res_last_id, 0))
            {
              -- dbg_obj_princ ('HostFs_CF_LIST_PROP_DISTVALS: full hit at ', res_last_id);
              v_max := v_last; -- note that vectorbld_acc() will destroy the value of v_last so this assignment should be before vectorbld_acc().
              dict_put (distval_dict, v_last, 1);
            }
        }
    }
nf_c_last2:
      close c_last2;
}
;


create function "HostFs_CF_GET_RDF_HITS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, in schema_uri varchar, inout filter_data any, in detcol_path varchar, in make_diritems integer, in auth_uid integer) returns any
{
  declare topcol_name varchar;
  declare topcol_id, acc_ctr, acc_len integer;
  declare filter_length, p0_id, p1_id, p2_id, p3_id, p4_id, res0_id, res1_id, res2_id, res3_id, res4_id, res_id_max integer;
  declare acc any;
  declare p0_val, p1_val, p2_val, p3_val, p4_val varchar;
  --declare acl_bits any;
  --declare auth_gid integer;
  declare c0 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p0_id and HRI_CATVALUE = p0_val and HRI_RES_ID >= res_id_max
--    No per-resource security for a while, so there's nothing like this: and
--    exists (select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = HRI_RES_ID and case (DAV_CHECK_PERM (RES_PERMS, '1__', auth_uid, auth_gid, RES_GROUP, RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (RES_ACL, auth_uid, acl_bits) else 1 end)
    ;
  declare c1 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p1_id and HRI_CATVALUE = p1_val and HRI_RES_ID >= res_id_max;
  declare c2 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p2_id and HRI_CATVALUE = p2_val and HRI_RES_ID >= res_id_max;
  declare c3 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p3_id and HRI_CATVALUE = p3_val and HRI_RES_ID >= res_id_max;
  declare c4 cursor for select HRI_RES_ID from WS.WS.HOSTFS_RDF_INVERSE where HRI_TOPCOL_ID = topcol_id and HRI_PROP_CATID = p4_id and HRI_CATVALUE = p4_val and HRI_RES_ID >= res_id_max;
  -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ')');
  topcol_name := coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = detcol_id and COL_DET = 'HostFs'));
  if (topcol_name is null)
    {
      -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS: can not find the specified mount point', detcol_id);
      return vector ();
    }
  topcol_id := coalesce ((select COL_ID from WS.WS.HOSTFS_COL where COL_PARENT_ID is null and COL_NAME = topcol_name), WS.WS.HOSTFS_FIND_COL (topcol_name));
  filter_length := length (filter_data);
  vectorbld_init (acc);

  res0_id := -1;
  res1_id := -1;
  res2_id := -1;
  res3_id := -1;
  res4_id := -1;
  res_id_max := 0;

  --auth_gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = auth_uid), 0);
  --acl_bits := DAV_REQ_CHARS_TO_BITMASK ('1__');

  p0_id := filter_data [1];
  p0_val := "CatFilter_ENCODE_CATVALUE" (filter_data [2]);
  if (filter_length = 4) -- resources with 1 fixed property
    {
      whenever not found goto get_distincts_0;
      open c0 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max)
            fetch c0 into res0_id;
          res_id_max := res0_id;
          -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS: put hit ', res_id_max);
          vectorbld_acc (acc, res0_id);
        }
    }

  p1_id := filter_data [4+1];
  p1_val := "CatFilter_ENCODE_CATVALUE" (filter_data [4+2]);
  if (filter_length = 8) -- resources with 2 fixed properties
    {
      whenever not found goto get_distincts_1;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
          if (res1_id > res_id_max) res_id_max := res1_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
          if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

  p2_id := filter_data [8+1];
  p2_val := "CatFilter_ENCODE_CATVALUE" (filter_data [8+2]);
  if (filter_length = 12) -- resources with 3 fixed properties
    {
      whenever not found goto get_distincts_2;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS_RES_IDS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

  p3_id := filter_data [12+1];
  p3_val := "CatFilter_ENCODE_CATVALUE" (filter_data [12+2]);
  if (filter_length = 16) -- resources with 4 fixed properties
    {
      whenever not found goto get_distincts_3;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

  p4_id := filter_data [16+1];
  p4_val := "CatFilter_ENCODE_CATVALUE" (filter_data [16+2]);
  if (filter_length = 20) -- resources with 5 fixed properties
    {
      whenever not found goto get_distincts_4;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      open c4 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          while (res4_id < res_id_max) fetch c4 into res4_id;
	  if (res4_id > res_id_max) res_id_max := res4_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max) and (res4_id = res_id_max))
            {
              -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

get_distincts_4:
  close c4;
get_distincts_3:
  close c3;
get_distincts_2:
  close c2;
get_distincts_1:
  close c1;
get_distincts_0:
  close c0;

finalize:
  vectorbld_final (acc);
  acc_len := length (acc);
  acc_ctr := 0;
  while (acc_ctr < acc_len)
    {
      declare r_id integer;
      declare fullname varchar;
      declare full_id, diritm any;
      r_id := acc [acc_ctr];
      fullname := coalesce ((select top 1 COL_FULL_PATH || RES_NAME from WS.WS.HOSTFS_RES join WS.WS.HOSTFS_COL on (RES_COL = COL_ID) where RES_ID = r_id), '\377\377\377dead');
      full_id := vector (UNAME'HostFs', detcol_id, fullname);
      if (make_diritems = 1)
        {
	  diritm := "HostFs_DAV_DIR_SINGLE" (full_id, 'R', '(fake path)', auth_uid);
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
  if (acc_len < length (acc)) -- There were collisions in the air
    {
      acc := subseq (acc, 0, acc_len);
    }
  -- dbg_obj_princ ('HostFs_CF_GET_RDF_HITS (', detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, make_diritems, auth_uid, ') returns ', acc);
  return acc;
}
;


create procedure "HostFs_RF_ID2SUFFIX" (in id any, in what char(1))
{
  if (what='C')
    {
      return sprintf ('HostDir-%d-%d',
        id[1], WS.WS.HOSTFS_FIND_COL (id[2]));
    }
  if (what='R')
    {
      declare full_path varchar;
      declare len, slash_pos integer;
      declare r_id, c_id integer;
      full_path := id[2];
      len := length (full_path);
      if ((len = 0) or (full_path[len-1] = 47))
        r_id := 0; -- There's no resource with empty name, for sure
      else
        {
          slash_pos := strrchr (full_path, '/');
	  if (c_id is null)
	    {
	      if (slash_pos is null)
		c_id := WS.WS.HOSTFS_FIND_COL ('');
	      else
		c_id := WS.WS.HOSTFS_FIND_COL (subseq (full_path, 0, slash_pos));
	    }
	  r_id := coalesce ((select RES_ID from WS.WS.HOSTFS_RES where RES_NAME = subseq (full_path, slash_pos + 1) and RES_COL = c_id), 0);
        }
      return sprintf ('HostFile-%d-%d', id[1], r_id);
    }
  signal ('OBLOM', 'Invalid arguments for HostFs_RF_ID2SUFFIX');
}
;

create procedure "HostFile_RF_SUFFIX2ID" (in suffix varchar, in what char(1))
{
  declare pairs any;
  declare r_id varchar;
  declare detcol_id integer;
  if ('R' <> what)
    return null;
  pairs := regexp_parse ('^([1-9][0-9]*)-([1-9][0-9]*)\044', suffix, 0);
  if (pairs is null)
    {
      -- dbg_obj_princ ('HostFile_RF_SUFFIX2ID (', suffix, ') failed to parse the argument');
      return null;
    }
  detcol_id := cast (subseq (suffix, pairs[2], pairs[3]) as integer);
  whenever not found goto oblom;
  select vector (UNAME'HostFs', detcol_id, COL_FULL_PATH || RES_NAME) into r_id
  from WS.WS.HOSTFS_RES join WS.WS.HOSTFS_COL on (RES_COL = COL_ID)
  where RES_ID = cast (subseq (suffix, pairs[4], pairs[5]) as integer);
  return r_id;
oblom:
  return null;
}
;

create procedure "HostDir_RF_SUFFIX2ID" (in suffix varchar, in what char(1))
{
  declare pairs any;
  declare c_id varchar;
  declare detcol_id integer;
  if ('C' <> what)
    return null;
  pairs := regexp_parse ('^([1-9][0-9]*)-([1-9][0-9]*)\044', suffix, 0);
  if (pairs is null)
    {
      -- dbg_obj_princ ('HostDir_RF_SUFFIX2ID (', suffix, ') failed to parse the argument');
      return null;
    }
  detcol_id := cast (subseq (suffix, pairs[2], pairs[3]) as integer);
  whenever not found goto oblom;
  select vector (UNAME'HostFs', detcol_id, COL_FULL_PATH) into c_id
    from WS.WS.HOSTFS_RES join WS.WS.HOSTFS_COL on (RES_COL = COL_ID);
  return c_id;
oblom:
  return NULL;
}
;
