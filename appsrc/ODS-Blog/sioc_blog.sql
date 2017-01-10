--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

create procedure ods_weblog_scot_init (in inst_id int)
{
  declare iri any;
  for select BT_BLOG_ID, BT_POST_ID, BT_TAGS from BLOG.DBA.BLOG_TAG, BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE
    where BT_BLOG_ID = BI_BLOG_ID and BI_WAI_NAME = WAI_NAME and WAI_ID = inst_id do
    {
      iri := blog_post_iri (BT_BLOG_ID, BT_POST_ID);
      scot_tags_insert (inst_id, iri, BT_TAGS);
    }
}
;

create procedure fill_ods_weblog_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
    {
  declare iri, cr_iri, blog_iri, cm_iri, tiri, maker varchar;
  declare links any;

 {
    fill_ods_weblog_services ();

    declare deadl, cnt any;
    declare _pid any;

    _pid := '';
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

  for select B_BLOG_ID, B_POST_ID, BI_WAI_NAME, B_USER_ID, B_TITLE, B_TS, B_MODIFIED, BI_HOME,
    B_CONTENT, B_META, B_HAVE_ENCLOSURE, WAI_ID
    from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE
    where B_POST_ID > _pid and B_BLOG_ID = BI_BLOG_ID and BI_WAI_NAME = WAI_NAME
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
	 links :=
	 (select DB.DBA.VECTOR_AGG (vector (CL_TITLE,CL_LINK)) from BLOG..BLOG_COMMENT_LINKS
	  where CL_BLOG_ID = B_BLOG_ID and CL_POST_ID = B_POST_ID and CL_CID = BM_ID);

	 ods_sioc_post (graph_iri, cm_iri, blog_iri, null, BM_TITLE, BM_TS, BM_TS, BI_HOME ||'?id='||B_POST_ID, BM_COMMENT,
	     null, links, BM_HOME_PAGE);
	 DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_reply'), cm_iri);
	 DB.DBA.ODS_QUAD_URI (graph_iri, cm_iri, sioc_iri ('reply_of'), iri);
       }
      for select BT_TAGS from BLOG..BLOG_TAG where BT_BLOG_ID =  B_BLOG_ID and BT_POST_ID = B_POST_ID do
	{
	  scot_tags_insert (WAI_ID, iri, BT_TAGS);
	}
    cnt := cnt + 1;
    if (mod (cnt, 500) = 0)
      {
	commit work;
	_pid := B_POST_ID;
      }
    }
   commit work;
  }
 {
    declare deadl, cnt any;
    declare _bid any;

    _bid := '';
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

  for select BI_WAI_NAME, BI_BLOG_ID from BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where BI_WAI_NAME = WAI_NAME and ((WAI_IS_PUBLIC = 1 and _wai_name is null) or BI_WAI_NAME = _wai_name) and BI_BLOG_ID > _bid do
    {
      blog_iri := blog_iri (BI_WAI_NAME);
      iri := sprintf ('http://%s/RPC2', get_cname());
      ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'XML-RPC');
      iri := sprintf ('http://%s/mt-tb', get_cname());
      ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'XML-RPC');
      iri := sprintf ('http://%s/Atom/%s', get_cname(), BI_BLOG_ID);
      ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'Atom');
      iri := sprintf ('http://%s/GData/%s', get_cname(), BI_BLOG_ID);
      ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'GData');
      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
        {
	  commit work;
	  _bid := BI_BLOG_ID;
        }
    }
  commit work;
    }
};

create procedure fill_ods_weblog_services ()
{
  declare graph_iri, services_iri, service_iri, service_url varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('weblog.get', 'weblog.post.new', 'weblog.upstreaming.set', 'weblog.upstreaming.get', 'weblog.upstreaming.remove', 'weblog.options.set',  'weblog.options.get');
  ods_object_services (graph_iri, 'weblog', 'ODS weblog instance services', svc_functions);

  -- item
  svc_functions := vector ('weblog.post.get', 'weblog.post.edit', 'weblog.post.delete', 'weblog.comment.new');
  ods_object_services (graph_iri, 'weblog/contact', 'ODS weblog contact services', svc_functions);

  -- item comment
  svc_functions := vector ('weblog.comment.get', 'weblog.comment.approve', 'weblog.comment.delete');
  ods_object_services (graph_iri, 'weblog/contact/comment', 'ODS weblog comment services', svc_functions);
}
;

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

