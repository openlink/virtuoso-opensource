create procedure tpcd_to_quads ()
{
  declare graph_iid IRI_ID;
  log_enable(2, 0);
  graph_iid := iri_to_id ('http://example.com/tpcd-quads');
  for (sparql define output:valmode "LONG" select ?s ?p ?o from <http://example.com/tpcd> where { ?s ?p ?o}) do
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (graph_iid, "s", "p", DB.DBA.RDF_OBJ_OF_LONG ("o"));
    }
  log_enable(1, 0);
}
;
