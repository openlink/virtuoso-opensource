--
--  sioc.sql
--
--  $Id$
--
--  Procedures to support the SIOC Ontology RDF data in ODS.
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

create procedure get_cname ()
{
  declare default_host, ret varchar;
  default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (default_host is not null)
    return default_host;
  ret := sys_stat ('st_host_name');
  if (server_http_port () <> '80')
    ret := ret ||':'|| server_http_port ();
  return ret;
};

create procedure get_base_path ()
{
  return '/dataspace';
};

create procedure get_graph ()
{
  return sprintf ('http://%s%s', get_cname (), get_base_path ());
};

create procedure get_ods_link ()
{
  return sprintf ('http://%s/ods', get_cname ());
};


-- ODS object to IRI functions

-- NULL means no such

create procedure user_obj_iri (in _u_name varchar)
{
  return sprintf ('http://%s%s/%U', get_cname(), get_base_path (), _u_name);
};

create procedure user_iri (in _u_id int)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select u_name into _u_name from DB.DBA.SYS_USERS where U_ID = _u_id and U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0;
  return user_obj_iri (_u_name);
};

create procedure user_group_iri (in _g_id int)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select u_name into _u_name from DB.DBA.SYS_USERS where U_ID = _g_id and U_IS_ROLE = 1;
  return user_obj_iri (_u_name);
};

create procedure role_iri (in _wai_id int, in _wam_member_id int)
{
  declare _role, inst, _member, tp varchar;
  declare exit handler for not found { return null; };
  select WMT_NAME, WAI_NAME, U_NAME, WAI_TYPE_NAME into _role, 	inst, _member, tp
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_MEMBER_TYPE, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAI_ID = _wai_id
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;
  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure role_iri_by_name (in _wai_name varchar, in _wam_member_id int)
{
  declare _role, inst, _member, tp varchar;
  declare exit handler for not found { return null; };
  select WMT_NAME, WAI_NAME, U_NAME, WAI_TYPE_NAME into _role, 	inst, _member, tp
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_MEMBER_TYPE, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME
      and WAI_NAME = _wai_name
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;
  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure forum_iri (in inst_type varchar, in wai_name varchar)
{
  declare _member, tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);

  declare exit handler for not found { return null; };
  select U_NAME into _member from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_INST = wai_name and WAM_USER = U_ID and WAM_MEMBER_TYPE = 1;
  return sprintf ('http://%s%s/%U/%U/%U', get_cname(), get_base_path (), _member, tp, wai_name);
};

create procedure user_iri_ent (in sne int)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select sne_name into _u_name from DB.DBA.sn_entity where sne_id = sne;
  return sprintf ('http://%s%s/%U', get_cname(), get_base_path (), _u_name);
};

create procedure  blog_iri (in wai_name varchar)
{
  return forum_iri ('WEBLOG2', wai_name);
};

create procedure wiki_iri (in wai_name varchar)
{
  return forum_iri ('oWiki', wai_name);
};

create procedure feeds_iri (in wai_name varchar)
{
  return forum_iri ('eNews2', wai_name);
};

create procedure briefcase_iri (in wai_name varchar)
{
  return forum_iri ('oDrive', wai_name);
};

create procedure community_iri (in wai_name varchar)
{
  return forum_iri ('Community', wai_name);
};

create procedure bookmark_iri (in wai_name varchar)
{
  return forum_iri ('Bookmark', wai_name);
};

create procedure mail_iri (in wai_name varchar)
{
  return forum_iri ('oMail', wai_name);
};

create procedure photo_iri (in wai_name varchar)
{
  return forum_iri ('oGallery', wai_name);
};

