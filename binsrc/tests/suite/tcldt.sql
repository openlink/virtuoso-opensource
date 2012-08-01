




-- Multistate dt and code vec 




ECHO BOTH "Cluster multistate derived tables\n";


__dbf_set ('cl_req_batch_size', 7);
__dbf_set ('dc_batch_sz', 7);
__dbf_set ('dc_max_batch_sz', 7);


create procedure DPINC (in q int)
{
  return vector (q + 1, 1);
}

create procedure L_INC (in q int)
{
  id_to_iri (#i100); -- colocation break
  return q + 1;
}


create procedure L_INC_pass (in q int)
{
  return q + 1;
}

dpipe_define ('DPINC', 'DB.DBA.T1', 'FI2', 'DB.DBA.DPINC', 0);


explain ('select row_no, (select top 1  b.row_no as ct  from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) as cnt from t1 a');

explain ('select row_no, (select  b.row_no as ct  from t1 b table option (loop) where b.row_no = 1 + a.row_no) as cnt from t1 a');

select row_no, (select  b.row_no as ct  from t1 b table option (loop) where b.row_no = 1 + a.row_no) as cnt from t1 a order by row_no;
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ": single row scalar  subq\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
ECHO BOTH ": null as scalar subq when no match\n";

select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where b.fi2 >= 1 + a.fi2) as cnt from t1 a order by fi2;
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ": implied top 1 in range subq\n";

select top 1 fi2, (select  b.fi2 as ct  from t1 b table option (loop) where sqrt (b.fi2) > 0 and b.fi2 >= 1 + a.fi2) as cnt from t1 a order by fi2;
ECHO BOTH $IF $EQU $LAST[2] 21  "PASSED" "***FAILED";
ECHO BOTH ": double implied top 1\n";

select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where l_inc (b.fi2) > 0 and b.fi2 >= 1 + a.fi2) as cnt from t1 a order by fi2;
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ": no implied top 1 in subq with func\n";

select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where l_inc_pass (b.fi2) > 0 and b.fi2 >= 1 + a.fi2) as cnt from t1 a order by fi2;
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ":With colocated sql func:  no implied top 1 in subq with func\n";


select fi2, (select  b.fi2 as ct  from t1 b table option (loop) where dpinc (b.fi2) > 0 and b.fi2 >= 1 + a.fi2) as cnt from t1 a order by fi2;
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ": no implied top 1 in subq with dp func\n";


select fi2, (select  dpinc (b.fi2) as ct  from t1 b table option (loop) where  b.fi2 >= 1 + a.fi2) as cnt from t1 a order by fi2;
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ": skipping sets with dp node in value subq\n";

select dpinc (row_no), (select  b.row_no as ct  from t1 b table option (loop) where b.row_no in ( 1 + a.row_no, 3 + a.row_no)) as cnt from t1 a table option (index primary key);
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ":  scalar  subq with in and dp\n";


select row_no, (select top 1  b.row_no as ct  from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) as cnt from t1 a order by row_no;
ECHO BOTH $IF $EQU $LAST[2] 119 "PASSED" "***FAILED";
ECHO BOTH ": scalar subq with top and range\n";


select row_no, (select count (*) as ct  from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) as cnt from t1 a order by row_no;
ECHO BOTH $IF $EQU $LAST[2] 2 "PASSED" "***FAILED";
ECHO BOTH ": scalar subq with count\n";

explain ('select a.row_no, b.row_no from t1 a left join (select row_no from t1) b on b.row_no in (a.row_no + 1, a.row_no + 2)');

select a.row_no, b.row_no from t1 a left join (select row_no from t1) b on b.row_no in (a.row_no + 1, a.row_no + 2);
ECHO BOTH $IF $EQU $ROWCNT 199 "PASSED" "***FAILED";
ECHO BOTH ": oj of dt 199 rows\n";


select a.row_no, b.row_no from t1 a left join (select row_no from t1) b on b.row_no in (a.row_no + 199, a.row_no + 299);
ECHO BOTH $IF $EQU $ROWCNT 101 "PASSED" "***FAILED";
ECHO BOTH ": oj of dt no hit 101 rows\n";




-- implicit top in value subq 

select a.row_no, (select count (*) from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) from t1 a;

