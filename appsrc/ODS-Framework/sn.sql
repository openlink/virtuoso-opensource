--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

wa_exec_no_error('create table sn_entity (
    sne_id int identity,
    sne_name varchar unique,
    sne_source int references sn_source,
    sne_org_id any,
    primary key (sne_id))');

wa_exec_no_error ('create table sn_person (under sn_entity)');

wa_exec_no_error('create table sn_group (under sn_entity)');

wa_exec_no_error('create table sn_alias (
    sna_alias int,
    sna_entity varchar references sn_entity,
    primary key (sna_alias))');

wa_exec_no_error('create table sn_member (
    snm_group int references sn_entity,
    snm_entity int references sn_entity,
    primary key (snm_group, snm_entity))');


wa_exec_no_error('create table sn_related (
    snr_from int references sn_entity,
    snr_to int references sn_entity,
    snr_since datetime,
    snr_weight int,
    snr_url varchar,
    snr_serial int,
    snr_source int references sn_source,
    snr_confirmed int default 0,
    primary key (snr_from, snr_to, snr_serial))');

wa_exec_no_error('create index sn_related_from on sn_related (snr_from)');

wa_exec_no_error('create index sn_related_to on sn_related (snr_to)');

wa_exec_no_error('create table sn_invitation (
    sni_id integer identity,
    sni_from int references sn_entity,
    sni_to varchar not null,		-- e-mail
    sni_ts timestamp,
    sni_status int,
    primary key (sni_from, sni_to))');

wa_add_col('DB.DBA.sn_invitation', 'sni_id', 'integer identity');

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

  insert soft sn_source (sns_id,sns_name) values (1,'ODS');

  update DB.DBA.sn_related set snr_source=1;

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
