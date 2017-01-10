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


-- Now the cpt rollback has checkpointed a virgin T1 on ins 1111 100000 100.


backup '/dev/null';


str2ck ();
echo both "Done str2ck 1\n";

select count (*) from t1;
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": OK count of T1 after cpt rb and restart.\n";

select count (distinct length (fs5)) from t1;
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": distinct lengths of fs5 after cpt rb and restart.\n";

select count (*) from t2;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": empty T2 after cpt rollback.\n";

select count (*) from t2 where row_no = 11111;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": empty T2 after cpt rollback 2.\n";

set autocommit manual;
insert into t2 (row_no, string1, string2) select row_no, string1, string2 from t1 where row_no < 60000;
select  count (*) from t2;
echo both $if $equ $last[1] 59900 "PASSED" "***FAILED\n";
echo both ": Inserted into t2 with empty pages after cpt rollback.\n";

checkpoint &
wait_for_children;

rollback work;
str2ck ();
echo both "Done str2ck 2\n";

vacuum ();
checkpoint;
str2ck ();
echo both "Done str2ck 3\n";

vacuum ();
str2ck ();
echo both "Done str2ck 4\n";


select count (*) from t2;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": 0 in T2 after insert, cpt and rb of insert.\n";

update t1 set fi2 = fi2 + 1;
str2ck ();
echo both "Done str2ck 5\n";

checkpoint;
-- now the idea is that a good number of t1 main row pages will have checkpoint remap.

str2ck ();
echo both "Done str2ck 6\n";

set autocommit manual;

update t1 set fi2 = fi2 + row_no;

checkpoint &
wait_for_children;

str2ck();
echo both "Done str2ck 7\n";


select count (distinct fi2) from t1;
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": distinct fi2 after update 100000.\n";

rollback work;

str2ck();
echo both "Done str2ck 8\n";

select count (distinct fi2) from t1;
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": distinct fi2 after rb of update 1.\n";


checkpoint;
str2ck();
echo both "Done str2ck 9\n";

load tcptrb3.sql;

drop
table t1;
drop table t2;
shutdown;




