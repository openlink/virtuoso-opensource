--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
SET ARGV[0] 0;
SET ARGV[1] 0;
ECHO BOTH "STARTED: TPC-D queries\n";
select
	l_returnflag,
	l_linestatus,
	sum(l_quantity) as sum_qty,
	sum(l_extendedprice) as sum_base_price,
	sum(l_extendedprice*(1-l_discount)) as sum_disc_price,
	sum(l_extendedprice*(1-l_discount)*(1+l_tax)) as sum_charge,
	avg(l_quantity) as avg_qty,
	avg(l_extendedprice) as avg_price,
	avg(l_discount) as avg_disc,
	count(*) as count_order
from
	LINEITEM
where
	l_shipdate <= DATE_ADD('1998-12-01', INTERVAL -90 DAY)
group by
	l_returnflag,
	l_linestatus
order by
	l_returnflag,
	l_linestatus;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q1\n";

select
	s_acctbal,
	s_name,
	n_name,
	p_partkey,
	p_mfgr,
	s_address,
	s_phone,
	s_comment
from
	PART,
	SUPPLIER,
	PARTSUPP,
	NATION,
	REGION
where
	p_partkey = ps_partkey
	and s_suppkey = ps_suppkey
	and p_size = 15
	and p_type like '%BRASS'
	and s_nationkey = n_nationkey
	and n_regionkey = r_regionkey
	and r_name = 'EUROPE'
	and ps_supplycost = (
			select
				min(ps_supplycost)
			from
				PARTSUPP, SUPPLIER,
				NATION, REGION
			where
				p_partkey = ps_partkey
				and s_suppkey = ps_suppkey
				and s_nationkey = n_nationkey
				and n_regionkey = r_regionkey
				and r_name = 'EUROPE'
			)
order by
	s_acctbal desc,
	n_name,
	s_name,
	p_partkey;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q2\n";

select
	l_orderkey,
	sum(l_extendedprice*(1-l_discount)) as revenue,
	o_orderdate,
	o_shippriority
from
	CUSTOMER,
	ORDERS,
	LINEITEM
where
	c_mktsegment = 'BUILDING'
	and c_custkey = o_custkey
	and l_orderkey = o_orderkey
	and o_orderdate < {d '1995-03-15'}
	and l_shipdate > {d '1995-03-15'}
group by
	l_orderkey,
	o_orderdate,
	o_shippriority
order by
	revenue desc,
	o_orderdate;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q3\n";


select
	o_orderpriority,
	count(*) as order_count
from ORDERS
where
	o_orderdate >= '1993-07-01'
	and o_orderdate < DATE_ADD('1993-07-01', INTERVAL 3 MONTH)
	and exists (
		select
			*
		from
			LINEITEM
		where
			l_orderkey = o_orderkey
			and l_commitdate < l_receiptdate
	)
	group by
		o_orderpriority
	order by
		o_orderpriority;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q4\n";

select
	n_name,
	sum(l_extendedprice * (1 - l_discount)) as revenue
from
	REGION,
	NATION,
	SUPPLIER,
	CUSTOMER,
	LINEITEM,
	ORDERS
where
	c_custkey = o_custkey
	and o_orderkey = l_orderkey
	and l_suppkey = s_suppkey
	and c_nationkey = s_nationkey
	and s_nationkey = n_nationkey
	and n_regionkey = r_regionkey
	and r_name = 'ASIA'
	and o_orderdate >= '1994-01-01'
	and o_orderdate < DATE_ADD('1994-01-01', INTERVAL 12 MONTH)
group by
	n_name
order by
	revenue desc;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q5\n";

select
	sum(l_extendedprice * l_discount) as revenue
from
	LINEITEM
where
	l_shipdate >= '1994-01-01'
	and l_shipdate < DATE_ADD('1994-01-01', INTERVAL 12 MONTH)
	and l_discount between 0.06 - 0.01 and 0.06 + 0.01
	and l_quantity < 24;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q6\n";

