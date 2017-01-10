--
--  large_db.sql
--
--  $Id: large_db_3g.sql,v 1.3.10.1 2013/01/02 16:14:41 source Exp $
--
--  Large DB test
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

echo BOTH "STARTED: Large DB test\n";

drop table TEST;

create table TEST (id integer, str long varchar);

create procedure make_1M (in base integer, in c integer:=10)
{
	declare cc integer;
	cc:=base;
	while (c > 0)
	{
--		insert into TEST values (c, make_string (100000));
		insert into TEST values (base, make_string (100000));
--		insert into TEST values (c, make_string (10));
		base:=base+1;
		c:=c-1;
	}
	commit work;
}

create procedure make_1G (in str varchar, in base integer, in c integer:=1000)
-- create procedure make_1G (in c integer:=10)
{
	declare cc integer;
	cc:=base;
	while (c>0)
	{
		make_1M (cc, 10);
		base:=base + 10;
		c:=c-1;
	}
	exec ('checkpoint');
	return str;
}

create procedure check_sum()
{
  declare csum integer;
  csum:=1;
  for select id from TEST do
    {
	csum:=mod ((csum+171)*(id+1), 677);
    }
  return csum;
}

select make_1G('1G', 0);
eCHO BOTH $IF $EQU $LAST[1] '1G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";

select make_1G('2G', 10000);
ECHO BOTH $IF $EQU $LAST[1] '2G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";

select make_1G('3G', 20000);
ECHO BOTH $IF $EQU $LAST[1] '3G' "PASSED" "***FAILED";
ECHO BOTH " Inserted: " $LAST[1] " bytes\n";


