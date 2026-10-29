--
--  tsparul_load.sql
--
--  SPARQL 1.2 Update LOAD of an RDF dataset: TriG and N-Quads documents,
--  with and without INTO GRAPH.
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

ECHO BOTH "STARTED: SPARQL LOAD of RDF datasets (tsparul_load.sql)\n";

-- The documents, served by the DAV of this server with their media types.
DB.DBA.DAV_COL_CREATE ('/DAV/tsparul_load/', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsparul_load/ds.trig', '@prefix : <http://example.com/tsparul_load/> .
:d1 :p "in the default graph" .
GRAPH <urn:tsparul_load:one> { :n1 :p "in named graph one" . }
<urn:tsparul_load:two> { :n2 :p "in named graph two" . }
', 'application/trig', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsparul_load/ds_x.trig', '@prefix : <http://example.com/tsparul_load/> .
:xd1 :p "in the default graph" .
GRAPH <urn:tsparul_load:x:one> { :xn1 :p "in named graph one" . }
', 'application/x-trig', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsparul_load/ds.nq', '<http://example.com/tsparul_load/q1> <http://example.com/tsparul_load/p> "default quad" .
<http://example.com/tsparul_load/q2> <http://example.com/tsparul_load/p> "named quad" <urn:tsparul_load:nq> .
', 'application/n-quads', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsparul_load/dflt.trig', '@prefix : <http://example.com/tsparul_load/> .
:t1 :p "outside braces" .
{ :t2 :p "in a default graph block" . }
', 'application/trig', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsparul_load/dflt.nq', '<http://example.com/tsparul_load/u1> <http://example.com/tsparul_load/p> "default quad only" .
', 'application/n-quads', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsparul_load/plain.ttl', '@prefix : <http://example.com/tsparul_load/> .
:v1 :p "turtle" .
', 'text/turtle', '110100100R', 'dav', 'dav', 'dav', 'dav');

select count (*) from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/tsparul_load/%';
echo both $if $equ $LAST[1] 6 "PASSED" "***FAILED";
echo both ": the six documents are in DAV\n";

-- The URL of a document; the HTTP server port may be given with a host.
create function TSPARUL_LOAD_URL (in doc varchar) returns varchar
{
  declare hp varchar;
  hp := cast (server_http_port () as varchar);
  if (strchr (hp, ':') is null)
    hp := 'localhost:' || hp;
  return 'http://' || hp || '/DAV/tsparul_load/' || doc;
}
;

-- SPARQL LOAD of a document, INTO GRAPH target unless target is NULL, into
-- emptied graphs: 'OK', or the SQL state and message of the error.
create function TSPARUL_LOAD (in doc varchar, in target varchar := null) returns varchar
{
  declare st, msg varchar;
  foreach (varchar gr in vector (coalesce (target, TSPARUL_LOAD_URL (doc)),
    'urn:tsparul_load:one', 'urn:tsparul_load:two', 'urn:tsparul_load:x:one', 'urn:tsparul_load:nq')) do
    delete from DB.DBA.RDF_QUAD where G = iri_to_id (gr);
  commit work;
  st := '00000';
  if (target is null)
    exec (sprintf ('sparql load <%s>', TSPARUL_LOAD_URL (doc)), st, msg);
  else
    exec (sprintf ('sparql load <%s> into graph <%s>', TSPARUL_LOAD_URL (doc), target), st, msg);
  if ('00000' = st)
    return 'OK';
  return st || ': ' || msg;
}
;

-- The number of triples in a graph.
create function TSPARUL_LOAD_COUNT (in graph_iri varchar) returns integer
{
  return (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id (graph_iri));
}
;

-- Whether a LOAD outcome is the error for a named graph in the document.
create function TSPARUL_LOAD_IS_NAMED_GRAPH_ERROR (in outcome varchar) returns varchar
{
  if ('OK' = outcome)
    return 'loaded';
  if (strstr (outcome, 'named graph') is not null)
    return 'named graph error';
  return outcome;
}
;

--------------------------------------------------------------------------
-- 1. LOAD without INTO GRAPH: the document is a dataset, its default graph
--    goes to the graph named by the document IRI and each named graph to
--    its own graph.
--
--    A TriG document served as application/trig, its registered media type,
--    failed to load: only application/x-trig was taken for TriG, so it was
--    read as Turtle, its GRAPH blocks as N3 formulae, reified into the
--    document's graph before the next block failed to parse.
--------------------------------------------------------------------------

select TSPARUL_LOAD ('ds.trig');
echo both $if $equ $LAST[1] "OK" "PASSED" "***FAILED";
echo both ": 1a LOAD of an application/trig dataset\n";

select TSPARUL_LOAD_COUNT (TSPARUL_LOAD_URL ('ds.trig'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1b its default graph is in the graph of the document (" $LAST[1] " triples)\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:one');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1c its GRAPH <...> { } block is in that named graph\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:two');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1d its <...> { } block is in that named graph\n";

select TSPARUL_LOAD ('ds_x.trig');
echo both $if $equ $LAST[1] "OK" "PASSED" "***FAILED";
echo both ": 1e LOAD of an application/x-trig dataset\n";

select TSPARUL_LOAD_COUNT (TSPARUL_LOAD_URL ('ds_x.trig')) * 10 + TSPARUL_LOAD_COUNT ('urn:tsparul_load:x:one');
echo both $if $equ $LAST[1] 11 "PASSED" "***FAILED";
echo both ": 1f its default and named graph are where they belong\n";

select TSPARUL_LOAD ('ds.nq');
echo both $if $equ $LAST[1] "OK" "PASSED" "***FAILED";
echo both ": 1g LOAD of an N-Quads dataset\n";

select TSPARUL_LOAD_COUNT (TSPARUL_LOAD_URL ('ds.nq')) * 10 + TSPARUL_LOAD_COUNT ('urn:tsparul_load:nq');
echo both $if $equ $LAST[1] 11 "PASSED" "***FAILED";
echo both ": 1h its default quad and named quad are where they belong\n";

--------------------------------------------------------------------------
-- 2. LOAD ... INTO GRAPH: "it is an error if named graphs are encountered
--    when parsing the RDF document" (SPARQL 1.2 Update, LOAD).
--
--    A named quad was loaded into its own graph and the LOAD succeeded; a
--    TriG document with named graphs failed only because it was not read as
--    TriG, and one with a default graph block for the same reason.
--------------------------------------------------------------------------

select TSPARUL_LOAD_IS_NAMED_GRAPH_ERROR (TSPARUL_LOAD ('ds.nq', 'urn:tsparul_load:into:nq'));
echo both $if $equ $LAST[1] "named graph error" "PASSED" "***FAILED";
echo both ": 2a LOAD of N-Quads with a named quad INTO GRAPH is an error\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:nq');
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": 2b and the named quad is not loaded into its graph\n";

select TSPARUL_LOAD_IS_NAMED_GRAPH_ERROR (TSPARUL_LOAD ('ds.trig', 'urn:tsparul_load:into:trig'));
echo both $if $equ $LAST[1] "named graph error" "PASSED" "***FAILED";
echo both ": 2c LOAD of TriG with named graphs INTO GRAPH is an error\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:one') + TSPARUL_LOAD_COUNT ('urn:tsparul_load:two');
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": 2d and its named graphs are not loaded\n";

select TSPARUL_LOAD_IS_NAMED_GRAPH_ERROR (TSPARUL_LOAD ('ds.trig', TSPARUL_LOAD_URL ('ds.trig')));
echo both $if $equ $LAST[1] "named graph error" "PASSED" "***FAILED";
echo both ": 2e so is LOAD <doc> INTO GRAPH <doc> of it\n";

select TSPARUL_LOAD ('dflt.trig', 'urn:tsparul_load:into:dflt');
echo both $if $equ $LAST[1] "OK" "PASSED" "***FAILED";
echo both ": 2f LOAD of TriG with only a default graph INTO GRAPH\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:into:dflt');
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 2g loads its triples, in a { } block or not, into the graph (" $LAST[1] " triples)\n";

select TSPARUL_LOAD ('dflt.nq', 'urn:tsparul_load:into:dflt_nq');
echo both $if $equ $LAST[1] "OK" "PASSED" "***FAILED";
echo both ": 2h LOAD of N-Quads with only default quads INTO GRAPH\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:into:dflt_nq');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2i loads them into the graph\n";

select TSPARUL_LOAD ('plain.ttl', 'urn:tsparul_load:into:ttl');
echo both $if $equ $LAST[1] "OK" "PASSED" "***FAILED";
echo both ": 2j LOAD of Turtle INTO GRAPH\n";

select TSPARUL_LOAD_COUNT ('urn:tsparul_load:into:ttl');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2k loads it into the graph\n";

--------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------

create procedure TSPARUL_LOAD_CLEANUP ()
{
  foreach (varchar gr in vector (TSPARUL_LOAD_URL ('ds.trig'), TSPARUL_LOAD_URL ('ds_x.trig'), TSPARUL_LOAD_URL ('ds.nq'),
    'urn:tsparul_load:one', 'urn:tsparul_load:two', 'urn:tsparul_load:x:one', 'urn:tsparul_load:nq',
    'urn:tsparul_load:into:nq', 'urn:tsparul_load:into:trig', 'urn:tsparul_load:into:dflt',
    'urn:tsparul_load:into:dflt_nq', 'urn:tsparul_load:into:ttl')) do
    delete from DB.DBA.RDF_QUAD where G = iri_to_id (gr);
  DB.DBA.DAV_DELETE ('/DAV/tsparul_load/', 1, 'dav', 'dav');
}
;
TSPARUL_LOAD_CLEANUP ();

ECHO BOTH "COMPLETED: SPARQL LOAD of RDF datasets (tsparul_load.sql)\n";
