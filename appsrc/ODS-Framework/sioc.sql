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

create procedure make_href (in u varchar)
{
  return WS.WS.EXPAND_URL (sprintf ('http://%s/', get_cname ()), u);
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
  declare _role, inst, _member, tp, m_type any;
  declare exit handler for not found { return null; };


  select WAI_NAME, U_NAME, WAI_TYPE_NAME, WAM_MEMBER_TYPE into inst, _member, tp, m_type
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAI_ID = _wai_id
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;

  _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = tp and WMT_ID = m_type);

  if (_role is null and m_type = 1)
    _role := 'owner';

  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure role_iri_by_name (in _wai_name varchar, in _wam_member_id int)
{
  declare _role, inst, _member, tp, m_type any;
  declare exit handler for not found { return null; };

  select WAM_INST, U_NAME, WAM_APP_TYPE, WAM_MEMBER_TYPE into inst, _member, tp, m_type
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where WAM_INST = _wai_name
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;

  _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = tp and WMT_ID = m_type);

  if (_role is null and m_type = 1)
    _role := 'owner';

  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure forum_iri (in inst_type varchar, in wai_name varchar)
{
  declare _member, tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  declare exit handler for not found { return null; };
  if (inst_type = 'nntpf')
    return sprintf ('http://%s%s/%U/%U', get_cname(), get_base_path (), tp, wai_name);

  select U_NAME into _member from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_INST = wai_name and WAM_USER = U_ID and WAM_MEMBER_TYPE = 1;
  return sprintf ('http://%s%s/%U/%U/%U', get_cname(), get_base_path (), _member, tp, wai_name);
};

create procedure post_iri (in u_name varchar, in inst_type varchar, in wai_name varchar, in post_id varchar)
{
  declare tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  return sprintf ('http://%s%s/%U/%U/%U/%U', get_cname(), get_base_path (), u_name, tp, wai_name, post_id);
};

create procedure forum_iri_n (in inst_type varchar, in wai_name varchar, in n_wai_name varchar)
{
  declare _member, tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  declare exit handler for not found { return null; };
  select U_NAME into _member from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_INST = wai_name and WAM_USER = U_ID and WAM_MEMBER_TYPE = 1;
  return sprintf ('http://%s%s/%U/%U/%U', get_cname(), get_base_path (), _member, tp, n_wai_name);
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

create procedure xd_iri (in wai_name varchar)
{
  return forum_iri ('Community', wai_name);
};

create procedure bmk_iri (in wai_name varchar)
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

create procedure nntp_iri (in grp varchar)
{
  return forum_iri ('nntpf', grp);
};

create procedure ods_sioc_clean_all ()
{
  declare graph_iri varchar;
  graph_iri := get_graph ();
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
};

create procedure ods_graph_init ()
{
  declare iri, site_iri, graph_iri varchar;
  set isolation='uncommitted';
  site_iri  := get_graph ();
  graph_iri := get_graph ();
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, rdf_iri ('type'),
      sioc_iri ('Site'));
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, sioc_iri ('link'), get_ods_link ());
  return;
};

create procedure ods_sioc_init ()
{
  if (registry_get ('__ods_sioc_init') = 'done')
    return;
  fill_ods_sioc ();
  registry_set ('__ods_sioc_init', 'done');
  return;
};

create procedure foaf_iri (in s varchar)
{
  return concat ('http://xmlns.com/foaf/0.1/#', s);
};

create procedure sioc_iri (in s varchar)
{
  return concat ('http://rdfs.org/sioc/ns#', s);
};

create procedure rdf_iri (in s varchar)
{
  return concat ('http://www.w3.org/1999/02/22-rdf-syntax-ns#', s);
};

create procedure rdfs_iri (in s varchar)
{
  return concat ('http://www.w3.org/2000/01/rdf-schema#', s);
};

create procedure geo_iri (in s varchar)
{
  return concat ('http://www.w3.org/2003/01/geo/wgs84_pos#', s);
};

create procedure atom_iri (in s varchar)
{
  return concat ('http://atomowl.org/ontologies/atomrdf#', s);
};

