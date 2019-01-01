--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

--      declare source any;
--	source := file_to_string (http_root()||'/wa/home.vspx');
--      xslt ('file:/wa/comp/compile.xsl', xtree_doc (source));

create procedure wa_get_xslt_url (in url varchar)
{
  if (http_map_get ('is_dav') = 0)
--    return 'file:' || registry_get('_wa_path_') || url;
    return 'file:' || '/samples/wa/' || url;
  else
    return 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || registry_get('_wa_path_') || url;
};

create procedure wa_ensure_page_class (inout path any, inout params any, inout lines any, in comp_only int)
{
  declare cls vspx_page;
  cls := db.dba.vspx_dispatch (registry_get ('_wa_path_')||'generic.vspx', path, params, lines, 'wa_generic_template', comp_only);
  commit work;
  return cls;
}
;

wa_exec_no_error ('drop type DB.DBA.wa_generic_template');

create procedure wa_home_exec (in full_path varchar, inout path any, inout params any, inout lines any)
{

  declare dummy, force any;
  declare cls vspx_page;

  --dbg_printf ('start wa_home_exec');

  -- uncomment this line to compile class per page
  --vspx_dispatch (full_path, path, params, lines);
  --return;

  dummy := null;
  force := 0;
  if (not udt_is_available ('DB.DBA.wa_generic_template'))
    {
      db.dba.wa_ensure_page_class (dummy, dummy, dummy, 1);
      force := 1;
    }

  wa_ensure_widgets (full_path, force);
  cls := db.dba.wa_ensure_page_class (path, vector_concat (params, vector ('template-name', full_path)), lines, 0);
  --dbg_printf ('done wa_home_exec');
};


create procedure wa_template_body_render (inout cls vspx_page)
{
  declare xt, rc any;
  --dbg_obj_print ('wa_template_body_render: start');
  xt := udt_get (cls, 'template_xml');
  rc := xslt (wa_get_xslt_url ('comp/render.xsl'), xt, vector ('class', cls, 'what', 'body'));
  --dbg_obj_print ('wa_template_body_render: done');
};

create procedure wa_template_header_render (inout cls vspx_page)
{
  declare xt, rc any;
  --dbg_obj_print ('wa_template_header_render: start');
  xt := udt_get (cls, 'template_xml');
  rc := xslt (wa_get_xslt_url ('comp/render.xsl'), xt, vector ('class', cls, 'what', 'header'));
  --dbg_obj_print ('wa_template_header_render: done');
};


create procedure WA_ITEM_RENDER (in widget varchar, inout cls any)
{
  declare page_class db.dba.vspx_page;
  declare ret, p_name any;

  page_class := cls;
  p_name := 'wa_wt_render_'||widget;
  --dbg_obj_print ('widget', widget);
  if (__proc_exists (p_name))
    {
      --dbg_obj_print ('rendering vsp:' , p_name);
      call (p_name) (page_class);
    }
  else
    {
      http ('Unknown widget: ', widget);
    }
  return;
}
;

create procedure WA_STATIC_ITEM_RENDER (inout x any, inout cnt any, in f int, in not_single int)
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
      http (cast (x as varchar));
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

create procedure WA_CHECK_CONDITION (in cond varchar, inout cls any) returns integer
{
  declare val any;
  --dbg_obj_print ('condition: ', cond);
  if (cond = 'owner')
    {
      val := udt_get (cls, 'isowner');
      --dbg_obj_print ('val=', val);
      if (isinteger (val))
        return val;
    }
  if (cond = 'not-owner')
    {
      val := udt_get (cls, 'isowner');
      --dbg_obj_print ('val=', val);
      if (isinteger (val) and val = 0)
        return 1;
    }
  else if (cond = 'login')
    {
      val := udt_get (cls, 'sid');
      --dbg_obj_print ('val=', val);
      if (length (val) > 0)
	return 1;
    }
  else if (cond = 'exists-map-key')
    {
      declare arr any;
      arr := udt_get (cls, 'arr');
      val := udt_get (cls, 'maps_key');
      --dbg_obj_print ('val=', val);
      if (isstring (val) and length (val) > 0 and isarray (arr) and length(arr) > 40
	  and arr[39] is not null and arr[40] is not null)
	return 1;
    }
  return 0;
};

grant execute on WA_STATIC_ITEM_RENDER to public;
grant execute on WA_ITEM_RENDER to public;
grant execute on WA_CHECK_CONDITION to public;

xpf_extension ('http://www.openlinksw.com/vspx/wa/:render', 'DB.DBA.WA_ITEM_RENDER');
xpf_extension ('http://www.openlinksw.com/vspx/wa/:render-static', 'DB.DBA.WA_STATIC_ITEM_RENDER');
xpf_extension ('http://www.openlinksw.com/vspx/wa/:condition', 'DB.DBA.WA_CHECK_CONDITION');



create procedure wa_ensure_widgets (in template varchar, in force int := 0)
{
  declare src any;
  declare xt, xp, dummy, nwd any;
  declare wname, wcomp, ss, newsql, p_name, t_name, tses, orgw any;

  dummy := 0;
  src := db.dba.vspx_src_get (template, dummy, 0);
  xt := xtree_doc (src);
  xp := xpath_eval ('[ xmlns:vm="http://www.openlinksw.com/vspx/ods/" ] //vm:*[local-name() != "page" and local-name () != "header" and local-name () != "body" and local-name () != "pagewrapper" and local-name () != "condition" ]', xt, 0);

  ss := string_output ();
  tses := string_output ();

  nwd := 0;

  foreach (any w in xp) do
    {
      declare tmp_file, full_tmp_file any;

      wname := replace(cast(xpath_eval ('local-name()', w) as varchar), '-', '_');

      p_name := 'wa_wt_render_' || wname;

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
--	  wcomp := xslt (wa_get_xslt_url ('comp/store.xsl'), xtree_doc(w));
	  wcomp := xslt (wa_get_xslt_url ('comp/store.xsl'), xtree_doc(w));
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
      w := db.dba.vspx_make_vspxm (null, newsql, 0, null);

      if (xpath_eval ('[ xmlns:v="http://www.openlinksw.com/vspx/" ] .//v:*', w) is not null)
	goto wdt_def;

      make_sp:
      w := xslt (wa_get_xslt_url ('comp/make_sp.xsl'), w);
      --dbg_obj_print ('simple proc def');

      string_output_flush (ss);
      http (sprintf ('create procedure %s (inout self db.dba.wa_generic_template) { \n', p_name) , ss);
      http ('declare path, params, lines any; params := self.vc_event.ve_params; path := self.vc_event.ve_path; lines := self.vc_event.ve_lines; \n ?>',ss);
      xml_tree_doc_set_output (w, 'text');
      http_value (w, null, ss);
      http ('<?vsp }\n',ss);

      w := string_output_string (ss);
      --dbg_obj_print (wname, w);
      wa_make_temp_sp (w);

      goto next;

      wdt_def:;

      string_output_flush (ss);
      http (sprintf ('create procedure %s (inout self db.dba.wa_generic_template) { \n ', p_name) , ss);
      http (sprintf (' self.wa_widget_render (\'%s\'); \n }\n', wname), ss);
      w := string_output_string (ss);
      wa_make_temp_sp (w);
      next:;
    }
  return;
};


create procedure wa_make_temp_sp (in text any)
{
  --dbg_obj_print ('compile:', subseq (text, 0, 1500));
  exec ('explain(?)', null, null, vector (text), 0);
}
;

