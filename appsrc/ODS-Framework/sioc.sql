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

create procedure services_iri (in s varchar)
{
  return concat ('http://rdfs.org/sioc/services#', s);
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

create procedure scot_iri (in s varchar)
{
  return concat ('http://scot-project.org/scot/ns#', s);
};

create procedure moat_iri (in s varchar)
{
  return concat ('http://moat-project.org/ns#', s);
};

create procedure ext_iri (in s varchar)
{
  return concat ('http://rdfs.org/sioc/types#', s);
};

create procedure wikiont_iri (in s varchar)
{
  return concat ('http://sw.deri.org/2005/04/wikipedia/wikiont.owl#', s);
};

create procedure bm_iri (in s varchar)
{
  return concat ('http://www.w3.org/2002/01/bookmark#', s);
};

create procedure exif_iri (in s varchar)
{
  return concat ('http://www.w3.org/2003/12/exif/ns/', s);
};

create procedure ann_iri (in s varchar)
{
  return concat ('http://www.w3.org/2000/10/annotation-ns#', s);
};

create procedure bio_iri (in s varchar)
{
  return concat ('http://vocab.org/bio/0.1/', s);
};

create procedure vcard_iri (in s varchar)
{
  return concat ('http://www.w3.org/2001/vcard-rdf/3.0#', s);
};

create procedure vcal_iri (in s varchar)
{
  return concat ('http://www.w3.org/2002/12/cal#', s);
};

create procedure bibo_iri (in s varchar)
{
  return concat ('http://purl.org/ontology/bibo/', s);
};

create procedure owl_iri (in s varchar)
{
  return concat ('http://www.w3.org/2002/07/owl#', s);
};

create procedure cc_iri (in s varchar)
{
  return concat ('http://web.resource.org/cc/', s);
};

create procedure an_iri (in s varchar)
{
  return concat ('http://www.w3.org/2000/10/annotation-ns#', s);
};

create procedure ore_iri (in s varchar)
{
  return concat ('http://www.openarchives.org/ore/terms/', s);
};

create procedure make_href (in u varchar)
{
  return WS.WS.EXPAND_URL (sprintf ('http://%s/', get_cname ()), u);
};

-- ODS object to IRI functions

-- NULL means no such
create procedure user_space_iri (in _u_name varchar)
{
  return sprintf ('http://%s%s/%U/space#this', get_cname(), get_base_path (), _u_name);
};


create procedure user_obj_iri (in _u_name varchar)
{
  return sprintf ('http://%s%s/%U#this', get_cname(), get_base_path (), _u_name);
};

create procedure user_doc_iri (in _u_name varchar)
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

create procedure role_iri (in _wai_id int, in _wam_member_id int, in _role varchar := null)
{
  declare inst, _member, tp, m_type any;
  declare exit handler for not found { return null; };

  select WAI_NAME, U_NAME, WAI_TYPE_NAME, WAM_MEMBER_TYPE into inst, _member, tp, m_type
    from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
   where WAM_INST = WAI_NAME and WAI_ID = _wai_id and WAM_USER = _wam_member_id and U_ID = WAM_USER;

  if (isnull (_role)) {
    _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = tp and WMT_ID = m_type);

    if (_role is null and m_type = 1)
      _role := 'owner';
  }

  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure role_iri_by_name (in _wai_name varchar, in _wam_member_id int, in _role varchar := null)
{
  declare inst, _member, tp, m_type any;
  declare exit handler for not found { return null; };

  select WAM_INST, U_NAME, WAM_APP_TYPE, WAM_MEMBER_TYPE into inst, _member, tp, m_type
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where WAM_INST = _wai_name
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;

  if (isnull (_role)) {
    _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = tp and WMT_ID = m_type);

    if (_role is null and m_type = 1)
      _role := 'owner';
  }

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

create procedure post_iri_ex (in firi varchar, in id any)
{
  return firi || '/' || cast (id as varchar);
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
  return sprintf ('http://%s%s/%U#this', get_cname(), get_base_path (), _u_name);
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

create procedure polls_iri (in wai_name varchar)
{
  return forum_iri ('Polls', wai_name);
};

create procedure addressbook_iri (in wai_name varchar)
{
  return forum_iri ('AddressBook', wai_name);
};

create procedure socialnetwork_iri (in wai_name varchar)
{
  return forum_iri ('SocialNetwork', wai_name);
};

create procedure calendar_iri (in wai_name varchar)
{
  return forum_iri ('Calendar', wai_name);
};

create procedure tag_iri (in forum_iri varchar, in tag varchar)
{
  return forum_iri || '/tag/' || tag;
};

create procedure ods_sioc_clean_all ()
{
  declare graph_iri varchar;
  graph_iri := get_graph ();
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
};

create procedure ods_sioc_forum_ext_type (in app varchar)
{
  return get_keyword (app, vector (
	'WEBLOG2',       ext_iri ('Weblog'),
	'eNews2',        ext_iri ('SubscriptionList'),
	'oWiki',         ext_iri ('Wiki'),
	'oDrive',        ext_iri ('Briefcase'),
	'oMail',         ext_iri ('MailingList'),
	'oGallery',      ext_iri ('ImageGallery'),
	'Community',     sioc_iri ('Community'),
	'Bookmark',      ext_iri ('BookmarkFolder'),
	'nntpf',         ext_iri ('MessageBoard'),
	'Polls',         ext_iri ('SurveyCollection'),
	'AddressBook',   ext_iri ('AddressBook'),
	'SocialNetwork', ext_iri ('SocialNetwork'),
	'Calendar',      ext_iri ('Calendar')
	), app);
};


create procedure ods_sioc_forum_type (in app varchar)
{
  declare pclazz any;
  pclazz := get_keyword (app, vector (
	'WEBLOG2',       'Forum',
	'eNews2',        'Container',
	'oWiki',         'Container',
	'oDrive',        'Container',
	'oMail',         'Forum',
	'oGallery',      'Container',
	'Community',     'Community',
	'Bookmark',      'Container',
	'nntpf',         'Forum',
	'Polls',         'Container',
	'AddressBook',   'Container',
	'SocialNetwork', 'Container',
	'Calendar',      'Container'
	), app);
  return sioc_iri (pclazz);
};

DB.DBA.RDF_OBJ_FT_RULE_ADD (get_graph (), null, 'ODS RDF Data');

create procedure ods_graph_init ()
{
  declare iri, site_iri, graph_iri varchar;
  set isolation='uncommitted';
  site_iri  := get_graph ();
  graph_iri := get_graph ();
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, rdf_iri ('type'), sioc_iri ('Space'));
  DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, sioc_iri ('link'), get_ods_link ());
  DB.DBA.RDF_QUAD_URI_L (graph_iri, site_iri, dc_iri ('title'),
      coalesce ((select top 1 WS_WEB_TITLE from DB.DBA.WA_SETTINGS), sys_stat ('st_host_name')));

  return;
};

create procedure ods_is_defined_by (in graph_iri varchar, in iri varchar)
{
  declare df_uri, tmp, pos any;
  --df_uri := sprintf ('http://%s/ods/data/rdf/iid%%20%%28%d%%29.rdf', get_cname(), iri_id_num (iri_to_id (iri)));
  pos := strrchr (iri, '#');
  if (pos is not null)
    tmp := subseq (iri, 0, pos);
  else
    tmp := iri;
  if (iri like 'http://%/dataspace/person/%')
    df_uri := tmp || '/about.rdf';
  else
    df_uri := tmp || '/sioc.rdf';
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, ore_iri ('isDescribedBy'), df_uri);
};

create procedure foaf_maker (in graph_iri varchar, in iri varchar, in full_name varchar, in u_e_mail varchar)
{
  if (not length (iri))
    return null;

  ods_sioc_result (iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Person'));
  if (length (full_name))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), full_name);
  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }
};

create procedure person_iri (in iri varchar, in suff varchar := '#this', in tp int := null)
{
  declare arr any;
  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  if (length (arr) <> 2)
    signal ('22023', sprintf ('Non-user IRI [%s] can\'t be transformed to person IRI', iri));

  if (tp is null and
      exists (select 1 from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where WAUI_U_ID = U_ID and U_NAME = arr[1] and WAUI_IS_ORG = 1))
    return sprintf ('http://%s/dataspace/organization/%s%s',arr[0],arr[1], suff);

  if (tp = 1)
    return sprintf ('http://%s/dataspace/organization/%s%s',arr[0],arr[1], suff);

  return sprintf ('http://%s/dataspace/person/%s%s',arr[0],arr[1], suff);
};

create procedure group_iri (in iri varchar, in suff varchar := '#this')
{
  declare arr any;
  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s/community/%s', 1);
  if (length (arr) <> 3)
    signal ('22023', sprintf ('Community IRI [%s] can\'t be transformed to group IRI', iri));
  return sprintf ('http://%s/dataspace/group/%s%s', arr[0], arr[2], suff);
}
;

create procedure person_ola_iri (in iri varchar, in suff varchar)
{
  declare arr any;
  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  if (length (arr) <> 2)
    signal ('22023', sprintf ('Non-user IRI [%s] can\'t be transformed to person IRI', iri));
  return sprintf ('http://%s/dataspace/person/%s/online_account#%s',arr[0],arr[1], suff);
};

create procedure person_prj_iri (in iri varchar, in suff varchar)
{
  declare arr any;
  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  if (length (arr) <> 2)
    signal ('22023', sprintf ('Non-user IRI [%s] can\'t be transformed to person IRI', iri));
  return sprintf ('http://%s/dataspace/person/%s/projects#%s',arr[0],arr[1], suff);
};

-- User
create procedure sioc_user (in graph_iri varchar, in iri varchar, in u_name varchar, in u_e_mail varchar, in full_name varchar := null)
{
  declare u_site_iri varchar;
  declare person_iri, link varchar;
  declare os_iri varchar;

  ods_sioc_result (iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('User'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), U_NAME);
  ods_is_defined_by (graph_iri, iri);

  u_site_iri := user_space_iri (u_name);
  link := user_doc_iri (u_name);

  DB.DBA.RDF_QUAD_URI (graph_iri, u_site_iri, rdf_iri ('type'), sioc_iri ('Space'));
  DB.DBA.RDF_QUAD_URI (graph_iri, u_site_iri, sioc_iri ('link'), link);

  os_iri := sprintf ('http://%s/feeds/people/%U', get_cname(), u_name);
  ods_sioc_service (graph_iri, os_iri, iri, null, null, null, os_iri, 'OpenSocial');
  os_iri := sprintf ('http://%s/feeds/people/%U/friends', get_cname(), u_name);
  ods_sioc_service (graph_iri, os_iri, iri, null, null, null, os_iri, 'OpenSocial');

  if (full_name is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), full_name);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), link);

  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (link, '/sioc.rdf'));

  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (u_e_mail));
    }

  -- FOAF
  person_iri := person_iri (iri);
  ods_is_defined_by (graph_iri, person_iri);
  --DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, rdfs_iri ('seeAlso'), concat (link, '/about.rdf'));
  if (person_iri like '%/organization/%')
    DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, rdf_iri ('type'), foaf_iri ('Organization'));
  else
    DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, rdf_iri ('type'), foaf_iri ('Person'));
  DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri, foaf_iri ('nick'), u_name);
  if (length (u_e_mail))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri, foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }

  delete_quad_sp (graph_iri, person_iri, foaf_iri ('name'));
  if (length (full_name))
    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri, foaf_iri ('name'), full_name);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), full_name);
    }
  else
    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), U_NAME);
    }

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('account_of'), person_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, foaf_iri ('holdsAccount'), iri);
  -- OpenID (new)
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, foaf_iri ('openid'), link);

  -- ATOM the person here is a subclass of foaf:Person which is already the case
  --delete_quad_sp (graph_iri, person_iri, atom_iri ('personEmail'));
  --if (person_iri not like '%/organization/%')
  --  {
  --    DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, rdf_iri ('type'), atom_iri ('Person'));
  --    DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri, atom_iri ('personName'), u_name);
  --    if (length (u_e_mail))
  --	DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri, atom_iri ('personEmail'), u_e_mail);
  --  }

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

create procedure wa_pub_info (in txt varchar, in flags varchar, in fld int)
{
  if (length (txt) and wa_user_pub_info (flags, fld))
    return 1;
  return 0;
};

