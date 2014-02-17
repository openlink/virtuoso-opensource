--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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


create procedure fill_ods_nntp_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
    {
  declare iri, firi, title, arr, link, riri, maker, maker_iri varchar;
{
    declare deadl, cnt any;
    declare _grp, _msg any;

    _grp := -1;
    _msg := '';
    deadl := 5;
    cnt := 0;
    declare exit handler for sqlstate '40001'
    {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
};
    l0:

  for select NG_GROUP, NG_NAME, NG_DESC, NG_TYPE from DB.DBA.NEWS_GROUPS where NG_GROUP > _grp do
    {
	    declare t_cnt int;

      firi := forum_iri ('nntpf', NG_NAME);
      sioc_forum (graph_iri, site_iri, firi, NG_NAME, 'nntpf', NG_DESC);
      t_cnt:=0;
      for select NNPT_TAGS, NNPT_UID
            from DB.DBA.NNTPF_NGROUP_POST_TAGS
	      where NNPT_NGROUP_ID = NG_GROUP and NNPT_POST_ID = '' do
	      {
	    ods_sioc_tags (graph_iri, firi, sprintf ('"^UID%d",', NNPT_UID)|| NNPT_TAGS);
		     t_cnt := t_cnt + 1;
	      }
	    if (not t_cnt)
	      ods_sioc_tags (graph_iri, firi, null);

      riri := nntp_role_iri (NG_NAME);
      DB.DBA.ODS_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
      DB.DBA.ODS_QUAD_URI (graph_iri, firi, sioc_iri ('scope_of'), riri);
      for select NM_KEY_ID
            from DB.DBA.NEWS_MULTI_MSG
	where NM_GROUP = NG_GROUP and NM_KEY_ID > _msg order by NM_KEY_ID do
	  {
	    declare par_iri, par_id, links_to any;
            declare _NM_ID, _NM_REC_DATE, _NM_HEAD, _NM_BODY any;

	    whenever not found goto nxt;
	    select NM_ID, NM_REC_DATE, NM_HEAD, NM_BODY
		into _NM_ID, _NM_REC_DATE, _NM_HEAD, _NM_BODY
		from DB.DBA.NEWS_MSG
		where NM_ID = NM_KEY_ID and NM_TYPE = NG_TYPE;

	    iri := nntp_post_iri (NG_NAME, _NM_ID);
	    arr := deserialize (_NM_HEAD);
	    title := get_keyword ('Subject', arr[0]);
	    maker := get_keyword ('From', arr[0]);
	    maker := DB.DBA.nntpf_get_sender (maker);
	    maker_iri := null;
	    if (maker is not null)
	      {
	        maker_iri := 'mailto:'||maker;
		foaf_maker (graph_iri, maker_iri, null, maker);
	      }
	    DB.DBA.nntpf_decode_subj (title);
	    link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (_NM_ID));
	    links_to := DB.DBA.nntpf_get_links (_NM_BODY);
	    ods_sioc_post (graph_iri, iri, firi, null, title, _NM_REC_DATE, _NM_REC_DATE, link, _NM_BODY, null, links_to, maker_iri);
	    t_cnt := 0;
  	    for select NNPT_TAGS, NNPT_UID
  	          from DB.DBA.NNTPF_NGROUP_POST_TAGS
	      where NNPT_NGROUP_ID = NG_GROUP and NNPT_POST_ID = NM_KEY_ID do
	      {
		ods_sioc_tags (graph_iri, iri, sprintf ('"^UID%d",', NNPT_UID)|| NNPT_TAGS);
		scot_tags_insert (-1 * NG_GROUP, iri, NNPT_TAGS);
		t_cnt := t_cnt + 1;
	      }
	    if (not t_cnt)
	      ods_sioc_tags (graph_iri, iri, null);

	    par_id := (select FTHR_REFER from DB.DBA.NNFE_THR where FTHR_MESS_ID = _NM_ID and FTHR_GROUP = NG_GROUP);
	    if (par_id is not null)
	      {
		par_iri := nntp_post_iri (NG_NAME, par_id);
      		DB.DBA.ODS_QUAD_URI (graph_iri, par_iri, sioc_iri ('has_reply'), iri);
      		DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), par_iri);
	      }
	    nxt:
	    cnt := cnt + 1;
	    if (mod (cnt, 500) = 0)
	      {
		commit work;
		_msg := NM_KEY_ID;
	      }
	  }
      for select U_NAME from DB.DBA.SYS_USERS where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0 do
	   {
	     declare user_iri varchar;

             user_iri := user_obj_iri (U_NAME);
  	    DB.DBA.ODS_QUAD_URI (graph_iri, riri, sioc_iri ('function_of'), user_iri);
  	    DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), riri);
	   }
	 commit work;
	 _grp := NG_GROUP;
	 _msg := '';
    }
  commit work;
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

