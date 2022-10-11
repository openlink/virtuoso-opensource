SPARQL drop silent quad map <http://localhost:8890/schemas/Demo/qm-categories> .;
SPARQL drop silent quad map <http://localhost:8890/schemas/Demo/qm-products> .;
grant select on "Demo"."demo"."Categories" to SPARQL_SELECT;
grant select on "Demo"."demo"."Products" to SPARQL_SELECT;


SPARQL
prefix Demo: <http://localhost:8890/schemas/Demo/> 
create iri class Demo:categories "http://localhost:8890/Demo/categories/CategoryID/%d#this" (in _CategoryID integer not null) . ;
SPARQL
prefix Demo: <http://localhost:8890/schemas/Demo/> 
create iri class Demo:products "http://localhost:8890/Demo/products/ProductID/%d#this" (in _ProductID integer not null) . ;


create view "Demo"."demo"."CategoriesCount" as select count (*) as cnt from "Demo"."demo"."Categories"; 
grant select on "Demo"."demo"."CategoriesCount" to SPARQL_SELECT; 
create view "Demo"."demo"."ProductsCount" as select count (*) as cnt from "Demo"."demo"."Products"; 
grant select on "Demo"."demo"."ProductsCount" to SPARQL_SELECT; 
drop view "Demo"."demo"."Demo__Total"; 
create view "Demo"."demo"."Demo__Total" as select (cnt0*cnt1)+(cnt2*cnt3) AS cnt from 
 (select count(*) cnt0 from "Demo"."demo"."Categories") tb0, 
 (select count(*)+1 as cnt1 from DB.DBA.TABLE_COLS where "TABLE" = 'Demo.demo.Categories'  and "COLUMN" <> '_IDN') tb1,
 (select count(*) cnt2 from "Demo"."demo"."Products") tb2, 
 (select count(*)+1 as cnt3 from DB.DBA.TABLE_COLS where "TABLE" = 'Demo.demo.Products'  and "COLUMN" <> '_IDN') tb3
; 
grant select on "Demo"."demo"."Demo__Total" to SPARQL_SELECT; 


SPARQL
prefix Demo: <http://localhost:8890/schemas/Demo/> 
prefix demo-stat: <http://localhost:8890/Demo/stat#> 
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
prefix void: <http://rdfs.org/ns/void#> 
prefix scovo: <http://purl.org/NET/scovo#> 
prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/> 
alter quad storage virtrdf:DefaultQuadStorage 
 from "Demo"."demo"."Categories" as categories_s
 from "Demo"."demo"."Products" as products_s
 where (^{products_s.}^."CategoryID" = ^{categories_s.}^."CategoryID") 
 { 
   create Demo:qm-categories as graph iri ("http://localhost:8890/Demo#")  
    { 
      # Maps from columns of "Demo.demo.Categories"
      Demo:categories (categories_s."CategoryID")  a Demo:Categories ;
      Demo:categoryid categories_s."CategoryID" as Demo:demo-categories-categoryid ;
      Demo:categoryname categories_s."CategoryName" as Demo:demo-categories-categoryname ;
      Demo:description categories_s."Description" as Demo:demo-categories-description ;
      # Maps from foreign-key relations of "Demo.demo.Categories"
      Demo:categories_of Demo:products (products_s."ProductID")  as Demo:categories_products_of .

    }
 }

;

