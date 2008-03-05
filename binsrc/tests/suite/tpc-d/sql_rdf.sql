use DB;

GRANT SELECT ON DB.DBA.partsupp  TO "SPARQL";
GRANT SELECT ON DB.DBA.supplier  TO "SPARQL";
GRANT SELECT ON DB.DBA.customer  TO "SPARQL";
GRANT SELECT ON DB.DBA.history   TO "SPARQL";
GRANT SELECT ON DB.DBA.part      TO "SPARQL";
GRANT SELECT ON DB.DBA.lineitem  TO "SPARQL";
GRANT SELECT ON DB.DBA.orders    TO "SPARQL";
GRANT SELECT ON DB.DBA.nation    TO "SPARQL";
GRANT SELECT ON DB.DBA.region    TO "SPARQL";

create procedure DB.DBA.SPARQL_NW_RUN (in txt varchar)
{
  declare REPORT, stat, msg, sqltext varchar;
  declare metas, rowset any;
  result_names (REPORT);
  sqltext := string_output_string (sparql_to_sql_text (txt));
  stat := '00000';
  msg := '';
  rowset := null;
  exec (sqltext, stat, msg, vector (), 1000, metas, rowset);
  result ('STATE=' || stat || ': ' || msg);
  if (__tag (rowset) = 193)
    {
      foreach (any r in rowset) do
        result (r[0] || ': ' || r[1]);
    }
}
;

sparql drop quad map graph iri("http://example.com/tpcd")
;

sparql drop quad storage virtrdf:tpcd
;

sparql drop quad map virtrdf:tpcd
;

