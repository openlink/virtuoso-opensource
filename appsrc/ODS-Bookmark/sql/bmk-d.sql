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
------------------------------------------------------------------------------
-- bmk-d.sql
-- script for cleaning wa installation.
------------------------------------------------------------------------------

create procedure BMK.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Bookmark' do
  {
    (WAI_INST as DB.DBA.wa_bookmark).wa_drop_instance();
    commit work;
  }
}
;
BMK.WA.uninstall ()
;

create procedure BMK.WA.uninstall ()
{
  for select DB.DBA.DAV_SEARCH_PATH (COL_ID, 'C') path from WS.WS.SYS_DAV_COL where COL_DET = 'Bookmark' do
  {
    DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
    commit work;
  }
}
;
BMK.WA.uninstall ()
;
-- Scheduler
BMK.WA.exec_no_error ('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'Bookmark Exchange Scheduler\'');

VHOST_REMOVE (lpath => '/bookmark');
VHOST_REMOVE (lpath => '/dataspace/services/bookmark');

-- NNTP
BMK.WA.exec_no_error ('DROP procedure DB.DBA.BOOKMARKS_NEWS_MSG_I');
BMK.WA.exec_no_error ('DROP procedure DB.DBA.BOOKMARKS_NEWS_MSG_U');
BMK.WA.exec_no_error ('DROP procedure DB.DBA.BOOKMARKS_NEWS_MSG_D');
BMK.WA.exec_no_error ('DB.DBA.NNTP_NEWS_MSG_DEL (\'BOOKMARKS\')');

-- Scheduler
BMK.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'BM tags aggregator\'');

-- Triggers
BMK.WA.exec_no_error('DROP TRIGGER WA_MEMBER_AU_BMK');

-- Tables
BMK.WA.exec_no_error('DROP VIEW  BMK.DBA.TAGS_STATISTICS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.SETTINGS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.TAGS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.GRANTS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.ANNOTATIONS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_COMMENT');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DATA');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DOMAIN');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.SFOLDER');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.FOLDER');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.EXCHANGE');

-- Types
BMK.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'Bookmark\'');
BMK.WA.exec_no_error('drop type wa_bookmark');

-- Views
BMK.WA.exec_no_error('drop view BMK..TAGS_VIEW');
BMK.WA.exec_no_error('drop view BMK..GRANTS_VIEW');
BMK.WA.exec_no_error('drop view BMK..GRANTS_OBJECT_VIEW');

-- Registry
registry_remove ('_bookmark_path_');
registry_remove ('_bookmark_version_');
registry_remove ('_bookmark_build_');
registry_remove ('__ods_bookmark_sioc_init');

registry_remove ('bmk_table_update');
registry_remove ('bmk_index_version');
registry_remove ('bmk_path_update');
registry_remove ('bmk_path_upgrade2');
registry_remove ('bmk_services_update');

-- Procedures
create procedure BMK.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'BMK.WA.%') do
  {
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
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_comment_iri');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_annotation_iri');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_links_to');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_tag_iri');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_bookmark_sioc2');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.clean_ods_bookmark_sioc2');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_domain_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_domain_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_comments_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_comments_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_comment_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_comment_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_annotations_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bookmark_annotations_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_annotation_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_annotation_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_claims_insert');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.bmk_claims_delete');
BMK.WA.exec_no_error('DROP procedure SIOC.DBA.ods_bookmark_sioc_init');

-- RDF Views - procs & views
BMK.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_bookmark_view_str');
BMK.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_bookmark_view_str_tables');
BMK.WA.exec_no_error ('DROP procedure SIOC.DBA.rdf_bookmark_view_str_maps');

BMK.WA.exec_no_error ('DROP procedure DB.DBA.ODS_BMK_TAGS');
BMK.WA.exec_no_error ('DROP view DB.DBA.ODS_BMK_POSTS');
BMK.WA.exec_no_error ('DROP view DB.DBA.ODS_BMK_TAGS');

-- reinit
ODS_RDF_VIEW_INIT ();

-- dropping ODS procs
BMK.WA.exec_no_error('DROP procedure DB.DBA.wa_search_bmk_get_excerpt_html');
BMK.WA.exec_no_error('DROP procedure DB.DBA.wa_collect_bmk_tags');

-- dropping SIOC procs
BMK.WA.exec_no_error('DROP procedure DBA.DB.bookmarks_import');
BMK.WA.exec_no_error('DROP procedure DBA.DB.bookmarks_export');
BMK.WA.exec_no_error('DROP procedure DBA.DB.bookmarks_update');

-- dropping API procs
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.get"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.new"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.edit"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.delete"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.folder.new"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.folder.delete"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.import"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.export"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.comment.get"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.comment.new"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.comment.delete"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.publication.new"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.publication.edit"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.publication.delete"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.subscription.new"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.subscription.edit"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.subscription.delete"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.options.set"');
BMK.WA.exec_no_error('DROP procedure ODS.ODS_API."bookmark.options.get"');

-- dropping DET procs
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_FIXNAME"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_COMPOSE_XBEL_NAME"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_COMPOSE_FOLDERS_PATH"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_ACCESS_PARAMS"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_AUTHENTICATE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_AUTHENTICATE_HTTP"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_GET_PARENT"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_COL_CREATE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_COL_MOUNT"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_COL_MOUNT_HERE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_DELETE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_RES_UPLOAD"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_PROP_REMOVE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_PROP_SET"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_PROP_GET"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_PROP_LIST"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_DIR_SINGLE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_DIR_LIST"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_FC_PRED_METAS"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_FC_TABLE_METAS"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_FC_PRINT_WHERE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_DIR_FILTER"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_SEARCH_ID_IMPL"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_SEARCH_ID"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_SEARCH_PATH"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_RES_UPLOAD_COPY"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_RES_UPLOAD_MOVE"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_RES_CONTENT"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_SYMLINK"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_DEREFERENCE_LIST"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_RESOLVE_PATH"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_LOCK"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_UNLOCK"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_IS_LOCKED"');
BMK.WA.exec_no_error('DROP procedure DB.DBA."bookmark_DAV_LIST_LOCKS"');

-- final proc
BMK.WA.exec_no_error('DROP procedure BMK.WA.exec_no_error');
