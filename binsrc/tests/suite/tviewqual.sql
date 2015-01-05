--
--  tviewqual.sql
--
--  $Id$
--
--  expansion of the view qualifiers
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

--- testcase for the backward compatibility of bug #1092

use B1092;
drop table TBL;
create table TBL (ID integer not null primary key);
insert into TBL values (1);
drop view VTBL;
create view VTBL as select ID from TBL;

use DB;
create procedure test_it (in follow_std integer)
{
  declare msg, stat varchar;
  stat := '00000';
  exec ('select VTBL.ID from B1092.DBA.VTBL where VTBL.ID > 0', stat, msg);
  if (follow_std = 0)
    {
      if (stat <> '00000')
	signal (stat, msg);
    }
  else
    {
      if (stat = '00000')
	signal ('B1092', 'The compilation of the views with non-full column prefixes was successfull');
    }
  return sys_stat ('sqlc_add_views_qualifiers');
};

select test_it($U{follow_std});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Bug 1092: view col refs prefix get's expanded to a three-part name STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
