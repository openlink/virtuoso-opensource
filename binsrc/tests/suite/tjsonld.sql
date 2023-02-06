create procedure jldfile(in f varchar)
{
  return file_to_string (concat ('jsonld/',f));
};


DB.DBA.SYS_CACHED_RESOURCE_ADD ('https://www.w3.org/ns/activitystreams', '', jldfile ('activitystreams.jsonld'), curutcdatetime(), 'Activity Streams Vocabulary');
DB.DBA.SYS_CACHED_RESOURCE_ADD ('http://www.w3.org/ns/activitystreams', '', jldfile ('activitystreams.jsonld'), curutcdatetime(), 'Activity Streams Vocabulary');
DB.DBA.SYS_CACHED_RESOURCE_ADD ('https://w3id.org/security/v1', '', jldfile ('security-v1.jsonld'), curutcdatetime(), 'Security Vocabulary');
DB.DBA.SYS_CACHED_RESOURCE_ADD ('http://schema.org/', '', jldfile ('jsonldcontext.json'), curutcdatetime(), 'Schema.org Vocabulary');
DB.DBA.SYS_CACHED_RESOURCE_ADD ('https://json-ld.org/contexts/person.jsonld', '', jldfile ('person.jsonld'), curutcdatetime(), 'Person Vocabulary');

create procedure jtest_path (in tn varchar)
{
  return concat ('json-ld-api/tests/toRdf/', tn);
}
;

create procedure jacts_path (in tn varchar)
{
  return concat ('actstrm_tests/', tn);
}
;

create procedure jacts_graph (in tn varchar)
{
  tn := regexp_replace (tn, '-jsonld\.json\x24', '');
  tn := regexp_replace (tn, '\.json\x24', '');
  return concat ('urn:as:', tn);
}
;


create procedure jtest_graph (in tn varchar)
{
  tn := regexp_replace (tn, '\.jsonld\x24', '');
  return concat ('urn:jsonld:', tn);
}
;

create procedure jacts_load_ttl(in tn varchar)
{
  declare g, p, nq varchar;
  p := regexp_replace (tn, '-jsonld\.json\x24', '-cmp');
  p := regexp_replace (p, '\.json\x24', '-cmp');
  nq := concat (tn, '.ttl');
  g := concat ('urn:as:', p);
  declare exit handler for sqlstate '*' {
    rollback work;
    dbg_obj_print (jacts_path (nq));
    return;
  };
  sparql clear graph ?:g;
  if (file_stat (jacts_path(nq)) and nq like '%.ttl')
    DB.DBA.TTLP (file_open (jacts_path(nq)), '', g, 255);
  commit work;
}
;


create procedure jacts_run (in tn varchar, in f int := 0)
{
  declare data, meta any;
  declare graph_iid varchar;

  log_message (sprintf ('ACTS test: %s', tn));
  graph_iid := jacts_graph (tn);
  declare exit handler for sqlstate '*' {
    rollback work;
    return __SQL_MESSAGE;
  };
  jacts_load_ttl (tn);
  sparql clear graph ?:graph_iid;
  DB.DBA.RDF_LOAD_JSON_LD (file_to_string (jacts_path (tn)), '', jacts_graph(tn));
  commit work;
  return 'OK';
}
;

create procedure jacts_run_all ()
{
  declare files any;
  declare inx, passed, df int;
  declare rc varchar;
  df := __dbf_set ('callstack_on_exception',0);
  result_names (files);
  files := sys_dirlist ('./actstrm_tests/', 1);
  files := __vector_sort (files);
  passed := inx := 0;
  foreach (varchar tn in files) do
    {
      if (tn like '%.json')
        {
          rc := jacts_run (tn);
          if (rc <> 'OK')
            result (concat (tn,': ', rc));
          else
            passed := passed + 1;
          inx := inx + 1;
        }
    }
  result (sprintf ('passed: %d/%d',passed,inx));
  __dbf_set ('callstack_on_exception',df);
}
;

create procedure jtest_load_nq(in tn varchar)
{
  declare g, p, nq varchar;
  p := regexp_replace (tn, '\-in.jsonld\x24', '-out');
  nq := regexp_replace (tn, '\-in.jsonld\x24', '-out.nq');
  g := concat ('urn:jsonld:', p);
  declare exit handler for sqlstate '*' {
    rollback work;
    dbg_obj_print (jtest_path (nq));
    return;
  };
  sparql clear graph ?:g;
  if (file_stat (jtest_path(nq)) and nq like '%.nq')
    DB.DBA.TTLP (file_open (jtest_path(nq)), '', g, 255+512);
  commit work;
}
;

create procedure jtest (in tn varchar, in f int := 0)
{
  declare data, meta any;
  declare graph_iid varchar;

  graph_iid := jtest_graph (tn);
  declare exit handler for sqlstate '*' {
    rollback work;
    return __SQL_MESSAGE;
  };
  sparql clear graph ?:graph_iid;
  DB.DBA.RDF_LOAD_JSON_LD (file_to_string (tn), concat ('file:', tn), graph_iid);
  --rdf_load_jsonld (file_to_string (tn), concat ('file:', tn), graph_iid, f);
  commit work;
  return graph_iid;
}
;


