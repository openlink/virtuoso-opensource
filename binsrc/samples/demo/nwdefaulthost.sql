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
create iri class northwind:Category "http://^{URIQADefaultHost}^/Northwind/Category/%d#this" (in category_id integer not null) .
create iri class northwind:Shipper "http://^{URIQADefaultHost}^/Northwind/Shipper/%d#this" (in shipper_id integer not null) .
create iri class northwind:Supplier "http://^{URIQADefaultHost}^/Northwind/Supplier/%d#this" (in supplier_id integer not null) .
create iri class northwind:Product   "http://^{URIQADefaultHost}^/Northwind/Product/%d#this" (in product_id integer not null) .
create iri class northwind:Customer "http://^{URIQADefaultHost}^/Northwind/Customer/%U#this" (in customer_id varchar not null) .
create iri class northwind:Employee
  "http://^{URIQADefaultHost}^/Northwind/Employee/%U%U%d#this"
  (in employee_firstname varchar not null, in employee_lastname varchar not null, in employee_id integer not null) .
create iri class northwind:Order "http://^{URIQADefaultHost}^/Northwind/Order/%d#this" (in order_id integer not null) .
create iri class northwind:CustomerContact
  "http://^{URIQADefaultHost}^/Northwind/CustomerContact/%U#this"
  (in customer_id varchar not null) .
create iri class northwind:OrderLine "http://^{URIQADefaultHost}^/Northwind/OrderLine/%d/%d#this"
  (in order_id integer not null, in product_id integer not null) .
create iri class northwind:Province "http://^{URIQADefaultHost}^/Northwind/Province/%U/%U#this"
  (in country_name varchar not null, in province_name varchar not null) .
create iri class northwind:Country "http://^{URIQADefaultHost}^/Northwind/Country/%U#this" (in country_name varchar not null) .
create iri class northwind:Flag "http://^{URIQADefaultHost}^%U#this" (in flag_path varchar not null) .
create iri class northwind:EmployeePhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/EMP%d#this" (in emp_id varchar not null) .
create iri class northwind:CategoryPhoto "http://^{URIQADefaultHost}^/DAV/VAD/demo/sql/CAT%d#this" (in category_id varchar not null) .
;

SPARQL
prefix northwind: <http://demo.openlinksw.com/schemas/northwind#>
create iri class northwind:dbpedia_iri "http://dbpedia.org/resource/%U" (in uname varchar not null)
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
                        rdfs:isDefinedBy northwind:Category (categories.CategoryID) .

                northwind:CategoryPhoto(categories.CategoryID)
                        a northwind:CategoryPhoto
                                as virtrdf:Category-categories.CategoryPhotoID ;
                        rdfs:isDefinedBy northwind:CategoryPhoto(categories.CategoryID) .

                northwind:Shipper (shippers.ShipperID)
                        a northwind:Shipper
                                as virtrdf:Shipper-ShipperID ;
                        northwind:companyName shippers.CompanyName
                                as virtrdf:Shipper-company_name ;
                        northwind:phone shippers.Phone
                                as virtrdf:Shipper-phone ;
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
                        northwind:postalCode customers.PostalCode
                                as virtrdf:Customer-postal_code ;
                        foaf:phone customers.Phone
                                as virtrdf:Customer-foaf_phone ;
                        northwind:phone customers.Phone
                                as virtrdf:Customer-phone ;
                        northwind:fax customers.Fax
                                as virtrdf:Customer-fax ;
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
                        northwind:employeeID employees.EmployeeID
                                as virtrdf:Employee-key ;
                        northwind:reportsTo northwind:Employee(employees2.FirstName, employees2.LastName, employees2.ReportsTo) where (^{employees.}^.ReportsTo = ^{employees2.}^.EmployeeID)
                                as virtrdf:Employee-reports_to ;
                        foaf:img northwind:EmployeePhoto(employees.EmployeeID)
                                as virtrdf:Employee-employees.EmployeePhoto ;
                        rdfs:isDefinedBy northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID) .

                northwind:EmployeePhoto(employees.EmployeeID)
                        a northwind:EmployeePhoto
                                as virtrdf:Employee-employees.EmployeePhotoId ;
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
                        northwind:has_salesrep northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
                                as virtrdf:Customer-has_salesrep ;
                        northwind:has_employee northwind:Employee (employees.FirstName, employees.LastName, employees.EmployeeID) where (^{orders.}^.EmployeeID = ^{employees.}^.EmployeeID)
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
                        rdfs:isDefinedBy northwind:Province (provinces.CountryCode, provinces.Province) .

                northwind:Province (provinces.CountryCode, provinces.Province)
                        northwind:is_province_of
                northwind:Country (countries.Name) where  (^{countries.}^.Code = ^{provinces.}^.CountryCode) as virtrdf:Province-country_of .
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
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/Northwind%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
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
    '/about/html/http://^{URIQADefaultHost}^%s%%23this',
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
