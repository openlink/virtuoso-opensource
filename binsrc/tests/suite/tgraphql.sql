
ECHO BOTH "STARTED: Started GraphQL/SPARQL bridge tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

GQL_INIT_TYPE_SCHEMA();

create procedure GQL_TEST (in ql varchar, in xp varchar, in authenticate int := 0)
{
  declare result_string, xe, xt any;
  declare user_name, passwd, state, message, auth varchar;

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

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GraphQL/SPARQL bridge tests\n";
