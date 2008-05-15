use DB;

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

SPARQL
prefix tut_northwind: <http://demo.openlinksw.com/schemas/tutorial/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
drop quad map graph iri("http://^{URIQADefaultHost}^/tutorial/Northwind") .
;

SPARQL
prefix tut_northwind: <http://demo.openlinksw.com/schemas/tutorial/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
drop quad map virtrdf:TutorialNorthwindDemo .
;

create function DB.DBA.TUT_NORTHWIND_ID_TO_IRI(in _prefix varchar,in _id varchar)
{
  declare iri, uriqa_host any;
  uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  iri := 'http://' || uriqa_host || '/tutorial/Northwind/' || _prefix || '/' || _id || '#this';
  return sprintf ('http://%s/DAV/VAD/tutorial/rdfview/rd_v_1/RDFData/All/iid%%20(%d).rdf', uriqa_host, iri_id_num (iri_to_id (iri)));
}
;

create function DB.DBA.TUT_NORTHWIND_IRI_TO_ID(in _iri varchar)
{
    declare parts any;
    parts := sprintf_inverse (_iri, 'http://%s/DAV/VAD/tutorial/rdfview/rd_v_1/RDFData/All/iid (%d).rdf', 1 );
    if (parts is not null)
    {
        declare uriqa_host, iri any;
        uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
        if (parts[0] = uriqa_host)
        {
            iri := id_to_iri(iri_id_from_num(parts[1]));
            parts := sprintf_inverse (iri, 'http://%s/tutorial/Northwind/%s/%s#this', 1 );
            if (parts[0] = uriqa_host)
            {
                return parts[2];
            }
        }
    }
    return NULL;
}
;

create function DB.DBA.TUT_CATEGORY_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Category', cast(_id as varchar));
}
;

create function DB.DBA.TUT_CATEGORY_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_SHIPPER_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Shipper', cast(_id as varchar));
}
;

create function DB.DBA.TUT_SHIPPER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_SUPPLIER_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Supplier', cast(_id as varchar));
}
;

create function DB.DBA.TUT_SUPPLIER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_PRODUCT_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Product', cast(_id as varchar));
}
;

create function DB.DBA.TUT_PRODUCT_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_CUSTOMER_IRI (in _id varchar) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Customer', _id);
}
;

create function DB.DBA.TUT_CUSTOMER_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.TUT_EMPLOYEE_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Employee', cast(_id as varchar));
}
;

create function DB.DBA.TUT_EMPLOYEE_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_ORDER_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Order', cast(_id as varchar));
}
;

create function DB.DBA.TUT_ORDER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_CUSTOMERCONTACT_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('CustomerContact', cast(_id as varchar));
}
;

create function DB.DBA.TUT_CUSTOMERCONTACT_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_ORDERLINE_IRI (in _id1 integer, in _id2 integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('OrderLine', sprintf('%d/%d', _id1, _id2));
}
;

create function DB.DBA.TUT_ORDERLINE_IRI_INV_1 (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_ORDERLINE_IRI_INV_2 (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};


create function DB.DBA.TUT_PROVINCE_IRI (in _id1 varchar, in _id2 varchar) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Province', sprintf('%s/%s', _id1, _id2));
}
;

create function DB.DBA.TUT_PROVINCE_IRI_INV_1 (in _iri varchar) returns varchar
{
    return DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.TUT_PROVINCE_IRI_INV_2 (in _iri varchar) returns varchar
{
    return DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.TUT_COUNTRY_IRI (in _id varchar) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Country', _id);
}
;

create function DB.DBA.TUT_COUNTRY_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.TUT_FLAG_IRI (in _id varchar) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('Flag', _id);
}
;

create function DB.DBA.TUT_FLAG_IRI_INVERSE (in _iri varchar) returns varchar
{
    return DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri);
};

create function DB.DBA.TUT_EMPLOYEEPHOTO_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('EmployeePhoto', cast(_id as varchar));
}
;

create function DB.DBA.TUT_EMPLOYEEPHOTO_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

create function DB.DBA.TUT_CATEGORYPHOTO_IRI (in _id integer) returns varchar
{
    return TUT_NORTHWIND_ID_TO_IRI('CategoryPhoto', cast(_id as varchar));
}
;

create function DB.DBA.TUT_CATEGORYPHOTO_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_NORTHWIND_IRI_TO_ID(_iri));
};

