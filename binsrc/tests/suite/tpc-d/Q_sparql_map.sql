--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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


set prompt on;
set autocommit on;

ECHO "Q1";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?l+>tpcd:returnflag,
  ?l+>tpcd:linestatus,
  sum(?l+>tpcd:linequantity) as ?sum_qty,
  sum(?l+>tpcd:lineextendedprice) as ?sum_base_price,
  sum(?l+>tpcd:lineextendedprice*(1 - ?l+>tpcd:linediscount)) as ?sum_disc_price,
  sum(?l+>tpcd:lineextendedprice*(1 - ?l+>tpcd:linediscount)*(1+?l+>tpcd:linetax)) as ?sum_charge,
  avg(?l+>tpcd:linequantity) as ?avg_qty,
  avg(?l+>tpcd:lineextendedprice) as ?avg_price,
  avg(?l+>tpcd:linediscount) as ?avg_disc,
  count(1) as ?count_order
from <http://example.com/tpcd>
where {
    ?l a tpcd:lineitem .
    filter (?l+>tpcd:shipdate <= bif:dateadd ("day", -90, '1998-12-01'^^xsd:date)) }
order by ?l+>tpcd:returnflag ?l+>tpcd:linestatus
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q2";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
select
  ?supp+>tpcd:acctbal,
  ?supp+>tpcd:name,
  ?supp+>tpcd:has_nation+>tpcd:name as ?nation_name,
  ?part+>tpcd:partkey,
  ?part+>tpcd:mfgr,
  ?supp+>tpcd:address,
  ?supp+>tpcd:phone,
  ?supp+>tpcd:comment
from <http://example.com/tpcd>
where {
  ?ps a tpcd:partsupp; tpcd:has_supplier ?supp; tpcd:has_part ?part .
  ?supp+>tpcd:has_nation+>tpcd:has_region tpcd:name 'EUROPE' .
  ?part tpcd:size 15 .
  ?ps tpcd:supplycost ?minsc .
  { select ?part min(?ps+>tpcd:supplycost) as ?minsc
    where {
        ?ps a tpcd:partsupp; tpcd:has_part ?part; tpcd:has_supplier ?ms .
        ?ms+>tpcd:has_nation+>tpcd:has_region tpcd:name 'EUROPE' .
      } }
    filter (?part+>tpcd:type like '%BRASS') }
order by
  desc (?supp+>tpcd:acctbal)
  ?supp+>tpcd:has_nation+>tpcd:name
  ?supp+>tpcd:name
  ?part+>tpcd:partkey
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q3";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?ord+>tpcd:orderkey,
  sum(?li+>tpcd:lineextendedprice*(1 - ?li+>tpcd:linediscount)) as ?revenue,
  ?ord+>tpcd:orderdate,
  ?ord+>tpcd:shippriority
from <http://example.com/tpcd>
where
  {
    ?cust a tpcd:customer ; tpcd:mktsegment "BUILDING" ; tpcd:customer_of ?ord .
    ?li tpcd:has_order ?ord .
    filter ((?ord+>tpcd:orderdate < "1995-03-15"^^xsd:date) &&
      (?li+>tpcd:shipdate > "1995-03-15"^^xsd:date) ) }
order by
  desc (sum (?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)))
  ?ord+>tpcd:orderdate
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q4";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (?ord+>tpcd:orderpriority),
  count(1) as ?order_count
from <http://example.com/tpcd>
where
  { ?ord a tpcd:order .
    { select ?ord count(?li) as ?cnt
      where {
          ?li tpcd:has_order ?ord .
          filter ( ?li+>tpcd:commitdate < ?li+>tpcd:receiptdate ) } }
    filter ((?ord+>tpcd:orderdate >= "1993-07-01"^^xsd:date) &&
      (?ord+>tpcd:orderdate < bif:dateadd ("month", 3, "1993-07-01"^^xsd:date)) &&
      (?cnt > 0) )
  }
order by
  ?ord+>tpcd:orderpriority
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q5";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?supp+>tpcd:has_nation+>tpcd:name as ?nation,
  sum(?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)) as ?revenue
