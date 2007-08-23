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
create procedure addressbook_contact_iri (
  in domain_id varchar,
	in contact_id integer)
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
create procedure addressbook_annotation_iri (
	in domain_id varchar,
	in contact_id integer,
	in annotation_id integer)
{
	declare _member, _inst varchar;
	declare exit handler for not found { return null; };

	select U_NAME, WAI_NAME into _member, _inst
		from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
	 where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

	return sprintf ('http://%s%s/%U/addressbook/%U/%d/annotation/%d', get_cname(), get_base_path (), _member, _inst, contact_id, annotation_id);
}
;

-------------------------------------------------------------------------------
--
create procedure socialnetwork_contact_iri (
  in domain_id varchar,
  in contact_id int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
   where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/socialnetwork/%U/%d', get_cname(), get_base_path (), _member, _inst, contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_addressbook_sioc (
  in graph_iri varchar,
  in site_iri varchar,
  in _wai_name varchar := null)
{
  declare id, deadl, cnt integer;
	declare ab_iri, sc_iri, creator_iri, r_iri, iri varchar;

  {
    id := -1;
    deadl := 3;
    cnt := 0;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	      resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
    };
  l0:

    for (select WAI_ID,
                WAI_NAME,
                WAM_USER,
                P_ID,
                P_DOMAIN_ID,
                P_NAME,
                P_TITLE,
                P_FIRST_NAME,
                P_LAST_NAME,
                P_GENDER,
                P_BIRTHDAY,
                P_MAIL,
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
                P_B_COUNTRY,
                P_B_STATE,
                P_B_CITY,
                P_B_CODE,
                P_B_ADDRESS1,
                P_B_ADDRESS1,
                P_CREATED,
                P_UPDATED,
                P_TAGS
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                AB.WA.PERSONS
          where WAM_INST = WAI_NAME
            and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
            and P_DOMAIN_ID = WAI_ID
          order by P_ID) do
  {
      ab_iri := addressbook_iri (WAI_NAME);
      sc_iri := socialnetwork_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
    r_iri := role_iri (WAI_ID, WAM_USER, 'contact');

      contact_insert (graph_iri,
                      ab_iri,
                      sc_iri,
                      creator_iri,
                      r_iri,
                      P_ID,
                    P_DOMAIN_ID,
                    P_NAME,
                      P_TITLE,
                    P_FIRST_NAME,
                    P_LAST_NAME,
                    P_GENDER,
                    P_BIRTHDAY,
                      P_MAIL,
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
                      P_B_COUNTRY,
                      P_B_STATE,
                      P_B_CITY,
                      P_B_CODE,
                      P_B_ADDRESS1,
                      P_B_ADDRESS1,
                    P_CREATED,
                    P_UPDATED,
                    P_TAGS);

			for (select A_ID,
									A_DOMAIN_ID,
									A_OBJECT_ID,
									A_BODY,
									A_AUTHOR,
									A_CREATED,
									A_UPDATED
						 from AB.WA.ANNOTATIONS
						where A_OBJECT_ID = P_ID) do
			{
				annotation_insert (graph_iri,
													 ab_iri,
													 A_ID,
													 A_DOMAIN_ID,
													 A_OBJECT_ID,
													 A_BODY,
													 A_AUTHOR,
													 A_CREATED,
													 A_UPDATED);
			}
      cnt := cnt + 1;
      if (mod (cnt, 500) = 0) {
  	    commit work;
  	    id := P_ID;
      }
    }
    commit work;

		id := -1;
		deadl := 3;
		cnt := 0;
		declare exit handler for sqlstate '40001' {
			if (deadl <= 0)
				resignal;
			rollback work;
			deadl := deadl - 1;
			goto l1;
		};
	l1:
		for (select WAI_ID,
								WAI_NAME
					 from DB.DBA.WA_INSTANCE
					where ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
					order by WAI_ID) do
		{
			ab_iri := addressbook_iri (WAI_NAME);
      iri := sprintf ('http://%s%s/services/addressbook', get_cname(), get_base_path ());
      ods_sioc_service (graph_iri, iri, ab_iri, null, 'text/xml', iri||'/services.wsdl', iri, 'SOAP');

			cnt := cnt + 1;
			if (mod (cnt, 500) = 0) {
				commit work;
				id := WAI_ID;
			}
    }
		commit work;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure contact_insert (
  in graph_iri varchar,
  in ab_iri varchar,
  in sc_iri varchar,
  in creator_iri varchar,
  in r_iri varchar,
  inout contact_id integer,
  inout domain_id integer,
  inout name varchar,
  inout title varchar,
  inout firstName varchar,
  inout lastName varchar,
  inout gender varchar,
  inout birthday datetime,
  inout mail varchar,
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
  inout bCountry varchar,
  inout bState varchar,
  inout bCity varchar,
  inout bCode varchar,
  inout bAddress1 varchar,
  inout bAddress2 varchar,
  inout created datetime,
  inout updated datetime,
  inout tags varchar)
{
  declare iri, iri2, temp_iri varchar;

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
      ab_iri := addressbook_iri (WAI_NAME);
      sc_iri := socialnetwork_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
      r_iri := role_iri (WAI_ID, WAM_USER, 'contact');
    }

  if (not isnull (graph_iri)) {
    -- SocialNetwork
    iri := socialnetwork_contact_iri (domain_id, contact_id);
    ods_sioc_post (graph_iri, iri, sc_iri, creator_iri, name, created, updated, AB.WA.contact_url (domain_id, contact_id));
    ods_sioc_tags (graph_iri, iri, tags);

    -- FOAF Data Space
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
      temp_iri := iri || '#event';
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('birthday'), substring (datestring (coalesce (birthday, now())), 6, 5));
      DB.DBA.RDF_QUAD_URI (graph_iri, temp_iri, rdf_iri ('type'), bio_iri ('Birth'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, bio_iri ('event'), temp_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, dc_iri ('date'), substring (datestring (birthday), 1, 10));
    }
    if (not DB.DBA.is_empty_or_null (mail))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), mail);
    if (not DB.DBA.is_empty_or_null (hMail))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), hMail);
    if (not DB.DBA.is_empty_or_null (hWeb))
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('homepage'), hWeb);
    if (not DB.DBA.is_empty_or_null (hPhone))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || hPhone);
    if (not DB.DBA.is_empty_or_null (hLat) and not DB.DBA.is_empty_or_null (hLng)) {
      temp_iri := iri || '#based_near';
      DB.DBA.RDF_QUAD_URI (graph_iri, temp_iri, rdf_iri ('type'), geo_iri ('Point'));
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('based_near'), temp_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, geo_iri ('lat'), sprintf ('%.06f', coalesce (hLat, 0)));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, geo_iri ('long'), sprintf ('%.06f', coalesce (hLng, 0)));
    }

    -- AddressBook
    iri2 := addressbook_contact_iri (domain_id, contact_id);
    ods_sioc_post (graph_iri, iri2, ab_iri, creator_iri, name, created, updated, AB.WA.contact_url (domain_id, contact_id));
    ods_sioc_tags (graph_iri, iri2, tags);

    -- vCard Data Space
    DB.DBA.RDF_QUAD_URI   (graph_iri, iri2, rdf_iri ('type'), vcard_iri ('vCard'));
    DB.DBA.RDF_QUAD_URI   (graph_iri, iri2, vcard_iri ('UID'), iri);
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri2, vcard_iri ('NICKNAME'), name);
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri2, vcard_iri ('FN'), lastName);
    if (not DB.DBA.is_empty_or_null (firstName) or not DB.DBA.is_empty_or_null (lastName) or not DB.DBA.is_empty_or_null (title)) {
      temp_iri := iri2 || '#n';
      DB.DBA.RDF_QUAD_URI (graph_iri, iri2, vcard_iri ('N'), temp_iri);
      if (not DB.DBA.is_empty_or_null (firstName))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Given'), lastName);
      if (not DB.DBA.is_empty_or_null (lastName))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Family'), lastName);
      if (not DB.DBA.is_empty_or_null (title))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Prefix'), title);
    }
    if (not DB.DBA.is_empty_or_null (birthday))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri2, vcard_iri ('BDAY'), AB.WA.dt_format (birthday, 'Y-M-D'));
    if (not DB.DBA.is_empty_or_null (mail)) {
      temp_iri := iri2 || '#email_pref';
      DB.DBA.RDF_QUAD_URI (graph_iri, iri2, vcard_iri ('EMAIL'), temp_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('pref'));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('value'), mail);
    }
    if (not DB.DBA.is_empty_or_null (hMail)) {
      temp_iri := iri2 || '#email_internet';
      DB.DBA.RDF_QUAD_URI (graph_iri, iri2, vcard_iri ('EMAIL'), temp_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('internet'));
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('value'), hMail);
    }
    if (not DB.DBA.is_empty_or_null (tags))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri2, vcard_iri ('CATEGORIES'), tags);
    if (not DB.DBA.is_empty_or_null (hCountry) or not DB.DBA.is_empty_or_null (hState) or not DB.DBA.is_empty_or_null (hCity) or not DB.DBA.is_empty_or_null (hCode) or not DB.DBA.is_empty_or_null (hAddress1) or not DB.DBA.is_empty_or_null (hAddress2)) {
      temp_iri := iri2 || '#adr_home';
      DB.DBA.RDF_QUAD_URI (graph_iri, iri2, vcard_iri ('ADR'), temp_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('home'));
      if (not DB.DBA.is_empty_or_null (hAddress1))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Street'), hAddress1);
      if (not DB.DBA.is_empty_or_null (hAddress2))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Extadd'), hAddress2);
      if (not DB.DBA.is_empty_or_null (hCode))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Pobox'), hCode);
      if (not DB.DBA.is_empty_or_null (hCity))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Locality'), hCity);
      if (not DB.DBA.is_empty_or_null (hState))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Region'), hState);
      if (not DB.DBA.is_empty_or_null (hCountry))
        DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Country'), hCountry);
    }
    if (not DB.DBA.is_empty_or_null (bCountry) or not DB.DBA.is_empty_or_null (bState) or not DB.DBA.is_empty_or_null (bCity) or not DB.DBA.is_empty_or_null (bCode) or not DB.DBA.is_empty_or_null (bAddress1) or not DB.DBA.is_empty_or_null (bAddress2)) {
      temp_iri := iri2 || '#adr_work';
      DB.DBA.RDF_QUAD_URI (graph_iri, iri2, vcard_iri ('ADR'), temp_iri);
      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('work'));
      if (not DB.DBA.is_empty_or_null (hAddress1))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Street'), bAddress1);
      if (not DB.DBA.is_empty_or_null (hAddress2))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Extadd'), bAddress2);
      if (not DB.DBA.is_empty_or_null (hCode))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Pobox'), bCode);
      if (not DB.DBA.is_empty_or_null (hCity))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Locality'), bCity);
      if (not DB.DBA.is_empty_or_null (hState))
	      DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Region'), bState);
      if (not DB.DBA.is_empty_or_null (hCountry))
        DB.DBA.RDF_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Country'), bCountry);
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
                  null,
                  N.P_ID,
                  N.P_DOMAIN_ID,
                  N.P_NAME,
                  N.P_TITLE,
                  N.P_FIRST_NAME,
                  N.P_LAST_NAME,
                  N.P_GENDER,
                  N.P_BIRTHDAY,
                  N.P_MAIL,
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
									N.P_H_ADDRESS2,
                  N.P_H_LAT,
                  N.P_H_LNG,
                  N.P_H_PHONE,
                  N.P_H_MAIL,
                  N.P_H_WEB,
                  N.P_B_COUNTRY,
                  N.P_B_STATE,
                  N.P_B_CITY,
                  N.P_B_CODE,
                  N.P_B_ADDRESS1,
									N.P_B_ADDRESS2,
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
                  null,
                  N.P_ID,
                  N.P_DOMAIN_ID,
                  N.P_NAME,
                  N.P_TITLE,
                  N.P_FIRST_NAME,
                  N.P_LAST_NAME,
                  N.P_GENDER,
                  N.P_BIRTHDAY,
                  N.P_MAIL,
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
									N.P_H_ADDRESS2,
                  N.P_H_LAT,
                  N.P_H_LNG,
                  N.P_H_PHONE,
                  N.P_H_MAIL,
                  N.P_H_WEB,
                  N.P_B_COUNTRY,
                  N.P_B_STATE,
                  N.P_B_CITY,
                  N.P_B_CODE,
                  N.P_B_ADDRESS1,
									N.P_B_ADDRESS2,
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
create procedure annotation_insert (
	in graph_iri varchar,
	in forum_iri varchar,
	inout annotation_id integer,
	inout domain_id integer,
	inout master_id integer,
	inout author varchar,
	inout body varchar,
	inout created datetime,
	inout updated datetime)
{
	declare master_iri, annotattion_iri varchar;

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
			forum_iri := addressbook_iri (WAI_NAME);
		}

	if (not isnull (graph_iri)) {
		master_iri := addressbook_contact_iri (domain_id, cast (master_id as integer));
		annotattion_iri := addressbook_annotation_iri (domain_id, cast (master_id as integer), annotation_id);
		DB.DBA.RDF_QUAD_URI (graph_iri, annotattion_iri, an_iri ('annotates'), master_iri);
		DB.DBA.RDF_QUAD_URI (graph_iri, master_iri, an_iri ('hasAnnotation'), annotattion_iri);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('author'), author);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('body'), body);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('created'), created);
		DB.DBA.RDF_QUAD_URI_L (graph_iri, annotattion_iri, an_iri ('modified'), updated);
	}
	return;
}
;

