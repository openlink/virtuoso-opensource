use DB;

DB.DBA.exec_no_error('UPDATE WS.WS.SYS_DAV_RES set RES_TYPE=\'image/jpeg\' where RES_FULL_PATH like \'/DAV/VAD/demo/sql/CAT%\'')
;

DB.DBA.exec_no_error('UPDATE WS.WS.SYS_DAV_RES set RES_TYPE=\'image/jpeg\' where RES_FULL_PATH like \'/DAV/VAD/demo/sql/EMP%\'')
;

--GRANT SPARQL_UPDATE TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Products" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Suppliers" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Shippers" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Categories" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Customers" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Employees" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Orders" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Order_Details" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Countries" TO "SPARQL";
GRANT SELECT ON "Demo"."demo"."Provinces" TO "SPARQL";

create function DB.DBA.NORTHWIND_ID_TO_IRI(in _prefix varchar,in _id varchar)
{
  declare iri, uriqa_host any;
  uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  iri := 'http://' || uriqa_host || '/Northwind/' || _prefix || '/' || _id || '#this';
  return sprintf ('http://%s/DAV/home/demo/RDFData/All/iid%%20(%d).rdf', uriqa_host, iri_id_num (iri_to_id (iri)));
}
;

create function DB.DBA.NORTHWIND_IRI_TO_ID(in _iri varchar)
{
    declare parts any;
    parts := sprintf_inverse (_iri, 'http://%s/DAV/home/demo/RDFData/All/iid (%d).rdf', 1 );
    if (parts is not null)
    {
        declare uriqa_host, iri any;
        uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
        if (parts[0] = uriqa_host)
        {
            iri := id_to_iri(iri_id_from_num(parts[1]));
            parts := sprintf_inverse (iri, 'http://%s/Northwind/%s/%s#this', 1 );
            if (parts[0] = uriqa_host)
            {
                return parts[2];
            }
        }
    }
    return NULL;
}
;

create function DB.DBA.CATEGORY_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Category', cast(_id as varchar));
}
;

create function DB.DBA.CATEGORY_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.CATEGORYDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CategoryDoc', cast(_id as varchar));
}
;

create function DB.DBA.CATEGORYDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.SHIPPER_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Shipper', cast(_id as varchar));
}
;

create function DB.DBA.SHIPPER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.SHIPPERDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('ShipperDoc', cast(_id as varchar));
}
;

create function DB.DBA.SHIPPERDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.SUPPLIER_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Supplier', cast(_id as varchar));
}
;

create function DB.DBA.SUPPLIER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.SUPPLIERDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('SupplierDoc', cast(_id as varchar));
}
;

create function DB.DBA.SUPPLIERDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.PRODUCT_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Product', cast(_id as varchar));
}
;

create function DB.DBA.PRODUCT_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.PRODUCTDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('ProductDoc', cast(_id as varchar));
}
;

create function DB.DBA.PRODUCTDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.CUSTOMER_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Customer', _id);
}
;

create function DB.DBA.CUSTOMER_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.CUSTOMERDOC_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CustomerDoc', _id);
}
;

create function DB.DBA.CUSTOMERDOC_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.EMPLOYEE_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Employee', cast(_id as varchar));
}
;

create function DB.DBA.EMPLOYEE_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.EMPLOYEEDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('EmployeeDoc', cast(_id as varchar));
}
;

create function DB.DBA.EMPLOYEEDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.ORDER_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Order', cast(_id as varchar));
}
;

create function DB.DBA.ORDER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.ORDERDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('OrderDoc', cast(_id as varchar));
}
;

create function DB.DBA.ORDERDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.CUSTOMERCONTACT_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CustomerContact', cast(_id as varchar));
}
;

create function DB.DBA.CUSTOMERCONTACT_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.CUSTOMERCONTACTDOC_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CustomerContactDoc', cast(_id as varchar));
}
;

create function DB.DBA.CUSTOMERCONTACTDOC_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.ORDERLINE_IRI (in _id1 integer, in _id2 integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('OrderLine', sprintf('%d/%d', _id1, _id2));
}
;

create function DB.DBA.ORDERLINE_IRI_INV_1 (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.ORDERLINE_IRI_INV_2 (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.ORDERLINEDOC_IRI (in _id1 integer, in _id2 integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('OrderLineDoc', sprintf('%d/%d', _id1, _id2));
}
;

create function DB.DBA.ORDERLINEDOC_IRI_INV_1 (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.ORDERLINEDOC_IRI_INV_2 (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};


create function DB.DBA.PROVINCE_IRI (in _id1 varchar, in _id2 varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Province', sprintf('%s/%s', _id1, _id2));
}
;

create function DB.DBA.PROVINCE_IRI_INV_1 (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.PROVINCE_IRI_INV_2 (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.PROVINCEDOC_IRI (in _id1 varchar, in _id2 varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('ProvinceDoc', sprintf('%s/%s', _id1, _id2));
}
;

create function DB.DBA.PROVINCEDOC_IRI_INV_1 (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.PROVINCEDOC_IRI_INV_2 (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.COUNTRY_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Country', _id);
}
;

create function DB.DBA.COUNTRY_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.COUNTRYDOC_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CountryDoc', _id);
}
;

create function DB.DBA.COUNTRYDOC_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.FLAG_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Flag', _id);
}
;

create function DB.DBA.FLAG_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.FLAGDOC_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('FlagDoc', _id);
}
;

create function DB.DBA.FLAGDOC_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.EMPLOYEEPHOTO_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('EmployeePhoto', cast(_id as varchar));
}
;

create function DB.DBA.EMPLOYEEPHOTO_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.CATEGORYPHOTO_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CategoryPhoto', cast(_id as varchar));
}
;

create function DB.DBA.CATEGORYPHOTO_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.NORTHWIND_IRI_TO_ID(_iri));
};