--db.dba.wa_exec_no_error('ods_weblog_sioc_init ()');


create trigger SYS_BLOG_INFO_SIOC_I after insert on BLOG..SYS_BLOG_INFO order 10 referencing new as N
{
  declare iri, blog_iri, graph_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  blog_iri := blog_iri (N.BI_WAI_NAME);
  iri := sprintf ('http://%s/RPC2', get_cname());
  ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'XML-RPC');
  iri := sprintf ('http://%s/mt-tb', get_cname());
  ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'XML-RPC');
  iri := sprintf ('http://%s/Atom/%s', get_cname(), N.BI_BLOG_ID);
  ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'Atom');
  iri := sprintf ('http://%s/GData/%s', get_cname(), N.BI_BLOG_ID);
  ods_sioc_service (graph_iri, iri, blog_iri, null, null, null, iri, 'GData');
  return;
};

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
  -- services
  SIOC..ods_object_services_attach (graph_iri, iri, 'weblog/item');
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
  -- services
  SIOC..ods_object_services_dettach (graph_iri, iri, 'weblog/item');
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
  if (not is_http_ctx ()) -- otherwise done in SYS_SYS_BLOGS_UP_SYS_BLOG_ATTACHES trigger
  delete_quad_s_or_o (graph_iri, iri, iri);
  links :=
      (select DB.DBA.VECTOR_AGG (vector (PL_TITLE,PL_LINK)) from BLOG..BLOG_POST_LINKS
      	where PL_BLOG_ID = N.B_BLOG_ID and PL_POST_ID = N.B_POST_ID);
  ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, N.B_TITLE, N.B_TS, N.B_MODIFIED, null, N.B_CONTENT, null, links, null, att);
  -- services
  SIOC..ods_object_services_attach (graph_iri, iri, 'weblog/item');
};

create trigger BLOG_COMMENTS_SIOC_I after insert on BLOG..BLOG_COMMENTS referencing new as N
{
  declare iri, graph_iri, cr_iri, blog_iri, home, post_iri, _wai_name, links varchar;
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
  links :=
	 (select DB.DBA.VECTOR_AGG (vector (CL_TITLE,CL_LINK)) from BLOG..BLOG_COMMENT_LINKS
	  where CL_BLOG_ID = N.BM_BLOG_ID and CL_POST_ID = N.BM_POST_ID and CL_CID = N.BM_ID);
  ods_sioc_post (graph_iri, iri, blog_iri, null, N.BM_TITLE, N.BM_TS, N.BM_TS, home ||'?id='||N.BM_POST_ID, N.BM_COMMENT,
      null, links, N.BM_HOME_PAGE);
  post_iri := blog_post_iri (N.BM_BLOG_ID, N.BM_POST_ID);
  DB.DBA.ODS_QUAD_URI (graph_iri, post_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), post_iri);
  -- services
  SIOC..ods_object_services_attach (graph_iri, iri, 'weblog/item/comment');
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
  -- services
  SIOC..ods_object_services_dettach (graph_iri, iri, 'weblog/item/comment');
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
  DB.DBA.ODS_QUAD_URI (graph_iri, post_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), post_iri);
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
  for select BI_HOME, WAI_ID from BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where
    BI_BLOG_ID = N.BT_BLOG_ID and WAI_NAME = BI_WAI_NAME and WAI_IS_PUBLIC = 1 do
	{
      scot_tags_insert (WAI_ID, post_iri, N.BT_TAGS);
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
  for select WAI_ID from BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where
    BI_BLOG_ID = O.BT_BLOG_ID and WAI_NAME = BI_WAI_NAME and WAI_IS_PUBLIC = 1 do
    {
      scot_tags_delete (WAI_ID, post_iri, O.BT_TAGS);
    }
};

-------------------------------------------------------------------------------
--
create procedure BLOG.DBA.tmp_update ()
{
  if (registry_get ('weblog_services_update') = '1')
    return;

  SIOC..fill_ods_weblog_services();
  registry_set ('weblog_services_update', '1');
}
;

BLOG.DBA.tmp_update ();

use DB;
-- BLOG

-- BLOG posts & related

