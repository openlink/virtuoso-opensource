--
--  wikibase_mwapi.sql
--
--  Fixture-based tests for the wikibase:mwapi SERVICE handler
--  (DB.DBA.SPARQL_SINV_CB_WIKIBASE_MWAPI and its pure helpers in
--  libsrc/Wi/sparql_io.sql).  No network access is required: URL
--  building and JSON-to-rows mapping are exercised directly through
--  the refactored procedures, with canned MediaWiki API responses.
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

echo BOTH "\nSTARTED: wikibase:mwapi SERVICE handler tests (wikibase_mwapi.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

-- Test helpers: pure-procedure results in assertable string form
create procedure DB.DBA.TWMW_FMT (in _v any) returns varchar
{
  declare _out varchar;
  declare _ctr integer;
  declare _e any;
  if (_v is null)
    return 'null';
  _out := '[';
  for (_ctr := 0; _ctr < length (_v); _ctr := _ctr + 1)
    {
      if (_ctr > 0) _out := _out || ',';
      _e := _v[_ctr];
      if (isvector (_e))
        _out := _out || DB.DBA.TWMW_FMT (_e);
      else if (isiri_id (_e))
        _out := _out || id_to_iri (_e);
      else if (_e is null)
        _out := _out || 'NULL';
      else
        _out := _out || cast (_e as varchar);
    }
  return _out || ']';
}
;

-- Titles of the items extracted from a canned response document, in order
create procedure DB.DBA.TWMW_TITLES (in _api_action varchar, in _json varchar) returns varchar
{
  declare _items any;
  declare _out varchar;
  declare _ctr integer;
  _items := DB.DBA.SPARQL_SINV_MWAPI_EXTRACT_ITEMS (_api_action, json_parse (_json));
  if (_items is null)
    return '(null)';
  _out := '[';
  for (_ctr := 0; _ctr < length (_items); _ctr := _ctr + 1)
    {
      if (_ctr > 0) _out := _out || ',';
      _out := _out || cast (DB.DBA.SPARQL_SINV_MWAPI_GET_FIELD (_items[_ctr], 'title') as varchar);
    }
  return _out || ']';
}
;

create procedure DB.DBA.TWMW_LEX_SUMMARY (in _qtext varchar) returns varchar
{
  declare _a, _h varchar;
  declare _p, _m, _im any;
  DB.DBA.SPARQL_SINV_PARSE_QUERY_LEXER (_qtext, _a, _h, _p, _m, _im);
  return sprintf ('action=%s|host=%s|params=%s|maps=%s|items=%s',
    _a, _h, DB.DBA.TWMW_FMT (_p), DB.DBA.TWMW_FMT (_m), DB.DBA.TWMW_FMT (_im));
}
;

-- ---------------------------------------------------------------------------
-- 1. Namespace tolerance: the SERVICE body template contains expanded IRIs
--    (the SPARQL compiler prints prefixed names as <full-iri>), so both the
--    http:// and https:// spellings of www.mediawiki.org/ontology#API must
--    yield identical parses.
--

