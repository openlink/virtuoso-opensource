--
--  tsinv_lang.sql
--
--  Language-tagged literals in the reply to a SPARQL SERVICE call.
--
--  A literal with a language tag has the datatype rdf:langString (with a
--  direction, rdf:dirLangString), and Virtuoso's SPARQL XML results say so:
--  <literal xml:lang="es" datatype="...#langString">.  Virtuoso 8 endpoints
--  write that, and so does this server.  The SERVICE reply parser hands the
--  text, the datatype and the language of each literal to
--  DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS, which passed both to rdf_box
--  and failed the query with SR549; DB.DBA.SPARQL_REXEC_TO_ARRAY goes
--  through DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS, which kept the
--  datatype and dropped the language.
--
--  The constructors are called as the parser calls them, with variables: a
--  call with constant arguments is folded by the SQL compiler and does not
--  run them.
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

ECHO BOTH "STARTED: language-tagged literals in SERVICE replies (tsinv_lang.sql)\n";

-- ------------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------------

-- text|language|datatype of the literal a constructor makes, or the error.
create function TSINV_LIT (in which varchar, in v varchar, in dt any, in lang any) returns varchar
{
  declare r any;
  declare exit handler for sqlstate '*' { return 'ERROR ' || __SQL_STATE; };
  if (which = 'obj')
    r := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS (v, dt, lang);
  else
    r := DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (v, dt, lang);
  return sprintf ('%s|%s|%s', cast (__rdf_strsqlval (r) as varchar),
    coalesce (DB.DBA.RDF_LANGUAGE_OF_LONG (r, ''), ''),
    coalesce (cast (DB.DBA.RDF_DATATYPE_IRI_OF_LONG (r, '') as varchar), ''));
}
;

-- The same for the first value of the first row SPARQL_REXEC_TO_ARRAY reads.
create function TSINV_REXEC (in url varchar, in q varchar) returns varchar
{
  declare rows, r any;
  declare exit handler for sqlstate '*' { return 'ERROR ' || __SQL_STATE; };
  rows := DB.DBA.SPARQL_REXEC_TO_ARRAY (url, q, null, null, null, 10, null);
  if (length (rows) <> 1)
    return sprintf ('%d rows', length (rows));
  r := rows[0][0];
  return sprintf ('%s|%s|%s', cast (__rdf_strsqlval (r) as varchar),
    coalesce (DB.DBA.RDF_LANGUAGE_OF_LONG (r, ''), ''),
    coalesce (cast (DB.DBA.RDF_DATATYPE_IRI_OF_LONG (r, '') as varchar), ''));
}
;

-- ------------------------------------------------------------------
-- 1. the constructors the reply parser calls for each literal
-- ------------------------------------------------------------------

