use DB;

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
  --result ('STATE=' || stat || ': ' || msg);
  --if (__tag(rowset) = 193)
  --{
  --  foreach (any r in rowset) do
  --    result (r[0] || ': ' || r[1]);
  --}
}
;

DB.DBA.exec_no_error('GRANT \"SPARQL_UPDATE\" TO \"SPARQL\"')
;

DB.DBA.exec_no_error('UPDATE WS.WS.SYS_DAV_RES set RES_TYPE=\'image/jpeg\' where RES_FULL_PATH like \'/DAV/VAD/demo/sql/CAT%\'')
;

DB.DBA.exec_no_error('UPDATE WS.WS.SYS_DAV_RES set RES_TYPE=\'image/jpeg\' where RES_FULL_PATH like \'/DAV/VAD/demo/sql/EMP%\'')
;

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

DB.DBA.SPARQL_NW_RUN ('
drop quad map graph iri("http://^{URIQADefaultHost}^/Northwind") .
')
;

DB.DBA.SPARQL_NW_RUN ('
drop quad map virtrdf:NorthwindDemo .
')
;

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

create function DB.DBA.SHIPPER_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Shipper', cast(_id as varchar));
}
;

create function DB.DBA.SHIPPER_IRI_INVERSE (in _iri varchar) returns integer
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

create function DB.DBA.PRODUCT_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Product', cast(_id as varchar));
}
;

create function DB.DBA.PRODUCT_IRI_INVERSE (in _iri varchar) returns integer
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

create function DB.DBA.EMPLOYEE_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Employee', cast(_id as varchar));
}
;

create function DB.DBA.EMPLOYEE_IRI_INVERSE (in _iri varchar) returns integer
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

create function DB.DBA.CUSTOMERCONTACT_IRI (in _id integer) returns varchar
{
    return NORTHWIND_ID_TO_IRI('CustomerContact', cast(_id as varchar));
}
;

create function DB.DBA.CUSTOMERCONTACT_IRI_INVERSE (in _iri varchar) returns integer
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

create function DB.DBA.COUNTRY_IRI (in _id varchar) returns varchar
{
    return NORTHWIND_ID_TO_IRI('Country', _id);
}
;

