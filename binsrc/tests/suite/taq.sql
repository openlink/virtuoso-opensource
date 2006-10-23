--
--  $Id$
--
--  Test for async queue 
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

echo both "Async Queue Tests\n";


drop table aqi;
create table aqi (n int);

create procedure INS1 (in n int)
{
  --dbg_obj_print ('ins1 ', n);
  insert into AQI (N) values (n);
  commit work;
  return '22';
}

create procedure taq1 (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
  return (aq_wait (aq, res, 1, err));
}

taq1 (1000, 1);



create procedure taq1t (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      ins1 (n);
    }
}

create procedure taq_drop (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
}

taq_drop (2000, 5);


create procedure taq_all (in x int, in thrs int := 1)
{
  declare aq, res, err  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1', vector (n));
    }
  aq_wait_all (aq);
}

taq_all (1000, 10);


create procedure taq1err(in x int, in thrs int := 1)
{
  declare aq, res, err, v  any;
  declare n int;
  aq := async_queue (thrs);
  for (n:= 0; n < x; n:=n+1)
    {
      res := aq_request (aq, 'DB.DBA.INS1_ERR', vector (n));
    }
 v := (aq_wait (aq, res, 1, err));
	dbg_obj_print (err);
	return v;
}

taq1err (1);

create procedure INS1_ERR (in q int, in w int)
{
  return 0;
}

taq1err (1);

