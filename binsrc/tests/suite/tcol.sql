--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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


create table tco (k1 bigint, k2 bigint not null, primary key (k1) column);

insert into tco values (3, 4);
insert into tco values (1, 2);
insert into tco values (2, 3);

--select count (*) from  tco a, tco b where b.k1 = a.k2 option (order, loop);


create procedure tco (in i1 int, in n int, in step int, in ck int := 0)
{
  declare ctr int;
  log_enable (0, 1);
  for (ctr := 0; ctr < n; ctr := ctr + 1)
    {
      insert into tco values (i1 + ctr * step, i1 + ctr * step);
      if (ck)
	{
	  if ((select count (*) from tco a where not exists (select 1 from tco b table option (loop) where a.k1 = b.k1)))
	    {
	      dbg_obj_print ('bad after ins of ', i1 + ctr * step);
	      signal ('oow..', 'out of whack');
	    }
	}
    }
}

create procedure tcoins (in ak1 any array, in ak2 any array)
{
  log_enable (2, 1);
  for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into tco values (k1, k2);
    }
}


tcoins (vector (10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110),
       vector ( 0, 0, 3, 6, 7, 10, 14, 31, 34, 35, 39));

tcoins (vector (91, 92), vector (35, 39));



tco (1000, 1000, 1000, 1);
tco (1010, 1000, 1000, 1);
tco (1020, 1000, 1000);


insert into tco select k1 - 5, k2 - 5 from tco where k1 + 0 < 500000;
select k1, count (*) from tco group by k1 having count (*) > 1;

log_enable (0, 1);
insert into tco select k1 - 2, k2 - 2 from tco where k1 + 0 > 900;

insert into tco select k1 - 10000000, k2 - 10000000 from tco where k1 + 0 >  900 ;



tco (1030, 5300, 1000);
tco (1030 + 5300000, 6000, 1000);
tco (1220001,  1000, 2);
tco (1222001,  4000, 2);


--tco (1040, 2000000, 1000);


create procedure intd_arr_fill (inout arr any, in inx_from int, in n_from int, in n int, in step int)
{
 declare c int;
  for (c := 0; c < n; c := c+ 1)
   arr[inx_from + c] := n_from + c * step;
}


create procedure intd_test_vec ()
{
  declare arr any;
  arr := make_array (310, 'any');
  intd_arr_fill (arr, 0, 0hex10000000, 100, 256);
  intd_arr_fill (arr, 100, 0hex20000000, 100, 256);
  intd_arr_fill (arr, 200, 0hex25000000, 100, 256);
  intd_arr_fill (arr, 300, 0hex8ffef000, 10, 128);
    tcoins (arr, arr);
}

select top 10 k1 from tco a where not exists (select 1 from tco b table option (loop) where a.k1 = b.k1);


insert into tco select k1 + 1, k2 + 1 from tco a where  not exists (select 1 from tco b table option (loop) where a.k1 + 1 = b.k1) and 0 = mod (k1, 10);

create table tco2 (k1 int, k2 int, d int not null, primary key (k1, k2) column);

create procedure tco2 (in n1 int, in n2 int)
{
  declare c, c2 int;
  log_enable (2, 1);
  for (c := n1; c < n2; c := c + 1)
    {
      for (c2 := 0; c2 < mod (c, 17) + 1; c2 := c2 + 1)
	insert into tco2 values (c, c2, c + c2);
    }
}


create procedure tco2ins (in ak1 any array, in ak2 any array)
{
  log_enable (2, 1);
  for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into tco2 values (k1, k2, k1 + k2);
    }
}



create procedure tco2_co (in sz int, in rounds int)
{
  set non_txn_insert = 1;
  declare ctr, i int;
  declare a1, a2, a3 any;
 a1 := make_array (sz, 'any');
 a2 := make_array (sz, 'any');
 a3 := make_array (sz, 'any');
  for (i := 0; i < rounds; i := i + 1)
    {
      for (ctr := 0; ctr < sz; ctr := ctr + 1)
	{
	  a1[ctr] := rnd (10);
	  a2[ctr] := sequence_next ('tco2_co');
	  a3[ctr] := a1[ctr] + a2[ctr];
	}
      tco2ins (a1, a2);
      commit work;
    }
}


