ECHO BOTH "STARTED: RDF API tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;
sparql delete { graph ?g { ?s ?p ?o } } where { graph ?g { ?s ?p ?o } filter (?g in (<http://example.org/bob>,<http://example.org/alice>,<http://example.org/default>,<http://example.org/joe>))};

TTLP('
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix dc: <http://purl.org/dc/terms/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://www.example.org/vocabulary#> .
@prefix : <http://example.org/> .

# default graph - no {} used.

:joe dc:publisher "Joe" .

{
  <http://example.org/bob> dc:publisher "Bob" .
  <http://example.org/alice> dc:publisher "Alice" .
}

# GRAPH keyword to highlight a named graph
# Abbreviation of triples using ;
GRAPH <http://example.org/bob>
{
   [] foaf:name "Bob" ;
      foaf:mbox <mailto:bob@oldcorp.example.org> ;
      foaf:knows _:b .
}

<http://example.org/alice>
{
    _:b foaf:name "Alice" ;
        foaf:mbox <mailto:alice@work.example.org>
}

GRAPH :joe { :me a ex:Person ;
              ex:name "Joe Doe" ;
              ex:homepage <http://example.org/joedoe> ;
              foaf:knows _:b ;
              ex:hasSkill graph ,
                          ex:Nothing .
}', 'http://example.org/', 'http://example.org/default', 256);

sparql select * from <http://example.org/default> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/default> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/bob> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/bob> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/alice> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/alice> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/joe> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/joe> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/bob> from <http://example.org/alice> from <http://example.org/default> from <http://example.org/joe> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TriG test contains : " $ROWCNT " triples\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: RDF API tests\n";