from <http://example.com/tpcd>
where
  { ?li a tpcd:lineitem ; tpcd:has_order ?ord ; tpcd:has_supplier ?supp .
    ?ord tpcd:has_customer ?cust .
    ?supp+>tpcd:has_nation+>tpcd:has_region tpcd:name "ASIA" .
    filter ((?cust+>tpcd:has_nation = ?supp+>tpcd:has_nation) &&
      (?ord+>tpcd:orderdate >= "1994-01-01"^^xsd:date) &&
      (?ord+>tpcd:orderdate < bif:dateadd ("year", 1,"1994-01-01" ^^xsd:date)) ) }
order by
  desc (sum(?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)))
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q6";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  sum(?li+>tpcd:lineextendedprice * ?li+>tpcd:linediscount) as ?revenue
from <http://example.com/tpcd>
where {
    ?li a tpcd:lineitem .
    filter ( (?li+>tpcd:shipdate >= "1994-01-01"^^xsd:date) &&
      (?li+>tpcd:shipdate < bif:dateadd ("year", 1, "1994-01-01"^^xsd:date)) &&
      (?li+>tpcd:linediscount >= 0.06 - 0.01) &&
      (?li+>tpcd:linediscount <= 0.06 + 0.01) &&
      (?li+>tpcd:linequantity < 24) ) }
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q7 -- bad grouping by year";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select ?supp_nation ?cust_nation ?li_year
  sum (?value) as ?revenue
from <http://example.com/tpcd>
where {
    {
      select
        ?suppn+>tpcd:name as ?supp_nation,
        ?custn+>tpcd:name as ?cust_nation,
        (bif:year (?li+>tpcd:shipdate)) as ?li_year,
        (?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)) as ?value
      where {
          ?li a tpcd:lineitem ; tpcd:has_order ?ord ; tpcd:has_supplier ?supp .
          ?ord tpcd:has_customer ?cust .
          ?cust tpcd:has_nation ?custn .
          ?supp tpcd:has_nation ?suppn .
          filter ((
              (?custn+>tpcd:name = "FRANCE" and ?suppn+>tpcd:name = "GERMANY") ||
              (?custn+>tpcd:name = "GERMANY" and ?suppn+>tpcd:name = "FRANCE") ) &&
            (?li+>tpcd:shipdate >= "1995-01-01"^^xsd:date) &&
            (?li+>tpcd:shipdate <= "1996-12-31"^^xsd:date) ) } } }
order by
  ?supp_nation
  ?li_year
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q8 -- bad grouping by year";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?o_year,
  (?sum1 / ?sum2) as ?mkt_share
from <http://example.com/tpcd>
where {
    { select
        ?o_year
        sum (?volume * bif:equ (?nation, "BRAZIL")) as ?sum1
        sum (?volume) as ?sum2
      where {
          { select
              (bif:year (?ord+>tpcd:orderdate)) as ?o_year,
              (?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)) as ?volume,
              ?n2+>tpcd:name as ?nation
            where {
                ?li a tpcd:lineitem ; tpcd:has_order ?ord ; tpcd:has_part ?part .
                ?li+>tpcd:has_supplier tpcd:has_nation ?n2 .
                ?order+>tpcd:has_customer+>tpcd:has_nation+>tpcd:has_region tpcd:name "AMERICA" .
                ?part tpcd:type "ECONOMY ANODIZED STEEL" .
                filter ((?ord+>tpcd:orderdate >= "1995-01-01"^^xsd:date) &&
                  (?ord+>tpcd:orderdate <= "1996-12-31"^^xsd:date) ) } } } } }
order by
  ?o_year
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q9 -- bad grouping by year";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?nation,
  ?o_year,
  sum(?amount) as ?sum_profit
from <http://example.com/tpcd>
where {
    { select
        ?supp+>tpcd:has_nation+>tpcd:name as ?nation,
        (bif:year (?ord+>tpcd:orderdate)) as ?o_year,
        (?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount) - ?ps+>tpcd:supplycost * ?li+>tpcd:linequantity) as ?amount
      where {
          ?li a tpcd:lineitem ; tpcd:has_order ?ord ; tpcd:has_supplier ?supp ; tpcd:has_part ?part .
          ?ps a tpcd:partsupp ; tpcd:has_part ?part ; tpcd:has_supplier ?supp .
          filter (?part+>tpcd:name like "%green%") } } }
order by
  ?nation
  desc (?o_year)
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q10";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?cust+>tpcd:custkey,
  ?cust+>tpcd:companyName,
  (sum(?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount))) as ?revenue,
  ?cust+>tpcd:acctbal,
  ?cust+>tpcd:has_nation+>tpcd:name as ?nation,
  ?cust+>tpcd:address,
  ?cust+>tpcd:phone,
  ?cust+>tpcd:comment
