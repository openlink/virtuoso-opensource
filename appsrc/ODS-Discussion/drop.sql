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

use DB;

DROP VIEW NNTPF_GROUP_LIST_V;
DROP VIEW NNTPF_SEARCH_RESULT_V;
DROP TABLE NNFE_THR;
DROP TABLE NNTPFE_USERRSSFEEDS;
VHOST_REMOVE (lpath=>'/nntpf');

create procedure NNTPFE_DROP_ALL_PROC ()
{
  declare arr any;
  arr := vector ();
  for select P_NAME from DB.DBA.SYS_PROCEDURES where lower (P_NAME) like 'db.dba.nntpf_%'
	and P_NAME <> 'DB.DBA.NNTPFE_DROP_ALL_PROC'
        do
    {
      arr := vector_concat (arr, vector (P_NAME));
    }
  foreach (any elm in arr) do
    {
      DB.DBA.EXEC_STMT ('drop procedure "'||elm||'"', 0);
    }
}
;

NNTPFE_DROP_ALL_PROC ()
;

registry_remove ('__nntpf_ver');

drop procedure NNTPFE_DROP_ALL_PROC;
drop procedure NEWS_MULTI_MSG_TO_NNFE_THR;
drop procedure NNFE_FILL_THR_INIT;

drop trigger NEWS_MULTI_MSG_I_NNTPF;
drop trigger NEWS_MULTI_MSG_D_NNTPF;

