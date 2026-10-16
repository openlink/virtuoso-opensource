--
--  trdfdur.sql
--
--  xsd:duration, dayTimeDuration and yearMonthDuration: lexical form on output and in the client,
--  BIND, casts, STRDT, INSERT/DELETE, lookup by value, comparison and index consistency
--

echo both "xsd:duration tests\n";

sparql clear graph <urn:tdur>;

ttlp ('@prefix ex: <http://example.org/> . @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
ex:a ex:val "P18Y3M"^^xsd:duration .
ex:b ex:val "PT4M57.56S"^^xsd:duration .
ex:c ex:val "PT0.6S"^^xsd:duration .
ex:d ex:val "PT1S"^^xsd:duration .
ex:e ex:val "P1Y2M3DT4H5M6.5S"^^xsd:duration .
ex:f ex:val "P3D"^^xsd:duration .
ex:g ex:val "PT1S"^^xsd:dayTimeDuration .
ex:h ex:val "P1Y"^^xsd:yearMonthDuration .
ex:z ex:val "PT0S"^^xsd:duration .
ex:n ex:val "-P1DT1H1M1.25S"^^xsd:duration .
', '', 'urn:tdur');
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": load durations STATE=" $state "\n";

-- str() of stored values

create procedure tdur_str (in s varchar)
{
  declare sid any;
  sid := iri_to_id (concat ('http://example.org/', s));
  return (select cast (__rdf_strsqlval (O) as varchar) from DB.DBA.RDF_QUAD
    where G = iri_to_id ('urn:tdur') and S = sid);
}
;

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/a> ?p ?o } };
echo both $if $equ $last[1] "P18Y3M" "PASSED" "***FAILED";
echo both ": str P18Y3M : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/b> ?p ?o } };
echo both $if $equ $last[1] "PT4M57.56S" "PASSED" "***FAILED";
echo both ": str PT4M57.56S : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/c> ?p ?o } };
echo both $if $equ $last[1] "PT0.6S" "PASSED" "***FAILED";
echo both ": str PT0.6S : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/d> ?p ?o } };
echo both $if $equ $last[1] "PT1S" "PASSED" "***FAILED";
echo both ": str PT1S : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/e> ?p ?o } };
echo both $if $equ $last[1] "P1Y2M3DT4H5M6.5S" "PASSED" "***FAILED";
echo both ": str P1Y2M3DT4H5M6.5S : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/f> ?p ?o } };
echo both $if $equ $last[1] "P3D" "PASSED" "***FAILED";
echo both ": str P3D : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/g> ?p ?o } };
echo both $if $equ $last[1] "PT1S" "PASSED" "***FAILED";
echo both ": str dayTimeDuration PT1S : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/h> ?p ?o } };
echo both $if $equ $last[1] "P1Y" "PASSED" "***FAILED";
echo both ": str yearMonthDuration P1Y : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/z> ?p ?o } };
echo both $if $equ $last[1] "PT0S" "PASSED" "***FAILED";
echo both ": str PT0S : " $last[1] "\n";