create procedure jtest_run (in tn varchar, in f int := 0)
{
  declare data, meta any;
  declare graph_iid varchar;

  log_message (sprintf ('JLD test: %s', tn));
  graph_iid := jtest_graph (tn);
  declare exit handler for sqlstate '*' {
    rollback work;
    return __SQL_MESSAGE;
  };
  jtest_load_nq (tn);
  sparql clear graph ?:graph_iid;
  DB.DBA.RDF_LOAD_JSON_LD (file_to_string (jtest_path (tn)), concat ('https://w3c.github.io/json-ld-api/tests/toRdf/', tn), jtest_graph(tn));
  --rdf_load_jsonld (file_to_string (jtest_path (tn)), concat ('https://w3c.github.io/json-ld-api/tests/toRdf/', tn), jtest_graph(tn), f);
  commit work;
  return 'OK';
}
;

create procedure jtest_run_all ()
{
  declare files any;
  declare inx, passed, df int;
  declare rc varchar;
  df := __dbf_set ('callstack_on_exception',0);
  result_names (files);
  files := sys_dirlist ('./json-ld-api/tests/toRdf/', 1);
  files := __vector_sort (files);
  passed := inx := 0;
  foreach (varchar tn in files) do
    {
      if (tn like '%.jsonld')
        {
          rc := jtest_run (tn);
          if (rc <> 'OK')
            result (concat (tn,': ', rc));
          else
            passed := passed + 1;
          inx := inx + 1;
        }
    }
  result (sprintf ('PASSED: %d/%d',passed,inx));
  __dbf_set ('callstack_on_exception',df);
}
;

create procedure jtest_dump (in tn varchar, in diff_only int := 1)
{
  declare i,o, gin, gout, dif varchar;
  declare r any;
  declare exit handler for sqlstate '*' {
    return concat ('SQL Error: ',tn,':',__sql_message);
  };
  r := string_output ();
  gin := concat ('urn:jsonld:',tn, '-in');
  gout := concat ('urn:jsonld:',tn, '-out');
  i := ((sparql define input:storage "" define output:format "NICE_TTL" construct { ?s ?p ?o } where { graph `iri(?:gin)` { ?s ?p ?o }}));
  o := ((sparql define input:storage "" define output:format "NICE_TTL" construct { ?s ?p ?o } where { graph `iri(?:gout)` { ?s ?p ?o }}));
  i := string_output_string (i);
  o := string_output_string (o);
  http (sprintf ('%s >>>\n', gout),r); 
  http (o, r);
  http (sprintf ('%s >>>\n', gin),r); 
  http (i, r);
  i := regexp_replace (i,'_:v?b[0-9]\+','_:vb00000');
  o := regexp_replace (o,'_:v?b[0-9]\+','_:vb00000');
  dif := diff (o, i);
  http ('--diff >>>\n',r); 
  http (dif,r);
  if (diff_only and length (dif))
    return concat (sprintf ('***FAILED: %s\n', tn), string_output_string (r));
  else
    return sprintf ('PASSED: %s\n', tn);
}
;

create procedure jtest_dump_results ()
{
  declare files any;
  declare res varchar;
  declare ses any;
  files := sys_dirlist ('./json-ld-api/tests/toRdf/', 1);
  files := __vector_sort (files);
  ses := string_output ();
  foreach (varchar tn in files) do
    {
      if (tn like '%.jsonld')
        {
          tn := regexp_replace (tn, '\-in.jsonld\x24', '');
          res := jtest_dump (tn);
          http (res, ses);
          http ('-----\n', ses);
        }
    }
  return ses;
}
;

create procedure jacts_dump (in tn varchar, in diff_only int := 1)
{
  declare i,o, gin, gout, dif varchar;
  declare r any;
  declare exit handler for sqlstate '*' {
    return concat ('SQL Error: ',tn,':',__sql_message);
  };
  r := string_output ();
  gin := concat ('urn:as:',tn);
  gout := concat ('urn:as:',tn, '-cmp');
  i := ((sparql define input:storage "" define output:format "NICE_TTL" construct { ?s ?p ?o } where { graph `iri(?:gin)` { ?s ?p ?o }}));
  o := ((sparql define input:storage "" define output:format "NICE_TTL" construct { ?s ?p ?o } where { graph `iri(?:gout)` { ?s ?p ?o }}));
  i := string_output_string (i);
  o := string_output_string (o);
  http (sprintf ('%s >>>\n', gout),r); 
  http (o, r);
  http (sprintf ('%s >>>\n', gin),r); 
  http (i, r);
  i := regexp_replace (i,'_:v?b[0-9]\+','_:vb00000');
  o := regexp_replace (o,'_:v?b[0-9]\+','_:vb00000');
  dif := diff (o, i);
  http ('--diff >>>\n',r); 
  http (dif,r);
  if (diff_only and length (dif))
    return concat (sprintf ('***FAILED: %s', tn), string_output_string (r));
  else
    return sprintf ('PASSED: %s', tn);
}
;

create procedure jacts_dump_results ()
{
  declare files any;
  declare res varchar;
  declare ses any;
  files := sys_dirlist ('./actstrm_tests/', 1);
  files := __vector_sort (files);
  ses := string_output ();
  result_names (res);
  foreach (varchar tn in files) do
    {
      if (tn like '%.json')
        {
          tn := regexp_replace (tn, '\-jsonld\.json\x24', '');
          tn := regexp_replace (tn, '\.json\x24', '');
          res := jacts_dump (tn);
          result (res);
          --http (res, ses);
          --http ('-----\n', ses);
        }
    }
  --return ses;
}
;

jacts_run_all();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON-LD tests run STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
jacts_dump_results();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON-LD results check STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