create procedure sioc_user_info (
    in graph_iri varchar, in in_iri varchar,
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
    in webpage varchar := null,
    -- new props
    in photo varchar := null,
    in org_page varchar := null,
    in resume varchar := null,
    in interests any := null,
    in interestTopics any := null,
    in hcity varchar := null,
    in hstate varchar := null,
    in hcountry varchar := null,
    in ext_urls any := null,
    in hb_latlng int := 0
    )
{
  declare org_iri, iri any;
  declare addr_iri any;
  declare giri varchar;
  declare ev_iri any;
  declare is_person int;

  if (iri is null)
    return;
  is_person := 1;

--  delete_quad_sp (graph_iri, iri, sioc_iri ('first_name'));
--  delete_quad_sp (graph_iri, iri, sioc_iri ('last_name'));

--  if (length (waui_first_name) and wa_user_pub_info (flags, 1))
--    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('first_name'), waui_first_name);
--  if (length (waui_last_name) and wa_user_pub_info (flags, 2))
--    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('last_name'), waui_last_name);

  iri := person_iri (in_iri, '');
  org_iri := iri || '#org';
  addr_iri := iri || '#addr';
  ev_iri := iri || '#event';
  giri := iri || '#based_near';
  iri := person_iri (in_iri);
  if (iri like '%/organization/%')
    is_person := 0;

  ods_sioc_result (iri);

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
  delete_quad_sp (graph_iri, iri, foaf_iri ('homepage'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('depiction'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('interest'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('topic_interest'));
  delete_quad_sp (graph_iri, iri, foaf_iri ('workplaceHomepage'));
  delete_quad_sp (graph_iri, iri, bio_iri ('olb'));
  delete_quad_sp (graph_iri, iri, owl_iri ('sameAs'));
  delete_quad_s_or_o (graph_iri, ev_iri, ev_iri);
  delete_quad_s_or_o (graph_iri, org_iri, org_iri);
  delete_quad_s_or_o (graph_iri, addr_iri, addr_iri);
  delete_quad_s_or_o (graph_iri, giri, giri);

  if (is_person and length (waui_first_name) and wa_user_pub_info (flags, 1))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('firstName'), waui_first_name);
  if (is_person and length (waui_last_name) and wa_user_pub_info (flags, 2))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('family_name'), waui_last_name);

  if (is_person and length (gender) and wa_user_pub_info (flags, 5))
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
    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('birthday'), substring (datestring(coalesce (birthday, now())), 6, 5));
      DB.DBA.RDF_QUAD_URI (graph_iri, ev_iri, rdf_iri ('type'), bio_iri ('Birth'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, bio_iri ('event'), ev_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, ev_iri, dc_iri ('date'), substring (datestring(birthday), 1, 10));
    }
  if (length (phone) and wa_user_pub_info (flags, 18) and wa_user_pub_info (flags, 25))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || phone);
  if (lat is not null and lng is not null and wa_user_pub_info (flags, (case when hb_latlng = 0 then 39 else 47 end)))
    {

      DB.DBA.RDF_QUAD_URI (graph_iri, giri, rdf_iri ('type'), geo_iri ('Point'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('based_near'), giri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, giri, geo_iri ('lat'), sprintf ('%.06f', coalesce (lat, 0)));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, giri, geo_iri ('long'), sprintf ('%.06f', coalesce (lng, 0)));
    }
  if (wa_pub_info (photo, flags, 37))
    DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('depiction'), DB.DBA.WA_LINK (1, photo));

  if (is_person and length (org) and length (org_page) and wa_user_pub_info (flags, 20))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('workplaceHomepage'), org_page);
      DB.DBA.RDF_QUAD_URI (graph_iri, org_iri, rdf_iri ('type') , foaf_iri ('Organization'));
      DB.DBA.RDF_QUAD_URI (graph_iri, org_iri, foaf_iri ('homepage'), org_page);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, org_iri, dc_iri ('title'), org);
    }

  if (is_person and length (interests))
    {
      for (select interest, label from DB.DBA.WA_USER_INTERESTS (txt) (interest varchar, label varchar) P where txt = interests) do
	{
	  if (length (interest))
	    {
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('interest'), interest);
	      if (length (label))
		{
		  DB.DBA.RDF_QUAD_URI_L (graph_iri, interest, rdfs_iri ('label'), label);
		}
	    }
	}
    }

  if (is_person and length (interestTopics))
    {
      for (select interest, label from DB.DBA.WA_USER_INTERESTS (txt) (interest varchar, label varchar) P where txt = interestTopics) do
  	  {
  	    if (length (interest))
  	    {
  	      if (length (label))
  		    {
  		      DB.DBA.RDF_QUAD_URI_L (graph_iri, interest, rdfs_iri ('label'), label);
  		    }
  	    }
  	  }
    }

  if (wa_pub_info (hcountry, flags, 15))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, vcard_iri ('ADR'), addr_iri);
      if (length (hcity))
	DB.DBA.RDF_QUAD_URI_L (graph_iri, addr_iri, vcard_iri ('Locality'), hcity);
      if (length (hstate))
	DB.DBA.RDF_QUAD_URI_L (graph_iri, addr_iri, vcard_iri ('Region'), hstate);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, addr_iri, vcard_iri ('Country'), hcountry);
    }

  if (is_person and wa_pub_info (resume, flags, 34))
    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, bio_iri ('olb'), resume);
    }

  if (wa_pub_info (webpage, flags, 7))
    DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('homepage'), webpage);

  if (length (ext_urls) and wa_pub_info (ext_urls, flags, 8))
    {
      declare arr any;
      ext_urls := replace (ext_urls, '\r', '\n');
      ext_urls := replace (ext_urls, '\n\n', '\n');
      arr := split_and_decode (ext_urls, 0, '\0\0\n');
      foreach (any u in arr) do
	{
	  if (length (trim (u)))
	    {
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, owl_iri ('sameAs'), u);
	    }
	}
    }

};

create procedure sioc_user_project (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar, in descr varchar, in piri varchar := null)
{
  declare prj_iri, pers_iri any;

  if (piri is null)
    prj_iri := person_prj_iri (iri, sprintf ('%U', nam));
  else
    prj_iri := piri;
  pers_iri := person_iri (iri);
  delete_quad_s_or_o (graph_iri, prj_iri, prj_iri);

  DB.DBA.RDF_QUAD_URI (graph_iri, pers_iri, foaf_iri ('made'), prj_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, prj_iri, foaf_iri ('maker'), pers_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, prj_iri, dc_iri ('creator'), pers_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, prj_iri, dc_iri ('identifier'), url);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, prj_iri, dc_iri ('title'), nam);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, prj_iri, dc_iri ('description'), descr);
};

create procedure sioc_user_related (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar, in pred varchar)
{
  declare rel_iri, pers_iri any;

  rel_iri := url;
  pers_iri := person_iri (iri);
  delete_quad_s_or_o (graph_iri, rel_iri, rel_iri);

  if (0 = length (pred))
    pred := rdfs_iri ('seeAlso');

  DB.DBA.RDF_QUAD_URI (graph_iri, pers_iri, pred, rel_iri);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, rel_iri, rdfs_iri ('label'), nam);
};

create procedure sioc_app_related (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar, in pred varchar := null)
{
  declare rel_iri any;

  rel_iri := url;
  delete_quad_s_or_o (graph_iri, rel_iri, rel_iri);

  if (0 = length (pred))
    pred := rdfs_iri ('seeAlso');

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, pred, rel_iri);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, rel_iri, rdfs_iri ('label'), nam);
};


create procedure sioc_user_account (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar)
{
  declare acc_iri, pers_iri any;
  pers_iri := person_iri (iri);
  acc_iri := person_ola_iri (iri, nam);
  -- XXX, have to know if this is URL
  DB.DBA.RDF_QUAD_URI (graph_iri, acc_iri, rdf_iri ('type'), foaf_iri ('OnlineAccount'));
  DB.DBA.RDF_QUAD_URI (graph_iri, acc_iri, foaf_iri ('accountServiceHomepage'), url);
  DB.DBA.RDF_QUAD_URI_L (graph_iri, acc_iri, foaf_iri ('accountName'), nam);
  DB.DBA.RDF_QUAD_URI (graph_iri, pers_iri, foaf_iri ('holdsAccount'), acc_iri);
};
-- Group

create procedure sioc_group (in graph_iri varchar, in iri varchar, in u_name varchar)
{
  if (iri is not null)
    {
      ods_sioc_result (iri);
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
	in wai_description varchar,
	in wai_id int := null)
{

  declare uname, clazz, sub, pers_iri, uiri varchar;

  if (iri is null)
    return;

  uname := (select U_NAME from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where U_ID = WAM_USER
  	and WAM_INST = wai_name and WAM_MEMBER_TYPE = 1);

  pers_iri := null;
  if (uname is not null)
    {
      site_iri := user_space_iri (uname);
      uiri := user_obj_iri (uname);
      pers_iri := person_iri (uiri);
    }

  ods_sioc_result (iri);

  sub := ods_sioc_forum_ext_type (wai_type_name);
  clazz := ods_sioc_forum_type (wai_type_name);

  -- we keep this until we verify subclassing work
  -- if (wai_type_name <> 'Community')
  --   DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), clazz);
  -- if (clazz <> sioc_iri ('Container') and wai_type_name <> 'Community')
  --   DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Container'));
  -- A given forum is a subclass of the sioc:Forum, based on sioc types module
  -- if (sub <> clazz or wai_type_name = 'Community')

  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sub);
  ods_is_defined_by (graph_iri, iri);

  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), wai_name);
  if (wai_id is null)
    wai_id := (select i.WAI_ID from DB.DBA.WA_INSTANCE i where i.WAI_NAME = wai_name);
  if (wai_id is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('identifier'), wai_id);
  -- deprecated DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('type'), DB.DBA.wa_type_to_app (wai_type_name));
  if (wai_description is null)
    wai_description := wai_name;

    {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('description'), wai_description);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), wai_description);
    }
  if (wai_type_name <> 'Community')
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, site_iri, sioc_iri ('space_of'), iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_space'), site_iri);
    }
  if (wai_type_name = 'Community')
    {
      declare giri any;
      giri :=  group_iri (iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, giri, rdf_iri ('type'), foaf_iri ('Group'));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, giri, foaf_iri ('name'), wai_name);
    }
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);

  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));
--  DB.DBA.RDF_QUAD_URI (graph_iri, concat (iri, '/sioc.rdf'), rdf_iri ('type'), sub);

  -- ATOM
  if (clazz = ods_sioc_forum_type ('WEBLOG2'))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Feed'));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), wai_name);
    }
  if (wai_type_name = 'AddressBook')
    {
      iri := forum_iri ('SocialNetwork', wai_name);
      sioc_forum (graph_iri, site_iri, iri, wai_name, 'SocialNetwork', wai_description);
    }

  if (pers_iri is not null)
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), pers_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, pers_iri, foaf_iri ('made'), iri);
    }

};

create procedure cc_gen_rdf (in iri varchar, in lic_iri varchar)
{
  declare xt, xd, ses any;
  if (not length (lic_iri))
    return null;
  xd := gen_cc_xml ();
  xt := xpath_eval (sprintf ('//License[@about = "%s"]', lic_iri), xd);
  if (xt is null)
    return null;
  xd := serialize_to_UTF8_xml (xt);
  ses := string_output ();
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:cc="http://web.resource.org/cc/">\n', ses);
  http (sprintf ('<cc:Work rdf:about="%s">\n', iri), ses);
  http ('<cc:license>\n', ses);
  http (xd, ses);
  http ('</cc:license>\n', ses);
  http ('</cc:Work>\n', ses);
  http ('</rdf:RDF>', ses);
  ses := string_output_string (ses);
  return ses;
};

create procedure cc_work_lic (in graph_iri varchar, in iri varchar, in lic_iri varchar)
{
  declare ses any;
  ses := cc_gen_rdf (iri, lic_iri);
  if (ses is not null)
    DB.DBA.RDF_LOAD_RDFXML (ses, iri, graph_iri);
};