grant execute on DB.DBA.TUT_CATEGORY_IRI to "SPARQL";
grant execute on DB.DBA.TUT_CATEGORY_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_SHIPPER_IRI to "SPARQL";
grant execute on DB.DBA.TUT_SHIPPER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_SUPPLIER_IRI to "SPARQL";
grant execute on DB.DBA.TUT_SUPPLIER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_PRODUCT_IRI to "SPARQL";
grant execute on DB.DBA.TUT_PRODUCT_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_CUSTOMER_IRI to "SPARQL";
grant execute on DB.DBA.TUT_CUSTOMER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_EMPLOYEE_IRI to "SPARQL";
grant execute on DB.DBA.TUT_EMPLOYEE_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_ORDER_IRI to "SPARQL";
grant execute on DB.DBA.TUT_ORDER_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_CUSTOMERCONTACT_IRI to "SPARQL";
grant execute on DB.DBA.TUT_CUSTOMERCONTACT_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_ORDERLINE_IRI to "SPARQL";
grant execute on DB.DBA.TUT_ORDERLINE_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.TUT_ORDERLINE_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.TUT_PROVINCE_IRI to "SPARQL";
grant execute on DB.DBA.TUT_PROVINCE_IRI_INV_1 to "SPARQL";
grant execute on DB.DBA.TUT_PROVINCE_IRI_INV_2 to "SPARQL";
grant execute on DB.DBA.TUT_COUNTRY_IRI to "SPARQL";
grant execute on DB.DBA.TUT_COUNTRY_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_FLAG_IRI to "SPARQL";
grant execute on DB.DBA.TUT_FLAG_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_EMPLOYEEPHOTO_IRI to "SPARQL";
grant execute on DB.DBA.TUT_EMPLOYEEPHOTO_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.TUT_CATEGORYPHOTO_IRI to "SPARQL";
grant execute on DB.DBA.TUT_CATEGORYPHOTO_IRI_INVERSE to "SPARQL";

SPARQL
prefix tut_northwind: <http://demo.openlinksw.com/schemas/tutorial/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tut_northwind:Category "http://^{URIQADefaultHost}^/tutorial/Northwind/Category/%d#this" (in category_id integer not null) .
create iri class tut_northwind:Shipper "http://^{URIQADefaultHost}^/tutorial/Northwind/Shipper/%d#this" (in shipper_id integer not null) .
create iri class tut_northwind:Supplier "http://^{URIQADefaultHost}^/tutorial/Northwind/Supplier/%d#this" (in supplier_id integer not null) .
create iri class tut_northwind:Product   "http://^{URIQADefaultHost}^/tutorial/Northwind/Product/%d#this" (in product_id integer not null) .
create iri class tut_northwind:Customer "http://^{URIQADefaultHost}^/tutorial/Northwind/Customer/%U#this" (in customer_id varchar not null) .
create iri class tut_northwind:Employee "http://^{URIQADefaultHost}^/tutorial/Northwind/Employee/%U%U%d#this" (in employee_firstname varchar not null, in employee_lastname varchar not null, in employee_id integer not null) .
create iri class tut_northwind:Order "http://^{URIQADefaultHost}^/tutorial/Northwind/Order/%d#this" (in order_id integer not null) .
create iri class tut_northwind:CustomerContact "http://^{URIQADefaultHost}^/tutorial/Northwind/CustomerContact/%U#this" (in customer_id varchar not null) .
create iri class tut_northwind:OrderLine "http://^{URIQADefaultHost}^/tutorial/Northwind/OrderLine/%d/%d#this" (in order_id integer not null, in product_id integer not null) .
create iri class tut_northwind:Province "http://^{URIQADefaultHost}^/tutorial/Northwind/Province/%U/%U#this" (in country_name varchar not null, in province_name varchar not null) .
create iri class tut_northwind:Country "http://^{URIQADefaultHost}^/tutorial/Northwind/Country/%U#this" (in country_name varchar not null) .
create iri class tut_northwind:Flag "http://^{URIQADefaultHost}^%U#this" (in flag_path varchar not null) .
create iri class tut_northwind:dbpedia_iri "http://dbpedia.org/resource/%U" (in uname varchar not null) .
create iri class tut_northwind:EmployeePhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/EMP%d#this" (in emp_id varchar not null) .
create iri class tut_northwind:CategoryPhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/CAT%d#this" (in category_id varchar not null) .
;

