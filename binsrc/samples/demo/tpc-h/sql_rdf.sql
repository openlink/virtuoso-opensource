use DB;

GRANT SELECT ON TPCH.DBA.PARTSUPP  TO "SPARQL";
GRANT SELECT ON TPCH.DBA.SUPPLIER  TO "SPARQL";
GRANT SELECT ON TPCH.DBA.CUSTOMER  TO "SPARQL";
GRANT SELECT ON TPCH.DBA.HISTORY   TO "SPARQL";
GRANT SELECT ON TPCH.DBA.PART      TO "SPARQL";
GRANT SELECT ON TPCH.DBA.LINEITEM  TO "SPARQL";
GRANT SELECT ON TPCH.DBA.ORDERS    TO "SPARQL";
GRANT SELECT ON TPCH.DBA.NATION    TO "SPARQL";
GRANT SELECT ON TPCH.DBA.REGION    TO "SPARQL";

SPARQL
drop quad map virtrdf:TPCH
;

SPARQL
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpch:customer "http://^{URIQADefaultHost}^/tpch/customer/%U%d#this" (in custname varchar, in c_custkey integer not null) option (bijection, deref) .
create iri class tpch:lineitem "http://^{URIQADefaultHost}^/tpch/lineitem/%d/%d#this" (in l_orderkey integer not null, in l_linenumber integer not null) option (bijection, deref) .
create iri class tpch:nation "http://^{URIQADefaultHost}^/tpch/nation/%U%d#this" (in name varchar, in l_nationkey integer not null) option (bijection, deref) .
create iri class tpch:order "http://^{URIQADefaultHost}^/tpch/order/%d#this" (in o_orderkey integer not null) option (bijection, deref) .
create iri class tpch:part "http://^{URIQADefaultHost}^/tpch/part/%U%d#this" (in p_partname varchar, in p_partkey integer not null) option (bijection, deref) .
create iri class tpch:partsupp "http://^{URIQADefaultHost}^/tpch/partsupp/%d/%d#this" (in ps_partkey integer not null, in ps_suppkey integer not null) option (bijection, deref) .
create iri class tpch:region "http://^{URIQADefaultHost}^/tpch/region/%U%d#this" (in name varchar, in r_regionkey integer not null) option (bijection, deref) .
create iri class tpch:supplier "http://^{URIQADefaultHost}^/tpch/supplier/%U%d#this" (in name varchar, in s_supplierkey integer not null) option (bijection, deref) .
;

