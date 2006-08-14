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
-- Conatins all subscribed feeds
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
-- Conatins folders structure. Structure is domain specific.
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

  for (select F_NAME, F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_PARENT_ID = parent_id) do {
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
-- Conatins smart folders structure. Structure is domain specific.
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

-------------------------------------------------------------------------------
--
-- Conatins domain feeds.
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.BOOKMARK_DOMAIN (
    BD_ID integer identity,
  	BD_DOMAIN_ID integer not null,
  	BD_BOOKMARK_ID integer not null,
  	BD_FOLDER_ID integer,
    BD_NAME varchar,
    BD_DESCRIPTION varchar,
    BD_CREATED datetime,
    BD_LAST_UPDATE datetime,

    constraint FK_BOOKMARK_DOMAIN_01 FOREIGN KEY (BD_BOOKMARK_ID) references BMK.WA.BOOKMARK (B_ID) on delete cascade,
    constraint FK_BOOKMARK_DOMAIN_02 FOREIGN KEY (BD_FOLDER_ID) references BMK.WA.FOLDER (F_ID) on delete set null,

    primary key (BD_ID)
  )
');

BMK.WA.exec_no_error(
  'alter table BMK.WA.BOOKMARK_DOMAIN add BD_CREATED datetime', 'C', 'BMK.WA.BOOKMARK_DOMAIN', 'BD_CREATED'
);

BMK.WA.exec_no_error('
  drop index SK_BOOKMARK_DOMAIN_01 BMK.WA.BOOKMARK_DOMAIN
');

BMK.WA.exec_no_error('
  create index SK_BOOKMARK_DOMAIN_01 on BMK.WA.BOOKMARK_DOMAIN(BD_DOMAIN_ID, BD_BOOKMARK_ID)
');

-------------------------------------------------------------------------------
--
-- Conatins specific data for feed items and domain/user - flags, tags and etc.
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.BOOKMARK_DATA (
  	BD_ID integer identity,
  	BD_MODE integer,
  	BD_OBJECT_ID integer,
  	BD_BOOKMARK_ID integer not null,
  	BD_TAGS varchar,
    BD_LAST_UPDATE datetime,
    BD_LAST_VISITED datetime,

    constraint FK_BOOKMARK_DATA_01 FOREIGN KEY (BD_BOOKMARK_ID) references BMK.WA.BOOKMARK (B_ID) on delete cascade,

  	primary key (BD_ID)
  )
');

BMK.WA.exec_no_error('
  create index SK_BOOKMARK_DATA_01 on BMK.WA.BOOKMARK_DATA(BD_MODE, BD_OBJECT_ID, BD_BOOKMARK_ID)
');

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
-- Conatins settings.
--
-------------------------------------------------------------------------------
BMK.WA.exec_no_error('
  create table BMK.WA.SETTINGS (
    S_ACCOUNT_ID integer not null,
    S_DATA varchar,

    primary key(S_ACCOUNT_ID)
  )
');

-------------------------------------------------------------------------------
--
-- Conatins sharings
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
BMK.WA.exec_no_error('
  drop table BMK.WA.BOOKMARK_DOMAIN_BD_DESCRIPTION_WORDS
');

BMK.WA.exec_no_error('
  create text index on BMK.WA.BOOKMARK_DOMAIN(BD_DESCRIPTION) with key BD_ID not insert clustered with (BD_ID) using function
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
  for (select BD_DOMAIN_ID, BD_BOOKMARK_ID, BD_NAME, BD_DESCRIPTION from BMK.WA.BOOKMARK_DOMAIN where BD_ID = d_id) do {
    vt_batch_feed (vtb, sprintf('^R%d', BD_DOMAIN_ID), mode);

    vt_batch_feed (vtb, coalesce(BD_NAME, ''), mode);

    vt_batch_feed (vtb, coalesce(BD_DESCRIPTION, ''), mode);

    if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = BD_DOMAIN_ID and WAI_TYPE_NAME = 'bookmark' and WAI_IS_PUBLIC = 1))
      vt_batch_feed (vtb, '^public', mode);

    vt_batch_feed_offband (vtb, serialize (vector (d_id, BD_BOOKMARK_ID)), mode);
  }
  return 1;
}
;

BMK.WA.vt_index_BMK_WA_BOOKMARK_DOMAIN();
DB.DBA.vt_batch_update('BMK.WA.BOOKMARK_DOMAIN', 'off', null);

BMK.WA.exec_no_error('
  drop table BMK.WA.BOOKMARK_DATA_BD_TAGS_WORDS
');

BMK.WA.exec_no_error('
  create text index on BMK.WA.BOOKMARK_DATA (BD_TAGS) with key BD_ID not insert clustered with (BD_ID, BD_MODE, BD_OBJECT_ID, BD_BOOKMARK_ID) using function language \'x-ViDoc\'
');

-------------------------------------------------------------------------------
--
create procedure BMK.WA.BOOKMARK_DATA_BD_TAGS_index_hook (inout vtb any, inout d_id any)
{
  return BMK.WA.BOOKMARK_DATA_BD_TAGS_int(vtb, d_id, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.BOOKMARK_DATA_BD_TAGS_unindex_hook (inout vtb any, inout d_id any)
{
  return BMK.WA.BOOKMARK_DATA_BD_TAGS_int(vtb, d_id, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.BOOKMARK_DATA_BD_TAGS_int (inout vtb any, inout d_id any, in mode any)
{
  declare tags any;

  for (select BD_MODE, BD_OBJECT_ID, BD_BOOKMARK_ID, BD_TAGS from BMK.WA.BOOKMARK_DATA where BD_ID = d_id) do {

    tags := split_and_decode (BD_TAGS, 0, '\0\0,');
    foreach (any tag in tags) do  {
      tag := trim(tag);
      tag := replace (tag, ' ', '_');
      tag := replace (tag, '+', '_');
      vt_batch_feed (vtb, tag, mode);
    }

    if (BD_MODE = 0) {
      if (exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = BD_OBJECT_ID and WAI_TYPE_NAME = 'bookmark' and WAI_IS_PUBLIC = 1))
        vt_batch_feed (vtb, '^public', mode);
      vt_batch_feed (vtb, sprintf ('^R%d', BD_OBJECT_ID), mode);
    } else {
      vt_batch_feed (vtb, sprintf ('^UID%d', BD_OBJECT_ID), mode);
    }

    vt_batch_feed (vtb, sprintf ('^I%d', BD_BOOKMARK_ID), mode);

    vt_batch_feed_offband (vtb, serialize (vector (d_id, BD_MODE, BD_OBJECT_ID, BD_BOOKMARK_ID)), mode);
  }

  return 1;
}
;

BMK.WA.vt_index_BMK_WA_BOOKMARK_DATA();
DB.DBA.vt_batch_update('BMK.WA.BOOKMARK_DATA', 'off', null);

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error('
  create trigger WA_MEMBER_AU_BMK AFTER UPDATE ON DB.DBA.WA_MEMBER order 20 referencing old as O, new as N {
    declare domain_id, account_id integer;

    if ((O.WAM_INST <> N.WAM_INST) and (N.WAM_MEMBER_TYPE = 1)) {
      account_id := N.WAM_USER;
      domain_id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = N.WAM_INST);
      BMK.WA.domain_gems_delete(domain_id, account_id, \'BM\', O.WAM_INST || \'_Gems\');
      BMK.WA.domain_gems_create(domain_id, account_id);
    }
  }
');

-------------------------------------------------------------------------------
--
BMK.WA.exec_no_error('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'BM tags aggregator\', now(), \'BMK.WA.tags_agregator()\', 1440)
')
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.path_update()
{
  if (registry_get ('bmk_path_update') <> '1')
    update BMK.WA.FOLDER
       set F_NAME = F_NAME
     where coalesce(F_PARENT_ID, 0) = 0;
}
;
BMK.WA.path_update()
;
registry_set ('bmk_path_update', '1')
;
