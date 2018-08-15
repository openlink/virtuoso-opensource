--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
use SIOC;

-------------------------------------------------------------------------------
--
create procedure calendar_event_iri_internal (
  in domain_id integer,
  in event_id integer)
{
  declare kind integer;
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

  kind := coalesce ((select E_KIND from CAL.WA.EVENTS where E_ID = event_id), 0);
  return sprintf ('http://%s%s/%U/calendar/%U/%s/%d', get_cname(), get_base_path (), _member, _inst, case when (kind = 0) then 'Event' else 'Task' end, event_id);
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_event_iri (
  in domain_id integer,
  in event_id integer)
{
	declare c_iri varchar;

	c_iri := calendar_event_iri_internal (domain_id, event_id);
	if (isnull (c_iri))
	  return c_iri;

	return c_iri || '#this';
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_comment_iri (
  in domain_id integer,
  in event_id integer,
  in comment_id integer)
{
	declare c_iri varchar;

	c_iri := calendar_event_iri_internal (domain_id, event_id);
	if (isnull (c_iri))
	  return c_iri;

	return sprintf ('%s/%d', c_iri, comment_id);
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_annotation_iri (
  in domain_id integer,
  in event_id integer,
  in annotation_id integer)
{
	declare c_iri varchar;

	c_iri := calendar_event_iri_internal (domain_id, event_id);
	if (isnull (c_iri))
	  return c_iri;

	return sprintf ('%s/annotation/%d', c_iri, annotation_id);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_calendar_sioc (
  in graph_iri varchar,
  in site_iri varchar,
  in _wai_name varchar := null)
{
  declare id, deadl, cnt integer;
  declare acl_graph_iri, c_iri, creator_iri, iri varchar;

  {
    -- init services
    SIOC..fill_ods_calendar_services ();

    for (select WAI_ID,
                WAI_IS_PUBLIC,
                WAI_TYPE_NAME,
                WAI_NAME,
                WAI_ACL
           from DB.DBA.WA_INSTANCE
          where ((_wai_name is null) or (WAI_NAME = _wai_name))
            and WAI_TYPE_NAME = 'Calendar') do
    {
      acl_graph_iri := SIOC..acl_graph (WAI_TYPE_NAME, WAI_NAME);
      exec (sprintf ('sparql clear graph <%s>', acl_graph_iri));
      SIOC..wa_instance_acl_insert (WAI_IS_PUBLIC, WAI_TYPE_NAME, WAI_NAME, WAI_ACL);
      for (select E_DOMAIN_ID, E_ID, E_ACL
             from CAL.WA.EVENTS
            where E_DOMAIN_ID = WAI_ID and E_ACL is not null) do
      {
        event_acl_insert (E_DOMAIN_ID, E_ID, E_ACL);
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
      goto L0;
    };
  L0:

    for (select WAI_ID,
                WAI_NAME,
                WAM_USER,
                E_ID,
                E_UID,
                E_DOMAIN_ID,
                E_KIND,
                E_SUBJECT,
                E_DESCRIPTION,
                E_LOCATION,
                E_PRIVACY,
                E_EVENT,
                E_EVENT_START,
                E_EVENT_END,
                E_PRIORITY,
                E_STATUS,
                E_COMPLETE,
                E_COMPLETED,
                E_CREATED,
                E_UPDATED,
                E_TAGS,
                E_NOTES,
                E_ACL
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                CAL.WA.EVENTS
          where WAM_INST = WAI_NAME
            and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
            and E_DOMAIN_ID = WAI_ID
            and E_PRIVACY = 1
          order by E_ID) do
  {
      c_iri := calendar_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

      event_insert (graph_iri,
                    c_iri,
                    creator_iri,
                    E_ID,
                    E_UID,
                    E_DOMAIN_ID,
                    E_KIND,
                    E_SUBJECT,
                    E_DESCRIPTION,
                    E_LOCATION,
                    E_PRIVACY,
                    E_EVENT,
                    E_EVENT_START,
                    E_EVENT_END,
                    E_PRIORITY,
                    E_STATUS,
                    E_COMPLETE,
                    E_COMPLETED,
                    E_CREATED,
                    E_UPDATED,
                    E_TAGS,
                    E_NOTES);

      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
      {
  	    commit work;
  	    id := E_ID;
      }
    }
    commit work;

		id := -1;
		deadl := 3;
		cnt := 0;
		declare exit handler for sqlstate '40001'
		{
			if (deadl <= 0)
				resignal;
			rollback work;
			deadl := deadl - 1;
			goto L1;
		};
	L1:
		for (select WAI_ID,
								WAI_NAME
					 from DB.DBA.WA_INSTANCE
					where ((WAI_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
					  and WAI_TYPE_NAME = 'Calendar'
					  and WAI_ID > id
					order by WAI_ID) do
		{
			c_iri := calendar_iri (WAI_NAME);
      iri := sprintf ('http://%s%s/%U/calendar/%U/atom-pub', get_cname(), get_base_path (), CAL.WA.domain_owner_name (WAI_ID), WAI_NAME);
      ods_sioc_service (graph_iri, iri, c_iri, null, null, null, iri, 'Atom');
			cnt := cnt + 1;
			if (mod (cnt, 500) = 0)
			{
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
create procedure fill_ods_calendar_services ()
{
  declare graph_iri, services_iri, service_iri, service_url varchar;
  declare svc_functions any;

  graph_iri := get_graph ();

  -- instance
  svc_functions := vector ('calendar.event.new', 'calendar.task.new', 'calendar.import', 'calendar.export', 'calendar.publication.new', 'calendar.subscription.new', 'calendar.upstream.new', 'calendar.options.set',  'calendar.options.get');
  ods_object_services (graph_iri, 'calendar', 'ODS calendar instance services', svc_functions);

  -- event
  svc_functions := vector ('calendar.get', 'calendar.event.edit', 'calendar.delete', 'calendar.comment.new', 'calendar.annotation.new');
  ods_object_services (graph_iri, 'calendar/event', 'ODS calendar item services', svc_functions);

  -- task
  svc_functions := vector ('calendar.get', 'calendar.task.edit', 'calendar.delete', 'calendar.comment.new', 'calendar.annotation.new');
  ods_object_services (graph_iri, 'calendar/task', 'ODS calendar item services', svc_functions);

  -- item comment
  svc_functions := vector ('calendar.comment.get', 'calendar.comment.delete');
  ods_object_services (graph_iri, 'calendar/item/comment', 'ODS calendar comment services', svc_functions);

  -- item annotation
  svc_functions := vector ('calendar.annotation.get', 'calendar.annotation.claim', 'calendar.annotation.delete');
  ods_object_services (graph_iri, 'calendar/item/annotation', 'ODS calendar annotation services', svc_functions);
}
;

-------------------------------------------------------------------------------
--
create procedure clean_ods_calendar_sioc (
  in _wai_name varchar := null,
  in _access_mode integer := null)
{
  declare id, deadl, cnt integer;
  declare acl_graph_iri, c_iri, creator_iri, iri varchar;

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
      goto L0;
    };
  L0:

    for (select E_ID,
                E_DOMAIN_ID,
                E_TAGS
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER,
                CAL.WA.EVENTS
          where WAM_INST = WAI_NAME
            and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)
            and E_DOMAIN_ID = WAI_ID
            and E_PRIVACY = 1
          order by E_ID) do
    {
      event_delete (E_ID,
                    E_DOMAIN_ID,
                    E_TAGS);

      cnt := cnt + 1;
      if (mod (cnt, 500) = 0)
      {
  	    commit work;
  	    id := E_ID;
      }
    }
    commit work;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ods_calendar_services (
  in graph_iri varchar, 
  in forum_iri varchar,
  in wai_id varchar := null,
  in wai_name varchar := null)
{
  declare svc_iri varchar;
  
  svc_iri := sprintf ('http://%s%s/%U/calendar/%U/atom-pub', get_cname(), get_base_path (), CAL.WA.domain_owner_name (wai_id), wai_name);
  ods_sioc_service (graph_iri, svc_iri, forum_iri, null, null, null, svc_iri, 'Atom');
}
;

-------------------------------------------------------------------------------
--
create procedure event_insert (
  in graph_iri varchar,
  in c_iri varchar,
  in creator_iri varchar,
  inout event_id integer,
  inout uid integer,
  inout domain_id integer,
  inout kind integer,
  inout subject varchar,
  inout description varchar,
  inout location varchar,
  inout privacy integer,
  inout event varchar,
  inout eventStart datetime,
  inout eventEnd datetime,
  inout priority integer,
  inout status varchar,
  inout complete integer,
  inout completed datetime,
  inout created datetime,
  inout updated datetime,
  inout tags varchar,
  inout notes varchar)
{
  declare iri varchar;

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
            and WAI_IS_PUBLIC > 0
            and WAM_INST = WAI_NAME) do
    {
      graph_iri := get_graph_ext (WAI_IS_PUBLIC);
      c_iri := calendar_iri (WAI_NAME);
      creator_iri := user_iri (WAM_USER);
    }

  if (isnull (graph_iri))
    return;

    iri := calendar_event_iri (domain_id, event_id);

    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, subject, created, updated, CAL.WA.event_url (domain_id, event_id), description);
    scot_tags_insert (domain_id, iri, tags);

    if (kind = 0)
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, iri, rdf_iri ('type'), vcal_iri ('vevent'));
      if (not isnull (uid))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('uid'), uid);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('url'), CAL.WA.event_url (domain_id, event_id));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('dtstamp'), now ());
      if (not isnull (created))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('created'), created);
      if (not isnull (updated))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('lastModified'), updated);
      if (not isnull (eventStart))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('dtstart'), eventStart);
      if (not isnull (eventEnd))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('dtend'), eventEnd);
    if (not isnull (subject))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('summary'), subject);
    if (not isnull (description))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('description'), description);
      if (not isnull (notes))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('notes'), notes);
    if (not isnull (location))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('location'), location);
      if (not isnull (privacy))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('class'), case when privacy = 1 then 'PUBLIC' else 'PRIVATE' end);

    -- event services
    SIOC..ods_object_services_attach (graph_iri, iri, 'calendar/event');
    }
  else if (kind = 1)
    {
      DB.DBA.ODS_QUAD_URI   (graph_iri, iri, rdf_iri ('type'), vcal_iri ('vtodo'));
      if (not isnull (uid))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('uid'), uid);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('url'), CAL.WA.event_url (domain_id, event_id));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('dtstamp'), now ());
      if (not isnull (completed))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('completed'), completed);
      if (not isnull (created))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('created'), created);
      if (not isnull (updated))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('lastModified'), updated);
    if (not isnull (eventStart))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('dtstart'), eventStart);
    if (not isnull (eventEnd))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('dtend'), eventEnd);
      if (not isnull (subject))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('summary'), subject);
      if (not isnull (description))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('description'), description);
      if (not isnull (notes))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('notes'), notes);
    if (not isnull (priority))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('priority'), priority);
    if (not isnull (status))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('status'), status);
      if (not isnull (privacy))
        DB.DBA.ODS_QUAD_URI_L (graph_iri, iri, vcal_iri ('class'), case when privacy = 1 then 'PUBLIC' else 'PRIVATE' end);

    -- task services
    SIOC..ods_object_services_attach (graph_iri, iri, 'calendar/task');

    SIOC..calendar_comments_insert (graph_iri, c_iri, domain_id, event_id);
    SIOC..cal_annotations_insert (graph_iri, domain_id, event_id);
  }
  }
