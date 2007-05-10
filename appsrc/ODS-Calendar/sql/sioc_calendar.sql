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
use SIOC;

-------------------------------------------------------------------------------
--
create procedure calendar_event_iri (in domain_id varchar, in event_id int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
   where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/calendar/%U/%d', get_cname(), get_base_path (), _member, _inst, event_id);
}
;

-------------------------------------------------------------------------------
--
create procedure fill_ods_calendar_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare c_iri, creator_iri varchar;

  for (select WAI_ID, WAI_NAME, WAM_USER
         from DB.DBA.WA_INSTANCE i,
              DB.DBA.WA_MEMBER m
        where m.WAM_INST = i.WAI_NAME
          and ((m.WAM_IS_PUBLIC = 1 and _wai_name is null) or i.WAI_NAME = _wai_name)) do
  {
    c_iri := polls_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

    for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = WAI_ID) do
      event_insert (graph_iri,
                    c_iri,
                    creator_iri,
                    E_ID,
                    E_DOMAIN_ID,
                    E_SUBJECT,
                    E_DESCRIPTION,
                    E_LOCATION,
                    E_EVENT,
                    E_EVENT_START,
                    E_EVENT_END,
                    E_CREATED,
                    E_UPDATED,
                    E_TAGS);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure event_insert (
  in graph_iri varchar,
  in c_iri varchar,
  in creator_iri varchar,
  inout event_id integer,
  inout domain_id integer,
  inout subject varchar,
  inout description varchar,
  inout location varchar,
  inout event varchar,
  inout eventStart datetime,
  inout eventEnd datetime,
  inout created datetime,
  inout updated datetime,
  inout tags varchar)
{
  declare iri varchar;

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
      c_iri := calendar_iri (WAI_NAME);
      creator_iri := user_iri (WAM_USER);
    }

  if (not isnull (graph_iri)) {
    iri := calendar_event_iri (domain_id, event_id);

    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, subject, created, updated, CAL.WA.event_url (domain_id, event_id), description);
    ods_sioc_tags (graph_iri, iri, tags);

    DB.DBA.RDF_QUAD_URI   (graph_iri, iri, rdf_iri ('type'), vcal_iri ('vevent'));
    DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, vcal_iri ('url'), CAL.WA.event_url (domain_id, event_id));
    if (not isnull (subject))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, vcal_iri ('summary'), subject);
    if (not isnull (description))
      DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, vcal_iri ('description'), description);
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure event_delete (
  inout event_id integer,
  inout domain_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := calendar_event_iri (domain_id, event_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_I after insert on CAL.WA.EVENTS referencing new as N
{
  event_insert (null,
                null,
                null,
                N.E_ID,
                N.E_DOMAIN_ID,
                N.E_SUBJECT,
                N.E_DESCRIPTION,
                N.E_LOCATION,
                N.E_EVENT,
                N.E_EVENT_START,
                N.E_EVENT_END,
                N.E_CREATED,
                N.E_UPDATED,
                N.E_TAGS);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_U after update on CAL.WA.EVENTS referencing old as O, new as N
{
  event_delete (O.E_ID,
                O.E_DOMAIN_ID);
  event_insert (null,
                null,
                null,
                N.E_ID,
                N.E_DOMAIN_ID,
                N.E_SUBJECT,
                N.E_DESCRIPTION,
                N.E_LOCATION,
                N.E_EVENT,
                N.E_EVENT_START,
                N.E_EVENT_END,
                N.E_CREATED,
                N.E_UPDATED,
                N.E_TAGS);
}
;

-------------------------------------------------------------------------------
--
create trigger EVENTS_SIOC_D before delete on CAL.WA.EVENTS referencing old as O
{
  event_delete (O.E_ID,
                O.E_DOMAIN_ID);
}
;

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

-- RDF Views
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
    foreach (any t in V) do {
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

create procedure view ODS_CALENDAR_TAGS as ODS_CALENDAR_TAGS () (WAM_INST varchar, U_NAME varchar, ITEM_ID int, E_TAG varchar);

-------------------------------------------------------------------------------
--
create procedure sioc.DBA.rdf_calendar_view_str ()
{
  return
      '
        #Event
        sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME, DB.DBA.ODS_CALENDAR_EVENTS.E_ID)
          a calendar:vevent option (EXCLUSIVE) ;
        dc:title E_SUBJECT ;
        dct:created E_CREATED ;
       	dct:modified E_UPDATED ;
	      dc:date E_UPDATED ;
	      ann:created E_CREATED ;
	      dc:creator U_NAME ;
	      sioc:link sioc:proxy_iri (E_URI) ;
	      sioc:content E_DESCRIPTION ;
	      sioc:has_creator sioc:user_iri (U_NAME) ;
	      foaf:maker foaf:person_iri (U_NAME) ;
	      rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
	      sioc:has_container sioc:calendar_forum_iri (U_NAME, WAI_NAME) .

        sioc:calendar_forum_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME) sioc:container_of sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID) .

	      sioc:user_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME) sioc:creator_of sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID) .

      	# Event tags
      	sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_TAGS.U_NAME, DB.DBA.ODS_CALENDAR_TAGS.WAM_INST, DB.DBA.ODS_CALENDAR_TAGS.ITEM_ID) sioc:topic sioc:tag_iri (U_NAME, E_TAG) .

      	sioc:tag_iri (DB.DBA.ODS_CALENDAR_TAGS.U_NAME, DB.DBA.ODS_CALENDAR_TAGS.E_TAG) a skos:Concept ;
      	skos:prefLabel E_TAG ;
      	skos:isSubjectOf sioc:calendar_event_iri (U_NAME, WAM_INST, ITEM_ID) .

        sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME, DB.DBA.ODS_CALENDAR_EVENTS.E_ID) a atom:Entry ;
      	atom:title E_SUBJECT ;
      	atom:source sioc:calendar_forum_iri (U_NAME, WAI_NAME) ;
      	atom:author foaf:person_iri (U_NAME) ;
        atom:published E_CREATED ;
      	atom:updated E_UPDATED ;
      	atom:content sioc:calendar_event_text_iri (U_NAME, WAI_NAME, E_ID) .

        sioc:calendar_event_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME, DB.DBA.ODS_CALENDAR_EVENTS.E_ID) a atom:Content ;
        atom:type "text/plain" ;
      	atom:lang "en-US" ;
	      atom:body E_DESCRIPTION .

        sioc:calendar_forum_iri (DB.DBA.ODS_CALENDAR_EVENTS.U_NAME, DB.DBA.ODS_CALENDAR_EVENTS.WAI_NAME) atom:contains sioc:calendar_event_iri (U_NAME, WAI_NAME, E_ID) .
      '
      ;
};

grant select on ODS_CALENDAR_EVENTS to "SPARQL";
grant select on ODS_CALENDAR_TAGS to "SPARQL";

-- RDF Views
ODS_RDF_VIEW_INIT ();
