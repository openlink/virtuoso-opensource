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

create table ot (o any primary key);
alter index ot on ot partition (o varchar (-1, 0hexffff));

insert into ot values (22);
insert into ot values (cast (22 as decimal));
insert into ot values (rdf_box (cast (22 as decimal), 257, 257, 0, 1));


insert into ot values (stringdate ('2001-1-1'));
insert into ot values (rdf_box (stringdate ('2001-1-1'), 257, 257, 0, 1));

select * from ot;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": rows in ot after non-unq inserts with different dtps and rdf boxes\n";


