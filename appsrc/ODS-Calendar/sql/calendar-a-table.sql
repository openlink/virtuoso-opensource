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

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.upstream_event_update (
  in domain_id integer,
  in event_id integer,
  in event_uid varchar,
  in event_tags varchar,
  in action varchar)
{
  return;
}
;

-------------------------------------------------------------------------------
--
-- Sequences
--
-------------------------------------------------------------------------------
CAL.WA.exec_no_error (
  'sequence_set (\'CAL.WA.event_id\', %d, 0)', 'S', 'CAL.WA.EVENTS', 'E_ID'
)
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.TAGS (
    T_DOMAIN_ID integer not null,
    T_TAG varchar,
    T_COUNT integer,

    primary key (T_DOMAIN_ID, T_TAG)
  )
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_grants_update') = '1')
    return;

  CAL.WA.exec_no_error('DROP TABLE CAL.WA.GRANTS');

  registry_set ('cal_grants_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.GRANTS (
    G_ID integer identity,
    G_DOMAIN_ID integer not null,
    G_ACCOUNT_ID integer not null,
    G_ENABLE integer default 1,
    G_MODE varchar default \'R\',

    PRIMARY KEY (G_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_GRANTS_01 on CAL.WA.GRANTS (G_DOMAIN_ID)
');

CAL.WA.exec_no_error ('
  create index SK_GRANTS_02 on CAL.WA.GRANTS (G_ACCOUNT_ID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.SHARED (
    S_ID integer identity,
    S_DOMAIN_ID integer not null,
    S_GRANT_ID integer,
    S_CALENDAR_ID integer not null,
    S_VISIBLE integer default 1,
    S_COLOR varchar,
    S_OPTIONS long varchar,

    constraint FK_SHARED_01 FOREIGN KEY (S_GRANT_ID) references CAL.WA.GRANTS (G_ID) ON DELETE CASCADE,

    PRIMARY KEY (S_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_SHARED_01 on CAL.WA.SHARED (S_DOMAIN_ID, S_CALENDAR_ID)
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.my_calendars (
  in domain_id any,
  in account_role varchar)
{
  declare calendar_id integer;

  result_names (calendar_id);
  result (domain_id);

  if (account_role in ('public', 'guest'))
    return;

  for (select a.WAI_IS_PUBLIC,
              b.S_GRANT_ID,
              b.S_CALENDAR_ID
         from DB.DBA.WA_INSTANCE a,
              CAL.WA.SHARED b
        where a.WAI_TYPE_NAME = 'Calendar'
          and a.WAI_ID = b.S_CALENDAR_ID
          and b.S_DOMAIN_ID = domain_id
          and b.S_VISIBLE = 1) do
  {
    if (isnull (S_GRANT_ID))
    {
      if (WAI_IS_PUBLIC = 1)
        result (S_CALENDAR_ID);
    } else {
      for (select G_ID from CAL.WA.GRANTS where G_ID = S_GRANT_ID and G_ENABLE = 1) do
        result (S_CALENDAR_ID);
    }
  }
}
;

CAL.WA.exec_no_error ('drop view CAL..MY_CALENDARS');
CAL.WA.exec_no_error ('
  create procedure view CAL..MY_CALENDARS as CAL.WA.my_calendars (domain_id, account_role) (CALENDAR_ID integer)
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.EVENTS (
    E_ID integer not null,
    E_UID varchar,
    E_DOMAIN_ID integer not null,
    E_KIND integer default 0,             -- 0 - Event
                                          -- 1 - Task
    E_PRIVACY integer default 0,          -- 0 - PRIVATE
                                          -- 1 - PUBLIC
    E_SUBJECT varchar,
    E_DESCRIPTION long varchar,
    E_NOTES long varchar,
    E_LOCATION varchar,
    E_TAGS varchar,

    -- Event fields
    E_EVENT integer default 1,
    E_EVENT_START datetime,
    E_EVENT_END datetime,
    E_REPEAT char (2) default \'\',       -- \'\' - no repeat,
                                          -- D1 - every day,
                                          -- D2 - every weekday ,
                                          -- W1 - every [] week on (day),
                                          -- M1 - day [] of every [] month(s),
                                          -- M2 - the (f|s|t|f|l) (day) of every [] month(s),
                                          -- Y1 - every (month) (date),
                                          -- Y2 - the ((f|s|t|f|l)) (day) of (mounth)  //
    E_REPEAT_PARAM1 integer,              -- units used to determine the date on which to repeat the event
    E_REPEAT_PARAM2 integer,
    E_REPEAT_PARAM3 integer,
    E_REPEAT_UNTIL date,                  -- repeat until this date or null (infinite)
    E_REPEAT_EXCEPTIONS long varchar,     -- mark the dates on which the event is hidden /set on deletion of the repeated event/ format is: yyyymmdd
    E_REMINDER integer default 0,         -- default is no remainder
    E_REMINDER_DATE datetime,             -- keep when to remind the user.
                                          -- calculated through insert/update.
                                          -- reminder procedure set this to NULL when user is reminded, in case of recursive event is set to next remind date
    -- Task fields
    E_PRIORITY integer,                   -- 1 - highest,
                                          -- 2 - high
                                          -- 3 - normal,
                                          -- 4 - low
                                          -- 5 - lowest
    E_COMPLETE integer,                   -- 0,
                                          -- 25,
                                          -- 50,
                                          -- 75,
                                          -- 100
    E_STATUS varchar,                     -- Not Started
                                          -- In Progress;
                                          -- Completed,
                                          -- Waiting,
                                          -- Deferred
    E_COMPLETED datetime,
    E_CREATED datetime,
    E_UPDATED datetime,

    primary key (E_ID)
  )
');

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_UID varchar', 'C', 'CAL.WA.EVENTS', 'E_UID'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_NOTES long varchar', 'C', 'CAL.WA.EVENTS', 'E_NOTES'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_COMPLETED datetime', 'C', 'CAL.WA.EVENTS', 'E_COMPLETED'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_PRIVACY integer default 0', 'C', 'CAL.WA.EVENTS', 'E_PRIVACY'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS drop E_CLASS', 'D', 'CAL.WA.EVENTS', 'E_CLASS'
);

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

  update CAL.WA.EVENTS set E_PRIVACY = 1;
  registry_set ('cal_privacy_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_description_update ()
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
CAL.WA.tmp_description_update();

CAL.WA.exec_no_error ('
  create index SK_EVENTS_01 on CAL.WA.EVENTS (E_DOMAIN_ID, E_KIND, E_EVENT_START)
');

CAL.WA.exec_no_error ('
  create index SK_EVENTS_02 on CAL.WA.EVENTS (E_REMINDER_DATE)
');

CAL.WA.exec_no_error ('
  create index SK_EVENTS_03 on CAL.WA.EVENTS (E_UID)
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AI after insert on CAL.WA.EVENTS referencing new as N {
    if (isnull (N.E_UID))
    {
      set triggers off;
      N.E_UID := sprintf (\'%s@%s\', uuid (), sys_stat (\'st_host_name\'));
      update CAL.WA.EVENTS set E_UID = N.E_UID where E_ID = N.E_ID;
      set triggers on;
    }
    CAL.WA.tags_update (N.E_DOMAIN_ID, \'\', N.E_TAGS);
    CAL.WA.domain_ping (N.E_DOMAIN_ID);
    if (N.E_REMINDER <> 0)
    {
      set triggers off;
      CAL.WA.event_addReminder (CAL.WA.event_user2gmt (now (), CAL.WA.settings_timeZone2 (N.E_DOMAIN_ID)),
                                N.E_ID,
                                N.E_DOMAIN_ID,
                                N.E_EVENT,
                                N.E_EVENT_START,
                                N.E_EVENT_END,
                                N.E_REPEAT,
                                N.E_REPEAT_PARAM1,
                                N.E_REPEAT_PARAM2,
                                N.E_REPEAT_PARAM3,
                                N.E_REPEAT_UNTIL,
                                N.E_REPEAT_EXCEPTIONS,
                                CAL.WA.settings_weekStarts2 (N.E_DOMAIN_ID),
                                N.E_REMINDER,
                                null);
      set triggers on;
    }

    CAL.WA.upstream_event_update (N.E_DOMAIN_ID, N.E_ID, N.E_UID, N.E_TAGS, \'I\');
  }
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AU after update on CAL.WA.EVENTS referencing  old as O, new as N {
    if (isnull (N.E_UID))
    {
      set triggers off;
      N.E_UID := sprintf (\'%s@%s\', uuid (), sys_stat (\'st_host_name\'));
      update CAL.WA.EVENTS set E_UID = N.E_UID where E_ID = N.E_ID;
      set triggers on;
    }
    CAL.WA.tags_update (N.E_DOMAIN_ID, O.E_TAGS, N.E_TAGS);
    CAL.WA.domain_ping (N.E_DOMAIN_ID);
    delete from CAL.WA.ALARMS where A_EVENT_ID = O.E_ID;

    set triggers off;

    if ((O.E_REPEAT        <> N.E_REPEAT) or
        (O.E_REPEAT_PARAM1 <> N.E_REPEAT_PARAM1) or
        (O.E_REPEAT_PARAM2 <> N.E_REPEAT_PARAM2) or
        (O.E_REPEAT_PARAM3 <> N.E_REPEAT_PARAM3))
    {
      update CAL.WA.EVENTS set E_REPEAT_EXCEPTIONS = \'\' where E_ID = N.E_ID;
    }

    if (N.E_REMINDER <> 0)
    {
      CAL.WA.event_addReminder (CAL.WA.event_user2gmt (now (), CAL.WA.settings_timeZone2 (N.E_DOMAIN_ID)),
                                N.E_ID,
                                N.E_DOMAIN_ID,
                                N.E_EVENT,
                                N.E_EVENT_START,
                                N.E_EVENT_END,
                                N.E_REPEAT,
                                N.E_REPEAT_PARAM1,
                                N.E_REPEAT_PARAM2,
                                N.E_REPEAT_PARAM3,
                                N.E_REPEAT_UNTIL,
                                N.E_REPEAT_EXCEPTIONS,
                                CAL.WA.settings_weekStarts2 (N.E_DOMAIN_ID),
                                N.E_REMINDER,
                                null);
    }
    set triggers on;

    CAL.WA.upstream_event_update (N.E_DOMAIN_ID, N.E_ID, N.E_UID, N.E_TAGS, \'U\');
  }
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AD after delete on CAL.WA.EVENTS referencing old as O {
    CAL.WA.tags_update (O.E_DOMAIN_ID, O.E_TAGS, \'\');
    delete from CAL.WA.ALARMS where A_EVENT_ID = O.E_ID;

    CAL.WA.upstream_event_update (O.E_DOMAIN_ID, O.E_ID, O.E_UID, O.E_TAGS, \'D\');
  }
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tags_update (
  inout domain_id integer,
  in oTags any,
  in nTags any)
{
  declare N integer;

  oTags := split_and_decode (oTags, 0, '\0\0,');
  nTags := split_and_decode (nTags, 0, '\0\0,');

  foreach (any tag in oTags) do
  {
    if (not CAL.WA.vector_contains (nTags, lcase (tag)))
      update CAL.WA.TAGS
         set T_COUNT = T_COUNT - 1
       where T_DOMAIN_ID = domain_id
         and T_TAG = lcase (tag);
  }
  foreach (any tag in nTags) do
  {
    if (not CAL.WA.vector_contains (oTags, lcase (tag)))
      if (exists (select 1 from CAL.WA.TAGS where T_DOMAIN_ID = domain_id and T_TAG = lcase (tag)))
      {
        update CAL.WA.TAGS
           set T_COUNT = T_COUNT + 1
         where T_DOMAIN_ID = domain_id
           and T_TAG = lcase (tag);
      } else {
       insert replacing CAL.WA.TAGS (T_DOMAIN_ID, T_TAG, T_COUNT)
         values (domain_id, lcase (tag), 1);
      }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.EVENTS_E_SUBJECT_int (inout vtb any, inout d_id any, in mode any)
{
  declare tags any;

  for (select * from CAL.WA.EVENTS where E_ID = d_id) do
  {
    vt_batch_feed (vtb, sprintf('^R%d', E_DOMAIN_ID), mode);

    vt_batch_feed (vtb, sprintf('^UID%d', coalesce (CAL.WA.domain_owner_id (E_DOMAIN_ID), 0)), mode);

    vt_batch_feed (vtb, coalesce(E_SUBJECT, ''), mode);

    vt_batch_feed (vtb, coalesce (E_DESCRIPTION, ''), mode);

    vt_batch_feed (vtb, coalesce (E_LOCATION, ''), mode);

    vt_batch_feed (vtb, coalesce (E_NOTES, ''), mode);
    
    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = E_DOMAIN_ID and WAI_TYPE_NAME = 'Calendar' and WAI_IS_PUBLIC = 1))
      vt_batch_feed (vtb, '^public', mode);

    tags := split_and_decode (E_TAGS, 0, '\0\0,');
    foreach (any tag in tags) do
    {
      tag := concat('^T', trim(tag));
      tag := replace (tag, ' ', '_');
      tag := replace (tag, '+', '_');
      vt_batch_feed (vtb, tag, mode);
    }
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.EVENTS_E_SUBJECT_index_hook (inout vtb any, inout d_id any)
{
  return CAL.WA.EVENTS_E_SUBJECT_int (vtb, d_id, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.EVENTS_E_SUBJECT_unindex_hook (inout vtb any, inout d_id any)
{
  return CAL.WA.EVENTS_E_SUBJECT_int (vtb, d_id, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_drop_index ()
{
  if (registry_get ('cal_index_version') = '4')
    return;

    CAL.WA.exec_no_error ('drop table CAL.WA.EVENTS_E_SUBJECT_WORDS');

  registry_set ('cal_index_version', '4');
}
;
CAL.WA.tmp_drop_index ();

CAL.WA.exec_no_error ('
  create text index on CAL.WA.EVENTS (E_SUBJECT) with key E_ID clustered with (E_DOMAIN_ID, E_UPDATED) using function language \'x-ViDoc\'
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_uid_update') = '1')
    return;

  update CAL.WA.EVENTS set E_UID = sprintf ('%s@%s', uuid (), sys_stat ('st_host_name')) where E_UID is null;

  registry_set ('cal_uid_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.ALARMS (
    A_ID integer identity,
    A_DOMAIN_ID integer not null,
    A_EVENT_ID integer not null,
    A_EVENT_OFFSET integer default 0,
    A_ACTION integer default 0,           -- 0 - Display
                                          -- 1 - Mail
    A_TRIGGER datetime,
    A_SHOWN datetime,

    constraint FK_ALARMS_01 FOREIGN KEY (A_EVENT_ID) references CAL.WA.EVENTS (E_ID) ON DELETE CASCADE,

    primary key (A_ID)
  )
');

CAL.WA.exec_no_error (
  'alter table CAL.WA.ALARMS drop A_REPEAT', 'D', 'CAL.WA.ALARMS', 'A_REPEAT'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.ALARMS drop A_DURATION', 'D', 'CAL.WA.ALARMS', 'A_DURATION'
);

CAL.WA.exec_no_error (
  'drop trigger CAL.WA.ALARMS_AU'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.ALARMS add A_SHOWN datetime', 'C', 'CAL.WA.ALARMS', 'A_SHOWN'
);

CAL.WA.exec_no_error ('
  create index SK_ALARMS_01 on CAL.WA.ALARMS (A_DOMAIN_ID, A_TRIGGER)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.ANNOTATIONS (
    A_ID integer identity,
    A_DOMAIN_ID integer not null,
    A_OBJECT_ID integer not null,
    A_BODY long varchar,
    A_CONTEXT varchar,
    A_AUTHOR varchar,
    A_CREATED datetime,
    A_UPDATED datetime,

    constraint FK_CAL_ANNOTATIONS_01 FOREIGN KEY (A_OBJECT_ID) references CAL.WA.EVENTS (E_ID) on delete cascade,

    primary key (A_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_CAL_ANNOTATIONS_01 on CAL.WA.ANNOTATIONS (A_OBJECT_ID, A_ID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.SETTINGS (
    S_ACCOUNT_ID integer not null,
    S_DATA varchar,

    primary key(S_ACCOUNT_ID)
  )
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tags_procedure (
  in tags any)
{
  declare tag varchar;

  result_names (tag);
  tags := split_and_decode (tags, 0, '\0\0,');
  foreach (any tag in tags) do
    result (trim (tag));
}
;

CAL.WA.exec_no_error ('
  create procedure view CAL..TAGS_VIEW as CAL.WA.tags_procedure (tags) (TV_TAG varchar)
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'Calendar Alarm Scheduler\', now(), \'CAL.WA.alarm_scheduler ()\', 30)
')
;

-------------------------------------------------------------------------------
--
--  Upstreams
--
-------------------------------------------------------------------------------
CAL.WA.exec_no_error ('
  create table CAL.WA.UPSTREAM (
    U_ID integer identity,
    U_DOMAIN_ID integer,
    U_NAME varchar,
    U_URI varchar,
    U_USER varchar,
    U_PASSWORD varchar,
    U_INCLUDE varchar,
    U_EXCLUDE varchar,

    primary key (U_ID)
  )
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.UPSTREAM_EVENT (
    UE_ID integer identity,
    UE_UPSTREAM_ID integer,
    UE_EVENT_ID integer,
    UE_EVENT_UID varchar,
    UE_ACTION char (1),           -- I - insert, U - update, D - delete
    UE_STATUS integer default 0,  -- 1 - sent

    constraint FK_UPSTREAM_EVENT_01 FOREIGN KEY (UE_UPSTREAM_ID) references CAL.WA.UPSTREAM (U_ID) on delete cascade,

    primary key (UE_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_UPSTREAM_EVENT_01 on CAL.WA.UPSTREAM_EVENT (UE_UPSTREAM_ID, UE_EVENT_ID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.UPSTREAM_LOG (
    UL_ID integer identity,
	  UL_UPSTREAM_ID integer,
	  UL_DT datetime not null,
	  UL_MESSAGE varchar not null,

	  constraint FK_UPSTREAM_LOG_01 foreign key (UL_UPSTREAM_ID) references CAL.WA.UPSTREAM (U_ID) on delete cascade,

    primary key (UL_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_UPSTREAM_LOG_01 on CAL.WA.UPSTREAM_LOG (UL_UPSTREAM_ID, UL_DT)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'Calendar Upstream Scheduler\', now(), \'CAL.WA.upstream_scheduler ()\', 10)
')
;

