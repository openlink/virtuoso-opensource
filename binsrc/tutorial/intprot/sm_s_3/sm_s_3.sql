--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
create procedure 
"WS"."WS"."TT_NOTIFY_SYS_DAV_RES" () 
  { 
    declare stat, msg, ntf, comment varchar; 
    declare _u_id, _ts, _d_id, _t_id any; 
    declare cntf cursor for 
	select TTH_U_ID, TTH_TS, TTH_D_ID, TTH_T_ID, TTH_NOTIFY 
	    from  "WS"."WS"."SYS_DAV_RES_RES_CONTENT_HIT" where TTH_NOTIFY like '%@%'; 
    whenever not found goto err_exit; 
    open cntf (exclusive, prefetch 1);   
    while (1) 
      { 
	fetch cntf into _u_id, _ts, _d_id, _t_id, ntf; 
	whenever not found goto nfq; 
	select coalesce (TT_COMMENT, TT_QUERY) into comment 
	    from "WS"."WS"."SYS_DAV_RES_RES_CONTENT_QUERY" where TT_ID = _t_id; 
nfq: 
        if (comment is null) 
	  comment := '*** query not found ***'; 
        stat := '00000'; 
        ntf := concat ('<', ntf, '>'); 
        exec ('smtp_send (null,?,?,?)', stat, msg,  
	  vector (ntf, ntf, concat ('Subject: New ', 'hit on "', comment, 
	     '" registered text trigger notification'))); 
        update "WS"."WS"."SYS_DAV_RES_RES_CONTENT_HIT" set TTH_NOTIFY = '' where CURRENT OF cntf; 
      } 
err_exit:   
  close cntf; 
  return; 
};
