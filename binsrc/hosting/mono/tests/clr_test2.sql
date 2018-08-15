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
DROP LIBRARY "myPoint";

CREATE LIBRARY "myPoint" as concat (server_root() , 'temp_dll_stor\\Point_ho_s_10.dll') WITH PERMISSION_SET = UNRESTRICTED WITH AUTOREGISTER;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CREATE LIBRARY 'myPoint' = " $STATE "\n";

delete from DB.DBA.CLR_VAC;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete from DB.DBA.CLR_VAC to test AppendPrivatePath " $STATE "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": delete from DB.DBA.CLR_VAC to test unmanaged hook " $STATE "\n";

commit work
;

drop table CLR..Supplier_ho_s_10;
;

create table CLR..Supplier_ho_s_10 (id integer primary key, name varchar (20), location Point_10);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create table CLR..Supplier_ho_s_10 " $STATE "\n";

insert into CLR..Supplier_ho_s_10 (id, name, location) values (1, 'S1', new Point_10 (1, 1));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into CLR..Supplier_ho_s_10 new Point_10 (1, 1) " $STATE "\n";

insert into CLR..Supplier_ho_s_10 (id, name, location) values (2, 'S2', new Point_10 (3, 3));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into CLR..Supplier_ho_s_10 new Point_10 (3, 3) " $STATE "\n";

insert into CLR..Supplier_ho_s_10 (id, name, location) values (3, 'S3', new Point_10 (5, 5));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into CLR..Supplier_ho_s_10 new Point_10 (5, 5) " $STATE "\n";

select s.name from CLR..Supplier_ho_s_10 s where s.location.x > 2 and s.location.x < 5;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select s.name from CLR..Supplier_ho_s_10 row selected " $ROWCNT "\n";
ECHO BOTH $IF $EQU $LAST[1] S2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": s.name " $LAST[1] "\n";
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select s.name from CLR..Supplier_ho_s_10 row selected " $STATE "\n";

