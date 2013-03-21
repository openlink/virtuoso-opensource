backup '/dev/null';

select * from T2;
ECHO BOTH $IF $EQU $ROWCNT 50  "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT" rows in t2 after cpt recov\n";

insert into T2 (row_no) values (1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": insert on place of existing STATE=" $STATE " MESSAGE=" $MESSAGE " \n";

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

checkpoint;
--drop table t1;
--drop table t2;
shutdown;
