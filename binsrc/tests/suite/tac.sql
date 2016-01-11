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


-- autocompact

echo both "Autocompact and vacuum test\n";


create table tac (s varchar primary key, d varchar);

create procedure tac_fill (in n1 int, in n2 int)
{
  declare i int;
  for (i:= n1; i < n2; i := i + 1)
    insert into tac values (cast (i as varchar) || make_string (900), cast (i as varchar));
}


tac_fill (0, 10);
delete from tac where atoi (s) > 3;
autocompact ();

echo both "tac 1\n";

delete from tac;
tac_fill (0, 10);
delete from tac where atoi (s) > 3 and atoi (s) < 9;
autocompact ();
echo both "tac 2\n";


delete from tac;
tac_fill (1, 10);
delete from tac where atoi (s) > 3 and atoi (s) < 9;
vacuum ('DB.DBA.TAC');
echo both "tac 3\n";

delete from tac;
tac_fill (0, 1000);
delete from tac where atoi (s) > 500 and mod (atoi (s), 10) <> 0;
autocompact ();
echo both "tac 4\n";


delete from tac;
tac_fill (0, 1000);
delete from tac where atoi (s) > 500 and mod (atoi (s), 10) <> 0;
vacuum ('DB.DBA.TAC');
vacuum ('DB.DBA.TAC');
vacuum ('DB.DBA.TAC');
vacuum ('DB.DBA.TAC');
echo both "tac 5\n";

