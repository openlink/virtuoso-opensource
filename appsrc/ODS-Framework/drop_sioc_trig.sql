--
--  sioc.sql
--
--  $Id$
--
--  script to clean the old variant of the ODS RDF data support : triggers over the apps
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

use sioc;

ods_sioc_clean_all ();

db.dba.wa_exec_no_error ('drop trigger DB.DBA.NNFE_THR_REPLY_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.WA_SETTINGS');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.BLOG_COMMENTS_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.BLOG_COMMENTS_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.BLOG_COMMENTS_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.BLOG_TAG_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.BLOG_TAG_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.SYS_BLOGS_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.SYS_BLOGS_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger BLOG.DBA.SYS_BLOGS_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger BMK.WA.BOOKMARK_DATA_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger BMK.WA.BOOKMARK_DATA_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger BMK.WA.BOOKMARK_DATA_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger BMK.WA.BOOKMARK_DOMAIN_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger BMK.WA.BOOKMARK_DOMAIN_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger BMK.WA.BOOKMARK_DOMAIN_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.NEWS_GROUPS_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.NEWS_GROUPS_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.NEWS_MULTI_MSG_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.NEWS_MULTI_MSG_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.SYS_ROLE_GRANTS_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.SYS_ROLE_GRANTS_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.SYS_USERS_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.SYS_USERS_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.SYS_USERS_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.WA_INSTANCE_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.WA_MEMBER_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.WA_MEMBER_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.WA_USER_INFO_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.WA_USER_INFO_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.sn_related_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger DB.DBA.sn_related_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger ODS.COMMUNITY.COMMUNITY_MEMBER_APP_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger ODS.COMMUNITY.COMMUNITY_MEMBER_APP_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger OMAIL.WA.MESSAGES_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger OMAIL.WA.MESSAGES_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger OMAIL.WA.MESSAGES_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger PHOTO.WA.PHOTO_COMMENTS_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger PHOTO.WA.PHOTO_COMMENTS_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger PHOTO.WA.PHOTO_COMMENTS_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger WS.WS.SYS_DAV_RES_PHOTO_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger WS.WS.SYS_DAV_RES_PHOTO_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger WS.WS.SYS_DAV_RES_PHOTO_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger WV.Wiki.WV_COMMENT_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger WV.Wiki.WV_COMMENT_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEEDD_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEEDD_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_COMMENT_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_COMMENT_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_COMMENT_SIOC_U');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_DATA_SIOC_D');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_DATA_SIOC_I');
db.dba.wa_exec_no_error ('drop trigger eNews.WA.FEED_ITEM_DATA_SIOC_U');

use DB;