wa_exec_no_error ('drop view ODS_BLOG_POSTS');
wa_exec_no_error ('drop view ODS_BLOG_POST_LINKS');
wa_exec_no_error ('drop view ODS_BLOG_POST_ATTS');
wa_exec_no_error ('drop view ODS_BLOG_POST_TAGS');
wa_exec_no_error ('drop view ODS_BLOG_COMMENTS');

create view ODS_BLOG_POSTS as select
	uo.U_NAME 	as B_OWNER,
	i.BI_WAI_NAME	as B_INST,
	p.B_POST_ID	as B_POST_ID,
	p.B_TITLE	as B_TITLE,
	p.B_CONTENT	as B_CONTENT,
	sioc..sioc_date (p.B_TS) as B_CREATED,
	sioc..sioc_date (p.B_MODIFIED) as B_MODIFIED,
	DB.DBA.WA_LINK (1, BI_HOME ||'?id='||B_POST_ID) as B_LINK,
	uc.U_NAME	as B_CREATOR,
        sioc..post_iri (uo.U_NAME, 'WEBLOG2', i.BI_WAI_NAME, p.B_POST_ID) || '/sioc.rdf' as B_SEE_ALSO,
        md5 (sioc..post_iri (uo.U_NAME, 'WEBLOG2', i.BI_WAI_NAME, p.B_POST_ID)) as IRI_MD5
	from BLOG.DBA.SYS_BLOG_INFO i, BLOG.DBA.SYS_BLOGS p, DB.DBA.SYS_USERS uo, DB.DBA.SYS_USERS uc
	where p.B_BLOG_ID = i.BI_BLOG_ID and i.BI_OWNER = uo.U_ID and p.B_USER_ID = uc.U_ID;

create view ODS_BLOG_POST_LINKS as select
	U_NAME      	as B_OWNER,
	BI_WAI_NAME 	as B_INST,
	PL_POST_ID 	as B_POST_ID,
	PL_LINK		as PL_LINK
	from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.SYS_USERS, BLOG.DBA.BLOG_POST_LINKS
	where PL_BLOG_ID = BI_BLOG_ID and BI_OWNER = U_ID;

create view ODS_BLOG_POST_ATTS as select
	U_NAME      	as B_OWNER,
	BI_WAI_NAME 	as B_INST,
	PE_POST_ID 	as B_POST_ID,
	PE_URL		as PE_LINK
	from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.SYS_USERS, BLOG.DBA.BLOG_POST_ENCLOSURES
	where PE_BLOG_ID = BI_BLOG_ID and BI_OWNER = U_ID;

create view ODS_BLOG_POST_TAGS as select
	BT_TAG,
	BT_POST_ID,
	BI_WAI_NAME,
	U_NAME
	from
	BLOG..BLOG_TAGS_STAT,
	BLOG..SYS_BLOG_INFO,
	DB.DBA.SYS_USERS
	where blogid = BI_BLOG_ID and BI_OWNER = U_ID;

create view ODS_BLOG_COMMENTS as select
	U_NAME,
	BI_WAI_NAME,
	BM_POST_ID,
	BM_ID,
	BM_COMMENT,
	BM_NAME,
	case when length (BM_E_MAIL) then 'mailto:'||BM_E_MAIL else null end as E_MAIL,
	case when length (BM_E_MAIL) then sha1_digest (BM_E_MAIL) else null end as E_MAIL_SHA1,
	case when length (BM_HOME_PAGE) then BM_HOME_PAGE else NULL end as BM_HOME_PAGE,
	sioc..sioc_date (BM_TS) as BM_CREATED,
	BM_TITLE,
        sioc..post_iri (U_NAME, 'WEBLOG2', BI_WAI_NAME, sprintf ('%s/%d', BM_POST_ID, BM_ID)) || '/sioc.rdf' as SEE_ALSO,
        md5 (sioc..post_iri (U_NAME, 'WEBLOG2', BI_WAI_NAME, sprintf ('%s/%d', BM_POST_ID, BM_ID))) as IRI_MD5
	from BLOG..BLOG_COMMENTS, BLOG..SYS_BLOG_INFO, DB.DBA.SYS_USERS
	where BI_BLOG_ID = BM_BLOG_ID and BM_IS_PUB = 1 and BI_OWNER = U_ID;



