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

use ODS;


-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.addressbook_setting_set (
  inout settings any,
  inout options any,
  in settingName varchar,
  in settingTest any := null)
{
	declare aValue any;

  aValue := get_keyword (settingName, options, get_keyword (settingName, settings));
  if (not isnull (settingTest))
    AB.WA.test (cast (aValue as varchar), settingTest);
  AB.WA.set_keyword (settingName, settings, aValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.addressbook_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.addressbook_type_check (
  in inType varchar,
  in inSource varchar)
{
  declare outType integer;

  if (isnull (inType))
    inType := case when (inSource like 'http://%') then 'url' else 'webdav' end;

	if (lcase (inType) = 'webdav')
	{
		outType := 1;
	}
	else if (lcase (inType) = 'url')
	{
		outType := 2;
	}
	else
	{
		signal ('AB106', 'The source type must be WebDAV or URL.');
	}
	return outType;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.addressbook_edit_update (
  in id integer,
  in domain_id integer,
  in pName varchar,
  in pValue any)
{
  if (isnull (pValue))
    return;

  AB.WA.contact_update2 (id, domain_id, pName, pValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.search" (
  in inst_id integer,
	in keywords any := null,
	in category any := null,
	in tags any := null,
	in maxResults integer := 100) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare uname varchar;
	declare N, account_id, contact_id, category_id integer;
	declare q, iri varchar;
  declare S, st, msg, meta, data any;

	if (not ods_check_auth (uname, inst_id, 'author'))
		return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

	account_id := AB.WA.domain_owner_id (inst_id);

  data := vector ();
  if (not isnull (keywords))
  {
    AB.WA.test (keywords, vector ('name', 'Keywords', 'class', 'free-text'));
    AB.WA.xml_set ('keywords', data, keywords);
  }
  if (not isnull (tags))
  {
    AB.WA.test (tags, vector ('name', 'Tags', 'class', 'tags'));
    AB.WA.xml_set ('tags', data, tags);
  }
  AB.WA.test (maxResults, vector ('name', 'Max Records', 'class', 'integer', 'minValue', 1, 'maxValue', 1000));
  if (not isnull (category))
  {
    category_id := (select C_ID from AB.WA.CATEGORIES where C_DOMAIN_ID = inst_id and C_NAME = category_id);
    AB.WA.xml_set ('category', data, category_id);
  }
  AB.WA.xml_set ('MyContacts', data, 1);

  set_user_id ('dba');
  S := AB.WA.search_sql (inst_id, account_id, data, cast (maxResults as varchar));
  S := concat (S, ' order by P_NAME');
  st := '00000';
  exec(S, st, msg, vector(), 0, meta, data);
  if (st = '00000')
  {
    for (N := 0; N < length (data); N := N + 1)
    {
    	ods_describe_iri (SIOC..addressbook_contact_iri (inst_id, data[N][0]));
    }
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.get" (
  in contact_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id integer;
  declare q, iri varchar;

  inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

	ods_describe_iri (SIOC..addressbook_contact_iri (inst_id, contact_id));
	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.new" (
  in inst_id integer,
  in name varchar,
  in category_id integer := null,
  in kind integer := 0,
  in title varchar := null,
  in fName varchar := null,
  in mName varchar := null,
  in lName varchar := null,
  in fullName varchar := null,
  in gender varchar := null,
  in birthday datetime := null,
  in iri varchar := null,
  in foaf varchar := null,
	in photo varchar := null,
	in interests varchar := null,
  in relationships varchar := null,
  in mail varchar := null,
  in web varchar := null,
  in icq varchar := null,
  in skype varchar := null,
  in aim varchar := null,
  in yahoo varchar := null,
  in msn varchar := null,
  in hCountry varchar := null,
  in hState varchar := null,
  in hCity varchar := null,
  in hCode varchar := null,
  in hAddress1 varchar := null,
  in hAddress2 varchar := null,
  in hTzone varchar := null,
  in hLat real := null,
  in hLng real := null,
  in hPhone varchar := null,
  in hMobile varchar := null,
  in hFax varchar := null,
  in hMail varchar := null,
  in hWeb varchar := null,
  in bCountry varchar := null,
  in bState varchar := null,
  in bCity varchar := null,
  in bCode varchar := null,
  in bAddress1 varchar := null,
  in bAddress2 varchar := null,
  in bTzone varchar := null,
  in bLat real := null,
  in bLng real := null,
  in bPhone varchar := null,
  in bMobile varchar := null,
  in bFax varchar := null,
  in bIndustry varchar := null,
  in bOrganization varchar := null,
  in bDepartment varchar := null,
  in bJob varchar := null,
  in bMail varchar := null,
  in bWeb varchar := null,
  in tags varchar := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  tags := coalesce (tags, '');
  rc := AB.WA.contact_update (
          -1,
          inst_id,
          category_id,
          kind,
          name,
          title,
          fName,
          mName,
          lName,
          fullName,
          gender,
          birthday,
          iri,
          foaf,
					photo,
					interests,
          relationships,
          mail,
          web,
          icq,
          skype,
          aim,
          yahoo,
          msn,
          hCountry,
          hState,
          hCity,
          hCode,
          hAddress1,
          hAddress2,
          hTzone,
          hLat,
          hLng,
          hPhone,
          hMobile,
          hFax,
          hMail,
          hWeb,
          bCountry,
          bState,
          bCity,
          bCode,
          bAddress1,
          bAddress2,
          bTzone,
          bLat,
          bLng,
          bPhone,
          bMobile,
          bFax,
          bIndustry,
          bOrganization,
          bDepartment,
          bJob,
          bMail,
          bWeb,
          tags);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.edit" (
  in contact_id integer,
  in name varchar := null,
  in category_id integer := null,
  in kind integer := null,
  in title varchar := null,
  in fName varchar := null,
  in mName varchar := null,
  in lName varchar := null,
  in fullName varchar := null,
  in gender varchar := null,
  in birthday datetime := null,
  in iri varchar := null,
  in foaf varchar := null,
	in photo varchar := null,
	in interests varchar := null,
  in relationships varchar := null,
  in mail varchar := null,
  in web varchar := null,
  in icq varchar := null,
  in skype varchar := null,
  in aim varchar := null,
  in yahoo varchar := null,
  in msn varchar := null,
  in hCountry varchar := null,
  in hState varchar := null,
  in hCity varchar := null,
  in hCode varchar := null,
  in hAddress1 varchar := null,
  in hAddress2 varchar := null,
  in hTzone varchar := null,
  in hLat real := null,
  in hLng real := null,
  in hPhone varchar := null,
  in hMobile varchar := null,
  in hFax varchar := null,
  in hMail varchar := null,
  in hWeb varchar := null,
  in bCountry varchar := null,
  in bState varchar := null,
  in bCity varchar := null,
  in bCode varchar := null,
  in bAddress1 varchar := null,
  in bAddress2 varchar := null,
  in bTzone varchar := null,
  in bLat real := null,
  in bLng real := null,
  in bPhone varchar := null,
  in bMobile varchar := null,
  in bFax varchar := null,
  in bIndustry varchar := null,
  in bOrganization varchar := null,
  in bDepartment varchar := null,
  in bJob varchar := null,
  in bMail varchar := null,
  in bWeb varchar := null,
  in tags varchar := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.PERSONS where P_ID = contact_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_KIND', kind);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_NAME', name);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_TITLE', title);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_FIRST_NAME', fName);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_MIDDLE_NAME', mName);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_LAST_NAME', lName);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_FULL_NAME', fullName);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_GENDER', gender);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_BIRTHDAY', birthday);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_IRI', iri);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_FOAF', foaf);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_PHOTO', photo);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_INTERESTS', interests);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_RELATIONSHIPS', relationships);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_MAIL', mail);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_WEB', web);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_ICQ', icq);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_SKYPE', skype);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_AIM', aim);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_YAHOO', yahoo);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_MSN', msn);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_ADDRESS1', hAddress1);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_ADDRESS2', hAddress2);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_CODE', hCode);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_CITY', hCity);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_STATE', hState);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_COUNTRY', hCountry);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_TZONE', hTzone);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_LAT', hLat);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_LNG', hLng);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_PHONE', hPhone);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_MOBILE', hMobile);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_FAX', hFax);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_MAIL', hMail);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_H_WEB', hWeb);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_ADDRESS1', bAddress1);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_ADDRESS2', bAddress2);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_CODE', bCode);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_CITY', bCity);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_STATE', bState);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_COUNTRY', bCountry);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_TZONE', bTzone);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_LAT', bLat);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_LNG', bLng);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_PHONE', bPhone);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_MOBILE', bMobile);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_FAX', bFax);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_INDUSTRY', bIndustry);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_ORGANIZATION', bOrganization);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_DEPARTMENT', bDepartment);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_JOB', bJob);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_MAIL', bMail);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_B_WEB', bWeb);
  ODS.ODS_API.addressbook_edit_update (contact_id, inst_id, 'P_TAGS', tags);

	return ods_serialize_int_res (contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.delete" (
  in contact_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.PERSONS where P_ID = contact_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from AB.WA.PERSONS where P_ID = contact_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.relationship.new" (
	in contact any,
	in relationship varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare rc integer;
	declare uname varchar;
	declare inst_id, contact_id integer;
	declare arr, tmp, relationships, new_relationships, _relationship any;

  if (atoi (contact) <> 0)
  {
    contact_id := atoi (contact);
  } else {
    arr := sprintf_inverse (contact, 'http://%s/dataspace/%s/addressbook/%s/%s', 1);
    if (length (arr) <> 4)
		  return ods_serialize_sql_error ('37000', 'The item is not found');
    contact_id := atoi (arr[3]);
  }
	inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);
	if (not ods_check_auth (uname, inst_id, 'author'))
		return ods_auth_failed ();

	if (not exists (select 1 from AB.WA.PERSONS where P_ID = contact_id))
		return ods_serialize_sql_error ('37000', 'The item is not found');

  relationships := (select P_RELATIONSHIPS from AB.WA.PERSONS where P_ID = contact_id);
  tmp := vector ();
  new_relationships := '';
  for (select _relationship from DB.DBA.WA_USER_INTERESTS (txt) (_relationship varchar) P where txt = relationships) do
  {
    new_relationships := new_relationships || _relationship || '\n';
    tmp := vector_concat (tmp, vector (_relationship));
  }
  if (not AB.WA.vector_contains (tmp, relationship))
    new_relationships := new_relationships || relationship || '\n';

  if (relationships <> new_relationships)
    AB.WA.contact_update2 (contact_id, inst_id, 'P_RELATIONSHIPS', new_relationships);

	return ods_serialize_int_res (contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.relationship.delete" (
	in contact any,
	in relationship varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare rc integer;
	declare uname varchar;
	declare inst_id, contact_id integer;
	declare arr, relationships, new_relationships, _relationship any;

  if (atoi (contact) <> 0)
  {
    contact_id := atoi (contact);
  } else {
    arr := sprintf_inverse (contact, 'http://%s/dataspace/%s/addressbook/%s/%s', 1);
    if (length (arr) <> 4)
		  return ods_serialize_sql_error ('37000', 'The item is not found');
    contact_id := atoi (arr[3]);
  }
	inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);
	if (not ods_check_auth (uname, inst_id, 'author'))
		return ods_auth_failed ();

	if (not exists (select 1 from AB.WA.PERSONS where P_ID = contact_id))
		return ods_serialize_sql_error ('37000', 'The item is not found');

  relationships := (select P_RELATIONSHIPS from AB.WA.PERSONS where P_ID = contact_id);
  new_relationships := '';
  for (select _relationship from DB.DBA.WA_USER_INTERESTS (txt) (_relationship varchar) P where txt = relationships) do
  {
    if (relationship <> _relationship)
      new_relationships := new_relationships || _relationship || '\n';
  }
  if (relationships <> new_relationships)
    AB.WA.contact_update2 (contact_id, inst_id, 'P_RELATIONSHIPS', new_relationships);

	return ods_serialize_int_res (contact_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.import" (
  in inst_id integer,
  in source varchar,
  in sourceType varchar := 'url',
  in contentType varchar := 'vcard',
  in tags varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname, passwd varchar;
  declare content varchar;
  declare tmp any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  dbg_obj_print ('', now());
	sourceType := lcase(sourceType);
	if (sourceType = 'string')
  {
    content := source;
  }
	else if (sourceType = 'webdav')
  {
    passwd := __user_password (uname);
    content := AB.WA.dav_content (AB.WA.host_url () || http_physical_path_resolve (replace (source, ' ', '%20')), uname, passwd);
  }
	else if (sourceType = 'url')
  {
    content := source;
  }
  else
  {
	  signal ('AB106', 'The source type must be string, WebDAV or URL.');
  }

  tags := trim (tags);
  AB.WA.test (tags, vector ('name', 'Tags', 'class', 'tags'));
  tmp := AB.WA.tags2vector (tags);
  tmp := AB.WA.vector_unique (tmp);
  tags := AB.WA.vector2tags (tmp);

  -- import content
  if (DB.DBA.is_empty_or_null (content))
    signal ('AB107', 'Bad import source!');

  set_user_id ('dba');
	contentType := lcase(contentType);
	dbg_obj_print ('contentType', contentType);
	if (contentType = 'vcard')
  {
    AB.WA.import_vcard (inst_id, content, vector ('tags', tags));
  }
	else if (contentType = 'foaf')
  {
	  dbg_obj_princ ('', inst_id, content, vector ('tags', tags, 'contentType', case when (sourceType = 'url') then 1 else 0 end));
		AB.WA.import_foaf (inst_id, content, vector ('tags', tags, 'contentType', case when (sourceType = 'url') then 1 else 0 end));
  }
  else
  {
  	signal ('AB105', 'The content type must be vCard or FOAF.');
  }
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.export" (
  in inst_id integer,
  in contentType varchar := 'vcard') __soap_http 'text/plain'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  if (lcase (contentType) = 'vcard')
  {
    http (AB.WA.export_vcard (inst_id));
  }
  else if (lcase (contentType) = 'foaf')
  {
    http (AB.WA.export_foaf (inst_id));
  }
  else if (lcase(contentType) = 'csv')
  {
    -- CSV
    http (AB.WA.export_csv_head ());
    http (AB.WA.export_csv (inst_id));
  }
  else
  {
  	signal ('AB104', 'The content type must be vCard, FOAF or CSV.');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.annotation.get" (
  in annotation_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id, contact_id integer;
  declare uname varchar;

  whenever not found goto _exit;

  select A_DOMAIN_ID, A_OBJECT_ID into inst_id, contact_id from AB.WA.ANNOTATIONS where A_ID = annotation_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

	ods_describe_iri (SIOC..addressbook_annotation_iri (inst_id, contact_id, annotation_id));
_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.annotation.new" (
  in contact_id integer,
  in author varchar,
  in body varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;

  rc := -1;
  inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);
  if (isnull (inst_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  insert into AB.WA.ANNOTATIONS (A_DOMAIN_ID, A_OBJECT_ID, A_BODY, A_AUTHOR, A_CREATED, A_UPDATED)
    values (inst_id, contact_id, body, author, now (), now ());
  rc := (select max (A_ID) from AB.WA.ANNOTATIONS);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.annotation.claim" (
  in annotation_id integer,
  in claimRelation varchar,
  in claimValue varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;
  declare claims any;

  rc := -1;
  inst_id := (select A_DOMAIN_ID from AB.WA.ANNOTATIONS where A_ID = annotation_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.ANNOTATIONS where A_ID = annotation_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  claims := (select deserialize (A_CLAIMS) from AB.WA.ANNOTATIONS where A_ID = annotation_id);
	claims := vector_concat (claims, vector (vector (null, claimRelation, claimValue)));
  update AB.WA.ANNOTATIONS
     set A_CLAIMS = serialize (claims),
         A_UPDATED = now ()
   where A_ID = annotation_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.annotation.delete" (
  in annotation_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;

  rc := -1;
  inst_id := (select A_DOMAIN_ID from AB.WA.ANNOTATIONS where A_ID = annotation_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.ANNOTATIONS where A_ID = annotation_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from AB.WA.ANNOTATIONS where A_ID = annotation_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.comment.get" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id, contact_id integer;

  whenever not found goto _exit;

  select PC_DOMAIN_ID, PC_PERSON_ID into inst_id, contact_id from AB.WA.PERSON_COMMENTS where PC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

	ods_describe_iri (SIOC..addressbook_comment_iri (inst_id, cast (contact_id as integer), comment_id));
_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.comment.new" (
  in contact_id integer,
  in parent_id integer := null,
  in title varchar,
  in text varchar,
  in name varchar,
  in email varchar,
  in url varchar := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select P_DOMAIN_ID from AB.WA.PERSONS where P_ID = contact_id);

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  if (not (AB.WA.discussion_check () and AB.WA.conversation_enable (inst_id)))
    return signal('API01', 'Discussions must be enabled for this instance');

  if (isnull (parent_id))
  {
    -- get root comment;
    parent_id := (select PC_ID from AB.WA.PERSON_COMMENTS where PC_DOMAIN_ID = inst_id and PC_PERSON_ID = contact_id and PC_PARENT_ID is null);
    if (isnull (parent_id))
    {
      AB.WA.nntp_root (inst_id, contact_id);
      parent_id := (select PC_ID from AB.WA.PERSON_COMMENTS where PC_DOMAIN_ID = inst_id and PC_PERSON_ID = contact_id and PC_PARENT_ID is null);
    }
  }

  AB.WA.nntp_update_item (inst_id, contact_id);
  insert into AB.WA.PERSON_COMMENTS (PC_PARENT_ID, PC_DOMAIN_ID, PC_PERSON_ID, PC_TITLE, PC_COMMENT, PC_U_NAME, PC_U_MAIL, PC_U_URL, PC_UPDATED)
    values (parent_id, inst_id, contact_id, title, text, name, email, url, now ());
  rc := (select max (PC_ID) from AB.WA.PERSON_COMMENTS);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.comment.delete" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select PC_DOMAIN_ID from AB.WA.PERSON_COMMENTS where PC_ID = comment_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.PERSON_COMMENTS where PC_ID = comment_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from AB.WA.PERSON_COMMENTS where PC_ID = comment_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.publication.new" (
  in inst_id integer,
  in name varchar,
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
	in destinationType varchar := null,
  in destination varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in tagsInclude varchar := '',
  in tagsExclude varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _type, options any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  _type := ODS.ODS_API.addressbook_type_check (destinationType, destination);
	options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
	insert into AB.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
		values (inst_id, 0, name, updateType, updatePeriod, updateFreq, serialize (options));
	rc := (select max (EX_ID) from AB.WA.EXCHANGE);

	return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.publication.get" (
  in publication_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;
  declare options any;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from AB.WA.EXCHANGE where EX_ID = publication_id) do
  {
    options := deserialize (EX_OPTIONS);
    http (sprintf ('<publication id="%d">\r\n', publication_id));

    http (sprintf ('  <name>%V</name>\r\n', EX_NAME));
    if (EX_UPDATE_TYPE = 0)
  {
      http ('  <updateType>manually</updateType>\r\n');
  }
    else if (EX_UPDATE_TYPE = 1)
  {
      http ('  <updateType>after any entry is changed</updateType>\r\n');
  }
  else
  {
      http (sprintf ('  <updatePeriod>%s</updatePeriod>\r\n', EX_UPDATE_PERIOD));
      http (sprintf ('  <updateFreq>%s</updateFreq>\r\n', cast (EX_UPDATE_FREQ as varchar)));
  }
    http (sprintf ('  <destinationType>%V</destinationType>\r\n', get_keyword (get_keyword ('type', options, 1), vector (1, 'WebDAV', 2, 'URL'))));
    http (sprintf ('  <destination>%V</destination>\r\n', get_keyword ('name', options)));
    if (get_keyword ('user', options, '') <> '')
    {
      http (sprintf ('  <userName>%V</userName>\r\n', get_keyword ('user', options)));
      http ('  <userPassword>******</userName>\r\n');
    }
    http ('  <options>\r\n');
    if (get_keyword ('tagsInclude', options, '') <> '')
      http (sprintf ('    <tagsInclude>%s</tagsInclude>\r\n', cast (get_keyword ('tagsInclude', options) as varchar)));
    if (get_keyword ('tagsExclude', options, '') <> '')
      http (sprintf ('    <tagsExclude>%s</tagsExclude>\r\n', cast (get_keyword ('tagsExclude', options) as varchar)));
    http ('  </options>\r\n');

    http ('</publication>');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.publication.edit" (
  in publication_id integer,
  in name varchar,
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
	in destinationType varchar := null,
  in destination varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in tagsInclude varchar := '',
  in tagsExclude varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare _type, options any;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = publication_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  _type := ODS.ODS_API.addressbook_type_check (destinationType, destination);
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  update AB.WA.EXCHANGE
     set EX_NAME = name,
         EX_UPDATE_TYPE = updateType,
         EX_UPDATE_PERIOD = updatePeriod,
         EX_UPDATE_FREQ = updateFreq,
         EX_OPTIONS = serialize (options)
   where EX_ID = publication_id;

  return ods_serialize_int_res (publication_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.publication.sync" (
  in publication_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname, syncLog varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  AB.WA.exchange_exec (publication_id);
  syncLog := (select EX_EXEC_LOG from AB.WA.EXCHANGE where EX_ID = publication_id);
  if (not DB.DBA.is_empty_or_null (syncLog))
    return ods_serialize_sql_error ('ERROR', syncLog);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.publication.delete" (
  in publication_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = publication_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from AB.WA.EXCHANGE where EX_ID = publication_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.subscription.new" (
  in inst_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
	in sourceType varchar := null,
  in source varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in tagsInclude varchar := '',
  in tagsExclude varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _type, options any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  _type := ODS.ODS_API.addressbook_type_check (sourceType, source);
	options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
	insert into AB.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
		values (inst_id, 1, name, updateType, updatePeriod, updateFreq, serialize (options));
	rc := (select max (EX_ID) from AB.WA.EXCHANGE);

	return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.subscription.get" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;
  declare options any;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from AB.WA.EXCHANGE where EX_ID = subscription_id) do
  {
    options := deserialize (EX_OPTIONS);
    http (sprintf ('<publication id="%d">\r\n', subscription_id));

    http (sprintf ('  <name>%V</name>\r\n', EX_NAME));
    if (EX_UPDATE_TYPE = 0)
  {
      http ('  <updateType>manually</updateType>\r\n');
  }
    else if (EX_UPDATE_TYPE = 1)
  {
      http ('  <updateType>after any entry is changed</updateType>\r\n');
  }
  else
  {
      http (sprintf ('  <updatePeriod>%s</updatePeriod>\r\n', EX_UPDATE_PERIOD));
      http (sprintf ('  <updateFreq>%s</updateFreq>\r\n', cast (EX_UPDATE_FREQ as varchar)));
  }
    http (sprintf ('  <sourceType>%V</sourceType>\r\n', get_keyword (get_keyword ('type', options, 1), vector (1, 'WebDAV', 2, 'URL'))));
    http (sprintf ('  <source>%V</source>\r\n', get_keyword ('name', options)));
    if (get_keyword ('user', options, '') <> '')
    {
      http (sprintf ('  <userName>%V</userName>\r\n', get_keyword ('user', options)));
      http ('  <userPassword>******</userName>\r\n');
    }
    http ('  <options>\r\n');
    if (get_keyword ('tagsInclude', options, '') <> '')
      http (sprintf ('    <tagsInclude>%s</tagsInclude>\r\n', cast (get_keyword ('tagsInclude', options) as varchar)));
    if (get_keyword ('tagsExclude', options, '') <> '')
      http (sprintf ('    <tagsExclude>%s</tagsExclude>\r\n', cast (get_keyword ('tagsExclude', options) as varchar)));
    http ('  </options>\r\n');

    http ('</publication>');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.subscription.edit" (
  in subscription_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
	in sourceType varchar := null,
  in source varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in tagsInclude varchar := '',
  in tagsExclude varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare _type, options any;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = subscription_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  _type := ODS.ODS_API.addressbook_type_check (sourceType, source);
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  update AB.WA.EXCHANGE
     set EX_NAME = name,
         EX_UPDATE_TYPE = updateType,
         EX_UPDATE_PERIOD = updatePeriod,
         EX_UPDATE_FREQ = updateFreq,
         EX_OPTIONS = serialize (options)
   where EX_ID = subscription_id;

  return ods_serialize_int_res (subscription_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.subscription.sync" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname, syncLog varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  AB.WA.exchange_exec (subscription_id);
  syncLog := (select EX_EXEC_LOG from AB.WA.EXCHANGE where EX_ID = subscription_id);
  if (not DB.DBA.is_empty_or_null (syncLog))
    return ods_serialize_sql_error ('ERROR', syncLog);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.subscription.delete" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from AB.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from AB.WA.EXCHANGE where EX_ID = subscription_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from AB.WA.EXCHANGE where EX_ID = subscription_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.options.set" (
	in inst_id integer := null,
	in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, account_id integer;
  declare conv, f_conv, f_conv_init any;
  declare uname varchar;
  declare optionsParams, settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := AB.WA.settings (inst_id);
  AB.WA.settings_init (settings);
  conv := cast (get_keyword ('conv', settings, '0') as integer);

  ODS.ODS_API.addressbook_setting_set (settings, optionsParams, 'chars');
  ODS.ODS_API.addressbook_setting_set (settings, optionsParams, 'rows', vector ('name', 'Rows per page', 'class', 'integer', 'type', 'integer', 'minValue', 1, 'maxValue', 1000));
  ODS.ODS_API.addressbook_setting_set (settings, optionsParams, 'tbLabels');
  ODS.ODS_API.addressbook_setting_set (settings, optionsParams, 'atomVersion');
	if (AB.WA.discussion_check ())
	{
  ODS.ODS_API.addressbook_setting_set (settings, optionsParams, 'conv');
  ODS.ODS_API.addressbook_setting_set (settings, optionsParams, 'conv_init');
  }
	insert replacing AB.WA.SETTINGS (S_DOMAIN_ID, S_ACCOUNT_ID, S_DATA)
	  values (inst_id, account_id, serialize (settings));

  f_conv := cast (get_keyword ('conv', settings, '0') as integer);
  f_conv_init := cast (get_keyword ('conv_init', settings, '0') as integer);
	if (AB.WA.discussion_check ())
	{
	  AB.WA.nntp_update (inst_id, null, null, conv, f_conv);
		if (f_conv and f_conv_init)
	    AB.WA.nntp_fill (inst_id);
	}

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.options.get" (
	in inst_id integer := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'AddressBook'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  settings := AB.WA.settings (inst_id);
  AB.WA.settings_init (settings);

  http ('<settings>');
  http (ODS.ODS_API.addressbook_setting_xml (settings, 'chars'));
  http (ODS.ODS_API.addressbook_setting_xml (settings, 'rows'));
  http (ODS.ODS_API.addressbook_setting_xml (settings, 'tbLabels'));
  http (ODS.ODS_API.addressbook_setting_xml (settings, 'atomVersion'));
  http (ODS.ODS_API.addressbook_setting_xml (settings, 'conv'));
  http (ODS.ODS_API.addressbook_setting_xml (settings, 'conv_init'));
  http ('</settings>');

  return '';
}
;

grant execute on ODS.ODS_API."addressbook.search" to ODS_API;
grant execute on ODS.ODS_API."addressbook.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.edit" to ODS_API;
grant execute on ODS.ODS_API."addressbook.delete" to ODS_API;
grant execute on ODS.ODS_API."addressbook.relationship.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.relationship.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.import" to ODS_API;
grant execute on ODS.ODS_API."addressbook.export" to ODS_API;

grant execute on ODS.ODS_API."addressbook.annotation.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.annotation.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.annotation.claim" to ODS_API;
grant execute on ODS.ODS_API."addressbook.annotation.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.comment.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.comment.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.publication.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.publication.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.publication.edit" to ODS_API;
grant execute on ODS.ODS_API."addressbook.publication.sync" to ODS_API;
grant execute on ODS.ODS_API."addressbook.publication.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.subscription.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.edit" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.sync" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.options.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.options.set" to ODS_API;

use DB;
