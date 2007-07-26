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

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
-- this represents a feed, not an instance
create procedure feed_iri (
  inout feed_id integer)
{
  return sprintf ('http://%s%s/feed/%d', get_cname(), get_base_path (), feed_id);
}
;

-------------------------------------------------------------------------------
--
-- this represents item in the given feed, if name changed should change in sioc.sql too
create procedure feed_item_iri (
  inout feed_id integer,
  inout item_id integer)
{
  return sprintf ('http://%s%s/feed/%d/%d', get_cname(), get_base_path (), feed_id, item_id);
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
create procedure feed_annotation_iri (
  in domain_id varchar,
  in item_id integer,
  in annotation_id integer)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
   where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/feeds/%U/%d/annotation/%d', get_cname(), get_base_path (), _member, _inst, item_id, annotation_id);
}
;

-------------------------------------------------------------------------------
--
create procedure feed_item_url (
  inout domain_id integer,
  inout item_id integer)
{
  return sprintf('http://%s/enews2/%d/news.vspx?link=%d', get_cname(), domain_id, item_id);
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
-- this represents author in the diven post
create procedure feeds_foaf_maker (inout graph_iri varchar, inout feed_id integer, inout author any, inout content any)
{
  declare a_name, a_email, a_uri, f_uri any;

  a_uri := null;
  if (isnull (author) or isnull (content))
    goto _end;

  a_name := null;
  if (xpath_eval ('/item', content) is not null) {
    -- RSS
    ENEWS.WA.mail_address_split (author, a_name, a_email);
  } else if (xpath_eval ('/entry', content) is not null) {
    -- Atom
    a_uri := cast(xpath_eval ('/entry/author/uri', content, 1) as varchar);
    a_name := cast(xpath_eval ('/entry/author/name', content, 1) as varchar);
    a_email := cast(xpath_eval ('/entry/author/email', content, 1) as varchar);
  }
  if (isnull(a_uri) and not isnull(a_name)) {
    f_uri := (select EF_URI from ENEWS.WA.FEED where EF_ID = feed_id);
    a_uri := f_uri || '#' || replace (sprintf ('%U', a_name), '+', '%2B');
  }
  if (not isnull(a_uri))
    foaf_maker (graph_iri, a_uri, a_name, a_email);
_end:
  return a_uri;
}
;

-------------------------------------------------------------------------------
--
create procedure feed_links_to (inout content any)
{
  declare xt, retValue any;

  declare exit handler for sqlstate '*'
    {
      return null;
    };

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

-------------------------------------------------------------------------------
--
create procedure fill_ods_feeds_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, m_iri, f_iri, t_iri, u_iri, c_iri varchar;
  declare tags, linksTo any;
  declare id, deadl, cnt any;

 {

    id := -1;
    deadl := 3;
    cnt := 0;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
    };
    l0:

  for select EFD_ID, EFD_DOMAIN_ID, EFD_FEED_ID, EFD_TITLE, EF_ID, EF_URI, EF_HOME_URI, EF_SOURCE_URI, EF_TITLE, EF_DESCRIPTION
        from ENEWS..FEED_DOMAIN,
             ENEWS..FEED,
             DB.DBA.WA_INSTANCE
         where EFD_ID > id
         and EFD_FEED_ID = EF_ID
         and EFD_DOMAIN_ID = WAI_ID
           and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
         order by EFD_ID do
  {
      iri := feed_iri (EF_ID);
      m_iri := feed_mgr_iri (EFD_DOMAIN_ID);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Feed'));
    DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
    DB.DBA.RDF_QUAD_URI (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
    cnt := cnt + 1;
      if (mod (cnt, 500) = 0) {
	commit work;
	      id := EFD_ID;
      }
  }
  commit work;
    }
 {
    id := -1;
    deadl := 3;
    cnt := 0;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l1;
    };
    l1:

    for select EFI_FEED_ID,
               EFI_ID,
               EFI_TITLE,
               EFI_DESCRIPTION,
               EFI_LINK,
               EFI_AUTHOR,
               EFI_PUBLISH_DATE,
               EFI_DATA
          from ENEWS.WA.FEED_ITEM,
               ENEWS.WA.FEED
         where EFI_FEED_ID = EF_ID
           and EFI_ID > id
	 order by 2 option (order, loop)
    do {
      f_iri := feed_iri (EFI_FEED_ID);
      iri := feed_item_iri (EFI_FEED_ID, EFI_ID);
      u_iri := feeds_foaf_maker (graph_iri, EFI_FEED_ID, EFI_AUTHOR, EFI_DATA);
    linksTo := feed_links_to (EFI_DESCRIPTION);
      ods_sioc_post (graph_iri, iri, f_iri, null, EFI_TITLE, EFI_PUBLISH_DATE, null, EFI_LINK, EFI_DESCRIPTION, null, linksTo, u_iri);

    -- tags
    for (select EFID_DOMAIN_ID, EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_DOMAIN_ID is not null and EFID_ITEM_ID = EFI_ID) do
      ods_sioc_tags (graph_iri, iri, EFID_TAGS);

    -- comments
    for (select EFIC_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE, EFIC_COMMENT, EFIC_U_NAME, EFIC_U_MAIL, EFIC_U_URL, EFIC_LAST_UPDATE from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ITEM_ID = EFI_ID and EFIC_PARENT_ID is not null) do
    {
      c_iri := feed_comment_iri (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer), EFIC_ID);
      if (not isnull (c_iri)) {
      foaf_maker (graph_iri, EFIC_U_URL, EFIC_U_NAME, EFIC_U_MAIL);
        ods_sioc_post (graph_iri, c_iri, f_iri, null, EFIC_TITLE, EFIC_LAST_UPDATE, EFIC_LAST_UPDATE, feed_item_url (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer)), EFIC_COMMENT, null, null, EFIC_U_URL);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_reply'), c_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, sioc_iri ('reply_of'), iri);
    }
    }
      -- annotations
      for (select A_ID,
                  A_DOMAIN_ID,
                  A_OBJECT_ID,
                  A_BODY,
                  A_AUTHOR,
                  A_CREATED,
                  A_UPDATED
             from ENEWS.WA.ANNOTATIONS
            where A_OBJECT_ID = EFI_ID) do
      {
        feeds_annotation_insert (graph_iri,
                                 feed_mgr_iri (A_DOMAIN_ID),
                                 A_ID,
                                 A_DOMAIN_ID,
                                 A_OBJECT_ID,
                                 A_BODY,
                                 A_AUTHOR,
                                 A_CREATED,
                                 A_UPDATED);
      }
    cnt := cnt + 1;
      if (mod (cnt, 500) = 0) {
	commit work;
	      id := EFI_ID;
      }
  }
  commit work;
 }
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
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
  declare iri, graph_iri, f_iri, u_iri, comment_iri varchar;
  declare linksTo any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  f_iri := feed_iri (feed_id);
  iri := feed_item_iri (feed_id, id);
  u_iri := feeds_foaf_maker (graph_iri, feed_id, author, data);
  linksTo := feed_links_to (description);
  ods_sioc_post (graph_iri, iri, f_iri, null, title, publish_date, null, link, description, null, linksTo, u_iri);
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_SIOC_I after insert on ENEWS..FEED_ITEM referencing new as N
{
  feeds_item_insert (N.EFI_FEED_ID, N.EFI_ID, N.EFI_TITLE, N.EFI_PUBLISH_DATE, N.EFI_AUTHOR, N.EFI_LINK, N.EFI_DESCRIPTION, N.EFI_DATA);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_SIOC_U after update on ENEWS..FEED_ITEM referencing old as O, new as N
{
  feeds_item_delete (O.EFI_FEED_ID, O.EFI_ID);
  feeds_item_insert (N.EFI_FEED_ID, N.EFI_ID, N.EFI_TITLE, N.EFI_PUBLISH_DATE, N.EFI_AUTHOR, N.EFI_LINK, N.EFI_DESCRIPTION, N.EFI_DATA);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_SIOC_D before delete on ENEWS..FEED_ITEM referencing old as O
{
  feeds_item_delete (O.EFI_FEED_ID, O.EFI_ID);
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_DATA_SIOC_I after insert on ENEWS.WA.FEED_ITEM_DATA referencing new as N
{
  feeds_tags_insert (N.EFID_DOMAIN_ID, N.EFID_ITEM_ID, N.EFID_TAGS);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_DATA_SIOC_U after update on ENEWS.WA.FEED_ITEM_DATA referencing old as O, new as N
{
  feeds_tags_delete (O.EFID_DOMAIN_ID, O.EFID_ITEM_ID, O.EFID_TAGS);
  feeds_tags_insert (N.EFID_DOMAIN_ID, N.EFID_ITEM_ID, N.EFID_TAGS);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_DATA_SIOC_D before delete on ENEWS.WA.FEED_ITEM_DATA referencing old as O
{
  feeds_tags_delete (O.EFID_DOMAIN_ID, O.EFID_ITEM_ID, O.EFID_TAGS);
}
;

-------------------------------------------------------------------------------
--
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
  if (not isnull (iri)) {
  foaf_maker (graph_iri, u_url, u_name, u_mail);
    ods_sioc_post (graph_iri, iri, feed_iri, null, title, last_update, last_update, feed_item_url (domain_id, item_id), comment, null, null, u_url);
  DB.DBA.RDF_QUAD_URI (graph_iri, item_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), item_iri);
}
}
;

-------------------------------------------------------------------------------
--
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

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_COMMENT_SIOC_I after insert on ENEWS.WA.FEED_ITEM_COMMENT referencing new as N
{
  if (not isnull(N.EFIC_PARENT_ID))
    feeds_comment_insert (N.EFIC_DOMAIN_ID, cast(N.EFIC_ITEM_ID as integer), N.EFIC_ID, N.EFIC_TITLE, N.EFIC_COMMENT, N.EFIC_LAST_UPDATE, N.EFIC_U_NAME, N.EFIC_U_MAIL, N.EFIC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_COMMENT_SIOC_U after update on ENEWS.WA.FEED_ITEM_COMMENT referencing old as O, new as N
{
  if (not isnull(O.EFIC_PARENT_ID))
    feeds_comment_delete (O.EFIC_DOMAIN_ID, cast(O.EFIC_ITEM_ID as integer), O.EFIC_ID);
  if (not isnull(N.EFIC_PARENT_ID))
    feeds_comment_insert (N.EFIC_DOMAIN_ID, cast(N.EFIC_ITEM_ID as integer), N.EFIC_ID, N.EFIC_TITLE, N.EFIC_COMMENT, N.EFIC_LAST_UPDATE, N.EFIC_U_NAME, N.EFIC_U_MAIL, N.EFIC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_ITEM_COMMENT_SIOC_D before delete on ENEWS.WA.FEED_ITEM_COMMENT referencing old as O
{
  if (not isnull(O.EFIC_PARENT_ID))
    feeds_comment_delete (O.EFIC_DOMAIN_ID, cast(O.EFIC_ITEM_ID as integer), O.EFIC_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure feeds_annotation_insert (
  in graph_iri varchar,
  in forum_iri varchar,
  inout annotation_id integer,
  inout domain_id integer,
  inout master_id integer,
  inout author varchar,
  inout body varchar,
  inout created datetime,
  inout updated datetime)
{
  declare master_iri, annotattion_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (isnull (graph_iri))
    for (select WAI_ID, WAM_USER, WAI_NAME
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER
          where WAI_ID = domain_id
            and WAM_INST = WAI_NAME
            and WAI_IS_PUBLIC = 1) do
    {
      graph_iri := get_graph ();
      forum_iri := feeds_iri (WAI_NAME);
    }

  if (not isnull (graph_iri)) {
    declare feed_id integer;

    feed_id := (select EFI_FEED_ID from ENEWS.WA.FEED_ITEM where EFI_ID = master_id);
    master_iri := feed_item_iri (feed_id, master_id);
    annotattion_iri := feed_annotation_iri (domain_id, cast (master_id as integer), annotation_id);

	  DB.DBA.RDF_QUAD_URI (graph_iri, annotattion_iri, sioc_iri ('has_container'), forum_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), annotattion_iri);

	  DB.DBA.RDF_QUAD_URI (graph_iri, annotattion_iri, an_iri ('annotates'), master_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, master_iri, an_iri ('hasAnnotation'), annotattion_iri);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('author'), author);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('body'), body);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('created'), created);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('modified'), updated);
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure feeds_annotation_delete (
  inout annotation_id integer,
  inout domain_id integer,
  inout master_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := feed_annotation_iri (domain_id, master_id, annotation_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_I after insert on ENEWS.WA.ANNOTATIONS referencing new as N
{
  feeds_annotation_insert (null,
                           null,
                           N.A_ID,
                           N.A_DOMAIN_ID,
                           N.A_OBJECT_ID,
                           N.A_BODY,
                           N.A_AUTHOR,
                           N.A_CREATED,
                           N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_U after update on ENEWS.WA.ANNOTATIONS referencing old as O, new as N
{
  feeds_annotation_delete (O.A_ID,
                           O.A_DOMAIN_ID,
                           O.A_OBJECT_ID);
  feeds_annotation_insert (null,
                           null,
                           N.A_ID,
                           N.A_DOMAIN_ID,
                           N.A_OBJECT_ID,
                           N.A_BODY,
                           N.A_AUTHOR,
                           N.A_CREATED,
                           N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_D before delete on ENEWS.WA.ANNOTATIONS referencing old as O
{
  feeds_annotation_delete (O.A_ID,
                           O.A_DOMAIN_ID,
                           O.A_OBJECT_ID);
}
;

-------------------------------------------------------------------------------
--
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

--ENEWS.WA.exec_no_error('ods_feeds_sioc_init ()');

create procedure feed_comment_iri_1 (
  inout owner varchar,
  inout instance varchar,
  inout domain_id integer,
  inout item_id integer,
  inout comment_id integer)
{
  return sprintf ('http://%s%s/%U/feeds/%U/%d/%d', get_cname(), get_base_path (), owner, instance, item_id, comment_id);
}
;


use DB;
-- FEEDS

-- Feeds posts & related

--wa_exec_no_error ('drop view ');

wa_exec_no_error ('drop view ODS_FEED_FEED_DOMAIN');
wa_exec_no_error ('drop view ODS_FEED_POSTS');
wa_exec_no_error ('drop view ODS_FEED_COMMENTS');
wa_exec_no_error ('drop view ODS_FEED_TAGS');
wa_exec_no_error ('drop view ODS_FEED_LINKS');
wa_exec_no_error ('drop view ODS_FEED_ATTS');

create view ODS_FEED_FEED_DOMAIN as select U_NAME, WAI_NAME, EF_ID, EF_TITLE, EF_URI
	from ENEWS..FEED_DOMAIN, ENEWS..FEED, WA_MEMBER, WA_INSTANCE, SYS_USERS
        where EFD_FEED_ID = EF_ID and EFD_DOMAIN_ID = WAI_ID and WAI_IS_PUBLIC = 1
	and U_ID = WAM_USER and WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1;

create view ODS_FEED_POSTS as select
	EFI_FEED_ID,
	EFI_ID,
	EFI_TITLE,
	EFI_DESCRIPTION,
	EFI_LINK,
	EFI_AUTHOR,
	sioc..feed_item_iri (EFI_FEED_ID, EFI_ID) || '/sioc.rdf' as SEE_ALSO,
	sioc..sioc_date (EFI_PUBLISH_DATE) as PUBLISH_DATE
	from ENEWS.WA.FEED_ITEM;

create view ODS_FEED_COMMENTS as select
	U_NAME,
	WAI_NAME,
	EFIC_ID,
	EFI_FEED_ID,
	EFIC_DOMAIN_ID,
	cast (EFIC_ITEM_ID as integer) as EFIC_ITEM_ID,
	EFIC_TITLE,
	EFIC_COMMENT,
	EFIC_U_NAME,
	EFIC_U_MAIL,
	EFIC_U_URL,
	sioc..feed_comment_iri_1 (U_NAME, WAI_NAME, EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer), EFIC_ID) || '/sioc.rdf' as SEE_ALSO,
	sioc..sioc_date (EFIC_LAST_UPDATE) as LAST_UPDATE,
	sioc..feed_item_url (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer)) as LINK
	from ENEWS.WA.FEED_ITEM_COMMENT, ENEWS.WA.FEED_ITEM, DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
        where
	EFIC_ITEM_ID = EFI_ID and
	WAM_USER = U_ID and
	WAM_MEMBER_TYPE = 1 and
	WAM_INST = WAI_NAME and
	WAI_ID = EFIC_DOMAIN_ID and
	EFIC_PARENT_ID is not null;

create procedure ODS_FEED_TAGS ()
{
  declare inst, uname, item_id, tag, feed_id any;
  result_names (inst, uname, item_id, tag, feed_id);
  for  select WAM_INST, U_NAME, EFID_ITEM_ID, EFID_TAGS, EFI_FEED_ID from  ENEWS.WA.FEED_ITEM_DATA, ENEWS.WA.FEED_ITEM, WA_MEMBER, WA_INSTANCE, SYS_USERS where WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1 and EFID_DOMAIN_ID = WAI_ID and WAM_USER = U_ID and EFID_ITEM_ID = EFI_ID do
    {
      declare arr any;
      arr := split_and_decode (EFID_TAGS, 0, '\0\0,');
      foreach (any t in arr) do
	{
	  t := trim(t);
	  if (length (t))
	    {
	      result (WAM_INST, U_NAME, EFID_ITEM_ID, t, EFI_FEED_ID);
	    }
	}
    }
};

create procedure view ODS_FEED_TAGS as DB.DBA.ODS_FEED_TAGS() (WAM_INST varchar, U_NAME varchar, EFID_ITEM_ID int, EFID_TAG varchar, EFI_FEED_ID int);

create view ODS_FEED_LINKS as select EFIL_LINK, EFI_FEED_ID, EFI_ID
	from ENEWS.WA.FEED_ITEM, ENEWS.WA.FEED_ITEM_LINK
	where EFI_ID = EFIL_ITEM_ID;

create view ODS_FEED_ATTS as select EFIE_URL, EFI_FEED_ID, EFI_ID from ENEWS.WA.FEED_ITEM_ENCLOSURE, ENEWS.WA.FEED_ITEM
	where EFI_ID = EFIE_ITEM_ID;

create procedure sioc.DBA.rdf_feeds_view_str ()
{
  return
      '

	# Feeds
        sioc:feed_iri (DB.DBA.ODS_FEED_FEED_DOMAIN.EF_ID) a atom:Feed option (EXCLUSIVE) ;
        sioc:link sioc:proxy_iri (EF_URI) ;
	atom:link sioc:proxy_iri (EF_URI) ;
	atom:title EF_TITLE ;
	sioc:has_parent sioc:feed_mgr_iri (U_NAME, WAI_NAME) .
	sioc:feed_mgr_iri (DB.DBA.ODS_FEED_FEED_DOMAIN.U_NAME, DB.DBA.ODS_FEED_FEED_DOMAIN.WAI_NAME)
	sioc:parent_of sioc:feed_iri (EF_ID) .

	# Posts
	sioc:feed_item_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID, DB.DBA.ODS_FEED_POSTS.EFI_ID) a sioc:Item ;
  	sioc:has_container sioc:feed_iri (EFI_FEED_ID) ;
	dc:title EFI_TITLE ;
	dct:created PUBLISH_DATE ;
	dct:modified PUBLISH_DATE ;
	sioc:link sioc:proxy_iri (EFI_LINK) ;
	rdfs:seeAlso  sioc:proxy_iri (SEE_ALSO) ;
	sioc:content EFI_DESCRIPTION .

        sioc:feed_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID) sioc:container_of sioc:feed_item_iri (EFI_FEED_ID, EFI_ID) .

	# Post tags
        sioc:feed_item_iri (DB.DBA.ODS_FEED_TAGS.EFI_FEED_ID, DB.DBA.ODS_FEED_TAGS.EFID_ITEM_ID)
	sioc:topic
	sioc:tag_iri (U_NAME, EFID_TAG) .

	sioc:tag_iri (DB.DBA.ODS_FEED_TAGS.U_NAME, DB.DBA.ODS_FEED_TAGS.EFID_TAG) a skos:Concept ;
	skos:prefLabel EFID_TAG ;
	skos:isSubjectOf sioc:feed_item_iri (EFI_FEED_ID, EFID_ITEM_ID) .

	# Comments
	sioc:feed_comment_iri (DB.DBA.ODS_FEED_COMMENTS.U_NAME, DB.DBA.ODS_FEED_COMMENTS.WAI_NAME, DB.DBA.ODS_FEED_COMMENTS.EFIC_ITEM_ID, DB.DBA.ODS_FEED_COMMENTS.EFIC_ID) a sioct:Comment ;
	dc:title EFIC_TITLE ;
	sioc:content EFIC_COMMENT ;
	dct:modified LAST_UPDATE ;
	dct:created LAST_UPDATE ;
	rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
	sioc:link sioc:proxy_iri (LINK) ;
	sioc:has_container sioc:feed_iri (EFI_FEED_ID) ;
	sioc:reply_of sioc:feed_item_iri (EFI_FEED_ID, EFIC_ITEM_ID) ;
	foaf:maker sioc:proxy_iri (EFIC_U_URL)
        .

	sioc:proxy_iri (DB.DBA.ODS_FEED_COMMENTS.EFIC_U_URL) a foaf:Person ;
	foaf:name EFIC_U_NAME;
	foaf:mbox sioc:proxy_iri (EFIC_U_MAIL)
        .

	sioc:feed_iri (DB.DBA.ODS_FEED_COMMENTS.EFI_FEED_ID)
	sioc:container_of
	sioc:feed_comment_iri (U_NAME, WAI_NAME, EFIC_ITEM_ID, EFIC_ID) .

        sioc:feed_item_iri (DB.DBA.ODS_FEED_COMMENTS.EFI_FEED_ID, DB.DBA.ODS_FEED_COMMENTS.EFIC_ITEM_ID)
	sioc:has_reply
	sioc:feed_comment_iri (U_NAME, WAI_NAME, EFIC_ITEM_ID, EFIC_ID) .

	# Feed Post links_to
	sioc:feed_item_iri (DB.DBA.ODS_FEED_LINKS.EFI_FEED_ID, DB.DBA.ODS_FEED_LINKS.EFI_ID)
	sioc:links_to
	sioc:proxy_iri (EFIL_LINK) .

	sioc:feed_item_iri (DB.DBA.ODS_FEED_ATTS.EFI_FEED_ID, DB.DBA.ODS_FEED_ATTS.EFI_ID)
	sioc:attachment
	sioc:proxy_iri (EFIE_URL) .

	sioc:feed_item_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID, DB.DBA.ODS_FEED_POSTS.EFI_ID) a atom:Entry ;
        atom:title EFI_TITLE ;
	atom:source sioc:feed_iri (EFI_FEED_ID) ;
	atom:published PUBLISH_DATE ;
	atom:updated PUBLISH_DATE ;
	atom:content sioc:feed_item_text_iri (EFI_FEED_ID, EFI_ID) .

        sioc:feed_item_text_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID, DB.DBA.ODS_FEED_POSTS.EFI_ID)
	a atom:Content ;
	atom:type "text/xhtml" ;
	atom:lang "en-US" ;
	atom:body EFI_DESCRIPTION .

	sioc:feed_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID)
	atom:contains
	sioc:feed_item_iri (EFI_FEED_ID, EFI_ID) .

      ';
};

grant select on ODS_FEED_FEED_DOMAIN to SPARQL_SELECT;
grant select on ODS_FEED_POSTS to SPARQL_SELECT;
grant select on ODS_FEED_COMMENTS to SPARQL_SELECT;
grant select on ODS_FEED_TAGS to SPARQL_SELECT;
grant select on ODS_FEED_LINKS to SPARQL_SELECT;
grant select on ODS_FEED_ATTS to SPARQL_SELECT;
grant execute on sioc.DBA.feed_comment_iri_1 to SPARQL_SELECT;
grant execute on sioc.DBA.feed_item_url to SPARQL_SELECT;
grant execute on DB.DBA.ODS_FEED_TAGS to SPARQL_SELECT;

-- END FEEDS
ODS_RDF_VIEW_INIT ();
