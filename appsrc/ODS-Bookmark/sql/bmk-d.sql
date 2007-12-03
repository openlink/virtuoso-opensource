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
-- bmk-d.sql
-- script for cleaning wa instalation.
-- Copyright (C) 2004 OpenLink Software
------------------------------------------------------------------------------

create procedure BMK.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Bookmark' do {
    (WAI_INST as DB.DBA.wa_bookmark).wa_drop_instance();
  }
}
;
BMK.WA.uninstall ()
;

VHOST_REMOVE (lpath => '/bookmark');
VHOST_REMOVE (lpath => '/dataspace/services/bookmark');

-- Scheduler
BMK.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'BM tags aggregator\'');

-- Triggers
BMK.WA.exec_no_error('DROP TDRIGGER WA_MEMBER_AU_BMK');

-- Tables
BMK.WA.exec_no_error('DROP VIEW  BMK.DBA.TAGS_STATISTICS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.SETTINGS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.TAGS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.GRANTS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.ANNOTATIONS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DATA');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DOMAIN');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.SFOLDER');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.FOLDER');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK');

-- Types
BMK.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'Bookmark\'');
BMK.WA.exec_no_error('drop type wa_bookmark');

-- Views
BMK.WA.exec_no_error('drop view BMK..TAGS_VIEW');

-- Registry
registry_remove ('_bookmark_path_');
registry_remove ('_bookmark_version_');
registry_remove ('_bookmark_build_');
registry_remove ('__ods_bookmark_sioc_init');

registry_remove ('bmk_table_update');
registry_remove ('bmk_index_version');
registry_remove ('bmk_path_update');

-- Procedures
create procedure BMK.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'BMK.WA.%') do {
    if (P_NAME not in ('BMK.WA.exec_no_error', 'BMK.WA.drop_procedures'))
      BMK.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for BMK
BMK.WA.drop_procedures();
BMK.WA.exec_no_error('DROP procedure BMK.WA.drop_procedures');

-- dropping SIOC procs
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_post_iri');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_links_to');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_bookmark_sioc');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_domain_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_domain_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_tags_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_tags_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.ods_bookmark_sioc_init');

-- dropping ODS procs
BMK.WA.exec_no_error('DROP procedure DB.DBA.wa_search_bmk_get_excerpt_html');
BMK.WA.exec_no_error('DROP procedure DB.DBA.wa_collect_bmk_tags');

-- dropping SIOC procs
BMK.WA.exec_no_error('DROP procedure DBA.DB.bookmarks_import');
BMK.WA.exec_no_error('DROP procedure DBA.DB.bookmarks_export');

-- final proc
BMK.WA.exec_no_error('DROP procedure BMK.WA.exec_no_error');
