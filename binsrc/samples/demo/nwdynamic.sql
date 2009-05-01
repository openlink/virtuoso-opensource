use DB;

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


SPARQL
drop quad map graph iri("http://^{URIQADefaultHost}^/Northwind") .
;

SPARQL
drop quad map virtrdf:NorthwindDemo .
;

SPARQL
drop quad map virtrdf:NorthwindDynamicLocalDemo .
;

SPARQL
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
create iri class northwind:DLF-graph "^{DynamicLocalFormat}^/Northwind" () .
create iri class northwind:DLF-Category "^{DynamicLocalFormat}^/Northwind/Category/%d#this" (in category_id integer not null) .
create iri class northwind:DLF-Shipper "^{DynamicLocalFormat}^/Northwind/Shipper/%d#this" (in shipper_id integer not null) .
create iri class northwind:DLF-Supplier "^{DynamicLocalFormat}^/Northwind/Supplier/%d#this" (in supplier_id integer not null) .
create iri class northwind:DLF-Product   "^{DynamicLocalFormat}^/Northwind/Product/%d#this" (in product_id integer not null) .
create iri class northwind:DLF-Customer "^{DynamicLocalFormat}^/Northwind/Customer/%U#this" (in customer_id varchar not null) .
create iri class northwind:DLF-Employee
  "^{DynamicLocalFormat}^/Northwind/Employee/%U%U%d#this"
  (in employee_firstname varchar not null, in employee_lastname varchar not null, in employee_id integer not null) .
create iri class northwind:DLF-Order "^{DynamicLocalFormat}^/Northwind/Order/%d#this" (in order_id integer not null) .
create iri class northwind:DLF-CustomerContact
  "^{DynamicLocalFormat}^/Northwind/CustomerContact/%U#this"
  (in customer_id varchar not null) .
create iri class northwind:DLF-OrderLine "^{DynamicLocalFormat}^/Northwind/OrderLine/%d/%d#this"
  (in order_id integer not null, in product_id integer not null) .
create iri class northwind:DLF-Province "^{DynamicLocalFormat}^/Northwind/Province/%U/%U#this"
  (in country_name varchar not null, in province_name varchar not null) .
