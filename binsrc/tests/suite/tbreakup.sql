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

select * from (select breakup (row_no, fi2) (row_no, fi3) from r1..t1 where row_no <10)f;
echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
echo both ": remote breakup no cond\n";

select * from (select breakup (row_no, fi2) (row_no, fi3 where fi3 = 3333) from r1..t1 where row_no <10)f;
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": remote breakup false cond\n";

select * from (select breakup (row_no, fi2) (row_no, fi3 where fi3 is null) from r1..t1 where row_no <10)f;
echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
echo both ": remote breakup true cond\n";


select * from (select breakup (a.row_no, b.fi2) (b.row_no, a.fi3 where a.fi3 is null) from r1..t1 a, r1..t1 b where a.row_no <10 and b.row_no = a.row_no)f;
echo both $if $equ $rowcnt 20 "PASSED" "***FAILED";
echo both ": remote join breakup true cond\n";


select * from (select breakup (a.row_no, b.fi2) (b.row_no, a.fi3 where a.fi3 is null) from r1..t1 a, r1..t1 b where a.row_no <10 and b.row_no = a.row_no union select breakup (a.row_no, b.fi2) (b.row_no, a.fi3 where a.fi3 is null) from r1..t1 a, r1..t1 b where a.row_no <15 and b.row_no = a.row_no)f;
echo both $if $equ $rowcnt 30 "PASSED" "***FAILED";
echo both ": union remote join breakup true cond\n";


select * from (select breakup (a.row_no, b.fi2) (b.row_no, a.fi3 where a.fi3 is null) from r1..t1 a, r1..t1 b where a.row_no <10 and b.row_no = a.row_no union all select breakup (a.row_no, b.fi2) (b.row_no, a.fi3 where a.fi3 is null) from r1..t1 a, r1..t1 b where a.row_no <15 and b.row_no = a.row_no)f;
echo both $if $equ $rowcnt 50 "PASSED" "***FAILED";
echo both ": union all remote join breakup true cond\n";

