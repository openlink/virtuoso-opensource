

-- Now the cpt rollback has checkpointed a virgin T1 on ins 1111 100000 100.


backup '/dev/null';


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

vacuum ();
checkpoint;
vacuum ();


select count (*) from t2;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": 0 in T2 after insert, cpt and rb of insert.\n";

update t1 set fi2 = fi2 + 1; 
checkpoint;
-- now the idea is that a good number of t1 main row pages will have checkpoint remap.


set autocommit manual;

update t1 set fi2 = fi2 + row_no;

checkpoint &
wait_for_children;

select count (distinct fi2) from t1;
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": distinct fi2 after update 100000.\n";

rollback work;


select count (distinct fi2) from t1;
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": distinct fi2 after rb of update 1.\n";


checkpoint;
drop table t1;
drop table t2;
shutdown;




