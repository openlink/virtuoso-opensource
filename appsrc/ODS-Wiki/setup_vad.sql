--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
create procedure WV.WIKI.SILENT_EXEC (in code varchar)
{
  whenever sqlstate '*' goto cont; exec (code); commit work; return; cont: rollback work;
};

create procedure WV.WIKI.USERROLE_DROP (in _role varchar)
{
  if ((_role is not null) and (_role <> ''))
  {
    if (exists (select 1 from  SYS_USERS where U_NAME = _role and U_IS_ROLE = 1))
	    DB.DBA.USER_ROLE_DROP(_role);
  }
};

WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_CREATE (\'WikiAdmin\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_CREATE (\'WikiUser\', 1)');
WV.WIKI.SILENT_EXEC('drop trigger WV.Wiki.WIKI_USERS_U');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_CREATE (\'Wiki\', uuid() , vector (\'LOGIN_QUALIFIER\', \'WV\', \'DISABLED\', 1, \'SQL_ENABLE\', 1, \'DAV_ENABLE\', 0))');
grant all privileges to "Wiki";
DB.DBA.USER_SET_OPTION ('Wiki', 'SQL_ENABLE', 1);

WV.WIKI.SILENT_EXEC ('DB.DBA.USER_CREATE (\'WikiGuest\', uuid(), vector (\'LOGIN_QUALIFIER\', \'WV\', \'SQL_ENABLE\', 0, \'DAV_ENABLE\', 1, \'DISABLED\', 1))');

WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'Wiki\', \'administrators\', 0)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'Wiki\', \'WikiAdmin\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'Wiki\', \'WikiUser\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'dav\', \'WikiUser\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'dav\', \'WikiAdmin\', 1)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_GRANT_ROLE (\'WikiGuest\', \'WikiUser\', 0)');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_SET_QUALIFIER (\'Wiki\', \'WV\')');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/resources');
DB.DBA.VHOST_REMOVE(vhost=>sioc..get_cname(), lpath=>'/wiki/resources');
DB.DBA.VHOST_DEFINE(is_dav=>1, lpath=>'/wiki/resources/', ppath=>'/DAV/VAD/wiki/Root/', vsp_user=>'Wiki', opts=>vector('executable','yes'));

