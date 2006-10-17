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

create procedure blog_post_iri (in blog_id varchar, in post_id varchar)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };
  select U_NAME, BI_WAI_NAME into _member, _inst from DB.DBA.SYS_USERS, BLOG..SYS_BLOG_INFO, BLOG..SYS_BLOGS
      where BI_OWNER = U_ID and BI_BLOG_ID = B_BLOG_ID and B_BLOG_ID = blog_id and B_POST_ID = post_id;
  return sprintf ('http://%s%s/%U/weblog/%U/%U', get_cname(), get_base_path (), _member, _inst, post_id);
};

create procedure blog_comment_iri (in blog_id varchar, in post_id varchar, in cid int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };
  select U_NAME, BI_WAI_NAME into _member, _inst from DB.DBA.SYS_USERS, BLOG..SYS_BLOG_INFO, BLOG..SYS_BLOGS
      where BI_OWNER = U_ID and BI_BLOG_ID = B_BLOG_ID and B_BLOG_ID = blog_id and B_POST_ID = post_id;
  return sprintf ('http://%s%s/%U/weblog/%U/%U/%d', get_cname(), get_base_path (), _member, _inst, post_id, cid);
};

create procedure fill_ods_weblog_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
    {
  declare iri, cr_iri, blog_iri, cm_iri, tiri, maker varchar;
  declare links any;

  for select B_BLOG_ID, B_POST_ID, BI_WAI_NAME, B_USER_ID, B_TITLE, B_TS, B_MODIFIED, BI_HOME, B_CONTENT, B_META, B_HAVE_ENCLOSURE
    from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE
    where B_BLOG_ID = BI_BLOG_ID and BI_WAI_NAME = WAI_NAME
    and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or BI_WAI_NAME = _wai_name) do
    {
      declare meta BLOG.DBA."MWeblogPost";
      declare enc BLOG.DBA."MWeblogEnclosure";
      declare att any;

      enc := null;
      att := null;
      if (B_HAVE_ENCLOSURE = 1)
	{
	  meta := B_META;
	  enc := meta.enclosure;
	  att := vector (enc."url");
        }
      iri := blog_post_iri (B_BLOG_ID, B_POST_ID);
      blog_iri := blog_iri (BI_WAI_NAME);
      cr_iri := user_iri (B_USER_ID);
      links :=
      (select DB.DBA.VECTOR_AGG (vector (PL_TITLE,PL_LINK)) from BLOG..BLOG_POST_LINKS
      	where PL_BLOG_ID = B_BLOG_ID and PL_POST_ID = B_POST_ID);
      ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, B_TITLE, B_TS, B_MODIFIED, BI_HOME ||'?id='||B_POST_ID,
	  B_CONTENT, null, links, null, att);
      for select BM_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_TS, BM_TITLE from BLOG..BLOG_COMMENTS
       where BM_BLOG_ID = B_BLOG_ID and BM_POST_ID = B_POST_ID and BM_IS_PUB = 1 do
       {
	 cm_iri := blog_comment_iri (B_BLOG_ID, B_POST_ID, BM_ID);
	 foaf_maker (graph_iri, BM_HOME_PAGE, BM_NAME, BM_E_MAIL);
	 ods_sioc_post (graph_iri, cm_iri, blog_iri, null, BM_TITLE, BM_TS, BM_TS, BI_HOME ||'?id='||B_POST_ID, BM_COMMENT,
	     null, null, BM_HOME_PAGE);
	 DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_reply'), cm_iri);
	 DB.DBA.RDF_QUAD_URI (graph_iri, cm_iri, sioc_iri ('reply_of'), iri);
       }
      for select BT_TAGS from BLOG..BLOG_TAG where BT_BLOG_ID =  B_BLOG_ID and BT_POST_ID = B_POST_ID do
	{
	  ods_sioc_tags (graph_iri, iri, BT_TAGS);
	}
      --for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT_2 where blogid = B_BLOG_ID and postid = B_POST_ID do
      --	{
      --    tiri := sprintf ('http://%s%s?tag=%s', get_cname(), BI_HOME, BT_TAG);
      --	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('topic'), tiri);
      --	  DB.DBA.RDF_QUAD_URI_L (graph_iri, tiri, rdfs_iri ('label'), BT_TAG);
      --	}
    }
};


