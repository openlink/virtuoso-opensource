--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
-- this represents item in the given feed, if name changed should change in sioc.sql too
create procedure feed_item_iri2 (
  inout item_id integer)
{
  declare feed_id integer;

  feed_id := (select EFI_FEED_ID from ENEWS.WA.FEED_ITEM where EFI_ID = item_id);
  return feed_item_iri (feed_id, item_id);
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
-- this represents comment in the given feed item
create procedure feed_comment_iri (
  inout domain_id integer,
  inout item_id integer,
  inout comment_id integer)
{
  declare owner, instance varchar;
  declare exit handler for not found { return null; };
  select U_NAME, WAI_NAME into owner, instance from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_USER = U_ID and WAM_MEMBER_TYPE = 1 and WAM_INST = WAI_NAME and WAI_ID = domain_id;
  return sprintf ('http://%s%s/%U/subscriptions/%U/%d/%d', get_cname(), get_base_path (), owner, instance, item_id, comment_id);
}
;

-------------------------------------------------------------------------------
--
create procedure feed_comment_iri2 (
  inout owner varchar,
  inout instance varchar,
  inout domain_id integer,
  inout item_id integer,
  inout comment_id integer)
{
  return sprintf ('http://%s%s/%U/subscriptions/%U/%d/%d', get_cname(), get_base_path (), owner, instance, item_id, comment_id);
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

  return sprintf ('http://%s%s/%U/subscriptions/%U/%d/annotation/%d', get_cname(), get_base_path (), _member, _inst, item_id, annotation_id);
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
  if (xpath_eval ('/item', content) is not null)
  {
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
  if (not isnull(a_name))
  {
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
  if (xpath_eval ('/item', content) is not null)
  {
    -- RSS
    ENEWS.WA.mail_address_split (author, a_name, a_email);
  }
  else if (xpath_eval ('/entry', content) is not null)
  {
    -- Atom
    a_uri := cast(xpath_eval ('/entry/author/uri', content, 1) as varchar);
    a_name := cast(xpath_eval ('/entry/author/name', content, 1) as varchar);
    a_email := cast(xpath_eval ('/entry/author/email', content, 1) as varchar);
  }
  if (isnull(a_uri) and not isnull(a_name))
  {
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
create procedure feeds_tag_iri (
	in user_id integer,
	in tag varchar)
{
	declare user_name varchar;
	declare exit handler for not found { return null; };

	select U_NAME into user_name from DB.DBA.SYS_USERS where U_ID = user_id;
	return sprintf ('http://%s%s/%U/concept#%s', get_cname(), get_base_path (), user_name, ENEWS.WA.tag_id (tag));
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_subscriptions_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  return fill_ods_feeds_sioc (graph_iri, site_iri, _wai_name);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_feeds_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare acl_graph_iri, iri, m_iri, f_iri, t_iri, u_iri, c_iri varchar;
  declare tags, linksTo any;
  declare id, deadl, cnt any;

 {
    -- init service containers
    fill_ods_feeds_services ();

    for (select WAI_ID,
                WAI_IS_PUBLIC,
                WAI_TYPE_NAME,
                WAI_NAME,
                WAI_ACL
           from DB.DBA.WA_INSTANCE
          where ((_wai_name is null) or (WAI_NAME = _wai_name))
            and WAI_TYPE_NAME = 'eNews2') do
    {
      acl_graph_iri := SIOC..acl_graph (WAI_TYPE_NAME, WAI_NAME);
      exec (sprintf ('sparql clear graph <%s>', acl_graph_iri));
      SIOC..wa_instance_acl_insert (WAI_IS_PUBLIC, WAI_TYPE_NAME, WAI_NAME, WAI_ACL);
      for (select EFD_DOMAIN_ID, EFD_FEED_ID, EFD_ACL
             from ENEWS.WA.FEED_DOMAIN
            where EFD_DOMAIN_ID = WAI_ID and EFD_ACL is not null) do
      {
        feedDomain_acl_insert (EFD_DOMAIN_ID, EFD_FEED_ID, EFD_ACL);
      }
    }

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
          from ENEWS.WA.FEED_DOMAIN,
               ENEWS.WA.FEED,
             DB.DBA.WA_INSTANCE
         where EFD_ID > id
         and EFD_FEED_ID = EF_ID
         and EFD_DOMAIN_ID = WAI_ID
           and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
         order by EFD_ID do
  {
      iri := feed_iri (EF_ID);
      m_iri := ENEWS.WA.forum_iri (EFD_DOMAIN_ID);
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Feed'));
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), m_iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, m_iri, sioc_iri ('container_of'), iri);
      if (length (EF_TITLE))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), EF_TITLE);
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
	       order by 2 option (order, loop) do
    {
      f_iri := feed_iri (EFI_FEED_ID);
      iri := feed_item_iri (EFI_FEED_ID, EFI_ID);
      u_iri := feeds_foaf_maker (graph_iri, EFI_FEED_ID, EFI_AUTHOR, EFI_DATA);
    linksTo := feed_links_to (EFI_DESCRIPTION);
      ods_sioc_post (graph_iri, iri, f_iri, null, EFI_TITLE, EFI_PUBLISH_DATE, null, EFI_LINK, EFI_DESCRIPTION, null, linksTo, u_iri);

    -- tags
    for (select EFID_DOMAIN_ID, EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_DOMAIN_ID is not null and EFID_ITEM_ID = EFI_ID) do
	scot_tags_insert (EFID_DOMAIN_ID, iri, EFID_TAGS);

    -- comments
    for (select EFIC_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE, EFIC_COMMENT, EFIC_U_NAME, EFIC_U_MAIL, EFIC_U_URL, EFIC_LAST_UPDATE from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ITEM_ID = EFI_ID and EFIC_PARENT_ID is not null) do
    {
      c_iri := feed_comment_iri (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer), EFIC_ID);
        if (not isnull (c_iri))
        {
      foaf_maker (graph_iri, EFIC_U_URL, EFIC_U_NAME, EFIC_U_MAIL);
        ods_sioc_post (graph_iri, c_iri, f_iri, null, EFIC_TITLE, EFIC_LAST_UPDATE, EFIC_LAST_UPDATE, feed_item_url (EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer)), EFIC_COMMENT, null, null, EFIC_U_URL);
          DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_reply'), c_iri);
          DB.DBA.ODS_QUAD_URI (graph_iri, c_iri, sioc_iri ('reply_of'), iri);
    }
    }
      -- annotations
      for (select A_ID,
                  A_DOMAIN_ID,
                  A_OBJECT_ID,
                  A_AUTHOR,
                  A_BODY,
                  A_CLAIMS,
                  A_CREATED,
                  A_UPDATED
             from ENEWS.WA.ANNOTATIONS
            where A_OBJECT_ID = EFI_ID) do
      {
        feeds_annotation_insert (graph_iri,
                                 ENEWS.WA.forum_iri (A_DOMAIN_ID),
                                 A_ID,
                                 A_DOMAIN_ID,
                                 A_OBJECT_ID,
                                 A_AUTHOR,
                                 A_BODY,
                                 A_CLAIMS,
                                 A_CREATED,
                                 A_UPDATED);
      }
    cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
      {
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
create procedure fill_ods_feeds_services ()
{
  declare graph_iri, services_iri, service_iri, service_url varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('feeds.subscribe', 'feeds.blog.subscribe', 'feeds.options.set',  'feeds.options.get');
  ods_object_services (graph_iri, 'feeds', 'ODS feeds instance services', svc_functions);

  -- feed
  svc_functions := vector ('feeds.get', 'feeds.unsubscribe', 'feeds.refresh');
  ods_object_services (graph_iri, 'feeds/feed', 'ODS Feeds feed services', svc_functions);

  -- blog
  svc_functions := vector ('feeds.blog.unsubscribe', 'feeds.blog.refresh');
  ods_object_services (graph_iri, 'feeds/blog', 'ODS Feeds blog services', svc_functions);

  -- feed item comment
  svc_functions := vector ('feeds.comment.get', 'feeds.comment.delete');
  ods_object_services (graph_iri, 'feeds/item/comment', 'ODS Feeds comment services', svc_functions);

  -- feed item annotation
  svc_functions := vector ('feeds.annotation.get', 'feeds.annotation.claim', 'feeds.annotation.delete');
  ods_object_services (graph_iri, 'feeds/item/annotation', 'ODS Feeds annotation services', svc_functions);
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
  m_iri := ENEWS.WA.forum_iri (N.EFD_DOMAIN_ID);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), m_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, m_iri, sioc_iri ('container_of'), iri);
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
  m_iri := ENEWS.WA.forum_iri (O.EFD_DOMAIN_ID);
  delete_quad_s_p_o (graph_iri, iri, sioc_iri ('has_parent'), m_iri);
  delete_quad_s_p_o (graph_iri, m_iri, sioc_iri ('parent_of'), iri);
  delete_quad_s_p_o (graph_iri, iri, sioc_iri ('has_container'), m_iri);
  delete_quad_s_p_o (graph_iri, m_iri, sioc_iri ('container_of'), iri);
}
;

-------------------------------------------------------------------------------
--
create procedure feedDomain_acl_insert (
  inout domain_id integer,
  inout feed_id integer,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..feed_iri (feed_id);
  graph_iri := ENEWS.WA.acl_graph (domain_id);

  SIOC..acl_insert (graph_iri, iri, acl);
}
;

-------------------------------------------------------------------------------
--
create procedure feedDomain_acl_delete (
  inout domain_id integer,
  inout feed_id integer,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..feed_iri (feed_id);
  graph_iri := ENEWS.WA.acl_graph (domain_id);

  SIOC..acl_delete (graph_iri, iri, acl);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_DOMAIN_SIOC_ACL_I after insert on ENEWS.WA.FEED_DOMAIN order 100 referencing new as N
{
  if (coalesce (N.EFD_ACL, '') <> '')
  {
    feedDomain_acl_insert (N.EFD_DOMAIN_ID,
                           N.EFD_FEED_ID,
                           N.EFD_ACL);

    SIOC..acl_ping (N.EFD_DOMAIN_ID,
                    SIOC..feed_iri (N.EFD_FEED_ID),
                    null,
                    N.EFD_ACL);
  }
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_DOMAIN_SIOC_ACL_U after update (EFD_ACL) on ENEWS.WA.FEED_DOMAIN order 100 referencing old as O, new as N
{
  if (coalesce (O.EFD_ACL, '') <> '')
    feedDomain_acl_delete (O.EFD_DOMAIN_ID,
                           O.EFD_FEED_ID,
                           O.EFD_ACL);

  if (coalesce (N.EFD_ACL, '') <> '')
    feedDomain_acl_insert (N.EFD_DOMAIN_ID,
                           N.EFD_FEED_ID,
                           N.EFD_ACL);

  SIOC..acl_ping (N.EFD_DOMAIN_ID,
                  SIOC..feed_iri (N.EFD_FEED_ID),
                  O.EFD_ACL,
                  N.EFD_ACL);
}
;

-------------------------------------------------------------------------------
--
create trigger FEED_DOMAIN_SIOC_ACL_D before delete on ENEWS.WA.FEED_DOMAIN order 100 referencing old as O
{
  if (coalesce (O.EFD_ACL, '') <> '')
    feedDomain_acl_delete (O.EFD_DOMAIN_ID,
                           O.EFD_FEED_ID,
                           O.EFD_ACL);
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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1))
    return;
  home := '/enews2/' || cast(domain_id as varchar);
  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  iri := feed_iri (feed_id);
  post_iri := feed_item_iri (feed_id, item_id);

  scot_tags_insert (domain_id, post_iri, tags);
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
  scot_tags_delete (domain_id, post_iri, tags);
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

  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  feed_iri := feed_iri (feed_id);
  item_iri := feed_item_iri (feed_id, item_id);
  iri := feed_comment_iri (domain_id, item_id, id);
  if (not isnull (iri))
  {
  foaf_maker (graph_iri, u_url, u_name, u_mail);
    ods_sioc_post (graph_iri, iri, feed_iri, null, title, last_update, last_update, feed_item_url (domain_id, item_id), comment, null, null, u_url);
    -- services
    SIOC..ods_object_services_attach (graph_iri, iri, 'feeds/item/comment');
    DB.DBA.ODS_QUAD_URI (graph_iri, item_iri, sioc_iri ('has_reply'), iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), item_iri);
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
  -- services
  SIOC..ods_object_services_dettach (graph_iri, iri, 'feeds/item/comment');
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
  inout claims any,
  inout created datetime,
  inout updated datetime)
{
  declare master_iri, annotation_iri varchar;

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

  if (isnull (graph_iri))
    return;

    declare feed_id integer;

    feed_id := (select EFI_FEED_ID from ENEWS.WA.FEED_ITEM where EFI_ID = master_id);
    master_iri := feed_item_iri (feed_id, master_id);
  annotation_iri := feed_annotation_iri (domain_id, cast (master_id as integer), annotation_id);

  DB.DBA.ODS_QUAD_URI (graph_iri, annotation_iri, sioc_iri ('has_container'), forum_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), annotation_iri);

  DB.DBA.ODS_QUAD_URI (graph_iri, annotation_iri, an_iri ('annotates'), master_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, master_iri, an_iri ('hasAnnotation'), annotation_iri);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('author'), author);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('body'), body);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('created'), created);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('modified'), updated);

  feeds_claims_insert (graph_iri, annotation_iri, claims);
  SIOC..ods_object_services_attach (graph_iri, annotation_iri, 'feeds/item/annotation');
}
;