SPARQL
prefix tut_northwind: <http://demo.openlinksw.com/schemas/tutorial/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
create iri class tut_northwind:customercontact_iri using
    function DB.DBA.TUT_CUSTOMERCONTACT_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.TUT_CUSTOMERCONTACT_IRI_INVERSE (in customer_iri varchar) returns varchar.
create iri class tut_northwind:category_iri using
    function DB.DBA.TUT_CATEGORY_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_CATEGORY_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:shipper_iri using
    function DB.DBA.TUT_SHIPPER_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_SHIPPER_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:supplier_iri using
    function DB.DBA.TUT_SUPPLIER_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.TUT_SUPPLIER_IRI_INVERSE (in customer_iri varchar) returns varchar.
create iri class tut_northwind:product_iri using
    function DB.DBA.TUT_PRODUCT_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_PRODUCT_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:customer_iri using
    function DB.DBA.TUT_CUSTOMER_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.TUT_CUSTOMER_IRI_INVERSE (in customer_iri varchar) returns varchar.
create iri class tut_northwind:employee_iri using
    function DB.DBA.TUT_EMPLOYEE_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_EMPLOYEE_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:order_iri using
    function DB.DBA.TUT_ORDER_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_ORDER_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:orderline_iri using
    function DB.DBA.TUT_ORDERLINE_IRI (in customer_id integer, in customer_id2 integer) returns varchar,
    function DB.DBA.TUT_ORDERLINE_IRI_INV_1 (in customer_iri varchar) returns integer,
    function DB.DBA.TUT_ORDERLINE_IRI_INV_2 (in customer_iri varchar) returns integer.
create iri class tut_northwind:province_iri using
    function DB.DBA.TUT_PROVINCE_IRI (in customer_id varchar, in customer_id2 varchar) returns varchar,
    function DB.DBA.TUT_PROVINCE_IRI_INV_1 (in customer_iri varchar) returns varchar,
    function DB.DBA.TUT_PROVINCE_IRI_INV_2 (in customer_iri varchar) returns varchar.
create iri class tut_northwind:country_iri using
    function DB.DBA.TUT_COUNTRY_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.TUT_COUNTRY_IRI_INVERSE (in customer_iri varchar) returns varchar.
create iri class tut_northwind:employeephoto_iri using
    function DB.DBA.TUT_EMPLOYEEPHOTO_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_EMPLOYEEPHOTO_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:categoryphoto_iri using
    function DB.DBA.TUT_CATEGORYPHOTO_IRI (in customer_id integer) returns varchar,
    function DB.DBA.TUT_CATEGORYPHOTO_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tut_northwind:flag_iri using
    function DB.DBA.TUT_FLAG_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.TUT_FLAG_IRI_INVERSE (in customer_iri varchar) returns varchar.
;

