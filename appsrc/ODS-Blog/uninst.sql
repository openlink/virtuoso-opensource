--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

USE "BLOG"
;

create procedure BLOG.DBA.weblog2_uninst()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'WEBLOG2' do
  {
    (WAI_INST as DB.DBA.wa_blog2).wa_drop_instance();
  }
}
;
BLOG.DBA.weblog2_uninst()
;
DB.DBA.wa_exec_no_error('DROP procedure BLOG.DBA.weblog2_uninst');

-- Procedures
create procedure BLOG.DBA._drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'BLOG.%' or P_NAME like 'DB.DBA.BLOG%' or P_NAME like 'DB.DBA.Blog%') do {
    if (P_NAME not in ( 'BLOG.DBA._drop_procedures'))
        DB.DBA.wa_exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for BLOG
BLOG.DBA._drop_procedures();

DB.DBA.wa_exec_no_error('DROP procedure BLOG.DBA._drop_procedures');




--drop procedure BLOG2_HOME_GET_RDF
--;
--drop procedure BLOG2_HOME_GET_RSSCOMMENT
--;
--drop procedure BLOG2_HOME_GET_RSS
--;
--drop procedure BLOG2_HOME_GET_ATOM
--;
--drop procedure BLOG2_HOME_GET_OPML
--;
--drop procedure BLOG2_HOME_GET_FOAF
--;
--drop procedure BLOG2_COMMUNITY_GET_RSS
--;
--drop procedure BLOG2_COMMUNITY_GET_ATOM
--;
--drop procedure BLOG2_COMMUNITY_GET_OCS
--;
--drop procedure BLOG2_COMMUNITY_GET_OPML
--;
--drop procedure BLOG2_COMMUNITY_GET_FOAF
--;
--drop procedure BLOG2_GET_HOME_DIR
--;
--drop procedure BLOG2_MAKE_TITLE
--;
--drop procedure BLOG2_GET_TITLE
--;
--drop procedure BLOG2_GET_HOST
--;
--drop procedure BLOG2_GET_CURRENT_BLOG_HOME
--;
--drop procedure BLOG2_GET_CURRENT_BLOG_ID
--;
--drop procedure BLOG2_CREATE_DEFAULT_SITE
--;
--drop procedure BLOG2_HOME_CREATE
--;

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

use DB;

DELETE FROM DB.DBA.WA_MEMBER      WHERE WAM_INST      IN (SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'WEBLOG2')
;
DELETE FROM DB.DBA.WA_INSTANCE    WHERE WAI_TYPE_NAME = 'WEBLOG2'
;
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP       = 'WEBLOG2'
;
drop type DB.DBA.wa_blog2
;
DELETE FROM DB.DBA.WA_TYPES       WHERE WAT_NAME      = 'WEBLOG2'
;

drop trigger SYS_USERS_BLOG_INFO_UP
;
drop trigger BI_WAI_MEMBER_MODEL_UPD
;

-- NNTP
DB.DBA.wa_exec_no_error('DROP procedure DB.DBA.BLOG_NEWS_MSG_I')
;
DB.DBA.wa_exec_no_error('DROP procedure DB.DBA.BLOG_NEWS_MSG_U')
;
DB.DBA.wa_exec_no_error('DROP procedure DB.DBA.BLOG_NEWS_MSG_D')
;
DB.DBA.wa_exec_no_error('DB.DBA.NNTP_NEWS_MSG_DEL (''BLOG'')')
;
DB.DBA.wa_exec_no_error('delete from DB.DBA.news_groups where NG_TYPE=''BLOG''')
;

-- API procedures
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.post.new"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.post.edit"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.post.delete"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.post.get"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.comment.get"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.comment.approve"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.comment.delete"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.comment.new"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.get"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.options.set"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.options.get"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.upstreaming.set"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.upstreaming.get"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.upstreaming.remove"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.tagging.set"')
;
DB.DBA.wa_exec_no_error('DROP procedure ODS.ODS_API."weblog.tagging.retag"')
;
