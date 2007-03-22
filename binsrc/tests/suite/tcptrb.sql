
---  Test checkpoint rollback.
--- init situation has T1 filled as ../ins 1111 100000 100
-- This relies on 2000 buffers in ini.


create table T2 (row_no int, string1 varchar, string2 varchar, epyter long varchar, fs1 varchar, primary key (row_no));
alter table T1 add lst varchar;


set autocommit manual;
update T1 set lst = 'parashakti aum' || cast (row_no as varchar) where row_no between 50000 and 55000 and mod (row_no, 10) = 5;
update t1 set fs5 = make_string (mod (row_no, 14)) where row_no < 40000; 
delete from t1 where row_no < 10000;
insert into t2 (row_no, string1, string2) select row_no, string1, string2 from t1 where row_no < 60000;

delete from T1 where row_no > 60000 and mod (row_no, 20) = 0;
echo both $if $equ $rowcnt 2004 "PASSED" "***FAILED";
echo both ": count of deld pre cpt where ropw_no mod 20 = 0.\n";


update t1 set fs5 = 'que pasa' where  row_no > 70000 and mod (row_no, 20) = 2;
echo both $if $equ $rowcnt 1505 "PASSED" "***FAILED";
echo both ": rows in pre cpt update.\n";

select fs5 from t1 where row_no between 90000 and 90010 for update;


update T2 set epyter = make_string (1000) where row_no between 55000 and 55500;
update t2 set epyter = make_string (100000) where row_no = 56000;
update t2 set epyter = make_string (200000) where row_no = 56000;


checkpoint &
wait_for_children;

select count (*) from t1 where length (fs5) < 5;
echo both $if $equ $last[1] 10713 "PASSED" "***FAILED";
echo both ": len fs5 < 5 in t1 before cpt\n";

select count (*) from t1;
echo both $if $equ $last[1] 88096 "PASSED" "***FAILED";
echo both ": count of T1 pre cpt\n";

select count (*) from t2;
echo both $if $equ $last[1] 50000 "PASSED" "***FAILED";
echo both ": count of T2 pre chpt.\n";


