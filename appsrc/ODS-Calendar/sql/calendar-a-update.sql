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

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_note_update') = '1')
    return;

  delete from CAL.WA.EVENTS where E_KIND > 1;
  registry_set ('cal_note_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_privacy_update') = '1')
    return;

  set triggers off;
  update CAL.WA.EVENTS set E_PRIVACY = 1;
  set triggers on;

  registry_set ('cal_privacy_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_description_update') = '1')
    return;

  CAL.WA.exec_no_error ('alter table CAL.WA.EVENTS add E_TMP varchar', 'C', 'CAL.WA.EVENTS', 'E_TMP');
  CAL.WA.exec_no_error ('update CAL.WA.EVENTS set E_TMP = E_DESCRIPTION');
  CAL.WA.exec_no_error ('alter table CAL.WA.EVENTS drop E_DESCRIPTION', 'D', 'CAL.WA.EVENTS', 'E_DESCRIPTION');
  CAL.WA.exec_no_error ('alter table CAL.WA.EVENTS add E_DESCRIPTION long varchar', 'C', 'CAL.WA.EVENTS', 'E_DESCRIPTION');
  CAL.WA.exec_no_error ('update CAL.WA.EVENTS set E_DESCRIPTION = E_TMP');
  CAL.WA.exec_no_error ('alter table CAL.WA.EVENTS drop E_TMP', 'D', 'CAL.WA.EVENTS', 'E_TMP');

  registry_set ('cal_description_update', '1');
}
;
CAL.WA.tmp_update();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_uid_update') = '1')
    return;

  set triggers off;
  update CAL.WA.EVENTS set E_UID = CAL.WA.uid () where E_UID is null;
  set triggers on;

  registry_set ('cal_uid_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_attendee_update') = '1')
    return;

  set triggers off;
  update CAL.WA.EVENTS set E_ATTENDEES = 0 where E_ATTENDEES is null;
  set triggers on;

  registry_set ('cal_attendee_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_attendee_update2') = '1')
    return;

  set triggers off;
  update CAL.WA.ATTENDEES set AT_ROLE = 'REQ-PARTICIPANT';
  set triggers on;

  registry_set ('cal_attendee_update2', '1');
}
;
CAL.WA.tmp_update ();

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_atom_update') = '2')
    return;

  for (select * from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'Calendar') do
  {
    VHOST_REMOVE (lpath => CAL.WA.atom_lpath (WAI_ID));
  }

  registry_set ('cal_atom_update', '2');
}
;
CAL.WA.tmp_update ()
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER
                join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'Calendar'
          and WAM_MEMBER_TYPE = 1) do {
    CAL.WA.domain_update (WAI_ID, WAM_USER);
  }
}
;
CAL.WA.tmp_update ()
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  declare cTimezone integer;

  if (registry_get ('cal_tasks_version') = '1')
    return;

  for (select E_ID          _id,
              E_DOMAIN_ID   _domain_id,
              E_EVENT_START _start,
              E_EVENT_END   _end
         from CAL.WA.EVENTS
        where E_KIND = 1) do
  {
    cTimezone := CAL.WA.settings_timeZone2 (_domain_id);
    if (not isnull (_start)) {
      _start := CAL.WA.event_gmt2user (_start, cTimezone);
      _start := CAL.WA.dt_join (_start, CAL.WA.dt_timeEncode (12, 0));
    }
    if (not isnull (_end))
    {
      _end := CAL.WA.event_gmt2user (_end, cTimezone);
      _end := CAL.WA.dt_join (_end, CAL.WA.dt_timeEncode (12, 0));
    }
    update CAL.WA.EVENTS
       set E_EVENT_START = CAL.WA.event_user2gmt (_start, cTimezone),
           E_EVENT_END = CAL.WA.event_user2gmt (_end, cTimezone)
     where E_ID = _id;
  }
  registry_set ('cal_tasks_version', '1');
}
;
CAL.WA.tmp_update ()
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_acl_update') = '1')
    return;
  registry_set ('cal_acl_update', '1');

  set triggers off;
  update CAL.WA.EVENTS set E_ACL = null where E_ACL is not null;
  set triggers on;
}
;

CAL.WA.tmp_update ();
