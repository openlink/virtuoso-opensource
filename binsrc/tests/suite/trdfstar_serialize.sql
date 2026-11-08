--
--  trdfstar_serialize.sql
--
--  RDF 1.2 triple terms written out by the Turtle, TriG and N-Triples
--  serializers.
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

ECHO BOTH "STARTED: RDF 1.2 triple term serialization tests (trdfstar_serialize.sql)\n";

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:bn>;

-- Serializes the triples of a graph the way a CONSTRUCT result is serialized.
create function TRDFSTAR_SER_WRITE (in fmt varchar, in graph_iri varchar) returns varchar
{
  declare triples, ses any;
  triples := (select vector_agg (vector (S, P, __ro2lo (O))) from DB.DBA.RDF_QUAD where G = iri_to_id (graph_iri));
  ses := string_output ();
  if (fmt = 'NT')
    DB.DBA.RDF_TRIPLES_TO_NT (triples, ses);
  else if (fmt = 'TTL')
    DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
  else if (fmt = 'TRIG')
    DB.DBA.RDF_TRIPLES_TO_TRIG (triples, ses);
  else if (fmt = 'NICE_TTL')
    DB.DBA.RDF_TRIPLES_TO_NICE_TTL (triples, ses);
  else if (fmt = 'HTML_NICE_TTL_BODY')
    DB.DBA.RDF_TRIPLES_TO_NICE_TTL_IMPL (triples, 257, ses);
  else
    signal ('22023', 'TRDFSTAR_SER_WRITE: unknown format');
  return string_output_string (ses);
}
;

-- How often a blank node label is written; a label is always followed by a
-- space or a tab, so a label that is a prefix of another is not counted.
create function TRDFSTAR_SER_LABEL_COUNT (in txt varchar, in label varchar) returns integer
{
  declare n integer;
  n := 0;
  foreach (varchar sep in vector (' ', '\t')) do
    n := n + (length (txt) - length (replace (txt, label || sep, ''))) / length (label || sep);
  return n;
}
;

-- The label the serializers give the blank node subject of the only triple
-- with predicate pred.
create function TRDFSTAR_SER_LABEL (in graph_iri varchar, in pred varchar) returns varchar
{
  return (select '_:v' || subseq (id_to_iri (S), 9) from DB.DBA.RDF_QUAD
    where G = iri_to_id (graph_iri) and P = iri_to_id (pred));
}
;

--------------------------------------------------------------------------
-- 1. A blank node inside a triple term.
--
--    It was written as an IRI, <nodeID://b...>, while the same node outside
--    the triple term was _:vb...: the written graph had an IRI where the
--    stored one has a blank node, unrelated to the node it stands for.
--------------------------------------------------------------------------

