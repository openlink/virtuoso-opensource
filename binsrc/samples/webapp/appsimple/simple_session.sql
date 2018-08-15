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
-- connect as DBA
connect;
-- define a http map pointed to /samples/appsimple 
VHOST_DEFINE (lpath=>'/samples/appsimple', 
	      ppath=>'/samples/appsimple/', 
	      is_brws=>1,  
    	      auth_fn=>'WS.WS.RESTORE_SESSION_SAMPLE', 
	      realm=>'simple HTTP session demo', 
	      ppr_fn=>'WS.WS.SAVE_SESSION_SAMPLE', 
	      vsp_user=>'WS',
	      ses_vars=>1);

-- create a user witch will be perform vsp execution 
create user WS;
user_set_qualifier ('WS', 'WS');
set UID=WS;
set PWD=WS;
-- connect as WS user
reconnect;

-- sessions table 
CREATE TABLE SESSIONS (SES_ID VARCHAR NOT NULL PRIMARY KEY, -- unique ID of session
	               SES_IP_ADDRESS VARCHAR,		    -- client IP address
		       SES_EXPIRE DATETIME,      	    -- expire time
                       SES_VARS VARCHAR   		    -- session variables
		       );		      


-- this function will be called every time if user agent is pointed to /samples/appsimple 
-- restore a session variables from existing session or create a new one
-- this always return authenticated 
-- in this place can be checked user name and password, so if not authenticated then must return 0
CREATE PROCEDURE RESTORE_SESSION_SAMPLE (in realm varchar)
{
  declare sid varchar;
  declare vars any;
  -- we reserved a 'sid' as session id URL variable , got it
  sid := http_param ('sid'); 
  -- if not an session 
  if (not isstring (sid)
      or not exists (select 1 from SESSIONS where SES_ID = sid))
    {
      -- generate a new session id and store into the sessions table
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ())); 
      insert into SESSIONS (SES_ID, SES_IP_ADDRESS, SES_EXPIRE)
             values (sid, http_client_ip (), dateadd ('minute', 10, now ()));	 
      -- set a connection variable 'sid' with value of session id
      connection_set ('sid', sid); 
    }
  else
    {
      -- session found , increase a expire time 
      update SESSIONS set SES_EXPIRE =  dateadd ('minute', 10, now ()) where SES_ID = sid;
      -- restore persistent session variables
      vars := coalesce ((select deserialize (SES_VARS) from SESSIONS where SES_ID = sid), NULL);
      connection_vars_set (vars);
    }
  RETURN 1;
};

-- this function will be executed always after successful authentication   
-- will store session variables into the session table 
CREATE PROCEDURE SAVE_SESSION_SAMPLE ()
{
  declare sid varchar;
  declare vars any;
  vars := connection_vars (); -- retrieve all session variables
  if (http_map_get ('persist_ses_vars') and connection_is_dirty ()) -- check if persistent storage of it allowed
    {
      sid := get_keyword ('sid', vars, null);  -- retrieve a session id from variables    
      if (sid is not null)
        update SESSIONS set SES_VARS = serialize (vars) where SES_ID = sid; -- and update session table	
    }
  connection_vars_set (NULL); -- after this reset session variables to empty vector in the memory.
}
;

