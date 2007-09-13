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
CAL.WA.exec_no_error ('
  create table CAL.WA.GRANTS (
    G_ID integer identity,
    G_GRANTER_ID integer not null,
    G_GRANTEE_ID integer not null,
    G_EVENT_ID integer not null,

    PRIMARY KEY (G_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_GRANTS_01 on CAL.WA.GRANTS (G_GRANTER_ID, G_EVENT_ID)
');

CAL.WA.exec_no_error ('
  create index SK_GRANTS_02 on CAL.WA.GRANTS (G_GRANTEE_ID, G_EVENT_ID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.EVENTS (
    E_ID integer not null,
    E_DOMAIN_ID integer not null,
    E_KIND integer default 0,             -- 0 - Event
                                          -- 1 - Task
                                          -- 2 - Notes
    E_CLASS integer default 0,            -- 0 - PUBLIC
                                          -- 1 - PRIVATE
                                          -- 2 - CONFIDENTIAL
    E_SUBJECT varchar,
    E_DESCRIPTION varchar,
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
    E_CREATED datetime,
    E_UPDATED datetime,

    primary key (E_ID)
  )
');

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_NOTES long varchar', 'C', 'CAL.WA.EVENTS', 'E_NOTES'
);

CAL.WA.exec_no_error ('
  create index SK_EVENTS_01 on CAL.WA.EVENTS (E_DOMAIN_ID, E_KIND, E_EVENT_START)
');

CAL.WA.exec_no_error ('
  create index SK_EVENTS_02 on CAL.WA.EVENTS (E_REMINDER_DATE)
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AI after insert on CAL.WA.EVENTS referencing new as N {
    CAL.WA.tags_update (N.E_DOMAIN_ID, \'\', N.E_TAGS);
    CAL.WA.domain_ping (N.E_DOMAIN_ID);
  }
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AU after update on CAL.WA.EVENTS referencing  old as O, new as N {
    CAL.WA.tags_update (N.E_DOMAIN_ID, O.E_TAGS, N.E_TAGS);
    CAL.WA.domain_ping (N.E_DOMAIN_ID);
  }
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AD after delete on CAL.WA.EVENTS referencing old as O {
    CAL.WA.tags_update (O.E_DOMAIN_ID, O.E_TAGS, \'\');
    delete from CAL.WA.GRANTS where G_EVENT_ID = O.E_ID;
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

  foreach (any tag in oTags) do {
    if (not CAL.WA.vector_contains (nTags, lcase (tag)))
      update CAL.WA.TAGS
         set T_COUNT = T_COUNT - 1
       where T_DOMAIN_ID = domain_id
         and T_TAG = lcase (tag);
  }
  foreach (any tag in nTags) do {
    if (not CAL.WA.vector_contains (oTags, lcase (tag)))
      if (exists (select 1 from CAL.WA.TAGS where T_DOMAIN_ID = domain_id and T_TAG = lcase (tag))) {
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

  for (select * from CAL.WA.EVENTS where E_ID = d_id) do {
    vt_batch_feed (vtb, sprintf('^R%d', E_DOMAIN_ID), mode);

    vt_batch_feed (vtb, coalesce(E_SUBJECT, ''), mode);

    vt_batch_feed (vtb, coalesce (E_DESCRIPTION, ''), mode);

    vt_batch_feed (vtb, coalesce (E_LOCATION, ''), mode);

    vt_batch_feed (vtb, coalesce (E_NOTES, ''), mode);
    
    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = E_DOMAIN_ID and WAI_TYPE_NAME = 'Calendar' and WAI_IS_PUBLIC = 1))
      vt_batch_feed (vtb, '^public', mode);

    tags := split_and_decode (E_TAGS, 0, '\0\0,');
    foreach (any tag in tags) do  {
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
create procedure CAL.WA.drop_index()
{
  if (registry_get ('cal_index_version') <> '2') {
    CAL.WA.exec_no_error ('drop table CAL.WA.EVENTS_E_SUBJECT_WORDS');
  }
}
;

CAL.WA.drop_index();

CAL.WA.exec_no_error ('
  create text index on CAL.WA.EVENTS (E_SUBJECT) with key E_ID clustered with (E_DOMAIN_ID, E_UPDATED) using function language \'x-ViDoc\'
');

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
    A_REPEAT integer,
    A_DURATION integer,

    constraint FK_ALARMS_01 FOREIGN KEY (A_EVENT_ID) references CAL.WA.EVENTS (E_ID) ON DELETE CASCADE,

    primary key (A_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_ALARMS_01 on CAL.WA.ALARMS (A_DOMAIN_ID, A_TRIGGER)
');

CAL.WA.exec_no_error ('
  create trigger ALARMS_AU after update on CAL.WA.ALARMS referencing  old as O, new as N {
    if (N.A_REPEAT = 0)
      delete from CAL.WA.ALARMS where A_ID = N.A_ID;
  }
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
registry_set ('cal_index_version', '2');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'Calendar Alarm Scheduler\', now(), \'CAL.WA.alarm_scheduler ()\', 30)
')
;
