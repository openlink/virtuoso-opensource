--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

--!
-- \brief Change a configuration setting on the Calendar app
--/
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

--!
-- \brief A Calendar setting encoded as XML.
--
-- \param settings
-- \param settingName
--/
create procedure ODS.ODS_API.calendar_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

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

--!
-- \brief Get the details of a specific event or task.
--
-- \param event_id The id of the event or task. Event ids are unque across calendar instances.
--
-- \return A set of RDF triples detailing the event or task encoded as RDF+XML.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.get?event_id=3286&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 21:05:58 GMT
-- Accept-Ranges: bytes
-- Content-Type: application/sparql-results+xml
-- Content-Length: 7809
--
-- <?xml version="1.0" encoding="utf-8" ?>
-- <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <sioc:content xmlns:sioc="http://rdfs.org/sioc/ns#">test</sioc:content>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <sioc:has_creator xmlns:sioc="http://rdfs.org/sioc/ns#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo#this"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:description xmlns:n0pred="http://www.w3.org/2002/12/cal#">test</n0pred:description>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <rdf:type rdf:resource="http://atomowl.org/ontologies/atomrdf#Entry"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <rdf:type rdf:resource="http://www.w3.org/2002/12/cal#vevent"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <opl:isDescribedUsing xmlns:opl="http://www.openlinksw.com/schema/attribution#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286/sioc.rdf"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <atom:updated xmlns:atom="http://atomowl.org/ontologies/atomrdf#">2011-05-24T21:01:53Z</atom:updated>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:lastModified xmlns:n0pred="http://www.w3.org/2002/12/cal#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-24T17:01:53-04:00</n0pred:lastModified>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:dtstamp xmlns:n0pred="http://www.w3.org/2002/12/cal#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-24T17:01:53.000004-04:00</n0pred:dtstamp>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <foaf:maker xmlns:foaf="http://xmlns.com/foaf/0.1/" rdf:resource="http://ods-qa.openlinksw.com/dataspace/person/demo#this"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:dtstart xmlns:n0pred="http://www.w3.org/2002/12/cal#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-20T00:00:00-04:00</n0pred:dtstart>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:created xmlns:n0pred="http://www.w3.org/2002/12/cal#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-24T17:01:53-04:00</n0pred:created>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <sioc:id xmlns:sioc="http://rdfs.org/sioc/ns#">ef922cbdd8636f7829a24af90b522cf3</sioc:id>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:url xmlns:n0pred="http://www.w3.org/2002/12/cal#">http://ods-qa.openlinksw.com:80/calendar/148/home.vspx?id=3286</n0pred:url>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <atom:title xmlns:atom="http://atomowl.org/ontologies/atomrdf#">demoevent</atom:title>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:notes xmlns:n0pred="http://www.w3.org/2002/12/cal#"></n0pred:notes>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:class xmlns:n0pred="http://www.w3.org/2002/12/cal#">PUBLIC</n0pred:class>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <sioc:link xmlns:sioc="http://rdfs.org/sioc/ns#" rdf:resource="http://ods-qa.openlinksw.com:80/calendar/148/home.vspx?id=3286"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:dtend xmlns:n0pred="http://www.w3.org/2002/12/cal#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-20T00:00:00-04:00</n0pred:dtend>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:has_services xmlns:n0pred="http://rdfs.org/sioc/services#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/services/calendar/event"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">demoevent</dc:title>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <n0pred:summary xmlns:n0pred="http://www.w3.org/2002/12/cal#">demoevent</n0pred:summary>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <sioc:has_container xmlns:sioc="http://rdfs.org/sioc/ns#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <atom:published xmlns:atom="http://atomowl.org/ontologies/atomrdf#">2011-05-24T21:01:53Z</atom:published>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <atom:author xmlns:atom="http://atomowl.org/ontologies/atomrdf#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/person/demo#this"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <rdfs:label>demoevent</rdfs:label>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-24T17:01:53-04:00</dcterms:modified>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-24T17:01:53-04:00</dcterms:created>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3286#this">
--     <atom:source xmlns:atom="http://atomowl.org/ontologies/atomrdf#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar"/>
--   </rdf:Description>
-- </rdf:RDF>
-- \endverbatim
--/
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
--!
-- \brief Create a new Calendar event.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param uid
-- \param subject The subject/title of the event.
-- \param description The optional description of the event, typically longer than \p subject.
-- \param location
-- \param attendees An optional comma-separated list of email addresses of people working on the event.
-- \param privacy Set the new event to be public \p (1) or private \p (0) or controlled by ACL \p (2). See \ref ods_permissions_acl for details.
-- \param tags An optional comma-separated list of tags to assign to the new event.
-- \param event The type of the event: An all-day event \p (1) or an intervall event \p (0) for which both \p eventStart and \p eventEnd should contain a time.
-- \param eventStart The start of the event as a datetime value. This only requires a time if the type of the event
--                   is set to intervall \p (0). Otherwise only the date is required. See also
--                   <a href="http://docs.openlinksw.com/virtuoso/coredbengine.html#DTTIMESTAMP">Virtuoso TIMESTAMP; DATE & TIME</a>.
-- \param eventEnd The end time of the event. The same rules apply as for \p eventStart.
-- \param eRepeat Sets the event repetition:
-- - An empty value (the default) means no repetition
-- - \p D1 - repeats every Nth day where \p eRepeatParam1 indicates the interval (1 for every day, 3 for every 3rd day, etc.)
-- - \p D2 - repeats every weekday (Monday to Friday)
-- - \p W1 - repeats every Nth week (indicated by \p eRepeatParam1) on the week days indicated by \p eRepeatParam2. This is realized as a bitmask where
--           each day in the week corresponds to one bit. So to specify for example Mon, Tue, and Sat a value of \p 2^0+2^1+2^5=35 needs to be specified as
--           \p eRepeatParam2.
-- - \p M1 - repeats on every Nth day (indicated by \p eRepeatParam1) of the Mth month (indicated by \p eRepeatParam2)
-- - \p M2 - repeats the 1st, 2nd, 3rd, 4th, or last (indicated by 1-5 in \p eRepeatParam1) Mon, Tue, ..., Sun, day, weekday, or weekend (indicated by
--           1-10 in \p eRepeatParam2) of every Nth month (indicated by \p eRepeatParam3).
-- - \p Y1 - repeats every N years (indicated by \p eRepeatParam1) on the month and day indicated by \p eRepeatParam2 and \p eRepeatParam3 respectively.
-- - \p Y2 - repeats the 1st, 2nd, 3rd, 4th, or last (indicated by 1-5 in \p eRepeatParam1) Mon, Tue, ..., Sun, day, weekday, or weekend (indicated by
--           1-10 in \p eRepeatParam2) of the month indicated by \p eRepeatParam3 (Jan to Dec).
-- \param eRepeatParam1 Additional repetition parameter as detailed above.
-- \param eRepeatParam2 Additional repetition parameter as detailed above.
-- \param eRepeatParam3 Additional repetition parameter as detailed above.
-- \param eRepeatUntil An optional datetime when to end the repetition of the event.
-- \param eReminder \p 0 to disable the reminder or the time in seconds of how long before the event the reminder should be shown.
-- \param notes Additional notes on the event. FIXME: what is the difference to description?
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code. If the event
-- was successfully created the error code will match the id of the newly created event.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.event.new?inst_id=148&subject=test_event&description=test&eventStart=2011.05.20&eventEnd=2011.05.20&event=1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 05:23:09 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 60
--
-- <result>
--   <code>2517</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Modify a Calendar event.
--
-- \param event_id The id of the Calendar event. This is returned by calendar.event.new().
-- \param uid
-- \param subject The subject/title of the event.
-- \param description The optional description of the event, typically longer than \p subject.
-- \param location
-- \param attendees An optional comma-separated list of email addresses of people working on the event.
-- \param privacy Set the new event to be public \p (1) or private \p (0) or controlled by ACL \p (2). See \ref ods_permissions_acl for details.
-- \param tags An optional comma-separated list of tags to assign to the new event.
-- \param event The type of the event: An all-day event \p (1) or an intervall event \p (0) for which both \p eventStart and \p eventEnd should contain a time.
-- \param eventStart The start of the event as a datetime value. This only requires a time if the type of the event
--                   is set to intervall \p (0). Otherwise only the date is required. See also
--                   <a href="http://docs.openlinksw.com/virtuoso/coredbengine.html#DTTIMESTAMP">Virtuoso TIMESTAMP; DATE & TIME</a>.
-- \param eventEnd The end time of the event. The same rules apply as for \p eventStart.
-- \param eRepeat Sets the event repetition:
-- - An empty value (the default) means no repetition
-- - \p D1 - repeats every Nth day where \p eRepeatParam1 indicates the interval (1 for every day, 3 for every 3rd day, etc.)
-- - \p D2 - repeats every weekday (Monday to Friday)
-- - \p W1 - repeats every Nth week (indicated by \p eRepeatParam1) on the week days indicated by \p eRepeatParam2. This is realized as a bitmask where
--           each day in the week corresponds to one bit. So to specify for example Mon, Tue, and Sat a value of \p 2^0+2^1+2^5=35 needs to be specified as
--           \p eRepeatParam2.
-- - \p M1 - repeats on every Nth day (indicated by \p eRepeatParam1) of the Mth month (indicated by \p eRepeatParam2)
-- - \p M2 - repeats the 1st, 2nd, 3rd, 4th, or last (indicated by 1-5 in \p eRepeatParam1) Mon, Tue, ..., Sun, day, weekday, or weekend (indicated by
--           1-10 in \p eRepeatParam2) of every Nth month (indicated by \p eRepeatParam3).
-- - \p Y1 - repeats every N years (indicated by \p eRepeatParam1) on the month and day indicated by \p eRepeatParam2 and \p eRepeatParam3 respectively.
-- - \p Y2 - repeats the 1st, 2nd, 3rd, 4th, or last (indicated by 1-5 in \p eRepeatParam1) Mon, Tue, ..., Sun, day, weekday, or weekend (indicated by
--           1-10 in \p eRepeatParam2) of the month indicated by \p eRepeatParam3 (Jan to Dec).
-- \param eRepeatParam1 Additional repetition parameter as detailed above.
-- \param eRepeatParam2 Additional repetition parameter as detailed above.
-- \param eRepeatParam3 Additional repetition parameter as detailed above.
-- \param eRepeatUntil An optional datetime when to end the repetition of the event.
-- \param eReminder \p 0 to disable the reminder or the time in seconds of how long before the event the reminder should be shown.
-- \param notes Additional notes on the event. FIXME: what is the difference to description?
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code. If the event
-- was successfully modified the error code will match the id of the event.
--
-- \sa calendar.event.create()
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.event.edit?event_id=2517&subject=test_event2&description=test2&eventSt
-- art=2011.05.20&eventEnd=2011.06.20&event=1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 05:44:36 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 60
--
-- <result>
--   <code>2517</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Create a new Calendar Task
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param uid
-- \param subject The subject/title of the task.
-- \param description The optional description of the task, typically longer than \p subject.
-- \param attendees An optional comma-separated list of email addresses of people working on the task.
-- \param privacy Set the new task to be public \p (1) or private \p (0) or controlled by ACL \p (2). See \ref ods_permissions_acl for details.
-- \param tags An optional comma-separated list of tags to assign to the new task.
-- \param eventStart The start of the task as a datetime value. See also
--                   <a href="http://docs.openlinksw.com/virtuoso/coredbengine.html#DTTIMESTAMP">Virtuoso TIMESTAMP; DATE & TIME</a>.
-- \param eventEnd The end time of the task. The same rules apply as for \p eventStart.
-- \param priority The priority of the task.
-- - \p 1 - highest,
-- - \p 2 - high
-- - \p 3 - normal,
-- - \p 4 - low
-- - \p 5 - lowest
-- \param status The task status. Can be one of:
-- - \p "Not Started"
-- - \p "In Progress"
-- - \p "Completed"
-- - \p "Waiting"
-- - \p "Deferred"
-- \param complete The completion state as percentage (0%, 25%, 50%, 75%, 100%)
-- \param completed The time when the task has been completed.
-- \param notes Additional optional notes.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code. If the task
-- was successfully created the error code will match the id of the event.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.task.new?inst_id=148&subject=test_task&description=test&eventStart=2011.05.20&eventEnd=2011.05.20&event=1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 05:46:05 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 60
--
-- <result>
--   <code>2518</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Create a new Calendar Task
--
-- \param event_id The id of the Calendar task. This is returned by calendar.task.new().
-- \param uid
-- \param subject The subject/title of the task.
-- \param description The optional description of the task, typically longer than \p subject.
-- \param attendees An optional comma-separated list of email addresses of people working on the task.
-- \param privacy Set the new task to be public \p (1) or private \p (0) or controlled by ACL \p (2). See \ref ods_permissions_acl for details.
-- \param tags An optional comma-separated list of tags to assign to the new task.
-- \param eventStart The start of the task as a datetime value. See also
--                   <a href="http://docs.openlinksw.com/virtuoso/coredbengine.html#DTTIMESTAMP">Virtuoso TIMESTAMP; DATE & TIME</a>.
-- \param eventEnd The end time of the task. The same rules apply as for \p eventStart.
-- \param priority The priority of the task.
-- - \p 1 - highest,
-- - \p 2 - high
-- - \p 3 - normal,
-- - \p 4 - low
-- - \p 5 - lowest
-- \param status The task status. Can be one of:
-- - \p "Not Started"
-- - \p "In Progress"
-- - \p "Completed"
-- - \p "Waiting"
-- - \p "Deferred"
-- \param complete The completion state as percentage (0%, 25%, 50%, 75%, 100%)
-- \param completed The time when the task has been completed.
-- \param notes Additional optional notes.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code. If the task
-- was successfully modified the error code will match the id of the event.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.task.edit?event_id=2518&subject=test_task2&description=test2&eventStart=2011.05.20&eventEnd=2011.06.20&event=1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 05:57:14 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 60
--
-- <result>
--   <code>2518</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete a Calendar event or task.
--
-- \param event_id The id of the event or task to delete.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.delete?event_id=2520&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 05:59:10 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Import an iCal calendar.
--
-- ODS Calendar can import an complete iCal file into a Calendar app instance. This iCal file
-- can be located in the WebDAV tree or at any public URL.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param source The source URL or path depending on the \p sourceType.
-- \param sourceType Can be one of \p "url" or \p "webdav".
-- \param userName Optional user name required to access the source. Defaults to the calling user credentials.
-- \param userPassword Optional password required to access the source. Defaults to the calling user credentials.
-- \param events If \p 1 events will be imported.
-- \param tasks If \p 1 tasks will be imported.
-- \param tags An optional comma-separated list of tags to assign to the imported events and tasks.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.import?inst_id=148&source=http://mysportscal.com/Files_iCal_CSV/iCal_NFL_2010-2011/NFL_2010_complete_season.ics&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 06:29:00 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Export part of the calendar to into iCal.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param events If \p 1 events will be exported.
-- \param tasks If \p 1 tasks will be exported.
-- \param periodFrom Optional start time. If given no events or tasks before that time will be exported.
-- \param periodTo Optional end time. If given no events or tasks after that time will be exported.
-- \param tagsInclude Optional comma-separated list of tags to include in the export. If given only events and tasks
--        tagged thusly will be exported.
-- \param tagsExclude Optional comma-separated list of tags to exclude from the export. If given events and tasks
--        tagged thusly are excluded from the export.
--
-- \return The requested events and tasks encoded in the iCal format.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.export?inst_id=148&events=0&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 06:02:54 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/plain; charset="UTF-8"
-- Content-Length: 15381
--
-- BEGIN:VCALENDAR
-- VERSION:2.0
-- BEGIN:VTIMEZONE
-- TZID:Etc/GMT
-- BEGIN:STANDARD
-- TZOFFSETFROM:+0000
-- TZOFFSETTO:+0000
-- TZNAME:GMT +00:00
-- DTSTART:19700101T000000
-- END:STANDARD
-- END:VTIMEZONE
--
-- BEGIN:VEVENT
-- UID:4A635748-E5B9-11DF-A902-EA37E85308F4@domU-12-31-39-02-F9-62.compute-1.internal
-- URL:http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/1789
-- DTSTAMP:20110520T060254Z
-- CREATED:20101101T130942Z
-- LAST-MODIFIED:20101108T133130Z
-- SUMMARY:test
-- DESCRIPTION:Simple event test.
-- LOCATION:Boston
-- DTSTART;TZID=Etc/GMT:20101101T150000
-- DTEND;TZID=Etc/GMT:20101125T220000
-- BEGIN:VALARM
-- TRIGGER:-PT604800S
-- ACTION:DISPLAY
-- END:VALARM
-- CLASS:SHARED
-- END:VEVENT
--
-- BEGIN:VEVENT
-- UID:event_16344435@meetup.com
-- URL:http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/2470
-- DTSTAMP:20110520T060254Z
-- CREATED:20110131T180658Z
-- LAST-MODIFIED:20110131T180600Z
-- SUMMARY:Linked Data Meetup @ Strata Conference
-- DESCRIPTION:Linked Data Meetup
--
-- Santa Clara, CA  95054 - USA
--
-- Wednesday, February 2 at 9:30 PM
--
-- Photo: http://photos2.meetupstatic.com/photos/event/6/0/8/5/event_9084709.jpeg
--
-- Attending: 6
--
-- Details: http://www.meetup.com/linkeddata/events/16344435/
-- LOCATION:Hyatt Regency Santa Clara - 5101 Great American Parkway - Santa Clara, CA  95054 - USA
-- DTSTART;TZID=Etc/GMT:20110203T023000
-- DTEND;TZID=Etc/GMT:20110203T043000
-- CLASS:PUBLIC
-- END:VEVENT
--
-- ....
-- \endverbatim
--/
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
--!
-- \brief Get details of a comment.
--
-- \param comment_id The id of the comment.
--
-- \return The details of the comment encoded as RDF+XML triples.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.comment.get?comment_id=4&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 07:04:08 GMT
-- Accept-Ranges: bytes
-- Content-Type: application/sparql-results+xml
-- Content-Length: 5401
--
-- <?xml version="1.0" encoding="utf-8" ?>
-- <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <sioc:reply_of xmlns:sioc="http://rdfs.org/sioc/ns#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283#this"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <rdf:type rdf:resource="http://rdfs.org/sioc/ns#Item"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <atom:published xmlns:atom="http://atomowl.org/ontologies/atomrdf#">2011-05-20T07:03:15Z</atom:published>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-20T03:03:15.000002-04:00</dcterms:created>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <n0pred:has_services xmlns:n0pred="http://rdfs.org/sioc/services#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/services/calendar/item/comment"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <atom:updated xmlns:atom="http://atomowl.org/ontologies/atomrdf#">2011-05-20T07:03:15Z</atom:updated>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <sioc:has_container xmlns:sioc="http://rdfs.org/sioc/ns#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">test</dc:title>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <rdf:type rdf:resource="http://rdfs.org/sioc/types#Comment"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <rdfs:label>test</rdfs:label>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <atom:source xmlns:atom="http://atomowl.org/ontologies/atomrdf#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <rdf:type rdf:resource="http://rdfs.org/sioc/ns#Post"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <sioc:id xmlns:sioc="http://rdfs.org/sioc/ns#">b207403243d98571a0a72876aa34a0f9</sioc:id>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <foaf:maker xmlns:foaf="http://xmlns.com/foaf/0.1/" rdf:resource="http://openlinksw.com"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-20T03:03:15.000002-04:00</dcterms:modified>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <opl:isDescribedUsing xmlns:opl="http://www.openlinksw.com/schema/attribution#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4/sioc.rdf"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <rdf:type rdf:resource="http://atomowl.org/ontologies/atomrdf#Entry"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <rdf:type rdf:resource="http://www.w3.org/2000/01/rdf-schema#Resource"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <atom:title xmlns:atom="http://atomowl.org/ontologies/atomrdf#">test</atom:title>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <sioc:link xmlns:sioc="http://rdfs.org/sioc/ns#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/4">
--     <sioc:content xmlns:sioc="http://rdfs.org/sioc/ns#">simple</sioc:content>
--   </rdf:Description>
-- </rdf:RDF>
-- \endverbatim
--/
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
--!
-- \brief Create a new comment on an event or task.
--
-- Comments can be put in threads, ie. a comment can have a parent comment. In that
-- case it is considered a reply to the parent comment.
--
-- \param event_id The id of the event or task to comment on.
-- \param parent_id The optional id of the comment the new comment should reply to.
-- \param title The title of the comment.
-- \param text The text body of the comment.
-- \param name The name of the commenter.
-- \param email The email address of the commenter.
-- \param url An optional URL to identify the commenter.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
-- If successful the error code matches the id of the newly created comment.
--
-- \sa calendar.comment.delete
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.comment.new?event_id=3283&title=test&text=simple&name=Kate&email=kate@yahoo.com&url=http://openlinksw.com&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 07:03:15 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>4</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete a comment.
--
-- \param comment_id The numerical id of the comment to delete.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa calendar.comment.new
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.comment.delete?comment_id=4&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 07:07:00 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get details of an annotation.
--
-- \param annotation_id The id of the annotation.
--
-- \return The details of the annotation encoded as RDF+XML triples
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.annotation.get?annotation_id=2&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 06:46:30 GMT
-- Accept-Ranges: bytes
-- Content-Type: application/sparql-results+xml
-- Content-Length: 1943
--
-- <?xml version="1.0" encoding="utf-8" ?>
-- <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/annotation/2">
--     <n0pred:has_services xmlns:n0pred="http://rdfs.org/sioc/services#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/services/calendar/item/annotation"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/annotation/2">
--     <n0pred:annotates xmlns:n0pred="http://www.w3.org/2000/10/annotation-ns#" rdf:resource="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283#this"/>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/annotation/2">
--     <n0pred:body xmlns:n0pred="http://www.w3.org/2000/10/annotation-ns#">test</n0pred:body>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/annotation/2">
--     <n0pred:modifiedxmlns:n0pred="http://www.w3.org/2000/10/annotation-ns#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-20T02:45:24-04:00</n0pred:modified>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/annotation/2">
--     <n0pred:created xmlns:n0pred="http://www.w3.org/2000/10/annotation-ns#" rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">2011-05-20T02:45:24-04:00</n0pred:created>
--   </rdf:Description>
--   <rdf:Description rdf:about="http://ods-qa.openlinksw.com/dataspace/demo/calendar/Demo%20User%27s%20Calendar/Event/3283/annotation/2">
--     <n0pred:author xmlns:n0pred="http://www.w3.org/2000/10/annotation-ns#">John</n0pred:author>
--   </rdf:Description>
-- </rdf:RDF>
-- \endverbatim
--/
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
--!
-- \brief Create a new annotation.
--
-- Calendar events and tasks can be annotated. An annotation is comparable to a comment.
--
-- \param event_id The id of the event or task to annotate.
-- \param author The name of the author of the annotation.
-- \param body The content of the annotation.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
-- If successful the returned error code matches the new annotation's numerical id.
--
-- \sa annotation.delete
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.annotation.new?event_id=3283&author=John&body=test&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 06:45:24 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>2</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Create an annotation claim.
--
-- An annotation claim is a triple which makes a statement over the annotation.
--
-- FIXME: why do we only have a claim method for annotations and not one for any resource?
--
-- \param annotation_id The id of the annotation as returned by annotation.new().
-- \param claimIri The IRI of the annotation. FIXME: this seems redundant seeing that we also put in the id
-- \param claimRelation The property to be stored.
-- \param claimValue The value of the property.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.annotation.claim?annotation_id=2&claimIri=http://mytest.com&claimRelation=test&claimValue=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 07:00:18 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete an annotation.
--
-- \param annotation_id The id of the annotation to delete as returned by annotation.new().
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa annotation.new
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.annotation.delete?annotation_id=2&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 07:01:12 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Create a new calendar publication.
--
-- ODS Calendar allows to publish its contents to WebDAV, CalDAV, or a writable URL. This method
-- allows to create new publications which are then updated according to the settings.
--
-- The published file contains the calendar's events and/or tasks in iCal format.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param name A user-readable name for the new publication.
-- \param updateType Can be one of:
-- - \p 1 - The publication is updated manually via calendar.publication.sync()
-- - \p 2 - The publication is updated automatically whenever an entry changes.
-- - \p 3 - The publication is updated based on the schedule set via \p updatePeriod and \p updateFreq.
-- \param updatePeriod Can be one of \p "daily" and \p "hourly". Only used for the scheduled updating.
-- \param updateFreq Specifies the frequency of the scheduled updates. Depending on the value of
--                   \p updatePeriod the publication is updated every N days or hours.
-- \param destinationType Can be one of the following:
-- - \p "webdav" - In this case the \p destination is a WebDAV path.
-- - \p "caldav" - In this case the \p destination is a CalDAV path.
-- - \p "url" - In this case the \p destination is a URL.
-- \param destination The location where the events and tasks should be published (depends on the value of \p destinationType)
-- \param userName An optional userName which might be required to access the \p destination.
-- \param userPassword The password for the given \p userName.
-- \param events If \p 1 events are published.
-- \param tasks If \p 1 tasks are published.
--
-- FIXME: the UI provides "mails to attendees" configuration.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa calendar.publication.sync()
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.publication.new?inst_id=148&name=demo_pub&destination=DAV/home/demo/Public/Demo_PUB_Calendar.ics&userName=demo&userPassword=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh9ba13"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 21:42:38 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 58
--
-- <result>
--  <code>20</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get details about a calendar publication.
--
-- Used to retrieve details of a publication added via calendar.publication.new().
--
-- \param publication_id The numerical id of the publication.
--
-- \return The configuration of the given publication encoded as XML.
--
-- \b Example:
-- \verbatim
-- $  curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.publication.get?publication_id=20&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 21:45:17 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 385
--
-- <publication id="20">
--   <name>demo_pub</name>
--   <updatePeriod>daily</updatePeriod>
--   <updateFreq>1</updateFreq>
--   <destinationType>WebDAV</destinationType>
--   <destination>DAV/home/demo/Public/Demo_PUB_Calendar.ics</destination>
--   <userName>demo</userName>
--   <userPassword>******</userName>
--   <options>
--     <events>1</events>
--     <tasks>1</tasks>
--   </options>
-- </publication>
-- \endverbatim
--/
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
--!
-- \brief Modify a calendar publication.
--
-- ODS Calendar allows to publish its contents to WebDAV, CalDAV, or a writable URL. This method
-- allows to create new publications which are then updated according to the settings.
--
-- The published file contains the calendar's events and/or tasks in iCal format.
--
-- \param publication_id The id of the Calendar publication as returned by calendar.publication.new().
-- \param name A user-readable name for the publication. FIXME: why is this not optional?
-- \param updateType Can be one of:
-- - \p 1 - The publication is updated manually via calendar.publication.sync()
-- - \p 2 - The publication is updated automatically whenever an entry changes.
-- - \p 3 - The publication is updated based on the schedule set via \p updatePeriod and \p updateFreq.
-- \param updatePeriod Can be one of \p "daily" and \p "hourly". Only used for the scheduled updating.
-- \param updateFreq Specifies the frequency of the scheduled updates. Depending on the value of
--                   \p updatePeriod the publication is updated every N days or hours.
-- \param destinationType Can be one of the following:
-- - \p "webdav" - In this case the \p destination is a WebDAV path.
-- - \p "caldav" - In this case the \p destination is a CalDAV path.
-- - \p "url" - In this case the \p destination is a URL.
-- \param destination The location where the events and tasks should be published (depends on the value of \p destinationType)
-- \param userName An optional userName which might be required to access the \p destination.
-- \param userPassword The password for the given \p userName.
-- \param events If \p 1 events are published.
-- \param tasks If \p 1 tasks are published.
--
-- FIXME: the UI provides "mails to attendees" configuration.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa calendar.publication.new()
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.publication.edit?publication_id=20&name=testpub3&destination=DAV/home/demo/Public/Demo_PUB_Calendar.ics&userName=demo&userPassword=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 21:56:16 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 58
--
-- <result>
--   <code>20</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Synchronize a calendar publication.
--
-- Manually synchonizes a calendar publication created with calendar.publication.new(). This is required
-- if the publication has been configured to be manually updated. However, it can also be used to force an
-- update on publications with a scheduled update interval.
--
-- \param publication_id The numerical id of the publication to update.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.publication.sync?publication_id=20&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 21:57:58 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete a calendar publication.
--
-- \param publication_id The numerical id of the publication created via calendar.publication.new().
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.publication.delete?publication_id=13&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:05:56 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Create a new calendar subscription.
--
-- ODS Calendar can subscribe to external calendars and integrate the events and tasks into
-- its own. This function allows to set up such a subscription to an iCal file.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param name A user-readable name for the new subscription.
-- \param updateType Can be one of:
-- - \p 1 - The subscription is updated manually via calendar.subscription.sync()
-- - \p 2 - The subscription is updated based on the schedule set via \p updatePeriod and \p updateFreq.
-- \param updatePeriod Can be one of \p "daily" and \p "hourly". Only used for the scheduled updating.
-- \param updateFreq Specifies the frequency of the scheduled updates. Depending on the value of
--                   \p updatePeriod the subscription is updated every N days or hours.
-- \param sourceType Can be one of the following:
-- - \p "webdav" - In this case the \p source is a WebDAV path.
-- - \p "caldav" - In this case the \p source is a CalDAV path.
-- - \p "url" - In this case the \p source is a URL.
-- \param source The location from where the events and tasks should be fetched (depends on the value of \p sourceType)
-- \param userName An optional userName which might be required to access the \p source.
-- \param userPassword The password for the given \p userName.
-- \param events If \p 1 events are included.
-- \param tasks If \p 1 tasks are included.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
-- If successful the error code matches the numerical id of the newly created subscription.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.subscription.new?inst_id=148&name=testsubscr23&source=DAV/home/demo/Public/Demo_PUB_Calendar.ics&destinationType=WebDAV&userName=demo&userPassword=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 21:59:21 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 58
--
-- <result>
--   <code>21</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get details about a calendar subscription.
--
-- Used to retrieve details of a subscription added via calendar.subscription.new().
--
-- \param subscription_id The numerical id of the subscription.
--
-- \return The configuration of the given subscription encoded as XML.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.subscription.get?subscription_id=21&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 22:00:34 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 369
--
-- <publication id="21">
--   <name>testsubscr23</name>
--   <updatePeriod>daily</updatePeriod>
--   <updateFreq>1</updateFreq>
--   <sourceType>WebDAV</sourceType>
--   <source>DAV/home/demo/Public/Demo_PUB_Calendar.ics</source>
--   <userName>demo</userName>
--   <userPassword>******</userName>
--   <options>
--     <events>1</events>
--     <tasks>1</tasks>
--   </options>
-- </publication>
-- \endverbatim
--/
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
--!
-- \brief Modify a calendar subscription.
--
-- ODS Calendar can subscribe to external calendars and integrate the events and tasks into
-- its own. This function allows to set up such a subscription to an iCal file.
--
-- \param subscription_id The id of the Calendar subscription as returned by calendar.subscription.new().
-- \param name A user-readable name for the new subscription.
-- \param updateType Can be one of:
-- - \p 1 - The subscription is updated manually via calendar.subscription.sync()
-- - \p 2 - The subscription is updated based on the schedule set via \p updatePeriod and \p updateFreq.
-- \param updatePeriod Can be one of \p "daily" and \p "hourly". Only used for the scheduled updating.
-- \param updateFreq Specifies the frequency of the scheduled updates. Depending on the value of
--                   \p updatePeriod the subscription is updated every N days or hours.
-- \param sourceType Can be one of the following:
-- - \p "webdav" - In this case the \p source is a WebDAV path.
-- - \p "caldav" - In this case the \p source is a CalDAV path.
-- - \p "url" - In this case the \p source is a URL.
-- \param source The location from where the events and tasks should be fetched (depends on the value of \p sourceType)
-- \param userName An optional userName which might be required to access the \p source.
-- \param userPassword The password for the given \p userName.
-- \param events If \p 1 events are included.
-- \param tasks If \p 1 tasks are included.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.subscription.edit?subscription_id=21&name=testsubscr24&source=DAV/home/demo/Public/Demo_PUB_Calendar.ics&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 22:01:52 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 58
--
-- <result>
--   <code>21</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Synchronize a calendar subscription.
--
-- Manually synchonizes a calendar subscription created with calendar.subscription.new(). This is required
-- if the subscription has been configured to be manually updated. However, it can also be used to force an
-- update on subscriptions with a scheduled update interval.
--
-- \param subscription_id The numerical id of the subscription to update.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.subscription.sync?subscription_id=19&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 24 May 2011 22:40:59 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete a calendar subscription.
--
-- \param subscription_id The numerical id of the subscription created via calendar.subscription.new().
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.subscription.delete?subscription_id=17&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:25:45 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Create a new calendar upstream.
--
-- FIXME: what is an upstream?
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param name A human-readable name for the new upstream.
-- \param source
-- \param userName
-- \param userPassword
-- \param tagsInclude
-- \param tagsExclude
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
-- If successful the error code matches the id of the newly created upstream.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.upstream.new?inst_id=148&name=testups&source=http://myopenlink.net/dataspace/test1/calendar/demo%27s%20Calendar/atom-pub&userName=demo&userPassword=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:28:58 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/plain; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Modify a calendar upstream.
--
-- FIXME: what is an upstream?
--
-- \param upstream_id The numerical id of the upstream to modify.
-- \param name A human-readable name for the new upstream.
-- \param source
-- \param userName
-- \param userPassword
-- \param tagsInclude
-- \param tagsExclude
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.upstream.edit?upstream_id=1&name=testups2&source=http://myopenlink.net/dataspace/test1/calendar/demo%27s%20Calendar/atom-pub&userName=demo&userPassword=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:30:08 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/plain; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete a calendar upstream.
--
-- \param upstream_id The numerical id of the upstream created via calendar.upstream.new().
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.upstream.delete?upstream_id=1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:31:09 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Configure a ODS Calendar instance.
--
-- FIXME: most of these options are only valid for the UI which means they should not be in the REST API.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
-- \param options A comma-separated list of \p "key=value" pairs. Supported keys are:
-- - chars
-- - rows
-- - atomVersion
-- - defaultView
-- - weekStarts
-- - timeFormat
-- - dateFormat
-- - timeZone
-- - showTasks
-- - conv
-- - conv_init
-- - event_E_UPDATED
-- - event_E_CREATED
-- - event_E_LOCATION
-- - task_E_STATUS
-- - task_E_PRIORITY
-- - task_E_START
-- - task_E_END
-- - task_E_COMPLETED
-- - task_E_UPDATED
-- - task_E_CREATED
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.options.set?inst_id=148&options=rows%3D10&user_name=demo&password_ha
-- sh=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:09:04 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get the configuration of a ODS Calendar instance.
--
-- \param inst_id The id of the Calendar app instance. See \ref ods_instance_id for details.
--
-- \return The configuration settings encoded as XML.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://ods-qa.openlinksw.com/ods/api/calendar.options.get?inst_id=148&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Linux) x86_64-generic-linux-glibc25-64  VDB
-- Connection: Keep-Alive
-- Date: Fri, 20 May 2011 08:10:08 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 625
--
-- <settings>
--   <chars>60</chars>
--   <rows>10</rows>
--   <atomVersion>1.0</atomVersion>
--   <defaultView>week</defaultView>
--   <weekStarts>m</weekStarts>
--   <timeFormat>e</timeFormat>
--   <dateFormat>dd.MM.yyyy</dateFormat>
--   <timeZone>0</timeZone>
--   <showTasks>0</showTasks>
--   <conv>1</conv>
--   <conv_init>0</conv_init>
--   <event_E_UPDATED>0</event_E_UPDATED>
--   <event_E_CREATED>0</event_E_CREATED>
--   <event_E_LOCATION>0</event_E_LOCATION>
--   <task_E_STATUS>0</task_E_STATUS>
--   <task_E_PRIORITY>0</task_E_PRIORITY>
--   <task_E_START>0</task_E_START>
--   <task_E_END>0</task_E_END>
--   <task_E_COMPLETED>0</task_E_COMPLETED>
--   <task_E_UPDATED>0</task_E_UPDATED>
--   <task_E_CREATED>0</task_E_CREATED>
-- </settings>
-- \endverbatim
--/
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
