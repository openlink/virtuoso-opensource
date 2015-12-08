use DB;

GRANT SELECT ON DB.DBA.partsupp  TO "SPARQL";
GRANT SELECT ON DB.DBA.supplier  TO "SPARQL";
GRANT SELECT ON DB.DBA.customer  TO "SPARQL";
GRANT SELECT ON DB.DBA.part      TO "SPARQL";
GRANT SELECT ON DB.DBA.lineitem  TO "SPARQL";
GRANT SELECT ON DB.DBA.orders    TO "SPARQL";
GRANT SELECT ON DB.DBA.nation    TO "SPARQL";
GRANT SELECT ON DB.DBA.region    TO "SPARQL";

sparql drop quad map virtrdf:TPCD
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:customer "http://lod2.eu/schemas/rdfh-inst#customer_%d" (in c_custkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:lineitem "http://lod2.eu/schemas/rdfh-inst#lineitem_%d_%d" (in l_orderkey integer not null, in l_linenumber integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:nation "http://lod2.eu/schemas/rdfh-inst#nation_%d" (in l_nationkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:order "http://lod2.eu/schemas/rdfh-inst#order_%d" (in o_orderkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:part "http://lod2.eu/schemas/rdfh-inst#part_%d" (in p_partkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:partsupp "http://lod2.eu/schemas/rdfh-inst#partsupp_%d_%d" (in ps_partkey integer not null, in ps_suppkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:region "http://lod2.eu/schemas/rdfh-inst#region_%d" (in r_regionkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpcd:supplier "http://lod2.eu/schemas/rdfh-inst#supplier_%d" (in s_supplierkey integer not null) option (bijection, deref) .
;

sparql
prefix tpcd: <http://lod2.eu/schemas/rdfh#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
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
            tpcd:c_custkey customers.C_CUSTKEY
                as virtrdf:TPCDcustomer-c_custkey ;
            foaf:name customers.C_NAME
                as virtrdf:TPCDcustomer-foaf_name ;
            tpcd:c_name customers.C_NAME
                as virtrdf:TPCDcustomer-c_name ;
            tpcd:c_has_nation tpcd:nation (customers.C_NATIONKEY)
                as virtrdf:TPCDcustomer-c_nationkey ;
            tpcd:c_address customers.C_ADDRESS
                as virtrdf:TPCDcustomer-c_address ;
            foaf:phone customers.C_PHONE
                as virtrdf:TPCDcustomer-foaf_phone ;
            tpcd:c_phone customers.C_PHONE
                as virtrdf:TPCDcustomer-phone ;
            tpcd:c_acctbal customers.C_ACCTBAL
                as virtrdf:TPCDcustomer-acctbal ;
            tpcd:c_mktsegment customers.C_MKTSEGMENT
                as virtrdf:TPCDcustomer-c_mktsegment ;
            tpcd:c_comment customers.C_COMMENT
                as virtrdf:TPCDcustomer-c_comment .

# Nations
        tpcd:nation (customers.C_NATIONKEY)
            tpcd:n_nation_of tpcd:customer (customers.C_CUSTKEY) as virtrdf:TPCDcustomer-nation_of .

# Lineitems
        tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER)
            a tpcd:lineitem
                as virtrdf:TPCDlineitem-lineitems ;
            tpcd:l_has_order tpcd:order (lineitems.L_ORDERKEY)
                as virtrdf:TPCDlineitem-l_orderkey ;
            tpcd:l_has_part tpcd:part (lineitems.L_PARTKEY)
                as virtrdf:TPCDlineitem-l_partkey ;
            tpcd:l_has_supplier tpcd:supplier (lineitems.L_SUPPKEY)
                as virtrdf:TPCDlineitem-l_suppkey ;
            tpcd:l_linenumber lineitems.L_LINENUMBER
                as virtrdf:TPCDlineitem-l_linenumber ;
            tpcd:l_linequantity lineitems.L_QUANTITY
                as virtrdf:TPCDlineitem-l_linequantity ;
            tpcd:l_lineextendedprice lineitems.L_EXTENDEDPRICE
                as virtrdf:TPCDlineitem-l_lineextendedprice ;
            tpcd:l_linediscount lineitems.L_DISCOUNT
                as virtrdf:TPCDlineitem-l_linediscount ;
            tpcd:l_linetax lineitems.L_TAX
                as virtrdf:TPCDlineitem-l_linetax ;
            tpcd:l_returnflag lineitems.L_RETURNFLAG
                as virtrdf:TPCDlineitem-l_returnflag ;
            tpcd:l_linestatus lineitems.L_LINESTATUS
                as virtrdf:TPCDlineitem-l_linestatus ;
            tpcd:l_shipdate lineitems.L_SHIPDATE
                as virtrdf:TPCDlineitem-l_shipdate ;
            tpcd:l_commitdate lineitems.L_COMMITDATE
                as virtrdf:TPCDlineitem-l_commitdate ;
            tpcd:l_receiptdate lineitems.L_RECEIPTDATE
                as virtrdf:TPCDlineitem-l_receiptdate ;
            tpcd:l_shipinstruct lineitems.L_SHIPINSTRUCT
                as virtrdf:TPCDlineitem-l_shipinstruct ;
            tpcd:l_shipmode lineitems.L_SHIPMODE
                as virtrdf:TPCDlineitem-l_shipmode ;
            tpcd:l_comment lineitems.L_COMMENT
                as virtrdf:TPCDlineitem-l_comment .

        tpcd:part (lineitems.L_PARTKEY)
            tpcd:p_part_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:TPCDlineitem-part_of .

        tpcd:order (lineitems.L_ORDERKEY)
            tpcd:o_order_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:TPCDlineitem-order_of .

        tpcd:supplier (lineitems.L_SUPPKEY)
            tpcd:s_supplier_of tpcd:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:TPCDlineitem-supplier_of .

# Nation
        tpcd:nation (nations.N_NATIONKEY)
            a tpcd:nation
                as virtrdf:TPCDnation-nations ;
            tpcd:n_name nations.N_NAME
                as virtrdf:TPCDnation-n_name ;
            tpcd:n_has_region tpcd:region (nations.N_REGIONKEY)
                as virtrdf:TPCDnation-n_regionkey ;
            tpcd:n_comment nations.N_COMMENT
                as virtrdf:TPCDnation-n_comment .

        tpcd:region (nations.N_REGIONKEY)
            tpcd:r_region_of tpcd:nation (nations.N_NATIONKEY) as virtrdf:TPCDnation-region_of .

# Order
        tpcd:order (orders.O_ORDERKEY)
            a tpcd:order
                as virtrdf:TPCDorder-orders ;
            tpcd:o_orderkey orders.O_ORDERKEY
                as virtrdf:TPCDorder-o_orderkey ;
            tpcd:o_has_customer tpcd:customer (orders.O_CUSTKEY)
                as virtrdf:TPCDorder-o_custkey ;
            tpcd:o_orderstatus orders.O_ORDERSTATUS
                as virtrdf:TPCDorder-o_orderstatus ;
            tpcd:o_ordertotalprice orders.O_TOTALPRICE
                as virtrdf:TPCDorder-o_totalprice ;
            tpcd:o_orderdate orders.O_ORDERDATE
                as virtrdf:TPCDorder-o_orderdate ;
            tpcd:o_orderpriority orders.O_ORDERPRIORITY
                as virtrdf:TPCDorder-o_orderpriority ;
            tpcd:o_clerk orders.O_CLERK
                as virtrdf:TPCDorder-o_clerk ;
            tpcd:o_shippriority orders.O_SHIPPRIORITY
                as virtrdf:TPCDorder-o_shippriority ;
            tpcd:o_comment orders.O_COMMENT
                as virtrdf:TPCDorder-o_comment .

        tpcd:customer (orders.O_CUSTKEY)
            tpcd:c_customer_of tpcd:order (orders.O_ORDERKEY) as virtrdf:TPCDorder-customer_of .

# Part
        tpcd:part (parts.P_PARTKEY)
            a tpcd:part
                as virtrdf:TPCDpart-parts ;
            tpcd:p_partkey parts.P_PARTKEY
                as virtrdf:TPCDpart-p_partkey ;
            tpcd:p_name parts.P_NAME
                as virtrdf:TPCDpart-p_name ;
            tpcd:p_mfgr parts.P_MFGR
                as virtrdf:TPCDpart-p_mfgr ;
            tpcd:p_brand parts.P_BRAND
                as virtrdf:TPCDpart-p_brand ;
            tpcd:p_type parts.P_TYPE
                as virtrdf:TPCDpart-p_type ;
            tpcd:p_size parts.P_SIZE
                as virtrdf:TPCDpart-p_size ;
            tpcd:p_container parts.P_CONTAINER
                as virtrdf:TPCDpart-p_container ;
            tpcd:p_comment parts.P_COMMENT
                as virtrdf:TPCDpart-p_comment .

# Partsupp
        tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            a tpcd:partsupp
                as virtrdf:TPCDpartsupp-partsupps ;
            tpcd:ps_has_part tpcd:part (partsupps.PS_PARTKEY)
                as virtrdf:TPCDpartsupp-ps_partkey ;
            tpcd:has_ps_partkey partsupps.PS_PARTKEY
                as virtrdf:TPCDpartsupp-has_ps_partkey ;
            tpcd:ps_has_supplier tpcd:supplier (partsupps.PS_SUPPKEY)
                as virtrdf:TPCDpartsupp-ps_suppkey ;
            tpcd:ps_availqty partsupps.PS_AVAILQTY
                as virtrdf:TPCDpartsupp-ps_availqty ;
            tpcd:ps_supplycost partsupps.PS_SUPPLYCOST
                as virtrdf:TPCDpartsupp-ps_supplycost ;
            tpcd:ps_comment partsupps.PS_COMMENT
                as virtrdf:TPCDpartsupp-ps_comment .

        tpcd:part (partsupps.PS_PARTKEY)
            tpcd:p_part_of tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:TPCDpartsupp-part_of .

        tpcd:supplier (partsupps.PS_SUPPKEY)
            tpcd:s_supplier_of tpcd:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:TPCDpartsupp-supplier_of .

# Region
        tpcd:region (regions.R_REGIONKEY)
            a tpcd:region
                as virtrdf:TPCDregion-regions ;
            tpcd:r_name regions.R_NAME
                as virtrdf:TPCDregion-r_name ;
            tpcd:r_comment regions.R_COMMENT
                as virtrdf:TPCDregion-r_comment .

# Supplier
        tpcd:supplier (suppliers.S_SUPPKEY)
            a tpcd:supplier
                as virtrdf:TPCDsupplier-suppliers ;
            tpcd:s_suppkey suppliers.S_SUPPKEY
                as virtrdf:TPCDsupplier-s_suppkey ;
            tpcd:s_name suppliers.S_NAME
                as virtrdf:TPCDsupplier-s_name ;
            tpcd:s_address suppliers.S_ADDRESS
                as virtrdf:TPCDsupplier-s_address ;
            tpcd:s_has_nation tpcd:nation (suppliers.S_NATIONKEY)
                as virtrdf:TPCDsupplier-s_nationkey ;
            foaf:phone suppliers.S_PHONE
                as virtrdf:TPCDsupplier-foaf_phone ;
            tpcd:s_phone suppliers.S_PHONE
                as virtrdf:TPCDsupplier-s_phone ;
            tpcd:s_acctbal suppliers.S_ACCTBAL
                as virtrdf:TPCDsupplier-s_acctbal ;
            tpcd:s_comment suppliers.S_COMMENT
                as virtrdf:TPCDsupplier-s_comment .

        tpcd:nation (suppliers.S_NATIONKEY)
            tpcd:n_nation_of tpcd:supplier (suppliers.S_SUPPKEY) as virtrdf:TPCDsupplier-nation_of .
    }
}
;