SPARQL
prefix tut_northwind: <http://demo.openlinksw.com/schemas/tutorial/northwind#>
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
        create virtrdf:TutorialNorthwindDemo as graph iri ("http://^{URIQADefaultHost}^/tutorial/Northwind") option (exclusive)
        {
                tut_northwind:CustomerContact (customers.CustomerID)
                        a foaf:Person
                                as virtrdf:tutCustomerContact-foaf_Person .
                tut_northwind:CustomerContact (customers.CustomerID)
                        a tut_northwind:CustomerContact
                                as virtrdf:tutCustomerContact-CustomerContact;
                        foaf:name customers.ContactName
                                as virtrdf:tutCustomerContact-contact_name ;
                        foaf:phone customers.Phone
                                as virtrdf:tutCustomerContact-foaf_phone ;
                        tut_northwind:is_contact_at tut_northwind:Customer (customers.CustomerID)
                                as virtrdf:tutCustomerContact-is_contact_at ;
                        tut_northwind:country tut_northwind:Country (customers.Country)
                                as virtrdf:tutCustomerContact-country ;
                        rdfs:isDefinedBy tut_northwind:customercontact_iri (customers.CustomerID) ;
                        rdfs:isDefinedBy tut_northwind:CustomerContact (customers.CustomerID) .

                tut_northwind:Country (customers.Country)
                        tut_northwind:is_country_of
                tut_northwind:CustomerContact (customers.CustomerID) as virtrdf:tutCustomerContact-is_country_of .
                tut_northwind:Product (products.ProductID)
                        a tut_northwind:Product
                                as virtrdf:tutProduct-ProductID ;
                        tut_northwind:has_category tut_northwind:Category (products.CategoryID)
                                as virtrdf:tutProduct-product_has_category ;
                        tut_northwind:has_supplier tut_northwind:Supplier (products.SupplierID)
                                as virtrdf:tutProduct-product_has_supplier ;
                        tut_northwind:productName products.ProductName
                                as virtrdf:tutProduct-name_of_product ;
                        tut_northwind:quantityPerUnit products.QuantityPerUnit
                                as virtrdf:tutProduct-quantity_per_unit ;
                        tut_northwind:unitPrice products.UnitPrice
                                as virtrdf:tutProduct-unit_price ;
                        tut_northwind:unitsInStock products.UnitsInStock
                                as virtrdf:tutProduct-units_in_stock ;
                        tut_northwind:unitsOnOrder products.UnitsOnOrder
                                as virtrdf:tutProduct-units_on_order ;
                        tut_northwind:reorderLevel products.ReorderLevel
                                as virtrdf:tutProduct-reorder_level ;
                        tut_northwind:discontinued products.Discontinued
                                as virtrdf:tutProduct-discontinued ;
                        rdfs:isDefinedBy tut_northwind:product_iri (products.ProductID) ;
                        rdfs:isDefinedBy tut_northwind:Product (products.ProductID).

                tut_northwind:Category (products.CategoryID)
                        tut_northwind:category_of tut_northwind:Product (products.ProductID) as virtrdf:tutProduct-category_of .

                tut_northwind:Supplier (products.SupplierID)
                        tut_northwind:supplier_of tut_northwind:Product (products.ProductID) as virtrdf:tutProduct-supplier_of .

                tut_northwind:Supplier (suppliers.SupplierID)
                        a tut_northwind:Supplier
                                as virtrdf:tutSupplier-SupplierID ;
                        tut_northwind:companyName suppliers.CompanyName
                                as virtrdf:tutSupplier-company_name ;
                        tut_northwind:contactName suppliers.ContactName
                                as virtrdf:tutSupplier-contact_name ;
                        tut_northwind:contactTitle suppliers.ContactTitle
                                as virtrdf:tutSupplier-contact_title ;
                        tut_northwind:address suppliers.Address
                                as virtrdf:tutSupplier-address ;
                        tut_northwind:city suppliers.City
                                as virtrdf:tutSupplier-city ;
                        tut_northwind:dbpedia_city tut_northwind:dbpedia_iri(suppliers.City)
                                as virtrdf:tutSupplier-dbpedia_city ;
                        tut_northwind:region suppliers.Region
                                as virtrdf:tutSupplier-region ;
                        tut_northwind:postalCode suppliers.PostalCode
                                as virtrdf:tutSupplier-postal_code ;
                        tut_northwind:country tut_northwind:Country(suppliers.Country)
                                as virtrdf:tutSupplier-country ;
                        tut_northwind:phone suppliers.Phone
                                as virtrdf:tutSupplier-phone ;
                        tut_northwind:fax suppliers.Fax
                                as virtrdf:tutSupplier-fax ;
                        tut_northwind:homePage suppliers.HomePage
                                as virtrdf:tutSupplier-home_page ;
                        rdfs:isDefinedBy tut_northwind:supplier_iri (suppliers.SupplierID) ;
                        rdfs:isDefinedBy tut_northwind:Supplier (suppliers.SupplierID).

                tut_northwind:Country (suppliers.Country)
                        tut_northwind:is_country_of
                tut_northwind:Supplier (suppliers.SupplierID) as virtrdf:tutSupplier-is_country_of .
                tut_northwind:Category (categories.CategoryID)
                        a tut_northwind:Category
                                as virtrdf:tutCategory-CategoryID ;
                        tut_northwind:categoryName categories.CategoryName
                                as virtrdf:tutCategory-home_page ;
                        tut_northwind:description categories.Description
                                as virtrdf:tutCategory-description ;
                        foaf:img tut_northwind:CategoryPhoto(categories.CategoryID)
                                as virtrdf:tutCategory-categories.CategoryPhoto ;
                        rdfs:isDefinedBy tut_northwind:category_iri (categories.CategoryID) ;
                        rdfs:isDefinedBy tut_northwind:Category (categories.CategoryID).
								
				tut_northwind:CategoryPhoto(categories.CategoryID)
						a tut_northwind:CategoryPhoto
                                as virtrdf:tutCategory-categories.CategoryPhotoID ;
                        rdfs:isDefinedBy tut_northwind:categoryphoto_iri (categories.CategoryID) ;
                        rdfs:isDefinedBy tut_northwind:CategoryPhoto(categories.CategoryID).

                tut_northwind:Shipper (shippers.ShipperID)
                        a tut_northwind:Shipper
                                as virtrdf:tutShipper-ShipperID ;
                        tut_northwind:companyName shippers.CompanyName
                                as virtrdf:tutShipper-company_name ;
                        tut_northwind:phone shippers.Phone
                                as virtrdf:tutShipper-phone ;
                        rdfs:isDefinedBy tut_northwind:shipper_iri (shippers.ShipperID) ;
                        rdfs:isDefinedBy tut_northwind:Shipper (shippers.ShipperID).

                tut_northwind:Customer (customers.CustomerID)
                        a  tut_northwind:Customer
                                as virtrdf:tutCustomer-CustomerID2 ;
                        a  foaf:Organization
                                as virtrdf:tutCustomer-CustomerID ;
                        foaf:name customers.CompanyName
                                as virtrdf:tutCustomer-foaf_name ;
                        tut_northwind:companyName customers.CompanyName
                                as virtrdf:tutCustomer-company_name ;
                        tut_northwind:has_contact tut_northwind:CustomerContact (customers.CustomerID)
                                as virtrdf:tutCustomer-contact ;
                        tut_northwind:country tut_northwind:Country (customers.Country)
                                as virtrdf:tutCustomer-country ;
                        tut_northwind:contactName customers.ContactName
                                as virtrdf:tutCustomer-contact_name ;
                        tut_northwind:contactTitle customers.ContactTitle
                                as virtrdf:tutCustomer-contact_title ;
                        tut_northwind:address customers.Address
                                as virtrdf:tutCustomer-address ;
                        tut_northwind:city customers.City
                                as virtrdf:tutCustomer-city ;
                        tut_northwind:dbpedia_city tut_northwind:dbpedia_iri(customers.City)
                                as virtrdf:tutCustomer-dbpedia_city ;
                        tut_northwind:region customers.Region
                                as virtrdf:tutCustomer-region ;
                        tut_northwind:PostalCode customers.PostalCode
                                as virtrdf:tutCustomer-postal_code ;
                        foaf:phone customers.Phone
                                as virtrdf:tutCustomer-foaf_phone ;
                        tut_northwind:phone customers.Phone
                                as virtrdf:tutCustomer-phone ;
                        tut_northwind:fax customers.Fax
                                as virtrdf:tutCustomer-fax ;
                        rdfs:isDefinedBy tut_northwind:customer_iri (customers.CustomerID) ;
                        rdfs:isDefinedBy tut_northwind:Customer (customers.CustomerID).

                tut_northwind:Country (customers.Country)
                        tut_northwind:is_country_of
                tut_northwind:Customer (customers.CustomerID) as virtrdf:tutCustomer-is_country_of .

                tut_northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID)
                        a tut_northwind:Employee
                                as virtrdf:tutEmployee-EmployeeID2 ;
                        a foaf:Person
                                as virtrdf:tutEmployee-EmployeeID ;
                        foaf:surname employees.LastName
                                as virtrdf:tutEmployee-foaf_last_name ;
                        tut_northwind:lastName employees.LastName
                                as virtrdf:tutEmployee-last_name ;
                        foaf:firstName employees.FirstName
                                as virtrdf:tutEmployee-foaf_first_name ;
                        tut_northwind:firstName employees.FirstName
                                as virtrdf:tutEmployee-first_name ;
                        foaf:title employees.Title
                                as virtrdf:tutEmployee-title ;
                        tut_northwind:titleOfCourtesy employees.TitleOfCourtesy
                                as virtrdf:tutEmployee-title_of_courtesy ;
                        foaf:birthday employees.BirthDate
                                as virtrdf:tutEmployee-foaf_birth_date ;
                        tut_northwind:birthday employees.BirthDate
                                as virtrdf:tutEmployee-birth_date ;
                        tut_northwind:hireDate employees.HireDate
                                as virtrdf:tutEmployee-hire_date ;
                        tut_northwind:address employees.Address
                                as virtrdf:tutEmployee-address ;
                        tut_northwind:city employees.City
                                as virtrdf:tutEmployee-city ;
                        tut_northwind:dbpedia_city tut_northwind:dbpedia_iri(employees.City)
                                as virtrdf:tutEmployee-dbpedia_city ;
                        tut_northwind:region employees.Region
                                as virtrdf:tutEmployee-region ;
                        tut_northwind:postalCode employees.PostalCode
                                as virtrdf:tutEmployee-postal_code ;
                        tut_northwind:country tut_northwind:Country (employees.Country)
                                as virtrdf:tutEmployee-country ;
                        foaf:phone employees.HomePhone
                                as virtrdf:tutEmployee-home_phone ;
                        tut_northwind:extension employees.Extension
                                as virtrdf:tutEmployee-extension ;
                        tut_northwind:notes employees.Notes
                                as virtrdf:tutEmployee-notes ;
                        tut_northwind:reportsTo tut_northwind:Employee(employees.FirstName, employees.LastName, employees.ReportsTo) where (^{employees.}^.ReportsTo = ^{employees.}^.EmployeeID)
                                as virtrdf:tutEmployee-reports_to ;
                        foaf:img tut_northwind:EmployeePhoto(employees.EmployeeID)
                                as virtrdf:tutEmployee-employees.EmployeePhoto ;
                        rdfs:isDefinedBy tut_northwind:employee_iri (employees.EmployeeID) ;
                        rdfs:isDefinedBy tut_northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID).

				tut_northwind:EmployeePhoto(employees.EmployeeID)
						a tut_northwind:EmployeePhoto
                                as virtrdf:tut_Employee-employees.EmployeePhotoId ;
                        rdfs:isDefinedBy tut_northwind:employeephoto_iri (employees.EmployeeID) ;
                        rdfs:isDefinedBy tut_northwind:EmployeePhoto (employees.EmployeeID).

                tut_northwind:Employee (employees.FirstName, employees.LastName, orders.EmployeeID)
                        tut_northwind:is_salesrep_of
                tut_northwind:Order (orders.OrderID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID) as virtrdf:tutOrder-is_salesrep_of .

                tut_northwind:Country (employees.Country)
                        tut_northwind:is_country_of
                tut_northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID) as virtrdf:tutEmployee-is_country_of .

                tut_northwind:Order (orders.OrderID)
                        a tut_northwind:Order
                                as virtrdf:tutOrder-Order ;
                        tut_northwind:has_customer tut_northwind:Customer (orders.CustomerID)
                                as virtrdf:tutOrder-order_has_customer ;
                        tut_northwind:has_salesrep tut_northwind:Employee (employees.FirstName, employees.LastName, orders.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as virtrdf:tutCustomer-has_salesrep ;
                        tut_northwind:has_employee tut_northwind:Employee (employees.FirstName, employees.LastName, orders.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as virtrdf:tutOrder-order_has_employee ;
                        tut_northwind:orderDate orders.OrderDate
                                as virtrdf:tutOrder-order_date ;
                        tut_northwind:requiredDate orders.RequiredDate
                                as virtrdf:tutOrder-required_date ;
                        tut_northwind:shippedDate orders.ShippedDate
                                as virtrdf:tutOrder-shipped_date ;
                        tut_northwind:order_ship_via tut_northwind:Shipper (orders.ShipVia)
                                as virtrdf:tutOrder-order_ship_via ;
                        tut_northwind:freight orders.Freight
                                as virtrdf:tutOrder-freight ;
                        tut_northwind:shipName orders.ShipName
                                as virtrdf:tutOrder-ship_name ;
                        tut_northwind:shipAddress orders.ShipAddress
                                as virtrdf:tutOrder-ship_address ;
                        tut_northwind:shipCity orders.ShipCity
                                as virtrdf:tutOrder-ship_city ;
                        tut_northwind:dbpedia_shipCity tut_northwind:dbpedia_iri(orders.ShipCity)
                                as virtrdf:tutOrder-ship_dbpedia_city ;
                        tut_northwind:shipRegion orders.ShipRegion
                                as virtrdf:tutOrder-ship_region ;
                        tut_northwind:shipPostal_code orders.ShipPostalCode
                                as virtrdf:tutOrder-ship_postal_code ;
                        tut_northwind:shipCountry tut_northwind:Country(orders.ShipCountry)
                                as virtrdf:tutship_country ;
                        rdfs:isDefinedBy tut_northwind:order_iri (orders.OrderID) ;
                        rdfs:isDefinedBy tut_northwind:Order (orders.OrderID).

                tut_northwind:Country (orders.ShipCountry)
                        tut_northwind:is_ship_country_of
                tut_northwind:Order (orders.OrderID) as virtrdf:tutOrder-is_country_of .

                tut_northwind:Customer (orders.CustomerID)
                        tut_northwind:has_order tut_northwind:Order (orders.OrderID) as virtrdf:tutOrder-has_order .
                
                tut_northwind:Shipper (orders.ShipVia)
                        tut_northwind:ship_order tut_northwind:Order (orders.OrderID) as virtrdf:tutOrder-ship_order .
                
                tut_northwind:OrderLine (order_lines.OrderID, order_lines.ProductID)
                        a tut_northwind:OrderLine
                                as virtrdf:tutOrderLine-OrderLines ;
                        tut_northwind:has_order_id tut_northwind:Order (order_lines.OrderID)
                                as virtrdf:tutorder_lines_has_order_id ;
                        tut_northwind:has_product_id tut_northwind:Product (order_lines.ProductID)
                                as virtrdf:tutorder_lines_has_product_id ;
                        tut_northwind:unitPrice order_lines.UnitPrice
                                as virtrdf:tutOrderLine-unit_price ;
                        tut_northwind:quantity order_lines.Quantity
                                as virtrdf:tutOrderLine-quantity ;
                        tut_northwind:discount order_lines.Discount
                                as virtrdf:tutOrderLine-discount ;
                        rdfs:isDefinedBy tut_northwind:orderline_iri (order_lines.OrderID, order_lines.ProductID) ;
                        rdfs:isDefinedBy tut_northwind:OrderLine (order_lines.OrderID, order_lines.ProductID).
                
                tut_northwind:Order (orders.OrderID)
                        tut_northwind:is_order_of
                tut_northwind:OrderLine (order_lines.OrderID, order_lines.ProductID) where (^{orders.}^.OrderID = ^{order_lines.}^.OrderID) as virtrdf:tutOrder-is_order_of .

                tut_northwind:Product (products.ProductID)
                        tut_northwind:is_product_of
                tut_northwind:OrderLine (order_lines.OrderID, order_lines.ProductID) where (^{products.}^.ProductID = ^{order_lines.}^.ProductID) as virtrdf:tutProduct-is_product_of .

                tut_northwind:Country (countries.Name)
                        a tut_northwind:Country
                                as virtrdf:tutCountry-Type2 ;
                        a wgs:SpatialThing
                                as virtrdf:tutCountry-Type ;
                        owl:sameAs tut_northwind:dbpedia_iri (countries.Name) ;
                        tut_northwind:name countries.Name
                                as virtrdf:tutCountry-Name ;
                        tut_northwind:code countries.Code
                                as virtrdf:tutCountry-Code ;
                        tut_northwind:smallFlagDAVResourceName countries.SmallFlagDAVResourceName
                                as virtrdf:tutCountry-SmallFlagDAVResourceName ;
                        tut_northwind:largeFlagDAVResourceName countries.LargeFlagDAVResourceName
                                as virtrdf:tutCountry-LargeFlagDAVResourceName ;
                        tut_northwind:smallFlagDAVResourceURI tut_northwind:Flag(countries.SmallFlagDAVResourceURI)
                                as virtrdf:tutCountry-SmallFlagDAVResourceURI ;
                        tut_northwind:largeFlagDAVResourceURI tut_northwind:Flag(countries.LargeFlagDAVResourceURI)
                                as virtrdf:tutCountry-LargeFlagDAVResourceURI ;
                        wgs:lat countries.Lat
                                as virtrdf:tutCountry-Lat ;
                        wgs:long countries.Lng
                                as virtrdf:tutCountry-Lng ;
                        rdfs:isDefinedBy tut_northwind:country_iri (countries.Name) ;
                        rdfs:isDefinedBy tut_northwind:Country (countries.Name).

                tut_northwind:Country (countries.Name)
                        tut_northwind:has_province
                tut_northwind:Province (provinces.CountryCode, provinces.Province) where (^{provinces.}^.CountryCode = ^{countries.}^.Code) as virtrdf:tutCountry-has_province .

                tut_northwind:Province (provinces.CountryCode, provinces.Province)
                        a tut_northwind:Province
                                as virtrdf:tutProvince-Provinces ;
                        tut_northwind:has_country_code provinces.CountryCode
                                as virtrdf:tuthas_country_code ;
                        tut_northwind:provinceName provinces.Province
                                as virtrdf:tutProvince-ProvinceName ;
                        rdfs:isDefinedBy tut_northwind:province_iri (provinces.CountryCode, provinces.Province) ;
                        rdfs:isDefinedBy tut_northwind:Province (provinces.CountryCode, provinces.Province).

                tut_northwind:Province (provinces.CountryCode, provinces.Province)
                        tut_northwind:is_province_of
                tut_northwind:Country (countries.Name) where  (^{countries.}^.Code = ^{provinces.}^.CountryCode) as virtrdf:tutProvince-country_of .
        } .
} .
;

