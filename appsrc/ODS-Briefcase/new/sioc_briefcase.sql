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

create procedure briefcase_links_to (inout content any)
{
  declare xt, retValue any;

  if (content is null)
    return null;
  else if (isentity (content))
    xt := content;
  else
    xt := xtree_doc (content, 2, '', 'UTF-8');
  xt := xpath_eval ('//a[starts-with (@href,"http") and not(img)]', xt, 0);
  retValue := vector ();
  foreach (any x in xt) do
    retValue := vector_concat (retValue, vector (vector (cast (xpath_eval ('string()', x) as varchar), cast (xpath_eval ('@href', x) as varchar))));

  return retValue;
}
;

create procedure fill_ods_briefcase_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, c_iri, creator_iri, t_iri, link, content varchar;
  declare linksTo, tags any;

  for (select WAI_ID,
              WAI_NAME,
              WAM_USER,
              U_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER,
              DB.DBA.SYS_USERS
        where WAI_TYPE_NAME = 'oDrive'
          and WAM_INST = WAI_NAME
          and ((_wai_name is null) or (WAI_NAME = _wai_name))
          and WAM_USER = U_ID
          and U_IS_ROLE = 0
          and U_ACCOUNT_DISABLED = 0
          and U_DAV_ENABLE = 1) do
  {
    c_iri := briefcase_iri (WAI_NAME);
    for (select RES_ID, RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER, RES_CONTENT
           from WS.WS.SYS_DAV_RES
                  join WS.WS.SYS_DAV_USER ON RES_OWNER = U_ID
          where RES_FULL_PATH like ODRIVE.WA.odrive_dav_home(U_NAME) || 'Public/%') do
    {
      iri := dav_res_iri (RES_FULL_PATH);
      creator_iri := user_iri (RES_OWNER);
      link := sprintf ('http://%s%s', get_cname(), RES_FULL_PATH);
      content := null;
      if (RES_TYPE like 'text/%')
        content := RES_CONTENT;
      linksTo := null;
      if (RES_TYPE like 'text/html')
        linksTo := briefcase_links_to (RES_CONTENT);
      ods_sioc_post (graph_iri, iri, c_iri, creator_iri, RES_NAME, RES_CR_TIME, RES_MOD_TIME, link, content, null, linksTo);

      -- tags
      tags := DB.DBA.DAV_PROP_GET_INT (RES_ID, 'R', ':virtpublictags', 0);
      if (ODRIVE.WA.DAV_ERROR (tags))
        tags := '';
      ods_sioc_tags (graph_iri, iri, tags);
    }
  }
  return;
}
;

create procedure briefcase_sioc_insert (
  inout r_id integer,
  inout r_full_path varchar,
  inout r_name varchar,
  inout r_type varchar,
  inout r_owner integer,
  inout r_created datetime,
  inout r_updated datetime,
  inout r_content any)
{
  declare graph_iri, iri, c_iri, creator_iri, t_iri, link varchar;
  declare path, linksTo, tags any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (r_full_path not like '/DAV/home/%')
    return;

  path := split_and_decode (r_full_path, 0, '\0\0/');
  if (length (path) < 6)
    return;
  if (path [4] <> 'Public')
    return;

  for (select WAI_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER,
              DB.DBA.SYS_USERS
        where WAI_TYPE_NAME = 'oDrive'
          and WAM_INST = WAI_NAME
          and WAM_USER = U_ID
          and U_NAME = path[3]
          and U_ACCOUNT_DISABLED = 0) do
  {
    graph_iri := get_graph ();
    iri := dav_res_iri (r_full_path);
    creator_iri := user_iri (r_owner);
    c_iri := briefcase_iri (WAI_NAME);
    link := sprintf ('http://%s%s', get_cname(), r_full_path);
    linksTo := null;
    if (r_type like 'text/html')
      linksTo := briefcase_links_to (r_content);
    if (r_type not like 'text/%')
      r_content := null;
    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, r_name, r_created, r_updated, link, r_content, null, linksTo);

    -- tags
    tags := DB.DBA.DAV_PROP_GET_INT (r_id, 'R', ':virtpublictags', 0);
    if (ODRIVE.WA.DAV_ERROR (tags))
      tags := '';
    ods_sioc_tags (graph_iri, iri, tags);
  }
}
;

create procedure briefcase_sioc_delete (
  inout r_full_path varchar)
{
  declare iri, graph_iri varchar;

 declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := dav_res_iri (r_full_path);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

create trigger SYS_DAV_RES_BRIEFCASE_SIOC_I after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  briefcase_sioc_insert (N.RES_ID, N.RES_FULL_PATH, N.RES_NAME, N.RES_TYPE, N.RES_OWNER, N.RES_CR_TIME, N.RES_MOD_TIME, N.RES_CONTENT);
}
;

create trigger SYS_DAV_RES_BRIEFCASE_SIOC_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  briefcase_sioc_delete (O.RES_FULL_PATH);
  briefcase_sioc_insert (N.RES_ID, N.RES_FULL_PATH, N.RES_NAME, N.RES_TYPE, N.RES_OWNER, N.RES_CR_TIME, N.RES_MOD_TIME, N.RES_CONTENT);
}
;

create trigger SYS_DAV_RES_BRIEFCASE_SIOC_D before delete on WS.WS.SYS_DAV_RES referencing old as O
{
  briefcase_sioc_delete (O.RES_FULL_PATH);
}
;

create procedure ods_briefcase_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_briefcase_sioc_init') = sioc_version)
    return;
  fill_ods_briefcase_sioc (get_graph (), get_graph ());
  registry_set ('__ods_briefcase_sioc_init', sioc_version);
  return;
}
;

ODRIVE.WA.exec_no_error ('ods_briefcase_sioc_init ()');

use DB;
