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

create procedure CAL.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Calendar' do
  {
    (WAI_INST as DB.DBA.wa_Calendar).wa_drop_instance();
    commit work;
  }
}
;
CAL.WA.uninstall ()
;

create procedure CAL.WA.uninstall ()
{
  for select DB.DBA.DAV_SEARCH_PATH (COL_ID, 'C') path from WS.WS.SYS_DAV_COL where COL_DET = 'Calendar' do
  {
    DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
    commit work;
  }
}
;
CAL.WA.uninstall ()
;
                                                                                            -- Scheduler
VHOST_REMOVE (lpath => '/calendar');
VHOST_REMOVE (lpath => '/calendar/atom-pub');

-- Triggers
CAL.WA.exec_no_error('drop trigger WS.WS.CALENDAR_SYS_DAV_RES_AI');
CAL.WA.exec_no_error('drop trigger WS.WS.CALENDAR_SYS_DAV_RES_AU');
CAL.WA.exec_no_error('drop trigger WS.WS.CALENDAR_SYS_DAV_RES_AD');

-- Scheduler
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Alarm Scheduler\'');
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Upstream Scheduler\'');
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Attendees Scheduler\'');
CAL.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Exchange Scheduler\'');

-- NNTP
CAL.WA.exec_no_error ('DROP procedure DB.DBA.CALENDAR_NEWS_MSG_I');
CAL.WA.exec_no_error ('DROP procedure DB.DBA.CALENDAR_NEWS_MSG_U');
CAL.WA.exec_no_error ('DROP procedure DB.DBA.CALENDAR_NEWS_MSG_D');
CAL.WA.exec_no_error ('DB.DBA.NNTP_NEWS_MSG_DEL (\'CALENDAR\')');

-- Tables
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM_LOG');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM_EVENT');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ATTENDEES');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.SHARED');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.GRANTS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ANNOTATIONS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ALARMS');
CAL.WA.exec_no_error ('DROP TABLE CAL.WA.EVENT_GRANTS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.EVENT_COMMENTS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.EVENTS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.EXCHANGE');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.TAGS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.SETTINGS');

-- Types
CAL.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'Calendar\'');
CAL.WA.exec_no_error('drop type wa_Calendar');

-- Views
CAL.WA.exec_no_error('drop view CAL..TAGS_VIEW');
CAL.WA.exec_no_error('drop view CAL..MY_CALENDARS');
CAL.WA.exec_no_error ('drop view CAL..EVENT_GRANTS_VIEW');

-- Registry
registry_remove ('calendar_path');
registry_remove ('calendar_version');
registry_remove ('calendar_build');
registry_remove ('cal_note_update');
registry_remove ('cal_class_update');
registry_remove ('cal_privacy_update');
registry_remove ('cal_description_update');
registry_remove ('cal_index_version');
registry_remove ('cal_uid_version');
registry_remove ('cal_attendee_update');
registry_remove ('cal_path_upgrade2');
registry_remove ('cal_atom_update');
registry_remove ('cal_services_update');

-- Procedures
create procedure CAL.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'CAL.WA.%') do
  {
    if (P_NAME not in ('CAL.WA.exec_no_error', 'CAL.WA.drop_procedures'))
      CAL.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for Polls
CAL.WA.drop_procedures();
CAL.WA.exec_no_error('DROP procedure CAL.WA.drop_procedures');

-- dropping SIOC procs
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.calendar_event_iri_internal');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.calendar_event_iri');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.calendar_comment_iri');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.calendar_annotation_iri');
CAL.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_calendar_sioc');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.event_insert');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.event_delete');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.calendar_comment_insert');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.calendar_comment_delete');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.cal_annotation_insert');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.cal_annotation_delete');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.cal_claims_insert');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.cal_claims_delete');
CAL.WA.exec_no_error('DROP procedure SIOC.DBA.ods_calendar_sioc_init');

-- RDF Views - procs & views
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_calendar_view_str');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_calendar_view_str_tables');
CAL.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_calendar_view_str_maps');

CAL.WA.exec_no_error ('DROP procedure DB.DBA.ODS_CALENDAR_TAGS');
CAL.WA.exec_no_error ('DROP view DB.DBA.ODS_CALENDAR_EVENTS');
CAL.WA.exec_no_error ('DROP view DB.DBA.ODS_CALENDAR_TASKS');
CAL.WA.exec_no_error ('DROP view DB.DBA.ODS_CALENDAR_TAGS');

-- reinit
ODS_RDF_VIEW_INIT ();

-- dropping API procs
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."setting_set"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."setting_xml"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.get"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.event.new"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.event.edit"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.task.new"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.task.edit"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.delete"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.import"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.export"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.comment.get"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.comment.new"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.comment.delete"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.publication.new"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.publication.edit"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.publication.delete"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.subscription.new"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.subscription.edit"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.subscription.delete"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.options.set"');
CAL.WA.exec_no_error ('DROP procedure ODS.ODS_API."calendar.options.get"');

-- dropping DET procs
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_FIXNAME"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_COMPOSE_ICS_NAME"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_ACCESS_PARAMS"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_AUTHENTICATE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_AUTHENTICATE_HTTP"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_GET_PARENT"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_COL_CREATE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_COL_MOUNT"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_COL_MOUNT_HERE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_DELETE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_RES_UPLOAD"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_PROP_REMOVE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_PROP_SET"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_PROP_GET"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_PROP_LIST"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_DIR_SINGLE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_DIR_LIST"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_FC_PRED_METAS"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_FC_TABLE_METAS"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_FC_PRINT_WHERE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_DIR_FILTER"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_SEARCH_ID_IMPL"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_SEARCH_ID"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_SEARCH_PATH"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_RES_UPLOAD_COPY"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_RES_UPLOAD_MOVE"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_RES_CONTENT"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_SYMLINK"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_DEREFERENCE_LIST"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_RESOLVE_PATH"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_LOCK"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_UNLOCK"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_IS_LOCKED"');
CAL.WA.exec_no_error('DROP procedure DB.DBA."calendar_DAV_LIST_LOCKS"');

-- final proc
CAL.WA.exec_no_error('DROP procedure CAL.WA.exec_no_error');
