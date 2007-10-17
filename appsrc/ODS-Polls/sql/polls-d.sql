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

create procedure POLLS.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Polls' do {
    (WAI_INST as DB.DBA.wa_Polls).wa_drop_instance();
  }
}
;
POLLS.WA.uninstall ()
;

VHOST_REMOVE (lpath => '/polls');

-- Tables
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.ANSWER');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.VOTE');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.QUESTION');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.ANNOTATIONS');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.POLL');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.TAGS');
POLLS.WA.exec_no_error('DROP TABLE POLLS.WA.SETTINGS');

-- Types
POLLS.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'Polls\'');
POLLS.WA.exec_no_error('drop type wa_polls');

-- Views
POLLS.WA.exec_no_error('drop view POLLS..TAGS_VIEW');

-- Procedures
create procedure POLLS.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'POLLS.WA.%') do {
    if (P_NAME not in ('POLLS.WA.exec_no_error', 'POLLS.WA.drop_procedures'))
      POLLS.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for Polls
POLLS.WA.drop_procedures();
POLLS.WA.exec_no_error('DROP procedure POLLS.WA.drop_procedures');

-- dropping SIOC procs
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.poll_post_iri');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_polls_sioc');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.polls_insert');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.polls_delete');
POLLS.WA.exec_no_error('DROP procedure SIOC.DBA.ods_polls_sioc_init');

-- final proc
POLLS.WA.exec_no_error('DROP procedure POLLS.WA.exec_no_error');