select
	supp_nation,
	cust_nation,
	l_year,
	sum(volume) as revenue
from (
	select
		n1.n_name as supp_nation,
		n2.n_name as cust_nation,
		{fn year (l_shipdate)} as l_year,
		l_extendedprice * (1 - l_discount) as volume
	from
		NATION n2,
		NATION n1,
		CUSTOMER,
		ORDERS,
		LINEITEM,
		SUPPLIER
	where
		s_suppkey = l_suppkey
		and o_orderkey = l_orderkey
		and c_custkey = o_custkey
		and s_nationkey = n1.n_nationkey
		and c_nationkey = n2.n_nationkey
		and (
			(n1.n_name = 'FRANCE' and n2.n_name = 'GERMANY')
			or (n1.n_name = 'GERMANY' and n2.n_name = 'FRANCE')
			)
		and l_shipdate between {d '1995-01-01'} and {d '1996-12-31'}
		) shipping
	group by
		supp_nation,
		cust_nation,
		l_year
	order by
		supp_nation,
		cust_nation,
		l_year;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q7\n";

select
        o_year,
	sum1 / sum2 as mkt_share
  from (
        select
	o_year,
	sum(case
		when nation = 'BRAZIL'
			then volume
		else 0
		end) as sum1 ,
   	sum(volume) as sum2
            from (
		select
		        {fn year (o_orderdate)} as o_year,
			l_extendedprice * (1-l_discount) as volume,
			n2.n_name as nation
		from
			REGION,
			NATION n2,
			NATION n1,
			CUSTOMER,
			ORDERS,
			LINEITEM,
			SUPPLIER,
			PART
		where
			p_partkey = l_partkey
			and s_suppkey = l_suppkey
			and l_orderkey = o_orderkey
			and o_custkey = c_custkey
			and c_nationkey = n1.n_nationkey
			and n1.n_regionkey = r_regionkey
			and r_name = 'AMERICA'
			and s_nationkey = n2.n_nationkey
			and o_orderdate between {d '1995-01-01'} and {d '1996-12-31'}
			and p_type = 'ECONOMY ANODIZED STEEL'
	) all_nations
group by
	o_year
	) test
order by
	o_year
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q8\n";

select
	nation,
	o_year,
	sum(amount) as sum_profit
from (
	select
		n_name as nation,
		{fn year(o_orderdate)} as o_year,
		l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity as amount
	from
		NATION,
		ORDERS,
		PARTSUPP,
		LINEITEM,
		SUPPLIER,
		PART
	where
		s_suppkey = l_suppkey
		and ps_suppkey = l_suppkey
		and ps_partkey = l_partkey
		and p_partkey = l_partkey
		and o_orderkey = l_orderkey
		and s_nationkey = n_nationkey
		and p_name like '%green%'
	) profit
group by
	nation,
	o_year
order by
	nation,
        o_year desc;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q9\n";

select
	c_custkey,
	c_name,
	sum(l_extendedprice * (1 - l_discount)) as revenue,
	c_acctbal,
	n_name,
	c_address,
	c_phone,
	c_comment
from
	NATION,
	LINEITEM,
	ORDERS,
	CUSTOMER
where
	c_custkey = o_custkey
	and l_orderkey = o_orderkey
	and o_orderdate >= {d '1993-10-01'}
	and o_orderdate < DATE_ADD('1993-10-01', INTERVAL 3 MONTH)
	and l_returnflag = 'R'
	and c_nationkey = n_nationkey
group by
	c_custkey,
	c_name,
	c_acctbal,
	c_phone,
	n_name,
	c_address,
	c_comment
order by
	revenue desc;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q10\n";

select
	ps_partkey,
	sum(ps_supplycost * ps_availqty) as value
from
	NATION,
	SUPPLIER,
	PARTSUPP
where
	ps_suppkey = s_suppkey
	and s_nationkey = n_nationkey
	and n_name = 'GERMANY'