grant execute on DB.DBA.CATEGORY_IRI to "SPARQL";
grant execute on DB.DBA.CATEGORY_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CATEGORYDOC_IRI to "SPARQL";
grant execute on DB.DBA.CATEGORYDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.SHIPPER_IRI to "SPARQL";
grant execute on DB.DBA.SHIPPER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.SHIPPERDOC_IRI to "SPARQL";
grant execute on DB.DBA.SHIPPERDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.SUPPLIER_IRI to "SPARQL";
grant execute on DB.DBA.SUPPLIER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.SUPPLIERDOC_IRI to "SPARQL";
grant execute on DB.DBA.SUPPLIERDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.PRODUCT_IRI to "SPARQL";
grant execute on DB.DBA.PRODUCT_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.PRODUCTDOC_IRI to "SPARQL";
grant execute on DB.DBA.PRODUCTDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CUSTOMER_IRI to "SPARQL";
grant execute on DB.DBA.CUSTOMER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CUSTOMERDOC_IRI to "SPARQL";
grant execute on DB.DBA.CUSTOMERDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.EMPLOYEE_IRI to "SPARQL";
grant execute on DB.DBA.EMPLOYEE_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.EMPLOYEEDOC_IRI to "SPARQL";
grant execute on DB.DBA.EMPLOYEEDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.ORDER_IRI to "SPARQL";
grant execute on DB.DBA.ORDER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.ORDERDOC_IRI to "SPARQL";
grant execute on DB.DBA.ORDERDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CUSTOMERCONTACT_IRI to "SPARQL";
grant execute on DB.DBA.CUSTOMERCONTACT_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CUSTOMERCONTACTDOC_IRI to "SPARQL";
grant execute on DB.DBA.CUSTOMERCONTACTDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.ORDERLINE_IRI to "SPARQL";
grant execute on DB.DBA.ORDERLINE_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.ORDERLINE_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.ORDERLINEDOC_IRI to "SPARQL";
grant execute on DB.DBA.ORDERLINEDOC_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.ORDERLINEDOC_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.PROVINCE_IRI to "SPARQL";
grant execute on DB.DBA.PROVINCE_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.PROVINCE_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.PROVINCEDOC_IRI to "SPARQL";
grant execute on DB.DBA.PROVINCEDOC_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.PROVINCEDOC_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.COUNTRY_IRI to "SPARQL";
grant execute on DB.DBA.COUNTRY_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.COUNTRYDOC_IRI to "SPARQL";
grant execute on DB.DBA.COUNTRYDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.FLAG_IRI to "SPARQL";
grant execute on DB.DBA.FLAG_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.FLAGDOC_IRI to "SPARQL";
grant execute on DB.DBA.FLAGDOC_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.EMPLOYEEPHOTO_IRI to "SPARQL";
grant execute on DB.DBA.EMPLOYEEPHOTO_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CATEGORYPHOTO_IRI to "SPARQL";
grant execute on DB.DBA.CATEGORYPHOTO_IRI_INVERSE to "SPARQL";

SPARQL drop quad map graph iri("http://^{URIQADefaultHost}^/Northwind") .
;

SPARQL drop quad map virtrdf:NorthwindDemo .
;

SPARQL
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
drop iri class northwind:Category .
drop iri class northwind:CategoryDoc .
drop iri class northwind:Shipper .
drop iri class northwind:ShipperDoc .
drop iri class northwind:Supplier .
drop iri class northwind:SupplierDoc .
drop iri class northwind:Product .
drop iri class northwind:ProductDoc .
drop iri class northwind:Customer .
drop iri class northwind:CustomerDoc .
drop iri class northwind:Employee .
drop iri class northwind:EmployeeDoc .
drop iri class northwind:Order .
drop iri class northwind:OrderDoc .
drop iri class northwind:CustomerContact .
drop iri class northwind:CustomerContactDoc .
drop iri class northwind:OrderLine .
drop iri class northwind:OrderLineDoc .
drop iri class northwind:Province .
drop iri class northwind:ProvinceDoc .
drop iri class northwind:Country .
drop iri class northwind:CountryDoc .
drop iri class northwind:Flag .
drop iri class northwind:FlagDoc .
drop iri class northwind:dbpedia_iri .
drop iri class northwind:EmployeePhoto .
drop iri class northwind:CategoryPhoto .
drop iri class northwind:category_iri .
drop iri class northwind:categorydoc_iri .
drop iri class northwind:shipper_iri .
drop iri class northwind:shipperdoc_iri .
drop iri class northwind:supplier_iri .
drop iri class northwind:supplierdoc_iri .
drop iri class northwind:product_iri .
drop iri class northwind:productdoc_iri .
drop iri class northwind:customer_iri .
drop iri class northwind:customerdoc_iri .
drop iri class northwind:employee_iri .
drop iri class northwind:employeedoc_iri .
drop iri class northwind:order_iri .
drop iri class northwind:orderdoc_iri .
drop iri class northwind:customercontact_iri .
drop iri class northwind:customercontactdoc_iri .
drop iri class northwind:orderline_iri .
drop iri class northwind:orderlinedoc_iri .
drop iri class northwind:province_iri .
drop iri class northwind:provincedoc_iri .
drop iri class northwind:country_iri .
drop iri class northwind:countrydoc_iri .
drop iri class northwind:employeephoto_iri .
drop iri class northwind:categoryphoto_iri .
drop iri class northwind:flag_iri .
drop iri class northwind:flagdoc_iri .
;

SPARQL
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>

