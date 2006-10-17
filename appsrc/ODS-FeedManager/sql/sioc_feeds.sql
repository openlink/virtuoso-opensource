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

-- the same as feeds_iri (wai_name)
create procedure feed_mgr_iri (
  inout domain_id integer)
{
  declare instance varchar;
  declare exit handler for not found { return null; };
  select WAI_NAME into instance from DB.DBA.WA_INSTANCE where WAI_ID = domain_id;
  return feeds_iri (instance);
}
;

-- this represents a feed, not an instance
create procedure feed_iri (
  inout feed_id integer)
{
  return sprintf ('http://%s%s/feed/%d', get_cname(), get_base_path (), feed_id);
}
;

-- this represents item in the given feed
create procedure feed_item_iri (
  inout feed_id integer,
  inout item_id integer)
{
  return sprintf ('http://%s%s/feed/%d/%d', get_cname(), get_base_path (), feed_id, item_id);
}
;

-- this represents comment in the given feed item
create procedure feed_comment_iri (
  inout domain_id integer,
  inout item_id integer,
  inout comment_id integer)
{
  declare owner, instance varchar;
  declare exit handler for not found { return null; };
  select U_NAME, WAI_NAME into owner, instance from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_USER = U_ID and WAM_MEMBER_TYPE = 1 and WAM_INST = WAI_NAME and WAI_ID = domain_id;
  return sprintf ('http://%s%s/%U/feeds/%U/%d/%d', get_cname(), get_base_path (), owner, instance, item_id, comment_id);
}
;

create procedure feed_item_url (
  inout domain_id integer,
  inout item_id integer)
{
  return sprintf('http://%s/enews2/%d/news.vspx?link=%d', get_cname(), domain_id, item_id);
}
;

-- this represents author in the diven post
create procedure author_iri (inout feed_id integer, inout author any, inout content any)
{
  declare a_name, a_email, a_uri, f_uri any;

  a_uri := null;
  if (isnull(author))
    goto _end;
  if (xpath_eval ('/item', content) is not null) {
    -- RSS
    ENEWS.WA.mail_address_split (author, a_name, a_email);
  } else if (xpath_eval ('/entry', content) is not null) {
    -- Atom
    a_uri := cast(xpath_eval ('/entry/author/uri', content, 1) as varchar);
    if (not isnull(a_uri))
      goto _end;
    a_name := cast(xpath_eval ('/entry/author/name', content, 1) as varchar);
    a_email := cast(xpath_eval ('/entry/author/email', content, 1) as varchar);
  }
  if (not isnull(a_name)) {
    f_uri := (select EF_URI from ENEWS.WA.FEED where EF_ID = feed_id);
    a_uri := f_uri || '#' || replace (sprintf ('%U', a_name), '+', '%2B');
  }
_end:
  return a_uri;
}
;

create procedure feed_links_to (inout content any)
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

create procedure fill_ods_feeds_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, m_iri, f_iri, t_iri, c_iri varchar;
  declare tags, linksTo any;

  for select EFD_ID, EFD_DOMAIN_ID, EFD_FEED_ID, EFD_TITLE, EF_ID, EF_URI, EF_HOME_URI, EF_SOURCE_URI, EF_TITLE, EF_DESCRIPTION
        from ENEWS..FEED_DOMAIN,
             ENEWS..FEED,
             DB.DBA.WA_INSTANCE
       where EFD_FEED_ID = EF_ID
         and EFD_DOMAIN_ID = WAI_ID
         and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name) do
  {
      iri := feed_iri (EF_ID);
      m_iri := feed_mgr_iri (EFD_DOMAIN_ID);
    DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
    DB.DBA.RDF_QUAD_URI (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
    }
  for (select EFI_FEED_ID, EFI_ID, EFI_TITLE, EFI_DESCRIPTION, EFI_LINK, EFI_AUTHOR, EFI_PUBLISH_DATE from ENEWS..FEED_ITEM) do
  {
    iri := feed_item_iri (EFI_FEED_ID, EFI_ID);
      f_iri := feed_iri (EFI_FEED_ID);
    linksTo := feed_links_to (EFI_DESCRIPTION);
    ods_sioc_post (graph_iri, iri, f_iri, null, EFI_TITLE, EFI_PUBLISH_DATE, null, EFI_LINK, EFI_DESCRIPTION, null, linksTo);

    -- tags
    for (select EFID_DOMAIN_ID, EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_DOMAIN_ID is not null and EFID_ITEM_ID = EFI_ID) do
    {
      ods_sioc_tags (graph_iri, iri, EFID_TAGS);
    }

    -- comments
    for (select EFIC_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE, EFIC_COMMENT, EFIC_U_NAME, EFIC_U_MAIL, EFIC_U_URL, EFIC_LAST_UPDATE from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ITEM_ID = EFI_FEED_ID and EFIC_PARENT_ID is not null) do
    {
      c_iri := feed_comment_iri (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer), EFIC_ID);
      foaf_maker (graph_iri, EFIC_U_URL, EFIC_U_NAME, EFIC_U_MAIL);
      ods_sioc_post (graph_iri, c_iri, f_iri, null, EFIC_TITLE, EFIC_LAST_UPDATE, EFIC_LAST_UPDATE, feed_item_url (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer)), EFIC_COMMENT, null, null, EFIC_U_NAME);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_reply'), c_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, sioc_iri ('reply_of'), iri);
    }
    }
}
;

