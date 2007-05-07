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
  create table CAL.WA.EVENTS (
    E_ID integer not null,
    E_DOMAIN_ID integer not null,
    E_SUBJECT varchar,
    E_DESCRIPTION varchar,
    E_LOCATION varchar,
    E_KIND integer default 0,
    E_EVENT integer default 0,
    E_EVENT_START datetime not null,
    E_EVENT_END datetime not null,
    E_REPEAT char (2) default \'\',       -- \'\' - no repeat,
                                          -- D1 - every day,
                                          -- D2 - every weekday ,
                                          -- W  - every [] week on (day),
                                          -- M1 - day [] of every [] month(s),
                                          -- M2 - the (f|s|t|f|l) (day) of every [] month(s),
                                          -- Y1 - every (month) (date),
                                          -- Y2 - the ((f|s|t|f|l)) (day) of (mounth)  //
    E_REPEAT_PARAM1 integer,              -- units used to determine the date on which to repeat the event
    E_REPEAT_PARAM2 integer,
    E_REPEAT_PARAM3 integer,
    E_REPEAT_UNTIL date,                  -- repeat until this date or null (infinite)
    E_REMINDER integer default 600,       -- 10 minutes remainder
    E_TAGS varchar,
    E_CREATED datetime,
    E_UPDATED datetime,

    primary key (E_ID)
  )
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
    delete from CAL.WA.GRANTS where G_PERSON_ID = O.E_ID;
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

    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = E_DOMAIN_ID and WAI_TYPE_NAME = 'AddressBook' and WAI_IS_PUBLIC = 1))
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
  if (registry_get ('ab_index_version') <> '1') {
    CAL.WA.exec_no_error ('drop table CAL.WA.EVENTS_E_SUBJECT_WORDS');
  }
}
;

CAL.WA.drop_index();

CAL.WA.exec_no_error ('
  create text index on CAL.WA.EVENTS (E_SUBJECT) with key E_ID clustered with (E_DOMAIN_ID) using function language \'x-ViDoc\'
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
  create index SK_GRANTS_01 on CAL.WA.GRANTS (G_GRANTER_ID, G_PERSON_ID)
');

CAL.WA.exec_no_error ('
  create index SK_GRANTS_02 on CAL.WA.GRANTS (G_GRANTEE_ID, G_EVENT_ID)
');