create iri class northwind:DLF-Country "^{DynamicLocalFormat}^/Northwind/Country/%U#this" (in country_name varchar not null) .
create iri class northwind:DLF-Flag "^{DynamicLocalFormat}^%U#this" (in flag_path varchar not null) .
create iri class northwind:dbpedia_iri "http://dbpedia.org/resource/%U" (in uname varchar not null) .
create iri class northwind:DLF-EmployeePhoto "^{DynamicLocalFormat}^/DAV/VAD/demo/sql/EMP%d#this" (in emp_id varchar not null) .
create iri class northwind:DLF-CategoryPhoto "^{DynamicLocalFormat}^/DAV/VAD/demo/sql/CAT%d#this" (in category_id varchar not null) .
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
from Demo.demo.Employees as employees2
from Demo.demo.Orders as orders
from Demo.demo.Order_Details as order_lines
from Demo.demo.Countries as countries
from Demo.demo.Provinces as provinces
where (^{suppliers.}^.Country = ^{countries.}^.Name)
where (^{customers.}^.Country = ^{countries.}^.Name)
where (^{employees.}^.Country = ^{countries.}^.Name)
where (^{orders.}^.ShipCountry = ^{countries.}^.Name)
{
        create virtrdf:NorthwindDynamicLocalDemo as graph northwind:DLF-graph() option (soft exclusive)
        {
                northwind:DLF-CustomerContact (customers.CustomerID)
                        a foaf:Person
                                as northwind:DLF-map-CustomerContact-foaf_Person .

                northwind:DLF-CustomerContact (customers.CustomerID)
                        a northwind:CustomerContact
                                as northwind:DLF-map-CustomerContact-CustomerContact;
                        foaf:name customers.ContactName
                                as northwind:DLF-map-CustomerContact-contact_name ;
                        foaf:phone customers.Phone
                                as northwind:DLF-map-CustomerContact-foaf_phone ;
                        northwind:is_contact_at northwind:DLF-Customer (customers.CustomerID)
                                as northwind:DLF-map-CustomerContact-is_contact_at ;
                        northwind:country northwind:DLF-Country (customers.Country)
                                as northwind:DLF-map-CustomerContact-country ;
                        rdfs:isDefinedBy northwind:DLF-CustomerContact (customers.CustomerID) .

                northwind:DLF-Country (customers.Country)
                        northwind:is_country_of
                northwind:DLF-CustomerContact (customers.CustomerID) as northwind:DLF-map-CustomerContact-is_country_of .

                northwind:DLF-Product (products.ProductID)
                        a northwind:Product
                                as northwind:DLF-map-Product-ProductID ;
                        northwind:has_category northwind:DLF-Category (products.CategoryID)
                                as northwind:DLF-map-Product-product_has_category ;
                        northwind:has_supplier northwind:DLF-Supplier (products.SupplierID)
                                as northwind:DLF-map-Product-product_has_supplier ;
                        northwind:productName products.ProductName
                                as northwind:DLF-map-Product-name_of_product ;
                        northwind:quantityPerUnit products.QuantityPerUnit
                                as northwind:DLF-map-Product-quantity_per_unit ;
                        northwind:unitPrice products.UnitPrice
                                as northwind:DLF-map-Product-unit_price ;
                        northwind:unitsInStock products.UnitsInStock
                                as northwind:DLF-map-Product-units_in_stock ;
                        northwind:unitsOnOrder products.UnitsOnOrder
                                as northwind:DLF-map-Product-units_on_order ;
                        northwind:reorderLevel products.ReorderLevel
                                as northwind:DLF-map-Product-reorder_level ;
                        northwind:discontinued products.Discontinued
                                as northwind:DLF-map-Product-discontinued ;
                        rdfs:isDefinedBy northwind:DLF-Product (products.ProductID) .

                northwind:DLF-Category (products.CategoryID)
                        northwind:category_of northwind:DLF-Product (products.ProductID) as northwind:DLF-map-Product-category_of .

                northwind:DLF-Supplier (products.SupplierID)
                        northwind:supplier_of northwind:DLF-Product (products.ProductID) as northwind:DLF-map-Product-supplier_of .

                northwind:DLF-Supplier (suppliers.SupplierID)
                        a northwind:Supplier
                                as northwind:DLF-map-Supplier-SupplierID ;
                        northwind:companyName suppliers.CompanyName
                                as northwind:DLF-map-Supplier-company_name ;
                        northwind:contactName suppliers.ContactName
                                as northwind:DLF-map-Supplier-contact_name ;
                        northwind:contactTitle suppliers.ContactTitle
                                as northwind:DLF-map-Supplier-contact_title ;
                        northwind:address suppliers.Address
                                as northwind:DLF-map-Supplier-address ;
                        northwind:city suppliers.City
                                as northwind:DLF-map-Supplier-city ;
                        northwind:dbpedia_city northwind:dbpedia_iri(suppliers.City)
                                as northwind:DLF-map-Supplier-dbpediacity ;
                        northwind:region suppliers.Region
                                as northwind:DLF-map-Supplier-region ;
                        northwind:postalCode suppliers.PostalCode
                                as northwind:DLF-map-Supplier-postal_code ;
                        northwind:country northwind:DLF-Country(suppliers.Country)
                                as northwind:DLF-map-Supplier-country ;
                        northwind:phone suppliers.Phone
                                as northwind:DLF-map-Supplier-phone ;
                        northwind:fax suppliers.Fax
                                as northwind:DLF-map-Supplier-fax ;
                        northwind:homePage suppliers.HomePage
                                as northwind:DLF-map-Supplier-home_page ;
                        rdfs:isDefinedBy northwind:DLF-Supplier (suppliers.SupplierID) .

                northwind:DLF-Country (suppliers.Country)
                        northwind:is_country_of
                northwind:DLF-Supplier (suppliers.SupplierID) as northwind:DLF-map-Supplier-is_country_of .

                northwind:DLF-Category (categories.CategoryID)
                        a northwind:Category
                                as northwind:DLF-map-Category-CategoryID ;
                        northwind:categoryName categories.CategoryName
                                as northwind:DLF-map-Category-home_page ;
                        northwind:description categories.Description
                                as northwind:DLF-map-Category-description ;
                        foaf:img northwind:DLF-CategoryPhoto(categories.CategoryID)
                                as northwind:DLF-map-Category-categories.CategoryPhoto ;
                        rdfs:isDefinedBy northwind:DLF-Category (categories.CategoryID) .

                northwind:DLF-CategoryPhoto(categories.CategoryID)
                        a northwind:CategoryPhoto
                                as northwind:DLF-map-Category-categories.CategoryPhotoID ;
                        rdfs:isDefinedBy northwind:DLF-CategoryPhoto(categories.CategoryID) .

                northwind:DLF-Shipper (shippers.ShipperID)
                        a northwind:Shipper
                                as northwind:DLF-map-Shipper-ShipperID ;
                        northwind:companyName shippers.CompanyName
                                as northwind:DLF-map-Shipper-company_name ;
                        northwind:phone shippers.Phone
                                as northwind:DLF-map-Shipper-phone ;
                        rdfs:isDefinedBy northwind:DLF-Shipper (shippers.ShipperID) .

                northwind:DLF-Customer (customers.CustomerID)
                        a  northwind:Customer
                                as northwind:DLF-map-Customer-CustomerID2 ;
                        a  foaf:Organization
                                as northwind:DLF-map-Customer-CustomerID ;
                        foaf:name customers.CompanyName
                                as northwind:DLF-map-Customer-foaf_name ;
                        northwind:companyName customers.CompanyName
                                as northwind:DLF-map-Customer-company_name ;
                        northwind:has_contact northwind:DLF-CustomerContact (customers.CustomerID)
                                as northwind:DLF-map-Customer-contact ;
                        northwind:country northwind:DLF-Country (customers.Country)
                                as northwind:DLF-map-Customer-country ;
                        northwind:contactName customers.ContactName
                                as northwind:DLF-map-Customer-contact_name ;
                        northwind:contactTitle customers.ContactTitle
                                as northwind:DLF-map-Customer-contact_title ;
                        northwind:address customers.Address
                                as northwind:DLF-map-Customer-address ;
                        northwind:city customers.City
                                as northwind:DLF-map-Customer-city ;
                        northwind:dbpedia_city northwind:dbpedia_iri(customers.City)
                                as northwind:DLF-map-Customer-dbpediacity ;
                        northwind:region customers.Region
                                as northwind:DLF-map-Customer-region ;
                        northwind:postalCode customers.PostalCode
                                as northwind:DLF-map-Customer-postal_code ;
                        foaf:phone customers.Phone
                                as northwind:DLF-map-Customer-foaf_phone ;
                        northwind:phone customers.Phone
                                as northwind:DLF-map-Customer-phone ;
                        northwind:fax customers.Fax
                                as northwind:DLF-map-Customer-fax ;
                        rdfs:isDefinedBy northwind:DLF-Customer (customers.CustomerID) .

                northwind:DLF-Country (customers.Country)
                        northwind:is_country_of
                northwind:DLF-Customer (customers.CustomerID) as northwind:DLF-map-Customer-is_country_of .

                northwind:DLF-Employee (employees.FirstName, employees.LastName, employees.EmployeeID)
                        a northwind:Employee
                                as northwind:DLF-map-Employee-EmployeeID2 ;
                        a foaf:Person
                                as northwind:DLF-map-Employee-EmployeeID ;
                        foaf:surname employees.LastName
                                as northwind:DLF-map-Employee-foaf_last_name ;
                        northwind:lastName employees.LastName
                                as northwind:DLF-map-Employee-last_name ;
                        foaf:firstName employees.FirstName
                                as northwind:DLF-map-Employee-foaf_first_name ;
                        northwind:firstName employees.FirstName
                                as northwind:DLF-map-Employee-first_name ;
                        foaf:title employees.Title
                                as northwind:DLF-map-Employee-title ;
                        northwind:titleOfCourtesy employees.TitleOfCourtesy
                                as northwind:DLF-map-Employee-title_of_courtesy ;
                        foaf:birthday employees.BirthDate
                                as northwind:DLF-map-Employee-foaf_birth_date ;
                        northwind:birthday employees.BirthDate
                                as northwind:DLF-map-Employee-birth_date ;
                        northwind:hireDate employees.HireDate
                                as northwind:DLF-map-Employee-hire_date ;
                        northwind:address employees.Address
                                as northwind:DLF-map-Employee-address ;
                        northwind:city employees.City
                                as northwind:DLF-map-Employee-city ;
                        northwind:dbpedia_city northwind:dbpedia_iri(employees.City)
                                as northwind:DLF-map-Employee-dbpediacity ;
                        northwind:region employees.Region
                                as northwind:DLF-map-Employee-region ;
                        northwind:postalCode employees.PostalCode
                                as northwind:DLF-map-Employee-postal_code ;
                        northwind:country northwind:DLF-Country(employees.Country)
                                as northwind:DLF-map-Employee-country ;
                        foaf:phone employees.HomePhone
                                as northwind:DLF-map-Employee-home_phone ;
                        northwind:extension employees.Extension
                                as northwind:DLF-map-Employee-extension ;
                        northwind:notes employees.Notes
                                as northwind:DLF-map-Employee-notes ;
                        northwind:employeeID employees.EmployeeID
                                as northwind:DLF-map-Employee-key ;
                        northwind:reportsTo northwind:DLF-Employee(employees2.FirstName, employees2.LastName, employees2.EmployeeID) where (^{employees.}^.ReportsTo = ^{employees2.}^.EmployeeID)
                                as northwind:DLF-map-Employee-reports_to ;
                        foaf:img northwind:DLF-EmployeePhoto(employees.EmployeeID)
                                as northwind:DLF-map-Employee-employees.EmployeePhoto ;
                        rdfs:isDefinedBy northwind:DLF-Employee (employees.FirstName, employees.LastName, employees.EmployeeID) .

                northwind:DLF-EmployeePhoto(employees.EmployeeID)
                        a northwind:EmployeePhoto
                                as northwind:DLF-map-Employee-employees.EmployeePhotoId ;
                        rdfs:isDefinedBy northwind:DLF-EmployeePhoto (employees.EmployeeID) .

                northwind:DLF-Employee (employees.FirstName, employees.LastName, employees.EmployeeID)
                        northwind:is_salesrep_of
                northwind:DLF-Order (orders.OrderID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID) as northwind:DLF-map-Order-is_salesrep_of .

                northwind:DLF-Country (employees.Country)
                        northwind:is_country_of
                northwind:DLF-Employee (employees.FirstName, employees.LastName, employees.EmployeeID) as northwind:DLF-map-Employee-is_country_of .

                northwind:DLF-Order (orders.OrderID)
                        a northwind:Order
                                as northwind:DLF-map-Order-Order ;
                        northwind:has_customer northwind:DLF-Customer (orders.CustomerID)
                                as northwind:DLF-map-Order-order_has_customer ;
                        northwind:has_salesrep northwind:DLF-Employee (employees.FirstName, employees.LastName, employees.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as northwind:DLF-map-Customer-has_salesrep ;
                        northwind:has_employee northwind:DLF-Employee (employees.FirstName, employees.LastName, employees.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as northwind:DLF-map-Order-order_has_employee ;
                        northwind:orderDate orders.OrderDate
                                as northwind:DLF-map-Order-order_date ;
                        northwind:requiredDate orders.RequiredDate
                                as northwind:DLF-map-Order-required_date ;
                        northwind:shippedDate orders.ShippedDate
                                as northwind:DLF-map-Order-shipped_date ;
                        northwind:order_ship_via northwind:DLF-Shipper (orders.ShipVia)
                                as northwind:DLF-map-Order-order_ship_via ;
                        northwind:freight orders.Freight
                                as northwind:DLF-map-Order-freight ;
                        northwind:shipName orders.ShipName
                                as northwind:DLF-map-Order-ship_name ;
                        northwind:shipAddress orders.ShipAddress
                                as northwind:DLF-map-Order-ship_address ;
                        northwind:shipCity orders.ShipCity
                                as northwind:DLF-map-Order-ship_city ;
                        northwind:dbpedia_shipCity northwind:dbpedia_iri(orders.ShipCity)
                                as northwind:DLF-map-Order-dbpediaship_city ;
                        northwind:shipRegion orders.ShipRegion
                                as northwind:DLF-map-Order-ship_region ;
                        northwind:shipPostal_code orders.ShipPostalCode
                                as northwind:DLF-map-Order-ship_postal_code ;
                        northwind:shipCountry northwind:DLF-Country(orders.ShipCountry)
                                as northwind:DLF-map-ship_country ;
                        rdfs:isDefinedBy northwind:DLF-Order (orders.OrderID) .

                northwind:DLF-Customer (orders.CustomerID)
                        northwind:has_order northwind:DLF-Order (orders.OrderID) as northwind:DLF-map-Order-has_order .

                northwind:DLF-Shipper (orders.ShipVia)
                        northwind:ship_order northwind:DLF-Order (orders.OrderID) as northwind:DLF-map-Order-ship_order .

                northwind:DLF-OrderLine (order_lines.OrderID, order_lines.ProductID)
                        a northwind:OrderLine
                                as northwind:DLF-map-OrderLine-OrderLines ;
                        northwind:has_order_id northwind:DLF-Order (order_lines.OrderID)
                                as northwind:DLF-map-order_lines_has_order_id ;
                        northwind:has_product_id northwind:DLF-Product (order_lines.ProductID)
                                as northwind:DLF-map-order_lines_has_product_id ;
                        northwind:unitPrice order_lines.UnitPrice
                                as northwind:DLF-map-OrderLine-unit_price ;
                        northwind:quantity order_lines.Quantity
                                as northwind:DLF-map-OrderLine-quantity ;
                        northwind:discount order_lines.Discount
                                as northwind:DLF-map-OrderLine-discount ;
                        rdfs:isDefinedBy northwind:DLF-OrderLine (order_lines.OrderID, order_lines.ProductID) .

                northwind:DLF-Country (countries.Name)
                        a northwind:Country
                                as northwind:DLF-map-Country-Type2 ;
                        a wgs:SpatialThing
                                as northwind:DLF-map-Country-Type ;
                        owl:sameAs northwind:dbpedia_iri (countries.Name) ;
                        northwind:name countries.Name
                                as northwind:DLF-map-Country-Name ;
                        northwind:code countries.Code
                                as northwind:DLF-map-Country-Code ;
                        northwind:smallFlagDAVResourceName countries.SmallFlagDAVResourceName
                                as northwind:DLF-map-Country-SmallFlagDAVResourceName ;
                        northwind:largeFlagDAVResourceName countries.LargeFlagDAVResourceName
                                as northwind:DLF-map-Country-LargeFlagDAVResourceName ;
                        northwind:smallFlagDAVResourceURI northwind:DLF-Flag(countries.SmallFlagDAVResourceURI)
                                as northwind:DLF-map-Country-SmallFlagDAVResourceURI ;
                        northwind:largeFlagDAVResourceURI northwind:DLF-Flag(countries.LargeFlagDAVResourceURI)
                                as northwind:DLF-map-Country-LargeFlagDAVResourceURI ;
                        wgs:lat countries.Lat
                                as northwind:DLF-map-Country-Lat ;
                        wgs:long countries.Lng
                                as northwind:DLF-map-Country-Lng ;
                        rdfs:isDefinedBy northwind:DLF-Country (countries.Name) .

                northwind:DLF-Country (countries.Name)
                        northwind:has_province
                northwind:DLF-Province (provinces.CountryCode, provinces.Province) where (^{provinces.}^.CountryCode = ^{countries.}^.Code) as northwind:DLF-map-Country-has_province .

                northwind:DLF-Province (provinces.CountryCode, provinces.Province)
                        a northwind:Province
                                as northwind:DLF-map-Province-Provinces ;
                        northwind:has_country_code provinces.CountryCode
                                as northwind:DLF-map-has_country_code ;
                        northwind:provinceName provinces.Province
                                as northwind:DLF-map-Province-ProvinceName ;
                        rdfs:isDefinedBy northwind:DLF-Province (provinces.CountryCode, provinces.Province) .

                northwind:DLF-Province (provinces.CountryCode, provinces.Province)
                        northwind:is_province_of
                northwind:DLF-Country (countries.Name) where  (^{countries.}^.Code = ^{provinces.}^.CountryCode) as northwind:DLF-map-Province-country_of .
        }.
}.
;

--!<para>As a precaution, we erase url rewrite rule list that may be in the database after previous run of the script:</para>
select DB.DBA.URLREWRITE_DROP_RULELIST (URRL_LIST, 1)
from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = 'demo_nw_rule_list1'
;
--!<para>Same for individual rewrite rules:</para>
select DB.DBA.URLREWRITE_DROP_RULE (URR_RULE, 1)
from DB.DBA.URL_REWRITE_RULE where URR_RULE = 'demo_nw_rule1' 
;
select DB.DBA.URLREWRITE_DROP_RULE (URR_RULE, 1)
from DB.DBA.URL_REWRITE_RULE where URR_RULE = 'demo_nw_rule2'
;
select DB.DBA.URLREWRITE_DROP_RULE (URR_RULE, 1)
from DB.DBA.URL_REWRITE_RULE where URR_RULE = 'demo_nw_rule3'
;
select DB.DBA.URLREWRITE_DROP_RULE (URR_RULE, 1)
from DB.DBA.URL_REWRITE_RULE where URR_RULE = 'demo_nw_rule4'
;
select DB.DBA.URLREWRITE_DROP_RULE (URR_RULE, 1)
from DB.DBA.URL_REWRITE_RULE where URR_RULE = 'demo_nw_rdf'
;
--!<para>As a sanity check we ensure that there are no more rules named like our rules</para>
select signal ('WEIRD', sprintf ('Rewrite rule "%s" found', URR_RULE))
from DB.DBA.URL_REWRITE_RULE where URR_RULE like 'demo_nw%'
;

--!<para>Now we create URI rewrite rules based on regular expressions by calling<link linkend="fn_urlrewrite_create_regex_rule"><function>DB.DBA.URLREWRITE_CREATE_REGEX_RULE</function></link>, so same path will be redirected to different places depending on MIME types the client can accept.</para>

--!<para>This rule is to construct TURTLE or RDF/XML output of CONSTRUCT. Note dots in regexp for MIME type because there exist SPARQL web clients published before the related W3C recommendation, they will produce slightly incorrect &quot;Accept:&quot; string.</para>

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule2',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3C^{DynamicLocalFormat}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3C^{DynamicLocalFormat}^/Northwind%%3E+WHERE+{+%%3C^{DynamicLocalFormat}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    )
;

--!<para>This rule is to redirect to the RDF browser that will show the subject description and let the user to explore related subjects.</para>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule1',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/about/html/http://^{DynamicLocalFormat}^%s%%23this',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    )
;

--!<para>This rule is to remove trailing slash from path. Note that <emphasis>\x24</emphasis> is <emphasis>$</emphasis> for end of line regex pattern, it is written escaped because dollar sign indicates the beginning of macro for ISQL.</para>
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
    )
