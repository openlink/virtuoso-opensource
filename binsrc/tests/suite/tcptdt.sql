create table T2 as select * from T1 where ROW_NO <= 100 with data;
alter table T2 modify primary key (row_no);
alter table T1 add lst varchar;


create table T3 as select * from T1 where ROW_NO <= 100 with data;
alter table T3 modify primary key (row_no);


select count (*) from T1;
ECHO BOTH $IF $EQU $LAST[1] 100000  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows loaded in t1\n";

select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 100  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows copied in t2\n";


checkpoint;

update t1 set fi2 = 1.0 where row_no < 50001;
update t1 set fi2 = 2.0 where row_no > 50000;

update T1 set lst = 'parashakti aum' || cast (row_no as varchar) where row_no between 50000 and 55000 and mod (row_no, 10) = 5;
update t1 set fs5 = make_string (mod (row_no, 14)) where row_no < 40000;
delete from t1 where row_no <= 10000; -- 90000 left

select * from T1;
ECHO BOTH $IF $EQU $ROWCNT 90000  "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT" rows in t1 after cpt recov\n";

select count (distinct length (fs5)) from t1;
ECHO BOTH $if $equ $last[1] 15 "PASSED" "***FAILED";
ECHO BOTH ": " $last[1] " distinct lengths of fs5 after cpt rb and restart.\n";

select count (distinct fi2) from t1;
ECHO BOTH $if $equ $last[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $last[1] " distinct numbers in fi2 after cpt rb and restart.\n";

select distinct fs5 from t1 where row_no > 70000 and mod (row_no, 20) = 2;
ECHO BOTH $if $equ $rowcnt 1 "PASSED" "***FAILED";
ECHO BOTH ": " $rowcnt " rows in pre cpt update.\n";

delete from T2 where ROW_NO > 50; -- 50 left

set autocommit manual;

delete from T2 where ROW_NO <= 50; -- empty

delete from T1 where row_no > 60000 and mod (row_no, 20) = 0;
ECHO BOTH $if $equ $rowcnt 2000 "PASSED" "***FAILED";
ECHO BOTH ": count of deld pre cpt rows=" $rowcnt " where ropw_no mod 20 = 0.\n";

update t1 set fs5 = 'que pasa' where  row_no > 70000 and mod (row_no, 20) = 2;
ECHO BOTH $if $equ $rowcnt 1500 "PASSED" "***FAILED";
ECHO BOTH ": " $rowcnt " rows in pre cpt update.\n";

delete from T1 where row_no > 90000; -- 78000 left

insert into T1 (row_no) values (1); -- 80001 left

select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": all rows deleted\n";

-- make committed pages with no cpt space counterpart and have uyncommitted delta on them.
insert into t3 (row_no, fs4) select row_no, fs4 from t1 where row_no > 10000;
update t3 set fi2 = row_no where row_no < 40000;

ECHO BOTH " will stop server in mid of cpt with __stop_cpt (" $U{FLAG} ") \n";

__stop_cpt ($U{FLAG});
checkpoint &
WAIT_FOR_CHILDREN;
exit;
