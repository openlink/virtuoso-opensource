--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
echo BOTH "STARTED: Web Import tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

delete from WS.WS.VFS_SITE;
delete from WS.WS.VFS_URL;
delete from WS.WS.VFS_QUEUE;
delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/local/%';

ECHO BOTH "Adding entries into configuration\n";
insert into WS.WS.VFS_SITE (VS_DESCR, VS_HOST, VS_ROOT, VS_URL, VS_FOLLOW, VS_DEL, VS_SRC, VS_OWN)
            values ('Virtuoso', '$U{HOST}', 'local', '/', '/%', 'checked', 'checked', http_dav_uid ());
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Virtuoso site defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


insert into WS.WS.VFS_SITE (VS_DESCR, VS_HOST, VS_ROOT, VS_URL, VS_FOLLOW, VS_DEL, VS_SRC, VS_OWN)
            values ('Non existing', 'nonexisting.none.none', 'nonexist', '/', '/%', 'checked', 'checked', http_dav_uid ());
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Non existing site defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


insert into WS.WS.VFS_QUEUE (VQ_HOST, VQ_ROOT, VQ_URL, VQ_STAT)
            values ('$U{HOST}', 'local', '/', 'waiting');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Queue for Virtuoso site defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into WS.WS.VFS_QUEUE (VQ_HOST, VQ_ROOT, VQ_URL, VQ_STAT)
            values ('nonexisting', 'nonexist', '/', 'waiting');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Queue for Non existing site defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



ECHO BOTH "Retrieving local WEB site\n";
WS.WS.SERV_QUEUE_TOP ('$U{HOST}', 'local', 0, 0, null, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Retrival of the " $U{HOST} " site done : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "Checking unexisting site\n";
WS.WS.SERV_QUEUE_TOP ('nonexisting', 'nonexist', 0, 0, null, null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Retrival of the non existing site done : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



select count (*) from WS.WS.VFS_QUEUE;
ECHO BOTH $IF $EQU $LAST[1] 36 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " entries in queue processed\n";

select * from WS.WS.VFS_URL;
select count (*) from WS.WS.VFS_URL;
ECHO BOTH $IF $EQU $LAST[1] 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " urls retrieved\n";
select count (*) from WS.WS.SYS_DAV_RES;
ECHO BOTH $IF $EQU $LAST[1] 21 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " urls stored\n";


ECHO BOTH "Export to local file system\n";
WS.WS.LFS_EXP ('$U{HOST}', '/', 'local', '$U{EXP_PATH}');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Export to local file system of the " $U{HOST} " site : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Web Import tests\n";