-- User
create procedure sioc_user (in graph_iri varchar, in iri varchar, in u_name varchar, in u_e_mail varchar, in full_name varchar := null)
{
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('User'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), U_NAME);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);

  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (u_e_mail));
    }

  -- FOAF
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Person'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('nick'), u_name);
  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }

  delete_quad_sp (graph_iri, iri, foaf_iri ('name'));
  if (length (full_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), full_name);

  -- ATOM
  delete_quad_sp (graph_iri, iri, atom_iri ('personEmail'));
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Person'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('personName'), u_name);
  if (length (u_e_mail))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('personEmail'), u_e_mail);

};

create procedure sioc_user_info (
    in graph_iri varchar, in iri varchar, in waui_first_name varchar, in waui_last_name varchar,
    in title varchar := null,
    in full_name varchar := null,
    in gender varchar := null,
    in icq varchar := null,
    in msn varchar := null,
    in aim varchar := null,
    in yahoo varchar := null,
    in birthday datetime := null,
    in org varchar := null,
    in phone varchar := null,
    in lat float := null,
    in lng float := null,
    in webpage varchar := null
    )
{
  if (iri is null)
    return;

  delete_quad_sp (graph_iri, iri, sioc_iri ('first_name'));
  delete_quad_sp (graph_iri, iri, sioc_iri ('last_name'));

  if (length (waui_first_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('first_name'), waui_first_name);
  if (length (waui_last_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('last_name'), waui_last_name);

  delete_quad_sp (graph_iri, iri, foaf_iri ('firstName'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('family_name'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('gender'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('icqChatID'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('msnChatID'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('aimChatID'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('yahooChatID'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('birthday'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('organization'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('phone'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('based_near'));

  if (length (waui_first_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('firstName'), waui_first_name);
  if (length (waui_last_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('family_name'), waui_last_name);

  if (length (gender))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('gender'), gender);
  if (length (icq))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('icqChatID'), icq);
  if (length (msn))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('msnChatID'), msn);
  if (length (aim))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('aimChatID'), aim);
  if (length (yahoo))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('yahooChatID'), yahoo);
  if (birthday is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('birthday'), substring (datestring(coalesce (birthday, now())), 6, 5));
  if (length (org))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('organization'), org);
  if (length (phone))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || phone);
  if (lat is not null and lng is not null)
    {
      declare giri varchar;
      giri := iri || '#based_near';

      DB.DBA.RDF_QUAD_URI (graph_iri, giri, rdf_iri ('type'), geo_iri ('Point'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('based_near'), giri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, giri, geo_iri ('lat'), sprintf ('%.06f', coalesce (lat, 0)));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, giri, geo_iri ('long'), sprintf ('%.06f', coalesce (lng, 0)));
    }
  --if (length (webpage))
  --  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri (''), webpage);

};

-- Group

create procedure sioc_group (in graph_iri varchar, in iri varchar, in u_name varchar)
{
  if (iri is not null)
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Usergroup'));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), u_name);
    }
};

-- Knows

create procedure sioc_knows (in graph_iri varchar, in _from_iri varchar, in _to_iri varchar)
{
  DB.DBA.RDF_QUAD_URI (graph_iri, _from_iri, sioc_iri ('knows'), _to_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, _to_iri, sioc_iri ('knows'), _from_iri);

  DB.DBA.RDF_QUAD_URI (graph_iri, _from_iri, foaf_iri ('knows'), _to_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, _to_iri, foaf_iri ('knows'), _from_iri);
};

-- Forum

create procedure sioc_forum (
    	in graph_iri varchar,
	in site_iri varchar,
        in iri varchar,
     	in wai_name varchar,
    	in wai_type_name varchar,
	in wai_description varchar)
{
  if (iri is null)
    return;
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Forum'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), wai_name);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('type'), DB.DBA.wa_type_to_app (wai_type_name));
  if (wai_description is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('description'), wai_description);
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, sioc_iri ('host_of'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_host'), site_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);

  -- ATOM
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('FeedInstance'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), wai_name);
};

create procedure sioc_date (in d any)
{
  declare str any;
  str := DB.DBA.date_iso8601 (dt_set_tz (d, 0));
  return substring (str, 1, 19) || 'Z';
};

create procedure ods_sioc_post (
    in graph_iri varchar,
    in iri varchar,
    in forum_iri varchar,
    in cr_iri varchar,
    in title varchar,
    in ts any,
    in modf any,
    in link any := null,
    in content any := null,
    in tags varchar := null
    )
{

      if (iri is null)
	return;

      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));

      -- user
      if (cr_iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_creator'), cr_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, cr_iri, sioc_iri ('creator_of'), iri);
	}

      -- forum
      if (forum_iri is not null)
        {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), forum_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), iri);
        }

      -- literal data
      if (title is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('title'), title);
      if (ts is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('created_at'), sioc_date(ts));
      if (modf is not null)
	{
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('modified_at'), sioc_date(modf));
	  if (ts is null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('created_at'), sioc_date(modf));
	}

      if (link is not null)
	link := make_href (link);

      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);
      if (link is not null)
        DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('links_to'), link);

      -- ATOM
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('EntryInstance'));
      if (forum_iri is not null)
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('containingFeed'), forum_iri);
      if (title is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), title);
      if (cr_iri is not null)
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('author'), cr_iri);
      if (ts is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('published'), sioc_date (ts));
      if (modf is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('updated'), sioc_date (modf));
      if (link is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, link, rdf_iri ('type'), atom_iri ('Link'));
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('link'), link);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, link, atom_iri ('LinkHref'), link);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, link, atom_iri ('linkRel'), 'alternate');
	}

      return;
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

  ods_graph_init ();

  for select U_NAME, U_ID, U_E_MAIL, U_IS_ROLE, U_FULL_NAME
    from DB.DBA.SYS_USERS
	where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' do
    {
      -- sioc:Usergroup
      if (U_IS_ROLE)
	{
	  iri := user_group_iri (U_ID);
	  sioc_group (graph_iri, iri, U_NAME);
	}
      else -- sioc:User
	{
	  iri := user_iri (u_id);
	  if (iri is not null)
	    {
	      sioc_user (graph_iri, iri, U_NAME, U_E_MAIL, U_FULL_NAME);
	      -- it should be one row.
	      for select WAUI_FIRST_NAME, WAUI_LAST_NAME, WAUI_TITLE,
		WAUI_GENDER, WAUI_ICQ, WAUI_MSN, WAUI_AIM, WAUI_YAHOO, WAUI_BIRTHDAY,
		    WAUI_BORG, WAUI_HPHONE, WAUI_HMOBILE, WAUI_BPHONE, WAUI_LAT,
		    WAUI_LNG, WAUI_WEBPAGE
		from DB.DBA.WA_USER_INFO where WAUI_U_ID = u_id do
		{
		  sioc_user_info (graph_iri, iri, WAUI_FIRST_NAME, WAUI_LAST_NAME,
		      WAUI_TITLE, U_FULL_NAME, WAUI_GENDER, WAUI_ICQ, WAUI_MSN, WAUI_AIM, WAUI_YAHOO, WAUI_BIRTHDAY, WAUI_BORG,
	              	case when length (WAUI_HPHONE) then WAUI_HPHONE
		      	when length (WAUI_HMOBILE) then WAUI_HMOBILE else  WAUI_BPHONE end,
			WAUI_LAT,
			WAUI_LNG,
			WAUI_WEBPAGE
			);
		}


	      for select WAI_NAME, WAI_TYPE_NAME, WAI_ID, WAM_USER
		from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
		    where WAM_USER = U_ID and WAM_INST = WAI_NAME do
		{
		  declare riri, firi varchar;
		  riri := role_iri (WAI_ID, WAM_USER);
		  firi := forum_iri (WAI_TYPE_NAME, WAI_NAME);
		  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_function'), riri);
		  DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
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
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('member_of'), g_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, g_iri, sioc_iri ('has_member'), iri);
        }
    }

  -- sioc:knows
  for select snr_from, snr_to from DB.DBA.sn_related do
    {
      declare _from_iri, _to_iri varchar;
      _from_iri := user_iri_ent (snr_from);
      _to_iri := user_iri_ent (snr_to);
      sioc_knows (graph_iri, _from_iri, _to_iri);
    }

  -- sioc:Forum
  for select WAI_TYPE_NAME, WAI_ID, WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE do
    {
      iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      if (iri is not null)
	{
	  sioc_forum (graph_iri, site_iri, iri, WAI_NAME, WAI_TYPE_NAME, WAI_DESCRIPTION);

	  for select WAM_USER from DB.DBA.WA_MEMBER where WAM_INST = WAI_NAME do
	    {
	      declare miri varchar;
	      miri := user_iri (WAM_USER);
	      if (miri is not null)
	        DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_member'), miri);
	    }
	}
    }
  if (__proc_exists ('sioc..fill_ods_blog_sioc'))
    call ('sioc..fill_ods_blog_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_feeds_sioc'))
    call ('sioc..fill_ods_feeds_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_wiki_sioc'))
    call ('sioc..fill_ods_wiki_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_mail_sioc'))
    call ('sioc..fill_ods_mail_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_photo_sioc'))
    call ('sioc..fill_ods_photo_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_nntp_sioc'))
    call ('sioc..fill_ods_nntp_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_bmk_sioc'))
    call ('sioc..fill_ods_bmk_sioc') (graph_iri, site_iri);

  if (__proc_exists ('sioc..fill_ods_xd_sioc'))
    call ('sioc..fill_ods_xd_sioc') (graph_iri, site_iri);
  --fill_ods_dav_sioc (graph_iri, site_iri);
};


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
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_creator'), c_iri);
	      DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, sioc_iri ('creator_of'), iri);

	      for select WAM_INST from DB.DBA.WA_MEMBER where WAM_USER = U_ID and WAM_APP_TYPE = 'oDrive' do
		{
		  f_iri := briefcase_iri (WAM_INST);
		  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), f_iri);
		  DB.DBA.RDF_QUAD_URI (graph_iri, f_iri, sioc_iri ('container_of'), iri);
		}

	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('title'), RES_NAME);
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('created_at'), sioc_date (RES_CR_TIME));
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('modified_at') , sioc_date (RES_MOD_TIME));
	    }
      }
};