co2 (0, 10);


select top 10 * from tco2 a where not exists (select 1 from tco2 b table option (loop) where b.k1 = a.k1 and b.k2 = a.k2);
select top 10 * from tco2 a where not exists (select 1 from tco2 b where b.k1 = a.k1 and b.k2 = a.k2 and b.k1 + b.k2 = a.d);
select top 10 * from tco2 a where not exists (select 1 from tco2 b table option (loop) where b.k1 = a.k1 and b.k2 = a.k2 and b.k1 + b.k2 = a.d) ;


select top 20 a.k1, a.k2, b.k1, b.k2, b.d from tco2 a, tco2 b where a.k1 = b.k1 and a.k2 = b.k2 and a.k1 + 0 between 29 and 34 option (order, loop);

select top 60 a.k1, a.k2, b.k1, b.k2, b.d from tco2 a, tco2 b where a.k1 = b.k1 and a.k2 = b.k2 and a.k1 + 0 between 29 and 31  option (order, loop);

select top 100 * from tco2 a where k1 + 0 between 466 and 520 and not exists (select 1 from tco2 b where b.k1 = a.k1 and b.k2 = a.k2 + 1);

select b.k1, count (*) from (select distinct k1 from tco2) a, tco2 b where b.k1 = a.k1 / 2 group by b.k1 order by 1 option (loop, order);


select b.k1, b.k2, count (*) from tco2 a, tco2 b where a.k1 = b.k1 and a.k2 = b.k2 group by b.k1, b.k2 having count (*) > 1;


create table tcoa (k1 any, k2 any,
  primary key (k1, k2) column);


create procedure tcoains (in ak1 any array, in ak2 any array)
{
  log_enable (2, 1);
  for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into tcoa values (k1, k2);
    }
}

tcoains (vector (1, 2, 3, 4, 5, 6, 7, 8, 9, 10), vector ('aabb', 'aaxx', 'aabb', 'aabc', 'aazz', 'aabb', 'aamm', 'aamr'));

create procedure tcoa_str (in n int)
{
  return sprintf ('%16ld%16ld %200s', n, 1000000000000 - n, 'xx');
}

create procedure tcoa (in i1 int, in i2 int, in rl_len int := 12000, in is_str int := 0)
{
declare ak1, ak2 any array;
 declare i, len, ctr int;
 ctr := 0;
  len := i2 - i1;
 ak1 := make_array (len,  'any');
 ak2 := make_array (len, 'any');
  for (i := i1; i < i2; i := i + 1)
    {
      ak1[ctr] := 1 + (i / rl_len);
      ak2[ctr] := (i / 100) * 1000 + 2 * ctr;
      if (is_str)
	ak2[ctr] := tcoa_str (ak2[ctr]);
    ctr := ctr + 1;
    }
  tcoains (ak1, ak2);
}


create table tco3 (
  kf int, krld int, krow int, kd int, kd2 int,
  primary key (kf, krld, krow, kd, kd2) column);

--create index tco3r on tco3 (krow);
create column index tco3rc on tco3 (krow);


create procedure tco3 (in i1 int, in i2 int, in ck int := 0)
{
  declare c int;
  log_enable (0, 1);
  for (c:= i1; c < i2; c := c + 1)
    {
      insert into tco3 values (1 + (c / 1000), 3 * (c / 11), mod (c, 17), 15 - mod (c / 2, 13), c);
  if (ck and exists (select 1 from tco3 table option (index tco3) where kd > 20))
    return -c;
      if (ck and 0 <> (select count (*) from tco3 a table option (index tco3) where not exists (select 1 from tco3 b table option (loop, index tco3rc) where a.kf = b.kf and a.krld = b.krld and a.krow = b.krow and a.kd = b.kd and a.kd2 = b.kd2)))
      return c;
    }
}