-------------------------------------------------------------------------------
--
create procedure feeds_annotation_delete (
  inout annotation_id integer,
  inout domain_id integer,
  inout master_id integer,
  inout claims any)
{
  declare graph_iri, annotation_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  annotation_iri := feed_annotation_iri (domain_id, master_id, annotation_id);
  delete_quad_s_or_o (graph_iri, annotation_iri, annotation_iri);
  SIOC..ods_object_services_dettach (graph_iri, annotation_iri, 'feeds/item/annotation');
}
;

-------------------------------------------------------------------------------
--
create procedure feeds_claims_insert (
  in graph_iri varchar,
  in iri varchar,
  in claims any)
{
  declare N integer;
  declare V, cURI, cPedicate, cValue any;

  V := deserialize (claims);
  for (N := 0; N < length (V); N := N +1)
  {
    cPedicate := V[N][1];
    cValue := V[N][2];
    if (0 = length (cPedicate))
    {
      cPedicate := rdfs_iri ('seeAlso');
    } else {
      cPedicate := ODS.ODS_API."ontology.denormalize" (cPedicate);
    }
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, cPedicate, cValue);
  }
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
                           N.A_AUTHOR,
                           N.A_BODY,
                           N.A_CLAIMS,
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
                           O.A_OBJECT_ID,
                           O.A_CLAIMS);
  feeds_annotation_insert (null,
                           null,
                           N.A_ID,
                           N.A_DOMAIN_ID,
                           N.A_OBJECT_ID,
                           N.A_AUTHOR,
                           N.A_BODY,
                           N.A_CLAIMS,
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
                           O.A_OBJECT_ID,
                           O.A_CLAIMS);
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

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tmp_update ()
{
  if (registry_get ('news_services_update') = '1')
    return;

  SIOC..fill_ods_feeds_services();
  registry_set ('news_services_update', '1');
}
;