create iri class northwind:Category "http://^{URIQADefaultHost}^/Northwind/Category/%d#this" (in category_id integer not null) .
create iri class northwind:CategoryDoc "http://^{URIQADefaultHost}^/Northwind/Category/%d" (in category_id integer not null) .
create iri class northwind:Shipper "http://^{URIQADefaultHost}^/Northwind/Shipper/%d#this" (in shipper_id integer not null) .
create iri class northwind:ShipperDoc "http://^{URIQADefaultHost}^/Northwind/Shipper/%d" (in shipper_id integer not null) .
create iri class northwind:Supplier "http://^{URIQADefaultHost}^/Northwind/Supplier/%d#this" (in supplier_id integer not null) .
create iri class northwind:SupplierDoc "http://^{URIQADefaultHost}^/Northwind/Supplier/%d" (in supplier_id integer not null) .
create iri class northwind:Product   "http://^{URIQADefaultHost}^/Northwind/Product/%d#this" (in product_id integer not null) .
create iri class northwind:ProductDoc   "http://^{URIQADefaultHost}^/Northwind/Product/%d" (in product_id integer not null) .
create iri class northwind:Customer "http://^{URIQADefaultHost}^/Northwind/Customer/%U#this" (in customer_id varchar not null) .
create iri class northwind:CustomerDoc "http://^{URIQADefaultHost}^/Northwind/Customer/%U" (in customer_id varchar not null) .
create iri class northwind:Employee "http://^{URIQADefaultHost}^/Northwind/Employee/%U_%U_%d#this" (in employee_firstname varchar not null, in employee_lastname varchar not null, in employee_id integer not null) .
create iri class northwind:EmployeeDoc "http://^{URIQADefaultHost}^/Northwind/Employee/%U_%U_%d" (in employee_firstname varchar not null, in employee_lastname varchar not null, in employee_id integer not null) .
create iri class northwind:Order "http://^{URIQADefaultHost}^/Northwind/Order/%d#this" (in order_id integer not null) .
create iri class northwind:OrderDoc "http://^{URIQADefaultHost}^/Northwind/Order/%d" (in order_id integer not null) .
create iri class northwind:CustomerContact "http://^{URIQADefaultHost}^/Northwind/CustomerContact/%U#this" (in customer_id varchar not null) .
create iri class northwind:CustomerContactDoc "http://^{URIQADefaultHost}^/Northwind/CustomerContact/%U" (in customer_id varchar not null) .
create iri class northwind:OrderLine "http://^{URIQADefaultHost}^/Northwind/OrderLine/%d/%d#this" (in order_id integer not null, in product_id integer not null) .
create iri class northwind:OrderLineDoc "http://^{URIQADefaultHost}^/Northwind/OrderLine/%d/%d" (in order_id integer not null, in product_id integer not null) .
create iri class northwind:Province "http://^{URIQADefaultHost}^/Northwind/Province/%U/%U#this" (in country_name varchar not null, in province_name varchar not null) .
create iri class northwind:ProvinceDoc "http://^{URIQADefaultHost}^/Northwind/Province/%U/%U" (in country_name varchar not null, in province_name varchar not null) .
create iri class northwind:Country "http://^{URIQADefaultHost}^/Northwind/Country/%U#this" (in country_name varchar not null) .
create iri class northwind:CountryDoc "http://^{URIQADefaultHost}^/Northwind/Country/%U" (in country_name varchar not null) .
create iri class northwind:Flag "http://^{URIQADefaultHost}^%U#this" (in flag_path varchar not null) .
create iri class northwind:FlagDoc "http://^{URIQADefaultHost}^%U" (in flag_path varchar not null) .
create iri class northwind:dbpedia_iri "http://dbpedia.org/resource/%U" (in uname varchar not null) .
create iri class northwind:EmployeePhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/EMP%d#this" (in emp_id varchar not null) .
create iri class northwind:CategoryPhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/CAT%d#this" (in category_id varchar not null) .
create iri class northwind:category_iri using
    function DB.DBA.CATEGORY_IRI (in category_id integer) returns varchar,
    function DB.DBA.CATEGORY_IRI_INVERSE (in category_iri varchar) returns integer .
create iri class northwind:categorydoc_iri using
    function DB.DBA.CATEGORYDOC_IRI (in category_id integer) returns varchar,
    function DB.DBA.CATEGORYDOC_IRI_INVERSE (in category_iri varchar) returns integer .
create iri class northwind:shipper_iri using
    function DB.DBA.SHIPPER_IRI (in shipper_id integer) returns varchar,
    function DB.DBA.SHIPPER_IRI_INVERSE (in shipper_iri varchar) returns integer .
create iri class northwind:shipperdoc_iri using
    function DB.DBA.SHIPPERDOC_IRI (in shipper_id integer) returns varchar,
    function DB.DBA.SHIPPERDOC_IRI_INVERSE (in shipper_iri varchar) returns integer .
create iri class northwind:supplier_iri using
    function DB.DBA.SUPPLIER_IRI (in supplier_id varchar) returns varchar,
    function DB.DBA.SUPPLIER_IRI_INVERSE (in supplier_iri varchar) returns varchar.
create iri class northwind:supplierdoc_iri using
    function DB.DBA.SUPPLIERDOC_IRI (in supplier_id varchar) returns varchar,
    function DB.DBA.SUPPLIERDOC_IRI_INVERSE (in supplier_iri varchar) returns varchar .
create iri class northwind:product_iri using
    function DB.DBA.PRODUCT_IRI (in product_id integer) returns varchar,
    function DB.DBA.PRODUCT_IRI_INVERSE (in product_iri varchar) returns integer .
create iri class northwind:productdoc_iri using
    function DB.DBA.PRODUCTDOC_IRI (in product_id integer) returns varchar,
    function DB.DBA.PRODUCTDOC_IRI_INVERSE (in product_iri varchar) returns integer .
create iri class northwind:customer_iri using
    function DB.DBA.CUSTOMER_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.CUSTOMER_IRI_INVERSE (in customer_iri varchar) returns varchar .
create iri class northwind:customerdoc_iri using
    function DB.DBA.CUSTOMERDOC_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.CUSTOMERDOC_IRI_INVERSE (in customer_iri varchar) returns varchar .
