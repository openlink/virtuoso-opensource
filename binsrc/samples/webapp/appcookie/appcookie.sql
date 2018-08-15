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
-- we got connect as DBA
connect;

-- first we must define http map for demo application
VHOST_DEFINE (lpath=>'/samples/appcookie', 
              ppath=>'/samples/appcookie/', 
	      def_page=>'front.vsp',  
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS',
	      ses_vars=>1);


-- connect as web application demo user WS
set UID=WS; 
set PWD=WS;
reconnect;

-- restore session variables using a cookie variable 'sid'
-- or do redirect to the re-login page if session is missing
CREATE PROCEDURE SESSION_REUSE_COOKIE (in params any, in lines any)
{
  declare sid varchar;
  declare vars any;
  sid := get_keyword ('sid', DB.DBA.vsp_ua_get_cookie_vec (lines));
  if (isarray (params) and get_keyword ('login' , params) = 'yes')
    return 1;    
  if (sid is not null and not exists (select 1 from SESSION where S_ID = sid and S_EXPIRE >= now()))
    {
      declare new_sid varchar;
      new_sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      connection_vars_set (vars);
      insert into SESSION (S_REALM, S_ID, S_EXPIRE, S_VARS, S_REQUEST_UNDER_RELOGIN)
		 values (http_path (), new_sid, dateadd ('minute', 10, now ()), 
		     serialize (connection_vars()), serialize (vector (http_path (), params)));
      connection_set ('sid', new_sid);
      http_request_status ('HTTP/1.1 302 Found');
      http_header (sprintf ('Location: %s\r\n', 'relogin.vsp'));
      DB.DBA.vsp_ua_set_cookie (DB.DBA.vsp_ua_make_cookie ('sid', new_sid, null, '', '', 0));
      delete from SESSION where S_EXPIRE <= now () and S_ID = sid;
      return 0;
    }
  else 
    {
      declare request_under_relogin, url varchar;
      request_under_relogin := 	coalesce ((select deserialize (S_REQUEST_UNDER_RELOGIN) 
				   from SESSION where S_ID = sid), NULL);    
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      update SESSION set S_EXPIRE =  dateadd ('minute', 10, now ()), S_REQUEST_UNDER_RELOGIN = NULL where S_ID = sid;
      connection_vars_set (vars);
      if (request_under_relogin is not null)
	{ 
	  connection_set ('sid', sid);
          url := aref (request_under_relogin , 0);
          call (sprintf ('WS.WS.%s', url)) (null, null, lines);
	}
    }
  return 1;
}
;

-- create new session, and set cookie to browser with 'sid' (session id) cookie variable
-- after this redirect to the default application page
create procedure SESSION_START_COOKIE (in params any, in lines any, in url varchar)
{
  declare sid varchar;
  connection_set ('uid', get_keyword ('uid', params));
  connection_set ('pwd', get_keyword ('pwd', params));
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));

  insert into SESSION (S_REALM, S_ID, S_EXPIRE)
             values (http_path (), sid, dateadd ('minute', 10, now ()));
  connection_set ('sid', sid);
  DB.DBA.vsp_ua_set_cookie (DB.DBA.vsp_ua_make_cookie ('sid', sid, null, '', '', 0));
  if (params is null)
    params := vector ();
  call (sprintf ('WS.WS./samples/appcookie/%s', url)) (null, vector_concat (params, vector ('login','yes')), lines);
};

set UID=dba; 
set PWD=dba;
reconnect;
ws..vsp_define ('/samples/appcookie/relogin.vsp', 'WS');
ws..vsp_define ('/samples/appcookie/default.vsp', 'WS');