create procedure sioc_date (in d any)
{
  declare str any;
  if (__tag (d) <> 211)
    d := now ();
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

    declare do_ann, do_exif, do_atom int;
    declare arr, creator, app any;

    do_atom := do_ann := do_exif := 0;
    creator := null;

      if (iri is null)
	return;

      ods_sioc_result (iri);

      --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Item'));

      --if (maker is null)
      --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));
      ods_is_defined_by (graph_iri, iri);

      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), md5 (iri));
      -- user
      if (cr_iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_creator'), cr_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, cr_iri, sioc_iri ('creator_of'), iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), person_iri (cr_iri));
	  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri (cr_iri), foaf_iri ('made'), iri);
	}

      if (cr_iri is null and length (maker) > 0)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), maker);
	}

      app := null;

      -- forum
      if (forum_iri is not null)
        {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), forum_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), iri);
	  arr := sprintf_inverse (forum_iri, graph_iri || '/%s/%s/%s', 1);
	  if (arr is not null and length (arr) = 3)
	    {
	      app := arr[1];
	      if (arr[1] = 'photos')
		do_exif := 1;
		else if (arr[1] = 'bookmark')
		  {
		    do_ann := 1;
		    creator := arr[0];
		  }
	      else if (arr[1] <> 'socialnetwork')
		do_atom := 1;
	    }
	  else if (forum_iri like graph_iri || '/discussion/%')
	    {
	      app := 'discussion';
	    }
	  else
	    do_atom := 1;
        }

      -- this is a subclassing of the different types of Item, former Post

      if (maker is not null and app <> 'discussion') -- means comment
	{
	  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('Comment'));
	}
      else if (app = 'weblog')
	{
	  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('BlogPost'));
	}
      else if (app = 'discussion')
	{
	  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('BoardPost'));
	}
      else if (app = 'mail')
	{
	  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('MailMessage'));
	}
      --else if (app = 'bookmark') handled below
      --;
      else if (app = 'briefcase')
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Document'));
      else if (app = 'wiki')
	{
	  --DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), wikiont_iri ('Article'));
	}
      else if (not do_exif and not do_ann and not do_atom)
        DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Item'));

      -- literal data
      if (title is not null and length (title))
	{
          DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('title'), title);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), title);
        }
      if (ts is not null)
        DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), (ts));
      if (modf is not null)
	{
          DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('modified'), (modf));
	  if (ts is null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), (modf));
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
		{
		  declare url varchar;
		  url := DB.DBA.RDF_MAKE_IID_OF_QNAME (l[1]);
		  if (url is not null)
	            DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('links_to'), url);
		  else
		    log_message ('ODS RDF: Bad link from IRI:'||iri);
		}
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
      if (do_atom)
        {
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Entry'));
	  if (forum_iri is not null)
	    {
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('source'), forum_iri);
	      DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, atom_iri ('entry'), iri);
	      DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, atom_iri ('contains'), iri);
	    }
	  if (title is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), title);
	  if (cr_iri is not null)
	    DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('author'), person_iri (cr_iri));
	  if (ts is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('published'), sioc_date (ts));
	  if (modf is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, atom_iri ('updated'), sioc_date (modf));
	  if (0 and link is not null) -- obsoleted
	    {
	      DB.DBA.RDF_QUAD_URI (graph_iri, link, rdf_iri ('type'), atom_iri ('Link'));
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, atom_iri ('link'), link);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, link, atom_iri ('LinkHref'), link);
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, link, atom_iri ('linkRel'), 'alternate');
	    }
        }

      if (content is not null and not do_exif)
	{
	  declare ses any;
	  ses := string_output ();
	  http_value (content, null, ses);
	  ses := string_output_string (ses);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, sioc_iri ('content'), ses);
	}

      if (do_ann)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'),  bm_iri ('Bookmark'));

          if (modf is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('date'), sioc_date (modf));
          if (content is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('description'), content);
	  if (creator is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('creator'), creator);
          if (ts is not null)
	    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, ann_iri ('created'), (ts));
          if (link is not null)
	    DB.DBA.RDF_QUAD_URI (graph_iri, iri, bm_iri ('recalls'), link);
	}
      else if (do_exif)
	{
	  declare arr1, id, path any;
	  path := substring (iri, length (forum_iri)+2, length (iri));
	  id := (select RES_ID from WS.WS.SYS_DAV_RES where RES_ID = atoi(path));
	  if (id is not null)
	    {
		{
		  declare exit handler for sqlstate '*' { goto noexif; };
		  arr1 := PHOTO.WA.get_attributes ('', 0, id);
		}
	      DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'),  exif_iri ('IFD'));
	      make_exif_fld (graph_iri, iri, arr1, 'make');
	      make_exif_fld (graph_iri, iri, arr1, 'model');
	      make_exif_fld (graph_iri, iri, arr1, 'orientation');
	      make_exif_fld (graph_iri, iri, arr1, 'xResolution');
	      make_exif_fld (graph_iri, iri, arr1, 'yResolution');
	      make_exif_fld (graph_iri, iri, arr1, 'software');
	      make_exif_fld (graph_iri, iri, arr1, 'dateTime');
	      make_exif_fld (graph_iri, iri, arr1, 'exposureTime');
	      noexif:;
	    }
	}
commit work;
      return;
};

create procedure make_exif_fld (in graph_iri any, in iri any, inout arr any, in fld any)
{
  declare r, n any;
  foreach (any u in arr) do
    {
      if (u is not null)
	{
	  n := udt_get (u, 'name');
	  r := udt_get (u, 'value');
	  if (r is not null and upper (fld) = n)
	    {
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, exif_iri (fld), r);
	    }
	}
    }
};

-- svc:max_results svc:results_format svc:service_of svc:service_definition svc:service_endpoint svc:service_protocol
create procedure ods_sioc_service (
    in graph_iri varchar,
    in iri varchar,
    in forum_iri varchar,
    in max_res int,
    in fmt varchar,
    in wsdl varchar,
    in endpoint varchar,
    in proto varchar,
    in descr varchar := null,
    in id int := null
    )
{
  if (iri is null or forum_iri is null)
    return;
  ods_sioc_result (iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), services_iri ('Service'));
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, services_iri ('service_of'), forum_iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, forum_iri, services_iri ('has_service'), iri);
  if (max_res is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, services_iri ('max_results'), cast (max_res as varchar));
  if (fmt is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, services_iri ('results_format'), fmt);
  if (wsdl is not null)
    DB.DBA.RDF_QUAD_URI (graph_iri, iri, services_iri ('service_definition'), wsdl);
  if (endpoint is not null)
    DB.DBA.RDF_QUAD_URI (graph_iri, iri, services_iri ('service_endpoint'), endpoint);
  if (proto is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, services_iri ('service_protocol'), proto);
  if (descr is not null or proto is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), coalesce (descr, proto));
  if (id is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('identifier'), id);
  commit work;
};

-- the ods_sioc_tags* is used for text indexing the NNTP data
-- the SKOS & SCOT tags are produced by scot_tags_insert & scot_tags_delete
create procedure ods_sioc_tags_delete (in graph_iri any, in post_iri any, in _tags any)
{
  if (post_iri is null)
    return;
  delete_quad_sp (graph_iri, post_iri, dc_iri ('subject'));
};

create procedure ods_sioc_tags (in graph_iri any, in post_iri any, in _tags any)
{
  if (post_iri is null)
    return;
  if (length (_tags))
    DB.DBA.RDF_QUAD_URI_L (graph_iri, post_iri, dc_iri ('subject'), _tags);
  else
    DB.DBA.RDF_QUAD_URI_L (graph_iri, post_iri, dc_iri ('subject'), '~none~');
};

create procedure service_iri (in forum_iri varchar, in id int)
{
  return sprintf ('%s/service/%d', forum_iri, id);
}
;

create procedure ods_ping_svc_init (in graph_iri varchar, in site_iri varchar)
{
  declare iri any;
  for select SH_URL, SH_NAME, SH_PROTO, SH_ID, SH_METHOD from ODS.DBA.SVC_HOST where SH_ID > 0 do
    {
      iri := service_iri (site_iri, SH_ID);
      ods_sioc_service (graph_iri, iri, site_iri, null, null, null, SH_URL, SH_PROTO, SH_NAME, SH_ID);
    }
}
;

create procedure ods_current_ver ()
{
  return '25';
};

create procedure ods_sioc_init ()
{
  registry_set ('__ods_sioc_version', ods_current_ver ());
  --if (registry_get ('__ods_sioc_init') = registry_get ('__ods_sioc_version'))
  if (isstring (registry_get ('__ods_sioc_init')))
    return;
  declare exit handler for sqlstate '*'
    {
      __atomic (0);
      resignal;
    };
  __atomic (1);
  DB.DBA.TTLP (sioct_n3 (), '', get_graph() || '/inf');
  DB.DBA.RDFS_RULE_SET (get_graph (), get_graph() || '/inf');
  fill_ods_sioc (1);
  registry_set ('__ods_sioc_init', registry_get ('__ods_sioc_version'));
  __atomic (0);
  return;
};

create procedure ods_sioc_result (in iri_res any)
{
  declare rc int;
  rc := connection_get ('iri_result');
  if (rc = 1)
    result (iri_res);
  else if (rc = 2)
    registry_set ('ods_rdf_state', iri_res);
};

create procedure fill_ods_sioc_online (in doall int := 0, in iri_result int := 1)
{
  declare res_iri varchar;
  exec ('checkpoint');
  ods_sioc_version_reset ();
  if (iri_result = 1)
    result_names (res_iri);
  connection_set ('iri_result', iri_result);
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (sioc_iri (''));
  DB.DBA.TTLP (sioct_n3 (), '', get_graph() || '/inf');
  fill_ods_sioc (doall);
  DB.DBA.RDFS_RULE_SET (get_graph (), get_graph() || '/inf');
  DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();
  registry_set ('__ods_sioc_version', ods_current_ver ());
  exec ('checkpoint');
};

create procedure fill_ods_sioc (in doall int := 0)
{
  declare iri, site_iri, graph_iri, sioc_version varchar;
  declare cpt, deadl, cnt int;

  declare exit handler for sqlstate '*', not found
    {
      --checkpoint_interval (cpt);
      log_enable (1);
      resignal;
    };

  cnt := 0;
  log_enable (2);

  --cpt := checkpoint_interval (0);

  site_iri  := get_graph ();
  graph_iri := get_graph ();

  -- delete all
  {
    deadl := 3;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
    };
    l0:
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (graph_iri);
    commit work;
    set isolation='committed';
    ods_graph_init ();
  }

  ods_ping_svc_init (graph_iri, site_iri);

  scot_tags_init ();

  -- init users
  {
    declare _u_name varchar;
    _u_name := '';
    deadl := 3;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l1;
    };
    l1:

  for select U_NAME, U_ID, U_E_MAIL, U_IS_ROLE, U_FULL_NAME
    from DB.DBA.SYS_USERS
	where U_NAME > _u_name and U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' do
    {
      -- sioc:Usergroup
      if (U_IS_ROLE)
	{
	  iri := user_group_iri (U_ID);
	  sioc_group (graph_iri, iri, U_NAME);
	}
      else -- sioc:User
	{
	  declare u_site_iri, person_iri any;
	  iri := user_iri (u_id);
	  if (iri is not null)
	    {
	      sioc_user (graph_iri, iri, U_NAME, U_E_MAIL, U_FULL_NAME);
	      person_iri := person_iri (iri);
	      u_site_iri := user_space_iri (U_NAME);
	      -- it should be one row.
	      for select WAUI_VISIBLE,
	                 WAUI_FIRST_NAME,
	                 WAUI_LAST_NAME,
	                 WAUI_TITLE,
           		     WAUI_GENDER,
           		     WAUI_ICQ,
           		     WAUI_MSN,
           		     WAUI_AIM,
           		     WAUI_YAHOO,
           		     WAUI_BIRTHDAY,
            		   WAUI_BORG,
            		   WAUI_HPHONE,
            		   WAUI_HMOBILE,
            		   WAUI_BPHONE,
            		   WAUI_LAT,
            		   WAUI_LNG,
            		   WAUI_WEBPAGE,
            		   WAUI_SITE_NAME,
            		   WAUI_PHOTO_URL,
            		   WAUI_BORG_HOMEPAGE,
            		   WAUI_RESUME,
            		   WAUI_INTERESTS,
            		   WAUI_INTEREST_TOPICS,
            		   WAUI_HCITY,
            		   WAUI_HSTATE,
            		   WAUI_HCOUNTRY,
            		   WAUI_FOAF,
            		   WAUI_BLAT,
            		   WAUI_BLNG,
            		   WAUI_LATLNG_HBDEF,
            		   WAUI_SKYPE
		          from DB.DBA.WA_USER_INFO
		         where WAUI_U_ID = u_id do
		{
                  declare kwd any;
		  declare lat, lng real;

		  if (WAUI_LATLNG_HBDEF)
		    {
		      lat := WAUI_BLAT;
		      lng :=  WAUI_BLNG;
		    }
		  else
		    {
		      lat := WAUI_LAT;
		      lng :=  WAUI_LNG;
		    }

		  if (WAUI_SITE_NAME is not null)
		    DB.DBA.RDF_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), WAUI_SITE_NAME);

		  sioc_user_info (graph_iri,
		                  iri,
		                  WAUI_VISIBLE,
		                  WAUI_FIRST_NAME,
		                  WAUI_LAST_NAME,
		                  WAUI_TITLE,
		                  U_FULL_NAME,
		                  WAUI_GENDER,
		                  WAUI_ICQ,
		                  WAUI_MSN,
		                  WAUI_AIM,
		                  WAUI_YAHOO,
		                  WAUI_BIRTHDAY,
		                  WAUI_BORG,
	              	    case when length (WAUI_HPHONE) then WAUI_HPHONE when length (WAUI_HMOBILE) then WAUI_HMOBILE else WAUI_BPHONE end,
			lat,
			lng,
			WAUI_WEBPAGE,
			WAUI_PHOTO_URL,
			WAUI_BORG_HOMEPAGE,
			WAUI_RESUME,
			WAUI_INTERESTS,
                			WAUI_INTEREST_TOPICS,
			WAUI_HCITY,
			WAUI_HSTATE,
			WAUI_HCOUNTRY,
			WAUI_FOAF,
			WAUI_LATLNG_HBDEF
			);
		  kwd := DB.DBA.WA_USER_TAG_GET (U_NAME);
		  if (length (kwd))
		    DB.DBA.RDF_QUAD_URI_L (graph_iri, person_iri, bio_iri ('keywords'), kwd);
		  for select WUP_NAME, WUP_URL, WUP_DESC, WUP_IRI from DB.DBA.WA_USER_PROJECTS where WUP_U_ID = U_ID do
		    {
		      sioc_user_project (graph_iri, iri, WUP_NAME, WUP_URL, WUP_DESC, WUP_IRI);
		    }
		  for select WUO_NAME, WUO_URL from DB.DBA.WA_USER_OL_ACCOUNTS where WUO_U_ID = U_ID do
		    {
		      sioc_user_account (graph_iri, iri, WUO_NAME, WUO_URL);
		    }
		  for select WUR_LABEL, WUR_SEEALSO_IRI, WUR_P_IRI from DB.DBA.WA_USER_RELATED_RES where WUR_U_ID = U_ID do
		    {
		      sioc_user_related (graph_iri, iri, WUR_LABEL, WUR_SEEALSO_IRI, WUR_P_IRI);
		    }
		  if (length (WAUI_SKYPE))
		    sioc_user_account (graph_iri, iri, WAUI_SKYPE, 'skype:'||WAUI_SKYPE||'?chat');
		}


	      for select WAI_NAME, WAI_TYPE_NAME, WAI_ID, WAM_USER
		    from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
		   where WAM_USER = U_ID and WAM_INST = WAI_NAME and ((WAI_IS_PUBLIC = 1) or (WAI_TYPE_NAME = 'oDrive')) do
		{
		  declare riri, firi, _wai_type varchar;
		  _wai_type := WAI_TYPE_NAME;
		  do_social:
		  riri := role_iri (WAI_ID, WAM_USER);
		  firi := forum_iri (_wai_type, WAI_NAME);
		  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_function'), riri);
		  DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('function_of'), iri);

		  DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
		  DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('scope_of'), riri);

		  if (riri like '%#owner')
		    {
		      DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('has_owner'), iri);
		      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('owner_of'), firi);
		    }

		  if (_wai_type = 'AddressBook')
		    {
		      _wai_type := 'SocialNetwork';
		      goto do_social;
		    }
		  if (_wai_type = 'Community')
		    {
		      DB.DBA.RDF_QUAD_URI (graph_iri, group_iri (firi), foaf_iri ('member'), person_iri);
		    }
		  for select RA_URI, RA_LABEL from DB.DBA.WA_RELATED_APPS where RA_WAI_ID = WAI_ID do
		    {
		      sioc_app_related (graph_iri, firi, RA_LABEL, RA_URI);
		    }
		}
	      for select US_IRI, US_KEY from DB.DBA.WA_USER_SVC where US_U_ID = U_ID and length (US_IRI) do
		{
		  declare sas_iri any;
		  sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), US_IRI);
		  if (length (US_KEY))
		    sas_iri := sas_iri || sprintf ('&login=%U', U_NAME);
		  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
		}
	    }
	}
      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
	{
	  commit work;
	  _u_name := U_NAME;
	}
    }
    commit work;
  }

  {
    declare _gi_super, _gi_sub any;

    _gi_super := _gi_sub := -1;
    deadl := 3;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l2;
    };
    l2:

  -- sioc:member_of
  for select GI_SUB, GI_SUPER from DB.DBA.SYS_ROLE_GRANTS
    where GI_SUPER > _gi_super and GI_SUB > _gi_sub and GI_DIRECT = 1 do
    {
      declare g_iri varchar;
      iri := user_iri (GI_SUPER);
      g_iri := user_group_iri (GI_SUB);
      if (iri is not null and g_iri is not null)
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('member_of'), g_iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, g_iri, sioc_iri ('has_member'), iri);
        }
      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
	{
	  commit work;
	  _gi_super := GI_SUPER;
	  _gi_sub := GI_SUB;
	}
    }
    commit work;
  }

  {
    declare _from, _to, _serial any;
    _from := _to := _serial := -1;
    deadl := 3;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l3;
    };
    l3:
  -- sioc:knows
  for select snr_from, snr_to, snr_serial from DB.DBA.sn_related
    where snr_from > _from and snr_to > _to and snr_serial > _serial do
    {
      declare _from_iri, _to_iri varchar;
      _from_iri := user_iri_ent (snr_from);
      _to_iri := user_iri_ent (snr_to);
      sioc_knows (graph_iri, _from_iri, _to_iri);
      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
	{
	  commit work;
	  _from := snr_from;
	  _to := snr_to;
	  _serial := snr_serial;
	}
    }
    commit work;
  }

  {
    declare _wai_name varchar;
    _wai_name := '';
    deadl := 3;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l4;
    };
    l4:

  -- sioc:Forum
  for select WAI_TYPE_NAME, WAI_ID, WAI_NAME, WAI_DESCRIPTION, WAI_LICENSE from DB.DBA.WA_INSTANCE
    where WAI_NAME > _wai_name and WAI_IS_PUBLIC = 1 or WAI_TYPE_NAME = 'oDrive' do
    {
      iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      if (iri is not null)
	{
	  sioc_forum (graph_iri, site_iri, iri, WAI_NAME, WAI_TYPE_NAME, WAI_DESCRIPTION, WAI_ID);
	  cc_work_lic (graph_iri, iri, WAI_LICENSE);

	  --for select WAM_USER from DB.DBA.WA_MEMBER where WAM_INST = WAI_NAME do
	  --  {
	  --    declare miri varchar;
	  --    miri := user_iri (WAM_USER);
	  --    if (miri is not null)
	  --      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_member'), miri);
	  --  }
	}
      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
	{
	  commit work;
	  _wai_name := WAI_NAME;
	}
    }
    commit work;
  }

  if (doall)
    {
      sioc_version := registry_get ('__ods_sioc_version');
      for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES
	--where 0 = 1
	do
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

  commit work;
  ods_sioc_result ('The RDF data is reloaded');
  --checkpoint_interval (cpt);
  log_enable (1);
  return;
};

