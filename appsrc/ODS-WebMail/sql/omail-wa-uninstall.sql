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
------------------------------------------------------------------------------

-- dropping nntp procedure
create procedure OMAIL.WA.drop_nntp ()
{
  for (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oMail') do
    OMAIL.WA.nntp_update (WAI_ID, 1, 0);
}
;
OMAIL.WA.drop_nntp ()
;

create procedure OMAIL.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oMail' do
  {
    (WAI_INST as DB.DBA.wa_mail).wa_drop_instance();
  }
}
;
OMAIL.WA.uninstall ()
;

-- Scheduler
OMAIL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'WebMail External POP3 Scheduler\'');

-- Tables
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MSG_PARTS_TDATA_WORDS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MESSAGES_ADDRESS_WORDS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MIME_HANDLERS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.EXTERNAL_POP_ACC');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MSG_PARTS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MESSAGES');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.FOLDERS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.SETTINGS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.SHARES');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.CONVERSATION');

OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.RES_MIME_EXT');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.RES_MIME_TYPES');

-- Paths
vhost_remove (lpath=>'/oMail');
vhost_remove (lpath=>'/oMail/i');
vhost_remove (lpath=>'/oMail/res');

-- Types
OMAIL.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'oMail\'');
OMAIL.WA.exec_no_error('drop type wa_mail');

-- Procedures
create procedure OMAIL.WA.omail_drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'OMAIL.WA.%') do
  {
    if (P_NAME not in ('OMAIL.WA.exec_no_error', 'OMAIL.WA.omail_drop_procedures'))
      OMAIL.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

xpf_extension_remove ('http://www.openlinksw.com/mail/:getODSBar', 'OMAIL.WA.GET_ODS_BAR');
xpf_extension_remove ('http://www.openlinksw.com/mail/:getCopyright', 'OMAIL.WA.get_copyright');

-- dropping procedures for OMAIL
OMAIL.WA.omail_drop_procedures();
OMAIL.WA.exec_no_error('DROP procedure OMAIL.WA.omail_drop_procedures');

-- NNTP
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.MAIL_NEWS_MSG_I');
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.MAIL_NEWS_MSG_U');
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.MAIL_NEWS_MSG_D');
DB.DBA.NNTP_NEWS_MSG_DEL ('MAIL');

-- ODS search procedures
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_OMAIL_GET_EXCERPT_HTML');
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_OMAIL_AGG_init');
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_OMAIL_AGG_acc');
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_OMAIL_AGG_final');
OMAIL.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_OMAIL');

-- final proc
OMAIL.WA.exec_no_error('DROP procedure OMAIL.WA.exec_no_error');

