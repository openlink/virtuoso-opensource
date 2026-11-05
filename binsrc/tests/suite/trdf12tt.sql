-- RDF 1.2/SPARQL INSERT DATA compatibility tests.

create procedure RDF12TT_ASSERT (in test_name varchar, in expected integer, in actual integer)
{
  if (expected <> actual)
    signal ('RDF12TT', sprintf ('%s: expected %d row(s), got %d', test_name, expected, actual));
}
;

sparql clear graph <urn:virtuoso:test:rdf12tt:relative>;
sparql with <urn:virtuoso:test:rdf12tt:relative>
  insert data { <*#subj> <#prop> <obj> };
commit work;
RDF12TT_ASSERT ('relative IRIs with WITH', 1,
  (sparql select count (*) from <urn:virtuoso:test:rdf12tt:relative>
    { ?s ?p ?o
      filter (str (?s) = '*#subj' and str (?p) = '#prop' and str (?o) = 'obj') }));

sparql clear graph <urn:virtuoso:test:rdf12tt:base>;
sparql base <http://example.org/books/123>
  with <urn:virtuoso:test:rdf12tt:base>
  insert data { <> <*#title> "HHGG" };
commit work;
RDF12TT_ASSERT ('relative IRIs with BASE and WITH', 1,
  (sparql select count (*) from <urn:virtuoso:test:rdf12tt:base>
    { ?s ?p ?o
      filter (str (?s) = 'http://example.org/books/123'
        and str (?p) = 'http://example.org/books/*#title'
        and str (?o) = 'HHGG') }));

sparql clear graph <urn:virtuoso:test:rdf12tt:absolute>;
sparql with <urn:virtuoso:test:rdf12tt:absolute>
  insert data {
    <<( <http://example.org/s> <http://example.org/p> <http://example.org/o> )>>
      <http://example.org/asserted> "yes"
  };
commit work;
RDF12TT_ASSERT ('absolute RDF 1.2 triple term', 1,
  (select count (*) from DB.DBA.RDF_QUAD
    where G = iri_to_id ('urn:virtuoso:test:rdf12tt:absolute')
      and P = iri_to_id ('http://example.org/asserted')
      and O = 'yes'
      and DB.DBA.RDF_STAR_TT_CHECK (S,
        'http://example.org/s', 'http://example.org/p', 'http://example.org/o') = 1));

commit work;
