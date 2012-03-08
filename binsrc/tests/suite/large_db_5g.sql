--
--  large_db.sql
--
--  $Id$
--
--  Large DB test
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

echo BOTH "STARTED: Large DB test\n";

drop table TEST;

create table TEST (id integer, str long varchar);

create procedure make_1M (in c integer:=10)
{
	while (c > 0)
	{
		insert into TEST values (c, make_string (100000));
		c:=c-1;
	}
	commit work;
}

create procedure make_1G (in c integer:=1000)
{
	while (c>0)
	{
		make_1M ();
		c:=c-1;
	}
	exec ('checkpoint');
	return '1G';
}

select make_1G();
ECHO BOTH $IF $EQU $LAST[1] '1G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";

select make_1G();
ECHO BOTH $IF $EQU $LAST[1] '1G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";

select make_1G();
ECHO BOTH $IF $EQU $LAST[1] '1G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";

select make_1G();
ECHO BOTH $IF $EQU $LAST[1] '1G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";


select make_1G();
ECHO BOTH $IF $EQU $LAST[1] '1G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";

backup '/dev/null';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": Travers all trees\n";