-- ENEWS..FEED
create trigger FEEDD_SIOC_I after insert on ENEWS..FEED_DOMAIN referencing new as N
{
  declare iri, graph_iri, m_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := feed_iri (N.EFD_FEED_ID);
  m_iri := feed_mgr_iri (N.EFD_DOMAIN_ID);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
}
;

create trigger FEEDD_SIOC_D before delete on ENEWS..FEED_DOMAIN referencing old as O
{
  declare iri, graph_iri, m_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := feed_iri (O.EFD_FEED_ID);
  m_iri := feed_mgr_iri (O.EFD_DOMAIN_ID);
  delete_quad_s_p_o (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
  delete_quad_s_p_o (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
}
;

-- ENEWS..FEED_ITEM
create procedure feeds_item_insert (
  inout feed_id integer,
  inout id integer,
  inout title varchar,
  inout publish_date datetime,
  inout author varchar,
  inout link varchar,
  inout description varchar,
  inout data any)
{
  declare iri, graph_iri, f_iri, a_iri, comment_iri varchar;
  declare linksTo any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  f_iri := feed_iri (feed_id);
  iri := feed_item_iri (feed_id, id);
  a_iri := author_iri (feed_id, author, data);
  linksTo := feed_links_to (description);
  ods_sioc_post (graph_iri, iri, f_iri, a_iri, title, publish_date, null, link, description, null, linksTo);
}
;

create procedure feeds_item_delete (
  inout feed_id integer,
  inout id integer)
{
  declare iri, graph_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := feed_item_iri (feed_id, id);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
}
;

create trigger FEED_ITEM_SIOC_I after insert on ENEWS..FEED_ITEM referencing new as N
{
  feeds_item_insert (N.EFI_FEED_ID, N.EFI_ID, N.EFI_TITLE, N.EFI_PUBLISH_DATE, N.EFI_AUTHOR, N.EFI_LINK, N.EFI_DESCRIPTION, N.EFI_DATA);
}
;

create trigger FEED_ITEM_SIOC_U after update on ENEWS..FEED_ITEM referencing old as O, new as N
{
  feeds_item_delete (O.EFI_FEED_ID, O.EFI_ID);
  feeds_item_insert (N.EFI_FEED_ID, N.EFI_ID, N.EFI_TITLE, N.EFI_PUBLISH_DATE, N.EFI_AUTHOR, N.EFI_LINK, N.EFI_DESCRIPTION, N.EFI_DATA);
}
;

create trigger FEED_ITEM_SIOC_D before delete on ENEWS..FEED_ITEM referencing old as O
{
  feeds_item_delete (O.EFI_FEED_ID, O.EFI_ID);
}
;

create procedure feeds_tags_insert (
  inout domain_id integer,
  inout item_id integer,
  inout tags varchar)
{
  if (isnull(domain_id))
    return;

  declare feed_id integer;
  declare graph_iri, iri, post_iri, home varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  home := '/enews2/' || cast(domain_id as varchar);
  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  iri := feed_iri (feed_id);
  post_iri := feed_item_iri (feed_id, item_id);

  ods_sioc_tags (graph_iri, post_iri, tags);
}
;

create procedure feeds_tags_delete (
  inout domain_id integer,
  inout item_id integer,
  in tags any)
{
  if (isnull(domain_id))
    return;

  declare feed_id integer;
  declare graph_iri, post_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};

  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  post_iri := feed_item_iri (feed_id, item_id);
  ods_sioc_tags_delete (graph_iri, post_iri, tags);
}
;

create trigger FEED_ITEM_DATA_SIOC_I after insert on ENEWS.WA.FEED_ITEM_DATA referencing new as N
{
  feeds_tags_insert (N.EFID_DOMAIN_ID, N.EFID_ITEM_ID, N.EFID_TAGS);
}
;

create trigger FEED_ITEM_DATA_SIOC_U after update on ENEWS.WA.FEED_ITEM_DATA referencing old as O, new as N
{
  feeds_tags_delete (O.EFID_DOMAIN_ID, O.EFID_ITEM_ID, O.EFID_TAGS);
  feeds_tags_insert (N.EFID_DOMAIN_ID, N.EFID_ITEM_ID, N.EFID_TAGS);
}
;

create trigger FEED_ITEM_DATA_SIOC_D before delete on ENEWS.WA.FEED_ITEM_DATA referencing old as O
{
  feeds_tags_delete (O.EFID_DOMAIN_ID, O.EFID_ITEM_ID, O.EFID_TAGS);
}
;

create procedure feeds_comment_insert (
  inout domain_id integer,
  inout item_id integer,
  inout id integer,
  inout title varchar,
  inout comment varchar,
  inout last_update datetime,
  inout u_name varchar,
  inout u_mail varchar,
  inout u_url varchar)
{
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1))
    return;

  declare feed_id integer;
  declare graph_iri, iri, feed_iri, item_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  feed_iri := feed_iri (feed_id);
  item_iri := feed_item_iri (feed_id, item_id);
  iri := feed_comment_iri (domain_id, item_id, id);
  foaf_maker (graph_iri, u_url, u_name, u_mail);
  ods_sioc_post (graph_iri, iri, feed_iri, null, title, last_update, last_update, feed_item_url (domain_id, item_id), comment, null, null, u_name);
  DB.DBA.RDF_QUAD_URI (graph_iri, item_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), item_iri);
}
;

