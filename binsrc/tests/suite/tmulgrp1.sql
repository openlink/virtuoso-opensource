--
--  tmulgroup.sql
--
--  $Id: tmulgrp1.sql,v 1.3.10.1 2013/01/02 16:15:13 source Exp $
--
--  Check multiple user group functions
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

SET ARGV[0] 0;
SET ARGV[1] 0;

ECHO BOTH "STARTED: Multiple user group load test\n";

set charset='IBM866';

delete user ADMIN;
delete user DB_USERS;
delete user WEB_USERS;
delete user WEB_USER;
delete user DB_USER;
delete user ACCOUNTANTS;
delete user ACCOUNTANT;
drop table WEB_DATA;
drop table DB_DATA;
drop table WEB_USERS.TEST;

create user ADMIN;
create user DB_USERS;
create user WEB_USERS;
create user WEB_USER;
create user DB_USER;
create user ACCOUNTANTS;
create user ACCOUNTANT;

add user group ACCOUNTANT ACCOUNTANTS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user ACCOUNTANT assigned the group ACCOUNTANTS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group DB_USER DB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user DB_USER assigned the group DB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group ADMIN DB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user ADMIN assigned the group DB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group ACCOUNTANTS DB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": group ACCOUNTANTS assigned the group WEB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group WEB_USER WEB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user WEB_USER assigned the group WEB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group ADMIN WEB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user ADMIN assigned the group WEB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group ACCOUNTANTS WEB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": group ACCOUNTANTS assigned the group WEB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group ACCOUNTANTS WEB_USERS;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": group ACCOUNTANTS assigned again the group WEB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete user group ACCOUNTANTS DBA;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": group DBA deleted from the group ACCOUNTANTS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

add user group ACCOUNTANTS ACCOUNTANTS;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": group ACCOUNTANTS assigned it's primary group. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table WEB_DATA (ID integer not null primary key, DATA varchar (50));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table WEB_DATA created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB_DATA (ID integer not null primary key, DATA varchar (50));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table DB_DATA created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table WEB_USERS.TEST (ID integer not null primary key, DATA varchar (50));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table WEB_USERS.TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant ALL on DB_DATA to DB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table DB_DATA granted to DB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant SELECT on WEB_DATA to WEB_USERS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table WEB_DATA granted to WEB_USERS. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



ECHO BOTH "COMPLETED: Multiple user group load test (tmulgrp.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n";