SPARQL
prefix Demo: <http://localhost:8890/schemas/Demo/> 
prefix demo-stat: <http://localhost:8890/Demo/stat#> 
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
prefix void: <http://rdfs.org/ns/void#> 
prefix scovo: <http://purl.org/NET/scovo#> 
prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/> 
alter quad storage virtrdf:DefaultQuadStorage 
 from "Demo"."demo"."Products" as products_s
 from "Demo"."demo"."Categories" as categories_s
 where (^{products_s.}^."CategoryID" = ^{categories_s.}^."CategoryID") 
 { 
   create Demo:qm-products as graph iri ("http://localhost:8890/Demo#")  
    { 
      # Maps from columns of "Demo.demo.Products"
      Demo:products (products_s."ProductID")  a Demo:Products ;
      Demo:productid products_s."ProductID" as Demo:demo-products-productid ;
      Demo:productname products_s."ProductName" as Demo:demo-products-productname ;
      Demo:supplierid products_s."SupplierID" as Demo:demo-products-supplierid ;
      Demo:categoryid products_s."CategoryID" as Demo:demo-products-categoryid ;
      Demo:quantityperunit products_s."QuantityPerUnit" as Demo:demo-products-quantityperunit ;
      Demo:unitprice products_s."UnitPrice" as Demo:demo-products-unitprice ;
      Demo:unitsinstock products_s."UnitsInStock" as Demo:demo-products-unitsinstock ;
      Demo:unitsonorder products_s."UnitsOnOrder" as Demo:demo-products-unitsonorder ;
      Demo:reorderlevel products_s."ReorderLevel" as Demo:demo-products-reorderlevel ;
      Demo:discontinued products_s."Discontinued" as Demo:demo-products-discontinued ;
      # Maps from foreign-key relations of "Demo.demo.Products"
      Demo:has_categories Demo:categories (categories_s."CategoryID")  as Demo:products_has_categories .

    }
 }

;

SPARQL
prefix Demo: <http://localhost:8890/schemas/Demo/> 
prefix demo-stat: <http://localhost:8890/Demo/stat#> 
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
prefix void: <http://rdfs.org/ns/void#> 
prefix scovo: <http://purl.org/NET/scovo#> 
prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/> 
alter quad storage virtrdf:DefaultQuadStorage 
 from "Demo"."demo"."CategoriesCount" as categoriescount_s
 from "Demo"."demo"."ProductsCount" as productscount_s
 from "Demo"."demo"."Demo__Total" as demo__total_s
 { 
   create Demo:qm-VoidStatistics as graph iri ("http://localhost:8890/Demo#") option (exclusive) 
    { 
      # voID Statistics 
      demo-stat: a void:Dataset as Demo:dataset-demo ; 
       void:sparqlEndpoint <http://localhost:8890/sparql> as Demo:dataset-sparql-demo ; 
      void:statItem demo-stat:Stat . 
      demo-stat:Stat a scovo:Item ; 
       rdf:value demo__total_s.cnt as Demo:stat-decl-demo ; 
       scovo:dimension void:numOfTriples . 

      demo-stat: void:statItem demo-stat:CategoriesStat as Demo:statitem-demo-categories . 
      demo-stat:CategoriesStat a scovo:Item as Demo:statitem-decl-demo-categories ; 
      rdf:value categoriescount_s.cnt as Demo:statitem-cnt-demo-categories ; 
      scovo:dimension void:numberOfResources as Demo:statitem-type-1-demo-categories ; 
      scovo:dimension Demo:Categories as Demo:statitem-type-2-demo-categories .

      demo-stat: void:statItem demo-stat:ProductsStat as Demo:statitem-demo-products . 
      demo-stat:ProductsStat a scovo:Item as Demo:statitem-decl-demo-products ; 
      rdf:value productscount_s.cnt as Demo:statitem-cnt-demo-products ; 
      scovo:dimension void:numberOfResources as Demo:statitem-type-1-demo-products ; 
      scovo:dimension Demo:Products as Demo:statitem-type-2-demo-products .

    }
 }
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NW Demo quad maps created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql select count(*) from <http://localhost:8890/Demo#> { ?s a <http://localhost:8890/schemas/Demo/Categories> };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Categories \n";

sparql select count(*) from <http://localhost:8890/Demo#> { ?s a <http://localhost:8890/schemas/Demo/Products> };
ECHO BOTH $IF $EQU $LAST[1] 77 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Products \n";

