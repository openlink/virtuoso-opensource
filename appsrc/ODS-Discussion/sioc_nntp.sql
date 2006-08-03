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

create procedure nntp_role_iri (in name varchar)
{
  return sprintf ('http://%s%s/discussion/%U#reader', get_cname(), get_base_path (), name);
};

create procedure fill_ods_nntp_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, firi, title, arr, link, riri varchar;
  for select NG_GROUP, NG_NAME, NG_DESC, NG_TYPE from DB.DBA.NEWS_GROUPS do
    {
      firi := forum_iri ('nntpf', NG_NAME);
      sioc_forum (graph_iri, site_iri, firi, NG_NAME, 'nntpf', NG_DESC);
      riri := nntp_role_iri (NG_NAME);
      DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
      for select NM_ID, NM_REC_DATE, NM_HEAD from DB.DBA.NEWS_MSG, DB.DBA.NEWS_MULTI_MSG
	where NM_GROUP = NG_GROUP and NM_KEY_ID = NM_ID and NM_TYPE = NG_TYPE do
	  {
	    iri := nntp_post_iri (NG_NAME, NM_ID);
	    arr := deserialize (NM_HEAD);
	    title := get_keyword ('Subject', arr[0]);
	    DB.DBA.nntpf_decode_subj (title);
	    link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (NM_ID));
	    ods_sioc_post (graph_iri, iri, firi, null, title, NM_REC_DATE, NM_REC_DATE, link);
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

create trigger NEWS_MULTI_MSG_SIOC_I after insert on DB.DBA.NEWS_MULTI_MSG referencing new as N
{
  declare iri, graph_iri, firi, arr, title, link varchar;
  declare g_name, g_type, m_id, m_date, m_head any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;

  select NG_NAME, NG_TYPE into g_name, g_type from DB.DBA.NEWS_GROUPS where NG_GROUP = N.NM_GROUP;
  select NM_ID, NM_REC_DATE, NM_HEAD into m_id, m_date, m_head
      from DB.DBA.NEWS_MSG where NM_ID = N.NM_KEY_ID and NM_TYPE = g_type;

  firi := forum_iri ('nntpf', g_name);
  iri := nntp_post_iri (g_name, m_id);
  arr := deserialize (m_head);
  title := get_keyword ('Subject', arr[0]);
  DB.DBA.nntpf_decode_subj (title);
  link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (m_id));
  ods_sioc_post (graph_iri, iri, firi, null, title, m_date, m_date, link);
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

