

-- test all combinations of inlined dt's in froms and in join exps 

ECHO BOTH "Different dt inlining in join exps tjoin2.sql\n";

select count (*) from (select row_no as s from t1) f;

select count (*) from (select a.row_no + b.row_no as s from t1 a, t1 b where b.row_no = a.row_no + 1) f;

select count (*) from (select b.row_no  from t1 a, t1 b where b.row_no = a.row_no + 1) f inner join t1 c on c.row_no = f.row_no + 1;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": dt inline inner 1 \n";

select count (*) from (select b.row_no  from t1 a join t1 b on b.row_no = a.row_no + 1) f inner join t1 c on c.row_no = f.row_no + 1;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": dt inline inner 2 \n";



select count (*) from (select b.row_no  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join t1 c on c.row_no = f.row_no + 1;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer 1\n";


select count (*) from (select b.row_no  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (select c.row_no from t1 c) g on g.row_no = f.row_no + 1;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer single\n";

select count (f.r1), count (f.r2), count (g.r1), count (g.r2) from (select a.row_no as r1, b.row_no as r2  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (select c.row_no as r1, d.row_no as r2 from t1 c join t1 d on d.row_no = c.row_no + 1) g on g.r1 = f.r2 + 1;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer dt 1\n";
ECHO BOTH $IF $EQU $LAST[4] 17 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer dt2\n";


select count (f.r1), count (f.r2), count (g.r1), count (g.r2) from (select a.row_no as r1, b.row_no as r2  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (select * from (select c.row_no as r1, d.row_no as r2 from t1 c join t1 d on d.row_no = c.row_no + 1) gp) g on g.r1 = f.r2 + 1;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer dbl dt 1\n";
ECHO BOTH $IF $EQU $LAST[4] 17 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer dbl dt2\n";


select count (f.r1), count (f.r2), count (c.row_no), count (d.row_no) from (select a.row_no as r1, b.row_no as r2  from t1 a left join t1 b on b.row_no = a.row_no + 1) f left join (t1 c join t1 d on d.row_no = c.row_no + 1) on c.row_no = f.r2 + 1;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer outer join exp 1\n";
ECHO BOTH $IF $EQU $LAST[4] 17 "PASSED" "***FAILED";
ECHO BOTH ": dt inline outer join exp 2\n";