group by
	ps_partkey
having
	sum(ps_supplycost * ps_availqty) > (
		select
			sum(ps_supplycost * ps_availqty) * 0.0001
		from
			NATION,
			SUPPLIER,
			PARTSUPP
		where
			ps_suppkey = s_suppkey
			and s_nationkey = n_nationkey
			and n_name = 'GERMANY'
		)
order by
	value desc;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q11\n";

select
	l_shipmode,
	sum(case
			when o_orderpriority ='1-URGENT'
			or o_orderpriority ='2-HIGH'
			then 1
			else 0
	end) as high_line_count,
	sum(case
			when o_orderpriority <> '1-URGENT'
			and o_orderpriority <> '2-HIGH'
			then 1
			else 0
	end) as low_line_count
from
	LINEITEM,
	ORDERS
where
	o_orderkey = l_orderkey
	and l_shipmode in ('MAIL', 'SHIP')
	and l_commitdate < l_receiptdate
	and l_shipdate < l_commitdate
	and l_receiptdate >= {d '1994-01-01'}
	and l_receiptdate < DATE_ADD('1994-01-01', INTERVAL 1 YEAR)
group by
	l_shipmode
order by
	l_shipmode;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q12\n";

select
	100 * sum(case
		when p_type like 'PROMO%'
			then l_extendedprice*(1-l_discount)
		else 0.0
	end) /
	sum(l_extendedprice * (1 - l_discount)) as promo_revenue
from
	PART,
	LINEITEM
where
	l_partkey = p_partkey
	and l_shipdate >= {d '1995-09-01'}
	and l_shipdate < DATE_ADD('1995-09-01', INTERVAL 1 MONTH);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q14\n";

select
  s_suppkey,
  s_name,
  s_address,
  s_phone,
  total_revenue
from
  SUPPLIER,
  (
    select
      l_suppkey as supplier_no,
      sum(l_extendedprice * (1 - l_discount)) as total_revenue
    from
      LINEITEM
    where
      l_shipdate >= '1996-01-01' and
      l_shipdate < DATE_ADD('1996-01-01', INTERVAL 3 MONTH)
    group by
      l_suppkey
  ) as revenue
where
  s_suppkey = supplier_no and
  total_revenue =
  (
    select
      max(total_revenue)
    from
      (
        select
          l_suppkey as supplier_no,
          sum(l_extendedprice * (1 - l_discount)) as total_revenue
        from
          LINEITEM
        where
          l_shipdate >= '1996-01-01' and
	  l_shipdate < DATE_ADD('1996-01-01', INTERVAL 3 MONTH)
	group by
          l_suppkey
      ) as revenue
  )
order by
  s_suppkey;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q15\n";

select
	p_brand,
	p_type,
	p_size,
	count(distinct ps_suppkey) as supplier_cnt
from
	PART,
	PARTSUPP
where
	p_partkey = ps_partkey
	and p_brand <> 'Brand#45'
	and p_type not like 'MEDIUM POLISHED%'
	and p_size in (49, 14, 23, 45, 19, 3, 36, 9)
	and ps_suppkey not in (
			select
				s_suppkey
			from
				SUPPLIER
			where
				s_comment like '%Customer%Complaints%'
			)
group by
	p_brand,
	p_type,
	p_size
order by
	supplier_cnt desc,
	p_brand,
	p_type,
	p_size;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q16\n";

select
	sum(l_extendedprice) / 7.0 as avg_yearly
from
	PART,
	LINEITEM
where
	p_partkey = l_partkey
	and p_brand = 'Brand#23'
	and p_container = 'MED BOX'
	and (l_quantity) < (
		select
			0.2 * avg(l_quantity)
		from
			LINEITEM
		where
			l_partkey = p_partkey
	)
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q17\n";


select
	sum(l_extendedprice * (1 - l_discount) ) as revenue
from
	PART,
	LINEITEM
