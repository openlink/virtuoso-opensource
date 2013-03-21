
---  Test checkpoint rollback.
--- init situation has T1 filled as ../ins 1111 100000 100
-- This relies on 2000 buffers in ini.


create table T2 (row_no int, string1 varchar, string2 varchar, epyter long varchar, fs1 varchar, primary key (row_no));
alter table T1 add lst varchar;

create procedure str2ck (in use_rc int := 0)
{
  if (use_rc)
    {
      set isolation = 'committed';
    }
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
ECHO BOTH "done str2ck 1\n";

delete from t1 where row_no < 10000;
str2ck ();
ECHO BOTH "done str2ck 2\n";

insert into t2 (row_no, string1, string2) select row_no, string1, string2 from t1 where row_no < 60000;
str2ck ();
ECHO BOTH "done str2ck 3\n";

delete from T1 where row_no > 60000 and mod (row_no, 20) = 0;
ECHO BOTH $IF $EQU $ROWCNT 2004 "PASSED" "***FAILED";
ECHO BOTH ": count of deld pre cpt where ropw_no mod 20 = 0.\n";

str2ck ();
ECHO BOTH "Done str2ck 3\n";

update t1 set fs5 = 'que pasa' where  row_no > 70000 and mod (row_no, 20) = 2;
ECHO BOTH $IF $EQU $ROWCNT 1505 "PASSED" "***FAILED";
ECHO BOTH ": rows in pre cpt update.\n";

select fs5 from t1 where row_no between 90000 and 90010 for update;


update T2 set epyter = make_string (1000) where row_no between 55000 and 55500;
update t2 set epyter = make_string (100000) where row_no = 56000;
update t2 set epyter = make_string (200000) where row_no = 56000;

ECHO BOTH "cpt intermediate\n";
checkpoint &
wait_for_children;


str2ck ();
ECHO BOTH "done str2ck 4\n";

load tcptrbck.sql &
wait_for_children;
ECHO BOTH "done history str2ck 1\n";

checkpoint &
wait_for_children;

load tcptrbck.sql &
wait_for_children;
ECHO BOTH "done history str2ck 2\n";

str2ck ();
ECHO BOTH "done str2ck 5\n";

select count (*) from t1 where length (fs5) < 5;
ECHO BOTH $IF $EQU $LAST[1] 10713 "PASSED" "***FAILED";
ECHO BOTH ": len fs5 < 5 in t1 before cpt\n";

select count (*) from t1;
ECHO BOTH $IF $EQU $LAST[1] 88096 "PASSED" "***FAILED";
ECHO BOTH ": count of T1 pre cpt\n";

select count (*) from t2;
ECHO BOTH $IF $EQU $LAST[1] 50000 "PASSED" "***FAILED";
ECHO BOTH ": count of T2 pre chpt.\n";
