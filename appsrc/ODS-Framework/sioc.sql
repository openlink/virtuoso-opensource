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

use sioc;

create procedure get_cname ()
{
  return DB.DBA.wa_cname ();
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

-- IRIs of the ontologies used for ODS RDF data

create procedure foaf_iri (in s varchar)
{
  return concat ('http://xmlns.com/foaf/0.1/', s);
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

create procedure dc_iri (in s varchar)
{
  return concat ('http://purl.org/dc/elements/1.1/', s);
};

create procedure dcterms_iri (in s varchar)
{
  return concat ('http://purl.org/dc/terms/', s);
};

create procedure skos_iri (in s varchar)
{
  return concat ('http://www.w3.org/2004/02/skos/core#', s);
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

create procedure user_site_iri (in _u_name varchar)
{
  return user_obj_iri (_u_name) || '#site';
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
  return sprintf ('http://%s%s/%U/%U/%U/%s', get_cname(), get_base_path (), u_name, tp, wai_name, post_id);
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
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, rdf_iri ('type'), sioc_iri ('Site'));
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, sioc_iri ('link'), get_ods_link ());
  DB.DBA.RDF_QUAD_URI_L (graph_iri, site_iri, dc_iri ('title'),
      coalesce ((select top 1 WS_WEB_TITLE from DB.DBA.WA_SETTINGS), sys_stat ('st_host_name')));
  return;
};

create procedure ods_sioc_init ()
{
  registry_set ('__ods_sioc_version', '22');
  if (registry_get ('__ods_sioc_init') = registry_get ('__ods_sioc_version'))
    return;
  fill_ods_sioc ();
  registry_set ('__ods_sioc_init', registry_get ('__ods_sioc_version'));
  return;
};

create procedure foaf_maker (in graph_iri varchar, in iri varchar, in full_name varchar, in u_e_mail varchar)
{
  if (not length (iri))
    return null;

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Person'));
  if (length (full_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), full_name);
  if (length (u_e_mail))
{
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }
};

create procedure person_iri (in iri varchar)
{
  return iri || '#person';
};

-- User
create procedure sioc_user (in graph_iri varchar, in iri varchar, in u_name varchar, in u_e_mail varchar, in full_name varchar := null)
{
  declare u_site_iri varchar;

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('User'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), U_NAME);

  u_site_iri := user_site_iri (u_name);

  DB.DBA.RDF_QUAD_URI (graph_iri, u_site_iri, rdf_iri ('type'), sioc_iri ('Site'));
  DB.DBA.RDF_QUAD_URI (graph_iri, u_site_iri, sioc_iri ('link'), iri);

  if (full_name is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), full_name);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));

  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (u_e_mail));
    }

  -- FOAF
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri (iri), rdfs_iri ('seeAlso'), concat (iri, '/about.rdf'));
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri (iri), rdf_iri ('type'), foaf_iri ('Person'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri (iri), foaf_iri ('nick'), u_name);
  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri (iri), foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri (iri), foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }

  delete_quad_sp (graph_iri, person_iri (iri), foaf_iri ('name'));
  if (length (full_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri (iri), foaf_iri ('name'), full_name);

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('account_of'), person_iri (iri));
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri (iri), foaf_iri ('holdsAccount'), iri);

  -- ATOM
  delete_quad_sp (graph_iri, person_iri (iri), atom_iri ('personEmail'));
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri (iri), rdf_iri ('type'), atom_iri ('Person'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri (iri), atom_iri ('personName'), u_name);
  if (length (u_e_mail))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri (iri), atom_iri ('personEmail'), u_e_mail);

};

create procedure wa_user_pub_info (in flags varchar, in fld int)
{
  declare r any;
  if (length (flags) <= fld)
    return 0;
  r := atoi (chr (flags[fld]));
  if (r = 1)
    return 1;
  return 0;
};

