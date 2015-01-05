--
--  tbin.sql
--
--  $Id$
--
--  Test distinct varbinary and varchar
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

drop table tbin;

create table tbin (id integer, kb varbinary (20), kc varchar);

create index kb on tbin (kb);
create index kc on tbin (kc);

create procedure n_identity (in n varchar)
{
  return n;
}

create procedure rndstr (in len integer)
{
  declare i integer;
  declare str varchar;
  str := make_string (len);
  while (i < len) {
    aset (str, i, 32 + rnd (120));
    i := i + 1;
  }
  return str;
}


create procedure tbin_fill (in n integer)
{
  declare str varchar;
  declare i integer;
  i := 0;
  while (i < n) {
    str := cast (i as varchar);
    if (rnd (10) = 5)
      str := concat (rndstr (250 + rnd (20)), str);

    insert into tbin (id, kb, kc)
      values (i, cast (str as varbinary (200)), str);
    i := i + 1;
  }
}

tbin_fill (1000);

select count (distinct kb) from tbin;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " distinct bin\n";

insert into tbin (id, kb) select id + 1000, kc from tbin where id < 1000;

select count (distinct kb) from tbin;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " distinct bin + varchar\n";

select count (distinct cast (kb as varchar)) from tbin;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " distinct cast to varchar\n";
