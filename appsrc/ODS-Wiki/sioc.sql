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

use sioc
;

create procedure wiki_post_iri (in cluster_id int, in localname varchar)
{
  declare _inst, owner varchar;
  declare exit handler for not found { return null; };
  select top 1 ClusterName, U_NAME into _inst, owner from WV..CLUSTERS, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where ClusterId = cluster_id
      and ClusterName = WAM_INST and U_ID = WAM_USER;
  return sprintf ('http://%s%s/%U/wiki/%U/%U', get_cname(), get_base_path (), owner, _inst, localname);
}
;

create procedure wiki_cluster_iri (in cluster_id int)
{
  declare _inst, owner varchar;
  declare exit handler for not found { return null; };
  select top 1 ClusterName, U_NAME into _inst, owner from WV..CLUSTERS, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where ClusterId = cluster_id
      and ClusterName = WAM_INST and U_ID = WAM_USER;
  return sprintf ('http://%s%s/%U/wiki/%U', get_cname(), get_base_path (), owner, _inst);
}
;

create procedure fill_ods_wiki_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, c_iri varchar;
  for select ClusterId, LocalName, TitleText, T_OWNER_ID, T_CREATE_TIME, T_PUBLISHED from WV..TOPIC do
    {
      iri := wiki_post_iri (ClusterId, LocalName);
      c_iri := wiki_cluster_iri (ClusterId);
      if (iri is not null)
	{
	  ods_sioc_post (graph_iri, iri, c_iri, null, coalesce (TitleText, LocalName), T_CREATE_TIME, null);
        }
    }
}
;


create trigger TOPIC_SIOC_I after insert on WV..TOPIC referencing new as N
{
  declare iri, c_iri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := wiki_post_iri (N.ClusterId, N.LocalName);
  c_iri := wiki_cluster_iri (N.ClusterId);
  ods_sioc_post (graph_iri, iri, c_iri, null, coalesce (N.TitleText, N.LocalName), N.T_CREATE_TIME, null);
}
;


create trigger TOPIC_SIOC_D before delete on WV..TOPIC referencing old as O
{
  declare iri, c_iri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := wiki_post_iri (O.ClusterId, O.LocalName);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;


use DB
;