create procedure ods_sioc_version_reset (in ver any := '0')
{
  registry_set ('__ods_sioc_init', ver);
  for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES do
    {
      declare p_name varchar;
      p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc', suffix);
      if (__proc_exists (p_name))
	{
	  registry_set (sprintf('__ods_%s_sioc_init', suffix), ver);
	}
    }
  if (__proc_exists ('sioc..fill_ods_nntp_sioc'))
    {
      registry_set ('__ods_nntp_sioc_init', ver);
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
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), (RES_CR_TIME));
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('modified') , (RES_MOD_TIME));
	    }
         commit work;
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

create procedure delete_quad_po (in _g any, in _p any, in _o any)
{
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _p := DB.DBA.RDF_IID_OF_QNAME (_p);
  if (_g is null or _o is null or _p is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and O = _o and P = _p;
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
  delete from DB.DBA.RDF_QUAD where G = _g and O = _o;

  -- not valid if index is OGPS
  --preds := all_predicates ();
  --foreach (any pred in preds) do
  --  {
  --    pred := DB.DBA.RDF_IID_OF_QNAME (pred);
  --    if (pred is not null)
  --      delete from DB.DBA.RDF_QUAD where P = pred and G = _g and O = _o;
  --  }
};

create procedure update_quad_s_o (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null or _n = _o)
    return;
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set S = _n where G = _g and S = _o;
  update DB.DBA.RDF_QUAD set O = _n where G = _g and O = _o;
};

create procedure update_quad_p (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null or _n = _o)
    return;
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set P = _n where G = _g and P = _o;
};

create procedure sioc_log_message (in msg varchar)
{
--  dbg_obj_princ ('sioc_log_message: ', msg);
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

--  dbg_obj_print ('row_cnt:',row_count(1), row_count());
  if (not row_count(1))
    return;

  graph_iri := get_graph ();

  if (N.U_ACCOUNT_DISABLED = 1)
    return;
  iri := user_obj_iri (N.U_NAME);
  delete_quad_s_or_o (graph_iri, iri, iri);
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

	  iri := person_iri (iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (N.U_E_MAIL));
	  if (length (N.U_FULL_NAME))
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
  u_site_iri := user_space_iri (uname);
  if (N.WAUI_SITE_NAME is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), N.WAUI_SITE_NAME);
  sioc_user_info (graph_iri, iri, N.WAUI_VISIBLE, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME);
  return;
};

create trigger WA_USER_INFO_SIOC_U after update on DB.DBA.WA_USER_INFO referencing old as O, new as N
{
  declare iri, graph_iri, u_site_iri, uname, niri, del_iri varchar;
  declare lat, lng real;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  --sioc_user_info (graph_iri, iri, N.WAUI_VISIBLE, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME);
  uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WAUI_U_ID);
  u_site_iri := user_space_iri (uname);
  delete_quad_sp (graph_iri, u_site_iri, dc_iri ('title'));
  if (N.WAUI_SITE_NAME is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), N.WAUI_SITE_NAME);
  if (N.WAUI_LATLNG_HBDEF)
    {
      lat := N.WAUI_BLAT;
      lng :=  N.WAUI_BLNG;
    }
  else
    {
      lat := N.WAUI_LAT;
      lng :=  N.WAUI_LNG;
    }
  niri := person_iri (iri, tp=>N.WAUI_IS_ORG);
  if (O.WAUI_IS_ORG <> N.WAUI_IS_ORG)
    {
      declare oiri any;
      oiri := person_iri (iri, tp=>O.WAUI_IS_ORG);
      update_quad_s_o (graph_iri, oiri, niri);
      if (N.WAUI_IS_ORG)
	{
          update DB.DBA.RDF_QUAD set O = iri_to_id (foaf_iri ('Organization')) where
	    G = iri_to_id (graph_iri) and S = iri_to_id (niri) and P = iri_to_id (rdf_iri ('type'))
	    and O = iri_to_id (foaf_iri ('Person'));
	}
      else
	{
          update DB.DBA.RDF_QUAD set O = iri_to_id (foaf_iri ('Person')) where
	    G = iri_to_id (graph_iri) and S = iri_to_id (niri) and P = iri_to_id (rdf_iri ('type'))
	    and O = iri_to_id (foaf_iri ('Organization'));
	}
    }
  sioc_user_info (graph_iri,
                  iri,
                  N.WAUI_VISIBLE,
                  N.WAUI_FIRST_NAME,
                  N.WAUI_LAST_NAME,
        		      N.WAUI_TITLE,
        		      null,
        		      N.WAUI_GENDER,
        		      N.WAUI_ICQ,
        		      N.WAUI_MSN,
        		      N.WAUI_AIM,
        		      N.WAUI_YAHOO,
        		      N.WAUI_BIRTHDAY,
        		      N.WAUI_BORG,
        	        case when length (N.WAUI_HPHONE) then N.WAUI_HPHONE when length (N.WAUI_HMOBILE) then N.WAUI_HMOBILE else N.WAUI_BPHONE end,
			lat,
			lng,
			N.WAUI_WEBPAGE,
			N.WAUI_PHOTO_URL,
			N.WAUI_BORG_HOMEPAGE,
			N.WAUI_RESUME,
			N.WAUI_INTERESTS,
            			N.WAUI_INTEREST_TOPICS,
			N.WAUI_HCITY,
			N.WAUI_HSTATE,
			N.WAUI_HCOUNTRY,
			N.WAUI_FOAF,
			N.WAUI_LATLNG_HBDEF
			);
  for select US_IRI, US_KEY from DB.DBA.WA_USER_SVC where US_U_ID = N.WAUI_U_ID and length (US_IRI) do
    {
      declare sas_iri any;
      sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), US_IRI);
      if (length (US_KEY))
	sas_iri := sas_iri || sprintf ('&login=%U', uname);
	DB.DBA.RDF_QUAD_URI (graph_iri, niri, owl_iri ('sameAs'), sas_iri);
    }
  if (length (O.WAUI_SKYPE))
    {
      del_iri := person_ola_iri (iri, O.WAUI_SKYPE);
      delete_quad_s_or_o (graph_iri, del_iri, del_iri);
    }
  if (length (N.WAUI_SKYPE))
    sioc_user_account (graph_iri, iri, N.WAUI_SKYPE, 'skype:'||N.WAUI_SKYPE||'?chat');
  return;
};

create trigger WA_USER_PROJECT_SIOC_I after insert on DB.DBA.WA_USER_PROJECTS referencing new as N
{
  declare graph_iri, iri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.WUP_U_ID);
  sioc_user_project (graph_iri, iri, N.WUP_NAME, N.WUP_URL, N.WUP_DESC, N.WUP_IRI);
};

create trigger WA_USER_PROJECT_SIOC_U after update on DB.DBA.WA_USER_PROJECTS referencing old as O, new as N
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.WUP_U_ID);
  opiri := coalesce (O.WUP_IRI, person_prj_iri (iri, O.WUP_NAME));
  delete_quad_s_or_o (graph_iri, opiri, opiri);
  sioc_user_project (graph_iri, iri, N.WUP_NAME, N.WUP_URL, N.WUP_DESC, N.WUP_IRI);
};

create trigger WA_USER_PROJECT_SIOC_D after delete on DB.DBA.WA_USER_PROJECTS referencing old as O
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (O.WUP_U_ID);
  opiri := coalesce (O.WUP_IRI, person_prj_iri (iri, O.WUP_NAME));
  delete_quad_s_or_o (graph_iri, opiri, opiri);
};

create trigger WA_USER_OL_ACCOUNTS_SIOC_I after insert on DB.DBA.WA_USER_OL_ACCOUNTS referencing new as N
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.WUO_U_ID);
  sioc_user_account (graph_iri, iri, N.WUO_NAME, N.WUO_URL);
};

create trigger WA_USER_OL_ACCOUNTS_SIOC_U after update on DB.DBA.WA_USER_OL_ACCOUNTS referencing old as O, new as N
{
  declare graph_iri, iri, opiri, del_iri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.WUO_U_ID);
  del_iri := person_ola_iri (iri, O.WUO_NAME);
  delete_quad_s_or_o (graph_iri, del_iri, del_iri);
  sioc_user_account (graph_iri, iri, N.WUO_NAME, N.WUO_URL);
};