SPARQL
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
alter quad storage virtrdf:DefaultQuadStorage
from TPCH.DBA.LINEITEM as lineitems
from TPCH.DBA.CUSTOMER as customers
from TPCH.DBA.NATION as nations
from TPCH.DBA.ORDERS as orders
from TPCH.DBA.PART as parts
from TPCH.DBA.PARTSUPP as partsupps
from TPCH.DBA.REGION as regions
from TPCH.DBA.SUPPLIER as suppliers
where (^{suppliers.}^.S_NATIONKEY = ^{nations.}^.N_NATIONKEY)
where (^{customers.}^.C_NATIONKEY = ^{nations.}^.N_NATIONKEY)
{
    create virtrdf:TPCH as graph iri ("http://^{URIQADefaultHost}^/tpch") option (exclusive)
    {
# Customers
        tpch:customer (customers.C_NAME, customers.C_CUSTKEY)
            a  tpch:customer
                as virtrdf:customer-tpch-type ;
            a  foaf:Organization
                as virtrdf:customer-foaf-type ;
            tpch:custkey customers.C_CUSTKEY
                as virtrdf:customer-c_custkey ;
            foaf:name customers.C_NAME
                as virtrdf:customer-foaf_name ;
            tpch:companyName customers.C_NAME
                as virtrdf:customer-c_name ;
            tpch:has_nation tpch:nation (nations.N_NAME, customers.C_NATIONKEY)
                as virtrdf:customer-c_nationkey ;
            tpch:address customers.C_ADDRESS
                as virtrdf:customer-c_address ;
            foaf:phone customers.C_PHONE
                as virtrdf:customer-foaf_phone ;
            tpch:phone customers.C_PHONE
                as virtrdf:customer-phone ;
            tpch:acctbal customers.C_ACCTBAL
                as virtrdf:customer-acctbal ;
            tpch:mktsegment customers.C_MKTSEGMENT
                as virtrdf:customer-c_mktsegment ;
            tpch:comment customers.C_COMMENT
                as virtrdf:customer-c_comment .

# Nations
        tpch:nation (nations.N_NAME, customers.C_NATIONKEY)
            tpch:nation_of tpch:customer (customers.C_NAME, customers.C_CUSTKEY)
            as virtrdf:customer-nation_of .

        tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER)
            a tpch:lineitem
                as virtrdf:lineitem-lineitems ;
            tpch:has_order tpch:order (lineitems.L_ORDERKEY)
                as virtrdf:lineitem-l_orderkey ;
            tpch:has_part tpch:part (parts.P_NAME, lineitems.L_PARTKEY)
                where (^{parts.}^.P_PARTKEY = ^{lineitems.}^.L_PARTKEY)
                as virtrdf:lineitem-l_partkey ;
            tpch:has_supplier tpch:supplier (suppliers.S_NAME, lineitems.L_SUPPKEY)
                where (^{suppliers.}^.S_SUPPKEY = ^{lineitems.}^.L_SUPPKEY)
                as virtrdf:lineitem-l_suppkey ;
            tpch:linenumber lineitems.L_LINENUMBER
                as virtrdf:lineitem-l_linenumber ;
            tpch:linequantity lineitems.L_QUANTITY
                as virtrdf:lineitem-l_linequantity ;
            tpch:lineextendedprice lineitems.L_EXTENDEDPRICE
                as virtrdf:lineitem-l_lineextendedprice ;
            tpch:linediscount lineitems.L_DISCOUNT
                as virtrdf:lineitem-l_linediscount ;
            tpch:linetax lineitems.L_TAX
                as virtrdf:lineitem-l_linetax ;
            tpch:returnflag lineitems.L_RETURNFLAG
                as virtrdf:lineitem-l_returnflag ;
            tpch:linestatus lineitems.L_LINESTATUS
                as virtrdf:lineitem-l_linestatus ;
            tpch:shipdate lineitems.L_SHIPDATE
                as virtrdf:lineitem-l_shipdate ;
            tpch:commitdate lineitems.L_COMMITDATE
                as virtrdf:lineitem-l_commitdate ;
            tpch:receiptdate lineitems.L_RECEIPTDATE
                as virtrdf:lineitem-l_receiptdate ;
            tpch:shipinstruct lineitems.L_SHIPINSTRUCT
                as virtrdf:lineitem-l_shipinstruct ;
            tpch:shipmode lineitems.L_SHIPMODE
                as virtrdf:lineitem-l_shipmode ;
            tpch:comment lineitems.L_COMMENT
                as virtrdf:lineitem-l_comment .

        tpch:part (parts.P_NAME, lineitems.L_PARTKEY)
            tpch:part_of tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER)
            where (^{parts.}^.P_PARTKEY = ^{lineitems.}^.L_PARTKEY)
            as virtrdf:lineitem-part_of .

        tpch:order (lineitems.L_ORDERKEY)
            tpch:order_of tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-order_of .

        tpch:supplier (suppliers.S_NAME, lineitems.L_SUPPKEY)
            tpch:supplier_of tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) 
            where (^{suppliers.}^.S_SUPPKEY = ^{lineitems.}^.L_SUPPKEY)
            as virtrdf:lineitem-supplier_of .

# Nation
        tpch:nation (nations.N_NAME, nations.N_NATIONKEY)
            a tpch:nation
                as virtrdf:nation-nations ;
            tpch:name nations.N_NAME
                as virtrdf:nation-n_name ;
            tpch:has_region tpch:region (regions.R_NAME, nations.N_REGIONKEY)
                where (^{regions.}^.R_REGIONKEY = ^{nations.}^.N_REGIONKEY)
                as virtrdf:nation-n_regionkey ;
            tpch:comment nations.N_COMMENT
                as virtrdf:nation-n_comment .

        tpch:region (regions.R_NAME, nations.N_REGIONKEY)
            tpch:region_of tpch:nation (nations.N_NAME, nations.N_NATIONKEY)
            where (^{regions.}^.R_REGIONKEY = ^{nations.}^.N_REGIONKEY)
            as virtrdf:nation-region_of .

