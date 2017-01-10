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

---  Test checkpoint rollback.
--- init situation has T1 filled as ../ins 1111 100000 100



create table T2 (row_no int, string1 varchar, string2 varchar, epyter long varchar, fs1 varchar, primary key (row_no));
alter table T1 add lst varchar;

create procedure str2ck (in use_rc int := 0)
{
  if (use_rc)
    {
      set isolation = 'committed';
    }
  else
    set isolation = 'serializable';
  if ((select count (*) from t1) <> (select count (*) from t1 a where exists (select 1 from t1 b table option (loop, index str2) where b.string2 = a.string2 and b.row_no = a.row_no) ))
 signal ('str2w', 'string2 inx out of whack');
  if ((select count (*) from t1) <> (select count (*) from t1 a where exists (select 1 from t1 b table option (loop, index str1) where b.string1 = a.string1 and b.row_no = a.row_no) ))
 signal ('str1w', 'string1 inx out of whack');
  if ((select count (*) from t1) <> (select count (*) from t1 a where exists (select 1 from t1 b table option (loop, index time1) where b.time1 = a.time1 and b.row_no = a.row_no) ))
 signal ('tim1w', 'time1 inx out of whack');
}


set autocommit manual;
update T1 set lst = 'parashakti aum' || cast (row_no as varchar) where row_no between 50000 and 55000 and mod (row_no, 10) = 5;
update t1 set fs5 = make_string (mod (row_no, 14)) where row_no < 40000;
str2ck ();
echo both "done str2ck 1\n";

str2ck (1) &
str2ck (1);
wait_for_children;
echo both "done str2ck1-1 rc\n";

delete from t1 where row_no < 10000;
str2ck ();
echo both "done str2ck 2\n";

insert into t2 (row_no, string1, string2) select row_no, string1, string2 from t1 where row_no < 60000;
str2ck (1);
echo both "done str2ck 3\n";

delete from T1 where row_no > 60000 and mod (row_no, 20) = 0;
echo both $if $equ $rowcnt 2004 "PASSED" "***FAILED";
echo both ": count of deld pre cpt where ropw_no mod 20 = 0.\n";

str2ck ();
echo both "Done str2ck 3\n";

update t1 set fs5 = 'que pasa' where  row_no > 70000 and mod (row_no, 20) = 2;
echo both $if $equ $rowcnt 1505 "PASSED" "***FAILED";
echo both ": rows in pre cpt update.\n";

select fs5 from t1 where row_no between 90000 and 90010 for update;


update T2 set epyter = make_string (1000) where row_no between 55000 and 55500;
update t2 set epyter = make_string (100000) where row_no = 56000;
update t2 set epyter = make_string (200000) where row_no = 56000;

echo both "cpt intermediate\n";
checkpoint &
wait_for_children;

select top 10 row_no from t1 a table option (index time1) where not exists (select 1 from t1 b table option (loop, index t1) where a.row_no = b.row_no and a.time1 = b.time1);

str2ck ();
echo both "done str2ck 4\n";

load tcptrbck.sql &
wait_for_children;
echo both "done history str2ck 1\n";

checkpoint &
wait_for_children;

load tcptrbck.sql &
wait_for_children;
echo both "done history str2ck 2\n";

str2ck ();
echo both "done str2ck 5\n";

select count (*) from t1 where length (fs5) < 5;
echo both $if $equ $last[1] 10713 "PASSED" "***FAILED";
echo both ": len fs5 < 5 in t1 before cpt\n";

select count (*) from t1;
echo both $if $equ $last[1] 88096 "PASSED" "***FAILED";
echo both ": count of T1 pre cpt\n";

select count (*) from t2;
echo both $if $equ $last[1] 50000 "PASSED" "***FAILED";
echo both ": count of T2 pre chpt.\n";


