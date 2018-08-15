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

use DB;

create procedure ensure_page_class (inout path any, inout params any, inout lines any, in comp_only int)
{
  declare cls vspx_page;
  cls := db.dba.vspx_dispatch (registry_get ('_blog2_path_')
  	|| 'templates/main.vspx', path, params, lines, 'blog_main', comp_only);
  commit work;
  return cls;
}
;

BLOG.DBA.blog2_exec_no_error('drop type DB.DBA.blog_main');

use BLOG;

create procedure template_exec (in full_path varchar, inout path any, inout params any, inout lines any)
{
  -- put template in params
  declare dummy, force any;
  declare cls db.dba.vspx_page;

  set http_charset='UTF-8';

  --dbg_printf ('start template_exec [%s]', full_path);

  -- uncomment this line to compile class per page
  --vspx_dispatch (full_path, path, params, lines);
  --return;

  dummy := null;
  force := 0;
  if (not udt_is_available ('DB.DBA.blog_main'))
    {
      --dbg_printf ('compiling the base class');
      db.dba.ensure_page_class (dummy, dummy, dummy, 1);
      --dbg_printf ('done  compiling the base class');
      force := 1;
    }

  ensure_widgets (full_path, force);
  cls := db.dba.ensure_page_class (path, vector_concat (params, vector ('template-name', full_path)), lines, 0);
  --dbg_printf ('done template_exec');
}
;

create procedure template_header_render (inout cls db.dba.vspx_page)
{
  declare xt, rc any;
  xt := udt_get (cls, 'template_xml');
  rc := xslt (BLOG2_GET_PPATH_URL ('widgets/render.xsl'), xt, vector ('class', cls, 'what', 'header', 'ctr', null));
  --dbg_obj_print ('header: outstanding', rc);
  return;
}
;

create procedure template_body_render (inout cls db.dba.vspx_page)
{
  declare xt, rc any;
  xt := udt_get (cls, 'template_xml');
  rc := xslt (BLOG2_GET_PPATH_URL ('widgets/render.xsl'), xt, vector ('class', cls, 'what', 'body', 'ctr', null));
  --dbg_obj_print ('body: outstanding', rc);
  return;
}
;

create procedure template_post_render (inout cls db.dba.vspx_page, inout control db.dba.vspx_row_template,
    				       in t_post_id varchar, in  t_comm int, in t_tb int)
{
  declare xt, rc any;
  xt := udt_get (cls, 'post_template_xml');
  --http (sprintf ('template_post_render %s', t_post_id));
  rc := xslt (BLOG2_GET_PPATH_URL ('widgets/render.xsl'), xt,
  vector ('class', cls, 'what', 'posts', 'ctr', control, 'post', t_post_id, 'comm', t_comm, 'tb', t_tb));
  --dbg_obj_print ('post: outstanding', rc);
  return;
};

create procedure BLOG.DBA.ITEM_RENDER (in widget varchar, inout cls any, inout data any,
    				       inout ctr any, inout post any, inout comm any, inout tb any)
 returns int
{
  declare page_class db.dba.vspx_page;
  declare ret, p_name, data_arr any;

  ret := 0;
  data_arr := make_data_arr_from_xml (data);
  --dbg_obj_print (widget, data_arr);

  if (cls is null)
    signal ('42000', 'General fault');

  page_class := cls;
  udt_set (page_class, 'user_data', data_arr);
  p_name := 'db.dba.blog_wt_render_'||widget;
  --dbg_obj_print ('widget', widget);
  if (__proc_exists (p_name))
    {
      --dbg_obj_print ('rendering widget:' , p_name);
      if (not isstring (ctr) and ctr is not null)
        ret := call (p_name) (page_class, ctr, post, comm, tb);
      else
        ret := call (p_name) (page_class);
    }
  else
    {
      --dbg_obj_print ('failed rendering vsp:' , p_name);
      if (not isstring (ctr) and ctr is not null)
        http (concat ('Unknown post widget: ', widget));
      else
        http (concat ('Unknown widget: ', widget));
    }
  --if (ret)
  --  dbg_printf ('%s returning: %d', widget, ret);
  return ret;
}
;

create procedure BLOG.DBA.STATIC_ITEM_RENDER (inout x any, inout cnt any, in f int, in not_single int)
{
  declare tag any;
  if (f = 1)
    {
      http (sprintf ('<%s', x));
    }
  else if (f = 2)
    {
      http (' ');
      http (x);
      http ('="');
      http (cnt);
      http ('"');
    }
  else if (f = 3)
    {
      http (serialize_to_UTF8_xml (x));
    }
  else
    {
      if (not_single)
        http (sprintf ('</%s>', x));
      else
	http (' />');
    }
}
;

