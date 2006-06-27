--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

use sioc;

create procedure fill_ods_photo_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, c_iri, creator_iri varchar;
  for select OWNER_ID, WAI_NAME, HOME_PATH from PHOTO..SYS_INFO do
    {
      c_iri := photo_iri (WAI_NAME);
      for select RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER
	from WS.WS.SYS_DAV_RES where RES_FULL_PATH like HOME_PATH || '%' and RES_FULL_PATH not like HOME_PATH || '%/.thumbnails/%'
	do
	  {
	    iri := dav_res_iri (RES_FULL_PATH);
	    creator_iri := user_iri (RES_OWNER);
	    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, RES_NAME, RES_CR_TIME, RES_MOD_TIME, null);
	  }
    }
};

create trigger SYS_DAV_RES_PHOTO_SIOC_D after delete on WS.WS.SYS_DAV_RES referencing old as O
{
  declare iri, c_iri, creator_iri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := dav_res_iri (O.RES_FULL_PATH);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

create trigger SYS_DAV_RES_PHOTO_SIOC_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  declare dir varchar;
  declare iri, c_iri, creator_iri varchar;
  declare pos int;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  pos := strrchr (N.RES_FULL_PATH, '/');
  if (pos is null)
    return;

  dir := subseq (N.RES_FULL_PATH, 0, pos+1);
  graph_iri := get_graph ();

  -- delete old
  iri := dav_res_iri (O.RES_FULL_PATH);
  delete_quad_s_or_o (graph_iri, iri, iri);

  iri := dav_res_iri (N.RES_FULL_PATH);
  for select WAI_NAME from PHOTO..SYS_INFO where HOME_PATH = dir and N.RES_OWNER = OWNER_ID do
    {
      creator_iri := user_iri (N.RES_OWNER);
      c_iri := photo_iri (WAI_NAME);
      ods_sioc_post (graph_iri, iri, c_iri, creator_iri, N.RES_NAME, N.RES_CR_TIME, N.RES_MOD_TIME, null);
    }

  return;
};

use DB;
