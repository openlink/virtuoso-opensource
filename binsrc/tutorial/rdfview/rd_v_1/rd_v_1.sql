use DB;

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
  if (rowset is not null)
    {
      foreach (any r in rowset) do
        result (r[0] || ': ' || r[1]);
    }
}
;

DB.DBA.SPARQL_NW_RUN ('
drop quad map graph iri("http://^{URIQADefaultHost}^/tutorial/Northwind") .
')
;

DB.DBA.SPARQL_NW_RUN ('
drop quad map virtrdf:TutorialNorthwindDemo .
')
;

DB.DBA.SPARQL_NW_RUN ('
prefix tut_northwind: <http://www.openlinksw.com/schemas/tutorial/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
create iri class tut_northwind:Category "http://^{URIQADefaultHost}^/tutorial/Northwind/Category/%d#this" (in category_id integer not null) .
create iri class tut_northwind:Shipper "http://^{URIQADefaultHost}^/tutorial/Northwind/Shipper/%d#this" (in shipper_id integer not null) .
create iri class tut_northwind:Supplier "http://^{URIQADefaultHost}^/tutorial/Northwind/Supplier/%d#this" (in supplier_id integer not null) .
create iri class tut_northwind:Product   "http://^{URIQADefaultHost}^/tutorial/Northwind/Product/%d#this" (in product_id integer not null) .
create iri class tut_northwind:Customer "http://^{URIQADefaultHost}^/tutorial/Northwind/Customer/%U#this" (in customer_id varchar not null) .
create iri class tut_northwind:Employee "http://^{URIQADefaultHost}^/tutorial/Northwind/Employee/%d#this" (in employee_id integer not null) .
create iri class tut_northwind:Order "http://^{URIQADefaultHost}^/tutorial/Northwind/Order/%d#this" (in order_id integer not null) .
create iri class tut_northwind:CustomerContact "http://^{URIQADefaultHost}^/tutorial/Northwind/CustomerContact/%U#this" (in customer_id integer not null) .
create iri class tut_northwind:OrderLine "http://^{URIQADefaultHost}^/tutorial/Northwind/OrderLine/%d/%d#this" (in order_id integer not null, in product_id integer not null) .
create iri class tut_northwind:Province "http://^{URIQADefaultHost}^/tutorial/Northwind/Province/%U/%U#this" (in country_name varchar not null, in province_name varchar not null) .
create iri class tut_northwind:Country "http://^{URIQADefaultHost}^/tutorial/Northwind/Country/%U#this" (in country_name varchar not null) .
create iri class tut_northwind:Flag "http://^{URIQADefaultHost}^/DAV/sample_data/images/flags/%s#this" (in flag_path varchar not null) .
')
;

DB.DBA.SPARQL_NW_RUN ('
prefix tut_northwind: <http://www.openlinksw.com/schemas/tutorial/northwind#>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
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
                                as virtrdf:tutCustomerContact-country .
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
                                as virtrdf:tutProduct-discontinued .
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
                                as virtrdf:tutSupplier-home_page .
                tut_northwind:Country (suppliers.Country)
                        tut_northwind:is_country_of
                tut_northwind:Supplier (suppliers.SupplierID) as virtrdf:tutSupplier-is_country_of .
                tut_northwind:Category (categories.CategoryID)
                        a tut_northwind:Category
                                as virtrdf:tutCategory-CategoryID ;
                        tut_northwind:categoryName categories.CategoryName
                                as virtrdf:tutCategory-home_page ;
                        tut_northwind:description categories.Description
                                as virtrdf:tutCategory-description .
                tut_northwind:Shipper (shippers.ShipperID)
                        a tut_northwind:Shipper
                                as virtrdf:tutShipper-ShipperID ;
                        tut_northwind:companyName shippers.CompanyName
                                as virtrdf:tutShipper-company_name ;
                        tut_northwind:phone shippers.Phone
                                as virtrdf:tutShipper-phone .
                tut_northwind:Customer (customers.CustomerID)
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
                        tut_northwind:region customers.Region
                                as virtrdf:tutCustomer-region ;
                        tut_northwind:PostalCode customers.PostalCode
                                as virtrdf:tutCustomer-postal_code ;
                        foaf:phone customers.Phone
                                as virtrdf:tutCustomer-foaf_phone ;
                        tut_northwind:phone customers.Phone
                                as virtrdf:tutCustomer-phone ;
                        tut_northwind:fax customers.Fax
                                as virtrdf:tutCustomer-fax .
                tut_northwind:Country (customers.Country)
                        tut_northwind:is_country_of
                tut_northwind:Customer (customers.CustomerID) as virtrdf:tutCustomer-is_country_of .
                tut_northwind:Employee (employees.EmployeeID)
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
                        tut_northwind:reportsTo employees.ReportsTo
                                as virtrdf:tutEmployee-reports_to .
                tut_northwind:Employee (orders.EmployeeID)
                        tut_northwind:is_salesrep_of
                tut_northwind:Order (orders.OrderID) as virtrdf:tutOrder-is_salesrep_of .
                tut_northwind:Country (employees.Country)
                        tut_northwind:is_country_of
                tut_northwind:Employee (employees.EmployeeID) as virtrdf:tutEmployee-is_country_of .
                tut_northwind:Order (orders.OrderID)
                        a tut_northwind:Order
                                as virtrdf:tutOrder-Order ;
                        tut_northwind:has_customer tut_northwind:Customer (orders.CustomerID)
                                as virtrdf:tutOrder-order_has_customer ;
                        tut_northwind:has_salesrep tut_northwind:Employee (orders.EmployeeID)
                                as virtrdf:tutCustomer-has_salesrep ;
                        tut_northwind:has_employee tut_northwind:Employee (orders.EmployeeID)
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
                        tut_northwind:shipRegion orders.ShipRegion
                                as virtrdf:tutOrder-ship_region ;
                        tut_northwind:shipPostal_code orders.ShipPostalCode
                                as virtrdf:tutOrder-ship_postal_code ;
                        tut_northwind:shipCountry tut_northwind:Country(orders.ShipCountry)
                                as virtrdf:tutship_country .
                tut_northwind:Customer (orders.CustomerID)
                        tut_northwind:has_order tut_northwind:Order (orders.OrderID) as virtrdf:tutOrder-has_order .
                tut_northwind:Employee (orders.EmployeeID)
                        tut_northwind:placed_order tut_northwind:Order (orders.OrderID) as virtrdf:tutOrder-placed_order .
                
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
                                as virtrdf:tutOrderLine-discount .
                
                tut_northwind:Country (countries.Name)
                        a wgs:SpatialThing
                                as virtrdf:tutCountry-Type ;
                        tut_northwind:name countries.Name
                                as virtrdf:tutCountry-Name ;
                        tut_northwind:code countries.Code
                                as virtrdf:tutCountry-Code ;
                        tut_northwind:smallFlagDAVResourceName tut_northwind:Flag (countries.SmallFlagDAVResourceName)
                                as virtrdf:tutCountry-SmallFlagDAVResourceName ;
                        tut_northwind:largeFlagDAVResourceName tut_northwind:Flag (countries.LargeFlagDAVResourceName)
                                as virtrdf:tutCountry-LargeFlagDAVResourceName ;
                        tut_northwind:smallFlagDAVResourceURI countries.SmallFlagDAVResourceURI
                                as virtrdf:tutCountry-SmallFlagDAVResourceURI ;
                        tut_northwind:largeFlagDAVResourceURI countries.LargeFlagDAVResourceURI
                                as virtrdf:tutCountry-LargeFlagDAVResourceURI ;
                        wgs:lat countries.Lat
                                as virtrdf:tutCountry-Lat ;
                        wgs:long countries.Lng
                                as virtrdf:tutCountry-Lng .
                
                tut_northwind:Country (countries.Name)
                        tut_northwind:has_province
                tut_northwind:Province (provinces.CountryCode, provinces.Province) where (^{provinces.}^.CountryCode = ^{countries.}^.Code) as virtrdf:tutCountry-has_province .

                tut_northwind:Province (provinces.CountryCode, provinces.Province)
                        a tut_northwind:Province
                                as virtrdf:tutProvince-Provinces ;
                        tut_northwind:has_country_code tut_northwind:Country (provinces.CountryCode)
                                as virtrdf:tuthas_country_code ;
                        tut_northwind:provinceName provinces.Province
                                as virtrdf:tutProvince-ProvinceName .
                tut_northwind:Province (provinces.CountryCode, provinces.Province)
                        tut_northwind:is_province_of
                tut_northwind:Country (countries.Name) where  (^{countries.}^.Code = ^{provinces.}^.CountryCode) as virtrdf:tutProvince-country_of .
        }
}
')
;

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


create procedure tut_nw_rdf_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*\x24', path);
  return r||'#this';
};

create procedure tut_nw_html_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*#', path);
  return subseq (r, 0, length (r)-1);
};

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tut_nw_rule2',
    1,
    '(/[^#]*)\x24',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/tutorial/Northwind%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tut_nw_rule1',
    1,
    '(/[^#]*)\x24',
    vector('path'),
    1,
    '/isparql/execute.html?query=SELECT%%20%%3Fp%%20%%3Fo%%20FROM%%20%%3Chttp%%3A//^{URIQADefaultHost}^/tutorial/Northwind%%3E%%20WHERE%%20{%%20%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E%%20%%3Fp%%20%%3Fo%%20}&endpoint=/sparql',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tut_nw_rule_list1',
    1,
    vector (
                'tut_nw_rule1',
                'tut_nw_rule2'
          ));


VHOST_REMOVE (lpath=>'/tutorial/Northwind');
VHOST_DEFINE (lpath=>'/tutorial/Northwind', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/', is_dav=>1, vsp_user=>'dba', is_brws=>0, opts=>vector ('url_rewrite', 'tut_nw_rule_list1'));
