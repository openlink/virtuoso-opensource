--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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
POLLS.WA.exec_no_error('
  create table POLLS.WA.TAGS (
    T_DOMAIN_ID integer not null,
    T_TAG varchar,
    T_COUNT integer,

    primary key (T_DOMAIN_ID, T_TAG)
  )
');

-------------------------------------------------------------------------------
--
-- Conatins polls, questions, answers
--
-------------------------------------------------------------------------------
POLLS.WA.exec_no_error('
  create table POLLS.WA.POLL (
    P_ID integer not null,
    P_DOMAIN_ID integer not null,
    P_NAME varchar,
    P_DESCRIPTION varchar,
    P_CREATED datetime,
    P_UPDATED datetime,
    P_DATE_START datetime,
    P_DATE_END datetime,
    P_MODE char (1) default \'S\',          -- S - single question; M - multiple questions
    P_STATE char (2) default \'DR\',        -- DR - draft; OP - open; CL - close;
    P_MULTI_VOTE integer default 0,         -- 0 - not allowed; 1 - allowed;
    P_VOTE_RESULT integer default 1,        -- 0 - not allowed; 1 - allowed to see results at any time;
    P_VOTE_RESULT_BEFORE integer default 0, -- 0 - not allowed; 1 - allowed to see results before voted for;
    P_VOTE_RESULT_OPENED integer default 1, -- 0 - not allowed; 1 - allowed for open polls;
    P_TAGS varchar,
    P_VOTED datetime,
    P_VOTES integer default 0,

    primary key(P_ID)
  )
');

POLLS.WA.exec_no_error ('
  create trigger POLL_AI after insert on POLLS.WA.POLL referencing new as N {
    POLLS.WA.tags_update (N.P_DOMAIN_ID, \'\', N.P_TAGS);
    POLLS.WA.domain_ping (N.P_DOMAIN_ID);
    if (__proc_exists (\'DB.DBA.WA_NEW_POLL_IN\'))
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = N.P_DOMAIN_ID and WAI_IS_PUBLIC = 1))
        DB.DBA.WA_NEW_POLL_IN (N.P_NAME, sprintf(\'/polls/polls.vspx?vote=%d\', N.P_ID), N.P_ID);
  }
');

POLLS.WA.exec_no_error ('
  create trigger POLL_AU after update on POLLS.WA.POLL referencing  old as O, new as N {
    POLLS.WA.tags_update (N.P_DOMAIN_ID, O.P_TAGS, N.P_TAGS);
    POLLS.WA.domain_ping (N.P_DOMAIN_ID);
    if (__proc_exists (\'DB.DBA.WA_NEW_POLL_IN\'))
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = N.P_DOMAIN_ID and WAI_IS_PUBLIC = 1))
        DB.DBA.WA_NEW_POLL_IN (N.P_NAME, sprintf(\'/polls/polls.vspx?vote=%d\', N.P_ID), N.P_ID);
  }
');

POLLS.WA.exec_no_error ('
  create trigger POLL_AD after delete on POLLS.WA.POLL referencing old as O {
    POLLS.WA.tags_update (O.P_DOMAIN_ID, O.P_TAGS, \'\');
    if (__proc_exists (\'DB.DBA.WA_NEW_POLL_RM\'))
      DB.DBA.WA_NEW_POLL_RM (O.P_ID);
  }
');

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.tags_update (
  inout domain_id integer,
  in oTags any,
  in nTags any)
{
  declare N integer;

  oTags := split_and_decode (oTags, 0, '\0\0,');
  nTags := split_and_decode (nTags, 0, '\0\0,');

  foreach (any tag in oTags) do {
    if (not POLLS.WA.vector_contains (nTags, lcase (tag)))
      update POLLS.WA.TAGS
         set T_COUNT = T_COUNT - 1
       where T_DOMAIN_ID = domain_id
         and T_TAG = lcase (tag)
         and T_COUNT > 0;
  }
  foreach (any tag in nTags) do {
    if (not POLLS.WA.vector_contains (oTags, lcase (tag)))
      if (exists (select 1 from POLLS.WA.TAGS where T_DOMAIN_ID = domain_id and T_TAG = lcase (tag))) {
        update POLLS.WA.TAGS
           set T_COUNT = T_COUNT + 1
         where T_DOMAIN_ID = domain_id
           and T_TAG = lcase (tag);
      } else {
       insert replacing POLLS.WA.TAGS (T_DOMAIN_ID, T_TAG, T_COUNT)
         values (domain_id, lcase (tag), 1);
      }
  }
}
;

-------------------------------------------------------------------------------
--
POLLS.WA.exec_no_error('
  create table POLLS.WA.QUESTION (
    Q_ID integer identity,
    Q_POLL_ID integer not null,
    Q_NUMBER integer,
    Q_TEXT varchar not null,
    Q_DESCRIPTION varchar,
    Q_REQUIRED integer default 1,     -- 0 - not required; 1 - required;
    Q_TYPE char (1) default \'M\',    -- M - Multiple choice; N - numeric; T - text;
    Q_ANSWER varchar,

    constraint FK_QUESTION_01 FOREIGN KEY (Q_POLL_ID) references POLLS.WA.POLL (P_ID) on delete cascade,

    primary key(Q_ID)
  )
');

-------------------------------------------------------------------------------
--
POLLS.WA.exec_no_error('
  create table POLLS.WA.VOTE (
    V_ID integer not null,
    V_POLL_ID integer not null,
    V_CLIENT_ID varchar not null,
    V_CREATED datetime,

    constraint FK_VOTE_01 FOREIGN KEY (V_POLL_ID) references POLLS.WA.POLL (P_ID) on delete cascade,

    primary key(V_ID)
  )
');

POLLS.WA.exec_no_error ('
  create trigger VOTE_AI after insert on POLLS.WA.VOTE referencing new as N {
    update POLLS.WA.POLL
       set P_VOTES = coalesce (P_VOTES, 0) + 1,
           P_VOTED = now ()
     where P_ID = N.V_POLL_ID;
  }
');

-------------------------------------------------------------------------------
--
POLLS.WA.exec_no_error('
  create table POLLS.WA.ANSWER (
    A_VOTE_ID integer not null,
    A_QUESTION_ID integer not null,
    A_NUMBER integer not null,
    A_VALUE varchar,

    constraint FK_ANSWER_01 FOREIGN KEY (A_VOTE_ID) references POLLS.WA.VOTE (V_ID) on delete cascade,

    primary key(A_VOTE_ID, A_QUESTION_ID, A_NUMBER)
  )
');

POLLS.WA.exec_no_error('
  create index SK_ANSWER_01 on POLLS.WA.ANSWER (A_QUESTION_ID, A_NUMBER)
');

-------------------------------------------------------------------------------
--
POLLS.WA.exec_no_error('
  create table POLLS.WA.SETTINGS (
    S_ACCOUNT_ID integer not null,
    S_DATA varchar,

    primary key(S_ACCOUNT_ID)
  )
');


POLLS.WA.exec_no_error (
  'sequence_set (\'POLLS.WA.poll_id\', %d, 0)', 'S', 'POLLS.WA.POLL', 'P_ID'
)
;

POLLS.WA.exec_no_error (
  'sequence_set (\'POLLS.WA.vote_id\', %d, 0)', 'S', 'POLLS.WA.VOTE', 'V_ID'
)
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.POLL_P_NAME_int (inout vtb any, inout d_id any, in mode any)
{
  declare tags any;

  for (select P_DOMAIN_ID, P_NAME, P_DESCRIPTION, P_TAGS from POLLS.WA.POLL where P_ID = d_id) do
  {
    vt_batch_feed (vtb, sprintf('^R%d', P_DOMAIN_ID), mode);

    vt_batch_feed (vtb, sprintf('^UID%d', coalesce (POLLS.WA.domain_owner_id (P_DOMAIN_ID), 0)), mode);

    vt_batch_feed (vtb, coalesce(P_NAME, ''), mode);

    vt_batch_feed (vtb, coalesce(P_DESCRIPTION, ''), mode);

    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = P_DOMAIN_ID and WAI_TYPE_NAME = 'polls' and WAI_IS_PUBLIC = 1))
      vt_batch_feed (vtb, '^public', mode);

    tags := split_and_decode (P_TAGS, 0, '\0\0,');
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
create procedure POLLS.WA.POLL_P_NAME_index_hook (inout vtb any, inout d_id any)
{
  return POLLS.WA.POLL_P_NAME_int (vtb, d_id, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.POLL_P_NAME_unindex_hook (inout vtb any, inout d_id any)
{
  return POLLS.WA.POLL_P_NAME_int (vtb, d_id, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.drop_index()
{
  if (registry_get ('polls_index_version') <> '2') {
    POLLS.WA.exec_no_error ('drop table POLLS.WA.POLL_P_NAME_WORDS');
  }
}
;

POLLS.WA.drop_index();

POLLS.WA.exec_no_error('
  create text index on POLLS.WA.POLL (P_NAME) with key P_ID clustered with (P_DESCRIPTION, P_TAGS) using function language \'x-ViDoc\'
');

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.tags_procedure (
  in tags any)
{
  declare tag varchar;

  result_names (tag);
  tags := split_and_decode (tags, 0, '\0\0,');
  foreach (any tag in tags) do
    result (trim (tag));
}
;

POLLS.WA.exec_no_error ('
  create procedure view POLLS..TAGS_VIEW as POLLS.WA.tags_procedure (tags) (TV_TAG varchar)
')
;

-------------------------------------------------------------------------------
--
registry_set ('polls_index_version', '2');
