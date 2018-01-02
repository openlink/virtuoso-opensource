--
--  tnum.sql
--
--  $Id: tnum.sql,v 1.4.10.1 2013/01/02 16:15:14 source Exp $
--
--  Number tests
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

create procedure rnd_cast (in r numeric)
{
  declare f integer;
  f := rnd (4);
  if (f = 0)
    r := r;
  else if (f = 1)
    r := cast (r as real);
  else if (f = 2)
    r := cast (r as double precision);
  else
    r := cast (r as decimal (20, 2));
  return r;
}

create procedure tfill (in n integer)
{
  declare f, r, i  integer;
  i := 0;
  while (i < n) {
    r := rnd (990000000);
    f := rnd (4);
    if (f = 0)
      r := r;
    else if (f = 1)
      r := cast (r as real);
    else if (f = 2)
      r := cast (r as double precision);
    else
      r := cast (r as decimal (20, 2));
    insert into n_inx (id, dec, i, f, d)
      values (r, r, rnd_cast (rnd (10000)), rnd_cast (rnd (10000)), rnd_cast (rnd (10000)));
    i := i + 1;
  }
}

tfill (200);

select * from n_inx a where not exists (select 1 from n_inx b where b.id = a.id and b.serial = a.serial);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows where n <> n\n";

select * from n_inx a where cast (cast (dec as varchar) as decimal) <> dec;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows where n as varchar as decimal <> n\n";

select * from n_inx where id <> dec or dec <> id;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows where id <> dec\n";


create procedure inx_order (in q integer)
{
  declare prev, n varchar;
  declare cr cursor for select id from n_inx;
  open cr;
  prev := null;
  while (1) {
    fetch cr into n;
    if (prev <> null)
      if (n < prev)
	signal ('ORDER', 'bad sort order');
    prev := n;
  }
}

inx_order (0);

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": " $STATE " on index order\n";


create procedure add_test (in q integer)
{
  declare x, y, i integer;
  declare x1, y1 decimal;
  result_names (x, y, x1, y1, x, y);
  i := 0;
  while (i < q) {
    i := i + 1;
    x := rnd (10000);
    y := rnd (10000);
    if (x + y <> (x1 := rnd_cast (x)) + (y1 := rnd_cast (y)))
      result (x, y, x1, y1, __tag (x1), __tag (y1));
  }
}

add_test (1000);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " bad casts in addition\n";


select cast ('111111.1111' as decimal (3, 1)) from sys_users;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": State " $STATE " For truncate overflow\n";
