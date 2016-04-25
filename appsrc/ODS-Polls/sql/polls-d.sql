--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

create procedure POLLS.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Polls' do
  {
    (WAI_INST as DB.DBA.wa_Polls).wa_drop_instance();
    commit work;
  }
}
;
POLLS.WA.uninstall ()
;

VHOST_REMOVE (lpath => '/polls');

-- NNTP
POLLS.WA.exec_no_error ('DROP procedure DB.DBA.POLLS_NEWS_MSG_I');
POLLS.WA.exec_no_error ('DROP procedure DB.DBA.POLLS_NEWS_MSG_U');
POLLS.WA.exec_no_error ('DROP procedure DB.DBA.POLLS_NEWS_MSG_D');
POLLS.WA.exec_no_error ('DB.DBA.NNTP_NEWS_MSG_DEL (\'POLLS\')');

-- Tables
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.ANSWER');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.VOTE');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.QUESTION');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.ANNOTATIONS');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.POLL_COMMENT');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.POLL');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.TAGS');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.SETTINGS');

-- Types
POLLS.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'Polls\'');
POLLS.WA.exec_no_error ('DROP type wa_polls');

-- Views
POLLS.WA.exec_no_error ('DROP view POLLS..TAGS_VIEW');

-- Registry
registry_remove ('_polls_path_');
registry_remove ('_polls_version_');
registry_remove ('_polls_build_');
registry_remove ('polls_settings_update');
registry_remove ('polls_index_version');
registry_remove ('polls_path_upgrade2');
registry_remove ('__ods_polls_sioc_init');
registry_remove ('polls_services_update');

-- Procedures
create procedure POLLS.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'POLLS.WA.%') do {
    if (P_NAME not in ('POLLS.WA.exec_no_error', 'POLLS.WA.drop_procedures'))
      POLLS.WA.exec_no_error (sprintf('DROP procedure %s', P_NAME));
  }
}
;

-- dropping procedures for Polls
POLLS.WA.drop_procedures();
POLLS.WA.exec_no_error('DROP procedure POLLS.WA.drop_procedures');

-- SIOC - dropping procs
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.poll_post_iri');
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.poll_comment_iri');
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.poll_tag_iri');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_polls_sioc');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.polls_insert');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.polls_delete');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.ods_polls_sioc_init');
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.polls_comment_insert');
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.polls_comment_delete');

-- RDF Views - procs & views
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_polls_view_str');
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_polls_view_str_tables');
POLLS.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_polls_view_str_maps');

POLLS.WA.exec_no_error ('DROP procedure DB.DBA.ODS_POLLS_TAGS');
POLLS.WA.exec_no_error ('DROP view DB.DBA.ODS_POLLS_POSTS');
POLLS.WA.exec_no_error ('DROP view DB.DBA.ODS_POLLS_TAGS');

-- reinit
ODS_RDF_VIEW_INIT ();

POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.get"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.new"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.edit"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.delete"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.question.new"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.question.delete"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.activate"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.close"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.clear"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.vote"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.vote.answer"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.result"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.comment.get"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.comment.new"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.comment.delete"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.options.set"');
POLLS.WA.exec_no_error ('DROP procedure ODS.ODS_API."poll.options.get"');

-- final proc
POLLS.WA.exec_no_error('DROP procedure POLLS.WA.exec_no_error');
