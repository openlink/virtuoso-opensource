--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
CREATE USER VS_U_7
;

USER_SET_QUALIFIER ('VS_U_7', 'WS')
;

GRANT INSERT, UPDATE, DELETE, SELECT ON WS.WS.SESSION TO VS_U_7
;

VHOST_REMOVE (lpath=>'/vs_u_7')
;

VHOST_DEFINE (lpath=>'/vs_u_7', ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/web/vs_u_7/', is_brws=>1,
              auth_fn=>'WS.VS_U_7.SIMPLE_SES_RESTORE', ppr_fn=>'WS.WS.SESSION_SAVE',
	      is_dav=>TUTORIAL_IS_DAV(),
	      vsp_user=>'VS_U_7', ses_vars=>1)
;

CREATE PROCEDURE WS.VS_U_7.SIMPLE_SES_RESTORE (in realm varchar)
{
  declare sid varchar;
  declare vars any;
  sid := http_param ('sid');
  if (not isstring (sid) or not exists (select 1 from WS.WS.SESSION where S_ID = sid))
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into WS.WS.SESSION (S_REALM, S_ID, S_EXPIRE)
	 values (http_path (), sid, dateadd ('minute', 10, now ()));
      connection_set ('sid', sid);
    }
  else
    {
      update WS.WS.SESSION set S_EXPIRE =  dateadd ('minute', 10, now ()) where S_ID = sid;
      vars := coalesce ((select deserialize (S_VARS) from WS.WS.SESSION where S_ID = sid), NULL);
      connection_vars_set (vars);
    }
  return 1;
}
;

grant select on Demo.demo.Employees to VS_U_7
;

grant select on Demo.demo.Products to VS_U_7
;

grant select on Demo.demo.Customers to VS_U_7
;

grant select on Demo.demo.Orders to VS_U_7
;

grant select on Demo.demo.Order_Details to VS_U_7
;