create trigger WA_USER_OL_ACCOUNTS_SIOC_D after delete on DB.DBA.WA_USER_OL_ACCOUNTS referencing old as O
{
  declare graph_iri, iri, opiri, del_iri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (O.WUO_U_ID);
  del_iri := person_ola_iri (iri, O.WUO_NAME);
  delete_quad_s_or_o (graph_iri, del_iri, del_iri);
};

-- Related
create trigger WA_USER_RELATED_RES_SIOC_I after insert on DB.DBA.WA_USER_RELATED_RES referencing new as N
{
  declare graph_iri, iri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.WUR_U_ID);
  sioc_user_related (graph_iri, iri, N.WUR_LABEL, N.WUR_SEEALSO_IRI, N.WUR_P_IRI);
};

create trigger WA_USER_RELATED_RES_SIOC_U after update on DB.DBA.WA_USER_RELATED_RES referencing old as O, new as N
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.WUR_U_ID);
  opiri := O.WUR_SEEALSO_IRI;
  delete_quad_s_or_o (graph_iri, opiri, opiri);
  sioc_user_related (graph_iri, iri, N.WUR_LABEL, N.WUR_SEEALSO_IRI, N.WUR_P_IRI);
};

create trigger WA_USER_RELATED_RES_SIOC_D after delete on DB.DBA.WA_USER_RELATED_RES referencing old as O
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (O.WUR_U_ID);
  opiri := O.WUR_SEEALSO_IRI;
  delete_quad_s_or_o (graph_iri, opiri, opiri);
};

-- Related Apps
create trigger WA_RELATED_APPS_SIOC_I after insert on DB.DBA.WA_RELATED_APPS referencing new as N
{
  declare graph_iri, iri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = N.RA_WAI_ID do
    {
      iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      sioc_app_related (graph_iri, iri, N.RA_LABEL, N.RA_URI);
    }
};

create trigger WA_RELATED_APPS_SIOC_U after update on DB.DBA.WA_RELATED_APPS referencing old as O, new as N
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = N.RA_WAI_ID do
    {
      iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      opiri := O.RA_URI;
      delete_quad_s_or_o (graph_iri, opiri, opiri);
      sioc_app_related (graph_iri, iri, N.RA_LABEL, N.RA_URI);
    }
};

create trigger WA_RELATED_APPS_SIOC_D after delete on DB.DBA.WA_RELATED_APPS referencing old as O
{
  declare graph_iri, iri, opiri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  graph_iri := get_graph ();
  for select WAI_TYPE_NAME, WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = O.RA_WAI_ID do
    {
      iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      opiri := O.RA_URI;
      delete_quad_s_or_o (graph_iri, opiri, opiri);
    }
};




-- DB.DBA.WA_MEMBER
create trigger WA_MEMBER_SIOC_I after insert on DB.DBA.WA_MEMBER referencing new as N
{
  declare iri, graph_iri, riri, firi, site_iri, svc_iri varchar;
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
      -- add services here
      if (N.WAM_APP_TYPE = 'oDrive')
	{
	  svc_iri := sprintf ('http://%s%s/services/briefcase', get_cname(), get_base_path ());
	  ods_sioc_service (graph_iri, svc_iri, iri, null, 'text/xml', svc_iri||'/services.wsdl', svc_iri, 'SOAP');
	}
    }
  declare _wai_type varchar;
  _wai_type := N.WAM_APP_TYPE;

  iri :=  user_iri (N.WAM_USER);
  riri := role_iri_by_name (N.WAM_INST, N.WAM_USER);
  do_social:
  firi := forum_iri (_wai_type, N.WAM_INST);
  if (iri is not null and riri is not null and firi is not null and ((N.WAM_IS_PUBLIC = 1) or (N.WAM_APP_TYPE = 'oDrive')))
    {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_function'), riri);
      DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('function_of'), iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
      DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('scope_of'), riri);
      if (riri like '%#owner')
	{
	  DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('has_owner'), iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('owner_of'), firi);
	}
      if (N.WAM_APP_TYPE = 'Community')
	{
	  declare person_iri any;
	  person_iri := person_iri (iri);
	  DB.DBA.RDF_QUAD_URI (graph_iri, group_iri (firi), foaf_iri ('member'), person_iri);
	}
      --DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('has_member'), iri);
    }
  if (_wai_type = 'AddressBook')
    {
      _wai_type := 'SocialNetwork';
      goto do_social;
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
--  dbg_obj_print (iri, riri);
  if (iri is not null and riri is not null)
    {
      delete_quad_s_or_o (graph_iri, riri, riri);
    }
  if (O.WAM_APP_TYPE = 'Community')
    {
      declare person_iri any;
      person_iri := person_iri (iri);
      delete_quad_po (graph_iri, foaf_iri ('member'), person_iri);
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

  if (N.WAI_TYPE_NAME = 'Community')
    {
      declare giri any;
      giri := group_iri (iri);
      delete_quad_sp (graph_iri, giri, foaf_iri ('name'));
    }

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
      sioc_forum (graph_iri, site_iri, iri, N.WAI_NAME, N.WAI_TYPE_NAME, N.WAI_DESCRIPTION, N.WAI_ID);
      cc_work_lic (graph_iri, iri, N.WAI_LICENSE);
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
      delete_quad_sp (graph_iri, oiri, cc_iri ('license'));
      cc_work_lic (graph_iri, iri, N.WAI_LICENSE);

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
  if (not row_count())
    return;
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
  _from_iri := person_iri (user_iri_ent (O.snr_from));
  _to_iri := person_iri (user_iri_ent (O.snr_to));
  delete_quad_s_p_o (graph_iri, _from_iri, foaf_iri ('knows'), _to_iri);
  delete_quad_s_p_o (graph_iri, _to_iri, foaf_iri ('knows'), _from_iri);
  return;
};

create trigger WA_USER_SVC_I after insert on DB.DBA.WA_USER_SVC referencing new as N
{
  declare sas_iri, graph_iri, person_iri, iri, uname any;

  if (not length (N.US_IRI))
    return;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.US_U_ID);
  iri := user_obj_iri (uname);
  person_iri := person_iri (iri);
  sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), N.US_IRI);
  if (length (N.US_KEY))
    sas_iri := sas_iri || sprintf ('&login=%U', uname);
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
}
;

create trigger WA_USER_SVC_U after update on DB.DBA.WA_USER_SVC referencing old as O, new as N
{
  declare sas_iri, graph_iri, person_iri, iri, uname any;

  if (not length (N.US_IRI))
    return;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.US_U_ID);
  iri := user_obj_iri (uname);
  person_iri := person_iri (iri);

  if (length (O.US_IRI))
    {
      sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), O.US_IRI);
      if (length (O.US_KEY))
	sas_iri := sas_iri || sprintf ('&login=%U', uname);
	delete_quad_s_p_o (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
    }

  sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), N.US_IRI);
  if (length (N.US_KEY))
    sas_iri := sas_iri || sprintf ('&login=%U', uname);
  DB.DBA.RDF_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
}
;

create trigger WA_USER_SVC_D after delete on DB.DBA.WA_USER_SVC referencing old as O
{
  declare sas_iri, graph_iri, person_iri, iri, uname any;

  if (not length (O.US_IRI))
    return;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = O.US_U_ID);
  iri := user_obj_iri (uname);
  person_iri := person_iri (iri);
  sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), O.US_IRI);
  if (length (O.US_KEY))
    sas_iri := sas_iri || sprintf ('&login=%U', uname);
  delete_quad_s_p_o (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
}
;

create function std_pref (in iri varchar, in rev int := 0)
{
  declare v any;
  v := vector (
  'http://xmlns.com/foaf/0.1/', 'foaf',
  'http://rdfs.org/sioc/ns#', 'sioc',
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf',
  'http://www.w3.org/2000/01/rdf-schema#', 'rdfs',
  'http://www.w3.org/2003/01/geo/wgs84_pos#', 'geo',
  'http://atomowl.org/ontologies/atomrdf#', 'aowl',
  'http://purl.org/dc/elements/1.1/', 'dc',
  'http://purl.org/dc/terms/', 'dct',
  'http://www.w3.org/2004/02/skos/core#', 'skos',
  'http://rdfs.org/sioc/types#', 'sioct',
  'http://sw.deri.org/2005/04/wikipedia/wikiont.owl#', 'wiki',
  'http://www.w3.org/2002/01/bookmark#', 'bm',
  'http://www.w3.org/2003/12/exif/ns/', 'exif',
  'http://www.w3.org/2000/10/annotation-ns#', 'ann',
  'http://vocab.org/bio/0.1/', 'bio',
  'http://www.w3.org/2001/vcard-rdf/3.0#', 'vcard',
  'http://www.w3.org/2002/12/cal#', 'vcal',
  'http://www.w3.org/2002/07/owl#', 'owl',
  'http://web.resource.org/cc/', 'cc'

  );
  if (rev)
    {
      declare nv, l any;
      nv := make_array (length (v), 'any');
      for (declare i, j int, j := 0, i := length (v) - 1; i >= 0; i := i - 2, j := j + 2)
        {
	   nv[j] := v[i];
	   nv[j+1] := v[i-1];
	}
      return get_keyword (iri, nv, null);
    }
  else
   return get_keyword (iri, v, null);
};

create procedure is_defined_by (in uname varchar, in cls varchar, in iri varchar, in lab varchar)
{
  declare res any;
  declare pref, tit, tmp varchar;
  declare pos, p1, p2, p3 int;
  p1 := coalesce (strrchr (cls, '#'), -1);
  p2 := coalesce (strrchr (cls, '/'), -1);
  p3 := coalesce (strrchr (cls, ':'), -1);
  pos := __max (p1, p2, p3);
  if (pos > 0)
    {
      tit := subseq (CLS, pos + 1);
      tmp := subseq (CLS, 0, pos + 1);
      pref := std_pref (tmp);
      if (pref is not null)
	tit := pref || ':' || tit;
      else
        tit := cls;
    }
  else
    tit := cls;
  tit := replace (tit, '/', '^2f');
  if (lab is null)
    lab := '~unnamed~';
  res := sprintf ('/DAV/home/%U/RDFData/%U/%U%%20(%d).rdf', uname, tit, lab, iri_id_num (iri_to_id (iri)));
  return db.dba.wa_link (1, res);
};

create procedure cls_short_print (in cls varchar)
{
  declare res any;
  declare pref, tit, tmp varchar;
  declare pos, p1, p2, p3 int;
  p1 := coalesce (strrchr (cls, '#'), -1);
  p2 := coalesce (strrchr (cls, '/'), -1);
  p3 := coalesce (strrchr (cls, ':'), -1);
  pos := __max (p1, p2, p3);
  if (pos > 0)
    {
      tit := subseq (CLS, pos + 1);
      tmp := subseq (CLS, 0, pos + 1);
      pref := std_pref (tmp);
      if (pref is not null)
	tit := pref || ':' || tit;
      else
        tit := cls;
    }
  else
    tit := cls;
  tit := replace (tit, '/', '^2f');
  return tit;
};

create procedure rdf_head (inout ses any)
{
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">', ses);
};

create procedure rdf_tail (inout ses any)
{
  http ('</rdf:RDF>', ses);
};

create procedure ods_rdf_describe (in path varchar, in fmt varchar, in is_foaf int)
{
  declare iri, ses any;
  declare qr, stat, msg, accept any;
  declare rset, metas any;

  if (fmt = 'TTL')
    accept := 'text/rdf+n3';
  else
    accept := '';
  iri := 'http://'||get_cname()||path;
  qr := sprintf ('SPARQL DESCRIBE <%s> FROM <%s>', iri, get_graph ());
--  dbg_printf ('%s', qr);
  stat := '00000';
  set_user_id ('SPARQL');
  exec (qr, stat, msg, vector (), 0, metas, rset);
  if (stat = '00000')
    {
      ses := string_output ();
      DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);
    }
  else
    signal (stat, msg);
  return ses;
}
;