create procedure ods_weblog_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');

  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;

  if (registry_get ('__ods_weblog_sioc_init') = sioc_version)
    return;

  fill_ods_weblog_sioc (get_graph (), get_graph ());
  registry_set ('__ods_weblog_sioc_init', sioc_version);
  return;

};

db.dba.wa_exec_no_error('ods_weblog_sioc_init ()');

create trigger SYS_BLOGS_SIOC_I after insert on BLOG..SYS_BLOGS order 10 referencing new as N
{
  declare iri, graph_iri, cr_iri, blog_iri, home, _wai_name varchar;
  declare links any;
  declare meta BLOG.DBA."MWeblogPost";
  declare enc BLOG.DBA."MWeblogEnclosure";
  declare att any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := blog_post_iri (N.B_BLOG_ID, N.B_POST_ID);
  for select BI_WAI_NAME, BI_HOME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = N.B_BLOG_ID do
    {
      blog_iri := blog_iri (BI_WAI_NAME);
      home := BI_HOME;
      _wai_name := BI_WAI_NAME;
    }

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name and WAI_IS_PUBLIC = 1))
    return;

  enc := null;
  att := null;
  meta := N.B_META;
  if (meta is not null and meta.enclosure is not null)
    {
      enc := meta.enclosure;
      att := vector (enc."url");
    }

  cr_iri := user_iri (N.B_USER_ID);
  links :=
      (select DB.DBA.VECTOR_AGG (vector (PL_TITLE,PL_LINK)) from BLOG..BLOG_POST_LINKS
      	where PL_BLOG_ID = N.B_BLOG_ID and PL_POST_ID = N.B_POST_ID);
  ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, N.B_TITLE, N.B_TS, N.B_MODIFIED,
      home ||'?id='||N.B_POST_ID, N.B_CONTENT, null, links, null, att);
  return;
};

create trigger SYS_BLOGS_SIOC_D before delete on BLOG..SYS_BLOGS referencing old as O
{
  declare iri, graph_iri, cr_iri, blog_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := blog_post_iri (O.B_BLOG_ID, O.B_POST_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

create trigger SYS_BLOGS_SIOC_U after update on BLOG..SYS_BLOGS order 10 referencing old as O, new as N
{
  declare iri, graph_iri, cr_iri, blog_iri, _wai_name, home varchar;
  declare links any;
  declare meta BLOG.DBA."MWeblogPost";
  declare enc BLOG.DBA."MWeblogEnclosure";
  declare att any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := blog_post_iri (N.B_BLOG_ID, N.B_POST_ID);

  for select BI_WAI_NAME, BI_HOME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = N.B_BLOG_ID do
    {
      blog_iri := blog_iri (BI_WAI_NAME);
      home := BI_HOME;
      _wai_name := BI_WAI_NAME;
    }

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name and WAI_IS_PUBLIC = 1))
    return;

  enc := null;
  att := null;
  meta := N.B_META;
  if (meta is not null and meta.enclosure is not null)
    {
      enc := meta.enclosure;
      att := vector (enc."url");
    }

  cr_iri := user_iri (N.B_USER_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  links :=
      (select DB.DBA.VECTOR_AGG (vector (PL_TITLE,PL_LINK)) from BLOG..BLOG_POST_LINKS
      	where PL_BLOG_ID = N.B_BLOG_ID and PL_POST_ID = N.B_POST_ID);
  ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, N.B_TITLE, N.B_TS, N.B_MODIFIED, null, N.B_CONTENT, null, links, null, att);
  return;
};