create procedure sioc.DBA.rdf_weblog_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_BLOG_POSTS as blog_posts
      where (^{blog_posts.}^.B_OWNER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_POST_LINKS as blog_links
      where (^{blog_links.}^.B_OWNER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_POST_ATTS as blog_atts
      where (^{blog_atts.}^.B_OWNER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_POST_TAGS as blog_tags
      where (^{blog_tags.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_COMMENTS as blog_comms
      where (^{blog_comms.}^.U_NAME = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_weblog_view_str_maps ()
{
  return
      '
      # Weblog
	    ods:blog_post (blog_posts.B_OWNER, blog_posts.B_INST, blog_posts.B_POST_ID) a sioct:BlogPost ;
	    sioc:link ods:proxy (blog_posts.B_LINK) ;
	    sioc:has_creator ods:user (blog_posts.B_CREATOR) ;
	    foaf:maker ods:person (blog_posts.B_CREATOR) ;
	    sioc:has_container ods:blog_forum (blog_posts.B_OWNER, blog_posts.B_INST) ;
	    dc:title blog_posts.B_TITLE ;
	    dct:created blog_posts.B_CREATED ;
	    dct:modified blog_posts.B_MODIFIED ;
	    sioc:content blog_posts.B_CONTENT .

	    ods:blog_forum (blog_posts.B_OWNER, blog_posts.B_INST)
	    sioc:container_of
	    ods:blog_post (blog_posts.B_OWNER, blog_posts.B_INST, blog_posts.B_POST_ID) .

	    ods:user (blog_posts.B_CREATOR)
	    sioc:creator_of
	    ods:blog_post (blog_posts.B_OWNER, blog_posts.B_INST, blog_posts.B_POST_ID) .

	    ods:blog_post (blog_links.B_OWNER, blog_links.B_INST, blog_links.B_POST_ID)
	    sioc:links_to
	    ods:proxy (blog_links.PL_LINK) .
	    # end Weblog
      '
      ;
};

create procedure sioc.DBA.rdf_weblog_view_str ()
{
  return
      '

	# Blog Posts
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER,
			    DB.DBA.ODS_BLOG_POSTS.B_INST,
			    DB.DBA.ODS_BLOG_POSTS.B_POST_ID) a sioct:BlogPost ;
        rdfs:seeAlso  sioc:proxy_iri (B_SEE_ALSO) ;
	sioc:id IRI_MD5 ;
	sioc:link sioc:proxy_iri (B_LINK) ;
	sioc:has_creator sioc:user_iri (B_CREATOR) ;
	foaf:maker foaf:person_iri (B_CREATOR) ;
        sioc:has_container sioc:blog_forum_iri (B_OWNER, B_INST) ;
        dc:title B_TITLE ;
        dct:created B_CREATED ;
 	dct:modified B_MODIFIED ;
	sioc:content B_CONTENT
	.

	sioc:user_iri (DB.DBA.ODS_BLOG_POSTS.B_CREATOR)
	sioc:creator_of
	sioc:blog_post_iri (B_OWNER, B_INST, B_POST_ID) .

	sioc:blog_forum_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER, DB.DBA.ODS_BLOG_POSTS.B_INST)
	sioc:container_of
	sioc:blog_post_iri (B_OWNER, B_INST, B_POST_ID) .

	# Blog Post links_to
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POST_LINKS.B_OWNER,
	    		    DB.DBA.ODS_BLOG_POST_LINKS.B_INST,
			    DB.DBA.ODS_BLOG_POST_LINKS.B_POST_ID)
	sioc:links_to
	sioc:proxy_iri (PL_LINK) .

	# Blog Post enclosures
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POST_ATTS.B_OWNER,
	    		    DB.DBA.ODS_BLOG_POST_ATTS.B_INST,
			    DB.DBA.ODS_BLOG_POST_ATTS.B_POST_ID)
	sioc:attachment
	sioc:proxy_iri (PE_LINK) .

        # Blog Post tags
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POST_TAGS.U_NAME,
	    		    DB.DBA.ODS_BLOG_POST_TAGS.BI_WAI_NAME,
			    DB.DBA.ODS_BLOG_POST_TAGS.BT_POST_ID)
	sioc:topic
	sioc:tag_iri (U_NAME, BT_TAG) .

        sioc:tag_iri (DB.DBA.ODS_BLOG_POST_TAGS.U_NAME, DB.DBA.ODS_BLOG_POST_TAGS.BT_TAG) a skos:Concept ;
	skos:prefLabel BT_TAG ;
	skos:isSubjectOf sioc:blog_post_iri (U_NAME,BI_WAI_NAME,BT_POST_ID) .

	# Blog Comments
        sioc:blog_comment_iri (DB.DBA.ODS_BLOG_COMMENTS.U_NAME,
			       DB.DBA.ODS_BLOG_COMMENTS.BI_WAI_NAME,
		   	       DB.DBA.ODS_BLOG_COMMENTS.BM_POST_ID,
			       DB.DBA.ODS_BLOG_COMMENTS.BM_ID) a sioct:Comment ;
        sioc:id IRI_MD5 ;
        rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
	foaf:maker sioc:proxy_iri (BM_HOME_PAGE) ;
	sioc:has_container sioc:blog_forum_iri (U_NAME, BI_WAI_NAME) ;
	dc:title BM_TITLE ;
	dct:created BM_CREATED ;
 	dct:modified BM_CREATED ;
	sioc:content BM_COMMENT ;
        sioc:reply_of sioc:blog_post_iri (U_NAME, BI_WAI_NAME, BM_POST_ID)
        .

        sioc:blog_post_iri (DB.DBA.ODS_BLOG_COMMENTS.U_NAME,
			    DB.DBA.ODS_BLOG_COMMENTS.BI_WAI_NAME,
		   	       DB.DBA.ODS_BLOG_COMMENTS.BM_POST_ID)
	sioc:has_reply
	sioc:blog_comment_iri (U_NAME, BI_WAI_NAME, BM_POST_ID, BM_ID)
	.

	sioc:blog_forum_iri (DB.DBA.ODS_BLOG_COMMENTS.U_NAME, DB.DBA.ODS_BLOG_COMMENTS.BI_WAI_NAME)
	sioc:container_of
	sioc:blog_comment_iri (U_NAME, BI_WAI_NAME, BM_POST_ID, BM_ID)
	.

	sioc:proxy_iri (DB.DBA.ODS_BLOG_COMMENTS.BM_HOME_PAGE) a foaf:Person ;
        foaf:name BM_NAME ;
	foaf:mbox sioc:proxy_iri (E_MAIL) ;
	foaf:mbox_sha1sum E_MAIL_SHA1
        .

	# AtomOWL post
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER,
			    DB.DBA.ODS_BLOG_POSTS.B_INST,
			    DB.DBA.ODS_BLOG_POSTS.B_POST_ID) a atom:Entry ;
        atom:title B_TITLE ;
	atom:source sioc:blog_forum_iri (B_OWNER, B_INST) ;
	atom:author atom:person_iri (B_CREATOR) ;
	atom:published B_CREATED ;
	atom:updated B_MODIFIED ;
	atom:content sioc:blog_post_text_iri (B_OWNER, B_INST, B_POST_ID) .

        sioc:blog_post_text_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER, DB.DBA.ODS_BLOG_POSTS.B_INST, DB.DBA.ODS_BLOG_POSTS.B_POST_ID)
	a atom:Content ;
	atom:type "text/xhtml" ;
	atom:lang "en-US" ;
	atom:body B_CONTENT .

	sioc:blog_forum_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER, DB.DBA.ODS_BLOG_POSTS.B_INST)
	atom:contains
	sioc:blog_post_iri (B_OWNER, B_INST, B_POST_ID) .


      ';
};

grant select on ODS_BLOG_POSTS to SPARQL_SELECT;
grant select on ODS_BLOG_POST_LINKS to SPARQL_SELECT;
grant select on ODS_BLOG_POST_ATTS to SPARQL_SELECT;
grant select on ODS_BLOG_POST_TAGS to SPARQL_SELECT;
grant select on ODS_BLOG_COMMENTS to SPARQL_SELECT;
grant execute on BLOG.DBA.BLOG_TAGS_STAT to SPARQL_SELECT;
grant select on BLOG.DBA.BLOG_TAGS_STAT to SPARQL_SELECT;
grant execute on BLOG..MAKE_POST_RFC_MSG to SPARQL_SELECT;

-- END BLOG
ODS_RDF_VIEW_INIT ();
