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

use sioc;

create procedure fill_ods_community_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, firi varchar;
  declare deadl, cnt any;

  deadl := 5;
  cnt := 0;
  declare exit handler for sqlstate '40001' {
    if (deadl <= 0)
      resignal;
    rollback work;
    deadl := deadl - 1;
    goto l1;
  };
  l1:
  for select CM_COMMUNITY_ID, CM_MEMBER_APP, WAI_TYPE_NAME, WAI_DESCRIPTION
    from ODS.COMMUNITY.COMMUNITY_MEMBER_APP, DB.DBA.WA_INSTANCE where WAI_NAME = CM_MEMBER_APP
	and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
	do
    {
      firi := xd_iri (CM_COMMUNITY_ID);
      iri := forum_iri (WAI_TYPE_NAME, CM_MEMBER_APP);
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('part_of'), firi);
      DB.DBA.ODS_QUAD_URI (graph_iri, firi, sioc_iri ('has_part'), iri);
    }
  commit work;
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
	DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('part_of'), firi);
	DB.DBA.ODS_QUAD_URI (graph_iri, firi, sioc_iri ('has_part'), iri);
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


--ODS.COMMUNITY.exec_no_error('ods_community_sioc_init ()');

use DB;
use DB;
-- COMMUNITY

wa_exec_no_error ('drop view ODS_COMMUNITIES');

create view ODS_COMMUNITIES as
		select
		CM_COMMUNITY_ID,
		cu.U_NAME as C_OWNER,
		CM_MEMBER_APP,
		DB.DBA.wa_type_to_app (am.WAM_APP_TYPE) as A_TYPE,
		au.U_NAME as A_OWNER
		from
		ODS.COMMUNITY.COMMUNITY_MEMBER_APP, DB.DBA.WA_MEMBER cm, DB.DBA.WA_MEMBER am, DB.DBA.SYS_USERS cu, DB.DBA.SYS_USERS au
		where CM_COMMUNITY_ID = cm.WAM_INST and cm.WAM_USER = cu.U_ID and CM_MEMBER_APP = am.WAM_INST and am.WAM_USER = au.U_ID
		and cm.WAM_MEMBER_TYPE = 1 and am.WAM_MEMBER_TYPE = 1;

create procedure sioc.DBA.rdf_community_view_str ()
{
  return
      '
      # Relation between forums and community
      sioc:community_forum_iri (DB.DBA.ODS_COMMUNITIES.C_OWNER, DB.DBA.ODS_COMMUNITIES.CM_COMMUNITY_ID)
      sioc:has_part
      sioc:forum_iri (A_OWNER, A_TYPE, CM_MEMBER_APP) .

      sioc:forum_iri (DB.DBA.ODS_COMMUNITIES.A_OWNER, DB.DBA.ODS_COMMUNITIES.A_TYPE, DB.DBA.ODS_COMMUNITIES.CM_MEMBER_APP)
      sioc:part_of
      sioc:community_forum_iri (C_OWNER, CM_COMMUNITY_ID) .

      '
      ;
};

create procedure sioc.DBA.rdf_community_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_COMMUNITIES as community
      where (^{community.}^.C_OWNER = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_community_view_str_maps ()
{
  return
      '
      # Community
	    ods:community_forum (community.C_OWNER, community.CM_COMMUNITY_ID) a sioc:Community ;
	    sioc:has_part ods:forum (community.A_OWNER, community.A_TYPE, community.CM_MEMBER_APP) .

	    ods:forum (community.A_OWNER, community.A_TYPE, community.CM_MEMBER_APP)
	    sioc:part_of
	    ods:community_forum (community.C_OWNER, community.CM_COMMUNITY_ID) .
      # end Community
      '
      ;
};

grant select on ODS_COMMUNITIES to "SPARQL_SELECT";
-- END COMMUNITY
ODS_RDF_VIEW_INIT ();