;

-------------------------------------------------------------------------------
--
create procedure event_delete (
  inout event_id integer,
  inout domain_id integer,
  inout tags varchar)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph_ext (CAL.WA.domain_is_public (domain_id));
  iri := calendar_event_iri (domain_id, event_id);
  scot_tags_delete (domain_id, iri, tags);
  delete_quad_s_or_o (graph_iri, iri, iri);

  -- event services
  SIOC..ods_object_services_dettach (graph_iri, iri, 'calendar/event');
  SIOC..ods_object_services_dettach (graph_iri, iri, 'calendar/task');

  SIOC..calendar_comments_delete (graph_iri, domain_id, event_id);
  SIOC..cal_annotations_delete (graph_iri, domain_id, event_id);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_I after insert on CAL.WA.EVENTS referencing new as N
{
  if (N.E_PRIVACY <> 1)
    return;
  event_insert (null,
                null,
                null,
                N.E_ID,
                N.E_UID,
                N.E_DOMAIN_ID,
                N.E_KIND,
                N.E_SUBJECT,
                N.E_DESCRIPTION,
                N.E_LOCATION,
                N.E_PRIVACY,
                N.E_EVENT,
                N.E_EVENT_START,
                N.E_EVENT_END,
                N.E_PRIORITY,
                N.E_STATUS,
                N.E_COMPLETE,
                N.E_COMPLETED,
                N.E_CREATED,
                N.E_UPDATED,
                N.E_TAGS,
                N.E_NOTES);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_U after update on CAL.WA.EVENTS referencing old as O, new as N
{
  event_delete (O.E_ID,
                O.E_DOMAIN_ID,
                O.E_TAGS);
  if (N.E_PRIVACY <> 1)
    return;
  event_insert (null,
                null,
                null,
                N.E_ID,
                N.E_UID,
                N.E_DOMAIN_ID,
                N.E_KIND,
                N.E_SUBJECT,
                N.E_DESCRIPTION,
                N.E_LOCATION,
                N.E_PRIVACY,
                N.E_EVENT,
                N.E_EVENT_START,
                N.E_EVENT_END,
                N.E_PRIORITY,
                N.E_STATUS,
                N.E_COMPLETED,
                N.E_COMPLETE,
                N.E_CREATED,
                N.E_UPDATED,
                N.E_TAGS,
                N.E_NOTES);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_D before delete on CAL.WA.EVENTS referencing old as O
{
  event_delete (O.E_ID,
                O.E_DOMAIN_ID,
                O.E_TAGS);
}
;

-------------------------------------------------------------------------------
--
create procedure event_acl_insert (
  inout domain_id integer,
  inout event_id integer,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..calendar_event_iri (domain_id, event_id);
  graph_iri := CAL.WA.acl_graph (domain_id);

  SIOC..acl_insert (graph_iri, iri, acl);
}
;

-------------------------------------------------------------------------------
--
create procedure event_acl_delete (
  inout domain_id integer,
  inout event_id integer,
  inout acl any)
{
  declare graph_iri, iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  iri := SIOC..calendar_event_iri (domain_id, event_id);
  graph_iri := CAL.WA.acl_graph (domain_id);

  SIOC..acl_delete (graph_iri, iri, acl);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_ACL_I after insert on CAL.WA.EVENTS order 100 referencing new as N
{
  if (coalesce (N.E_ACL, '') <> '')
  {
    event_acl_insert (N.E_DOMAIN_ID,
                        N.E_ID,
                        N.E_ACL);

    SIOC..acl_ping (N.E_DOMAIN_ID,
                    SIOC..calendar_event_iri (N.E_DOMAIN_ID, N.E_ID),
                    null,
                    N.E_ACL);
  }
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_ACL_U after update (E_ACL) on CAL.WA.EVENTS order 100 referencing old as O, new as N
{
  if (coalesce (O.E_ACL, '') <> '')
    event_acl_delete (O.E_DOMAIN_ID,
                      O.E_ID,
                      O.E_ACL);

  if (coalesce (N.E_ACL, '') <> '')
    event_acl_insert (N.E_DOMAIN_ID,
                      N.E_ID,
                      N.E_ACL);

  SIOC..acl_ping (N.E_DOMAIN_ID,
                  SIOC..calendar_event_iri (N.E_DOMAIN_ID, N.E_ID),
                  O.E_ACL,
                  N.E_ACL);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_ACL_D before delete on CAL.WA.EVENTS order 100 referencing old as O
{
  if (coalesce (O.E_ACL, '') <> '')
    event_acl_delete (O.E_DOMAIN_ID,
                      O.E_ID,
                      O.E_ACL);
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_comments_insert (
  in graph_iri varchar,
  in forum_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select EC_ID,
              EC_DOMAIN_ID,
              EC_EVENT_ID,
              EC_TITLE,
              EC_COMMENT,
              EC_UPDATED,
              EC_U_NAME,
              EC_U_MAIL,
              EC_U_URL
         from CAL.WA.EVENT_COMMENTS
        where EC_EVENT_ID = master_id) do
  {
    calendar_comment_insert (graph_iri,
                             forum_iri,
                             EC_ID,
                             EC_DOMAIN_ID,
                             EC_EVENT_ID,
                             EC_TITLE,
                             EC_COMMENT,
                             EC_UPDATED,
                             EC_U_NAME,
                             EC_U_MAIL,
                             EC_U_URL);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_comments_delete (
  in graph_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select EC_ID,
              EC_DOMAIN_ID,
              EC_EVENT_ID
         from CAL.WA.EVENT_COMMENTS
        where EC_EVENT_ID = master_id) do
  {
    calendar_comment_delete (graph_iri,
                             EC_DOMAIN_ID,
                             EC_EVENT_ID,
                             EC_ID);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_comment_insert (
	in graph_iri varchar,
	in forum_iri varchar,
  inout comment_id integer,
  inout domain_id integer,
  inout master_id integer,
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
	if (isnull (graph_iri))
		for (select WAI_ID,
                WAI_IS_PUBLIC,
		            WAM_USER,
		            WAI_NAME
					 from DB.DBA.WA_INSTANCE,
								DB.DBA.WA_MEMBER
					where WAI_ID = domain_id
            and WAI_IS_PUBLIC > 0
            and WAM_INST = WAI_NAME) do
		{
      graph_iri := get_graph_ext (WAI_IS_PUBLIC);
      forum_iri := calendar_iri (WAI_NAME);
		}

	if (isnull (graph_iri))
	  return;

		comment_iri := calendar_comment_iri (domain_id, master_id, comment_id);
  if (isnull (comment_iri))
	  return;

  master_iri := SIOC..calendar_event_iri (domain_id, master_id);
      foaf_maker (graph_iri, u_url, u_name, u_mail);
      ods_sioc_post (graph_iri, comment_iri, forum_iri, null, title, last_update, last_update, null, comment, null, null, u_url);
      DB.DBA.ODS_QUAD_URI (graph_iri, master_iri, sioc_iri ('has_reply'), comment_iri);
      DB.DBA.ODS_QUAD_URI (graph_iri, comment_iri, sioc_iri ('reply_of'), master_iri);

  SIOC..ods_object_services_attach (graph_iri, comment_iri, 'calendar/item/comment');
}
;

-------------------------------------------------------------------------------
--
create procedure calendar_comment_delete (
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
  master_iri := SIOC..calendar_event_iri (domain_id, master_id);
  if (isnull (graph_iri))
    graph_iri := SIOC..get_graph_new (CAL.WA.domain_is_public (domain_id), master_iri);

  if (isnull (graph_iri))
    return;

  comment_iri := calendar_comment_iri (domain_id, master_id, comment_id);
  delete_quad_s_or_o (get_graph_ext (CAL.WA.domain_is_public (domain_id)), comment_iri, comment_iri);
  SIOC..ods_object_services_dettach (graph_iri, comment_iri, 'calendar/item/comment');
}
;

-------------------------------------------------------------------------------
--
create trigger EVENT_COMMENTS_SIOC_I after insert on CAL.WA.EVENT_COMMENTS referencing new as N
{
  if (not isnull(N.EC_PARENT_ID))
    calendar_comment_insert (null,
                             null,
                             N.EC_ID,
                             N.EC_DOMAIN_ID,
                             N.EC_EVENT_ID,
                             N.EC_TITLE,
                             N.EC_COMMENT,
                             N.EC_UPDATED,
                             N.EC_U_NAME,
                             N.EC_U_MAIL,
                             N.EC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENT_COMMENTS_SIOC_U after update on CAL.WA.EVENT_COMMENTS referencing old as O, new as N
{
  if (not isnull(O.EC_PARENT_ID))
    calendar_comment_delete (null,
                             O.EC_DOMAIN_ID,
                             O.EC_EVENT_ID,
                             O.EC_ID);
  if (not isnull(N.EC_PARENT_ID))
    calendar_comment_insert (null,
                             null,
                             N.EC_ID,
                             N.EC_DOMAIN_ID,
                             N.EC_EVENT_ID,
                             N.EC_TITLE,
                             N.EC_COMMENT,
                             N.EC_UPDATED,
                             N.EC_U_NAME,
                             N.EC_U_MAIL,
                             N.EC_U_URL);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENT_COMMENTS_SIOC_D before delete on CAL.WA.EVENT_COMMENTS referencing old as O
{
  if (not isnull(O.EC_PARENT_ID))
    calendar_comment_delete (null,
                             O.EC_DOMAIN_ID,
                             O.EC_EVENT_ID,
                             O.EC_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure cal_annotations_insert (
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
         from CAL.WA.ANNOTATIONS
        where A_OBJECT_ID = master_id) do
  {
    cal_annotation_insert (graph_iri,
                           A_ID,
                           A_DOMAIN_ID,
                           A_OBJECT_ID,
                           A_AUTHOR,
                           A_BODY,
                           A_CLAIMS,
                           A_CREATED,
                           A_UPDATED);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure cal_annotations_delete (
  in graph_iri varchar,
  inout domain_id integer,
  inout master_id integer)
{
  for (select A_ID,
              A_DOMAIN_ID,
              A_OBJECT_ID,
              A_CLAIMS
         from CAL.WA.ANNOTATIONS
        where A_OBJECT_ID = master_id) do
  {
    cal_annotation_delete (graph_iri,
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
create procedure cal_annotation_insert (
  in graph_iri varchar,
  inout annotation_id integer,
  inout domain_id integer,
  inout master_id integer,
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

  if (isnull (graph_iri))
    for (select WAI_ID,
                WAI_IS_PUBLIC,
                WAM_USER,
                WAI_NAME
           from DB.DBA.WA_INSTANCE,
                DB.DBA.WA_MEMBER
          where WAI_ID = domain_id
            and WAI_IS_PUBLIC > 0
            and WAM_INST = WAI_NAME) do
    {
      graph_iri := get_graph_ext (WAI_IS_PUBLIC);
    }

  if (isnull (graph_iri))
    return;

    master_iri := calendar_event_iri (domain_id, cast (master_id as integer));
  annotation_iri := calendar_annotation_iri (domain_id, cast (master_id as integer), annotation_id);
  DB.DBA.ODS_QUAD_URI (graph_iri, annotation_iri, an_iri ('annotates'), master_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, master_iri, an_iri ('hasAnnotation'), annotation_iri);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('author'), author);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('body'), body);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('created'), created);
  DB.DBA.ODS_QUAD_URI_L (graph_iri, annotation_iri, an_iri ('modified'), updated);

  cal_claims_insert (graph_iri, annotation_iri, claims);
  SIOC..ods_object_services_attach (graph_iri, annotation_iri, 'calendar/item/annotation');
}
;

-------------------------------------------------------------------------------
--
create procedure cal_annotation_delete (
  inout annotation_id integer,
  inout domain_id integer,
  inout master_id integer,
  inout claims any)
{
  declare graph_iri, annotation_iri varchar;
  declare exit handler for sqlstate '*'
  {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph_ext (CAL.WA.domain_is_public (domain_id));
  annotation_iri := calendar_annotation_iri (domain_id, master_id, annotation_id);
  delete_quad_s_or_o (graph_iri, annotation_iri, annotation_iri);
  SIOC..ods_object_services_dettach (graph_iri, annotation_iri, 'calendar/item/annotation');
}
;

-------------------------------------------------------------------------------
--
create procedure cal_claims_insert (
  in graph_iri varchar,
  in iri varchar,
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
    DB.DBA.ODS_QUAD_URI (graph_iri, iri, cPedicate, cValue);
}
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_I after insert on CAL.WA.ANNOTATIONS referencing new as N
{
  cal_annotation_insert (null,
                         N.A_ID,
                         N.A_DOMAIN_ID,
                         N.A_OBJECT_ID,
                         N.A_AUTHOR,
                         N.A_BODY,
                         N.A_CLAIMS,
                         N.A_CREATED,
                         N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_U after update on CAL.WA.ANNOTATIONS referencing old as O, new as N
{
  cal_annotation_delete (O.A_ID,
                         O.A_DOMAIN_ID,
                         O.A_OBJECT_ID,
                         O.A_CLAIMS);
  cal_annotation_insert (null,
                         N.A_ID,
                         N.A_DOMAIN_ID,
                         N.A_OBJECT_ID,
                         N.A_AUTHOR,
                         N.A_BODY,
                         N.A_CLAIMS,
                         N.A_CREATED,
                         N.A_UPDATED);
}
;

-------------------------------------------------------------------------------
--
create trigger ANNOTATIONS_SIOC_D before delete on CAL.WA.ANNOTATIONS referencing old as O
{
  cal_annotation_delete (O.A_ID,
                         O.A_DOMAIN_ID,
                         O.A_OBJECT_ID,
                         O.A_CLAIMS);
}
;

-------------------------------------------------------------------------------
--
create procedure ods_calendar_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_calendar_sioc_init') = sioc_version)
    return;
  fill_ods_calendar_sioc (get_graph (), get_graph ());
  registry_set ('__ods_calendar_sioc_init', sioc_version);
  return;
}
;

--CAL.WA.exec_no_error ('ods_calendar_sioc_init ()');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_services_update') = '1')
    return;

  SIOC..fill_ods_calendar_services();
  registry_set ('cal_services_update', '1');
}
;

CAL.WA.tmp_update ();
-------------------------------------------------------------------------------
--
-- RDF Views
--
use DB;

-------------------------------------------------------------------------------
--
wa_exec_no_error ('drop view ODS_CALENDAR_EVENTS');

create view ODS_CALENDAR_EVENTS
as
select
	WAI_NAME,
	E_DOMAIN_ID,
	E_ID,
	E_SUBJECT,
	E_DESCRIPTION,
	sioc..sioc_date (E_UPDATED) as E_UPDATED,
	sioc..sioc_date (E_CREATED) as E_CREATED,
	sioc..post_iri (U_NAME, 'calendar', WAI_NAME, cast (E_ID as varchar)) || '/sioc.rdf' as SEE_ALSO,
	CAL.WA.event_url (E_DOMAIN_ID, E_ID) E_URI,
	U_NAME
from
	DB.DBA.WA_INSTANCE,
	CAL.WA.EVENTS,
	DB.DBA.WA_MEMBER,
	DB.DBA.SYS_USERS
where E_DOMAIN_ID = WAI_ID
  and E_KIND = 0
  and	WAM_INST = WAI_NAME
  and	WAM_IS_PUBLIC = 1
  and	WAM_USER = U_ID
  and	WAM_MEMBER_TYPE = 1;

wa_exec_no_error ('drop view ODS_CALENDAR_TASKS');

create view ODS_CALENDAR_TASKS
as
select
	WAI_NAME,
	E_DOMAIN_ID,
	E_ID,
	E_SUBJECT,
	E_DESCRIPTION,
	sioc..sioc_date (E_UPDATED) as E_UPDATED,
	sioc..sioc_date (E_CREATED) as E_CREATED,
	sioc..post_iri (U_NAME, 'calendar', WAI_NAME, cast (E_ID as varchar)) || '/sioc.rdf' as SEE_ALSO,
	CAL.WA.event_url (E_DOMAIN_ID, E_ID) E_URI,
	U_NAME
from
	DB.DBA.WA_INSTANCE,
	CAL.WA.EVENTS,
	DB.DBA.WA_MEMBER,
	DB.DBA.SYS_USERS
where E_DOMAIN_ID = WAI_ID
  and E_KIND = 1
  and	WAM_INST = WAI_NAME
  and	WAM_IS_PUBLIC = 1
  and	WAM_USER = U_ID
  and	WAM_MEMBER_TYPE = 1;

-------------------------------------------------------------------------------
--
create procedure ODS_CALENDAR_TAGS ()
{
  declare V any;
  declare inst, uname, item_id, tag any;

  result_names (inst, uname, item_id, tag);

  for (select WAM_INST,
              U_NAME,
              E_ID,
              E_TAGS
         from CAl.WA.EVENTS,
              WA_MEMBER,
              WA_INSTANCE,
              SYS_USERS
        where WAM_INST = WAI_NAME
          and WAM_MEMBER_TYPE = 1
          and WAM_USER = U_ID
          and E_DOMAIN_ID = WAI_ID
          and length (E_TAGS) > 0) do {
    V := split_and_decode (E_TAGS, 0, '\0\0,');
    foreach (any t in V) do
    {
      t := trim(t);
      if (length (t))
 	      result (WAM_INST, U_NAME, E_ID, t);
    }
  }
}
;

-------------------------------------------------------------------------------
--
wa_exec_no_error ('drop view ODS_CALENDAR_TAGS');

create procedure view ODS_CALENDAR_TAGS as DB.DBA.ODS_CALENDAR_TAGS () (WAM_INST varchar, U_NAME varchar, ITEM_ID int, E_TAG varchar);

-------------------------------------------------------------------------------
--
create procedure sioc.DBA.rdf_calendar_view_str ()
{
  return
      '
        #Event
        sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME, DB.DBA.ODS_CALENDAR_EVENTS.E_ID)
        a calendar:vevent ;
        dc:title E_SUBJECT ;
        dct:created E_CREATED ;
       	dct:modified E_UPDATED ;
	      dc:date E_UPDATED ;
	      dc:creator U_NAME ;
	      sioc:link sioc:proxy_iri (E_URI) ;
	      sioc:content E_DESCRIPTION ;
	      sioc:has_creator sioc:user_iri (U_NAME) ;
	      foaf:maker foaf:person_iri (U_NAME) ;
	      rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
	      sioc:has_container sioc:calendar_forum_iri (U_NAME, WAI_NAME)
	    .

      sioc:calendar_forum_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME)
        sioc:container_of sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID)
      .

	    sioc:user_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME)
	      sioc:creator_of sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID)
	    .

      	# Event tags
    	sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_TAGS.U_NAME, DB.DBA.ODS_CALENDAR_TAGS.WAM_INST, DB.DBA.ODS_CALENDAR_TAGS.ITEM_ID)
    	  sioc:topic sioc:tag_iri (U_NAME, E_TAG)
    	.

    	sioc:tag_iri (DB.DBA.ODS_CALENDAR_TAGS.U_NAME, DB.DBA.ODS_CALENDAR_TAGS.E_TAG)
    	  a skos:Concept ;
      	skos:prefLabel E_TAG ;
    	  skos:isSubjectOf sioc:calendar_event_iri (U_NAME, WAM_INST, ITEM_ID)
    	.

      sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME, DB.DBA.ODS_CALENDAR_EVENTS.E_ID)
        a atom:Entry ;
      	atom:title E_SUBJECT ;
      	atom:source sioc:calendar_forum_iri (U_NAME, WAI_NAME) ;
      	atom:author foaf:person_iri (U_NAME) ;
        atom:published E_CREATED ;
      	atom:updated E_UPDATED ;
      	atom:content sioc:calendar_event_text_iri (U_NAME, WAI_NAME, E_ID)
     	.

      sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME, DB.DBA.ODS_CALENDAR_EVENTS.E_ID)
        a atom:Content ;
        atom:type "text/plain" ;
      	atom:lang "en-US" ;
	      atom:body E_DESCRIPTION
	    .

      sioc:calendar_forum_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME)
        atom:contains sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID)
      .
      
      #Task
      sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_TASKS.U_NAME, DB.DBA.ODS_CALENDAR_TASKS.WAI_NAME, DB.DBA.ODS_CALENDAR_TASKS.E_ID)
        a calendar:vtodo ;
        dc:title E_SUBJECT ;
        dct:created E_CREATED ;
     	  dct:modified E_UPDATED ;
	      dc:date E_UPDATED ;
	      dc:creator U_NAME ;
	      sioc:link sioc:proxy_iri (E_URI) ;
	      sioc:content E_DESCRIPTION ;
	      sioc:has_creator sioc:user_iri (U_NAME) ;
	      foaf:maker foaf:person_iri (U_NAME) ;
	      rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
	      sioc:has_container sioc:calendar_forum_iri (U_NAME, WAI_NAME)
	    .

      sioc:calendar_forum_iri (DB.DBA.ODS_CALENDAR_TASKS.U_NAME, DB.DBA.ODS_CALENDAR_TASKS.WAI_NAME)
        sioc:container_of sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID)
      .

	    sioc:user_iri (DB.DBA.ODS_CALENDAR_TASKS.U_NAME)
	      sioc:creator_of sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID)
	    .

    	# Task tags
    	sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_TAGS.U_NAME, DB.DBA.ODS_CALENDAR_TAGS.WAM_INST, DB.DBA.ODS_CALENDAR_TAGS.ITEM_ID)
    	  sioc:topic sioc:tag_iri (U_NAME, E_TAG)
    	.

    	sioc:tag_iri (DB.DBA.ODS_CALENDAR_TAGS.U_NAME, DB.DBA.ODS_CALENDAR_TAGS.E_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel E_TAG ;
    	  skos:isSubjectOf sioc:calendar_event_iri (U_NAME, WAM_INST, ITEM_ID)
    	.

      sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_TASKS.U_NAME, DB.DBA.ODS_CALENDAR_TASKS.WAI_NAME, DB.DBA.ODS_CALENDAR_TASKS.E_ID)
        a atom:Entry ;
      	atom:title E_SUBJECT ;
      	atom:source sioc:calendar_forum_iri (U_NAME, WAI_NAME) ;
      	atom:author foaf:person_iri (U_NAME) ;
        atom:published E_CREATED ;
      	atom:updated E_UPDATED ;
      	atom:content sioc:calendar_event_text_iri (U_NAME, WAI_NAME, E_ID)
     	.

      sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_TASKS.U_NAME, DB.DBA.ODS_CALENDAR_TASKS.WAI_NAME, DB.DBA.ODS_CALENDAR_TASKS.E_ID)
        a atom:Content ;
        atom:type "text/plain" ;
    	  atom:lang "en-US" ;
	      atom:body E_DESCRIPTION
	    .

      sioc:calendar_forum_iri (DB.DBA.ODS_CALENDAR_TASKS.U_NAME, DB.DBA.ODS_CALENDAR_TASKS.WAI_NAME)
        atom:contains sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID)
      .
      '
      ;
};

