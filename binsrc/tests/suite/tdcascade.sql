--  
--  $Id: tdcascade.sql,v 1.3.10.3 2013/01/02 16:15:04 source Exp $
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
echo BOTH "\nSTARTED: Drop user cascade option tests (tdcascade.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop user GOGO;
drop user GOGO2;
create user GOGO;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user GOGO created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create user GOGO2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user GOGO2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
reconnect GOGO;

-- some tables
drop table X1;

drop table X2_FK;
drop table X2;

drop table X3_SUB;
drop table X3;

drop table X4_FK_SUB;
drop table X4_FK;
drop table X4;

drop table X5_SUB_FK;
drop table X5_SUB;
drop table X5;

drop table X6;

create table X1 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table X2 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create table X2_FK (ID int primary key, DATA integer, foreign key (DATA) references X2 (ID));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X2_FK created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table X3 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X3 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- XXX: no under
--create table X3_SUB (under X3, DT_SUB integer);
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": X3_SUB created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table X4 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X4 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create table X4_FK (ID int primary key, DATA integer, foreign key (DATA) references X4 (ID));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X4_FK created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- XXX: no under
--create table X4_FK_SUB (under X4_FK, DT_SUB integer);
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": X4_FK_SUB created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table X5 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X5 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- XXX: no under
--create table X5_SUB (under X5, DT_SUB integer);
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": X5_SUB created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
--create table X5_SUB_FK (ID int primary key, DATA integer, foreign key (DATA) references X5_SUB (ID));
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": X5_SUB_FK created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table X6 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X6 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
alter table X6 add DATA varchar;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X6 altered STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- some udts
drop type TX1;

drop type TUX2;
drop type TX2;

drop type TUUX3;
drop type TUX3;
drop type TX3;

drop type TUX4;
drop type TX4;

create type TX1 as (ID int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TX1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type TX2 as (ID int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TX2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create type TUX2 under TX2 as (ID_U int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TUX2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type TX3 as (ID int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TX3 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create type TUX3 under TX3 as (ID_U int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TUX3 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create type TUUX3 under TUX3 as (ID_UU int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TUUX3 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type TX4 as (ID int) temporary self as ref;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TX4 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create type TUX4 under TX4 as (ID_U int) temporary self as ref;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type TUX4 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop module M1;
create module M1 { procedure M1P1 () { return 1;}; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": module M1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure P1;
create procedure P1 () { return 2; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure P1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

-- XXX: no under
--select * from GOGO.X5_SUB_FK;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": X5_SUB_FK present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select new GOGO.TUUX3 ().ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TUUX3 present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select new GOGO.TUX4 ().ID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TUX4 present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select GOGO.P1 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": P1 present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select DB.GOGO.M1.M1P1 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": M1 present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
drop user GOGO cascade;
-- XXX: no under
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": drop cascade on GOGO STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from GOGO.X5_SUB_FK;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": X5_SUB_FK not present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select new GOGO.TUUX3 ().ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TUUX3 not present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select new GOGO.TUX4 ().ID;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TUX4 not present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select GOGO.P1 ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": P1 not present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select DB.GOGO.M1.M1P1 ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": M1 not present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect GOGO2;
drop table GOGO2.GT1;
create table GT1 (ID int primary key);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GOGO2.GT1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select * from GOGO2.GT1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GOGO2.GT1 present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

-- XXX
drop user GOGO2;
-- XXX: no under
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": GOGO2 dropped STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from GOGO2.GT1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GOGO2.GT1 present STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: Drop user cascade option tests (tdcascade.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
