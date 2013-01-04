--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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
-- Contains polls, questions, answers
--
-------------------------------------------------------------------------------
POLLS.WA.exec_no_error (
  'sequence_set (\'POLLS.WA.poll_id\', %d, 0)', 'S', 'POLLS.WA.POLL', 'P_ID'
)
;

POLLS.WA.exec_no_error('
  create table POLLS.WA.POLL (
    P_ID integer not null,
    P_DOMAIN_ID integer not null,
    P_NAME varchar,
    P_DESCRIPTION varchar,
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
    P_ACL long varchar,
    P_CREATED datetime,
    P_UPDATED datetime,

    primary key(P_ID)
  )
');

POLLS.WA.exec_no_error (
  'alter table POLLS.WA.POLL add P_ACL long varchar', 'C', 'POLLS.WA.POLL', 'P_ACL'
);

POLLS.WA.exec_no_error ('
  create trigger POLL_AI after insert on POLLS.WA.POLL referencing new as N
  {
    POLLS.WA.tags_update (N.P_DOMAIN_ID, \'\', N.P_TAGS);
    POLLS.WA.domain_ping (N.P_DOMAIN_ID);
    if (__proc_exists (\'DB.DBA.WA_NEW_POLL_IN\'))
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = N.P_DOMAIN_ID and WAI_IS_PUBLIC = 1))
        DB.DBA.WA_NEW_POLL_IN (N.P_NAME, sprintf(\'/polls/polls.vspx?vote=%d\', N.P_ID), N.P_ID);
  }
');

POLLS.WA.exec_no_error ('
  create trigger POLL_AU after update on POLLS.WA.POLL referencing  old as O, new as N
  {
    POLLS.WA.tags_update (N.P_DOMAIN_ID, O.P_TAGS, N.P_TAGS);
    POLLS.WA.domain_ping (N.P_DOMAIN_ID);
    if (__proc_exists (\'DB.DBA.WA_NEW_POLL_IN\'))
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = N.P_DOMAIN_ID and WAI_IS_PUBLIC = 1))
        DB.DBA.WA_NEW_POLL_IN (N.P_NAME, sprintf(\'/polls/polls.vspx?vote=%d\', N.P_ID), N.P_ID);
  }
');

POLLS.WA.exec_no_error ('
  create trigger POLL_AD after delete on POLLS.WA.POLL referencing old as O
  {
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

  foreach (any tag in oTags) do
  {
    if (not POLLS.WA.vector_contains (nTags, lcase (tag)))
      update POLLS.WA.TAGS
         set T_COUNT = T_COUNT - 1
       where T_DOMAIN_ID = domain_id
         and T_TAG = lcase (tag)
         and T_COUNT > 0;
  }
  foreach (any tag in nTags) do {
    if (not POLLS.WA.vector_contains (oTags, lcase (tag)))
      if (exists (select 1 from POLLS.WA.TAGS where T_DOMAIN_ID = domain_id and T_TAG = lcase (tag)))
      {
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
POLLS.WA.exec_no_error (
  'sequence_set (\'POLLS.WA.vote_id\', %d, 0)', 'S', 'POLLS.WA.VOTE', 'V_ID'
)
;

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
  create table POLLS.WA.POLL_COMMENT (
    PC_ID integer identity,
    PC_PARENT_ID integer,
    PC_DOMAIN_ID integer not null,
    PC_POLL_ID varchar not null,
    PC_TITLE varchar,
    PC_COMMENT long varchar,
    PC_U_NAME varchar,
    PC_U_MAIL varchar,
    PC_U_URL varchar,
    PC_RFC_ID varchar,
    PC_RFC_HEADER long varchar,
    PC_RFC_REFERENCES varchar,
    PC_OPENID_SIG long varbinary,
    PC_CREATED datetime,
    PC_UPDATED datetime,

    constraint FK_POLL_COMMENT_01 FOREIGN KEY (PC_POLL_ID) references POLLS.WA.POLL (P_ID) on delete cascade,

    primary key (PC_ID)
  )
');

POLLS.WA.exec_no_error ('
  create index SK_POLL_COMMENT_01 on POLLS.WA.POLL_COMMENT (PC_POLL_ID)
');

POLLS.WA.exec_no_error ('
  create trigger POLL_COMMENT_I after insert on POLLS.WA.POLL_COMMENT referencing new as N
  {
    declare id integer;
    declare rfc_id, rfc_header, rfc_references varchar;
    declare nInstance any;

    nInstance := POLLS.WA.domain_nntp_name (N.PC_DOMAIN_ID);
    id := N.PC_ID;
    rfc_id := N.PC_RFC_ID;
    if (isnull(rfc_id))
      rfc_id := POLLS.WA.make_rfc_id (N.PC_POLL_ID, N.PC_ID);

    rfc_references := \'\';
    if (N.PC_PARENT_ID)
    {
      declare p_rfc_id, p_rfc_references any;

      --declare exit handler for not found;

      select PC_RFC_ID, PC_RFC_REFERENCES
        into p_rfc_id, p_rfc_references
        from POLLS.WA.POLL_COMMENT
       where PC_ID = N.PC_PARENT_ID;
      if (isnull(p_rfc_references))
         p_rfc_references := rfc_references;
      rfc_references :=  p_rfc_references || \' \' || p_rfc_id;
    }

    rfc_header := N.PC_RFC_HEADER;
    if (isnull(rfc_header))
      rfc_header := POLLS.WA.make_post_rfc_header (rfc_id, rfc_references, nInstance, N.PC_TITLE, N.PC_UPDATED, N.PC_U_MAIL);

    set triggers off;
    update POLLS.WA.POLL_COMMENT
       set PC_RFC_ID = rfc_id,
           PC_RFC_HEADER = rfc_header,
           PC_RFC_REFERENCES = rfc_references
     where PC_ID = id;
    set triggers on;
  }
')
;

POLLS.WA.exec_no_error ('
  create trigger POLL_COMMENT_NEWS_I after insert on POLLS.WA.POLL_COMMENT order 30 referencing new as N
  {
    declare grp, ngnext integer;
    declare rfc_id, nInstance any;

    declare exit handler for not found { return;};

    nInstance := POLLS.WA.domain_nntp_name (N.PC_DOMAIN_ID);
    select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nInstance;
    if (ngnext < 1)
      ngnext := 1;
    rfc_id := (select PC_RFC_ID from POLLS.WA.POLL_COMMENT where PC_ID = N.PC_ID);

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

POLLS.WA.exec_no_error ('
  create trigger POLL_COMMENT_D after delete on POLLS.WA.POLL_COMMENT referencing old as O
  {
    -- update all that have PC_PARENT_ID == O.PC_PARENT_ID
    set triggers off;
    update POLLS.WA.POLL_COMMENT
       set PC_PARENT_ID = O.PC_PARENT_ID
     where PC_PARENT_ID = O.PC_ID;
    set triggers on;
  }
')
;

POLLS.WA.exec_no_error ('
  create trigger POLL_COMMENT_NEWS_D after delete on POLLS.WA.POLL_COMMENT order 30 referencing old as O
  {
    declare grp integer;
    declare oInstance any;

    oInstance := POLLS.WA.domain_nntp_name (O.PC_DOMAIN_ID);
    grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.PC_RFC_ID and NM_GROUP = grp;
    DB.DBA.ns_up_num (grp);
  }
')
;

-------------------------------------------------------------------------------
--
POLLS.WA.exec_no_error('
  create table POLLS.WA.SETTINGS (
    S_DOMAIN_ID integer,
    S_DATA varchar,
    S_ACCOUNT_ID integer,

    primary key (S_DOMAIN_ID)
)
')
;

POLLS.WA.exec_no_error (
  'alter table POLLS.WA.SETTINGS add S_DOMAIN_ID integer', 'C', 'POLLS.WA.SETTINGS', 'S_DOMAIN_ID'
)
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.tmp_update ()
{
  declare account_id, domain_id integer;

  if (registry_get ('polls_settings_update') = '1')
    return;

  POLLS.WA.exec_no_error ('update POLLS.WA.SETTINGS set S_DOMAIN_ID = -S_ACCOUNT_ID');

  set triggers off;
  for (select * from POLLS.WA.SETTINGS) do
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
                     and C.WAI_TYPE_NAME = 'Polls');
    if (isnull (domain_id))
    {
      delete from POLLS.WA.SETTINGS where S_DOMAIN_ID = -account_id;
    } else {
      update POLLS.WA.SETTINGS set S_DOMAIN_ID = domain_id where S_DOMAIN_ID = -account_id;
    }
  }
  set triggers on;

  --POLLS.WA.exec_no_error ('alter table POLLS.WA.SETTINGS drop S_ACCOUNT_ID', 'D', 'POLLS.WA.SETTINGS', 'S_ACCOUNT_ID');
  POLLS.WA.exec_no_error ('alter table POLLS.WA.SETTINGS modify primary key (S_DOMAIN_ID)');

  registry_set ('polls_settings_update', '1');
}
;
POLLS.WA.tmp_update ();

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
create procedure POLLS.WA.tmp_update ()
{
  if (registry_get ('polls_index_version') = '2')
    return;

    POLLS.WA.exec_no_error ('drop table POLLS.WA.POLL_P_NAME_WORDS');

  registry_set ('polls_index_version', '2');
}
;
POLLS.WA.tmp_update ();

POLLS.WA.exec_no_error('
  create text index on POLLS.WA.POLL (P_NAME) with key P_ID clustered with (P_DESCRIPTION, P_TAGS) using function language \'x-ViDoc\'
')
;

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