create procedure sioc_user_info (
    in graph_iri varchar, in iri varchar,
    in flags varchar,
    in waui_first_name varchar,
    in waui_last_name varchar,
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

--  delete_quad_sp (graph_iri, iri, sioc_iri ('first_name'));
--  delete_quad_sp (graph_iri, iri, sioc_iri ('last_name'));

--  if (length (waui_first_name) and wa_user_pub_info (flags, 1))
--    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('first_name'), waui_first_name);
--  if (length (waui_last_name) and wa_user_pub_info (flags, 2))
--    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('last_name'), waui_last_name);

  iri := person_iri (iri);

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

  if (length (waui_first_name) and wa_user_pub_info (flags, 1))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('firstName'), waui_first_name);
  if (length (waui_last_name) and wa_user_pub_info (flags, 2))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('family_name'), waui_last_name);

  if (length (gender) and wa_user_pub_info (flags, 5))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('gender'), gender);
  if (length (icq) and wa_user_pub_info (flags, 10))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('icqChatID'), icq);
  if (length (msn) and wa_user_pub_info (flags, 14))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('msnChatID'), msn);
  if (length (aim) and wa_user_pub_info (flags, 12))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('aimChatID'), aim);
  if (length (yahoo) and wa_user_pub_info (flags, 13))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('yahooChatID'), yahoo);
  if (birthday is not null and wa_user_pub_info (flags, 6))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('birthday'), substring (datestring(coalesce (birthday, now())), 6, 5));
  if (length (org) and wa_user_pub_info (flags, 20))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('organization'), org);
  if (length (phone) and wa_user_pub_info (flags, 18) and wa_user_pub_info (flags, 25))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || phone);
  if (lat is not null and lng is not null and wa_user_pub_info (flags, 39))
    {
      declare giri varchar;
      giri := iri || '_based_near';

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
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), u_name);
    }
};

-- Knows

create procedure sioc_knows (in graph_iri varchar, in _from_iri varchar, in _to_iri varchar)
{
  --DB.DBA.RDF_QUAD_URI (graph_iri, _from_iri, sioc_iri ('knows'), _to_iri);
  --DB.DBA.RDF_QUAD_URI (graph_iri, _to_iri, sioc_iri ('knows'), _from_iri);

  _from_iri := person_iri (_from_iri);
  _to_iri := person_iri (_to_iri);

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

  declare uname varchar;

  if (iri is null)
    return;

  uname := (select U_NAME from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where U_ID = WAM_USER
  	and WAM_INST = wai_name and WAM_MEMBER_TYPE = 1);

  if (uname is not null)
    site_iri := user_site_iri (uname);

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Forum'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), wai_name);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('type'), DB.DBA.wa_type_to_app (wai_type_name));
  if (wai_description is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('description'), wai_description);
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, sioc_iri ('host_of'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_host'), site_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));

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
    in tags varchar := null,
    in links_to any := null,
    in maker any := null,
    in attachments any := null)
{

      if (iri is null)
	return;

      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));

      --if (maker is null)
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));

      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), md5 (iri));
      -- user
      if (cr_iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_creator'), cr_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, cr_iri, sioc_iri ('creator_of'), iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), person_iri (cr_iri));
	}

      if (cr_iri is null and maker is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), maker);
	}


      -- forum
      if (forum_iri is not null)
        {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), forum_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), iri);
        }

      -- literal data
      if (title is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('title'), title);
      if (ts is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), sioc_date(ts));
      if (modf is not null)
	{
          DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('modified'), sioc_date(modf));
	  if (ts is null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), sioc_date(modf));
	}

      if (link is not null)
	link := make_href (link);
      else
        link := iri;

      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), link);
      if (links_to is not null)
	{
	  foreach (any l in links_to) do
	    {
	      if (length (l) > 1 and l[1] is not null)
	        DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('links_to'), l[1]);
	    }
	}
      if (attachments is not null)
	{
	  foreach (any l in attachments) do
	    {
	      if (length (l))
	        DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('attachment'), l);
	    }
	}

      -- ATOM
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('EntryInstance'));
      if (forum_iri is not null)
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('containingFeed'), forum_iri);
      if (title is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), title);
      if (cr_iri is not null)
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('author'), person_iri (cr_iri));
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

      if (content is not null)
	{
	  if (__tag (content) = 126)
	    content := blob_to_string (content);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('content'), content);
	}
      return;
};

create procedure ods_sioc_tags_delete (in graph_iri any, in post_iri any, in _tags any)
{
  declare tag_iri, arr, base, tags any;

  if (post_iri is null)
    return;

  arr := sprintf_inverse (post_iri, graph_iri || '/%s/%s', 1);

  -- briefcase is special case of IRI
  if (arr is null)
    arr := sprintf_inverse (post_iri, 'http://' || get_cname () || '/DAV/home/%s/%s', 1);

  if (arr is null or length (arr) < 1)
    return;

  base := sprintf ('%s/%s/concept#', graph_iri, arr[0]);

  tags := split_and_decode (_tags, 0, '\0\0,');

  foreach (any tag in tags) do
    {
      tag := trim (tag);
      tag := replace (tag, ' ', '_');
      if (length (tag))
	{
	  tag_iri := base || tag;
	  delete_quad_s_or_o (graph_iri, tag_iri, tag_iri);
	}
    }
};

