
delete from DB.DBA.RDF_QUAD
where G = __i2id ('http://test.com/tests/') ;
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 
delete from DB.DBA.RDF_QUAD
where G = __i2id (http://test.com/tests/) \n";

sparql clear graph <http://test.com/tests/>;
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": sparql clear graph <http://test.com/tests/>\n";

#line 6 "tsparup.sql"
sparql
insert data 
{
  graph <http://test.com/tests/> {
    <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> "9"^^<http://www.w3.org/2001/XMLSchema#int> .
  }
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 6 tsparup.sql
sparql
insert data 
{
  graph <http://test.com/tests/> {
    <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> 9^^<http://www.w3.org/2001/XMLSchema#int> .
  }
}\n";

qt_check_dir ('tsparup_1');
#line 22 "tsparup.sql"
sparql
with <http://test.com/tests/>
delete 
{ 
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
}
where
{
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 22 tsparup.sql
sparql
with <http://test.com/tests/>
delete 
{ 
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
}
where
{
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
}\n";

qt_check_dir ('tsparup_2');

delete from DB.DBA.RDF_QUAD
where G = __i2id ('http://test.com/tests/') ;
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 
delete from DB.DBA.RDF_QUAD
where G = __i2id (http://test.com/tests/) \n";

sparql clear graph <http://test.com/tests/>;
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": sparql clear graph <http://test.com/tests/>\n";

#line 43 "tsparup.sql"
sparql
insert data 
{
  graph <http://test.com/tests/> {
    <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> "9" .
  }
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 43 tsparup.sql
sparql
insert data 
{
  graph <http://test.com/tests/> {
    <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> 9 .
  }
}\n";

qt_check_dir ('tsparup_3');
#line 59 "tsparup.sql"
sparql
with <http://test.com/tests/>
delete 
{ 
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
}
where
{
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 59 tsparup.sql
sparql
with <http://test.com/tests/>
delete 
{ 
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
}
where
{
  <http://foo.com/datasets/tests/foo> <http://purl.org/ontology/wsf#product_in_inventory> ?o .
}\n";

qt_check_dir ('tsparup_4');
#line 78 "tsparup.sql"
sparql
INSERT INTO GRAPH <http://mygraph/> {
  <http://mygraph/#myitem> <http://www.w3.org/2000/01/rdf-schema#label> "Blabla" .
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 78 tsparup.sql
sparql
INSERT INTO GRAPH <http://mygraph/> {
  <http://mygraph/#myitem> <http://www.w3.org/2000/01/rdf-schema#label> Blabla .
}\n";

qt_check_dir ('tsparup_5');
#line 85 "tsparup.sql"
sparql
DELETE FROM GRAPH <http://mygraph/> {
    <http://mygraph/#myitem> <http://www.w3.org/2000/01/rdf-schema#label> "Blabla" .
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 85 tsparup.sql
sparql
DELETE FROM GRAPH <http://mygraph/> {
    <http://mygraph/#myitem> <http://www.w3.org/2000/01/rdf-schema#label> Blabla .
}\n";

qt_check_dir ('tsparup_6');
#line 92 "tsparup.sql"
sparql
INSERT INTO GRAPH <http://mygraph/> {
    <http://mygraph/#austrian_lot_source_1> <http://www.opengis.net/ont/geosparql#geometry> "MULTIPOLYGON(((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)))"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 92 tsparup.sql
sparql
INSERT INTO GRAPH <http://mygraph/> {
    <http://mygraph/#austrian_lot_source_1> <http://www.opengis.net/ont/geosparql#geometry> MULTIPOLYGON(((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)))^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .
}\n";

qt_check_dir ('tsparup_7');
#line 99 "tsparup.sql"
sparql
DELETE FROM GRAPH <http://mygraph/> {
    <http://mygraph/#austrian_lot_source_1> <http://www.opengis.net/ont/geosparql#geometry> "MULTIPOLYGON(((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)))"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .
};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": #line 99 tsparup.sql
sparql
DELETE FROM GRAPH <http://mygraph/> {
    <http://mygraph/#austrian_lot_source_1> <http://www.opengis.net/ont/geosparql#geometry> MULTIPOLYGON(((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)))^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .
}\n";

qt_check_dir ('tsparup_8');