create procedure gen_cc_xml ()
{
  declare ses any;
  ses := string_output ();
  http ('<?xml version="1.0"?>\n', ses);
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:cc="http://web.resource.org/cc/" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/by-nd/1.0/">\n', ses);
  http ('    <rdfs:label>Attribution-NoDerivs 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/by/1.0/">\n', ses);
  http ('    <rdfs:label>Attribution 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/by-nd-nc/1.0/">\n', ses);
  http ('    <rdfs:label>Attribution-NoDerivs-NonCommercial 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>\n', ses);
  http ('    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/by-nc/1.0/">\n', ses);
  http ('    <rdfs:label>Attribution-NonCommercial 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>\n', ses);
  http ('    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/by-nc-sa/1.0/">\n', ses);
  http ('    <rdfs:label>Attribution-NonCommercial-ShareAlike 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>\n', ses);
  http ('    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/by-sa/1.0/">\n', ses);
  http ('    <rdfs:label>Attribution-ShareAlike 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/nd/1.0/">\n', ses);
  http ('    <rdfs:label>NoDerivs 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/nd-nc/1.0/">\n', ses);
  http ('    <rdfs:label>NoDerivs-NonCommercial 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/nc/1.0/">\n', ses);
  http ('    <rdfs:label>NonCommercial 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/nc-sa/1.0/">\n', ses);
  http ('    <rdfs:label>NonCommercial-ShareAlike 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>\n', ses);
  http ('    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('  <cc:License rdf:about="http://creativecommons.org/licenses/sa/1.0/">\n', ses);
  http ('    <rdfs:label>ShareAlike 1.0</rdfs:label>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>\n', ses);
  http ('    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>\n', ses);
  http ('    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>\n', ses);
  http ('  </cc:License>\n', ses);
  http ('</rdf:RDF>\n', ses);
  return xtree_doc (string_output_string (ses));
}
;

create procedure sioct_n3 ()
{
  declare ses any;
  ses := string_output ();
  http (' @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('<http://atomowl.org/ontologies/atomrdf#Feed> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://captsolo.net/semweb/resume/cv.rdfs#Resume> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://purl.org/dc/dcmitype/MovingImage> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://purl.org/dc/dcmitype/Sound> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://purl.org/ibis#Idea> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Community> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Container> rdfs:subClassOf <http://rdfs.org/sioc/ns#Space> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Forum> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Item> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Post> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Role> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Service> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Site> rdfs:subClassOf <http://rdfs.org/sioc/ns#Space> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Space> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#User> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/ns#Usergroup> rdfs:subClassOf <http://www.w3.org/2000/01/rdf-schema#Resource> .\n', ses);
  http ('<http://rdfs.org/sioc/types#AddressBook> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#AnnotationSet> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#ArgumentativeDiscussion> rdfs:subClassOf <http://rdfs.org/sioc/ns#Forum> .\n', ses);
  http ('<http://rdfs.org/sioc/types#AudioChannel> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#BlogPost> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://rdfs.org/sioc/types#BoardPost> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://rdfs.org/sioc/types#BookmarkFolder> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Briefcase> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#ChatChannel> rdfs:subClassOf <http://rdfs.org/sioc/ns#Forum> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Comment> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://rdfs.org/sioc/types#EventCalendar> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#ImageGallery> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#InstantMessage> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://rdfs.org/sioc/types#MailMessage> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://rdfs.org/sioc/types#MailingList> rdfs:subClassOf <http://rdfs.org/sioc/ns#Forum> .\n', ses);
  http ('<http://rdfs.org/sioc/types#MessageBoard> rdfs:subClassOf <http://rdfs.org/sioc/ns#Forum> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Poll> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://rdfs.org/sioc/types#ProjectDirectory> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#ResumeBank> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#ReviewArea> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#SubscriptionList> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#SurveyCollection> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Thread> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#VideoChannel> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Weblog> rdfs:subClassOf <http://rdfs.org/sioc/ns#Forum> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Wiki> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://sw.deri.org/2005/04/wikipedia/wikiont.owl#Article> rdfs:subClassOf <http://rdfs.org/sioc/ns#Post> .\n', ses);
  http ('<http://usefulinc.com/ns/doap#Project> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://www.isi.edu/webscripter/communityreview/abstract-review-o#Review> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://www.w3.org/2000/10/annotation-ns#Annotation> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://www.w3.org/2002/01/bookmark#Bookmark> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://www.w3.org/2002/12/cal/icaltzd#VEVENT> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://www.w3.org/2003/12/exif/ns/IFD> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://xmlns.com/foaf/0.1/Agent> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  http ('<http://xmlns.com/foaf/0.1/Document> rdfs:subClassOf <http://rdfs.org/sioc/ns#Item> .\n', ses);
  return string_output_string (ses);
}
;

create procedure std_pref_declare ()
{
  return
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
   	 ' prefix sioct: <http://rdfs.org/sioc/types#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> \n'||
         ' prefix dct: <http://purl.org/dc/terms/> \n'||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' prefix vcard: <http://www.w3.org/2001/vcard-rdf/3.0#> \n' ||
	 ' prefix owl: <http://www.w3.org/2002/07/owl#> \n' ||
	 ' prefix wiki: <http://sw.deri.org/2005/04/wikipedia/wikiont.owl#> \n' ||
	 ' prefix bm: <http://www.w3.org/2002/01/bookmark#> \n' ||
	 ' prefix vcal: <http://www.w3.org/2002/12/cal#> \n' ||
         ' prefix bio: <http://vocab.org/bio/0.1/> \n' ;
};

create procedure compose_foaf (in u_name varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare state, decl, qry, qrs, msg, maxrows, metas, rset, graph, iri, accept, part any;
  declare ses, dociri any;
  declare triples any;
  declare ss, sa_dict, lim, offs any;
  declare pers_iri, http_hdr varchar;

  -- dbg_obj_print (u_name,wai_name,inst_type,postid);
  set http_charset='utf-8';
  graph := get_graph ();
  ses := string_output ();

  if (fmt = 'text/rdf+n3')
    fmt := 'n3';
  else if (fmt = 'application/rdf+xml')
    fmt := 'rdf';

  dociri := person_iri (user_obj_iri(u_name), '');
  pers_iri := person_iri (user_obj_iri(u_name));

  if (fmt not in ('n3', 'ttl', 'rdf'))
    fmt := 'rdf';

  if (fmt = 'n3' or fmt = 'ttl')
    accept := 'text/rdf+n3';
  else
    accept := 'application/rdf+xml';

  lim := coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
  offs := coalesce (p, 0) * lim;

  http_hdr := http_header_get ();
  if (strcasestr (http_hdr, 'Content-Type:') is null)
    http_header (http_hdr || sprintf ('Content-Type: %s; charset=UTF-8\r\n', accept));

  if (fmt = 'rdf')
    rdf_head (ses);

  qrs := make_array (6, 'any');
  iri := user_obj_iri (u_name);

  decl := 'sparql '
         --' define input:inference <' || graph || '>' ||
	  || std_pref_declare ();

  part := sprintf (
	  ' CONSTRUCT {
	    ?person a ?type .
	    ?person foaf:nick ?nick .
	    ?person foaf:mbox ?mbox .
	    ?person foaf:mbox_sha1sum ?sha1 .
	    ?person foaf:name ?full_name .
	    ?person foaf:holdsAccount ?sioc_user .
	    ?person rdfs:seeAlso ?pers_see_also .
	    ?sioc_user rdfs:seeAlso ?see_also .
	    ?sioc_user a sioc:User .
	    ?person foaf:firstName ?fn .
	    ?person foaf:family_name ?ln .
	    ?person foaf:gender ?gender .
	    ?person foaf:icqChatID ?icq .
	    ?person foaf:msnChatID ?msn .
	    ?person foaf:aimChatID ?aim .
	    ?person foaf:yahooChatID ?yahoo .
	    ?person foaf:birthday ?birthday .
	    ?person foaf:phone ?phone .
	    ?person foaf:based_near ?geo .
	    ?geo ?geo_pred ?geo_subj .
	    ?person foaf:knows ?friend .
	    ?friend rdfs:seeAlso ?f_see_also .
	    ?friend rdf:type ?friend_type .
	    ?friend foaf:nick ?f_nick .
	    ?friend foaf:name ?f_name .
	    <%s> a foaf:PersonalProfileDocument .
	    <%s> foaf:primaryTopic ?person .
	    <%s> foaf:maker ?person .
	    <%s> dc:title `bif:concat (?full_name, "\'s FOAF file")` .
	    ?person foaf:workplaceHomepage ?wphome .
	    ?org foaf:homepage ?wphome .
	    ?org rdf:type foaf:Organization .
	    ?org dc:title ?orgtit .
	    ?person foaf:depiction ?depiction .
	    ?person foaf:homepage ?homepage .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
	      ?person foaf:holdsAccount <%s/%s#this> ;
	      rdf:type ?type ;
	      foaf:nick ?nick ;
	      foaf:holdsAccount ?sioc_user .
	      optional { ?person rdfs:seeAlso ?pers_see_also . } .
	      optional { ?sioc_user rdfs:seeAlso ?see_also . } .
	      optional { ?person foaf:mbox ?mbox ; foaf:mbox_sha1sum ?sha1 . } .
	      optional {
			optional { ?person foaf:knows ?friend } .
			optional { ?friend rdfs:seeAlso ?f_see_also } .
			optional { ?friend foaf:nick ?f_nick } .
			optional { ?friend rdf:type ?friend_type } .
			optional { ?friend foaf:name ?f_name . }
	      	       } .
	      optional { ?person foaf:name ?full_name } .
	      optional { ?person foaf:firstName ?fn } .
	      optional { ?person foaf:family_name ?ln } .
	      optional { ?person foaf:gender ?gender } .
	      optional { ?person foaf:icqChatID ?icq } .
	      optional { ?person foaf:msnChatID ?msn } .
	      optional { ?person foaf:aimChatID ?aim } .
	      optional { ?person foaf:yahooChatID ?yahoo } .
	      optional { ?person foaf:birthday ?birthday } .
	      optional { ?person foaf:phone ?phone } .
	      optional { ?person foaf:based_near ?geo . ?geo ?geo_pred ?geo_subj } .
	      optional { ?person foaf:workplaceHomepage ?wphome } .
	      optional { ?org foaf:homepage ?wphome . ?org a foaf:Organization ; dc:title ?orgtit . } .
	      optional { ?person foaf:depiction ?depiction } .
	      optional { ?person foaf:homepage ?homepage } .
	      }
	    }
	  }',
	  dociri, dociri, dociri, dociri,
	  graph, graph, u_name);

  qry := decl || part;
  qrs [0] := qry;
  if (p <> 0) qrs [0] := null;

  declare vars, cons, uname varchar;
  declare ix int;
  vars := '';
  cons := '';
  uname := u_name;
  ix := 0;

  for select distinct WUR_P_IRI as P_IRI from DB.DBA.WA_USER_RELATED_RES
    where WUR_U_ID = (select U_ID from DB.DBA.SYS_USERS u where u.U_NAME = uname ) do
    {
      vars := vars || sprintf ( 'optional { ?person <%s> ?var%d } .\n' , P_IRI, ix);
      cons := cons || sprintf (' ?person <%s> ?var%d . \n', P_IRI, ix );
      ix := ix + 1;
    }

  part := sprintf (
	  ' CONSTRUCT {
	    ?person foaf:openid ?oid .
	    ?person vcard:ADR ?adr .
	    ?adr vcard:Country ?country .
            ?adr vcard:Locality ?city .
	    ?adr vcard:Region ?state .
	    ?person bio:olb ?bio .
	    ?person bio:event ?event .
	    ?event rdf:type bio:Birth .
	    ?event dc:date ?bdate .
	    ?person bio:keywords ?keywords .
	    ?person owl:sameAs ?same_as .
	    ?person foaf:holdsAccount ?oa .
	    ?oa a foaf:OnlineAccount .
	    ?oa foaf:accountServiceHomepage ?ashp .
	    ?oa foaf:accountName ?an .
	    #?person foaf:made ?made .
	    #?made foaf:maker ?person .
	    #?made dc:title ?made_title .
            #?made a ?made_type . '
	    || cons ||
	    '
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
	      ?person foaf:holdsAccount <%s/%s#this> ;
	      foaf:openid ?oid .
	      optional { ?person bio:olb ?bio  } .
              optional { ?person bio:event ?event . ?event a bio:Birth ; dc:date ?bdate } .
	      optional { ?person vcard:ADR ?adr . ?adr vcard:Country ?country .
	        	optional { ?adr vcard:Locality ?city } .
			optional { ?adr vcard:Region ?state } .
	      	       } .
              optional { ?person bio:keywords ?keywords } .
	      optional { ?person owl:sameAs ?same_as } .
			 ?person foaf:holdsAccount ?oa .
	      optional {
		         ?oa foaf:accountServiceHomepage ?ashp ; foaf:accountName ?an
	      	       } .
              #optional { ?person foaf:made ?made . ?made dc:identifier ?ident . ?made dc:title ?made_title . optional { ?made a ?made_type . } } .
	      '
	      || vars ||
	      '
	      }
	    }
	  }', graph, graph, u_name);

  qry := decl || part;
  qrs [1] := qry;
  if (p <> 0) qrs [1] := null;

  part := sprintf (
	  ' CONSTRUCT {
	    ?person foaf:made ?made .
	    ?made foaf:maker ?person .
	    ?made dc:title ?made_title .
	    ?made a ?made_type .
	    ?person foaf:interest ?interest .
	    ?interest rdfs:label ?interest_label .
	    ?person foaf:topic_interest ?topic_interest .
	    ?topic_interest rdfs:label ?topic_interest_label .

	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
	      ?person foaf:holdsAccount <%s/%s#this> .
	      ?person foaf:made ?made . ?made dc:identifier ?ident . ?made dc:title ?made_title . optional { ?made a ?made_type . } .
	      optional { ?person foaf:interest ?interest } .
	      optional { ?interest rdfs:label ?interest_label  } .
	      optional { ?person foaf:topic_interest ?topic_interest } .
	      optional { ?topic_interest rdfs:label ?topic_interest_label  } .
	      }
	    }
	  }', graph, graph, u_name);

  qry := decl || part;
  qrs [5] := qry;
  if (p <> 0) qrs [5] := null;

  part := sprintf (
	  ' CONSTRUCT {
	    ?maker foaf:made ?forum .
	    ?forum foaf:maker ?maker .
#	    ?forum a ?forum_type .
	    ?forum rdfs:label ?label .
#	    ?forum rdfs:seeAlso ?see_also .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
                <%S> sioc:has_function ?function .
                ?function sioc:has_scope ?forum .
		?forum a ?forum_type .
		?forum foaf:maker ?maker .
		optional { ?forum rdfs:label ?label . }
		optional { ?forum rdfs:seeAlso ?see_also . }
	      }
	    }
	  }', graph, iri);

  qry := decl || part;
  qrs [2] := qry;
  if (p <> 0)
    qrs [2] := null;
  --qrs [2] := null;

  part := sprintf (
	  ' CONSTRUCT {
	    ?child_forum a ?forum_type .
	    ?forum sioc:parent_of ?child_forum .
	    ?child_forum sioc:has_parent ?forum .
	    ?child_forum rdfs:label ?label .
	    ?child_forum rdfs:seeAlso ?see_also .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
                <%S> sioc:has_function ?function .
                ?function sioc:has_scope ?forum .
		?forum sioc:parent_of ?child_forum .
		?child_forum a ?forum_type .
		optional { ?child_forum rdfs:label ?label . }
		optional { ?child_forum rdfs:seeAlso ?see_also . }
	      }
	    }
	  } LIMIT %d OFFSET %d', graph, iri, lim, offs);

  qry := decl || part;
  qrs [3] := qry;
  if (p <> 0)
    qrs [3] := null;
  -- disabled now
  qrs [3] := null;

  part := sprintf (
	  ' CONSTRUCT {
	  <%S> sioc:owner_of ?container .
	  ?container sioc:container_of ?item .
	  ?item a ?item_type .
	  ?item rdfs:label ?label .
          ?container sioc:container_of ?child_forum .
	  ?child_forum sioc:container_of ?item1 .
	  ?item1 a ?item_type1 .
	  ?item1 rdfs:label ?label1 .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
		<%S> sioc:owner_of ?container .
		optional
		{
		  ?container sioc:container_of ?item .
		  ?item a ?item_type .
		  optional { ?item rdfs:label ?label . }
		} .
		optional
		{
		  ?container sioc:container_of ?child_forum .
		  ?child_forum sioc:container_of ?item1 .
		  ?item1 a ?item_type1 .
		  optional { ?item1 rdfs:label ?label1 . }
		} .
	      }
	    }
	  } LIMIT %d OFFSET %d', iri, graph, iri, lim, offs);

  qry := decl || part;
  qrs [4] := qry;
  -- disabled now
  qrs [4] := null;


  set_user_id ('dba');
  foreach (any q in qrs) do
    {
      maxrows := 0;
      state := '00000';
      if (q is not null)
	{
--	  dbg_printf ('%s', q);
	  exec (q, state, msg, vector(), maxrows, metas, rset);
--	  dbg_obj_print (msg);
	  if (state <> '00000')
	    signal (state, msg);
	  if (fmt = 'rdf')
	    {
	      if ((1 = length (rset)) and (1 = length (rset[0])) and (214 = __tag (rset[0][0])))
		{
		  triples := dict_list_keys (rset[0][0], 1);
		  DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
		}
	    }
	  else
	    {
	      DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 0);
	    }
	}
    }

  if (0)
    {
      ss := string_output ();
      rdf_head (ss);
      http (sprintf ('<rdf:Description rdf:about="%s">', dociri), ss);
      http (sprintf ('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/page/%d" />',
       dociri, coalesce (p, 0) + 1), ss);
      http ('</rdf:Description>', ss);
      rdf_tail (ss);
      ss := string_output_string (ss);
      sa_dict := DB.DBA.RDF_RDFXML_TO_DICT (ss, dociri, graph);
      triples := dict_list_keys (sa_dict, 1);
      if (fmt = 'rdf')
	DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
      else
	DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
    }

  if (fmt = 'rdf')
    rdf_tail (ses);
  return ses;
}
;

