
ECHO BOTH "STARTED: Started GraphQL/SPARQL bridge tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

GQL_INIT_TYPE_SCHEMA();

create procedure GQL_TEST (in ql varchar, in xp varchar, in authenticate int := 0)
{
  declare result_string, xe, xt any;
  declare user_name, passwd, state, message, auth varchar;
  -- FIRST make sure JSON is correct
  json_parse (ql);
  result_names (state, message);
  auth := '';
  if (authenticate)
    auth := '\nAuthorization: Basic ZGJhOmRiYQ==';
  result_string := DB.DBA.HTTP_CLIENT (url=>sprintf ('http://localhost:%s/graphql', server_http_port()), http_method=>'POST', 
    http_headers=>concat('Content-Type: application/json', auth), body=>ql);
  xe := xtree_doc (json2xml (result_string));
  xt := xpath_eval (xp, xe);
  if (xp like 'count(%' and xt = 0)
    result ('***FAILED', concat (xp, ' : ', xt));
  else if (xt is not null)
    result ('PASSED', concat (xp, ' : ', xt));
  else
    result ('***FAILED', concat (xp, ' : ', xt));
};

TTLP (file_open ('nwgschema.ttl'), '', 'http://localhost:8890/schemas/Demo#');
TTLP (gql_create_type_schema ('http://localhost:8890/schemas/Demo#'), '', 'urn:graphql:intro:demo');
GQL_INTRO_ADD ('urn:graphql:intro:demo');

GQL_TEST(sprintf ('{"query":"%s"}', replace (file_to_string ('tgql_intro.ql'), '\n','')), '/data/__schema/types/name[.="Categories"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query { Products (productid:1){iri productname productid unitprice quantityperunit has_categories {iri categoryname description } } }"}', '/data/Products/productname[.="Chai"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query {\\n  Bulgaria: country (code:\\"BG\\") {\\n    code\\n    code3\\n    name\\n    region {\\n      code\\n      name\\n    }\\n  }\\n}"}','/data/Bulgaria/code[.="BG"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query CountryByCode(\x24expand: Boolean! = true, \x24rext: Boolean!, \x24scp: Boolean!) {\\n  usa: country(code: \\"US\\") {\\n    code\\n    ... @include(if: \x24expand) {\\n      name\\n      code3\\n    }\\n    country_code @skip(if: \x24scp)\\n    region @include(if: \x24expand) {\\n      code\\n      ...regionFields @include(if: \x24rext)\\n    }\\n  }\\n}\\n\\nfragment regionFields on region {\\n  name\\n  ccode\\n  population\\n}\\n","variables":{"scp":true,"rext":true},"operationName":"CountryByCode"}','/data/usa/region/code[.="AM"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query regions {\\n  regions\\n}\\n","operationName":"regions"}','/data/regions[. = "http://example.org/region/AF"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query countries {\\n  countries (region:\\"http://example.org/region/EU\\"){\\n    code3\\n    name\\n    code\\n    country_code\\n  }\\n}","operationName":"countries"}','/data/countries/code3[.="NOR"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query CountriesForRegion(\x24ccode: String!, \x24ccodes: [String!]!) {\\n  region(code: \x24ccode) {\\n    name\\n    code\\n    countries(code: \x24ccodes) {\\n      __typename\\n      name\\n      code\\n      country_code\\n      code3\\n    }\\n  }\\n}\\n","variables":{"ccode":"AM","ccodes":["US","CL","BR"]},"operationName":"CountriesForRegion"}','/data/region/countries/country_code[.="152"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query {\\n  regions(code:\\"AN\\") {\\n    name\\n    population\\n    countries{\\n      code\\n      code3\\n      country_code\\n      name\\n    }\\n  }\\n}"}','/data/regions/countries/code[.="AQ"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";


GQL_TEST('{"query":"mutation updateRegion(\x24code: String!, \x24population: Float) {\\n  updateRegion(code: \x24code, population: \x24population) {\\n    name\\n    population\\n  }\\n}\\n","variables":{"code":"AN","population":4490},"operationName":"updateRegion"}','/data/updateRegion/population[.="4490"]',1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query {\\n  regions(code:\\"AN\\") {\\n    name\\n    population\\n    countries{\\n      code\\n      code3\\n      country_code\\n      name\\n    }\\n  }\\n}"}','/data/regions/population[.="4490"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"mutation {\\n  insertCountry(\\n    code: \\"ZZ\\"\\n    name: \\"Kin-dza-dza\\"\\n    code3: \\"KZZ\\"\\n    region: \\"http://example.org/region/AN\\"\\n    country_code: 2048\\n  ) {\\n    name\\n    code\\n    code3\\n    country_code\\n  }\\n}\\n"}','/data/insertCountry/country_code[.="2048"]',1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query CountryByCode(\x24expand: Boolean! = true, \x24rext: Boolean!, \x24scp: Boolean!) {\\n  country(code: \\"ZZ\\") {\\n    code\\n    ... @include(if: \x24expand) {\\n      name\\n      code3\\n    }\\n    country_code @skip(if: \x24scp)\\n    region @include(if: \x24expand) {\\n      code\\n      ...regionFields @include(if: \x24rext)\\n    }\\n  }\\n}\\n\\nfragment regionFields on region {\\n  name\\n  ccode\\n  population\\n}\\n","variables":{"scp":true,"rext":true},"operationName":"CountryByCode"}','/data/country/code3[.="KZZ"]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"mutation {\\n  deleteCountry(code: \\"ZZ\\") {\\n    code\\n  }\\n}\\n"}','/data/deleteCountry[.=""]',1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";


