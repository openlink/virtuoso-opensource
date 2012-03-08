--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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
create procedure ODS.ODS_API.calendar_setting_set (
  inout settings any,
  inout options any,
  in settingName varchar,
  in settingTest any := null)
{
	declare aValue any;

  aValue := get_keyword (settingName, options, get_keyword (settingName, settings));
  if (not isnull (settingTest))
    CAL.WA.test (cast (aValue as varchar), settingTest);
  CAL.WA.set_keyword (settingName, settings, aValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.calendar_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.calendar_type_check (
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
		signal ('CAL106', 'The source type must be WebDAV or URL.');
	}
	return outType;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.get" (
  in event_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id integer;

  inst_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = event_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  ods_describe_iri (SIOC..calendar_event_iri (inst_id, event_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.event.new" (
  in inst_id integer,
  in uid varchar := null,
  in subject varchar,
  in description varchar := null,
  in location varchar := null,
  in attendees varchar := null,
  in privacy integer := 1,
  in tags varchar := '',
  in event integer := 0,
  in eventStart datetime,
  in eventEnd datetime,
  in eRepeat varchar := '',
  in eRepeatParam1 integer := null,
  in eRepeatParam2 integer := null,
  in eRepeatParam3 integer := null,
  in eRepeatUntil datetime := null,
  in eReminder integer := 0,
  in notes varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare cTimezone any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  cTimezone := CAL.WA.settings_usedTimeZone (inst_id);
  eventStart := CAL.WA.event_user2gmt (eventStart, cTimezone);
  eventEnd := CAL.WA.event_user2gmt (eventEnd, cTimezone);

  rc := CAL.WA.event_update (
    -1,
    uid,
    inst_id,
    subject,
    description,
    location,
    attendees,
    privacy,
    tags,
    event,
    eventStart,
    eventEnd,
    eRepeat,
    eRepeatParam1,
    eRepeatParam2,
    eRepeatParam3,
    eRepeatUntil,
    eReminder,
    notes);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.event.edit" (
  in event_id integer,
  in uid varchar := null,
  in subject varchar,
  in description varchar := null,
  in location varchar := null,
  in attendees varchar := null,
  in privacy integer := 1,
  in tags varchar := '',
  in event integer := 1,
  in eventStart datetime,
  in eventEnd datetime,
  in eRepeat varchar := '',
  in eRepeatParam1 integer := null,
  in eRepeatParam2 integer := null,
  in eRepeatParam3 integer := null,
  in eRepeatUntil datetime := null,
  in eReminder integer := 0,
  in notes varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare cTimezone any;

  inst_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = event_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  cTimezone := CAL.WA.settings_usedTimeZone (inst_id);
  eventStart := CAL.WA.event_user2gmt (eventStart, cTimezone);
  eventEnd := CAL.WA.event_user2gmt (eventEnd, cTimezone);

  rc := CAL.WA.event_update (
          event_id,
          uid,
          inst_id,
          subject,
          description,
          location,
          attendees,
          privacy,
          tags,
          event,
          eventStart,
          eventEnd,
          eRepeat,
          eRepeatParam1,
          eRepeatParam2,
          eRepeatParam3,
          eRepeatUntil,
          eReminder,
          notes);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.task.new" (
  in inst_id integer,
  in uid varchar := null,
  in subject varchar,
  in description varchar := null,
  in attendees varchar := null,
  in privacy integer := 1,
  in tags varchar := '',
  in eventStart datetime,
  in eventEnd datetime,
  in priority integer := 3,
  in status varchar := 'Not Started',
  in complete integer := 0,
  in completed datetime := null,
  in notes varchar := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare cTimezone any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  cTimezone := CAL.WA.settings_usedTimeZone (inst_id);
  eventStart := CAL.WA.event_user2gmt (CAL.WA.dt_join (CAL.WA.dt_dateClear (eventStart), CAL.WA.dt_timeEncode (12, 0)), cTimezone);
  eventEnd := CAL.WA.event_user2gmt (CAL.WA.dt_join (CAL.WA.dt_dateClear (eventEnd), CAL.WA.dt_timeEncode (12, 0)), cTimezone);

  rc := CAL.WA.task_update (
          -1,
          uid,
          inst_id,
          subject,
          description,
          attendees,
          privacy,
          tags,
          eventStart,
          eventEnd,
          priority,
          status,
          complete,
          completed,
          notes);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.task.edit" (
  in event_id integer,
  in uid varchar := null,
  in subject varchar,
  in description varchar := null,
  in attendees varchar := null,
  in privacy integer := 1,
  in tags varchar := '',
  in eventStart datetime,
  in eventEnd datetime,
  in priority integer := 3,
  in status varchar := 'Not Started',
  in complete integer := 0,
  in completed datetime := null,
  in notes varchar := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare cTimezone any;

  inst_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = event_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  cTimezone := CAL.WA.settings_usedTimeZone (inst_id);
  eventStart := CAL.WA.event_user2gmt (CAL.WA.dt_join (CAL.WA.dt_dateClear (eventStart), CAL.WA.dt_timeEncode (12, 0)), cTimezone);
  eventEnd := CAL.WA.event_user2gmt (CAL.WA.dt_join (CAL.WA.dt_dateClear (eventEnd), CAL.WA.dt_timeEncode (12, 0)), cTimezone);

  rc := CAL.WA.task_update (
          event_id,
          uid,
          inst_id,
          subject,
          description,
          attendees,
          privacy,
          tags,
          eventStart,
          eventEnd,
          priority,
          status,
          complete,
          completed,
          notes);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.delete" (
  in event_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = event_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EVENTS where E_ID = event_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  rc := CAL.WA.event_delete (event_id);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.import" (
  in inst_id integer,
  in source varchar,
  in sourceType varchar := 'url',
  in userName varchar := null,
  in userPassword varchar := null,
  in events integer := 1,
  in tasks integer := 1,
  in tags varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare content varchar;
  declare tmp any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  if (isnull (userName))
  {
    userName := uname;
    userPassword := __user_password (uname);
  }
  if (lcase (sourceType) = 'string')
  {
    content := source;
  }
  else if (lcase (sourceType) = 'webdav')
  {
    commit work;
    content := CAL.WA.dav_content (CAL.WA.host_url () || http_physical_path_resolve (replace (source, ' ', '%20')), 0, userName, userPassword);
  }
  else if (lcase (sourceType) = 'url')
  {
    commit work;
    content := CAL.WA.dav_content (source, 0, userName, userPassword);
  }
  else
  {
	  signal ('CAL106', 'The source type must be string, WebDAV or URL.');
  }

  tags := trim (tags);
  CAL.WA.test (tags, vector ('name', 'Tags', 'class', 'tags'));
  tmp := CAL.WA.tags2vector (tags);
  tmp := CAL.WA.vector_unique (tmp);
  tags := CAL.WA.vector2tags (tmp);

  -- import content
  if (DB.DBA.is_empty_or_null (content))
    signal ('CAL107', 'Bad import source!');

  CAL.WA.import_vcal (inst_id, content, vector ('events', events, 'tasks', tasks, 'tags', tags));

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.export" (
  in inst_id integer,
  in events integer := 1,
  in tasks integer := 1,
  in periodFrom date := null,
  in periodTo date := null,
  in tagsInclude varchar := null,
  in tagsExclude varchar := null) __soap_http 'text/plain'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  http (CAL.WA.export_vcal (inst_id, null, vector ('events', events, 'tasks', tasks, 'periodFrom', periodFrom, 'periodTo', periodTo, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude)));

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.comment.get" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id, event_id integer;
  declare uname varchar;

  whenever not found goto _exit;

  select EC_DOMAIN_ID, EC_EVENT_ID into inst_id, event_id from CAL.WA.EVENT_COMMENTS where EC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (SIOC..calendar_comment_iri (inst_id, cast (event_id as integer), comment_id));
_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.comment.new" (
  in event_id integer,
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

  declare rc, inst_id integer;
  declare uname varchar;

  rc := -1;
  inst_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = event_id);

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  if (not (CAL.WA.discussion_check () and CAL.WA.conversation_enable (inst_id)))
    return signal('API01', 'Discussions must be enabled for this instance');

  if (isnull (parent_id))
  {
    -- get root comment;
    parent_id := (select EC_ID from CAL.WA.EVENT_COMMENTS where EC_DOMAIN_ID = inst_id and EC_EVENT_ID = event_id and EC_PARENT_ID is null);
    if (isnull (parent_id))
    {
      CAL.WA.nntp_root (inst_id, event_id);
      parent_id := (select EC_ID from CAL.WA.EVENT_COMMENTS where EC_DOMAIN_ID = inst_id and EC_EVENT_ID = event_id and EC_PARENT_ID is null);
    }
  }

  CAL.WA.nntp_update_item (inst_id, event_id);
  insert into CAL.WA.EVENT_COMMENTS (EC_PARENT_ID, EC_DOMAIN_ID, EC_EVENT_ID, EC_TITLE, EC_COMMENT, EC_U_NAME, EC_U_MAIL, EC_U_URL, EC_UPDATED)
    values (parent_id, inst_id, event_id, title, text, name, email, url, now ());
  rc := (select max (EC_ID) from CAL.WA.EVENT_COMMENTS);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.comment.delete" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;

  rc := -1;
  inst_id := (select EC_DOMAIN_ID from CAL.WA.EVENT_COMMENTS where EC_ID = comment_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EVENT_COMMENTS where EC_ID = comment_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from CAL.WA.EVENT_COMMENTS where EC_ID = comment_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.annotation.get" (
  in annotation_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id, event_id integer;
  declare uname varchar;
  declare q, iri varchar;

  whenever not found goto _exit;

  select A_DOMAIN_ID, A_OBJECT_ID into inst_id, event_id from CAL.WA.ANNOTATIONS where A_ID = annotation_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (SIOC..calendar_annotation_iri (inst_id, event_id, annotation_id));
_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.annotation.new" (
  in event_id integer,
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
  inst_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = event_id);
  if (isnull (inst_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  insert into CAL.WA.ANNOTATIONS (A_DOMAIN_ID, A_OBJECT_ID, A_BODY, A_AUTHOR, A_CREATED, A_UPDATED)
    values (inst_id, event_id, body, author, now (), now ());
  rc := (select max (A_ID) from CAL.WA.ANNOTATIONS);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.annotation.claim" (
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
  inst_id := (select A_DOMAIN_ID from CAL.WA.ANNOTATIONS where A_ID = annotation_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  claims := (select deserialize (A_CLAIMS) from CAL.WA.ANNOTATIONS where A_ID = annotation_id);
  claims := vector_concat (claims, vector (vector (claimIri, claimRelation, claimValue)));
  update CAL.WA.ANNOTATIONS
     set A_CLAIMS = serialize (claims),
         A_UPDATED = now ()
   where A_ID = annotation_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.annotation.delete" (
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
  inst_id := (select A_DOMAIN_ID from CAL.WA.ANNOTATIONS where A_ID = annotation_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.ANNOTATIONS where A_ID = annotation_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from CAL.WA.ANNOTATIONS where A_ID = annotation_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.publication.new" (
  in inst_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
  in destinationType varchar := null,
  in destination varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in events integer := 1,
  in tasks integer := 1) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _type, _name, _permissions, options any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  _type := ODS.ODS_API.calendar_type_check (destinationType, destination);
  _name := trim (destination);
  if (_type = 1)
  {
    _name := '/' || _name;
    _name := replace (_name, '//', '/');
  }
  _name := ODS..dav_path_normalize(_name);
  if (_type = 1)
  {
    _name := CAL.WA.dav_parent (_name);
    _permissions := '11_';
    if (not CAL.WA.dav_check_authenticate (_name, userName, userPassword, _permissions))
      signal ('TEST', 'The user has no rights for this folder.<>');
  }
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'events', events, 'tasks', tasks);
  insert into CAL.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 0, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from CAL.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.publication.get" (
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

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from CAL.WA.EXCHANGE where EX_ID = publication_id) do
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
      http (sprintf ('    <events>%s</events>\r\n', cast (get_keyword ('events', options, 1) as varchar)));
      http (sprintf ('    <tasks>%s</tasks>\r\n', cast (get_keyword ('tasks', options, 1) as varchar)));
    http ('  </options>\r\n');

    http ('</publication>');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.publication.edit" (
  in publication_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
  in destinationType varchar := null,
  in destination varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in events integer := 1,
  in tasks integer := 1) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare _type, _name, _permissions, options any;

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  _type := ODS.ODS_API.calendar_type_check (destinationType, destination);
  _name := trim (destination);
  if (_type = 1)
  {
    _name := '/' || _name;
    _name := replace (_name, '//', '/');
  }
  _name := ODS..dav_path_normalize(_name);
  if (_type = 1)
  {
    _name := CAL.WA.dav_parent (_name);
    _permissions := '11_';
    if (not CAL.WA.dav_check_authenticate (_name, userName, userPassword, _permissions))
      signal ('TEST', 'The user has no rights for this folder.<>');
  }
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'events', events, 'tasks', tasks);
  update CAL.WA.EXCHANGE
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
create procedure ODS.ODS_API."calendar.publication.sync" (
  in publication_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id integer;
  declare uname, syncLog varchar;

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  CAL.WA.exchange_exec (publication_id);
  syncLog := (select EX_EXEC_LOG from CAL.WA.EXCHANGE where EX_ID = publication_id);
  if (not DB.DBA.is_empty_or_null (syncLog))
    return ods_serialize_sql_error ('ERROR', syncLog);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.publication.delete" (
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

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  delete from CAL.WA.EXCHANGE where EX_ID = publication_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.subscription.new" (
  in inst_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
  in sourceType varchar := null,
  in source varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in events integer := 1,
  in tasks integer := 1) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _type, _name, _permissions, options any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  _type := ODS.ODS_API.calendar_type_check (sourceType, source);
  _name := trim (source);
  if (_type = 1)
  {
    _name := '/' || _name;
    _name := replace (_name, '//', '/');
  }
  _name := ODS..dav_path_normalize(_name);
  if (_type = 1)
  {
    _name := CAL.WA.dav_parent (_name);
    _permissions := '1__';
    if (not CAL.WA.dav_check_authenticate (_name, userName, userPassword, _permissions))
      signal ('TEST', 'The user has no rights for this folder.<>');
  }
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'events', events, 'tasks', tasks);
  insert into CAL.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 1, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from CAL.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.subscription.get" (
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

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from CAL.WA.EXCHANGE where EX_ID = subscription_id) do
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
      http (sprintf ('    <events>%s</events>\r\n', cast (get_keyword ('events', options, 1) as varchar)));
      http (sprintf ('    <tasks>%s</tasks>\r\n', cast (get_keyword ('tasks', options, 1) as varchar)));
    http ('  </options>\r\n');

    http ('</publication>');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.subscription.edit" (
  in subscription_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
  in sourceType varchar := null,
  in source varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in events integer := 1,
  in tasks integer := 1) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare _type, _name, _permissions, options any;

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  _type := ODS.ODS_API.calendar_type_check (sourceType, source);
  _name := trim (source);
  if (_type = 1)
  {
    _name := '/' || _name;
    _name := replace (_name, '//', '/');
  }
  _name := ODS..dav_path_normalize(_name);
  if (_type = 1)
  {
    _name := CAL.WA.dav_parent (_name);
    _permissions := '1__';
    if (not CAL.WA.dav_check_authenticate (_name, userName, userPassword, _permissions))
      signal ('TEST', 'The user has no rights for this folder.<>');
  }
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'events', events, 'tasks', tasks);
  update CAL.WA.EXCHANGE
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
create procedure ODS.ODS_API."calendar.subscription.sync" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id integer;
  declare uname, syncLog varchar;

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  CAL.WA.exchange_exec (subscription_id);
  syncLog := (select EX_EXEC_LOG from CAL.WA.EXCHANGE where EX_ID = subscription_id);
  if (not DB.DBA.is_empty_or_null (syncLog))
    return ods_serialize_sql_error ('ERROR', syncLog);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.subscription.delete" (
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

  inst_id := (select EX_DOMAIN_ID from CAL.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  delete from CAL.WA.EXCHANGE where EX_ID = subscription_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.upstream.new" (
  in inst_id integer,
  in name varchar,
  in source varchar,
  in userName varchar,
  in userPassword varchar,
  in tagsInclude varchar := null,
  in tagsExclude varchar := null) __soap_http 'text/plain'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare tmp any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  CAL.WA.test (name, vector('name', 'Upstream Name', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (source, vector('name', 'Upstream URI', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (userName, vector('name', 'Upstream User', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (userPassword, vector('name', 'Upstream Password', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (tagsInclude, vector ('name', 'Include Tags', 'class', 'tags'));
  tmp := CAL.WA.tags2vector (tagsInclude);
  tmp := CAL.WA.vector_unique (tmp);
  tagsInclude := CAL.WA.vector2tags (tmp);
  CAL.WA.test (tagsExclude, vector ('name', 'Exclude Tags', 'class', 'tags'));
  tmp := CAL.WA.tags2vector (tagsExclude);
  tmp := CAL.WA.vector_unique (tmp);
  tagsExclude := CAL.WA.vector2tags (tmp);

  insert into CAL.WA.UPSTREAM (U_DOMAIN_ID, U_NAME, U_URI, U_USER, U_PASSWORD, U_INCLUDE, U_EXCLUDE)
    values (inst_id, name, source, userName, userPassword, tagsInclude, tagsExclude);
  rc := (select max (U_ID) from CAL.WA.UPSTREAM);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.upstream.edit" (
  in upstream_id integer,
  in name varchar,
  in source varchar,
  in userName varchar,
  in userPassword varchar,
  in tagsInclude varchar := null,
  in tagsExclude varchar := null) __soap_http 'text/plain'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare tmp any;

  inst_id := (select U_DOMAIN_ID from CAL.WA.UPSTREAM where U_ID = upstream_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.UPSTREAM where U_ID = upstream_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  CAL.WA.test (name, vector('name', 'Upstream Name', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (source, vector('name', 'Upstream URI', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (userName, vector('name', 'Upstream User', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (userPassword, vector('name', 'Upstream Password', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  CAL.WA.test (tagsInclude, vector ('name', 'Include Tags', 'class', 'tags'));
  tmp := CAL.WA.tags2vector (tagsInclude);
  tmp := CAL.WA.vector_unique (tmp);
  tagsInclude := CAL.WA.vector2tags (tmp);
  CAL.WA.test (tagsExclude, vector ('name', 'Exclude Tags', 'class', 'tags'));
  tmp := CAL.WA.tags2vector (tagsExclude);
  tmp := CAL.WA.vector_unique (tmp);
  tagsExclude := CAL.WA.vector2tags (tmp);

  update CAL.WA.UPSTREAM
     set U_NAME = name,
         U_URI = source,
         U_USER = userName,
         U_PASSWORD = userPassword,
         U_INCLUDE = tagsInclude,
         U_EXCLUDE = tagsExclude
   where U_ID = upstream_id;

  return ods_serialize_int_res (upstream_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.upstream.delete" (
  in upstream_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select U_DOMAIN_ID from CAL.WA.UPSTREAM where U_ID = upstream_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from CAL.WA.UPSTREAM where U_ID = upstream_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  delete from CAL.WA.UPSTREAM where U_ID = upstream_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.options.set" (
  in inst_id int, in options any) __soap_http 'text/xml'
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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := CAL.WA.settings (inst_id);
  CAL.WA.settings_init (settings);
  conv := cast (get_keyword ('conv', settings, '0') as integer);

  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'chars');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'rows', vector ('name', 'Rows per page', 'class', 'integer', 'type', 'integer', 'minValue', 1, 'maxValue', 1000));
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'atomVersion');

  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'defaultView');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'weekStarts');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'timeFormat');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'dateFormat');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'timeZone');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'showTasks');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'daylichtEnable');
	if (CAL.WA.discussion_check ())
	{
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'conv');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'conv_init');
  }

  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'event_E_UPDATED');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'event_E_CREATED');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'event_E_LOCATION');

  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_STATUS');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_PRIORITY');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_START');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_END');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_COMPLETED');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_UPDATED');
  ODS.ODS_API.calendar_setting_set (settings, optionsParams, 'task_E_CREATED');

  insert replacing CAL.WA.SETTINGS (S_DOMAIN_ID, S_ACCOUNT_ID, S_DATA)
    values (inst_id, account_id, serialize (settings));

  f_conv := cast (get_keyword ('conv', settings, '0') as integer);
  f_conv_init := cast (get_keyword ('conv_init', settings, '0') as integer);
	if (CAL.WA.discussion_check ())
	{
	  CAL.WA.nntp_update (inst_id, null, null, conv, f_conv);
		if (f_conv and f_conv_init)
	    CAL.WA.nntp_fill (inst_id);
	}

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."calendar.options.get" (
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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Calendar'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  settings := CAL.WA.settings (inst_id);
  CAL.WA.settings_init (settings);

  http ('<settings>');

  http (ODS.ODS_API.calendar_setting_xml (settings, 'chars'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'rows'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'atomVersion'));

  http (ODS.ODS_API.calendar_setting_xml (settings, 'defaultView'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'weekStarts'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'timeFormat'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'dateFormat'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'timeZone'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'showTasks'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'daylichEnable'));

  http (ODS.ODS_API.calendar_setting_xml (settings, 'conv'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'conv_init'));

  http (ODS.ODS_API.calendar_setting_xml (settings, 'event_E_UPDATED'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'event_E_CREATED'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'event_E_LOCATION'));

  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_STATUS'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_PRIORITY'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_START'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_END'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_COMPLETED'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_UPDATED'));
  http (ODS.ODS_API.calendar_setting_xml (settings, 'task_E_CREATED'));

  http ('</settings>');

  return '';
}
;