create iri class northwind:employee_iri using
    function DB.DBA.EMPLOYEE_IRI (in employee_id integer) returns varchar,
    function DB.DBA.EMPLOYEE_IRI_INVERSE (in employee_iri varchar) returns integer .
create iri class northwind:employeedoc_iri using
    function DB.DBA.EMPLOYEEDOC_IRI (in employee_id integer) returns varchar,
    function DB.DBA.EMPLOYEEDOC_IRI_INVERSE (in employee_iri varchar) returns integer .
create iri class northwind:order_iri using
    function DB.DBA.ORDER_IRI (in order_id integer) returns varchar,
    function DB.DBA.ORDER_IRI_INVERSE (in order_iri varchar) returns integer .
create iri class northwind:orderdoc_iri using
    function DB.DBA.ORDERDOC_IRI (in order_id integer) returns varchar,
    function DB.DBA.ORDERDOC_IRI_INVERSE (in order_iri varchar) returns integer .
create iri class northwind:customercontact_iri using
    function DB.DBA.CUSTOMERCONTACT_IRI (in customercontact_id varchar) returns varchar,
    function DB.DBA.CUSTOMERCONTACT_IRI_INVERSE (in customercontact_iri varchar) returns varchar .
create iri class northwind:customercontactdoc_iri using
    function DB.DBA.CUSTOMERCONTACTDOC_IRI (in customercontact_id varchar) returns varchar,
    function DB.DBA.CUSTOMERCONTACTDOC_IRI_INVERSE (in customercontact_iri varchar) returns varchar .
create iri class northwind:orderline_iri using
    function DB.DBA.ORDERLINE_IRI (in orderline_id integer, in orderline_id2 integer) returns varchar,
    function DB.DBA.ORDERLINE_IRI_INV_1 (in orderline_iri varchar) returns integer,
    function DB.DBA.ORDERLINE_IRI_INV_2 (in orderline_iri varchar) returns integer .
create iri class northwind:orderlinedoc_iri using
    function DB.DBA.ORDERLINEDOC_IRI (in orderline_id integer, in orderline_id2 integer) returns varchar,
    function DB.DBA.ORDERLINEDOC_IRI_INV_1 (in orderline_iri varchar) returns integer,
    function DB.DBA.ORDERLINEDOC_IRI_INV_2 (in orderline_iri varchar) returns integer .
create iri class northwind:province_iri using
    function DB.DBA.PROVINCE_IRI (in province_id varchar, in province_id2 varchar) returns varchar,
    function DB.DBA.PROVINCE_IRI_INV_1 (in province_iri varchar) returns varchar,
    function DB.DBA.PROVINCE_IRI_INV_2 (in province_iri varchar) returns varchar .
create iri class northwind:provincedoc_iri using
    function DB.DBA.PROVINCEDOC_IRI (in province_id varchar, in province_id2 varchar) returns varchar,
    function DB.DBA.PROVINCEDOC_IRI_INV_1 (in province_iri varchar) returns varchar,
    function DB.DBA.PROVINCEDOC_IRI_INV_2 (in province_iri varchar) returns varchar .
create iri class northwind:country_iri using
    function DB.DBA.COUNTRY_IRI (in country_id varchar) returns varchar,
    function DB.DBA.COUNTRY_IRI_INVERSE (in country_iri varchar) returns varchar .
create iri class northwind:countrydoc_iri using
    function DB.DBA.COUNTRYDOC_IRI (in country_id varchar) returns varchar,
    function DB.DBA.COUNTRYDOC_IRI_INVERSE (in country_iri varchar) returns varchar .
create iri class northwind:employeephoto_iri using
    function DB.DBA.EMPLOYEEPHOTO_IRI (in employeephoto_id integer) returns varchar,
    function DB.DBA.EMPLOYEEPHOTO_IRI_INVERSE (in employeephoto_iri varchar) returns integer .
create iri class northwind:categoryphoto_iri using
    function DB.DBA.CATEGORYPHOTO_IRI (in categoryphoto_id integer) returns varchar,
    function DB.DBA.CATEGORYPHOTO_IRI_INVERSE (in categoryphoto_iri varchar) returns integer .
create iri class northwind:flag_iri using
    function DB.DBA.FLAG_IRI (in flag_id varchar) returns varchar,
    function DB.DBA.FLAG_IRI_INVERSE (in flag_iri varchar) returns varchar .
create iri class northwind:flagdoc_iri using
    function DB.DBA.FLAGDOC_IRI (in flag_id varchar) returns varchar,
    function DB.DBA.FLAGDOC_IRI_INVERSE (in flag_iri varchar) returns varchar .
;

SPARQL
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>