create procedure feeds_comment_delete (
  inout domain_id integer,
  inout item_id integer,
  inout id integer)
{
  declare iri, graph_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := feed_comment_iri (domain_id, item_id, id);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
}
;

create trigger FEED_ITEM_COMMENT_SIOC_I after insert on ENEWS.WA.FEED_ITEM_COMMENT referencing new as N
{
  if (not isnull(N.EFIC_PARENT_ID))
    feeds_comment_insert (N.EFIC_DOMAIN_ID, cast(N.EFIC_ITEM_ID as integer), N.EFIC_ID, N.EFIC_TITLE, N.EFIC_COMMENT, N.EFIC_LAST_UPDATE, N.EFIC_U_NAME, N.EFIC_U_MAIL, N.EFIC_U_URL);
}
;

create trigger FEED_ITEM_COMMENT_SIOC_U after update on ENEWS.WA.FEED_ITEM_COMMENT referencing old as O, new as N
{
  if (not isnull(O.EFIC_PARENT_ID))
    feeds_comment_delete (O.EFIC_DOMAIN_ID, cast(O.EFIC_ITEM_ID as integer), O.EFIC_ID);
  if (not isnull(N.EFIC_PARENT_ID))
    feeds_comment_insert (N.EFIC_DOMAIN_ID, cast(N.EFIC_ITEM_ID as integer), N.EFIC_ID, N.EFIC_TITLE, N.EFIC_COMMENT, N.EFIC_LAST_UPDATE, N.EFIC_U_NAME, N.EFIC_U_MAIL, N.EFIC_U_URL);
}
;

create trigger FEED_ITEM_COMMENT_SIOC_D before delete on ENEWS.WA.FEED_ITEM_COMMENT referencing old as O
{
  if (not isnull(O.EFIC_PARENT_ID))
    feeds_comment_delete (O.EFIC_DOMAIN_ID, cast(O.EFIC_ITEM_ID as integer), O.EFIC_ID);
}
;

create procedure ods_feeds_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_feeds_sioc_init') = sioc_version)
    return;
  fill_ods_feeds_sioc (get_graph (), get_graph ());
  registry_set ('__ods_feeds_sioc_init', sioc_version);
  return;
}
;

ENEWS.WA.exec_no_error('ods_feeds_sioc_init ()');

use DB;