create procedure nntp_post_iri (in grp varchar, in msgid varchar)
{
  return sprintf ('http://%s%s/discussion/%U/%U', get_cname(), get_base_path (), grp, msgid);
};


create procedure dav_res_iri (in path varchar)
{
  return sprintf ('http://%s%s', get_cname(), path);
};

create procedure delete_quad_so (in _g any, in _s any, in _o any)
{
  _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_MAKE_IID_OF_QNAME (_s);
  _o := DB.DBA.RDF_MAKE_IID_OF_QNAME (_o);
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and O = _o;
};

create procedure delete_quad_sp (in _g any, in _s any, in _p any)
	{
  _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_MAKE_IID_OF_QNAME (_s);
  _p := DB.DBA.RDF_MAKE_IID_OF_QNAME (_p);
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and P = _p;
};

create procedure delete_quad_s_p_o (in _g any, in _s any, in _p any, in _o any)
        {
  _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_MAKE_IID_OF_QNAME (_s);
  _p := DB.DBA.RDF_MAKE_IID_OF_QNAME (_p);
  _o := DB.DBA.RDF_MAKE_IID_OF_QNAME (_o);
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and P = _p and O = _o;
};

create procedure delete_quad_s_or_o (in _g any, in _s any, in _o any)
{
  _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_MAKE_IID_OF_QNAME (_s);
  _o := DB.DBA.RDF_MAKE_IID_OF_QNAME (_o);
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s;
  delete from DB.DBA.RDF_QUAD where G = _g and O = _o;
};

