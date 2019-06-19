

-- test join on build side of hash join 
-- over tpch qualification db

explain ('select count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = ''EUROPE'' and c_mktsegment = ''BUILDING'' ', -5);

explain ('select n_name, r_regionkey, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = ''EUROPE'' and c_mktsegment = ''BUILDING'' group by n_name, r_regionkey option (order)', -5);

explain ('select n_name, r_name, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = ''EUROPE'' and c_mktsegment = ''BUILDING'' group by n_name, r_name option (order)', -5);

explain ('select n_name, r_name, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = ''EUROPE'' and c_mktsegment = ''BUILDING'' group by n_name, r_name ', -5);

explain ('select n_nationkey, n_name, r_name, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = ''EUROPE'' and c_mktsegment = ''BUILDING'' group by n_nationkey, n_name, r_name ', -5);

select n_name, r_name, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = 'EUROPE' and c_mktsegment = 'BUILDING' group by n_name, r_name option (order);
select n_name, r_name, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = 'EUROPE' and c_mktsegment = 'BUILDING' group by n_name, r_name ;

select n_nationkey, n_name, r_name, count (*) from customer, nation, region where c_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = 'EUROPE' and c_mktsegment = 'BUILDING' group by n_nationkey, n_name, r_name;



explain ('select count (*) from lineitem, supplier, nation sn, region sr, part  where l_suppkey = s_suppkey and s_nationkey = sn.n_nationkey and sn.n_regionkey = sr.r_regionkey and sr.r_name = ''EUROPE'' and l_partkey = p_partkey and p_size = 15');


explain ('select n_name, count (*) from lineitem, supplier, nation sn, region sr, part  where l_suppkey = s_suppkey and s_nationkey = sn.n_nationkey and sn.n_regionkey = sr.r_regionkey and sr.r_name = ''EUROPE'' and l_partkey = p_partkey and p_size = 15 group by n_name');

explain ('select n_name, count (*) from lineitem, supplier, nation sn, region sr, part  where l_suppkey = s_suppkey and s_nationkey = sn.n_nationkey and sn.n_regionkey = sr.r_regionkey and sr.r_name = ''EUROPE'' and l_partkey = p_partkey and p_size = 15 group by n_name option (order)');


select count (*) from words a, words b where a.word = b.word option (order, hash);


select count (*) from words a, where exists (select 1 from words b table option (hash) where subseq (b.word, 0, length (b.word) - 1) = subseq (a.word, 0, length (a.word) - 1) and b.word <> a.word);


select count (*) from t1 a, t1 b where a.row_no = b.row_no option (order, hash);


select top 20 * from (select c_custkey, min (cast (o_totalprice as float)) as minp, max (cast (o_totalprice as float)) as maxp, count (*) as cnt   from customer, orders where o_custkey = c_custkey group by c_custkey order by c_custkey) ff  where minp = maxp and cnt > 1;
echo both if $equ $rowcnt 0  "PASSED"  "***FAILED";
echo both ": group by added up as floats\n";

select top 20 * from (select c_custkey, min (cast (o_totalprice as decimal)) as minp, max (cast (o_totalprice as decimal)) as maxp, count (*) as cnt   from customer, orders where o_custkey = c_custkey group by c_custkey order by c_custkey) ff  where minp = maxp and cnt > 1;
echo both if $equ $rowcnt 0  "PASSED"  "***FAILED";
echo both ": group by added up as decimals\n";




-- aggregates of union 



select n_name, r_name, count (*), grouping (n_name), grouping (r_name) from (
  select n_name, r_name from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
  union all select n_name, r_name from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
  union all select n_name, r_name from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f 
group by rollup (n_name, r_name);

select n_name, r_name, count (*) from (
  select n_name, r_name from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
  union all select n_name, r_name from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
  union all select n_name, r_name from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f 
group by n_name, r_name order by n_name;

echo both $if $equ $last[1] 25 "PASSED" "***FAILED";
echo both ": union all 1\n";

select n_name, r_name, count (*), avg (bal) from (
  select n_name, r_name, c_acctbal * 0.75 as bal from (
    select n_name, r_name, c_acctbal from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f
  ) i 
group by n_name, r_name order by n_name;
echo both $if $equ $last[1] 25 "PASSED" "***FAILED";
echo both ": union all 2\n";



select n_name, r_name, count (*) from (
  select n_name, r_name from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
  union all select n_name, r_name from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
  union all select n_name, r_name from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f 
group by n_name, r_name order by n_name;
echo both $if $equ $last[1] 25 "PASSED" "***FAILED";
echo both ": union all 3\n";



select n_name, r_name, count (*), avg (bal) from (
  select n_name, r_name, c_acctbal * 0.75 as bal from (
    select n_name, r_name, c_acctbal from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f
  ) i 
group by n_name, r_name order by n_name;
echo both $if $equ $last[1] 25 "PASSED" "***FAILED";
echo both ": union all 4\n";


select count (*), avg (bal) from (
  select n_name, r_name, c_acctbal * 0.75 as bal from (
    select n_name, r_name, c_acctbal from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f
  ) i;

echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": union all 5\n";


select top 10 * from (
  select n_name, r_name, c_acctbal * 0.75 as bal from (
    select n_name, r_name, c_acctbal from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f
  ) i
order by bal desc;

echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": union all top oby 1\n";


select distinct top 10 * from (
  select n_name, r_name, c_acctbal * 0.75 as bal from (
    select n_name, r_name, c_acctbal from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f
  ) i
order by bal desc;

echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": union all top oby 2\n";

select distinct  top 10 n_name, r_name, bal + 1 from (
  select n_name, r_name, c_acctbal * 0.75 as bal from (
    select n_name, r_name, c_acctbal from customer, nation, region where n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal < 10 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and  c_acctbal > 100 
    union all select n_name, r_name, c_acctbal from customer, nation, region where  n_nationkey = c_nationkey and r_regionkey = n_regionkey and c_acctbal between 40 and 50 ) f
  ) i
order by bal + 1  desc;
echo both $if $equ $last[1] 10 "PASSED" "***FAILED";
echo both ": union all top oby 3\n";




select top 10 a.l_partkey, a.total, b.total  from 
(select l_partkey, sum (l_extendedprice) as total from lineitem  where l_shipdate between cast ('1995-1-1'as date)  and cast ('1996-1-1' as date)) a,
(select l_partkey, sum (l_extendedprice) as total from lineitem  where l_shipdate between cast ('1996-1-1'as date)  and cast ('1997-1-1' as date)) b
where a.l_partkey = b.l_partkey
order by a.total desc;
