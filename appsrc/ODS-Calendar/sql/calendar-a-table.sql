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

    constraint FK_SHARED_01 FOREIGN KEY (S_GRANT_ID) references CAL.WA.GRANTS (G_ID) on delete cascade,

    PRIMARY KEY (S_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_SHARED_01 on CAL.WA.SHARED (S_DOMAIN_ID, S_CALENDAR_ID)
');

CAL.WA.exec_no_error ('
  create index SK_SHARED_02 on CAL.WA.SHARED (S_GRANT_ID)
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.my_calendars (
  in domain_id any,
  in privacy integer)
{
  declare calendar_id, calendar_privacy integer;

  result_names (calendar_id, calendar_privacy);
  result (domain_id, privacy);

  if (not privacy)
  {
  for (select a.WAI_IS_PUBLIC,
              b.S_GRANT_ID,
                b.S_CALENDAR_ID,
                c.G_ENABLE
         from DB.DBA.WA_INSTANCE a,
              CAL.WA.SHARED b
                 left join CAL.WA.GRANTS c on c.G_ID = b.S_GRANT_ID
        where a.WAI_TYPE_NAME = 'Calendar'
          and a.WAI_ID = b.S_CALENDAR_ID
          and b.S_DOMAIN_ID = domain_id
          and b.S_VISIBLE = 1) do
  {
    if (isnull (S_GRANT_ID))
    {
      if (WAI_IS_PUBLIC = 1)
          result (S_CALENDAR_ID, 1);
    } else {
        if (G_ENABLE = 1)
          result (S_CALENDAR_ID, 1);
      }
    }
  }
}
;

CAL.WA.exec_no_error ('drop view CAL..MY_CALENDARS');
CAL.WA.exec_no_error ('
  create procedure view CAL..MY_CALENDARS as CAL.WA.my_calendars (domain_id, privacy) (CALENDAR_ID integer, CALENDAR_PRIVACY integer)
')
;

-------------------------------------------------------------------------------
--
--  PUBLISH & SUBSCRIBE
--
-------------------------------------------------------------------------------
CAL.WA.exec_no_error ('
  create table CAL.WA.EXCHANGE (
    EX_ID integer identity,
    EX_DOMAIN_ID integer not null,
    EX_TYPE integer not null,
    EX_NAME varchar not null,
    EX_UPDATE_TYPE integer not null,
    EX_UPDATE_SUBTYPE integer,
    EX_UPDATE_INTERVAL integer,
    EX_UPDATE_PERIOD varchar,
    EX_UPDATE_FREQ integer,
    EX_OPTIONS varchar,
	  EX_EXEC_LOG long varchar,
    EX_EXEC_TIME datetime,

    primary key (EX_ID)
  )
');

CAL.WA.exec_no_error(
  'alter table CAL.WA.EXCHANGE add EX_UPDATE_SUBTYPE integer', 'C', 'CAL.WA.EXCHANGE', 'EX_UPDATE_SUBTYPE'
);

CAL.WA.exec_no_error ('
  create trigger EXCHANGE_AI AFTER INSERT ON CAL.WA.EXCHANGE referencing new as N
  {
    CAL.WA.calc_update_interval (N.EX_ID, N.EX_UPDATE_TYPE, N.EX_UPDATE_PERIOD, N.EX_UPDATE_FREQ);
  }
');

CAL.WA.exec_no_error ('
  create trigger EXCHANGE_AU AFTER UPDATE on CAL.WA.EXCHANGE referencing old as O, new as N
  {
    CAL.WA.calc_update_interval (N.EX_ID, N.EX_UPDATE_TYPE, N.EX_UPDATE_PERIOD, N.EX_UPDATE_FREQ);
  }
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.EVENTS (
    E_ID integer not null,
    E_UID varchar,
    E_DOMAIN_ID integer not null,
    E_EXCHANGE_ID integer,
    E_KIND integer default 0,             -- 0 - Event
                                          -- 1 - Task
    E_PRIVACY integer default 0,          -- 0 - PRIVATE
                                          -- 1 - PUBLIC
                                          -- 2 - ACL
    E_ATTENDEES integer default 0,        -- 0 - no attendees
                                          -- N - number of attendees
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
    E_ACL long varchar,
    E_CREATED datetime,
    E_UPDATED datetime,

    primary key (E_ID)
  )
');

CAL.WA.exec_no_error (
  'sequence_set (\'CAL.WA.event_id\', %d, 0)', 'S', 'CAL.WA.EVENTS', 'E_ID'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_UID varchar', 'C', 'CAL.WA.EVENTS', 'E_UID'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_EXCHANGE_ID integer', 'C', 'CAL.WA.EVENTS', 'E_EXCHANGE_ID'
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

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_ATTENDEES integer default 0', 'C', 'CAL.WA.EVENTS', 'E_ATTENDEES'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add E_ACL long varchar', 'C', 'CAL.WA.EVENTS', 'E_ACL'
);

CAL.WA.exec_no_error (
  'alter table CAL.WA.EVENTS add constraint FK_EVENTS_01 FOREIGN KEY (E_EXCHANGE_ID) references CAL.WA.EXCHANGE (EX_ID) on delete set null'
);

-------------------------------------------------------------------------------
--
create procedure CAL.WA.EVENTS_E_SUBJECT_int (inout vtb any, inout d_id any, in mode any)
{
  declare tags any;

  for (select * from CAL.WA.EVENTS where E_ID = d_id) do
  {
    vt_batch_feed (vtb, sprintf('^R%d', coalesce (E_DOMAIN_ID, 0)), mode);

    vt_batch_feed (vtb, sprintf('^UID%d', coalesce (CAL.WA.domain_owner_id (E_DOMAIN_ID), 0)), mode);

    vt_batch_feed (vtb, coalesce (E_SUBJECT, ''), mode);

    vt_batch_feed (vtb, coalesce (E_DESCRIPTION, ''), mode);

    vt_batch_feed (vtb, coalesce (E_LOCATION, ''), mode);

    vt_batch_feed (vtb, coalesce (E_NOTES, ''), mode);

    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = E_DOMAIN_ID and WAI_TYPE_NAME = 'Calendar' and WAI_IS_PUBLIC = 1))
      vt_batch_feed (vtb, '^public', mode);

    tags := split_and_decode (E_TAGS, 0, '\0\0,');
    foreach (any tag in tags) do
    {
      tag := concat('^T', trim (tag));
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
create procedure CAL.WA.tmp_update ()
{
  if (registry_get ('cal_index_version') = '4')
    return;

  CAL.WA.exec_no_error ('drop table CAL.WA.EVENTS_E_SUBJECT_WORDS');

  registry_set ('cal_index_version', '4');
}
;
CAL.WA.tmp_update ();

CAL.WA.exec_no_error ('
  create text index on CAL.WA.EVENTS (E_SUBJECT) with key E_ID clustered with (E_DOMAIN_ID, E_UPDATED) using function language \'x-ViDoc\'
');

CAL.WA.exec_no_error ('
  create index SK_EVENTS_01 on CAL.WA.EVENTS (E_DOMAIN_ID, E_KIND, E_EVENT_START)
');

CAL.WA.exec_no_error ('
  create index SK_EVENTS_02 on CAL.WA.EVENTS (E_REMINDER_DATE)
');

CAL.WA.exec_no_error ('
  create index SK_EVENTS_03 on CAL.WA.EVENTS (E_UID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create trigger EVENTS_AI after insert on CAL.WA.EVENTS referencing new as N
  {
    declare _uid varchar;

    _uid := N.E_UID;
    if (isnull (_uid))
    {
      _uid := CAL.WA.uid ();
      set triggers off;
      update CAL.WA.EVENTS set E_UID = _uid where E_ID = N.E_ID;
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
    CAL.WA.upstream_event_update (N.E_DOMAIN_ID, N.E_ID, _uid, N.E_TAGS, \'I\');
    CAL.WA.exchange_event_update (N.E_DOMAIN_ID);
    CAL.WA.syncml_entry_update (N.E_DOMAIN_ID, N.E_ID, _uid, N.E_KIND, \'I\');
  }
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AU after update on CAL.WA.EVENTS referencing old as O, new as N
  {
    declare _uid varchar;

    _uid := N.E_UID;
    if (isnull (_uid))
    {
      _uid := CAL.WA.uid ();
      set triggers off;
      update CAL.WA.EVENTS set E_UID = _uid where E_ID = N.E_ID;
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

    CAL.WA.upstream_event_update (N.E_DOMAIN_ID, N.E_ID, _uid, N.E_TAGS, \'U\');
    CAL.WA.exchange_event_update (N.E_DOMAIN_ID);
    CAL.WA.syncml_entry_update (N.E_DOMAIN_ID, N.E_ID, _uid, N.E_KIND, \'U\');
    CAL.WA.domain_ping (N.E_DOMAIN_ID);
  }
');

CAL.WA.exec_no_error ('
  create trigger EVENTS_AD after delete on CAL.WA.EVENTS referencing old as O
  {
    CAL.WA.tags_update (O.E_DOMAIN_ID, O.E_TAGS, \'\');
    delete from CAL.WA.ALARMS where A_EVENT_ID = O.E_ID;

    CAL.WA.upstream_event_update (O.E_DOMAIN_ID, O.E_ID, O.E_UID, O.E_TAGS, \'D\');
    CAL.WA.exchange_event_update (O.E_DOMAIN_ID);
    CAL.WA.syncml_entry_update (O.E_DOMAIN_ID, O.E_ID, O.E_UID, O.E_KIND, \'D\');
    CAL.WA.domain_ping (O.E_DOMAIN_ID);
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
CAL.WA.exec_no_error ('
  create table CAL.WA.EVENT_GRANTS (
    G_ID integer identity,
    G_GRANTER_ID integer not null,
    G_GRANTEE_ID integer not null,
    G_EVENT_ID integer not null,

    PRIMARY KEY (G_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_EVENT_GRANTS_01 on CAL.WA.EVENT_GRANTS (G_GRANTER_ID, G_EVENT_ID)
');

CAL.WA.exec_no_error ('
  create index SK_EVENT_GRANTS_02 on CAL.WA.EVENT_GRANTS (G_GRANTEE_ID, G_EVENT_ID)
');

CAL.WA.exec_no_error ('
  alter table CAL.WA.EVENT_GRANTS add constraint FK_CAL_EVENT_GRANTS_01 FOREIGN KEY (G_EVENT_ID) references CAL.WA.EVENTS (E_ID) on delete cascade
');

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_grants_procedure (
  in to_id integer,
  in event_id integer := null)
{
  declare c0 integer;

  result_names (c0);
  for (select distinct G_EVENT_ID
         from CAL.WA.EVENT_GRANTS
        where G_GRANTEE_ID = to_id
          and (G_EVENT_ID = event_id or event_id is null)
        order by 1) do
  {
    result (G_EVENT_ID);
  }
  for (select distinct G_EVENT_ID
         from CAL.WA.EVENT_GRANTS a,
              DB.DBA.SYS_ROLE_GRANTS c
        where (a.G_EVENT_ID  = event_id or event_id is null)
          and c.GI_SUPER     = to_id
          and c.GI_GRANT     = a.G_GRANTEE_ID
          and c.GI_DIRECT    = '1'
        order by 1) do
  {
    result (G_EVENT_ID);
  }
}
;

CAL.WA.exec_no_error ('
  create procedure view CAL..EVENT_GRANTS_VIEW as CAL.WA.event_grants_procedure (to_id, event_id) (G_EVENT_ID integer)
')
;

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

    constraint FK_ALARMS_01 FOREIGN KEY (A_EVENT_ID) references CAL.WA.EVENTS (E_ID) on delete cascade,

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
    A_CLAIMS long varchar,
    A_CONTEXT varchar,
    A_AUTHOR varchar,
    A_CREATED datetime,
    A_UPDATED datetime,

    constraint FK_CAL_ANNOTATIONS_01 FOREIGN KEY (A_OBJECT_ID) references CAL.WA.EVENTS (E_ID) on delete cascade,

    primary key (A_ID)
  )
');

CAL.WA.exec_no_error (
  'alter table CAL.WA.ANNOTATIONS add A_CLAIMS long varchar', 'C', 'CAL.WA.ANNOTATIONS', 'A_CLAIMS'
);

CAL.WA.exec_no_error ('
  create index SK_CAL_ANNOTATIONS_01 on CAL.WA.ANNOTATIONS (A_OBJECT_ID, A_ID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.EVENT_COMMENTS (
    EC_ID integer identity,
    EC_PARENT_ID integer,
    EC_DOMAIN_ID integer not null,
    EC_EVENT_ID varchar not null,
    EC_TITLE varchar,
    EC_COMMENT long varchar,
    EC_U_NAME varchar,
    EC_U_MAIL varchar,
    EC_U_URL varchar,
    EC_RFC_ID varchar,
    EC_RFC_HEADER long varchar,
    EC_RFC_REFERENCES varchar,
    EC_OPENID_SIG long varbinary,
    EC_CREATED datetime,
    EC_UPDATED datetime,

    constraint FK_EVENT_COMMENTS_01 FOREIGN KEY (EC_EVENT_ID) references CAL.WA.EVENTS (E_ID) on delete cascade,

    primary key (EC_ID)
  )
');

CAL.WA.exec_no_error ('
  create index SK_EVENT_COMMENTS_01 on CAL.WA.EVENT_COMMENTS (EC_EVENT_ID)
');

CAL.WA.exec_no_error ('
  create trigger EVENT_COMMENTS_I after insert on CAL.WA.EVENT_COMMENTS referencing new as N
  {
    declare id integer;
    declare rfc_id, rfc_header, rfc_references varchar;
    declare nInstance any;

    nInstance := CAL.WA.domain_nntp_name (N.EC_DOMAIN_ID);
    id := N.EC_ID;
    rfc_id := N.EC_RFC_ID;
    if (isnull(rfc_id))
      rfc_id := CAL.WA.make_rfc_id (N.EC_EVENT_ID, N.EC_ID);

    rfc_references := \'\';
    if (N.EC_PARENT_ID)
    {
      declare p_rfc_id, p_rfc_references any;

      --declare exit handler for not found;

      select EC_RFC_ID, EC_RFC_REFERENCES
        into p_rfc_id, p_rfc_references
        from CAL.WA.EVENT_COMMENTS
       where EC_ID = N.EC_PARENT_ID;
      if (isnull(p_rfc_references))
         p_rfc_references := rfc_references;
      rfc_references :=  p_rfc_references || \' \' || p_rfc_id;
    }

    rfc_header := N.EC_RFC_HEADER;
    if (isnull(rfc_header))
      rfc_header := CAL.WA.make_post_rfc_header (rfc_id, rfc_references, nInstance, N.EC_TITLE, N.EC_UPDATED, N.EC_U_MAIL);

    set triggers off;
    update CAL.WA.EVENT_COMMENTS
       set EC_RFC_ID = rfc_id,
           EC_RFC_HEADER = rfc_header,
           EC_RFC_REFERENCES = rfc_references
     where EC_ID = id;
    set triggers on;
  }
')
;

CAL.WA.exec_no_error ('
  create trigger EVENT_COMMENTS_NEWS_I after insert on CAL.WA.EVENT_COMMENTS order 30 referencing new as N
  {
    declare grp, ngnext integer;
    declare rfc_id, nInstance any;

    declare exit handler for not found { return;};

    nInstance := CAL.WA.domain_nntp_name (N.EC_DOMAIN_ID);
    select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nInstance;
    if (ngnext < 1)
      ngnext := 1;
    rfc_id := (select EC_RFC_ID from CAL.WA.EVENT_COMMENTS where EC_ID = N.EC_ID);

    insert into DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP)
      values (rfc_id, grp, ngnext);

    set triggers off;
    update DB.DBA.NEWS_GROUPS
       set NG_NEXT_NUM = ngnext + 1
     where NG_NAME = nInstance;
    DB.DBA.ns_up_num (grp);
    set triggers on;
  }
')
;

CAL.WA.exec_no_error ('
  create trigger EVENT_COMMENTS_D after delete on CAL.WA.EVENT_COMMENTS referencing old as O
  {
    -- update all that have EC_PARENT_ID == O.EC_PARENT_ID
    set triggers off;
    update CAL.WA.EVENT_COMMENTS
       set EC_PARENT_ID = O.EC_PARENT_ID
     where EC_PARENT_ID = O.EC_ID;
    set triggers on;
  }
')
;

CAL.WA.exec_no_error ('
  create trigger EVENT_COMMENTS_NEWS_D after delete on CAL.WA.EVENT_COMMENTS order 30 referencing old as O
  {
    declare grp integer;
    declare oInstance any;

    oInstance := CAL.WA.domain_nntp_name (O.EC_DOMAIN_ID);
    grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.EC_RFC_ID and NM_GROUP = grp;
    DB.DBA.ns_up_num (grp);
  }
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.SETTINGS (
    S_DOMAIN_ID integer,
    S_DATA varchar,
    S_ACCOUNT_ID integer,

    primary key (S_DOMAIN_ID)
  )
')
;

CAL.WA.exec_no_error (
  'alter table CAL.WA.SETTINGS add S_DOMAIN_ID integer', 'C', 'CAL.WA.SETTINGS', 'S_DOMAIN_ID'
)
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tmp_update ()
{
  declare account_id, domain_id integer;

  if (registry_get ('cal_settings_update') = '1')
    return;

  CAL.WA.exec_no_error ('update CAL.WA.SETTINGS set S_DOMAIN_ID = -S_ACCOUNT_ID');

  set triggers off;
  for (select * from CAL.WA.SETTINGS) do
  {
    account_id := abs (S_DOMAIN_ID);
    domain_id := (select top 1 C.WAI_ID
                    from SYS_USERS A,
                         WA_MEMBER B,
                         WA_INSTANCE C
                   where A.U_ID = account_id
                     and B.WAM_USER = A.U_ID
                     and B.WAM_MEMBER_TYPE = 1
                     and B.WAM_INST = C.WAI_NAME
                     and C.WAI_TYPE_NAME = 'Calendar');
    if (isnull (domain_id))
    {
      delete from CAL.WA.SETTINGS where S_DOMAIN_ID = -account_id;
    } else {
      update CAL.WA.SETTINGS set S_DOMAIN_ID = domain_id where S_DOMAIN_ID = -account_id;
    }
  }
  set triggers on;

  --CAL.WA.exec_no_error ('alter table CAL.WA.SETTINGS drop S_ACCOUNT_ID', 'D', 'CAL.WA.SETTINGS', 'S_ACCOUNT_ID');
  CAL.WA.exec_no_error ('alter table CAL.WA.SETTINGS modify primary key (S_DOMAIN_ID)');

  registry_set ('cal_settings_update', '1');
}
;
CAL.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tags_procedure (
  in tags any)
{
  declare T varchar;

  result_names (T);
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

-------------------------------------------------------------------------------
--
create procedure CAL.WA.calc_update_interval (
  in _id any,
  in _type any,
  in _period any,
  in _freq any)
{
  declare _update integer;

  if (_type < 2)
    return;

  _update := case lower (coalesce (_period, 'daily'))
               when 'hourly' then 60
               when 'daily' then 1440
               else 1440
             end / coalesce (_freq, 1);

  set triggers off;
  update CAL.WA.EXCHANGE
     set EX_UPDATE_INTERVAL = _update
   where EX_ID = _id;
  set triggers on;
}
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'Calendar Exchange Scheduler\', now(), \'CAL.WA.exchange_scheduler ()\', 30)
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create table CAL.WA.ATTENDEES (
    AT_ID integer identity,
    AT_UID varchar,
    AT_EVENT_ID integer not null,
    AT_ROLE varchar,
    AT_NAME varchar,
    AT_MAIL varchar,
    AT_DATE_REQUEST datetime,
    AT_DATE_RESPOND datetime,
    AT_STATUS varchar,
    AT_LOG long varchar,

    constraint FK_ATTENDEES_01 FOREIGN KEY (AT_EVENT_ID) references CAL.WA.EVENTS (E_ID) on delete cascade,

    primary key (AT_ID)
  )
');

CAL.WA.exec_no_error(
  'alter table CAL.WA.ATTENDEES add AT_NAME varchar', 'C', 'CAL.WA.ATTENDEES', 'AT_NAME'
);

CAL.WA.exec_no_error(
  'alter table CAL.WA.ATTENDEES add AT_ROLE varchar', 'C', 'CAL.WA.ATTENDEES', 'AT_ROLE'
);

CAL.WA.exec_no_error ('
  create index SK_ATTENDEES_01 on CAL.WA.ATTENDEES (AT_EVENT_ID)
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create trigger ATTENDEES_AI after insert on CAL.WA.ATTENDEES referencing new as N
  {
    update CAL.WA.EVENTS set E_ATTENDEES = E_ATTENDEES + 1 where E_ID = N.AT_EVENT_ID;
  }
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create trigger ATTENDEES_AD after delete on CAL.WA.ATTENDEES referencing old as O
  {
    update CAL.WA.EVENTS set E_ATTENDEES = E_ATTENDEES - 1 where E_ID = O.AT_EVENT_ID;
  }
');

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'Calendar Attendees Scheduler\', now(), \'CAL.WA.attendees_mails ()\', 10)
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create trigger CALENDAR_SYS_DAV_RES_AI after insert on WS.WS.SYS_DAV_RES order 200 referencing new as N
  {
    declare data any;

    if (not CAL.WA.syncml_check (DB.DBA.DAV_SEARCH_PATH (N.RES_COL, \'C\')))
      return;

    if (connection_get (\'__sync_ods\') = \'1\')
      return;

  	data := CAL.WA.exec (\'select RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_ID = ?\', vector (N.RES_ID));
  	if (length (data) = 0)
      return;

    CAL.WA.syncml2entry (N.RES_CONTENT, N.RES_NAME, N.RES_COL, N.RES_MOD_TIME);
  }
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create trigger CALENDAR_SYS_DAV_RES_AU after update on WS.WS.SYS_DAV_RES order 200 referencing old as O, new as N
  {
    declare data any;

    if (not CAL.WA.syncml_check (DB.DBA.DAV_SEARCH_PATH (N.RES_COL, \'C\')))
      return;

    if (connection_get (\'__sync_ods\') = \'1\')
      return;

  	data := CAL.WA.exec (\'select RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_ID = ?\', vector (N.RES_ID));
  	if (length (data) = 0)
      return;

    if (O.RES_CONTENT = N.RES_CONTENT)
      return;

    CAL.WA.syncml2entry (N.RES_CONTENT, N.RES_NAME, N.RES_COL, N.RES_MOD_TIME);
  }
')
;

-------------------------------------------------------------------------------
--
CAL.WA.exec_no_error ('
  create trigger CALENDAR_SYS_DAV_RES_AD after delete on WS.WS.SYS_DAV_RES order 200 referencing old as O
  {
    declare _syncmlPath, _path varchar;
    declare data any;

    if (not CAL.WA.syncml_check (DB.DBA.DAV_SEARCH_PATH (O.RES_COL, \'C\')))
      return;

    if (connection_get (\'__sync_ods\') = \'1\')
      return;

  	data := CAL.WA.exec (\'select RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_ID = ?\', vector (O.RES_ID));
  	if (length (data) = 0)
      return;

    for (select E_ID, E_DOMAIN_ID from CAL.WA.EVENTS where E_UID = O.RES_NAME) do
    {
      for (select deserialize (EX_OPTIONS) as _options from CAL.WA.EXCHANGE where EX_DOMAIN_ID = E_DOMAIN_ID and EX_TYPE = 2) do
      {
        _path := WS.WS.COL_PATH (O.RES_COL);
        if (_path = _syncmlPath)
        {
          CAL.WA.event_delete (E_ID);
        }
      }
    }
  }
')
;
