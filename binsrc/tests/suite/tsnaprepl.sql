--
--  tsnaprepl.sql
--
--  $Id$
--
--  Snapshot replication local tests
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

echo BOTH "STARTED: Snapshot replication local test\n";

CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table SRL_TB1;
create table SRL_TB1 (ID int primary key, DATA varchar(50));

foreach integer between 1 10 insert into SRL_TB1 (ID, DATA) values (?, 'data');

create snapshot log for SRL_TB1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Snapshot log created for SRL_TB_1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create snapshot SRL_SN1_TB1 from SRL_TB1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Snapshot SRL_SN1_TB1 created for SRL_TB_1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SRL_SN1_TB1;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Snapshot SRL_SN1_TB1 has " $ROWCNT " rows\n";

select * from DB.DBA.SYS_SNAPSHOT where SN_NAME like '%SRL_SN1_TB1';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Snapshot SRL_SN1_TB1 has " $ROWCNT " rows in SYS_SNAPSHOT\n";

drop table SRL_SN1_TB1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Snapshot SRL_SN1_TB1 dropped STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.SYS_SNAPSHOT where SN_NAME like '%SRL_SN1_TB1';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B8628: Snapshot SRL_SN1_TB1 has " $ROWCNT " rows in SYS_SNAPSHOT\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Snapshot replication local test\n";