from <http://example.com/tpcd>
where
  {
    ?li tpcd:returnflag "R" ; tpcd:has_order ?ord .
    ?ord tpcd:has_customer ?cust .
    filter ((?ord+>tpcd:orderdate >= "1993-10-01"^^xsd:date) &&
      (?ord+>tpcd:orderdate < bif:dateadd ("month", 3, "1993-10-01"^^xsd:date)) ) }
order by
  desc (sum(?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)))
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q11";
sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?bigps+>tpcd:has_part,
  ?bigpsvalue
from <http://example.com/tpcd>
where {
      { select
          ?bigps+>tpcd:has_ps_partkey as ?bpartkey,
          sum(?bigps+>tpcd:supplycost * ?bigps+>tpcd:availqty) as ?bigpsvalue
        where
          {
            ?bigps a tpcd:partsupp .
            ?bigps+>tpcd:has_supplier+>tpcd:has_nation tpcd:name "GERMANY" .
          }
      }
    filter (?bigpsvalue > (
        select
          (sum(?thr_ps+>tpcd:supplycost * ?thr_ps+>tpcd:availqty) * 0.0001) as ?threshold
        where
          {
            ?thr_ps a tpcd:partsupp .
            ?thr_ps+>tpcd:has_supplier+>tpcd:has_nation tpcd:name "GERMANY" .
          }))
  }
order by
  desc (?bigpsvalue)
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q12";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?li+>tpcd:shipmode,
  sum (
    bif:__or (
      bif:equ (?ord+>tpcd:orderpriority, "1-URGENT"),
      bif:equ (?ord+>tpcd:orderpriority, "2-HIGH") ) ) as ?high_line_count,
  sum (1 -
    bif:__or (
      bif:equ (?ord+>tpcd:orderpriority, "1-URGENT"),
      bif:equ (?ord+>tpcd:orderpriority, "2-HIGH") ) ) as ?low_line_count
from <http://example.com/tpcd>
where
  { ?li tpcd:has_order ?ord .
    filter (?li+>tpcd:shipmode in ("MAIL", "SHIP") &&
      (?li+>tpcd:commitdate < ?li+>tpcd:receiptdate) &&
      (?li+>tpcd:shipdate < ?li+>tpcd:commitdate) &&
      (?li+>tpcd:receiptdate >= "1994-01-01"^^xsd:date) &&
      (?li+>tpcd:receiptdate < bif:dateadd ("year", 1, "1994-01-01"^^xsd:date)) )
  }
order by
  ?li+>tpcd:shipmode
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q13";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?c_count,
  count(1) as ?custdist
from <http://example.com/tpcd>
where {
    { select
        ?cust+>tpcd:custkey,
        count (?ord) as ?c_count
      where
        {
          ?cust a tpcd:customer .
          optional { ?cust tpcd:customer_of ?ord
              filter (!(?ord+>tpcd:comment like "%special%requests%")) }
        }
    }
  }
order by
  desc (count(1))
  desc (?c_count)
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q14";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (100 * sum (
      bif:equ(bif:LEFT(?part+>tpcd:type, 5), "PROMO") *
      ?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount) ) /
    sum (?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount)) ) as ?promo_revenue
