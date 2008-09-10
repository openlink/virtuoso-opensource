--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2007 OpenLink Software
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

create procedure AB.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'AddressBook' do
  {
    (WAI_INST as DB.DBA.wa_AddressBook).wa_drop_instance();
    commit work;
  }
}
;
AB.WA.uninstall ()
;

-- Triggers
AB.WA.exec_no_error ('drop trigger WS.WS.ADDRESSBOOK_SYS_DAV_RES_AI');
AB.WA.exec_no_error ('drop trigger WS.WS.ADDRESSBOOK_SYS_DAV_RES_AU');
AB.WA.exec_no_error ('drop trigger WS.WS.ADDRESSBOOK_SYS_DAV_RES_AD');

-- Scheduler
AB.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'AddressBook Exchange Scheduler\'');

VHOST_REMOVE (lpath => '/addressbook');
VHOST_REMOVE (lpath => '/dataspace/services/addressbook');

-- NNTP
DB.DBA.wa_exec_no_error('DROP procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_I');
DB.DBA.wa_exec_no_error('DROP procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_U');
DB.DBA.wa_exec_no_error('DROP procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_D');
DB.DBA.wa_exec_no_error('DB.DBA.NNTP_NEWS_MSG_DEL (\'ADDRESSBOOK\')');

-- Tables
AB.WA.exec_no_error('DROP TABLE AB.WA.GRANTS');
AB.WA.exec_no_error('DROP TABLE AB.WA.PERSON_COMMENTS');
AB.WA.exec_no_error('DROP TABLE AB.WA.ANNOTATIONS');
AB.WA.exec_no_error('DROP TABLE AB.WA.PERSONS');
AB.WA.exec_no_error('DROP TABLE AB.WA.CATEGORIES');
AB.WA.exec_no_error ('DROP TABLE AB.WA.EXCHANGE');
AB.WA.exec_no_error('DROP TABLE AB.WA.TAGS');
AB.WA.exec_no_error('DROP TABLE AB.WA.SETTINGS');

-- Types
AB.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'AddressBook\'');
AB.WA.exec_no_error('drop type wa_AddressBook');

-- Views
AB.WA.exec_no_error('drop view AB..TAGS_VIEW');

-- Registry
registry_remove ('ab_path');
registry_remove ('ab_version');
registry_remove ('ab_build');
registry_remove ('ab_index_version');
registry_remove ('__ods_addressbook_sioc_init');

-- Procedures
create procedure AB.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'AB.WA.%') do
  {
    if (P_NAME not in ('AB.WA.exec_no_error', 'AB.WA.drop_procedures'))
      AB.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for AddressBook
AB.WA.drop_procedures();
AB.WA.exec_no_error('DROP procedure AB.WA.drop_procedures');

-- dropping SIOC procs
AB.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_addressbook_sioc');
AB.WA.exec_no_error('DROP procedure SIOC.DBA.ods_addressbook_sioc_init');

-- dropping SIOC procs
AB.WA.exec_no_error('DROP procedure DBA.DB.addressbook_import');
AB.WA.exec_no_error('DROP procedure DBA.DB.addressbook_export');

-- dropping API procs
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.get"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.new"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.edit"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.delete"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.import"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.export"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.comment.get"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.comment.new"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.comment.delete"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.publication.new"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.publication.edit"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.publication.delete"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.subscription.new"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.ssubscription.edit"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.subscription.delete"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.options.set"');
AB.WA.exec_no_error ('DROP procedure ODS.ODS_API."addressbook.options.get"');

-- final proc
AB.WA.exec_no_error('DROP procedure AB.WA.exec_no_error');