sparql drop quad map virtrdf:TPCD
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:customer "http://example.com/tpcd/customer/%d" (in c_custkey integer not null) option (bijection, deref) .
create iri class tpcd:lineitem "http://example.com/tpcd/lineitem/%d/%d" (in l_orderkey integer not null, in l_linenumber integer not null) option (bijection, deref) .
create iri class tpcd:nation "http://example.com/tpcd/nation/%d" (in l_nationkey integer not null) option (bijection, deref) .
create iri class tpcd:order "http://example.com/tpcd/order/%d" (in o_orderkey integer not null) option (bijection, deref) .
create iri class tpcd:part "http://example.com/tpcd/part/%d" (in p_partkey integer not null) option (bijection, deref) .
create iri class tpcd:partsupp "http://example.com/tpcd/partsupp/%d/%d" (in ps_partkey integer not null, in ps_suppkey integer not null) option (bijection, deref) .
create iri class tpcd:region "http://example.com/tpcd/region/%d" (in r_regionkey integer not null) option (bijection, deref) .
create iri class tpcd:supplier "http://example.com/tpcd/supplier/%d" (in s_supplierkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
alter quad storage virtrdf:DefaultQuadStorage
from DB.DBA.LINEITEM as lineitems
from DB.DBA.CUSTOMER as customers
from DB.DBA.NATION as nations
from DB.DBA.ORDERS as orders
from DB.DBA.PART as parts
from DB.DBA.PARTSUPP as partsupps
from DB.DBA.REGION as regions
from DB.DBA.SUPPLIER as suppliers
where (^{suppliers.}^.S_NATIONKEY = ^{nations.}^.N_NATIONKEY)
where (^{customers.}^.C_NATIONKEY = ^{nations.}^.N_NATIONKEY)
{
    create virtrdf:TPCD as graph iri ("http://example.com/tpcd") option (exclusive)
    {
        tpcd:customer (customers.C_CUSTKEY)
            a  tpcd:customer
                as virtrdf:customer-tpcd-type ;
            a  foaf:Organization
                as virtrdf:customer-foaf-type ;
            tpcd:custkey customers.C_CUSTKEY
                as virtrdf:customer-c_custkey ;
            foaf:name customers.C_NAME
                as virtrdf:customer-foaf_name ;
            tpcd:companyName customers.C_NAME
                as virtrdf:customer-c_name ;
            tpcd:has_nation tpcd:nation (customers.C_NATIONKEY)
                as virtrdf:customer-c_nationkey ;
            tpcd:address customers.C_ADDRESS
                as virtrdf:customer-c_address ;
            foaf:phone customers.C_PHONE
                as virtrdf:customer-foaf_phone ;
            tpcd:phone customers.C_PHONE
                as virtrdf:customer-phone ;
            tpcd:acctbal customers.C_ACCTBAL
                as virtrdf:customer-acctbal ;
            tpcd:mktsegment customers.C_MKTSEGMENT
                as virtrdf:customer-c_mktsegment ;
            tpcd:comment customers.C_COMMENT
                as virtrdf:customer-c_comment .

        tpcd:nation (customers.C_NATIONKEY)
            tpcd:nation_of tpcd:customer (customers.C_CUSTKEY) as virtrdf:customer-nation_of .

        tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER)
            a tpcd:lineitem
                as virtrdf:lineitem-lineitems ;
            tpcd:has_order tpcd:order (lineitems.L_ORDERKEY)
                as virtrdf:lineitem-l_orderkey ;
            tpcd:has_part tpcd:part (lineitems.L_PARTKEY)
                as virtrdf:lineitem-l_partkey ;
            tpcd:has_supplier tpcd:supplier (lineitems.L_SUPPKEY)
                as virtrdf:lineitem-l_suppkey ;
            tpcd:linenumber lineitems.L_LINENUMBER
                as virtrdf:lineitem-l_linenumber ;
            tpcd:linequantity lineitems.L_QUANTITY
                as virtrdf:lineitem-l_linequantity ;
            tpcd:lineextendedprice lineitems.L_EXTENDEDPRICE
                as virtrdf:lineitem-l_lineextendedprice ;
            tpcd:linediscount lineitems.L_DISCOUNT
                as virtrdf:lineitem-l_linediscount ;
            tpcd:linetax lineitems.L_TAX
                as virtrdf:lineitem-l_linetax ;
            tpcd:returnflag lineitems.L_RETURNFLAG
                as virtrdf:lineitem-l_returnflag ;
            tpcd:linestatus lineitems.L_LINESTATUS
                as virtrdf:lineitem-l_linestatus ;
            tpcd:shipdate lineitems.L_SHIPDATE
                as virtrdf:lineitem-l_shipdate ;
            tpcd:commitdate lineitems.L_COMMITDATE
                as virtrdf:lineitem-l_commitdate ;
            tpcd:receiptdate lineitems.L_RECEIPTDATE
                as virtrdf:lineitem-l_receiptdate ;
            tpcd:shipinstruct lineitems.L_SHIPINSTRUCT
                as virtrdf:lineitem-l_shipinstruct ;
            tpcd:shipmode lineitems.L_SHIPMODE
                as virtrdf:lineitem-l_shipmode ;
            tpcd:comment lineitems.L_COMMENT
                as virtrdf:lineitem-l_comment .

        tpcd:part (lineitems.L_PARTKEY)
            tpcd:part_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-part_of .

        tpcd:order (lineitems.L_ORDERKEY)
            tpcd:order_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-order_of .

        tpcd:supplier (lineitems.L_SUPPKEY)
            tpcd:supplier_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-supplier_of .

        tpcd:nation (nations.N_NATIONKEY)
            a tpcd:nation
                as virtrdf:nation-nations ;
            tpcd:name nations.N_NAME
                as virtrdf:nation-n_name ;
            tpcd:has_region tpcd:region (nations.N_REGIONKEY)
                as virtrdf:nation-n_regionkey ;
            tpcd:comment nations.N_COMMENT
                as virtrdf:nation-n_comment .

        tpcd:region (nations.N_REGIONKEY)
            tpcd:region_of tpcd:nation (nations.N_NATIONKEY) as virtrdf:nation-region_of .

        tpcd:order (orders.O_ORDERKEY)
            a tpcd:order
                as virtrdf:order-orders ;
            tpcd:orderkey orders.O_ORDERKEY
                as virtrdf:order-o_orderkey ;
            tpcd:has_customer tpcd:customer (orders.O_CUSTKEY)
                as virtrdf:order-o_custkey ;
            tpcd:orderstatus orders.O_ORDERSTATUS
                as virtrdf:order-o_orderstatus ;
            tpcd:ordertotalprice orders.O_TOTALPRICE
                as virtrdf:order-o_totalprice ;
            tpcd:orderdate orders.O_ORDERDATE
                as virtrdf:order-o_orderdate ;
            tpcd:orderpriority orders.O_ORDERPRIORITY
                as virtrdf:order-o_orderpriority ;
            tpcd:clerk orders.O_CLERK
                as virtrdf:order-o_clerk ;
            tpcd:shippriority orders.O_SHIPPRIORITY
                as virtrdf:order-o_shippriority ;
            tpcd:comment orders.O_COMMENT
                as virtrdf:order-o_comment .

        tpcd:customer (orders.O_CUSTKEY)
            tpcd:customer_of tpcd:order (orders.O_ORDERKEY) as virtrdf:order-customer_of .

        tpcd:part (parts.P_PARTKEY)
            a tpcd:part
                as virtrdf:part-parts ;
            tpcd:partkey parts.P_PARTKEY
                as virtrdf:part-p_partkey ;
            tpcd:name parts.P_NAME
                as virtrdf:part-p_name ;
            tpcd:mfgr parts.P_MFGR
                as virtrdf:part-p_mfgr ;
            tpcd:brand parts.P_BRAND
                as virtrdf:part-p_brand ;
            tpcd:type parts.P_TYPE
                as virtrdf:part-p_type ;
            tpcd:size parts.P_SIZE
                as virtrdf:part-p_size ;
            tpcd:container parts.P_CONTAINER
                as virtrdf:part-p_container ;
            tpcd:comment parts.P_COMMENT
                as virtrdf:part-p_comment .

        tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            a tpcd:partsupp
                as virtrdf:partsupp-partsupps ;
            tpcd:has_part tpcd:part (partsupps.PS_PARTKEY)
                as virtrdf:partsupp-ps_partkey ;
            tpcd:has_supplier tpcd:supplier (partsupps.PS_SUPPKEY)
                as virtrdf:partsupp-ps_suppkey ;
            tpcd:availqty partsupps.PS_AVAILQTY
                as virtrdf:partsupp-ps_availqty ;
            tpcd:supplycost partsupps.PS_SUPPLYCOST
                as virtrdf:partsupp-ps_supplycost ;
            tpcd:comment partsupps.PS_COMMENT
                as virtrdf:partsupp-ps_comment .

        tpcd:part (partsupps.PS_PARTKEY)
            tpcd:part_of tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:partsupp-part_of .

        tpcd:supplier (partsupps.PS_SUPPKEY)
            tpcd:supplier_of tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:partsupp-supplier_of .

        tpcd:region (regions.R_REGIONKEY)
            a tpcd:region
                as virtrdf:region-regions ;
            tpcd:name regions.R_NAME
                as virtrdf:region-r_name ;
            tpcd:comment regions.R_COMMENT
                as virtrdf:region-r_comment .

        tpcd:supplier (suppliers.S_SUPPKEY)
            a tpcd:supplier
                as virtrdf:supplier-suppliers ;
            tpcd:name suppliers.S_NAME
                as virtrdf:supplier-s_name ;
            tpcd:address suppliers.S_ADDRESS
                as virtrdf:supplier-s_address ;
            tpcd:has_nation tpcd:nation (suppliers.S_NATIONKEY)
                as virtrdf:supplier-s_nationkey ;
            foaf:phone suppliers.S_PHONE
                as virtrdf:supplier-foaf_phone ;
            tpcd:phone suppliers.S_PHONE
                as virtrdf:supplier-s_phone ;
            tpcd:acctbal suppliers.S_ACCTBAL
                as virtrdf:supplier-s_acctbal ;
            tpcd:comment suppliers.S_COMMENT
                as virtrdf:supplier-s_comment .

        tpcd:nation (suppliers.S_NATIONKEY)
            tpcd:nation_of tpcd:supplier (suppliers.S_SUPPKEY) as virtrdf:supplier-nation_of .
    }
}
;