from <http://example.com/tpcd>
where
  {
    ?li a tpcd:lineitem ; tpcd:has_part ?part .
    filter ((?li+>tpcd:shipdate >= "1995-09-01"^^xsd:date) &&
      (?li+>tpcd:shipdate < bif:dateadd("month", 1, "1995-09-01"^^xsd:date)) )
  }
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q15";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?supplier+>tpcd:suppkey ?supplier+>tpcd:name ?supplier+>tpcd:address ?supplier+>tpcd:phone ?total_revenue
from <http://example.com/tpcd>
where
  {
    ?supplier a tpcd:supplier .
      {
        select
          ?supplier
          (sum(?l_extendedprice * (1 - ?l_discount))) as ?total_revenue
        where
          {
            [ a tpcd:lineitem ; tpcd:shipdate ?l_shipdate ;
              tpcd:lineextendedprice ?l_extendedprice ; tpcd:linediscount ?l_discount ;
              tpcd:has_supplier ?supplier ] .
            filter (
                ?l_shipdate >= "1996-01-01"^^xsd:date and
                ?l_shipdate < bif:dateadd ("month", 3, "1996-01-01"^^xsd:date) )
          }
      }
      {
        select max (?l2_total_revenue) as ?maxtotal
        where
          {
              {
                select
                  ?supplier2
                  (sum(?l2_extendedprice * (1 - ?l2_discount))) as ?l2_total_revenue
                where
                  {
                    [ a tpcd:lineitem ; tpcd:shipdate ?l2_shipdate ;
                      tpcd:lineextendedprice ?l2_extendedprice ; tpcd:linediscount ?l2_discount ;
                      tpcd:has_supplier ?supplier2 ] .
                    filter (
                        ?l2_shipdate >= "1996-01-01"^^xsd:date and
                        ?l2_shipdate < bif:dateadd ("month", 3, "1996-01-01"^^xsd:date) )
                  }
              }
          }
      }
    filter (?total_revenue = ?maxtotal)
  }
order by
  ?supplier
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q16";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?part+>tpcd:brand,
  ?part+>tpcd:type,
  ?part+>tpcd:size,
  (count(distinct ?supp)) as ?supplier_cnt
from <http://example.com/tpcd>
where
  {
    ?ps a tpcd:partsupp ; tpcd:has_part ?part ; tpcd:has_supplier ?supp .
    filter (
      (?part+>tpcd:brand != "Brand#45") &&
      !(?part+>tpcd:type like "MEDIUM POLISHED%") &&
      (?part+>tpcd:size in (49, 14, 23, 45, 19, 3, 36, 9)) &&
      !bif:exists ((select (1) where {
        ?supp a tpcd:supplier; tpcd:comment ?badcomment . filter (?badcomment like "%Customer%Complaints%") } ) ) )
  }
order by
  desc ((count(distinct ?supp)))
  ?part+>tpcd:brand
  ?part+>tpcd:type
  ?part+>tpcd:size
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q17";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (sum(?li+>tpcd:lineextendedprice) / 7.0) as ?avg_yearly
from <http://example.com/tpcd>
where
  {
    ?li a tpcd:lineitem ; tpcd:has_part ?part .
    ?part tpcd:brand "Brand#23" ; tpcd:container "MED BOX" .
    filter (?li+>tpcd:linequantity < (
        select (0.2 * avg(?li2+>tpcd:linequantity)) as ?threshold
      where { ?li2  a tpcd:lineitem ; tpcd:has_part ?part } ) ) }
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q18";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select ?cust+>foaf:name ?cust+>tpcd:custkey ?ord+>tpcd:orderkey ?ord+>tpcd:orderdate ?ord+>tpcd:ordertotalprice sum(?li+>tpcd:linequantity)
from <http://example.com/tpcd>
where
  {
    ?cust a tpcd:customer ; foaf:name ?c_name .
    ?ord a tpcd:order ; tpcd:has_customer ?cust .
    ?li a tpcd:lineitem ; tpcd:has_order ?ord .
      {
        select ?sum_order sum (?li2+>tpcd:linequantity) as ?sum_q
        where
          {
            ?li2 a tpcd:lineitem ; tpcd:has_order ?sum_order .
          }
      } .
    filter (?sum_order = ?ord and ?sum_q > 250)
  }
order by desc (?ord+>tpcd:ordertotalprice) ?ord+>tpcd:orderdate
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q19";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (sum(?li+>tpcd:lineextendedprice * (1 - ?li+>tpcd:linediscount))) as ?revenue
from <http://example.com/tpcd>
where
  {
    ?li a tpcd:lineitem ; tpcd:has_part ?part ; tpcd:shipinstruct "DELIVER IN PERSON" .
    filter (?li+>tpcd:shipmode in ("AIR", "AIR REG") &&
      ( ( (?part+>tpcd:brand = "Brand#12") &&
          (?part+>tpcd:container in ("SM CASE", "SM BOX", "SM PACK", "SM PKG")) &&
          (?li+>tpcd:linequantity >= 1) && (?li+>tpcd:linequantity <= 1 + 10) &&
          (?part+>tpcd:size >= 1) && (?part+>tpcd:size <= 5) ) ||
        ( (?part+>tpcd:brand = "Brand#23") &&
          (?part+>tpcd:container in ("MED BAG", "MED BOX", "MED PKG", "MED PACK")) &&
          (?li+>tpcd:linequantity >= 10) && (?li+>tpcd:linequantity <= 10 + 10) &&
          (?part+>tpcd:size >= 1) && (?part+>tpcd:size <= 10) ) ||
        ( (?part+>tpcd:brand = "Brand#34") &&
          (?part+>tpcd:container in ("LG CASE", "LG BOX", "LG PACK", "LG PKG")) &&
          (?li+>tpcd:linequantity >= 20) && (?li+>tpcd:linequantity <= 20 + 10) &&
          (?part+>tpcd:size >= 1) && (?part+>tpcd:size <= 15) ) ) )
  }
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q20";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?supp+>tpcd:name,
  ?supp+>tpcd:address
