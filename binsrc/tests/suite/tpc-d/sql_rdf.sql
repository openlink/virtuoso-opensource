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
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:customer "http://example.com/tpcd/customer/%d" (in c_custkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:lineitem "http://example.com/tpcd/lineitem/%d/%d" (in l_orderkey integer not null, in l_linenumber integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:nation "http://example.com/tpcd/nation/%d" (in l_nationkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:order "http://example.com/tpcd/order/%d" (in o_orderkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:part "http://example.com/tpcd/part/%d" (in p_partkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:partsupp "http://example.com/tpcd/partsupp/%d/%d" (in ps_partkey integer not null, in ps_suppkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tpcd:region "http://example.com/tpcd/region/%d" (in r_regionkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://www.openlinksw.com/schemas/tpcd#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
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
# Customers
        tpcd:customer (customers.C_CUSTKEY)
            a  tpcd:customer
                as virtrdf:TPCDcustomer-tpcd-type ;
            a  foaf:Organization
                as virtrdf:TPCDcustomer-foaf-type ;
            tpcd:custkey customers.C_CUSTKEY
                as virtrdf:TPCDcustomer-c_custkey ;
            foaf:name customers.C_NAME
                as virtrdf:TPCDcustomer-foaf_name ;
            tpcd:companyName customers.C_NAME
                as virtrdf:TPCDcustomer-c_name ;
            tpcd:has_nation tpcd:nation (customers.C_NATIONKEY)
                as virtrdf:TPCDcustomer-c_nationkey ;
            tpcd:address customers.C_ADDRESS
                as virtrdf:TPCDcustomer-c_address ;
            foaf:phone customers.C_PHONE
                as virtrdf:TPCDcustomer-foaf_phone ;
            tpcd:phone customers.C_PHONE
                as virtrdf:TPCDcustomer-phone ;
            tpcd:acctbal customers.C_ACCTBAL
                as virtrdf:TPCDcustomer-acctbal ;
            tpcd:mktsegment customers.C_MKTSEGMENT
                as virtrdf:TPCDcustomer-c_mktsegment ;
            tpcd:comment customers.C_COMMENT
                as virtrdf:TPCDcustomer-c_comment .

# Nations
        tpcd:nation (customers.C_NATIONKEY)
            tpcd:nation_of tpcd:customer (customers.C_CUSTKEY) as virtrdf:TPCDcustomer-nation_of .

# Lineitems
        tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER)
            a tpcd:lineitem
                as virtrdf:TPCDlineitem-lineitems ;
            tpcd:has_order tpcd:order (lineitems.L_ORDERKEY)
                as virtrdf:TPCDlineitem-l_orderkey ;
            tpcd:has_part tpcd:part (lineitems.L_PARTKEY)
                as virtrdf:TPCDlineitem-l_partkey ;
            tpcd:has_supplier tpcd:supplier (lineitems.L_SUPPKEY)
                as virtrdf:TPCDlineitem-l_suppkey ;
            tpcd:linenumber lineitems.L_LINENUMBER
                as virtrdf:TPCDlineitem-l_linenumber ;
            tpcd:linequantity lineitems.L_QUANTITY
                as virtrdf:TPCDlineitem-l_linequantity ;
            tpcd:lineextendedprice lineitems.L_EXTENDEDPRICE
                as virtrdf:TPCDlineitem-l_lineextendedprice ;
            tpcd:linediscount lineitems.L_DISCOUNT
                as virtrdf:TPCDlineitem-l_linediscount ;
            tpcd:linetax lineitems.L_TAX
                as virtrdf:TPCDlineitem-l_linetax ;
            tpcd:returnflag lineitems.L_RETURNFLAG
                as virtrdf:TPCDlineitem-l_returnflag ;
            tpcd:linestatus lineitems.L_LINESTATUS
                as virtrdf:TPCDlineitem-l_linestatus ;
            tpcd:shipdate lineitems.L_SHIPDATE
                as virtrdf:TPCDlineitem-l_shipdate ;
            tpcd:commitdate lineitems.L_COMMITDATE
                as virtrdf:TPCDlineitem-l_commitdate ;
            tpcd:receiptdate lineitems.L_RECEIPTDATE
                as virtrdf:TPCDlineitem-l_receiptdate ;
            tpcd:shipinstruct lineitems.L_SHIPINSTRUCT
                as virtrdf:TPCDlineitem-l_shipinstruct ;
            tpcd:shipmode lineitems.L_SHIPMODE
                as virtrdf:TPCDlineitem-l_shipmode ;
            tpcd:comment lineitems.L_COMMENT
                as virtrdf:TPCDlineitem-l_comment .

        tpcd:part (lineitems.L_PARTKEY)
            tpcd:part_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:TPCDlineitem-part_of .

        tpcd:order (lineitems.L_ORDERKEY)
            tpcd:order_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:TPCDlineitem-order_of .

        tpcd:supplier (lineitems.L_SUPPKEY)
            tpcd:supplier_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:TPCDlineitem-supplier_of .

# Nation
        tpcd:nation (nations.N_NATIONKEY)
            a tpcd:nation
                as virtrdf:TPCDnation-nations ;
            tpcd:name nations.N_NAME
                as virtrdf:TPCDnation-n_name ;
            tpcd:has_region tpcd:region (nations.N_REGIONKEY)
                as virtrdf:TPCDnation-n_regionkey ;
            tpcd:comment nations.N_COMMENT
                as virtrdf:TPCDnation-n_comment .

        tpcd:region (nations.N_REGIONKEY)
            tpcd:region_of tpcd:nation (nations.N_NATIONKEY) as virtrdf:TPCDnation-region_of .

# Order
        tpcd:order (orders.O_ORDERKEY)
            a tpcd:order
                as virtrdf:TPCDorder-orders ;
            tpcd:orderkey orders.O_ORDERKEY
                as virtrdf:TPCDorder-o_orderkey ;
            tpcd:has_customer tpcd:customer (orders.O_CUSTKEY)
                as virtrdf:TPCDorder-o_custkey ;
            tpcd:orderstatus orders.O_ORDERSTATUS
                as virtrdf:TPCDorder-o_orderstatus ;
            tpcd:ordertotalprice orders.O_TOTALPRICE
                as virtrdf:TPCDorder-o_totalprice ;
            tpcd:orderdate orders.O_ORDERDATE
                as virtrdf:TPCDorder-o_orderdate ;
            tpcd:orderpriority orders.O_ORDERPRIORITY
                as virtrdf:TPCDorder-o_orderpriority ;
            tpcd:clerk orders.O_CLERK
                as virtrdf:TPCDorder-o_clerk ;
            tpcd:shippriority orders.O_SHIPPRIORITY
                as virtrdf:TPCDorder-o_shippriority ;
            tpcd:comment orders.O_COMMENT
                as virtrdf:TPCDorder-o_comment .

        tpcd:customer (orders.O_CUSTKEY)
            tpcd:customer_of tpcd:order (orders.O_ORDERKEY) as virtrdf:TPCDorder-customer_of .

# Part
        tpcd:part (parts.P_PARTKEY)
            a tpcd:part
                as virtrdf:TPCDpart-parts ;
            tpcd:partkey parts.P_PARTKEY
                as virtrdf:TPCDpart-p_partkey ;
            tpcd:name parts.P_NAME
                as virtrdf:TPCDpart-p_name ;
            tpcd:mfgr parts.P_MFGR
                as virtrdf:TPCDpart-p_mfgr ;
            tpcd:brand parts.P_BRAND
                as virtrdf:TPCDpart-p_brand ;
            tpcd:type parts.P_TYPE
                as virtrdf:TPCDpart-p_type ;
            tpcd:size parts.P_SIZE
                as virtrdf:TPCDpart-p_size ;
            tpcd:container parts.P_CONTAINER
                as virtrdf:TPCDpart-p_container ;
            tpcd:comment parts.P_COMMENT
                as virtrdf:TPCDpart-p_comment .

# Partsupp
        tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            a tpcd:partsupp
                as virtrdf:TPCDpartsupp-partsupps ;
            tpcd:has_part tpcd:part (partsupps.PS_PARTKEY)
                as virtrdf:TPCDpartsupp-ps_partkey ;
            tpcd:has_ps_partkey partsupps.PS_PARTKEY
                as virtrdf:TPCDpartsupp-has_ps_partkey ;
            tpcd:has_supplier tpcd:supplier (partsupps.PS_SUPPKEY)
                as virtrdf:TPCDpartsupp-ps_suppkey ;
            tpcd:availqty partsupps.PS_AVAILQTY
                as virtrdf:TPCDpartsupp-ps_availqty ;
            tpcd:supplycost partsupps.PS_SUPPLYCOST
                as virtrdf:TPCDpartsupp-ps_supplycost ;
            tpcd:comment partsupps.PS_COMMENT
                as virtrdf:TPCDpartsupp-ps_comment .

        tpcd:part (partsupps.PS_PARTKEY)
            tpcd:part_of tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:TPCDpartsupp-part_of .

        tpcd:supplier (partsupps.PS_SUPPKEY)
            tpcd:supplier_of tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:TPCDpartsupp-supplier_of .

# Region
        tpcd:region (regions.R_REGIONKEY)
            a tpcd:region
                as virtrdf:TPCDregion-regions ;
            tpcd:name regions.R_NAME
                as virtrdf:TPCDregion-r_name ;
            tpcd:comment regions.R_COMMENT
                as virtrdf:TPCDregion-r_comment .

# Supplier
        tpcd:supplier (suppliers.S_SUPPKEY)
            a tpcd:supplier
                as virtrdf:TPCDsupplier-suppliers ;
            tpcd:suppkey suppliers.S_SUPPKEY
                as virtrdf:TPCDsupplier-s_suppkey ;
            tpcd:name suppliers.S_NAME
                as virtrdf:TPCDsupplier-s_name ;
            tpcd:address suppliers.S_ADDRESS
                as virtrdf:TPCDsupplier-s_address ;
            tpcd:has_nation tpcd:nation (suppliers.S_NATIONKEY)
                as virtrdf:TPCDsupplier-s_nationkey ;
            foaf:phone suppliers.S_PHONE
                as virtrdf:TPCDsupplier-foaf_phone ;
            tpcd:phone suppliers.S_PHONE
                as virtrdf:TPCDsupplier-s_phone ;
            tpcd:acctbal suppliers.S_ACCTBAL
                as virtrdf:TPCDsupplier-s_acctbal ;
            tpcd:comment suppliers.S_COMMENT
                as virtrdf:TPCDsupplier-s_comment .

        tpcd:nation (suppliers.S_NATIONKEY)
            tpcd:nation_of tpcd:supplier (suppliers.S_SUPPKEY) as virtrdf:TPCDsupplier-nation_of .
    }
}
;
