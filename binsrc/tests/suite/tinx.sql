--
--  $Id: tinx.sql,v 1.3.10.1 2013/01/02 16:15:11 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
drop table tinx;

create table tinx (k1 int, k2 varchar, k3 int, d1 varchar,
	row_no int primary key);

create index tinx3 on tinx (k1, k2, k3, d1);
create index tinx2 on tinx (k3, k2, k1, d1);

create procedure tinx_fill (in n1 int, in n2 int, in n3 int)
{
  declare i1, i2, i3, n int;
  n := 0;
  for (i1 := 0; i1 < n1; i1 := i1 + 1)
    {
      for (i2 := 0; i2 < n2; i2 := i2 + 1)
	{
	  for (i3 := 0; i3 < n3; i3 := i3 + 1)
	    {
	      insert into tinx (k1, k2, k3, d1, row_no) values (i1, i2, i3, sprintf (' xx %d %d %d xxxxxxxxxxx', i1, i2, i3), n);
	      n := n + 1;
	    }
	}
    }
}



tinx_fill (10, 10, 10);

update tinx set k1 = null where row_no < 500;

select k1, k2, k3 from tinx where k1> 3;
echo both $if $equ $rowcnt 500 "PASSED" "**FAILED";
echo both " tinx k1 > 3 " $rowcnt " rows\n";

select k1, k2, k3 from tinx where k1> 3 order by k1 desc;
echo both $if $equ $rowcnt 500 "PASSED" "**FAILED";
echo both " tinx k1 > 3 " $rowcnt " rows\n";

update tinx set k1 = row_no / 100;

select k1, k2, k3 from tinx where k1 < 3;
echo both $if $equ $rowcnt 300 "PASSED" "**FAILED";
echo both " tinx k1 < 3  " $rowcnt " rows\n";


select k1, k2, k3 from tinx where k1 < 3 order by k1 desc;
echo both $if $equ $rowcnt 300 "PASSED" "**FAILED";
echo both " tinx k1 < 3  " $rowcnt " rows\n";

delete from tinx;

tinx_fill (10, 10, 10);
update tinx set k1 = null where row_no < 495;
select k1, k2, k3 from tinx where k1 < 7;
echo both $if $equ $rowcnt 205 "PASSED" "**FAILED";
echo both " tinx k1 < 7 " $rowcnt " rows\n";

select k1, k2, k3 from tinx where k1 < 7 order by k1 desc;
echo both $if $equ $rowcnt 205 "PASSED" "**FAILED";
echo both " tinx k1 < 7 " $rowcnt " rows\n";