select TSINV_LIT ('obj', 'Hola', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#langString', 'es');
echo both $if $equ $LAST[1] "Hola|es|http://www.w3.org/1999/02/22-rdf-syntax-ns#langString" "PASSED" "***FAILED";
echo both ": L1 obj of 'Hola', rdf:langString, 'es' is 'Hola'@es: " $LAST[1] "\n";

select TSINV_LIT ('long', 'Hola', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#langString', 'es');
echo both $if $equ $LAST[1] "Hola|es|http://www.w3.org/1999/02/22-rdf-syntax-ns#langString" "PASSED" "***FAILED";
echo both ": L2 long of 'Hola', rdf:langString, 'es' keeps the language: " $LAST[1] "\n";

select TSINV_LIT ('obj', 'salaam', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#dirLangString', 'ar--rtl');
echo both $if $equ $LAST[1] "salaam|ar--rtl|http://www.w3.org/1999/02/22-rdf-syntax-ns#dirLangString" "PASSED" "***FAILED";
echo both ": L3 obj of a directional literal, rdf:dirLangString: " $LAST[1] "\n";

select TSINV_LIT ('long', 'salaam', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#dirLangString', 'ar--rtl');
echo both $if $equ $LAST[1] "salaam|ar--rtl|http://www.w3.org/1999/02/22-rdf-syntax-ns#dirLangString" "PASSED" "***FAILED";
echo both ": L4 long of a directional literal, rdf:dirLangString: " $LAST[1] "\n";

select TSINV_LIT ('obj', 'Hola', UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#langString', 'es');
echo both $if $equ $LAST[1] "Hola|es|http://www.w3.org/1999/02/22-rdf-syntax-ns#langString" "PASSED" "***FAILED";
echo both ": L5 obj with the datatype given as a UNAME: " $LAST[1] "\n";

select TSINV_LIT ('obj', 'Hola', null, 'es');
echo both $if $equ $LAST[1] "Hola|es|http://www.w3.org/1999/02/22-rdf-syntax-ns#langString" "PASSED" "***FAILED";
echo both ": L6 obj of a language alone (guard): " $LAST[1] "\n";

select TSINV_LIT ('obj', '5', 'http://www.w3.org/2001/XMLSchema#integer', null);
echo both $if $equ $LAST[1] "5||http://www.w3.org/2001/XMLSchema#integer" "PASSED" "***FAILED";
echo both ": L7 obj of a typed literal (guard): " $LAST[1] "\n";

select TSINV_LIT ('long', 'x', 'urn:tsinv:dt', null);
echo both $if $equ $LAST[1] "x||urn:tsinv:dt" "PASSED" "***FAILED";
echo both ": L8 long of a literal of an unknown datatype (guard): " $LAST[1] "\n";

select TSINV_LIT ('long', 'Hola', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#langString', null);
echo both $if $equ $LAST[1] "Hola||http://www.w3.org/1999/02/22-rdf-syntax-ns#langString" "PASSED" "***FAILED";
echo both ": L9 rdf:langString with no language is left as it was (guard): " $LAST[1] "\n";

-- ------------------------------------------------------------------
-- 2. SERVICE to an endpoint that answers as Virtuoso 8 does: a static
--    reply, served from the filesystem
-- ------------------------------------------------------------------

string_to_file ('tsinv_lang.srx', '<?xml version="1.0" encoding="utf-8" ?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
 <head><variable name="l"/></head>
 <results distinct="false" ordered="true">
  <result><binding name="l"><literal xml:lang="es" datatype="http://www.w3.org/1999/02/22-rdf-syntax-ns#langString">Hola</literal></binding></result>
 </results>
</sparql>
', -2);
DB.DBA.VHOST_REMOVE (lpath=>'/tsinvfs');
DB.DBA.VHOST_DEFINE (lpath=>'/tsinvfs', ppath=>'/', is_dav=>0, vsp_user=>'dba');

SPARQL SELECT ?l (lang (?l) AS ?lang) WHERE {
  SERVICE <http://localhost:$U{HTTPPORT}/tsinvfs/tsinv_lang.srx> { ?s ?p ?l } };
echo both $if $equ $state "OK" $if $equ $LAST[1] "Hola" $if $equ $LAST[2] "es" "PASSED" "***FAILED" "***FAILED" "***FAILED";
echo both ": L10 SERVICE reads xml:lang with datatype rdf:langString as 'Hola'@es: " $LAST[1] " " $LAST[2] " " $STATE " " $MESSAGE "\n";

select TSINV_REXEC ('http://localhost:$U{HTTPPORT}/tsinvfs/tsinv_lang.srx', 'SELECT ?l WHERE { ?s ?p ?l }');
echo both $if $equ $LAST[1] "Hola|es|http://www.w3.org/1999/02/22-rdf-syntax-ns#langString" "PASSED" "***FAILED";
echo both ": L11 SPARQL_REXEC_TO_ARRAY keeps the language: " $LAST[1] "\n";

-- ------------------------------------------------------------------
-- 3. SERVICE to this server's own /sparql endpoint
-- ------------------------------------------------------------------

SPARQL INSERT DATA { GRAPH <urn:tsinv:g> {
  <urn:tsinv:s> <urn:tsinv:label> "Hola"@es .
  <urn:tsinv:s> <urn:tsinv:n> 5 } };

SPARQL SELECT ?o (lang (?o) AS ?lang) WHERE {
  SERVICE <http://localhost:$U{HTTPPORT}/sparql> { GRAPH <urn:tsinv:g> { <urn:tsinv:s> <urn:tsinv:label> ?o } } };
echo both $if $equ $state "OK" $if $equ $LAST[1] "Hola" $if $equ $LAST[2] "es" "PASSED" "***FAILED" "***FAILED" "***FAILED";
echo both ": L12 SERVICE to this server reads its language-tagged literal: " $LAST[1] " " $LAST[2] " " $STATE " " $MESSAGE "\n";

SPARQL SELECT ?o (str (datatype (?o)) AS ?dt) WHERE {
  SERVICE <http://localhost:$U{HTTPPORT}/sparql> { GRAPH <urn:tsinv:g> { <urn:tsinv:s> <urn:tsinv:n> ?o } } };
echo both $if $equ $state "OK" $if $equ $LAST[1] "5" $if $equ $LAST[2] "http://www.w3.org/2001/XMLSchema#integer" "PASSED" "***FAILED" "***FAILED" "***FAILED";
echo both ": L13 SERVICE to this server, a typed literal (guard): " $LAST[1] " " $LAST[2] " " $STATE "\n";

-- ------------------------------------------------------------------
-- cleanup
-- ------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:tsinv:g>;
DB.DBA.VHOST_REMOVE (lpath=>'/tsinvfs');
drop function TSINV_LIT;
drop function TSINV_REXEC;

ECHO BOTH "COMPLETED: language-tagged literals in SERVICE replies (tsinv_lang.sql)\n";