create procedure update_quad_s_o (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null)
    return;
  _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_MAKE_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set S = _n where G = _g and S = _o;
  update DB.DBA.RDF_QUAD set O = _n where G = _g and O = _o;
};

create procedure update_quad_p (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null)
    return;
  _g := DB.DBA.RDF_MAKE_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_MAKE_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set P = _n where G = _g and P = _o;
};

create procedure sioc_log_message (in msg varchar)
    {
  if (0) log_message (msg);
};

-- SYS_USERS

create trigger SYS_USERS_SIOC_I after insert on DB.DBA.SYS_USERS referencing new as N
{
  declare iri, graph_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};

  graph_iri := get_graph ();

  if (N.U_ACCOUNT_DISABLED = 1)
    return;
  iri := user_obj_iri (N.U_NAME);
  if (N.U_IS_ROLE)
{
      sioc_group (graph_iri, iri, N.U_NAME);
    }
  else
    {
      sioc_user (graph_iri, iri, N.U_NAME, N.U_E_MAIL, N.U_FULL_NAME);
    }
  return;
};

create trigger SYS_USERS_SIOC_U after update on DB.DBA.SYS_USERS referencing old as O, new as N
{
  declare oiri, iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};
  graph_iri := get_graph ();

  if (N.U_ACCOUNT_DISABLED = 1) -- tdb erase
    return;
  iri := user_obj_iri (N.U_NAME);
  oiri := user_obj_iri (O.U_NAME);
  if (N.U_IS_ROLE = 0)
{
      delete_quad_sp (graph_iri, oiri, sioc_iri ('email'));
      delete_quad_sp (graph_iri, oiri, sioc_iri ('email_sha1'));

      delete_quad_sp (graph_iri, oiri, foaf_iri ('name'));
      delete_quad_sp (graph_iri, oiri, foaf_iri ('mbox'));
      delete_quad_sp (graph_iri, oiri, foaf_iri ('mbox_sha1sum'));

      if (length (N.U_E_MAIL))
    {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (N.U_E_MAIL));

	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (N.U_E_MAIL));
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), N.U_FULL_NAME);
    }
    }
  return;
};

