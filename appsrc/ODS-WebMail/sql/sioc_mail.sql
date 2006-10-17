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

create procedure mail_post_iri (in domain_id int, in user_id int, in msg_id int)
{
  declare owner varchar;
  declare exit handler for not found { return null; };
  select U_NAME into owner from DB.DBA.SYS_USERS where U_ID = user_id;
  return sprintf ('http://%s%s/%U/mail/%d', get_cname(), get_base_path (), owner, msg_id);
};

create procedure fill_ods_mail_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  declare iri, c_iri varchar;
  declare do_post int;

  for select DOMAIN_ID, USER_ID, MSG_ID, SUBJECT, SND_DATE, UNIQ_MSG_ID from OMAIL..MESSAGES do
    {
      do_post := 1;
      for select WAM_INST
           from DB.DBA.WA_MEMBER
          where WAM_USER = USER_ID and WAM_MEMBER_TYPE = 1 and  WAM_APP_TYPE = 'oMail'
	  and ((WAM_IS_PUBLIC = 1 and _wai_name is null) or WAM_INST = _wai_name)
	do
	  {
          if (do_post = 1)
            {
              iri := mail_post_iri (DOMAIN_ID, USER_ID, MSG_ID);
              DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), sioc_iri ('Post'));
              DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('title'), SUBJECT);
              DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dcterms_iri ('created'), DB.DBA.date_iso8601 (SND_DATE));
              do_post := 0;
            }
	    c_iri := mail_iri (WAM_INST);
          DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), c_iri);
          DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, sioc_iri ('container_of'), iri);
	  }
    }
};

-- OMAIL..MESSAGES
create trigger MESSAGES_SIOC_I after insert on OMAIL..MESSAGES referencing new as N
{
  declare iri, c_iri varchar;
  declare graph_iri varchar;
  declare do_post int;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := mail_post_iri (N.DOMAIN_ID, N.USER_ID, N.MSG_ID);

  do_post := 1;
  for select WAM_INST from DB.DBA.WA_MEMBER where WAM_USER = N.USER_ID and WAM_MEMBER_TYPE = 1 and  WAM_APP_TYPE = 'oMail' and WAM_IS_PUBLIC = 1 do
    {
      if (do_post = 1)
    {
          ods_sioc_post (graph_iri, iri, null, null, N.SUBJECT, N.SND_DATE, null);
          do_post := 0;
        }
      c_iri := mail_iri (WAM_INST);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), c_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, sioc_iri ('container_of'), iri);
    }
  return;
};

create trigger MESSAGES_SIOC_D before delete on OMAIL..MESSAGES referencing old as O
{
  declare iri, c_iri varchar;
  declare graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := mail_post_iri (O.DOMAIN_ID, O.USER_ID, O.MSG_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

create trigger MESSAGES_SIOC_U after update on OMAIL..MESSAGES referencing old as O, new as N
{
  declare iri, c_iri varchar;
  declare graph_iri varchar;
  declare do_post int;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := mail_post_iri (N.DOMAIN_ID, N.USER_ID, N.MSG_ID);

  delete_quad_s_or_o (graph_iri, iri, iri);

  do_post := 1;
  for select WAM_INST from DB.DBA.WA_MEMBER where WAM_USER = N.USER_ID and WAM_MEMBER_TYPE = 1 and  WAM_APP_TYPE = 'oMail' and WAM_IS_PUBLIC = 1 do
    {
      if (do_post = 1)
        {
  ods_sioc_post (graph_iri, iri, null, null, N.SUBJECT, N.SND_DATE, null);
          do_post := 0;
        }
      c_iri := mail_iri (WAM_INST);
      DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), c_iri);
      DB.DBA.RDF_QUAD_URI (graph_iri, c_iri, sioc_iri ('container_of'), iri);
    }
  return;
};

create procedure ods_mail_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_mail_sioc_init') = sioc_version)
    return;
  fill_ods_mail_sioc (get_graph (), get_graph ());
  registry_set ('__ods_mail_sioc_init', sioc_version);
  return;
};

OMAIL.WA.exec_no_error ('ods_mail_sioc_init ()');

use DB;
