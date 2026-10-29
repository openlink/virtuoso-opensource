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

--
-- A document big enough that the vectored loader sends quads to the store while
-- it is still parsing: DB.DBA.TTLP_RL_TRIPLE_L sends a batch once the dpipe holds
-- more than 30 MB, about 90,000 short quads.  The JSON-LD loader never gave the
-- triple feed its graph, so the callbacks got graph 0, that batch failed with
-- SR130 and the load stopped part way.
--
create function TJSONLD_BIG_DOC (in n integer) returns varchar
{
  declare ses any;
  declare i integer;
  ses := string_output ();
  http ('{ "@context": { "v": { "@id": "urn:tjsonld:big:v" } }, "@graph": [', ses);
  for (i := 0; i < n; i := i + 1)
    http (sprintf ('%s{ "@id": "urn:tjsonld:big:s%d", "v": [ "a%d", "b%d" ] }', case when i > 0 then ',' else '' end, i, i, i), ses);
  http (' ] }', ses);
  return string_output_string (ses);
}
;

SPARQL CLEAR GRAPH <urn:tjsonld:big>;
DB.DBA.RDF_LOAD_JSON_LD (TJSONLD_BIG_DOC (60000), '', 'urn:tjsonld:big');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": a JSON-LD document of 120000 quads, sent to the store while parsing, loads STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tjsonld:big');
ECHO BOTH $IF $EQU $LAST[1] 120000 "PASSED" "***FAILED";
ECHO BOTH ": all 120000 quads of the big JSON-LD document are in its graph, got " $LAST[1] "\n";

SPARQL CLEAR GRAPH <urn:tjsonld:big>;

--
-- The parser keeps its working memory in the thread's temp pool and ran the
-- triple callbacks inside it, so SQL in a callback saw the parser's pool.
-- json_parse () in a callback started a pool of its own over it ("MP
-- reallocated"), and a vectored insert in a callback (insert ... select)
-- cleared the thread's pool, so the parser then had none for its next
-- allocation.
--
create procedure TJSONLD_CB_JSON (inout g_iid any, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar, inout app_env any)
{
  dict_put (app_env, vector (s_uri, p_uri, o_val), length (json_parse ('{ "k": [ 1, 2 ] }')));
}
;

create table TJSONLD_CB_LOG (S varchar primary key)
;

create procedure TJSONLD_CB_INSERT (inout g_iid any, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar, inout app_env any)
{
  insert soft TJSONLD_CB_LOG (S) select s_uri from DB.DBA.SYS_USERS where U_NAME = 'dba';
  dict_put (app_env, vector (s_uri, p_uri, o_val), 1);
}
;

-- loads three triples through the given literal callback, returns how many it got
create function TJSONLD_CB_LOAD (in cb varchar) returns integer
{
  declare d any;
  d := dict_new ();
  rdf_load_jsonld ('{ "@graph": [ { "@id": "urn:tjsonld:cb:s1", "urn:tjsonld:cb:p": "one" },
    { "@id": "urn:tjsonld:cb:s2", "urn:tjsonld:cb:p": "two" },
    { "@id": "urn:tjsonld:cb:s3", "urn:tjsonld:cb:p": 3.5 } ] }', '', 'urn:tjsonld:cb', 0,
    vector ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH', 'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK', 'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE', cb, '', 'DB.DBA.TTLP_EV_REPORT_DEFAULT'), d);
  return dict_size (d);
}
;

select TJSONLD_CB_LOAD ('DB.DBA.TJSONLD_CB_JSON');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": a JSON-LD triple callback that calls json_parse () gets all 3 triples, got " $LAST[1] "\n";

select TJSONLD_CB_LOAD ('DB.DBA.TJSONLD_CB_INSERT');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": a JSON-LD triple callback that runs insert ... select gets all 3 triples, got " $LAST[1] "\n";

select count (*) from TJSONLD_CB_LOG;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": the insert ... select callback stored a row for each subject, got " $LAST[1] "\n";

drop table TJSONLD_CB_LOG;

jacts_run_all();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON-LD tests run STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
jacts_dump_results();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON-LD results check STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


--
-- Native JSON numbers.  JSON-LD 1.1 (toRdf, Object to RDF Conversion) makes
-- a number with a non-zero fractional part, or of 10^21 or more, an
-- xsd:double, and any other number an xsd:integer; JSON itself has no
-- decimal type.  The loader made a number with an exponent an xsd:string
-- (a stray break in jsonld.y) and a number with a '.' an xsd:decimal.
--
SPARQL CLEAR GRAPH <urn:tjsonld:num>;
DB.DBA.RDF_LOAD_JSON_LD ('{ "@context": { "v": { "@id": "urn:tjsonld:v" } }, "@graph": [
  { "@id": "urn:tjsonld:int", "v": 12000 },
  { "@id": "urn:tjsonld:frac", "v": 2500.5 },
  { "@id": "urn:tjsonld:exp", "v": 2.25e0 },
  { "@id": "urn:tjsonld:expint", "v": 1.5e3 },
  { "@id": "urn:tjsonld:zero", "v": 2.0 },
  { "@id": "urn:tjsonld:huge", "v": 1e21 },
  { "@id": "urn:tjsonld:arr", "v": [ 7, 0.5 ] },
  { "@id": "urn:tjsonld:typed", "v": { "@value": 5, "@type": "http://www.w3.org/2001/XMLSchema#int" } } ] }', '', 'urn:tjsonld:num');

-- datatype and value of the objects of one subject, sorted, as text
create function TJSONLD_NUM (in subj_iri varchar) returns varchar
{
  declare st, msg, mdta, rset any;
  declare inx integer;
  declare res varchar;
  st := '00000';
  exec (sprintf ('sparql select (str (datatype (?o)) as ?dt) (str (?o) as ?lex) from <urn:tjsonld:num> where { <%s> <urn:tjsonld:v> ?o } order by str (?o)', subj_iri),
    st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return 'error ' || st;
  res := '';
  for (inx := 0; inx < length (rset); inx := inx + 1)
    res := res || case when inx > 0 then ' ' else '' end || subseq (rset[inx][0], 33) || ':' || rset[inx][1];
  return res;
}
;

select TJSONLD_NUM ('urn:tjsonld:int');
ECHO BOTH $IF $EQU $LAST[1] "integer:12000" "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD number 12000 loads as an xsd:integer, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:typed');
ECHO BOTH $IF $EQU $LAST[1] "int:5" "PASSED" "***FAILED";
ECHO BOTH ": a number with an explicit @type keeps it, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:exp');
ECHO BOTH $IF $EQU $LAST[1] "double:2.25" "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD number 2.25e0 loads as an xsd:double, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:frac');
ECHO BOTH $IF $EQU $LAST[1] "double:2500.5" "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD number 2500.5 loads as an xsd:double, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:expint');
ECHO BOTH $IF $EQU $LAST[1] "integer:1500" "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD number 1.5e3, no fraction, loads as the xsd:integer 1500, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:zero');
ECHO BOTH $IF $EQU $LAST[1] "integer:2" "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD number 2.0 loads as the xsd:integer 2, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:huge');
ECHO BOTH $IF $EQU $LAST[1] "double:1e+21" "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD number 1e21 loads as an xsd:double, got " $LAST[1] "\n";

select TJSONLD_NUM ('urn:tjsonld:arr');
ECHO BOTH $IF $EQU $LAST[1] "double:0.5 integer:7" "PASSED" "***FAILED";
ECHO BOTH ": an array [7, 0.5] loads an xsd:integer and an xsd:double, got " $LAST[1] "\n";

SPARQL CLEAR GRAPH <urn:tjsonld:num>;
