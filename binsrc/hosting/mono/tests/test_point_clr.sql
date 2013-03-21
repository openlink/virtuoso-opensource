--  
--  $Id$
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

drop type Point;

import_clr (vector ('Point'), vector ('Point'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": import_clr 'Point' = " $STATE "\n";

drop table Supplier;

create table Supplier (id integer primary key, name varchar (20), location Point);

insert into Supplier (id, name, location) values (1, 'S1', new Point (1, 1));
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into Supplier 1 \n";

insert into Supplier (id, name, location) values (2, 'S2', new Point (3, 3));
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into Supplier 2 \n";

insert into Supplier (id, name, location) values (3, 'S3', new Point (5, 5));
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into Supplier 3 \n";

select s.name from Supplier s where s.location.distance (Point (4, 4)) < 3;
ECHO BOTH $IF $EQU $LAST[1] S3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": distance < 3 s.name=" $LAST[1]"\n";
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select from Supplier rows=" $ROWCNT "\n";

select (deserialize (serialize (new Point (1, 1))));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing/deserializing serializable type STATE=" $STATE" MESSAGE=" $MESSAGE "\n";