DB.DBA.TTLP ('@prefix : <http://example.com/ns#> .
_:b1 :first "one" .
_:b2 :second "two" .
:r rdf:reifies <<( _:b1 :p _:b2 )>> .
_:r2 rdf:reifies <<( :a :b _:b1 )>> .
:r3 rdf:reifies <<( :a :b <<( _:b1 :q _:b2 )>> )>> .
', '', 'urn:trdfstar_serialize:bn', 0);

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_serialize:bn');
echo both $if $equ $LAST[1] 5 "PASSED" "***FAILED";
echo both ": 1a the graph with blank nodes inside triple terms is loaded\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:bn'), '<nodeID:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 1b N-Triples writes no blank node as an <nodeID:...> IRI\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#first'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 1c N-Triples writes the subject, object and nested triple term blank node with the label it has outside them\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#second'));
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 1d N-Triples writes a triple term object blank node with the label it has outside it\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TTL', 'urn:trdfstar_serialize:bn'), '<nodeID:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 1e Turtle writes no blank node as an <nodeID:...> IRI\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('TTL', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#first'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 1f Turtle writes the blank node inside triple terms with the label it has outside them\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TRIG', 'urn:trdfstar_serialize:bn'), '<nodeID:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 1g TriG writes no blank node as an <nodeID:...> IRI\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('TRIG', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#first'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 1h TriG writes the blank node inside triple terms with the label it has outside them\n";

--------------------------------------------------------------------------
-- 2. A written graph with triple terms reads back as the same graph.
--
--    A triple term was written as << s p o >>, which RDF 1.2 Turtle and TriG
--    read as a reifying triple, a fresh reifier of the triple, and N-Triples
--    1.2 does not accept at all; and a blank node reifier was replaced by its
--    triple term wherever it was used, its rdf:reifies triple dropped.  So
--    :r rdf:reifies <<( :a :b :c )>> read back as :r rdf:reifies _:x .
--    _:x rdf:reifies <<( :a :b :c )>>, and a reifier used three times read
--    back as three reifiers.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt>;

DB.DBA.TTLP ('@prefix : <http://example.com/ns#> .
:r rdf:reifies <<( :a :b :c )>> .
:x :p <<( :a :b :e )>> .
_:r2 rdf:reifies <<( :a :b :d )>> .
_:r2 :src :x .
_:r2 :date "2020" .
:y :about _:r2 .
:r4 rdf:reifies <<( :a :b <<( :c :d :e )>> )>> .
', '', 'urn:trdfstar_serialize:rt', 0);

-- Writes a graph in fmt and loads the text into a second graph.
create procedure TRDFSTAR_SER_ROUND_TRIP (in fmt varchar, in graph_iri varchar, in copy_iri varchar)
{
  declare txt varchar;
  txt := TRDFSTAR_SER_WRITE (fmt, graph_iri);
  delete from DB.DBA.RDF_QUAD where G = iri_to_id (copy_iri);
  DB.DBA.TTLP (txt, '', copy_iri, case when fmt = 'TRIG' then 256 else 0 end);
}
;

-- The shape of the test graph: triples, rdf:reifies triples, triples with a
-- triple term object, whether :r reifies a triple term itself, and whether
-- one node is the reifier of <<( :a :b :d )>> in all four of its uses.
create function TRDFSTAR_SER_SHAPE (in graph_iri varchar) returns varchar
{
  declare gid, reifies, src, dt, about any;
  gid := iri_to_id (graph_iri);
  reifies := iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies');
  src := iri_to_id ('http://example.com/ns#src');
  dt := iri_to_id ('http://example.com/ns#date');
  about := iri_to_id ('http://example.com/ns#about');
  return sprintf ('%d %d %d %d %d',
    (select count (*) from DB.DBA.RDF_QUAD where G = gid),
    (select count (*) from DB.DBA.RDF_QUAD where G = gid and P = reifies),
    (select count (*) from DB.DBA.RDF_QUAD where G = gid and isiri_id (O) and id_to_iri (O) like 'urn:rdf-star:triple:%'),
    (select count (*) from DB.DBA.RDF_QUAD where G = gid and S = iri_to_id ('http://example.com/ns#r') and P = reifies
       and isiri_id (O) and id_to_iri (O) like 'urn:rdf-star:triple:%'),
    (select count (*) from DB.DBA.RDF_QUAD a, DB.DBA.RDF_QUAD b, DB.DBA.RDF_QUAD c, DB.DBA.RDF_QUAD d
       where a.G = gid and a.P = src and b.G = gid and b.S = a.S and b.P = dt
         and c.G = gid and c.O = a.S and c.P = about and d.G = gid and d.S = a.S and d.P = reifies));
}
;

select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2a the round trip test graph is loaded (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), '<<(') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "found" "PASSED" "***FAILED";
echo both ": 2b N-Triples writes a triple term as <<( s p o )>>\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), '<< ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2c N-Triples writes no reifying triple << s p o >>\n";

select case when "LEFT" (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), 2) = '<<'
  or strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), '\n<<') is not null then 'found' else 'none' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2d N-Triples writes no triple term as a subject\n";

