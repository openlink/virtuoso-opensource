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

create procedure nntp_role_iri (in name varchar)
{
  return sprintf ('http://%s%s/discussion/%U#reader', get_cname(), get_base_path (), name);
};

create procedure get_sender (in email varchar)
{
   declare mail, name varchar;
   mail := regexp_match ('<[^@<>]+@[^@<>]+>', email);
   if (mail is null)
     mail := regexp_match ('([^@()]+@[^@()]+)', email);
   if (mail is null)
     mail := regexp_match ('\\[[^@\\[\\]]+@[^@\\[\\]]+\\]', email);
   if (mail is null)
     return mail;
   return trim (mail, '[]()<>');
};

create procedure nntp_process_parts (in parts any, inout body any, out result any)
{
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, l, i1, l1, is_allowed int;
  declare part, xt, xp any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;
  -- test if there is an moblog compliant image
  part := parts[0];
--  dbg_obj_print ('part=', part);

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '') {
    mime1 := http_mime_type (name1);
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

--  dbg_obj_print (_cnt_disp, mime1);

  if ((_cnt_disp = 'inline' or _cnt_disp = '') and mime1 = 'text/html')
    {
      name := name1;
      mime := mime1;
      enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
--      dbg_obj_print (enc);
      content := subseq (body, parts[1][0], parts[1][1]);
      if (enc = 'base64')
	content := decode_base64 (content);
      else if (enc = 'quoted-printable')
	content := uudecode (content, 12);
      xt := xtree_doc (content, 2, '', 'UTF-9');
--      dbg_obj_print (xt);
      xp := xpath_eval ('//a[starts-with (@href,"http") and not(img)]', xt, 0);
      foreach (any elm in xp) do
	{
	  declare tit, href any;
	  tit := cast (xpath_eval ('string()', elm) as varchar);
	  href := cast (xpath_eval ('@href', elm) as varchar);
	  result := vector_concat (result, vector (vector (tit, href)));
	}
      return 1;
    }
  -- process the parts
  if(not isarray (parts[2]))
    return 0;
  i := 0;
  l := length (parts[2]);
  while (i < l) {
    nntp_process_parts (parts[2][i], body, result);
    i := i + 1;
  }
  return 0;

};

create procedure nntp_get_links (in message any)
{
  declare parsed_message, res any;
  parsed_message := mime_tree (message);
  res := null;
  nntp_process_parts (parsed_message, message, res);
  return res;
};

create procedure fill_ods_nntp_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, firi, title, arr, link, riri, maker, maker_iri varchar;
  for select NG_GROUP, NG_NAME, NG_DESC, NG_TYPE from DB.DBA.NEWS_GROUPS do
    {
      firi := forum_iri ('nntpf', NG_NAME);
      sioc_forum (graph_iri, site_iri, firi, NG_NAME, 'nntpf', NG_DESC);
      riri := nntp_role_iri (NG_NAME);
      DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
      for select NM_ID, NM_REC_DATE, NM_HEAD, NM_BODY from DB.DBA.NEWS_MSG, DB.DBA.NEWS_MULTI_MSG
	where NM_GROUP = NG_GROUP and NM_KEY_ID = NM_ID and NM_TYPE = NG_TYPE do
	  {
	    declare par_iri, par_id, links_to any;
	    iri := nntp_post_iri (NG_NAME, NM_ID);
	    arr := deserialize (NM_HEAD);
	    title := get_keyword ('Subject', arr[0]);
	    maker := get_keyword ('From', arr[0]);
	    maker := get_sender (maker);
	    maker_iri := null;
	    if (maker is not null)
	      {
	        maker_iri := 'mailto:'||maker;
		foaf_maker (graph_iri, maker_iri, null, maker);
	      }
	    DB.DBA.nntpf_decode_subj (title);
	    link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (NM_ID));
	    links_to := nntp_get_links (NM_BODY);
--	    dbg_obj_print (iri, links_to);
	    ods_sioc_post (graph_iri, iri, firi, null, title, NM_REC_DATE, NM_REC_DATE, link, NM_BODY, null, links_to, maker_iri);

	    par_id := (select FTHR_REFER from DB.DBA.NNFE_THR where FTHR_MESS_ID = NM_ID and FTHR_GROUP = NG_GROUP);
	    if (par_id is not null)
	      {
		par_iri := nntp_post_iri (NG_NAME, par_id);
		DB.DBA.RDF_QUAD_URI (graph_iri, par_iri, sioc_iri ('has_reply'), iri);
		DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), par_iri);
	      }
	  }
       for select U_NAME from DB.DBA.SYS_USERS where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0
	 do
	   {
	     declare user_iri varchar;
             user_iri := user_obj_iri (U_NAME);
	     DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('has_member'), user_iri);
	     DB.DBA.RDF_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), riri);
	   }
    }
};

