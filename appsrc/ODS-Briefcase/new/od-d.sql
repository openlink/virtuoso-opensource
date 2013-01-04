--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

ODRIVE.WA.exec_no_error('drop table ODRIVE.WA.GROUPS');
ODRIVE.WA.exec_no_error('drop table ODRIVE.WA.FOAF_GROUPS');
ODRIVE.WA.exec_no_error('drop table ODRIVE.WA.SETTINGS');

create procedure ODRIVE.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oDrive' do
  {
    (WAI_INST as DB.DBA.wa_oDrive).wa_drop_instance();
    commit work;
  }
}
;
ODRIVE.WA.uninstall ()
;

VHOST_REMOVE (lpath => '/briefcase');
VHOST_REMOVE (lpath => '/dataspace/services/briefcase');

ODRIVE.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'oDrive\'');
ODRIVE.WA.exec_no_error('DROP type wa_oDrive');

create procedure ODRIVE.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'ODRIVE.WA.%') do {
    if (P_NAME not in ('ODRIVE.WA.exec_no_error', 'ODRIVE.WA.drop_procedures'))
      ODRIVE.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for ODRIVE
ODRIVE.WA.drop_procedures();

ODRIVE.WA.exec_no_error('DROP procedure ODRIVE.WA.odrive_vhost');
ODRIVE.WA.exec_no_error('DROP procedure ODRIVE.WA.drop_procedures');

-- dropping SIOC procs and triggers
drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_I;
drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_U;
drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_D;
drop trigger WS.WS.SYS_DAV_PROP_BRIEFCASE_SIOC_I;
drop trigger WS.WS.SYS_DAV_PROP_BRIEFCASE_SIOC_U;
drop trigger WS.WS.SYS_DAV_PROP_BRIEFCASE_SIOC_D;

-- dropping SIOC procs
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.briefcase_links_to');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.briefcase_person_iri');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.briefcase_event_iri');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.briefcase_sparql');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_briefcase_sioc');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.ods_briefcase_sioc_tags');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.briefcase_sioc_insert');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.briefcase_sioc_insert_ex');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.briefcase_sioc_delete');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.ods_briefcase_sioc_init');

-- RDF Views - procs & views
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_briefcase_view_str');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_briefcase_view_str_tables');
ODRIVE.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_briefcase_view_str_maps');

ODRIVE.WA.exec_no_error ('DROP procedure DB.DBA.ODS_ODRIVE_TAGS');
ODRIVE.WA.exec_no_error ('DROP view DB.DBA.ODS_ODRIVE_POSTS');
ODRIVE.WA.exec_no_error ('DROP view DB.DBA.ODS_ODRIVE_TAGS');

-- reinit
ODS_RDF_VIEW_INIT ();

-- dropping ODS procs
ODRIVE.WA.exec_no_error('DROP procedure DB.DBA.wa_collect_odrive_tags');

-- final proc
ODRIVE.WA.exec_no_error('DROP procedure ODRIVE.WA.exec_no_error');

registry_remove ('_oDrive_path_');
registry_remove ('_oDrive_version_');
registry_remove ('_oDrive_build_');
registry_remove ('__ods_briefcase_sioc_init');
registry_remove ('odrive_items_upgrade');
registry_remove ('odrive_path_upgrade');
registry_remove ('odrive_path_upgrade2');
registry_remove ('odrive_services_update');