create procedure fill_ods_sioc ()
{
  declare iri, site_iri, graph_iri varchar;

  site_iri  := get_graph ();
  graph_iri := get_graph ();

  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
-- XXX: this is for tests only
--  delete from DB.DBA.RDF_URL;
--  delete from DB.DBA.RDF_OBJ;

  set isolation='uncommitted';

  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      'http://rdfs.org/sioc/ns#Site');
  DB.DBA.RDF_QUAD_URI_L (graph_iri, site_iri, 'http://rdfs.org/sioc/ns#link', get_ods_link ());

  for select U_NAME, U_ID, U_E_MAIL, U_IS_ROLE from DB.DBA.SYS_USERS do
    {
      -- sioc:Usergroup
      if (U_IS_ROLE)
	{
	  iri := user_group_iri (U_ID);
	  if (iri is not null)
	    {
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
	      	'http://rdfs.org/sioc/ns#Usergroup');
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#name', U_NAME);
	    }
	}
      else -- sioc:User
	{
	  iri := user_iri (u_id);
	  if (iri is not null)
	    {
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
	      	'http://rdfs.org/sioc/ns#User');
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#name', U_NAME);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#link', iri);
	      -- it should be one row.
	      for select WAUI_FIRST_NAME, WAUI_LAST_NAME from DB.DBA.WA_USER_INFO where WAUI_U_ID = u_id do
		{
		  if (length (WAUI_FIRST_NAME))
		    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#first_name', WAUI_FIRST_NAME);
		  if (length (WAUI_LAST_NAME))
 		    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#last_name', WAUI_LAST_NAME);
		}

	      if (length (u_e_mail))
		{
		  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#email', 'mailto:'||u_e_mail);
		  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#email_sha1', sha1_digest (u_e_mail));
		}

	      for select WAI_ID, WAM_USER from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_USER = U_ID and WAM_INST = WAI_NAME do
		{
		  declare riri varchar;
		  riri := role_iri (WAI_ID, WAM_USER);
		  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_function', riri);
		}
	    }
	}
    }

  -- sioc:member_of
  for select GI_SUB, GI_SUPER from DB.DBA.SYS_ROLE_GRANTS where GI_DIRECT = 1 do
    {
      declare g_iri varchar;
      iri := user_iri (GI_SUPER);
      g_iri := user_group_iri (GI_SUB);
      if (iri is not null and g_iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#member_of', g_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, g_iri, 'http://rdfs.org/sioc/ns#has_member', iri);
        }
    }

  -- sioc:knows
  for select snr_from, snr_to from DB.DBA.sn_related do
    {
      declare _from_iri, _to_iri varchar;
      _from_iri := user_iri_ent (snr_from);
      _to_iri := user_iri_ent (snr_to);
      DB.DBA.RDF_QUAD_URI (graph_iri, _from_iri, 'http://rdfs.org/sioc/ns#knows', _to_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, _to_iri, 'http://rdfs.org/sioc/ns#knows', _from_iri);
    }

  -- sioc:Forum
  for select WAI_TYPE_NAME, WAI_ID, WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE do
    {
      iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      if (iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'http://rdfs.org/sioc/ns#Forum');
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#name', WAI_NAME);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#type', DB.DBA.wa_type_to_app (WAI_TYPE_NAME));
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#description', WAI_DESCRIPTION);
	  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, 'http://rdfs.org/sioc/ns#host_of', iri);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#link', iri);

	  for select WAM_USER from DB.DBA.WA_MEMBER where WAM_INST = WAI_NAME do
	    {
	      declare miri varchar;
	      miri := user_iri (WAM_USER);
	      if (miri is not null)
	        DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_member', miri);
	    }
	}
    }
  if (__proc_exists ('fill_ods_blog_sioc'))
    call ('fill_ods_blog_sioc') (graph_iri, site_iri);

  if (__proc_exists ('fill_ods_feeds_sioc'))
    call ('fill_ods_feeds_sioc') (graph_iri, site_iri);

  if (__proc_exists ('fill_ods_wiki_sioc'))
    call ('fill_ods_wiki_sioc') (graph_iri, site_iri);

  if (__proc_exists ('fill_ods_mail_sioc'))
    call ('fill_ods_mail_sioc') (graph_iri, site_iri);

  if (__proc_exists ('fill_ods_mail_sioc'))
    call ('fill_ods_photo_sioc') (graph_iri, site_iri);
  --fill_ods_dav_sioc (graph_iri, site_iri);
};

--
-- The bellow to be move in the apps scripts
--

-- DAV
create procedure fill_ods_dav_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, c_iri, f_iri varchar;
  for select U_NAME, U_ID from DB.DBA.SYS_USERS where U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0
    and U_DAV_ENABLE = 1 do
      {
	c_iri := user_iri (U_ID);
	for select RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER from
	  WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/home/' || U_NAME || '/%' and RES_OWNER = U_ID do
	    {
	      iri := dav_res_iri (RES_FULL_PATH);
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'http://rdfs.org/sioc/ns#Post');
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_creator', c_iri);
	      DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, 'http://rdfs.org/sioc/ns#creator_of', iri);

	      for select WAM_INST from DB.DBA.WA_MEMBER where WAM_USER = U_ID and WAM_APP_TYPE = 'oDrive' do
		{
		  f_iri := briefcase_iri (WAM_INST);
		  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_container', f_iri);
		  DB.DBA.RDF_QUAD_URI (graph_iri, f_iri, 'http://rdfs.org/sioc/ns#container_of', iri);
		}

	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#title', RES_NAME);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#link', iri);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#created_at', DB.DBA.date_iso8601 (RES_CR_TIME));
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#modified_at' , DB.DBA.date_iso8601 (RES_MOD_TIME));
	    }
      }
};


