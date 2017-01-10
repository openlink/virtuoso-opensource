--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
AB.WA.exec_no_error ('DROP procedure SIOC.DBA.fill_ods_addressbook_sioc');

use sioc;

-------------------------------------------------------------------------------
--
create procedure addressbook_contact_iri (
	in domain_id integer,
	in contact_id integer)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME,
         WAI_NAME
    into _member,
         _inst
    from DB.DBA.SYS_USERS,
         DB.DBA.WA_INSTANCE,
         DB.DBA.WA_MEMBER
   where WAI_ID = domain_id
     and WAI_NAME = WAM_INST
     and WAM_MEMBER_TYPE = 1
     and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/addressbook/%U/%d', get_cname(), get_base_path (), _member, _inst, contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure addressbook_comment_iri (
	in domain_id integer,
	in contact_id integer,
	in comment_id integer)
{
	declare c_iri varchar;

	c_iri := addressbook_contact_iri (domain_id, contact_id);
	if (isnull (c_iri))
	  return c_iri;

	return sprintf ('%s/%d', c_iri, comment_id);
}
;

-------------------------------------------------------------------------------
--
create procedure addressbook_annotation_iri (
	in domain_id varchar,
	in contact_id integer,
	in annotation_id integer)
{
	declare c_iri varchar;

	c_iri := addressbook_contact_iri (domain_id, contact_id);
	if (isnull (c_iri))
	  return c_iri;

	return sprintf ('%s/annotation/%d', c_iri, annotation_id);
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

  select U_NAME,
         WAI_NAME
    into _member,
         _inst
    from DB.DBA.SYS_USERS,
         DB.DBA.WA_INSTANCE,
         DB.DBA.WA_MEMBER
   where WAI_ID = domain_id
     and WAI_NAME = WAM_INST
     and WAM_MEMBER_TYPE = 1
     and WAM_USER = U_ID;

	return sprintf ('http://%s%s/%U/socialnetwork/%U/%d#this', get_cname(), get_base_path (), _member, _inst, contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_addressbook_sioc2 (
  in _wai_name varchar := null,
  in _access_mode integer := null)
{
  declare id, deadl, cnt integer;
  declare graph_iri, addressbook_iri, socialnetwork_iri, contact_iri, creator_iri, role_iri, iri varchar;

  {
    fill_ods_addressbook_services ();

    for (select WAI_ID,
                WAI_IS_PUBLIC,
                WAI_TYPE_NAME,
                WAI_NAME,
                WAI_ACL
           from DB.DBA.WA_INSTANCE
          where ((_wai_name is null) or (WAI_NAME = _wai_name))
            and WAI_TYPE_NAME = 'AddressBook') do
    {
      graph_iri := SIOC..acl_graph (WAI_TYPE_NAME, WAI_NAME);
      exec (sprintf ('sparql clear graph <%s>', graph_iri));
      SIOC..wa_instance_acl_insert (WAI_IS_PUBLIC, WAI_TYPE_NAME, WAI_NAME, WAI_ACL);
      for (select P_DOMAIN_ID, P_ID, P_ACL
             from AB.WA.PERSONS
            where P_DOMAIN_ID = WAI_ID and P_ACL is not null) do
      {
        contact_acl_insert (P_DOMAIN_ID, P_ID, P_ACL);
      }
    }

    id := -1;
    deadl := 3;
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
    for (select WAI_ID,
                WAI_IS_PUBLIC,
                WAI_NAME,
                WAM_USER,
                P_ID,
                P_DOMAIN_ID,
								P_KIND,
                P_NAME,
                P_TITLE,
                P_FIRST_NAME,
								P_MIDDLE_NAME,
                P_LAST_NAME,
								P_FULL_NAME,
                P_GENDER,
                P_BIRTHDAY,
                P_PHOTO,
                P_INTERESTS,
                P_RELATIONSHIPS,
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
								P_B_LAT,
								P_B_LNG,
								P_B_PHONE,
								P_B_MAIL,
								P_B_WEB,
                P_B_ORGANIZATION,
                P_CREATED,
                P_UPDATED,
								P_TAGS,
	              P_FOAF,
                P_IRI,
                P_ACL,
                P_CERTIFICATE
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                AB.WA.PERSONS
          where WAM_INST = WAI_NAME
            and WAM_MEMBER_TYPE = 1
            and ((WAM_IS_PUBLIC > 0 and _wai_name is null) or WAI_NAME = _wai_name)
            and P_ID > id
            and P_DOMAIN_ID = WAI_ID
          order by P_ID) do
  {
      contact_iri := SIOC..addressbook_contact_iri (P_DOMAIN_ID, P_ID);
      graph_iri := SIOC..get_graph_new (coalesce (_access_mode, WAI_IS_PUBLIC), contact_iri);
      addressbook_iri := addressbook_iri (WAI_NAME);
      socialnetwork_iri := socialnetwork_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
      role_iri := role_iri (WAI_ID, WAM_USER, 'contact');

      contact_insert (graph_iri,
                      addressbook_iri,
                      socialnetwork_iri,
                      creator_iri,
                      role_iri,
                    P_DOMAIN_ID,
                      P_ID,
											P_KIND,
                    P_NAME,
                      P_TITLE,
                    P_FIRST_NAME,
											P_MIDDLE_NAME,
                    P_LAST_NAME,
											P_FULL_NAME,
                    P_GENDER,
                    P_BIRTHDAY,
                      P_PHOTO,
                      P_INTERESTS,
                      P_RELATIONSHIPS,
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
											P_B_LAT,
											P_B_LNG,
											P_B_PHONE,
											P_B_MAIL,
											P_B_WEB,
                      P_B_ORGANIZATION,
                    P_CREATED,
                    P_UPDATED,
											P_TAGS,
		                  P_FOAF,
                      P_IRI,
                      P_CERTIFICATE);

      cnt := cnt + 1;
		   if (mod (cnt, 500) = 0)
		   {
  	    commit work;
  	    id := P_ID;
      }
    }
    commit work;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_addressbook_services ()
{
  declare graph_iri, services_iri, service_iri, service_url varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('addressbook.search', 'addressbook.new', 'addressbook.import', 'addressbook.export', 'addressbook.publication.new', 'addressbook.subscription.new', 'addressbook.options.set',  'addressbook.options.get');
  ods_object_services (graph_iri, 'addressbook', 'ODS AddressBook instance services', svc_functions);

  -- contact
  svc_functions := vector ('addressbook.get', 'addressbook.edit', 'addressbook.delete', 'addressbook.comment.new', 'addressbook.relationship.new', 'addressbook.relationship.delete', 'addressbook.annotation.new');
  ods_object_services (graph_iri, 'addressbook/contact', 'ODS AddressBook contact services', svc_functions);

  -- contact comment
  svc_functions := vector ('addressbook.comment.get', 'addressbook.comment.delete');
  ods_object_services (graph_iri, 'addressbook/contact/comment', 'ODS AddressBook comment services', svc_functions);

  -- contact annotation
  svc_functions := vector ('addressbook.annotation.get', 'addressbook.annotation.claim', 'addressbook.annotation.delete');
  ods_object_services (graph_iri, 'addressbook/contact/annotation', 'ODS AddressBook annotation services', svc_functions);
}
;

-------------------------------------------------------------------------------
--
create procedure clean_ods_addressbook_sioc (
  in _wai_name varchar := null,
  in _access_mode integer := null)
{
  declare id, deadl, cnt integer;
  declare graph_iri, contact_iri varchar;

  {
    id := -1;
    deadl := 3;
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

    for (select WAI_ID,
                WAI_IS_PUBLIC,
                P_DOMAIN_ID,
                P_ID,
                P_TAGS
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                AB.WA.PERSONS
          where WAM_INST = WAI_NAME
            and WAM_MEMBER_TYPE = 1
            and ((WAM_IS_PUBLIC > 0 and _wai_name is null) or WAI_NAME = _wai_name)
            and P_ID > id
            and P_DOMAIN_ID = WAI_ID
          order by P_ID) do
    {
      contact_iri := SIOC..addressbook_contact_iri (P_DOMAIN_ID, P_ID);
      graph_iri := SIOC..get_graph_new (coalesce (_access_mode, WAI_IS_PUBLIC), contact_iri);

      contact_delete (graph_iri,
                      P_DOMAIN_ID,
                      P_ID,
                      P_TAGS
                     );

      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
      {
        commit work;
        id := P_ID;
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
  in addressbook_iri varchar,
  in socialnetwork_iri varchar,
  in creator_iri varchar,
  in role_iri varchar,
  inout domain_id integer,
  inout contact_id integer,
	inout kind integer,
  inout name varchar,
  inout title varchar,
  inout firstName varchar,
	inout middleName varchar,
  inout lastName varchar,
	inout fullName varchar,
  inout gender varchar,
  inout birthday datetime,
  inout photo varchar,
  inout interests varchar,
  inout relationships varchar,
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
	inout bLat real,
	inout bLng real,
	inout bPhone varchar,
	inout bMail varchar,
	inout bWeb varchar,
  inout bOrganization varchar,
  inout created datetime,
  inout updated datetime,
	inout tags varchar,
	inout foaf varchar,
  inout ext_iri varchar,
  inout certificate varchar)
{
  declare iri, iri2, temp_iri varchar;
	declare person_iri varchar;
  declare info, modulus, exponent, certificate_iri any;

	declare exit handler for sqlstate '*'
	{
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  if (isnull (graph_iri))
    for (select WAI_ID,
                WAI_IS_PUBLIC,
                WAM_USER,
                WAI_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER
        where WAI_ID = domain_id
          and WAM_INST = WAI_NAME
            and WAM_MEMBER_TYPE = 1
            and WAI_IS_PUBLIC > 0) do
  {
      iri := addressbook_contact_iri (domain_id, contact_id);
      graph_iri := SIOC..get_graph_new (WAI_IS_PUBLIC, iri);
      addressbook_iri := addressbook_iri (WAI_NAME);
      socialnetwork_iri := socialnetwork_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);
      role_iri := role_iri (WAI_ID, WAM_USER, 'contact');
    }

	if (not isnull (graph_iri))
	{
    -- SocialNetwork
    iri := socialnetwork_contact_iri (domain_id, contact_id);
    scot_tags_insert (domain_id, iri, tags);

		person_iri := person_iri (creator_iri);

    -- FOAF Data Space
    DB.DBA.ODS_QUAD_URI (graph_iri, person_iri, foaf_iri ('knows'), iri);
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('nick'), name);
		if (not DB.DBA.is_empty_or_null (fullName))
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('name'), fullName);
		if (not DB.DBA.is_empty_or_null (ext_iri))
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, owl_iri ('sameAs'), ext_iri);
		if (not DB.DBA.is_empty_or_null (foaf))
      if (foaf like 'http://%')
      {
        DB.DBA.ODS_QUAD_URI (graph_iri, foaf, rdf_iri ('type'), foaf_iri ('Document'));
        DB.DBA.ODS_QUAD_URI (graph_iri, foaf, foaf_iri ('topic'), iri);
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('page'), foaf);
      }
    DB.DBA.ODS_QUAD_URI (graph_iri, socialnetwork_iri, sioc_iri ('container_of'), iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), socialnetwork_iri);

    if (not DB.DBA.is_empty_or_null (interests))
    {
      for (select interest, label from DB.DBA.WA_USER_INTERESTS (txt) (interest varchar, label varchar) P where txt = interests) do
  	  {
  	    if (length (interest))
  	    {
  	      DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('interest'), interest);
  	      if (length (label))
  		    {
  		      DB.DBA.ODS_QUAD_URI_L (graph_iri, interest, rdfs_iri ('label'), label);
  		    }
  	    }
  	  }
    }
    if (not DB.DBA.is_empty_or_null (relationships))
    {
      for (select fld1, fld2 from DB.DBA.WA_USER_INTERESTS (txt) (fld1 varchar, fld2 varchar) P where txt = relationships) do
  	  {
  	    if (length (fld1))
  	    {
          if (DB.DBA.is_empty_or_null (fld2))
            fld2 := person_iri;
  	      DB.DBA.ODS_QUAD_URI (graph_iri, iri, ODS.ODS_API."ontology.denormalize"(fld1), fld2);
  	    }
  	  }
    }
		if (kind = 1)
		{
		  -- Organization
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Organization'));

  		if (not DB.DBA.is_empty_or_null (bMail))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), bMail);
  		if (not DB.DBA.is_empty_or_null (bWeb))
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('homepage'), bWeb);
  		if (not DB.DBA.is_empty_or_null (bPhone))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || bPhone);
  		if (not DB.DBA.is_empty_or_null (bLat) and not DB.DBA.is_empty_or_null (bLng))
  		{
  			temp_iri := iri || '#based_near';
        DB.DBA.ODS_QUAD_URI (graph_iri, temp_iri, rdf_iri ('type'), geo_iri ('Point'));
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('based_near'), temp_iri);
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, geo_iri ('lat'), sprintf ('%.06f', coalesce (bLat, 0)));
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, geo_iri ('long'), sprintf ('%.06f', coalesce (bLng, 0)));
  		}
    }
    else
    {
		  -- Person
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), foaf_iri ('Person'));

  		if (not DB.DBA.is_empty_or_null (firstName))
         DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('firstName'), firstName);
		  if (not DB.DBA.is_empty_or_null (lastName))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('family_name'), lastName);
    if (not DB.DBA.is_empty_or_null (gender))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('gender'), gender);
    if (not DB.DBA.is_empty_or_null (icq))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('icqChatID'), icq);
    if (not DB.DBA.is_empty_or_null (msn))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('msnChatID'), msn);
    if (not DB.DBA.is_empty_or_null (aim))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('aimChatID'), aim);
    if (not DB.DBA.is_empty_or_null (yahoo))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('yahooChatID'), yahoo);
  		if (not DB.DBA.is_empty_or_null (birthday))
  		{
      temp_iri := iri || '#event';
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('birthday'), substring (datestring (coalesce (birthday, now())), 6, 5));
        DB.DBA.ODS_QUAD_URI (graph_iri, temp_iri, rdf_iri ('type'), bio_iri ('Birth'));
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, bio_iri ('event'), temp_iri);
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, dc_iri ('date'), substring (datestring (birthday), 1, 10));
    }
    if (not DB.DBA.is_empty_or_null (mail))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox'), mail);
    if (not DB.DBA.is_empty_or_null (hMail))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('mbox_sha1sum'), hMail);
    if (not DB.DBA.is_empty_or_null (hWeb))
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('homepage'), hWeb);
    if (not DB.DBA.is_empty_or_null (hPhone))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, foaf_iri ('phone'), 'tel:' || hPhone);
  		if (not DB.DBA.is_empty_or_null (hLat) and not DB.DBA.is_empty_or_null (hLng))
  		{
      temp_iri := iri || '#based_near';
        DB.DBA.ODS_QUAD_URI (graph_iri, temp_iri, rdf_iri ('type'), geo_iri ('Point'));
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('based_near'), temp_iri);
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, geo_iri ('lat'), sprintf ('%.06f', coalesce (hLat, 0)));
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, geo_iri ('long'), sprintf ('%.06f', coalesce (hLng, 0)));
    }
      if (length (bOrganization) and length (bWeb))
      {
        temp_iri := iri || '#org';
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('workplaceHomepage'), bWeb);
        DB.DBA.ODS_QUAD_URI (graph_iri, temp_iri, rdf_iri ('type') , foaf_iri ('Organization'));
        DB.DBA.ODS_QUAD_URI (graph_iri, temp_iri, foaf_iri ('homepage'), bWeb);
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, dc_iri ('title'), bOrganization);
      }
      if (not DB.DBA.is_empty_or_null (photo))
        DB.DBA.ODS_QUAD_URI (graph_iri, iri, foaf_iri ('depiction'), DB.DBA.WA_LINK (1, photo));
  	}

    -- AddressBook
    iri2 := addressbook_contact_iri (domain_id, contact_id);
    ods_sioc_post (graph_iri, iri2, addressbook_iri, creator_iri, name, created, updated, AB.WA.contact_url (domain_id, contact_id));
    scot_tags_insert (domain_id, iri2, tags);

    -- vCard Data Space
    DB.DBA.ODS_QUAD_URI (graph_iri, iri2, rdf_iri ('type'), vcard_iri ('vCard'));
    DB.DBA.ODS_QUAD_URI (graph_iri, iri2, vcard_iri ('UID'), iri);
    DB.DBA.ODS_QUAD_URI_L (graph_iri, iri2, vcard_iri ('NICKNAME'), name);
	  if (not DB.DBA.is_empty_or_null (fullName))
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri2, vcard_iri ('FN'), fullName);
		if (not DB.DBA.is_empty_or_null (firstName) or not DB.DBA.is_empty_or_null (lastName) or not DB.DBA.is_empty_or_null (title))
		{
      temp_iri := iri2 || '#n';
      DB.DBA.ODS_QUAD_URI (graph_iri, iri2, vcard_iri ('N'), temp_iri);
      if (not DB.DBA.is_empty_or_null (firstName))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Given'), firstName);
      if (not DB.DBA.is_empty_or_null (lastName))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Family'), lastName);
      if (not DB.DBA.is_empty_or_null (title))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Prefix'), title);
    }
    if (not DB.DBA.is_empty_or_null (birthday))
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri2, vcard_iri ('BDAY'), AB.WA.dt_format (birthday, 'Y-M-D'));
		if (not DB.DBA.is_empty_or_null (mail))
		{
      temp_iri := iri2 || '#email_pref';
      DB.DBA.ODS_QUAD_URI (graph_iri, iri2, vcard_iri ('EMAIL'), temp_iri);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('pref'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('value'), mail);
    }
		if (not DB.DBA.is_empty_or_null (hMail))
		{
      temp_iri := iri2 || '#email_internet';
      DB.DBA.ODS_QUAD_URI (graph_iri, iri2, vcard_iri ('EMAIL'), temp_iri);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('internet'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('value'), hMail);
    }
    if (not DB.DBA.is_empty_or_null (tags))
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri2, vcard_iri ('CATEGORIES'), tags);
		if (not DB.DBA.is_empty_or_null (hCountry) or not DB.DBA.is_empty_or_null (hState) or not DB.DBA.is_empty_or_null (hCity) or not DB.DBA.is_empty_or_null (hCode) or not DB.DBA.is_empty_or_null (hAddress1) or not DB.DBA.is_empty_or_null (hAddress2))
		{
      temp_iri := iri2 || '#adr_home';
      DB.DBA.ODS_QUAD_URI (graph_iri, iri2, vcard_iri ('ADR'), temp_iri);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('home'));
      if (not DB.DBA.is_empty_or_null (hAddress1))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Street'), hAddress1);
      if (not DB.DBA.is_empty_or_null (hAddress2))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Extadd'), hAddress2);
      if (not DB.DBA.is_empty_or_null (hCode))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Pobox'), hCode);
      if (not DB.DBA.is_empty_or_null (hCity))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Locality'), hCity);
      if (not DB.DBA.is_empty_or_null (hState))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Region'), hState);
      if (not DB.DBA.is_empty_or_null (hCountry))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Country'), hCountry);
    }
		if (not DB.DBA.is_empty_or_null (bCountry) or not DB.DBA.is_empty_or_null (bState) or not DB.DBA.is_empty_or_null (bCity) or not DB.DBA.is_empty_or_null (bCode) or not DB.DBA.is_empty_or_null (bAddress1) or not DB.DBA.is_empty_or_null (bAddress2))
		{
      temp_iri := iri2 || '#adr_work';
      DB.DBA.ODS_QUAD_URI (graph_iri, iri2, vcard_iri ('ADR'), temp_iri);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, rdf_iri ('type'), vcard_iri ('work'));
      if (not DB.DBA.is_empty_or_null (hAddress1))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Street'), bAddress1);
      if (not DB.DBA.is_empty_or_null (hAddress2))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Extadd'), bAddress2);
      if (not DB.DBA.is_empty_or_null (hCode))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Pobox'), bCode);
      if (not DB.DBA.is_empty_or_null (hCity))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Locality'), bCity);
      if (not DB.DBA.is_empty_or_null (hState))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Region'), bState);
      if (not DB.DBA.is_empty_or_null (hCountry))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, temp_iri, vcard_iri ('Country'), bCountry);
    }
  }

  -- certificate
  info := get_certificate_info (9, cast (certificate as varchar), 0);
  if (info is not null and isarray (info) and cast (info[0] as varchar) = 'RSAPublicKey')
  {
    modulus := info[2];
    exponent := info[1];
    certificate_iri := iri || '#cert';
    DB.DBA.ODS_QUAD_URI (graph_iri, certificate_iri, cert_iri ('identity'), iri);
    DB.DBA.ODS_QUAD_URI (graph_iri, certificate_iri, rdf_iri ('type'), rsa_iri ('RSAPublicKey'));

    DB.DBA.ODS_QUAD_URI_L_TYPED (graph_iri, certificate_iri, rsa_iri ('modulus'), bin2hex (modulus), cert_iri ('hex'), null);
    DB.DBA.ODS_QUAD_URI_L_TYPED (graph_iri, certificate_iri, rsa_iri ('public_exponent'), cast (exponent as varchar), cert_iri ('int'), null);
  }

  -- contact services
  SIOC..ods_object_services_attach (graph_iri, iri2, 'addressbook/contact');

  SIOC..contact_comments_insert (graph_iri, addressbook_iri, domain_id, contact_id);
  SIOC..contact_annotations_insert (graph_iri, domain_id, contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure contact_delete (
  in graph_iri varchar,
	inout domain_id integer,
  inout contact_id integer,
	inout tags varchar)
{
  declare iri varchar;
	declare exit handler for sqlstate '*'
	{
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..addressbook_contact_iri (domain_id, contact_id);
  if (isnull (graph_iri))
  {
    graph_iri := SIOC..get_graph_new (AB.WA.domain_is_public (domain_id), iri);
    if (isnull (graph_iri))
      return;
  }

  -- AB Data
	scot_tags_delete (domain_id, iri, tags);
	delete_quad_s_or_o (graph_iri, iri, iri);

  SIOC..ods_object_services_dettach (graph_iri, iri, 'addressbook/contact');

  -- Social Data
  iri := SIOC..socialnetwork_contact_iri (domain_id, contact_id);
	scot_tags_delete (domain_id, iri, tags);
  delete_quad_s_or_o (graph_iri, iri, iri);

  contact_comments_delete (graph_iri, domain_id, contact_id);
  contact_annotations_delete (graph_iri, domain_id, contact_id);
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
                  N.P_DOMAIN_ID,
                  N.P_ID,
									N.P_KIND,
                  N.P_NAME,
                  N.P_TITLE,
                  N.P_FIRST_NAME,
									N.P_MIDDLE_NAME,
                  N.P_LAST_NAME,
									N.P_FULL_NAME,
                  N.P_GENDER,
                  N.P_BIRTHDAY,
                  N.P_PHOTO,
                  N.P_INTERESTS,
                  N.P_RELATIONSHIPS,
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
									N.P_B_LAT,
									N.P_B_LNG,
									N.P_B_PHONE,
									N.P_B_MAIL,
									N.P_B_WEB,
                  N.P_B_ORGANIZATION,
                  N.P_CREATED,
                  N.P_UPDATED,
									N.P_TAGS,
									N.P_FOAF,
                  N.P_IRI,
                  N.P_CERTIFICATE);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_U after update on AB.WA.PERSONS referencing old as O, new as N
{
  contact_delete (null,
                  O.P_DOMAIN_ID,
                  O.P_ID,
                  O.P_TAGS);
  contact_insert (null,
                  null,
                  null,
                  null,
                  null,
                  N.P_DOMAIN_ID,
                  N.P_ID,
									N.P_KIND,
                  N.P_NAME,
                  N.P_TITLE,
                  N.P_FIRST_NAME,
									N.P_MIDDLE_NAME,
                  N.P_LAST_NAME,
									N.P_FULL_NAME,
                  N.P_GENDER,
                  N.P_BIRTHDAY,
                  N.P_PHOTO,
                  N.P_INTERESTS,
                  N.P_RELATIONSHIPS,
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
									N.P_B_LAT,
									N.P_B_LNG,
									N.P_B_PHONE,
									N.P_B_MAIL,
									N.P_B_WEB,
                  N.P_B_ORGANIZATION,
                  N.P_CREATED,
                  N.P_UPDATED,
									N.P_TAGS,
									N.P_FOAF,
                  N.P_IRI,
                  N.P_CERTIFICATE);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_D before delete on AB.WA.PERSONS referencing old as O
{
  contact_delete (null,
                  O.P_DOMAIN_ID,
                  O.P_ID,
                  O.P_TAGS);
}
;

-------------------------------------------------------------------------------
--
create procedure contact_acl_insert (
  inout domain_id integer,
  inout contact_id integer,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..addressbook_contact_iri (domain_id, contact_id);
  graph_iri := AB.WA.acl_graph (domain_id);

  SIOC..acl_insert (graph_iri, iri, acl);
}
;

-------------------------------------------------------------------------------
--
create procedure contact_acl_delete (
  inout domain_id integer,
  inout contact_id integer,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..addressbook_contact_iri (domain_id, contact_id);
  graph_iri := AB.WA.acl_graph (domain_id);

  SIOC..acl_delete (graph_iri, iri, acl);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_ACL_I after insert on AB.WA.PERSONS order 100 referencing new as N
{
  if (coalesce (N.P_ACL, '') <> '')
  {
    contact_acl_insert (N.P_DOMAIN_ID,
                        N.P_ID,
                        N.P_ACL);

    SIOC..acl_ping (N.P_DOMAIN_ID,
                    SIOC..addressbook_contact_iri (N.P_DOMAIN_ID, N.P_ID),
                    null,
                    N.P_ACL);
  }
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_ACL_U after update (P_ACL) on AB.WA.PERSONS order 100 referencing old as O, new as N
{
  if (coalesce (O.P_ACL, '') <> '')
    contact_acl_delete (O.P_DOMAIN_ID,
                        O.P_ID,
                        O.P_ACL);

  if (coalesce (N.P_ACL, '') <> '')
    contact_acl_insert (N.P_DOMAIN_ID,
                        N.P_ID,
                        N.P_ACL);

  SIOC..acl_ping (N.P_DOMAIN_ID,
                  SIOC..addressbook_contact_iri (N.P_DOMAIN_ID, N.P_ID),
                  O.P_ACL,
                  N.P_ACL);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSONS_SIOC_ACL_D before delete on AB.WA.PERSONS order 100 referencing old as O
{
  if (coalesce (O.P_ACL, '') <> '')
    contact_acl_delete (O.P_DOMAIN_ID,
                        O.P_ID,
                        O.P_ACL);
}
;

-------------------------------------------------------------------------------
--
create procedure contact_comments_insert (
  in graph_iri varchar,
  in forum_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select PC_ID,
              PC_DOMAIN_ID,
              PC_PERSON_ID,
              PC_TITLE,
              PC_COMMENT,
              PC_UPDATED,
              PC_U_NAME,
              PC_U_MAIL,
              PC_U_URL
         from AB.WA.PERSON_COMMENTS
        where PC_PERSON_ID = master_id) do
  {
    contact_comment_insert (graph_iri,
                            forum_iri,
                            PC_DOMAIN_ID,
                            PC_PERSON_ID,
                            PC_ID,
                            PC_TITLE,
                            PC_COMMENT,
                            PC_UPDATED,
                            PC_U_NAME,
                            PC_U_MAIL,
                            PC_U_URL
                           );
  }
}
;

-------------------------------------------------------------------------------
--
create procedure contact_comments_delete (
  in graph_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select PC_ID,
              PC_DOMAIN_ID,
              PC_PERSON_ID,
              PC_TITLE,
              PC_COMMENT,
              PC_UPDATED,
              PC_U_NAME,
              PC_U_MAIL,
              PC_U_URL
         from AB.WA.PERSON_COMMENTS
        where PC_PERSON_ID = master_id) do
  {
    SIOC..contact_comment_delete (graph_iri,
                                  PC_DOMAIN_ID,
                                  PC_PERSON_ID,
                                  PC_ID);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure contact_comment_insert (
	in graph_iri varchar,
	in forum_iri varchar,
  inout domain_id integer,
  inout master_id integer,
  inout comment_id integer,
  inout title varchar,
  inout comment varchar,
  inout last_update datetime,
  inout u_name varchar,
  inout u_mail varchar,
  inout u_url varchar)
{
	declare master_iri, comment_iri varchar;

	declare exit handler for sqlstate '*'
	{
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

  master_id := cast (master_id as integer);
  master_iri := SIOC..addressbook_contact_iri (domain_id, master_id);
	if (isnull (graph_iri))
    graph_iri := get_graph_new (AB.WA.domain_is_public (domain_id), master_iri);

    if (isnull (graph_iri))
      return;

  if (isnull (forum_iri))
    forum_iri := AB.WA.forum_iri (domain_id);

    if (isnull (forum_iri))
      return;

		comment_iri := addressbook_comment_iri (domain_id, master_id, comment_id);
  if (isnull (comment_iri))
    return;

      foaf_maker (graph_iri, u_url, u_name, u_mail);
  SIOC..ods_sioc_post (graph_iri, comment_iri, forum_iri, null, title, last_update, last_update, null, comment, null, null, u_url);
  SIOC..ods_object_services_attach (graph_iri, comment_iri, 'addressbook/contact/comment');
  DB.DBA.ODS_QUAD_URI (graph_iri, master_iri, sioc_iri ('has_reply'), comment_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, comment_iri, sioc_iri ('reply_of'), master_iri);
    }
;

-------------------------------------------------------------------------------
--
create procedure contact_comment_delete (
  in graph_iri varchar,
  inout domain_id integer,
  inout master_id integer,
  inout comment_id integer)
{
  declare master_iri, comment_iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  master_id := cast (master_id as integer);
  master_iri := SIOC..addressbook_contact_iri (domain_id, master_id);
  if (isnull (graph_iri))
    graph_iri := SIOC..get_graph_new (AB.WA.domain_is_public (domain_id), master_iri);

    if (isnull (graph_iri))
      return;

  comment_iri := SIOC..addressbook_comment_iri (domain_id, master_id, comment_id);
  delete_quad_s_or_o (graph_iri, comment_iri, comment_iri);
  -- comment services
  SIOC..ods_object_services_dettach (graph_iri, comment_iri, 'addressbook/contact/comment');
}
;

-------------------------------------------------------------------------------
--
create trigger PERSON_COMMENTS_SIOC_I after insert on AB.WA.PERSON_COMMENTS referencing new as N
{
  if (not isnull(N.PC_PARENT_ID))
    contact_comment_insert (null,
                                null,
                                N.PC_DOMAIN_ID,
                                N.PC_PERSON_ID,
                            N.PC_ID,
                                N.PC_TITLE,
                                N.PC_COMMENT,
                                N.PC_UPDATED,
                                N.PC_U_NAME,
                                N.PC_U_MAIL,
                                N.PC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSON_COMMENTS_SIOC_U after update on AB.WA.PERSON_COMMENTS referencing old as O, new as N
{
  if (not isnull(O.PC_PARENT_ID))
    contact_comment_delete (null,
                            O.PC_DOMAIN_ID,
                                O.PC_PERSON_ID,
                                O.PC_ID);
  if (not isnull(N.PC_PARENT_ID))
    contact_comment_insert (null,
                                null,
                                N.PC_DOMAIN_ID,
                                N.PC_PERSON_ID,
                            N.PC_ID,
                                N.PC_TITLE,
                                N.PC_COMMENT,
                                N.PC_UPDATED,
                                N.PC_U_NAME,
                                N.PC_U_MAIL,
                                N.PC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger PERSON_COMMENTS_SIOC_D before delete on AB.WA.PERSON_COMMENTS referencing old as O
{
  if (not isnull(O.PC_PARENT_ID))
    contact_comment_delete (null,
                            O.PC_DOMAIN_ID,
                                O.PC_PERSON_ID,
                                O.PC_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure contact_annotations_insert (
  in graph_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select A_ID,
              A_DOMAIN_ID,
              A_OBJECT_ID,
              A_AUTHOR,
              A_BODY,
              A_CLAIMS,
              A_CREATED,
              A_UPDATED
         from AB.WA.ANNOTATIONS
        where A_OBJECT_ID = master_id) do
  {
    contact_annotation_insert (graph_iri,
                               A_DOMAIN_ID,
                               A_OBJECT_ID,
                               A_ID,
                               A_AUTHOR,
                               A_BODY,
                               A_CLAIMS,
                               A_CREATED,
                               A_UPDATED
                              );
  }
}
;

-------------------------------------------------------------------------------
--
create procedure contact_annotations_delete (
  in graph_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select A_ID,
              A_DOMAIN_ID,
              A_OBJECT_ID,
              A_CLAIMS
         from AB.WA.ANNOTATIONS
        where A_OBJECT_ID = master_id) do
  {
    contact_annotation_delete (graph_iri,
                               A_DOMAIN_ID,
                               A_OBJECT_ID,
                               A_ID,
                               A_CLAIMS
                              );
  }
}
;

-------------------------------------------------------------------------------
--
create procedure contact_annotation_insert (
	in graph_iri varchar,
	in forum_iri varchar,
	inout domain_id integer,
	inout master_id integer,
  inout annotation_id integer,
	inout author varchar,
	inout body varchar,
  inout claims any,
	inout created datetime,
	inout updated datetime)
{
  declare master_iri, annotation_iri varchar;
	declare exit handler for sqlstate '*'
	{
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

  master_id := cast (master_id as integer);
  master_iri := SIOC..addressbook_contact_iri (domain_id, master_id);
	if (isnull (graph_iri))
		{
    graph_iri := get_graph_new (AB.WA.domain_is_public (domain_id), master_iri);
    if (isnull (graph_iri))
      return;
		}
  annotation_iri := addressbook_annotation_iri (domain_id, master_id, annotation_id);
  DB.DBA.ODS_QUAD_URI (graph_iri, annotation_iri, an_iri ('annotates'), master_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, master_iri, an_iri ('hasAnnotation'), annotation_iri);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('author'), author);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('body'), body);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('created'), created);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('modified'), updated);

  addressbook_claims_insert (graph_iri, annotation_iri, claims);
  SIOC..ods_object_services_attach (graph_iri, annotation_iri, 'addressbook/contact/annotation');
	}
;

-------------------------------------------------------------------------------
--
create procedure contact_annotation_delete (
  in graph_iri varchar,
	inout domain_id integer,
  inout master_id integer,
  inout annotation_id integer,
  inout claims any)
{
  declare master_iri, annotation_iri varchar;
  declare exit handler for sqlstate '*'
  {
		sioc_log_message (__SQL_MESSAGE);
		return;
	};

  master_id := cast (master_id as integer);
  master_iri := SIOC..addressbook_contact_iri (domain_id, master_id);
  if (isnull (graph_iri))
  {
    graph_iri := SIOC..get_graph_new (AB.WA.domain_is_public (domain_id), master_iri);
    if (isnull (graph_iri))
      return;
  }
  annotation_iri := addressbook_annotation_iri (domain_id, master_id, annotation_id);
  SIOC..delete_quad_s_or_o (graph_iri, annotation_iri, annotation_iri);
  SIOC..ods_object_services_dettach (graph_iri, annotation_iri, 'addressbook/contact/annotation');
}
;

-------------------------------------------------------------------------------
--
create procedure addressbook_claims_insert (
  in graph_iri varchar,
  in annotation_iri varchar,
  in claims any)
{
  declare N integer;
  declare V, cURI, cPedicate, cValue any;

  V := deserialize (claims);
  for (N := 0; N < length (V); N := N +1)
  {
    cPedicate := V[N][1];
    cValue := V[N][2];
    if (0 = length (cPedicate))
    {
      cPedicate := rdfs_iri ('seeAlso');
    } else {
      cPedicate := ODS.ODS_API."ontology.denormalize" (cPedicate);
  }
    DB.DBA.ODS_QUAD_URI (graph_iri, annotation_iri, cPedicate, cValue);
}
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_I after insert on AB.WA.ANNOTATIONS referencing new as N
{
  contact_annotation_insert (null,
										 null,
										 N.A_DOMAIN_ID,
										 N.A_OBJECT_ID,
                             N.A_ID,
										 N.A_AUTHOR,
           										   N.A_BODY,
                                 N.A_CLAIMS,
										 N.A_CREATED,
										 N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_U after update on AB.WA.ANNOTATIONS referencing old as O, new as N
{
  contact_annotation_delete (null,
										 O.A_DOMAIN_ID,
										             O.A_OBJECT_ID,
                             O.A_ID,
                                 O.A_CLAIMS);
  contact_annotation_insert (null,
										 null,
										 N.A_DOMAIN_ID,
										 N.A_OBJECT_ID,
                             N.A_ID,
										 N.A_AUTHOR,
										             N.A_BODY,
                                 N.A_CLAIMS,
										 N.A_CREATED,
										 N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_D before delete on AB.WA.ANNOTATIONS referencing old as O
{
  contact_annotation_delete (null,
										 O.A_DOMAIN_ID,
										             O.A_OBJECT_ID,
                             O.A_ID,
                                 O.A_CLAIMS);
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
  fill_ods_addressbook_sioc2 ();
  registry_set ('__ods_addressbook_sioc_init', sioc_version);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tmp_update ()
{
  if (registry_get ('ab_services_update') = '1')
    return;

  SIOC..fill_ods_addressbook_services();
  registry_set ('ab_services_update', '1');
}
;

AB.WA.tmp_update ();

-------------------------------------------------------------------------------
--
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
		foreach (any t in V) do
		{
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
				a foaf:Person ;
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

create procedure sioc.DBA.rdf_addressbook_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_ADDRESSBOOK_CONTACTS as addressbook_contacts
      where (^{addressbook_contacts.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_ADDRESSBOOK_TAGS as addressbook_tags
      where (^{addressbook_tags.}^.U_NAME = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_addressbook_view_str_maps ()
{
  return
      '
      # AddressBook
      ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
        a foaf:Person ;
        dc:title addressbook_contacts.P_NAME ;
        dct:created addressbook_contacts.P_CREATED ;
       	dct:modified addressbook_contacts.P_UPDATED ;
  	    dc:date addressbook_contacts.P_UPDATED ;
  	    dc:creator addressbook_contacts.U_NAME ;
  	    sioc:link ods:proxy (addressbook_contacts.P_URI) ;
  	    sioc:content addressbook_contacts.P_FULL_NAME ;
  	    sioc:has_creator ods:user (addressbook_contacts.U_NAME) ;
  	    sioc:has_container ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME) ;
  	    rdfs:seeAlso ods:proxy (addressbook_contacts.SEE_ALSO) ;
  	    foaf:maker ods:person (addressbook_contacts.U_NAME) ;
  	    foaf:nick addressbook_contacts.P_NAME ;
  	    foaf:name addressbook_contacts.P_FULL_NAME ;
  	    foaf:firstName addressbook_contacts.P_FIRST_NAME ;
  	    foaf:family_name addressbook_contacts.P_LAST_NAME ;
  	    foaf:gender addressbook_contacts.P_GENDER ;
  	    foaf:mbox ods:proxy(addressbook_contacts.P_MAIL) ;
  	    foaf:icqChatID addressbook_contacts.P_ICQ ;
  	    foaf:msnChatID addressbook_contacts.P_MSN ;
  	    foaf:aimChatID addressbook_contacts.P_AIM ;
  	    foaf:yahooChatID addressbook_contacts.P_YAHOO ;
  	    foaf:birthday addressbook_contacts.P_BIRTHDAY
  	  .
      ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME)
        sioc:container_of ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
      .
	    ods:user (addressbook_contacts.U_NAME)
	      sioc:creator_of ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
	    .
      ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
        a atom:Entry ;
      	atom:title addressbook_contacts.P_NAME ;
      	atom:source ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME) ;
      	atom:author ods:person (addressbook_contacts.U_NAME) ;
        atom:published addressbook_contacts.P_CREATED ;
      	atom:updated addressbook_contacts.P_UPDATED ;
      	atom:content ods:addressbook_contact_text (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
     	.
      ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
        a atom:Content ;
        atom:type "text/plain" ;
    	  atom:lang "en-US" ;
	      atom:body addressbook_contacts.P_FULL_NAME
	    .
      ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME)
        atom:contains ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
      .
    	ods:addressbook_contact (addressbook_tags.U_NAME, addressbook_tags.WAM_INST, addressbook_tags.P_ID)
    	  sioc:topic ods:tag (addressbook_tags.U_NAME, addressbook_tags.P_TAG)
    	.
    	ods:tag (addressbook_tags.U_NAME, addressbook_tags.P_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel addressbook_tags.P_TAG ;
    	  skos:isSubjectOf ods:addressbook_contact (addressbook_tags.U_NAME, addressbook_tags.WAM_INST, addressbook_tags.P_ID)
    	.
      # end AddressBook
      '
      ;
};

grant select on ODS_ADDRESSBOOK_CONTACTS to SPARQL_SELECT;
grant select on ODS_ADDRESSBOOK_TAGS to SPARQL_SELECT;
grant execute on ODS_ADDRESSBOOK_TAGS to SPARQL_SELECT;
grant execute on AB.WA.contact_url to SPARQL_SELECT;

-- RDF Views
ODS_RDF_VIEW_INIT ();