create procedure ods_sioc_obj_describe (in u_name varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare iri, graph, ses any;
  declare qrs, stat, msg, accept, pref any;
  declare rset, metas any;
  declare triples, maybe_more any;

--  dbg_obj_print (u_name, fmt);
  set http_charset='utf-8';
  if (fmt = 'text/rdf+n3')
    fmt := 'n3';
  else if (fmt = 'application/rdf+xml')
    fmt := 'rdf';
  if (fmt not in ('n3', 'ttl', 'rdf'))
    fmt := 'rdf';

  if (fmt = 'n3' or fmt = 'ttl')
    accept := 'text/rdf+n3';
  else
    accept := 'application/rdf+xml';
  graph := get_graph ();
  ses := string_output ();
  iri := user_obj_iri (u_name);
  qrs := vector (0,0);
  pref := 'sparql prefix sioc: <http://rdfs.org/sioc/ns#> prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ';
  qrs[0] := sprintf ('CONSTRUCT { <%s> ?p ?o . ?o a ?t . ?o rdfs:label ?l . ?o rdfs:seeAlso ?sa . } '||
	  ' FROM <%s> WHERE { <%s> ?p ?o . optional { ?o a ?t } . optional { ?o rdfs:label ?l } . optional { ?o rdfs:seeAlso ?sa } '||
	  ' filter (?p != sioc:creator_of) }', iri, get_graph (), iri);
  qrs[1] := sprintf ('CONSTRUCT { ?s ?p <%s> . ?s a ?t . ?s rdfs:label ?l . ?s rdfs:seeAlso ?sa . } '||
	  ' FROM <%s> WHERE { ?s ?p <%s> . optional { ?s a ?t } . optional { ?s rdfs:label ?l } . optional { ?s rdfs:seeAlso ?sa } '||
	  ' filter (?p != sioc:has_creator) }', iri, get_graph (), iri);

  if (fmt = 'rdf')
    rdf_head (ses);
  set_user_id ('dba');
  foreach (any qr in qrs) do
    {
      qr := pref || qr;
--      dbg_printf ('%s', qr);
      stat := '00000';
      exec (qr, stat, msg, vector (), 0, metas, rset);
      if (stat <> '00000')
	signal (stat, msg);
      ods_sioc_print_rset (iri, rset, ses, fmt, maybe_more);
    }
  if (fmt = 'rdf')
    rdf_tail (ses);
  return ses;
}
;

create procedure ods_sioc_print_rset (in iri any, inout rset any, inout ses any, inout fmt any, inout maybe_more int)
{
  declare triples any;
  declare this_iri, type_iri, label_iri, g_iri, dict, sa_iri any;

  triples := null;
  if ((1 = length (rset)) and (1 = length (rset[0])) and (214 = __tag (rset[0][0])))
    {
      this_iri := iri_to_id (iri);
      type_iri := iri_to_id (sioc..rdf_iri ('type'));
      label_iri := iri_to_id (sioc..rdfs_iri ('label'));
      sa_iri := iri_to_id (sioc..rdfs_iri ('seeAlso'));
      g_iri := iri_to_id (sioc..get_graph ());
      dict := rset[0][0];
      triples := dict_list_keys (dict, 0);
      if (length (triples) = 0)
	maybe_more := 0;
      foreach (any tr in triples) do
	{
	  declare subj, obj any;
	  subj := tr[0];
	  obj := tr[2];
	  if (isiri_id (subj) and this_iri <> subj)
	    {
	      for select S, P, O from DB.DBA.RDF_QUAD where G = g_iri and S = subj and P in (type_iri, label_iri, sa_iri)
		do
		  {
		    dict_put (dict, vector (S, P, O), 0);
		  }
	    }
	  else if (isiri_id (obj) and obj <> this_iri)
	    {
	      for select S, P, O from DB.DBA.RDF_QUAD where G = g_iri and S = obj and P in (type_iri, label_iri, sa_iri)
		do
		  {
		    dict_put (dict, vector (S, P, O), 0);
		  }
	    }
	}
	triples := dict_list_keys (dict, 0);
    }
  if (length (triples))
    {
      if (fmt = 'rdf')
	DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
      else
	DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
    }
};

create procedure ods_sioc_container_obj_describe (in iri varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare graph, ses any;
  declare qrs, stat, msg, accept, pref any;
  declare rset, metas any;
  declare triples any;
  declare lim, offs, maybe_more int;

--  dbg_obj_print (u_name, fmt);
  set http_charset='utf-8';
  maybe_more := 1;
  if (fmt = 'text/rdf+n3')
    fmt := 'n3';
  else if (fmt = 'application/rdf+xml')
    fmt := 'rdf';
  if (fmt not in ('n3', 'ttl', 'rdf'))
    fmt := 'rdf';

  if (fmt = 'n3' or fmt = 'ttl')
    accept := 'text/rdf+n3';
  else
    accept := 'application/rdf+xml';
  graph := get_graph ();
  ses := string_output ();
  lim := 20;--coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
  offs := coalesce (p, 0) * lim;
  qrs := vector (0,0,0);
  pref := 'sparql prefix sioc: <http://rdfs.org/sioc/ns#> prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> prefix dct: <http://purl.org/dc/terms/> prefix atom: <http://atomowl.org/ontologies/atomrdf#> ';
  if (offs = 0)
    {
      qrs[0] := sprintf ('CONSTRUCT { <%s> ?p ?o . } '||
      ' FROM <%s> WHERE { <%s> ?p ?o . filter (?p != sioc:container_of && ?p != atom:entry && ?p != atom:contains) }',
      iri, get_graph (), iri);
      qrs[1] := sprintf ('CONSTRUCT { ?s ?p <%s> . } '||
      ' FROM <%s> WHERE { ?s ?p <%s> . filter (?p != sioc:has_container && ?p != atom:source ) }',
      iri, get_graph (), iri);
    }
  qrs[2] := sprintf (
    'CONSTRUCT { <%s> sioc:container_of ?o . ?o sioc:has_container <%s> . ?o a ?t . ?o rdfs:label ?l . ?o rdfs:seeAlso ?sa . } '||
    ' FROM <%s> WHERE { <%s> sioc:container_of ?o . optional { ?o a ?t } . optional { ?o rdfs:label ?l } . '||
    ' optional { ?o rdfs:seeAlso ?sa } . optional { ?o dct:created ?cr } } order by desc (?cr) LIMIT %d OFFSET %d',
    iri, iri, get_graph (), iri, lim, offs);

  if (fmt = 'rdf')
    rdf_head (ses);
  set_user_id ('dba');

  foreach (any qr in qrs) do
    {
      if (qr <> 0)
	{
	  qr := pref || qr;
--          dbg_printf ('%s', qr);
	  stat := '00000';
	  exec (qr, stat, msg, vector (), 0, metas, rset);
	  if (stat <> '00000')
	    signal (stat, msg);

	  ods_sioc_print_rset (iri, rset, ses, fmt, maybe_more);
	}
    }
  if (maybe_more)
    {
      declare ss, sa_dict any;
      ss := string_output ();
      rdf_head (ss);
      http (sprintf ('<rdf:Description rdf:about="%s">', iri), ss);
      http (sprintf ('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/page/%d" />',
       iri, coalesce (p, 0) + 1), ss);
      http ('</rdf:Description>', ss);

      http (sprintf ('<rdf:Description rdf:about="%s/page/%d">', iri, coalesce (p, 0) + 1), ss);
      http (sprintf ('<rdfs:label>page %d</rdfs:label>', coalesce (p, 0) + 1), ss);
      http ('</rdf:Description>', ss);

      rdf_tail (ss);
      ss := string_output_string (ss);
      sa_dict := DB.DBA.RDF_RDFXML_TO_DICT (ss, iri, graph);
      triples := dict_list_keys (sa_dict, 1);
      if (fmt = 'rdf')
	DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
      else
	DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
    }
  if (fmt = 'rdf')
    rdf_tail (ses);
  return ses;
}
;

