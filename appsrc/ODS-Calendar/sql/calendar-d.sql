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

-- Triggers
CAL.WA.exec_no_error('drop trigger WS.WS.CALENDAR_SYS_DAV_RES_AI');
CAL.WA.exec_no_error('drop trigger WS.WS.CALENDAR_SYS_DAV_RES_AU');
CAL.WA.exec_no_error('drop trigger WS.WS.CALENDAR_SYS_DAV_RES_AD');

-- Scheduler
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Alarm Scheduler\'');
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Upstream Scheduler\'');
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Attendees Scheduler\'');
CAL.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Exchange Scheduler\'');

-- Tables
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM_LOG');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM_EVENT');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ATTENDEES');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.SHARED');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.GRANTS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ANNOTATIONS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ALARMS');
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
registry_remove ('cal_atom_update');

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
CAL.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_calendar_sioc');
CAL.WA.exec_no_error('DROP procedure SIOC.DBA.ods_calendar_sioc_init');

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

-- final proc
CAL.WA.exec_no_error('DROP procedure CAL.WA.exec_no_error');
