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
DROP USER VS_U_4
;

CREATE USER VS_U_4
;

USER_SET_QUALIFIER ('VS_U_4', 'WS')
;

DROP TABLE WS.VS_U_4.APP_USER
;

CREATE TABLE WS.VS_U_4.APP_USER (AP_ID VARCHAR PRIMARY KEY, AP_PWD VARCHAR)
;

GRANT INSERT, UPDATE, DELETE, SELECT ON WS.WS.SESSION TO VS_U_4
;

GRANT INSERT, UPDATE, DELETE, SELECT ON WS.VS_U_4.APP_USER TO VS_U_4
;

VHOST_REMOVE (lpath=>'/vs_u_4')
;

VHOST_DEFINE (lpath=>'/vs_u_4',
              ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/web/vs_u_4/',
              auth_fn=>'WS.WS.DIGEST_AUTH', realm=>'Digest Authentication Example',
	      ppr_fn=>'WS.WS.SESSION_SAVE',
	      vsp_user=>'VS_U_4',
	      sec=>'DIGEST',
	      ses_vars=>1,
	      def_page=>'front.vsp',
	      is_dav=>TUTORIAL_IS_DAV(),
	      auth_opts=>vector ('users_proc', 'WS.VS_U_4.DIGEST_USER_CHECK', 'public_pages', 'front.vsp,login.vsp,register.vsp'));


CREATE PROCEDURE WS.VS_U_4.DIGEST_USER_CHECK (in _uname any, out passwd varchar)
{
  passwd := coalesce ((select AP_PWD from WS.VS_U_4.APP_USER where AP_ID = _uname), null);
};

create procedure WS.VS_U_4.DIGEST_REDIRECT_TO (in url varchar)
{
   http_request_status ('HTTP/1.1 302 Found');
   http_header (sprintf ('Location: %s\r\n', url));
};




GRANT EXECUTE ON WS.VS_U_4.DIGEST_USER_CHECK TO VS_U_4
;

GRANT EXECUTE ON WS.VS_U_4.DIGEST_REDIRECT_TO TO VS_U_4
;

