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

use DB;

DROP VIEW NNTPF_GROUP_LIST_V;
DROP VIEW NNTPF_SEARCH_RESULT_V;
DROP TABLE NNFE_THR;
DROP TABLE NNTPFE_USERRSSFEEDS;
DROP TABLE NNTPF_PING_REG;
DROP TABLE NNTPF_PING_LOG;
DROP TABLE NNTPF_NGROUP_POST_TAGS;
DROP TABLE NNTPF_TAG;

VHOST_REMOVE (lpath=>'/nntpf');


create procedure NNTPFE_DROP_ALL_PROC ()
{
  declare arr any;
  arr := vector ();
  for select P_NAME from DB.DBA.SYS_PROCEDURES where lower (P_NAME) like 'db.dba.nntpf_%' or (P_NAME) like 'db.dba.NNTPF_%'
	and P_NAME <> 'DB.DBA.NNTPFE_DROP_ALL_PROC'
        do
    {
      arr := vector_concat (arr, vector (P_NAME));
    }
  foreach (any elm in arr) do
    {
      DB.DBA.wa_exec_no_error('drop procedure "'||elm||'"');
    }
}
;

NNTPFE_DROP_ALL_PROC ()
;

registry_remove ('__nntpf_ver');

DB.DBA.wa_exec_no_error('drop procedure NEWS_MULTI_MSG_TO_NNFE_THR');
DB.DBA.wa_exec_no_error('drop procedure NNFE_FILL_THR_INIT');

drop trigger NEWS_MULTI_MSG_I_NNTPF;
drop trigger NEWS_MULTI_MSG_D_NNTPF;
drop trigger NEWS_MULTI_MSG_D_NGROUP_POST_TAGS;


DELETE FROM DB.DBA.WA_MEMBER      WHERE WAM_INST      IN (SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Discussion')
;
DELETE FROM DB.DBA.WA_INSTANCE    WHERE WAI_TYPE_NAME = 'Discussion'
;
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP       = 'Discussion'
;
drop type ODS.DISCUSSION.discussion
;
DELETE FROM DB.DBA.WA_TYPES       WHERE WAT_NAME      = 'Discussion'
;

DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.groups.get"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.group.get"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.group.new"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.group.remove"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.feed.new"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.feed.remove"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.message.new"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.message.get"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.comment.new"');
DB.DBA.wa_exec_no_error('drop procedure ODS.ODS_API."discussion.comment.get"');