create trigger SYS_USERS_SIOC_D after delete on DB.DBA.SYS_USERS referencing old as O
{
  declare iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (O.U_ACCOUNT_DISABLED = 1)
    return;

  graph_iri := get_graph ();
  iri := user_obj_iri (O.U_NAME);

  delete_quad_s_or_o (graph_iri, iri, iri);

  return;
};

-- DB.DBA.WA_USER_INFO

create trigger WA_USER_INFO_SIOC_I after insert on DB.DBA.WA_USER_INFO referencing new as N
{
  declare iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  sioc_user_info (graph_iri, iri, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME);
  return;
};

create trigger WA_USER_INFO_SIOC_U after update on DB.DBA.WA_USER_INFO referencing old as O, new as N
    {
  declare iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  sioc_user_info (graph_iri, iri, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME);
		  sioc_user_info (graph_iri, iri, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME,
		      N.WAUI_TITLE, null, N.WAUI_GENDER, N.WAUI_ICQ, N.WAUI_MSN, N.WAUI_AIM, N.WAUI_YAHOO,
		      N.WAUI_BIRTHDAY, N.WAUI_BORG,
	              	case when length (N.WAUI_HPHONE) then N.WAUI_HPHONE
		      	when length (N.WAUI_HMOBILE) then N.WAUI_HMOBILE else  N.WAUI_BPHONE end,
			N.WAUI_LAT,
			N.WAUI_LNG,
			N.WAUI_WEBPAGE
			);
  return;
};

-- DB.DBA.WA_MEMBER
create trigger WA_MEMBER_SIOC_I after insert on DB.DBA.WA_MEMBER referencing new as N
	{
  declare iri, graph_iri, riri, firi, site_iri varchar;
--  dbg_obj_print (current_proc_name ());
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();


  if (N.WAM_MEMBER_TYPE = 1)
    {
      site_iri  := get_graph ();
      iri := forum_iri (N.WAM_APP_TYPE, N.WAM_INST);
      sioc_forum (graph_iri, site_iri, iri, N.WAM_INST, N.WAM_APP_TYPE, null);
    }

  iri :=  user_iri (N.WAM_USER);
  riri := role_iri_by_name (N.WAM_INST, N.WAM_USER);
  firi := forum_iri (N.WAM_APP_TYPE, N.WAM_INST);
  if (iri is not null and riri is not null and firi is not null)
{
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_function'), riri);
      DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
      DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('has_member'), iri);
    }
  return;
};

create trigger WA_MEMBER_SIOC_D before delete on DB.DBA.WA_MEMBER referencing old as O
{
  declare iri, graph_iri, riri, firi varchar;
--  dbg_obj_print (current_proc_name ());
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  if (O.WAM_MEMBER_TYPE = 1) -- instance drop
	  {
      firi := forum_iri (O.WAM_APP_TYPE, O.WAM_INST);
--      dbg_obj_print ('firi:',firi);
      delete_quad_s_or_o (graph_iri, firi, firi);
	  }

  iri :=  user_iri (O.WAM_USER);
  riri := role_iri_by_name (O.WAM_INST, O.WAM_USER);
  if (iri is not null and riri is not null)
    {
      delete_quad_so (graph_iri, iri, riri);
    }
  return;
};

