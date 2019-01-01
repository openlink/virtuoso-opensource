--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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
CREATE USER VS_U_3
;

USER_SET_QUALIFIER ('VS_U_3', 'WS')
;

DROP TABLE WS.VS_U_3.APP_USER
;

CREATE TABLE WS.VS_U_3.APP_USER (AP_ID VARCHAR PRIMARY KEY, AP_PWD VARCHAR)
;

GRANT INSERT, UPDATE, DELETE, SELECT ON WS.WS.SESSION TO VS_U_3
;

GRANT INSERT, UPDATE, DELETE, SELECT ON WS.VS_U_3.APP_USER TO VS_U_3
;

VHOST_REMOVE (lpath=>'/vs_u_3')
;

VHOST_DEFINE (lpath=>'/vs_u_3', ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/web/vs_u_3/', def_page=>'front.vsp',
              auth_fn=>'WS.VS_U_3.COOKIE_SES_RESTORE', ppr_fn=>'WS.WS.SESSION_SAVE',
	      vsp_user=>'VS_U_3', ses_vars=>1, is_dav=>TUTORIAL_IS_DAV())
;

CREATE PROCEDURE WS.VS_U_3.COOKIE_SES_RESTORE (in realm varchar)
{
  declare sid varchar;
  declare cookie, cookie_vec any;
  declare vars any;
  declare i, l int;
  cookie := http_request_header (http_request_header (), 'Cookie', null, '');
  if (cookie <> '')
    {
      cookie_vec := split_and_decode (cookie, 0, '\0\0;=');
      i := 0; l := length (cookie_vec);
      while (i < l)
        {
	  declare kw, val varchar;
          kw := trim (cookie_vec[i]);
          if (val is not null)
            val := trim (cookie_vec[i+1]);
	  else
	    val := null;
	  aset (cookie_vec, i, kw);
	  aset (cookie_vec, i+1, val);
          i := i + 2;
	}
      sid := get_keyword ('sid', cookie_vec, '');
    }
  if ('1' = http_param ('logoff'))
    delete from WS.WS.SESSION where S_ID = sid;
  if (http_path () like '%/front.vsp' or http_path () like '%/' or http_path () like '%/register.vsp' or http_path () like '%/login.vsp')
	  return 1;
  if (not isstring (sid) or not exists (select 1 from WS.WS.SESSION where S_ID = sid))
    {
      http_request_status ('HTTP/1.1 302 Found');
      http_header (sprintf ('Location: %s\r\n', 'login.vsp'));
      return 0;
    }
  else
    {
      update WS.WS.SESSION set S_EXPIRE =  dateadd ('minute', 10, now ()) where S_ID = sid;
      vars := coalesce ((select deserialize (S_VARS) from WS.WS.SESSION where S_ID = sid), NULL);
      connection_vars_set (vars);
      return 1;
    }
  return 0;
}
;

create procedure WS.VS_U_3.COOKIE_SES_START (in params any, in url varchar)
{
  declare sid varchar;
  connection_set ('uid', get_keyword ('uid', params));
  connection_set ('pwd', get_keyword ('pwd', params));
  http_request_status ('HTTP/1.1 302 Found');
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into WS.WS.SESSION (S_REALM, S_ID, S_EXPIRE)
             values (http_path (), sid, dateadd ('minute', 10, now ()));
  connection_set ('sid', sid);
  http_header (sprintf ('Location: %s\r\nSet-Cookie: sid=%s\r\n', url, sid));
}
;

GRANT EXECUTE ON WS.VS_U_3.COOKIE_SES_START TO VS_U_3
;

