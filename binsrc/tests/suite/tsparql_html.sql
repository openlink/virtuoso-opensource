--
--  tsparql_html.sql
--
--  SPARQL result pages (HTML5, XHTML) written from SQL into a stream of the
--  caller.
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

ECHO BOTH "STARTED: SPARQL result page tests (tsparql_html.sql)\n";

--------------------------------------------------------------------------
-- 1. The page header.
--
--    WS.WS.SPARQL_RESULT_HTML5_OUTPUT_BEGIN and _XHTML_OUTPUT_BEGIN wrote
--    the title in the navigation bar with http_value (title), and the XHTML
--    one the Bootstrap stylesheet link with http (...), to no stream, while
--    the rest of the page went to their ses argument.  Outside an HTTP
--    request every page writer failed with HT069, and inside one, with a
--    stream of its own, those parts went to the response, not the page.
--------------------------------------------------------------------------

-- A result page written into a string output, as define output:format or a
-- DAV resource writes it.
create function TSPARQL_HTML_PAGE (in fmt varchar) returns varchar
{
  declare triples, ses any;
  triples := vector (vector (iri_to_id ('http://example.com/ns#s'), iri_to_id ('http://example.com/ns#p'), iri_to_id ('http://example.com/ns#o')));
  ses := string_output ();
  if (fmt = 'HTML;UL')
    DB.DBA.RDF_TRIPLES_TO_HTML_UL (triples, ses, ' tsparql_html');
  else if (fmt = 'HTML;NICE_TTL')
    DB.DBA.RDF_TRIPLES_TO_HTML_NICE_TTL (triples, ses, ' tsparql_html');
  else if (fmt = 'RDFA;XHTML')
    DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML (triples, ses, ' tsparql_html');
  else
    signal ('22023', 'TSPARQL_HTML_PAGE: unknown format');
  return string_output_string (ses);
}
;

-- How often the page has str, -1 if it cannot be written.
create function TSPARQL_HTML_COUNT (in fmt varchar, in str varchar) returns integer
{
  declare page varchar;
  declare exit handler for sqlstate '*' { return -1; };
  page := TSPARQL_HTML_PAGE (fmt);
  return (length (page) - length (replace (page, str, ''))) / length (str);
}
;

select TSPARQL_HTML_COUNT ('HTML;UL', 'tsparql_html');
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 1a an HTML5 page written from SQL has its title in the head and the navigation bar (" $LAST[1] ")\n";

select TSPARQL_HTML_COUNT ('HTML;NICE_TTL', 'tsparql_html');
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 1b an HTML5 Turtle page written from SQL has its title in the head and the navigation bar (" $LAST[1] ")\n";

select TSPARQL_HTML_COUNT ('RDFA;XHTML', 'tsparql_html');
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 1c an XHTML page written from SQL has its title in the head and the navigation bar (" $LAST[1] ")\n";

select TSPARQL_HTML_COUNT ('RDFA;XHTML', 'bootstrap.min.css');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1d an XHTML page written from SQL links its stylesheet (" $LAST[1] ")\n";

ECHO BOTH "COMPLETED: SPARQL result page tests (tsparql_html.sql)\n";