select top 10 * from tco3 a table option (index tco3) where not exists (select 1 from tco3 b table option (loop, index tco3) where a.kf = b.kf and a.krld = b.krld and a.krow = b.krow and a.kd = b.kd and a.kd2 = b.kd2);
select top 10 * from tco3 a table option (index tco3rc) where not exists (select 1 from tco3 b table option (loop, index tco3rc) where a.kf = b.kf and a.krld = b.krld and a.krow = b.krow and a.kd = b.kd and a.kd2 = b.kd2);
select top 10 * from tco3 a table option (index tco3) where not exists (select 1 from tco3 b table option (loop, index tco3rc) where a.kf = b.kf and a.krld = b.krld and a.krow = b.krow and a.kd = b.kd and a.kd2 = b.kd2);
select top 10 * from tco3 a table option (index tco3rc) where not exists (select 1 from tco3 b table option (loop, index tco3) where a.kf = b.kf and a.krld = b.krld and a.krow = b.krow and a.kd = b.kd and a.kd2 = b.kd2);

o3 a where not exists (select 1 from tco3 b table option (loop) where a.kf = b.kf and a.krld = b.krld and a.krow = b.krow and a.kd = b.kd and a.kd2 = b.kd2);



create table tide (k1 int, d int, primary key (k1) column);

create procedure ftide (in i1 int, in i2 int)
{
declare c int;
log_enable (1, 0);
  for (c := i1;c < i2; c := c + 1)
    insert into tide values ((c / 10) * 100000 + 100 * c, mod (c, 7));
}


select top 10 * from tide a where not exists (select 1 from tide b where b.k1 = a.k1 and b.d = a.d);

select  k1, d from tide where d = 3 ;


create table tco4 (k1 any, k2 any, primary key (k1, k2) column);

create procedure  tco4 (in i1 int, in i2 int)
{
  declare c int;
  log_enable (0, 1);
  for (c :	= i1; c < i2; c := c + 1)
    {
      declare s2 any;
      declare r int;
    r := c / 1000;
    s2 := case when mod (r, 3) = 0 then 'fixed'|| cast (r as varchar) when mod (r, 3) = 1 then r else iri_id_from_num (r) end;
      insert into tco4 values (c, s2);
      insert into tco4 values ('st'|| cast (c as varchar),  s2);
      insert into tco4 values (iri_id_from_num (c),  s2);
    }
}

}

select top 10 * from tco4 a where not exists (select 1 from tco4 b table option (loop) where b.k1 = a.k1 and b.k2 = a.k2);


create procedure  tco4_1 (in i1 int, in i2 int)
{
  declare c int;
  log_enable (0, 1);
  for (c :	= i1; c < i2; c := c + 1)
    {
      declare s2 any;
      declare r int;
      insert into tco4 values ('xst'|| cast (c as varchar), 'tr' || cast (c / 7 as varchar));
      insert into tco4 values ('yst'|| cast (c / 7 as varchar), 'sr' || cast (c as varchar));
    }
}


create table tdt (k1 int, f real, d double precision, dt date, c varchar, i int,
  primary key (k1) column);


create procedure tdt (in i1 int, in i2 int)
{
  declare c int;
  log_enable (0, 1);
  for (c :	= i1; c < i2; c := c + 1)
    {
      insert into tdt (k1, f, d, dt, c, i)
 values (2 * c, C * 1000.5, c * 2000.5, dateadd ('day', 500 - mod (c, 1100), stringdate ('2010-1-1')),
  sprintf ('%d ---- %d ----', c, c), mod (c, 11));
    }
}


create table cnum (k1 int, num any, primary key (k1, num) column);
create column index num on cnum (num);

create procedure cnum (in i1 int, in i2 int)
{
  declare c, r int;
  randomize (11);
  log_enable (2, 1);
  for (c := i1; c < i2; c:=c+1)
    {
    r := rnd (16);
      insert into cnum values (c, r);
      insert into cnum values (c, cast (r as real) + 0.1);
      insert into cnum values (c, cast (r as double precision) + 0.01);
      insert into cnum values (c, cast (r as decimal) + 0.02);
    }
}


select top 10 k1, num from cnum a table option (index cnum) where not exists (select 1 from cnum b table option (loop, index num) where b.k1 = a.k1 and b.num = a.num);
select top 10 k1, num from cnum a table option (index num) where not exists (select 1 from cnum b table option (loop, index cnum) where b.k1 = a.k1 and b.num = a.num);


