ECHO BOTH "STARTED: SPARQL HTTP sponge tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

VAD_INSTALL ('rdf_mappers_dav.vad');

registry_set ('__sparql_sponge_use_w3c_xslt', 'off');
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTTP_SESSION';

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
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RDFa example : " $ROWCNT " triples, expected 3\n";

-- the bellow is not quite right
sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/inline.html>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Inline transformation reference : " $ROWCNT " triples, expected 2\n";

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
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Content Negotiation with GRDDL " $ROWCNT " triples, expected 2\n";

sparql define get:soft "replacing" define input:default-graph-uri
<http://localhost:$U{HTTPPORT}/grddl-tests/grddlonrdf-xmlmediatype.rdf>
select * where { ?s ?p ?o . };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Testing GRDDL attributes on RDF documents with XML media type " $ROWCNT " triples, expected 4\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SPARQL HTTP sponge tests\n";
