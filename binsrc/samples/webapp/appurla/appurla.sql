--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
VHOST_DEFINE (lpath => '/samples/appurla', 
	      ppath => '/samples/appurla/', 
	      def_page => 'front.vsp',  
	      ppr_fn => 'WS.WS.SESSION_SAVE', 
	      vsp_user => 'WS', 
	      ses_vars => 1);

-- connect as web application demo user WS
set UID=WS; 
set PWD=WS;
reconnect;

-- restore session variables or redirect to the re-login page
CREATE PROCEDURE SESSION_RESTORE_URLA (in params varchar)
{
  declare sid varchar;
  declare vars any;
  sid := get_keyword ('sid', params);
  if (not isstring (sid) or not exists (select 1 from SESSION where S_ID = sid and S_EXPIRE >= now ()))
    {
      declare new_sid varchar;
      new_sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      connection_vars_set (vars);
      connection_set ('sid', new_sid);
      insert into SESSION (S_REALM, S_ID, S_EXPIRE, S_VARS, S_REQUEST_UNDER_RELOGIN)
		 values (http_path (), new_sid, dateadd ('minute', 10, now ()), 
		     serialize (connection_vars()), serialize (vector (http_path (), params)));
      delete from SESSION where S_EXPIRE <= now () and S_ID = sid;
      call (sprintf ('WS.WS.%s', '/samples/appurla/relogin.vsp')) (null, vector ('sid', new_sid), null);
      return 0;
    }
  else if ('' = get_keyword ('login', params, ''))
    {
      declare request_under_relogin, url varchar;
      request_under_relogin := 	coalesce ((select deserialize (S_REQUEST_UNDER_RELOGIN) 
				   from SESSION where S_ID = sid), NULL);    
      vars := coalesce ((select deserialize (S_VARS) from SESSION where S_ID = sid), NULL);
      update SESSION set S_EXPIRE =  dateadd ('minute', 10, now ()), S_REQUEST_UNDER_RELOGIN = NULL 
	  where S_ID = sid;
      connection_set ('sid', sid);
      connection_vars_set (vars);
      if (request_under_relogin is not null)
	{ 
          url := aref (request_under_relogin , 0);
          call (sprintf ('WS.WS.%s', url)) (null, vector ('sid', sid), null);
	}
	
    }
  return 1;
}
;

-- create a new session and redirect to the default page
create procedure SESSION_START_URLA (in params any, in url varchar)
{
  declare sid varchar;
  connection_set ('uid', get_keyword ('uid', params));
  connection_set ('pwd', get_keyword ('pwd', params));
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));

  insert into SESSION (S_REALM, S_ID, S_EXPIRE)
             values (http_path (), sid, dateadd ('minute', 10, now ()));
  connection_set ('sid', sid);
  params := vector_concat (params, vector ('sid', sid, 'login', 'yes'));
  call (sprintf ('WS.WS.%s', url)) (null, params, null);
};


-- terminate the session and call front page
create procedure SESSION_TERMINATE_URLA (in url varchar)
{
  delete from SESSION where S_ID = connection_get ('sid');
  call (sprintf ('WS.WS.%s', url)) (null, null, null);
};

set UID=dba; 
set PWD=dba;
reconnect;
ws..vsp_define ('/samples/appurla/relogin.vsp', 'WS');
ws..vsp_define ('/samples/appurla/default.vsp', 'WS');
