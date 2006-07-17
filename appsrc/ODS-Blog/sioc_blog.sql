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

create procedure fill_ods_blog_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, cr_iri, blog_iri varchar;
  for select B_BLOG_ID, B_POST_ID, BI_WAI_NAME, B_USER_ID, B_TITLE, B_TS, B_MODIFIED, BI_HOME from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO
    where B_BLOG_ID = BI_BLOG_ID do
    {
      iri := blog_post_iri (B_BLOG_ID, B_POST_ID);
      blog_iri := blog_iri (BI_WAI_NAME);
      cr_iri := user_iri (B_USER_ID);
      ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, B_TITLE, B_TS, B_MODIFIED, BI_HOME ||'?id='||B_POST_ID);
    }
};

create trigger SYS_BLOGS_SIOC_I after insert on BLOG..SYS_BLOGS referencing new as N
{
  declare iri, graph_iri, cr_iri, blog_iri, home varchar;
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
    }
  cr_iri := user_iri (N.B_USER_ID);
  ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, N.B_TITLE, N.B_TS, N.B_MODIFIED, home ||'?id='||N.B_POST_ID);
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

create trigger SYS_BLOGS_SIOC_U after update on BLOG..SYS_BLOGS referencing old as O, new as N
{
  declare iri, graph_iri, cr_iri, blog_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := blog_post_iri (N.B_BLOG_ID, N.B_POST_ID);
  blog_iri := blog_iri ((select BI_WAI_NAME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = N.B_BLOG_ID));
  cr_iri := user_iri (N.B_USER_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, N.B_TITLE, N.B_TS, N.B_MODIFIED);
  return;
};

use DB;