-------------------------------------------------------------------------------
--
create procedure annotation_delete (
	inout annotation_id integer,
	inout domain_id integer,
	inout master_id integer)
{
	declare graph_iri, iri varchar;

	declare exit handler for sqlstate '*' {
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

	graph_iri := get_graph ();
	iri := contact_annotation_iri (domain_id, master_id, annotation_id);
	delete_quad_s_or_o (graph_iri, iri, iri);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_I after insert on AB.WA.ANNOTATIONS referencing new as N
{
	annotation_insert (null,
										 null,
										 N.A_ID,
										 N.A_DOMAIN_ID,
										 N.A_OBJECT_ID,
										 N.A_BODY,
										 N.A_AUTHOR,
										 N.A_CREATED,
										 N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_U after update on AB.WA.ANNOTATIONS referencing old as O, new as N
{
	annotation_delete (O.A_ID,
										 O.A_DOMAIN_ID,
										 O.A_OBJECT_ID);
	annotation_insert (null,
										 null,
										 N.A_ID,
										 N.A_DOMAIN_ID,
										 N.A_OBJECT_ID,
										 N.A_BODY,
										 N.A_AUTHOR,
										 N.A_CREATED,
										 N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_D before delete on AB.WA.ANNOTATIONS referencing old as O
{
	annotation_delete (O.A_ID,
										 O.A_DOMAIN_ID,
										 O.A_OBJECT_ID);
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

--AB.WA.exec_no_error('ods_addressbook_sioc_init ()');

use DB;
-------------------------------------------------------------------------------
--
wa_exec_no_error ('drop view ODS_ADDRESSBOOK_CONTACTS');

create view ODS_ADDRESSBOOK_CONTACTS as
select
	WAI_NAME,
	P_ID,
	P_DOMAIN_ID,
	P_NAME,
	P_TITLE,
	P_FIRST_NAME,
	P_LAST_NAME,
	P_FULL_NAME,
	P_GENDER,
	substring (datestring(coalesce (P_BIRTHDAY, now ())), 6, 5) P_BIRTHDAY,
	P_MAIL,
	P_ICQ,
	P_SKYPE,
	P_AIM,
	P_YAHOO,
	P_MSN,
	sioc..sioc_date (P_UPDATED) as P_UPDATED,
	sioc..sioc_date (P_CREATED) as P_CREATED,
	sioc..post_iri (U_NAME, 'addressbook', WAI_NAME, cast (P_ID as varchar)) || '/sioc.rdf' as SEE_ALSO,
	AB.WA.contact_url (P_DOMAIN_ID, P_ID) P_URI,
	U_NAME
from
	DB.DBA.WA_INSTANCE,
	AB.WA.PERSONS,
	DB.DBA.WA_MEMBER,
	DB.DBA.SYS_USERS
where P_DOMAIN_ID = WAI_ID
	and	WAM_INST = WAI_NAME
	and	WAM_IS_PUBLIC = 1
	and	WAM_USER = U_ID
	and	WAM_MEMBER_TYPE = 1;

-------------------------------------------------------------------------------
--
create procedure ODS_ADDRESSBOOK_TAGS ()
{
	declare V any;
	declare inst, uname, p_id, tag any;

	result_names (inst, uname, p_id, tag);

	for (select WAM_INST,
							U_NAME,
							P_ID,
							P_TAGS
				 from AB.WA.PERSONS,
							WA_MEMBER,
							WA_INSTANCE,
							SYS_USERS
				where WAM_INST = WAI_NAME
					and WAM_MEMBER_TYPE = 1
					and WAM_USER = U_ID
					and P_DOMAIN_ID = WAI_ID
					and length (P_TAGS) > 0) do {
		V := split_and_decode (P_TAGS, 0, '\0\0,');
		foreach (any t in V) do {
			t := trim(t);
			if (length (t))
				result (WAM_INST, U_NAME, P_ID, t);
		}
	}
}
;

-------------------------------------------------------------------------------
--
wa_exec_no_error ('drop view ODS_ADDRESSBOOK_TAGS');

create procedure view ODS_ADDRESSBOOK_TAGS as DB.DBA.ODS_ADDRESSBOOK_TAGS () (WAM_INST varchar, U_NAME varchar, P_ID int, P_TAG varchar);

-------------------------------------------------------------------------------
--
create procedure sioc.DBA.rdf_addressbook_view_str ()
{
	return
		'
			# Contact
			sioc:addressbook_contact_iri (DB.DBA.ODS_ADDRESSBOOK_CONTACTS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.WAI_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.P_ID)
				a foaf:Person option (EXCLUSIVE) ;
				dc:title P_NAME ;
				dct:created P_CREATED ;
				dct:modified P_UPDATED ;
				dc:date P_UPDATED ;
				dc:creator U_NAME ;
				sioc:link sioc:proxy_iri (P_URI) ;
				sioc:content P_FULL_NAME ;
				sioc:has_creator sioc:user_iri (U_NAME) ;
				sioc:has_container sioc:addressbook_forum_iri (U_NAME, WAI_NAME) ;
				rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
				foaf:maker foaf:person_iri (U_NAME) ;
				foaf:nick P_NAME ;
				foaf:name P_FULL_NAME ;
				foaf:firstName P_FIRST_NAME ;
				foaf:family_name P_LAST_NAME ;
				foaf:gender P_GENDER ;
				foaf:mbox sioc:proxy_iri(P_MAIL) ;
				foaf:icqChatID P_ICQ ;
				foaf:msnChatID P_MSN ;
				foaf:aimChatID P_AIM ;
				foaf:yahooChatID P_YAHOO ;
				foaf:birthday P_BIRTHDAY
			.

			sioc:addressbook_forum_iri (DB.DBA.ODS_ADDRESSBOOK_CONTACTS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.WAI_NAME)
				sioc:container_of sioc:addressbook_contact_iri (U_NAME, WAI_NAME, P_ID)
			.

			sioc:user_iri (DB.DBA.ODS_ADDRESSBOOK_CONTACTS.U_NAME)
				sioc:creator_of sioc:addressbook_contact_iri (U_NAME, WAI_NAME, P_ID)
			.

			# Contact tags
			sioc:addressbook_contact_iri (DB.DBA.ODS_ADDRESSBOOK_TAGS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_TAGS.WAM_INST, DB.DBA.ODS_ADDRESSBOOK_TAGS.P_ID)
				sioc:topic sioc:tag_iri (U_NAME, P_TAG)
			.

			sioc:tag_iri (DB.DBA.ODS_ADDRESSBOOK_TAGS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_TAGS.P_TAG)
				a skos:Concept ;
				skos:prefLabel P_TAG ;
				skos:isSubjectOf sioc:addressbook_contact_iri (U_NAME, WAM_INST, P_ID)
			.

			sioc:addressbook_contact_iri (DB.DBA.ODS_ADDRESSBOOK_CONTACTS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.WAI_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.P_ID)
				a atom:Entry ;
				atom:title P_NAME ;
				atom:source sioc:addressbook_forum_iri (U_NAME, WAI_NAME) ;
				atom:author foaf:person_iri (U_NAME) ;
				atom:published P_CREATED ;
				atom:updated P_UPDATED ;
				atom:content sioc:addressbook_contact_text_iri (U_NAME, WAI_NAME, P_ID)
			.

			sioc:addressbook_contact_iri (DB.DBA.ODS_ADDRESSBOOK_CONTACTS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.WAI_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.P_ID)
				a atom:Content ;
				atom:type "text/plain" ;
				atom:lang "en-US" ;
				atom:body P_FULL_NAME
			.

			sioc:addressbook_forum_iri (DB.DBA.ODS_ADDRESSBOOK_CONTACTS.U_NAME, DB.DBA.ODS_ADDRESSBOOK_CONTACTS.WAI_NAME)
				atom:contains sioc:addressbook_contact_iri (U_NAME, WAI_NAME, P_ID)
			.
		'
		;
};

grant select on ODS_ADDRESSBOOK_CONTACTS to SPARQL_SELECT;
grant select on ODS_ADDRESSBOOK_TAGS to SPARQL_SELECT;
grant execute on ODS_ADDRESSBOOK_TAGS to SPARQL_SELECT;
grant execute on AB.WA.contact_url to SPARQL_SELECT;

-- RDF Views
ODS_RDF_VIEW_INIT ();