delete from db.dba.url_rewrite_rule_list where urrl_list like 'tut_nw%';
delete from db.dba.url_rewrite_rule where urr_rule like 'tut_nw%';

create procedure DB.DBA.install_run ()
{
        declare file_text, uriqa varchar;
        uriqa := registry_get('URIQADefaultHost');
        file_text := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.isparql');
        file_text := replace(file_text, 'URIQA_MACRO', concat('http://', uriqa, '/tutorial/Northwind'));
        update WS.WS.SYS_DAV_RES set RES_CONTENT=file_text where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.isparql';
}
;

DB.DBA.install_run()
;

drop procedure DB.DBA.install_run
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tut_nw_rule2',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/tutorial/Northwind%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tut_nw_rule1',
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
    'tut_nw_rule3',
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

create procedure DB.DBA.REMOVE_TUT_DEMO_RDF_DET()
{
  declare colid int;
  colid := DAV_SEARCH_ID('/DAV/VAD/tutorial/rdfview/rd_v_1/', 'C');
  if (colid < 0)
    return;
  update WS.WS.SYS_DAV_COL set COL_DET=null where COL_ID = colid;
}
;

DB.DBA.REMOVE_TUT_DEMO_RDF_DET();

drop procedure DB.DBA.REMOVE_TUT_DEMO_RDF_DET;

