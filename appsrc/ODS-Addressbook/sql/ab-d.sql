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
AB.WA.exec_no_error ('DROP trigger WS.WS.ADDRESSBOOK_SYS_DAV_RES_AI');
AB.WA.exec_no_error ('DROP trigger WS.WS.ADDRESSBOOK_SYS_DAV_RES_AU');
AB.WA.exec_no_error ('DROP trigger WS.WS.ADDRESSBOOK_SYS_DAV_RES_AD');

-- Scheduler
AB.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'AddressBook Exchange Scheduler\'');

VHOST_REMOVE (lpath => '/addressbook');
VHOST_REMOVE (lpath => '/dataspace/services/addressbook');
VHOST_REMOVE (lpath => '/ods/portablecontacts');
VHOST_REMOVE (lpath => '/ods/livecontacts');
VHOST_REMOVE (lpath => '/ods/yahoocontacts');
VHOST_REMOVE (lpath => '/ods/google');


-- NNTP
AB.WA.exec_no_error ('DROP procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_I');
AB.WA.exec_no_error ('DROP procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_U');
AB.WA.exec_no_error ('DROP procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_D');
AB.WA.exec_no_error ('DB.DBA.NNTP_NEWS_MSG_DEL (\'ADDRESSBOOK\')');

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
AB.WA.exec_no_error ('DROP type wa_AddressBook');

-- Views
AB.WA.exec_no_error ('DROP view AB.DBA.TAGS_VIEW');
AB.WA.exec_no_error ('DROP view AB.DBA.GRANTS_PERSON_VIEW');
AB.WA.exec_no_error ('DROP view AB.DBA.GRANTS_VIEW');

-- Registry
registry_remove ('ab_path');
registry_remove ('ab_version');
registry_remove ('ab_build');
registry_remove ('ab_index_version');
registry_remove ('ab_path_upgrade2');
registry_remove ('ab_acl_update');
registry_remove ('__ods_addressbook_sioc_init');
registry_remove ('ab_services_update');

-- Procedures
create procedure AB.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'AB.WA.%') do
  {
    if (P_NAME not in ('AB.WA.exec_no_error', 'AB.WA.drop_procedures'))
      AB.WA.exec_no_error (sprintf('DROP procedure %s', P_NAME));
  }
}
;

-- dropping procedures for AddressBook
AB.WA.drop_procedures();
AB.WA.exec_no_error('DROP procedure AB.WA.drop_procedures');

-- dropping SIOC procs
AB.WA.exec_no_error ('DROP procedure SIOC.DB.addressbook_contact_iri');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.addressbook_comment_iri');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.addressbook_annotation_iri');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.socialnetwork_contact_iri');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.addressbook_tag_iri');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.fill_ods_addressbook_sioc2');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.clean_ods_addressbook_sioc2');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_insert');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_delete');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_comments_insert');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_comments_delete');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_comment_insert');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_comment_delete');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_annotations_insert');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_annotations_delete');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_annotation_insert');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.contact_annotation_delete');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.addressbook_claims_insert');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.addressbook_claims_delete');
AB.WA.exec_no_error ('DROP procedure SIOC.DB.ods_addressbook_sioc_init');

-- RDF Views - procs & views
AB.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_addressbook_view_str');
AB.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_addressbook_view_str_tables');
AB.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_addressbook_view_str_maps');

AB.WA.exec_no_error ('DROP procedure DB.DBA.ODS_ADDRESSBOOK_TAGS');
AB.WA.exec_no_error ('DROP view DB.DBA.ODS_ADDRESSBOOK_CONTACTS');
AB.WA.exec_no_error ('DROP view DB.DBA.ODS_ADDRESSBOOK_TAGS');

-- reinit
ODS_RDF_VIEW_INIT ();

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
