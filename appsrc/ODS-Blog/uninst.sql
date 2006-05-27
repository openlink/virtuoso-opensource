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
--
USE "BLOG"
;

create procedure weblog2_uninst()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'WEBLOG2' do
  {
    (WAI_INST as DB.DBA.wa_blog2).wa_drop_instance();
  }
}
;
weblog2_uninst()
;
drop procedure weblog2_uninst
;
drop procedure BLOG2_HOME_GET_RDF
;
drop procedure BLOG2_HOME_GET_RSSCOMMENT
;
drop procedure BLOG2_HOME_GET_RSS
;
drop procedure BLOG2_HOME_GET_ATOM
;
drop procedure BLOG2_HOME_GET_OPML
;
drop procedure BLOG2_HOME_GET_FOAF
;
drop procedure BLOG2_COMMUNITY_GET_RSS
;
drop procedure BLOG2_COMMUNITY_GET_ATOM
;
drop procedure BLOG2_COMMUNITY_GET_OCS
;
drop procedure BLOG2_COMMUNITY_GET_OPML
;
drop procedure BLOG2_COMMUNITY_GET_FOAF
;
drop procedure BLOG2_GET_HOME_DIR
;
drop procedure BLOG2_MAKE_TITLE
;
drop procedure BLOG2_GET_TITLE
;
drop procedure BLOG2_GET_HOST
;
drop procedure BLOG2_GET_CURRENT_BLOG_HOME
;
drop procedure BLOG2_GET_CURRENT_BLOG_ID
;
DB.DBA.vhost_remove(lpath=>'/weblog')
;
DB.DBA.vhost_remove(lpath=>'/weblog/public')
;
DB.DBA.vhost_remove(lpath=>'/weblog/templates')
;
DB.DBA.vhost_remove(lpath=>'/weblog/gems/rss.xml')
;
DB.DBA.vhost_remove(lpath=>'/weblog/gems/index.rdf')
;
DB.DBA.vhost_remove(lpath=>'/weblog/gems/atom.xml')
;
DB.DBA.vhost_remove(lpath=>'/weblog/gems/index.ocs')
;
DB.DBA.vhost_remove(lpath=>'/weblog/gems/index.opml')
;
DB.DBA.vhost_remove(lpath=>'/weblog/gems/foaf.xml')
;
drop procedure BLOG2_CREATE_DEFAULT_SITE
;
drop procedure BLOG2_HOME_CREATE
;
DELETE FROM DB.DBA.WA_MEMBER      WHERE WAM_INST      IN (SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'WEBLOG2')
;
DELETE FROM DB.DBA.WA_INSTANCE    WHERE WAI_TYPE_NAME = 'WEBLOG2'
;
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP       = 'WEBLOG2'
;
drop type wa_blog2
;
DELETE FROM DB.DBA.WA_TYPES       WHERE WAT_NAME      = 'WEBLOG2'
;

use DB;

drop trigger SYS_USERS_BLOG_INFO_UP
;

-- NNTP
DROP procedure DB.DBA.BLOG_NEWS_MSG_I
;
DROP procedure DB.DBA.BLOG_NEWS_MSG_U
;
DROP procedure DB.DBA.BLOG_NEWS_MSG_D
;
DB.DBA.NNTP_NEWS_MSG_DEL ('BLOG');