create procedure DB.DBA.TUT_NORTHWIND_MAKE_RDF_DET()
{
    declare uriqa_str varchar;
    uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    uriqa_str := 'http://' || uriqa_str || '/tutorial/Northwind';
    DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/VAD/tutorial/rdfview/rd_v_1/RDFData/', uriqa_str, NULL);
    VHOST_REMOVE (lpath=>'/tutorial/Northwind/data/rdf');
    DB.DBA.VHOST_DEFINE (lpath=>'/tutorial/Northwind/data/rdf', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/RDFData/All/', is_dav=>1, vsp_user=>'dba');
}
;

DB.DBA.TUT_NORTHWIND_MAKE_RDF_DET();

drop procedure DB.DBA.TUT_NORTHWIND_MAKE_RDF_DET;

-- procedure to convert path to DET resource name
create procedure DB.DBA.TUT_NORTHWIND_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  uriqa_str := 'http://' || uriqa_str || '/tutorial/Northwind';
  iri := uriqa_str || val;
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('tut_nw_rdf', 1,
    '/tutorial/Northwind/(.*)', vector('path'), 1, 
    '/tutorial/Northwind/data/rdf/%U', vector('path'),
    'DB.DBA.TUT_NORTHWIND_DET_REF',
    'application/rdf.xml',
    2,  
    303);


DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tut_nw_rule_list1',
    1,
    vector (
                'tut_nw_rule1',
                'tut_nw_rule2',
                'tut_nw_rule3',
                'tut_nw_rdf'
          ));


