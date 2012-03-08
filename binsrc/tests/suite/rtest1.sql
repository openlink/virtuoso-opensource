--
--  rtest1.sql
--
--  $Id$
--
--  Remote database testing part 1
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

--
--  Start the test
--
SET ARGV[0] 0;
SET ARGV[1] 0;
echo BOTH "STARTED: Remote test 1 (rtest1.sql) PORT=" $U{PORT} " LOCALPORT="$U{LOCALPORT}"\n";

create table misc (m_id integer not null primary key,
		     m_short any, m_long long varchar);

create table numtest(nt_id integer not null primary key,
    m_numeric numeric(20, 2));

attach table "MISC" as R1.DBA.MISC from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DBA.MISC " $STATE " " $MESSAGE "\n";

attach table "BLOBS" as R1.DBA.BLOBS from '$U{PORT}';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DBA.BLOBS " $STATE " " $MESSAGE "\n";

attach table "T1" as R1.DBA.T1 from '$U{PORT}';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DBA.T1 " $STATE " " $MESSAGE "\n";

attach table "NUMTEST" as R1.DBA.NUMTEST from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DBA.NUMTEST " $STATE " " $MESSAGE "\n";

attach table "B3202" as R1.DBA.B3202 from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DBA.B3202 " $STATE " " $MESSAGE "\n";

attach table "XMLT" as R1.DBA.XMLT from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DBA.XMLT " $STATE " " $MESSAGE "\n";

drop table B9680_TB;
attach table B9680_TB from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attach remote table R1.DDB.B9680_TB " $STATE " " $MESSAGE "\n";

create user R1;
grant all privileges to R1;
DB..user_set_qualifier ('R1', 'R1');
create user U1;

--- For NT
-- DB..vd_remote_data_source ('test', '', 'sa', '');
-- DB..vd_remote_table ('test', 'R1.DBA.T1', 'master.dbo.T1');
-- DB..vd_remote_table ('test', 'R1.DBA.BLOBS', 'master.dbo.BLOBS');

--
-- End of test
--

attach table misc from '$U{LOCALPORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE "OK"  "***FAILED" "PASSED";
ECHO BOTH ": Attach table from the same server \n";

ECHO BOTH "COMPLETED: Remote test 1 (rtest1.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