alter quad storage virtrdf:DefaultQuadStorage
from Demo.demo.Products as products
from Demo.demo.Suppliers as suppliers
from Demo.demo.Shippers as shippers
from Demo.demo.Categories as categories
from Demo.demo.Customers as customers
from Demo.demo.Employees as employees
from Demo.demo.Orders as orders
from Demo.demo.Order_Details as order_lines
from Demo.demo.Countries as countries
from Demo.demo.Provinces as provinces
where (^{suppliers.}^.Country = ^{countries.}^.Name)
where (^{customers.}^.Country = ^{countries.}^.Name)
where (^{employees.}^.Country = ^{countries.}^.Name)
where (^{orders.}^.ShipCountry = ^{countries.}^.Name)
{
        create virtrdf:NorthwindDemo as graph iri ("http://^{URIQADefaultHost}^/Northwind") option (exclusive)
        {
                northwind:CustomerContact (customers.CustomerID)
                        a foaf:Person
                                as virtrdf:CustomerContact-foaf_Person .

                northwind:CustomerContact (customers.CustomerID)
                        a northwind:CustomerContact
                                as virtrdf:CustomerContact-CustomerContact;
                        foaf:name customers.ContactName
                                as virtrdf:CustomerContact-contact_name ;
                        foaf:phone customers.Phone
                                as virtrdf:CustomerContact-foaf_phone ;
                        northwind:is_contact_at northwind:Customer (customers.CustomerID)
                                as virtrdf:CustomerContact-is_contact_at ;
                        northwind:country northwind:Country (customers.Country)
                                as virtrdf:CustomerContact-country ;
                        rdfs:isDefinedBy northwind:customercontact_iri (customers.CustomerID) .

                northwind:CustomerContactDoc (customers.CustomerID)
                        a northwind:CustomerContactDoc
                                as virtrdf:CustomerContactDoc-CustomerID ;
                        a foaf:Document
                                as virtrdf:CustomerContactDoc-foaf_DocCustomerID ;
                        foaf:primaryTopic northwind:CustomerContact (customers.CustomerID)
                                as virtrdf:CustomerContactDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:customercontactdoc_iri (customers.CustomerID) .

                northwind:Country (customers.Country)
                        northwind:is_country_of
                northwind:CustomerContact (customers.CustomerID) as virtrdf:CustomerContact-is_country_of .

                northwind:Product (products.ProductID)
                        a northwind:Product
                                as virtrdf:Product-ProductID ;
                        northwind:has_category northwind:Category (products.CategoryID)
                                as virtrdf:Product-product_has_category ;
                        northwind:has_supplier northwind:Supplier (products.SupplierID)
                                as virtrdf:Product-product_has_supplier ;
                        northwind:productName products.ProductName
                                as virtrdf:Product-name_of_product ;
                        northwind:quantityPerUnit products.QuantityPerUnit
                                as virtrdf:Product-quantity_per_unit ;
                        northwind:unitPrice products.UnitPrice
                                as virtrdf:Product-unit_price ;
                        northwind:unitsInStock products.UnitsInStock
                                as virtrdf:Product-units_in_stock ;
                        northwind:unitsOnOrder products.UnitsOnOrder
                                as virtrdf:Product-units_on_order ;
                        northwind:reorderLevel products.ReorderLevel
                                as virtrdf:Product-reorder_level ;
                        northwind:discontinued products.Discontinued
                                as virtrdf:Product-discontinued ;
                        rdfs:isDefinedBy northwind:product_iri (products.ProductID) .

                northwind:ProductDoc (products.ProductID)
                        a northwind:ProductDoc
                                as virtrdf:ProductDoc-ProductID ;
                        a foaf:Document
                                as virtrdf:ProductDoc-foaf_DocProductID ;
                        foaf:primaryTopic northwind:Product (products.ProductID)
                                as virtrdf:ProductDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:productdoc_iri (products.ProductID) .

                northwind:Category (products.CategoryID)
                        northwind:category_of northwind:Product (products.ProductID) as virtrdf:Product-category_of .

                northwind:Supplier (products.SupplierID)
                        northwind:supplier_of northwind:Product (products.ProductID) as virtrdf:Product-supplier_of .

                northwind:Supplier (suppliers.SupplierID)
                        a northwind:Supplier
                                as virtrdf:Supplier-SupplierID ;
                        northwind:companyName suppliers.CompanyName
                                as virtrdf:Supplier-company_name ;
                        northwind:contactName suppliers.ContactName
                                as virtrdf:Supplier-contact_name ;
                        northwind:contactTitle suppliers.ContactTitle
                                as virtrdf:Supplier-contact_title ;
                        northwind:address suppliers.Address
                                as virtrdf:Supplier-address ;
                        northwind:city suppliers.City
                                as virtrdf:Supplier-city ;
                        northwind:dbpedia_city northwind:dbpedia_iri(suppliers.City)
                                as virtrdf:Supplier-dbpediacity ;
                        northwind:region suppliers.Region
                                as virtrdf:Supplier-region ;
                        northwind:postalCode suppliers.PostalCode
                                as virtrdf:Supplier-postal_code ;
                        northwind:country northwind:Country(suppliers.Country)
                                as virtrdf:Supplier-country ;
                        northwind:phone suppliers.Phone
                                as virtrdf:Supplier-phone ;
                        northwind:fax suppliers.Fax
                                as virtrdf:Supplier-fax ;
                        northwind:homePage suppliers.HomePage
                                as virtrdf:Supplier-home_page ;
                        rdfs:isDefinedBy northwind:supplier_iri (suppliers.SupplierID) .

                northwind:SupplierDoc (suppliers.SupplierID)
                        a northwind:SupplierDoc
                                as virtrdf:SupplierDoc-SupplierID ;
                        a foaf:Document
                                as virtrdf:SupplierDoc-foaf_DocSupplierID ;
                        foaf:primaryTopic northwind:Supplier (suppliers.SupplierID)
                                as virtrdf:SupplierDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:supplierdoc_iri (suppliers.SupplierID) .

                northwind:Country (suppliers.Country)
                        northwind:is_country_of
                northwind:Supplier (suppliers.SupplierID) as virtrdf:Supplier-is_country_of .

                northwind:Category (categories.CategoryID)
                        a northwind:Category
                                as virtrdf:Category-CategoryID ;
                        northwind:categoryName categories.CategoryName
                                as virtrdf:Category-home_page ;
                        northwind:description categories.Description
                                as virtrdf:Category-description ;
			foaf:img northwind:CategoryPhoto(categories.CategoryID)
                                as virtrdf:Category-categories.CategoryPhoto ;
                        rdfs:isDefinedBy northwind:category_iri (categories.CategoryID) .
				
                northwind:CategoryDoc (categories.CategoryID)
                        a northwind:CategoryDoc
                                as virtrdf:CategoryDoc-CategoryID ;
                        a foaf:Document
                                as virtrdf:CategoryDoc-foaf_DocCategoryID ;
                        foaf:primaryTopic northwind:Category (categories.CategoryID)
                                as virtrdf:CategoryDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:categorydoc_iri (categories.CategoryID) .

				northwind:CategoryPhoto(categories.CategoryID)
						a northwind:CategoryPhoto
                                as virtrdf:Category-categories.CategoryPhotoID ;
                        rdfs:isDefinedBy northwind:categoryphoto_iri (categories.CategoryID) .

                northwind:Shipper (shippers.ShipperID)
                        a northwind:Shipper
                                as virtrdf:Shipper-ShipperID ;
                        northwind:companyName shippers.CompanyName
                                as virtrdf:Shipper-company_name ;
                        northwind:phone shippers.Phone
                                as virtrdf:Shipper-phone ;
                        rdfs:isDefinedBy northwind:shipper_iri (shippers.ShipperID) .

                northwind:ShipperDoc (shippers.ShipperID)
                        a northwind:ShipperDoc
                                as virtrdf:ShipperDoc-ShipperID ;
                        a  foaf:Document
                                as virtrdf:ShipperDoc-foaf_DocShipperID ;
                        foaf:primaryTopic northwind:Shipper (shippers.ShipperID)
                                as virtrdf:ShipperDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:shipperdoc_iri (shippers.ShipperID) .

                northwind:Customer (customers.CustomerID)
                        a  northwind:Customer
                                as virtrdf:Customer-CustomerID2 ;
                        a  foaf:Organization
                                as virtrdf:Customer-CustomerID ;
                        foaf:name customers.CompanyName
                                as virtrdf:Customer-foaf_name ;
                        northwind:companyName customers.CompanyName
                                as virtrdf:Customer-company_name ;
                        northwind:has_contact northwind:CustomerContact (customers.CustomerID)
                                as virtrdf:Customer-contact ;
                        northwind:country northwind:Country (customers.Country)
                                as virtrdf:Customer-country ;
                        northwind:contactName customers.ContactName
                                as virtrdf:Customer-contact_name ;
                        northwind:contactTitle customers.ContactTitle
                                as virtrdf:Customer-contact_title ;
                        northwind:address customers.Address
                                as virtrdf:Customer-address ;
                        northwind:city customers.City
                                as virtrdf:Customer-city ;
                        northwind:dbpedia_city northwind:dbpedia_iri(customers.City)
                                as virtrdf:Customer-dbpediacity ;
                        northwind:region customers.Region
                                as virtrdf:Customer-region ;
                        northwind:PostalCode customers.PostalCode
                                as virtrdf:Customer-postal_code ;
                        foaf:phone customers.Phone
                                as virtrdf:Customer-foaf_phone ;
                        northwind:phone customers.Phone
                                as virtrdf:Customer-phone ;
                        northwind:fax customers.Fax
                                as virtrdf:Customer-fax ;
                        rdfs:isDefinedBy northwind:customer_iri (customers.CustomerID) .

                northwind:CustomerDoc (customers.CustomerID)
                        a  northwind:CustomerDoc
                                as virtrdf:CustomerDoc-CustomerID2 ;
                        a  foaf:Document
                                as virtrdf:CustomerDoc-CustomerID3 ;
                        foaf:primaryTopic northwind:Customer (customers.CustomerID)
                                as virtrdf:CustomerDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:customerdoc_iri (customers.CustomerID) .

                northwind:Country (customers.Country)
                        northwind:is_country_of
                northwind:Customer (customers.CustomerID) as virtrdf:Customer-is_country_of .
                
                northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID)
                        a northwind:Employee
                                as virtrdf:Employee-EmployeeID2 ;
                        a foaf:Person
                                as virtrdf:Employee-EmployeeID ;
                        foaf:surname employees.LastName
                                as virtrdf:Employee-foaf_last_name ;
                        northwind:lastName employees.LastName
                                as virtrdf:Employee-last_name ;
                        foaf:firstName employees.FirstName
                                as virtrdf:Employee-foaf_first_name ;
                        northwind:firstName employees.FirstName
                                as virtrdf:Employee-first_name ;
                        foaf:title employees.Title
                                as virtrdf:Employee-title ;
                        northwind:titleOfCourtesy employees.TitleOfCourtesy
                                as virtrdf:Employee-title_of_courtesy ;
                        foaf:birthday employees.BirthDate
                                as virtrdf:Employee-foaf_birth_date ;
                        northwind:birthday employees.BirthDate
                                as virtrdf:Employee-birth_date ;
                        northwind:hireDate employees.HireDate
                                as virtrdf:Employee-hire_date ;
                        northwind:address employees.Address
                                as virtrdf:Employee-address ;
                        northwind:city employees.City
                                as virtrdf:Employee-city ;
                        northwind:dbpedia_city northwind:dbpedia_iri(employees.City)
                                as virtrdf:Employee-dbpediacity ;
                        northwind:region employees.Region
                                as virtrdf:Employee-region ;
                        northwind:postalCode employees.PostalCode
                                as virtrdf:Employee-postal_code ;
                        northwind:country northwind:Country(employees.Country)
                                as virtrdf:Employee-country ;
                        foaf:phone employees.HomePhone
                                as virtrdf:Employee-home_phone ;
                        northwind:extension employees.Extension
                                as virtrdf:Employee-extension ;
                        northwind:notes employees.Notes
                                as virtrdf:Employee-notes ;
                        northwind:reportsTo northwind:Employee(employees.FirstName, employees.LastName, employees.ReportsTo) where (^{employees.}^.ReportsTo = ^{employees.}^.EmployeeID)
                                as virtrdf:Employee-reports_to ;
			foaf:img northwind:EmployeePhoto(employees.EmployeeID)                                                                                                      
                                as virtrdf:Employee-employees.EmployeePhoto ;
                        rdfs:isDefinedBy northwind:employee_iri (employees.EmployeeID) .

                northwind:EmployeeDoc (employees.FirstName, employees.LastName, employees.EmployeeID)
                        a  northwind:EmployeeDoc
                                as virtrdf:EmployeeDoc-EmployeeID2 ;
                        a  foaf:Document
                                as virtrdf:EmployeeDoc-EmployeeID3 ;
                        foaf:primaryTopic northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID)
                                as virtrdf:EmployeeDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:employeedoc_iri (employees.EmployeeID) .

				northwind:EmployeePhoto(employees.EmployeeID)
						a northwind:EmployeePhoto
                                as virtrdf:Employee-employees.EmployeePhotoId ;
                        rdfs:isDefinedBy northwind:employeephoto_iri (employees.EmployeeID) .

                northwind:Employee (employees.FirstName, employees.LastName, orders.EmployeeID)
                        northwind:is_salesrep_of
                northwind:Order (orders.OrderID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID) as virtrdf:Order-is_salesrep_of .

                northwind:Country (employees.Country)
                        northwind:is_country_of
                northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID) as virtrdf:Employee-is_country_of .

                northwind:Order (orders.OrderID)
                        a northwind:Order
                                as virtrdf:Order-Order ;
                        northwind:has_customer northwind:Customer (orders.CustomerID)
                                as virtrdf:Order-order_has_customer ;
                        northwind:has_salesrep northwind:Employee (employees.FirstName, employees.LastName, orders.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as virtrdf:Customer-has_salesrep ;
                        northwind:has_employee northwind:Employee (employees.FirstName, employees.LastName, orders.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as virtrdf:Order-order_has_employee ;
                        northwind:orderDate orders.OrderDate
                                as virtrdf:Order-order_date ;
                        northwind:requiredDate orders.RequiredDate
                                as virtrdf:Order-required_date ;
                        northwind:shippedDate orders.ShippedDate
                                as virtrdf:Order-shipped_date ;
                        northwind:order_ship_via northwind:Shipper (orders.ShipVia)
                                as virtrdf:Order-order_ship_via ;
                        northwind:freight orders.Freight
                                as virtrdf:Order-freight ;
                        northwind:shipName orders.ShipName
                                as virtrdf:Order-ship_name ;
                        northwind:shipAddress orders.ShipAddress
                                as virtrdf:Order-ship_address ;
                        northwind:shipCity orders.ShipCity
                                as virtrdf:Order-ship_city ;
                        northwind:dbpedia_shipCity northwind:dbpedia_iri(orders.ShipCity)
                                as virtrdf:Order-dbpediaship_city ;
                        northwind:shipRegion orders.ShipRegion
                                as virtrdf:Order-ship_region ;
                        northwind:shipPostal_code orders.ShipPostalCode
                                as virtrdf:Order-ship_postal_code ;
                        northwind:shipCountry northwind:Country(orders.ShipCountry)
                                as virtrdf:ship_country ;
                        rdfs:isDefinedBy northwind:order_iri (orders.OrderID) .

                northwind:OrderDoc (orders.OrderID)
                        a  northwind:OrderDoc
                                as virtrdf:OrderDoc-OrderID2 ;
                        a  foaf:Document
                                as virtrdf:OrderDoc-OrderID3 ;
                        foaf:primaryTopic northwind:Order (orders.OrderID)
                                as virtrdf:OrderDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:orderdoc_iri (orders.OrderID) .

                northwind:Country (orders.ShipCountry)
                        northwind:is_ship_country_of
                northwind:Order (orders.OrderID) as virtrdf:Order-is_country_of .

                northwind:Customer (orders.CustomerID)
                        northwind:has_order northwind:Order (orders.OrderID) as virtrdf:Order-has_order .

                northwind:Shipper (orders.ShipVia)
                        northwind:ship_order northwind:Order (orders.OrderID) as virtrdf:Order-ship_order .

                northwind:OrderLine (order_lines.OrderID, order_lines.ProductID)
                        a northwind:OrderLine
                                as virtrdf:OrderLine-OrderLines ;
                        northwind:has_order_id northwind:Order (order_lines.OrderID)
                                as virtrdf:order_lines_has_order_id ;
                        northwind:has_product_id northwind:Product (order_lines.ProductID)
                                as virtrdf:order_lines_has_product_id ;
                        northwind:unitPrice order_lines.UnitPrice
                                as virtrdf:OrderLine-unit_price ;
                        northwind:quantity order_lines.Quantity
                                as virtrdf:OrderLine-quantity ;
                        northwind:discount order_lines.Discount
                                as virtrdf:OrderLine-discount ;
                        rdfs:isDefinedBy northwind:orderline_iri (order_lines.OrderID, order_lines.ProductID) .
                                
                northwind:OrderLineDoc (order_lines.OrderID, order_lines.ProductID)
                        a  northwind:OrderLineDoc
                                as virtrdf:OrderLineDoc-OrderLineID2 ;
                        a  foaf:Document
                                as virtrdf:OrderLineDoc-OrderLineID3 ;
                        foaf:primaryTopic northwind:OrderLine (order_lines.OrderID, order_lines.ProductID)
                                as virtrdf:OrderLineDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:orderlinedoc_iri (order_lines.OrderID, order_lines.ProductID) .

                northwind:Order (orders.OrderID)
                        northwind:is_order_of
                northwind:OrderLine (order_lines.OrderID, order_lines.ProductID) where (^{orders.}^.OrderID = ^{order_lines.}^.OrderID) as virtrdf:Order-is_order_of .

                northwind:Product (products.ProductID)
                        northwind:is_product_of
                northwind:OrderLine (order_lines.OrderID, order_lines.ProductID) where (^{products.}^.ProductID = ^{order_lines.}^.ProductID) as virtrdf:Product-is_product_of .

                northwind:Country (countries.Name)
                        a northwind:Country
                                as virtrdf:Country-Type2 ;
                        a wgs:SpatialThing
                                as virtrdf:Country-Type ;
                        owl:sameAs northwind:dbpedia_iri (countries.Name) ;
                        northwind:name countries.Name
                                as virtrdf:Country-Name ;
                        northwind:code countries.Code
                                as virtrdf:Country-Code ;
                        northwind:smallFlagDAVResourceName countries.SmallFlagDAVResourceName
                                as virtrdf:Country-SmallFlagDAVResourceName ;
                        northwind:largeFlagDAVResourceName countries.LargeFlagDAVResourceName
                                as virtrdf:Country-LargeFlagDAVResourceName ;
                        northwind:smallFlagDAVResourceURI northwind:Flag(countries.SmallFlagDAVResourceURI)
                                as virtrdf:Country-SmallFlagDAVResourceURI ;
                        northwind:largeFlagDAVResourceURI northwind:Flag(countries.LargeFlagDAVResourceURI)
                                as virtrdf:Country-LargeFlagDAVResourceURI ;
                        wgs:lat countries.Lat
                                as virtrdf:Country-Lat ;
                        wgs:long countries.Lng
                                as virtrdf:Country-Lng ;
                        rdfs:isDefinedBy northwind:country_iri (countries.Name) .

                northwind:CountryDoc (countries.Name)
                        a  northwind:CountryDoc
                                as virtrdf:CountryDoc-CountryID2 ;
                        a  foaf:Document
                                as virtrdf:CountryDoc-CountryID3 ;
                        foaf:primaryTopic northwind:Country (countries.Name)
                                as virtrdf:CountryDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:countrydoc_iri (countries.Name) .

                northwind:Country (countries.Name)
                        northwind:has_province
                northwind:Province (provinces.CountryCode, provinces.Province) where (^{provinces.}^.CountryCode = ^{countries.}^.Code) as virtrdf:Country-has_province .

                northwind:Province (provinces.CountryCode, provinces.Province)
                        a northwind:Province
                                as virtrdf:Province-Provinces ;
                        northwind:has_country_code provinces.CountryCode
                                as virtrdf:has_country_code ;
                        northwind:provinceName provinces.Province
                                as virtrdf:Province-ProvinceName ;
                        rdfs:isDefinedBy northwind:province_iri (provinces.CountryCode, provinces.Province) .

                northwind:ProvinceDoc (provinces.CountryCode, provinces.Province)
                        a  northwind:ProvinceDoc
                                as virtrdf:ProvinceDoc-ProvinceID2 ;
                        a  foaf:Document
                                as virtrdf:ProvinceDoc-ProvinceID3 ;
                        foaf:primaryTopic northwind:Province (provinces.CountryCode, provinces.Province)
                                as virtrdf:ProvinceDoc-foaf_primarytopic ;
                        rdfs:isDefinedBy northwind:provincedoc_iri (provinces.CountryCode, provinces.Province) .

                northwind:Province (provinces.CountryCode, provinces.Province)
                        northwind:is_province_of
                northwind:Country (countries.Name) where  (^{countries.}^.Code = ^{provinces.}^.CountryCode) as virtrdf:Province-country_of .
        }.
}.
;