VHOST_REMOVE (lpath=>'/tutorial/Northwind');
DB.DBA.VHOST_DEFINE (lpath=>'/tutorial/Northwind', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/', vsp_user=>'dba', is_dav=>1, def_page=>'sfront.vspx',
          is_brws=>0, opts=>vector ('url_rewrite', 'tut_nw_rule_list1'));

create procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV()
{
  declare content, urihost varchar;
  whenever not found goto endpoint;
  select cast (RES_CONTENT as varchar) into content from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl';
  if (content is null or content = '')
    goto endpoint;
  DB.DBA.RDF_LOAD_RDFXML (content, 'http://demo.openlinksw.com/schemas/tutorial/northwind#', 'http://demo.openlinksw.com/schemas/TutorialNorthwindOntology/1.0/');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial/northwind#');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial/northwind#', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial/northwind');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial/northwind', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
  endpoint:
  ;
}
;

DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV()
;

drop procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV
;

create procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV2()
{
  declare urihost varchar;
  sparql base <http://demo.openlinksw.com/schemas/tutorial/northwind#> load bif:concat ("http://", bif:registry_get("URIQADefaultHost"), "/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl")
   into graph <http://demo.openlinksw.com/schemas/TutorialNorthwindOntology/1.0/>;
  urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/tutorial/northwind#');
    DB.DBA.VHOST_DEFINE (lpath=>'/tutorial/northwind#', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
}
;

--DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV2();

drop procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV2
;
