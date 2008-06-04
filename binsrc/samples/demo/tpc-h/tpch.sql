
use TPCH;

create procedure tpch_create_table ()
{

    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.CUSTOMER', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.HISTORY', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.LINEITEM', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.NATION', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.ORDERS', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.PART', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.PARTSUPP', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.REGION', 0);
    DB.DBA.EXEC_STMT ('drop table TPCH.DBA.SUPPLIER', 0);
    DB.DBA.EXEC_STMT ('sparql drop quad map virtrdf:TPCH', 0);

    DB.DBA.EXEC_STMT ('create table CUSTOMER (
	    C_CUSTKEY	integer,
	    C_NAME		varchar(25),
	    C_ADDRESS	varchar(40),
	    C_NATIONKEY	integer,
	    C_PHONE		character(15),
	    C_ACCTBAL	numeric (20,2),
	    C_MKTSEGMENT	character(10),
	    C_COMMENT	varchar(117),
	    primary key (C_CUSTKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table HISTORY (
	    H_P_KEY integer,
	    H_S_KEY integer,
	    H_O_KEY integer,
	    H_L_KEY integer,
	    H_DELTA integer,
	    H_DATE_T datetime
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table LINEITEM (
	    L_ORDERKEY	integer,
	    L_PARTKEY	integer,
	    L_SUPPKEY	integer,
	    L_LINENUMBER	integer,
	    L_QUANTITY	numeric (20,2),
	    L_EXTENDEDPRICE	numeric (20,2),
	    L_DISCOUNT	numeric (3,2),
	    L_TAX		numeric (3,2),
	    L_RETURNFLAG	character(1),
	    L_LINESTATUS	character(1),
	    L_SHIPDATE	date,
	    L_COMMITDATE	date,
	    L_RECEIPTDATE	date,
	    L_SHIPINSTRUCT	character(25),
	    L_SHIPMODE	character(10),
	    L_COMMENT	varchar(44),
	    primary key (L_ORDERKEY, L_LINENUMBER)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table NATION (
	    N_NATIONKEY	integer,
	    N_NAME	character(225),
	    N_REGIONKEY	integer,
	    N_COMMENT	varchar(152),
	    primary key (N_NATIONKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table ORDERS (
	    O_ORDERKEY	integer,
	    O_CUSTKEY	integer,
	    O_ORDERSTATUS	character(1),
	    O_TOTALPRICE	numeric (20,2),
	    O_ORDERDATE	date,
	    O_ORDERPRIORITY	character(15),
	    O_CLERK		character(15),
	    O_SHIPPRIORITY	integer,
	    O_COMMENT	varchar(79),
	    primary key(O_ORDERKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table PART (
	    P_PARTKEY	integer,
	    P_NAME		varchar(55),
	    P_MFGR		character(25),
	    P_BRAND		character(10),
	    P_TYPE		varchar(25),
	    P_SIZE		integer,
	    P_CONTAINER	character(10),
	    P_RETAILPRICE	numeric (20,2),
	    P_COMMENT	varchar(23),
	    primary key (P_PARTKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table PARTSUPP (
	    PS_PARTKEY	integer,
	    PS_SUPPKEY	integer,
	    PS_AVAILQTY	integer,
	    PS_SUPPLYCOST	numeric (20,2),
	    PS_COMMENT	varchar(199),
	    primary key (PS_PARTKEY, PS_SUPPKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table REGION (
	    R_REGIONKEY	integer,
	    R_NAME	character(225),
	    R_COMMENT	varchar(152),
	    primary key (R_REGIONKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('create table SUPPLIER (
	    S_SUPPKEY	integer,
	    S_NAME		character(25),
	    S_ADDRESS	varchar(40),
	    S_NATIONKEY	integer,
	    S_PHONE		character(15),
	    S_ACCTBAL	numeric (20,2),
	    S_COMMENT	varchar(101),
	    primary key (S_SUPPKEY)
    )', 0)
    ;

    DB.DBA.EXEC_STMT ('CREATE INDEX N_RK ON NATION (N_REGIONKEY)', 0)
    ;

    DB.DBA.EXEC_STMT ('CREATE INDEX S_NK ON SUPPLIER (S_NATIONKEY)', 0)
    ;


    DB.DBA.EXEC_STMT ('CREATE UNIQUE INDEX PS_SKPK ON PARTSUPP (PS_SUPPKEY, PS_PARTKEY)', 0)
    ;

    --DB.DBA.EXEC_STMT ('CREATE INDEX PS_SK ON PARTSUPP (PS_SUPPKEY)', 0)

    DB.DBA.EXEC_STMT ('CREATE INDEX C_NK ON CUSTOMER (C_NATIONKEY)', 0)
    ;

    DB.DBA.EXEC_STMT ('CREATE INDEX O_CK ON ORDERS (O_CUSTKEY)', 0)
    ;

    DB.DBA.EXEC_STMT ('CREATE INDEX L_PK ON LINEITEM (L_PARTKEY)', 0)
    ;

    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.PARTSUPP  TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.SUPPLIER  TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.CUSTOMER  TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.HISTORY   TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.PART      TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.LINEITEM  TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.ORDERS    TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.NATION    TO "SPARQL"', 0);
    DB.DBA.EXEC_STMT ('GRANT SELECT ON TPCH.DBA.REGION    TO "SPARQL"', 0);

}
;

create procedure SPARQL_TPCH_RUN (in txt varchar)
{
  declare stat, msg, sqltext, metas, rowset any;

  sqltext := string_output_string (sparql_to_sql_text (txt));
  exec (sqltext, stat, msg, vector (), 1000, metas, rowset);
}
;

create procedure init_class ()
{
   SPARQL_TPCH_RUN ('
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tpch:customer "http://^{URIQADefaultHost}^/tpch/customer/%d#this" (in c_custkey integer not null) option (bijection, deref) .
create iri class tpch:lineitem "http://^{URIQADefaultHost}^/tpch/lineitem/%d/%d#this" (in l_orderkey integer not null, in l_linenumber integer not null) option (bijection, deref) .
create iri class tpch:nation "http://^{URIQADefaultHost}^/tpch/nation/%d#this" (in l_nationkey integer not null) option (bijection, deref) .
create iri class tpch:order "http://^{URIQADefaultHost}^/tpch/order/%d#this" (in o_orderkey integer not null) option (bijection, deref) .
create iri class tpch:part "http://^{URIQADefaultHost}^/tpch/part/%d#this" (in p_partkey integer not null) option (bijection, deref) .
create iri class tpch:partsupp "http://^{URIQADefaultHost}^/tpch/partsupp/%d/%d#this" (in ps_partkey integer not null, in ps_suppkey integer not null) option (bijection, deref) .
create iri class tpch:region "http://^{URIQADefaultHost}^/tpch/region/%d#this" (in r_regionkey integer not null) option (bijection, deref) .
create iri class tpch:supplier "http://^{URIQADefaultHost}^/tpch/supplier/%d#this" (in s_supplierkey integer not null) option (bijection, deref) .
'
)
;
}
;

create procedure init_view ()
{
   SPARQL_TPCH_RUN ('
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
        tpch:customer (customers.C_CUSTKEY)
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
            tpch:has_nation tpch:nation (customers.C_NATIONKEY)
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

        tpch:nation (customers.C_NATIONKEY)
            tpch:nation_of tpch:customer (customers.C_CUSTKEY) as virtrdf:customer-nation_of .

        tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER)
            a tpch:lineitem
                as virtrdf:lineitem-lineitems ;
            tpch:has_order tpch:order (lineitems.L_ORDERKEY)
                as virtrdf:lineitem-l_orderkey ;
            tpch:has_part tpch:part (lineitems.L_PARTKEY)
                as virtrdf:lineitem-l_partkey ;
            tpch:has_supplier tpch:supplier (lineitems.L_SUPPKEY)
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

        tpch:part (lineitems.L_PARTKEY)
            tpch:part_of tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-part_of .

        tpch:order (lineitems.L_ORDERKEY)
            tpch:order_of tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-order_of .

        tpch:supplier (lineitems.L_SUPPKEY)
            tpch:supplier_of tpch:lineitem (lineitems.L_ORDERKEY, lineitems.L_LINENUMBER) as virtrdf:lineitem-supplier_of .

        tpch:nation (nations.N_NATIONKEY)
            a tpch:nation
                as virtrdf:nation-nations ;
            tpch:name nations.N_NAME
                as virtrdf:nation-n_name ;
            tpch:has_region tpch:region (nations.N_REGIONKEY)
                as virtrdf:nation-n_regionkey ;
            tpch:comment nations.N_COMMENT
                as virtrdf:nation-n_comment .

        tpch:region (nations.N_REGIONKEY)
            tpch:region_of tpch:nation (nations.N_NATIONKEY) as virtrdf:nation-region_of .

        tpch:order (orders.O_ORDERKEY)
            a tpch:order
                as virtrdf:order-orders ;
            tpch:orderkey orders.O_ORDERKEY
                as virtrdf:order-o_orderkey ;
            tpch:has_customer tpch:customer (orders.O_CUSTKEY)
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

        tpch:customer (orders.O_CUSTKEY)
            tpch:customer_of tpch:order (orders.O_ORDERKEY) as virtrdf:order-customer_of .

        tpch:part (parts.P_PARTKEY)
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

        tpch:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY)
            a tpch:partsupp
                as virtrdf:partsupp-partsupps ;
            tpch:has_part tpch:part (partsupps.PS_PARTKEY)
                as virtrdf:partsupp-ps_partkey ;
            tpch:has_supplier tpch:supplier (partsupps.PS_SUPPKEY)
                as virtrdf:partsupp-ps_suppkey ;
            tpch:availqty partsupps.PS_AVAILQTY
                as virtrdf:partsupp-ps_availqty ;
            tpch:supplycost partsupps.PS_SUPPLYCOST
                as virtrdf:partsupp-ps_supplycost ;
            tpch:comment partsupps.PS_COMMENT
                as virtrdf:partsupp-ps_comment .

        tpch:part (partsupps.PS_PARTKEY)
            tpch:part_of tpch:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:partsupp-part_of .

        tpch:supplier (partsupps.PS_SUPPKEY)
            tpch:supplier_of tpch:partsupp (partsupps.PS_PARTKEY, partsupps.PS_SUPPKEY) as virtrdf:partsupp-supplier_of .

        tpch:region (regions.R_REGIONKEY)
            a tpch:region
                as virtrdf:region-regions ;
            tpch:name regions.R_NAME
                as virtrdf:region-r_name ;
            tpch:comment regions.R_COMMENT
                as virtrdf:region-r_comment .

        tpch:supplier (suppliers.S_SUPPKEY)
            a tpch:supplier
                as virtrdf:supplier-suppliers ;
            tpch:name suppliers.S_NAME
                as virtrdf:supplier-s_name ;
            tpch:address suppliers.S_ADDRESS
                as virtrdf:supplier-s_address ;
            tpch:has_nation tpch:nation (suppliers.S_NATIONKEY)
                as virtrdf:supplier-s_nationkey ;
            foaf:phone suppliers.S_PHONE
                as virtrdf:supplier-foaf_phone ;
            tpch:phone suppliers.S_PHONE
                as virtrdf:supplier-s_phone ;
            tpch:acctbal suppliers.S_ACCTBAL
                as virtrdf:supplier-s_acctbal ;
            tpch:comment suppliers.S_COMMENT
                as virtrdf:supplier-s_comment .

        tpch:nation (suppliers.S_NATIONKEY)
            tpch:nation_of tpch:supplier (suppliers.S_SUPPKEY) as virtrdf:supplier-nation_of .
    }
}
'
)
;
}
;

create procedure
tpch_check_status ()
{
    declare stmt, state, msg, res varchar;

    stmt := sprintf ('sparql select count (*) from <http://%s/tpch> where {?s ?p ?o}',
		     cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost'));

    if (exec (stmt, state, msg, vector (), 1, NULL, res) = 0)
     {
	if (res[0][0] = 1471920)
	  {
	     connection_set ('DATA', 'OK');
	     return;
	  }
     }

    tpch_create_table ();
    init_class ();
    init_view ();
}
;

tpch_check_status ()
;

create procedure randomNumber (in nmin integer, in nmax integer) {

	declare result integer;
	result := rnd(nmax - nmin + 1) + nmin;
	return result;
};

create procedure randomNumeric(in nmin numeric, in nmax numeric, in pwr numeric) {

	declare result numeric;
	return (cast (randomNumber (nmin * pwr, nmax * pwr) as numeric) / pwr);
}
;

create procedure random_aString (in _sz integer)
{
  declare _res varchar;

  _res := space (_sz);
  while (_sz > 0)
    {
      if (mod (_sz, 3) = 0)
	aset (_res, _sz - 1, ascii ('a') + randomNumber (0, 25));
      else if (mod (_sz, 3)  = 1)
	aset (_res, _sz - 1, ascii ('A') + randomNumber (0, 25));
      else
	aset (_res, _sz - 1, ascii ('1') + randomNumber (0, 9));
      _sz := _sz - 1;
    }
  return _res;
}
;

create procedure random_vString (in x integer)
{
  declare _sz integer;

  _sz := x * randomNumber (40, 160) / 100;

  return (random_aString(_sz));
}
;

create procedure randomPhone(in n integer) {

	return concat(sprintf('%d', n + 10), '-', sprintf('%d', randomNumber(100, 999)), '-', sprintf('%d', randomNumber(100, 999)), '-', sprintf('%d', randomNumber(1000, 9999)));
}
;

create procedure randomType(in n integer) {

	declare syl1, syl2, syl3 integer;

	syl1 := vector('STANDARD', 'SMALL', 'MEDIUM', 'LARGE', 'ECONOMY', 'PROMO');
	syl2 := vector('ANODIZED', 'BURNISHED', 'PLATED', 'POLISHED', 'BRUSHED');
	syl3 := vector('TIN', 'NICKEL', 'BRASS', 'STEEL', 'COPPER');

	return concat(aref(syl1, randomNumber(0, 5)), ' ', aref(syl2, randomNumber(0, 4)), ' ', aref(syl3, randomNumber(0, 4)));
}
;

create procedure randomContainer(in n integer) {

	declare syl1, syl2 integer;

	syl1 := vector('SM', 'LG', 'MED', 'JUMBO', 'WRAP');
	syl2 := vector('CASE', 'BOX', 'BAG', 'JAR', 'PKG', 'PACK', 'CAN', 'DRUM');

	return concat(aref(syl1, randomNumber(0, 4)), ' ', aref(syl2, randomNumber(0, 7)));
}
;

create procedure randomSegment(in n integer) {

	declare syl integer;

	syl := vector('AUTOMOBILE', 'BUILDING', 'FURNITURE', 'MACHINERY', 'HOUSEHOLD');

	return aref(syl, randomNumber(0, 4));
}
;

create procedure randomInstruction(in n integer) {

	declare syl integer;

	syl := vector('DELIVER IN PERSON', 'COLLECT COD', 'NONE', 'TAKE BACK RETURN');

	return aref(syl, randomNumber(0, 3));
}
;

create procedure randomMode(in n integer) {

	declare syl integer;

	syl := vector('REG AIR', 'AIR', 'RAIL', 'SHIP', 'TRUCK', 'MAIL', 'FOB');

	return aref(syl, randomNumber(0, 6));
}
;

create procedure randomPriority(in n integer) {

	declare syl integer;

	syl := vector('1-URGENT', '2-HIGH', '3-MEDIUM', '4-NOT SPECIFIED', '5-LOW');

	return aref(syl, randomNumber(0, 4));
}
;

create procedure randomText(in n integer) {

	declare nouns, verbs, ajectives, adverbs, prepositions, auxiliaries, terminators integer;

	declare _result, _temp varchar;
	declare _actual_length integer;

	nouns := vector('foxes', 'ideas', 'theodolites', 'pinto', 'beans', 'instructions', 'dependencies', 'excuses', 'platelets', 'asymptotes', 'courts', 'dolphins', 'multipliers', 'sauternes', 'warthogs', 'frets', 'dinos', 'attainments', 'somas', 'Tiresias', 'patterns', 'forges', 'braids', 'hockey', 'players', 'frays', 'warhorses', 'dugouts', 'notornis', 'epitaphs', 'pearls', 'tithes', 'waters', 'orbits', 'gifts', 'sheaves', 'depths', 'sentiments', 'decoys', 'realms', 'pains', 'grouches', 'escapades');

    verbs := vector('sleep', 'wake', 'are', 'cajole', 'haggle', 'nag', 'use', 'boost', 'affix', 'detect', 'integrate', 'maintain', 'nod', 'was', 'lose', 'sublate', 'solve', 'thrash', 'promise', 'engage', 'hinder', 'print', 'x-ray', 'breach', 'eat', 'grow', 'impress', 'mold', 'poach', 'serve', 'run', 'dazzle', 'snooze', 'doze', 'unwind', 'kindle', 'play', 'hang', 'believe', 'doubt');

	ajectives := vector('furious', 'sly', 'careful', 'blithe', 'quick', 'fluffy', 'slow', 'quiet', 'ruthless', 'thin', 'close', 'dogged', 'daring', 'brave', 'stealthy', 'permanent', 'enticing', 'idle', 'busy', 'regular', 'final', 'ironic', 'even', 'bold', 'silent');

	adverbs := vector('sometimes', 'always', 'never', 'furiously', 'slyly', 'carefully', 'blithely', 'quickly', 'fluffily', 'slowly', 'quietly', 'ruthlessly', 'thinly', 'closely', 'doggedly', 'daringly', 'bravely', 'stealthily', 'permanently', 'enticingly', 'idly', 'busily', 'regularly', 'finally', 'ironically', 'evenly', 'boldly', 'silently');

	prepositions := vector('about', 'above', 'according', 'to', 'across', 'after', 'against', 'along', 'alongside', 'of', 'among', 'around', 'at', 'atop', 'before', 'behind', 'beneath', 'beside', 'besides', 'between', 'beyond', 'by', 'despite', 'during', 'except', 'for', 'from', 'in', 'place', 'of', 'inside', 'instead', 'of', 'into', 'near', 'of', 'on', 'outside', 'over', 'past', 'since', 'through', 'throughout', 'to', 'toward', 'under', 'until', 'up', 'upon', 'without', 'with', 'within');

	auxiliaries := vector('do', 'may', 'might', 'shall', 'will', 'would', 'can', 'could', 'should', 'ought', 'to', 'must', 'will', 'have', 'to', 'shall', 'have', 'to', 'could', 'have', 'to', 'should', 'have', 'to', 'must', 'have', 'to', 'need', 'to', 'try', 'to');

	terminators := vector('.', ';', ':', '?', '!', '--');

	_result := '';

	_actual_length := n * randomNumber (40, 160) / 100;

	while (length(_result) < _actual_length) {
		_temp := sprintf('%s %s %s %s %s %s the %s %s',
					  aref(ajectives, randomNumber(0, 24)),
					  aref(nouns, randomNumber(0, 40)),
					  aref(auxiliaries, randomNumber(0, 17)),
					  aref(verbs, randomNumber(0, 39)),
					  aref(adverbs, randomNumber(0, 27)),
					  aref(prepositions, randomNumber(0, 46)),
					  aref(nouns, randomNumber(0, 40)),
					  aref(terminators, randomNumber(0, 5))
				);
		if (length (_result) + length (_temp) > _actual_length)
	          _temp := substring (_temp, 1, _actual_length - length (_result));
		_result := concat(_result, _temp);
	}

	return substring(_result, 1, _actual_length);
}
;

create procedure fill_nation(in n integer)
{
	declare _n_nationkey, _n_regionkey integer;
	declare _n_name, _n_comment varchar;

	declare namearray, regionarray integer;

	namearray := vector ('http://dbpedia.org/resource/Algeria', 'http://dbpedia.org/resource/Argentina',
			     'http://dbpedia.org/resource/Brazil', 'http://dbpedia.org/resource/Canada',
			     'http://dbpedia.org/resource/Egypt', 'http://dbpedia.org/resource/Ethiopia',
			     'http://dbpedia.org/resource/France', 'http://dbpedia.org/resource/Germany',
			     'http://dbpedia.org/resource/India', 'http://dbpedia.org/resource/Indonesia',
			     'http://dbpedia.org/resource/Iran', 'http://dbpedia.org/resource/Iraq',
			     'http://dbpedia.org/resource/Japan', 'http://dbpedia.org/resource/Jordan',
			     'http://dbpedia.org/resource/Kenya', 'http://dbpedia.org/resource/Morocco',
			     'http://dbpedia.org/resource/Mozambique', 'http://dbpedia.org/resource/Peru',
			     'http://dbpedia.org/resource/China', 'http://dbpedia.org/resource/Romania',
			     'http://dbpedia.org/resource/Saudi_Arabia', 'http://dbpedia.org/resource/Vietnam',
			     'http://dbpedia.org/resource/Russia', 'http://dbpedia.org/resource/United_Kingdom',
			     'http://dbpedia.org/resource/USA');
	regionarray := vector(0, 1, 1, 1, 4, 0, 3, 3, 2, 2, 4, 4, 2, 4, 0, 0, 0, 1, 2, 3, 4, 2, 3, 3, 1);

	_n_nationkey := 0;
	while (_n_nationkey <= 24) {

		_n_name := aref(namearray, _n_nationkey);
		_n_regionkey := aref(regionarray, _n_nationkey);
		_n_comment := randomText(95);

		insert into NATION (N_NATIONKEY, N_NAME, N_REGIONKEY, N_COMMENT) values (_n_nationkey, _n_name, _n_regionkey, _n_comment);

		_n_nationkey := _n_nationkey + 1;
	}
}
;

create procedure fill_region(in n integer) {

	declare _r_regionkey integer;
	declare _r_name, _r_comment varchar;

	declare namearray, regionarray integer;

	namearray := vector ('http://dbpedia.org/resource/Africa', 'http://dbpedia.org/resource/America',
			     'http://dbpedia.org/resource/Asia',   'http://dbpedia.org/resource/Europe',
			     'http://dbpedia.org/resource/Middle_East');

	_r_regionkey := 0;
	while (_r_regionkey <= 4) {

		_r_name := aref(namearray, _r_regionkey);
		_r_comment := randomText(95);

		insert into REGION (R_REGIONKEY, R_NAME, R_COMMENT) values (_r_regionkey, _r_name, _r_comment);

		_r_regionkey := _r_regionkey + 1;
	}
}
;

create procedure fill_customer (in nStartingRow integer, in NumRows integer) {

	declare _c_custkey, _c_nationkey integer;
	declare _c_name, _c_address, _c_phone, _c_mktsegment, _c_comment varchar;
	declare _c_acctbal numeric(20, 2);

	_c_custkey := nStartingRow;
	while (_c_custkey <= NumRows) {
		_c_name := sprintf('Customer#%d', _c_custkey);
		_c_address := random_vString(25);
		_c_nationkey := randomNumber(0, 24);
		_c_phone := randomPhone(_c_nationkey);
		_c_acctbal := randomNumeric(-999.99, 9999.99, 100);
		_c_mktsegment := randomSegment(0);
		_c_comment := randomText(73);

		insert into CUSTOMER (C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE, C_ACCTBAL, C_MKTSEGMENT, C_COMMENT) values (_c_custkey, _c_name, _c_address, _c_nationkey, _c_phone, _c_acctbal, _c_mktsegment, _c_comment);
		_c_custkey := _c_custkey + 1;
	}
}
;

create procedure fill_lineitems_for_order(in SF float, in _o_orderkey integer, in _o_orderdate date,
					  out _o_orderstatus character(1), out _o_totalprice numeric(20, 2))
{

	declare _l_orderkey, _l_partkey, _l_suppkey, _l_linenumber  integer;
	declare _l_returnflag, _l_linestatus, _l_shipinstruct, _l_shipmode,  _l_comment varchar;
	declare _l_quantity, _l_extendedprice, _l_discount, _l_tax varchar;
	declare _l_shipdate, _l_commitdate, _l_receiptdate date;

	declare numLines, suppIndex, numFs, numOs integer;
	declare _p_retailprice numeric(20, 2);
	declare currentDate date;
	declare S integer;

        S := cast (SF * 10000 as integer);

	currentDate := stringdate('1995.06.17');
	numLines := randomNumber(1, 7);
	_l_linenumber := 1;
	_o_totalprice := 0;
	suppIndex := 0;
	numFs := 0;
	numOs := 0;
	while (_l_linenumber <= numLines) {
		_l_orderkey := _o_orderkey;
		_l_partkey := randomNumber(1, cast (200000 * SF as integer));
		_l_suppkey := mod(_l_partkey + (mod(suppIndex, 4) * (S/4 + (_l_partkey - 1)/S)), S + 1);
		_l_quantity := randomNumeric(1, 50, 1);

	        _p_retailprice := (90000 + mod(_l_partkey/10, 20001) + 100 * mod(_l_partkey, 1000))/100;

		_l_extendedprice := _l_quantity * _p_retailprice;
		_l_discount := randomNumeric(0.0, 0.10, 100);
		_l_tax := randomNumeric(0.0, 0.08, 100);
		_l_shipdate := dateadd('day', randomNumber(1, 121), _o_orderdate);
		_l_commitdate := dateadd('day', randomNumber(30, 90), _o_orderdate);
		_l_receiptdate := dateadd('day', randomNumber(1, 30), _l_shipdate);
		if (datediff('day', _l_receiptdate, currentDate) > 0) {
			if (randomNumber(0, 1) > 0)
				_l_returnflag := 'R';
			else
				_l_returnflag := 'A';
		} else
			_l_returnflag := 'N';

		if (datediff('day', _l_shipdate, currentDate) > 0) {
			_l_linestatus := 'F';
			numFs := numFs + 1;
		} else {
			_l_linestatus := 'O';
			numOs := numOs + 1;
		}

		_l_shipinstruct := randomInstruction(0);
		_l_shipmode := randomMode(0);
		_l_comment := randomText(27);

		_o_totalprice := _o_totalprice + (_l_extendedprice * (1 + _l_tax) * (1 - _l_discount));
		suppIndex := suppIndex + 1;

		insert into LINEITEM (L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT) values (_l_orderkey, _l_partkey, _l_suppkey, _l_linenumber, _l_quantity, _l_extendedprice, _l_discount, _l_tax, _l_returnflag, _l_linestatus, _l_shipdate, _l_commitdate, _l_receiptdate, _l_shipinstruct, _l_shipmode, _l_comment);
		_l_linenumber := _l_linenumber + 1;
	}
	if (numOs > 0) {
	    if (numFs = 0)
			_o_orderstatus := 'O';
	    else
		    _o_orderstatus := 'P';
	} else {
		if (numFs = 0)
		    _o_orderstatus := 'P';
	    else
			_o_orderstatus := 'F';
	}
}
;

create procedure fill_orders (in SF float, in nStartingGroup integer, in NumGroups integer) {

	declare _o_orderkey, _o_custkey, _o_shippriority integer;
	declare _o_orderstatus, _o_orderpriority, _o_clerk, _o_comment varchar;
	declare _o_totalprice numeric(20, 2);
	declare _o_orderdate date;

	declare currentGroup, groupIndex, helper1 integer;
	declare startdate, enddate date;

	startdate := stringdate('1992.01.01');
	enddate := stringdate('1998.12.31');
	currentGroup := nStartingGroup;

	while (currentGroup <= NumGroups) {
		groupIndex := 0;
		while (groupIndex < 8) {
			_o_orderkey := (currentGroup - 1) * 32 + 1 + groupIndex;
			_o_custkey := randomNumber(1, cast (150000 * SF as integer));
			while (mod(_o_custkey, 3) = 0)
				_o_custkey := randomNumber(1, cast (150000 * SF as integer));
			_o_orderdate :=
					dateadd('day',
						randomNumber(0,
							datediff('day',
								startdate,
								dateadd('day', -151, enddate)
							)
						),
						startdate
					);
			_o_orderpriority := randomPriority(0);
			_o_clerk := sprintf('Clerk#%d', randomNumber(1, cast (1000 * SF as integer)));
			_o_shippriority := 0;
			_o_comment := randomText(49);

			fill_lineitems_for_order(SF, _o_orderkey, _o_orderdate, _o_orderstatus, _o_totalprice);

			insert into ORDERS (O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS, O_TOTALPRICE, O_ORDERDATE, O_ORDERPRIORITY, O_CLERK, O_SHIPPRIORITY, O_COMMENT) values (_o_orderkey, _o_custkey, _o_orderstatus, _o_totalprice, _o_orderdate, _o_orderpriority, _o_clerk, _o_shippriority, _o_comment);

			groupIndex := groupIndex + 1;
		}
		currentGroup := currentGroup + 1;
	}
}
;

create procedure fill_part (in nStartingRow integer, in NumRows integer) {

	declare _p_partkey, _p_size integer;
	declare _p_name, _p_mfgr, _p_brand, _p_type, _p_container, _p_comment varchar;
	declare _p_retailprice numeric(20, 2);

	declare words, nMfgr, nWord integer;

	words := vector('almond', 'antique', 'aquamarine', 'azure', 'beige', 'bisque', 'black', 'blanched',
			'blue', 'blush', 'brown', 'burlywood', 'burnished', 'chartreuse', 'chiffon', 'chocolate',
			'coral', 'cornflower', 'cornsilk', 'cream', 'cyan', 'dark', 'deep', 'dim', 'dodger', 'drab',
			'firebrick', 'floral', 'forest', 'frosted', 'gainsboro', 'ghost', 'goldenrod', 'green', 'grey',
			'honeydew', 'hot', 'indian', 'ivory', 'khaki', 'lace', 'lavender', 'lawn', 'lemon', 'light',
			'lime', 'linen', 'magenta', 'maroon', 'medium', 'metallic', 'midnight', 'mint', 'misty',
			'moccasin', 'navajo', 'navy', 'olive', 'orange', 'orchid', 'pale', 'papaya', 'peach', 'peru',
			'pink', 'plum', 'powder', 'puff', 'purple', 'red', 'rose', 'rosy', 'royal', 'saddle', 'salmon',
			'sandy', 'seashell', 'sienna', 'sky', 'slate', 'smoke', 'snow', 'spring', 'steel', 'tan',
			'thistle', 'tomato', 'turquoise', 'violet', 'wheat', 'white', 'yellow');

	_p_partkey := nStartingRow;
	while (_p_partkey <= NumRows) {
		nWord := 0;
		_p_name := '';
		while (nWord < 5) {
			_p_name := concat(_p_name, aref(words, randomNumber(0, length(words) - 1)), ' ');
			nWord := nWord + 1;
		}

		nMfgr := randomNumber(1, 5);
		_p_mfgr := sprintf('Manufacturer#%d', nMfgr);
		_p_brand := sprintf('Brand#%d%d', nMfgr, randomNumber(1, 5));
		_p_type := randomType(0);
		_p_size := randomNumber(1, 50);
		_p_container := randomContainer(0);
		_p_retailprice := (90000 + mod(_p_partkey/10, 20001) + 100 * mod(_p_partkey, 1000))/100;
		_p_comment := randomText(14);

		insert into PART (P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE, P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT) values (_p_partkey, _p_name, _p_mfgr, _p_brand, _p_type, _p_size, _p_container, _p_retailprice, _p_comment);
		_p_partkey := _p_partkey + 1;
	}
}
;

create procedure fill_partsupp (in SF float, in nStartingRow integer, in NumRows integer) {

	declare _ps_partkey, _ps_suppkey, _ps_availqty integer;
	declare _ps_comment varchar;
	declare _ps_supplycost numeric(20, 2);
	declare subRow integer;
	declare S integer;

        S := cast (SF * 10000 as integer);

	_ps_partkey := nStartingRow;
	while (_ps_partkey <= NumRows) {
		subRow := 0;
		while (subRow < 4) {
			_ps_suppkey := mod(_ps_partkey + ( subRow * ( S/4 + (_ps_partkey - 1)/S ) ), S + 1);
			_ps_availqty := randomNumber(1, 9999);
			_ps_supplycost := randomNumeric(1, 1000, 1);
			_ps_comment := randomText(124);

			insert into PARTSUPP (PS_PARTKEY, PS_SUPPKEY, PS_AVAILQTY, PS_SUPPLYCOST, PS_COMMENT)  values (_ps_partkey, _ps_suppkey, _ps_availqty, _ps_supplycost, _ps_comment);
			subRow := subRow + 1;
		}
		_ps_partkey := _ps_partkey + 1;
	}
}
;

create procedure fill_supplier (in initial_suppkey integer, in NumRows integer)
{

	declare _s_suppkey, _s_nationkey integer;
	declare _s_name, _s_address, _s_phone, _s_comment varchar;
	declare _s_acctbal numeric;

	_s_suppkey := initial_suppkey;

	while (_s_suppkey <= NumRows) {

		_s_name := concat('Supplier#', sprintf('%d', _s_suppkey));
		_s_address := random_vString(25);
		_s_nationkey := randomNumber(0, 24);
		_s_phone := randomPhone(_s_nationkey);
		_s_acctbal := randomNumeric(-999.99, 9999.99, 100);
		_s_comment := randomText(63);


		insert into SUPPLIER (S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY, S_PHONE, S_ACCTBAL, S_COMMENT) values (_s_suppkey, _s_name, _s_address, _s_nationkey, _s_phone, _s_acctbal, _s_comment);
		_s_suppkey := _s_suppkey + 1;
	}
}
;

create procedure supplier_add_random(in SF float, in nNumRows integer) {

	declare _strHelper varchar;
	declare _nHelper1, _nHelper2, _nHelper3 integer;

	_nHelper2 := 0;
	while (_nHelper2 < (5 * SF)) {
		_nHelper3 := randomNumber(1, nNumRows);
		declare cr1 cursor for
			select s_comment from supplier where s_suppkey = _nHelper3;

		open cr1;
		fetch cr1 into _strHelper;

		update supplier set s_comment = 'CustomerComplaints' where current of cr1;
		_nHelper2 := _nHelper2 + 1;
		close cr1;

	}

	_nHelper2 := 0;
	while (_nHelper2 < (5 * SF)) {
		_nHelper3 := randomNumber(1, nNumRows);
		declare cr2 cursor for
			select s_comment from supplier where s_suppkey = _nHelper3;

		open cr2;
		fetch cr2 into _strHelper;

		update supplier set s_comment = 'CustomerRecommends' where current of cr2;
		_nHelper2 := _nHelper2 + 1;
		close cr2;
	}
}
;

create procedure up_isparql (in q_num integer, in q_text any)
{
   declare file_name, res, uriqa_str, xml_query any;
   declare uriqa_str varchar;
   declare dav_pwd varchar;

   file_name := sprintf ('tpch/Q%02d', q_num);

   uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');

   if (uriqa_str is null)
     {
       if (server_http_port () <> '80')
	 uriqa_str := 'localhost:'||server_http_port ();
       else
         uriqa_str := 'localhost';
     }

   q_text := replace (q_text, '__URIQA__', uriqa_str);

   xml_query := sprintf ('<?xml version="1.0" encoding="UTF-8"?>\n<?xml-stylesheet type="text/xsl" href="/isparql/xslt/dynamic-page.xsl"?><iSPARQL xmlns="urn:schemas-openlink-com:isparql"><ISparqlDynamicPage><proxy>true</proxy><query><![CDATA[#service:/sparql\r\n#should-sponge:soft\r\n%s]]></query><graph>http://%s/tpch</graph></ISparqlDynamicPage><should_sponge>soft</should_sponge><service>/sparql</service></iSPARQL>',
  q_text, uriqa_str);

  dav_pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
   res := DB.DBA.DAV_RES_UPLOAD ('/DAV/home/demo/' || file_name || '.isparql', xml_query, '', '111101101R',
			  http_dav_uid(), http_dav_uid() + 1, 'dav', dav_pwd);
  if (res <= 0)
    {
      signal ('42000',DB.DBA.DAV_PERROR (res));
    }
}
;


create procedure
tpch_check_status_2 ()
{
   declare dav_pwd varchar;
    if (connection_get ('DATA') = 'OK')
      goto make_isparql;

    randomize(1);
    fill_supplier (1, 100);
    fill_part (1, 1000);
    fill_part (1001, 2000);
    fill_partsupp (1.0 / 100, 1, 1000);
    fill_partsupp (1.0 / 100, 1001, 2000);
    fill_customer (1, 1000);
    fill_customer (1001, 1500);
    fill_orders (1.0 / 100, 1, 100);
    fill_orders (1.0 / 100, 101, 200);
    fill_orders (1.0 / 100, 201, 300);
    fill_orders (1.0 / 100, 301, 400);
    fill_orders (1.0 / 100, 401, 500);
    fill_orders (1.0 / 100, 501, 600);
    fill_orders (1.0 / 100, 601, 700);
    fill_orders (1.0 / 100, 701, 800);
    fill_orders (1.0 / 100, 801, 900);
    fill_orders (1.0 / 100, 901, 1000);
    fill_orders (1.0 / 100, 1001, 1100);
    fill_orders (1.0 / 100, 1101, 1200);
    fill_orders (1.0 / 100, 1201, 1300);
    fill_orders (1.0 / 100, 1301, 1400);
    fill_orders (1.0 / 100, 1401, 1500);
    fill_orders (1.0 / 100, 1501, 1600);
    fill_orders (1.0 / 100, 1601, 1700);
    fill_orders (1.0 / 100, 1701, 1800);
    fill_orders (1.0 / 100, 1801, 1875);
    fill_nation(0);
    fill_region(0);

make_isparql:

  dav_pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
    DB.DBA.DAV_COL_CREATE ('/DAV/home/demo/tpch/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', dav_pwd);

up_isparql (1, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?l+>tpch:returnflag,
  ?l+>tpch:linestatus,
  sum(?l+>tpch:linequantity) as ?sum_qty,
  sum(?l+>tpch:lineextendedprice) as ?sum_base_price,
  sum(?l+>tpch:lineextendedprice*(1 - ?l+>tpch:linediscount)) as ?sum_disc_price,
  sum(?l+>tpch:lineextendedprice*(1 - ?l+>tpch:linediscount)*(?l+>tpch:linetax)) as ?sum_charge,
  avg(?l+>tpch:linequantity) as ?avg_qty,
  avg(?l+>tpch:lineextendedprice) as ?avg_price,
  avg(?l+>tpch:linediscount) as ?avg_disc,
  count(1) as ?count_order
from <http://__URIQA__/tpch>
where {
    ?l a tpch:lineitem .
    filter (?l+>tpch:shipdate <= bif:dateadd ("day", 90, ''1998-12-01''^^xsd:date)) }
order by ?l+>tpch:returnflag ?l+>tpch:linestatus
');

--up_isparql (2, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--select
--  ?supp+>tpch:acctbal,
--  ?supp+>tpch:name,
--  ?supp+>tpch:has_nation+>tpch:name as ?nation_name,
--  ?part+>tpch:partkey,
--  ?part+>tpch:mfgr,
--  ?supp+>tpch:address,
--  ?supp+>tpch:phone,
--  ?supp+>tpch:comment
--from <http://__URIQA__/tpch>
--where {
--  ?ps a tpch:partsupp; tpch:has_supplier ?supp; tpch:has_part ?part .
--  ?supp+>tpch:has_nation+>tpch:has_region tpch:name ''http://dbpedia.org/resource/Europe'' .
--  ?part tpch:size 15 .
--  ?ps tpch:supplycost ?minsc .
--  { select ?part min(?ps+>tpch:supplycost) as ?minsc
--    where {
--        ?ps a tpch:partsupp; tpch:has_part ?part; tpch:has_supplier ?ms .
--        ?ms+>tpch:has_nation+>tpch:has_region tpch:name ''http://dbpedia.org/resource/Europe'' .
--      } }
--    filter (?part+>tpch:type like ''%BRASS'') }
--order by
--  desc (?supp+>tpch:acctbal)
--  ?supp+>tpch:has_nation+>tpch:name
--  ?supp+>tpch:name
--  ?part+>tpch:partkey
--');

up_isparql (3, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?ord+>tpch:orderkey,
  sum(?li+>tpch:lineextendedprice*(1 - ?li+>tpch:linediscount)) as ?revenue,
  ?ord+>tpch:orderdate,
  ?ord+>tpch:shippriority
from <http://__URIQA__/tpch>
where
  {
    ?cust a tpch:customer ; tpch:mktsegment "BUILDING" ; tpch:customer_of ?ord .
    ?li tpch:has_order ?ord .
    filter ((?ord+>tpch:orderdate < "1995-03-15"^^xsd:date) &&
      (?li+>tpch:shipdate > "1995-03-15"^^xsd:date) ) }
order by
  desc (sum (?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)))
  ?ord+>tpch:orderdate
');

up_isparql (4, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (?ord+>tpch:orderpriority),
  count(1) as ?order_count
from <http://__URIQA__/tpch>
where
  { ?ord a tpch:order .
    { select ?ord count(?li) as ?cnt
      where {
          ?li tpch:has_order ?ord .
          filter ( ?li+>tpch:commitdate < ?li+>tpch:receiptdate ) } }
    filter ((?ord+>tpch:orderdate >= "1993-07-01"^^xsd:date) &&
      (?ord+>tpch:orderdate < bif:dateadd ("month", 3, "1993-07-01"^^xsd:date)) &&
      (?cnt > 0) )
  }
order by
  ?ord+>tpch:orderpriority
');

up_isparql (5, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?supp+>tpch:has_nation+>tpch:name as ?nation,
  sum(?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)) as ?revenue
from <http://__URIQA__/tpch>
where
  { ?li a tpch:lineitem ; tpch:has_order ?ord ; tpch:has_supplier ?supp .
    ?ord tpch:has_customer ?cust .
    ?supp+>tpch:has_nation+>tpch:has_region tpch:name "http://dbpedia.org/resource/Asia" .
    filter ((?cust+>tpch:has_nation = ?supp+>tpch:has_nation) &&
      (?ord+>tpch:orderdate >= "1994-01-01"^^xsd:date) &&
      (?ord+>tpch:orderdate < bif:dateadd ("year", 1,"1994-01-01" ^^xsd:date)) ) }
order by
  desc (sum(?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)))
');

up_isparql (6, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  sum(?li+>tpch:lineextendedprice * ?li+>tpch:linediscount) as ?revenue
from <http://__URIQA__/tpch>
where {
    ?li a tpch:lineitem .
    filter ( (?li+>tpch:shipdate >= "1994-01-01"^^xsd:date) &&
      (?li+>tpch:shipdate < bif:dateadd ("year", 1, "1994-01-01"^^xsd:date)) &&
      (?li+>tpch:linediscount >= 0.06 - 0.01) &&
      (?li+>tpch:linediscount <= 0.06 + 0.01) &&
      (?li+>tpch:linequantity < 24) ) }
');

up_isparql (7, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select ?supp_nation ?cust_nation ?li_year
  sum (?value) as ?revenue
from <http://__URIQA__/tpch>
where {
    {
      select
        ?suppn+>tpch:name as ?supp_nation,
        ?custn+>tpch:name as ?cust_nation,
        (bif:year (?li+>tpch:shipdate)) as ?li_year,
        (?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)) as ?value
      where {
          ?li a tpch:lineitem ; tpch:has_order ?ord ; tpch:has_supplier ?supp .
          ?ord tpch:has_customer ?cust .
          ?cust tpch:has_nation ?custn .
          ?supp tpch:has_nation ?suppn .
          filter ((
              (?custn+>tpch:name = "http://dbpedia.org/resource/France"
		  and ?suppn+>tpch:name = "http://dbpedia.org/resource/Germany") ||
              (?custn+>tpch:name = "http://dbpedia.org/resource/Germany"
		  and ?suppn+>tpch:name = "http://dbpedia.org/resource/France") ) &&
            (?li+>tpch:shipdate >= "1995-01-01"^^xsd:date) &&
            (?li+>tpch:shipdate <= "1996-12-31"^^xsd:date) ) } } }
order by
  ?supp_nation
  ?li_year
');

up_isparql (8, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?o_year,
  (?sum1 / ?sum2) as ?mkt_share
from <http://__URIQA__/tpch>
where {
    { select
        ?o_year
        sum (?volume * bif:equ (?nation, "http://dbpedia.org/resource/Brazil")) as ?sum1
        sum (?volume) as ?sum2
      where {
          { select
              (bif:year (?ord+>tpch:orderdate)) as ?o_year,
              (?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)) as ?volume,
              ?n2+>tpch:name as ?nation
            where {
                ?li a tpch:lineitem ; tpch:has_order ?ord ; tpch:has_part ?part .
                ?li+>tpch:has_supplier tpch:has_nation ?n2 .
                ?order+>tpch:has_customer+>tpch:has_nation+>tpch:has_region tpch:name "http://dbpedia.org/resource/America" .
                ?part tpch:type "ECONOMY ANODIZED STEEL" .
                filter ((?ord+>tpch:orderdate >= "1995-01-01"^^xsd:date) &&
                  (?ord+>tpch:orderdate <= "1996-12-31"^^xsd:date) ) } } } } }
order by
  ?o_year
');

up_isparql (9, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?nation,
  ?o_year,
  sum(?amount) as ?sum_profit
from <http://__URIQA__/tpch>
where {
    { select
        ?supp+>tpch:has_nation+>tpch:name as ?nation,
        (bif:year (?ord+>tpch:orderdate)) as ?o_year,
        (?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount) - ?ps+>tpch:supplycost * ?li+>tpch:linequantity) as ?amount
      where {
          ?li a tpch:lineitem ; tpch:has_order ?ord ; tpch:has_supplier ?supp ; tpch:has_part ?part .
          ?ps a tpch:partsupp ; tpch:has_part ?part ; tpch:has_supplier ?supp .
          filter (?part+>tpch:name like "%green%") } } }
order by
  ?nation
  desc (?o_year)
');

--up_isparql (10, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
--prefix sioc: <http://rdfs.org/sioc/ns#>
--prefix foaf: <http://xmlns.com/foaf/0.1/>
--select
--  ?cust+>tpch:custkey,
--  ?cust+>tpch:companyName,
--  (sum(?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount))) as ?revenue,
--  ?cust+>tpch:acctbal,
--  ?cust+>tpch:has_nation+>tpch:name as ?nation,
--  ?cust+>tpch:address,
--  ?cust+>tpch:phone,
--  ?cust+>tpch:comment
--from <http://__URIQA__/tpch>
--where
--  {
--    ?li tpch:returnflag "R" ; tpch:has_order ?ord .
--    ?ord tpch:has_customer ?cust .
--    filter ((?ord+>tpch:orderdate >= "1993-10-01"^^xsd:date) &&
--      (?ord+>tpch:orderdate < bif:dateadd ("month", 3, "1993-10-01"^^xsd:date)) ) }
--order by
--  desc (sum(?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)))
--');

--up_isparql (11, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
--prefix sioc: <http://rdfs.org/sioc/ns#>
--prefix foaf: <http://xmlns.com/foaf/0.1/>
--select
--  ?bigps+>tpch:has_part,
--  ?bigpsvalue
--from <http://__URIQA__/tpch>
--where {
--      { select
--          (sum(?thr_ps+>tpch:supplycost * ?thr_ps+>tpch:availqty) * 0.0001) as ?threshold
--        where
--          {
--            ?thr_tps a tpch:partsupp .
--            ?thr_ps+>tpch:has_supplier+>tpch:has_nation tpch:name "http://dbpedia.org/resource/Germany" .
--          }
--      }
--      { select
--          ?bigps+>tpch:has_part as ?bpart,
--          sum(?bigps+>tpch:supplycost * ?bigps+>tpch:availqty) as ?bigpsvalue
--        where
--          {
--            ?bigps a tpch:partsupp .
--            ?bigps+>tpch:has_supplier+>tpch:has_nation tpch:name "http://dbpedia.org/resource/Germany" .
--          }
--      }
--    filter (?bigpsvalue > ?threshold)
--  }
--order by
--  desc (?bigpsvalue)
--');

up_isparql (12, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?li+>tpch:shipmode,
  sum (
    bif:__or (
      bif:equ (?ord+>tpch:orderpriority, "1-URGENT"),
      bif:equ (?ord+>tpch:orderpriority, "2-HIGH") ) ) as ?high_line_count,
  sum (1 -
    bif:__or (
      bif:equ (?ord+>tpch:orderpriority, "1-URGENT"),
      bif:equ (?ord+>tpch:orderpriority, "2-HIGH") ) ) as ?low_line_count
from <http://__URIQA__/tpch>
where
  { ?li tpch:has_order ?ord .
    filter (?li+>tpch:shipmode in ("MAIL", "SHIP") &&
      (?li+>tpch:commitdate < ?li+>tpch:receiptdate) &&
      (?li+>tpch:shipdate < ?li+>tpch:commitdate) &&
      (?li+>tpch:receiptdate >= "1994-01-01"^^xsd:date) &&
      (?li+>tpch:receiptdate < bif:dateadd ("year", 1, "1994-01-01"^^xsd:date)) )
  }
order by
  ?li+>tpch:shipmode
');

up_isparql (13, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  ?c_count,
  count(1) as ?custdist
from <http://__URIQA__/tpch>
where {
    { select
        ?cust+>tpch:custkey,
        count (?ord) as ?c_count
      where
        {
          ?cust a tpch:customer .
          optional { ?cust tpch:customer_of ?ord
              filter (!(?ord+>tpch:comment like "%special%requests%")) }
        }
    }
  }
order by
  desc (count(1))
  desc (?c_count)
');

up_isparql (14, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (100 * sum (
      bif:equ(bif:LEFT(?part+>tpch:type, 5), "PROMO") *
      ?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount) ) /
    sum (?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount)) ) as ?promo_revenue
from <http://__URIQA__/tpch>
where
  {
    ?li a tpch:lineitem ; tpch:has_part ?part .
    filter ((?li+>tpch:shipdate >= "1995-09-01"^^xsd:date) &&
      (?li+>tpch:shipdate < bif:dateadd("month", 1, "1995-09-01"^^xsd:date)) )
  }
');

--up_isparql (15, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
--prefix sioc: <http://rdfs.org/sioc/ns#>
--prefix foaf: <http://xmlns.com/foaf/0.1/>
--select
--  ?supplier ?supplier+>tpch:name ?supplier+>tpch:address ?supplier+>tpch:phone ?total_revenue
--from <http://__URIQA__/tpch>
--where
--  {
--    ?supplier a tpch:supplier .
--      {
--        select
--          ?supplier
--          (sum(?l_extendedprice * (1 - ?l_discount))) as ?total_revenue
--        where
--          {
--            [ a tpch:lineitem ; tpch:shipdate ?l_shipdate ;
--              tpch:lineextendedprice ?l_extendedprice ; tpch:linediscount ?l_discount ;
--              tpch:has_supplier ?supplier ] .
--            filter (
--                ?l_shipdate >= "1996-01-01"^^xsd:date and
--                ?l_shipdate < bif:dateadd ("month", 3, "1996-01-01"^^xsd:date) )
--          }
--      }
--      {
--        select max (?l2_total_revenue) as ?maxtotal
--        where
--          {
--              {
--                select
--                  ?supplier2
--                  (sum(?l2_extendedprice * (1 - ?l2_discount))) as ?l2_total_revenue
--                where
--                  {
--                    [ a tpch:lineitem ; tpch:shipdate ?l2_shipdate ;
--                      tpch:lineextendedprice ?l2_extendedprice ; tpch:linediscount ?l2_discount ;
--                      tpch:has_supplier ?supplier2 ] .
--                    filter (
--                        ?l2_shipdate >= "1996-01-01"^^xsd:date and
--                        ?l2_shipdate < bif:dateadd ("month", 3, "1996-01-01"^^xsd:date) )
--                  }
--              }
--          }
--      }
--    filter (?total_revenue = ?maxtotal)
--  }
--order by
--  ?supplier
--');

--up_isparql (16, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
--prefix sioc: <http://rdfs.org/sioc/ns#>
--prefix foaf: <http://xmlns.com/foaf/0.1/>
--select
--  ?part+>tpch:brand,
--  ?part+>tpch:type,
--  ?part+>tpch:size,
--  (count(distinct ?ps)) as ?supplier_cnt
--from <http://__URIQA__/tpch>
--where
--  {
--    ?ps tpch:has_part ?part .
--    optional {
--        ?ps tpch:comment ?badcomment . filter (?badcomment like "%Customer%Complaints%") }
--    filter (
--      (?part+>tpch:brand != "Brand#45") &&
--      !(?part+>tpch:type like "MEDIUM POLISHED%") &&
--      (?part+>tpch:size in (49, 14, 23, 45, 19, 3, 36, 9)) &&
--      !bound (?badcomment) )
--  }
--order by
--  desc ((count(distinct ?ps)))
--  ?part+>tpch:brand
--  ?part+>tpch:type
--  ?part+>tpch:size
--');

up_isparql (17, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (sum(?li+>tpch:lineextendedprice) / 7.0) as ?avg_yearly
from <http://__URIQA__/tpch>
where
  {
    ?li a tpch:lineitem ; tpch:has_part ?part .
    ?part tpch:container "MED BOX" ; tpch:brand "Brand#23" .
    { select ?part, (0.2 * avg(?li2+>tpch:linequantity)) as ?threshold
      where { ?li2  a tpch:lineitem ; tpch:has_part ?part } }
    filter (?li+>tpch:linequantity < ?threshold) }
');

up_isparql (18, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select ?cust+>foaf:name ?cust ?ord ?ord+>tpch:orderdate ?ord+>tpch:ordertotalprice sum(?li+>tpch:linequantity)
from <http://__URIQA__/tpch>
where
  {
    ?cust a tpch:customer ; foaf:name ?c_name .
    ?ord a tpch:order ; tpch:has_customer ?cust .
    ?li a tpch:lineitem ; tpch:has_order ?ord .
      {
        select ?sum_order sum (?li2+>tpch:linequantity) as ?sum_q
        where
          {
            ?li2 a tpch:lineitem ; tpch:has_order ?sum_order .
          }
      } .
    filter (?sum_order = ?ord and ?sum_q > 250)
  }
order by desc (?ord+>tpch:ordertotalprice) ?ord+>tpch:orderdate
');

up_isparql (19, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (sum(?li+>tpch:lineextendedprice * (1 - ?li+>tpch:linediscount))) as ?revenue
from <http://__URIQA__/tpch>
where
  {
    ?li a tpch:lineitem ; tpch:has_part ?part ; tpch:shipinstruct "DELIVER IN PERSON" .
    filter (?li+>tpch:shipmode in ("AIR", "AIR REG") &&
      ( ( (?part+>tpch:brand = "Brand#12") &&
          (?part+>tpch:container in ("SM CASE", "SM BOX", "SM PACK", "SM PKG")) &&
          (?li+>tpch:linequantity >= 1) && (?li+>tpch:linequantity <= 1 + 10) &&
          (?part+>tpch:size >= 1) && (?part+>tpch:size <= 5) ) ||
        ( (?part+>tpch:brand = "Brand#23") &&
          (?part+>tpch:container in ("MED BAG", "MED BOX", "MED PKG", "MED PACK")) &&
          (?li+>tpch:linequantity >= 10) && (?li+>tpch:linequantity <= 10 + 10) &&
          (?part+>tpch:size >= 1) && (?part+>tpch:size <= 10) ) ||
        ( (?part+>tpch:brand = "Brand#34") &&
          (?part+>tpch:container in ("LG CASE", "LG BOX", "LG PACK", "LG PKG")) &&
          (?li+>tpch:linequantity >= 20) && (?li+>tpch:linequantity <= 20 + 10) &&
          (?part+>tpch:size >= 1) && (?part+>tpch:size <= 15) ) ) )
  }
');

--up_isparql (20, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
--prefix sioc: <http://rdfs.org/sioc/ns#>
--prefix foaf: <http://xmlns.com/foaf/0.1/>
--select
--  ?supp+>tpch:name,
--  ?supp+>tpch:address
--from <http://__URIQA__/tpch>
--where
--  {
--      {
--        select
--          ?supp, count (?big_ps) as ?big_ps_cnt
--        where
--          {
--            ?big_ps a tpch:partsupp ; tpch:has_supplier ?supp .
--            ?supp+>tpch:has_nation tpch:name "http://dbpedia.org/resource/Canada" .
--              { select ?forest_part
--                where { ?forest_part a tpch:part .
--                    filter ( ?forest_part+>tpch:name like "forest%" ) }
--              }
--              { select
--                   ?big_ps, (0.5 * sum(?li+>tpch:linequantity)) as ?qty_threshold
--                  where
--                    {
--                      ?li a tpch:lineitem ; tpch:has_part ?big_ps+>tpch:has_part ; tpch:has_supplier ?bigps+>tpch:has_supplier .
--                      filter ((?li+>tpch:shipdate >= "1994-01-01"^^xsd:date) &&
--                        (?li+>tpch:shipdate < bif:dateadd ("year", 1, "1994-01-01"^^xsd:date)) ) }
--              }
--            filter (?big_ps+>tpch:availqty > ?qty_threshold)
--          }
--       }
--  }
--order by
--  ?supp+>tpch:name
--');

--up_isparql (21, '
--define sql:signal-void-variables 1
--prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
--prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
--prefix sioc: <http://rdfs.org/sioc/ns#>
--prefix foaf: <http://xmlns.com/foaf/0.1/>
--select
--    ?supp+>tpch:name,
--    (count(1)) as ?numwait
--from <http://__URIQA__/tpch>
--where
--  {
--      { select ?l1 ?ord ?supp (count(1)) as ?l2_cnt
--        where {
--            ?supp a tpch:supplier .
--            ?supp+>tpch:has_nation tpch:name "http://dbpedia.org/resource/Saudi_Arabia" .
--            ?l1 a tpch:lineitem ; tpch:has_supplier ?supp ; tpch:has_order ?ord .
--            ?ord tpch:orderstatus "F" .
--            ?l2 a tpch:lineitem ; tpch:has_supplier ?supp2 ; tpch:has_order ?ord .
--            optional {
--                  { select ?l1 (count (1)) as ?l3_cnt
--                    where {
--                        ?l1 a tpch:lineitem ; tpch:has_supplier ?supp ; tpch:has_order ?ord .
--                        ?l3 a tpch:lineitem ; tpch:has_supplier ?supp3 ; tpch:has_order ?ord .
--                        filter ((?l3+>tpch:receiptdate > ?l3+>tpch:commitdate) && (?supp3 != ?supp)) } } }
--            filter ((?l1+>tpch:receiptdate > ?l1+>tpch:commitdate) && (?supp2 != ?supp) && !bound (?l3_cnt))
--          }
--      }
--  }
--order by
--    desc (count(1))
--    ?supp+>tpch:name
--');

up_isparql (22, '
define sql:signal-void-variables 1
prefix tpch: <http://www.openlinksw.com/schemas/tpch#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
select
  (bif:LEFT (?cust+>tpch:phone, 2)) as ?cntrycode,
  (count (1)) as ?numcust,
  sum (?cust+>tpch:acctbal) as ?totacctbal
from <http://__URIQA__/tpch>
where {
      { select
          (avg (?cust2+>tpch:acctbal)) as ?acctbal_threshold
        where
          {
            ?cust2 a tpch:customer .
            filter ((?cust2+>tpch:acctbal > 0.00) &&
              bif:LEFT (?cust2+>tpch:phone, 2) in ("13", "35", "31", "23", "29", "30", "17", "18") )
          }
      }
    ?cust a tpch:customer .
    optional { select ?cust (count(?ord)) as ?ord_cnt
      where { ?cust a tpch:customer ; tpch:customer_of ?ord } }
    filter ((?cust+>tpch:acctbal > ?acctbal_threshold) &&
      bif:LEFT (?cust+>tpch:phone, 2) in ("13", "35", "31", "23", "29", "30", "17", "18") &&
      !bound (?ord_cnt) )
  }
order by
  (bif:LEFT (?cust+>tpch:phone, 2))
');

}
;

tpch_check_status_2 ()
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule1',
    1,
    '([^#]*)',
    vector('path'),
    1,
    '/rdfbrowser/index.html?uri=http%%3A//^{URIQADefaultHost}^%U%%23this',
    vector('path'),
    null,
    null,
    2,
    303
    );



DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule2', 1,
    '([^#]*)', vector('path'), 1,
    '/sparql?query=describe%%20%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E%%20from%%20%%3Chttp%%3A//^{URIQADefaultHost}^/tpch%%3E&format=%U',
    vector('path', '*accept*'),
    null,
    '(application/rdf.xml)|(text/rdf.n3)',
    2,
    303);

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tpch_rule_list1',
    1,
    vector (
                'tpch_rule1',
                'tpch_rule2'
          ));

DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/home/demo/tpch/rdf/',
	'http://' || cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost') || '/tpch', NULL);

DB.DBA.VHOST_REMOVE (lpath=>'/tpch/data/rdf');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch/data/rdf', ppath=>'/DAV/home/demo/tpch/rdf/All/', is_dav=>1, vsp_user=>'dba');

create procedure DB.DBA.TPCH_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  iri := 'http://' || uriqa_str || val || '#this';
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/tpch');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch', ppath=>'/DAV/home/demo/tpch/', vsp_user=>'dba', is_dav=>1,
          is_brws=>0, opts=>vector ('url_rewrite', 'tpch_rule_list1'));


DB.DBA.VHOST_REMOVE (lpath=>'/tpch/linkeddata');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch/linkeddata', ppath=>'/DAV/home/demo/tpch/', vsp_user=>'dba', is_dav=>1,
          is_brws=>1);

DB.DBA.VHOST_REMOVE (lpath=>'/tpc-h');
DB.DBA.VHOST_DEFINE (lpath=>'/tpc-h', ppath=>'/DAV/home/demo/tpch/', vsp_user=>'dba', is_dav=>1, is_brws=>1);