create procedure ods_sioc_tags (in graph_iri any, in post_iri any, in _tags any)
{
  declare tag_iri, arr, base, tags any;

  if (post_iri is null)
    return;

  arr := sprintf_inverse (post_iri, graph_iri || '/%s/%s', 1);

  -- briefcase is special case of IRI
  if (arr is null)
    arr := sprintf_inverse (post_iri, 'http://' || get_cname () || '/DAV/home/%s/%s', 1);

  if (arr is null or length (arr) < 1)
    return;

  base := sprintf ('%s/%s/concept#', graph_iri, arr[0]);

  tags := split_and_decode (_tags, 0, '\0\0,');

  foreach (any tag in tags) do
    {
      tag := trim (tag);
      tag := replace (tag, ' ', '_');
      if (length (tag))
	{
	  tag_iri := base || tag;
	  DB.DBA.RDF_QUAD_URI (graph_iri, tag_iri, rdf_iri ('type'), skos_iri ('Concept'));
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, tag_iri, skos_iri ('prefLabel'), tag);
	  DB.DBA.RDF_QUAD_URI (graph_iri, tag_iri, skos_iri ('isSubjectOf'), post_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, post_iri, sioc_iri ('topic'), tag_iri);
        }
    }
};


create procedure fill_ods_sioc ()
{
  declare iri, site_iri, graph_iri, sioc_version varchar;

  site_iri  := get_graph ();
  graph_iri := get_graph ();

  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (graph_iri);
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
	  declare u_site_iri any;
	  iri := user_iri (u_id);
	  if (iri is not null)
	    {
	      sioc_user (graph_iri, iri, U_NAME, U_E_MAIL, U_FULL_NAME);
	      u_site_iri := user_site_iri (U_NAME);
	      -- it should be one row.
	      for select WAUI_VISIBLE, WAUI_FIRST_NAME, WAUI_LAST_NAME, WAUI_TITLE,
		WAUI_GENDER, WAUI_ICQ, WAUI_MSN, WAUI_AIM, WAUI_YAHOO, WAUI_BIRTHDAY,
		    WAUI_BORG, WAUI_HPHONE, WAUI_HMOBILE, WAUI_BPHONE, WAUI_LAT,
		    WAUI_LNG, WAUI_WEBPAGE, WAUI_SITE_NAME
		from DB.DBA.WA_USER_INFO where WAUI_U_ID = u_id do
		{

		  if (WAUI_SITE_NAME is not null)
		    DB.DBA.RDF_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), WAUI_SITE_NAME);

		  sioc_user_info (graph_iri, iri, WAUI_VISIBLE, WAUI_FIRST_NAME, WAUI_LAST_NAME,
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
		   where WAM_USER = U_ID and WAM_INST = WAI_NAME and ((WAI_IS_PUBLIC = 1) or (WAI_TYPE_NAME = 'oDrive')) do
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
  for select WAI_TYPE_NAME, WAI_ID, WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_IS_PUBLIC = 1 or WAI_TYPE_NAME = 'oDrive' do
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
  if (0)
    {
      sioc_version := registry_get ('__ods_sioc_version');
      for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES do
	{
	  declare p_name varchar;
	  p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc', suffix);
	  if (__proc_exists (p_name))
	    if (registry_get (sprintf('__ods_%s_sioc_init', suffix)) <> sioc_version)
	      {
		  call (p_name) (graph_iri, site_iri);
		registry_set (sprintf('__ods_%s_sioc_init', suffix), sioc_version);
	      }
	}
  if (__proc_exists ('sioc..fill_ods_nntp_sioc'))
	if (registry_get ('__ods_nntp_sioc_init') <> sioc_version)
	  {
    call ('sioc..fill_ods_nntp_sioc') (graph_iri, site_iri);
	    registry_set ('__ods_nntp_sioc_init', sioc_version);
	  }
    }
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

	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('title'), RES_NAME);
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), sioc_date (RES_CR_TIME));
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('modified') , sioc_date (RES_MOD_TIME));
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