create procedure BLOG_CHECK_CONDITION (in cond varchar, inout cls any, inout ctr any) returns integer
{
  declare val, opts any;
  declare blog_id varchar;

  --dbg_obj_print ('condition: ', cond);
  /*
     "login"
     "subscribe"
     "have_community"
     "browse_posts"
     "fish"
     "ocs"
     "opml"
     "amazon"
     "google"
     "ebay"

   */

  blog_id := udt_get (cls, 'blogid');
  opts := udt_get (cls, 'opts');

  if (cond = 'subscribe')
    {
      if (exists (select 1 from BLOG.DBA.SYS_ROUTING where R_ITEM_ID = blog_id and R_TYPE_ID = 2 and R_PROTOCOL_ID = 4))
	return 1;
    }
  else if (cond = 'have_community')
    {
      val := udt_get (cls, 'have_comunity_blog');
      if (isinteger (val) and val = 1)
        return 1;
    }
  else if (cond = 'browse_posts')
    {
      val := udt_get (cls, 'postid');
      if (val is null)
        return 1;
    }
  else if (cond = 'fish')
    {
      if (get_keyword('ShowFish', opts))
        return 1;
    }
  else if (cond = 'ocs')
    {
      if (exists (select 1 from BLOG.DBA.BLOG_CHANNELS where  BC_BLOG_ID = blog_id and length (BC_RSS_URI) and BC_HOME_URI is null and BC_FORM = 'OCS'))
	return 1;
    }
  else if (cond = 'opml')
    {
      if (exists (select 1 from BLOG.DBA.BLOG_CHANNELS where  BC_BLOG_ID = blog_id and length (BC_RSS_URI) and BC_HOME_URI is null and BC_FORM = 'OPML'))
	return 1;
    }
  else if (cond = 'amazon')
    {
      if (get_keyword('ShowAmazon', opts) and get_keyword('AmazonID', opts))
	return 1;
    }
  else if (cond = 'google')
    {
      if (get_keyword('ShowGoogle', opts))
	return 1;
    }
  else if (cond = 'ebay')
    {
      if (get_keyword('ShowEbay', opts))
	return 1;
    }
  else if (cond = 'login')
    {
      val := udt_get (cls, 'sid');
      if (length (val) > 0)
	return 1;
    }
  else if (cond = 'post-view')
    {
      val := udt_get (cls, 'postid');
      if (length (val) > 0)
	return 1;
    }
  else if (cond = 'summary-post-view')
    {
      val := udt_get (cls, 'postid');
      if (length (val) = 0)
	return 1;
    }
  else if (cond = 'tagid')
    {
      val := udt_get (cls, 'tagid');
      if (length (val) > 0)
	return 1;
    }
  else if (cond = 'comments')
    {
      val := udt_get (cls, 'comm');
      if (isinteger (val) and val > 0)
	return 1;
    }
  else if (cond = 'blog_author')
    {
      val := udt_get (cls, 'blog_access');
      if (isinteger (val) and (val = 2 or val = 1))
	return 1;
    }
  else if (cond = 'trackbacks')
    {
      if (get_keyword ('EnableTrackback', opts, 1))
	return 1;
    }
  else if (cond = 'referral')
    {
      if (get_keyword ('EnableReferral', opts, 1))
	return 1;
    }
  else if (cond = 'comments-or-enabled')
    {
      declare comments_list db.dba.vspx_data_set;
      val := udt_get (cls, 'comm');
      comments_list := udt_get (cls, 'comments_list');
      if (val or (comments_list is not null and length (comments_list.ds_row_data)))
	return 1;
    }
  else if (cond = 'have_tags')
    {
      declare control db.dba.vspx_row_template;
      control := ctr;
      if (exists (select top 1 1 from BLOG..BLOG_POST_TAGS_STAT_2 where postid = control.te_rowset[2]
	    and blogid = control.te_rowset[10]))
	return 1;
    }
  else if (cond = 'have_categories')
    {
      declare control db.dba.vspx_row_template;
      control := ctr;
      if (exists (select top 1 1 from BLOG..MTYPE_BLOG_CATEGORY where MTB_POST_ID = control.te_rowset[2]
	    and MTB_BLOG_ID = control.te_rowset[10]))
	return 1;
    }
  else
    {
      signal ('22023', sprintf ('Unknown condition test: ', cond));
    }
  return 0;
};

grant execute on BLOG.DBA.STATIC_ITEM_RENDER to public;
grant execute on BLOG.DBA.ITEM_RENDER to public;
grant execute on BLOG.DBA.BLOG_CHECK_CONDITION to public;


xpf_extension ('http://www.openlinksw.com/vspx/weblog/:render', 'BLOG.DBA.ITEM_RENDER');
xpf_extension ('http://www.openlinksw.com/vspx/weblog/:render-static', 'BLOG.DBA.STATIC_ITEM_RENDER');
xpf_extension ('http://www.openlinksw.com/vspx/weblog/:condition', 'BLOG.DBA.BLOG_CHECK_CONDITION');


create procedure make_temp_sp (in text any)
{
  /*
  declare exit handler for sqlstate '*'
    {
      dbg_printf ('[%s]\n%s', __SQL_STATE, substring (text, 1, 1500));
      resignal;
    };
  */
  exec ('explain(?)', null, null, vector (text), 0);
}
;

