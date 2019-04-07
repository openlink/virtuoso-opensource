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

create table bint (bi bigint, i int, primary key (bi, i));

insert into bint values ('5000000000', 11);

insert into bint values (1000000 * 1000000, 12);

select * from bint a, bint b where a.bi = b.bi option (hash);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": hash join of bigint\n";

select * from bint order by bi + 1;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": oby bigint col\n";


select * from bint order by i + 10000000000;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": oby large int exp\n";