create procedure all_predicates ()
{
 return vector (
 atom_iri ('LinkHref'),
 atom_iri ('author'),
 atom_iri ('containingFeed'),
 atom_iri ('link'),
 atom_iri ('linkRel'),
 atom_iri ('personEmail'),
 atom_iri ('personName'),
 atom_iri ('published'),
 atom_iri ('title'),
 atom_iri ('updated'),
 dc_iri ('title'),
 dcterms_iri ('created'),
 dcterms_iri ('modified'),
 dcterms_iri ('modified'),
 foaf_iri ('aimChatID'),
 foaf_iri ('based_near'),
 foaf_iri ('birthday'),
 foaf_iri ('family_name'),
 foaf_iri ('firstName'),
 foaf_iri ('gender'),
 foaf_iri ('holdsAccount'),
 foaf_iri ('icqChatID'),
 foaf_iri ('knows'),
 foaf_iri ('maker'),
 foaf_iri ('mbox'),
 foaf_iri ('mbox_sha1sum'),
 foaf_iri ('msnChatID'),
 foaf_iri ('name'),
 foaf_iri ('nick'),
 foaf_iri ('organization'),
 foaf_iri ('phone'),
 foaf_iri ('yahooChatID'),
 geo_iri ('lat'),
 geo_iri ('long'),
 rdf_iri ('type'),
 rdfs_iri ('label'),
 rdfs_iri ('seeAlso'),
 sioc..sioc_iri ('attachment'),
 sioc..sioc_iri ('container_of'),
 sioc..sioc_iri ('has_reply'),
 sioc..sioc_iri ('links_to'),
 sioc..sioc_iri ('reply_of'),
 sioc..sioc_iri ('topic'),
 sioc_iri ('account_of'),
 sioc_iri ('attachment'),
 sioc_iri ('container_of'),
 sioc_iri ('content'),
 sioc_iri ('creator_of'),
 sioc_iri ('description'),
 sioc_iri ('email'),
 sioc_iri ('email_sha1'),
 sioc_iri ('first_name'),
 sioc_iri ('has_container'),
 sioc_iri ('has_creator'),
 sioc_iri ('has_function'),
 sioc_iri ('has_host'),
 sioc_iri ('has_member'),
 sioc_iri ('has_parent'),
 sioc_iri ('has_reply'),
 sioc_iri ('has_scope'),
 sioc_iri ('host_of'),
 sioc_iri ('id'),
 sioc_iri ('knows'),
 sioc_iri ('last_name'),
 sioc_iri ('link'),
 sioc_iri ('links_to'),
 sioc_iri ('member_of'),
 sioc_iri ('name'),
 sioc_iri ('parent_of'),
 sioc_iri ('reply_of'),
 sioc_iri ('topic'),
 sioc_iri ('type'),
 skos_iri ('isSubjectOf'),
 skos_iri ('prefLabel')
 );
}
;

create procedure delete_quad_so (in _g any, in _s any, in _o any)
{
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  if (_g is null or _s is null or _o is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and O = _o;
};

create procedure delete_quad_sp (in _g any, in _s any, in _p any)
	{
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  _p := DB.DBA.RDF_IID_OF_QNAME (_p);
  if (_g is null or _s is null or _p is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and P = _p;
};

create procedure delete_quad_s_p_o (in _g any, in _s any, in _p any, in _o any)
        {
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  _p := DB.DBA.RDF_IID_OF_QNAME (_p);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  if (_g is null or _s is null or _p is null or _o is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and P = _p and O = _o;
};

create procedure delete_quad_s_or_o (in _g any, in _s any, in _o any)
{
  declare preds any;
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  if (_g is null or _s is null or _o is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s;
  preds := all_predicates ();
  foreach (any pred in preds) do
    {
      pred := DB.DBA.RDF_IID_OF_QNAME (pred);
      if (pred is not null)
        delete from DB.DBA.RDF_QUAD where P = pred and G = _g and O = _o;
    }
};

create procedure update_quad_s_o (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null)
    return;
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set S = _n where G = _g and S = _o;
  update DB.DBA.RDF_QUAD set O = _n where G = _g and O = _o;
};

create procedure update_quad_p (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null)
    return;
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
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
      delete_quad_sp (graph_iri, oiri, sioc_iri ('name'));
      delete_quad_sp (graph_iri, oiri, sioc_iri ('email_sha1'));

      oiri := person_iri (oiri);
      delete_quad_sp (graph_iri, oiri, foaf_iri ('name'));
      delete_quad_sp (graph_iri, oiri, foaf_iri ('mbox'));
      delete_quad_sp (graph_iri, oiri, foaf_iri ('mbox_sha1sum'));

      if (length (N.U_FULL_NAME))
	{
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), N.U_FULL_NAME);
	}

      if (length (N.U_E_MAIL))
    {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (N.U_E_MAIL));

	  iri := person_iri (oiri);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (N.U_E_MAIL));
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), N.U_FULL_NAME);
    }
    }
  return;
};