-- BLOG

DB.DBA.wa_exec_no_error('
create procedure blog_post_iri (in blog_id varchar, in post_id varchar)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };
  select U_NAME, BI_WAI_NAME into _member, _inst from DB.DBA.SYS_USERS, BLOG..SYS_BLOG_INFO, BLOG..SYS_BLOGS
      where BI_OWNER = U_ID and BI_BLOG_ID = B_BLOG_ID and B_BLOG_ID = blog_id and B_POST_ID = post_id;
  return sprintf (''http://%s%s/%U/weblog/%U/%U'', get_cname(), get_base_path (), _member, _inst, post_id);
}');

create procedure ods_sioc_post (
    in graph_iri varchar,
    in iri varchar,
    in forum_iri varchar,
    in cr_iri varchar,
    in title varchar,
    in ts any,
    in modf any,
    in link any := null,
    in content any := null
    )
{
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'http://rdfs.org/sioc/ns#Post');

      -- user
      if (cr_iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_creator', cr_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, cr_iri, 'http://rdfs.org/sioc/ns#creator_of', iri);
	}

      -- forum
      if (forum_iri is not null)
        {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, 'http://rdfs.org/sioc/ns#has_container', forum_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, 'http://rdfs.org/sioc/ns#container_of', iri);
        }

      -- literal data
      if (title is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#title', title);
      if (ts is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#created_at', DB.DBA.date_iso8601 (ts));
      if (modf is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#modified_at', DB.DBA.date_iso8601 (modf));

      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, 'http://rdfs.org/sioc/ns#link', coalesce (link, iri));
      -- XXX add content
};

DB.DBA.wa_exec_no_error('
create procedure fill_ods_blog_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, cr_iri, blog_iri varchar;
  for select B_BLOG_ID, B_POST_ID, BI_WAI_NAME, B_USER_ID, B_TITLE, B_TS, B_MODIFIED from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO
    where B_BLOG_ID = BI_BLOG_ID do
    {
      iri := blog_post_iri (B_BLOG_ID, B_POST_ID);
      blog_iri := blog_iri (BI_WAI_NAME);
      cr_iri := user_iri (B_USER_ID);
      ods_sioc_post (graph_iri, iri, blog_iri, cr_iri, B_TITLE, B_TS, B_MODIFIED);
    }
}');

-- ENEWS

-- the same as feeds_iri (wai_name)
create procedure feed_mgr_iri (in domain_id int)
{
  declare inst varchar;
  declare exit handler for not found { return null; };
  select WAI_NAME into inst from DB.DBA.WA_INSTANCE where WAI_ID = domain_id;
  return feeds_iri (inst);
};

-- this represents post in the given feed
create procedure feeds_post_iri (in feed_id int, in item_id int)
{
  declare feed_title, item_title varchar;
  declare exit handler for not found { return null; };
  return sprintf ('http://%s%s/feed/%d/%d', get_cname(), get_base_path (), feed_id, item_id);
};

-- this represents a feed, not an instance
create procedure feed_iri (in feed_id int)
{
  return sprintf ('http://%s%s/feed/%d', get_cname(), get_base_path (), feed_id);
};

DB.DBA.wa_exec_no_error('
create procedure fill_ods_feeds_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, m_iri, f_iri varchar;
  for select EFD_ID, EFD_DOMAIN_ID, EFD_FEED_ID, EFD_TITLE, EF_ID, EF_URI, EF_HOME_URI, EF_SOURCE_URI, EF_TITLE, EF_DESCRIPTION
    from ENEWS..FEED_DOMAIN, ENEWS..FEED where EFD_FEED_ID = EF_ID do
    {
      iri := feed_iri (EF_ID);
      m_iri := feed_mgr_iri (EFD_DOMAIN_ID);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, ''http://rdfs.org/sioc/ns#has_container'', m_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, m_iri, ''http://rdfs.org/sioc/ns#parent_of'', iri);
    }
  for select EFI_FEED_ID, EFI_ID, EFI_TITLE, EFI_DESCRIPTION, EFI_LINK, EFI_AUTHOR,  EFI_PUBLISH_DATE from ENEWS..FEED_ITEM do
    {
      iri := feeds_post_iri (EFI_FEED_ID, EFI_ID);
      f_iri := feed_iri (EFI_FEED_ID);
      ods_sioc_post (graph_iri, iri, f_iri, null, EFI_TITLE, EFI_PUBLISH_DATE, null, EFI_LINK);
    }
}');

-- Wiki
DB.DBA.wa_exec_no_error('
create procedure wiki_post_iri (in cluster_id int, in localname varchar)
{
  declare _inst, owner varchar;
  declare exit handler for not found { return null; };
  select top 1 ClusterName, U_NAME into _inst, owner from WV..CLUSTERS, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where ClusterId = cluster_id
      and ClusterName = WAM_INST and U_ID = WAM_USER;
  return sprintf (''http://%s%s/%U/wiki/%U/%U'', get_cname(), get_base_path (), owner, _inst, localname);
}');

DB.DBA.wa_exec_no_error('
create procedure wiki_cluster_iri (in cluster_id int)
{
  declare _inst, owner varchar;
  declare exit handler for not found { return null; };
  select top 1 ClusterName, U_NAME into _inst, owner from WV..CLUSTERS, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where ClusterId = cluster_id
      and ClusterName = WAM_INST and U_ID = WAM_USER;
  return sprintf (''http://%s%s/%U/wiki/%U'', get_cname(), get_base_path (), owner, _inst);
}');

DB.DBA.wa_exec_no_error ('
create procedure fill_ods_wiki_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, c_iri varchar;
  for select ClusterId, LocalName, TitleText, T_OWNER_ID, T_CREATE_TIME, T_PUBLISHED from WV..TOPIC do
    {
      iri := wiki_post_iri (ClusterId, LocalName);
      c_iri := wiki_cluster_iri (ClusterId);
      if (iri is not null)
	{
	  ods_sioc_post (graph_iri, iri, c_iri, null, coalesce (TitleText, LocalName), T_CREATE_TIME, null);
        }
    }
}');



-- Mail

create procedure mail_post_iri (in domain_id int, in user_id int, in msg_id int)
{
  declare owner varchar;
  declare exit handler for not found { return null; };
  select U_NAME into owner from DB.DBA.SYS_USERS where U_ID = user_id;
  return sprintf ('http://%s%s/%U/mail/%d', get_cname(), get_base_path (), owner, msg_id);
};

DB.DBA.wa_exec_no_error('
create procedure fill_ods_mail_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, c_iri varchar;
  for select DOMAIN_ID, USER_ID, MSG_ID, SUBJECT, SND_DATE, UNIQ_MSG_ID from OMAIL..MESSAGES do
    {
      iri := mail_post_iri (DOMAIN_ID, USER_ID, MSG_ID);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, ''http://www.w3.org/1999/02/22-rdf-syntax-ns#type'', ''http://rdfs.org/sioc/ns#Post'');
      for select WAM_INST from DB.DBA.WA_MEMBER where WAM_USER = USER_ID and WAM_MEMBER_TYPE = 1 and  WAM_APP_TYPE = ''oMail''
	do
	  {
	    c_iri := mail_iri (WAM_INST);
	    DB.DBA.RDF_QUAD_URI (graph_iri, iri, ''http://rdfs.org/sioc/ns#has_container'', c_iri);
	    DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, ''http://rdfs.org/sioc/ns#container_of'', iri);
	  }
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, ''http://rdfs.org/sioc/ns#title'', SUBJECT);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, ''http://rdfs.org/sioc/ns#created_at'', DB.DBA.date_iso8601 (SND_DATE));
    }
}');

create procedure dav_res_iri (in path varchar)
{
  return sprintf ('http://%s%s', get_cname(), path);
};

-- Photo

DB.DBA.wa_exec_no_error('
create procedure fill_ods_photo_sioc (in graph_iri varchar, in site_iri varchar)
{
  declare iri, c_iri, creator_iri varchar;
  for select OWNER_ID, WAI_NAME, HOME_PATH from PHOTO..SYS_INFO do
    {
      c_iri := photo_iri (WAI_NAME);
      for select RES_FULL_PATH, RES_NAME, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_OWNER
	from WS.WS.SYS_DAV_RES where RES_FULL_PATH like HOME_PATH || ''%'' and RES_FULL_PATH not like HOME_PATH || ''%/.thumbnails/%''
	do
	  {
	    iri := dav_res_iri (RES_FULL_PATH);
	    creator_iri := user_iri (RES_OWNER);
	    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, RES_NAME, RES_CR_TIME, RES_MOD_TIME, null);
	  }
    }
}');

-- Briefcase/DAV

-- Bookmark

-- load all (on init time)
DB.DBA.wa_exec_no_error('fill_ods_sioc ()');

create procedure exec_sparql (in qry varchar)
{
  declare state, msg, maxrows, metas, rset any;
  declare ses any;

  maxrows := 0;
  state := '00000';
  exec (qry, state, msg, vector(), maxrows, metas, rset);
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, '', 1);
  return string_output_string (ses);
};

use DB;

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
   values ('ODS_SIOC_RDF', cast (stringtime ('0:0') as DATETIME), concat ('sioc.DBA.fill_ods_sioc ()'), 10)
;