create procedure DB.DBA.REMOVE_DEMO_RDF_DET()
{
  declare colid int;
  colid := DAV_SEARCH_ID('/DAV/home/demo/', 'C');
  if (colid < 0)
    return;
  update WS.WS.SYS_DAV_COL set COL_DET=null where COL_ID = colid;
}
;

DB.DBA.REMOVE_DEMO_RDF_DET();

drop procedure DB.DBA.REMOVE_DEMO_RDF_DET;

create procedure DB.DBA.NORTHWIND_MAKE_RDF_DET()
{
    declare uriqa_str varchar;
    uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    uriqa_str := 'http://' || uriqa_str || '/Northwind';
    DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/home/demo/RDFData/', uriqa_str, NULL);
    VHOST_REMOVE (lpath=>'/Northwind/data/rdf');
    DB.DBA.VHOST_DEFINE (lpath=>'/Northwind/data/rdf', ppath=>'/DAV/home/demo/RDFData/All/', is_dav=>1, vsp_user=>'dba');
}
;

DB.DBA.NORTHWIND_MAKE_RDF_DET();
drop procedure DB.DBA.NORTHWIND_MAKE_RDF_DET;

delete from DB.DBA.URL_REWRITE_RULE_LIST where urrl_list like 'demo_nw%';
delete from DB.DBA.URL_REWRITE_RULE where urr_rule like 'demo_nw%';

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule2',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/sparql?query=DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%3E+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/Northwind%%3E&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule1',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/about/html/http://^{URIQADefaultHost}^%s',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'demo_nw_rule_list1',
    1,
    vector (
                'demo_nw_rule1',
                'demo_nw_rule2'
          ));


VHOST_REMOVE (lpath=>'/Northwind');
DB.DBA.VHOST_DEFINE (lpath=>'/Northwind', ppath=>'/DAV/home/demo/', vsp_user=>'dba', is_dav=>1,
          is_brws=>0, opts=>vector ('url_rewrite', 'demo_nw_rule_list1'));

create procedure DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV()
{
  declare content1, urihost varchar;
  select cast (RES_CONTENT as varchar) into content1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/demo/sql/nw.owl';
  DB.DBA.RDF_LOAD_RDFXML (content1, 'http://demo.openlinksw.com/schemas/northwind#', 'http://demo.openlinksw.com/schemas/NorthwindOntology/1.0/');
  urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/northwind');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/northwind', ppath=>'/DAV/VAD/demo/sql/nw.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/northwind#');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/northwind#', ppath=>'/DAV/VAD/demo/sql/nw.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
};

DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV();
drop procedure DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV;

DB.DBA.XML_SET_NS_DECL ('northwind', 'http://demo.openlinksw.com/schemas/northwind#', 2);