sparql select str(?o) where { graph <urn:tdur> { <http://example.org/n> ?p ?o } };
echo both $if $equ $last[1] "-P1DT1H1M1.25S" "PASSED" "***FAILED";
echo both ": str -P1DT1H1M1.25S : " $last[1] "\n";

select tdur_str ('b');
echo both $if $equ $last[1] "PT4M57.56S" "PASSED" "***FAILED";
echo both ": __rdf_strsqlval PT4M57.56S : " $last[1] "\n";

-- values stored by older builds: integer months, integer seconds

select __rdf_strsqlval (rdf_box (219, sys_stat ('rb_type__xsd:duration'), 257, 0, 1));
echo both $if $equ $last[1] "P18Y3M" "PASSED" "***FAILED";
echo both ": legacy integer months duration : " $last[1] "\n";

select __rdf_strsqlval (rdf_box (12, sys_stat ('rb_type__xsd:yearMonthDuration'), 257, 0, 1));
echo both $if $equ $last[1] "P1Y" "PASSED" "***FAILED";
echo both ": legacy integer months yearMonthDuration : " $last[1] "\n";

select __rdf_strsqlval (rdf_box (5, sys_stat ('rb_type__xsd:dayTimeDuration'), 257, 0, 1));
echo both $if $equ $last[1] "PT5S" "PASSED" "***FAILED";
echo both ": integer seconds dayTimeDuration : " $last[1] "\n";

-- BIND of a constant

sparql select (str(?d) as ?s) where { bind ("P18Y3M"^^xsd:duration as ?d) };
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": bind P18Y3M rows : " $rowcnt "\n";
echo both $if $equ $last[1] "P18Y3M" "PASSED" "***FAILED";
echo both ": bind P18Y3M : " $last[1] "\n";

sparql select (str(?d) as ?s) where { bind ("P1Y2M3DT4H"^^xsd:duration as ?d) };
echo both $if $equ $last[1] "P1Y2M3DT4H" "PASSED" "***FAILED";
echo both ": bind P1Y2M3DT4H : " $last[1] "\n";

sparql select (str(?d) as ?s) where { bind ("PT1S"^^xsd:duration as ?d) };
echo both $if $equ $last[1] "PT1S" "PASSED" "***FAILED";
echo both ": bind PT1S : " $last[1] "\n";

-- result sets and serializations

create procedure tdur_xml_res (in s varchar)
{
  declare ses, sid any;
  ses := string_output ();
  sid := iri_to_id (concat ('http://example.org/', s));
  for (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur') and S = sid) do
    sparql_rset_xml_write_row (ses, vector ('o'), vector (O));
  return string_output_string (ses);
}
;

create procedure tdur_json_res (in s varchar)
{
  declare ses, v, sid any;
  ses := string_output ();
  sid := iri_to_id (concat ('http://example.org/', s));
  for (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur') and S = sid) do
    {
      v := O;
      DB.DBA.SPARQL_RESULTS_JSON_WRITE_TERM (ses, v);
    }
  return string_output_string (ses);
}
;

create procedure tdur_fmt (in fmt varchar, in pattern varchar)
{
  declare st, msg, meta, rows any;
  st := '00000';
  exec (sprintf ('sparql define output:format "%s" construct { ?s ?p ?o } where { graph <urn:tdur> { ?s ?p ?o } }', fmt),
      st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return msg;
  if (strstr (cast (rows[0][0] as varchar), pattern) is not null)
    return 'found';
  return 'not found';
}
;

select case when strstr (tdur_xml_res ('b'), '>PT4M57.56S</literal>') is not null then 'found' else 'not found' end;
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": XML result PT4M57.56S\n";

create procedure tdur_xml_bool ()
{
  declare ses any;
  ses := string_output ();
  sparql_rset_xml_write_row (ses, vector ('o'), vector (rdf_box (1, sys_stat ('rb_type__xsd:boolean'), 257, 0, 1)));
  return string_output_string (ses);
}
;

select case when strstr (tdur_xml_bool (), '>true</literal>') is not null then 'found' else 'not found' end;
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": XML result boolean printed once\n";

select case when strstr (tdur_json_res ('c'), '"value": "PT0.6S"') is not null then 'found' else 'not found' end;
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": JSON result PT0.6S\n";

select tdur_fmt ('TTL', '"PT4M57.56S"^^xsd:duration');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": TTL PT4M57.56S\n";

select tdur_fmt ('TTL', '"PT0.6S"^^xsd:duration');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": TTL PT0.6S\n";

select tdur_fmt ('TTL', '"P18Y3M"^^xsd:duration');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": TTL P18Y3M\n";

select tdur_fmt ('NT', '"PT4M57.56S"^^<http://www.w3.org/2001/XMLSchema#duration>');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": NT PT4M57.56S\n";

select tdur_fmt ('RDF/XML', '#duration">PT0.6S<');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": RDF/XML PT0.6S\n";

select tdur_fmt ('JSON', '"value" : "PT0.6S"');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": Talis JSON PT0.6S\n";

select tdur_fmt ('JSON;LD', '"@value" : "PT0.6S"');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": JSON-LD PT0.6S\n";

-- storage: INSERT/DELETE DATA, lookup by value, index consistency

sparql insert data { graph <urn:tdur> {
  <http://example.org/i1> <http://example.org/val> "P18Y3M"^^xsd:duration .
  <http://example.org/i2> <http://example.org/val> "P2D"^^xsd:duration .
  <http://example.org/i3> <http://example.org/val> "PT1S"^^xsd:dayTimeDuration } };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": insert data durations STATE=" $state "\n";

sparql insert { graph <urn:tdur> { <http://example.org/i4> <http://example.org/val> ?d } } where { bind ("P18Y3M"^^xsd:duration as ?d) };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": insert from bind STATE=" $state "\n";

sparql select ?s where { graph <urn:tdur> { ?s ?p "P18Y3M"^^xsd:duration } };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": lookup P18Y3M by value rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur> { ?s ?p ?o filter (?o = "P18Y3M"^^xsd:duration) } };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": filter = P18Y3M rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur> { ?s ?p "PT4M57.56S"^^xsd:duration } };
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": lookup PT4M57.56S by value rows : " $rowcnt "\n";

select count (distinct O) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur') and O in (
  (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur') and S = iri_to_id ('http://example.org/a')),
  (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur') and S = iri_to_id ('http://example.org/i1')),
  (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur') and S = iri_to_id ('http://example.org/i4')));
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": loaded and inserted P18Y3M share one object : " $last[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where __tag (O) = 195;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": no raw duration arrays in O : " $last[1] "\n";

select count (*) from DB.DBA.RDF_QUAD a where G = iri_to_id ('urn:tdur') and not exists
  (select 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD_POGS) where b.P = a.P and b.O = a.O and b.G = a.G and b.S = a.S);
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": every row found via POGS : " $last[1] "\n";

select count (*) from DB.DBA.RDF_QUAD a where G = iri_to_id ('urn:tdur') and not exists
  (select 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD_OP) where b.P = a.P and b.O = a.O);
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": every row found via OP : " $last[1] "\n";

sparql delete data { graph <urn:tdur> {
  <http://example.org/i1> <http://example.org/val> "P18Y3M"^^xsd:duration .
  <http://example.org/b> <http://example.org/val> "PT4M57.56S"^^xsd:duration } };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": delete data durations STATE=" $state "\n";

sparql select ?s where { graph <urn:tdur> { ?s ?p ?o filter (?s in (<http://example.org/i1>, <http://example.org/b>)) } };
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": deleted rows gone : " $rowcnt "\n";

select (select count (*) from DB.DBA.RDF_QUAD table option (index RDF_QUAD)) - (select count (*) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS));
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": RDF_QUAD and POGS counts agree : " $last[1] "\n";

sparql clear graph <urn:tdur>;

-- the three duration types, each written five ways: ttlp, INSERT DATA, INSERT from BIND, cast and STRDT

sparql clear graph <urn:tdur3>;

ttlp ('@prefix ex: <http://example.org/> . @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
ex:w1 ex:dur "P1Y2M3DT4H5M6S"^^xsd:duration ; ex:dtd "P3DT4H"^^xsd:dayTimeDuration ; ex:ymd "P1Y2M"^^xsd:yearMonthDuration .
', '', 'urn:tdur3');
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": types load STATE=" $state "\n";

sparql insert data { graph <urn:tdur3> {
  <http://example.org/w2> <http://example.org/dur> "P1Y2M3DT4H5M6S"^^xsd:duration ;
    <http://example.org/dtd> "P3DT4H"^^xsd:dayTimeDuration ; <http://example.org/ymd> "P1Y2M"^^xsd:yearMonthDuration } };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": types insert data STATE=" $state "\n";

sparql insert { graph <urn:tdur3> {
  <http://example.org/w3> <http://example.org/dur> ?a ; <http://example.org/dtd> ?b ; <http://example.org/ymd> ?c } }
  where { bind ("P1Y2M3DT4H5M6S"^^xsd:duration as ?a) bind ("P3DT4H"^^xsd:dayTimeDuration as ?b) bind ("P1Y2M"^^xsd:yearMonthDuration as ?c) };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": types insert from bind STATE=" $state "\n";

sparql insert { graph <urn:tdur3> {
  <http://example.org/w4> <http://example.org/dur> ?a ; <http://example.org/dtd> ?b ; <http://example.org/ymd> ?c } }
  where { bind (xsd:duration ("P1Y2M3DT4H5M6S") as ?a) bind (xsd:dayTimeDuration ("P3DT4H") as ?b) bind (xsd:yearMonthDuration ("P1Y2M") as ?c) };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": types insert from cast STATE=" $state "\n";

sparql insert { graph <urn:tdur3> {
  <http://example.org/w5> <http://example.org/dur> ?a ; <http://example.org/dtd> ?b ; <http://example.org/ymd> ?c } }
  where { bind (strdt ("P1Y2M3DT4H5M6S", xsd:duration) as ?a) bind (strdt ("P3DT4H", xsd:dayTimeDuration) as ?b) bind (strdt ("P1Y2M", xsd:yearMonthDuration) as ?c) };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": types insert from strdt STATE=" $state "\n";

create procedure tdur3_objects (in pname varchar)
{
  return (select sprintf ('%d of %d', count (distinct O), count (*)) from DB.DBA.RDF_QUAD
    where G = iri_to_id ('urn:tdur3') and P = iri_to_id (concat ('http://example.org/', pname)));
}
;

select tdur3_objects ('dur');
echo both $if $equ $last[1] "1 of 5" "PASSED" "***FAILED";
echo both ": duration written 5 ways is one object : " $last[1] "\n";

select tdur3_objects ('dtd');
echo both $if $equ $last[1] "1 of 5" "PASSED" "***FAILED";
echo both ": dayTimeDuration written 5 ways is one object : " $last[1] "\n";

select tdur3_objects ('ymd');
echo both $if $equ $last[1] "1 of 5" "PASSED" "***FAILED";
echo both ": yearMonthDuration written 5 ways is one object : " $last[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur3') and __tag (O) in (189, 190, 191, 195);
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": no plain duration numbers or arrays in O : " $last[1] "\n";

sparql select ?s where { graph <urn:tdur3> { ?s ?p "P1Y2M3DT4H5M6S"^^xsd:duration } };
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": lookup duration P1Y2M3DT4H5M6S rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur3> { ?s ?p "P3DT4H"^^xsd:dayTimeDuration } };
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": lookup dayTimeDuration P3DT4H rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur3> { ?s ?p "P1Y2M"^^xsd:yearMonthDuration } };
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": lookup yearMonthDuration P1Y2M rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur3> { ?s ?p ?o filter (?o = "P3DT4H"^^xsd:dayTimeDuration) } };
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": filter = dayTimeDuration P3DT4H rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur3> { ?s ?p ?o filter (?o = "P1Y2M"^^xsd:yearMonthDuration) } };
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both ": filter = yearMonthDuration P1Y2M rows : " $rowcnt "\n";

sparql select count (*) where { graph <urn:tdur3> { ?s <http://example.org/dur> ?o
  filter (str (?o) = "P1Y2M3DT4H5M6S" && datatype (?o) = xsd:duration) } };
echo both $if $equ $last[1] 5 "PASSED" "***FAILED";
echo both ": duration str and datatype kept : " $last[1] "\n";

sparql select count (*) where { graph <urn:tdur3> { ?s <http://example.org/dtd> ?o
  filter (str (?o) = "P3DT4H" && datatype (?o) = xsd:dayTimeDuration) } };
echo both $if $equ $last[1] 5 "PASSED" "***FAILED";
echo both ": dayTimeDuration str and datatype kept : " $last[1] "\n";

sparql select count (*) where { graph <urn:tdur3> { ?s <http://example.org/ymd> ?o
  filter (str (?o) = "P1Y2M" && datatype (?o) = xsd:yearMonthDuration) } };
echo both $if $equ $last[1] 5 "PASSED" "***FAILED";
echo both ": yearMonthDuration str and datatype kept : " $last[1] "\n";

-- what the ODBC client shows: the lexical form, not dvector(...) or the seconds

sparql select ?a ?b ?c where { graph <urn:tdur3> {
  <http://example.org/w1> <http://example.org/dur> ?a ; <http://example.org/dtd> ?b ; <http://example.org/ymd> ?c } };
echo both $if $equ $last[1] "P1Y2M3DT4H5M6S" "PASSED" "***FAILED";
echo both ": client shows stored duration : " $last[1] "\n";
echo both $if $equ $last[2] "P3DT4H" "PASSED" "***FAILED";
echo both ": client shows stored dayTimeDuration : " $last[2] "\n";
echo both $if $equ $last[3] "P1Y2M" "PASSED" "***FAILED";
echo both ": client shows stored yearMonthDuration : " $last[3] "\n";

sparql select ?a ?b ?c where { bind ("P1Y2M3DT4H5M6S"^^xsd:duration as ?a) bind ("P3DT4H"^^xsd:dayTimeDuration as ?b) bind ("P1Y2M"^^xsd:yearMonthDuration as ?c) };
echo both $if $equ $last[1] "P1Y2M3DT4H5M6S" "PASSED" "***FAILED";
echo both ": client shows bound duration : " $last[1] "\n";
echo both $if $equ $last[2] "P3DT4H" "PASSED" "***FAILED";
echo both ": client shows bound dayTimeDuration : " $last[2] "\n";
echo both $if $equ $last[3] "P1Y2M" "PASSED" "***FAILED";
echo both ": client shows bound yearMonthDuration : " $last[3] "\n";

sparql select ?a ?b ?c where { bind (xsd:duration ("PT0S") as ?a) bind (xsd:dayTimeDuration ("-P1DT2H") as ?b) bind (xsd:yearMonthDuration ("-P3M") as ?c) };
echo both $if $equ $last[1] "PT0S" "PASSED" "***FAILED";
echo both ": client shows cast duration PT0S : " $last[1] "\n";
echo both $if $equ $last[2] "-P1DT2H" "PASSED" "***FAILED";
echo both ": client shows cast dayTimeDuration -P1DT2H : " $last[2] "\n";
echo both $if $equ $last[3] "-P3M" "PASSED" "***FAILED";
echo both ": client shows cast yearMonthDuration -P3M : " $last[3] "\n";

select dvector (1e0, 2e0);
echo both $if $equ $last[1] "dvector(1.000000,2.000000)" "PASSED" "***FAILED";
echo both ": client shows a plain two-double vector as a vector : " $last[1] "\n";

-- the datatype of a cast or STRDT

sparql select (str (datatype (?a)) as ?x) (str (datatype (?b)) as ?y) (str (datatype (?c)) as ?z) where {
  bind (xsd:duration ("P2Y") as ?a) bind (xsd:dayTimeDuration ("PT5S") as ?b) bind (strdt ("P3M", xsd:yearMonthDuration) as ?c) };
echo both $if $equ $last[1] "http://www.w3.org/2001/XMLSchema#duration" "PASSED" "***FAILED";
echo both ": cast duration datatype : " $last[1] "\n";
echo both $if $equ $last[2] "http://www.w3.org/2001/XMLSchema#dayTimeDuration" "PASSED" "***FAILED";
echo both ": cast dayTimeDuration datatype : " $last[2] "\n";
echo both $if $equ $last[3] "http://www.w3.org/2001/XMLSchema#yearMonthDuration" "PASSED" "***FAILED";
echo both ": strdt yearMonthDuration datatype : " $last[3] "\n";

-- the same value under a different duration type is a different term

ttlp ('@prefix ex: <http://example.org/> . @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
ex:s1 ex:same "P1Y"^^xsd:duration . ex:s2 ex:same "P1Y"^^xsd:yearMonthDuration .
ex:s3 ex:same "PT5S"^^xsd:duration . ex:s4 ex:same "PT5S"^^xsd:dayTimeDuration .
', '', 'urn:tdur3');
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": same value load STATE=" $state "\n";

sparql select ?s where { graph <urn:tdur3> { ?s <http://example.org/same> "P1Y"^^xsd:duration } };
echo both $if $equ $last[1] "http://example.org/s1" "PASSED" "***FAILED";
echo both ": P1Y duration found as : " $last[1] "\n";
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": P1Y duration rows : " $rowcnt "\n";

sparql select ?s where { graph <urn:tdur3> { ?s <http://example.org/same> "P1Y"^^xsd:yearMonthDuration } };
echo both $if $equ $last[1] "http://example.org/s2" "PASSED" "***FAILED";
echo both ": P1Y yearMonthDuration found as : " $last[1] "\n";
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": P1Y yearMonthDuration rows : " $rowcnt "\n";

-- PT5S as duration and as dayTimeDuration are both an inline double, which compares by value only, so check the types instead

sparql select (str (datatype (?o)) as ?t) where { graph <urn:tdur3> { <http://example.org/s3> <http://example.org/same> ?o } };
echo both $if $equ $last[1] "http://www.w3.org/2001/XMLSchema#duration" "PASSED" "***FAILED";
echo both ": PT5S duration keeps its datatype : " $last[1] "\n";

sparql select (str (datatype (?o)) as ?t) where { graph <urn:tdur3> { <http://example.org/s4> <http://example.org/same> ?o } };
echo both $if $equ $last[1] "http://www.w3.org/2001/XMLSchema#dayTimeDuration" "PASSED" "***FAILED";
echo both ": PT5S dayTimeDuration keeps its datatype : " $last[1] "\n";

-- comparison and arithmetic

sparql select ("PT5S"^^xsd:dayTimeDuration < "PT6S"^^xsd:dayTimeDuration) ("P1Y"^^xsd:yearMonthDuration > "P11M"^^xsd:yearMonthDuration)
  ("P1Y2M"^^xsd:yearMonthDuration = "P14M"^^xsd:yearMonthDuration) ("P3DT4H"^^xsd:dayTimeDuration = xsd:dayTimeDuration ("PT76H"))
  where { };
echo both $if $equ $last[1] 1 "PASSED" "***FAILED";
echo both ": dayTimeDuration less than : " $last[1] "\n";
echo both $if $equ $last[2] 1 "PASSED" "***FAILED";
echo both ": yearMonthDuration greater than : " $last[2] "\n";
echo both $if $equ $last[3] 1 "PASSED" "***FAILED";
echo both ": yearMonthDuration P1Y2M equals P14M : " $last[3] "\n";
echo both $if $equ $last[4] 1 "PASSED" "***FAILED";
echo both ": dayTimeDuration P3DT4H equals cast PT76H : " $last[4] "\n";

sparql select (str ("2020-01-01T00:00:00"^^xsd:dateTime + "P3DT4H"^^xsd:dayTimeDuration) as ?d) where { };
echo both $if $equ $last[1] "2020-01-04T04:00:00" "PASSED" "***FAILED";
echo both ": dateTime plus dayTimeDuration : " $last[1] "\n";

-- serializations

create procedure tdur3_fmt (in fmt varchar, in pattern varchar)
{
  declare st, msg, meta, rows any;
  st := '00000';
  exec (sprintf ('sparql define output:format "%s" construct { ?s ?p ?o } where { graph <urn:tdur3> { ?s ?p ?o } }', fmt),
      st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return msg;
  if (strstr (cast (rows[0][0] as varchar), pattern) is not null)
    return 'found';
  return 'not found';
}
;

select tdur3_fmt ('TTL', '"P3DT4H"^^xsd:dayTimeDuration');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": TTL dayTimeDuration P3DT4H\n";

select tdur3_fmt ('TTL', '"P1Y2M"^^xsd:yearMonthDuration');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": TTL yearMonthDuration P1Y2M\n";

select tdur3_fmt ('TTL', '"P1Y2M3DT4H5M6S"^^xsd:duration');
echo both $if $equ $last[1] "found" "PASSED" "***FAILED";
echo both ": TTL duration P1Y2M3DT4H5M6S\n";

-- delete by value

sparql delete data { graph <urn:tdur3> {
  <http://example.org/w2> <http://example.org/dur> "P1Y2M3DT4H5M6S"^^xsd:duration ;
    <http://example.org/dtd> "P3DT4H"^^xsd:dayTimeDuration ; <http://example.org/ymd> "P1Y2M"^^xsd:yearMonthDuration } };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": types delete data STATE=" $state "\n";

sparql select ?p where { graph <urn:tdur3> { <http://example.org/w2> ?p ?o } };
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": types delete data rows left : " $rowcnt "\n";

sparql delete where { graph <urn:tdur3> { ?s <http://example.org/dur> "P1Y2M3DT4H5M6S"^^xsd:duration } };
sparql delete where { graph <urn:tdur3> { ?s <http://example.org/dtd> "P3DT4H"^^xsd:dayTimeDuration } };
sparql delete where { graph <urn:tdur3> { ?s <http://example.org/ymd> "P1Y2M"^^xsd:yearMonthDuration } };
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdur3') and P <> iri_to_id ('http://example.org/same');
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": types delete where rows left : " $last[1] "\n";

select (select count (*) from DB.DBA.RDF_QUAD table option (index RDF_QUAD)) - (select count (*) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS));
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": RDF_QUAD and POGS counts agree after types : " $last[1] "\n";

sparql clear graph <urn:tdur3>;

-- concat() over an unparsed duration literal
-- A duration literal whose lexical form does not parse is kept as its string.
-- concat() must treat it as that string, not reach into the rdf box as if the
-- box held a parsed value; the latter reads past the string and corrupts memory.

sparql clear graph <urn:tdurc>;
sparql insert data { graph <urn:tdurc> {
  <http://example.org/bad> <http://example.org/val> "notaduration"^^xsd:duration } };
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": store unparsed duration STATE=" $state "\n";

select concat ((select O from DB.DBA.RDF_QUAD
    where G = iri_to_id ('urn:tdurc') and S = iri_to_id ('http://example.org/bad')), 'x');
echo both $if $equ $last[1] "notadurationx" "PASSED" "***FAILED";
echo both ": SQL concat over unparsed duration : " $last[1] "\n";

sparql select (concat(?o, "x") as ?c) where { graph <urn:tdurc> { ?s ?p ?o } };
echo both $if $equ $last[1] "notadurationx" "PASSED" "***FAILED";
echo both ": SPARQL concat over stored unparsed duration : " $last[1] "\n";

sparql select (concat(strdt("notaduration", xsd:duration), "x") as ?c) where { };
echo both $if $equ $last[1] "notadurationx" "PASSED" "***FAILED";
echo both ": SPARQL concat over STRDT unparsed duration : " $last[1] "\n";

sparql select (concat("x", strdt("notaduration", xsd:duration)) as ?c) where { };
echo both $if $equ $last[1] "xnotaduration" "PASSED" "***FAILED";
echo both ": SPARQL concat before unparsed duration : " $last[1] "\n";

-- concat() of a parsed duration keeps its lexical form, not the stored number

sparql select (concat(?o, "|z") as ?c) where { bind("P1Y2M3DT4H5M6.5S"^^xsd:duration as ?o) };
echo both $if $equ $last[1] "P1Y2M3DT4H5M6.5S|z" "PASSED" "***FAILED";
echo both ": SPARQL concat of generic duration : " $last[1] "\n";

sparql select (concat(?o, "|z") as ?c) where { bind("PT1S"^^xsd:dayTimeDuration as ?o) };
echo both $if $equ $last[1] "PT1S|z" "PASSED" "***FAILED";
echo both ": SPARQL concat of dayTimeDuration : " $last[1] "\n";

sparql select (concat(?o, "|z") as ?c) where { bind("P1Y"^^xsd:yearMonthDuration as ?o) };
echo both $if $equ $last[1] "P1Y|z" "PASSED" "***FAILED";
echo both ": SPARQL concat of yearMonthDuration : " $last[1] "\n";

-- cast of a parsed duration to string keeps its lexical form

sparql select (xsd:string(?o) as ?c) where { bind("PT1S"^^xsd:dayTimeDuration as ?o) };
echo both $if $equ $last[1] "PT1S" "PASSED" "***FAILED";
echo both ": SPARQL xsd:string of dayTimeDuration : " $last[1] "\n";

sparql select (xsd:string(?o) as ?c) where { bind("P1Y"^^xsd:yearMonthDuration as ?o) };
echo both $if $equ $last[1] "P1Y" "PASSED" "***FAILED";
echo both ": SPARQL xsd:string of yearMonthDuration : " $last[1] "\n";

sparql clear graph <urn:tdurc>;

echo both "COMPLETED: xsd:duration tests\n";
