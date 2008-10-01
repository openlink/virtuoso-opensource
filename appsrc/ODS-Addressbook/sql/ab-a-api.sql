--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2008 OpenLink Software
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
  iri := SIOC..addressbook_contact_iri (inst_id, contact_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);
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

  rc := AB.WA.contact_update (
          contact_id,
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

  delete from AB.WA.PERSONS where P_ID = contact_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
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

  if (lcase(sourceType) = 'string')
  {
    content := source;
  }
  else if (lcase(sourceType) = 'webdav')
  {
    passwd := __user_password (uname);
    content := AB.WA.dav_content (AB.WA.host_url () || http_physical_path_resolve (replace (source, ' ', '%20')), uname, passwd);
  }
  else if (lcase(sourceType) = 'url')
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

  if (lcase(contentType) = 'vcard')
  {
    AB.WA.import_vcard (inst_id, content, vector ('tags', tags));
  }
  else if (lcase(contentType) = 'foaf')
  {
    AB.WA.import_foaf (inst_id, content, tags, vector (), case when (lcase (sourceType) = 'url') then 1 else 0 end);
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
  declare q, iri varchar;

  whenever not found goto _exit;

  select A_DOMAIN_ID, A_OBJECT_ID into inst_id, contact_id from AB.WA.ANNOTATIONS where A_ID = annotation_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  iri := SIOC..addressbook_annotation_iri (inst_id, contact_id, annotation_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);

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
  in claimIri varchar,
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

  claims := (select deserialize (A_CLAIMS) from AB.WA.ANNOTATIONS where A_ID = annotation_id);
  claims := vector_concat (claims, vector (vector (claimIri, claimRelation, claimValue)));
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
  declare q, iri varchar;

  whenever not found goto _exit;

  select PC_DOMAIN_ID, PC_PERSON_ID into inst_id, contact_id from AB.WA.PERSON_COMMENTS where PC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  iri := SIOC..addressbook_comment_iri (inst_id, cast (contact_id as integer), comment_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);

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
  in url varchar) __soap_http 'text/xml'
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
  rc := row_count ();

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
  in destinationType varchar := 'WebDAV',
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

  if (lcase (destinationType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (destinationType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  insert into AB.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 0, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from AB.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
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
  in destinationType varchar := 'WebDAV',
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

  if (lcase (destinationType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (destinationType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
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
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
  in sourceType varchar := 'WebDAV',
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

  if (lcase (sourceType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (sourceType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  insert into AB.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 1, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from AB.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.ssubscription.edit" (
  in subscription_id integer,
  in name varchar,
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
  in sourceType varchar := 'WebDAV',
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

  if (lcase (sourceType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (sourceType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
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

  delete from AB.WA.EXCHANGE where EX_ID = subscription_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.options.set" (
  in inst_id int, in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, account_id integer;
  declare uname varchar;
  declare optionsParams, settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := AB.WA.settings (inst_id);
  AB.WA.settings_init (settings);
  settings := AB.WA.set_keyword ('chars', settings, get_keyword('chars', optionsParams, get_keyword('chars', settings)));
  settings := AB.WA.set_keyword ('rows', settings, get_keyword('rows', optionsParams, get_keyword('rows', settings)));
  settings := AB.WA.set_keyword ('tbLabels', settings, get_keyword('tbLabels', optionsParams, get_keyword('tbLabels', settings)));
  settings := AB.WA.set_keyword ('atomVersion', settings, get_keyword('atomVersion', optionsParams, get_keyword('atomVersion', settings)));
  settings := AB.WA.set_keyword ('conv', settings, get_keyword('conv', optionsParams, get_keyword('conv', settings)));
  settings := AB.WA.set_keyword ('conv_init', settings, get_keyword('conv_init', optionsParams, get_keyword('conv_init', settings)));
  insert replacing AB.WA.SETTINGS (S_DOMAIN_ID, S_ACCOUNT_ID, S_DATA) values (inst_id, account_id, serialize (settings));

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."addressbook.options.get" (
  in inst_id int) __soap_http 'text/xml'
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

  settings := AB.WA.settings (inst_id);
  AB.WA.settings_init (settings);

  http ('<settings>');
  http (sprintf ('<chars>%d</chars>', get_keyword ('chars', settings)));
  http (sprintf ('<rows>%d</rows>', get_keyword ('rows', settings)));
  http (sprintf ('<tbLabels>%d</tbLabels>', get_keyword ('tbLabels', settings)));
  http (sprintf ('<atomVersion>%s</atomVersion>', get_keyword ('atomVersion', settings)));
  http (sprintf ('<conv>%d</conv>', get_keyword ('conv', settings)));
  http (sprintf ('<conv_init>%d</conv_init>', get_keyword ('conv_init', settings)));
  http ('</settings>');

  return '';
}
;

grant execute on ODS.ODS_API."addressbook.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.edit" to ODS_API;
grant execute on ODS.ODS_API."addressbook.delete" to ODS_API;
grant execute on ODS.ODS_API."addressbook.import" to ODS_API;
grant execute on ODS.ODS_API."addressbook.export" to ODS_API;

grant execute on ODS.ODS_API."addressbook.annotation.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.annotation.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.annotation.claim" to ODS_API;
grant execute on ODS.ODS_API."addressbook.annotation.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.comment.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.comment.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.comment.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.publication.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.publication.edit" to ODS_API;
grant execute on ODS.ODS_API."addressbook.publication.delete" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.new" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.edit" to ODS_API;
grant execute on ODS.ODS_API."addressbook.subscription.delete" to ODS_API;

grant execute on ODS.ODS_API."addressbook.options.get" to ODS_API;
grant execute on ODS.ODS_API."addressbook.options.set" to ODS_API;

use DB;
