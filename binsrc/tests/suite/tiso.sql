--  
--  $Id$
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


echo both "Transaction Isolation Tests\n";

drop table rc_test;
create table rc_test (id int not null primary key, ctr int default 1, d varchar)
alter index rc_test on rc_test partition (id int)
create index v on rc_test (d) partition (d varchar);

create procedure rct_c (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '40001', sqlstate '23000', sqlstate '24000', sqlstate 'HY109', sqlstate '01001'  
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'committed';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn))
	    update rc_test set ctr = ctr + 1 where id = rn;
	  else
	    insert into rc_test values (rn, 1, 'xxxxxx');
	}
      else 
	delete from rc_test where id = rn;
      commit work;
      ct := ct + 1;
    }
}

create procedure rct_u (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '40001', sqlstate '23000', sqlstate '24000', sqlstate '01001', sqlstate 'HY109'   
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'uncommitted';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn for update))
	    update rc_test set ctr = ctr + 1 where id = rn;
	  else
	    insert into rc_test values (rn, 1, 'xxxxxx');
	}
      else 
	delete from rc_test where id = rn;
      commit work;
      ct := ct + 1;
    }
}

create procedure rct_r (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '40001', sqlstate '23000', sqlstate '24000'   
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'repeatable';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn for update))
	    update rc_test set ctr = ctr + 1 where id = rn;
	  else
	    insert into rc_test values (rn, 1, 'xxxxxx');
	}
      else 
	delete from rc_test where id = rn;
      commit work;
      ct := ct + 1;
    }
}

create procedure rct_su (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '24000'  
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'serializable';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn for update))
	    update rc_test set ctr = ctr + 1 where id = rn;
	  else
	    insert into rc_test values (rn, 1, 'xxxxxx');
	}
      else 
	delete from rc_test where id = rn;
      commit work;
      ct := ct + 1;
    }
}


create procedure rct_s (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '40001', sqlstate '24000'  
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'serializable';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn ))
	    update rc_test set ctr = ctr + 1 where id = rn;
	  else
	    insert into rc_test values (rn, 1, 'xxxxxx');
	}
      else 
	delete from rc_test where id = rn;
      commit work;
      ct := ct + 1;
    }
}

create procedure rct_s_ne (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '40001', sqlstate '23000', sqlstate '24000', sqlstate 'HY109', sqlstate '01001'  
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'serializable';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn ))
	    update rc_test set ctr = ctr + 1 where id = rn;
	  else
	    insert into rc_test values (rn, 1, 'xxxxxx');
	}
      else 
	delete from rc_test where id = rn;
      commit work;
      ct := ct + 1;
    }
}



create procedure rct_r_2 (in num int, in sp int)
{
  declare ct int;
  declare rn int;
 ct:= 0;
  declare exit handler for sqlstate '40001', sqlstate '23000', sqlstate '24000', sqlstate 'HY109', sqlstate '01001'  
    {
      dbg_obj_print (__SQL_state, __SQL_message);
      rollback work;
      goto retry;
    };
  while (ct < num)
    {
    retry: ;
      set isolation = 'serializable';
      rn := sp * rnd (10);
      if (rnd (3) < 2)
	{
	  if (exists (select 1 from rc_test where id = rn for update))
	    update rc_test set ctr = ctr + 1 where id >= rn and id < rn + sp;
	  else
	    {
	      declare i int;
	      i := 0;
	      while (i < sp)
		{
		  insert into rc_test values (rn + i, 1, 'xxxxxx');
		  i := i + 1;
		}
	    }
	}
      else 
	delete from rc_test where id >= rn and id < rn + sp;
      commit work;
      ct := ct + 1;
    }
}



create procedure rc_fill (in  n int)
{
  declare c int;
  c := 0;
  while (c < n)
    {
      insert into rc_test values (c, 1, 'xxxxxxxxx');
      c := c + 1;
    }
}


rc_fill (10000);


rct_u (10000, 1000) &
rct_u (10000, 1000) &
rct_u (10000, 1000) &
rct_u (10000, 1000) &

wait_for_children;

echo both "Done rct_u\n";


rct_s (10000, 1000) &
rct_s (10000, 1000) &
rct_s (10000, 1000) &
rct_s (10000, 1000) &
wait_for_children;
echo both "Done rct_s\n";

rct_su (10000, 1000) &
rct_su (10000, 1000) &
rct_su (10000, 1000) &
rct_su (10000, 1000) &
wait_for_children;
echo both "Done rct_su\n";


rct_su (10000, 2) &
rct_su (10000, 2) &
rct_su (10000, 2) &
rct_su (10000, 2) &
wait_for_children;
echo both "Done rct_u 2\n";




rct_r (10000, 1000) &
rct_r (10000, 1000) &
rct_r (10000, 1000) &
rct_r (10000, 1000) &
wait_for_children;
echo both "Done rct_r\n";


rct_c (10000, 1000) &
rct_c (10000, 1000) &
rct_c (10000, 1000) &
rct_c (10000, 1000) &
wait_for_children;
echo both "Done rct_c\n";



rct_s_ne (10000, 1000) &
rct_s_ne (10000, 1000) &
rct_s_ne (10000, 1000) &
rct_s_ne (10000, 1000) &
wait_for_children;

echo both "Done rct_ne\n";



rct_r (10000, 100) &
rct_r (10000, 100) &
rct_r (10000, 100) &
rct_r (10000, 100) &
wait_for_children;
echo both "Done rct_r 2\n";



create procedure rct_g ()
{
  declare c, xx, tctr int;
  declare cr cursor for select id, ctr from rc_test for update;
  open cr;
  c := 0;
  while (c < 5000)
    {
      fetch cr into xx, tctr;
      c := c + 1;
    }
  commit work;
  update rc_test set ctr = tctr + 1 where current of cr;
}

rct_g ();


create procedure rct_d ()
{
  declare c, xx, tctr int;
  declare cr cursor for select id, ctr from rc_test for update;
  open cr;
  c := 0;
  while (c < 5000)
    {
      fetch cr into xx, tctr;
      c := c + 1;
    }
  commit work;
  delete from rc_test where current of cr;
}

rct_d ();

status ('');
tc_stat ();
