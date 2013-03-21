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
VHOST_DEFINE (lpath=>'/samples/appdigest/default.vsp', 
              ppath=>'/samples/appdigest/default.vsp', 
              auth_fn=>'WS.WS.DIGEST_AUTH', realm=>'digest authentication sample', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      sec=>'DIGEST', 
	      ses_vars=>1,
	      auth_opts=>vector ('users_proc', 'WS.WS.USER_CHECK'));

VHOST_DEFINE (lpath=>'/samples/appdigest/logout.vsp', 
              ppath=>'/samples/appdigest/logout.vsp', 
              auth_fn=>'WS.WS.DIGEST_AUTH', realm=>'digest authentication sample', 
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      sec=>'DIGEST', 
	      ses_vars=>1,
	      auth_opts=>vector ('users_proc', 'WS.WS.USER_CHECK'));

VHOST_DEFINE (lpath=>'/samples/appdigest', 
              ppath=>'/samples/appdigest/', 
	      def_page=>'front.vsp',
	      ppr_fn=>'WS.WS.SESSION_SAVE', 
	      vsp_user=>'WS', 
	      ses_vars=>1);


-- connect as web application demo user WS
set UID=WS; 
set PWD=WS;
reconnect;


-- retrieve from application specific users table the password supplied for _user
-- and return password
CREATE PROCEDURE USER_CHECK (in _uname any, out passwd varchar)
{
  passwd := null;
  whenever not found goto nfu;
  select AP_PWD into passwd from APP_USER where AP_ID = _uname;
nfu:;
  return;
}

-- redirect to the specified url
create procedure REDIRECT_TO (in url varchar)
{
   http_request_status ('HTTP/1.1 302 Found');
   http_header (sprintf ('Location: %s\r\n', url));
};