create table tco5 (krld1 int, krld2 int, kbm int, primary key (krld1, krld2, kbm) column);


create procedure tco5a (in k1 any array, in k2 any array, in k3 any array)
{
  for vectored (in i1 int := k1, in i2 int := k2, in i3 int := k3)
    {
      insert into tco5 values (i1, i2, i3);
    }
}


create procedure tco5 (in i1 int, in i2 int, in is_mod int := 0)
{
  declare k1, k2, k3 any;
  declare len,r, fill int;
 fill := 0;
 len := i2 - i1;
 k1 := make_array (len, 'any');
 k2 := make_array (len, 'any');
 k3 := make_array (len, 'any');
  for (r := i1; r < i2; r := r + 2)
    {
      k1[fill] := r;
      k1[fill + 1] := r;
      k2[fill] := r;
      k2[fill + 1] := r;
      if (is_mod < 0)
	{
	  k3[fill] := 100 * ((r / 100) + mod (r, -is_mod));
	  k3[fill + 1] := 100 * ((r / 100) + mod (r, -is_mod));
	}
      else if (is_mod)
	{
	  k3[fill] := 100 - mod (r, is_mod);
	  k3[fill + 1] := 100 - mod (r, is_mod);
	}
      else
	{
	  k3[fill] := r * 4;
	  k3[fill + 1] := 2 + r * 4;
	}
    fill := fill + 2;
    }
  tco5a (k1, k2, k3);
}



tco5 (2000, 4000);


tco5a (vector (3000, 3001, 3001, 3001), vector (3000, 3001, 3001, 3001), vector (12001, 12003, 12005, 12007));
tco5a (vector (3998, 3998), vector (3998, 3998), vector (4 * 3998 + 1, 4 * 3998 + 3));
tco5 (5000,  5050);
tco5 (3995, 4011);

tco5a (vector (5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001), vector (5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001, 5001),
       vector (1, 2, 3,4, 5, 6, 7, 8,9, 10, 11, 12, 13, 14, 15, 16, 17));

tco5a (vector (5038, 5039, 5041), vector (5039, 5039, 5039), vector (1, 2, 3));
tco5a (vector (3333, 3333), vector (3333, 3334), vector (4 * 3333, 2 + 4 * 3333));

tco5a (vector (4500, 4507, 4514, 4521, 4528), vector (4500, 4507, 4514, 4521, 4528), vector (1, 2, 3, 4, 5));
tco5 (20000, 23000);
tco5 (22991, 23031);

tco5a (vector (15001, 15001, 15001, 15001, 15001, 15001, 15002, 15002, 15002, 15002, 15002, 15002, 15002, 15002, 15002, 15002, 15002), vector (15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001, 15001),
       vector (1, 2, 3,4, 5, 6, 7, 8,9, 10, 11, 12, 13, 14, 15, 16, 17));

tco5a (vector (15001, 15001), vector (15001, 20000), vector (1000, 2000));

select count (*) from tco15 a where not exists (select 1 from tco15 b table option (loop) where a.krld1 = b.krld1 and a.krld2 = b.krld2 and a.kbm = b.kbm);

-- dict


tco5 (40000, 42000, 10);

tco5a (vector (41501, 41503, 41507), vector (41501, 41503, 41507), vector (100, 98, 96));



-- int delta

tco5 (50000, 60000, -5000);



tco5a (vector (50011, 50013, 50301, 50303), vector (50011, 50013, 50301, 50303),
       vector (50111, 50223, 50333, 50445));





create procedure ce_seq (in ce_type int, in nth int)
{
  -- Given a ce type and a sequence number of a value, return value such that the consecutive values make up a ce of the type
    -- 1. rl 2. bm 3. rld 4. dict 5 int delta 6 vec ;
  if (1 = ce_type)
    return mod (nth, 259);
  if (2 = ce_type)
    return 2 * mod (nth, 1000) + (2000 * (nth / 1000));
  if (3 = ce_type)
    return (2 * mod (nth, 1000) + (4000 * (nth / 1000))) / 2;
  if (4 = ce_type)
    return 100000 * (15 - mod (nth, 13)) + (nth / 300);
  if  (5 = ce_type)
    return nth * 500;
  if (6 = ce_type)
    return 1000000 * nth;
  signal ('xxxxx', 'bad ce type for ce_seq');
}


