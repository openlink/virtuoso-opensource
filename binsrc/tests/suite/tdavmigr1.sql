--  
--  $Id: tdavmigr1.sql,v 1.3.10.1 2013/01/02 16:15:03 source Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
echo BOTH "STARTED: DAV migration test - filling\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;



select DAV_DELETE ('/DAV/col_all/col_admins/admin1/blabla1.xml', 0, 'dav_admin1', 'dav_admin1_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin1/blabla12.xml', 0, 'dav_admin1', 'dav_admin1_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin1/blabla13.xml', 0, 'dav_admin1', 'dav_admin1_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin1/blabla2.xml', 0, 'dav_admin2', 'dav_admin2_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin1/blabla22.xml', 0, 'dav_admin2', 'dav_admin2_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin1/blabla23.xml', 0, 'dav_admin2', 'dav_admin2_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin2/', 0, 'dav_admin2', 'dav_admin2_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/admin1/', 0, 'dav_admin1', 'dav_admin1_pwd');
select DAV_DELETE ('/DAV/col_all/col_admins/', 0, 'dav_admin', 'dav_admin_pwd');
select DAV_DELETE ('/DAV/col_all/', 0, 'dav_all', 'dav_all_pwd');
select DAV_DELETE ('/DAV/1/', 0, 'dav_all', 'dav_all_pwd');
select DAV_DELETE ('/DAV/2/', 0, 'dav_admin', 'dav_admin_pwd');
select DAV_DELETE ('/DAV/3/', 0, 'dav_admin1', 'dav_admin1_pwd');
select DAV_DELETE ('/DAV/4/', 0, 'dav_admin2', 'dav_admin2_pwd');
select DAV_DELETE ('/DAV/5/', 0, 'dav_user', 'dav_user_pwd');
select DAV_DELETE ('/DAV/6/', 0, 'dav_user1', 'dav_user1_pwd');
select DAV_DELETE ('/DAV/7/', 0, 'dav_user2', 'dav_user2_pwd');


DAV_DELETE_USER ('dav_all', 'dav', 'dav');
DAV_DELETE_USER ('dav_admin', 'dav', 'dav');
DAV_DELETE_USER ('dav_admin1', 'dav', 'dav');
DAV_DELETE_USER ('dav_admin2', 'dav', 'dav');
DAV_DELETE_USER ('dav_user', 'dav', 'dav');
DAV_DELETE_USER ('dav_user1', 'dav', 'dav');
DAV_DELETE_USER ('dav_user2', 'dav', 'dav');

DAV_DELETE_GROUP ('dav_all_grp', 'dav', 'dav');
DAV_DELETE_GROUP ('dav_admins_grp', 'dav', 'dav');
DAV_DELETE_GROUP ('dav_users_grp', 'dav', 'dav');


select DAV_ADD_GROUP ('dav_all_grp', 'dav', 'dav');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD GROUP dav_all\n";

select DAV_ADD_GROUP ('dav_admins_grp', 'dav', 'dav');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD GROUP dav_admins\n";

select DAV_ADD_GROUP ('dav_users_grp', 'dav', 'dav');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD GROUP dav_users\n";

select DAV_ADD_USER ('dav_all', 'dav_all_pwd', 'dav_all_grp', '111000000', 0,  '/DAV/1/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_all\n";

select DAV_ADD_USER ('dav_admin', 'dav_admin_pwd', 'dav_admins_grp', '111000000', 0,  '/DAV/2/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_admin\n";

select DAV_ADD_USER ('dav_admin1', 'dav_admin1_pwd', 'dav_admins_grp', '111000000', 0,  '/DAV/3/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_admin1\n";

select DAV_ADD_USER ('dav_admin2', 'dav_admin2_pwd', 'dav_admins_grp', '111000000', 0,  '/DAV/4/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_admin2\n";

select DAV_ADD_USER ('dav_user', 'dav_user_pwd', 'dav_users_grp', '111000000', 0,  '/DAV/5/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_user\n";

select DAV_ADD_USER ('dav_user1', 'dav_user1_pwd', 'dav_users_grp', '111000000', 0,  '/DAV/6/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_user1\n";

select DAV_ADD_USER ('dav_user2', 'dav_user2_pwd', 'dav_users_grp', '111000000', 0,  '/DAV/7/', 'dav_all', 'dav_all@localhost', 'dav', 'dav');
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD USER dav_user2\n";

select DAV_COL_CREATE ('/DAV/col_all/', '110100000', 'dav_all',   'dav_all_grp',  'dav', 'dav');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE dav_all\n";

select DAV_COL_CREATE ('/DAV/col_all/col_admins/', '110100000R', 'dav_admin',   'dav_admins_grp',  'dav_all', 'dav_all_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins\n";

select DAV_COL_CREATE ('/DAV/col_all/col_admins/admin1/', '110000000R', 'dav_admin1',   'dav_admins_grp',  'dav_admin', 'dav_admin_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin1\n";

select DAV_COL_CREATE ('/DAV/col_all/col_admins/admin2/', '110000000R', 'dav_admin2',   'dav_admins_grp',  'dav_admin', 'dav_admin_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin2\n";



select DAV_RES_UPLOAD ('/DAV/col_all/col_admins/admin1/blabla1.xml', '<a>admin1 was here</a>', '', '110100000R', 'dav_admin1', 'dav_admins_grp',    'dav_admin1', 'dav_admin1_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin1/blabla1.xml\n";

select DAV_RES_UPLOAD ('/DAV/col_all/col_admins/admin1/blabla12.xml', '<a>admin12 was here</a>', '', '110000000R', 'dav_admin1', 'dav_admins_grp',    'dav_admin1', 'dav_admin1_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin1/blabla12.xml\n";

select DAV_RES_UPLOAD ('/DAV/col_all/col_admins/admin1/blabla13.xml', '<a>admin13 was here</a>', '', '110000100R', 'dav_admin1', 'dav_admins_grp',    'dav_admin1', 'dav_admin1_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin1/blabla13.xml\n";

select DAV_RES_UPLOAD ('/DAV/col_all/col_admins/admin2/blabla2.xml', '<a>admin2 was here</a>', '', '110100000R', 'dav_admin2', 'dav_admins_grp',    'dav_admin2', 'dav_admin2_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin2/blabla2.xml\n";

select DAV_RES_UPLOAD ('/DAV/col_all/col_admins/admin2/blabla22.xml', '<a>admin22 was here</a>', '', '110000000R', 'dav_admin2', 'dav_admins_grp',    'dav_admin2', 'dav_admin2_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin2/blabla22.xml\n";

select DAV_RES_UPLOAD ('/DAV/col_all/col_admins/admin2/blabla23.xml', '<a>admin23 was here</a>', '', '110000100R', 'dav_admin2', 'dav_admins_grp',    'dav_admin2', 'dav_admin2_pwd');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": COL CREATE /DAV/col_all/col_admins/admin2/blabla23.xml\n";




ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: DAV migration test - filling\n";
