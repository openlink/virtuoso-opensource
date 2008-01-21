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
AB.WA.exec_no_error (
  'sequence_set (\'AB.WA.contact_id\', %d, 0)', 'S', 'AB.WA.PERSONS', 'P_ID'
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
  create table AB.WA.PERSONS (
    P_ID integer not null,
    P_DOMAIN_ID integer not null,
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
    P_CREATED datetime,
    P_UPDATED datetime,

    primary key (P_ID)
  )
');

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

AB.WA.exec_no_error ('
  create trigger PERSONS_AI after insert on AB.WA.PERSONS referencing new as N {
    AB.WA.tags_update (N.P_DOMAIN_ID, \'\', N.P_TAGS);
    AB.WA.domain_ping (N.P_DOMAIN_ID);
  }
');

AB.WA.exec_no_error ('
  create trigger PERSONS_AU after update on AB.WA.PERSONS referencing  old as O, new as N {
    AB.WA.tags_update (N.P_DOMAIN_ID, O.P_TAGS, N.P_TAGS);
    AB.WA.domain_ping (N.P_DOMAIN_ID);
  }
');

AB.WA.exec_no_error ('
  create trigger PERSONS_AD after delete on AB.WA.PERSONS referencing old as O {
    AB.WA.tags_update (O.P_DOMAIN_ID, O.P_TAGS, \'\');
    delete from AB.WA.GRANTS where G_PERSON_ID = O.P_ID;
  }
');

-------------------------------------------------------------------------------
--
create procedure AB.WA.table_update ()
{
  if (registry_get ('ab_table_update') = '1')
    return;

  update AB.WA.PERSONS set P_IRI = P_FOAF;
  update AB.WA.PERSONS set P_FOAF = null;

  registry_set ('ab_table_update', '1');
}
;
AB.WA.table_update ();

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

  for (select * from AB.WA.PERSONS where P_ID = d_id) do {
    vt_batch_feed (vtb, sprintf('^R%d', P_DOMAIN_ID), mode);

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
create procedure AB.WA.drop_index()
{
  if (registry_get ('ab_index_version') = '3')
    return;

    AB.WA.exec_no_error ('drop table AB.WA.PERSONS_P_NAME_WORDS');
  registry_set ('ab_index_version', '3');
}
;
AB.WA.drop_index();

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
    A_CONTEXT varchar,
    A_AUTHOR varchar,
    A_CREATED datetime,
    A_UPDATED datetime,

    constraint FK_AB_ANNOTATIONS_01 FOREIGN KEY (A_OBJECT_ID) references AB.WA.PERSONS (P_ID) on delete cascade,

    primary key (A_ID)
  )
');

AB.WA.exec_no_error ('
  create index SK_AB_ANNOTATIONS_01 on AB.WA.ANNOTATIONS (A_OBJECT_ID, A_ID)
');

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('
  create table AB.WA.SETTINGS (
    S_ACCOUNT_ID integer not null,
    S_DATA varchar,

    primary key(S_ACCOUNT_ID)
  )
');

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

create procedure AB.WA.grants_update ()
{
  if (registry_get ('ab_grants_update') = '2')
    return;

    delete from AB.WA.GRANTS where not exists (select 1 from AB.WA.PERSONS where P_ID = G_PERSON_ID);

  registry_set ('ab_grants_update', '2');
}
;

AB.WA.grants_update ();

-------------------------------------------------------------------------------
--
create procedure AB.WA.tags_procedure (
  in tags any)
{
  declare tag varchar;

  result_names (tag);
  tags := split_and_decode (tags, 0, '\0\0,');
  foreach (any tag in tags) do
    result (trim (tag));
}
;

AB.WA.exec_no_error ('
  create procedure view AB..TAGS_VIEW as AB.WA.tags_procedure (tags) (TV_TAG varchar)
')
;

-------------------------------------------------------------------------------
--

-------------------------------------------------------------------------------
--
AB.WA.exec_no_error('DROP TABLE AB.WA.LDAP_SERVERS');
