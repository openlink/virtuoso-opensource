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
--$Id$

-- This script configures Wiki for unit tesing and development.

-- Set default password for Wiki instead of random or changed by user.
user_set_password ('Wiki', 'Wiki');
use WV;
reconnect Wiki;

-- 'WikiDiskDump' specifies the directory where all compiled pages
--  will be saved as files. This is useful for debugging:
-- when you stop the server in the debugger, your changed pages
-- are 100% surely on disk even if editing transaction is not completed.
registry_set ('WikiDiskDump', 'test_dump');

-- 'TWiki' is for documents from blank TWiki installation (compatibility test).
CreateCluster ('TWiki', 0, WV.WIKI.WIKIUID());
registry_set ('WikiV %TWIKIWEB%', 'TWiki');

-- Creating users, clusters and pages for testing access control.
DB.DBA.USER_CREATE ('JamesBond', 'JamesBond', vector ('DAV_ENABLE', 1, 'SQL_ENABLE', 1));
user_set_password ('JamesBond', 'JamesBond');
DB.DBA.USER_GRANT_ROLE ('JamesBond', 'WikiUser', 0);
DB.DBA.USER_CREATE ('Writer', 'Writer', vector ('DAV_ENABLE', 1, 'SQL_ENABLE', 1));
user_set_password ('Writer', 'Writer');
DB.DBA.USER_GRANT_ROLE ('Writer', 'WikiUser', 0);
DB.DBA.USER_CREATE ('Reader', 'Reader', vector ('DAV_ENABLE', 1, 'SQL_ENABLE', 1));
user_set_password ('Reader', 'Reader');
DB.DBA.USER_GRANT_ROLE ('Reader', 'WikiUser', 0);
WV.WIKI.CREATEUSER ('JamesBond', 'JamesBond', 'WikiUser', 'A test user who has his own cluster but nobody can read it');
WV.WIKI.CREATEUSER ('Writer', 'TheWriter', 'WikiUser', 'A test user who has his own cluster');
WV.WIKI.CREATEUSER ('Reader', 'TheReader', 'WikiUser', 'A test user who only reads clusters of others');
select DB.DBA.DAV_COL_CREATE ('/DAV/JamesBond/', '110000000R', 'JamesBond', 'WikiUser', 'dav', null);
select DB.DBA.DAV_PROP_SET ('/DAV/JamesBond/', 'WikiCluster', 'SecretCluster', 'dav', null);
select DB.DBA.DAV_RES_UPLOAD ('/DAV/JamesBond/WelcomeVisitors.txt', 'This is a __top secret__ list of documents: SpaceWars, UsamaBinLaden, OpenSezame <hide><abstract>Test data</abstract></hide>', 'text/plain', '110000000R', 'JamesBond', 'WikiUser', 'dav', null);
select DB.DBA.DAV_RES_UPLOAD ('/DAV/JamesBond/SpaceWars.txt', 'First file. Let''s have a link to ClusterOne.WelcomeVisitors.', 'text/plain', '110000000R', 'JamesBond', 'WikiUser', 'dav', null);
select DB.DBA.DAV_RES_UPLOAD ('/DAV/JamesBond/UsamaBinLaden.txt', 'Second file. Let''s have a link to ClusterTwo.WelcomeVisitors.', 'text/plain', '110000000R', 'JamesBond', 'WikiUser', 'dav', null);
select DB.DBA.DAV_RES_UPLOAD ('/DAV/JamesBond/OpenSezame.txt', 'Third file with a BadLink inside.', 'text/plain', '110000000R', 'JamesBond', 'WikiUser', 'dav', null);
select DB.DBA.DAV_COL_CREATE ('/DAV/WriterOne/', '110100100R', 'Writer', 'WikiUser', 'dav', null);
select DB.DBA.DAV_PROP_SET ('/DAV/WriterOne/', 'WikiCluster', 'ClusterOne', 'dav', null);
select DB.DBA.DAV_RES_UPLOAD ('/DAV/WriterOne/WelcomeVisitors.txt', 'This is first standard _Hello world_ test :). <hide><abstract>Test data</abstract></hide>', 'text/plain', '110100100R', 'Writer', 'WikiUser', 'dav', null);
select DB.DBA.DAV_COL_CREATE ('/DAV/WriterTwo/', '110100100R', 'Writer', 'WikiUser', 'dav', null);
select DB.DBA.DAV_PROP_SET ('/DAV/WriterTwo/', 'WikiCluster', 'ClusterTwo', 'dav', null);
select DB.DBA.DAV_RES_UPLOAD ('/DAV/WriterTwo/WelcomeVisitors.txt', 'This is second standard _Hello world_ test :). Let''s try to have a link to ClusterOne.WelcomeVisitors and SecretCluster.WelcomeVisitors. <hide><abstract>Test data</abstract></hide>', 'text/plain', '110100100R', 'Writer', 'WikiUser', 'dav', null);

-- 'UsMain' is for documents from 'Main' web of US office Wiki.
-- While we have nothing better, it's the only test on real dirty data.
WV.WIKI.CREATECLUSTER());

-- Now it;s time to load test data.
set echo on;
WV.WIKI.LOADCLUSTERFROMFILES ('initial/TWiki', 'TWiki');
--WV.WIKI.LOADCLUSTERFROMFILES ('initial/UsMain', 'UsMain');
