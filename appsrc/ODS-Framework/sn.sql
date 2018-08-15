--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
--
create procedure wa_exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure wa_add_col(in tbl varchar, in col varchar, in coltype varchar,in postexec varchar := '')
{
 if(exists(
           select
             top 1 1
           from
             DB.DBA.SYS_COLS
           where
             upper("TABLE") = upper(tbl) and
             upper("COLUMN") = upper(col)
          )
    ) return;
  exec (sprintf ('alter table %s add column %s %s', tbl, col, coltype));
  if (postexec <> '' and not(isnull(postexec)))
    exec (postexec);
}
;

wa_exec_no_error ('create table sn_source (
    sns_id int,
    sns_name varchar,
    primary key (sns_id))');

--!
-- Old versions of ODS created sn_person and sn_group as "under sn_entity". Since V7 does not
-- support that we now create sn_entity as a view onto sn_person and sn_group. This, however,
-- requires some updating if we have existing data.
--
-- To that end we rename the old tables, the create the new ones how we want them, copy the old
-- data, and finally remove the old tables.
--
-- Since several other tables reference sn_entity and V does not support changing "references"
-- options of columns we also need to recreate those tables.
--/
create procedure sn_update_person_and_group_tables ()
{
  if (registry_get ('__WA_SN_UNDER_TABLE_UPGRADE') = 'done')
    return;

  -- Remove old indices, to avoid name clashes
  wa_exec_no_error('drop index DB_DBA_sn_entity_UNQC_sne_name sn_person');
  wa_exec_no_error('drop index DB_DBA_sn_person_UNQC_sne_name sn_person');
  wa_exec_no_error('drop index DB_DBA_sn_entity_UNQC_sne_name sn_group');
  wa_exec_no_error('drop index DB_DBA_sn_group_UNQC_sne_name sn_group');

  -- Rename old tables
  wa_exec_no_error('alter table sn_person rename sn_person_old');
  wa_exec_no_error('alter table sn_group rename sn_group_old');
  wa_exec_no_error('alter table sn_entity rename sn_entity_old');
  wa_exec_no_error('drop view sn_entity');

  -- Rename tables that reference sn_entity (sadly we cannot change reference columns)
  wa_exec_no_error('alter table sn_alias rename sn_alias_old');
  wa_exec_no_error('alter table sn_member rename sn_member_old');
  wa_exec_no_error('alter table sn_related rename sn_related_old');
  wa_exec_no_error('alter table sn_invitation rename sn_invitation_old');

  -- Drop the triggers on sn_entity which are not removed or changed by the table rename
  for select name_part (t_name, 2) as t from sys_triggers where t_table = 'DB.DBA.sn_entity' do
  {
    exec_stmt (sprintf ('drop trigger %s', t), 0);
  }

  -- create new tables
  wa_exec_no_error('create table sn_person (
    sne_id int identity,
    sne_name varchar unique,
    sne_source int references sn_source,
    sne_org_id any,
    primary key (sne_id))');

  wa_exec_no_error('create table sn_group (
    sne_id int identity,
    sne_name varchar unique,
    sne_source int references sn_source,
    sne_org_id any,
    primary key (sne_id))');

  -- create sn_entity as a view on the other two
  wa_exec_no_error('create view sn_entity as
    select sne_id, sne_name, sne_source, sne_org_id from sn_person
    union
    select (-1*sne_id) as sne_id, sne_name, sne_source, sne_org_id from sn_group');


  -- Create tables referencing sn_entity
  wa_exec_no_error('create table sn_alias (
    sna_alias int,
    sna_entity varchar,
    primary key (sna_alias))');

  wa_exec_no_error('create table sn_member (
    snm_group int,
    snm_entity int,
    primary key (snm_group, snm_entity))');

  wa_exec_no_error('create table sn_related (
    snr_from int,
    snr_to int,
    snr_since datetime,
    snr_weight int,
    snr_url varchar,
    snr_serial int,
    snr_source int,
    snr_confirmed int default 0,
    primary key (snr_from, snr_to, snr_serial))');

  wa_exec_no_error('create table sn_invitation (
    sni_id integer identity,
    sni_from int,
    sni_to varchar not null,    -- e-mail
    sni_ts timestamp,
    sni_status int,
    primary key (sni_from, sni_to))');


  -- Re-insert the old data
  wa_exec_no_error('insert into sn_person(sne_name, sne_source, sne_org_id) select sne_name, sne_source, sne_org_id from sn_person_old');
  wa_exec_no_error('insert into sn_group(sne_name, sne_source, sne_org_id) select sne_name, sne_source, sne_org_id from sn_group_old');
  wa_exec_no_error('insert into sn_alias(sna_alias, sna_entity) select sna_alias, sna_entity from sn_alias_old');
  wa_exec_no_error('insert into sn_member(snm_group, snm_entity) select snm_group, snm_entity from sn_member_old');
  wa_exec_no_error('insert into sn_related(snr_from, snr_to, snr_since, snr_weight, snr_url, snr_serial, snr_source, snr_confirmed) select snr_from, snr_to, snr_since, snr_weight, snr_url, snr_serial, snr_source, snr_confirmed from sn_related_old');
  wa_exec_no_error('insert into sn_invitation(sni_from, sni_to, sni_ts, sni_status) select sni_from, sni_to, sni_ts, sni_status from sn_invitation_old');


  -- drop the old tables
  wa_exec_no_error('drop table sn_invitation_old');
  wa_exec_no_error('drop table sn_related_old');
  wa_exec_no_error('drop table sn_member_old');
  wa_exec_no_error('drop table sn_alias_old');
  wa_exec_no_error('drop table sn_person_old');
  wa_exec_no_error('drop table sn_group_old');
  wa_exec_no_error('drop table sn_entity_old');

  registry_set ('__WA_SN_UNDER_TABLE_UPGRADE', 'done');
}
;

sn_update_person_and_group_tables ();


wa_exec_no_error('create index sn_related_from on sn_related (snr_from)');

wa_exec_no_error('create index sn_related_to on sn_related (snr_to)');

wa_exec_no_error('
create view SN_FRENDS as
select
  sne_from.sne_name as FROM_U_NAME,
  sne_to.sne_name as TO_U_NAME
from
  DB.DBA.sn_related, sn_entity sne_from, sn_entity sne_to
where
  snr_to = sne_to.sne_id
  and snr_from = sne_from.sne_id')
;

create procedure wa_sn_user_ent_set ()
{
  if (registry_get ('__wa_sn_user_ent_set_done') = 'done_2')
    return;
  for select U_NAME, U_ID from SYS_USERS where U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and U_NAME <> 'nobody' do
  {
    if (not exists (select 1 from sn_person where sne_name = U_NAME))
      insert soft sn_person (sne_name, sne_org_id) values (U_NAME, U_ID);
  }

  insert soft sn_source (sns_id, sns_name) values (1, 'ODS');
  update DB.DBA.sn_related set snr_source = 1;

  registry_set ('__wa_sn_user_ent_set_done', 'done_2');
};
wa_sn_user_ent_set ();

create procedure wa_sn_user_ent_set ()
{
  if (registry_get ('__wa_sn_user_ent_set_done2') = 'done_3')
    return;
  for (select sne_name as _sne_name from sn_person) do
  {
    if (not exists (select 1 from SYS_USERS where U_NAME = _sne_name))
      delete from sn_person where sne_name = _sne_name;
  }

  registry_set ('__wa_sn_user_ent_set_done2', 'done_3');
};
wa_sn_user_ent_set ();