# Order
        tpch:order (orders.O_ORDERKEY)
            a tpch:order
                as virtrdf:order-orders ;
            tpch:orderkey orders.O_ORDERKEY
                as virtrdf:order-o_orderkey ;
            tpch:has_customer tpch:customer (customers.C_NAME, orders.O_CUSTKEY)
                where (^{orders.}^.O_CUSTKEY = ^{customers.}^.C_CUSTKEY)
                as virtrdf:order-o_custkey ;
            tpch:orderstatus orders.O_ORDERSTATUS
                as virtrdf:order-o_orderstatus ;
            tpch:ordertotalprice orders.O_TOTALPRICE
                as virtrdf:order-o_totalprice ;
            tpch:orderdate orders.O_ORDERDATE
                as virtrdf:order-o_orderdate ;
            tpch:orderpriority orders.O_ORDERPRIORITY
                as virtrdf:order-o_orderpriority ;
            tpch:clerk orders.O_CLERK
                as virtrdf:order-o_clerk ;
            tpch:shippriority orders.O_SHIPPRIORITY
                as virtrdf:order-o_shippriority ;
            tpch:comment orders.O_COMMENT
                as virtrdf:order-o_comment .

        tpch:customer (customers.C_CUSTKEY, orders.O_CUSTKEY)
            tpch:customer_of tpch:order (orders.O_ORDERKEY) 
            where (^{orders.}^.O_CUSTKEY = ^{customers.}^.C_CUSTKEY)
            as virtrdf:order-customer_of .

# Part
        tpch:part (parts.P_NAME, parts.P_PARTKEY)
            a tpch:part
                as virtrdf:part-parts ;
            tpch:partkey parts.P_PARTKEY
                as virtrdf:part-p_partkey ;
            tpch:name parts.P_NAME
                as virtrdf:part-p_name ;
            tpch:mfgr parts.P_MFGR
                as virtrdf:part-p_mfgr ;
            tpch:brand parts.P_BRAND
                as virtrdf:part-p_brand ;
            tpch:type parts.P_TYPE
                as virtrdf:part-p_type ;
            tpch:size parts.P_SIZE
                as virtrdf:part-p_size ;
            tpch:container parts.P_CONTAINER
                as virtrdf:part-p_container ;
            tpch:comment parts.P_COMMENT
                as virtrdf:part-p_comment .

# Partsupp
        tpch:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            a tpch:partsupp
                as virtrdf:partsupp-partsupps ;
            tpch:has_part tpch:part (parts.P_NAME, partsupps.PS_PARTKEY)
                where (^{parts.}^.P_PARTKEY = ^{partsupps.}^.PS_PARTKEY)
                as virtrdf:partsupp-ps_partkey ;
            tpch:has_supplier tpch:supplier (suppliers.S_NAME, partsupps.PS_SUPPKEY)
                where (^{suppliers.}^.S_SUPPKEY = ^{partsupps.}^.PS_SUPPKEY)
                as virtrdf:partsupp-ps_suppkey ;
            tpch:availqty partsupps.PS_AVAILQTY
                as virtrdf:partsupp-ps_availqty ;
            tpch:supplycost partsupps.PS_SUPPLYCOST
                as virtrdf:partsupp-ps_supplycost ;
            tpch:comment partsupps.PS_COMMENT
                as virtrdf:partsupp-ps_comment .

        tpch:part (parts.P_NAME, partsupps.PS_PARTKEY)
            tpch:part_of tpch:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            where (^{parts.}^.P_PARTKEY = ^{partsupps.}^.PS_PARTKEY)
            as virtrdf:partsupp-part_of .

        tpch:supplier (suppliers.S_NAME, partsupps.PS_SUPPKEY)
            tpch:supplier_of tpch:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            where (^{suppliers.}^.S_SUPPKEY = ^{partsupps.}^.PS_SUPPKEY)
            as virtrdf:partsupp-supplier_of .

# Region
        tpch:region (regions.R_NAME, regions.R_REGIONKEY)
            a tpch:region
                as virtrdf:region-regions ;
            tpch:name regions.R_NAME
                as virtrdf:region-r_name ;
            tpch:comment regions.R_COMMENT
                as virtrdf:region-r_comment .

