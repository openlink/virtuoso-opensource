--
--  tsparql_xml_lang.sql
--
--  A literal with a language tag in the XML result formats.
--
--  The XML writers write a literal's datatype and language as they get them
--  from DB.DBA.RDF_DATATYPE_IRI_OF_LONG and DB.DBA.RDF_LANGUAGE_OF_LONG.
--  The first gave NULL for a literal with a language until the RDF 1.2
--  support made it rdf:langString (rdf:dirLangString with a direction), as
--  SPARQL's DATATYPE () must; since then the writers put the datatype
--  beside the language.  A reader that takes the datatype first -- rdflib,
--  and in RDF/XML every parser, rdf:datatype making a typed literal --
--  reads the literal without its language.  The JSON and Turtle writers
--  write the language alone, as the XML writers did before.
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

ECHO BOTH "STARTED: language-tagged literals in XML results (tsparql_xml_lang.sql)\n";

-- The body of /sparql's answer to q in format fmt.
create function TSXL_GET (in q varchar, in fmt varchar) returns varchar
{
  declare hdr any;
  declare exit handler for sqlstate '*' { return 'EXC:' || __SQL_STATE; };
  return http_get (sprintf ('http://localhost:$U{HTTPPORT}/sparql?query=%U&format=%U', q, fmt), hdr);
}
;

-- 1 when the body has frag.
create function TSXL_HAS (in q varchar, in fmt varchar, in frag varchar) returns integer
{
  declare b varchar;
  b := TSXL_GET (q, fmt);
  if (isstring (b) and strstr (b, frag) is not null)
    return 1;
  return 0;
}
;

SPARQL CLEAR GRAPH <urn:tsxl:g>;
SPARQL INSERT DATA { GRAPH <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:lang> "Hola"@es . <urn:tsxl:s> <urn:tsxl:n> 5 } };
DB.DBA.TTLP ('<urn:tsxl:s> <urn:tsxl:dir> "salaam"@ar--rtl .', '', 'urn:tsxl:g');

select TSXL_HAS ('SELECT ?o WHERE { GRAPH <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:lang> ?o } }', 'application/sparql-results+xml',
  '<literal xml:lang="es">Hola</literal>');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": X1 SPARQL XML results write a literal with a language with its language only\n";

select TSXL_HAS ('SELECT ?o WHERE { GRAPH <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:dir> ?o } }', 'application/sparql-results+xml',
  '<literal xml:lang="ar--rtl">salaam</literal>');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": X2 the same for a literal with a direction\n";

select TSXL_HAS ('SELECT ?o WHERE { GRAPH <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:n> ?o } }', 'application/sparql-results+xml',
  '<literal datatype="http://www.w3.org/2001/XMLSchema#integer">5</literal>');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": X3 a typed literal keeps its datatype (guard)\n";

select TSXL_HAS ('SELECT ?o WHERE { GRAPH <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:lang> ?o } }', 'application/sparql-results+json',
  '{ "type": "literal", "xml:lang": "es", "value": "Hola" }');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": X4 SPARQL JSON results write the language only (guard)\n";

select TSXL_HAS ('SELECT ?o WHERE { GRAPH <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:lang> ?o } }', 'application/rdf+xml',
  '<res:value xml:lang="es">Hola</res:value>');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": X5 a result set as RDF/XML writes the language only\n";

select case when strstr (b, '<rs:value xml:lang="es">Hola</rs:value>') is not null then 1 else 0 end
  from (select cast ((sparql define output:format "RDF/XML" select ?o where { graph <urn:tsxl:g> { <urn:tsxl:s> <urn:tsxl:lang> ?o } }) as varchar) as b) x;
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": X6 output:format RDF/XML of a SELECT writes the language only\n";

SPARQL CLEAR GRAPH <urn:tsxl:g>;
drop function TSXL_GET;
drop function TSXL_HAS;

ECHO BOTH "COMPLETED: language-tagged literals in XML results (tsparql_xml_lang.sql)\n";
