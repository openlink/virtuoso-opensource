





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

