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

use sioc;

create procedure bmk_post_iri (in domain_id varchar, in bmk_id int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst from
      DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
      where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/bookmark/%U/%d', get_cname(), get_base_path (), _member, _inst, bmk_id);
};

create procedure fill_ods_bmk_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, firi, criri varchar;
  for select WAI_NAME, BD_DOMAIN_ID, BD_BOOKMARK_ID, BD_NAME, BD_DESCRIPTION, BD_LAST_UPDATE, BD_CREATED, B_URI, WAM_USER
    from DB.DBA.WA_INSTANCE, BMK..BOOKMARK_DOMAIN, BMK..BOOKMARK, DB.DBA.WA_MEMBER
    where BD_DOMAIN_ID = WAI_ID and BD_BOOKMARK_ID = B_ID and WAM_INST = WAI_NAME do
      {
	firi := bmk_iri (WAI_NAME);
	iri := bmk_post_iri (BD_DOMAIN_ID, BD_BOOKMARK_ID);
	criri := user_iri (WAM_USER);
        ods_sioc_post (graph_iri, iri, firi, criri, BD_NAME, BD_CREATED, BD_LAST_UPDATE, B_URI);
      }
};

create trigger BOOKMARK_DOMAIN_SIOC_I after insert on BMK.WA.BOOKMARK_DOMAIN referencing new as N
{
  declare iri, firi, criri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := bmk_post_iri (N.BD_DOMAIN_ID, N.BD_BOOKMARK_ID);
  for select B_URI, WAM_USER, WAI_NAME from  DB.DBA.WA_INSTANCE, BMK..BOOKMARK, DB.DBA.WA_MEMBER
  where WAI_ID = N.BD_DOMAIN_ID and B_ID = N.BD_BOOKMARK_ID and WAM_INST = WAI_NAME
  do
    {
      firi := bmk_iri (WAI_NAME);
      criri := user_iri (WAM_USER);
      ods_sioc_post (graph_iri, iri, firi, criri, N.BD_NAME, N.BD_CREATED, N.BD_LAST_UPDATE, B_URI);
    }
  return;
};

create trigger BOOKMARK_DOMAIN_SIOC_D after delete on BMK.WA.BOOKMARK_DOMAIN referencing old as O
{
  declare iri, c_iri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := bmk_post_iri (O.BD_DOMAIN_ID, O.BD_BOOKMARK_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};


use DB;