# Supplier
        tpch:supplier (suppliers.S_NAME, suppliers.S_SUPPKEY)
            a tpch:supplier
                as virtrdf:supplier-suppliers ;
            tpch:name suppliers.S_NAME
                as virtrdf:supplier-s_name ;
            tpch:address suppliers.S_ADDRESS
                as virtrdf:supplier-s_address ;
            tpch:has_nation tpch:nation (nations.N_NAME, suppliers.S_NATIONKEY)
                where (^{nations.}^.N_NATIONKEY = ^{suppliers.}^.S_NATIONKEY)
                as virtrdf:supplier-s_nationkey ;
            foaf:phone suppliers.S_PHONE
                as virtrdf:supplier-foaf_phone ;
            tpch:phone suppliers.S_PHONE
                as virtrdf:supplier-s_phone ;
            tpch:acctbal suppliers.S_ACCTBAL
                as virtrdf:supplier-s_acctbal ;
            tpch:comment suppliers.S_COMMENT
                as virtrdf:supplier-s_comment .

        tpch:nation (nations.N_NAME, suppliers.S_NATIONKEY)
            tpch:nation_of tpch:supplier (suppliers.S_NAME, suppliers.S_SUPPKEY)
            where (^{nations.}^.N_NATIONKEY = ^{suppliers.}^.S_NATIONKEY)
            as virtrdf:supplier-nation_of .
    } .
} .
;

delete from db.dba.url_rewrite_rule_list where urrl_list like 'tpch_rule%';
delete from db.dba.url_rewrite_rule where urr_rule like 'tpch_rule%';

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule2',
    1,
    '([^#]*)',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/tpch%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );


DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule1',
    1,
    '([^#]*)',
    vector('path'),
    1,
    '/rdfbrowser/index.html?uri=http%%3A//^{URIQADefaultHost}^%U%%23this',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule3',
    1,
    '(/[^#]*)/\x24',
    vector('path'),
    1,
    '%s',
    vector('path'),
    null,
    null,
    0,
    null
    );

create procedure DB.DBA.REMOVE_TPCH_RDF_DET()
{
  declare colid int;
  colid := DAV_SEARCH_ID('/DAV/home/demo/tpch', 'C');
  if (colid < 0)
    return;
  update WS.WS.SYS_DAV_COL set COL_DET=null where COL_ID = colid;
}
;

DB.DBA.REMOVE_TPCH_RDF_DET();

drop procedure DB.DBA.REMOVE_TPCH_RDF_DET;

create procedure DB.DBA.TPCH_MAKE_RDF_DET()
{
    declare uriqa_str varchar;
    uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    uriqa_str := 'http://' || uriqa_str || '/tpch';
    DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/home/demo/tpch/RDFData/', uriqa_str, NULL);
    VHOST_REMOVE (lpath=>'/tpch/data/rdf');
    DB.DBA.VHOST_DEFINE (lpath=>'/tpch/data/rdf', ppath=>'/DAV/home/demo/tpch/RDFData/All/', is_dav=>1, vsp_user=>'dba');
}
;

DB.DBA.TPCH_MAKE_RDF_DET();

drop procedure DB.DBA.TPCH_MAKE_RDF_DET;

create procedure DB.DBA.TPCH_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  uriqa_str := 'http://' || uriqa_str || '/tpch';
  iri := uriqa_str || val;
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('tpch_rdf', 1,
    '/tpch/(.*)', vector('path'), 1, 
    '/tpch/data/rdf/%U', vector('path'),
    'DB.DBA.TPCH_DET_REF',
    'application/rdf.xml',
    2,  
    303);

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tpch_rule_list1',
    1,
    vector (
                'tpch_rule1',
                'tpch_rule2',
                'tpch_rule3',
                'tpch_rdf'
          ));

DB.DBA.VHOST_REMOVE (lpath=>'/tpch');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch', ppath=>'/DAV/home/demo/tpch/', vsp_user=>'dba', is_dav=>1,
          is_brws=>0, opts=>vector ('url_rewrite', 'tpch_rule_list1'));


DB.DBA.VHOST_REMOVE (lpath=>'/tpch/linkeddata');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch/linkeddata', ppath=>'/DAV/home/demo/tpch/', vsp_user=>'dba', is_dav=>1,
          is_brws=>1);
