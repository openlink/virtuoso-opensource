--  
--  $Id: tlock.sql,v 1.6.10.1 2013/01/02 16:15:12 source Exp $
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

drop table LOCK_TT;
set lock_escalation_pct = 10;
create table LOCK_TT (ID int identity not null primary key, CTR int);
create procedure LOCK_TT_FILL (in N int)
{
  declare _CTR int;
  _CTR := 0;
  while (_CTR < N)
    {
      insert into LOCK_TT (CTR) values (_CTR);
      _CTR := _CTR + 1;
    }
}


set DEADLOCK_RETRIES = 400;
LOCK_TT_FILL (50000) &
LOCK_TT_FILL (20000) &
LOCK_TT_FILL (10000) &
LOCK_TT_FILL (10000) &

wait_for_children;
set DEADLOCK_RETRIES = 0;
select count (*), count (distinct CTR)from LOCK_TT;

#echo both $if $equ $last[1] 90000 "PASSED" "***FAILED";
#$echo both ": Inserted " $last[1] " rows\n";
#echo both $if $equ $last[2] 50000 "PASSED" "***FAILED";
#echo both ": Inserted " $last[2] " distinct CTR values\n";