create procedure sioc_compose_xml (in u_name varchar, in wai_name varchar, in inst_type varchar, in postid varchar := null,
				   in p int := null, in fmt varchar := 'RDF/XML', in kind int := 0)
{
  declare state, tp, qry, msg, maxrows, metas, rset, graph, iri, offs, fmt_decl, accept, part any;
  declare ses any;

  -- dbg_obj_print (u_name,wai_name,inst_type,postid);
  graph := get_graph ();
  ses := string_output ();
  fmt_decl := '';
  --if (length (fmt))
  --  fmt_decl := ' define output:format "'||fmt||'" ';

  if (fmt = 'TTL')
    accept := 'text/rdf+n3';
  else
    accept := '';


  if (inst_type = 'users')
    inst_type := null;

  if (u_name is null)
    {
      qry := sprintf (
      		'sparql  ' || fmt_decl ||
		'prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> '||
		'prefix foaf: <http://xmlns.com/foaf/0.1/> '||
		'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
		'prefix dc: <http://purl.org/dc/elements/1.1/> '||
		'prefix dct: <http://purl.org/dc/terms/> '||
		'construct { '||
		  ' <%s#group> rdf:type foaf:Group ; '||
		  ' foaf:member ?s . '||
		  '?s rdf:type foaf:Agent . '||
		  '?s foaf:nick ?nick . '||
		  '?s foaf:name ?name . '||
		  '?s rdfs:seeAlso ?sa . ' ||
		  --'?sa dc:format "application/rdf+xml" '||
		  '} from <%s> '||
		  'where { ?s rdf:type foaf:Person . '||
		  '?s foaf:nick ?nick . '||
		  '?s rdfs:seeAlso ?sa . '||
		  'optional { ?s foaf:name ?name } . '||
		  '}', graph, graph, graph, graph);
    }
  else if (wai_name is null and inst_type is null and postid is null)
    {
      iri := user_obj_iri (u_name);
      qry := 'sparql ' || fmt_decl ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' prefix vcard: <http://www.w3.org/2001/vcard-rdf/3.0#> \n' ||
	 ' prefix owl: <http://www.w3.org/2002/07/owl#> ' ||
         ' prefix bio: <http://vocab.org/bio/0.1/> \n' ;
      if (kind = 0)
	{
	  part := sprintf (
	     ' CONSTRUCT { ?s ?p ?o . ?f foaf:holdsAccount ?ha . ?f rdfs:seeAlso ?sa . '||
	     '  ?frm sioc:scope_of ?role. ?role sioc:function_of ?member. ?frm sioc:type ?ft. ?frm sioc:id ?fid . '||
	     '  ?frm rdfs:seeAlso ?fsa . ?frm sioc:has_space ?fh .  ?role sioc:has_scope ?frm . ' ||
	     '  ?frm sioc:has_owner ?member . ?member sioc:owner_of ?frm . } \n' ||
	     ' FROM <%s> WHERE { \n' ||
	     '   { ?s ?p ?o . ?s sioc:id "%s" FILTER (?p != "http://www.w3.org/2000/01/rdf-schema#seeAlso" && ' ||
	     ' 					  ?p != "http://rdfs.org/sioc/ns#creator_of") } union  \n' ||
	     '   { ?f foaf:nick "%s" ; foaf:holdsAccount ?ha ; rdfs:seeAlso ?sa  } union  \n' ||
	     '   { ?frm sioc:scope_of ?role . ?role sioc:function_of ?member . '||
	     '     ?member sioc:id "%s". ?frm sioc:type ?ft; sioc:id ?fid; rdfs:seeAlso ?fsa; sioc:has_space ?fh. '||
             '     OPTIONAL { ?frm sioc:has_owner ?member . } '||
	     '  	 } } ',
	     graph, u_name, u_name, u_name);
	}
      else if (kind = 1) -- FOAF
	{
	  part := sprintf (
	  ' CONSTRUCT {
	    ?person a foaf:Person .
	    ?person foaf:nick "%s" .
	    ?person foaf:mbox ?mbox .
	    ?person foaf:mbox_sha1sum ?sha1 .
	    ?person foaf:name ?full_name .
	    ?person foaf:holdsAccount ?sioc_user .
	    ?sioc_user rdfs:seeAlso ?see_also .
	    ?sioc_user a sioc:User .
	    ?person foaf:firstName ?fn .
	    ?person foaf:family_name ?ln .
	    ?person foaf:gender ?gender .
	    ?person foaf:icqChatID ?icq .
	    ?person foaf:msnChatID ?msn .
	    ?person foaf:aimChatID ?aim .
	    ?person foaf:yahooChatID ?yahoo .
	    ?person foaf:birthday ?birthday .
	    ?person foaf:phone ?phone .
	    ?person foaf:based_near ?geo .
	    ?geo ?geo_pred ?geo_subj .
	    ?person rdfs:seeAlso ?forum_see_also .
	    ?forum_see_also rdf:type ?f_see_also_type .
	    ?person foaf:knows ?friend .
	    ?friend rdfs:seeAlso ?f_see_also .
	    ?friend foaf:nick ?f_nick .
	    <%s/about.rdf> a foaf:PersonalProfileDocument .
	    <%s/about.rdf> foaf:primaryTopic ?person .
	    <%s/about.rdf> foaf:maker ?person .
	    ?person foaf:workplaceHomepage ?wphome .
	    ?org foaf:homepage ?wphome .
	    ?org rdf:type foaf:Organization .
	    ?org dc:title ?orgtit .
	    ?person foaf:depiction ?depiction .
	    ?person foaf:homepage ?homepage .
	    ?person vcard:ADR ?adr .
	    ?adr vcard:Country ?country .
            ?adr vcard:Locality ?city .
	    ?adr vcard:Region ?state .
	    ?person bio:olb ?bio .
	    ?person bio:event ?event .
	    ?event rdf:type bio:Birth .
	    ?event dc:date ?bdate .
	    #?person foaf:interest ?interest .
	    #?person bio:keywords ?keywords .
	    #?person owl:sameAs ?same_as .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
	      ?person foaf:nick "%s" ;
	      foaf:holdsAccount ?sioc_user .
	      ?sioc_user rdfs:seeAlso ?see_also .
	      optional { ?person foaf:mbox ?mbox ; foaf:mbox_sha1sum ?sha1 . } .
	      optional {
		  #?sioc_user sioc:has_function ?function .
		  #?function sioc:has_scope ?forum .
		  ?sioc_user sioc:owner_of ?forum .
		  ?forum rdfs:seeAlso ?forum_see_also .
		  optional { ?forum_see_also rdf:type ?f_see_also_type } .
	      	} .
	      optional { ?person foaf:knows ?friend . ?friend rdfs:seeAlso ?f_see_also . ?friend foaf:nick ?f_nick . } .
	      optional { ?person foaf:name ?full_name } .
	      optional { ?person foaf:firstName ?fn } .
	      optional { ?person foaf:family_name ?ln } .
	      optional { ?person foaf:gender ?gender } .
	      optional { ?person foaf:icqChatID ?icq } .
	      optional { ?person foaf:msnChatID ?msn } .
	      optional { ?person foaf:aimChatID ?aim } .
	      optional { ?person foaf:yahooChatID ?yahoo } .
	      optional { ?person foaf:birthday ?birthday } .
	      optional { ?person foaf:phone ?phone } .
	      optional { ?person foaf:based_near ?geo . ?geo ?geo_pred ?geo_subj } .
	      optional { ?person foaf:workplaceHomepage ?wphome } .
	      optional { ?org foaf:homepage ?wphome . ?org a foaf:Organization ; dc:title ?orgtit . } .
	      optional { ?person foaf:depiction ?depiction } .
	      optional { ?person foaf:homepage ?homepage } .
	      optional { ?person bio:olb ?bio  } .
              optional { ?person bio:event ?event . ?event a bio:Birth ; dc:date ?bdate } .
	      optional { ?person vcard:ADR ?adr . ?adr vcard:Country ?country .
	        	optional { ?adr vcard:Locality ?city } .
			optional { ?adr vcard:Region ?state } .
	      	       } .
	      #optional { ?person foaf:interest ?interest } .
	      #optional { ?person bio:keywords ?keywords } .
	      #optional { ?person owl:sameAs ?same_as } .
	      }
	    }
	  }',
	  u_name,
	  iri, iri, iri,
	  graph, u_name);
	}

       qry := qry || part;
    }
  else if (postid is null)
    {
      declare triples, num any;
      declare lim any;

      if (kind = 1)
	signal ('22023', 'FOAF is not available for ODS instance');

      lim := coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
      offs := coalesce (p, 0) * lim;
      tp := DB.DBA.wa_type_to_app (inst_type);

      if (inst_type = 'discussion')
	iri := forum_iri ('nntpf', wai_name);
      else
        iri := forum_iri (inst_type, wai_name);
      if (fmt = 'RDF/XML')
	rdf_head (ses);
      set_user_id ('dba');
      qry:= sprintf ('sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	  prefix dc: <http://purl.org/dc/elements/1.1/>
          construct
	        {
		  ?host sioc:space_of ?forum .
		  ?host sioc:link ?link .
		  ?host dc:title ?title .
		  ?host rdf:type sioc:Space .
	        } where
            	{
		  graph <%s>
		  {
		    ?host sioc:space_of ?forum . ?forum sioc:id "%s" .
		    ?host sioc:link ?link . ?host dc:title ?title
		  }
		}', graph, wai_name
	    );
      rset := null;
      maxrows := 0;
      state := '00000';
      msg := '';
--      dbg_printf ('%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
--      dbg_obj_print (msg);
      if (state = '00000')
	{
	  triples := rset[0][0];
	  rset := dict_list_keys (triples, 1);
	  if (fmt = 'TTL')
	    DB.DBA.RDF_TRIPLES_TO_TTL (rset, ses);
	  else
	    DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	}

      qry := sprintf ('sparql
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
   	  prefix svc: <http://rdfs.org/sioc/services#>
	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	  prefix dc: <http://purl.org/dc/elements/1.1/>
	  prefix ext: <http://rdfs.org/sioc/types#>
          construct {
			?forum sioc:id "%s" .
			?forum rdf:type ?tp .
			?forum sioc:link ?link .
			?forum sioc:description ?descr .
			?forum sioc:scope_of ?role .
	    		?role sioc:function_of ?member .
			?member rdfs:seeAlso ?see_also .
			?forum sioc:has_space ?host .
			?forum sioc:type ?type .
			?forum svc:has_service ?svc .
			?svc svc:service_endpoint ?endp .
			?svc svc:service_protocol ?proto .
			?svc svc:service_of ?forum .
			?svc rdf:type svc:Service .
		    } where
            	{
		  graph <%s>
		  {
		    ?forum sioc:id "%s" ;
		    rdf:type ?tp ;
		    sioc:link ?link ;
		    sioc:description ?descr ;
		    sioc:has_space ?host ;
		    sioc:type ?type ;
		    sioc:scope_of ?role .
		    ?role sioc:function_of ?member .
		    ?member rdfs:seeAlso ?see_also .
   		    optional {
  		      ?forum svc:has_service ?svc .
  		      ?svc svc:service_endpoint ?endp .
  		      ?svc svc:service_protocol ?proto .
		    }
		  }
		}', wai_name, graph, wai_name
	    );
      rset := null;
      maxrows := 0;
      state := '00000';
      msg := '';
      exec (qry, state, msg, vector(), maxrows, metas, rset);
      if (state = '00000')
	{
	  triples := rset[0][0];
	  rset := dict_list_keys (triples, 1);
	  if (fmt = 'TTL')
	    DB.DBA.RDF_TRIPLES_TO_TTL (rset, ses);
	  else
	    DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	}

      if (tp = 'subscriptions')
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
		    ?post rdf:type ?post_tp .
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
			?post rdf:type ?post_tp .
			optional { ?post dct:created ?created } .
			optional { ?post sioc:reply_of ?reply_of }
			filter bif:isnull (?reply_of)
		      }
		    }
		    order by desc (?created) limit %d offset %d
		', graph, wai_name, lim, offs);
	}
      else if (tp = 'community')
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
		    ?forum sioc:has_part ?pforum .
		    ?pforum sioc:part_of ?forum .
		    ?post rdf:type ?post_tp .
		    ?post rdfs:seeAlso ?post_see_also
	       }
	      where
		    {
		      graph <%s>
		      {
			?pforum sioc:id "%s" .
			?pforum sioc:part_of ?forum .
			?post sioc:has_container ?forum .
			?post rdfs:seeAlso ?post_see_also .
			?post rdf:type ?post_tp .
			optional { ?post dct:created ?created } .
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
		    ?post rdf:type ?post_tp .
		    ?post rdfs:seeAlso ?post_see_also
	       }
	      where
		    {
		      graph <%s>
		      {
			?forum sioc:id "%s" .
			?post sioc:has_container ?forum .
			?post rdfs:seeAlso ?post_see_also .
			?post rdf:type ?post_tp .
		        optional { ?post dct:created ?created } .
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
--      set_user_id ('dba');
--      dbg_printf ('%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
--      dbg_obj_print (msg);
      if (state = '00000')
	{
	  triples := rset[0][0];
	  rset := dict_list_keys (triples, 1);
	  if (fmt = 'TTL')
	    DB.DBA.RDF_TRIPLES_TO_TTL (rset, ses);
	  else
	    DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	  -- seeAlso for the rest of posts
	  if (length (rset) and fmt = 'RDF/XML')
	    {
	      http (sprintf ('<rdf:Description rdf:about="%s">', iri), ses);
	      http (sprintf
	      	('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/sioc.rdf?p=%d" />',
		    iri, coalesce (p, 0) + 1), ses);
	      http ('</rdf:Description>', ses);
	    }
        }
      if (fmt = 'RDF/XML')
        rdf_tail (ses);
      goto ret;
    }
  else -- the post
    {
--      dbg_obj_print (u_name, inst_type, wai_name, postid);
      if (kind = 1)
	signal ('22023', 'FOAF is not available for posts');

      if (inst_type = 'feed')
        iri := feed_item_iri (atoi(wai_name), atoi(postid));
      else if (inst_type = 'discussion')
	iri := nntp_post_iri (wai_name, postid);
      else
        iri := post_iri (u_name, inst_type, wai_name, postid);
--      dbg_obj_print (iri, md5(iri));
      qry := sprintf ('sparql ' || fmt_decl ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
	 ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
	 ' prefix foaf: <http://xmlns.com/foaf/0.1/> '||
	 ' prefix skos: <http://www.w3.org/2004/02/skos/core#> '||
         ' construct {
	            ?post rdf:type ?post_tp .
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
	   ?post rdf:type ?post_tp .
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
--  dbg_printf ('%s', qry);
  set_user_id ('dba');
  exec (qry, state, msg, vector(), maxrows, metas, rset);
--  dbg_obj_print (msg);
  if (state <> '00000')
    signal (state, msg);
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);

ret:
  return ses;
};


use DB;


delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'ODS_SIOC_RDF';
delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = sioc.DBA.get_graph ();