--db.dba.wa_exec_no_error('ods_nntp_sioc_init ()');


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
  ods_sioc_tags (graph_iri, firi, null);

  riri := nntp_role_iri (N.NG_NAME);
  DB.DBA.ODS_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
  DB.DBA.ODS_QUAD_URI (graph_iri, firi, sioc_iri ('scope_of'), riri);
  for select U_NAME from DB.DBA.SYS_USERS where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0
    do
      {
	declare user_iri varchar;
	user_iri := user_obj_iri (U_NAME);
	DB.DBA.ODS_QUAD_URI (graph_iri, riri, sioc_iri ('function_of'), user_iri);
	DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), riri);
      }
      
  insert into sioc.DBA.inst_tag_stats (its_inst_id) values (-1 * N.NG_GROUP);
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
  delete from sioc.DBA.inst_tag_stats where its_inst_id = (-1 * O.NG_GROUP);
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
  DB.DBA.ODS_QUAD_URI (graph_iri, par_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), par_iri);
};

create trigger NNTPF_NGROUP_POST_TAGS_I after insert on DB.DBA.NNTPF_NGROUP_POST_TAGS referencing new as N
{
  declare iri, graph_iri varchar;
  declare g_name any;
  declare oobj any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  declare exit handler for not found;
  select NG_NAME into g_name from DB.DBA.NEWS_GROUPS where NG_GROUP = N.NNPT_NGROUP_ID;

  if(length(N.NNPT_POST_ID)>0)
  iri := nntp_post_iri (g_name, N.NNPT_POST_ID);
  else 
     iri := forum_iri ('nntpf', g_name);

  oobj := DB.DBA.RDF_OBJ_OF_SQLVAL ('~none~');
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (fix_graph (graph_iri)) and O = oobj and S = DB.DBA.RDF_IID_OF_QNAME (iri);
  ods_sioc_tags (graph_iri, iri,
      sprintf ('"^UID%d",', N.NNPT_UID) ||
      N.NNPT_TAGS);
  scot_tags_insert (-1 * N.NNPT_NGROUP_ID, iri, N.NNPT_TAGS);
}
;

create trigger NNTPF_NGROUP_POST_TAGS_U after update on DB.DBA.NNTPF_NGROUP_POST_TAGS referencing old as O, new as N
{
  declare iri, graph_iri varchar;
  declare g_name any;
  declare oobj any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  declare exit handler for not found;
  select NG_NAME into g_name from DB.DBA.NEWS_GROUPS where NG_GROUP = N.NNPT_NGROUP_ID;
 
  if(length(N.NNPT_POST_ID)>0)
  iri := nntp_post_iri (g_name, N.NNPT_POST_ID);
  else 
     iri := forum_iri ('nntpf', g_name);

  oobj := DB.DBA.RDF_OBJ_OF_SQLVAL (sprintf ('"^UID%d",', O.NNPT_UID)||O.NNPT_TAGS);
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (fix_graph (graph_iri)) and O = oobj and S = DB.DBA.RDF_IID_OF_QNAME (iri);
  ods_sioc_tags_delete(graph_iri, iri, sprintf ('"^UID%d",', N.NNPT_UID) || O.NNPT_TAGS);
  ods_sioc_tags (graph_iri, iri, sprintf ('"^UID%d",', N.NNPT_UID) || N.NNPT_TAGS);

  scot_tags_delete (-1 * O.NNPT_NGROUP_ID, iri, O.NNPT_TAGS);
  scot_tags_insert (-1 * N.NNPT_NGROUP_ID, iri, N.NNPT_TAGS);
  return;
}
;


