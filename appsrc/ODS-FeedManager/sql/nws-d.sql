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

-- dropping nntp procedure
create procedure ENEWS.WA.drop_nntp ()
{
  for (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'eNews2') do
    ENEWS.WA.nntp_update (WAI_ID, null, 1, 0);
}
;
ENEWS.WA.drop_nntp ()
;

create procedure ENEWS.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'eNews2' do {
    (WAI_INST as DB.DBA.wa_eNews2).wa_drop_instance();
  }
}
;
ENEWS.WA.uninstall ()
;

VHOST_REMOVE (lpath => '/enews2');

-- Scheduler
ENEWS.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'eNews feed aggregator\'');
ENEWS.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'eNews blog aggregator\'');
ENEWS.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'eNews tags aggregator\'');

-- Triggers
ENEWS.WA.exec_no_error('DROP TDRIGGER WA_MEMBER_AU_ENEWS');

-- Tables
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.SETTINGS');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_ITEM_DATA');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_DOMAIN');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.SFOLDER');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FOLDER');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_DIRECTORY');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.DIRECTORY');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.ANNOTATIONS');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_ITEM_ENCLOSURE');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_ITEM_LINK');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_ITEM_COMMENT');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_ITEM');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.TAGS');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.BLOG_POST_DATA');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.BLOG_POST');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.BLOG');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.WEBLOG');

-- Types
ENEWS.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'eNews2\'');
ENEWS.WA.exec_no_error('drop type wa_eNews2');

-- Views
ENEWS.WA.exec_no_error('drop view ENEWS..TAGS_VIEW');
ENEWS.WA.exec_no_error('drop view ENEWS..TAGS_STATISTICS');

-- Registry
registry_remove ('_enews2_path_');
registry_remove ('_enews2_version_');
registry_remove ('_enews2_build_');
registry_remove ('news_version_upgrade');
registry_remove ('news_table_version');
registry_remove ('news_index_version');
registry_remove ('news_links_upgrade');
registry_remove ('news_comment_upgrade');
registry_remove ('__ods_feeds_sioc_init');

-- Procedures
create procedure ENEWS.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'ENEWS.WA.%') do {
    if (P_NAME not in ('ENEWS.WA.exec_no_error', 'ENEWS.WA.drop_procedures'))
      ENEWS.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'DB.DBA.News_DAV_%') do {
    ENEWS.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
  ENEWS.WA.exec_no_error('drop procedure DB.DBA.News_FIXNAME');
  ENEWS.WA.exec_no_error('drop procedure DB.DBA.News_COMPOSE_NAME');
  ENEWS.WA.exec_no_error('drop procedure DB.DBA.News_ACCESS_PARAMS');
}
;

-- dropping procedures for ENEWS
ENEWS.WA.drop_procedures();

xpf_extension_remove ('http://www.openlinksw.com/feeds/:getHost', 'ENEWS.WA.host_url');

ENEWS.WA.exec_no_error('DROP procedure ENEWS.WA.vhost');
ENEWS.WA.exec_no_error('DROP procedure ENEWS.WA.drop_procedures');

-- NNTP
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.OFM_NEWS_MSG_I');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.OFM_NEWS_MSG_U');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.OFM_NEWS_MSG_D');
DB.DBA.NNTP_NEWS_MSG_DEL ('OFM');

-- dropping SIOC procs
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feed_mgr_iri');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feed_iri');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feed_item_iri');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feed_comment_iri');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feed_item_url');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.author_iri');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_foaf_maker');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feed_links_to');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_feeds_sioc');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_item_insert');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_item_delete');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_tags_insert');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_tags_delete');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_comment_insert');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.feeds_comment_delete');
ENEWS.WA.exec_no_error('DROP procedure SIOC.DBA.ods_feeds_sioc_init');

-- dropping ODS procs
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_ENEWS_GET_EXCERPT_HTML');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_ENEWS');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.WA_SEARCH_ADD_ENEWS_TAG');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.wa_collect_enews_tags');

-- final proc
ENEWS.WA.exec_no_error('DROP procedure ENEWS.WA.exec_no_error');
