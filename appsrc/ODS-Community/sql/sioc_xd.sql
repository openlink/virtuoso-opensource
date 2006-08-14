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

create procedure fill_ods_xd_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, firi varchar;
  for select CM_COMMUNITY_ID, CM_MEMBER_APP, WAI_TYPE_NAME, WAI_DESCRIPTION
    from ODS.COMMUNITY.COMMUNITY_MEMBER_APP, DB.DBA.WA_INSTANCE where WAI_NAME = CM_MEMBER_APP do
    {
      firi := xd_iri (CM_COMMUNITY_ID);
      iri := forum_iri (WAI_TYPE_NAME, CM_MEMBER_APP);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_parent', firi);
      DB.DBA.RDF_QUAD_URI (graph_iri, firi, 'http://rdfs.org/sioc/ns#parent_of', iri);
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
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_NAME = N.CM_MEMBER_APP
    do
      {
	iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_parent', firi);
	DB.DBA.RDF_QUAD_URI (graph_iri, firi, 'http://rdfs.org/sioc/ns#parent_of', iri);
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
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_NAME = O.CM_MEMBER_APP
    do
      {
	iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
	delete_quad_so (graph_iri, firi, iri);
	delete_quad_so (graph_iri, iri, firi);
      }
  return;
};

use DB;