create trigger NNTPF_NGROUP_POST_TAGS_D after delete on DB.DBA.NNTPF_NGROUP_POST_TAGS referencing old as O
{
  declare iri, graph_iri varchar;
  declare g_name any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  declare exit handler for not found;
  select NG_NAME into g_name from DB.DBA.NEWS_GROUPS where NG_GROUP = O.NNPT_NGROUP_ID;
  iri := nntp_post_iri (g_name, O.NNPT_POST_ID);
  ods_sioc_tags (graph_iri, iri, null);
  scot_tags_delete (-1 * O.NNPT_NGROUP_ID, iri, O.NNPT_TAGS);
  return;
}
;

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
  maker := DB.DBA.nntpf_get_sender (maker);
  maker_iri := null;
  if (maker is not null)
    {
      maker_iri := 'mailto:'||maker;
      foaf_maker (graph_iri, maker_iri, null, maker);
    }
  link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (m_id));
  links_to := DB.DBA.nntpf_get_links (m_body);
  ods_sioc_post (graph_iri, iri, firi, null, title, m_date, m_date, link, m_body, null, links_to, maker_iri);
  ods_sioc_tags (graph_iri, iri, null);
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
-- NNTPF

wa_exec_no_error ('drop view ODS_NNTP_GROUPS');
wa_exec_no_error ('drop view ODS_NNTP_POSTS');
wa_exec_no_error ('drop view ODS_NNTP_USERS');
wa_exec_no_error ('drop view ODS_NNTP_LINKS');

create view ODS_NNTP_GROUPS as select NG_NAME, NG_DESC, '' as DUMMY from DB.DBA.NEWS_GROUPS;

create view ODS_NNTP_POSTS as select
	NG_GROUP,
	NG_NAME,
	NM_ID,
	sioc..sioc_date (NM_REC_DATE) as REC_DATE,
	NM_HEAD,
	NM_BODY,
	FTHR_SUBJ,
	concat ('mailto:', FTHR_FROM) as MAKER,
	FTHR_REFER
	from
	DB.DBA.NEWS_MSG join DB.DBA.NEWS_MULTI_MSG on (NM_ID = NM_KEY_ID)
    	join DB.DBA.NEWS_GROUPS on (NM_GROUP = NG_GROUP and NM_TYPE = NG_TYPE)
    	left outer join DB.DBA.NNFE_THR on (FTHR_MESS_ID = NM_ID and FTHR_GROUP = NG_GROUP);

create view ODS_NNTP_USERS as select NG_NAME, U_NAME from DB.DBA.NEWS_GROUPS, DB.DBA.SYS_USERS
	where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0;

create view ODS_NNTP_LINKS as select NML_MSG_ID, NML_URL, NG_NAME
	from
	NNTPF_MSG_LINKS
	join DB.DBA.NEWS_MULTI_MSG on (NML_MSG_ID = NM_KEY_ID)
	join DB.DBA.NEWS_GROUPS on (NM_GROUP = NG_GROUP);

