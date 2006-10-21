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

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
      where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/bookmark/%U/%d', get_cname(), get_base_path (), _member, _inst, bmk_id);
}
;

create procedure bmk_links_to (inout content any)
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

create procedure fill_ods_bookmark_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare bookmark_id integer;
  declare iri, c_iri, creator_iri, t_iri varchar;
  declare tags, linksTo any;

  for (select WAI_NAME, BD_DOMAIN_ID, BD_BOOKMARK_ID, BD_NAME, BD_DESCRIPTION, BD_LAST_UPDATE, BD_CREATED, B_URI, WAM_USER
        from DB.DBA.WA_INSTANCE,
             BMK..BOOKMARK_DOMAIN,
             BMK..BOOKMARK,
             DB.DBA.WA_MEMBER
       where BD_DOMAIN_ID = WAI_ID
         and BD_BOOKMARK_ID = B_ID
         and WAM_INST = WAI_NAME
          and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)) do
      {
      c_iri := bmk_iri (WAI_NAME);
	iri := bmk_post_iri (BD_DOMAIN_ID, BD_BOOKMARK_ID);
      creator_iri := user_iri (WAM_USER);

    -- maker
    for (select coalesce(U_FULL_NAME, U_NAME) full_name, U_E_MAIL e_mail from DB.DBA.SYS_USERS where U_ID = WAM_USER) do
      foaf_maker (graph_iri, person_iri (creator_iri), full_name, e_mail);

      linksTo := bmk_links_to (BD_DESCRIPTION);
      ods_sioc_post (graph_iri, iri, c_iri, creator_iri, BD_NAME, BD_CREATED, BD_LAST_UPDATE, B_URI, BD_DESCRIPTION, null, linksTo);

      -- tags
      bookmark_id := BD_BOOKMARK_ID;
    for (select BD_TAGS from BMK.WA.BOOKMARK_DATA where BD_OBJECT_ID = BD_DOMAIN_ID and BD_MODE = 0 and BD_BOOKMARK_ID = bookmark_id) do
	  ods_sioc_tags (graph_iri, iri, BD_TAGS);
        }
    }
;

create procedure bookmark_domain_insert (
  inout domain_id integer,
  inout bookmark_id integer,
  inout name varchar,
  inout created datetime,
  inout updated datetime,
  inout description varchar)
{
  declare graph_iri, iri, c_iri, creator_iri varchar;
  declare linksTo any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};
  graph_iri := get_graph ();
  iri := bmk_post_iri (domain_id, bookmark_id);
  for (select B_URI, WAM_USER, WAI_NAME
         from DB.DBA.WA_INSTANCE,
              BMK..BOOKMARK,
              DB.DBA.WA_MEMBER
        where WAI_ID = domain_id
          and B_ID = bookmark_id
          and WAM_INST = WAI_NAME
          and WAI_IS_PUBLIC = 1) do
  {
    c_iri := bmk_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

    -- maker
    for (select coalesce(U_FULL_NAME, U_NAME) full_name, U_E_MAIL e_mail from DB.DBA.SYS_USERS where U_ID = WAM_USER) do
      foaf_maker (graph_iri, person_iri (creator_iri), full_name, e_mail);

    linksTo := bmk_links_to (description);
    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, name, created, updated, B_URI, description, null, linksTo);
  }
  return;
}
;

create procedure bookmark_domain_delete (
  inout domain_id integer,
  inout bookmark_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := bmk_post_iri (domain_id, bookmark_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

create trigger BOOKMARK_DOMAIN_SIOC_I after insert on BMK.WA.BOOKMARK_DOMAIN referencing new as N
{
  bookmark_domain_insert (N.BD_DOMAIN_ID, N.BD_BOOKMARK_ID, N.BD_NAME, N.BD_CREATED, N.BD_LAST_UPDATE, N.BD_DESCRIPTION);
}
;

create trigger BOOKMARK_DOMAIN_SIOC_U after update on BMK.WA.BOOKMARK_DOMAIN referencing old as O, new as N
{
  bookmark_domain_delete (O.BD_DOMAIN_ID, O.BD_BOOKMARK_ID);
  bookmark_domain_insert (N.BD_DOMAIN_ID, N.BD_BOOKMARK_ID, N.BD_NAME, N.BD_CREATED, N.BD_LAST_UPDATE, N.BD_DESCRIPTION);
}
;

create trigger BOOKMARK_DOMAIN_SIOC_D before delete on BMK.WA.BOOKMARK_DOMAIN referencing old as O
    {
  bookmark_domain_delete (O.BD_DOMAIN_ID, O.BD_BOOKMARK_ID);
    }
;

create procedure bookmark_tags_insert (
  in domain_id integer,
  in bookmark_id integer,
  in tags varchar)
{
  if (isnull(domain_id))
    return;

  declare graph_iri, iri, post_iri, home varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
  return;
};

  home := '/bookmarks/' || cast(domain_id as varchar);
  graph_iri := get_graph ();
  post_iri := bmk_post_iri (domain_id, bookmark_id);
  ods_sioc_tags (graph_iri, post_iri, tags);
}
;

create procedure bookmark_tags_delete (
  in domain_id integer,
  in bookmark_id integer,
  in tags any)
{
  if (isnull(domain_id))
    return;

  declare graph_iri, post_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  post_iri := bmk_post_iri (domain_id, bookmark_id);
  ods_sioc_tags_delete (graph_iri, post_iri, tags);
}
;

create trigger BOOKMARK_DATA_SIOC_I after insert on BMK.WA.BOOKMARK_DATA referencing new as N
{
  if (N.BD_MODE = 0)
    bookmark_tags_insert (N.BD_OBJECT_ID, N.BD_BOOKMARK_ID, N.BD_TAGS);
}
;

create trigger BOOKMARK_DATA_SIOC_U after update on BMK.WA.BOOKMARK_DATA referencing old as O, new as N
{
  if (O.BD_MODE = 0)
    bookmark_tags_delete (O.BD_OBJECT_ID, O.BD_BOOKMARK_ID, O.BD_TAGS);
  if (N.BD_MODE = 0)
    bookmark_tags_insert (N.BD_OBJECT_ID, N.BD_BOOKMARK_ID, N.BD_TAGS);
}
;

create trigger BOOKMARK_DATA_SIOC_D before delete on BMK.WA.BOOKMARK_DATA referencing old as O
{
  if (O.BD_MODE = 0)
    bookmark_tags_delete (O.BD_OBJECT_ID, O.BD_BOOKMARK_ID, O.BD_TAGS);
}
;

create procedure ods_bookmark_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
  return;
  if (registry_get ('__ods_bookmark_sioc_init') = sioc_version)
    return;
  fill_ods_bookmark_sioc (get_graph (), get_graph ());
  registry_set ('__ods_bookmark_sioc_init', sioc_version);
  return;
}
;

BMK.WA.exec_no_error('ods_bookmark_sioc_init ()');

use DB;
