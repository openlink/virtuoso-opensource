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
--  
CREATE USER VS_D_8
;

USER_SET_QUALIFIER ('VS_D_8', 'WS')
;

SET USER GROUP VS_D_8 DBA
;

DROP TABLE WS.VS_D_8.APP_USER
;

CREATE TABLE WS.VS_D_8.APP_USER (AP_ID VARCHAR PRIMARY KEY, AP_PWD VARCHAR)
;

VHOST_REMOVE (lpath=>'/vs_d_8')
;

VHOST_DEFINE (lpath=>'/vs_d_8', ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/web/vs_d_8/', def_page=>'front.vsp',
              auth_fn=>'WS.VS_D_8.URL_SES_RESTORE', ppr_fn=>'WS.WS.SESSION_SAVE',
	      is_dav=>TUTORIAL_IS_DAV(),
	      vsp_user=>'VS_D_8', ses_vars=>1)
;

CREATE PROCEDURE WS.VS_D_8.URL_SES_RESTORE (in realm varchar)
{
  declare sid varchar;
  declare vars any;
  sid := http_param ('sid');
  if ('1' = http_param ('logoff'))
    delete from WS.WS.SESSION where S_ID = sid;
  if (http_path () like '%/front.vsp' or http_path () like '%/' or http_path () like '%/register.vsp'
      or http_path () like '%/login.vsp')
    return 1;
  if (not isstring (sid) or not exists (select 1 from WS.WS.SESSION where S_ID = sid))
    {
      http_request_status ('HTTP/1.1 302 Found');
      http_header (sprintf ('Location: %s\r\n', 'login.vsp'));
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

create procedure WS.VS_D_8.URL_SES_START (in params any, in url varchar)
{
  declare sid varchar;
  connection_set ('uid', get_keyword ('uid', params));
  connection_set ('pwd', get_keyword ('pwd', params));
  http_request_status ('HTTP/1.1 302 Found');
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into WS.WS.SESSION (S_REALM, S_ID, S_EXPIRE)
             values (http_path (), sid, dateadd ('minute', 10, now ()));
  connection_set ('sid', sid);
  http_header (sprintf ('Location: %s?sid=%s\r\n', url, sid));
}
;