TRDFSTAR_SER_ROUND_TRIP ('NT', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:nt');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:nt');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2e the N-Triples output reads back as the same graph (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TTL', 'urn:trdfstar_serialize:rt'), '<< ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2f Turtle writes a triple term as a triple term, not as a reifying triple << s p o >>\n";

TRDFSTAR_SER_ROUND_TRIP ('TTL', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:ttl');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:ttl');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2g the Turtle output reads back as the same graph (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TRIG', 'urn:trdfstar_serialize:rt'), '<< ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2h TriG writes a triple term as a triple term, not as a reifying triple << s p o >>\n";

TRDFSTAR_SER_ROUND_TRIP ('TRIG', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:trig');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:trig');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2i the TriG output reads back as the same graph (shape " $LAST[1] ")\n";

--------------------------------------------------------------------------
-- 3. A triple without a triple term written after one with a triple term.
--
--    The Turtle and TriG writers write a triple with a triple term in SQL
--    and the others with http_ttl_triple, closing the statement the latter
--    left open first; but they cleared the wrong slots of its state, so the
--    next triple it wrote began with a second " ." and the output did not
--    parse.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix>;

DB.DBA.TTLP ('@prefix : <http://example.com/ns#> .
:a1 :p "v" .
:a2 :p <<( :x :y :z )>> .
:a3 :p "w" .
', '', 'urn:trdfstar_serialize:mix', 0);

-- The number of triples the written text reads back as, -1 if it does not parse.
create function TRDFSTAR_SER_RELOAD_COUNT (in fmt varchar, in graph_iri varchar, in copy_iri varchar) returns integer
{
  declare exit handler for sqlstate '*' { return -1; };
  TRDFSTAR_SER_ROUND_TRIP (fmt, graph_iri, copy_iri);
  return (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id (copy_iri));
}
;

select TRDFSTAR_SER_RELOAD_COUNT ('TTL', 'urn:trdfstar_serialize:mix', 'urn:trdfstar_serialize:mix:ttl');
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 3a Turtle with a plain triple after a triple term triple reads back (" $LAST[1] " triples)\n";

select TRDFSTAR_SER_RELOAD_COUNT ('TRIG', 'urn:trdfstar_serialize:mix', 'urn:trdfstar_serialize:mix:trig');
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 3b TriG with a plain triple after a triple term triple reads back (" $LAST[1] " triples)\n";

--------------------------------------------------------------------------
-- 4. The "nice" Turtle writer and triple terms.
--
--    DB.DBA.RDF_TRIPLES_TO_NICE_TTL (application/x-nice-turtle, DAV RDF
--    resources) and the body of the HTML Turtle page, which
--    RDF_TRIPLES_TO_HTML_NICE_TTL writes with RDF_TRIPLES_TO_NICE_TTL_IMPL,
--    have no triple term syntax: a triple term was written as its internal
--    IRI, a prefixed name like ns2:i1234 of an @prefix
--    <urn:rdf-star:triple:...:>, which other stores read as an unrelated IRI.
--------------------------------------------------------------------------

select case when strstr (TRDFSTAR_SER_WRITE ('NICE_TTL', 'urn:trdfstar_serialize:rt'), 'urn:rdf-star:triple:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 4a nice Turtle writes no internal triple term IRI\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NICE_TTL', 'urn:trdfstar_serialize:rt'), '<<( ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "found" "PASSED" "***FAILED";
echo both ": 4b nice Turtle writes a triple term as <<( s p o )>>\n";

TRDFSTAR_SER_ROUND_TRIP ('NICE_TTL', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:nice');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:nice');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 4c the nice Turtle output reads back as the same graph (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('HTML_NICE_TTL_BODY', 'urn:trdfstar_serialize:rt'), 'urn:rdf-star:triple:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 4d the HTML nice Turtle page body writes no internal triple term IRI\n";

select case when strstr (TRDFSTAR_SER_WRITE ('HTML_NICE_TTL_BODY', 'urn:trdfstar_serialize:rt'), '&lt;&lt;( ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "found" "PASSED" "***FAILED";
echo both ": 4e the HTML nice Turtle page body writes a triple term as <<( s p o )>>, escaped\n";

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:nice>;
DB.DBA.TTLP ('@prefix : <http://example.com/ns#> . :s :p [ :q "x" ] .', '', 'urn:trdfstar_serialize:nice', 0);

select case when strstr (TRDFSTAR_SER_WRITE ('NICE_TTL', 'urn:trdfstar_serialize:nice'), '[') is not null
  and strstr (TRDFSTAR_SER_WRITE ('NICE_TTL', 'urn:trdfstar_serialize:nice'), '_:vb') is null then 'nice' else 'plain' end;
echo both $if $equ $LAST[1] "nice" "PASSED" "***FAILED";
echo both ": 4f nice Turtle of a graph without triple terms still nests a blank node object in [ ]\n";

--------------------------------------------------------------------------
-- 5. Triple terms and literals in TSV results.
--
--    define output:format "TSV" (DB.DBA.RDF_FORMAT_RESULT_SET_AS_TSV_ACC)
--    had no triple term syntax and wrote a triple term as its internal IRI;
--    and the TSV writers of the SPARQL endpoint (SPARQL_RESULTS_TSV_WRITE_ROW,
--    and _STREAM_ROW for a streamed result) guessed from its text whether a
--    string was an IRI, so a literal that
--    looks like one, such as STR(<http://ex/a>), was written as the IRI
--    <http://ex/a>, where it was "http://ex/a" before RDF 1.2 support.
--------------------------------------------------------------------------

-- The text a SPARQL query with an output:format define returns.
create function TRDFSTAR_SER_SPARQL_TEXT (in qry varchar) returns varchar
{
  declare st, msg, mdta, rset any;
  st := '00000';
  exec (qry, st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return 'error ' || st || ': ' || msg;
  return cast (rset[0][0] as varchar);
}
;

-- The TSV the SPARQL endpoint writes for a value in a one column result.
create function TRDFSTAR_SER_TSV_ROW (in val any) returns varchar
{
  declare ses any;
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_TSV_WRITE_ROW (ses, vector (vector (vector ('x'))), vector (val));
  return string_output_string (ses);
}
;

select case when strstr (txt, '<<(<http://example.com/ns#a> <http://example.com/ns#b> <http://example.com/ns#c>)>>') is not null
  and strstr (txt, 'urn:rdf-star:triple:') is null then 'ok' else txt end
  from (select TRDFSTAR_SER_SPARQL_TEXT ('sparql define output:format "TSV" select ?o from <urn:trdfstar_serialize:rt> where { <http://example.com/ns#r> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> ?o }') as txt) as x;
echo both $if $equ $LAST[1] "ok" "PASSED" "***FAILED";
echo both ": 5a define output:format TSV writes a triple term as <<( s p o )>>\n";

select case when strstr (txt, '<<(<http://example.com/ns#a> <http://example.com/ns#b> <<(<http://example.com/ns#c> <http://example.com/ns#d> <http://example.com/ns#e>)>>)>>') is not null
  and strstr (txt, 'urn:rdf-star:triple:') is null then 'ok' else txt end
  from (select TRDFSTAR_SER_SPARQL_TEXT ('sparql define output:format "TSV" select ?o from <urn:trdfstar_serialize:rt> where { <http://example.com/ns#r4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> ?o }') as txt) as x;
echo both $if $equ $LAST[1] "ok" "PASSED" "***FAILED";
echo both ": 5b define output:format TSV writes a nested triple term as <<( s p <<( s p o )>> )>>\n";

-- The TSV the SPARQL endpoint streams for a value in a one column result.
create function TRDFSTAR_SER_TSV_STREAM_ROW (in val any) returns varchar
{
  declare ses, metas, env, row any;
  ses := string_output ();
  metas := vector (vector (vector ('x')));
  env := 0;
  row := vector (val);
  DB.DBA.SPARQL_RESULTS_TSV_STREAM_ROW (ses, metas, env, row, 0);
  return string_output_string (ses);
}
;

select case when strstr (TRDFSTAR_SER_SPARQL_TEXT ('sparql define output:format "TSV" select (str (<http://ex/a>) as ?x) {}'), '"http://ex/a"') is not null then 'literal' else 'other' end;
echo both $if $equ $LAST[1] "literal" "PASSED" "***FAILED";
echo both ": 5c define output:format TSV writes STR(<http://ex/a>) as a literal\n";

select case when strstr (TRDFSTAR_SER_TSV_ROW ('http://ex/a'), '"http://ex/a"') is not null then 'literal' else TRDFSTAR_SER_TSV_ROW ('http://ex/a') end;
echo both $if $equ $LAST[1] "literal" "PASSED" "***FAILED";
echo both ": 5d the endpoint TSV writes a string that looks like an IRI as a literal\n";

select case when strstr (TRDFSTAR_SER_TSV_ROW (iri_to_id ('http://ex/a')), '<http://ex/a>') is not null then 'iri' else 'other' end;
echo both $if $equ $LAST[1] "iri" "PASSED" "***FAILED";
echo both ": 5e the endpoint TSV writes an IRI as an IRI\n";

select case when strstr (TRDFSTAR_SER_TSV_ROW ((select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_serialize:rt') and S = iri_to_id ('http://example.com/ns#r'))),
  '<<(<http://example.com/ns#a> <http://example.com/ns#b> <http://example.com/ns#c>)>>') is not null then 'tt' else 'other' end;
echo both $if $equ $LAST[1] "tt" "PASSED" "***FAILED";
echo both ": 5f the endpoint TSV writes a triple term as <<( s p o )>>\n";

select "LEFT" (TRDFSTAR_SER_TSV_ROW ((select S from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_serialize:rt') and P = iri_to_id ('http://example.com/ns#src'))), 4);
echo both $if $equ $LAST[1] "_:vb" "PASSED" "***FAILED";
echo both ": 5g the endpoint TSV writes a blank node as _:vb...\n";

select case when strstr (TRDFSTAR_SER_TSV_STREAM_ROW ('http://ex/a'), '"http://ex/a"') is not null then 'literal' else TRDFSTAR_SER_TSV_STREAM_ROW ('http://ex/a') end;
echo both $if $equ $LAST[1] "literal" "PASSED" "***FAILED";
echo both ": 5h the streamed endpoint TSV writes a string that looks like an IRI as a literal\n";

select case when strstr (TRDFSTAR_SER_TSV_STREAM_ROW ((select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_serialize:rt') and S = iri_to_id ('http://example.com/ns#r'))),
  '<<(<http://example.com/ns#a> <http://example.com/ns#b> <http://example.com/ns#c>)>>') is not null then 'tt' else 'other' end;
echo both $if $equ $LAST[1] "tt" "PASSED" "***FAILED";
echo both ": 5i the streamed endpoint TSV writes a triple term as <<( s p o )>>\n";

select case when strstr (TRDFSTAR_SER_TSV_ROW (vector (iri_to_id ('http://example.com/ns#a'), iri_to_id ('http://example.com/ns#b'), iri_to_id ('http://example.com/ns#c'))),
  '<<(<http://example.com/ns#a> <http://example.com/ns#b> <http://example.com/ns#c>)>>') is not null then 'tt' else 'other' end;
echo both $if $equ $LAST[1] "tt" "PASSED" "***FAILED";
echo both ": 5j the endpoint TSV writes a TRIPLE() vector as <<( s p o )>>\n";

--------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:bn>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:nt>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:trig>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix:ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix:trig>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:nice>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:nice>;

ECHO BOTH "COMPLETED: RDF 1.2 triple term serialization tests (trdfstar_serialize.sql)\n";