where
	(
	 p_partkey = l_partkey
	 and p_brand = 'Brand#12'
	 and p_container in ( 'SM CASE', 'SM BOX', 'SM PACK', 'SM PKG')
	 and l_quantity >= 1 and l_quantity <= 1 + 10
	 and p_size between 1 and 5
	 and l_shipmode in ('AIR', 'AIR REG')
	 and l_shipinstruct = 'DELIVER IN PERSON'
	 )
	or
	(
	 p_partkey = l_partkey
	 and p_brand = 'Brand#23'
	 and p_container in ('MED BAG', 'MED BOX', 'MED PKG', 'MED PACK')
	 and l_quantity >= 10 and l_quantity <= 10 + 10
	 and p_size between 1 and 10
	 and l_shipmode in ('AIR', 'AIR REG')
	 and l_shipinstruct = 'DELIVER IN PERSON'
	 )
	or
	(
	 p_partkey = l_partkey
	 and p_brand = 'Brand#34'
	 and p_container in ( 'LG CASE', 'LG BOX', 'LG PACK', 'LG PKG')
	 and l_quantity >= 20 and l_quantity <= 20 + 10
	 and p_size between 1 and 15
	 and l_shipmode in ('AIR', 'AIR REG')
	 and l_shipinstruct = 'DELIVER IN PERSON'
	 );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q19\n";

select
    s_name,
    s_address
from
    NATION,
    SUPPLIER
where
    s_suppkey in (
        select
            ps_suppkey
        from
            PARTSUPP
        where
            ps_partkey in (
                select
                    p_partkey
                from
                    PART
                where
                    p_name like 'forest%'
            )
            and ps_availqty > (
                select
                    0.5 * sum(l_quantity)
                from
                    LINEITEM
                where
                    l_partkey = ps_partkey
                    and l_suppkey = ps_suppkey
                    and l_shipdate >= {d '1994-01-01'}
                    and l_shipdate < DATE_ADD('1994-01-01', INTERVAL 1 YEAR)
            )
        )
    and s_nationkey = n_nationkey
    and n_name = 'CANADA'
order by
    s_name;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q20\n";

select
    s_name,
    count(*) as numwait
from
    NATION,
    ORDERS,
    LINEITEM l1,
    SUPPLIER
where
    s_suppkey = l1.l_suppkey
    and o_orderkey = l1.l_orderkey
    and o_orderstatus = 'F'
    and l1.l_receiptdate > l1.l_commitdate
    and exists (
        select
            *
        from
            LINEITEM l2
        where
            l2.l_orderkey = l1.l_orderkey
            and l2.l_suppkey <> l1.l_suppkey
    )
    and not exists (
        select
            *
        from
            LINEITEM l3
        where
            l3.l_orderkey = l1.l_orderkey
            and l3.l_suppkey <> l1.l_suppkey
            and l3.l_receiptdate > l3.l_commitdate
    )
    and s_nationkey = n_nationkey
    and n_name = 'SAUDI ARABIA'
group by
    s_name
order by
    numwait desc,
    s_name;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q21\n";

select
  cntrycode,
  count(*) as numcust,
  sum(c_acctbal) as totacctbal
from (
    select
      {fn substring(c_phone, 1, 2)} as cntrycode,
      c_acctbal
    from
      CUSTOMER
    where
      {fn substring(c_phone, 1, 2)} in
        ('13', '35', '31', '23', '29', '30', '17', '18') and
      c_acctbal >
        (
	  select
	    avg(c_acctbal)
	  from
	    CUSTOMER
	  where
	    c_acctbal > 0.00 and
	    {fn substring(c_phone, 1, 2)} in
	      ('13', '35', '31', '23', '29', '30', '17', '18')
	) and
      not exists
        (
          select
	    *
	  from
	    ORDERS
	  where
	    o_custkey = c_custkey
	)
  ) as custsale
group by
  cntrycode
order by
  cntrycode;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q22\n";

ECHO BOTH "COMPLETED: TPC-D queries (tpc-d/Q.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
