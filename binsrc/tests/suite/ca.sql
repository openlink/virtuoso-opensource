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

-- test cpu cache  effect on join


create table ct (k1 bigint primary key, k2 bigint not null);
alter index ct on ct partition cluster ELASTIC (K1 int (0hexffff00));

create table ct_c (k1 bigint, k2 bigint not null, primary key (k1) column);
alter index ct_c on ct_c partition cluster ELASTIC (K1 int (0hexffff00));



create procedure ctf (in q int)
{
  declare i int;
  for  (i := 0; i < q; i := i + 1)
   insert into ct values (i, rnd (q));
}



create procedure ct_ins (inout ak1 any array, inout ak2 any array)
{
  log_enable (2, 1);
  for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into ct values (k1, k2);
    }
}


create procedure ct_c_ins (inout ak1 any array, inout ak2 any array)
{
  log_enable (2, 1);
  for vectored (in k1 any := ak1, in k2 any := ak2)
    {
      insert into ct_c values (k1, k2);
    }
}


create procedure ct_load (in rounds int, in sz int, in is_col int)
{
  set non_txn_insert = 1;
  declare ctr, i int;
  declare a1, a2 any array;
 a1 := make_array (sz, 'any');
 a2 := make_array (sz, 'any');
  for (i := 0; i < rounds; i := i + 1)
    {
      for (ctr := 0; ctr < sz; ctr := ctr + 1)
        {
          a1[ctr] := i * sz + ctr;
          a2[ctr] := rnd (rounds * sz);
        }
      if (is_col)
        ct_c_ins (a1, a2);
      else
        ct_ins (a1, a2);
      commit work;
    }
}


-- init
-- ct_load (4000, 10000, 0);
-- ct_load (4000, 10000, 1);

set u{tb} = "ct";



echo both "Single thread rows\n";
__dbf_set ('enable_qp', 1);
load ca2.sql;

echo both "8 thread rows\n";
__dbf_set ('enable_qp', 8);
load ca2.sql;


echo both "16 thread rows\n";
__dbf_set ('enable_qp', 16);
load ca2.sql;



set u{tb} = "ct_c";



echo both "Single thread columns\n";
__dbf_set ('enable_qp', 1);
load ca2.sql;

echo both "8 thread columns\n";
__dbf_set ('enable_qp', 8);
load ca2.sql;


echo both "16 thread columns\n";
__dbf_set ('enable_qp', 16);
load ca2.sql;