create procedure sioc.DBA.rdf_nntpf_view_str ()
{
  return
      '
      # NNTP forum
      # SIOC
      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_GROUPS.NG_NAME) a sioct:MessageBoard ;
      sioc:id NG_NAME ;
      sioc:description NG_DESC ;
      sioc:has_space sioc:default_site (DUMMY) .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.NM_ID) a sioct:BoardPost ;
      sioc:content NM_BODY ;
      dc:title FTHR_SUBJ ;
      dct:created  REC_DATE ;
      dct:modified REC_DATE ;
      foaf:maker sioc:proxy_iri (MAKER) ;
      sioc:reply_of sioc:nntp_post_iri (NG_NAME, FTHR_REFER) ;
      sioc:has_container sioc:nntp_forum_iri (NG_NAME) .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.FTHR_REFER)
      sioc:has_reply
      sioc:nntp_post_iri (NG_NAME, NM_ID) .

      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME)
      sioc:container_of
      sioc:nntp_post_iri (NG_NAME, NM_ID) .

      #OLD version sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_USERS.NG_NAME)
      #sioc:has_member
      #sioc:user_iri (U_NAME) .

      sioc:nntp_role_iri (DB.DBA.NEWS_GROUPS.NG_NAME)
      sioc:has_scope
      sioc:nntp_forum_iri (NG_NAME) .

      sioc:nntp_forum_iri (DB.DBA.NEWS_GROUPS.NG_NAME)
      sioc:scope_of
      sioc:nntp_role_iri (NG_NAME) .

      sioc:user_iri (DB.DBA.ODS_NNTP_USERS.U_NAME)
      sioc:has_function
      sioc:nntp_role_iri (NG_NAME) .

      sioc:nntp_role_iri (DB.DBA.ODS_NNTP_USERS.NG_NAME)
      sioc:function_of
      sioc:user_iri (U_NAME) .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_LINKS.NG_NAME, DB.DBA.ODS_NNTP_LINKS.NML_MSG_ID)
      sioc:links_to
      sioc:proxy_iri (NML_URL) .

      # AtomOWL
      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_GROUPS.NG_NAME) a atom:Feed .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.NM_ID) a atom:Entry ;
      atom:title FTHR_SUBJ ;
      atom:source sioc:nntp_forum_iri (NG_NAME) ;
      atom:author sioc:proxy_iri (MAKER) ;
      atom:published REC_DATE ;
      atom:updated REC_DATE ;
      atom:content sioc:nntp_post_text_iri (NG_NAME, NM_ID) .

      sioc:nntp_post_text_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.NM_ID) a atom:Content ;
      atom:type "text/plain"  option (EXCLUSIVE) ;
      atom:lang "en-US"  option (EXCLUSIVE) ;
      atom:body NM_BODY .

      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME)
      atom:contains
      sioc:nntp_post_iri (NG_NAME, NM_ID) .

      '
      ;
};

create procedure sioc.DBA.rdf_nntpf_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_NNTP_GROUPS as nntp_groups
      from DB.DBA.ODS_NNTP_POSTS as nntp_posts
      from DB.DBA.ODS_NNTP_USERS as nntp_users
      where (^{nntp_users.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_NNTP_LINKS as nntp_links
      '
      ;
};

create procedure sioc.DBA.rdf_nntpf_view_str_maps ()
{
  return
      '
	    # NNTP
	    ods:nntp_forum (nntp_groups.NG_NAME) a sioct:MessageBoard ;
  	    rdfs:label nntp_groups.NG_NAME ;
	    sioc:id nntp_groups.NG_NAME ;
	    sioc:description nntp_groups.NG_DESC .

	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.NM_ID) a sioct:BoardPost ;
	    sioc:content nntp_posts.NM_BODY ;
	    dc:title nntp_posts.FTHR_SUBJ ;
	    dct:created  nntp_posts.REC_DATE ;
	    dct:modified nntp_posts.REC_DATE ;
	    foaf:maker ods:proxy (nntp_posts.MAKER) ;
	    sioc:reply_of ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.FTHR_REFER) ;
	    sioc:has_container ods:nntp_forum (nntp_posts.NG_NAME) .

	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.FTHR_REFER)
	    sioc:has_reply
	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.NM_ID) .

	    ods:nntp_forum (nntp_posts.NG_NAME)
	    sioc:container_of
	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.NM_ID) .


	    ods:nntp_role (nntp_groups.NG_NAME)
	    sioc:has_scope
	    ods:nntp_forum (nntp_groups.NG_NAME) .

	    ods:nntp_forum (nntp_groups.NG_NAME)
	    sioc:scope_of
	    ods:nntp_role (nntp_groups.NG_NAME) .

	    ods:user (nntp_users.U_NAME)
	    sioc:has_function
	    ods:nntp_role (nntp_users.NG_NAME) .

	    ods:nntp_role (nntp_users.NG_NAME)
	    sioc:function_of
	    ods:user (nntp_users.U_NAME) .

	    ods:nntp_post (nntp_links.NG_NAME, nntp_links.NML_MSG_ID)
	    sioc:links_to
	    ods:proxy (nntp_links.NML_URL) .
	    # end NNTP
      '
      ;
};

-- END NNTPF

grant select on ODS_NNTP_GROUPS to SPARQL_SELECT;
grant select on ODS_NNTP_POSTS to SPARQL_SELECT;
grant select on ODS_NNTP_USERS to SPARQL_SELECT;
grant select on ODS_NNTP_LINKS to SPARQL_SELECT;


ODS_RDF_VIEW_INIT ();
