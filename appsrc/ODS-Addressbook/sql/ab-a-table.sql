--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
AB.WA.exec_no_error (
  'sequence_set (\'AB.WA.contact_id\', %d, 0)', 'S', 'AB.WA.PERSONS', 'P_ID'
)
;

AB.WA.exec_no_error (
  'sequence_set (\'AB.WA.category_id\', %d, 0)', 'S', 'AB.WA.CATEGORIES', 'C_ID'
)
;

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.TAGS (
    T_DOMAIN_ID integer not null,
    T_TAG varchar,
    T_COUNT integer,

    primary key (T_DOMAIN_ID, T_TAG)
  )
');

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.CATEGORIES (
    C_ID integer not null,
    C_DOMAIN_ID integer not null,
    C_NAME varchar,
    C_COUNT integer,
    C_CREATED datetime,
    C_UPDATED datetime,

    primary key (C_ID)
  )
');

AB.WA.exec_no_error('
  create unique index SK_CATEGORIES_01 on AB.WA.CATEGORIES (C_DOMAIN_ID, C_NAME)
');

AB.WA.exec_no_error (
  'alter table AB.WA.CATEGORIES add C_CREATED datetime', 'C', 'AB.WA.CATEGORIES', 'C_CREATED'
);

AB.WA.exec_no_error (
  'alter table AB.WA.CATEGORIES add C_UPDATED datetime', 'C', 'AB.WA.CATEGORIES', 'C_UPDATED'
);

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.PERSONS (
    P_ID integer not null,
    P_UID varchar,
    P_DOMAIN_ID integer not null,
    P_CATEGORY_ID integer,
    P_KIND integer,
    P_NAME varchar not null,
    P_TITLE varchar,
    P_FIRST_NAME varchar,
    P_MIDDLE_NAME varchar,
    P_LAST_NAME varchar,
    P_FULL_NAME varchar,
    P_GENDER varchar,
    P_BIRTHDAY datetime,
    P_IRI varchar,
    P_FOAF varchar,
    P_PHOTO long varchar,
    P_INTERESTS long varchar,
    P_RELATIONSHIPS long varchar,
    P_MAIL varchar,
    P_WEB varchar,
    P_ICQ varchar,
    P_SKYPE varchar,
    P_AIM varchar,
    P_YAHOO varchar,
    P_MSN varchar,
    P_H_ADDRESS1 varchar,
    P_H_ADDRESS2 varchar,
    P_H_CODE varchar,
    P_H_CITY varchar,
    P_H_STATE varchar,
    P_H_COUNTRY varchar,
    P_H_TZONE varchar,
    P_H_LAT real,
    P_H_LNG real,
    P_H_PHONE varchar,
    P_H_MOBILE varchar,
    P_H_FAX varchar,
    P_H_MAIL varchar,
    P_H_WEB varchar,
    P_B_ADDRESS1 varchar,
    P_B_ADDRESS2 varchar,
    P_B_CODE varchar,
    P_B_CITY varchar,
    P_B_STATE varchar,
    P_B_COUNTRY varchar,
    P_B_TZONE varchar,
    P_B_LAT real,
    P_B_LNG real,
    P_B_PHONE varchar,
    P_B_MOBILE varchar,
    P_B_FAX varchar,
    P_B_INDUSTRY varchar,
    P_B_ORGANIZATION varchar,
    P_B_DEPARTMENT varchar,
    P_B_JOB varchar,
    P_B_MAIL varchar,
    P_B_WEB varchar,
    P_TAGS varchar,
    P_ACL long varchar,
    P_CERTIFICATE long varchar,
    P_CREATED datetime,
    P_UPDATED datetime,

    primary key (P_ID)
  )
');

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_UID varchar', 'C', 'AB.WA.PERSONS', 'P_UID'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_CATEGORY_ID integer', 'C', 'AB.WA.PERSONS', 'P_CATEGORY_ID'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_KIND integer', 'C', 'AB.WA.PERSONS', 'P_KIND'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_MIDDLE_NAME varchar', 'C', 'AB.WA.PERSONS', 'P_MIDDLE_NAME'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_IRI varchar', 'C', 'AB.WA.PERSONS', 'P_IRI'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_H_FAX varchar', 'C', 'AB.WA.PERSONS', 'P_H_FAX'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_B_FAX varchar', 'C', 'AB.WA.PERSONS', 'P_B_FAX'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_B_DEPARTMENT varchar', 'C', 'AB.WA.PERSONS', 'P_B_DEPARTMENT'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_PHOTO long varchar', 'C', 'AB.WA.PERSONS', 'P_PHOTO'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_INTERESTS long varchar', 'C', 'AB.WA.PERSONS', 'P_INTERESTS'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_RELATIONSHIPS long varchar', 'C', 'AB.WA.PERSONS', 'P_RELATIONSHIPS'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_ACL long varchar', 'C', 'AB.WA.PERSONS', 'P_ACL'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add P_CERTIFICATE long varchar', 'C', 'AB.WA.PERSONS', 'P_CERTIFICATE'
);

