--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
  {
    OMAIL.WA.nntp_update (WAI_ID, 1, 0);
}
}
;
OMAIL.WA.drop_nntp ()
;

create procedure OMAIL.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oMail' do
  {
    (WAI_INST as DB.DBA.wa_mail).wa_drop_instance();
    commit work;
  }
}
;
OMAIL.WA.uninstall ()
;

create procedure OMAIL.WA.uninstall ()
{
  for select DB.DBA.DAV_SEARCH_PATH (COL_ID, 'C') path from WS.WS.SYS_DAV_COL where COL_DET = 'oMail' do
  {
    DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
    commit work;
  }
}
;
OMAIL.WA.uninstall ()
;

-- Scheduler
OMAIL.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'WebMail External POP3 Scheduler\'');
OMAIL.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'WebMail External Scheduler\'');
OMAIL.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'WebMail Spam Clean Scheduler\'');

-- Tables
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MSG_PARTS_TDATA_WORDS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MESSAGES_ADDRESS_WORDS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MIME_HANDLERS');
OMAIL.WA.exec_no_error ('DROP TABLE OMAIL.WA.EXTERNAL_ACCOUNT');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.EXTERNAL_POP_ACC');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MSG_PARTS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.MESSAGES');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.FOLDERS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.SETTINGS');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.SHARES');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.CONVERSATION');
OMAIL.WA.exec_no_error ('DROP TABLE OMAIL.WA.FILTERS');

OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.RES_MIME_EXT');
OMAIL.WA.exec_no_error('DROP TABLE OMAIL.WA.RES_MIME_TYPES');

-- Paths
vhost_remove (lpath=>'/oMail');
vhost_remove (lpath=>'/oMail/i');
vhost_remove (lpath=>'/oMail/res');

-- Types
OMAIL.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'oMail\'');
OMAIL.WA.exec_no_error('drop type wa_mail');

-- Registry
registry_remove ('_oMail_path_');
registry_remove ('_oMail_version_');
registry_remove ('_oMail_build_');
registry_remove ('_oMail_spam_');
registry_remove ('omail_version_upgrade');
registry_remove ('omail_path_upgrade2');
registry_remove ('mail_index_version');
registry_remove ('__ods_mail_sioc_init');
registry_remove ('omail_services_update');

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

-- API procedures
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API.mail_folder_id');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API.mail_folder_new');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API.mail_setting_set');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API.mail_setting_xml');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.message.get"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.message.new"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.message.delete"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.message.move"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.folder.new"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.folder.delete"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.folder.rename"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.options.set"');
OMAIL.WA.exec_no_error ('DROP procedure ODS.ODS_API."mail.options.get"');

-- dropping DET procs
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_AUTHENTICATE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_NORM"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_GET_CONFIG"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_FNMERGE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_FNSPLIT"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_FIXNAME"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_COMPOSE_NAME"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_SEARCH_ID_IMPL"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_AUTHENTICATE_HTTP"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_GET_PARENT"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_COL_CREATE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_COL_MOUNT"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_COL_MOUNT_HERE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_DELETE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_RES_UPLOAD"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_PROP_REMOVE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_PROP_SET"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_PROP_GET"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_PROP_LIST"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_COLNAME_OF_FOLDER"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_RESNAME_OF_MAIL"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_DIR_SINGLE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_DIR_LIST"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_FC_PRED_METAS"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_FC_TABLE_METAS"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_FC_PRINT_WHERE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_DIR_FILTER"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_SEARCH_ID"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_SEARCH_PATH"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_RES_UPLOAD_COPY"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_RES_UPLOAD_MOVE"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_RES_CONTENT"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_SYMLINK"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_LOCK"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_UNLOCK"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_IS_LOCKED"');
OMAIL.WA.exec_no_error ('DROP procedure DB.DBA."oMail_DAV_LIST_LOCKS"');

-- final proc
OMAIL.WA.exec_no_error('DROP procedure OMAIL.WA.exec_no_error');
