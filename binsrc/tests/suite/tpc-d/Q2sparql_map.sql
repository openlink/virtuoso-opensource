
sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
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
	part,
	supplier,
	partsupp,
	nation,
	region
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
				partsupp, supplier,
				nation, region
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



select
  ?l+>tpcd:returnflag
  ?l+>tpcd:linestatus
  sum(?l+>tpcd:linequantity) as ?sum_qty
  sum(?l+>tpcd:lineextendedprice) as ?sum_base_price
  sum(?l+>tpcd:lineextendedprice*(1-?l+>tpcd:linediscount)) as ?sum_disc_price
  sum(?l+>tpcd:lineextendedprice*(1-?l+>tpcd:linediscount)*(1+?l+>tpcd:linetax)) as ?sum_charge
  avg(?l+>tpcd:linequantity) as ?avg_qty
  avg(?l+>tpcd:lineextendedprice) as ?avg_price
  avg(?l+>tpcd:linediscount) as ?avg_disc
  count(1) as ?count_order
from
  <http://example.com/tpcd>
where
  {
#    ?l a tpcd:lineitem .
    filter (?l+>tpcd:shipdate <= bif:dateadd ("day", 90, '1998-12-01'^^xsd:dateTime))
  }
order by
  ?l+>tpcd:returnflag ?l+>tpcd:linestatus
;