create procedure make_data_arr_from_xml (inout x any)
{
  declare xp, ret any;
  declare i int;

  if (not isentity (x))
    return vector ();

  xp := xpath_eval ('/data/*', x, 0);
  ret := make_array (2*length (xp), 'any');
  i := 0;
  foreach (any elm in xp) do
    {
      declare nam, val any;
      nam := cast (xpath_eval ('local-name()', elm) as varchar);
      val := xpath_eval ('string(.)', elm);
      ret[i] := nam;
      ret[i+1] := val;
      i := i + 2;
    }
  return ret;
};

create procedure ensure_widgets (in template varchar, in force int := 0)
{
  declare src any;
  declare xt, xp, dummy any;
  declare wname, wcomp, ss, newsql, p_name, t_name, orgw, add_pars, posts_mode, have_posts any;

  have_posts := 0;
  posts_mode := null;
  add_pars := '';
  dummy := 0;
  src := db.dba.vspx_src_get (template, dummy, 0);
  xt := xtree_doc (src);
  xp := xpath_eval ('[ xmlns:vm="http://www.openlinksw.com/vspx/weblog/" ] //vm:*[local-name() != "page" and local-name () != "header" and local-name () != "body" and local-name () != "condition" and local-name () != "if" and not (ancestor::vm:posts) and not (ancestor::vm:comments-view) ]', xt, 0);

  ss := string_output ();
again:
  foreach (any w in xp) do
    {
      declare tmp_file, full_tmp_file, suff any;

      wname := replace(cast(xpath_eval ('local-name()', w) as varchar), '-', '_');

      suff := '';
      if (wname = 'posts')
        {
          suff := cast(xpath_eval ('@mode', w) as varchar);
	  posts_mode := suff;
	  if (length (suff))
	    suff := '_'||suff;
	  have_posts := 1;
	}

--      dbg_obj_print (wname);

      p_name := 'blog_wt_render_' || wname || suff;

      -- DELME: remove 0, add a udt_is...
      if (force = 0 and __proc_exists (p_name) is not null)
	goto next;

      newsql := '';
      string_output_flush (ss);
      http_value (w, null, ss);
      w := string_output_string (ss);
      while (newsql <> w)
	{
	  newsql := w;
	  string_output_flush (ss);
	  --dbg_obj_print (w);
	  wcomp := xslt (BLOG2_GET_PPATH_URL ('widgets/store.xsl'), xtree_doc(w));
	  --xml_tree_doc_set_output (wcomp, 'text');
	  if (xpath_eval ('*', wcomp) is null)
	    {
	      w := wcomp;
	      goto make_sp;
	    }
	  http_value (wcomp, null, ss);
	  w := string_output_string (ss);
	}

      proc_def:

      orgw := wcomp;
      --dbg_printf ('vspx_make_vspxm: %s%s', wname, suff);
      w := db.dba.vspx_make_vspxm (null, newsql, 0, null);

      if (xpath_eval ('[ xmlns:v="http://www.openlinksw.com/vspx/" ] .//v:*', w) is not null)
	goto wdt_def;

      make_sp:
      w := xslt (BLOG2_GET_PPATH_URL ('widgets/make_sp.xsl'), w);
      --dbg_obj_print ('widget based on simple proc def', p_name);

      string_output_flush (ss);
      http (sprintf ('create procedure %s (inout self db.dba.blog_main %s) { \n', p_name, add_pars) , ss);
      http ('declare path, params, lines any; params := self.vc_event.ve_params; path := self.vc_event.ve_path; lines := self.vc_event.ve_lines; \n ?>',ss);
      xml_tree_doc_set_output (w, 'text');
      http_value (w, null, ss);
      http ('<?vsp return 0; }\n',ss);

      w := string_output_string (ss);
      --dbg_obj_print (wname, w);
      make_temp_sp (w);

      goto next;

      wdt_def:
      --dbg_obj_print ('generic widget def', p_name);

      string_output_flush (ss);
      http (sprintf ('create procedure %s (inout self db.dba.blog_main %s) { \n ', p_name, add_pars) , ss);
      http (sprintf (' self.widget_render (\'%s\'); \n', wname), ss);
      if (wname = 'posts')
	{
	  http (' self.widget_render (\'post_remove\'); \n', ss);
	}
      http (' return 0; }\n', ss);
      w := string_output_string (ss);
      make_temp_sp (w);


      next:;
    }

  if (have_posts)
    {
      declare xe, posts_xml any;

      xe := xtree_doc (
        sprintf ('<vm:default-post-gen trackback="discovery" xmlns:vm="http://www.openlinksw.com/vspx/weblog/" %s />',
        case when posts_mode is null then '' else sprintf ('mode="%s"', posts_mode) end), 0, '', 'UTF-8');

      posts_xml := xslt (BLOG2_GET_PPATH_URL ('widgets/compat.xsl'), xe);
      xp := xpath_eval ('[ xmlns:vm="http://www.openlinksw.com/vspx/weblog/" ] .//vm:*[local-name () != "if"]', posts_xml, 0);
      posts_xml := null;
      add_pars := ' , inout control db.dba.vspx_row_template, in t_post_id varchar, in t_comm int, in t_tb int';
      have_posts := 0;
      goto again;
    }

  return;
};