create procedure tco5_mix (in i1 int, in i2 int)
{
  declare k1, k2, k3 any;
  declare len,r, fill int;
 fill := 0;
 len := i2 - i1;
 k1 := make_array (len, 'any');
 k2 := make_array (len, 'any');
 k3 := make_array (len, 'any');
  for (r := i1; r < i2; r := r + 1)
    {
      k1[fill] := 1 + mod (r / 10000, 6);
      k2[fill] := ce_seq (mod (r / 10000, 6) + 1, r);
      k3[fill] := r;
    fill := fill + 1;
    }
  tco5a (k1, k2, k3);
}


create procedure tco5_mix_ins (in i1 int, in i2 int, in step int, in off2 int, in batch int, in last_off int)
{
  declare k1, k2, k3 any;
  declare len,r, fill int;
 fill := 0;
 len := (i2 - i1) / step;
 k1 := make_array (batch, 'any');
 k2 := make_array (batch, 'any');
 k3 := make_array (batch, 'any');
  for (r := i1; r < i2; r := r + step)
    {
      k1[fill] := 1 + mod (r / 10000, 6);
      k2[fill] := ce_seq (mod (r / 10000, 6) + 1, r) + off2;
      k3[fill] := r + last_off;
    fill := fill + 1;
      if (fill = batch)
	{
	  tco5a (k1, k2, k3);
	fill := 0;
	}
    }
}



tco5_mix (0, 60000);

tco5_mix_ins (0, 60000, step => 10, batch => 1, off2 => 0, last_off => 100000)




create table tdate (k1 int, k2 any, kd datetime,
  primary key (k1, k2) column);

create column index td on tdate (k2, k1);
-- create column index td_kd on tdate (kd);


create procedure tdatins (in ak1 any array, in ak2 any array)
{
  log_enable (2, 1);
  for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into tdate values (k1, k2, k2);
    }
}


create procedure tdate (in i1 int, in i2 int,
       in divisor int := 1, in date_offset int := 0)
{
declare ak1, ak2 any array;
 declare i, len, ctr int;
 ctr := 0;
  len := i2 - i1;
 ak1 := make_array (len,  'any');
 ak2 := make_array (len, 'any');
  for (i := i1; i < i2; i := i + 1)
    {
      ak1[ctr] := i / divisor;
      ak2[ctr] := dateadd ('day', date_offset + rnd (1500), cast ('2000-1-1' as date));
    ctr := ctr + 1;
    }
  tdatins (ak1, ak2);
}


-- tdate (0, 1000, divisor => 100000);
-- tdate (1000, 2000, divisor => 100000, date_offset => 2000);
-- insert into tdate values (0, cast ('1999-12-12 13:13' as datetime));

select count (*) from tdate a where not exists (select 1 from tdate b table option (loop) where b.k1 = a.k1 and b.k2 = a.k2);



create table tac (k1 any, k2 varchar, primary key (k1) column);
create column index tac_k2 on tac (k2);

create procedure tacins (in ak1 any array, in ak2 any array)
{
  log_enable (2, 1);
    for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into tac values (k1, k2);
    }
}

create procedure tac (in i1 int, in i2 int,
       in divisor int := 1, in date_offset int := 0)
{
declare ak1, ak2 any array;
 declare i, len, ctr int;
 ctr := 0;
  len := i2 - i1;
 ak1 := make_array (len,  'any');
 ak2 := make_array (len, 'any');
  for (i := i1; i < i2; i := i + 1)
    {
      ak1[ctr] := cast (i / divisor as varchar);
      ak2[ctr] := cast (i / divisor as varchar);
    ctr := ctr + 1;
    }
  tacins (ak1, ak2);
}

tac (10000, 20000, 0.5);


select count (*) from tac a, tac b where a.k1 = b.k1 and a.k2 like '%22%' option (order, loop);