from <http://example.com/tpcd>
where
  {
      {
        select
          ?supp, count (?big_ps) as ?big_ps_cnt
        where
          {
            ?supp+>tpcd:has_nation tpcd:name "CANADA" .
            ?big_ps a tpcd:partsupp ; tpcd:has_supplier ?supp .
            filter (
              (?big_ps+>tpcd:has_part+>tpcd:name like "forest%") &&
              (?big_ps+>tpcd:availqty > (
                  select
                    (0.5 * sum(?li+>tpcd:linequantity)) as ?qty_threshold
                  where
                    {
                      ?li a tpcd:lineitem ; tpcd:has_part ?big_ps+>tpcd:has_part ; tpcd:has_supplier ?supp .
                      filter ((?li+>tpcd:shipdate >= "1994-01-01"^^xsd:date) &&
                        (?li+>tpcd:shipdate < bif:dateadd ("year", 1, "1994-01-01"^^xsd:date)) ) } ) ) )
          }
       }
  }
order by
  ?supp+>tpcd:name
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q21";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
    ?supp+>tpcd:name,
    (count(1)) as ?numwait
from <http://example.com/tpcd>
where
  {
      { select ?l1 ?ord ?supp (count(1)) as ?l2_cnt
        where {
            ?supp a tpcd:supplier .
            ?supp+>tpcd:has_nation tpcd:name "SAUDI ARABIA" .
            ?l1 a tpcd:lineitem ; tpcd:has_supplier ?supp ; tpcd:has_order ?ord .
            ?ord tpcd:orderstatus "F" .
            ?l2 a tpcd:lineitem ; tpcd:has_supplier ?supp2 ; tpcd:has_order ?ord .
            optional {
                  { select ?l1 (count (1)) as ?l3_cnt
                    where {
                        ?l1 a tpcd:lineitem ; tpcd:has_supplier ?supp ; tpcd:has_order ?ord .
                        ?l3 a tpcd:lineitem ; tpcd:has_supplier ?supp3 ; tpcd:has_order ?ord .
                        filter ((?l3+>tpcd:receiptdate > ?l3+>tpcd:commitdate) && (?supp3 != ?supp)) } } }
            filter ((?l1+>tpcd:receiptdate > ?l1+>tpcd:commitdate) && (?supp2 != ?supp) && !bound (?l3_cnt))
          }
      }
  }
order by
    desc (count(1))
    ?supp+>tpcd:name
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO "Q22";

sparql
define sql:signal-void-variables 1
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (bif:LEFT (?cust+>tpcd:phone, 2)) as ?cntrycode,
  (count (1)) as ?numcust,
  sum (?cust+>tpcd:acctbal) as ?totacctbal
from <http://example.com/tpcd>
where {
    ?cust a tpcd:customer .
    filter (
      bif:LEFT (?cust+>tpcd:phone, 2) in ("13", "35", "31", "23", "29", "30", "17", "18") &&
      (?cust+>tpcd:acctbal >
        ( select (avg (?cust2+>tpcd:acctbal)) as ?acctbal_threshold
          where
            {
              ?cust2 a tpcd:customer .
              filter ((?cust2+>tpcd:acctbal > 0.00) &&
                bif:LEFT (?cust2+>tpcd:phone, 2) in ("13", "35", "31", "23", "29", "30", "17", "18") )
            } ) ) &&
      !bif:exists (
        ( select (1)
          where { ?cust tpcd:customer_of ?ord } ) ) )
  }
group by (bif:LEFT (?cust+>tpcd:phone, 2))
order by (bif:LEFT (?cust+>tpcd:phone, 2))
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

