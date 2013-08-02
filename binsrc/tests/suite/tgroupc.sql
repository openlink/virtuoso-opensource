
-- group by variations
-- expects t1 filled ins xx 100000 100


cl_exec ('__dbf_set (''dc_batch_sz'', 10)');
cl_exec ('__dbf_set (''dc_max_batch_sz'', 10)');

cl_exec ('__dbf_set (''cha_max_gb_bytes'', 1600000)');

SELECT COUNT(*) FROM (SELECT DISTINCT TOP 100000 ROW_NO FROM T1) X;
ECHO BOTH $IF $EQU $LAST[1] 100000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DISTINCT switch from chash to memcache in select COUNT=" $LAST[1] "\n";


alter table t1 add a1 any;

update t1 set fi7 = row_no / 100, a1 = row_no;

select top 20  a1, count (*) from t1 group by a1 order by a1 desc, 2;
select  top 20 b.a1, count (*) from t1 a, t1 b where b.row_no = a.row_no + 150 group by b.a1 order by b.a1 desc, 2 option (loop, order);

-- enough memory to do with chash anbd chash merge
cl_exec ('__dbf_set (''cha_max_gb_bytes'', 16000000)');
select top 20  a1, count (*) from t1 group by a1 order by a1 desc, 2;
select  top 20 b.a1, count (*) from t1 a, t1 b where b.row_no = a.row_no + 150 group by b.a1 order by b.a1 desc, 2 option (loop, order);


-- even numberd partitions have one out of 64 a1 as string instead of number 
-- chash merges will fail because some chash have different key than others

update t1 set a1 = sprintf ('r%d', row_no) where mod (row_no, 64) = 0 and mod (mod (row_no / 256, 32), 2) = 0;

select top 20  a1, count (*) from t1 group by a1 order by a1 desc, 2;
select  top 20 b.a1, count (*) from t1 a, t1 b where b.row_no = a.row_no + 150 group by b.a1 order by b.a1 desc, 2 option (loop, order);

 
cl_exec ('__dbf_set (''dc_batch_sz'', 100)');
cl_exec ('__dbf_set (''dc_max_batch_sz'', 100)');

select top 20  a1, count (*) from t1 group by a1 order by a1 desc, 2;
select  top 20 b.a1, count (*) from t1 a, t1 b where b.row_no = a.row_no + 150 group by b.a1 order by b.a1 desc, 2 option (loop, order);



cl_exec ('__dbf_set (''dc_batch_sz'', 10000)');
cl_exec ('__dbf_set (''dc_max_batch_sz'', 1000000)');