select a.row_no, (select b.row_no from t1 b where b.row_no between a.row_no - 2 and a.row_no + 2) from t1 a  ;
-- other partition with fi2 inx
select a.row_no, (select b.row_no from t1 b where b.fi2 between a.row_no - 2 and a.row_no + 2) from t1 a      order by row_no;
ECHO BOTH $IF $EQU $LAST[2] 119 "PASSED" "***FAILED";
ECHO BOTH ": scalar subq with multivalue range\n";



select a.row_no, (select b.row_no from t1 b, t1 d  where b.fi2 between a.row_no - 2 and a.row_no + 2 and d.fi2 > b.row_no) from t1 a  ;

select a.row_no, (select d.row_no from t1 b, t1 d  where b.fi2 between a.row_no - 2 and a.row_no + 2 and d.fi2 > b.row_no - 2) from t1 a      order by row_no;
ECHO BOTH $IF $EQU $LAST[2] 118 "PASSED" "***FAILED";
ECHO BOTH ": scalar subq with joined multivalue range\n";


-- top and skip of derived table 
-- Note that a dt with a top cannot import predicates. 
select a.row_no, b.row_no from t1 a, (select top 3 c.row_no from t1 c) b where b.row_no > a.row_no option (loop, order);



--select a.row_no, b.row_no from t1 a table option (index t1), (select  top 3  c.row_no from t1 c ) b where b.row_no in ( a.row_no, a.row_no + 1)  option (loop, order);
--ECHO BOTH $IF $EQU $ROWCNT 200 "PASSED" "***FAILED";
--ECHO BOTH ": dt with in\n";


-- group by 

update t1 set fi6 = row_no / 10;
create index fi6 on t1 (fi6) partition (fi6 int);

select fi6, count (*) from t1 group by fi6 order by 2 desc;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": simple group by\n";


select a.fi6, b.* from (select distinct fi6 from t1) a, (select fi6, count (*) as ct from t1 group by fi6) b where b.fi6 = a.fi6 option (order);
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": multistate  group by dt\n";


select a.fi6, b.* from (select distinct fi6 from t1) a, (select fi6, count (*) as ct from t1 group by fi6) b where b.fi6 between  a.fi6 - 1 and a.fi6 + 1 order by 1, 2 option (order);
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": multistate  group by dt with range, gb partitioned\n";

select  a.fi6, b.* from (select distinct fi6 from t1) a, (select fi6, fi6 + 0 as dum, count (*) as ct from t1 group by fi6, fi6 + 0) b where b.fi6 between  a.fi6 - 1 and a.fi6 + 1 order by 1, 2 option (order);
ECHO BOTH $IF $EQU $LAST[4] 1 "PASSED" "***FAILED";
ECHO BOTH ": multistate  group by dt with range, gb not partitioned\n";



-- existence 

select a.row_no from t1 a where not exists (select 1 from t1 b where b.row_no > a.row_no + 30) and not exists (select 1 from t1 c where c.row_no < a.row_no - 30);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": not exists and not exists empty\n";


select a.row_no from t1 a where not exists (select 1 from t1 b where b.row_no > a.row_no + 60) and not exists (select 1 from t1 c where c.row_no < a.row_no - 60);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": not exists and not exists 20\n";

select a.fi2 from t1 a where not exists (select 1 from t1 b where b.fi2 > a.fi2 + 60) and not exists (select 1 from t1 c where c.fi2 < a.fi2 - 60);

select a.fi2 from t1 a where exists (select 1 from t1 b where b.fi2 > a.fi2 + 60) and exists (select 1 from t1 c where c.fi2 < a.fi2 - 60);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ":  exists and  exists 2 0\n";

select a.fi2 from t1 a where exists (select 1 from t1 b where b.fi2 > a.fi2 + 40) and exists (select 1 from t1 c where c.fi2 < a.fi2 - 40);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ":  exists and  exists 20\n";

select a.fi2 from t1 a where exists (select 1 from t1 b where b.fi2 in (a.fi2 + 40, a.fi2 + 41)) and exists (select 1 from t1 c where c.fi2 in ( a.fi2 - 40, a.fi2 - 41));
ECHO BOTH $IF $EQU $ROWCNT 22 "PASSED" "***FAILED";
ECHO BOTH ":  exists and  exists 22\n";