;

--!<para>This allow the server to describe proper ontology even when the requested IRI contain wrong host name and even if the ontology for <emphasis>http://demo.openlinksw.com/schemas/northwind#</emphasis> is actualy loaded in the database in graph with different IRI (<emphasis>http://demo.openlinksw.com/schemas/NorthwindOntology/1.0/</emphasis>) and the URI of downloadable ontology file differs from both (the file is <emphasis>/DAV/VAD/demo/sql/nw.owl</emphasis>) .</para>
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

DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV()
;

drop procedure DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'demo_nw_rule4',
    1,
    '/schemas/northwind#(.*)',
    vector('path'),
    1,
    '/sparql?query=DESCRIBE%20%3Chttp%3A//demo.openlinksw.com/schemas/northwind%23%U%3E%20FROM%20%3Chttp%3A//demo.openlinksw.com/schemas/NorthwindOntology/1.0/%3E',
    vector('path'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    )
;

--!<para>Finally we create the rulelist and define virtual directory <emphasis>/Northwind</emphasis>. Requests that match rewriting rules will be properly redirected and produce the requested data, access to the root will execute default page of the application, namely <emphasis>sfront.vspx</emphasis>.</para>
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'demo_nw_rule_list1',
    1,
    vector (
                'demo_nw_rule1',
                'demo_nw_rule2',
                'demo_nw_rule3',
                'demo_nw_rule4'
          ));


VHOST_REMOVE (lpath=>'/Northwind');
DB.DBA.VHOST_DEFINE (lpath=>'/Northwind', ppath=>'/DAV/home/demo/', vsp_user=>'dba', is_dav=>1, def_page=>'sfront.vspx',
          is_brws=>0, opts=>vector ('url_rewrite', 'demo_nw_rule_list1'))
;