create trigger BLOG_COMMENTS_SIOC_I after insert on BLOG..BLOG_COMMENTS referencing new as N
{
  declare iri, graph_iri, cr_iri, blog_iri, home, post_iri, _wai_name varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  if (N.BM_IS_PUB = 0)
    return;
  graph_iri := get_graph ();
  iri := blog_comment_iri (N.BM_BLOG_ID, N.BM_POST_ID, N.BM_ID);
  for select BI_WAI_NAME, BI_HOME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = N.BM_BLOG_ID do
    {
      blog_iri := blog_iri (BI_WAI_NAME);
      home := BI_HOME;
      _wai_name := BI_WAI_NAME;
    }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name and WAI_IS_PUBLIC = 1))
    return;

  foaf_maker (graph_iri, N.BM_HOME_PAGE, N.BM_NAME, N.BM_E_MAIL);
  ods_sioc_post (graph_iri, iri, blog_iri, null, N.BM_TITLE, N.BM_TS, N.BM_TS, home ||'?id='||N.BM_POST_ID, N.BM_COMMENT,
      null, null, N.BM_HOME_PAGE);
  post_iri := blog_post_iri (N.BM_BLOG_ID, N.BM_POST_ID);
  DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), post_iri);
  return;
};

create trigger BLOG_COMMENTS_SIOC_D after delete on BLOG..BLOG_COMMENTS referencing old as O
{
  declare iri, graph_iri, cr_iri, blog_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := blog_comment_iri (O.BM_BLOG_ID, O.BM_POST_ID, O.BM_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

create trigger BLOG_COMMENTS_SIOC_U after update on BLOG..BLOG_COMMENTS referencing old as O, new as N
{
  declare iri, graph_iri, cr_iri, blog_iri, post_iri, home, _wai_name varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  if (N.BM_IS_PUB = 0 and O.BM_IS_PUB = 0)
    return;
  graph_iri := get_graph ();
  iri := blog_comment_iri (N.BM_BLOG_ID, N.BM_POST_ID, N.BM_ID);

  for select BI_WAI_NAME, BI_HOME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = N.BM_BLOG_ID do
    {
      blog_iri := blog_iri (BI_WAI_NAME);
      home := BI_HOME;
      _wai_name := BI_WAI_NAME;
    }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name and WAI_IS_PUBLIC = 1))
    return;

  delete_quad_s_or_o (graph_iri, iri, iri);
  if (N.BM_IS_PUB = 0)
    return;
  foaf_maker (graph_iri, N.BM_HOME_PAGE, N.BM_NAME, N.BM_E_MAIL);
  ods_sioc_post (graph_iri, iri, blog_iri, null, N.BM_TITLE, N.BM_TS, N.BM_TS, null, N.BM_COMMENT,
      null, null, N.BM_HOME_PAGE);
  post_iri := blog_post_iri (N.BM_BLOG_ID, N.BM_POST_ID);
  DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), post_iri);
  return;
};

create trigger BLOG_TAG_SIOC_I after insert on BLOG..BLOG_TAG referencing new as N
{
  declare iri, graph_iri, post_iri, tarr varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  post_iri := blog_post_iri (N.BT_BLOG_ID, N.BT_POST_ID);
  for select BI_HOME from BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where BI_BLOG_ID = N.BT_BLOG_ID and WAI_NAME = BI_WAI_NAME and WAI_IS_PUBLIC = 1 do
    {
      ods_sioc_tags (graph_iri, post_iri, N.BT_TAGS);
      if (0) -- disabled now
    {
      tarr := split_and_decode (N.BT_TAGS, 0, '\0\0,');
      foreach (any elm in tarr) do
	{
	  elm := trim(elm);
	  elm := replace (elm, ' ', '_');
	  if (length (elm))
	    {
	      iri := sprintf ('http://%s%s?tag=%s', get_cname(), BI_HOME, elm);
	      DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, sioc_iri ('topic'), iri);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), elm);
	    }
	}
    }
    }
};

create trigger BLOG_TAG_SIOC_D after delete on BLOG..BLOG_TAG referencing old as O
{
  declare iri, graph_iri, post_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  post_iri := blog_post_iri (O.BT_BLOG_ID, O.BT_POST_ID);
  ods_sioc_tags_delete (graph_iri, post_iri, O.BT_TAGS);
  --delete_quad_sp (graph_iri, post_iri, sioc_iri ('topic'));
};

use DB;
