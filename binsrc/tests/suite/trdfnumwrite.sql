--
--  trdfnumwrite.sql
--
--  Numeric literals in RDF serializations must read back with the datatype
--  they were stored with.
--
--  Turtle, TriG and TSV have an abbreviated syntax for numbers, and the
--  reader takes the datatype from its shape: 12000 is an xsd:integer, 12000.0
--  an xsd:decimal, 1.5e3 an xsd:double.  JSON-LD reads a JSON number without a
--  fraction as xsd:integer and one with a fraction as xsd:double.  The writers
--  printed an xsd:decimal with an integer value as 12000 and an xsd:double as
--  1500.0 (Turtle, TSV), and both as JSON numbers (JSON-LD).
--
--  Each section writes the same graph of eight numeric objects in one format,
--  reads it back where Virtuoso has a reader for that format, and counts the
--  objects that kept their datatype and value; the N-Triples and RDF/XML
--  round trips are guards (they were right before the fix).
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--

ECHO BOTH "STARTED: numeric literals in RDF serializations (trdfnumwrite.sql)\n";

SPARQL CLEAR GRAPH <urn:tnumw:in>;
SPARQL CLEAR GRAPH <urn:tnumw:out>;

DB.DBA.TTLP ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
<urn:tnumw:d1> <urn:tnumw:v> "12000"^^xsd:decimal .
<urn:tnumw:d2> <urn:tnumw:v> "2500.50"^^xsd:decimal .
<urn:tnumw:d3> <urn:tnumw:v> "-0.5"^^xsd:decimal .
<urn:tnumw:f1> <urn:tnumw:v> "1.5e3"^^xsd:double .
<urn:tnumw:f2> <urn:tnumw:v> "0.1"^^xsd:double .
<urn:tnumw:f3> <urn:tnumw:v> "1.0e300"^^xsd:double .
<urn:tnumw:i1> <urn:tnumw:v> 42 .
<urn:tnumw:i2> <urn:tnumw:v> -7 .
', '', 'urn:tnumw:in');

SPARQL SELECT COUNT (*) FROM <urn:tnumw:in> WHERE { ?s <urn:tnumw:v> ?o };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": the test graph holds 8 numeric objects\n";