ENEWS.WA.tmp_update ();

-------------------------------------------------------------------------------
--
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
	sioc..feed_comment_iri2 (U_NAME, WAI_NAME, EFIC_DOMAIN_ID, cast(EFIC_ITEM_ID as integer), EFIC_ID) || '/sioc.rdf' as SEE_ALSO,
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

create procedure sioc.DBA.rdf_subscriptions_view_str ()
{
  return sioc.DBA.rdf_feeds_view_str ();
}
;

create procedure sioc.DBA.rdf_feeds_view_str ()
{
  return
      '

	# Feeds
        sioc:feed_iri (DB.DBA.ODS_FEED_FEED_DOMAIN.EF_ID) a atom:Feed ;
        sioc:link sioc:proxy_iri (EF_URI) ;
	atom:link sioc:proxy_iri (EF_URI) ;
	atom:title EF_TITLE ;
	  sioc:has_parent sioc:feeds_iri (WAI_NAME) .
	  sioc:feeds_iri (DB.DBA.ODS_FEED_FEED_DOMAIN.WAI_NAME)
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
	  sioc:topic sioc:tag_iri (U_NAME, EFID_TAG) .
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
	  foaf:maker sioc:proxy_iri (EFIC_U_URL).

	sioc:proxy_iri (DB.DBA.ODS_FEED_COMMENTS.EFIC_U_URL) a foaf:Person ;
	foaf:name EFIC_U_NAME;
	  foaf:mbox sioc:proxy_iri (EFIC_U_MAIL).

	sioc:feed_iri (DB.DBA.ODS_FEED_COMMENTS.EFI_FEED_ID)
	sioc:container_of
	sioc:feed_comment_iri (U_NAME, WAI_NAME, EFIC_ITEM_ID, EFIC_ID) .

        sioc:feed_item_iri (DB.DBA.ODS_FEED_COMMENTS.EFI_FEED_ID, DB.DBA.ODS_FEED_COMMENTS.EFIC_ITEM_ID)
	sioc:has_reply
	sioc:feed_comment_iri (U_NAME, WAI_NAME, EFIC_ITEM_ID, EFIC_ID) .

	# Feed Post links_to
	sioc:feed_item_iri (DB.DBA.ODS_FEED_LINKS.EFI_FEED_ID, DB.DBA.ODS_FEED_LINKS.EFI_ID)
	  sioc:links_to sioc:proxy_iri (EFIL_LINK) .

	sioc:feed_item_iri (DB.DBA.ODS_FEED_ATTS.EFI_FEED_ID, DB.DBA.ODS_FEED_ATTS.EFI_ID)
	  sioc:attachment sioc:proxy_iri (EFIE_URL) .

	sioc:feed_item_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID, DB.DBA.ODS_FEED_POSTS.EFI_ID) a atom:Entry ;
        atom:title EFI_TITLE ;
	atom:source sioc:feed_iri (EFI_FEED_ID) ;
	atom:published PUBLISH_DATE ;
	atom:updated PUBLISH_DATE ;
	atom:content sioc:feed_item_text_iri (EFI_FEED_ID, EFI_ID) .

  sioc:feed_item_text_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID, DB.DBA.ODS_FEED_POSTS.EFI_ID) a atom:Content ;
	atom:type "text/xhtml" ;
	atom:lang "en-US" ;
	atom:body EFI_DESCRIPTION .

	sioc:feed_iri (DB.DBA.ODS_FEED_POSTS.EFI_FEED_ID)
	  atom:contains sioc:feed_item_iri (EFI_FEED_ID, EFI_ID) .
  '
  ;
};

