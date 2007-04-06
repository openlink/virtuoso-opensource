--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2007 OpenLink Software
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

-------------------------------------------------------------------------------
--
create procedure addressbook_contact_iri (in domain_id varchar, in contact_id int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
   where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/addressbook/%U/%d', get_cname(), get_base_path (), _member, _inst, contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_addressbook_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare c_iri, creator_iri, r_iri varchar;

  for (select WAI_ID, WAI_NAME, WAM_USER
         from DB.DBA.WA_INSTANCE i,
              DB.DBA.WA_MEMBER m
        where m.WAM_INST = i.WAI_NAME
          and ((m.WAM_IS_PUBLIC = 1 and _wai_name is null) or i.WAI_NAME = _wai_name)) do
  {
    c_iri := polls_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
    r_iri := role_iri (WAI_ID, WAM_USER, 'contact');

    for (select * from AB.WA.PERSONS where P_DOMAIN_ID = WAI_ID) do
      contact_insert (graph_iri,
                      c_iri,
                      creator_iri,
                      r_iri,
                      P_ID,
                    P_DOMAIN_ID,
                    P_NAME,
                    P_FIRST_NAME,
                    P_LAST_NAME,
                    P_GENDER,
                    P_BIRTHDAY,
                    P_ICQ,
                    P_SKYPE,
                    P_AIM,
                    P_YAHOO,
                    P_MSN,
                    P_H_COUNTRY,
                    P_H_STATE,
                    P_H_CITY,
                    P_H_CODE,
                    P_H_ADDRESS1,
                    P_H_ADDRESS1,
                    P_H_LAT,
                    P_H_LNG,
                    P_H_PHONE,
                    P_H_MAIL,
                    P_H_WEB,
                    P_CREATED,
                    P_UPDATED,
                    P_TAGS);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure contact_insert (
  in graph_iri varchar,
  in c_iri varchar,
  in creator_iri varchar,
  in r_iri varchar,
  inout contact_id integer,
  inout domain_id integer,
  inout name varchar,
  inout firstName varchar,
  inout lastName varchar,
  inout gender varchar,
  inout birthday datetime,
  inout icq varchar,
  inout skype varchar,
  inout aim varchar,
  inout yahoo varchar,
  inout msn varchar,
  inout hCountry varchar,
  inout hState varchar,
  inout hCity varchar,
  inout hCode varchar,
  inout hAddress1 varchar,
  inout hAddress2 varchar,
  inout hLat real,
  inout hLng real,
  inout hPhone varchar,
  inout hMail varchar,
  inout hWeb varchar,
  inout created datetime,
  inout updated datetime,
  inout tags varchar)
{
  declare iri, event_iri, geo_iri, address_iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (isnull (graph_iri))
    for (select WAI_ID, WAM_USER, WAI_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER
        where WAI_ID = domain_id
          and WAM_INST = WAI_NAME
          and WAI_IS_PUBLIC = 1) do
  {
    graph_iri := get_graph ();
    c_iri := addressbook_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
      r_iri := role_iri (WAI_ID, WAM_USER, 'contact');
    }

  if (not isnull (graph_iri)) {
    iri := addressbook_contact_iri (domain_id, contact_id);
    event_iri := iri || '#event';
    geo_iri := iri || '#based_near';
    address_iri := iri || '#addr';

    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, name, created, updated, AB.WA.contact_url (domain_id, contact_id));
    ods_sioc_tags (graph_iri, iri, tags);

    DB.DBA.RDF_QUAD_URI   (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Person'));
    DB.DBA.RDF_QUAD_URI   (graph_iri, creator_iri, sioc_iri ('scope_of'), r_iri);
    DB.DBA.RDF_QUAD_URI   (graph_iri, r_iri, sioc_iri ('function_of'), iri);
    DB.DBA.RDF_QUAD_URI   (graph_iri, creator_iri, foaf_iri ('knows'), iri);
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('nick'), name);
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('firstName'), firstName);
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('family_name'), lastName);
    if (not DB.DBA.is_empty_or_null (gender))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('gender'), gender);
    if (not DB.DBA.is_empty_or_null (icq))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('icqChatID'), icq);
    if (not DB.DBA.is_empty_or_null (msn))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('msnChatID'), msn);
    if (not DB.DBA.is_empty_or_null (aim))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('aimChatID'), aim);
    if (not DB.DBA.is_empty_or_null (yahoo))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('yahooChatID'), yahoo);
    if (not DB.DBA.is_empty_or_null (birthday)) {
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('birthday'), substring (datestring (coalesce (birthday, now())), 6, 5));
      DB.DBA.RDF_QUAD_URI (graph_iri, event_iri, rdf_iri ('type'), bio_iri ('Birth'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, bio_iri ('event'), event_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, event_iri, dc_iri ('date'), substring (datestring (birthday), 1, 10));
    }
    if (not DB.DBA.is_empty_or_null (hPhone))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || hPhone);
    if (not DB.DBA.is_empty_or_null (hMail))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), hMail);
    if (not DB.DBA.is_empty_or_null (hWeb))
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('homepage'), hWeb);
    if (not DB.DBA.is_empty_or_null (hLat) and not DB.DBA.is_empty_or_null (hLng)) {
      DB.DBA.RDF_QUAD_URI (graph_iri, geo_iri, rdf_iri ('type'), geo_iri ('Point'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('based_near'), geo_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, geo_iri, geo_iri ('lat'), sprintf ('%.06f', coalesce (hLat, 0)));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, geo_iri, geo_iri ('long'), sprintf ('%.06f', coalesce (hLng, 0)));
    }
    if (not DB.DBA.is_empty_or_null (hCountry) or not DB.DBA.is_empty_or_null (hState) or not DB.DBA.is_empty_or_null (hCity) or not DB.DBA.is_empty_or_null (hCode) or not DB.DBA.is_empty_or_null (hAddress1) or not DB.DBA.is_empty_or_null (hAddress2)) {
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, vcard_iri ('ADR'), address_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, rdf_iri ('type'), vcard_iri ('home'));
      if (not DB.DBA.is_empty_or_null (hAddress1))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, vcard_iri ('Street'), hAddress1);
      if (not DB.DBA.is_empty_or_null (hAddress2))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, vcard_iri ('Extadd'), hAddress2);
      if (not DB.DBA.is_empty_or_null (hCode))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, vcard_iri ('Pobox'), hCode);
      if (not DB.DBA.is_empty_or_null (hCity))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, vcard_iri ('Locality'), hCity);
      if (not DB.DBA.is_empty_or_null (hState))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, vcard_iri ('Region'), hState);
      if (not DB.DBA.is_empty_or_null (hCountry))
        DB.DBA.RDF_QUAD_URI_L (graph_iri, address_iri, vcard_iri ('Country'), hCountry);
    }
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure contact_delete (
  inout contact_id integer,
  inout domain_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := addressbook_contact_iri (domain_id, contact_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_I after insert on AB.WA.PERSONS referencing new as N
{
  contact_insert (null,
                  null,
                  null,
                  null,
                  N.P_ID,
                  N.P_DOMAIN_ID,
                  N.P_NAME,
                  N.P_FIRST_NAME,
                  N.P_LAST_NAME,
                  N.P_GENDER,
                  N.P_BIRTHDAY,
                  N.P_ICQ,
                  N.P_SKYPE,
                  N.P_AIM,
                  N.P_YAHOO,
                  N.P_MSN,
                  N.P_H_COUNTRY,
                  N.P_H_STATE,
                  N.P_H_CITY,
                  N.P_H_CODE,
                  N.P_H_ADDRESS1,
                  N.P_H_ADDRESS1,
                  N.P_H_LAT,
                  N.P_H_LNG,
                  N.P_H_PHONE,
                  N.P_H_MAIL,
                  N.P_H_WEB,
                  N.P_CREATED,
                  N.P_UPDATED,
                  N.P_TAGS);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_U after update on AB.WA.PERSONS referencing old as O, new as N
{
  contact_delete (O.P_ID,
                  O.P_DOMAIN_ID);
  contact_insert (null,
                  null,
                  null,
                  null,
                  N.P_ID,
                  N.P_DOMAIN_ID,
                  N.P_NAME,
                  N.P_FIRST_NAME,
                  N.P_LAST_NAME,
                  N.P_GENDER,
                  N.P_BIRTHDAY,
                  N.P_ICQ,
                  N.P_SKYPE,
                  N.P_AIM,
                  N.P_YAHOO,
                  N.P_MSN,
                  N.P_H_COUNTRY,
                  N.P_H_STATE,
                  N.P_H_CITY,
                  N.P_H_CODE,
                  N.P_H_ADDRESS1,
                  N.P_H_ADDRESS1,
                  N.P_H_LAT,
                  N.P_H_LNG,
                  N.P_H_PHONE,
                  N.P_H_MAIL,
                  N.P_H_WEB,
                  N.P_CREATED,
                  N.P_UPDATED,
                  N.P_TAGS);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_D before delete on AB.WA.PERSONS referencing old as O
{
  contact_delete (O.P_ID,
                  O.P_DOMAIN_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure ods_addressbook_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_addressbook_sioc_init') = sioc_version)
    return;
  fill_ods_addressbook_sioc (get_graph (), get_graph ());
  registry_set ('__ods_addressbook_sioc_init', sioc_version);
  return;
}
;

AB.WA.exec_no_error('ods_addressbook_sioc_init ()');

use DB;