create procedure ods_nntp_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');

  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;

  if (registry_get ('__ods_nntp_sioc_init') = sioc_version)
    return;

  fill_ods_nntp_sioc (get_graph (), get_graph ());
  registry_set ('__ods_nntp_sioc_init', sioc_version);
  return;

};

db.dba.wa_exec_no_error('ods_nntp_sioc_init ()');


create trigger NEWS_GROUPS_SIOC_I after insert on DB.DBA.NEWS_GROUPS referencing new as N
{
  declare firi, graph_iri, site_iri, riri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  site_iri  := get_graph ();
  graph_iri := get_graph ();
  firi := forum_iri ('nntpf', N.NG_NAME);
  sioc_forum (graph_iri, site_iri, firi, N.NG_NAME, 'nntpf', N.NG_DESC);
  riri := nntp_role_iri (N.NG_NAME);
  DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
  for select U_NAME from DB.DBA.SYS_USERS where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0
    do
      {
	declare user_iri varchar;
	user_iri := user_obj_iri (U_NAME);
	DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('has_member'), user_iri);
	DB.DBA.RDF_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), riri);
      }
  return;
};

create trigger NEWS_GROUPS_SIOC_D after delete on DB.DBA.NEWS_GROUPS referencing old as O
{
  declare iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := forum_iri ('nntpf', O.NG_NAME);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

create trigger NNFE_THR_REPLY_I after insert on DB.DBA.NNFE_THR referencing new as N
{
  declare iri, graph_iri, par_iri varchar;
  declare g_name any;

  if (N.FTHR_TOP = 1)
    return;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;
  select NG_NAME into g_name from DB.DBA.NEWS_GROUPS where NG_GROUP = N.FTHR_GROUP;

  iri := nntp_post_iri (g_name, N.FTHR_MESS_ID);
  par_iri := nntp_post_iri (g_name, N.FTHR_REFER);
  DB.DBA.RDF_QUAD_URI (graph_iri, par_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), par_iri);
};

create trigger NEWS_MULTI_MSG_SIOC_I after insert on DB.DBA.NEWS_MULTI_MSG referencing new as N
{
  declare iri, graph_iri, firi, arr, title, link, maker, maker_iri varchar;
  declare g_name, g_type, m_id, m_date, m_head, m_body, links_to any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;

  select NG_NAME, NG_TYPE into g_name, g_type from DB.DBA.NEWS_GROUPS where NG_GROUP = N.NM_GROUP;
  select NM_ID, NM_REC_DATE, NM_HEAD, NM_BODY into m_id, m_date, m_head, m_body
      from DB.DBA.NEWS_MSG where NM_ID = N.NM_KEY_ID and NM_TYPE = g_type;

  firi := forum_iri ('nntpf', g_name);
  iri := nntp_post_iri (g_name, m_id);
  arr := deserialize (m_head);
  title := get_keyword ('Subject', arr[0]);
  DB.DBA.nntpf_decode_subj (title);
  maker := get_keyword ('From', arr[0]);
  maker := get_sender (maker);
  maker_iri := null;
  if (maker is not null)
    {
      maker_iri := 'mailto:'||maker;
      foaf_maker (graph_iri, maker_iri, null, maker);
    }
  link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (m_id));
  links_to := nntp_get_links (m_body);
  ods_sioc_post (graph_iri, iri, firi, null, title, m_date, m_date, link, m_body, null, links_to, maker_iri);
  return;
};

create trigger NEWS_MULTI_MSG_SIOC_D after delete on DB.DBA.NEWS_MULTI_MSG referencing old as O
{
  declare iri, graph_iri, firi varchar;
  declare g_name, g_type any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;
  select NG_NAME, NG_TYPE into g_name, g_type from DB.DBA.NEWS_GROUPS where NG_GROUP = O.NM_GROUP;
  iri := nntp_post_iri (g_name, O.NM_KEY_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

use DB;