create procedure sioc.DBA.rdf_subscriptions_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_FEED_FEED_DOMAIN as feed_domain
      where (^{feed_domain.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_FEED_POSTS as feed_posts
      where (^{feed_posts.}^.EFI_FEED_ID = ^{feed_domain.}^.EF_ID)
      from DB.DBA.ODS_FEED_COMMENTS as feed_comments
      where (^{feed_comments.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_FEED_TAGS as feed_tags
      where (^{feed_tags.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_FEED_LINKS as feed_links
      where (^{feed_links.}^.EFI_FEED_ID = ^{feed_domain.}^.EF_ID)
      from DB.DBA.ODS_FEED_ATTS as feed_atts
      where (^{feed_atts.}^.EFI_FEED_ID = ^{feed_domain.}^.EF_ID)

      '
      ;
};

create procedure sioc.DBA.rdf_subscriptions_view_str_maps ()
{
  return
      '
      # Feeds
	    ods:feed (feed_domain.EF_ID)
	      a atom:Feed ;
            rdfs:label feed_domain.EF_TITLE ;
  	    sioc:link ods:proxy (feed_domain.EF_URI) ;
  	    atom:link ods:proxy (feed_domain.EF_URI) ;
  	    atom:title feed_domain.EF_TITLE ;
  	    sioc:has_parent ods:feed_mgr (feed_domain.U_NAME, feed_domain.WAI_NAME) .

	    ods:feed_mgr (feed_domain.U_NAME, feed_domain.WAI_NAME)
	      sioc:parent_of ods:feed (feed_domain.EF_ID) .

	    ods:feed_item (feed_tags.EFI_FEED_ID, feed_tags.EFID_ITEM_ID)
	      sioc:topic ods:tag (feed_tags.U_NAME, feed_tags.EFID_TAG) .

	    ods:tag (feed_tags.U_NAME, feed_tags.EFID_TAG)
	      a skos:Concept ;
  	    skos:prefLabel feed_tags.EFID_TAG ;
  	    skos:isSubjectOf ods:feed_item (feed_tags.EFI_FEED_ID, feed_tags.EFID_ITEM_ID) .

	    ods:feed_comment (feed_comments.U_NAME, feed_comments.WAI_NAME, feed_comments.EFIC_ITEM_ID, feed_comments.EFIC_ID)
  	    a sioct:Comment ;
  	    dc:title feed_comments.EFIC_TITLE ;
  	    sioc:content feed_comments.EFIC_COMMENT ;
  	    dct:modified feed_comments.LAST_UPDATE ;
  	    dct:created feed_comments.LAST_UPDATE ;
  	    sioc:link ods:proxy (feed_comments.LINK) ;
  	    sioc:has_container ods:feed (feed_comments.EFI_FEED_ID) ;
  	    sioc:reply_of ods:feed_item (feed_comments.EFI_FEED_ID, feed_comments.EFIC_ITEM_ID) ;
  	    foaf:maker ods:proxy (feed_comments.EFIC_U_URL) .

	    ods:proxy (feed_comments.EFIC_U_URL)
	      a foaf:Person ;
	      foaf:name feed_comments.EFIC_U_NAME;
	      foaf:mbox ods:mbox (feed_comments.EFIC_U_MAIL) .

      ods:feed (feed_comments.EFI_FEED_ID)
	      sioc:container_of ods:feed_comment (feed_comments.U_NAME, feed_comments.WAI_NAME, feed_comments.EFIC_ITEM_ID, feed_comments.EFIC_ID) .

      ods:feed_item (feed_comments.EFI_FEED_ID, feed_comments.EFIC_ITEM_ID)
	      sioc:has_reply ods:feed_comment (feed_comments.U_NAME, feed_comments.WAI_NAME, feed_comments.EFIC_ITEM_ID, feed_comments.EFIC_ID) .

      ods:feed_item (feed_links.EFI_FEED_ID, feed_links.EFI_ID)
	      sioc:links_to ods:proxy (feed_links.EFIL_LINK) .

	    ods:feed_item (feed_atts.EFI_FEED_ID, feed_atts.EFI_ID)
	      sioc:attachment ods:proxy (feed_atts.EFIE_URL) .

	    ods:feed_item (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) a atom:Entry ;
  	    sioc:has_container ods:feed (feed_posts.EFI_FEED_ID) ;
  	    dc:title feed_posts.EFI_TITLE ;
  	    dct:created feed_posts.PUBLISH_DATE ;
  	    dct:modified feed_posts.PUBLISH_DATE ;
  	    sioc:link ods:proxy (feed_posts.EFI_LINK) ;
  	    sioc:content feed_posts.EFI_DESCRIPTION ;
  	    atom:title feed_posts.EFI_TITLE ;
  	    atom:source ods:feed (feed_posts.EFI_FEED_ID) ;
  	    atom:published feed_posts.PUBLISH_DATE ;
  	    atom:updated feed_posts.PUBLISH_DATE ;
  	    atom:content ods:feed_item_text (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) .

	    ods:feed (feed_posts.EFI_FEED_ID) sioc:container_of ods:feed_item (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) .

	    ods:feed_item_text (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) a atom:Content ;
              rdfs:label feed_posts.EFI_TITLE ;
	      atom:type "text/xhtml" ;
	      atom:lang "en-US" ;
	      atom:body feed_posts.EFI_DESCRIPTION .

	    ods:feed (feed_posts.EFI_FEED_ID)
	      atom:contains ods:feed_item (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) .
      # end Feeds
      '
      ;
};

grant select on ODS_FEED_FEED_DOMAIN to SPARQL_SELECT;
grant select on ODS_FEED_POSTS to SPARQL_SELECT;
grant select on ODS_FEED_COMMENTS to SPARQL_SELECT;
grant select on ODS_FEED_TAGS to SPARQL_SELECT;
grant select on ODS_FEED_LINKS to SPARQL_SELECT;
grant select on ODS_FEED_ATTS to SPARQL_SELECT;
grant execute on sioc.DBA.feed_comment_iri2 to SPARQL_SELECT;
grant execute on sioc.DBA.feed_item_url to SPARQL_SELECT;
grant execute on DB.DBA.ODS_FEED_TAGS to SPARQL_SELECT;
grant execute on ENEWS.WA.make_post_rfc_msg to SPARQL_SELECT;

-- END FEEDS
ODS_RDF_VIEW_INIT ();
