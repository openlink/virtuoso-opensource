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
-- we connect as DBA
connect;

-- first we must define http map for demo application
VHOST_DEFINE (lpath=>'/samples/appurl/default.vsp', 
              ppath=>'/samples/appurl/default.vsp',
              auth_fn=>'WS.WS.SESSION_AUTH_URL', 
	      realm=>'sample using url parameter', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      ses_vars=>1);

VHOST_DEFINE (lpath=>'/samples/appurl/logout.vsp', 
              ppath=>'/samples/appurl/logout.vsp',
              auth_fn=>'WS.WS.SESSION_AUTH_URL', 
	      realm=>'sample using url parameter', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      ses_vars=>1);


VHOST_DEFINE (lpath=>'/samples/appurl', 
              ppath=>'/samples/appurl/',
              def_page=>'front.vsp', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      ses_vars=>1);

-- connect as web application demo user 'WS'
set UID=WS; 
set PWD=WS;
reconnect;

-- This procedure check if exists the session, if exists restore persistent session variables
-- otherwise redirect to the login page
CREATE PROCEDURE SESSION_AUTH_URL (in realm varchar)
{
  declare sid varchar;
  declare vars any;
  sid := http_param ('sid');
  if (not isstring (sid) or not exists (select 1 from SESSION where S_ID = sid))
    {
      http_request_status ('HTTP/1.1 302 Found');
      http_header (sprintf ('Location: %s\r\n', 'login.vsp'));
    }
  else 
    {
      update SESSION set S_EXPIRE =  dateadd ('minute', 10, now ()) where S_ID = sid;
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      connection_vars_set (vars);
    }
  return 1;
}
;

-- make a new session and redirect to the default page
create procedure SESSION_START_URL (in params any, in url varchar)
{
  declare sid varchar;
  connection_set ('uid', get_keyword ('uid', params));
  connection_set ('pwd', get_keyword ('pwd', params));
  http_request_status ('HTTP/1.1 302 Found');
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));

  insert into SESSION (S_REALM, S_ID, S_EXPIRE)
             values (http_path (), sid, dateadd ('minute', 10, now ()));
  connection_set ('sid', sid);
  http_header (sprintf ('Location: %s?sid=%s\r\n', url, sid)); 
};


