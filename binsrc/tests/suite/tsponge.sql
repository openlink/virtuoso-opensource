ECHO BOTH "STARTED: SPARQL HTTP sponge tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

VAD_INSTALL ('cartridges_dav.vad');

registry_set ('__sparql_sponge_use_w3c_xslt', 'off');
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTTP_SESSION';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_CALAIS';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_FEED_RESPONSE';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTMLTABLE';
update DB.DBA.SYS_RDF_MAPPERS set RM_OPTIONS = vector ('add-html-meta', 'no', 'get-feeds', 'no') where RM_HOOK = 'DB.DBA.RDF_LOAD_HTML_RESPONSE';
delete from DB.DBA.RDF_META_CARTRIDGES;

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/xmlWithGrddlAttribute.xml>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": P3P work-alike returned : " $ROWCNT " triples, expected 4\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/projects.xml>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 22 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Get RDF from a spreadsheet : " $ROWCNT " triples, expected 22\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/rdf_sem.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDFa example : " $ROWCNT " triples, expected 6\n";

-- the bellow is not quite right
sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/inline.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Inline transformation reference : " $ROWCNT " triples, expected 1\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/baseURI.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Base URI: Same document reference : " $ROWCNT " triples, expected 2\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/titleauthor.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Title / Author (from specification) " $ROWCNT " triples, expected 4\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/card.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 23 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": An hcard profile " $ROWCNT " triples, expected 23\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/multiprofile.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 2 profiles: eRDF and hCard " $ROWCNT " triples, expected 8\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/sq1.xml>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Namespace documents and media types 1 " $ROWCNT " triples, expected 1\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/sq2.xml>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Namespace documents and media types 2 " $ROWCNT " triples, expected 1\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/loop.xml>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Namepace Loop " $ROWCNT " triples, expected 2\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/xinclude1.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Testing GRDDL when XInclude processing is disabled " $ROWCNT " triples, expected 1\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/grddlonrdf.rdf>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Testing GRDDL attributes on RDF documents (case 3) " $ROWCNT " triples, expected 4\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/atom-grddl.xml>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 22 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Transformations may produce serializations other than RDF/XML " $ROWCNT " triples, expected 22\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/conneg.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Content Negotiation with GRDDL " $ROWCNT " triples, expected 3\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/grddlonrdf-xmlmediatype.rdf>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Testing GRDDL attributes on RDF documents with XML media type " $ROWCNT " triples, expected 4\n";
ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SPARQL HTTP sponge tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;
ECHO BOTH "STARTED: JSON parser tests\n";
select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[2];
ECHO BOTH $IF $EQU $LAST[1] a "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member a=str " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[3];
ECHO BOTH $IF $EQU $LAST[1] str "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member a=str " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[4];
ECHO BOTH $IF $EQU $LAST[1] b "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member b=12 " $LAST[1] "\n";


select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[5];
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member b=12 " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[6];
ECHO BOTH $IF $EQU $LAST[1] c "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member c=null " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[7];
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member c=null " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[8];
ECHO BOTH $IF $EQU $LAST[1] d "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member d=false " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[9];
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member d=fales " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[10];
ECHO BOTH $IF $EQU $LAST[1] e "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member e=true " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[11];
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member e=true " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[12];
ECHO BOTH $IF $EQU $LAST[1] f "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member f=vector() " $LAST[1] "\n";

select length(json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[13]);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member f=vector " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "ff":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[14];
ECHO BOTH $IF $EQU $LAST[1] ff "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member ff=[a,b]" $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[15][1];
ECHO BOTH $IF $EQU $LAST[1] b "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member ff=[a,b] " $LAST[1] "\n";

select aref(aref(aref (json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }'), 19), 0), 3);
ECHO BOTH $IF $EQU $LAST[1] l "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member i=[{k:l}] " $LAST[1] "\n";

DB.DBA.RDF_OBJ_FT_RULE_ADD (null,null,'all');
VT_INC_INDEX_DB_DBA_RDF_OBJ();
sparql select count (1) where { graph <http://www.openlinksw.com/schemas/virtrdf#> { <http://www.openlinksw.com/virtrdf-data-formats#multipart-uri> <http://www.openlinksw.com/schemas/virtrdf#qmfStrsqlvalOfShortTmpl> ?o . ?o bif:contains "'__spfi'" }};
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": search for word in a single graph " $LAST[1] "\n";

sparql select count (1) where { <http://www.openlinksw.com/virtrdf-data-formats#multipart-uri> <http://www.openlinksw.com/schemas/virtrdf#qmfStrsqlvalOfShortTmpl> ?o . ?o bif:contains "'__spfi'" };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": search for word in all graphs " $LAST[1] "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: JSON parser tests\n";