create function DB.DBA.COUNTRY_IRI_INVERSE (in _iri varchar) returns varchar
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
grant execute on DB.DBA.SHIPPER_IRI to "SPARQL";
grant execute on DB.DBA.SHIPPER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.SUPPLIER_IRI to "SPARQL";
grant execute on DB.DBA.SUPPLIER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.PRODUCT_IRI to "SPARQL";
grant execute on DB.DBA.PRODUCT_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CUSTOMER_IRI to "SPARQL";
grant execute on DB.DBA.CUSTOMER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.EMPLOYEE_IRI to "SPARQL";
grant execute on DB.DBA.EMPLOYEE_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.ORDER_IRI to "SPARQL";
grant execute on DB.DBA.ORDER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CUSTOMERCONTACT_IRI to "SPARQL";
grant execute on DB.DBA.CUSTOMERCONTACT_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.ORDERLINE_IRI to "SPARQL";
grant execute on DB.DBA.ORDERLINE_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.ORDERLINE_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.PROVINCE_IRI to "SPARQL";
grant execute on DB.DBA.PROVINCE_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.PROVINCE_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.COUNTRY_IRI to "SPARQL";
grant execute on DB.DBA.COUNTRY_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.FLAG_IRI to "SPARQL";
grant execute on DB.DBA.FLAG_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.EMPLOYEEPHOTO_IRI to "SPARQL";
grant execute on DB.DBA.EMPLOYEEPHOTO_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.CATEGORYPHOTO_IRI to "SPARQL";
grant execute on DB.DBA.CATEGORYPHOTO_IRI_INVERSE to "SPARQL";

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:Category "http://^{URIQADefaultHost}^/Northwind/Category/%d#this" (in category_id integer not null) .
create iri class northwind:Shipper "http://^{URIQADefaultHost}^/Northwind/Shipper/%d#this" (in shipper_id integer not null) .
create iri class northwind:Supplier "http://^{URIQADefaultHost}^/Northwind/Supplier/%d#this" (in supplier_id integer not null) .
create iri class northwind:Product   "http://^{URIQADefaultHost}^/Northwind/Product/%d#this" (in product_id integer not null) .
create iri class northwind:Customer "http://^{URIQADefaultHost}^/Northwind/Customer/%U#this" (in customer_id varchar not null) .
create iri class northwind:Employee "http://^{URIQADefaultHost}^/Northwind/Employee/%U%U%d#this" (in employee_firstname varchar not null, in employee_lastname varchar not null, in employee_id integer not null) .
create iri class northwind:Order "http://^{URIQADefaultHost}^/Northwind/Order/%d#this" (in order_id integer not null) .
create iri class northwind:CustomerContact "http://^{URIQADefaultHost}^/Northwind/CustomerContact/%U#this" (in customer_id varchar not null) .
create iri class northwind:OrderLine "http://^{URIQADefaultHost}^/Northwind/OrderLine/%d/%d#this" (in order_id integer not null, in product_id integer not null) .
create iri class northwind:Province "http://^{URIQADefaultHost}^/Northwind/Province/%U/%U#this" (in country_name varchar not null, in province_name varchar not null) .
create iri class northwind:Country "http://^{URIQADefaultHost}^/Northwind/Country/%U#this" (in country_name varchar not null) .
create iri class northwind:Flag "http://^{URIQADefaultHost}^%U#this" (in flag_path varchar not null) .
create iri class northwind:dbpedia_iri "http://dbpedia.org/resource/%U" (in uname varchar not null) .
create iri class northwind:EmployeePhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/EMP%d#this" (in emp_id varchar not null) .
create iri class northwind:CategoryPhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/CAT%d#this" (in category_id varchar not null) .
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:category_iri using
    function DB.DBA.CATEGORY_IRI (in customer_id integer) returns varchar,
    function DB.DBA.CATEGORY_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:shipper_iri using
    function DB.DBA.SHIPPER_IRI (in customer_id integer) returns varchar,
    function DB.DBA.SHIPPER_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:supplier_iri using
    function DB.DBA.SUPPLIER_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.SUPPLIER_IRI_INVERSE (in customer_iri varchar) returns varchar.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:product_iri using
    function DB.DBA.PRODUCT_IRI (in customer_id integer) returns varchar,
    function DB.DBA.PRODUCT_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:customer_iri using
    function DB.DBA.CUSTOMER_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.CUSTOMER_IRI_INVERSE (in customer_iri varchar) returns varchar.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:employee_iri using
    function DB.DBA.EMPLOYEE_IRI (in customer_id integer) returns varchar,
    function DB.DBA.EMPLOYEE_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:order_iri using
    function DB.DBA.ORDER_IRI (in customer_id integer) returns varchar,
    function DB.DBA.ORDER_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:customercontact_iri using
    function DB.DBA.CUSTOMERCONTACT_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.CUSTOMERCONTACT_IRI_INVERSE (in customer_iri varchar) returns varchar.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:orderline_iri using
    function DB.DBA.ORDERLINE_IRI (in customer_id integer, in customer_id2 integer) returns varchar,
    function DB.DBA.ORDERLINE_IRI_INV_1 (in customer_iri varchar) returns integer,
    function DB.DBA.ORDERLINE_IRI_INV_2 (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:province_iri using
    function DB.DBA.PROVINCE_IRI (in customer_id varchar, in customer_id2 varchar) returns varchar,
    function DB.DBA.PROVINCE_IRI_INV_1 (in customer_iri varchar) returns varchar,
    function DB.DBA.PROVINCE_IRI_INV_2 (in customer_iri varchar) returns varchar.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:country_iri using
    function DB.DBA.COUNTRY_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.COUNTRY_IRI_INVERSE (in customer_iri varchar) returns varchar.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:employeephoto_iri using
    function DB.DBA.EMPLOYEEPHOTO_IRI (in customer_id integer) returns varchar,
    function DB.DBA.EMPLOYEEPHOTO_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:categoryphoto_iri using
    function DB.DBA.CATEGORYPHOTO_IRI (in customer_id integer) returns varchar,
    function DB.DBA.CATEGORYPHOTO_IRI_INVERSE (in customer_iri varchar) returns integer.
')
;

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class northwind:flag_iri using
    function DB.DBA.FLAG_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.FLAG_IRI_INVERSE (in customer_iri varchar) returns varchar.
')
;

DB.DBA.SPARQL_NW_RUN ('
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
prefix owl: <http://www.w3.org/2002/07/owl#>
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
                        rdfs:isDefinedBy northwind:customercontact_iri (customers.CustomerID) ;
                        rdfs:isDefinedBy northwind:CustomerContact (customers.CustomerID) .

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
                        rdfs:isDefinedBy northwind:product_iri (products.ProductID) ;
                        rdfs:isDefinedBy northwind:Product (products.ProductID) .

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
                        rdfs:isDefinedBy northwind:supplier_iri (suppliers.SupplierID) ;
                        rdfs:isDefinedBy northwind:Supplier (suppliers.SupplierID) .

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
                        rdfs:isDefinedBy northwind:category_iri (categories.CategoryID) ;
                        rdfs:isDefinedBy northwind:Category (categories.CategoryID) .
				
				northwind:CategoryPhoto(categories.CategoryID)
						a northwind:CategoryPhoto
                                as virtrdf:Category-categories.CategoryPhotoID ;
                        rdfs:isDefinedBy northwind:categoryphoto_iri (categories.CategoryID) ;
                        rdfs:isDefinedBy northwind:CategoryPhoto(categories.CategoryID) .

                northwind:Shipper (shippers.ShipperID)
                        a northwind:Shipper
                                as virtrdf:Shipper-ShipperID ;
                        northwind:companyName shippers.CompanyName
                                as virtrdf:Shipper-company_name ;
                        northwind:phone shippers.Phone
                                as virtrdf:Shipper-phone ;
                        rdfs:isDefinedBy northwind:shipper_iri (shippers.ShipperID) ;
                        rdfs:isDefinedBy northwind:Shipper (shippers.ShipperID) .

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
                        rdfs:isDefinedBy northwind:customer_iri (customers.CustomerID) ;
                        rdfs:isDefinedBy northwind:Customer (customers.CustomerID) .

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
                        rdfs:isDefinedBy northwind:employee_iri (employees.EmployeeID) ;
                        rdfs:isDefinedBy northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID) .

				northwind:EmployeePhoto(employees.EmployeeID)
						a northwind:EmployeePhoto
                                as virtrdf:Employee-employees.EmployeePhotoId ;
                        rdfs:isDefinedBy northwind:employeephoto_iri (employees.EmployeeID) ;
                        rdfs:isDefinedBy northwind:EmployeePhoto (employees.EmployeeID) .                        

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
                        rdfs:isDefinedBy northwind:order_iri (orders.OrderID) ;
                        rdfs:isDefinedBy northwind:Order (orders.OrderID) .

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
                        rdfs:isDefinedBy northwind:orderline_iri (order_lines.OrderID, order_lines.ProductID) ;
                        rdfs:isDefinedBy northwind:OrderLine (order_lines.OrderID, order_lines.ProductID) .
                                
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
                        rdfs:isDefinedBy northwind:country_iri (countries.Name) ;
                        rdfs:isDefinedBy northwind:Country (countries.Name) .

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
                        rdfs:isDefinedBy northwind:province_iri (provinces.CountryCode, provinces.Province) ;
                        rdfs:isDefinedBy northwind:Province (provinces.CountryCode, provinces.Province) .

                northwind:Province (provinces.CountryCode, provinces.Province)
                        northwind:is_province_of
                northwind:Country (countries.Name) where  (^{countries.}^.Code = ^{provinces.}^.CountryCode) as virtrdf:Province-country_of .
        }
}
')
;

