--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
create procedure WV.WIKI.SILENT_EXEC (in code varchar) { whenever sqlstate '*' goto cont; exec (code); return; cont: rollback work; };
-- WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_DROP (\'WikiAdmin\')');
-- WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_DROP (\'WikiUser\')');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_CREATE (\'WikiAdmin\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_CREATE (\'WikiUser\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_CREATE (\'Wiki\', \'Wiki\', vector (\'DAV_ENABLE\', 1, \'SQL_ENABLE\', 1, \'LOGIN_QUALIFIER\', \'WV\'))');
user_set_password ('Wiki', 'Wiki');
grant all privileges to Wiki;
DB.DBA.USER_CREATE ('WikiGuest', '', vector ('DAV_ENABLE', 1, 'SQL_ENABLE', 0, 'LOGIN_QUALIFIER', 'WV'));
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'Wiki\', \'administrators\', 0)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'Wiki\', \'WikiAdmin\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'Wiki\', \'WikiUser\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'dav\', \'WikiUser\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'dav\', \'WikiAdmin\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'WikiGuest\', \'WikiUser\', 0)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_SET_QUALIFIER (\'Wiki\', \'WV\')');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/main');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/resources');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Main');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Doc');
DB.DBA.VHOST_DEFINE(is_dav=>1, lpath=>'/wiki/main/', ppath=>'/DAV/VAD/wiki/Root/main.vsp', vsp_user=>'Wiki', opts=>vector('noinherit' ,1, 'executable','yes'));
DB.DBA.VHOST_DEFINE(is_dav=>1, lpath=>'/wiki/resources/', ppath=>'/DAV/VAD/wiki/Root/', vsp_user=>'Wiki', opts=>vector('executable','yes'));
DB.DBA.VHOST_REMOVE(lpath=>'/wikix');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/wikix');
DB.DBA.VHOST_REMOVE(lpath=>'/wikiview');
DB.DBA.VHOST_REMOVE(lpath=>'/DAV/wikiview');


