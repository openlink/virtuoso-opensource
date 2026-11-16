--
--  tsinv_silent.sql
--
--  SERVICE SILENT.
--
--  SPARQL 1.1 Federated Query, section 4: with SILENT, an error accessing
--  the remote endpoint is ignored, and the failed SERVICE clause is treated
--  as if it had a single solution with no bindings.  The SPARQL compiler
--  parsed SILENT and kept it only for printing the query; the SERVICE call
--  failed the whole query as without it.
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

ECHO BOTH "STARTED: SERVICE SILENT (tsinv_silent.sql)\n";

SPARQL CLEAR GRAPH <urn:tsil:g>;
SPARQL INSERT DATA { GRAPH <urn:tsil:g> { <urn:tsil:a> <urn:tsil:p> 1 . <urn:tsil:b> <urn:tsil:p> 2 } };
string_to_file ('tsinv_silent.rdf', 'not RDF/XML', -2);
DB.DBA.VHOST_REMOVE (lpath=>'/tsilfs');
DB.DBA.VHOST_DEFINE (lpath=>'/tsilfs', ppath=>'/', is_dav=>0, vsp_user=>'dba');

-- port 1 refuses the connection
SPARQL SELECT (COUNT (*) AS ?n) (COUNT (?s) AS ?bound) WHERE {
  SERVICE SILENT <http://localhost:1/sparql> { ?s ?p ?o } };
echo both $if $equ $state "OK" $if $equ $LAST[1] 1 $if $equ $LAST[2] 0 "PASSED" "***FAILED" "***FAILED" "***FAILED";
echo both ": S1 SERVICE SILENT, connection refused: one solution, nothing bound: " $LAST[1] " " $LAST[2] " " $STATE " " $MESSAGE "\n";

-- the endpoint refuses the query it is sent: HTTP 500
SPARQL SELECT (COUNT (*) AS ?n) (COUNT (?s) AS ?bound) WHERE {
  SERVICE SILENT <http://localhost:$U{HTTPPORT}/sparql> { ?s ?p ?o FILTER (<urn:tsil:no-such-function> (?o)) } };
echo both $if $equ $state "OK" $if $equ $LAST[1] 1 $if $equ $LAST[2] 0 "PASSED" "***FAILED" "***FAILED" "***FAILED";
echo both ": S2 SERVICE SILENT, the endpoint answers with an HTTP error: one solution, nothing bound: " $LAST[1] " " $LAST[2] " " $STATE " " $MESSAGE "\n";

SPARQL SELECT (COUNT (*) AS ?n) (COUNT (?s) AS ?bound) WHERE {
  SERVICE SILENT <http://localhost:$U{HTTPPORT}/tsilfs/tsinv_silent.rdf> { ?s ?p ?o } };
echo both $if $equ $state "OK" $if $equ $LAST[1] 1 $if $equ $LAST[2] 0 "PASSED" "***FAILED" "***FAILED" "***FAILED";
echo both ": S3 SERVICE SILENT, a reply that is not a SPARQL result: one solution, nothing bound: " $LAST[1] " " $LAST[2] " " $STATE " " $MESSAGE "\n";

SPARQL SELECT (COUNT (*) AS ?n) WHERE {
  GRAPH <urn:tsil:g> { ?x <urn:tsil:p> ?v }
  SERVICE SILENT <http://localhost:1/sparql> { ?s <urn:tsil:q> ?z } };
echo both $if $equ $state "OK" $if $equ $LAST[1] 2 "PASSED" "***FAILED" "***FAILED";
echo both ": S4 a failed SERVICE SILENT keeps the local solutions it joins: " $LAST[1] " " $STATE " " $MESSAGE "\n";

SPARQL SELECT (COUNT (*) AS ?n) WHERE {
  SERVICE SILENT <http://localhost:$U{HTTPPORT}/sparql> { GRAPH <urn:tsil:g> { ?s <urn:tsil:p> ?o } } };
echo both $if $equ $state "OK" $if $equ $LAST[1] 2 "PASSED" "***FAILED" "***FAILED";
echo both ": S5 SERVICE SILENT that succeeds returns its solutions (guard): " $LAST[1] " " $STATE " " $MESSAGE "\n";

SPARQL SELECT (COUNT (*) AS ?n) WHERE {
  SERVICE <http://localhost:1/sparql> { ?s ?p ?o } };
echo both $if $equ $state "OK" "***FAILED" "PASSED";
echo both ": S6 without SILENT the failure is an error (guard): " $STATE "\n";

SPARQL CLEAR GRAPH <urn:tsil:g>;
DB.DBA.VHOST_REMOVE (lpath=>'/tsilfs');

ECHO BOTH "COMPLETED: SERVICE SILENT (tsinv_silent.sql)\n";