AB.WA.exec_no_error (
  'alter table AB.WA.PERSONS add constraint FK_PERSONS_01 FOREIGN KEY (P_CATEGORY_ID) references AB.WA.CATEGORIES (C_ID) on delete set null'
);

AB.WA.exec_no_error ('
  create trigger PERSONS_AI after insert on AB.WA.PERSONS referencing new as N {
    declare _uid varchar;

    _uid := N.P_UID;
    if (isnull (_uid))
    {
      _uid := AB.WA.uid ();
      set triggers off;
      update AB.WA.PERSONS set P_UID = _uid where P_ID = N.P_ID;
      set triggers on;
    }
    AB.WA.tags_update (N.P_DOMAIN_ID, \'\', N.P_TAGS);
    AB.WA.exchange_entry_update (N.P_DOMAIN_ID);
    AB.WA.syncml_entry_update (N.P_DOMAIN_ID, N.P_ID, _uid, N.P_TAGS, \'I\');
    AB.WA.domain_ping (N.P_DOMAIN_ID);
  }
');

AB.WA.exec_no_error ('
  create trigger PERSONS_AU after update on AB.WA.PERSONS referencing  old as O, new as N {
    declare _uid varchar;

    _uid := N.P_UID;
    if (isnull (_uid))
    {
      _uid := AB.WA.uid ();
      set triggers off;
      update AB.WA.PERSONS set P_UID = _uid where P_ID = N.P_ID;
      set triggers on;
    }
    AB.WA.tags_update (N.P_DOMAIN_ID, O.P_TAGS, N.P_TAGS);
    AB.WA.exchange_entry_update (N.P_DOMAIN_ID);
    AB.WA.syncml_entry_update (N.P_DOMAIN_ID, N.P_ID, _uid, N.P_TAGS, \'U\');
    AB.WA.domain_ping (N.P_DOMAIN_ID);
  }
');

AB.WA.exec_no_error ('
  create trigger PERSONS_AD after delete on AB.WA.PERSONS referencing old as O {
    AB.WA.tags_update (O.P_DOMAIN_ID, O.P_TAGS, \'\');
    AB.WA.syncml_entry_update (O.P_DOMAIN_ID, O.P_ID, O.P_UID, O.P_TAGS, \'D\');
  }
');

-------------------------------------------------------------------------------
--
create procedure AB.WA.tags_update (
  inout domain_id integer,
  in oTags any,
  in nTags any)
{
  declare N integer;

  oTags := split_and_decode (oTags, 0, '\0\0,');
  nTags := split_and_decode (nTags, 0, '\0\0,');

  foreach (any tag in oTags) do {
    if (not AB.WA.vector_contains (nTags, lcase (tag)))
      update AB.WA.TAGS
         set T_COUNT = T_COUNT - 1
       where T_DOMAIN_ID = domain_id
         and T_TAG = lcase (tag);
  }
  foreach (any tag in nTags) do {
    if (not AB.WA.vector_contains (oTags, lcase (tag)))
      if (exists (select 1 from AB.WA.TAGS where T_DOMAIN_ID = domain_id and T_TAG = lcase (tag))) {
        update AB.WA.TAGS
           set T_COUNT = T_COUNT + 1
         where T_DOMAIN_ID = domain_id
           and T_TAG = lcase (tag);
      } else {
       insert replacing AB.WA.TAGS (T_DOMAIN_ID, T_TAG, T_COUNT)
         values (domain_id, lcase (tag), 1);
      }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.PERSONS_P_NAME_int (inout vtb any, inout d_id any, in mode any)
{
  declare tags any;

  for (select * from AB.WA.PERSONS where P_ID = d_id) do
  {
    vt_batch_feed (vtb, sprintf('^R%d', coalesce (P_DOMAIN_ID, 0)), mode);

    vt_batch_feed (vtb, coalesce(P_NAME, ''), mode);
    vt_batch_feed (vtb, coalesce(P_FIRST_NAME, ''), mode);
    vt_batch_feed (vtb, coalesce(P_MIDDLE_NAME, ''), mode);
    vt_batch_feed (vtb, coalesce(P_LAST_NAME, ''), mode);
    vt_batch_feed (vtb, coalesce(P_FULL_NAME, ''), mode);
    vt_batch_feed (vtb, coalesce(P_GENDER, ''), mode);
    vt_batch_feed (vtb, coalesce(P_BIRTHDAY, ''), mode);
    vt_batch_feed (vtb, coalesce(P_MAIL, ''), mode);
    vt_batch_feed (vtb, coalesce(P_WEB, ''), mode);
    vt_batch_feed (vtb, coalesce(P_ICQ, ''), mode);
    vt_batch_feed (vtb, coalesce(P_SKYPE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_AIM, ''), mode);
    vt_batch_feed (vtb, coalesce(P_YAHOO, ''), mode);
    vt_batch_feed (vtb, coalesce(P_MSN, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_COUNTRY, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_STATE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_CITY, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_CODE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_ADDRESS1, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_ADDRESS2, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_TZONE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_LAT, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_LNG, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_PHONE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_MOBILE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_MAIL, ''), mode);
    vt_batch_feed (vtb, coalesce(P_H_WEB, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_COUNTRY, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_STATE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_CITY, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_CODE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_ADDRESS1, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_ADDRESS2, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_TZONE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_LAT, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_LNG, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_PHONE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_MOBILE, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_MAIL, ''), mode);
    vt_batch_feed (vtb, coalesce(P_B_WEB, ''), mode);

    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = P_DOMAIN_ID and WAI_TYPE_NAME = 'AddressBook' and WAI_IS_PUBLIC = 1))
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
create procedure AB.WA.PERSONS_P_NAME_index_hook (inout vtb any, inout d_id any)
{
  return AB.WA.PERSONS_P_NAME_int (vtb, d_id, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.PERSONS_P_NAME_unindex_hook (inout vtb any, inout d_id any)
{
  return AB.WA.PERSONS_P_NAME_int (vtb, d_id, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tmp_update ()
{
  if (registry_get ('ab_index_version') = '3')
    return;

    AB.WA.exec_no_error ('drop table AB.WA.PERSONS_P_NAME_WORDS');
  registry_set ('ab_index_version', '3');
}
;
AB.WA.tmp_update ();

AB.WA.exec_no_error('
  create text index on AB.WA.PERSONS (P_NAME) with key P_ID clustered with (P_DOMAIN_ID, P_UPDATED) using function language \'x-ViDoc\'
');

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.ANNOTATIONS (
    A_ID integer identity,
    A_DOMAIN_ID integer not null,
    A_OBJECT_ID integer not null,
    A_BODY long varchar,
    A_CLAIMS long varchar,
    A_CONTEXT varchar,
    A_AUTHOR varchar,
    A_CREATED datetime,
    A_UPDATED datetime,

    constraint FK_AB_ANNOTATIONS_01 FOREIGN KEY (A_OBJECT_ID) references AB.WA.PERSONS (P_ID) on delete cascade,

    primary key (A_ID)
  )
');

AB.WA.exec_no_error (
  'alter table AB.WA.ANNOTATIONS add A_CLAIMS long varchar', 'C', 'AB.WA.ANNOTATIONS', 'A_CLAIMS'
);

AB.WA.exec_no_error ('
  create index SK_AB_ANNOTATIONS_01 on AB.WA.ANNOTATIONS (A_OBJECT_ID, A_ID)
');

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.PERSON_COMMENTS (
    PC_ID integer identity,
    PC_PARENT_ID integer,
    PC_DOMAIN_ID integer not null,
    PC_PERSON_ID varchar not null,
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

    constraint FK_PERSON_COMMENTS_01 FOREIGN KEY (PC_PERSON_ID) references AB.WA.PERSONS (P_ID) on delete cascade,

    primary key (PC_ID)
  )
');

AB.WA.exec_no_error ('
  create index SK_PERSON_COMMENTS_01 on AB.WA.PERSON_COMMENTS (PC_PERSON_ID)
');

AB.WA.exec_no_error ('
  create trigger PERSON_COMMENTS_I after insert on AB.WA.PERSON_COMMENTS referencing new as N
  {
    declare id integer;
    declare rfc_id, rfc_header, rfc_references varchar;
    declare nInstance any;

    nInstance := AB.WA.domain_nntp_name (N.PC_DOMAIN_ID);
    id := N.PC_ID;
    rfc_id := N.PC_RFC_ID;
    if (isnull(rfc_id))
      rfc_id := AB.WA.make_rfc_id (N.PC_PERSON_ID, N.PC_ID);

    rfc_references := \'\';
    if (N.PC_PARENT_ID)
    {
      declare p_rfc_id, p_rfc_references any;

      --declare exit handler for not found;

      select PC_RFC_ID, PC_RFC_REFERENCES
        into p_rfc_id, p_rfc_references
        from AB.WA.PERSON_COMMENTS
       where PC_ID = N.PC_PARENT_ID;
      if (isnull(p_rfc_references))
         p_rfc_references := rfc_references;
      rfc_references :=  p_rfc_references || \' \' || p_rfc_id;
    }

    rfc_header := N.PC_RFC_HEADER;
    if (isnull(rfc_header))
      rfc_header := AB.WA.make_post_rfc_header (rfc_id, rfc_references, nInstance, N.PC_TITLE, N.PC_UPDATED, N.PC_U_MAIL);

    set triggers off;
    update AB.WA.PERSON_COMMENTS
       set PC_RFC_ID = rfc_id,
           PC_RFC_HEADER = rfc_header,
           PC_RFC_REFERENCES = rfc_references
     where PC_ID = id;
    set triggers on;
  }
')
;

AB.WA.exec_no_error ('
  create trigger PERSON_COMMENTS_NEWS_I after insert on AB.WA.PERSON_COMMENTS order 30 referencing new as N
  {
    declare grp, ngnext integer;
    declare rfc_id, nInstance any;

    declare exit handler for not found { return;};

    nInstance := AB.WA.domain_nntp_name (N.PC_DOMAIN_ID);
    select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nInstance;
    if (ngnext < 1)
      ngnext := 1;
    rfc_id := (select PC_RFC_ID from AB.WA.PERSON_COMMENTS where PC_ID = N.PC_ID);

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

AB.WA.exec_no_error ('
  create trigger PERSON_COMMENTS_D after delete on AB.WA.PERSON_COMMENTS referencing old as O
  {
    -- update all that have PC_PARENT_ID == O.PC_PARENT_ID
    set triggers off;
    update AB.WA.PERSON_COMMENTS
       set PC_PARENT_ID = O.PC_PARENT_ID
     where PC_PARENT_ID = O.PC_ID;
    set triggers on;
  }
')
;

AB.WA.exec_no_error ('
  create trigger PERSON_COMMENTS_NEWS_D after delete on AB.WA.PERSON_COMMENTS order 30 referencing old as O
  {
    declare grp integer;
    declare oInstance any;

    oInstance := AB.WA.domain_nntp_name (O.PC_DOMAIN_ID);
    grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.PC_RFC_ID and NM_GROUP = grp;
    DB.DBA.ns_up_num (grp);
  }
')
;

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error ('
  create table AB.WA.SETTINGS (
    S_DOMAIN_ID integer,
    S_DATA varchar,
    S_ACCOUNT_ID integer,

    primary key (S_DOMAIN_ID)
  )
');

AB.WA.exec_no_error (
  'alter table AB.WA.SETTINGS add S_DOMAIN_ID integer', 'C', 'AB.WA.SETTINGS', 'S_DOMAIN_ID'
)
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tmp_update ()
{
  declare account_id, domain_id integer;

  if (registry_get ('ab_settings_update') = '1')
    return;

  AB.WA.exec_no_error ('update AB.WA.SETTINGS set S_DOMAIN_ID = -S_ACCOUNT_ID');

  set triggers off;
  for (select * from AB.WA.SETTINGS) do
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
                     and C.WAI_TYPE_NAME = 'AddressBook');
    if (isnull (domain_id))
    {
      delete from AB.WA.SETTINGS where S_DOMAIN_ID = -account_id;
    } else {
      update AB.WA.SETTINGS set S_DOMAIN_ID = domain_id where S_DOMAIN_ID = -account_id;
    }
  }
  set triggers on;

  --AB.WA.exec_no_error ('alter table AB.WA.SETTINGS drop S_ACCOUNT_ID', 'D', 'AB.WA.SETTINGS', 'S_ACCOUNT_ID');
  AB.WA.exec_no_error ('alter table AB.WA.SETTINGS modify primary key (S_DOMAIN_ID)');

  registry_set ('ab_settings_update', '1');
}
;
AB.WA.tmp_update ();

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.GRANTS (
    G_ID integer identity,
    G_GRANTER_ID integer not null,
    G_GRANTEE_ID integer not null,
    G_PERSON_ID integer not null,

    PRIMARY KEY (G_ID)
  )
');

AB.WA.exec_no_error('
  create index SK_GRANTS_01 on AB.WA.GRANTS (G_GRANTER_ID, G_PERSON_ID)
');

AB.WA.exec_no_error('
  create index SK_GRANTS_02 on AB.WA.GRANTS (G_GRANTEE_ID, G_PERSON_ID)
');

AB.WA.exec_no_error('
  alter table AB.WA.GRANTS add constraint FK_AB_GRANTS_01 FOREIGN KEY (G_PERSON_ID) references AB.WA.PERSONS (P_ID) on delete cascade
');

-------------------------------------------------------------------------------
--
create procedure AB.WA.grants_procedure (
  in id integer)
{
  declare c0 integer;
  declare c1 varchar;

  result_names (c0, c1);
  for (select distinct b.U_ID, b.U_NAME
         from AB.WA.GRANTS a,
              DB.DBA.SYS_USERS b
        where a.G_GRANTEE_ID = id
          and a.G_GRANTER_ID = b.U_ID
        order by 2) do
  {
    result (U_ID, U_NAME);
  }
  for (select distinct b.U_ID, b.U_NAME
         from AB.WA.GRANTS a,
              DB.DBA.SYS_USERS b,
              DB.DBA.SYS_ROLE_GRANTS c
        where a.G_GRANTER_ID = b.U_ID
          and c.GI_SUPER     = id
          and c.GI_GRANT     = a.G_GRANTEE_ID
          and c.GI_DIRECT    = '1'
        order by 2) do
  {
    result (U_ID, U_NAME);
  }
}
;

AB.WA.exec_no_error ('
  create procedure view AB..GRANTS_VIEW as AB.WA.grants_procedure (id) (U_ID integer, U_NAME varchar)
')
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.grants_person_procedure (
  in to_id integer,
  in from_id integer := null)
{
  declare c0 integer;

  result_names (c0);
  for (select distinct G_PERSON_ID from AB.WA.GRANTS where G_GRANTEE_ID = to_id and (G_GRANTER_ID = from_id or from_id is null) order by 1) do
  {
    result (G_PERSON_ID);
  }
  for (select distinct G_PERSON_ID
         from AB.WA.GRANTS a,
              DB.DBA.SYS_ROLE_GRANTS c
        where (a.G_GRANTER_ID = from_id or from_id is null)
          and c.GI_SUPER     = to_id
          and c.GI_GRANT     = a.G_GRANTEE_ID
          and c.GI_DIRECT    = '1'
        order by 1) do
  {
    result (G_PERSON_ID);
  }
}
;

AB.WA.exec_no_error ('
  create procedure view AB..GRANTS_PERSON_VIEW as AB.WA.grants_person_procedure (to_id, from_id) (G_PERSON_ID integer)
')
;


-------------------------------------------------------------------------------
--
--  PUBLISH & SUBSCRIBE
--
-------------------------------------------------------------------------------
AB.WA.exec_no_error ('
  create table AB.WA.EXCHANGE (
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

AB.WA.exec_no_error(
  'alter table AB.WA.EXCHANGE add EX_UPDATE_SUBTYPE integer', 'C', 'AB.WA.EXCHANGE', 'EX_UPDATE_SUBTYPE'
);

AB.WA.exec_no_error ('
  create trigger EXCHANGE_AI AFTER INSERT ON AB.WA.EXCHANGE referencing new as N
  {
    AB.WA.calc_update_interval (N.EX_ID, N.EX_UPDATE_TYPE, N.EX_UPDATE_PERIOD, N.EX_UPDATE_FREQ);
  }
');

AB.WA.exec_no_error ('
  create trigger EXCHANGE_AU AFTER UPDATE on AB.WA.EXCHANGE referencing old as O, new as N
  {
    AB.WA.calc_update_interval (N.EX_ID, N.EX_UPDATE_TYPE, N.EX_UPDATE_PERIOD, N.EX_UPDATE_FREQ);
  }
');

-------------------------------------------------------------------------------
--
create procedure AB.WA.calc_update_interval (
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
  update AB.WA.EXCHANGE
     set EX_UPDATE_INTERVAL = _update
   where EX_ID = _id;
  set triggers on;
}
;

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'AddressBook Exchange Scheduler\', now(), \'AB.WA.exchange_scheduler ()\', 30)
')
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tags_procedure (
  in tags any)
{
  declare tag varchar;

  result_names (tag);
  tags := split_and_decode (tags, 0, '\0\0,');
  foreach (any tag in tags) do
  {
    result (trim (tag));
}
}
;

AB.WA.exec_no_error ('
  create procedure view AB..TAGS_VIEW as AB.WA.tags_procedure (tags) (TV_TAG varchar)
')
;

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('DROP TABLE AB.WA.LDAP_SERVERS');

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error ('
  create trigger ADDRESSBOOK_SYS_DAV_RES_AI after insert on WS.WS.SYS_DAV_RES order 200 referencing new as N
  {
    declare data any;

    if (not AB.WA.syncml_check (DB.DBA.DAV_SEARCH_PATH (N.RES_COL, \'C\')))
      return;

    if (connection_get (\'__sync_ods\') = \'1\')
      return;

  	data := AB.WA.exec (\'select RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_ID = ?\', vector (N.RES_ID));
  	if (length (data) = 0)
      return;

    AB.WA.syncml2entry (N.RES_CONTENT, N.RES_NAME, N.RES_COL, N.RES_MOD_TIME);
  }
')
;

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error ('
  create trigger ADDRESSBOOK_SYS_DAV_RES_AU after update on WS.WS.SYS_DAV_RES order 200 referencing old as O, new as N
  {
    declare data any;

    if (not AB.WA.syncml_check (DB.DBA.DAV_SEARCH_PATH (N.RES_COL, \'C\')))
      return;

    if (connection_get (\'__sync_ods\') = \'1\')
      return;

  	data := AB.WA.exec (\'select RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_ID = ?\', vector (N.RES_ID));
  	if (length (data) = 0)
      return;

    AB.WA.syncml2entry (N.RES_CONTENT, N.RES_NAME, N.RES_COL, N.RES_MOD_TIME);
  }
')
;

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error ('
  create trigger ADDRESSBOOK_SYS_DAV_RES_AD after delete on WS.WS.SYS_DAV_RES order 200 referencing old as O
  {
    declare _syncmlPath, _path varchar;
    declare data any;

    if (not AB.WA.syncml_check (DB.DBA.DAV_SEARCH_PATH (O.RES_COL, \'C\')))
      return;

    if (connection_get (\'__sync_ods\') = \'1\')
      return;

  	data := AB.WA.exec (\'select RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_ID = ?\', vector (O.RES_ID));
  	if (length (data) = 0)
      return;

    for (select P_ID, P_DOMAIN_ID from AB.WA.PERSONS where P_UID = O.RES_NAME) do
    {
      for (select deserialize (EX_OPTIONS) as _options from AB.WA.EXCHANGE where EX_DOMAIN_ID = P_DOMAIN_ID and EX_TYPE = 2) do
      {
        _path := WS.WS.COL_PATH (O.RES_COL);
        _syncmlPath := get_keyword (\'name\', _options);
        if (_path = _syncmlPath)
        {
          AB.WA.contact_delete (P_ID, P_DOMAIN_ID);
        }
      }
    }
  }
')
;
