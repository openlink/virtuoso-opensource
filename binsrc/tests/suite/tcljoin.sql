
-- Test cluster outer join and quietcast and nulls
-- test batched dt, subquery, existence 

-- suppose start state of ins 1111 100 20

update t1 set fi2 = row_no, fi3 = row_no;

create index fi2 on t1 (fi2) partition (fi2 int);
create unique index fi3 on t1 (fi3) partition (fi3 int);

ECHO BOTH "Cluster outer join\n";


insert into t1 (row_no, fi2, string1) values (121, 121, '121');
__dbf_set ('cl_req_batch_size', 5);

select a.fi2, b.fi2 from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 1: " $ROWCNT " rows\n";


select count (a.fi2), count (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $LAST[2] 5 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2\n";

-- f is a colocation sequence break because of id to iri.  f_pass is safely colocatable 
create procedure f (in q any) { id_to_iri (#i100); return q;};
create procedure f_pass (in q any) { return q;};

select f (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 and b.fi2 - b.fi2 = 0 option (loop, any order);
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": outer dfg with after join test\n";

select f (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 and b.fi2 - b.fi2 = 0 option (loop);
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": outer dfg with after join test\n";


select count (a.fi2), count (f (b.fi2)) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2\n";

ECHO BOTH $IF $EQU $LAST[2] 5 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2\n";


select count (a.fi2), count (b.fi2) from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 3-1\n";
ECHO BOTH $IF $EQU $LAST[2] 5 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 3-2\n";



select a.fi2, b.fi2, b.string1  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key 1: " $ROWCNT " rows\n";



select count (a.fi2), count (b.fi2), count (b.string1)  from t1 a left join t1 b on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key 3-1\n";
ECHO BOTH $IF $EQU $LAST[2] 5 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key 3-2\n";


select count (a.fi2), count (b.fi2), count (b.string1)  from t1 a left join t1 b table option (index t1) on b.fi2 = a.fi2 + 5 where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj flood key 1-1\n";
ECHO BOTH $IF $EQU $LAST[2] 5 "PASSED" "***FAILED";
ECHO BOTH ": cl oj flood join key 1-2\n";



select a.fi2, b.fi2, b.string1  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (a.fi2 + 5, a.fi2 + 6)  where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $ROWCNT 13 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key in pred 1: " $ROWCNT " rows\n";


select a.fi2, b.fi2, b.string1  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (sprintf ('bad%d', a.fi2 + 5), a.fi2 + 6)  where a.fi2 > 110 option (loop, quietcast);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key quietcast in pred 1: " $ROWCNT " rows\n";


select a.fi2, b.fi2  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (sprintf ('bad%d', a.fi2 + 5), a.fi2 + 6)  where a.fi2 > 110 option (loop, quietcast);



select a.fi2, b.fi2  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 = sprintf ('bad%d', a.fi2 + 5)  where a.fi2 > 110 option (loop, quietcast);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 1st  key quietcast in pred 1: " $ROWCNT " rows\n";


select count (a.fi2), count (b.fi2), count (b.string1)  from t1 a left join t1 b table option (loop, index fi2) on b.fi2 in (a.fi2 + 5, a.fi2 + 6)  where a.fi2 > 110 option (loop);
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key in pred 3-1\n";
ECHO BOTH $IF $EQU $LAST[2] 9 "PASSED" "***FAILED";
ECHO BOTH ": cl oj 2nd key in pred 3-2\n";

select c.fi2, a.fi2, b.fi2, b.string1  from t1 c join t1 a on a.fi2 > c.fi2 left join t1 b table option (loop, index fi2) on b.fi2 in (a.fi2 + 5, a.fi2 + 6)  where c.fi2 in (110, 111) option (order, loop);
ECHO BOTH $IF $EQU $ROWCNT 24 "PASSED" "***FAILED";
ECHO BOTH ": cl 3 table oj 2nd key in pred 1: " $ROWCNT " rows\n";

select count (*) from t1 a left join t1 b  table option (loop) on b.row_no = a.row_no + 100 where b.row_no is null;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": outer unordered 1\n";

select count (*) from t1 a left join t1 b  table option (loop) on b.row_no = a.row_no + 100 where f (b.row_no) is null;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": outer unordered 2\n";


select count (*) from (select top 1000 b.row_no from t1 a left join t1 b table option (loop) on b.row_no = a.row_no + 100) c where f (c.row_no) is null;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": outer unordered 3\n";


create procedure cl_oj ()
{
  declare i int;
  for select a.fi2 as n1, b.fi2 as n2 from t1 a left join (select distinct fi2 from t1) b on b.fi2 = a.fi2 + 2 where a.fi2 > 1080 do
	       {
		 dbg_obj_princ (n1, ' ', n2);
	       }
}

-- a non join outer, the outer subq will go first since card known to be 0
select a.row_no, b.row_no from t1 a left join (select distinct row_no, o  from t1, rdf_quad where fi2 = -1 and s = iri_to_id ('ff', 0)) b on 1=1 where a.fi2 < 30;
