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

-- use a local t1 or attach it from remote.  Use differentr sizes and run with or without row_no 100000.


create procedure ut1 (in n int)
{
  declare ctr int;
  for (ctr := 0; ctr < n; ctr := ctr + 1)
 	    update t1 set fi2 = fi2 + 1 where row_no = 100000;
}


create procedure ust1 (in n int, in len int := 10000)
{
  declare ctr int;
  declare str varchar;
  str := make_string (len);
  for (ctr := 0; ctr < n; ctr := ctr + 1)
     update t1 set fs4 = str, fi2 = fi2 + 1 where row_no = 100000;
}

