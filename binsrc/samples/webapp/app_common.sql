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
connect;

-- define a virtual directory for all samples,
-- this take us a default page
VHOST_DEFINE (lpath=>'/samples', 
	      ppath=>'/samples/',
	      is_brws=>1, 
	      def_page=>'webapp.html');

-- the HTTP web application demo user
create user WS; 
user_set_qualifier ('WS', 'WS');


-- The expired sessions reaper
-- WARNING: the server scheduler MUST be enabled (see: INI parameters for details)
insert soft SYS_SCHEDULED_EVENT (SE_NAME, SE_INTERVAL, SE_SQL, SE_START) 
    values ('webapp old sessions clear', 10, 'delete from WS.WS.SESSION where S_EXPIRE <= now ()', now ())
;

-- reconnect as web application user
set UID=WS; 
set PWD=WS;
reconnect;

-- basic web application user information table
CREATE TABLE WS.WS.APP_USER (AP_ID VARCHAR NOT NULL, -- user name
                       AP_PWD VARCHAR NOT NULL,      -- password
		       PRIMARY KEY (AP_ID)
)
;