-- DB.DBA.WA_INSTANCE

-- INSERT and delete are DONE IN THE WA_MEMBER WHEN INSERT THE OWNER

create trigger WA_INSTANCE_SIOC_U before update on DB.DBA.WA_INSTANCE referencing old as O, new as N
{
  declare oiri, graph_iri, iri, riri, oriri varchar;
  --dbg_obj_print (current_proc_name ());
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};

  graph_iri := get_graph ();

  iri := forum_iri_n (O.WAI_TYPE_NAME, O.WAI_NAME, N.WAI_NAME);
  oiri := forum_iri (O.WAI_TYPE_NAME, O.WAI_NAME);

  delete_quad_sp (graph_iri, oiri, sioc_iri ('name'));
  delete_quad_sp (graph_iri, oiri, sioc_iri ('link'));

  update_quad_s_o (graph_iri, oiri, iri);

  for select distinct WAM_MEMBER_TYPE as tp from DB.DBA.WA_MEMBER where WAM_INST = O.WAI_NAME do
{
      declare _role varchar;
      _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = O.WAI_NAME and WMT_ID = tp);

      if (_role is null and tp = 1)
	_role := 'owner';

      riri := iri || '#' || _role;
      oriri := oiri || '#' || _role;
      update_quad_s_o (graph_iri, oriri, riri);
    }

  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), N.WAI_NAME);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);
};


-- DB.DBA.SYS_ROLE_GRANTS
create trigger SYS_ROLE_GRANTS_SIOC_I after insert on DB.DBA.SYS_ROLE_GRANTS referencing new as N
    {
  declare iri, graph_iri, g_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.GI_SUPER);
  g_iri := user_group_iri (N.GI_SUB);
  if (iri is not null and g_iri is not null)
	  {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('member_of'), g_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, g_iri, sioc_iri ('has_member'), iri);
	  }
  return;
};


create trigger SYS_ROLE_GRANTS_SIOC_D before delete on DB.DBA.SYS_ROLE_GRANTS referencing old as O
{
  declare iri, graph_iri, g_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (O.GI_SUPER);
  g_iri := user_group_iri (O.GI_SUB);
  if (iri is not null and g_iri is not null)
    {
      delete_quad_s_p_o (graph_iri, iri, sioc_iri ('member_of'), g_iri);
      delete_quad_s_p_o (graph_iri, g_iri, sioc_iri ('member_of'), iri);
    }
  return;
};


-- DB.DBA.sn_related
create trigger sn_related_SIOC_I after insert on DB.DBA.sn_related referencing new as N
{
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  declare _from_iri, _to_iri, graph_iri varchar;

  graph_iri := get_graph ();
  _from_iri := user_iri_ent (N.snr_from);
  _to_iri := user_iri_ent (N.snr_to);
  sioc_knows (graph_iri, _from_iri, _to_iri);
  return;
};

create trigger sn_related_SIOC_D before delete on DB.DBA.sn_related referencing old as O
{
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  declare _from_iri, _to_iri, graph_iri varchar;

  graph_iri := get_graph ();
  _from_iri := user_iri_ent (O.snr_from);
  _to_iri := user_iri_ent (O.snr_to);
  delete_quad_s_p_o (graph_iri, _from_iri, sioc_iri ('knows'), _to_iri);
  delete_quad_s_p_o (graph_iri, _to_iri, sioc_iri ('knows'), _from_iri);
  return;
};

create procedure rdf_head (inout ses any)
{
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">', ses);
};

create procedure rdf_tail (inout ses any)
{
  http ('</rdf:RDF>', ses);
};

