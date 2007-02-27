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
use sioc;

create procedure poll_post_iri (in domain_id varchar, in poll_id int)
{
  declare _member, _inst varchar;
  declare exit handler for not found { return null; };

  select U_NAME, WAI_NAME into _member, _inst
    from DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER
   where WAI_ID = domain_id and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID;

  return sprintf ('http://%s%s/%U/polls/%U/%d', get_cname(), get_base_path (), _member, _inst, poll_id);
}
;

create procedure fill_ods_polls_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare polls_id integer;
  declare iri, c_iri, creator_iri, t_iri varchar;
  declare tags any;

  for (select WAI_NAME, WAM_USER, P_DOMAIN_ID, P_ID, P_NAME, P_DESCRIPTION, P_UPDATED, P_CREATED, P_TAGS, POLLS.WA.poll_url (P_DOMAIN_ID, P_ID) P_URI
         from DB.DBA.WA_INSTANCE,
              POLLS.WA.POLL,
              DB.DBA.WA_MEMBER
        where P_DOMAIN_ID = WAI_ID
          and WAM_INST = WAI_NAME
          and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAI_NAME = _wai_name)) do
  {
    c_iri := polls_iri (WAI_NAME);
    iri := poll_post_iri (P_DOMAIN_ID, P_ID);
    creator_iri := user_iri (WAM_USER);

    -- maker
    for (select coalesce(U_FULL_NAME, U_NAME) full_name, U_E_MAIL e_mail from DB.DBA.SYS_USERS where U_ID = WAM_USER) do
      foaf_maker (graph_iri, person_iri (creator_iri), full_name, e_mail);

    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, P_NAME, P_CREATED, P_UPDATED, P_URI, P_DESCRIPTION);
    ods_sioc_tags (graph_iri, iri, P_TAGS);
  }
}
;

create procedure polls_insert (
  inout poll_id integer,
  inout domain_id integer,
  inout name varchar,
  inout created datetime,
  inout updated datetime,
  inout description varchar,
  inout tags varchar)
{
  declare graph_iri, iri, c_iri, creator_iri varchar;
  declare linksTo any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := poll_post_iri (domain_id, poll_id);
  for (select WAM_USER, WAI_NAME
         from DB.DBA.WA_INSTANCE,
              DB.DBA.WA_MEMBER
        where WAI_ID = domain_id
          and WAM_INST = WAI_NAME
          and WAI_IS_PUBLIC = 1) do
  {
    c_iri := polls_iri (WAI_NAME);
    creator_iri := user_iri (WAM_USER);

    -- maker
    for (select coalesce(U_FULL_NAME, U_NAME) full_name, U_E_MAIL e_mail from DB.DBA.SYS_USERS where U_ID = WAM_USER) do
      foaf_maker (graph_iri, person_iri (creator_iri), full_name, e_mail);

    ods_sioc_post (graph_iri, iri, c_iri, creator_iri, name, created, updated, POLLS.WA.poll_url (domain_id, poll_id), description);
    ods_sioc_tags (graph_iri, iri, tags);
  }
  return;
}
;

create procedure polls_delete (
  inout poll_id integer,
  inout domain_id integer)
{
  declare graph_iri, iri varchar;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  graph_iri := get_graph ();
  iri := poll_post_iri (domain_id, poll_id);
  delete_quad_s_or_o (graph_iri, iri, iri);
}
;

create trigger POLLS_SIOC_I after insert on POLLS.WA.POLL referencing new as N
{
  polls_insert (N.P_ID, N.P_DOMAIN_ID, N.P_NAME, N.P_CREATED, N.P_UPDATED, N.P_DESCRIPTION, N.P_TAGS);
}
;

create trigger POLLS_SIOC_U after update on POLLS.WA.POLL referencing old as O, new as N
{
  polls_delete (O.P_ID, O.P_DOMAIN_ID);
  polls_insert (N.P_ID, N.P_DOMAIN_ID, N.P_NAME, N.P_CREATED, N.P_UPDATED, N.P_DESCRIPTION, N.P_TAGS);
}
;

create trigger POLLS_SIOC_D before delete on POLLS.WA.POLL referencing old as O
{
  polls_delete (O.P_ID, O.P_DOMAIN_ID);
}
;

create procedure ods_polls_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_polls_sioc_init') = sioc_version)
    return;
  fill_ods_polls_sioc (get_graph (), get_graph ());
  registry_set ('__ods_polls_sioc_init', sioc_version);
  return;
}
;

--POLLS.WA.exec_no_error('ods_polls_sioc_init ()');

use DB;
