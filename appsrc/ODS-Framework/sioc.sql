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

create procedure get_graph_ext (
  in access_mode integer)
{
  declare graph varchar;

  graph := get_graph ();
  if (access_mode = 2)
    graph := graph || '/protected';

  return graph;
};

create procedure get_graph_new (
  in access_mode integer := null,
  in object_iri varchar := null)
{
  declare V any;

  if (access_mode = 1)
    return get_graph ();

  V := sprintf_inverse (object_iri, 'http://%s/dataspace/%s', 1);
  if (length (V) <> 2)
    return null;
  return sprintf ('http://%s/dataspace/protected/%s', V[0], V[1]);
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

create procedure sioct_iri (in s varchar)
{
  return concat ('http://rdfs.org/sioc/types#', s);
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

create procedure opl_iri (in s varchar)
{
  return concat ('http://www.openlinksw.com/schema/attribution#', s);
};


create procedure oplmail_iri (in s varchar)
{
  return concat ('http://www.openlinksw.com/schemas/mail#', s);
};

create procedure oplflt_iri (in s varchar)
{
  return concat ('http://www.openlinksw.com/schemas/acl/filter#', s);
};

create procedure cert_iri (in s varchar)
{
  return concat ('http://www.w3.org/ns/auth/cert#', s);
};

create procedure xsd_iri (in s varchar)
{
  return concat ('http://www.w3.org/2001/XMLSchema#', s);
};

create procedure rev_iri (in s varchar)
{
  return concat ('http://purl.org/stuff/rev#', s);
};

create procedure like_iri (in s varchar)
{
  return concat ('http://ontologi.es/like#', s);
};

create procedure rsa_iri (in s varchar)
{
  return concat ('http://www.w3.org/ns/auth/rsa#', s);
};

create procedure offer_iri (in s varchar)
{
  return concat ('http://purl.org/goodrelations/v1#', s);
};

create procedure acl_iri (in s varchar)
{
  return concat ('http://www.w3.org/ns/auth/acl#', s);
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

create procedure user_iri (in _u_id int, in _check_disabled integer := 1)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select u_name into _u_name from DB.DBA.SYS_USERS where U_ID = _u_id and U_IS_ROLE = 0 and (_check_disabled is null or (U_ACCOUNT_DISABLED = 0));
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

create procedure forum_iri (in inst_type varchar, in wai_name varchar, in _member varchar := null)
{
  declare tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  declare exit handler for not found { return null; };
  if (inst_type = 'nntpf')
    return sprintf ('http://%s%s/%U/%U', get_cname(), get_base_path (), tp, wai_name);

  if (isnull (_member))
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

create procedure forum_name (in user_name varchar, in forum_type varchar)
{
  return user_name || '''s ' || forum_type;
};

create procedure offerlist_forum_iri (in wai_name varchar, in wai_member varchar)
{
  return forum_iri ('offerlist', wai_name, wai_member);
};

create procedure wishlist_forum_iri (in wai_name varchar, in wai_member varchar)
{
  return forum_iri ('wishlist', wai_name, wai_member);
};

create procedure ownslist_forum_iri (in wai_name varchar, in wai_member varchar)
{
  return forum_iri ('ownslist', wai_name, wai_member);
};

create procedure like_forum_iri (in wai_name varchar, in wai_member varchar)
{
  return forum_iri ('like', wai_name, wai_member);
};

create procedure dislike_forum_iri (in wai_name varchar, in wai_member varchar)
{
  return forum_iri ('dislike', wai_name, wai_member);
};

create procedure favorite_forum_iri (in wai_name varchar, in wai_member varchar)
{
  return forum_iri ('favoritethings', wai_name, wai_member);
};

create procedure ods_sioc_clean_all ()
{
  declare graph_iri varchar;
  graph_iri := get_graph ();
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (fix_graph (graph_iri));
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
	'Calendar',      ext_iri ('Calendar'),
	'OfferList',     ext_iri ('OfferList'),
	'WishList',      ext_iri ('WishList'),
	'OwnsList',      ext_iri ('OwnsList'),
	'Likes',         ext_iri ('Likes'),
	'DisLikes',      ext_iri ('DisLikes'),
	'FavoriteThings',ext_iri ('FavoriteThings')
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
	'Calendar',      'Container',
	'OfferList',     'Container',
	'WishList',      'Container',
	'OwnsList',      'Container',
	'Likes',         'Container',
	'DisLikes',      'Container',
	'FavoriteThings','Container'
	), app);
  return sioc_iri (pclazz);
};

create procedure ods_init_ft ()
{
  if (1 = sys_stat ('cl_run_local_only'))
    {
DB.DBA.RDF_OBJ_FT_RULE_ADD (get_graph (), null, 'ODS RDF Data');
    }
}
;

ods_init_ft ();

create procedure ods_graph_init ()
{
  declare iri, site_iri, graph_iri varchar;
  set isolation='uncommitted';
  site_iri  := get_graph ();
  graph_iri := get_graph ();
  DB.DBA.ODS_QUAD_URI (graph_iri, site_iri, rdf_iri ('type'), sioc_iri ('Space'));
  DB.DBA.ODS_QUAD_URI (graph_iri, site_iri, sioc_iri ('link'), get_ods_link ());
  DB.DBA.ODS_QUAD_URI_L (graph_iri, site_iri, dc_iri ('title'),
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
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, opl_iri ('isDescribedUsing'), df_uri);
};

create procedure foaf_maker (in graph_iri varchar, in iri varchar, in full_name varchar, in u_e_mail varchar)
{
  if (not length (iri))
    return null;

  ods_sioc_result (iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Person'));
  if (length (full_name))
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), full_name);
  if (length (u_e_mail))
    {
      --!! ACL DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }
};

create procedure person_iri (in iri varchar, in suff varchar := '#this', in tp int := null)
{
  declare arr any;
  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  if (length (arr) <> 2)
    signal ('22023', sprintf ('Non-user IRI [%s] can\'t be transformed to person IRI', iri));

  if ((arr[1] like 'person/%') or (arr[1] like 'organization/%'))
    return sprintf ('http://%s/dataspace/%s%s',arr[0],arr[1], suff);

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

-- Update all existing user online accounts to write a fixed URI. Otherwise it will be impossible to remove them after
-- the update of person_ola_iri which introduces the 3rd parameter.
DB.DBA.wa_exec_no_error_log(
  'update DB.DBA.WA_USER_OL_ACCOUNTS set WUO_URI = sioc.DBA.person_ola_iri (sioc.DBA.user_iri (WUO_U_ID), WUO_NAME) where WUO_URI is null;'
)
;

create procedure person_ola_iri (in iri varchar, in suff varchar, in accountUid varchar)
{
  declare arr any;

  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  if (length (arr) <> 2)
    signal ('22023', sprintf ('Non-user IRI [%s] can\'t be transformed to person IRI', iri));

  if (arr[1] like 'person/%')
    arr[1] := subseq (arr[1], length ('person/'));

  if (accountUid is null)
  return sprintf ('http://%s/dataspace/person/%s/online_account/%U',arr[0],arr[1], suff);
  else
    return sprintf ('http://%s/dataspace/person/%U/online_account/%U/%U',arr[0],arr[1], suff, accountUid);
};

create procedure person_prj_iri (in iri varchar, in suff varchar)
{
  declare arr any;
  arr := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  if (length (arr) <> 2)
    signal ('22023', sprintf ('Non-user IRI [%s] can\'t be transformed to person IRI', iri));
  return sprintf ('http://%s/dataspace/person/%s/projects#%s',arr[0],arr[1], suff);
};

create procedure person_bio_iri (in person_iri varchar, in suff varchar)
{
  return person_iri || '#event' || suff;
};

create procedure offerlist_item_iri (in forum_iri varchar, in ID integer)
{
  return forum_iri || '/' || cast (ID as varchar);
};

create procedure wishlist_item_iri (in forum_iri varchar, in ID integer)
{
  return forum_iri || '/' || cast (ID as varchar);
};

create procedure likes_item_iri (in forum_iri varchar, in ID integer)
{
  return forum_iri || '/' || cast (ID as varchar);
};

create procedure favorite_item_iri (in forum_iri varchar, in ID integer)
{
  return forum_iri || '/' || cast (ID as varchar);
};

-- User
create procedure sioc_user (in graph_iri varchar, in iri varchar, in u_name varchar, in u_e_mail varchar, in full_name varchar := null)
{
  declare u_site_iri varchar;
  declare person_iri, link varchar;
  declare os_iri varchar;

  ods_sioc_result (iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('User'));
  DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), U_NAME);
  ods_is_defined_by (graph_iri, iri);

  u_site_iri := user_space_iri (u_name);
  link := user_doc_iri (u_name);

  DB.DBA.ODS_QUAD_URI (graph_iri, u_site_iri, rdf_iri ('type'), sioc_iri ('Space'));
  DB.DBA.ODS_QUAD_URI (graph_iri, u_site_iri, sioc_iri ('link'), link);

  os_iri := sprintf ('http://%s/feeds/people/%U', get_cname(), u_name);
  ods_sioc_service (graph_iri, os_iri, iri, null, null, null, os_iri, 'OpenSocial');
  os_iri := sprintf ('http://%s/feeds/people/%U/friends', get_cname(), u_name);
  ods_sioc_service (graph_iri, os_iri, iri, null, null, null, os_iri, 'OpenSocial');

  if (full_name is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), full_name);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('link'), link);

  --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (link, '/sioc.rdf'));

  if (length (u_e_mail))
    {
      --!! ACL DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||u_e_mail);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (u_e_mail));
    }

  -- FOAF
  person_iri := person_iri (iri);
  ods_is_defined_by (graph_iri, person_iri);
  --DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, rdfs_iri ('seeAlso'), concat (link, '/about.rdf'));
  if (person_iri like '%/organization/%')
    DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, rdf_iri ('type'), foaf_iri ('Organization'));
  else
    DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, rdf_iri ('type'), foaf_iri ('Person'));
  DB.DBA.ODS_QUAD_URI_L (graph_iri, person_iri, foaf_iri ('nick'), u_name);
  if (length (u_e_mail))
    {
      --!! ACL DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, foaf_iri ('mbox'), 'mailto:'||u_e_mail);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, person_iri, foaf_iri ('mbox_sha1sum'), sha1_digest (u_e_mail));
    }

  --!!! ACL delete_quad_sp (graph_iri, person_iri, foaf_iri ('name'));
  --!!! ACL if (length (full_name))
  --!!! ACL  {
  --!!! ACL    DB.DBA.ODS_QUAD_URI_L (graph_iri, person_iri, foaf_iri ('name'), full_name);
  --!!! ACL     DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), full_name);
  --!!! ACL    }
  --!!! ACL else
  --!!! ACL  {
  --!!! ACL    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), U_NAME);
  --!!! ACL   }

  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('account_of'), person_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, foaf_iri ('account'), iri);
  -- OpenID (new)
  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, foaf_iri ('openid'), link);

  -- ATOM the person here is a subclass of foaf:Person which is already the case
  --delete_quad_sp (graph_iri, person_iri, atom_iri ('personEmail'));
  --if (person_iri not like '%/organization/%')
  --  {
  --    DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, rdf_iri ('type'), atom_iri ('Person'));
  --    DB.DBA.ODS_QUAD_URI_L (graph_iri, person_iri, atom_iri ('personName'), u_name);
  --    if (length (u_e_mail))
  --	DB.DBA.ODS_QUAD_URI_L (graph_iri, person_iri, atom_iri ('personEmail'), u_e_mail);
  --  }

};

create procedure wa_user_check (inout txt any, inout flags varchar, in fld integer)
{
  declare exit handler for sqlstate '*' { return 0; };

  if (isnull (txt))
    return 0;

  if ((internal_type (txt) <> 211) and not length (txt))
    return 0;

  if (length (flags) <= fld)
    return 0;

  if (atoi (chr (flags[fld])) <= 2)
    return 1;

  return 0;
};

create procedure wa_user_graph (inout flags varchar, in fld integer, inout public_graph_iri varchar, inout protected_graph_iri varchar)
{
  if (atoi (chr (flags[fld])) <= 1)
    return public_graph_iri;

  return protected_graph_iri;
};

create procedure wa_user_pub_info (in flags varchar, in fld integer)
{
  if (length (flags) <= fld)
    return 0;

  if (atoi (chr (flags[fld])) = 1)
    return 1;

  return 0;
};

create procedure wa_pub_info (in txt varchar, in flags varchar, in fld integer)
{
  if (length (txt) and wa_user_pub_info (flags, fld))
    return 1;

  return 0;
};

create procedure wa_user_protected_check (in flags varchar, in fld integer)
{
  if (length (flags) <= fld)
    return 0;

  if (atoi (chr (flags[fld])) = 2)
    return 1;

  return 0;
};

create procedure sioc_user_cert (in graph_iri varchar, in person_iri varchar, in cert_id int, in cert any)
{
  declare info, modulus, exponent, crt_iri any;

  info := get_certificate_info (9, cast (cert as varchar), 0);
  if (info is not null and isarray (info) and cast (info[0] as varchar) = 'RSAPublicKey')
    {
      modulus := info[2];
      exponent := info[1];
      crt_iri := replace (person_iri, '#this', sprintf ('#cert%d', cert_id));
      DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, cert_iri ('key'), crt_iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, crt_iri, rdf_iri ('type'), cert_iri ('RSAPublicKey'));

      DB.DBA.ODS_QUAD_URI_L_TYPED (graph_iri,crt_iri, cert_iri ('modulus'), bin2hex (modulus), xsd_iri ('hexBinary'), null);
      DB.DBA.ODS_QUAD_URI_L_TYPED (graph_iri,crt_iri, cert_iri ('exponent'), cast (exponent as varchar), xsd_iri ('int'), null);
    }
  return;
}
;

create procedure sioc_user_graph2 (
  in graph_iri varchar,
  in iri varchar,
  in visible integer := 1)
{
  declare V any;

  if (visible <= 1)
    return graph_iri;

  V := sprintf_inverse (iri, 'http://%s/dataspace/%s#this', 1);
  return graph_iri || '/protected/' || V[1];
};

create procedure sioc_user_info (
    in public_graph_iri varchar,
    in in_iri varchar,
    in is_org integer,
    in flags varchar,
    in waui_first_name varchar,
    in waui_last_name varchar,
    in title varchar := null,
    in full_name varchar := null,
    in mail varchar := null,
    in gender varchar := null,
    in icq varchar := null,
    in msn varchar := null,
    in aim varchar := null,
    in yahoo varchar := null,
    in skype varchar := null,
    in birthday datetime := null,
    in org varchar := null,
    in phone varchar := null,
    in hb_latlng integer := 0,
    in lat float := null,
    in lng float := null,
    in blat float := null,
    in blng float := null,
    in webpage varchar := null,
    in photo varchar := null,
    in org_page varchar := null,
    in resume varchar := null,
    in interests any := null,
    in interestTopics any := null,
    in haddress1 varchar := null,
    in haddress2 varchar := null,
    in hcode varchar := null,
    in hcity varchar := null,
    in hstate varchar := null,
    in hcountry varchar := null,
    in cert any := null
    )
{
  declare work_graph_iri, protected_graph_iri, ev_iri, addr_iri, org_iri, iri, giri, crt_iri, crt_exp, crt_mod, protected varchar;
  declare hf, V any;
  declare N, is_person integer;

  if (in_iri is null)
    return;

  V := sprintf_inverse (in_iri, 'http://%s/dataspace/%s#this', 1);
  protected_graph_iri := public_graph_iri || '/protected/' || V[1];

  sioc_user_info_delete (vector (public_graph_iri, protected_graph_iri), in_iri, is_org);
  ods_sioc_result (in_iri);

  iri := person_iri (in_iri, '');
  org_iri := iri || '#org';
  addr_iri := iri || '#addr';
  ev_iri := iri || '#event';
  crt_iri := iri || '#cert';
  crt_exp := iri || '#cert_exp';
  crt_mod := iri || '#cert_mod';
  giri := iri || '#based_near';
  iri := person_iri (in_iri);
  is_person := case when (iri like '%/organization/%') then 0 else 1 end;

  if (is_person and wa_user_check (waui_first_name, flags, 1))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 1, public_graph_iri, protected_graph_iri), iri, foaf_iri ('firstName'), waui_first_name);

  if (is_person and wa_user_check (waui_last_name, flags, 2))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 2, public_graph_iri, protected_graph_iri), iri, foaf_iri ('family_name'), waui_last_name);

  if (wa_user_check (full_name, flags, 3))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 3, public_graph_iri, protected_graph_iri), iri, foaf_iri ('name'), full_name);

  if (wa_user_check (mail, flags, 4))
    {
      work_graph_iri := wa_user_graph (flags, 4, public_graph_iri, protected_graph_iri);
      DB.DBA.ODS_QUAD_URI (work_graph_iri, iri, foaf_iri ('mbox'), 'mailto:' || mail);
      DB.DBA.ODS_QUAD_URI (work_graph_iri, iri, owl_iri ('sameAs'), 'acct:' || mail);
    }

  if (is_person and wa_user_check (title, flags, 0))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 0, public_graph_iri, protected_graph_iri), iri, foaf_iri ('title'), title);

  if (is_person and wa_user_check (gender, flags, 5))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 5, public_graph_iri, protected_graph_iri), iri, foaf_iri ('gender'), gender);

  if (wa_user_check (icq, flags, 10))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 10, public_graph_iri, protected_graph_iri), iri, foaf_iri ('icqChatID'), icq);

  if (wa_user_check (msn, flags, 14))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 14, public_graph_iri, protected_graph_iri), iri, foaf_iri ('msnChatID'), msn);

  if (wa_user_check (aim, flags, 12))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 12, public_graph_iri, protected_graph_iri), iri, foaf_iri ('aimChatID'), aim);

  if (wa_user_check (yahoo, flags, 13))
    DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 13, public_graph_iri, protected_graph_iri), iri, foaf_iri ('yahooChatID'), yahoo);

  if (wa_user_check (skype, flags, 11))
    sioc_user_account (public_graph_iri, iri, skype, case when (atoi (chr (flags[11])) <= 1) then 1 else 3 end, 'skype:' || skype || '?chat');

  if (wa_user_check (birthday, flags, 6))
    {
      work_graph_iri := wa_user_graph (flags, 6, public_graph_iri, protected_graph_iri);
      DB.DBA.ODS_QUAD_URI_L (work_graph_iri, iri, foaf_iri ('birthday'), substring (datestring(coalesce (birthday, now())), 6, 5));
      DB.DBA.ODS_QUAD_URI (work_graph_iri, ev_iri, rdf_iri ('type'), bio_iri ('Birth'));
      DB.DBA.ODS_QUAD_URI (work_graph_iri, iri, bio_iri ('event'), ev_iri);
      DB.DBA.ODS_QUAD_URI_L (work_graph_iri, ev_iri, dc_iri ('date'), substring (datestring(birthday), 1, 10));
    }

  if (wa_user_check (phone, flags, 18))
    {
      phone := replace (replace (replace (phone, '-', ''), ',', ''), ' ', '');
      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 18, public_graph_iri, protected_graph_iri), iri, foaf_iri ('phone'), 'tel:' || phone);
    }

  N := 39;
  if (hb_latlng)
    {
    N := 47;
    lat := blat;
    lng := lng;
    }
  if (lat is not null and wa_user_check (lng, flags, N))
    {
      work_graph_iri := wa_user_graph (flags, N, public_graph_iri, protected_graph_iri);
      DB.DBA.ODS_QUAD_URI (work_graph_iri, giri, rdf_iri ('type'), geo_iri ('Point'));
      DB.DBA.ODS_QUAD_URI (work_graph_iri, iri, foaf_iri ('based_near'), giri);
      DB.DBA.ODS_QUAD_URI_L (work_graph_iri, giri, geo_iri ('lat'), sprintf ('%.06f', coalesce (lat, 0)));
      DB.DBA.ODS_QUAD_URI_L (work_graph_iri, giri, geo_iri ('long'), sprintf ('%.06f', coalesce (lng, 0)));
    }

  if (wa_user_check (photo, flags, 37))
    DB.DBA.ODS_QUAD_URI (wa_user_graph (flags, 37, public_graph_iri, protected_graph_iri), iri, foaf_iri ('depiction'), DB.DBA.WA_LINK (1, photo));

  if (is_person and length (org) and wa_user_check (org_page, flags, 20))
    {
      work_graph_iri := wa_user_graph (flags, 20, public_graph_iri, protected_graph_iri);
      DB.DBA.ODS_QUAD_URI (work_graph_iri, iri, foaf_iri ('workplaceHomepage'), org_page);
      DB.DBA.ODS_QUAD_URI (work_graph_iri, org_iri, rdf_iri ('type') , foaf_iri ('Organization'));
      DB.DBA.ODS_QUAD_URI (work_graph_iri, org_iri, foaf_iri ('homepage'), org_page);
      DB.DBA.ODS_QUAD_URI_L (work_graph_iri, org_iri, dc_iri ('title'), org);
    }

  if (is_person and length (interests))
    {
      for (select interest, label from DB.DBA.WA_USER_INTERESTS (txt) (interest varchar, label varchar) P where txt = interests) do
	{
	  if (length (interest))
	    {
  	      DB.DBA.ODS_QUAD_URI (public_graph_iri, iri, foaf_iri ('topic_interest'), interest);
	      if (length (label))
  		      DB.DBA.ODS_QUAD_URI_L (public_graph_iri, interest, rdfs_iri ('label'), label);
	    }
	}
    }

  if (is_person and length (interestTopics))
    {
      for (select interest, label from DB.DBA.WA_USER_INTERESTS (txt) (interest varchar, label varchar) P where txt = interestTopics) do
  	  {
  	    if (length (interest))
  	    {
  	      DB.DBA.ODS_QUAD_URI (public_graph_iri, iri, foaf_iri ('interest'), interest);
  	      if (length (label))
  		      DB.DBA.ODS_QUAD_URI_L (public_graph_iri, interest, rdfs_iri ('label'), label);
  	    }
  	  }
    }

  if (wa_user_check (hcountry,  flags, 16) or
      wa_user_check (hstate,    flags, 59) or
      wa_user_check (hcity,     flags, 58) or
      wa_user_check (hcode,     flags, 57) or
      wa_user_check (haddress1, flags, 15) or
      wa_user_check (haddress2, flags, 15)
     )
    {
      if (
          wa_user_pub_info (flags, 16) or
          wa_user_pub_info (flags, 59) or
          wa_user_pub_info (flags, 58) or
          wa_user_pub_info (flags, 57) or
          wa_user_pub_info (flags, 15) or
          wa_user_pub_info (flags, 15)
         )
      {
        DB.DBA.ODS_QUAD_URI (public_graph_iri, iri, vcard_iri ('ADR'), addr_iri);
        DB.DBA.ODS_QUAD_URI_L (public_graph_iri, addr_iri, rdf_iri ('type'), vcard_iri ('home'));
      }
      if (
          wa_user_protected_check (flags, 16) or
          wa_user_protected_check (flags, 59) or
          wa_user_protected_check (flags, 58) or
          wa_user_protected_check (flags, 57) or
          wa_user_protected_check (flags, 15) or
          wa_user_protected_check (flags, 15)
         )
    {
        DB.DBA.ODS_QUAD_URI (protected_graph_iri, iri, vcard_iri ('ADR'), addr_iri);
        DB.DBA.ODS_QUAD_URI_L (protected_graph_iri, addr_iri, rdf_iri ('type'), vcard_iri ('home'));
      }
      if (wa_user_check (hcountry, flags, 16))
        DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 16, public_graph_iri, protected_graph_iri), addr_iri, vcard_iri ('Country'), hcountry);

      if (wa_user_check (hstate, flags, 59))
	      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 59, public_graph_iri, protected_graph_iri), addr_iri, vcard_iri ('Region'), hstate);

      if (wa_user_check (hcity, flags, 58))
	      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 58, public_graph_iri, protected_graph_iri), addr_iri, vcard_iri ('Locality'), hcity);

      if (wa_user_check (hcode, flags, 57))
	      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 57, public_graph_iri, protected_graph_iri), addr_iri, vcard_iri ('Pobox'), hcode);

      if (wa_user_check (haddress1, flags, 15))
	      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 15, public_graph_iri, protected_graph_iri), addr_iri, vcard_iri ('Street'), haddress1);

      if (wa_user_check (haddress2, flags, 15))
	      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 15, public_graph_iri, protected_graph_iri), addr_iri, vcard_iri ('Extadd'), haddress2);
    }

  if (is_person and wa_user_check (resume, flags, 34))
      DB.DBA.ODS_QUAD_URI_L (wa_user_graph (flags, 34, public_graph_iri, protected_graph_iri), iri, bio_iri ('olb'), resume);

  if (wa_user_check (webpage, flags, 7))
    DB.DBA.ODS_QUAD_URI (wa_user_graph (flags, 7, public_graph_iri, protected_graph_iri), iri, foaf_iri ('homepage'), webpage);

  protected := null;
  if (server_https_port () is not null)
    {
      declare ssl_port, host, sp any;
      hf := rfc1808_parse_uri (iri);
      hf[5] := '';
      hf[0] := 'https';
      host := hf[1];
      sp := split_and_decode (host, 0, '\0\0:');
      host := sp[0];
      ssl_port := server_https_port ();
      if (ssl_port <> '443')
	host := host || ':' || ssl_port;
      hf[1] := host;
      protected := DB.DBA.vspx_uri_compose (hf);
    }
  if (protected is null and 
      exists (select 1 from DB.DBA.HTTP_PATH where HP_LPATH = '/dataspace' and HP_SECURITY = 'SSL' and HP_LISTEN_HOST <> '*sslini*'))
    {
      declare ssl_port, host, sp any;
      hf := rfc1808_parse_uri (iri);
      hf[5] := '';
      hf[0] := 'https';
      for select top 1 HP_HOST, HP_LISTEN_HOST
            from DB.DBA.HTTP_PATH
	where HP_LPATH = '/dataspace' and HP_SECURITY = 'SSL' and HP_LISTEN_HOST <> '*sslini*' do
	  {
	    declare pos int;
	    host := HP_HOST;
	    if (HP_LISTEN_HOST not like '%:443') -- no default https 
	      {
		pos := strchr (HP_LISTEN_HOST, ':');
		if (pos >= 0)
		  host := host || subseq (HP_LISTEN_HOST, pos);
	      }
	  }
      hf[1] := host;
      protected := DB.DBA.vspx_uri_compose (hf);
    }

  if (protected is not null)
    DB.DBA.ODS_QUAD_URI (public_graph_iri, iri, rdfs_iri ('seeAlso'), protected);

  -- contact services
  SIOC..ods_object_services_attach (public_graph_iri, iri, 'user');
};

create procedure sioc_user_info_delete (
    in graphs varchar,
    in in_iri varchar,
  in is_org integer)
{
  declare ev_iri, addr_iri, org_iri, iri, giri, crt_iri, crt_exp, crt_mod varchar;

  if (in_iri is null)
    return;

  if (is_org is null)
    return;

  iri      := person_iri (in_iri, '', is_org);
  org_iri := iri || '#org';
  addr_iri := iri || '#addr';
  ev_iri := iri || '#event';
  crt_iri  := iri || '#cert';
  crt_exp  := iri || '#cert_exp';
  crt_mod  := iri || '#cert_mod';
  giri := iri || '#based_near';
  iri      := person_iri (in_iri, tp=>is_org);

  declare N integer;
  foreach (varchar graph_iri in graphs) do
  	    {
    delete_quad_sp (graph_iri, iri, foaf_iri ('firstName'));
    delete_quad_sp (graph_iri, iri, foaf_iri ('family_name'));
    delete_quad_sp (graph_iri, iri, foaf_iri ('name'));
    delete_quad_sp (graph_iri, iri, foaf_iri ('mbox'));
    delete_quad_sp (graph_iri, iri, foaf_iri ('title'));
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
    delete_quad_s_or_o (graph_iri, ev_iri, ev_iri);
    delete_quad_s_or_o (graph_iri, org_iri, org_iri);
    delete_quad_s_or_o (graph_iri, addr_iri, addr_iri);
    delete_quad_s_or_o (graph_iri, giri, giri);
    delete_quad_s_or_o (graph_iri, crt_iri, crt_iri);
    delete_quad_s_or_o (graph_iri, crt_exp, crt_exp);
    delete_quad_s_or_o (graph_iri, crt_mod, crt_mod);

    -- contact services
    SIOC..ods_object_services_dettach (graph_iri, iri, 'user');
    	}
    }
;

create procedure sioc_user_project (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar, in descr varchar, in piri varchar := null)
{
  declare prj_iri, pers_iri any;

  if (DB.DBA.is_empty_or_null (piri))
    prj_iri := person_prj_iri (iri, sprintf ('%U', nam));
  else
    prj_iri := piri;
  pers_iri := person_iri (iri);
  delete_quad_s_or_o (graph_iri, prj_iri, prj_iri);

  DB.DBA.ODS_QUAD_URI (graph_iri, pers_iri, foaf_iri ('made'), prj_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, prj_iri, foaf_iri ('maker'), pers_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, prj_iri, dc_iri ('creator'), pers_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, prj_iri, dc_iri ('identifier'), url);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, prj_iri, dc_iri ('title'), nam);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, prj_iri, dc_iri ('description'), descr);
};

create procedure sioc_user_related (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar, in pred varchar)
{
  declare rel_iri, pers_iri any;

  rel_iri := url;
  pers_iri := person_iri (iri);
  --delete_quad_s_or_o (graph_iri, rel_iri, rel_iri);

  if (0 = length (pred))
    pred := rdfs_iri ('seeAlso');

  DB.DBA.ODS_QUAD_URI (graph_iri, pers_iri, pred, rel_iri);
  --DB.DBA.ODS_QUAD_URI_L (graph_iri, rel_iri, rdfs_iri ('label'), nam);
};

create procedure sioc_app_related (in graph_iri varchar, in iri varchar, in  nam varchar, in  url varchar, in pred varchar := null)
{
  declare rel_iri any;

  rel_iri := url;
  delete_quad_s_or_o (graph_iri, rel_iri, rel_iri);

  if (0 = length (pred))
    pred := rdfs_iri ('seeAlso');

  DB.DBA.ODS_QUAD_URI (graph_iri, iri, pred, rel_iri);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, rel_iri, rdfs_iri ('label'), nam);
};

create procedure sioc_user_bioevent (in graph_iri varchar, in user_iri varchar, in bioID integer, in bioEvent varchar, in bioDate varchar, in bioPlace varchar)
{
  declare bio_iri, person_iri any;

  person_iri := person_iri (user_iri);
  bio_iri := person_bio_iri (person_iri (user_iri, ''), cast (bioID as varchar));
  delete_quad_s_or_o (graph_iri, bio_iri, bio_iri);

  DB.DBA.ODS_QUAD_URI (graph_iri, bio_iri, rdf_iri ('type'), bioEvent);
  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, bio_iri ('event'), bio_iri);
  if (length (bioDate))
    DB.DBA.ODS_QUAD_URI_L (graph_iri, bio_iri, bio_iri ('date'), bioDate);
  if (length (bioPlace))
    DB.DBA.ODS_QUAD_URI_L (graph_iri, bio_iri, bio_iri ('place'), bioPlace);
};

create procedure sioc_user_offerlist (in user_id integer, in ol_id integer, in ol_type varchar, in ol_flag varchar, in ol_offer varchar, in ol_comment varchar, in ol_properties varchar)
{
  declare user_name, forum_type any;
  declare graph_iri, forum_iri, user_iri, iri, obj any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_iri := person_iri (user_iri (user_id));
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  graph_iri := sioc_user_graph (user_name, ol_flag);
  if (isnull (graph_iri))
    return;

  if        (ol_type = '1') {
    forum_type := 'OfferList';
  forum_iri := offerlist_forum_iri (ol_offer, user_name);
  } else if (ol_type = '2') {
    forum_type := 'WishList';
    forum_iri := wishlist_forum_iri (ol_offer, user_name);
  } else if (ol_type = '3') {
    forum_type := 'OwnsList';
    forum_iri := ownslist_forum_iri (ol_offer, user_name);
  }
  if (DB.DBA.is_empty_or_null (trim (ol_comment)))
    ol_comment := ol_offer;
  sioc_forum (graph_iri, graph_iri, forum_iri, ol_offer, forum_type, ol_comment, null, user_name);

  obj := deserialize (ol_properties);
  sioc_user_items_create (graph_iri, forum_iri, user_iri, obj);
};

create procedure sioc_user_offerlist_delete (in user_id integer, in ol_id integer, in ol_type varchar, in ol_flag varchar, in ol_offer varchar, in ol_comment varchar, in ol_properties varchar)
{
  declare N, M integer;
  declare user_name any;
  declare graph_iri, forum_iri, iri, obj, ontologies, products any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  graph_iri := sioc_user_graph (user_name, ol_flag);
  if (isnull (graph_iri))
    return;

  if        (ol_type = '1') {
  forum_iri := offerlist_forum_iri (ol_offer, user_name);
  } else if (ol_type = '2') {
    forum_iri := wishlist_forum_iri (ol_offer, user_name);
  } else if (ol_type = '3') {
    forum_iri := ownslist_forum_iri (ol_offer, user_name);
  }
  delete_quad_s_or_o (graph_iri, forum_iri, forum_iri);

  sioc_user_items_delete (graph_iri, forum_iri, deserialize (ol_properties));
  }
;

create procedure sioc_user_graph (in user_name varchar, in flag varchar)
{
  declare graph_iri varchar;

  if (flag = '1')
  {
  graph_iri := get_graph ();
  }
  else if (flag = '2')
  {
    graph_iri := get_graph () || '/protected/' || user_name;
  }
  else
  {
    graph_iri := null;
  }
  return graph_iri;
}
;

create procedure sioc_user_likes (in user_id integer, in l_id integer, in l_flag varchar, in l_uri varchar, in l_type varchar, in l_name varchar, in l_comment varchar, in l_properties varchar)
{
  declare user_name any;
  declare graph_iri, forum_iri, forum_name, like_property, user_iri, iri, obj any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_iri := person_iri (user_iri (user_id));
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  graph_iri := sioc_user_graph (user_name, l_flag);
  if (isnull (graph_iri))
    return;

  if (l_type = 'L')
  {
    forum_iri := like_forum_iri (l_name, user_name);
    forum_name := 'Likes';
    like_property := 'likes';
  } else {
    forum_iri := dislike_forum_iri (l_name, user_name);
    forum_name := 'DisLikes';
    like_property := 'dislikes';
  }
  if (DB.DBA.is_empty_or_null (trim (l_comment)))
    l_comment := l_name;
  sioc_forum (graph_iri, graph_iri, forum_iri, l_name, forum_name, l_comment, null, user_name);
  DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, like_iri (like_property), forum_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, rdfs_iri ('seeAlso'), l_uri);

  sioc_user_items_create (graph_iri, forum_iri, user_iri, deserialize (l_properties));
}
;

create procedure sioc_user_likes_delete (in user_id integer, in l_id integer, in l_flag varchar, in l_uri varchar, in l_type varchar, in l_name varchar, in l_comment varchar, in l_properties varchar)
{
  declare N integer;
  declare user_name any;
  declare graph_iri, forum_iri, iri, products any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  graph_iri := sioc_user_graph (user_name, l_flag);
  if (isnull (graph_iri))
    return;

  if (l_type = 'L')
  {
    forum_iri := like_forum_iri (l_name, user_name);
  } else {
    forum_iri := dislike_forum_iri (l_name, user_name);
  }
  delete_quad_s_or_o (graph_iri, forum_iri, forum_iri);

  sioc_user_items_delete (graph_iri, forum_iri, deserialize (l_properties));
}
;

create procedure sioc_user_knows (in user_id integer, in k_id integer, in k_flag varchar, in k_uri varchar, in l_label varchar)
{
  declare user_name any;
  declare graph_iri, forum_iri, forum_name, like_property, user_iri, iri, obj any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_iri := person_iri (user_iri (user_id));
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  graph_iri := sioc_user_graph (user_name, k_flag);
  if (isnull (graph_iri))
    return;

  DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, foaf_iri ('knows'), k_uri);
}
;

create procedure sioc_user_knows_delete (in user_id integer, in k_id integer, in k_flag varchar, in k_uri varchar, in l_label varchar)
{
  declare user_name any;
  declare graph_iri, forum_iri, forum_name, like_property, user_iri, iri, obj any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_iri := person_iri (user_iri (user_id));
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  graph_iri := sioc_user_graph (user_name, k_flag);
  if (isnull (graph_iri))
    return;

  delete_quad_s_p_o (graph_iri, user_iri, foaf_iri ('knows'), k_uri);
}
;

-- favorites
create procedure sioc_user_favorite (in user_id integer, in f_id integer, in f_flag varchar, in f_type varchar, in f_label varchar, in f_uri varchar, in f_class varchar, in f_properties any, in f_create integer := 0)
{
  declare user_name any;
  declare graph_iri, forum_iri, forum_name, user_iri, iri any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_iri := person_iri (user_iri (user_id));
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);

  forum_name := forum_name (user_name, 'FavoriteThings');
  forum_iri := favorite_forum_iri (forum_name (user_name, 'FavoriteThings'), user_name);
  -- first favorites?
  if (f_create or ((select count (WUF_ID) from DB.DBA.WA_USER_FAVORITES where WUF_U_ID = user_id) = 1))
    sioc_forum (get_graph (), get_graph (), forum_iri, forum_name, 'FavoriteThings', null, null, user_name);

  graph_iri := sioc_user_graph (user_name, f_flag);
  if (isnull (graph_iri))
    return;

  iri := favorite_item_iri (forum_iri, f_id);

  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), forum_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ODS.ODS_API."ontology.denormalize" (f_class));
  DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, sioct_iri ('likes'), iri);

  sioc_user_item_properies_create (graph_iri, iri, deserialize (f_properties));
  }
;

create procedure sioc_user_favorite_delete (in user_id integer, in f_id integer, in f_flag varchar, in f_type varchar, in f_label varchar, in f_uri varchar, in f_class varchar, in f_properties any)
{
  declare user_name any;
  declare graph_iri, forum_iri, iri any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  forum_iri := favorite_forum_iri (forum_name (user_name, 'FavoriteThings'), user_name);
  -- no more favorites?
  if ((select count (WUF_ID) from DB.DBA.WA_USER_FAVORITES where WUF_U_ID = user_id) = 0)
    SIOC..delete_quad_s_or_o (graph_iri (), forum_iri, forum_iri);

  graph_iri := sioc_user_graph (user_name, f_flag);
  if (isnull (graph_iri))
    return;

  iri := favorite_item_iri (forum_iri, f_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

create procedure sioc_user_items_create (in graph_iri varchar, in forum_iri varchar, in user_iri varchar, in obj any)
{
  declare N integer;
  declare ontologies any;

  if (get_keyword ('version', obj) = '1.0')
  {
    sioc_user_item_create (graph_iri, forum_iri, user_iri, get_keyword ('products', obj, vector ()));
  }
  else if (get_keyword ('version', obj) = '2.0')
  {
    ontologies := get_keyword ('ontologies', obj, vector ());
    foreach (any ontology in ontologies) do
    {
      sioc_user_item_create (graph_iri, forum_iri, user_iri, get_keyword ('items', ontology, vector ()));
    }
  }
}
;

create procedure sioc_user_item_create (in graph_iri varchar, in forum_iri varchar, in user_iri varchar, in items any)
{
  declare properties, iri any;

  foreach (any item in items) do
  {
    iri := offerlist_item_iri (forum_iri, get_keyword ('id', item));
	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), forum_iri);
	  DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ODS.ODS_API."ontology.denormalize" (get_keyword ('className', item)));

    properties := get_keyword ('properties', item);
    sioc_user_item_properies_create (graph_iri, iri, properties);
  }
}
;

create procedure sioc_user_item_properies_create (in graph_iri varchar, in iri varchar, in properties any)
{
  declare propertyType, propertyName, propertyValue, propertyLanguage any;

  foreach (any property in properties) do
  {
    propertyType := get_keyword ('type', property);
    propertyValue := get_keyword ('value', property);
    propertyName := ODS.ODS_API."ontology.denormalize" (get_keyword ('name', property));
    if (propertyType = 'object')
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, propertyName, ODS.ODS_API."ontology.denormalize" (propertyValue));
    }
    else if (propertyType = 'data')
    {
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, propertyName, propertyValue);
    }
    else
    {
      propertyLanguage := get_keyword ('language', property);
      DB.DBA.ODS_QUAD_URI_L_TYPED (graph_iri, iri, propertyName, propertyValue, ODS.ODS_API."ontology.denormalize" (propertyType), propertyLanguage);
    }
  }
}
;

create procedure sioc_user_items_delete (in graph_iri varchar, in forum_iri varchar, in obj any)
{
  declare N integer;
  declare iri varchar;
  declare ontologies, products any;

  if (get_keyword ('version', obj) = '1.0')
  {
    products := get_keyword ('products', obj, vector ());
    for (N := 0; N < length (products); N := N + 1)
    {
      iri := offerlist_item_iri (forum_iri, N+1);
      delete_quad_s_or_o (graph_iri, iri, iri);
    }
  }
  else if (get_keyword ('version', obj) = '2.0')
  {
    ontologies := get_keyword ('ontologies', obj, vector ());
    foreach (any ontology in ontologies) do
    {
      products := get_keyword ('items', ontology, vector ());
      for (N := 0; N < length (products); N := N + 1)
      {
        iri := offerlist_item_iri (forum_iri, N+1);
        delete_quad_s_or_o (graph_iri, iri, iri);
      }
    }
  }
}
;

create procedure sioc_user_account (
  in graph_iri varchar,
  in iri varchar,
  in name varchar,
  in visible integer,
  in url varchar,
  in uri varchar := null)
{
  declare person_iri any;

  person_iri := person_iri (iri);
  graph_iri := sioc_user_graph2 (graph_iri, person_iri, visible);
  if (name = 'webid' and uri is not null)
  {
    -- external IRIs
    DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), uri);
  }
  else
  {
  if (not length (uri))
      uri := person_ola_iri (iri, name, url);

  DB.DBA.ODS_QUAD_URI (graph_iri, uri, rdf_iri ('type'), foaf_iri ('OnlineAccount'));
  DB.DBA.ODS_QUAD_URI (graph_iri, uri, foaf_iri ('accountServiceHomepage'), url);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, uri, foaf_iri ('accountName'), name);
    DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, foaf_iri ('account'), uri);
  }
};

create procedure sioc_user_account_delete (
  in graph_iri varchar,
  in iri varchar,
  in name varchar,
  in url varchar,
  in visible integer := 1,
  in uri varchar := null)
{
  declare person_iri any;

  person_iri := person_iri (iri);
  graph_iri := sioc_user_graph2 (graph_iri, person_iri, visible);
  if (name = 'webid')
  {
    -- external IRIs
    delete_quad_s_p_o (graph_iri, person_iri, owl_iri ('sameAs'), uri);
  }
  else
  {
  if (isnull (uri))
      uri := person_ola_iri (iri, name, url);

  delete_quad_s_or_o (graph_iri, uri, uri);
  }
};

-- Group
create procedure sioc_group (in graph_iri varchar, in iri varchar, in u_name varchar)
{
  if (iri is null)
    return;

      ods_sioc_result (iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Usergroup'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), u_name);
};

-- Knows

create procedure sioc_knows (
  in graph_iri varchar,
  in _from_iri varchar,
  in _to_iri varchar)
{
  --DB.DBA.ODS_QUAD_URI (graph_iri, _from_iri, sioc_iri ('knows'), _to_iri);
  --DB.DBA.ODS_QUAD_URI (graph_iri, _to_iri, sioc_iri ('knows'), _from_iri);

  _from_iri := person_iri (_from_iri);
  _to_iri := person_iri (_to_iri);

  DB.DBA.ODS_QUAD_URI (graph_iri, _from_iri, foaf_iri ('knows'), _to_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, _to_iri, foaf_iri ('knows'), _from_iri);
};

-- Forum

create procedure sioc_forum (
    	in graph_iri varchar,
	in site_iri varchar,
        in iri varchar,
  in _wai_name varchar,
    	in wai_type_name varchar,
	in wai_description varchar,
	in wai_id int := null,
	in uname varchar := null)
{
  declare clazz, sub, pers_iri, uiri varchar;

  if (iri is null)
    return;

  if (uname is null)
    uname := (select U_NAME
                from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER
               where U_ID = WAM_USER and WAM_INST = _wai_name and WAM_MEMBER_TYPE = 1);

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
  --   DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), clazz);
  -- if (clazz <> sioc_iri ('Container') and wai_type_name <> 'Community')
  --   DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Container'));
  -- A given forum is a subclass of the sioc:Forum, based on sioc types module
  -- if (sub <> clazz or wai_type_name = 'Community')

  DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sub);
  ods_is_defined_by (graph_iri, iri);

  DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), _wai_name);
  if (wai_id is null)
    wai_id := (select i.WAI_ID from DB.DBA.WA_INSTANCE i where i.WAI_NAME = _wai_name);
  if (wai_id is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('identifier'), wai_id);
  -- deprecated DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('type'), DB.DBA.wa_type_to_app (wai_type_name));
  if (wai_description is null)
    wai_description := _wai_name;

    {
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('description'), wai_description);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), wai_description);
    }
  if (wai_type_name <> 'Community')
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, site_iri, sioc_iri ('space_of'), iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_space'), site_iri);
    }
  if (wai_type_name = 'Community')
    {
      declare giri any;
      giri :=  group_iri (iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, giri, rdf_iri ('type'), foaf_iri ('Group'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, giri, foaf_iri ('name'), _wai_name);
    }
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);

  --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));
  --DB.DBA.ODS_QUAD_URI (graph_iri, concat (iri, '/sioc.rdf'), rdf_iri ('type'), sub);

  -- ATOM
  if (clazz = ods_sioc_forum_type ('WEBLOG2'))
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Feed'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), _wai_name);
    }
  if (wai_type_name = 'AddressBook')
    {
      -- attach instance services
      ods_object_services_attach (graph_iri, iri, 'instance');
      ods_object_services_attach (graph_iri, iri, DB.DBA.wa_type_to_app (wai_type_name));

      iri := forum_iri ('SocialNetwork', _wai_name);
      sioc_forum (graph_iri, site_iri, iri, _wai_name, 'SocialNetwork', wai_description);
    }

  if (pers_iri is not null)
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), pers_iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, pers_iri, foaf_iri ('made'), iri);
    }

  -- attach instance services
  ods_object_services_attach (graph_iri, iri, 'instance');
  ods_object_services_attach (graph_iri, iri, DB.DBA.wa_type_to_app (wai_type_name));
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
  if (iri is null)
	  return;

    declare do_ann, do_exif, do_atom int;
    declare arr, creator, app any;

    do_atom := do_ann := do_exif := 0;
    creator := null;

      ods_sioc_result (iri);

  --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Item'));

      --if (maker is null)
  --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdfs_iri ('seeAlso'), concat (iri, '/sioc.rdf'));
      ods_is_defined_by (graph_iri, iri);

  DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('id'), md5 (iri));
      -- user
      if (cr_iri is not null)
	{
	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_creator'), cr_iri);
	  DB.DBA.ODS_QUAD_URI (graph_iri, cr_iri, sioc_iri ('creator_of'), iri);
	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), person_iri (cr_iri));
	  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri (cr_iri), foaf_iri ('made'), iri);
	}
      if (cr_iri is null and length (maker) > 0)
	{
	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), maker);
	}
      app := null;

      -- forum
      if (forum_iri is not null)
        {
	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), forum_iri);
	  DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, sioc_iri ('container_of'), iri);
	  arr := sprintf_inverse (forum_iri, graph_iri || '/%s/%s/%s', 1);
	  if (arr is not null and length (arr) = 3)
	    {
	      app := arr[1];
	      if (arr[1] = 'photos')
	    {
		do_exif := 1;
		  }
		else if (arr[1] = 'bookmark')
		  {
		    do_ann := 1;
		    creator := arr[0];
		  }
      else if (arr[1] not in ('socialnetwork', 'offerlist', 'wishlist', 'ownslist', 'favoritethings'))
	    {
		do_atom := 1;
	    }
	  }
	  else if (forum_iri like graph_iri || '/discussion/%')
	    {
	      app := 'discussion';
	    }
	  else
    {
	    do_atom := 1;
        }
  }
      -- this is a subclassing of the different types of Item, former Post
      if (maker is not null and app <> 'discussion') -- means comment
	{
    --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('Comment'));
	}
      else if (app = 'weblog')
	{
    --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('BlogPost'));
	}
      else if (app = 'discussion')
	{
    --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('BoardPost'));
	}
      else if (app = 'mail')
	{
    --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('MailMessage'));
	}
      --else if (app = 'bookmark') handled below
      --;
      else if (app = 'briefcase')
  {
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Document'));
  }
      else if (app = 'wiki')
	{
    --DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), wikiont_iri ('Article'));
	}
      else if (not do_exif and not do_ann and not do_atom)
  {
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Item'));
  }
      -- literal data
      if (title is not null and length (title))
	{
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('title'), title);
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), title);
        }
      if (ts is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), (ts));
      if (modf is not null)
	{
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dcterms_iri ('modified'), (modf));
	  if (ts is null)
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), (modf));
	}
      if (link is not null)
	link := make_href (link);
      else
        link := iri;

  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('link'), link);
      if (links_to is not null)
	{
	  foreach (any l in links_to) do
	    {
	      if (length (l) > 1 and l[1] is not null)
		{
		  declare url varchar;
		  url := DB.DBA.RDF_MAKE_IID_OF_QNAME (l[1]);
		  if (url is not null)
          DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('links_to'), url);
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
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('attachment'), l);
	    }
	}
      -- ATOM
      if (do_atom)
        {
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), atom_iri ('Entry'));
	  if (forum_iri is not null)
	    {
	    DB.DBA.ODS_QUAD_URI (graph_iri, iri, atom_iri ('source'), forum_iri);
	    DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, atom_iri ('entry'), iri);
	    DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, atom_iri ('contains'), iri);
	    }
	  if (title is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, atom_iri ('title'), title);
	  if (cr_iri is not null)
	    DB.DBA.ODS_QUAD_URI (graph_iri, iri, atom_iri ('author'), person_iri (cr_iri));
	  if (ts is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, atom_iri ('published'), sioc_date (ts));
	  if (modf is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, atom_iri ('updated'), sioc_date (modf));
	  if (0 and link is not null) -- obsoleted
	    {
      DB.DBA.ODS_QUAD_URI (graph_iri, link, rdf_iri ('type'), atom_iri ('Link'));
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, atom_iri ('link'), link);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, link, atom_iri ('LinkHref'), link);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, link, atom_iri ('linkRel'), 'alternate');
	    }
        }
      if (content is not null and not do_exif)
	{
	  declare ses any;
      if (__tag (content) = __tag of XML)
	content := serialize_to_UTF8_xml (content);
      content := subseq (content, 0, 10000000);
      --content := regexp_replace (content, '<[^>]+>', '', 1, null);
      --ses := string_output ();
      --http_value (content, null, ses);
      --ses := string_output_string (ses);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('content'), content);
	}
      if (do_ann)
	{
	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'),  bm_iri ('Bookmark'));
          if (modf is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('date'), sioc_date (modf));
          if (content is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('description'), content);
	  if (creator is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('creator'), creator);
          if (ts is not null)
	    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, ann_iri ('created'), (ts));
          if (link is not null)
	    DB.DBA.ODS_QUAD_URI (graph_iri, iri, bm_iri ('recalls'), link);
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
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'),  exif_iri ('IFD'));
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
	      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, exif_iri (fld), r);
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
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), services_iri ('Service'));
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, services_iri ('service_of'), forum_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, services_iri ('has_service'), iri);
  if (max_res is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, services_iri ('max_results'), cast (max_res as varchar));
  if (fmt is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, services_iri ('results_format'), fmt);
  if (wsdl is not null)
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, services_iri ('service_definition'), wsdl);
  if (endpoint is not null)
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, services_iri ('service_endpoint'), endpoint);
  if (proto is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, services_iri ('service_protocol'), proto);
  if (descr is not null or proto is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), coalesce (descr, proto));
  if (id is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('identifier'), id);
  commit work;
};



use sioc;

-------------------------------------------------------------------------------
--
create procedure ods_object_services_iri (
  in object_name varchar)
{
  return sprintf ('http://%s%s/services/%s', get_cname (), get_base_path (), object_name);
}
;

-------------------------------------------------------------------------------
--
create procedure ods_object_service_iri (
  in object_name varchar,
  in service_name varchar)
{
  return sprintf ('http://%s%s/service/%s/%s', get_cname (), get_base_path (), object_name, service_name);
}
;

-------------------------------------------------------------------------------
--
create procedure ods_object_service_url (
  in service_name varchar,
  in shortMode integer := 0)
{
  declare service_url varchar;
  declare params any;
  declare delimiter varchar;

  service_url := sprintf ('http://%s/ods/api/%s', get_cname(), service_name);
  if (not shortMode)
  {
    delimiter := '?';
    params := procedure_cols ('ODS..' || service_name);
    foreach (any param in params) do
    {
      service_url := sprintf ('%s%s%s={%s}', service_url, delimiter, param[3], param[3]);
      delimiter := '&';
    }
  }
  return service_url;
}
;

-------------------------------------------------------------------------------
--
create procedure ods_object_services (
  in graph_iri varchar,
  in svc_object varchar,
  in svc_object_title varchar,
  in svc_functions any)
{
  declare services_iri, service_iri, service_url varchar;

  services_iri := ods_object_services_iri (svc_object);
  DB.DBA.ODS_QUAD_URI (graph_iri, services_iri, rdf_iri ('type'), services_iri ('Services'));
  DB.DBA.ODS_QUAD_URI_L (graph_iri, services_iri, dc_iri ('title'), svc_object_title);
  foreach (any svc_function in svc_functions) do
  {
    service_iri := ods_object_service_iri (svc_object, svc_function);
    service_url := ods_object_service_url (svc_function);
    ods_sioc_service (graph_iri, service_iri, services_iri, null, null, null, service_url, 'REST');
  }
}
;

create procedure ods_object_services_attach (
  in graph_iri varchar,
  in iri varchar,
  in svc_object varchar)
{
  declare services_iri varchar;

  services_iri := ods_object_services_iri (svc_object);
  DB.DBA.ODS_QUAD_URI (graph_iri, services_iri, services_iri ('services_of'), iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, iri, services_iri ('has_services'), services_iri);
}
;

create procedure ods_object_services_dettach (
  in graph_iri varchar,
  in iri varchar,
  in svc_object varchar)
{
  declare services_iri varchar;

  services_iri := ods_object_services_iri (svc_object);
  delete_quad_s_p_o (graph_iri, services_iri, services_iri ('services_of'), iri);
  delete_quad_s_p_o (graph_iri, iri, services_iri ('has_services'), services_iri);
}
;

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
    DB.DBA.ODS_QUAD_URI_L (graph_iri, post_iri, dc_iri ('subject'), _tags);
  else
    DB.DBA.ODS_QUAD_URI_L (graph_iri, post_iri, dc_iri ('subject'), '~none~');
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

create procedure ods_sioc_atomic (in f int)
{
  if (1 = sys_stat ('cl_run_local_only'))
    {
      __atomic (f);
    }
}
;

create procedure ods_sioc_init ()
{
  registry_set ('__ods_sioc_version', ods_current_ver ());
  --if (registry_get ('__ods_sioc_init') = registry_get ('__ods_sioc_version'))
  if (isstring (registry_get ('__ods_sioc_init')))
    return;
  declare exit handler for sqlstate '*'
    {
      ods_sioc_atomic (0);
      resignal;
    };
  ods_sioc_atomic (1);
  DB.DBA.TTLP (sioct_n3 (), '', get_graph() || '/inf');
  DB.DBA.RDFS_RULE_SET (get_graph (), get_graph() || '/inf');
  fill_ods_sioc (1);
  registry_set ('__ods_sioc_init', registry_get ('__ods_sioc_version'));
  ods_sioc_atomic (0);
  return;
};

create procedure ods_sioc_result (in iri_res any)
{
  declare rc int;
  rc := connection_get ('iri_result');
  if (__tag (iri_res) = __tag of IRI_ID)
    iri_res := id_to_iri (iri_res);
  if (not isstring (iri_res))
    return; --signal ('22023', 'Not an iri');
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
  declare iri, site_iri, graph_iri, tmp_graph_iri, forum_iri, sioc_version varchar;
  declare fCreate, cpt, deadl, cnt int;

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
    declare exit handler for sqlstate '40001' 
    {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
    };
    
    l0:
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (fix_graph (graph_iri));

    -- clean private graphs
	  for select WAI_ID,
	             WAI_TYPE_NAME,
	             WAI_NAME,
               WAI_IS_PUBLIC
		      from DB.DBA.WA_INSTANCE
		     where WAI_IS_PUBLIC = 0 do
		{
      forum_iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
      tmp_graph_iri := get_graph_new (WAI_IS_PUBLIC, forum_iri);
      if (length (tmp_graph_iri))
      {
        delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (tmp_graph_iri);

        -- remove user's rights for private graphs
    	  for select WAM_USER
    		      from DB.DBA.WA_MEMBER
  		     where WAM_INST = WAI_NAME do
    		{
          SIOC..private_user_remove (tmp_graph_iri, WAM_USER);
        }
      }
		}
    commit work;
    set isolation='committed';
    ods_graph_init ();
  }

  ods_ping_svc_init (graph_iri, site_iri);
  scot_tags_init ();
  fill_ods_services ();

  -- init users
  {
    declare _u_name varchar;
    _u_name := '';
    deadl := 3;
    declare exit handler for sqlstate '40001' 
    {
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
    	  declare forum_name any;

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
                   WAUI_HADDRESS1,
                   WAUI_HADDRESS2,
                   WAUI_HCODE,
            		   WAUI_HCITY,
            		   WAUI_HSTATE,
            		   WAUI_HCOUNTRY,
            		   WAUI_BLAT,
            		   WAUI_BLNG,
            		   WAUI_LATLNG_HBDEF,
            		   WAUI_SKYPE,
			   WAUI_CERT
		          from DB.DBA.WA_USER_INFO
		         where WAUI_U_ID = u_id do
		{
                  declare kwd any;
		  declare lat, lng real;

		  if (WAUI_SITE_NAME is not null)
		    DB.DBA.ODS_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), WAUI_SITE_NAME);

		  sioc_user_info (graph_iri,
		                  iri,
		                  null,
		                  WAUI_VISIBLE,
		                  WAUI_FIRST_NAME,
		                  WAUI_LAST_NAME,
		                  WAUI_TITLE,
		                  U_FULL_NAME,
				  U_E_MAIL,
		                  WAUI_GENDER,
		                  WAUI_ICQ,
		                  WAUI_MSN,
		                  WAUI_AIM,
		                  WAUI_YAHOO,
		                  WAUI_SKYPE,
		                  WAUI_BIRTHDAY,
		                  WAUI_BORG,
	              	    case when length (WAUI_HPHONE) then WAUI_HPHONE when length (WAUI_HMOBILE) then WAUI_HMOBILE else WAUI_BPHONE end,
            					WAUI_LATLNG_HBDEF,
		                  WAUI_LAT,
		                  WAUI_LNG,
		                  WAUI_BLAT,
		                  WAUI_BLNG,
			WAUI_WEBPAGE,
			WAUI_PHOTO_URL,
			WAUI_BORG_HOMEPAGE,
			WAUI_RESUME,
			WAUI_INTERESTS,
                			WAUI_INTEREST_TOPICS,
                      WAUI_HADDRESS1,
                      WAUI_HADDRESS2,
                      WAUI_HCODE,
			WAUI_HCITY,
			WAUI_HSTATE,
			WAUI_HCOUNTRY,
					WAUI_CERT
			);

		  kwd := DB.DBA.WA_USER_TAG_GET (U_NAME);
		  if (length (kwd))
		    DB.DBA.ODS_QUAD_URI_L (graph_iri, person_iri, bio_iri ('keywords'), kwd);

      -- update WebAccess graph
      for (select distinct WACL_USER_ID from DB.DBA.WA_GROUPS_ACL) do
      {
        delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (SIOC..acl_groups_graph (WACL_USER_ID));
      }
      for (select * from DB.DBA.WA_GROUPS_ACL) do
      {
        wa_groups_acl_insert (WACL_USER_ID, WACL_NAME, WACL_WEBIDS);
      }
		  for select WUP_NAME, WUP_URL, WUP_DESC, WUP_IRI from DB.DBA.WA_USER_PROJECTS where WUP_U_ID = U_ID do
		    {
		      sioc_user_project (graph_iri, iri, WUP_NAME, WUP_URL, WUP_DESC, WUP_IRI);
		    }
		  for select WUO_NAME, WUO_PUBLIC, WUO_URL, WUO_URI from DB.DBA.WA_USER_OL_ACCOUNTS where WUO_U_ID = U_ID do
		    {
		      sioc_user_account (graph_iri, iri, WUO_NAME, WUO_PUBLIC, WUO_URL, WUO_URI);
		    }
		  for select WUR_LABEL, WUR_SEEALSO_IRI, WUR_P_IRI from DB.DBA.WA_USER_RELATED_RES where WUR_U_ID = U_ID do
		    {
		      sioc_user_related (graph_iri, iri, WUR_LABEL, WUR_SEEALSO_IRI, WUR_P_IRI);
		    }
		  for select WUB_ID, WUB_EVENT, WUB_DATE, WUB_PLACE from DB.DBA.WA_USER_BIOEVENTS where WUB_U_ID = U_ID do
		    {
          sioc_user_bioevent (graph_iri, iri, WUB_ID, WUB_EVENT, WUB_DATE, WUB_PLACE);
		    }
		  for select WUOL_U_ID, WUOL_ID, WUOL_TYPE, WUOL_FLAG, WUOL_OFFER, WUOL_COMMENT, WUOL_PROPERTIES from DB.DBA.WA_USER_OFFERLIST where WUOL_U_ID = U_ID do
		    {
		      sioc_user_offerlist (WUOL_U_ID, WUOL_ID, WUOL_TYPE, WUOL_FLAG, WUOL_OFFER, WUOL_COMMENT, WUOL_PROPERTIES);
		    }
		  for select WUL_U_ID, WUL_ID, WUL_FLAG, WUL_URI, WUL_TYPE, WUL_NAME, WUL_COMMENT, WUL_PROPERTIES from DB.DBA.WA_USER_LIKES where WUL_U_ID = U_ID do
		      {
		      sioc_user_likes (WUL_U_ID, WUL_ID, WUL_FLAG, WUL_URI, WUL_TYPE, WUL_NAME, WUL_COMMENT, WUL_PROPERTIES);
		    }
		  for select WUK_U_ID, WUK_ID, WUK_FLAG, WUK_URI, WUK_LABEL from DB.DBA.WA_USER_KNOWS where WUK_U_ID = U_ID do
		    {
		      sioc_user_knows (WUK_U_ID, WUK_ID, WUK_FLAG, WUK_URI, WUK_LABEL);
		    }
		  fCreate := 1;
		  for select WUF_U_ID, WUF_ID, WUF_FLAG, WUF_TYPE, WUF_LABEL, WUF_URI, WUF_CLASS, WUF_PROPERTIES from DB.DBA.WA_USER_FAVORITES where WUF_U_ID = U_ID do
		    {
		      sioc_user_favorite (WUF_U_ID, WUF_ID, WUF_FLAG, WUF_TYPE, WUF_LABEL, WUF_URI, WUF_CLASS, WUF_PROPERTIES, fCreate);
		      fCreate := 0;
		    }
		  for select UC_ID, UC_CERT from DB.DBA.WA_USER_CERTS where UC_U_ID = U_ID do
		    {
		      sioc_user_cert (graph_iri, person_iri, UC_ID, UC_CERT);
		    }
		}

	  for select WAI_ID,
	             WAI_TYPE_NAME, 
	             WAI_NAME,
	             WAM_INST,
               WAM_APP_TYPE,
               WAM_USER,
               WAM_MEMBER_TYPE,
               WAI_IS_PUBLIC,
               WAI_DESCRIPTION,
               WAI_LICENSE
		      from DB.DBA.WA_MEMBER, 
		           DB.DBA.WA_INSTANCE
		     where WAM_USER = U_ID 
		       and WAM_INST = WAI_NAME 
		       and SIOC..instance_sioc_check (WAI_IS_PUBLIC, WAI_TYPE_NAME) = 1 do
		{
		  instance_sioc_data (
                          WAM_INST,
                          WAM_APP_TYPE,
                          WAM_USER,
                          WAM_MEMBER_TYPE,
                          WAI_IS_PUBLIC,
                          WAI_DESCRIPTION,
                          WAI_LICENSE
                         );

		  declare firi varchar;

		  firi := forum_iri (WAI_TYPE_NAME, WAI_NAME);
		  for select RA_URI, RA_LABEL from DB.DBA.WA_RELATED_APPS where RA_WAI_ID = WAI_ID do
		      sioc_app_related (graph_iri, firi, RA_LABEL, RA_URI);
		    }
	      for select US_IRI, US_KEY from DB.DBA.WA_USER_SVC where US_U_ID = U_ID and length (US_IRI) do
		{
		  declare sas_iri any;
		  sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), US_IRI);
		  if (length (US_KEY))
		    sas_iri := sas_iri || sprintf ('&login=%U', U_NAME);
		  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
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

  declare ep, ep2 varchar;
  ep := sprintf ('http://%s/semping', sioc..get_cname ());
  ep2 := ep || '/rest';
  for select * from SEMPING.DBA.PING_RULES where PR_GRAPH = graph_iri do
    {
      sparql insert into graph iri(?:PR_GRAPH) { `iri(?:PR_IRI)` <http://purl.org/net/pingback/to> `iri(?:ep2)` . };
      -- XXX: obsolete
      --sparql insert into graph iri(?:PR_GRAPH) { `iri(?:PR_IRI)` <http://purl.org/net/pingback/service> `iri(?:ep)` . };
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
      	  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('member_of'), g_iri);
      	  DB.DBA.ODS_QUAD_URI (graph_iri, g_iri, sioc_iri ('has_member'), iri);
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
    declare exit handler for sqlstate '40001' 
    {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l3;
    };
    
    l3:
  -- sioc:knows
    for select snr_from, snr_to, snr_serial 
          from DB.DBA.sn_related
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

	  --  {
  --   declare _wai_name varchar;
  --   _wai_name := '';
  --   deadl := 3;
  --   declare exit handler for sqlstate '40001' 
  --   {
  --     if (deadl <= 0)
	--       resignal;
  --     rollback work;
  --     deadl := deadl - 1;
  --     goto l4;
  --   };
  --   l4:
  -- 
  -- -- sioc:Forum
  -- for select WAI_TYPE_NAME, WAI_ID, WAI_NAME, WAI_DESCRIPTION, WAI_LICENSE 
  --       from DB.DBA.WA_INSTANCE
  --      where WAI_NAME > _wai_name and WAI_IS_PUBLIC = 1 or WAI_TYPE_NAME = 'oDrive' do
  --   {
  --     iri := forum_iri (WAI_TYPE_NAME, WAI_NAME);
  --     if (iri is not null)
	--     {
  --   	  sioc_forum (graph_iri, site_iri, iri, WAI_NAME, WAI_TYPE_NAME, WAI_DESCRIPTION, WAI_ID);
  --   	  cc_work_lic (graph_iri, iri, WAI_LICENSE);
  --   
  --   	}
  --     cnt := cnt + 1;
  --     if (mod (cnt, 500) = 0)
  --   	{
  --   	  commit work;
  --   	  _wai_name := WAI_NAME;
  --   	}
  --   }
  --   commit work;
	  --  }

  if (doall)
    {
      sioc_version := registry_get ('__ods_sioc_version');
      for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES
	--where 0 = 1
	do
	{
	  declare p_name varchar;

	  p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc2', suffix);
	  if (__proc_exists (p_name))
	    if (registry_get (sprintf('__ods_%s_sioc_init', suffix)) <> sioc_version)
	    {
		    call (p_name) ();
		    registry_set (sprintf('__ods_%s_sioc_init', suffix), sioc_version);
	    }
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
}
;

create procedure fill_ods_services ()
{
  declare graph_iri varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('instance.create', 'instance.update', 'instance.delete', 'instance.join', 'instance.disjoin', 'instance.join_approve', 'instance.search', 'instance.get', 'instance.get.id', 'instance.freeze', 'instance.unfreeze' );
  ods_object_services (graph_iri, 'instance', 'ODS instance services', svc_functions);

  -- user
  svc_functions := vector ('user.login', 'user.validate', 'user.logout', 'user.update', 'user.password_change', 'user.delete', 'user.enable', 'user.disable', 'user.get', 'user.info', 'user.info.webID', 'user.search');
  ods_object_services (graph_iri, 'user', 'ODS user services', svc_functions);
}
;

create procedure ods_sioc_version_reset (in ver any := '0')
{
  registry_set ('__ods_sioc_init', ver);
  for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES do
    {
      declare p_name varchar;

      p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc', suffix);
      if (__proc_exists (p_name))
	  registry_set (sprintf('__ods_%s_sioc_init', suffix), ver);
    p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc2', suffix);
    if (__proc_exists (p_name))
   	  registry_set (sprintf('__ods_%s_sioc_init', suffix), ver);
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
	      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
	      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_creator'), c_iri);
	      DB.DBA.ODS_QUAD_URI (graph_iri, c_iri, sioc_iri ('creator_of'), iri);

	      for select WAM_INST from DB.DBA.WA_MEMBER where WAM_USER = U_ID and WAM_APP_TYPE = 'oDrive' do
		{
		  f_iri := briefcase_iri (WAM_INST);
		  DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), f_iri);
		  DB.DBA.ODS_QUAD_URI (graph_iri, f_iri, sioc_iri ('container_of'), iri);
		}

	      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dc_iri ('title'), RES_NAME);
	      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('link'), iri);
	      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), (RES_CR_TIME));
	      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, dcterms_iri ('modified') , (RES_MOD_TIME));
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
  declare S any;

  S := string_output ();
  http_dav_url (path, null, S);
  S := string_output_string (S);
  return sprintf ('http://%s%s', get_cname(), S);
};

registry_set ('URIQADynamicLocal', coalesce (cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DynamicLocal'), '0'));

create procedure fix_graph (in g any)
{
  if (registry_get ('URIQADynamicLocal') = '1' and isstring (g) and g like get_graph () || '%')
    {
      declare pref any;
      pref := sprintf ('http://%s', get_cname ());
      g := 'local:' || subseq (g, length (pref));
    }
  return g;
}
;

create procedure fix_uri (in uri any)
{
  declare hf any;

  hf := rfc1808_parse_uri (uri);
  if (hf[1] = registry_get ('URIQADefaultHost') and registry_get ('URIQADynamicLocal') = '1')
  {
    hf[0] := 'local';
    hf[1] := '';
    uri := DB.DBA.vspx_uri_compose (hf);
  }
  return uri;
}
;

create procedure DB.DBA.ODS_QUAD_URI (in g_iri any, in s_iri any, in p_iri any, in o_iri any)
{
  g_iri := fix_graph (g_iri);
  s_iri := fix_graph (s_iri);
  o_iri := fix_graph (o_iri);
  DB.DBA.RDF_QUAD_URI (g_iri, s_iri, p_iri, o_iri);
}
;

create procedure DB.DBA.ODS_QUAD_URI_L (in g_iri any, in s_iri any, in p_iri any, in obj any)
{
  g_iri := fix_graph (g_iri);
  s_iri := fix_graph (s_iri);
  DB.DBA.RDF_QUAD_URI_L (g_iri, s_iri, p_iri, obj);
}
;

create procedure DB.DBA.ODS_QUAD_URI_L_TYPED (in g_iri any, in s_iri any, in p_iri any, in obj any, in dt varchar, in lang varchar)
{
  g_iri := fix_graph (g_iri);
  s_iri := fix_graph (s_iri);
  DB.DBA.RDF_QUAD_URI_L_TYPED (g_iri, s_iri, p_iri, obj, dt, lang);
}
;

create procedure delete_quad_so (in _g any, in _s any, in _o any)
{
  _g := fix_graph (_g);
  _s := fix_graph (_s);
  _o := fix_graph (_o);
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  if (_g is null or _s is null or _o is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and O = _o;
};

create procedure delete_quad_sp (in _g any, in _s any, in _p any)
{
  _g := fix_graph (_g);
  _s := fix_graph (_s);
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  _p := DB.DBA.RDF_IID_OF_QNAME (_p);
  if (_g is null or _s is null or _p is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s and P = _p;
};

create procedure delete_quad_po (in _g any, in _p any, in _o any)
{
  _g := fix_graph (_g);
  _o := fix_graph (_o);
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _p := DB.DBA.RDF_IID_OF_QNAME (_p);
  if (_g is null or _o is null or _p is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and O = _o and P = _p;
};

create procedure delete_quad_s_p_o (in _g any, in _s any, in _p any, in _o any)
{
  _g := fix_graph (_g);
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
  _g := fix_graph (_g);
  _s := fix_graph (_s);
  _o := fix_graph (_o);
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

create procedure delete_quad_s (in _g any, in _s any)
{
  declare preds any;
  _g := fix_graph (_g);
  _s := fix_graph (_s);
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _s := DB.DBA.RDF_IID_OF_QNAME (_s);
  if (_g is null or _s is null)
    return;
  delete from DB.DBA.RDF_QUAD where G = _g and S = _s;
}
;

create procedure update_quad_s_o (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null or _n = _o)
    return;
  _g := fix_graph (_g);
  _n := fix_graph (_n);
  _o := fix_graph (_o);
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set S = _n where G = _g and S = _o;
  update DB.DBA.RDF_QUAD set O = _n where G = _g and O = _o;
};

create procedure update_quad_g_s_o (in _g any, in _gn any, in _o any, in _n any)
{
  if (_o is null or _n is null or (_n = _o and _g = _gn))
    return;
  _gn := fix_graph (_gn);
  _g := fix_graph (_g);
  _n := fix_graph (_n);
  _o := fix_graph (_o);
  _gn := DB.DBA.RDF_IID_OF_QNAME (_gn);
  _g := DB.DBA.RDF_IID_OF_QNAME (_g);
  _o := DB.DBA.RDF_IID_OF_QNAME (_o);
  _n := DB.DBA.RDF_MAKE_IID_OF_QNAME (_n);
  update DB.DBA.RDF_QUAD set G = _gn, S = _n where G = _g  and S = _o;
  update DB.DBA.RDF_QUAD set G = _gn, O = _n where G = _g  and O = _o;
  update DB.DBA.RDF_QUAD set S = _n where G = _gn  and S = _o;
  update DB.DBA.RDF_QUAD set O = _n where G = _gn  and O = _o;
};

create procedure update_quad_p (in _g any, in _o any, in _n any)
{
  if (_o is null or _n is null or _n = _o)
    return;
  _g := fix_graph (_g);
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
      --!!! ACL delete_quad_sp (graph_iri, oiri, sioc_iri ('email'));
      --!!! ACL delete_quad_sp (graph_iri, oiri, sioc_iri ('name'));
      delete_quad_sp (graph_iri, oiri, sioc_iri ('email_sha1'));

      oiri := person_iri (oiri);
      --!!! ACL delete_quad_sp (graph_iri, oiri, foaf_iri ('name'));
      --!!! ACL delete_quad_sp (graph_iri, oiri, foaf_iri ('mbox'));
      delete_quad_sp (graph_iri, oiri, foaf_iri ('mbox_sha1sum'));

      --!!! ACL if (length (N.U_FULL_NAME))
      --!!! ACL	  {
      --!!! ACL     DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('name'), N.U_FULL_NAME);
      --!!! ACL   }

      if (length (N.U_E_MAIL))
	{
	  --!!! ACL DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('email'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, sioc_iri ('email_sha1'), sha1_digest (N.U_E_MAIL));

	  iri := person_iri (iri);
	  --!!! ACL DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('mbox'), 'mailto:'||N.U_E_MAIL);
	  DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), sha1_digest (N.U_E_MAIL));
	  --!!! ACL if (length (N.U_FULL_NAME))
	  --!!! ACL  DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), N.U_FULL_NAME);
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
  DB.DBA.ODS_QUAD_URI_L (graph_iri, site_iri, dc_iri ('title'), coalesce (N.WS_WEB_TITLE, sys_stat ('st_host_name')));
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
  declare iri, graph_iri, u_site_iri, uname, _u_full_name, _u_e_mail varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  uname := _u_full_name := _u_e_mail := null;
  for select U_NAME, U_FULL_NAME, U_E_MAIL from DB.DBA.SYS_USERS where U_ID = N.WAUI_U_ID do
  {
    uname := U_NAME;
    _u_full_name := U_FULL_NAME;
    _u_e_mail := U_E_MAIL;
  }
  u_site_iri := user_space_iri (uname);
  if (N.WAUI_SITE_NAME is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), N.WAUI_SITE_NAME);
  sioc_user_info (graph_iri, iri, null, N.WAUI_VISIBLE, N.WAUI_FIRST_NAME, N.WAUI_LAST_NAME, N.WAUI_TITLE, _u_full_name, _u_e_mail);
}
;

create trigger WA_USER_INFO_SIOC_U after update on DB.DBA.WA_USER_INFO referencing old as O, new as N
{
  declare iri, graph_iri, u_site_iri, uname, niri, del_iri, _u_full_name, _u_e_mail varchar;
  declare lat, lng real;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := user_iri (N.WAUI_U_ID);
  uname := _u_full_name := _u_e_mail := null;
  for select U_NAME, U_FULL_NAME, U_E_MAIL from DB.DBA.SYS_USERS where U_ID = N.WAUI_U_ID do
  {
    uname := U_NAME;
    _u_full_name := U_FULL_NAME;
    _u_e_mail := U_E_MAIL;
  }
  u_site_iri := user_space_iri (uname);
  delete_quad_sp (graph_iri, u_site_iri, dc_iri ('title'));
  if (N.WAUI_SITE_NAME is not null)
    DB.DBA.ODS_QUAD_URI_L (graph_iri, u_site_iri, dc_iri ('title'), N.WAUI_SITE_NAME);

  niri := person_iri (iri, tp=>N.WAUI_IS_ORG);
  if (O.WAUI_IS_ORG <> N.WAUI_IS_ORG)
    {
      declare oiri any;
      oiri := person_iri (iri, tp=>O.WAUI_IS_ORG);
      update_quad_s_o (graph_iri, oiri, niri);
      if (N.WAUI_IS_ORG)
	{
      update DB.DBA.RDF_QUAD
         set O = iri_to_id (foaf_iri ('Organization'))
       where G = iri_to_id (graph_iri)
         and S = iri_to_id (niri)
         and P = iri_to_id (rdf_iri ('type'))
	    and O = iri_to_id (foaf_iri ('Person'));
	}
      else
	{
      update DB.DBA.RDF_QUAD
         set O = iri_to_id (foaf_iri ('Person'))
       where G = iri_to_id (graph_iri)
         and S = iri_to_id (niri)
         and P = iri_to_id (rdf_iri ('type'))
	    and O = iri_to_id (foaf_iri ('Organization'));
	}
    }
  if (length (O.WAUI_SKYPE))
    sioc_user_account_delete (graph_iri, iri, null, O.WAUI_SKYPE);

  sioc_user_info (graph_iri,
                  iri,
                  O.WAUI_IS_ORG,
                  N.WAUI_VISIBLE,
                  N.WAUI_FIRST_NAME,
                  N.WAUI_LAST_NAME,
        		      N.WAUI_TITLE,
        		      _u_full_name,
			      _u_e_mail,
        		      N.WAUI_GENDER,
        		      N.WAUI_ICQ,
        		      N.WAUI_MSN,
        		      N.WAUI_AIM,
        		      N.WAUI_YAHOO,
                  N.WAUI_SKYPE,
        		      N.WAUI_BIRTHDAY,
        		      N.WAUI_BORG,
        	        case when length (N.WAUI_HPHONE) then N.WAUI_HPHONE when length (N.WAUI_HMOBILE) then N.WAUI_HMOBILE else N.WAUI_BPHONE end,
          				N.WAUI_LATLNG_HBDEF,
	                N.WAUI_LAT,
	                N.WAUI_LNG,
	                N.WAUI_BLAT,
	                N.WAUI_BLNG,
			N.WAUI_WEBPAGE,
			N.WAUI_PHOTO_URL,
			N.WAUI_BORG_HOMEPAGE,
			N.WAUI_RESUME,
			N.WAUI_INTERESTS,
            			N.WAUI_INTEREST_TOPICS,
                  N.WAUI_HADDRESS1,
                  N.WAUI_HADDRESS2,
                  N.WAUI_HCODE,
			N.WAUI_HCITY,
			N.WAUI_HSTATE,
			N.WAUI_HCOUNTRY,
				N.WAUI_CERT
			);
  for select US_IRI, US_KEY from DB.DBA.WA_USER_SVC where US_U_ID = N.WAUI_U_ID and length (US_IRI) do
    {
      declare sas_iri any;
      sas_iri := sprintf ('http://%s/proxy?url=%U&force=rdf', get_cname(), US_IRI);
      if (length (US_KEY))
	sas_iri := sas_iri || sprintf ('&login=%U', uname);
      DB.DBA.ODS_QUAD_URI (graph_iri, niri, owl_iri ('sameAs'), sas_iri);
    }

  return;
};

create procedure wa_user_acl_insert (
  inout user_iri varchar,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := SIOC..acl_clean_iri (user_iri) || '/webaccess';
  SIOC..acl_insert (graph_iri, SIOC..person_iri (user_iri), acl);
}
;

create procedure wa_user_acl_delete (
  inout user_iri varchar,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := SIOC..acl_clean_iri (user_iri) || '/webaccess';
  SIOC..acl_delete (graph_iri, SIOC..person_iri (user_iri), acl);
}
;

create trigger WA_USER_INFO_SIOC_ACL_I after insert on DB.DBA.WA_USER_INFO order 100 referencing new as N
{
  if (coalesce (N.WAUI_ACL, '') <> '')
  {
    contact_acl_insert (person_iri (user_iri (N.WAUI_U_ID)), N.WAUI_ACL);

    SIOC..acl_ping2 (N.WAUI_U_ID,
                     person_iri (user_iri (N.WAUI_U_ID)),
                     null,
                     N.WAUI_ACL);
  }
}
;

create trigger WA_USER_INFO_SIOC_ACL_U after update (WAUI_ACL) on DB.DBA.WA_USER_INFO order 100 referencing old as O, new as N
{
  if (coalesce (O.WAUI_ACL, '') <> '')
    wa_user_acl_delete (person_iri (user_iri (O.WAUI_U_ID)), O.WAUI_ACL);

  if (coalesce (N.WAUI_ACL, '') <> '')
    wa_user_acl_insert (person_iri (user_iri (N.WAUI_U_ID)), N.WAUI_ACL);

    SIOC..acl_ping2 (N.WAUI_U_ID,
                     person_iri (user_iri (N.WAUI_U_ID)),
                     null,
                     N.WAUI_ACL);
}
;

create trigger WA_USER_INFO_SIOC_ACL_D before delete on DB.DBA.WA_USER_INFO order 100 referencing old as O
{
  if (coalesce (O.WAUI_ACL, '') <> '')
    wa_user_acl_delete (person_iri (user_iri (O.WAUI_U_ID)), O.WAUI_ACL);
}
;

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
  sioc_user_account (graph_iri, iri, N.WUO_NAME, N.WUO_PUBLIC, N.WUO_URL, N.WUO_URI);
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
  sioc_user_account_delete (graph_iri, iri, O.WUO_NAME, O.WUO_URL, O.WUO_PUBLIC, O.WUO_URI);
  sioc_user_account (graph_iri, iri, N.WUO_NAME, N.WUO_PUBLIC, N.WUO_URL, N.WUO_URI);
};

create trigger WA_USER_OL_ACCOUNTS_SIOC_D after delete on DB.DBA.WA_USER_OL_ACCOUNTS referencing old as O
{
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_account_delete (get_graph (), user_iri (O.WUO_U_ID), O.WUO_NAME, O.WUO_URL, O.WUO_PUBLIC, O.WUO_URI);
};

-- Bioevents
create trigger WA_USER_BIOEVENTS_SIOC_I after insert on DB.DBA.WA_USER_BIOEVENTS referencing new as N
{
  declare graph_iri, user_iri any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  user_iri := user_iri (N.WUB_U_ID);
  sioc_user_bioevent (graph_iri, user_iri, N.WUB_ID, N.WUB_EVENT, N.WUB_DATE, N.WUB_PLACE);
};

create trigger WA_USER_BIOEVENTS_SIOC_U after update on DB.DBA.WA_USER_BIOEVENTS referencing old as O, new as N
{
  declare graph_iri, user_iri any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  user_iri := user_iri (N.WUB_U_ID);
  sioc_user_bioevent (graph_iri, user_iri, N.WUB_ID, N.WUB_EVENT, N.WUB_DATE, N.WUB_PLACE);
};

create trigger WA_USER_BIOEVENTS_SIOC_D after delete on DB.DBA.WA_USER_BIOEVENTS referencing old as O
{
  declare graph_iri, user_iri, person_iri, bio_iri any;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  user_iri := user_iri (O.WUB_U_ID);
  person_iri := person_iri (user_iri, '');
  bio_iri := person_bio_iri (person_iri, cast (O.WUB_ID as varchar));
  delete_quad_s_or_o (graph_iri, bio_iri, bio_iri);
};

-- Offer List
create trigger WA_USER_OFFERLIST_SIOC_I after insert on DB.DBA.WA_USER_OFFERLIST referencing new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_offerlist (N.WUOL_U_ID, N.WUOL_ID, N.WUOL_TYPE, N.WUOL_FLAG, N.WUOL_OFFER, N.WUOL_COMMENT, N.WUOL_PROPERTIES);
};

create trigger WA_USER_OFFERLIST_SIOC_U after update on DB.DBA.WA_USER_OFFERLIST referencing old as O, new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_offerlist_delete (O.WUOL_U_ID, O.WUOL_ID, O.WUOL_TYPE, O.WUOL_FLAG, O.WUOL_OFFER, O.WUOL_COMMENT, O.WUOL_PROPERTIES);
  sioc_user_offerlist (N.WUOL_U_ID, N.WUOL_ID, N.WUOL_TYPE, N.WUOL_FLAG, N.WUOL_OFFER, N.WUOL_COMMENT, N.WUOL_PROPERTIES);
};

create trigger WA_USER_OFFERLIST_SIOC_D after delete on DB.DBA.WA_USER_OFFERLIST referencing old as O
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_offerlist_delete (O.WUOL_U_ID, O.WUOL_ID, O.WUOL_TYPE, O.WUOL_FLAG, O.WUOL_OFFER, O.WUOL_COMMENT, O.WUOL_PROPERTIES);
};

-- Likes
create trigger WA_USER_LIKES_SIOC_I after insert on DB.DBA.WA_USER_LIKES referencing new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_likes (N.WUL_U_ID, N.WUL_ID, N.WUL_FLAG, N.WUL_URI, N.WUL_TYPE, N.WUL_NAME, N.WUL_COMMENT, N.WUL_PROPERTIES);
};

create trigger WA_USER_LIKES_SIOC_U after update on DB.DBA.WA_USER_LIKES referencing old as O, new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_likes_delete (O.WUL_U_ID, O.WUL_ID, O.WUL_FLAG, O.WUL_URI, O.WUL_TYPE, O.WUL_NAME, O.WUL_COMMENT, O.WUL_PROPERTIES);
  sioc_user_likes (N.WUL_U_ID, N.WUL_ID, N.WUL_FLAG, N.WUL_URI, N.WUL_TYPE, N.WUL_NAME, N.WUL_COMMENT, N.WUL_PROPERTIES);
};

create trigger WA_USER_LIKES_SIOC_D after delete on DB.DBA.WA_USER_LIKES referencing old as O
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_likes_delete (O.WUL_U_ID, O.WUL_ID, O.WUL_FLAG, O.WUL_URI, O.WUL_TYPE, O.WUL_NAME, O.WUL_COMMENT, O.WUL_PROPERTIES);
};

-- Knows
create trigger WA_USER_KNOWS_SIOC_I after insert on DB.DBA.WA_USER_KNOWS referencing new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_knows (N.WUK_U_ID, N.WUK_ID, N.WUK_FLAG, N.WUK_URI, N.WUK_LABEL);
};

create trigger WA_USER_KNOWS_SIOC_U after update on DB.DBA.WA_USER_KNOWS referencing old as O, new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_knows_delete (O.WUK_U_ID, O.WUK_ID, O.WUK_FLAG, O.WUK_URI, O.WUK_LABEL);
  sioc_user_knows (N.WUK_U_ID, N.WUK_ID, N.WUK_FLAG, N.WUK_URI, N.WUK_LABEL);
};

create trigger WA_USER_KNOWS_SIOC_D after delete on DB.DBA.WA_USER_KNOWS referencing old as O
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_knows_delete (O.WUK_U_ID, O.WUK_ID, O.WUK_FLAG, O.WUK_URI, O.WUK_LABEL);
};

-- Favorite Things
create trigger WA_USER_FAVORITES_SIOC_I after insert on DB.DBA.WA_USER_FAVORITES referencing new as N
{
  declare user_id integer;
  declare user_name, forum_name, graph_iri, forum_iri any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  user_id := N.WUF_U_ID;
  if ((select count (WUF_ID) from DB.DBA.WA_USER_FAVORITES where WUF_U_ID = user_id) = 1)
  {
    graph_iri := get_graph ();
    user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
    forum_name := forum_name (user_name, 'FavoriteThings');
    forum_iri := favorite_forum_iri (forum_name, user_name);
    sioc_forum (graph_iri, graph_iri, forum_iri, forum_name, 'FavoriteThings', null, null, user_name);
  }
  sioc_user_favorite (N.WUF_U_ID, N.WUF_ID, N.WUF_TYPE, N.WUF_LABEL, N.WUF_URI, N.WUF_CLASS, N.WUF_PROPERTIES);
};

create trigger WA_USER_FAVORITES_SIOC_U after update on DB.DBA.WA_USER_FAVORITES referencing old as O, new as N
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_favorite_delete (O.WUF_U_ID, O.WUF_ID, O.WUF_TYPE, O.WUF_LABEL, O.WUF_URI, O.WUF_CLASS, O.WUF_PROPERTIES);
  sioc_user_favorite (N.WUF_U_ID, N.WUF_ID, N.WUF_TYPE, N.WUF_LABEL, N.WUF_URI, N.WUF_CLASS, N.WUF_PROPERTIES);
};

create trigger WA_USER_FAVORITES_SIOC_D after delete on DB.DBA.WA_USER_FAVORITES referencing old as O
{
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  sioc_user_favorite_delete (O.WUF_U_ID, O.WUF_ID, O.WUF_TYPE, O.WUF_LABEL, O.WUF_URI, O.WUF_CLASS, O.WUF_PROPERTIES);
};

-- Related
create trigger WA_USER_RELATED_RES_SIOC_I after insert on DB.DBA.WA_USER_RELATED_RES referencing new as N
{
  declare graph_iri, iri any;
  declare exit handler for sqlstate '*'
  {
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
  delete_quad_s_p_o (graph_iri, person_iri (iri), O.WUR_P_IRI, O.WUR_SEEALSO_IRI);
  --delete_quad_s_or_o (graph_iri, opiri, opiri);
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
  delete_quad_s_p_o (graph_iri, person_iri (iri), O.WUR_P_IRI, O.WUR_SEEALSO_IRI);
  --delete_quad_s_or_o (graph_iri, opiri, opiri);
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


create procedure instance_sioc_check (
  in _WA_IS_PUBLIC integer,
  in _WA_TYPE varchar)
{
  if ((_WA_IS_PUBLIC > 0) or (_WA_TYPE in ('oDrive', 'oMail')))
    return 1;

  return 0;
};

create procedure instance_sioc_data (
  in _WAM_INST varchar,
  in _WAM_APP_TYPE varchar,
  in _WAM_USER integer,
  in _WAM_MEMBER_TYPE integer,
  in _WAM_IS_PUBLIC integer,
  in _WAM_DESCRIPTION varchar := null,
  in _WAM_LICENSE varchar := null)
{
  declare graph_iri, user_iri, role_iri, forum_iri, site_iri, svc_proc_name varchar;
  declare exit handler for sqlstate '*'
{
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (not SIOC..instance_sioc_check (_WAM_IS_PUBLIC, _WAM_APP_TYPE))
    return;

  forum_iri := forum_iri (_WAM_APP_TYPE, _WAM_INST);
  graph_iri := get_graph_new (_WAM_IS_PUBLIC, forum_iri);
  if (_WAM_MEMBER_TYPE = 1)
    {
    if (not _WAM_IS_PUBLIC)
    {
      SIOC..private_init ();
      SIOC..private_graph_add (graph_iri, _WAM_INST);
      if (not SIOC..private_graph_check (graph_iri))
        return;
    }

    site_iri := get_graph ();
    sioc_forum (graph_iri, site_iri, forum_iri, _WAM_INST, _WAM_APP_TYPE, _WAM_DESCRIPTION);
    if (not isnull (_WAM_LICENSE))
      cc_work_lic (graph_iri, forum_iri, _WAM_LICENSE);

      -- add services here
    svc_proc_name := sprintf ('SIOC.DBA.ods_%s_services', DB.DBA.wa_type_to_app (_WAM_APP_TYPE));
    if (__proc_exists (svc_proc_name))
	    call (svc_proc_name) (graph_iri, forum_iri, _WAM_USER, _WAM_INST);
    }
  if (not _WAM_IS_PUBLIC)
  {
    SIOC..private_user_add (graph_iri, _WAM_USER);
    if (not SIOC..private_graph_check (graph_iri))
      return;
  }

  user_iri := user_iri (_WAM_USER);
  role_iri := role_iri_by_name (_WAM_INST, _WAM_USER);

_social:
  if ((user_iri is not null) and (role_iri is not null) and (forum_iri is not null))
  {
    DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), role_iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, role_iri, sioc_iri ('function_of'), user_iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, role_iri, sioc_iri ('has_scope'), forum_iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, sioc_iri ('scope_of'), role_iri);
    if (role_iri like '%#owner')
    {
	    DB.DBA.ODS_QUAD_URI (graph_iri, forum_iri, sioc_iri ('has_owner'), user_iri);
	    DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, sioc_iri ('owner_of'), forum_iri);
	}
    if (_WAM_APP_TYPE = 'Community')
	    DB.DBA.ODS_QUAD_URI (graph_iri, group_iri (forum_iri), foaf_iri ('member'), person_iri (user_iri));

    if (_WAM_APP_TYPE = 'AddressBook')
    {
      _WAM_APP_TYPE := 'SocialNetwork';
      forum_iri := forum_iri ('SocialNetwork', _WAM_INST);
      graph_iri := get_graph_new (_WAM_IS_PUBLIC, forum_iri);
      goto _social;
    }
  }
}
;

create procedure instance_sioc_data_delete (
  in _WAM_INST varchar,
  in _WAM_APP_TYPE varchar,
  in _WAM_USER integer,
  in _WAM_MEMBER_TYPE integer,
  in _WAM_IS_PUBLIC integer)
{
  declare p_name varchar;
  declare user_iri, graph_iri, role_iri, forum_iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (not SIOC..instance_sioc_check (_WAM_IS_PUBLIC, _WAM_APP_TYPE))
    return;

  forum_iri := SIOC..forum_iri (_WAM_APP_TYPE, _WAM_INST);
  graph_iri := SIOC..get_graph_new (_WAM_IS_PUBLIC, forum_iri);
  if (_WAM_MEMBER_TYPE = 1)
    {
    if (not _WAM_IS_PUBLIC)
      SIOC..private_graph_remove (graph_iri, _WAM_INST);

    -- instance drop
    SIOC..delete_quad_s_or_o (graph_iri, forum_iri, forum_iri);
    p_name := sprintf ('SIOC.DBA.clean_ods_%s_sioc', DB.DBA.wa_type_to_app (_WAM_APP_TYPE));
    if (__proc_exists (p_name))
	    call (p_name) (_WAM_INST, _WAM_IS_PUBLIC);

    SIOC..ods_object_services_dettach (graph_iri, forum_iri, 'instance');
    SIOC..ods_object_services_dettach (graph_iri, forum_iri, DB.DBA.wa_type_to_app (_WAM_APP_TYPE));
    }

  if (not _WAM_IS_PUBLIC)
    SIOC..private_user_remove (graph_iri, _WAM_USER);

  user_iri := user_iri (_WAM_USER);
  role_iri := role_iri_by_name (_WAM_INST, _WAM_USER);
  if (user_iri is not null and role_iri is not null)
    delete_quad_s_or_o (graph_iri, role_iri, role_iri);

  if (_WAM_APP_TYPE = 'Community')
    delete_quad_po (graph_iri, foaf_iri ('member'), person_iri (user_iri));
}
;

-- DB.DBA.WA_MEMBER
create trigger WA_MEMBER_SIOC_I after insert on DB.DBA.WA_MEMBER referencing new as N
{
  SIOC..instance_sioc_data (
    N.WAM_INST,
    N.WAM_APP_TYPE,
    N.WAM_USER,
    N.WAM_MEMBER_TYPE,
    N.WAM_IS_PUBLIC);
}
;

create trigger WA_MEMBER_SIOC_D before delete on DB.DBA.WA_MEMBER referencing old as O
{
  SIOC..instance_sioc_data_delete (
    O.WAM_INST,
    O.WAM_APP_TYPE,
    O.WAM_USER,
    O.WAM_MEMBER_TYPE,
    O.WAM_IS_PUBLIC);
}
;

-- DB.DBA.WA_INSTANCE
-- INSERT and delete are DONE IN THE WA_MEMBER WHEN INSERT THE OWNER
create trigger WA_INSTANCE_SIOC_U before update on DB.DBA.WA_INSTANCE referencing old as O, new as N
{
  declare _wam_user integer;
  declare p_name, site_iri, o_graph_iri, n_graph_iri, o_forum_iri, n_forum_iri, n_role_iri, o_role_iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  n_forum_iri := SIOC..forum_iri_n (O.WAI_TYPE_NAME, O.WAI_NAME, N.WAI_NAME);
  n_graph_iri := SIOC..get_graph_new (N.WAI_IS_PUBLIC, n_forum_iri);
  o_forum_iri := SIOC..forum_iri (O.WAI_TYPE_NAME, O.WAI_NAME);
  o_graph_iri := SIOC..get_graph_new (O.WAI_IS_PUBLIC, o_forum_iri);

  -- no SIOC related changes
  if ((n_graph_iri = o_graph_iri) and (n_forum_iri = o_forum_iri))
    return;

  -- delete old
  _wam_user := (select TOP 1 WAM_USER from DB.DBA.WA_MEMBER where WAM_INST = O.WAI_NAME and WAM_MEMBER_TYPE = 1);
  SIOC..instance_sioc_data_delete (
      O.WAI_NAME,
      O.WAI_TYPE_NAME,
      _wam_user,
      1,
      O.WAI_IS_PUBLIC);

  if (not SIOC..instance_sioc_check (N.WAI_IS_PUBLIC, N.WAI_TYPE_NAME))
    return;

  -- create new
  SIOC..instance_sioc_data (
    N.WAI_NAME,
    N.WAI_TYPE_NAME,
    _wam_user,
    1,
    N.WAI_IS_PUBLIC,
    N.WAI_DESCRIPTION,
    N.WAI_LICENSE);

  delete_quad_sp (o_graph_iri, o_forum_iri, sioc_iri ('id'));
  delete_quad_sp (o_graph_iri, o_forum_iri, sioc_iri ('link'));
  DB.DBA.ODS_QUAD_URI_L (n_graph_iri, n_forum_iri, sioc_iri ('id'), N.WAI_NAME);
  DB.DBA.ODS_QUAD_URI (n_graph_iri, n_forum_iri, sioc_iri ('link'), n_forum_iri);
  update_quad_g_s_o (o_graph_iri, n_graph_iri, o_forum_iri, n_forum_iri);

  delete_quad_sp (o_graph_iri, o_forum_iri, cc_iri ('license'));
  cc_work_lic (n_graph_iri, n_forum_iri, N.WAI_LICENSE);

  if (o_graph_iri <> n_graph_iri)
  {
    for select distinct WAM_MEMBER_TYPE as tp from DB.DBA.WA_MEMBER where WAM_INST = O.WAI_NAME and SIOC..instance_sioc_check (WAM_IS_PUBLIC, WAM_APP_TYPE) = 1 do
    {
      declare _role varchar;

      _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = O.WAI_NAME and WMT_ID = tp);
      if (_role is null and tp = 1)
        _role := 'owner';

      n_role_iri := n_forum_iri || '#' || _role;
      o_role_iri := o_forum_iri || '#' || _role;
      update_quad_g_s_o (o_graph_iri, n_graph_iri, o_role_iri, n_role_iri);
    }
    }

  -- update instanse item's data
  p_name := sprintf ('sioc.DBA.clean_ods_%s_sioc', DB.DBA.wa_type_to_app (N.WAI_TYPE_NAME));
  if (__proc_exists (p_name))
    call (p_name) (O.WAI_NAME, O.WAI_IS_PUBLIC);
  p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc', DB.DBA.wa_type_to_app (N.WAI_TYPE_NAME));
  if (__proc_exists (p_name))
    call (p_name) (n_graph_iri, site_iri, N.WAI_NAME);
  p_name := sprintf ('sioc.DBA.fill_ods_%s_sioc2', DB.DBA.wa_type_to_app (N.WAI_TYPE_NAME));
  if (__proc_exists (p_name))
    call (p_name) (N.WAI_NAME, N.WAI_IS_PUBLIC);
}
;

--
-- Private graphs
--
create procedure SIOC..private_graph ()
{
  return 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs';
}
;

create procedure SIOC..private_graph_id ()
{
  return iri_to_id (SIOC..private_graph ());
}
;

create procedure SIOC..private_init ()
{
  declare _disabled any;
  declare exit handler for sqlstate '*' {return 0;};

  -- create private graph group (if not exists)
  DB.DBA.RDF_GRAPH_GROUP_CREATE (SIOC..private_graph (), 1);

  DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('nobody', 0, 1);
  DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('dba', 1023, 1);

  _disabled := (select U_ACCOUNT_DISABLED from DB.DBA.SYS_USERS where U_NAME = 'SPARQL');
  update DB.DBA.SYS_USERS set U_ACCOUNT_DISABLED = 0 where U_NAME = 'SPARQL';
  DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('SPARQL', 1023, 1);
  update DB.DBA.SYS_USERS set U_ACCOUNT_DISABLED = _disabled where U_NAME = 'SPARQL';

  delete
     from DB.DBA.SYS_SPARQL_HOST
    where cast (SH_DEFINES as varchar) = 'define sql:gs-app-callback "ODS"';

  insert into DB.DBA.SYS_SPARQL_HOST (SH_HOST, SH_DEFINES)
    values ('*', 'define sql:gs-app-callback "ODS"');

  return 1;
}
;

create procedure SIOC..private_hasReplication ()
{
  if (repl_this_server () is null)
    return 0;

  return isstring (registry_get ('DB.DBA.RDF_REPL'));
}
;

create procedure DB.DBA.tmp_update ()
{
  if (registry_get ('ods_private_init') = '3')
    return;

  SIOC..private_init ();
  registry_set ('ods_private_init', '3');
}
;

DB.DBA.tmp_update ()
;

--!
-- \brief Make an RDF graph private.
--
-- \param graph_iri The IRI of the graph to make private. The graph will be private afterwards.
-- Without subsequent calls to SIOC..private_user_add nobody can read or write the graph.
--
-- \return \p 1 on success, \p 0 otherwise.
--
-- \sa SIOC..private_graph_remove, SIOC..private_user_add
--/
create procedure SIOC..private_graph_add (
  in graph_iri varchar,
  in instance_name varchar := null)
{
  declare exit handler for sqlstate '*' {return 0;};

  DB.DBA.RDF_GRAPH_GROUP_INS (SIOC..private_graph (), graph_iri);
  if (not isnull (instance_name))
  {
    for (select WAI_ID, WAI_TYPE_NAME from DB.DBA.WA_INSTANCE where WAI_NAME = instance_name) do
      DB.DBA.wa_private_graph_add (graph_iri, DB.DBA.wa_get_app_name (WAI_TYPE_NAME), WAI_ID);
  }
  return 1;
}
;

--!
-- \brief Make an RDF graph public.
--
-- \param The IRI of the graph to make public.
--
-- \sa SIOC..private_graph_remove, SIOC..private_user_add
--/
create procedure SIOC..private_graph_remove (
  in graph_iri varchar,
  in instance_name varchar := null)
{
  declare exit handler for sqlstate '*' {return 0;};

  DB.DBA.RDF_GRAPH_GROUP_DEL (SIOC..private_graph (), graph_iri);
  if (not isnull (instance_name))
  {
    for (select WAI_ID, WAI_TYPE_NAME from DB.DBA.WA_INSTANCE where WAI_NAME = instance_name) do
      DB.DBA.wa_private_graph_remove (graph_iri, DB.DBA.wa_get_app_name (WAI_TYPE_NAME), WAI_ID);
  }
  return 1;
}
;

--!
-- \brief Check if an RDF graph is private or not.
--
-- Private graphs can still be readable or even writable by certain users,
-- depending on the configured rights.
--
-- \param graph_iri The IRI of the graph to check.
--
-- \return \p 1 if the given graph is private, \p 0 otherwise.
--
-- \sa SIOC..private_graph_add, SIOC..private_user_add
--/
create procedure SIOC..private_graph_check (
  in graph_iri varchar)
{
  declare private_graph varchar;
  declare private_graph_id any;

  private_graph := SIOC..private_graph ();
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = private_graph))
    return 0;

  private_graph_id := SIOC..private_graph_id ();
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = private_graph_id and RGGM_MEMBER_IID = iri_to_id (graph_iri)))
    return 0;

  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i8192 and RGU_USER_ID = http_nobody_uid ()))
    return 0;

  return 1;
}
;

--!
-- \brief Grant access to a private RDF graph.
--
-- Grants access to a certain RDF graph. There is no need to call SIOC..private_graph_add before.
-- The given graph is made private automatically.
--
-- \param graph_iri The IRI of the graph to grant access to.
-- \param uid The numerical or string ID of the SQL user to grant access to \p graph_iri.
-- \param rights The rights to grant to \p uid:
-- - \p 1 - Read
-- - \p 2 - Write
-- - \p 3 - Read/Write
--
-- \return \p 1 on success, \p 0 otherwise.
--
-- \sa SIOC..private_graph_add, SIOC..private_user_add
--/
create procedure SIOC..private_user_add (
  in graph_iri varchar,
  in uid any,
  in rights integer := 1023)
{
  declare exit handler for sqlstate '*' {return 0;};

  if (isinteger (uid))
    uid := (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid);
  DB.DBA.RDF_GRAPH_GROUP_INS (SIOC..private_graph (), graph_iri);
  DB.DBA.RDF_GRAPH_USER_PERMS_SET (graph_iri, uid, rights);
  return 1;
}
;

--!
-- \brief Revoke access to a private RDF graph.
--
-- \param graph_iri The IRI of the private graph to revoke access to,
-- \param uid The numerical or string ID of the SQL user to revoke access from.
--
-- \sa SIOC..private_user_add
--/
create procedure SIOC..private_user_remove (
  in graph_iri varchar,
  in uid any)
{
  declare exit handler for sqlstate '*' {return 0;};

  if (isinteger (uid))
    uid := (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid);

  DB.DBA.RDF_GRAPH_USER_PERMS_DEL (graph_iri, uid);
  return 1;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.SPARQL_GS_APP_CALLBACK_ODS (
  in g_iid IRI_ID,
  in app_uid varchar := null) returns integer
{
  -- dbg_obj_princ ('DB.DBA.SPARQL_GS_APP_CALLBACK_ODS (', id_to_iri (g_iid), ')');
  declare _user varchar;
  declare rc any;
  declare _graph, _type, _id, _id2 any;
  declare exit handler for sqlstate '*' goto _exit;
  declare exit handler for NOT FOUND goto _exit;

  _user := get_user ();
  if (_user <> 'SPARQL')
    return 255;

  _graph := id_to_iri (g_iid);
  if (_graph not like get_graph () || '/%')
    return 255;
  select WAPG_TYPE, WAPG_ID, WAPG_ID2
    into _type, _id, _id2
    from DB.DBA.WA_PRIVATE_GRAPHS
   where WAPG_GRAPH = _graph;

  if (_type = 'WebDAV')
    {
    declare _dav_id any;

    _dav_id := DB.DBA.DAV_SEARCH_ID (_id, _id2);
    if (DB.DBA.DAV_HIDE_ERROR (_dav_id) is null)
      return 0;

    rc := DB.DBA.DAV_AUTHENTICATE (_dav_id, _id2, '1__', app_uid, null, null);
    if (rc > 0)
      return 255;
  }
  else
{
    declare _user_id any;

    _user_id := (select U_ID from DB.DBA.SYS_USERS where U_ACCOUNT_DISABLED = 0 and U_NAME = app_uid);
    if (_type = 'Mail')
  {
      rc := MAIL.WA.access_rights (_id, _user_id);
      if (not isnull (rc))
    {
        if (rc = 'R')
          return 1;

        if (rc = 'W')
          return 3;
    }
    }
  }

_exit:;
  return 0;
}
;

grant execute on DB.DBA.SPARQL_GS_APP_CALLBACK_ODS to public;

--
-- ACL
--
create procedure SIOC..acl_clean_iri (
  inout iri varchar)
{
  declare clean_iri varchar;
  declare N any;

  clean_iri := iri;
  N := strchr (clean_iri, '#');
	if (N >= 0)
    clean_iri := subseq (clean_iri, 0, N);

  return clean_iri;
}
;

create procedure SIOC..acl_groups_graph (
  in user_id integer)
{
  return sprintf ('http://%s/dataspace/private/%U', get_cname (), (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id));
}
;

create procedure SIOC..acl_group_iri (
  in user_id integer,
  in group_name varchar)
  {
  return sprintf ('http://%s/dataspace/%U/group/%U', get_cname (), (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id), group_name);
}
;

create procedure SIOC..acl_graph (
  in iType varchar,
  in iName varchar)
{
  return SIOC..forum_iri (DB.DBA.wa_type_to_app (iType), iName) || '/webaccess';
}
;

create procedure SIOC..acl_insert (
  inout graph_iri varchar,
  inout iri varchar,
  inout acl any)
{
  -- dbg_obj_princ ('SIOC..acl_insert (', graph_iri, iri, ')');
  declare acl_iri, clean_iri, filter_iri, criteria_iri varchar;
  declare N, M, aclArray any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  clean_iri := SIOC..acl_clean_iri (iri);
  aclArray := deserialize (acl);
  for (N := 0; N < length (aclArray); N := N + 1)
  {
    acl_iri := clean_iri || sprintf('#acl_%d', N);

    DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, rdf_iri ('type'), acl_iri ('Authorization'));
    DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('accessTo'), iri);
    if (aclArray[N][2] = 'person')
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('agent'), aclArray[N][1]);
    }
    else if (aclArray[N][2] = 'group')
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('agentClass'), aclArray[N][1]);
    }
    else if (aclArray[N][2] = 'public')
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('agentClass'), foaf_iri('Agent'));
    }
    else if (aclArray[N][2] = 'advanced')
    {
      filter_iri := clean_iri || sprintf('#filter_%d', N);
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, oplflt_iri ('hasFilter'), filter_iri);
      for (M := 0; M < length (aclArray[N][1]); M := M + 1)
      {
        criteria_iri := clean_iri || sprintf('#criteria_%d_%d', N, M);
        DB.DBA.ODS_QUAD_URI (graph_iri, filter_iri, oplflt_iri ('hasCriteria'), criteria_iri);
        DB.DBA.ODS_QUAD_URI (graph_iri, criteria_iri, oplflt_iri ('operand'), oplflt_iri (aclArray[N][1][M][1]));
        DB.DBA.ODS_QUAD_URI (graph_iri, criteria_iri, oplflt_iri ('condition'), oplflt_iri (aclArray[N][1][M][2]));
        DB.DBA.ODS_QUAD_URI_L (graph_iri, criteria_iri, oplflt_iri ('value'), aclArray[N][1][M][3]);
        if ((length (aclArray[N][1][M]) > 3) and not DB.DBA.is_empty_or_null (aclArray[N][1][M][4]))
          DB.DBA.ODS_QUAD_URI_L (graph_iri, criteria_iri, oplflt_iri ('statement'), aclArray[N][1][M][4]);
      }
    }
    if (aclArray[N][3])
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('mode'), acl_iri('Read'));
    if (aclArray[N][4])
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('mode'), acl_iri('Write'));
    if (aclArray[N][5])
      DB.DBA.ODS_QUAD_URI (graph_iri, acl_iri, acl_iri ('mode'), acl_iri('Control'));
  }
}
;

create procedure SIOC..acl_delete (
  inout graph_iri varchar,
  inout iri varchar,
  inout acl any)
{
  declare acl_iri, clean_iri, filter_iri, criteria_iri varchar;
  declare N, M, aclArray any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  clean_iri := SIOC..acl_clean_iri (iri);
  aclArray := deserialize (acl);
  for (N := 0; N < length (aclArray); N := N + 1)
  {
    acl_iri := clean_iri || sprintf('#acl%d', N);
    delete_quad_s_or_o (graph_iri, acl_iri, acl_iri);
    acl_iri := clean_iri || sprintf('#acl_%d', N);
    delete_quad_s_or_o (graph_iri, acl_iri, acl_iri);
    if (aclArray[N][2] = 'advanced')
    {
      filter_iri := clean_iri || sprintf('#filter_%d', N);
      delete_quad_s_or_o (graph_iri, filter_iri, filter_iri);
      for (M := 0; M < length (aclArray[N][1]); M := M + 1)
      {
        criteria_iri := clean_iri || sprintf('#criteria_%d_%d', N, M);
        delete_quad_s_or_o (graph_iri, criteria_iri, criteria_iri);
      }
    }
  }
}
;

create procedure SIOC..acl_webid (
  inout webid varchar,
  inout graph varchar := null)
{
  declare cert, vtype any;

  if (not is_https_ctx ())
    return null;

  webid := connection_get ('vspx_vebid');
  if (not isnull (webid))
  {
    if (webid = '')
      webid := null;
    goto _exit;
  }

  set_user_id ('dba');
  cert := client_attr ('client_certificate');
  if (not DB.DBA.WEBID_AUTH_GEN_2 (cert, 0, null, 1, 0, webid, graph, 0, vtype))
    webid := null;
  connection_set ('vspx_vebid', coalesce (webid, ''));

_exit:;
  return webid;
}
;

create procedure SIOC..acl_prepare_sql (
  inout _sql varchar,
  inout _sqlParams any,
  in _params any)
{
  declare _name, _value, _pattern, _char varchar;
  declare V any;

  _char := '?';
  if (_sql like 'sparql%')
    _char := '??';

  _pattern := '\\^\\{([a-zA-Z0-9])+\\}\\^';
  while (1)
  {
    V := regexp_parse (_pattern, _sql, 0);
    if (isnull (V))
      goto _exit;

    _name := subseq (_sql, V[0]+2, V[1]-2);
    _value := get_keyword (_name, _params);
    _sqlParams := vector_concat (_sqlParams, vector (_value));
    _sql := regexp_replace (_sql, _pattern, _char);
  }
_exit:;
  return;
}
;

create procedure SIOC..acl_check_internal (
  in webid varchar,
  in webidGraph varchar,
  in acl_graph_iri varchar,
  in acl_groups_iri varchar,
  in acl_iris any)
{
  declare M, I integer;
  declare rc varchar;
  declare _cert, _commands, _command any;
  declare _filterMode, _filterValue, _mode, _filter, _criteria, _operand, _condition, _pattern, _statement, _params any;
  declare _sql, _state, _msg, _sqlParams, _meta, _rows any;

  rc := '';
  foreach (any acl_iri in acl_iris) do
      {
    for ( sparql
          define input:storage ""
          prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          prefix foaf: <http://xmlns.com/foaf/0.1/>
          prefix acl: <http://www.w3.org/ns/auth/acl#>
          select ?p1 ?p2 ?p3 ?mode
           where {
                   {
                     graph `iri(?:acl_graph_iri)`
                     {
                       ?rule rdf:type acl:Authorization ;
                             acl:accessTo `iri(?:acl_iri)` ;
                             acl:agent `iri(?:webid)` ;
                             acl:agent ?p1 .
                       OPTIONAL {?rule acl:mode ?mode .} .
                     }
                   }
                   union
        {
                     graph `iri(?:acl_graph_iri)`
                     {
                       ?rule rdf:type acl:Authorization ;
                             acl:accessTo `iri(?:acl_iri)` ;
                             acl:agentClass foaf:Agent ;
                             acl:agentClass ?p2 .
                       OPTIONAL {?rule acl:mode ?mode .} .
                     }
                   }
                   union
          {
                     graph `iri(?:acl_graph_iri)`
            {
                       ?rule rdf:type acl:Authorization ;
                             acl:accessTo `iri(?:acl_iri)` ;
                             acl:agentClass ?p3 .
                       OPTIONAL {?rule acl:mode ?mode .} .
                     }
                     graph `iri(?:acl_groups_iri)`
                     {
                       ?p3 rdf:type foaf:Group ;
                           foaf:member `iri(?:webid)` .
                     }
            }
          }
           order by ?p3 ?p2 ?p1 DESC(?mode)) do
    {
      if      (not isnull ("p1"))
        I := 0;
      else if (not isnull ("p2"))
        I := 1;
      else if (not isnull ("p3"))
        I := 2;
      else
        goto _skip;

      if ("mode" like '%#Write')
      {
        rc := 'W';
        goto _exit;
      }
      if ("mode" like '%#Read')
        rc := 'R';

    _skip:;
    }

    _cert := client_attr ('client_certificate');
    _commands := ODS.ODS_API.commands ();
    _filterMode := '';
    _filterValue := 1;
    _filter := '';
    _criteria := '';
    for (
      sparql
          define input:storage ""
          prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          prefix foaf: <http://xmlns.com/foaf/0.1/>
          prefix acl: <http://www.w3.org/ns/auth/acl#>
      prefix flt: <http://www.openlinksw.com/schemas/acl/filter#>
      select ?filter ?criteria ?mode ?operand ?condition ?pattern ?statement
           where {
               {
                   graph `iri(?:acl_graph_iri)`
                   {
                     ?rule rdf:type acl:Authorization ;
                           acl:accessTo `iri(?:acl_iri)` ;
                         acl:mode ?mode ;
                         flt:hasFilter ?filter .
                         ?filter flt:hasCriteria ?criteria .
                         ?criteria flt:operand ?operand ;
                                   flt:condition ?condition ;
                                   flt:value ?pattern .
                         OPTIONAL { ?criteria flt:statement ?statement . }
                   }
                 }
             }
       order by ?filter ?criteria) do
    {
      _mode := "mode";
      _operand := replace ("operand", 'http://www.openlinksw.com/schemas/acl/filter#', '');
      _condition := replace ("condition", 'http://www.openlinksw.com/schemas/acl/filter#', '');;
      _pattern := cast ("pattern" as varchar);
      _statement := cast ("statement" as varchar);
      if (_filter <> "filter")
  	  {
        if (_filterValue and (_filter <> ''))
	      {
          if (_filterMode <> '')
            rc := _filterMode;
          if (rc = 'W')
            goto _exit;
        }
        _filterMode := '';
        _filterValue := 1;
        _filter := "filter";
        _criteria := '';
      }
      if (_filterValue and (_criteria <> "criteria"))
      {
        _command := get_keyword (_condition, _commands);
        if (isnull (_command))
          goto _skip2;

        if (_operand <> 'certSparqlTriplet')
           _command := replace (_command, 'bif:', '');

        _sql := 'select case when ' || _command || ' then 1 else 0 end';
        _sqlParams := vector ();
        _params := vector ('pattern', _pattern);
        if      (_operand = 'webIDVerified')
        {
          ODS.ODS_API.set_keyword ('value', _params, '1');
    }
        else if (_operand = 'webID')
                   {
          ODS.ODS_API.set_keyword ('value', _params, webid);
                   }
        else if (_operand = 'certExpiration')
                   {
          declare _from, _to any;

          _from := DB.DBA.X509_STRING_DATE (get_certificate_info (4, _cert));
          _to := DB.DBA.X509_STRING_DATE (get_certificate_info (5, _cert));
          ODS.ODS_API.set_keyword ('value', _params, case when (_to < now () or _from > now ()) then '1' else '0' end);
                   }
        else if (_operand = 'certSerial')
        {
          ODS.ODS_API.set_keyword ('value', _params, get_certificate_info (1, _cert));
                 }
        else if (_operand = 'certMail')
    {
          ODS.ODS_API.set_keyword ('value', _params, get_certificate_info (10, _cert, 0, '', 'emailAddress'));
        }
        else if (_operand = 'certSubject')
  	  {
          ODS.ODS_API.set_keyword ('value', _params, get_certificate_info (2, _cert));
        }
        else if (_operand = 'certIssuer')
        {
          ODS.ODS_API.set_keyword ('value', _params, get_certificate_info (3, _cert));
        }
        else if (_operand = 'certStartDate')
        {
          ODS.ODS_API.set_keyword ('value', _params, DB.DBA.X509_STRING_DATE (get_certificate_info (4, _cert)));
          ODS.ODS_API.set_keyword ('pattern', _params, DB.DBA.DAV_AUTHENTICATE_SSL_DATE (_pattern));
        }
        else if (_operand = 'certEndDate')
        {
          ODS.ODS_API.set_keyword ('value', _params, DB.DBA.X509_STRING_DATE (get_certificate_info (5, _cert)));
          ODS.ODS_API.set_keyword ('pattern', _params, DB.DBA.DAV_AUTHENTICATE_SSL_DATE (_pattern));
        }
        else if (_operand = 'certDigest')
        {
          ODS.ODS_API.set_keyword ('value', _params, _cert);
          _sql := 'select case when ' || sprintf ('(DB.DBA.DAV_AUTHENTICATE_SSL_DIGEST_CHECK (^{value}^, ''%s'', ^{pattern}^) = 1)', _condition) || ' then 1 else 0 end';
        }
        else if (_operand = 'certSparqlTriplet')
        {
          _command := replace (_command, ' <> ', ' != ');
          _command := replace (_command, '^{value}^', 'str (?v)');
          _sql := sprintf (
            'sparql \n' ||
            'prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
            'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> \n' ||
            'prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
            'ASK \n' ||
            'WHERE \n' ||
            '  { \n' ||
            '    <%s> %s ?v. \n' ||
            '    FILTER (%s). \n' ||
            '  }',
            webid,
            _statement,
            _command);
          ODS.ODS_API.set_keyword ('pattern', _params, _pattern);
        }
        else if (_operand = 'certSparqlASK')
        {
          ODS.ODS_API.set_keyword ('webid', _params, webid);
          ODS.ODS_API.set_keyword ('value', _params, webid);
          ODS.ODS_API.set_keyword ('graph', _params, webidGraph);
          _sql := 'sparql ' || _statement;
        }

        _state := '00000';
        SIOC..acl_prepare_sql (_sql, _sqlParams, _params);
        exec (_sql, _state, _msg, _sqlParams, 0, _meta, _rows);
        if (_state <> '00000')
        {
          _filterValue := 0;
        }
        else if (isvector (_rows) and length (_rows) and isvector (_rows[0]) and length (_rows[0]) and _rows[0][0] = 0)
        {
          _filterValue := 0;
        }
        else if ((_operand = 'certSparqlTriplet') and isvector (_rows) and (length (_rows) = 0))
        {
          _filterValue := 0;
        }
      }
      if (_filterMode <> 'W')
      {
        if (_mode like '%#Write')
          _filterMode := 'W';
        else if (_mode like '%#Read')
          _filterMode := 'R';
      }

    _skip2:;
      _criteria := "criteria";
    }
    if (_filterValue and (_filter <> '') and (_filterMode <> ''))
      rc := _filterMode;

  _continue:;
  }

_exit:;
  return rc;
}
;

create procedure SIOC..acl_check (
  in acl_graph_iri varchar,
  in acl_groups_iri varchar,
  in acl_iris any)
{
  -- dbg_obj_print ('SIOC..acl_check (', acl_graph_iri, acl_groups_iri, acl_iris, ')');
  declare rc, webid, webidGraph varchar;

  rc := '';
  webidGraph := ODS.ODS_API.graph_create ();
  SIOC..acl_webid (webid, webidGraph);
  if (isnull (webid))
    goto _exit;

  rc := SIOC..acl_check_internal (webid, webidGraph, acl_graph_iri, acl_groups_iri, acl_iris);

_exit:;
  ODS.ODS_API.graph_clear (webidGraph);
  return rc;
}
;

create procedure SIOC..acl_list (
  in acl_graph_iri varchar,
  in acl_groups_iri varchar,
  in acl_iri varchar)
{
  declare rc, webid, webidGraph varchar;
  declare cert, diArray, finger, digest, digestHash any;

  result_names (rc);

  webidGraph := null;
  SIOC..acl_webid (webid, webidGraph);
  if (isnull (webid))
    return;

  cert := client_attr ('client_certificate');
  for ( sparql
        define input:storage ""
        prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        prefix foaf: <http://xmlns.com/foaf/0.1/>
        prefix acl: <http://www.w3.org/ns/auth/acl#>
        select distinct ?iri
         where {
                 {
                   graph `iri(?:acl_graph_iri)`
                   {
                     ?rule rdf:type acl:Authorization ;
                           acl:accessTo ?iri ;
                           acl:agent `iri(?:webid)` .
                     filter (?iri != ?:acl_iri).
                   }
                 }
                 union
                 {
                   graph `iri(?:acl_graph_iri)`
                   {
                     ?rule rdf:type acl:Authorization ;
                           acl:accessTo ?iri ;
                           acl:agentClass foaf:Agent .
                     filter (?iri != ?:acl_iri).
                   }
                 }
                 union
                 {
                   graph `iri(?:acl_graph_iri)`
                   {
                     ?rule rdf:type acl:Authorization ;
                           acl:accessTo ?iri ;
                           acl:agentClass ?group .
                     filter (?iri != ?:acl_iri).
                   }
                   graph `iri(?:acl_groups_iri)`
                   {
                     ?group rdf:type foaf:Group ;
                            foaf:member `iri(?:webid)` .
                   }
                 }
               }
         order by ?iri) do
  {
    result ("iri");
  }
}
;

create procedure SIOC..acl_ping (
  in instance_id integer,
  in iri varchar,
  in oldAcl any,
  in newAcl any)
{
  declare user_id integer;

  user_id := (select WAM_USER
                from DB.DBA.WA_MEMBER,
                     DB.DBA.WA_INSTANCE
               where WAM_MEMBER_TYPE = 1
                 and WAM_INST = WAI_NAME
                 and WAI_ID = instance_id);
  SIOC..acl_ping2 (user_id, iri, oldAcl, newAcl);
}
;

create procedure SIOC..acl_ping2 (
  in user_id integer,
  in iri varchar,
  in oldAcl any,
  in newAcl any)
{
  declare N, M integer;
  declare graph, newAclArray, oldAclArray any;

  if (not DB.DBA.WA_USER_SPB_ENABLE (user_id))
    return;

  if (isnull (newAclArray))
    return;

  graph := SIOC..get_graph ();
  newAclArray := deserialize (newAcl);
  oldAclArray := deserialize (oldAcl);
  for (N := 0; N < length (newAclArray); N := N + 1)
  {
    if (newAclArray[N][2] = 'person')
    {
      if (not isnull (oldAclArray))
      {
        for (M := 0; M < length (oldAclArray); M := M + 1)
        {
          if ((oldAclArray[M][2] = 'person') and (oldAclArray[M][1] = newAclArray[N][1]))
          {
            goto _skip;
          }
        }
      }
      if (newAclArray[N][1] not like graph || '%')
        SEMPING.DBA.CLI_PING (iri, newAclArray[N][1]);
    }
  _skip:;
  }
}
;

create procedure SIOC..wa_instance_acl_insert (
  inout is_public integer,
  inout type_name varchar,
  inout name varchar,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..forum_iri (DB.DBA.wa_type_to_app (type_name), name);
  graph_iri := SIOC..acl_graph (type_name, name);

  SIOC..acl_insert (graph_iri, iri, acl);
}
;

create procedure SIOC..wa_instance_acl_delete (
  inout is_public integer,
  inout type_name varchar,
  inout name varchar,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  iri := SIOC..forum_iri (DB.DBA.wa_type_to_app (type_name), name);
  graph_iri := SIOC..acl_graph (type_name, name);

  SIOC..acl_delete (graph_iri, iri, acl);
}
;

create trigger WA_INSTANCE_ACL_I after insert on DB.DBA.WA_INSTANCE order 100 referencing new as N
{
    SIOC..wa_instance_acl_insert (N.WAI_IS_PUBLIC, N.WAI_TYPE_NAME, N.WAI_NAME, N.WAI_ACL);
}
;

create trigger WA_INSTANCE_ACL_U after update on DB.DBA.WA_INSTANCE order 100 referencing old as O, new as N
{
    SIOC..wa_instance_acl_delete (O.WAI_IS_PUBLIC, O.WAI_TYPE_NAME, O.WAI_NAME, O.WAI_ACL);
    SIOC..wa_instance_acl_insert (N.WAI_IS_PUBLIC, N.WAI_TYPE_NAME, N.WAI_NAME, N.WAI_ACL);
}
;

create trigger WA_INSTANCE_ACL_D before delete on DB.DBA.WA_INSTANCE order 100 referencing old as O
{
    SIOC..wa_instance_acl_delete (O.WAI_IS_PUBLIC, O.WAI_TYPE_NAME, O.WAI_NAME, O.WAI_ACL);
}
;

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
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('member_of'), g_iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, g_iri, sioc_iri ('has_member'), iri);
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
  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
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
  DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, owl_iri ('sameAs'), sas_iri);
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

create trigger WA_USER_CERTS_I after insert on DB.DBA.WA_USER_CERTS referencing new as N
{
  declare crt_iri, graph_iri, person_iri, iri, uname any;

  if (not length (N.UC_CERT))
    return;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (N.UC_U_ID);
  person_iri := person_iri (iri);
  sioc_user_cert (graph_iri, person_iri, N.UC_ID, N.UC_CERT);
  return;
}
;

create trigger WA_USER_CERTS_U after update on DB.DBA.WA_USER_CERTS referencing old as O, new as N
{
  declare crt_iri, graph_iri, person_iri, iri, uname any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (O.UC_U_ID);
  person_iri := person_iri (iri);
  crt_iri := replace (person_iri, '#this', sprintf ('#cert%d', O.UC_ID));
  delete_quad_s (graph_iri, crt_iri);
  sioc_user_cert (graph_iri, person_iri, N.UC_ID, N.UC_CERT);
}
;

create trigger WA_USER_CERTS_D after delete on DB.DBA.WA_USER_CERTS referencing old as O
{
  declare crt_iri, graph_iri, person_iri, iri, uname any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := user_iri (O.UC_U_ID);
  person_iri := person_iri (iri);
  crt_iri := replace (person_iri, '#this', sprintf ('#cert%d', O.UC_ID));
  delete_quad_s (graph_iri, crt_iri);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure waGraph ()
{
  return sprintf ('http://%s/webdav/webaccess', get_cname ());
}
;

-------------------------------------------------------------------------------
--
create procedure waGroup (
  in id integer,
  in name varchar)
{
  return sprintf ('%s/%s#%U', waGraph (), (select U_NAME from DB.DBA.SYS_USERS where U_ID = id), name);
}
;

-------------------------------------------------------------------------------
--
create procedure wa_groups_acl_insert (
  inout id integer,
  inout name varchar,
  inout webIDs any)
{
  declare N integer;
  declare graph_iri, group_iri varchar;
  declare tmp any;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := SIOC..acl_groups_graph (id);
  group_iri := SIOC..acl_group_iri (id, name);
  DB.DBA.ODS_QUAD_URI (graph_iri, group_iri, rdf_iri ('type'), foaf_iri ('Group'));
  tmp := split_and_decode (webIDs, 0, '\0\0\n');
  for (N := 0; N < length (tmp); N := N + 1)
  {
    if (length (tmp[N]))
      DB.DBA.ODS_QUAD_URI (graph_iri, group_iri, foaf_iri ('member'), tmp[N]);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure wa_groups_acl_delete (
  inout id integer,
  inout name varchar)
{
  declare graph_iri, group_iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := SIOC..acl_groups_graph (id);
  group_iri := SIOC..acl_group_iri (id, name);
  delete_quad_s_or_o (graph_iri, group_iri, group_iri);
}
;

-------------------------------------------------------------------------------
--
create trigger WA_GROUPS_ACL_SIOC_I after insert on DB.DBA.WA_GROUPS_ACL referencing new as N
{
  wa_groups_acl_insert (N.WACL_USER_ID,
                        N.WACL_NAME,
                        N.WACL_WEBIDS);
}
;

-------------------------------------------------------------------------------
--
create trigger WA_GROUPS_ACL_SIOC_U after update on DB.DBA.WA_GROUPS_ACL referencing old as O, new as N
{
  wa_groups_acl_delete (O.WACL_USER_ID,
                        O.WACL_NAME);
  wa_groups_acl_insert (N.WACL_USER_ID,
                        N.WACL_NAME,
                        N.WACL_WEBIDS);
}
;

-------------------------------------------------------------------------------
--
create trigger WA_GROUPS_ACL_SIOC_D before delete on DB.DBA.WA_GROUPS_ACL referencing old as O
{
  wa_groups_acl_delete (O.WACL_USER_ID,
                        O.WACL_NAME);
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
  qr := sprintf ('SPARQL define input:storage ""  DESCRIBE <%s> FROM <%s>', iri, fix_graph (get_graph ()));
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
  http ('<http://rdfs.org/sioc/types#WishList> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#OfferList> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#OwnsList> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#Likes> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
  http ('<http://rdfs.org/sioc/types#DisLikes> rdfs:subClassOf <http://rdfs.org/sioc/ns#Container> .\n', ses);
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

-- define common foaf+ssl NS
DB.DBA.XML_SET_NS_DECL ('rsa', 'http://www.w3.org/ns/auth/rsa#', 2);
DB.DBA.XML_SET_NS_DECL ('cert', 'http://www.w3.org/ns/auth/cert#', 2);

create procedure std_pref_declare ()
{
  return
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
   ' prefix pingback: <http://purl.org/net/pingback/> \n' ||
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
         ' prefix bio: <http://vocab.org/bio/0.1/> \n' ||
	 ' prefix cert: <' || cert_iri ('') || '> \n' ||
	 ' prefix rsa: <' || rsa_iri ('') || '> \n' ||
	 ' prefix gr: <' || offer_iri ('') || '> \n' ||
	 ' prefix svc: <http://rdfs.org/sioc/services#> \n'
	 ;
};

create procedure foaf_check_friend (in iri varchar, in agent varchar)
{
  declare hf, stat, msg, meta, data, graph any;

  hf := rfc1808_parse_uri (iri);
  if (registry_get ('URIQADynamicLocal') = '1')
    {
      graph := 'local:/dataspace';
  hf[0] := 'local';
  hf[1] := '';
    }
  else
    graph := get_graph ();
  iri := DB.DBA.vspx_uri_compose (hf);

  agent := fix_uri (agent);
  if (iri = agent) -- everybody has access to his own protected foaf
    return 1;
  stat := '00000';
  msg := 'OK';
  exec (
  	sprintf ('sparql define input:storage ""  prefix foaf: <http://xmlns.com/foaf/0.1/> ask from <%s> where { <%S> foaf:knows <%S> }',
	  graph, iri, agent), stat, msg, vector (), 0, meta, data);
  if (stat = '00000' and length (data) and length (data[0]) and data[0][0] = 1)
    return 1;
  return 0;
}
;

create procedure foaf_check_ssl (
  in iri varchar)
    {
  declare webid varchar;
  return foaf_check_ssl_2(iri, webid);
}
;

/**
The only reason to introduce this function was to expose the webid out parameter
without needing to change any calls to foaf_check_ssl.
*/
create procedure foaf_check_ssl_2 (
  in iri varchar,
  out webid varchar)
{
  declare arr, groups_iri, msg, webidGraph varchar;

  set_user_id ('dba');
  if (iri is not null)
  {
  -- ACL check
  arr := sprintf_inverse (iri, 'http://%s/dataspace/person/%s#this', 1);
  if (length (arr) <> 2)
    return 0;

  groups_iri := sprintf ('http://%s/dataspace/private/%s', arr[0], arr[1]);
  if (SIOC..acl_check (SIOC..acl_clean_iri (iri) || '/webaccess', groups_iri, vector (iri)) = '')
    return 0;
  }
  webidGraph := null;
  SIOC..acl_webid (webid, webidGraph);
  commit work;
  if (isnull (webid))
    return 0;
  return 1;
}
;


create procedure compose_foaf (in u_name varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare state, decl, qry, qrs, msg, maxrows, metas, rset, graph, iri, accept, part any;
  declare ses, dociri, hf any;
  declare triples any;
  declare ss, sa_dict, lim, offs any;
  declare pers_iri, http_hdr, iri_pref varchar;

  set http_charset='utf-8';
  if (registry_get ('URIQADynamicLocal') = '1')
  graph := 'local:/dataspace'; 
  else
    graph := get_graph ();
  iri_pref := graph; --get_graph ();
  ses := string_output ();

  if (fmt = 'text/rdf+n3' or fmt = 'text/n3')
    fmt := 'n3';
  else if (fmt = 'application/rdf+xml')
    fmt := 'rdf';
  else if (fmt = 'text/plain')  
    fmt := 'text';
  else if (fmt = 'application/json')  
    fmt := 'json';

  dociri := person_iri (user_obj_iri(u_name), '');

  hf := rfc1808_parse_uri (dociri);
  hf[0] := 'local';
  hf[1] := '';
  dociri := DB.DBA.vspx_uri_compose (hf);

  pers_iri := person_iri (user_obj_iri(u_name));

  if (fmt not in ('n3', 'ttl', 'rdf', 'text', 'json'))
    fmt := 'rdf';

  if (fmt = 'n3' or fmt = 'ttl' or fmt = 'nt')
    accept := 'text/rdf+n3';
  else if (fmt = 'text') 
    accept := 'text/plain';
  else if (fmt = 'json') 
    accept := 'application/json';
  else
    accept := 'application/rdf+xml';

  lim := coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
  offs := coalesce (p, 0) * lim;

  http_hdr := http_header_get ();
  if (strcasestr (http_hdr, 'Content-Type:') is null)
    http_header (http_hdr || sprintf ('Content-Type: %s; charset=UTF-8\r\n', accept));
  if (strcasestr (http_hdr, 'Expires:') is null)
    http_header (http_hdr || sprintf ('Expires: %s\r\n', DB.DBA.date_rfc1123 (dateadd ('second', 10, now ()))));

  if (fmt = 'rdf')
    rdf_head (ses);

  iri := user_obj_iri (u_name);

  decl := 'sparql define input:storage "" define sql:signal-void-variables 1 '
         --' define input:inference <' || graph || '>' ||
	  || std_pref_declare ();

  qrs := make_array (8, 'any');
  qrs[6] := null;
  qrs[7] := null;
  if (is_https_ctx () and foaf_check_ssl (pers_iri))
    {
      qrs[6] := sprintf ('sparql define input:storage ""  construct { ?s ?p ?o } from <%s/protected/%U> where { ?s ?p ?o }', graph, u_name);
    }

  part := sprintf (
	  ' CONSTRUCT {
	    ?person a ?type .
	    ?person foaf:nick ?nick .
	    ?person foaf:mbox ?mbox .
	    ?person foaf:mbox_sha1sum ?sha1 .
	    ?person foaf:name ?full_name .
	    ?person foaf:account ?sioc_user .
	    ?person rdfs:seeAlso ?pers_see_also .
	    ?sioc_user rdfs:seeAlso ?see_also .
	    ?sioc_user a sioc:User .
	    ?person foaf:firstName ?fn .
	    ?person foaf:family_name ?ln .
	    ?person foaf:title ?title .
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
	    <%s> dc:title `bif:concat (bif:coalesce (?full_name, ?nick), "\'s FOAF file")` .
	    ?person foaf:workplaceHomepage ?wphome .
	    ?org foaf:homepage ?wphome .
	    ?org rdf:type foaf:Organization .
	    ?org dc:title ?orgtit .
	    ?person foaf:depiction ?depiction .
	    ?person foaf:homepage ?homepage .
	    ?person svc:has_services ?svc .
	    ?svc svc:services_of ?person .
	    ?svc rdf:type svc:Services .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
	      ?person foaf:account <%s/%s#this> ;
	      rdf:type ?type ;
	      foaf:nick ?nick ;
	      foaf:account ?sioc_user .
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
	      optional { ?person foaf:title ?title } .
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
        optional { ?person svc:has_services ?svc } .
	      }
	    }
	  }',
	  dociri, dociri, dociri, dociri,
	  graph, iri_pref, u_name);

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
	    ?adr vcard:Pobox ?pobox .
	    ?adr vcard:Street ?street .
	    ?adr vcard:Extadd ?extadd .
	    ?person bio:olb ?bio .
	    ?person bio:event ?event .
	    ?event rdf:type bio:Birth .
	    ?event dc:date ?bdate .
	    ?person bio:keywords ?keywords .
	    ?person owl:sameAs ?same_as .
	    ?person foaf:account ?oa .
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
  	      ?person foaf:account <%s/%s#this> ;
	      foaf:openid ?oid .
	      optional { ?person bio:olb ?bio  } .
              optional { ?person bio:event ?event . ?event a bio:Birth ; dc:date ?bdate } .
  	      optional { ?person vcard:ADR ?adr .
  	                 optional { ?adr vcard:Country ?country } .
	        	optional { ?adr vcard:Locality ?city } .
			optional { ?adr vcard:Region ?state } .
              			 optional { ?adr vcard:Pobox ?pobox } .
              			 optional { ?adr vcard:Street ?street } .
              			 optional { ?adr vcard:Extadd ?extadd } .
	      	       } .
              optional { ?person bio:keywords ?keywords } .
	      optional { ?person owl:sameAs ?same_as } .
  	      ?person foaf:account ?oa .
	      optional {
		         ?oa foaf:accountServiceHomepage ?ashp ; foaf:accountName ?an
	      	       } .
              #optional { ?person foaf:made ?made . ?made dc:identifier ?ident . ?made dc:title ?made_title . optional { ?made a ?made_type . } } .
	      '
	      || vars ||
	      '
	      }
	    }
	  }', graph, iri_pref, u_name);

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
	    ?person cert:key ?key .
	    ?key rdf:type cert:RSAPublicKey .
	    ?key cert:exponent ?exp .
	    ?key cert:modulus ?mod .
	    ?event_iri rdf:type ?bioEvent .
	    ?event_iri bio:date ?bioDate .
	    ?event_iri bio:place ?bioPlace .
	    ?person pingback:to ?pb .
	    ?person pingback:service ?psvc .
	    ?person foaf:made `iri (bif:sprintf (''http://%%{WSHost}s/ods/describe?uri=%%U'', ?mbox))` .
	    ?person <http://vocab.deri.ie/void#inDataset> <http://%{URIQADefaultHost}s/dataspace> .
	    <http://%{URIQADefaultHost}s/dataspace> <http://rdfs.org/ns/void#sparqlEndpoint> <http://%{URIQADefaultHost}s/sparql-auth/> .
	  }
	  WHERE
	  {
	    graph <%s>
	    {
	      {
	        ?person foaf:account <%s/%s#this> .
		optional { ?person foaf:mbox ?mbox . } .  
	      optional { ?person foaf:made ?made . ?made dc:identifier ?ident . ?made dc:title ?made_title . optional { ?made a ?made_type . } } .
	      optional { ?person foaf:interest ?interest } .
	      optional { ?interest rdfs:label ?interest_label  } .
	      optional { ?person foaf:topic_interest ?topic_interest } .
	      optional { ?topic_interest rdfs:label ?topic_interest_label  } .
	        optional { ?person cert:key ?key . ?key cert:exponent ?exp ; cert:modulus ?mod . } .
	      optional { ?person bio:event ?event_iri . ?event_iri rdf:type ?bioEvent . ?event_iri bio:date ?bioDate . ?event_iri bio:place ?bioPlace } .
		optional { ?person pingback:to ?pb } .
		optional { ?person pingback:service ?psvc } .
	      }
	    }
	  }', graph, iri_pref, u_name);

  qry := decl || part;
  qrs [5] := qry;
  if (p <> 0)
    qrs [5] := null;

  part := sprintf (
	' CONSTRUCT {
	    ?person foaf:made ?container .
	    ?container foaf:maker ?person .
	    ?container rdfs:label ?label .
      ?container sioc:container_of ?grSubject.
      ?grSubject ?grProperty ?grObject.
	  }
	  WHERE
	  {
	    graph <%s>
	    {
        ?person foaf:account <%s/%s#this> .
        {
          {
            ?container foaf:maker ?person;
              a sioct:OfferList;
              rdfs:label ?label.
            OPTIONAL {?container sioc:container_of ?grSubject.
                      ?grSubject ?grProperty ?grObject.
                     }.
	      }
        union  
        {
            ?container foaf:maker ?person;
              a sioct:WishList;
              rdfs:label ?label.
            OPTIONAL {?container sioc:container_of ?grSubject.
                      ?grSubject ?grProperty ?grObject.
                     }.
	    }
        union  
        {
            ?container foaf:maker ?person;
              a sioct:OwnsList ;
              rdfs:label ?label .
            OPTIONAL { ?container sioc:container_of ?grSubject.
                       ?grSubject ?grProperty ?grObject.
                     } .
          }
          union
          {
            ?container foaf:maker ?person ;
              a sioct:Likes ;
              rdfs:label ?label .
            OPTIONAL { ?container sioc:container_of ?grSubject.
                       ?grSubject ?grProperty ?grObject.
                     } .
          }
          union
          {
            ?container foaf:maker ?person ;
              a sioct:DisLikes ;
              rdfs:label ?label .
            OPTIONAL { ?container sioc:container_of ?grSubject.
                       ?grSubject ?grProperty ?grObject.
                     } .
          }
          union
          {
            ?container foaf:maker ?person ;
              a sioct:FavoriteThings .
            OPTIONAL {?container sioc:container_of ?grSubject.
                      ?grSubject ?grProperty ?grObject.
                     }.
  	      }
	      }
	    }
	  }', graph, iri_pref, u_name);

  qry := decl || part;
  qrs [7] := qry;
  if (p <> 0)
    qrs [7] := null;

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

execute_qr:

  set_user_id ('dba');
  foreach (any q in qrs) do
    {
      maxrows := 0;
      state := '00000';
      msg := 'OK';
      if (q is not null)
	{
--	  dbg_printf ('%s', q);
    	  exec (q, state, msg, vector(), vector ('max_rows', maxrows, 'use_cache', 1), metas, rset);
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
	      if ((1 = length (rset)) and (1 = length (rset[0])) and (214 = __tag (rset[0][0])) and dict_size (rset[0][0]))
		{
	      DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 0);
		  http ('\n', ses);
		}
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
	{
	DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	  http ('\r\n', ses);
	}
    }

  if (fmt = 'rdf')
    rdf_tail (ses);
  return ses;
}
;

-- XXX: obsolete : see ods_obj_describe
create procedure ods_sioc_obj_describe (in u_name varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare iri, graph, ses any;
  declare qrs, stat, msg, accept, pref any;
  declare rset, metas any;
  declare maybe_more any;

--  dbg_obj_print (u_name, fmt);
  set http_charset='utf-8';
  if (fmt = 'text/rdf+n3' or fmt = 'text/n3')
    fmt := 'n3';
  else if (fmt = 'application/rdf+xml')
    fmt := 'rdf';
  if (fmt not in ('n3', 'ttl', 'rdf'))
    fmt := 'rdf';

  if (fmt = 'n3' or fmt = 'ttl')
    accept := 'text/rdf+n3';
  else
    accept := 'application/rdf+xml';
  graph := fix_graph (get_graph ());
  ses := string_output ();
  iri := fix_uri (user_obj_iri (u_name));
  qrs := vector (0,0);
  pref := 'sparql prefix sioc: <http://rdfs.org/sioc/ns#> prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ';
  qrs[0] := sprintf ('CONSTRUCT { <%s> ?p ?o . ?o a ?t . ?o rdfs:label ?l . ?o rdfs:seeAlso ?sa . } '||
	  ' FROM <%s> WHERE { <%s> ?p ?o . optional { ?o a ?t } . optional { ?o rdfs:label ?l } . optional { ?o rdfs:seeAlso ?sa } '||
	  ' filter (?p != sioc:creator_of) }', iri, graph, iri);
  qrs[1] := sprintf ('CONSTRUCT { ?s ?p <%s> . ?s a ?t . ?s rdfs:label ?l . ?s rdfs:seeAlso ?sa . } '||
	  ' FROM <%s> WHERE { ?s ?p <%s> . optional { ?s a ?t } . optional { ?s rdfs:label ?l } . optional { ?s rdfs:seeAlso ?sa } '||
	  ' filter (?p != sioc:has_creator) }', iri, graph, iri);

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

-- XXX: obsolete : see ods_obj_describe
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
	{
	DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	  http ('\n', ses);
    }
    }
};


-- XXX: obsolete : see ods_obj_describe
create procedure ods_sioc_container_obj_describe (in iri varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare graph, ses any;
  declare qrs, stat, msg, accept, pref any;
  declare rset, metas any;
  declare triples any;
  declare lim, offs, maybe_more int;

  set http_charset='utf-8';
  maybe_more := 1;
  if (fmt = 'text/rdf+n3' or fmt = 'text/n3')
    fmt := 'n3';
  else if (fmt = 'application/rdf+xml')
    fmt := 'rdf';
  if (fmt not in ('n3', 'ttl', 'rdf'))
    fmt := 'rdf';

  if (fmt = 'n3' or fmt = 'ttl')
    accept := 'text/rdf+n3';
  else
    accept := 'application/rdf+xml';
  graph := fix_graph (get_graph ());
  iri := fix_uri (iri);
  ses := string_output ();
  lim := 20;--coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
  offs := coalesce (p, 0) * lim;
  qrs := vector (0,0,0);
  pref := 'sparql prefix sioc: <http://rdfs.org/sioc/ns#> prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> prefix dct: <http://purl.org/dc/terms/> prefix atom: <http://atomowl.org/ontologies/atomrdf#> ';
  if (offs = 0)
    {
      qrs[0] := sprintf ('CONSTRUCT { <%s> ?p ?o . } '||
      ' FROM <%s> WHERE { <%s> ?p ?o . filter (?p != sioc:container_of && ?p != atom:entry && ?p != atom:contains) }',
      iri, graph, iri);
      qrs[1] := sprintf ('CONSTRUCT { ?s ?p <%s> . } '||
      ' FROM <%s> WHERE { ?s ?p <%s> . filter (?p != sioc:has_container && ?p != atom:source ) }',
      iri, graph, iri);
    }
  qrs[2] := sprintf (
    'CONSTRUCT { <%s> sioc:container_of ?o . ?o sioc:has_container <%s> . ?o a ?t . ?o rdfs:label ?l . ?o rdfs:seeAlso ?sa . } '||
    ' FROM <%s> WHERE { <%s> sioc:container_of ?o . optional { ?o a ?t } . optional { ?o rdfs:label ?l } . '||
    ' optional { ?o rdfs:seeAlso ?sa } . optional { ?o dct:created ?cr } } order by desc (?cr) LIMIT %d OFFSET %d',
    iri, iri, graph, iri, lim, offs);

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
  if (p > 0)
    {
      declare ss, sa_dict any;
      ss := string_output ();
      rdf_head (ss);
      http (sprintf ('<rdf:Description rdf:about="%s/page/%d">', iri, coalesce (p, 0)), ss);
      http (sprintf ('<foaf:primaryTopic xmlns:foaf="http://xmlns.com/foaf/0.1/" rdf:resource="%s" />', iri), ss);
      http ('</rdf:Description>', ss);
      rdf_tail (ss);
      ss := string_output_string (ss);
      sa_dict := DB.DBA.RDF_RDFXML_TO_DICT (ss, iri, graph);
      triples := dict_list_keys (sa_dict, 1);
      if (fmt = 'rdf')
	DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
      else
	{
	  DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	  http ('\n', ses);
	}

    }
  if (maybe_more)
    {
      declare ss, sa_dict any;
      ss := string_output ();
      rdf_head (ss);
      http (sprintf ('<rdf:Description rdf:about="%s">', iri), ss);
      http (sprintf ('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/page/%d" />', iri, coalesce (p, 0) + 1), ss);
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
	{
	DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	  http ('\n', ses);
	}
    }
  if (fmt = 'rdf')
    rdf_tail (ses);
  return ses;
}
;

create procedure ods_dict_merge (inout dict any, inout rset_dict any)
{
  declare triples any;
  triples := dict_list_keys (rset_dict, 1);
  foreach (any tr in triples) do
    {
      dict_put (dict, tr, 0);
    }
}
;

create procedure ods_obj_describe (in iri varchar, in fmt varchar := 'n3', in p int := 0)
{
  declare graph, ses any;
  declare qrs, stat, msg, accept, pref any;
  declare rset, metas any;
  declare triples, path, dict any;
  declare lim, offs, maybe_more int;
  declare ss, sa_dict any;

  path := http_path ();
  dict := dict_new ();
--  dbg_obj_print_vars (iri, fmt, path, http_header_get ());
  set http_charset='utf-8';
  maybe_more := 1;

  if (path like '%.rdf')
    accept := 'application/rdf+xml';
  if (path like '%.nt')
     accept := 'text/n3';
  if (path like '%.n3')
     accept := 'text/rdf+n3';
  if (path like '%.ttl')
     accept := 'text/rdf+ttl';
  if (path like '%.txt')
     accept := 'text/plain';
  if (path like '%.json')
     accept := 'application/json';
  if (path like '%.jmd')
     accept := 'application/microdata+json';
  if (path like '%.jld')
     accept := 'application/x-json+ld';
  if (path like '%.turtle')
     accept := 'text/turtle';


  graph := fix_graph (get_graph ());
  iri := fix_uri (iri);
  ses := string_output ();
  lim := 20;
  offs := coalesce (p, 0) * lim;
  qrs := vector (0,0,0);
  pref := 'sparql prefix sioc: <http://rdfs.org/sioc/ns#> prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> prefix dct: <http://purl.org/dc/terms/> prefix atom: <http://atomowl.org/ontologies/atomrdf#> ';
  if (offs = 0)
    {
      qrs[0] := sprintf ('CONSTRUCT { <%s> ?p ?o . } '||
      ' FROM <%s> WHERE { <%s> ?p ?o . filter (?p != sioc:container_of && ?p != atom:entry && ?p != atom:contains) }',
      iri, graph, iri);
      qrs[1] := sprintf ('CONSTRUCT { ?s ?p <%s> . } '||
      ' FROM <%s> WHERE { ?s ?p <%s> . filter (?p != sioc:has_container && ?p != atom:source ) }',
      iri, graph, iri);
    }
  qrs[2] := sprintf (
    'CONSTRUCT { <%s> sioc:container_of ?o . ?o sioc:has_container <%s> . ?o a ?t . ?o rdfs:label ?l . ?o rdfs:seeAlso ?sa . } '||
    ' FROM <%s> WHERE { <%s> sioc:container_of ?o . optional { ?o a ?t } . optional { ?o rdfs:label ?l } . '||
    ' optional { ?o rdfs:seeAlso ?sa } . optional { ?o dct:created ?cr } } order by desc (?cr) LIMIT %d OFFSET %d',
    iri, iri, graph, iri, lim, offs);

  set_user_id ('dba');

  metas := null;
  foreach (any qr in qrs) do
    {
      if (qr <> 0)
    	{
    	  qr := pref || qr;
        -- dbg_printf ('%s', qr);
    	  stat := '00000';
    	  exec (qr, stat, msg, vector (), 0, metas, rset);
    	  if (stat <> '00000')
    	    signal (stat, msg);
	  ods_dict_merge (dict, rset[0][0]);
    	}
    }
  if (p > 0)
    {
      ss := string_output ();
      rdf_head (ss);
      http (sprintf ('<rdf:Description rdf:about="%s/page/%d">', iri, coalesce (p, 0)), ss);
      http (sprintf ('<foaf:primaryTopic xmlns:foaf="http://xmlns.com/foaf/0.1/" rdf:resource="%s" />', iri), ss);
      http ('</rdf:Description>', ss);
      rdf_tail (ss);
      ss := string_output_string (ss);
      sa_dict := DB.DBA.RDF_RDFXML_TO_DICT (ss, iri, graph);
      ods_dict_merge (dict, sa_dict);
    }
  if (maybe_more)
    {
      ss := string_output ();
      rdf_head (ss);
      http (sprintf ('<rdf:Description rdf:about="%s">', iri), ss);
      http (sprintf ('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/page/%d" />', iri, coalesce (p, 0) + 1), ss);
      http ('</rdf:Description>', ss);
      http (sprintf ('<rdf:Description rdf:about="%s/page/%d">', iri, coalesce (p, 0) + 1), ss);
      http (sprintf ('<rdfs:label>page %d</rdfs:label>', coalesce (p, 0) + 1), ss);
      http ('</rdf:Description>', ss);

      rdf_tail (ss);
      ss := string_output_string (ss);
      sa_dict := DB.DBA.RDF_RDFXML_TO_DICT (ss, iri, graph);
      ods_dict_merge (dict, sa_dict);
    }
  if (metas is not null)
    {
      rset := vector (vector (dict));
      DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);
    }
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
  	     ' CONSTRUCT { ?s ?p ?o . ?f foaf:account ?ha . ?f rdfs:seeAlso ?sa . '||
	     '  ?frm sioc:scope_of ?role. ?role sioc:function_of ?member. ?frm sioc:type ?ft. ?frm sioc:id ?fid . '||
	     '  ?frm rdfs:seeAlso ?fsa . ?frm sioc:has_space ?fh .  ?role sioc:has_scope ?frm . ' ||
	     '  ?frm sioc:has_owner ?member . ?member sioc:owner_of ?frm . } \n' ||
	     ' FROM <%s> WHERE { \n' ||
	     '   { ?s ?p ?o . ?s sioc:id "%s" FILTER (?p != "http://www.w3.org/2000/01/rdf-schema#seeAlso" && ' ||
	     ' 					  ?p != "http://rdfs.org/sioc/ns#creator_of") } union  \n' ||
  	     '   { ?f foaf:nick "%s" ; foaf:account ?ha ; rdfs:seeAlso ?sa  } union  \n' ||
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
  	    ?person foaf:account ?sioc_user .
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
  	    ?adr vcard:Pobox ?pobox .
  	    ?adr vcard:Street ?street .
  	    ?adr vcard:Extadd ?extadd .
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
    	      foaf:account ?sioc_user .
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
    	      optional {
    	        ?person vcard:ADR ?adr .
              optional { ?adr vcard:Country ?country } .
	        	optional { ?adr vcard:Locality ?city } .
			optional { ?adr vcard:Region ?state } .
       			  optional { ?adr vcard:Pobox ?pobox } .
       			  optional { ?adr vcard:Street ?street } .
       			  optional { ?adr vcard:Extadd ?extadd } .
	      	       } .
	      #optional { ?person foaf:interest ?interest } .
	      #optional { ?person bio:keywords ?keywords } .
	      #optional { ?person owl:sameAs ?same_as } .
	      }
	    }
	  }',
  	  u_name, iri, iri, iri, graph, u_name);
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
                     }
                     where
            	{
		  graph <%s>
		  {
		    ?host sioc:space_of ?forum . ?forum sioc:id "%s" .
		    ?host sioc:link ?link . ?host dc:title ?title
		  }
              		   }', graph, wai_name);
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
                 			   ?forum svc:has_services ?svc .
                 			   ?svc svc:services_of ?forum .
                 			   ?svc rdf:type svc:Services .
                 		   }
                 		   where
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
                           optional { ?forum svc:has_services ?svc . }
		  }
                 		   }', wai_name, graph, wai_name);
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
	       } ', graph, md5(iri));
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


-----------------------------------------------------------------------------------------
--
create procedure SIOC..rdf_links_header (in iri any)
{
  declare links, desc_link varchar;

  if (iri is null)
    return;

  desc_link := sprintf ('http://%{WSHost}s/sparql?default-graph-uri=%U&query=%U', SIOC..get_graph (), sprintf ('DESCRIBE <%s>', iri));

  links := 'Link: ' ||
    sprintf ('<%s&output=application%%2Frdf%%2Bxml>; rel="alternate"; type="application/rdf+xml"; title="Structured Descriptor Document (RDF/XML format)",', desc_link);
  links := links ||
    sprintf ('<%s&output=text%%2Fn3>; rel="alternate"; type="text/n3"; title="Structured Descriptor Document (N3/Turtle format)",', desc_link);
  links := links ||
    sprintf ('<%s&output=application%%2Frdf%%2Bjson>; rel="alternate"; type="application/rdf+json"; title="Structured Descriptor Document (RDF/JSON format)",', desc_link);
  links := links ||
    sprintf ('<%s&output=application%%2Fatom%%2Bxml>; rel="alternate"; type="application/atom+xml"; title="Structured Descriptor Document (OData/Atom format)",', desc_link);
  links := links ||
    sprintf ('<%s&output=application%%2Fodata%%2Bjson>; rel="alternate"; type="application/odata+json"; title="Structured Descriptor Document (OData/JSON format)",', desc_link);
  links := links ||
    sprintf ('<%s&output=text%%2Fcxml>; rel="alternate"; type="text/cxml"; title="Structured Descriptor Document (CXML format)",', desc_link);
  links := links ||
    sprintf ('<%s&output=text%%2Fcsv>; rel="alternate"; type="text/csv"; title="Structured Descriptor Document (CSV format)",', desc_link);
  links := links ||
    sprintf ('<%s>; rel="http://xmlns.com/foaf/0.1/primaryTopic",', iri);
  links := links ||
    sprintf ('<%s>; rev="describedby"\r\n', iri);

  http_header (http_header_get () || links);
}
;

-----------------------------------------------------------------------------------------
--
create procedure SIOC..rdf_links_head_internal (in iri any)
{
  declare links, blank, desc_link varchar;

  if (iri is null)
    return '';

  blank := repeat (' ', 4);
  desc_link := sprintf ('http://%{WSHost}s/sparql?default-graph-uri=%U&query=%U', SIOC..get_graph (), sprintf ('DESCRIBE <%s>', iri));

  links := '\n' ||
    blank ||
    sprintf ('<link href="%V&amp;output=application%%2Frdf%%2Bxml" rel="alternate" type="application/rdf+xml" title="Structured Descriptor Document (RDF/XML format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V&amp;output=text%%2Fn3" rel="alternate" type="text/n3" title="Structured Descriptor Document (N3/Turtle format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V&amp;output=application%%2Frdf%%2Bjson" rel="alternate" type="application/rdf+json" title="Structured Descriptor Document (RDF/JSON format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V&amp;output=application%%2Fatom%%2Bxml" rel="alternate" type="application/atom+xml" title="Structured Descriptor Document (OData/Atom format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V&amp;output=application%%2Fatom%%2Bjson" rel="alternate" type="application/atom+json" title="Structured Descriptor Document (OData/JSON format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V&amp;output=text%%2Fcxml" rel="alternate" type="text/cxml" title="Structured Descriptor Document (CXML format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V&amp;output=text%%2Fcsv" rel="alternate" type="text/csv" title="Structured Descriptor Document (CSV format)" />\n', desc_link);
  links := links ||
    blank ||
    sprintf ('<link href="%V" rel="http://xmlns.com/foaf/0.1/primaryTopic" />\n', iri);
  links := links ||
    blank ||
    sprintf ('<link href="%V" rev="describedby" />\n', iri);

  return links;
}
;

-----------------------------------------------------------------------------------------
--
create procedure SIOC..rdf_links_head (in iri any)
{
  if (iri is null)
    return;

  http (SIOC..rdf_links_head_internal(iri));
}
;

create procedure ods_account_update ()
{
  if (registry_get ('ods_account_update') = '1') return;
  update_quad_p (get_graph (), foaf_iri ('holdsAccount'), foaf_iri ('account'));
  registry_set ('ods_account_update', '1');
}
;

ods_account_update ()
;

use DB;

create procedure WA_INTEREST_UPGRADE ()
{
  declare tmp, access, uname, visibility any;

  if (registry_get ('WA_INTEREST_UPGRADE') = 'done')
    return;

  for (select WAUI_U_ID, WAUI_INTERESTS as F1, WAUI_INTEREST_TOPICS as F2 from DB.DBA.WA_USER_INFO) do
  {
  	 uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = WAUI_U_ID);
  	 if (not isnull (uname))
  	 {
       WA_USER_EDIT (uname, 'WAUI_INTERESTS', F2);
       WA_USER_EDIT (uname, 'WAUI_INTEREST_TOPICS', F1);
     }
  }

  registry_set ('WA_INTEREST_UPGRADE', 'done');
}
;
WA_INTEREST_UPGRADE ()
;

create procedure ods_object_services_update ()
{
  if (registry_get ('ods_services_update') = '1') return;
  SIOC..fill_ods_services ();
  registry_set ('ods_services_update', '1');
}
;

ods_object_services_update ()
;

DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/VAD/wa/RDFData/', sioc..get_graph ());

delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'ODS_SIOC_RDF';
delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = sioc.DBA.get_graph ();