-- The text of a SPARQL query run with define output:format "<fmt>".
create function TNUMW_FORMAT (in fmt varchar, in qry varchar) returns varchar
{
  declare st, msg, mdta, rset, r any;
  st := '00000';
  exec (sprintf ('sparql define output:format "%s" %s', fmt, qry), st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return sprintf ('error %s %s', st, msg);
  r := rset[0][0];
  if (__tag of stream = __tag (r))
    return string_output_string (r);
  return cast (r as varchar);
}
;

create function TNUMW_CONSTRUCT (in fmt varchar) returns varchar
{
  return TNUMW_FORMAT (fmt, 'construct { ?s ?p ?o } where { graph <urn:tnumw:in> { ?s ?p ?o } }');
}
;

-- TSV text of ?s ?p ?o rows (a header line, then values in Turtle syntax) as Turtle.
create function TNUMW_TSV_TO_TTL (in txt varchar) returns varchar
{
  declare nl integer;
  nl := strchr (txt, '\n');
  if (nl is null)
    return '';
  txt := subseq (txt, nl + 1);
  return replace (txt, '\n', ' .\n');
}
;

-- How many of the 8 objects a text in a Turtle-family syntax gives back
-- with the same datatype and value.
create function TNUMW_KEPT (in txt varchar, in flags integer := 0) returns integer
{
  declare n integer;
  declare exit handler for sqlstate '*' { return -1; };
  delete from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tnumw:out');
  DB.DBA.TTLP (txt, '', 'urn:tnumw:out', flags);
  n := (select count (*) from (sparql select ?s where {
          graph <urn:tnumw:in> { ?s <urn:tnumw:v> ?o }
          graph <urn:tnumw:out> { ?s <urn:tnumw:v> ?o2 }
          filter (datatype (?o) = datatype (?o2) && ?o = ?o2) }) x);
  return n;
}
;

-- How many of the 8 objects are given back, with the same datatype and
-- value, as the res:value of a Turtle result set (the subjects are not in it).
create function TNUMW_KEPT_VALUES (in txt varchar) returns integer
{
  declare n integer;
  declare exit handler for sqlstate '*' { return -1; };
  delete from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tnumw:out');
  DB.DBA.TTLP (txt, '', 'urn:tnumw:out');
  n := (select count (*) from (sparql select distinct ?s where {
          graph <urn:tnumw:in> { ?s <urn:tnumw:v> ?o }
          graph <urn:tnumw:out> { ?b <http://www.w3.org/2005/sparql-results#value> ?o2 }
          filter (datatype (?o) = datatype (?o2) && ?o = ?o2) }) x);
  return n;
}
;

-- The same for a JSON-LD text, read back with Virtuoso's JSON-LD loader.
create function TNUMW_KEPT_JSON_LD (in txt varchar) returns integer
{
  declare n integer;
  declare exit handler for sqlstate '*' { return -1; };
  delete from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tnumw:out');
  DB.DBA.RDF_LOAD_JSON_LD (txt, '', 'urn:tnumw:out');
  n := (select count (*) from (sparql select ?s where {
          graph <urn:tnumw:in> { ?s <urn:tnumw:v> ?o }
          graph <urn:tnumw:out> { ?s <urn:tnumw:v> ?o2 }
          filter (datatype (?o) = datatype (?o2) && ?o = ?o2) }) x);
  return n;
}
;

-- The SPARQL TSV results the /sparql endpoint writes for ?s ?p ?o.
create function TNUMW_ENDPOINT_TSV () returns varchar
{
  declare st, msg, mdta, rset, ses any;
  st := '00000';
  exec ('sparql select ?s ?p ?o where { graph <urn:tnumw:in> { ?s ?p ?o } }', st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return sprintf ('error %s %s', st, msg);
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_TSV_WRITE (ses, mdta, rset);
  return string_output_string (ses);
}
;

-- The Turtle result set the /sparql endpoint writes for a SELECT of ?o.
create function TNUMW_ENDPOINT_TTL () returns varchar
{
  declare st, msg, mdta, rset, ses any;
  st := '00000';
  exec ('sparql select ?o where { graph <urn:tnumw:in> { ?s ?p ?o } }', st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return sprintf ('error %s %s', st, msg);
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_TTL_WRITE_NS (ses);
  DB.DBA.SPARQL_RESULTS_TTL_WRITE_HEAD (ses, mdta);
  DB.DBA.SPARQL_RESULTS_TTL_WRITE_RES (ses, mdta, rset);
  return string_output_string (ses);
}
;

--------------------------------------------------------------------------
-- 1. N-Triples and RDF/XML always write the datatype (guards).
--------------------------------------------------------------------------

select TNUMW_KEPT (TNUMW_CONSTRUCT ('NT'));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": N-Triples reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

create function TNUMW_KEPT_RDFXML (in txt varchar) returns integer
{
  declare n integer;
  declare exit handler for sqlstate '*' { return -1; };
  delete from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tnumw:out');
  DB.DBA.RDF_LOAD_RDFXML (txt, '', 'urn:tnumw:out');
  n := (select count (*) from (sparql select ?s where {
          graph <urn:tnumw:in> { ?s <urn:tnumw:v> ?o }
          graph <urn:tnumw:out> { ?s <urn:tnumw:v> ?o2 }
          filter (datatype (?o) = datatype (?o2) && ?o = ?o2) }) x);
  return n;
}
;

select TNUMW_KEPT_RDFXML (TNUMW_CONSTRUCT ('RDF/XML'));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": RDF/XML reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 2. Turtle, nice Turtle and TriG: 12000.0 for an xsd:decimal, an exponent
--    for an xsd:double.
--------------------------------------------------------------------------

select TNUMW_KEPT (TNUMW_CONSTRUCT ('TTL'));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": Turtle reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

select TNUMW_KEPT (TNUMW_CONSTRUCT ('NICE_TTL'));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": nice Turtle reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

select TNUMW_KEPT (TNUMW_CONSTRUCT ('TRIG'), 256);
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": TriG reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

select case when regexp_match ('[\t ]12000[.]0[\t ]', TNUMW_CONSTRUCT ('TTL')) is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Turtle writes the xsd:decimal 12000 as 12000.0\n";

-- The endpoint writes a SELECT as a Turtle result set (res:value) with the same writer.
select TNUMW_KEPT_VALUES (TNUMW_ENDPOINT_TTL ());
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": the endpoint's Turtle result set gives back all 8 numbers with their datatype, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 3. TSV: a CONSTRUCT, a SELECT, and the /sparql endpoint's results writer.
--------------------------------------------------------------------------

select TNUMW_KEPT (TNUMW_TSV_TO_TTL (TNUMW_CONSTRUCT ('TSV')));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": TSV of a CONSTRUCT reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

select TNUMW_KEPT (TNUMW_TSV_TO_TTL (TNUMW_FORMAT ('TSV', 'select ?s ?p ?o where { graph <urn:tnumw:in> { ?s ?p ?o } }')));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": TSV of a SELECT reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

select TNUMW_KEPT (TNUMW_TSV_TO_TTL (TNUMW_ENDPOINT_TSV ()));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": the endpoint's TSV results read back all 8 numbers with their datatype, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 4. JSON-LD: a JSON number only for an xsd:integer; any other number is a
--    value object with a string @value and its @type.
--------------------------------------------------------------------------

select case when strstr (TNUMW_CONSTRUCT ('JSON;LD'), '"@value" : "12000" , "@type" : "http://www.w3.org/2001/XMLSchema#decimal"') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD writes the xsd:decimal 12000 as a typed value object\n";

select case when strstr (TNUMW_CONSTRUCT ('JSON;LD'), '"@value" : "2500.5" , "@type" : "http://www.w3.org/2001/XMLSchema#decimal"') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD writes the xsd:decimal 2500.5 as a typed value object, not as a JSON number (xsd:double)\n";

select case when strstr (TNUMW_CONSTRUCT ('JSON;LD'), '"@value" : "1500" , "@type" : "http://www.w3.org/2001/XMLSchema#double"') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD writes the xsd:double 1500 as a typed value object, not as a JSON integer\n";

select case when regexp_match (': 42[^0-9.eE"]', TNUMW_CONSTRUCT ('JSON;LD')) is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD still writes the xsd:integer 42 as a JSON number\n";

select TNUMW_KEPT_JSON_LD (TNUMW_CONSTRUCT ('JSON;LD'));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": JSON-LD reads back all 8 numbers with their datatype, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 5. cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:tnumw:in>;
SPARQL CLEAR GRAPH <urn:tnumw:out>;

ECHO BOTH "COMPLETED: numeric literals in RDF serializations (trdfnumwrite.sql)\n";