create procedure sioc.DBA.rdf_calendar_view_str_tables ()
{
  return
      '
      from DB.DBA.ODS_CALENDAR_EVENTS as calendar_events
      where (^{calendar_events.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_CALENDAR_TASKS as calendar_tasks
      where (^{calendar_tasks.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_CALENDAR_TAGS as calendar_tags
      where (^{calendar_tags.}^.U_NAME = ^{users.}^.U_NAME)
      '
      ;
};

create procedure sioc.DBA.rdf_calendar_view_str_maps ()
{
  return
    '
      #Event
      ods:calendar_event (calendar_events.U_NAME, calendar_events.WAI_NAME, calendar_events.E_ID)
        a calendar:vevent ;
        dc:title calendar_events.E_SUBJECT ;
        dct:created calendar_events.E_CREATED ;
     	  dct:modified calendar_events.E_UPDATED ;
	      dc:date calendar_events.E_UPDATED ;
	      dc:creator calendar_events.U_NAME ;
	      sioc:link ods:proxy (calendar_events.E_URI) ;
	      sioc:content calendar_events.E_DESCRIPTION ;
	      sioc:has_creator ods:user (calendar_events.U_NAME) ;
	      foaf:maker ods:person (calendar_events.U_NAME) ;
	      rdfs:seeAlso ods:proxy (calendar_events.SEE_ALSO) ;
	      sioc:has_container ods:calendar_forum (calendar_events.U_NAME, calendar_events.WAI_NAME)
	    .

      ods:calendar_forum (calendar_events.U_NAME, calendar_events.WAI_NAME)
        sioc:container_of ods:calendar_event (calendar_events.U_NAME, calendar_events.WAI_NAME, calendar_events.E_ID)
      .

	    ods:user (calendar_events.U_NAME)
	      sioc:creator_of ods:calendar_event (calendar_events.U_NAME, calendar_events.WAI_NAME, calendar_events.E_ID)
	    .

    	# Event tags
    	ods:calendar_event (calendar_tags.U_NAME, calendar_tags.WAM_INST, calendar_tags.ITEM_ID)
    	  sioc:topic ods:tag (calendar_tags.U_NAME, calendar_tags.E_TAG)
    	.

    	ods:tag (calendar_tags.U_NAME, calendar_tags.E_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel calendar_tags.E_TAG ;
    	  skos:isSubjectOf ods:calendar_event (calendar_tags.U_NAME, calendar_tags.WAM_INST, calendar_tags.ITEM_ID)
    	.

	#ods:calendar_event (calendar_events.U_NAME, calendar_events.WAI_NAME, calendar_events.E_ID)
	#a atom:Entry ;
	#atom:title E_SUBJECT ;
	#atom:source ods:calendar_forum (U_NAME, WAI_NAME) ;
	#atom:author ods:person (U_NAME) ;
	#atom:published E_CREATED ;
	#atom:updated E_UPDATED ;
	#atom:content ods:calendar_event_text (U_NAME, WAI_NAME, E_ID)
	#.

	#ods:calendar_event (calendar_events.U_NAME, calendar_events.WAI_NAME, calendar_events.E_ID)
	#a atom:Content ;
	#atom:type "text/plain" ;
	#  atom:lang "en-US" ;
	#      atom:body E_DESCRIPTION
	#.

	#ods:calendar_forum (calendar_events.U_NAME, calendar_events.WAI_NAME)
	#atom:contains ods:calendar_event (U_NAME, WAI_NAME, E_ID)
        #.
      
      #Task
      ods:calendar_event (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME, calendar_tasks.E_ID)
        a calendar:vtodo ;
        dc:title calendar_tasks.E_SUBJECT ;
        dct:created calendar_tasks.E_CREATED ;
     	  dct:modified calendar_tasks.E_UPDATED ;
	      dc:date calendar_tasks.E_UPDATED ;
	      dc:creator calendar_tasks.U_NAME ;
	      sioc:link ods:proxy (calendar_tasks.E_URI) ;
	      sioc:content calendar_tasks.E_DESCRIPTION ;
	      sioc:has_creator ods:user (calendar_tasks.U_NAME) ;
	      foaf:maker ods:person (calendar_tasks.U_NAME) ;
	      rdfs:seeAlso ods:proxy (calendar_tasks.SEE_ALSO) ;
	      sioc:has_container ods:calendar_forum (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME)
	    .

      ods:calendar_forum (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME)
        sioc:container_of ods:calendar_event (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME, calendar_tasks.E_ID)
      .

	    ods:user (calendar_tasks.U_NAME)
	      sioc:creator_of ods:calendar_event (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME, calendar_tasks.E_ID)
	    .

    	# Task tags
    	ods:calendar_event (calendar_tags.U_NAME, calendar_tags.WAM_INST, calendar_tags.ITEM_ID)
    	  sioc:topic ods:tag (calendar_tags.U_NAME, calendar_tags.E_TAG)
    	.

    	ods:tag (calendar_tags.U_NAME, calendar_tags.E_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel calendar_tags.E_TAG ;
    	  skos:isSubjectOf ods:calendar_event (calendar_tags.U_NAME, calendar_tags.WAM_INST, calendar_tags.ITEM_ID)
    	.

	#ods:calendar_event (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME, calendar_tasks.E_ID)
	#a atom:Entry ;
	#atom:title E_SUBJECT ;
	#atom:source ods:calendar_forum (U_NAME, WAI_NAME) ;
	#atom:author ods:person (U_NAME) ;
	#atom:published E_CREATED ;
	#atom:updated E_UPDATED ;
	#atom:content ods:calendar_event_text (U_NAME, WAI_NAME, E_ID)
	#.

	#ods:calendar_event (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME, calendar_tasks.E_ID)
	#a atom:Content ;
	#atom:type "text/plain" ;
	#  atom:lang "en-US" ;
	#      atom:body E_DESCRIPTION
	#.

	#ods:calendar_forum (calendar_tasks.U_NAME, calendar_tasks.WAI_NAME)
	#atom:contains ods:calendar_event (U_NAME, WAI_NAME, E_ID)
        #.
    '
    ;
}
;

grant select on ODS_CALENDAR_EVENTS to SPARQL_SELECT;
grant select on ODS_CALENDAR_TASKS to SPARQL_SELECT;
grant select on ODS_CALENDAR_TAGS to SPARQL_SELECT;
grant execute on ODS_CALENDAR_TAGS to SPARQL_SELECT;
grant execute on CAL.WA.event_url to SPARQL_SELECT;


-- RDF Views
ODS_RDF_VIEW_INIT ();
