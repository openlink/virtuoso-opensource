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
-- nws-d.sql
-- script for cleaning wa instalation.
------------------------------------------------------------------------------

-- Scheduler
ENEWS.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'eNews feed aggregator\'');
ENEWS.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'eNews blog aggregator\'');

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
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED_ITEM');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.FEED');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.BLOG_POST_DATA');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.BLOG_POST');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.BLOG');
ENEWS.WA.exec_no_error('DROP TABLE ENEWS.WA.WEBLOG');

-- Types
ENEWS.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'eNews2\'');
ENEWS.WA.exec_no_error('drop type wa_eNews2');

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
ENEWS.WA.exec_no_error('DROP procedure ENEWS.WA.vhost');
ENEWS.WA.exec_no_error('DROP procedure ENEWS.WA.drop_procedures');

-- NNTP
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.OFM_NEWS_MSG_I');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.OFM_NEWS_MSG_U');
ENEWS.WA.exec_no_error('DROP procedure DB.DBA.OFM_NEWS_MSG_D');
DB.DBA.NNTP_NEWS_MSG_DEL ('OFM');

ENEWS.WA.exec_no_error('DROP procedure ENEWS.WA.exec_no_error');