create procedure sioc_compose_xml (in u_name varchar, in wai_name varchar, in inst_type varchar, in postid varchar := null)
{
  declare state, tp, qry, msg, maxrows, metas, rset, graph, iri any;
  declare ses any;

--  dbg_obj_print (u_name,wai_name,inst_type,postid);
  graph := get_graph ();
  ses := string_output ();

  if (inst_type = 'users')
    inst_type := null;

  if (wai_name is null and inst_type is null and postid is null)
    {
      iri := user_obj_iri (u_name);
      qry := sprintf ('sparql ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/#> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' construct { ?s ?p ?o } \n' ||
         ' from <%s> where { { \n' ||
	 '   ?s ?p ?o . ?s sioc:name "%s" FILTER (sql:ODS_FILTER_USER (?p, ?o)) } union  \n' ||
         '   { ?s sioc:has_member ?member . ?member sioc:name "%s" . ?s ?p ?o  filter sql:ODS_FILTER_USER_FORUM (?p, ?o, "%s/%s") } } '||
	 ' ',
	 graph, u_name, u_name, graph, u_name);
    }
  else if (wai_name is null and postid is null)
    {
      tp := DB.DBA.wa_type_to_app (inst_type);
      iri := user_obj_iri (u_name);
      qry := sprintf ('sparql ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/#> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' construct { ?s ?p ?o } \n' ||
         ' from <%s> where { \n' ||
         '    ?s sioc:has_member ?member  . ?member sioc:name "%s" . ?s ?p ?o . ?s sioc:type "%s"'||
	 '    FILTER sql:ODS_FILTER_USER_FORUM (?p, ?o, "%s/%s") '||
	 ' } ',
	 graph, u_name, tp, graph, u_name);
    }
  else if (postid is null)
    {
      declare triples, num any;
      declare lim any;

      lim := coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
      tp := DB.DBA.wa_type_to_app (inst_type);

      iri := forum_iri (inst_type, wai_name);
      rdf_head (ses);
      triples := (sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
          construct { ?s ?p ?o } where
            	{
		  graph ?:graph
		  {
		    ?s ?p ?o . ?s sioc:host_of ?forum . ?forum sioc:name ?:wai_name
		    FILTER sql:ODS_FILTER_FORUM_SITE (?p, ?o, ?:iri)
		  }
		}
	    );
      rset := dict_list_keys (triples, 1);
      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);

      triples := (sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
          construct { ?s ?p ?o } where
            	{
		  graph ?:graph
		  {
		    ?s ?p ?o .
		    ?s sioc:name ?:wai_name
		    FILTER sql:ODS_FILTER_FORUM (?p, ?o)
		  }
		}
	    );
      rset := dict_list_keys (triples, 1);
      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);

      if (tp = 'feeds' or tp = 'community')
	{
      qry := sprintf ('sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
   	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          construct
    {
		?forum sioc:container_of ?post .
		?post  sioc:has_container ?forum .
		    ?forum sioc:has_parent ?pforum .
		    ?pforum sioc:parent_of ?forum .
		?post rdf:type sioc:Post .
		?post sioc:title ?title .
		?post sioc:link ?link .
		?post sioc:links_to ?links_to .
		?post sioc:modified_at ?modified .
		?post sioc:created_at ?created .
		?post sioc:has_creator ?creator
	   }
	  where
                {
                  graph <%s>
                  {
			?pforum sioc:name "%s" .
			?pforum sioc:parent_of ?forum .
                    ?post sioc:has_container ?forum .
                    optional { ?post sioc:modified_at ?modified } .
                    optional { ?post sioc:created_at ?created } .
		    optional { ?post sioc:links_to ?links_to } .
		    optional { ?post sioc:link ?link } .
		    optional { ?post sioc:has_creator ?creator } .
			optional { ?post sioc:title ?title }
		      }
		    }
		    order by desc (?created) limit %d
		', graph, wai_name, lim);
	}
      else
	{
	  qry := sprintf ('sparql
	      prefix sioc: <http://rdfs.org/sioc/ns#>
	      prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	      prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	      construct
	       {
		    ?forum sioc:container_of ?post .
		    ?post  sioc:has_container ?forum .
		    ?post rdf:type sioc:Post .
		    ?post sioc:title ?title  .
		    ?post sioc:link ?link .
		    ?post sioc:links_to ?links_to .
		    ?post sioc:modified_at ?modified .
		    ?post sioc:created_at ?created .
		    ?post sioc:has_creator ?creator .
		    ?post sioc:reply_of ?reply .
		    ?reply sioc:has_reply ?post .
		    ?post sioc:topic ?topic . ?topic rdfs:label ?label
	       }
	      where
		    {
		      graph <%s>
		      {
			?forum sioc:name "%s" .
			?post sioc:has_container ?forum .
			optional { ?post sioc:modified_at ?modified } .
			optional { ?post sioc:created_at ?created } .
			optional { ?post sioc:links_to ?links_to } .
			optional { ?post sioc:link ?link } .
			optional { ?post sioc:has_creator ?creator } .
			optional { ?post sioc:reply_of ?reply } .
			optional { ?post sioc:title ?title } .
			optional { ?post sioc:topic ?topic . ?topic rdfs:label ?label } .
                  }
                }
                order by desc (?created) limit %d
	    ', graph, wai_name, lim);
	}
      rset := null;
      maxrows := 0;
      state := '00000';
      set_user_id ('dba');
--      dbg_printf ('%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
      if (state = '00000')
		  {
	  triples := rset[0][0];
      rset := dict_list_keys (triples, 1);
      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
        }
      rdf_tail (ses);
      goto ret;
    }
  else -- the post
    {
      iri := post_iri (u_name, inst_type, wai_name, postid);
      qry := sprintf ('sparql ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' construct { <%s> rdf:type sioc:Post . <%s> ?p ?o }  \n' ||
         ' from <%s> where { \n' ||
	 '   <%s> ?p ?o . ' ||
	 ' FILTER regex (?p, "^http://rdfs.org/sioc/ns#*") \n' ||
	 ' } ',
	 iri, iri, graph, iri);
    }

  maxrows := 0;
  state := '00000';
  --dbg_printf ('%s', qry);
  set_user_id ('dba');
  exec (qry, state, msg, vector(), maxrows, metas, rset);
--  dbg_obj_print (msg);
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, '', 1);

ret:
  return ses;
};

