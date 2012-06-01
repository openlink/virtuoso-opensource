

ECHO BOTH "RDF IFP Test\n";

ttlp ('
<john1> a <person> .
<john2> a <person> .
<mary> a <person> .
<mike> a <person> .
<john1> <name> "John" .
<john2> <name> "John" .
<john1> <address> "101 A street" .
<john2> <address> "102 B street" .
<john2> <knows> <mike> .
<john1> <http://www.w3.org/2002/07/owl#sameAs> <john2> .
<mary> <knows> "John" .
<mike> <knows> <john1> .
<mike> <knows> <john2> .
<john1> <name> "Tarzan" .
<mike> <nam> "Tarzan" .
', '', 'ifps');


ttlp ('
<name> a <http://www.w3.org/2002/07/owl#InverseFunctionalProperty> .
<name> <http://www.openlinksw.com/schemas/virtrdf#nullIFPValue> "Tarzan" .
', '', 'ifp_list');

rdfs_rule_set ('ifps', 'ifp_list');



sparql define input:inference 'ifps'  select * from <ifps> where {<john1> ?p ?o};
ECHO BOTH $IF $EQU $ROWCNT 9 "PASSED" "***FAILED";
ECHO BOTH ": properties of john\n";

sparql define input:inference 'ifps'  select * from <ifps> where { ?person a <person> . ?person <knows> ?somebody . ?somebody  ?p ?o};


sparql select distinct ?p from <ifps> where { ?p a <person>};
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
ECHO BOTH ": distinct persons\n";

sparql define input:inference "ifps" select distinct ?p from <ifps> where { ?p a <person>};
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": distinct persons with ifp inf\n";


-- rdf_inf_set_ifp_exclude_list ('ifps', iri_to_id ('name'), vector ('John'));

-- sparql define input:inference "ifps" select distinct ?p from <ifps> where { ?p a <person>};