create procedure demo_nw_rdf_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*\x24', path);
  return r||'#this';
};

create procedure demo_nw_html_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*#', path);
  return subseq (r, 0, length (r)-1);
};

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule2',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/Northwind%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
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
    '/rdfbrowser/index.html?uri=http%%3A//^{URIQADefaultHost}^%U%%23this',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule3',
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

-- procedure to convert path to DET resource name
create procedure DB.DBA.NORTHWIND_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  uriqa_str := 'http://' || uriqa_str || '/Northwind';
  iri := uriqa_str || val;
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('northwind_rdf', 1,
    '/Northwind/(.*)', vector('path'), 1, 
    '/Northwind/data/rdf/%U', vector('path'),
    'DB.DBA.NORTHWIND_DET_REF',
    'application/rdf.xml',
    2,  
    303);

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'demo_nw_rule_list1',
    1,
    vector (
                'demo_nw_rule1',
                'demo_nw_rule2',
                'demo_nw_rule3',
                'northwind_rdf'
          ));


VHOST_REMOVE (lpath=>'/Northwind');
DB.DBA.VHOST_DEFINE (lpath=>'/Northwind', ppath=>'/DAV/home/demo/', vsp_user=>'dba', is_dav=>1, def_page=>'sfront.vspx',
          is_brws=>0, opts=>vector ('url_rewrite', 'demo_nw_rule_list1'));