DB.DBA.wa_exec_no_error('ods_sioc_init ()');

use DB;

create procedure ODS_FILTER_FORUM (in p any, in o any)
{
  if (p = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' and o = 'http://rdfs.org/sioc/ns#Forum')
    return 1;
  else if (p like 'http://rdfs.org/sioc/ns#%' and p <> 'http://rdfs.org/sioc/ns#container_of'
    and p <> 'http://rdfs.org/sioc/ns#parent_of')
    return 1;
  return 0;
};

create procedure ODS_FILTER_POST (in p any, in o any)
{
  if (p = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' and o = 'http://rdfs.org/sioc/ns#Post')
    return 1;
  else if (p like 'http://rdfs.org/sioc/ns#%')
    return 1;
  return 0;
};

create procedure ODS_FILTER_USER (in p any, in o any)
{
  --dbg_obj_print (p, o);
  if (p = 'http://rdfs.org/sioc/ns#creator_of')
    return 0;
  else if (p = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' and o <> 'http://rdfs.org/sioc/ns#User')
    return 0;
  else if (p not like 'http://rdfs.org/sioc/ns#%' and p <> 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
    return 0;
  return 1;
};

create procedure ODS_FILTER_USER_FORUM (in p any, in o any, in m any)
{
  if (p = 'http://rdfs.org/sioc/ns#has_member' and o = m)
    return 1;
  else if (p like 'http://rdfs.org/sioc/ns#%'
    and p <> 'http://rdfs.org/sioc/ns#container_of'
    and p <> 'http://rdfs.org/sioc/ns#parent_of'
    and p <> 'http://rdfs.org/sioc/ns#has_member')
    return 1;
  else if (p = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' and o = 'http://rdfs.org/sioc/ns#Forum')
    return 1;
  return 0;
};

create procedure ODS_FILTER_FORUM_SITE (in p any, in o any, in m any)
{
  if (p = 'http://rdfs.org/sioc/ns#host_of' and o = m)
    return 1;
  else if (p like 'http://rdfs.org/sioc/ns#%' and p <> 'http://rdfs.org/sioc/ns#host_of')
    return 1;
  else if (p = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' and o = 'http://rdfs.org/sioc/ns#Site')
    return 1;
  return 0;
};


delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'ODS_SIOC_RDF';
--insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
--   values ('ODS_SIOC_RDF', cast (stringtime ('0:0') as DATETIME), concat ('sioc.DBA.fill_ods_sioc ()'), 120)
--;

--load sioc_blog.sql;
--load sioc_feeds.sql;
--load sioc_mail.sql;
--load sioc_wiki.sql;
--load sioc_photo.sql;


