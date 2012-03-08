--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
ECHO BOTH "STARTED: Checking security objects on Demo DB\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

select count(*) from SYS_USERS where U_ACCOUNT_DISABLED = 0 and U_IS_ROLE = 0 and U_NAME not in ('dba', 'dav', 'demo', 'nobody', 'tutorial_demo');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Users enabled different than dba,dav,demo.\n";

select G_OBJECT, U_NAME from SYS_GRANTS, SYS_USERS where G_USER = U_ID and U_NAME = 'demo';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " grants to demo.\n";

select res_name from WS.WS.SYS_DAV_RES where RES_OWNER <> http_dav_uid () and (RES_PERMS like '__1%' or RES_PERMS like '_____1%' or RES_PERMS like '________1%');
select G_OBJECT, U_NAME from SYS_GRANTS, SYS_USERS where G_USER = U_ID and U_NAME = 'demo';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " resources with executable permissions and owner <> dav.\n";

select res_name from WS.WS.SYS_DAV_RES where RES_OWNER = http_dav_uid () and (RES_PERMS like '____1%' or RES_PERMS like '_______1%');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " resources owner is dav and writable to public or group.\n";

select res_name, res_group from WS.WS.SYS_DAV_RES where RES_GROUP is not null and res_group <> http_dav_uid () + 1;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " resources with group different than administrators.\n";

select res_full_path, res_group from WS.WS.SYS_DAV_RES where RES_GROUP is not null and not exists (select 1 from SYS_USERS where U_ID = RES_GROUP);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " resources with non-matching group id.\n";

select res_full_path, res_group from WS.WS.SYS_DAV_RES where RES_OWNER is null or not exists (select 1 from SYS_USERS where U_ID = RES_OWNER);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " resources with non-matching user id.\n";

-- tutorial_demo user from setup_tutorial.sql
select WS.WS.COL_PATH(COL_ID), COL_OWNER from WS.WS.SYS_DAV_COL where COL_OWNER <> http_dav_uid ()
    and COL_OWNER <> coalesce ((select U_ID from SYS_USERS where U_NAME = 'tutorial_demo'), http_dav_uid ())
    and COL_OWNER <> coalesce ((select U_ID from SYS_USERS where U_NAME = 'demo'), http_dav_uid ())
    and COL_OWNER <> 0;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " collections belonging to non dav user.\n";

select WS.WS.COL_PATH(COL_ID) from WS.WS.SYS_DAV_COL where COL_GROUP <> http_dav_uid () + 1 and COL_GROUP <> 0;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " collections belonging to non administrators group.\n";

select WS.WS.COL_PATH(COL_ID) from WS.WS.SYS_DAV_COL where COL_PERMS like '____1%' or COL_PERMS like '_______1%';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " collections writable to public or group.\n";

select WS.WS.COL_PATH(COL_ID) from WS.WS.SYS_DAV_COL where COL_PERMS like '_____1%' or COL_PERMS like '________1%';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " collections with execute bit on.\n";

$IF $GTE $ARGV[0] 1 "raw_exit ()" "";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Checking security objects on Demo DB\n";
