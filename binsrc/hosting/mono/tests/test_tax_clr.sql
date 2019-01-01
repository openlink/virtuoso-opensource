--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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

drop type myFinances;

drop table Employee;

DB..import_clr (vector ('tax'), vector ('myFinances'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": import_clr 'myFinances' = " $STATE "\n";

create table Employee (name varchar primary key, salary double precision not null);

insert into Employee (name, salary) values ('John Dow', 35000);
insert into Employee (name, salary) values ('John Smith', 100000);
insert into Employee (name, salary) values ('John Little', 300000);

select name from Employee where myFinances::tax (salary) > 20;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": taxes " $ROWCNT " rows\n";

DB..unimport_clr (vector ('tax'), vector ('myFinances'));

select myFinances::tax (10000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": unimport_clr dropped the type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..import_clr (vector ('tax'), vector ('myFinances'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": import_clr 'myFinances' = " $STATE "\n";

create procedure tax (in x double precision) returns double precision LANGUAGE CLR EXTERNAL NAME 'tax/myFinances.tax';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure tax ... LANGUAGE CLR EXTERNAL NAME ... STATE=" $STATE "\n";

select tax(cast (1 as double precision));
ECHO BOTH $IF $EQU $LAST[1] 0.15 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tax (1) - LAST = " $LAST[1] "\n";

drop procedure tax;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop procedure tax STATE=" $STATE "\n";

select tax(cast (1 as double precision));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tax (1) - LAST = " $LAST[1] "\n";

drop type tax1;

create type tax1 language clr external name 'tax/MyFinances' static method tax (x double precision) returns double precision;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create type tax1 language clr external name ... STATE=" $STATE "\n";

select myFinances::tax (5);
ECHO BOTH $IF $EQU $LAST[1] 0.75 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": tax (5) - LAST = " $LAST[1] "\n";