GQL_TEST('{"query":"query CountryByCode(\x24expand: Boolean! = true, \x24rext: Boolean!, \x24scp: Boolean!) {\\n  country(code: \\"ZZ\\") {\\n    code\\n    ... @include(if: \x24expand) {\\n      name\\n      code3\\n    }\\n    country_code @skip(if: \x24scp)\\n    region @include(if: \x24expand) {\\n      code\\n      ...regionFields @include(if: \x24rext)\\n    }\\n  }\\n}\\n\\nfragment regionFields on region {\\n  name\\n  ccode\\n  population\\n}\\n","variables":{"scp":true,"rext":true},"operationName":"CountryByCode"}','/data/country[.=""]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";


GQL_TEST ('{"query":"mutation (\x24code: String!, \x24code3: String, \x24name: String, \x24region: regionInput) {\\n  insertCountry(code: \x24code, name: \x24name, code3: \x24code3) #region: \x24region\\n  {\\n    name\\n    country_code\\n    code3\\n  }\\n}\\n","variables":{"code":"YY","code3":"ZYZ","name":"Zamunda","region":{"code":"OZ","name":"Oz Land"}}}', '/data/insertCountry/code3[.="ZYZ"]', 1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST ('{"query":"query {country(code:\\"YY\\"){code3}}"}', '/data/country/code3[.="ZYZ"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"mutation {\\n  deleteCountry(code: \\"YY\\") {\\n    code\\n  }\\n}\\n"}','/data/deleteCountry[.=""]',1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST ('{"query":"query {country(code:\\"YY\\"){code3}}"}', '/data/country[.=""]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"{countries{code3 region(code:\\"AN\\") {ccode}}}"}', '/data/countries/region/ccode[.=1]',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"{countries{code3 region(code:\\"AN\\") {ccode}}}"}', 'count(/data/countries/region) = 1',0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_INIT_TYPE_SCHEMA();

SPARQL CLEAR GRAPH <urn:ex:map>;
SPARQL CLEAR GRAPH <urn:ex:data>;

SPARQL

PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX gql: <http://www.openlinksw.com/schemas/graphql#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX ex: <http://example.org/item/>

WITH <urn:ex:map>
INSERT {
gql:Map gql:schemaObjects gql:insertItem, gql:deleteItem, gql:updateItem, gql:getItems ;
    gql:dataGraph <urn:ex:data> ;
    gql:schemaGraph <urn:ex:map> .

gql:getItems gql:type gql:Array ;
    gql:rdfClass ex:Item .

gql:insertItem gql:type gql:Object ;
    gql:rdfClass ex:Item ;
    gql:mutationType "INSERT" .

gql:updateItem gql:type gql:Object ;
    gql:rdfClass ex:Item ;
    gql:mutationType "UPDATE" .

gql:deleteItem gql:type gql:Object ;
    gql:rdfClass ex:Item ;
    gql:mutationType "DELETE" .

ex:Item a owl:Class ;
    gql:iriPattern "%s" ;
    gql:field gql:item .

ex:stringAttr a owl:DatatypeProperty ;
   rdfs:range xsd:string ;
   rdfs:domain ex:Item ;
   gql:field gql:stringField ;
   gql:type gql:Scalar .

ex:iri a owl:DatatypeProperty ;
   rdfs:range xsd:anyURI ;
   rdfs:domain ex:Item ;
   gql:field gql:iri ;
   gql:type gql:ID .

ex:intAttr a owl:DatatypeProperty ;
   rdfs:range xsd:int ;
   rdfs:domain ex:Item ;
   gql:type gql:Scalar ;
   gql:field gql:intField .

ex:floatAttr a owl:DatatypeProperty ;
   rdfs:range xsd:float ;
   rdfs:domain ex:Item ;
   gql:type gql:Scalar ;
   gql:field gql:floatField .

ex:dateAttr a owl:DatatypeProperty ;
   rdfs:range xsd:dateTime ;
   rdfs:domain ex:Item ;
   gql:type gql:Scalar ;
   gql:field gql:dateField .

ex:boolAttr a owl:DatatypeProperty ;
   rdfs:range xsd:boolean ;
   rdfs:domain ex:Item ;
   gql:type gql:Scalar ;
   gql:field gql:boolField .

ex:objAttr a owl:ObjectProperty ;
   rdfs:range ex:Item ;
   rdfs:domain ex:Item ;
   gql:type gql:Object ;
   gql:field gql:objField .

};

GQL_TEST('{"query":"mutation ModifyItem {\\n  updateItem(\\n    iri: \\"urn:ex:1\\"\\n    stringField: \\"some string\\"\\n    intField: 100000\\n    floatField: 3.1415\\n    boolField: true\\n    dateField: \\"1999-07-14\\"\\n    objField: \\"urn:ex:0\\"\\n  ) {\\n    iri\\n    stringField\\n    intField\\n    floatField\\n    dateField\\n    boolField\\n    objField {\\n      iri\\n      stringField\\n    }\\n  }\\n}\\n\\nmutation RemoveItem {\\n  deleteItem(iri: \\"urn:ex:1\\") {\\n    iri\\n  }\\n}\\n\\nquery GetItems {\\n  getItems {\\n    iri\\n    stringField\\n    floatField\\n    dateField\\n    intField\\n    boolField\\n    objField {\\n      iri\\n      stringField\\n    }\\n  }\\n}\\n","operationName":"ModifyItem"}', '/data/updateItem/objField/iri[.="urn:ex:0"]', 1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

sparql select count(*) from <urn:ex:data> { <urn:ex:1> ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " triples\n";


GQL_TEST('{"query":"mutation ModifyItem {\\n  updateItem(\\n    iri: \\"urn:ex:1\\"\\n    stringField: \\"some string\\"\\n    intField: 100000\\n    floatField: 3.1415\\n    boolField: true\\n    dateField: \\"1999-07-14\\"\\n    objField: \\"urn:ex:0\\"\\n  ) {\\n    iri\\n    stringField\\n    intField\\n    floatField\\n    dateField\\n    boolField\\n    objField {\\n      iri\\n      stringField\\n    }\\n  }\\n}\\n\\nmutation RemoveItem {\\n  deleteItem(iri: \\"urn:ex:1\\") {\\n    iri\\n  }\\n}\\n\\nquery GetItems {\\n  getItems {\\n    iri\\n    stringField\\n    floatField\\n    dateField\\n    intField\\n    boolField\\n    objField {\\n      iri\\n      stringField\\n    }\\n  }\\n}\\n","operationName":"RemoveItem"}', '/data/deleteItem[.=""]', 1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

sparql select count(*) from <urn:ex:data> { <urn:ex:1> ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " remaining triples\n";


GQL_TEST ('{"query":"query CountryByCode(\\n  \x24code: String!\\n  \x24expand: Boolean! = true\\n  \x24rext: Boolean!\\n  \x24scp: Boolean!\\n) {\\n  kindzadza: country(code: \x24code) {\\n    code\\n    ... @include(if: \x24expand) {\\n      name\\n      code3\\n    }\\n    country_code @skip(if: \x24scp)\\n    region @include(if: \x24expand) {\\n      code\\n      ...regionFields @include(if: \x24rext)\\n    }\\n  }\\n}\\n\\nfragment regionFields on region {\\n  name\\n  ccode\\n  population @notNull\\n}\\n","variables":{"code":"AQ","expand":true,"scp":false,"rext":true},"operationName":"CountryByCode"}', '/data/kindzadza/region/code[.="AN"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";

SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST ('{"query":"query CountryByCode(\\n\x24code: String!\\n\x24expand: Boolean! = true\\n\x24rext: Boolean!\\n\x24scp: Boolean!\\n) {\\n  kindzadza: country(code: \x24code) {\\n    code\\n    ... @include(if: \x24expand) {\\n      name\\n      code3\\n    }\\n    country_code @skip(if: \x24scp)\\n    region @include(if: \x24expand) {\\n      code\\n      ...regionFields @include(if: \x24rext)\\n    }\\n  }\\n}\\n\\nfragment regionFields on region {\\n  name\\n  ccode\\n  population @notNull\\n}\\n","variables":{"code":"AQ","expand":false,"scp":false,"rext":true},"operationName":"CountryByCode"}', 'count(/data/kindzadza/region) = 0', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";

SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

-- Cleanup
SPARQL CLEAR GRAPH <urn:inf:data>;
SPARQL CLEAR GRAPH <urn:inf:schema>;
SPARQL CLEAR GRAPH <urn:inf:intro>;
SPARQL CLEAR GRAPH <urn:inf:inf>;

-- Load some data
SPARQL
PREFIX ex: <http://example.org/ex/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
WITH <urn:inf:data>
INSERT {

    ex:bob a foaf:Person ;
       foaf:mbox <mailto:bob@nowhere.no> ;
       foaf:knows ex:ali;
       foaf:name "Bob" .

    ex:suzi a foaf:Person ;
       foaf:mbox <mailto:suzi@nowhere.no> ;
       foaf:knows ex:bob ;
       foaf:name "Suzi" .

    ex:ali a foaf:Person ;
       foaf:mbox <mailto:ali@nowhere.no> ;
       foaf:knows ex:suzi, ex:bob ;
       foaf:name "Alice" .

    ex:company a foaf:Organization ;
       foaf:phone <tel:+1-00-001-000> ;
       foaf:mbox <mailto:acme@nowhere.co.no> ;
       rdfs:comment "ACME company, (c)2000" ;
       foaf:name "Company" .
}
;

SPARQL
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

WITH <urn:inf:inf>
INSERT {
  foaf:Person rdfs:subClassOf foaf:Agent .
  foaf:Organization rdfs:subClassOf foaf:Agent .
  foaf:Agent rdfs:subClassOf owl:Thing .
};

RDFS_RULE_SET ('foaf', 'urn:inf:inf', 1);
RDFS_RULE_SET ('foaf', 'urn:inf:inf');

-- Load annotated with mappings onotology, this is used to expose the urn:hello:data graph
SPARQL
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX gql: <http://www.openlinksw.com/schemas/graphql#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX ex: <http://example.org/hello/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

WITH <urn:inf:schema>
INSERT {

  gql:Map gql:dataGraph <urn:inf:data> ;
          gql:schemaGraph <urn:inf:schema> ;
          gql:inferenceName "foaf" ;
          gql:schemaObjects gql:individuals, gql:companies, gql:entities .

  gql:individuals gql:type gql:Array ;
     gql:rdfClass foaf:Person .

  gql:companies gql:type gql:Array ;
     gql:rdfClass foaf:Organization .

  gql:entities gql:type gql:Array ;
     gql:rdfClass foaf:Agent .

  foaf:Person a owl:Class ;
    rdfs:subClassOf foaf:Agent .

  foaf:Organization a owl:Class ;
    rdfs:subClassOf foaf:Agent .

  foaf:Agent a owl:Class ;
    rdfs:subClassOf owl:Thing .

  foaf:name a owl:DatatypeProperty ;
      rdfs:range xsd:string ;
      rdfs:domain foaf:Agent ;
      gql:field gql:name ;
      gql:type gql:Scalar .

  foaf:mbox a owl:DatatypeProperty ;
     rdfs:range xsd:anyURI ;
     rdfs:domain foaf:Agent ;
     gql:field gql:email ;
     gql:type gql:Scalar .

  foaf:phone a owl:DatatypeProperty ;
     rdfs:range xsd:anyURI ;
     rdfs:domain foaf:Agent ;
     gql:field gql:phone ;
     gql:type gql:Scalar .

  foaf:homepage a owl:DatatypeProperty ;
     rdfs:range xsd:anyURI ;
     rdfs:domain foaf:Agent ;
     gql:field gql:link ;
     gql:type gql:Scalar .

  foaf:knows a owl:ObjectProperty ;
    rdfs:range foaf:Person ;
    rdfs:domain foaf:Person ;
    gql:field gql:knows ;
    gql:type gql:Array .

  rdfs:label a owl:DatatypeProperty ;
    rdfs:range xsd:string ;
    rdfs:domain owl:Thing ;
    gql:field gql:label ;
    gql:type gql:Scalar .

  rdfs:comment a owl:DatatypeProperty ;
    rdfs:range xsd:string ;
    rdfs:domain owl:Thing ;
    gql:field gql:description ;
    gql:type gql:Scalar .

}
;

GQL_TEST( '{"query":"query Individuals { individuals { name knows { name } description @notNull email }}"}' ,
  '/data/individuals[name[.="Alice"]]/knows/name[.="Suzi"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST( '{"query":"query Individuals { individuals { name knows { name } description @notNull email }}"}' ,
  '/data/individuals[name[.="Alice"]]/knows/name[.="Bob"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query Companies { companies { iri name email phone description }}"}', '/data/companies/name[.="Company"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query Companies { companies { iri name email phone description }}"}', 'count(/data/companies)=1', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST('{"query":"query Entities { entities { iri name description @notNull phone @notNull email }}"}', 'count(/data/entities) = 4', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";


SPARQL CLEAR GRAPH <urn:geo:data>;
SPARQL CLEAR GRAPH <urn:geo:map>;
SPARQL CLEAR GRAPH <urn:geo:intro>;

SPARQL

PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX gql: <http://www.openlinksw.com/schemas/graphql#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX dct: <http://purl.org/dc/terms/>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX schema: <https://schema.org/>

WITH <urn:geo:map> INSERT {

gql:Map gql:schemaObjects gql:addPlace, gql:removePlace, gql:searchPlace ;
    gql:dataGraph <urn:geo:data> ;
    gql:schemaGraph <urn:geo:map> .

gql:searchPlace gql:type gql:Array ;
    gql:rdfClass schema:Place .

gql:addPlace gql:type gql:Object ;
    gql:rdfClass schema:Place ;
    gql:mutationType "UPDATE" .

gql:removePlace gql:type gql:Object ;
    gql:rdfClass schema:Place ;
    gql:mutationType "DELETE" .


geo:Point a owl:Class .

geo:lat a owl:DatatypeProperty ;
    rdfs:range xsd:float ;
    rdfs:domain geo:Point ;
    gql:field gql:lat ;
    gql:type gql:Scalar .

geo:long a owl:DatatypeProperty ;
    rdfs:range xsd:float ;
    rdfs:domain geo:Point ;
    gql:field gql:long ;
    gql:type gql:Scalar .

schema:Place a owl:Class ;
    gql:iriPattern "https://example.org/place/%U" .

schema:geo a owl:ObjectProperty ;
    rdfs:range geo:Point ;
    rdfs:domain schema:Place ;
    gql:field gql:location ;
    gql:type gql:Object .

dc:identifier a owl:DatatypeProperty ;
    rdfs:range xsd:string ;
    rdfs:domain schema:Place ;
    gql:field gql:id ;
    gql:type gql:ID .

schema:name a owl:DatatypeProperty ;
    rdfs:range xsd:string ;
    rdfs:domain schema:Place ;
    gql:field gql:name ;
    gql:type gql:Scalar .

dc:description a owl:DatatypeProperty ;
    rdfs:range xsd:string ;
    rdfs:domain schema:Place ;
    gql:field gql:description ;
    gql:type gql:Scalar .

};


GQL_TEST ('{"query":"mutation AddPlace { addPlace( id: \\"15\\" name: \\"Plovdiv\\" description: \\"ul.Il.Makarioploski 68\\" location: { long: 42.139233, lat: 24.761860 } ) { iri location { lat long } description name }}","operationName":"AddPlace"}', '/data/addPlace/location/lat[. > 0]', 1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

sparql select * from <urn:geo:data> { <https://example.org/place/15> <https://schema.org/geo> [ <http://www.w3.org/2003/01/geo/wgs84_pos#lat> ?lat ; <http://www.w3.org/2003/01/geo/wgs84_pos#long> ?long  ] };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " " $LAST[2] " location\n";

GQL_TEST ('{"query":"mutation AddPlaceWithParams( \x24id: ID! \x24name: String! \x24desc: String \x24loc: PointInput) { addPlace(id: \x24id, name: \x24name, description: \x24desc, location: \x24loc) { iri location { lat long } description name }}","variables":{"id":"14","name":"Home","desc":"ul.D-r Vlado 14","loc":{"long":42.139233,"lat":24.76186}},"operationName":"AddPlaceWithParams"}', '/data/addPlace/location/lat[. > 0]', 1);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

sparql select * from <urn:geo:data> { <https://example.org/place/14> <https://schema.org/geo> [ <http://www.w3.org/2003/01/geo/wgs84_pos#lat> ?lat ; <http://www.w3.org/2003/01/geo/wgs84_pos#long> ?long  ] };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " " $LAST[2] " location\n";

GQL_TEST ('{"query":"query Mix { GB:country(code: \\"GB\\") { code } BG:country(code: \\"BG\\") { code }}"}', '/data/GB/code[.="GB"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

GQL_TEST ('{"query":"query Mix { GB:country(code: \\"GB\\") { code } BG:country(code: \\"BG\\") { code }}"}', '/data/BG/code[.="BG"]', 0);
ECHO BOTH $IF $EQU $LAST[1] PASSED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[2] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GraphQL/SPARQL bridge tests\n";
