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
create procedure feed_mgr_iri (in domain_id int)
{
  declare inst varchar;
  declare exit handler for not found { return null; };
  select WAI_NAME into inst from DB.DBA.WA_INSTANCE where WAI_ID = domain_id;
  return feeds_iri (inst);
}
;

create procedure feed_post_url (in vhost varchar, in lhost varchar, in feed_id varchar, in post any)
{
  return concat('/enews2/news.vspx?link=', post);
}
;

-- this represents post in the given feed
create procedure feeds_post_iri (in feed_id int, in item_id int)
{
  declare feed_title, item_title varchar;
  declare exit handler for not found { return null; };
  return sprintf ('http://%s%s/feed/%d/%d', get_cname(), get_base_path (), feed_id, item_id);
}
;

-- this represents a feed, not an instance
create procedure feed_iri (in feed_id int)
{
  return sprintf ('http://%s%s/feed/%d', get_cname(), get_base_path (), feed_id);
}
;

create procedure fill_ods_feeds_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, m_iri, f_iri varchar;
  for select EFD_ID, EFD_DOMAIN_ID, EFD_FEED_ID, EFD_TITLE, EF_ID, EF_URI, EF_HOME_URI, EF_SOURCE_URI, EF_TITLE, EF_DESCRIPTION
        from ENEWS..FEED_DOMAIN, ENEWS..FEED
       where EFD_FEED_ID = EF_ID do {
      iri := feed_iri (EF_ID);
      m_iri := feed_mgr_iri (EFD_DOMAIN_ID);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_parent', m_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, m_iri, 'http://rdfs.org/sioc/ns#parent_of', iri);
    }
  for select EFI_FEED_ID, EFI_ID, EFI_TITLE, EFI_DESCRIPTION, EFI_LINK, EFI_AUTHOR, EFI_PUBLISH_DATE from ENEWS..FEED_ITEM do {
      iri := feeds_post_iri (EFI_FEED_ID, EFI_ID);
      f_iri := feed_iri (EFI_FEED_ID);
      ods_sioc_post (graph_iri, iri, f_iri, null, EFI_TITLE, EFI_PUBLISH_DATE, null, EFI_LINK);
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
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_parent', m_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, m_iri, 'http://rdfs.org/sioc/ns#parent_of', iri);
  return;
};

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
  delete_quad_s_p_o (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_parent', m_iri);
  delete_quad_s_p_o (graph_iri, m_iri, 'http://rdfs.org/sioc/ns#parent_of', iri);
  return;
};


-- ENEWS..FEED_ITEM
create trigger FEED_ITEM_SIOC_I after insert on ENEWS..FEED_ITEM referencing new as N
{
  declare iri, graph_iri, f_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  f_iri := feed_iri (N.EFI_FEED_ID);
  iri := feeds_post_iri (N.EFI_FEED_ID, N.EFI_ID);
  ods_sioc_post (graph_iri, iri, f_iri, null, N.EFI_TITLE, N.EFI_PUBLISH_DATE, null, N.EFI_LINK);
  return;
}
;

create trigger FEED_ITEM_SIOC_D before delete on ENEWS..FEED_ITEM referencing old as O
{
  declare iri, graph_iri, f_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := feeds_post_iri (O.EFI_FEED_ID, O.EFI_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
}
;

create trigger FEED_ITEM_SIOC_U after update on ENEWS..FEED_ITEM referencing old as O, new as N
{
  declare iri, graph_iri, f_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  f_iri := feed_iri (N.EFI_FEED_ID);
  iri := feeds_post_iri (N.EFI_FEED_ID, N.EFI_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  ods_sioc_post (graph_iri, iri, f_iri, null, N.EFI_TITLE, N.EFI_PUBLISH_DATE, null, N.EFI_LINK);
  return;
}
;

create procedure feeds_post_iri (in feed_id int, in item_id int)
{
  declare feed_title, item_title varchar;
  declare exit handler for not found { return null; };
  return sprintf ('http://%s%s/feed/%d/%d', get_cname(), get_base_path (), feed_id, item_id);
}
;

create procedure feeds_tags_insert (
  in domain_id integer,
  in item_id integer,
  in tags varchar)
{
  declare feed_id integer;
  declare graph_iri, iri, post_iri, tars, home varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  if (isnull(domain_id))
    return;
  home := '/enews2/' || cast(domain_id as varchar);
  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  iri := feed_iri (feed_id);
  post_iri := feeds_post_iri (feed_id, item_id);
  tars := split_and_decode (tags, 0, '\0\0,');
  foreach (any tag in tars) do {
	  tag := replace (trim(tag), ' ', '_');
	  if (length (tag)) {
	    iri := sprintf ('http://%s%s?tag=%s', get_cname(), home, tag);
	    DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, sioc_iri ('topic'), iri);
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), tag);
	  }
  }
}
;

create procedure feeds_tags_delete (
  in domain_id integer,
  in item_id integer)
{

  declare feed_id integer;
  declare graph_iri, post_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};
  if (isnull(domain_id))
    return;
  graph_iri := get_graph ();
  select EFI_FEED_ID into feed_id from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  post_iri := feeds_post_iri (feed_id, item_id);
  delete_quad_sp (graph_iri, post_iri, sioc_iri ('topic'));
}
;

create trigger FEED_ITEM_DATA_SIOC_I after insert on ENEWS.WA.FEED_ITEM_DATA referencing new as N
{
  feeds_tags_insert (N.EFID_DOMAIN_ID, N.EFID_ITEM_ID, N.EFID_TAGS);
}
;

create trigger FEED_ITEM_DATA_SIOC_U after update on ENEWS.WA.FEED_ITEM_DATA referencing old as O, new as N
{
  feeds_tags_delete (O.EFID_DOMAIN_ID, O.EFID_ITEM_ID);
  feeds_tags_insert (N.EFID_DOMAIN_ID, N.EFID_ITEM_ID, N.EFID_TAGS);
}
;

create trigger FEED_ITEM_DATA_SIOC_D after delete on ENEWS.WA.FEED_ITEM_DATA referencing old as O
{
  feeds_tags_delete (O.EFID_DOMAIN_ID, O.EFID_ITEM_ID);
}
;

use DB;