grant execute on ODS.ODS_API."calendar.get" to ODS_API;
grant execute on ODS.ODS_API."calendar.event.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.event.edit" to ODS_API;
grant execute on ODS.ODS_API."calendar.task.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.task.edit" to ODS_API;
grant execute on ODS.ODS_API."calendar.delete" to ODS_API;
grant execute on ODS.ODS_API."calendar.import" to ODS_API;
grant execute on ODS.ODS_API."calendar.export" to ODS_API;

grant execute on ODS.ODS_API."calendar.comment.get" to ODS_API;
grant execute on ODS.ODS_API."calendar.comment.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."calendar.annotation.get" to ODS_API;
grant execute on ODS.ODS_API."calendar.annotation.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.annotation.claim" to ODS_API;
grant execute on ODS.ODS_API."calendar.annotation.delete" to ODS_API;

grant execute on ODS.ODS_API."calendar.publication.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.publication.get" to ODS_API;
grant execute on ODS.ODS_API."calendar.publication.edit" to ODS_API;
grant execute on ODS.ODS_API."calendar.publication.sync" to ODS_API;
grant execute on ODS.ODS_API."calendar.publication.delete" to ODS_API;
grant execute on ODS.ODS_API."calendar.subscription.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.subscription.get" to ODS_API;
grant execute on ODS.ODS_API."calendar.subscription.edit" to ODS_API;
grant execute on ODS.ODS_API."calendar.subscription.sync" to ODS_API;
grant execute on ODS.ODS_API."calendar.subscription.delete" to ODS_API;
grant execute on ODS.ODS_API."calendar.upstream.new" to ODS_API;
grant execute on ODS.ODS_API."calendar.upstream.edit" to ODS_API;
grant execute on ODS.ODS_API."calendar.upstream.delete" to ODS_API;

grant execute on ODS.ODS_API."calendar.options.get" to ODS_API;
grant execute on ODS.ODS_API."calendar.options.set" to ODS_API;

use DB;
