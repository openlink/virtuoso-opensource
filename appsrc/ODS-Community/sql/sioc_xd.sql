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

create procedure fill_ods_community_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, firi varchar;
  for select CM_COMMUNITY_ID, CM_MEMBER_APP, WAI_TYPE_NAME, WAI_DESCRIPTION
    from ODS.COMMUNITY.COMMUNITY_MEMBER_APP, DB.DBA.WA_INSTANCE where WAI_NAME = CM_MEMBER_APP
	and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
	do
    {
      firi := xd_iri (CM_COMMUNITY_ID);
      iri := forum_iri (WAI_TYPE_NAME, CM_MEMBER_APP);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), firi);
      DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('parent_of'), iri);
    }
};

create trigger COMMUNITY_MEMBER_APP_SIOC_I after insert on ODS.COMMUNITY.COMMUNITY_MEMBER_APP referencing new as N
{
  declare iri, firi varchar;
  declare graph_iri, site_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  firi := xd_iri (N.CM_COMMUNITY_ID);
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_NAME = N.CM_MEMBER_APP and WAI_IS_PUBLIC = 1
    do
      {
	iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), firi);
	DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('parent_of'), iri);
      }
  return;
};

create trigger COMMUNITY_MEMBER_APP_SIOC_D after delete on ODS.COMMUNITY.COMMUNITY_MEMBER_APP referencing old as O
{
  declare iri, firi varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  firi := xd_iri (O.CM_COMMUNITY_ID);
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_NAME = O.CM_MEMBER_APP and WAI_IS_PUBLIC = 1
    do
      {
	iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
	delete_quad_so (graph_iri, firi, iri);
	delete_quad_so (graph_iri, iri, firi);
      }
  return;
};

create procedure ods_community_sioc_init ()
{

  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');

  if (registry_get ('__ods_sioc_init') <> sioc_version)

    return;

  if (registry_get ('__ods_community_sioc_init') = sioc_version)

    return;

  fill_ods_community_sioc (get_graph (), get_graph ());


  registry_set ('__ods_community_sioc_init', sioc_version);

  return;

};


ODS.COMMUNITY.exec_no_error('ods_community_sioc_init ()');

use DB;