create trigger WA_SETTINGS after update on DB.DBA.WA_SETTINGS referencing old as O, new as N
{
  declare site_iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  site_iri := get_graph ();
  delete_quad_sp (graph_iri, site_iri, dc_iri ('title'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, site_iri, dc_iri ('title'), coalesce (N.WS_WEB_TITLE, sys_stat ('st_host_name')));
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
  declare iri, graph_iri, u_site_iri, uname varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WAUI_U_ID);
  u_site_iri := user_site_iri (uname);
  if (N.WAUI_SITE_NAME is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), N.WAUI_SITE_NAME);
  sioc_user_info (graph_iri, iri, N.WAUI_VISIBLE, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME);
  return;
};

create trigger WA_USER_INFO_SIOC_U after update on DB.DBA.WA_USER_INFO referencing old as O, new as N
    {
  declare iri, graph_iri, u_site_iri, uname varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  --sioc_user_info (graph_iri, iri, N.WAUI_VISIBLE, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME);
  uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WAUI_U_ID);
  u_site_iri := user_site_iri (uname);
  delete_quad_sp (graph_iri, u_site_iri, dc_iri ('title'));
  if (N.WAUI_SITE_NAME is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), N.WAUI_SITE_NAME);
  sioc_user_info (graph_iri, iri, N.WAUI_VISIBLE, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME,
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
  --dbg_obj_print (current_proc_name (), N.WAM_INST, N.WAM_IS_PUBLIC);
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();


  if ((N.WAM_MEMBER_TYPE = 1) and ((N.WAM_IS_PUBLIC = 1) or (N.WAM_APP_TYPE = 'oDrive')))
    {
      site_iri  := get_graph ();
      iri := forum_iri (N.WAM_APP_TYPE, N.WAM_INST);
      sioc_forum (graph_iri, site_iri, iri, N.WAM_INST, N.WAM_APP_TYPE, null);
    }

  iri :=  user_iri (N.WAM_USER);
  riri := role_iri_by_name (N.WAM_INST, N.WAM_USER);
  firi := forum_iri (N.WAM_APP_TYPE, N.WAM_INST);
  if (iri is not null and riri is not null and firi is not null and ((N.WAM_IS_PUBLIC = 1) or (N.WAM_APP_TYPE = 'oDrive')))
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
  declare site_iri, oiri, graph_iri, iri, riri, oriri varchar;
  -- dbg_obj_print (current_proc_name (), N.WAI_NAME, N.WAI_IS_PUBLIC);
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
};

  graph_iri := get_graph ();

  iri := forum_iri_n (O.WAI_TYPE_NAME, O.WAI_NAME, N.WAI_NAME);
  oiri := forum_iri (O.WAI_TYPE_NAME, O.WAI_NAME);

  if (N.WAI_IS_PUBLIC = 0 and O.WAI_IS_PUBLIC = 1)
    {
      for select O as post from DB.DBA.RDF_QUAD where
	G = DB.DBA.RDF_IID_OF_QNAME (graph_iri) and
	S = DB.DBA.RDF_IID_OF_QNAME (oiri) and
	P = DB.DBA.RDF_IID_OF_QNAME (sioc_iri ('container_of'))
	do
	  {
	    -- dbg_obj_print ('delete posts rdf:', DB.DBA.RDF_QNAME_OF_IID (post));
	    delete_quad_s_or_o (graph_iri, post, post);
	  }
      delete_quad_s_or_o (graph_iri, oiri, oiri);
      return;
    }
  else if (N.WAI_IS_PUBLIC = 1 and O.WAI_IS_PUBLIC = 0)
    {
      declare p_name varchar;
      site_iri  := get_graph ();
      sioc_forum (graph_iri, site_iri, iri, N.WAI_NAME, N.WAI_TYPE_NAME, N.WAI_DESCRIPTION);
      p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc', DB.DBA.wa_type_to_app (N.WAI_TYPE_NAME));
      -- dbg_obj_print (p_name, __proc_exists (p_name));
      if (__proc_exists (p_name))
	call (p_name) (graph_iri, site_iri, N.WAI_NAME);
    }
  else
    {
      delete_quad_sp (graph_iri, oiri, sioc_iri ('id'));
  delete_quad_sp (graph_iri, oiri, sioc_iri ('link'));
  update_quad_s_o (graph_iri, oiri, iri);

      for select distinct WAM_MEMBER_TYPE as tp from DB.DBA.WA_MEMBER where WAM_INST = O.WAI_NAME and ((WAM_IS_PUBLIC = 1) or (WAM_APP_TYPE = 'oDrive')) do
{
      declare _role varchar;
      _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = O.WAI_NAME and WMT_ID = tp);

      if (_role is null and tp = 1)
	_role := 'owner';

      riri := iri || '#' || _role;
      oriri := oiri || '#' || _role;
      update_quad_s_o (graph_iri, oriri, riri);
    }

      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), N.WAI_NAME);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);
    }
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

