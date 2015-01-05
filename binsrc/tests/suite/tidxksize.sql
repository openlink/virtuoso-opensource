--
--  tidxksize.sql
--
--  $Id: tidxksize.sql,v 1.7.10.1 2013/01/02 16:15:10 source Exp $
--
--  Index key sizes test suite
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

ECHO BOTH "STARTED: Index key sizes test\n\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop table IOT;
create table IOT (id int not null primary  key, DT varchar);
create index DT on IOT (DT);


insert into IOT values (1, '123');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a normal length value 123 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into IOT values (2, make_string (1500));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a medium length value (1500) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into IOT values (2, make_string (15000));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a large length value (15000) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update IOT set DT = make_string (1500);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating with a medium length value (1500) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update IOT set DT = make_string (15000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": updating with a large length value (15000) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table IOT add DT2 varchar;
update IOT set DT = '';

update IOT set DT2 = make_string (1600);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": prefilling DT2 with a medium length value (1600) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index DT2 on IOT (DT2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating index over DT2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table IOT add DT3 long varchar;
create index DT3 on IOT (DT3);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating index over BLOB STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "\nCOMPLETED: Index key sizes test WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n";
