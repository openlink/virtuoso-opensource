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


set autocommit manual;
tco3 (1, 10);

rollback work;



set autocommit manual;
tco3 (1000, 4000);
delete from tco3 where kf = 3;
select count (*) from tco3;
echo both $if $equ $last[1] 2000 "PASSED"  "***FAILED";
echo both ": del after ins\n";

tco3 (2000, 2500);
commit work;

select count (*) from tco3;
echo both $if $equ $last[1] 2500 "PASSED"  "***FAILED";
echo both ": del after ins\n";




tco3 (0, 4000);

select * from tco3 table option (index tco3) where kf =1 and krld = 160;
echo both $if $equ $rowcnt 0 "PASSED" "***FAOI:FAILED";
echo both ":  non ext rld \n";

insert into tco3 (kf, krld, krow, kd, kd2) values (2, 100, 0, 0, 0);


tcoa (0, 50000);
tcoains (vector (1, 1, 1, 1), vector (1190, 1192, 1193, 1194));
tcoains (vector (5,5,5,5),  vector (592817, #i1, #i2, #i3));
select top 10 * from tcoa a where not exists (select 1 from tcoa b table option (loop) where a.k1 = b.k1 and a.k2 = b.k2);

tcoa (60000, 70000, 20);

tcoains (vector (3001, 3002, 3003), vector (600033 , 'str', #i1));


tcoa (1000000, 1000100, 1000, 1)tcoa (2000000000, 2000000100, 1000, 1);
tcoa (2000000, 3000000, 1000, 1);

tcoa (4000000, 5000000, 1000, 1);
checkpoint;
tcoa (3000000, 3003000, 1000, 1);


checkpoint;
delete from tcoa;



tcoa (1000, 5000, 1000, 1);
tcoa (10000, 15000, 1000, 1);
tcoa (100000, 1000000, 1000, 1);
checkpoint;
tcoa (5000, 6000, 1000, 1);
select count (*) from tcoa a where not exists (select 1 from tcoa b table option (loop) where a.k1 = b.k1 and a.k2 = b.k2);

checkpoint;




create table c_upd (k1 int, k2 varchar, d1 int, d2 varchar, d3 varchar, b1 long varchar, primary key (k1, k2) column);
