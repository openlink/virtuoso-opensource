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
-- Contains all subscribed feeds
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.BOOKMARK (
  	B_ID integer identity,
    B_URI varchar not null,
    B_NAME varchar,
    B_DESCRIPTION varchar,
    B_CREATED datetime,
    B_LAST_VISITED datetime,

    primary key (B_ID)
  )
');

BMK.WA.exec_no_error(
  'alter table BMK.WA.BOOKMARK add B_CREATED datetime', 'C', 'BMK.WA.BOOKMARK', 'B_CREATED'
);

BMK.WA.exec_no_error('
  create unique index SK_BOOKMARK_01 on BMK.WA.BOOKMARK(B_URI)
');

-------------------------------------------------------------------------------
--
-- Contains folders structure. Structure is domain specific.
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.FOLDER (
  	F_ID integer identity,
  	F_DOMAIN_ID integer not null,
  	F_PARENT_ID integer,
  	F_NAME varchar not null,
  	F_PATH varchar(1000) not null,

  	primary key (F_ID)
  )
');

BMK.WA.exec_no_error(
  'alter table BMK.WA.FOLDER add F_PATH varchar(1000)', 'C', 'BMK.WA.FOLDER', 'F_PATH'
);

BMK.WA.exec_no_error('
  create unique index SK_FOLDER_01 on BMK.WA.FOLDER(F_DOMAIN_ID, F_PARENT_ID, F_NAME)
');

BMK.WA.exec_no_error('
  create index SK_FOLDER_02 on BMK.WA.FOLDER(F_DOMAIN_ID, F_PATH)
');

BMK.WA.exec_no_error('
  create trigger FOLDER_AI after insert on BMK.WA.FOLDER referencing new as N {
    declare domain_id, folder_id integer;
    declare path varchar;

    domain_id := N.F_DOMAIN_ID;
    folder_id := N.F_ID;
    path := coalesce((select F_PATH from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_ID = N.F_PARENT_ID), \'\');
    path := path || \'/\' || N.F_NAME;
    set triggers off;
    update BMK.WA.FOLDER
       set F_PATH = path
     where F_DOMAIN_ID = domain_id
       and F_ID = folder_id;
    BMK.WA.folder_paths (domain_id, folder_id, path);
    set triggers on;
  }
');

BMK.WA.exec_no_error('
  create trigger FOLDER_AU after update on BMK.WA.FOLDER referencing old as O, new as N {
    if ((N.F_NAME <> O.F_NAME) or isnull(O.F_PATH)) {
      declare domain_id, folder_id integer;
      declare path varchar;

      domain_id := N.F_DOMAIN_ID;
      folder_id := N.F_ID;
      path := coalesce((select F_PATH from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_ID = N.F_PARENT_ID), \'\');
      path := path || \'/\' || N.F_NAME;
      set triggers off;
      update BMK.WA.FOLDER
         set F_PATH = path
       where F_DOMAIN_ID = domain_id
         and F_ID = folder_id;
      BMK.WA.folder_paths (domain_id, folder_id, path);
      set triggers on;
    }
  }
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_paths(
  in domain_id integer,
  in parent_id integer,
  in path varchar)
{
  declare folder_id integer;
  declare name varchar;

  for (select F_NAME, F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_PARENT_ID = parent_id) do
  {
    folder_id := F_ID;
    name := F_NAME;
    update BMK.WA.FOLDER
       set F_PATH = path || '/' || name
     where F_DOMAIN_ID = domain_id
       and F_ID = folder_id;
    BMK.WA.folder_paths(domain_id, folder_id, path || '/' || name);
  }
}
;

-------------------------------------------------------------------------------
--
-- Contains smart folders structure. Structure is domain specific.
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.SFOLDER (
  	SF_ID integer identity,
  	SF_DOMAIN_ID integer not null,
  	SF_NAME varchar not null,
  	SF_DATA long varchar,

  	primary key (SF_ID)
  )
');

BMK.WA.exec_no_error('
  create unique index SK_SFOLDER_01 on BMK.WA.SFOLDER(SF_DOMAIN_ID, SF_NAME)
');

BMK.WA.exec_no_error (
  'set_identity_column (\'BMK.WA.SFOLDER\', \'SF_ID\', %d)', 'I', 'BMK.WA.SFOLDER', 'SF_ID'
)
;

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error('
  create table BMK.WA.TAGS (
    T_DOMAIN_ID integer not null,
    T_ACCOUNT_ID integer not null,
    T_TAG varchar,
    T_COUNT integer,
    T_LAST_UPDATE datetime,

    primary key (T_DOMAIN_ID, T_ACCOUNT_ID, T_TAG)
  )
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.TAGS_STATISTICS (
  in domain_id integer,
  in account_id integer)
{
  declare ts_tag varchar;
  declare ts_count integer;

  BMK.WA.tags_refresh (domain_id, account_id, 1);
  result_names (ts_tag, ts_count);
  for (select T_TAG, T_COUNT FROM BMK.WA.TAGS where T_DOMAIN_ID = domain_id and T_ACCOUNT_ID = account_id) do
    result (T_TAG, T_COUNT);
}
;

BMK.WA.exec_no_error('
  create procedure view BMK..TAGS_STATISTICS as BMK.WA.TAGS_STATISTICS (domain_id, account_id) (TS_TAG varchar, TS_COUNT integer)
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tags_update (
  inout domain_id integer,
  in oTags any,
  in nTags any)
{
  declare N integer;

  oTags := split_and_decode (oTags, 0, '\0\0,');
  nTags := split_and_decode (nTags, 0, '\0\0,');

  foreach (any tag in oTags) do 
  {
    if (not BMK.WA.vector_contains (nTags, lcase (tag)))
      update BMK.WA.TAGS
         set T_COUNT = T_COUNT - 1
       where T_DOMAIN_ID = domain_id
         and T_TAG = lcase (tag)
         and T_COUNT > 0;
  }
  foreach (any tag in nTags) do 
  {
    if (not BMK.WA.vector_contains (oTags, lcase (tag)))
      if (exists (select 1 from BMK.WA.TAGS where T_DOMAIN_ID = domain_id and T_TAG = lcase (tag))) 
      {
        update BMK.WA.TAGS
           set T_COUNT = T_COUNT + 1
         where T_DOMAIN_ID = domain_id
           and T_TAG = lcase (tag);
      } else {
        insert replacing BMK.WA.TAGS (T_DOMAIN_ID, T_ACCOUNT_ID, T_TAG, T_COUNT)
          values (domain_id, 0, lcase (tag), 1);
      }
  }
}
;

-------------------------------------------------------------------------------
--
-- Contains domain bookmarks
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.BOOKMARK_DOMAIN (
    BD_ID integer identity,
    BD_UID varchar,
  	BD_DOMAIN_ID integer not null,
  	BD_BOOKMARK_ID integer not null,
  	BD_FOLDER_ID integer,
    BD_NAME varchar,
    BD_DESCRIPTION varchar,
    BD_TAGS varchar,
    BD_ACL long varchar,
    BD_CREATED datetime,
    BD_UPDATED datetime,
    BD_VISITED datetime,

    constraint FK_BOOKMARK_DOMAIN_01 FOREIGN KEY (BD_BOOKMARK_ID) references BMK.WA.BOOKMARK (B_ID) on delete cascade,
    constraint FK_BOOKMARK_DOMAIN_02 FOREIGN KEY (BD_FOLDER_ID) references BMK.WA.FOLDER (F_ID) on delete set null,

    primary key (BD_ID)
  )
');

BMK.WA.exec_no_error(
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_UID varchar', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_UID'
);

BMK.WA.exec_no_error (
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_TAGS varchar', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_TAGS'
);

BMK.WA.exec_no_error (
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_UPDATED datetime', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_UPDATED'
);

BMK.WA.exec_no_error (
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_VISITED datetime', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_VISITED'
);

BMK.WA.exec_no_error (
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_CREATED datetime', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_CREATED'
);

BMK.WA.exec_no_error (
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_ACL long varchar', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_ACL'
);

BMK.WA.exec_no_error('
  drop index SK_BOOKMARK_DOMAIN_01 BMK.WA.BOOKMARK_DOMAIN
');

BMK.WA.exec_no_error('
  create index SK_BOOKMARK_DOMAIN_01 on BMK.WA.BOOKMARK_DOMAIN(BD_DOMAIN_ID, BD_BOOKMARK_ID)
');

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_DOMAIN_WA_AI after insert on BMK.WA.BOOKMARK_DOMAIN referencing new as N {
    declare _uid varchar;

    _uid := N.BD_UID;
    if (isnull (_uid))
    {
      _uid := BMK.WA.uid ();
      set triggers off;
      update BMK.WA.BOOKMARK_DOMAIN set BD_UID = _uid where BD_ID = N.BD_ID;
      set triggers on;
    }
    BMK.WA.tags_update (N.BD_DOMAIN_ID, \'\', N.BD_TAGS);
    BMK.WA.exchange_entry_update (N.BD_DOMAIN_ID);
    BMK.WA.domain_ping (N.BD_DOMAIN_ID);
    if (__proc_exists (\'DB.DBA.WA_NEW_BOOKMARKS_IN\'))
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = N.BD_DOMAIN_ID and WAI_IS_PUBLIC = 1))
        DB.DBA.WA_NEW_BOOKMARKS_IN (N.BD_NAME, sprintf(\'/bookmark/bookmarks.vspx?location=%d\', N.BD_ID), N.BD_ID);
  }
');

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_DOMAIN_WA_AU after update on BMK.WA.BOOKMARK_DOMAIN referencing old as O, new as N  {
    declare _uid varchar;

    _uid := N.BD_UID;
    if (isnull (_uid))
    {
      _uid := BMK.WA.uid ();
      set triggers off;
      update BMK.WA.BOOKMARK_DOMAIN set BD_UID = _uid where BD_ID = N.BD_ID;
      set triggers on;
    }
    BMK.WA.tags_update (N.BD_DOMAIN_ID, O.BD_TAGS, N.BD_TAGS);
    BMK.WA.exchange_entry_update (N.BD_DOMAIN_ID);
    BMK.WA.domain_ping (N.BD_DOMAIN_ID);
    if (__proc_exists (\'DB.DBA.WA_NEW_BOOKMARKS_IN\'))
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = N.BD_DOMAIN_ID and WAI_IS_PUBLIC = 1))
        DB.DBA.WA_NEW_BOOKMARKS_IN (N.BD_NAME, sprintf(\'/bookmark/bookmarks.vspx?location=%d\', N.BD_ID), N.BD_ID);
  }
');

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_DOMAIN_WA_AD after delete on BMK.WA.BOOKMARK_DOMAIN referencing old as O {
    BMK.WA.tags_update (O.BD_DOMAIN_ID, O.BD_TAGS, \'\');
    if (__proc_exists (\'DB.DBA.WA_NEW_BOOKMARKS_RM\'))
      DB.DBA.WA_NEW_BOOKMARKS_RM (O.BD_ID);
  }
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.table_update ()
{
  if (registry_get ('bmk_table_update') = '1')
    return;

  declare _account_id integer;

  BMK.WA.exec_no_error ('update BMK.WA.BOOKMARK_DOMAIN set BD_UPDATED = BD_LAST_UPDATE');

  delete from BMK.WA.TAGS;
  for (select BD_ID as _id, BD_DOMAIN_ID as _domain_id, BD_BOOKMARK_ID as _bookmark_id from BMK.WA.BOOKMARK_DOMAIN) do
  {
    _account_id := BMK.WA.domain_owner_id (_domain_id);
    update BMK.WA.BOOKMARK_DOMAIN set BD_TAGS = BMK.WA.tags_select (_domain_id, _account_id, _bookmark_id) where BD_ID = _id;

  }
  registry_set ('bmk_table_update', '1');
}
;
BMK.WA.table_update ();

BMK.WA.exec_no_error (
  'alter table BMK.WA.BOOKMARK_DOMAIN drop BD_LAST_UPDATE', 'D', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_LAST_UPDATE'
);

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error('
  create table BMK.WA.ANNOTATIONS (
    A_ID integer identity,
    A_DOMAIN_ID integer not null,
    A_OBJECT_ID integer not null,
    A_BODY long varchar,
    A_CLAIMS long varchar,
    A_CONTEXT varchar,
    A_AUTHOR varchar,
    A_CREATED datetime,
    A_UPDATED datetime,

    constraint FK_BMK_ANNOTATIONS_01 FOREIGN KEY (A_OBJECT_ID) references BMK.WA.BOOKMARK_DOMAIN (BD_ID) on delete cascade,

    primary key (A_ID)
  )
');

BMK.WA.exec_no_error (
  'alter table BMK.WA.ANNOTATIONS add A_CLAIMS long varchar', 'C', 'BMK.WA.ANNOTATIONS', 'A_CLAIMS'
);

BMK.WA.exec_no_error ('
  create index SK_BMK_ANNOTATIONS_01 on BMK.WA.ANNOTATIONS (A_OBJECT_ID, A_ID)
');

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error ('
  create table BMK.WA.BOOKMARK_COMMENT (
    BC_ID integer identity,
    BC_PARENT_ID integer,
    BC_DOMAIN_ID integer not null,
    BC_BOOKMARK_ID varchar not null,
    BC_TITLE varchar,
    BC_COMMENT long varchar,
    BC_U_NAME varchar,
    BC_U_MAIL varchar,
    BC_U_URL varchar,
    BC_RFC_ID varchar,
    BC_RFC_HEADER long varchar,
    BC_RFC_REFERENCES varchar,
    BC_OPENID_SIG long varbinary,
    BC_CREATED datetime,
    BC_UPDATED datetime,

    constraint FK_BOOKMARK_COMMENT_01 FOREIGN KEY (BC_BOOKMARK_ID) references BMK.WA.BOOKMARK_DOMAIN (BD_ID) on delete cascade,

    primary key (BC_ID)
  )
');

BMK.WA.exec_no_error ('
  create index SK_BOOKMARK_COMMENT_01 on BMK.WA.BOOKMARK_COMMENT (BC_BOOKMARK_ID)
');

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_COMMENT_I after insert on BMK.WA.BOOKMARK_COMMENT referencing new as N
  {
    declare id integer;
    declare rfc_id, rfc_header, rfc_references varchar;
    declare nInstance any;

    nInstance := BMK.WA.domain_nntp_name (N.BC_DOMAIN_ID);
    id := N.BC_ID;
    rfc_id := N.BC_RFC_ID;
    if (isnull(rfc_id))
      rfc_id := BMK.WA.make_rfc_id (N.BC_BOOKMARK_ID, N.BC_ID);

    rfc_references := \'\';
    if (N.BC_PARENT_ID)
    {
      declare p_rfc_id, p_rfc_references any;

      --declare exit handler for not found;

      select BC_RFC_ID, BC_RFC_REFERENCES
        into p_rfc_id, p_rfc_references
        from BMK.WA.BOOKMARK_COMMENT
       where BC_ID = N.BC_PARENT_ID;
      if (isnull(p_rfc_references))
         p_rfc_references := rfc_references;
      rfc_references :=  p_rfc_references || \' \' || p_rfc_id;
    }

    rfc_header := N.BC_RFC_HEADER;
    if (isnull(rfc_header))
      rfc_header := BMK.WA.make_post_rfc_header (rfc_id, rfc_references, nInstance, N.BC_TITLE, N.BC_UPDATED, N.BC_U_MAIL);

    set triggers off;
    update BMK.WA.BOOKMARK_COMMENT
       set BC_RFC_ID = rfc_id,
           BC_RFC_HEADER = rfc_header,
           BC_RFC_REFERENCES = rfc_references
     where BC_ID = id;
    set triggers on;
  }
')
;

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_COMMENT_NEWS_I after insert on BMK.WA.BOOKMARK_COMMENT order 30 referencing new as N
  {
    declare grp, ngnext integer;
    declare rfc_id, nInstance any;

    declare exit handler for not found { return;};

    nInstance := BMK.WA.domain_nntp_name (N.BC_DOMAIN_ID);
    select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nInstance;
    if (ngnext < 1)
      ngnext := 1;
    rfc_id := (select BC_RFC_ID from BMK.WA.BOOKMARK_COMMENT where BC_ID = N.BC_ID);

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

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_COMMENT_D after delete on BMK.WA.BOOKMARK_COMMENT referencing old as O
  {
    -- update all that have BC_PARENT_ID == O.BC_PARENT_ID
    set triggers off;
    update BMK.WA.BOOKMARK_COMMENT
       set BC_PARENT_ID = O.BC_PARENT_ID
     where BC_PARENT_ID = O.BC_ID;
    set triggers on;
  }
')
;

BMK.WA.exec_no_error ('
  create trigger BOOKMARK_COMMENT_NEWS_D after delete on BMK.WA.BOOKMARK_COMMENT order 30 referencing old as O
  {
    declare grp integer;
    declare oInstance any;

    oInstance := BMK.WA.domain_nntp_name (O.BC_DOMAIN_ID);
    grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.BC_RFC_ID and NM_GROUP = grp;
    DB.DBA.ns_up_num (grp);
  }
')
;

-------------------------------------------------------------------------------
--
-- Contains settings
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.SETTINGS (
    S_DOMAIN_ID integer,
    S_DATA varchar,
    S_ACCOUNT_ID integer,

    primary key (S_DOMAIN_ID)
  )
');

BMK.WA.exec_no_error (
  'alter table BMK.WA.SETTINGS add S_DOMAIN_ID integer', 'C', 'BMK.WA.SETTINGS', 'S_DOMAIN_ID'
)
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tmp_update ()
{
  declare account_id, domain_id integer;

  if (registry_get ('bmk_settings_update') = '1')
    return;

  BMK.WA.exec_no_error ('update BMK.WA.SETTINGS set S_DOMAIN_ID = -S_ACCOUNT_ID');

  set triggers off;
  for (select * from BMK.WA.SETTINGS) do
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
                     and C.WAI_TYPE_NAME = 'Bookmark');
    if (isnull (domain_id))
    {
      delete from BMK.WA.SETTINGS where S_DOMAIN_ID = -account_id;
    } else {
      update BMK.WA.SETTINGS set S_DOMAIN_ID = domain_id where S_DOMAIN_ID = -account_id;
    }
  }
  set triggers on;

  --BMK.WA.exec_no_error ('alter table BMK.WA.SETTINGS drop S_ACCOUNT_ID', 'D', 'BMK.WA.SETTINGS', 'S_ACCOUNT_ID');
  BMK.WA.exec_no_error ('alter table BMK.WA.SETTINGS modify primary key (S_DOMAIN_ID)');

  registry_set ('bmk_settings_update', '1');
}
;
BMK.WA.tmp_update ();

-------------------------------------------------------------------------------
--
-- Contains sharings
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error ('
  create table BMK.WA.GRANTS (
    G_ID integer identity,
    G_GRANTER_ID integer not null,
    G_GRANTEE_ID integer not null,
    G_TYPE char(1) not null,
    G_OBJECT_TYPE char(1) not null,
    G_OBJECT_ID integer not null,

    PRIMARY KEY (G_ID)
  )
');

BMK.WA.exec_no_error('
  create index SK_GRANTS_01 on BMK.WA.GRANTS (G_GRANTER_ID, G_OBJECT_TYPE, G_OBJECT_ID)
');

BMK.WA.exec_no_error('
  create index SK_GRANTS_02 on BMK.WA.GRANTS (G_GRANTEE_ID, G_OBJECT_TYPE, G_OBJECT_ID)
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.grants_procedure (
  in gw_id integer)
{
  declare c0 integer;
  declare c1 varchar;

  result_names (c0, c1);
  for (select distinct b.U_ID, b.U_NAME
         from BMK.WA.GRANTS a,
              DB.DBA.SYS_USERS b
        where a.G_GRANTEE_ID = gw_id
          and a.G_GRANTER_ID = b.U_ID
        order by 2) do
  {
    result (U_ID, U_NAME);
  }
  for (select distinct b.U_ID, b.U_NAME
         from BMK.WA.GRANTS a,
              DB.DBA.SYS_USERS b,
              DB.DBA.SYS_ROLE_GRANTS c
        where a.G_GRANTER_ID = b.U_ID
          and c.GI_SUPER     = gw_id
          and c.GI_GRANT     = a.G_GRANTEE_ID
          and c.GI_DIRECT    = '1'
        order by 2) do
  {
    result (U_ID, U_NAME);
  }
}
;

BMK.WA.exec_no_error ('
  create procedure view BMK..GRANTS_VIEW as BMK.WA.grants_procedure (gw_id) (U_ID integer, U_NAME varchar)
')
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.grants_object_procedure (
  in gow_type varchar := null,
  in gow_to integer,
  in gow_from integer := null)
{
  declare c0 integer;

  result_names (c0, c0);
  for (select distinct G_ID, G_OBJECT_ID
         from BMK.WA.GRANTS
        where (G_OBJECT_TYPE = gow_type or gow_type is null)
          and G_GRANTEE_ID  = gow_to
          and (G_GRANTER_ID = gow_from or gow_from is null) order by 1) do
  {
    result (G_ID, G_OBJECT_ID);
  }
  for (select distinct G_ID, G_OBJECT_ID
         from BMK.WA.GRANTS a,
              DB.DBA.SYS_ROLE_GRANTS c
        where (a.G_OBJECT_TYPE = gow_type or gow_type is null)
          and c.GI_SUPER      = gow_to
          and (a.G_GRANTER_ID = gow_from or gow_from is null)
          and c.GI_GRANT      = a.G_GRANTEE_ID
          and c.GI_DIRECT     = '1'
        order by 1) do
  {
    result (G_ID, G_OBJECT_ID);
  }
}
;

BMK.WA.exec_no_error ('
  create procedure view BMK..GRANTS_OBJECT_VIEW as BMK.WA.grants_object_procedure (gow_type, gow_to, gow_from) (G_ID integer, G_OBJECT_ID integer)
')
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.drop_index ()
{
  if (registry_get ('bmk_index_version') = '3')
    return;

  BMK.WA.exec_no_error ('drop table BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_WORDS');
  registry_set ('bmk_index_version', '3');
}
;
BMK.WA.drop_index ();

BMK.WA.exec_no_error('
  create text index on BMK.WA.BOOKMARK_DOMAIN (BD_DESCRIPTION) with key BD_ID not insert clustered with (BD_ID, BD_UPDATED) using function language \'x-ViDoc\'
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_index_hook (inout vtb any, inout d_id any)
{
  return BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_int (vtb, d_id, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_unindex_hook (inout vtb any, inout d_id any)
{
  return BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_int (vtb, d_id, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_int (inout vtb any, inout d_id any, in mode any)
{
  declare tags any;

  for (select BD_DOMAIN_ID, BD_BOOKMARK_ID, BD_NAME, BD_DESCRIPTION, BD_TAGS from BMK.WA.BOOKMARK_DOMAIN where BD_ID = d_id) do {
    vt_batch_feed (vtb, sprintf('^R%d', BD_DOMAIN_ID), mode);

    vt_batch_feed (vtb, sprintf('^UID%d', coalesce (BMK.WA.domain_owner_id (BD_DOMAIN_ID), 0)), mode);

    vt_batch_feed (vtb, coalesce(BD_NAME, ''), mode);

    vt_batch_feed (vtb, coalesce(BD_DESCRIPTION, ''), mode);

    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = BD_DOMAIN_ID and WAI_TYPE_NAME = 'bookmark' and WAI_IS_PUBLIC = 1))
      vt_batch_feed (vtb, '^public', mode);

    tags := split_and_decode (BD_TAGS, 0, '\0\0,');
    foreach (any tag in tags) do
    {
      tag := concat('^T', trim(tag));
      tag := replace (tag, ' ', '_');
      tag := replace (tag, '+', '_');
      vt_batch_feed (vtb, tag, mode);
    }

    vt_batch_feed_offband (vtb, serialize (vector (d_id, BD_BOOKMARK_ID)), mode);
  }
  return 1;
}
;

BMK.WA.vt_index_BMK_WA_BOOKMARK_DOMAIN ();
DB.DBA.vt_batch_update('BMK.WA.BOOKMARK_DOMAIN', 'off', null);

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error ('drop trigger WA_MEMBER_AU_BMK');

-------------------------------------------------------------------------------
--
--  PUBLISH & SUBSCRIBE
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error ('
  create table BMK.WA.EXCHANGE (
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

BMK.WA.exec_no_error(
  'alter table BMK.WA.EXCHANGE add EX_UPDATE_SUBTYPE integer', 'C', 'BMK.WA.EXCHANGE', 'EX_UPDATE_SUBTYPE'
);

BMK.WA.exec_no_error ('
  create trigger EXCHANGE_AI AFTER INSERT ON BMK.WA.EXCHANGE referencing new as N
  {
    BMK.WA.calc_update_interval (N.EX_ID, N.EX_UPDATE_TYPE, N.EX_UPDATE_PERIOD, N.EX_UPDATE_FREQ);
  }
');

BMK.WA.exec_no_error ('
  create trigger EXCHANGE_AU AFTER UPDATE on BMK.WA.EXCHANGE referencing old as O, new as N
  {
    BMK.WA.calc_update_interval (N.EX_ID, N.EX_UPDATE_TYPE, N.EX_UPDATE_PERIOD, N.EX_UPDATE_FREQ);
  }
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.calc_update_interval (
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
  update BMK.WA.EXCHANGE
     set EX_UPDATE_INTERVAL = _update
   where EX_ID = _id;
  set triggers on;
}
;

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'Bookmark Exchange Scheduler\', now(), \'BMK.WA.exchange_scheduler ()\', 30)
')
;

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error('
  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = \'BM tags aggregator\'
')
;

create procedure BMK.WA.tags_procedure (
  in domain_id any,
  in account_id any,
  in item_id any)
{
  declare tag varchar;
  declare tags any;

  result_names (tag);
  tags := BMK.WA.tags_select (domain_id, item_id);
  tags := split_and_decode (tags, 0, '\0\0,');
  foreach (any tag in tags) do
    result (trim (tag));
}
;

BMK.WA.exec_no_error ('
  create procedure view BMK..TAGS_VIEW as BMK.WA.tags_procedure (domain_id, account_id, item_id) (BTV_TAG varchar)
')
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.path_update()
{
  update BMK.WA.FOLDER set F_PARENT_ID = -1 where F_PARENT_ID = 0;

  if (registry_get ('bmk_path_update') = '1')
    return;

  update BMK.WA.FOLDER set F_NAME = F_NAME where coalesce(F_PARENT_ID, -1) = -1;
  registry_set ('bmk_path_update', '1');
}
;
BMK.WA.path_update()
;

BMK.WA.exec_no_error ('
  create trigger VSPX_SESSION_BOOKMARK_AD after delete on DB.DBA.VSPX_SESSION referencing old as O {
    DB.DBA.DAV_DELETE_INT (\'/DAV/VAD/Bookmarks/Import/\' || O.VS_SID, 1, null, null, 0);
  }
');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DATA');