select count (*) from tac a, tac b where b.k2 = a.k1 and a.k2 like '%22%' option (order, loop);

select count (*) from tac a, tac b where a.k1 = b.k2 and a.k2 like '%22%' option (order, loop);



create table tany (k1 any, k2 int, primary key (k1, k2) column);

create table tany_ref (k1 any, k2 int, primary key (k1, k2) not column);



create procedure any_item (in n int, in dtp int)
{
  if (246 = dtp)
    return rdf_box (0, 257, 257, n, 0);
  if (189 = dtp)
    return n;
  if (243 = dtp)
    return iri_id_from_num (n);
  if (182 = dtp)
    {
      declare str varchar;
      declare i int;
    str := '1234567890';
    i := length (str) - 1;

      while (n and i > 0)
	{
	  str[i] := n;
	i := i - 1;
	n := bit_shift (n, -8);
	}
      return str;
		   }
  if (181 = dtp)
    {
      declare str varchar;
      declare i int;
    str := '12';
    i := length (str) - 1;

      while (n and i > 0)
	{
	  str[i] := n;
	i := i - 1;
	n := bit_shift (n, -8);
	}
      return str;
		   }
  signal ('....', 'test not made for this dtp');
}


create procedure tany_ins (in start int, in n int, in step int, in dtp int)
{
  declare ctr int;
  for (ctr :=0; ctr < n; ctr := ctr + 1)
    {
      insert into tany values (any_item (start + ctr * step, dtp), ctr);
    }
}

create procedure tany_ins_vec (in start int, in n int, in step int, in dtp int)
{
  declare ctr int;
  declare v1, v2 any;
 v1 := make_array (n, 'any');
 v2 := make_array (n, 'any');

  for (ctr := 0; ctr < n; ctr := ctr + 1)
    {
      v1[ctr] := any_item (start + ctr * step, dtp);
      v2[ctr] := ctr;
    }
  for vectored (in a any := v1, in i int := v2)
		 {
		   insert into tany values (a, i);
		 }
}

tany_ins_vec (bit_shift (1, 31) - 10000, 200, 100, 246);

delete from tany;

tany_ins_vec (bit_shift (1, 31) - 10000, 90, 100, 246);
insert into tany values (any_item (bit_shift (1, 31) + 1, 246), 0);


select count (*) from tany a where not exists (select 1 from tany b table option (loop) where a.k1 = b.k1 and a.k2 = b.k2);



create table tco6 (krld1 int, kbm int, primary key (krld1, kbm) column);


create procedure tco6a (in k1 any array, in k2 any array)
{
  for vectored (in i1 int := k1, in i2 int := k2)
    {
      insert soft tco6 values (i1, i2);
    }
}


create procedure tco6 (in i1 int, in i2 int, in is_mod int := 0)
{
  declare k1, k2 any;
  declare len,r, fill int;
 fill := 0;
 len := i2 - i1;
 k1 := make_array (len, 'any');
 k2 := make_array (len, 'any');
  for (r := i1; r < i2; r := r + 1)
    {
      k1[fill] := r / 4;
      k2[fill] := r * 2;
    fill := fill + 1;
    }
  tco6a (k1, k2);
}




tco6 (0, 100000);
tco6a (vector (24998, 24999, 24999, 24999, 24999), vector (199989, 199980, 199981, 199982, 199983));


create procedure tco5end (in i1 int, in i2 int, in is_mod int := 0)
{
  declare k1, k2, k3 any;
  declare len,r, fill int;
 fill := 0;
 len := i2 - i1;
 k1 := make_array (len, 'any');
 k2 := make_array (len, 'any');
 k3 := make_array (len, 'any');
  for (r := i1; r < i2; r := r + 1)
    {
      k1[fill] := r / 4;
      k2[fill] := r / 2;
      k3[fill] := r * 4;
    fill := fill + 1;
    }
  tco5a (k1, k2, k3);
}

delete from tco5;

tco5end (0, 100000);

tco5a (vector (24998, 24999, 24999), vector ( 49998, 49990, 49991 ), vector ( 399976, 399979, 399989));



create table tch (k1 varchar, k2 varchar, primary key (k1, k2) column);



create procedure

create procedure
