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
  }
}
;
CAL.WA.uninstall ()
;

-- Scheduler
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Alarm Scheduler\'');
CAL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Calendar Upstream Scheduler\'');

-- Tables
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM_LOG');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM_EVENT');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.UPSTREAM');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.GRANTS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.SHARED');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ANNOTATIONS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.ALARMS');
CAL.WA.exec_no_error('DROP TABLE CAL.WA.EVENTS');
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
registry_remove ('cal_description_update');
registry_remove ('cal_index_version');

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

-- final proc
CAL.WA.exec_no_error('DROP procedure CAL.WA.exec_no_error');
