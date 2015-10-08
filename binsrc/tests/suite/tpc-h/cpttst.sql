
update lineitem set l_discount = l_discount * 1.1e0 where  exists (select * from part where l_partkey = p_partkey and p_size < 10 and p_name like '%green%');

update lineitem set l_discount = l_discount + 1, l_extendedprice = l_extendedprice + 100000 where  exists (select * from part where l_partkey = p_partkey and p_size < 10 and p_name like '%green%');


-- insert more sales, random spread 

insert into lineitem 
(L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT) 
select L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER + 8, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT from lineitem, part where l_partkey = p_partkey   and p_size < 10 and p_name like '%green%' and l_linenumber < 8;



-- insert more sales, sequential 


insert into lineitem 
(L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT) 
select L_ORDERKEY  + 700000000, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT from lineitem, part where l_partkey = p_partkey   and p_size < 10 and p_name like '%green%' and l_linenumber < 8 and l_orderkey < 700000000 and l_linenumber < 8;

cl_exec ('checkpoint');

-- delete sales, random

delete from lineitem  where  exists (select * from part where l_partkey = p_partkey and p_size < 10 and p_name like '%green%');
delete from lineitem  where  l_orderkey > 700000000;

cl_exec ('__dbf_set (''dbs_stop_cp'', 1)');
cl_exec ('checkpoint');