select fi2 from t1 a where mod (fi2, 2) = 1 and exists (select 1 from t1 b where b.fi2 = 1 + a.fi2)  ;
ECHO BOTH $IF $EQU $ROWCNT 49 "PASSED" "***FAILED";
ECHO BOTH ":sparse   exists\n";


select fi2, s.string1 from (select distinct string1 from t1) s, t1 where row_no = (select max (row_no) from t1 where string1 = s.string1);


-- both after code and after test are multistate 
select row_no, (select count (*) from t1 b where b.string1 = a.string1) from t1 a where not exists (select 1 from t1 c table option (loop) where c.row_no = a.row_no + 10);

-- unions 

select a.fi2, b.fi2 from t1 a, (select fi2 from t1 union select row_no from t1) b where a.fi2 + 1 = b.fi2 option (order);
ECHO BOTH $IF $EQU $ROWCNT 99 "PASSED" "***FAILED";
ECHO BOTH ": union\n";

 
select a.fi2, b.fi2 from t1 a, (select fi2 from t1 union all select row_no from t1) b where a.fi2 + 1 = b.fi2 option (order);
ECHO BOTH $IF $EQU $ROWCNT 198 "PASSED" "***FAILED";
ECHO BOTH ": union all\n";





-- multistate except not supported 
-- select a.fi2, b.fi2 from t1 a, (select fi2 from t1 except select row_no from t1) b where a.fi2 + 1 = b.fi2 option (order);
-- ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
-- ECHO BOTH ": except \n";

select fi2 from t1 a where a.fi2 in (select b.fi2 from t1 b where b.fi2 = a.fi2 group by b.fi2 having sum (b.fi2) > 80) option (do not loop exists);
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": having over group by agg in existence subq, the gb is done by the partitions, no looping of exists\n";

select fi2 from t1 a where a.fi2 in (select b.row_no - 1 from t1 b where b.fi2 >= a.fi2 + 1 and b.fi2 < a.fi2 + 2 group by b.row_no - 1 having sum (b.row_no) > 80) option (do not loop exists);
ECHO BOTH $IF $EQU $ROWCNT 39 "PASSED" "***FAILED";
ECHO BOTH ": having over group by agg in existence subq, the gb is summed on coordinator, no looping of exists\n";


select c.fi2, sum (c.row_no) from t1 a, t1 b table option (hash), t1 c where b.fi2 = a.fi2 + 1 and c.fi2 = b.fi2  group by c.fi2 order by 2 desc option (order);
ECHO BOTH $IF $EQU $ROWCNT 99 "PASSED" "***FAILED";
ECHO BOTH ": final partitioned gb oby, many batches, one set\n";


select c.fi2, sum (c.row_no) from t1 a, t1 b table option (hash), t1 d, t1 c where b.fi2 = a.fi2 + 1 and d.fi2 = b.fi2 and c.fi2 = d.fi2 + 1 group by c.fi2 order by 2 desc option (order);
ECHO BOTH $IF $EQU $ROWCNT 98 "PASSED" "***FAILED";
ECHO BOTH ": final dfg w partitioned gb oby, many batches, one set\n";



-- vectored special cases of oby/gb 

__dbf_set ('qp_thread_min_usec', 0);
__dbf_set ('enable_qp', 8);

select top 10 a.row_no from t1 a table option (index t1), t1 b  where b.row_no = a.row_no and 0 + a.row_no between 80 and 90 order by a.row_no + 0 option (order, loop);

select top 10 row_no, (select c.row_no from t1 c table option (loop) where c.row_no = 1 + a.row_no) from t1 a where row_no + 1 = (select b.row_no from t1 b table option (loop) where b.row_no = 1 + a.row_no);

select a.string1, count (*) from t1 a, t1 b where b.row_no = 1000 + a.row_no group by a.string1 order by a.string1 option (order, hash);
select a.string1, count (*) from t1 b, t1 a where b.row_no = 1000 + a.row_no group by a.string1 order by a.string1 option (order, hash);
select a.string1, count (*) from t1 a, t1 b where b.row_no = 1000 + a.row_no group by a.string1 having count (*) <> 3330 order by a.string1 option (order, loop);