create procedure sioc_compose_xml (in u_name varchar, in wai_name varchar, in inst_type varchar, in postid varchar := null,
				   in p int := null)
{
  declare state, tp, qry, msg, maxrows, metas, rset, graph, iri, offs any;
  declare ses any;

--  dbg_obj_print (u_name,wai_name,inst_type,postid);
  graph := get_graph ();
  ses := string_output ();

  if (inst_type = 'users')
    inst_type := null;

  if (u_name is null)
    {
      qry := sprintf (
      		'sparql  ' ||
		'prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> '||
		'prefix foaf: <http://xmlns.com/foaf/0.1/> '||
		'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
		'prefix dc: <http://purl.org/dc/elements/1.1/> '||
		'prefix dct: <http://purl.org/dc/terms/> '||
		'construct { '||
		  '<%s#users> rdf:type foaf:Group . '||
		  '<%s#users> foaf:member ?s . '||
		  '?s rdf:type foaf:Agent . '||
		  '?s foaf:nick ?nick . '||
		  '?s foaf:name ?name . '||
		  '?s rdfs:seeAlso ?sa . ' ||
		  '?sa dc:format "application/rdf+xml" '||
		  '} from <%s> '||
		  'where { ?s rdf:type foaf:Person . '||
		  '?s foaf:nick ?nick . '||
		  '?s rdfs:seeAlso ?sa . '||
		  'optional { ?s foaf:name ?name } . '||
		  '}', graph, graph, graph, graph, graph);
    }
  else if (wai_name is null and inst_type is null and postid is null)
    {
      iri := user_obj_iri (u_name);
      qry := sprintf ('sparql ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' CONSTRUCT { ?s ?p ?o . ?f foaf:holdsAccount ?ha . ?f rdfs:seeAlso ?sa . '||
	 '  ?frm sioc:has_member ?member . ?frm sioc:type ?ft . ?frm sioc:id ?fid . '||
         '  ?frm rdfs:seeAlso ?fsa . ?frm sioc:has_host ?fh .  ?role sioc:has_scope ?frm } \n' ||
         ' FROM <%s> WHERE { \n' ||
	 '   { ?s ?p ?o . ?s sioc:id "%s" FILTER (?p != "http://www.w3.org/2000/01/rdf-schema#seeAlso" && ' ||
	 ' 					  ?p != "http://rdfs.org/sioc/ns#creator_of") } union  \n' ||
	 '   { ?f foaf:nick "%s" ; foaf:holdsAccount ?ha ; rdfs:seeAlso ?sa  } union  \n' ||
         '   { ?frm sioc:has_member ?member . '||
         '     ?member sioc:id "%s" . ?frm sioc:type ?ft ; sioc:id ?fid ; rdfs:seeAlso ?fsa ; sioc:has_host ?fh . '||
	 '     OPTIONAL { ?role sioc:has_scope ?frm } '||
	 '  	 } } ',
	 graph, u_name, u_name, u_name);
    }
  else if (wai_name is null and postid is null)
    {
      tp := DB.DBA.wa_type_to_app (inst_type);
      iri := user_obj_iri (u_name);
      qry := sprintf ('sparql ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
         ' CONSTRUCT { 	?s rdf:type sioc:Forum . ?s sioc:type ?ft . ?s sioc:has_member ?member . '||
      	 ' 		?member sioc:has_function ?role . ?member rdfs:seeAlso ?sa . '||
	 ' 		?s sioc:has_host ?fh . ?s sioc:id ?fid . ?s rdfs:seeAlso ?fsa . ?role sioc:has_scope ?s . } \n' ||
         ' FROM <%s> WHERE { \n' ||
         '    ?s sioc:has_member ?member  . ?member sioc:id "%s" ; rdfs:seeAlso ?sa . ?s sioc:type "%s" ; '||
	 '    sioc:has_host ?fh ; sioc:type ?ft ; sioc:id ?fid ; rdfs:seeAlso ?fsa . OPTIONAL { ?role sioc:has_scope ?s } . '||
	 ' } ',
	 graph, u_name, tp);
    }
  else if (postid is null)
    {
      declare triples, num any;
      declare lim any;

      lim := coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
      offs := coalesce (p, 0) * lim;
      tp := DB.DBA.wa_type_to_app (inst_type);

      if (inst_type = 'discussion')
	iri := forum_iri ('nntpf', wai_name);
      else
      iri := forum_iri (inst_type, wai_name);
      rdf_head (ses);
      triples := (sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	  prefix dc: <http://purl.org/dc/elements/1.1/>
          construct
	        {
		  ?host sioc:host_of ?forum .
		  ?host sioc:link ?link .
		  ?host dc:title ?title .
		  ?host rdf:type sioc:Site .
	        } where
            	{
		  graph ?:graph
		  {
		    ?host sioc:host_of ?forum . ?forum sioc:id ?:wai_name .
		    ?host sioc:link ?link . ?host dc:title ?title
		  }
		}
	    );
      rset := dict_list_keys (triples, 1);
      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);

      triples := (sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	  prefix dc: <http://purl.org/dc/elements/1.1/>
          construct {
			?forum sioc:id ?id .
			?forum sioc:type sioc:Forum .
			?forum sioc:link ?link .
			?forum sioc:description ?descr .
			?forum sioc:has_member ?member .
			?member rdfs:seeAlso ?see_also .
			?forum sioc:has_host ?host .
			?forum sioc:type ?type
		    } where
            	{
		  graph ?:graph
		  {
		    ?forum sioc:id ?:wai_name .
		    ?forum sioc:id ?id .
		    ?forum sioc:link ?link .
		    ?forum sioc:description ?descr .
		    ?forum sioc:has_member ?member .
		    ?member rdfs:seeAlso ?see_also .
		    ?forum sioc:has_host ?host .
		    ?forum sioc:type ?type
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
	      prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	      prefix dc: <http://purl.org/dc/elements/1.1/>
              prefix dct: <http://purl.org/dc/terms/>
          construct
    {
		?forum sioc:container_of ?post .
		?post  sioc:has_container ?forum .
		    ?forum sioc:has_parent ?pforum .
		    ?pforum sioc:parent_of ?forum .
		?post rdf:type sioc:Post .
		    ?post rdfs:seeAlso ?post_see_also
	   }
	  where
                {
                  graph <%s>
                  {
			?pforum sioc:id "%s" .
			?pforum sioc:parent_of ?forum .
                    ?post sioc:has_container ?forum .
			?post rdfs:seeAlso ?post_see_also .
			?post dct:created ?created .
			optional { ?post sioc:reply_of ?reply_of }
			filter bif:isnull (?reply_of)
		      }
		    }
		    order by desc (?created) limit %d offset %d
		', graph, wai_name, lim, offs);
	}
      else
	{
	  qry := sprintf ('sparql
	      prefix sioc: <http://rdfs.org/sioc/ns#>
	      prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	      prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	      prefix dc: <http://purl.org/dc/elements/1.1/>
              prefix dct: <http://purl.org/dc/terms/>
	      prefix foaf: <http://xmlns.com/foaf/0.1/>
	      construct
	       {
		    ?forum sioc:container_of ?post .
		    ?post  sioc:has_container ?forum .
		    ?post rdf:type sioc:Post .
		    ?post rdfs:seeAlso ?post_see_also
	       }
	      where
		    {
		      graph <%s>
		      {
			?forum sioc:id "%s" .
			?post sioc:has_container ?forum .
			?post rdfs:seeAlso ?post_see_also .
		        ?post dct:created ?created .
			optional { ?post sioc:has_creator ?creator } .
			optional { ?post sioc:reply_of ?reply_of }
			filter bif:isnull (?reply_of)
                  }
                }
		    order by desc (?created) limit %d offset %d
		', graph, wai_name, lim, offs);
	}
      rset := null;
      maxrows := 0;
      state := '00000';
      msg := '';
      set_user_id ('dba');
--      dbg_printf ('%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
      if (state = '00000')
		  {
	  triples := rset[0][0];
      rset := dict_list_keys (triples, 1);
      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	  -- seeAlso for the rest of posts
	  if (length (rset))
	    {
	      http (sprintf ('<rdf:Description rdf:about="%s">', iri), ses);
	      http (sprintf
	      	('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/sioc.rdf?p=%d" />',
		    iri, coalesce (p, 0) + 1), ses);
	      http ('</rdf:Description>', ses);
	    }
        }
      rdf_tail (ses);
      goto ret;
    }
  else -- the post
    {
--      dbg_obj_print (u_name, inst_type, wai_name, postid);
      if (inst_type = 'feed')
        iri := feeds_post_iri (atoi(wai_name), atoi(postid));
      else if (inst_type = 'discussion')
	iri := nntp_post_iri (wai_name, postid);
      else
      iri := post_iri (u_name, inst_type, wai_name, postid);
--      dbg_obj_print (iri, md5(iri));
      qry := sprintf ('sparql ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
	 ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
	 ' prefix foaf: <http://xmlns.com/foaf/0.1/> '||
	 ' prefix skos: <http://www.w3.org/2004/02/skos/core#> '||
         ' construct {
	            ?post rdf:type sioc:Post .
	   	    ?post sioc:has_container ?forum .
		    ?forum sioc:container_of ?post .  ?forum rdfs:seeAlso ?see_also .
		    ?forum sioc:has_parent ?pforum . ?pforum rdfs:seeAlso ?psee_also .
		    ?pforum sioc:parent_of ?forum .
		    ?post dc:title ?title .
		    ?post sioc:link ?link .
		    ?post sioc:links_to ?links_to .
		    ?post dct:modified ?modified .
		    ?post dct:created ?created .
		    ?post sioc:has_creator ?creator .
		    ?post sioc:has_reply ?reply .
		    ?reply sioc:reply_of ?post .
		    ?reply rdfs:seeAlso ?reply_see_also .
		    ?post sioc:reply_of ?reply_of .
		    ?reply_of sioc:has_reply ?post .
		    ?reply_of rdfs:seeAlso ?reply_of_see_also .
		    ?post sioc:content ?content .
		    ?post foaf:maker ?maker .
		    ?maker rdfs:seeAlso ?maker_see_also .
		    ?post sioc:topic ?topic . ?topic rdfs:label ?label .
		    ?post sioc:topic ?skos_topic . ?skos_topic rdf:type skos:Concept . ?skos_topic skos:prefLabel ?skos_label .
		    ?skos_topic skos:isSubjectOf ?post .
		    ?creator rdfs:seeAlso ?cr_see_also .
		    ?maker rdf:type foaf:Person .
	 }  \n' ||
         ' from <%s> where { \n' ||
	 ' ?post sioc:id "%s" .
	   ?post sioc:has_container ?forum .
	   optional { ?forum rdfs:seeAlso ?see_also . }
	   optional { ?forum sioc:has_parent ?pforum . ?pforum rdfs:seeAlso ?psee_also . }
	   optional { ?post dct:modified ?modified } .
	   optional { ?post dct:created ?created } .
	   optional { ?post sioc:links_to ?links_to } .
	   optional { ?post sioc:link ?link } .
	   optional { ?post sioc:has_creator ?creator . ?creator rdfs:seeAlso ?cr_see_also  . }
	   optional { ?post sioc:has_reply ?reply .
	     	      ?reply rdfs:seeAlso ?reply_see_also
	   	    } .
	   optional { ?post sioc:reply_of ?reply_of .
	     	      ?reply_of rdfs:seeAlso ?reply_of_see_also
	   	    } .
	   optional { ?post dc:title ?title } .
	   optional { ?post sioc:topic ?topic . ?topic rdfs:label ?label } .
	   optional { ?post sioc:topic ?skos_topic . ?skos_topic skos:prefLabel ?skos_label } .
	   optional { ?post sioc:content ?content } .
	   optional { ?post foaf:maker ?maker . optional { ?maker rdfs:seeAlso ?maker_see_also } .
		    optional { ?maker foaf:name ?foaf_name .  } . optional { ?maker foaf:mbox ?foaf_mbox } } .
	 ' ||
	 ' } ',
	 graph, md5(iri));
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


delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'ODS_SIOC_RDF';
--insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
--   values ('ODS_SIOC_RDF', cast (stringtime ('0:0') as DATETIME), concat ('sioc.DBA.fill_ods_sioc ()'), 120)
--;

--load sioc_blog.sql;
--load sioc_feeds.sql;
--load sioc_mail.sql;
--load sioc_wiki.sql;
--load sioc_photo.sql;