select DB.DBA.TWMW_LEX_SUMMARY ('SELECT ?title_ ?item WHERE { <http://www.bigdata.com/rdf#serviceParam> <http://wikiba.se/ontology#endpoint> "en.wikipedia.org" ; <http://wikiba.se/ontology#api> "Search" ; <http://www.mediawiki.org/ontology#API/srsearch> "scholia" . ?title_ <http://wikiba.se/ontology#apiOutput> <http://www.mediawiki.org/ontology#API/title> . ?item <http://wikiba.se/ontology#apiOutputItem> <http://www.mediawiki.org/ontology#API/item> . }');
ECHO BOTH $IF $EQU $LAST[1] 'action=Search|host=en.wikipedia.org|params=[srsearch,scholia]|maps=[title_,title]|items=[item,item]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": lexer parse of http:// mwapi prefix (Search) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_LEX_SUMMARY ('SELECT ?title_ ?item WHERE { <http://www.bigdata.com/rdf#serviceParam> <http://wikiba.se/ontology#endpoint> "en.wikipedia.org" ; <http://wikiba.se/ontology#api> "Generator" ; <https://www.mediawiki.org/ontology#API/generator> "search" ; <https://www.mediawiki.org/ontology#API/gsrsearch> "scholia" ; <https://www.mediawiki.org/ontology#API/gsrlimit> "200" . ?title_ <http://wikiba.se/ontology#apiOutput> <https://www.mediawiki.org/ontology#API/title> . ?item <http://wikiba.se/ontology#apiOutputItem> <https://www.mediawiki.org/ontology#API/item> . }');
ECHO BOTH $IF $EQU $LAST[1] 'action=Generator|host=en.wikipedia.org|params=[generator,search,gsrsearch,scholia,gsrlimit,200]|maps=[title_,title]|items=[item,item]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": lexer parse of https:// mwapi prefix (Generator) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_LEX_SUMMARY ('{ <http://www.bigdata.com/rdf#serviceParam> <http://wikiba.se/ontology#api> "Search" ; <https://www.mediawiki.org/ontology#APIgsrsearch> "scholia" . }');
ECHO BOTH $IF $EQU $LAST[1] 'action=Search|host=www.wikidata.org|params=[gsrsearch,scholia]|maps=[]|items=[]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": lexer parse of trailing-slash-less mwapi prefix STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_LEX_SUMMARY ('{ <http://www.bigdata.com/rdf#serviceParam> <http://wikiba.se/ontology#api> "Search" ; <http://www.mediawiki.org/ontology#API/srsearch> "x" . ?t <http://wikiba.se/ontology#apiOutput> <https://www.mediawiki.org/ontology#API/title> . }');
ECHO BOTH $IF $EQU $LAST[1] 'action=Search|host=www.wikidata.org|params=[srsearch,x]|maps=[t,title]|items=[]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": lexer parse of mixed http:/https: prefixes STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_LEX_SUMMARY ('{ <http://www.bigdata.com/rdf#serviceParam> <http://wikiba.se/ontology#api> "Search" ; <http://www.mediawiki.org/ontology#API/srsearch> "x" . ?t <http://wikiba.se/ontology#apiOutput> <http://example.org/ontology#API/title> . }');
ECHO BOTH $IF $EQU $LAST[1] 'action=Search|host=www.wikidata.org|params=[srsearch,x]|maps=[]|items=[]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": lexer rejects foreign namespace for apiOutput STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ---------------------------------------------------------------------------
-- 2. URL building (SPARQL_SINV_MWAPI_BUILD_URL)
--

select DB.DBA.SPARQL_SINV_MWAPI_BUILD_URL ('Search', 'www.wikidata.org', vector ('srsearch', 'spider-man'));
ECHO BOTH $IF $EQU $LAST[1] 'https://www.wikidata.org/w/api.php?format=json&action=query&list=search&srsearch=spider-man' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUILD_URL for Search STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_BUILD_URL ('wbsearchentities', 'www.wikidata.org', vector ('srsearch', 'Douglas Adams'));
ECHO BOTH $IF $EQU $LAST[1] 'https://www.wikidata.org/w/api.php?format=json&action=wbsearchentities&language=en&search=Douglas%20Adams' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUILD_URL for wbsearchentities renames srsearch and URL-encodes STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_BUILD_URL ('Generator', 'en.wikipedia.org', vector ('generator', 'search', 'gsrsearch', 'scholia', 'gsrlimit', '200'));
ECHO BOTH $IF $EQU $LAST[1] 'https://en.wikipedia.org/w/api.php?format=json&action=query&gsrsearch=scholia&gsrlimit=200&generator=search&prop=pageprops' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUILD_URL for Generator emits action=query, the generator param and prop=pageprops once STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_BUILD_URL ('Generator', 'en.wikipedia.org', vector ('generator', 'search', 'prop', 'images'));
ECHO BOTH $IF $EQU $LAST[1] 'https://en.wikipedia.org/w/api.php?format=json&action=query&generator=search&prop=images|pageprops' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUILD_URL for Generator merges caller prop with pageprops STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_BUILD_URL ('Generator', 'en.wikipedia.org', vector ('generator', 'search', 'prop', 'pageprops'));
ECHO BOTH $IF $EQU $LAST[1] 'https://en.wikipedia.org/w/api.php?format=json&action=query&generator=search&prop=pageprops' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUILD_URL for Generator keeps a caller prop already covering pageprops STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_BUILD_URL ('Generator', 'en.wikipedia.org', vector ('gsrsearch', 'x'));
ECHO BOTH $IF $EQU $STATE RDFZZ "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUILD_URL for Generator without mwapi:generator signals RDFZZ STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ---------------------------------------------------------------------------
-- 3. Response extraction and ordering (SPARQL_SINV_MWAPI_EXTRACT_ITEMS)
--

select DB.DBA.TWMW_TITLES ('Search', '{"batchcomplete":"","continue":{"sroffset":2,"continue":""},"query":{"search":[{"ns":0,"title":"Scholia","index":1,"snippet":"a tool"},{"ns":0,"title":"WikiProject Open Access","index":2,"snippet":"b"}],"searchinfo":{"totalhits":42}}}');
ECHO BOTH $IF $EQU $LAST[1] '[Scholia,WikiProject Open Access]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EXTRACT_ITEMS for Search response shape STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_TITLES ('Generator', '{"batchcomplete":"","continue":{"gsroffset":2,"continue":"gsroffset||"},"query":{"pages":{"55652":{"pageid":55652,"ns":0,"title":"WikiProject Open Access","index":2,"pageprops":{"wikibase_item":"Q3952168"}},"5315":{"pageid":5315,"ns":0,"title":"Scholia","index":1,"pageprops":{"wikibase_item":"Q1358144"}}}}}');
ECHO BOTH $IF $EQU $LAST[1] '[Scholia,WikiProject Open Access]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EXTRACT_ITEMS for Generator pages ordered by index, not by pageid key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_TITLES ('Generator', '{"query":{"pages":{"1":{"title":"Indexed First","index":2},"2":{"title":"NoIndex Page"},"3":{"title":"Indexed Second","index":1}}}}');
ECHO BOTH $IF $EQU $LAST[1] '[Indexed Second,Indexed First,NoIndex Page]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EXTRACT_ITEMS orders indexed pages by index, unindexed pages last in encounter order STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_TITLES ('Generator', '{"batchcomplete":"","query":{"pages":{}}}');
ECHO BOTH $IF $EQU $LAST[1] '[]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EXTRACT_ITEMS for empty Generator response STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_TITLES ('Generator', '{"batchcomplete":""}');
ECHO BOTH $IF $EQU $LAST[1] '(null)' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EXTRACT_ITEMS with no query{} object yields no items STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ---------------------------------------------------------------------------
-- 3a. Field resolution (SPARQL_SINV_MWAPI_GET_FIELD)
--

select DB.DBA.SPARQL_SINV_MWAPI_GET_FIELD (json_parse ('{"title":"Scholia","pageprops":{"wikibase_item":"Q1358144"}}'), 'title');
ECHO BOTH $IF $EQU $LAST[1] Scholia "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_FIELD flat lookup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_GET_FIELD (json_parse ('{"title":"Scholia","pageprops":{"wikibase_item":"Q1358144"}}'), 'pageprops.wikibase_item');
ECHO BOTH $IF $EQU $LAST[1] Q1358144 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_FIELD dotted path lookup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_GET_FIELD (json_parse ('{"title":"Scholia","pageprops":{"wikibase_item":"Q1358144"}}'), 'item');
ECHO BOTH $IF $EQU $LAST[1] Q1358144 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_FIELD item resolves through pageprops.wikibase_item STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select case when DB.DBA.SPARQL_SINV_MWAPI_GET_FIELD (json_parse ('{"title":"Scholia"}'), 'item') is null then 'NULL' else 'FOUND' end;
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_FIELD item with no pageprops is null STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ---------------------------------------------------------------------------
-- 4. Row mapping (SPARQL_SINV_MWAPI_MAP_ROWS)
--

select DB.DBA.TWMW_FMT (DB.DBA.SPARQL_SINV_MWAPI_MAP_ROWS (vector ('title_', 'item'),
  DB.DBA.SPARQL_SINV_MWAPI_EXTRACT_ITEMS ('Generator', json_parse ('{"query":{"pages":{"55652":{"pageid":55652,"ns":0,"title":"WikiProject Open Access","index":2,"pageprops":{"wikibase_item":"Q3952168"}},"5315":{"pageid":5315,"ns":0,"title":"Scholia","index":1,"pageprops":{"wikibase_item":"Q1358144"}}}}}')),
  vector ('title_', 'title'), vector ('item', 'item'), 10000));
ECHO BOTH $IF $EQU $LAST[1] '[[Scholia,http://www.wikidata.org/entity/Q1358144],[WikiProject Open Access,http://www.wikidata.org/entity/Q3952168]]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MAP_ROWS for Generator binds title and entity IRI in index order STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TWMW_FMT (DB.DBA.SPARQL_SINV_MWAPI_MAP_ROWS (vector ('t', 's'),
  DB.DBA.SPARQL_SINV_MWAPI_EXTRACT_ITEMS ('Search', json_parse ('{"query":{"search":[{"title":"Scholia","snippet":"a tool"},{"title":"WikiProject Open Access","snippet":"b"}]}}')),
  vector ('t', 'title', 's', 'snippet'), vector (), 10000));
ECHO BOTH $IF $EQU $LAST[1] '[[Scholia,a tool],[WikiProject Open Access,b]]' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MAP_ROWS for Search binds title and snippet STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select case when length (DB.DBA.SPARQL_SINV_MWAPI_MAP_ROWS (vector ('t'),
  DB.DBA.SPARQL_SINV_MWAPI_EXTRACT_ITEMS ('Search', json_parse ('{"query":{"search":[{"title":"A"},{"title":"B"},{"title":"C"}]}}')),
  vector ('t', 'title'), vector (), 2)) then 'TRUNCATED' else 'NOT' end;
ECHO BOTH $IF $EQU $LAST[1] TRUNCATED "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MAP_ROWS honors max_rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ---------------------------------------------------------------------------
-- 5. MediaWiki API errors surface loudly (SPARQL_SINV_MWAPI_CHECK_ERROR)
--

select DB.DBA.SPARQL_SINV_MWAPI_CHECK_ERROR (json_parse ('{"batchcomplete":"","limits":{"search":50}}'), 'https://www.wikidata.org/w/api.php?format=json&action=query&list=search');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CHECK_ERROR is silent on a successful response STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.SPARQL_SINV_MWAPI_CHECK_ERROR (json_parse ('{"error":{"code":"badvalue","info":"Unrecognized value for parameter \\\"action\\\": NoSuchAction.","*":"See https://api.wikimedia.org for API usage"}}'), 'https://www.wikidata.org/w/api.php?format=json&action=NoSuchAction');
ECHO BOTH $IF $EQU $STATE RDFZZ "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CHECK_ERROR signals RDFZZ on an MW error response STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure DB.DBA.TWMW_FMT;
drop procedure DB.DBA.TWMW_TITLES;
drop procedure DB.DBA.TWMW_LEX_SUMMARY;

ECHO BOTH "COMPLETED: wikibase:mwapi handler tests WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";