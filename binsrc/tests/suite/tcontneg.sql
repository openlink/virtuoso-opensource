--
--  tcontneg.sql
--
--  HTTP content negotiation of a reply whose type the page set itself.
--
--  ws_check_accept() recovers the reply's Content-Type out of the header
--  block the page already built, and then either negotiates against it or
--  rebuilds the block around the negotiated type.  Both halves depend on
--  ws_header_line_to_array() actually returning the lines of that block.
--  When it returns an empty array instead, the recovered type is NULL, the
--  negotiation runs against a defaulted "text/html", and the rebuild copies
--  nothing -- so every DAV-served resource came back as text/html with its
--  ETag, Last-Modified, Link, Allow, Vary, MS-Author-Via and Accept-Post
--  headers gone, and asking for the resource's own type got a 406.  The
--  SPARQL protocol endpoint was hit by the same thing, which made
--  Accept: application/sparql-results+xml a 406 and SPARQL federation
--  between two Virtuoso servers impossible.
--
--  Only requests that carry an Accept header reach the function at all, so
--  each case below is measured twice: once as a browser sends it and once
--  with no Accept header, which is the reference.
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

ECHO BOTH "STARTED: HTTP content negotiation tests (tcontneg.sql)\n";

-- ------------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------------

create function TCN_HDR (in hdr any, in nam varchar) returns varchar
{
  declare i, n int;
  declare ln varchar;
  if (not isarray (hdr)) return null;
  n := length (hdr);
  for (i := 0; i < n; i := i + 1)
    {
      ln := hdr[i];
      if (isstring (ln) and strstr (lower (ln), lower (nam) || ':') = 0)
        return trim (subseq (ln, length (nam) + 1), ' \r\n\t');
    }
  return null;
}
;

-- One request, one scalar answer, so every assertion below is a value
-- comparison rather than a state comparison.  acc is the whole Accept
-- request header, or NULL to send none at all -- that distinction is the
-- entire measurement, so it must not be blurred into an empty string.
create function TCN_PROBE (in url varchar, in acc any, in what varchar) returns varchar
{
  declare hdr, body any;
  declare ct varchar;
  declare exit handler for sqlstate '*' { return 'EXC:' || __SQL_STATE; };
  hdr := null;
  body := http_get (url, hdr, 'GET', acc);
  if (not isarray (hdr) or 0 = length (hdr)) return 'NOHDR';
  if ('status' = what) return trim (subseq (hdr[0], 9, 12));
  ct := TCN_HDR (hdr, 'Content-Type');
  if ('ctype' = what) return coalesce (ct, '(absent)');
  -- the media type without its parameters, so charset spelling cannot decide a test
  if ('mtype' = what)
    {
      if (ct is null) return '(absent)';
      if (strchr (ct, ';') is not null) ct := subseq (ct, 0, strchr (ct, ';'));
      return trim (ct);
    }
  if ('has' = what) return 'BADCALL';
  return 'BADWHAT';
}
;

create function TCN_HAS (in url varchar, in acc any, in nam varchar) returns varchar
{
  declare hdr, body any;
  declare exit handler for sqlstate '*' { return 'EXC:' || __SQL_STATE; };
  hdr := null;
  body := http_get (url, hdr, 'GET', acc);
  if (not isarray (hdr)) return 'NOHDR';
  return case when TCN_HDR (hdr, nam) is null then 'no' else 'yes' end;
}
;

-- ------------------------------------------------------------------
-- fixtures: the same bytes, once in DAV and once on the filesystem.
-- The filesystem copy is the control -- that path passes the real content
-- type into ws_check_accept and has always negotiated correctly.
-- ------------------------------------------------------------------

DB.DBA.DAV_COL_CREATE ('/DAV/tcn/', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tcn/style.css', 'body { color: red; }', 'text/css', '110100100R', 'dav', 'dav', 'dav', 'dav');
select coalesce ((select RES_TYPE from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/tcn/style.css'), '(missing)');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": the DAV fixture is stored with RES_TYPE text/css\n";

string_to_file ('tcn_static.css', 'body { color: red; }', -2);
DB.DBA.VHOST_REMOVE (lpath=>'/tcnfs');
DB.DBA.VHOST_DEFINE (lpath=>'/tcnfs', ppath=>'/', is_dav=>0, vsp_user=>'dba');
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": the filesystem control is served from /tcnfs\n";

-- ------------------------------------------------------------------
-- 1. no Accept header at all.  This never enters ws_check_accept, so it is
--    the reference for what the reply is supposed to look like.
-- ------------------------------------------------------------------

select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', null, 'status');
echo both $if $equ $LAST[1] "200" "PASSED" "***FAILED";
echo both ": DAV, no Accept -- 200\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', null, 'mtype');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": DAV, no Accept -- Content-Type text/css\n";
select TCN_HAS ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', null, 'ETag');
echo both $if $equ $LAST[1] "yes" "PASSED" "***FAILED";
echo both ": DAV, no Accept -- ETag present\n";

-- ------------------------------------------------------------------
-- 2. Accept: */* -- what every browser and every HTTP client sends.
--    The reply must be the same one as above.
-- ------------------------------------------------------------------

select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: */*', 'status');
echo both $if $equ $LAST[1] "200" "PASSED" "***FAILED";
echo both ": DAV, Accept */* -- 200\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: */*', 'mtype');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": DAV, Accept */* -- Content-Type is still text/css, not text/html\n";
select TCN_HAS ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: */*', 'ETag');
echo both $if $equ $LAST[1] "yes" "PASSED" "***FAILED";
echo both ": DAV, Accept */* -- ETag survives content negotiation\n";
select TCN_HAS ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: */*', 'Last-Modified');
echo both $if $equ $LAST[1] "yes" "PASSED" "***FAILED";
echo both ": DAV, Accept */* -- Last-Modified survives content negotiation\n";
select TCN_HAS ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: */*', 'Allow');
echo both $if $equ $LAST[1] "yes" "PASSED" "***FAILED";
echo both ": DAV, Accept */* -- Allow survives content negotiation\n";
select TCN_HAS ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: */*', 'MS-Author-Via');
echo both $if $equ $LAST[1] "yes" "PASSED" "***FAILED";
echo both ": DAV, Accept */* -- MS-Author-Via survives content negotiation\n";

-- ------------------------------------------------------------------
-- 3. Asking for exactly what the resource is must not be refused.  A 406
--    here is the server saying it thinks the resource is something else.
-- ------------------------------------------------------------------

select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: text/css', 'status');
echo both $if $equ $LAST[1] "200" "PASSED" "***FAILED";
echo both ": DAV, Accept text/css -- 200, not 406\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: text/css', 'mtype');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": DAV, Accept text/css -- Content-Type text/css\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: text/*', 'mtype');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": DAV, Accept text/* -- a wildcard subtype matches\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: text/css,*/*;q=0.1', 'mtype');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": DAV, Accept text/css,*/*;q=0.1 -- Content-Type text/css\n";

-- ------------------------------------------------------------------
-- 4. Negotiation must still REFUSE what the resource genuinely is not.
--    Without this a test suite passes just as well against a fix that
--    turns content negotiation off.
-- ------------------------------------------------------------------

select TCN_PROBE ('http://localhost:$U{HTTPPORT}/DAV/tcn/style.css', 'Accept: image/png', 'status');
echo both $if $equ $LAST[1] "406" "PASSED" "***FAILED";
echo both ": DAV, Accept image/png -- 406, negotiation still refuses a type the resource is not\n";

-- ------------------------------------------------------------------
-- 5. the filesystem path, which was already correct and must stay so.
-- ------------------------------------------------------------------

select TCN_PROBE ('http://localhost:$U{HTTPPORT}/tcnfs/tcn_static.css', 'Accept: */*', 'mtype');
echo both $if $equ $LAST[1] "text/css" "PASSED" "***FAILED";
echo both ": filesystem static, Accept */* -- text/css (unchanged)\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/tcnfs/tcn_static.css', 'Accept: text/css', 'status');
echo both $if $equ $LAST[1] "200" "PASSED" "***FAILED";
echo both ": filesystem static, Accept text/css -- 200 (unchanged)\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/tcnfs/tcn_static.css', 'Accept: image/png', 'status');
echo both $if $equ $LAST[1] "406" "PASSED" "***FAILED";
echo both ": filesystem static, Accept image/png -- 406 (unchanged)\n";

-- ------------------------------------------------------------------
-- 6. the SPARQL protocol endpoint.  A SPARQL client is required to ask for
--    a results media type by name; refusing that makes the endpoint
--    unreachable to a conforming client.
-- ------------------------------------------------------------------

select TCN_PROBE ('http://localhost:$U{HTTPPORT}/sparql?query=ASK%20%7B%7D', 'Accept: application/sparql-results+xml', 'status');
echo both $if $equ $LAST[1] "200" "PASSED" "***FAILED";
echo both ": /sparql, Accept application/sparql-results+xml -- 200, not 406\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/sparql?query=ASK%20%7B%7D', 'Accept: application/sparql-results+xml', 'mtype');
echo both $if $equ $LAST[1] "application/sparql-results+xml" "PASSED" "***FAILED";
echo both ": /sparql, Accept application/sparql-results+xml -- answered as that type\n";
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/sparql?query=ASK%20%7B%7D', 'Accept: */*', 'status');
echo both $if $equ $LAST[1] "200" "PASSED" "***FAILED";
echo both ": /sparql, Accept */* -- 200\n";

-- A SELECT reply is streamed with chunked encoding when its format allows;
-- the type it is sent as is negotiated the same way.
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/sparql?query=SELECT%20%3Fx%20%7B%20VALUES%20%3Fx%20%7B%201%20%7D%20%7D', 'Accept: application/sparql-results+json', 'mtype');
echo both $if $equ $LAST[1] "application/sparql-results+json" "PASSED" "***FAILED";
echo both ": /sparql SELECT, Accept application/sparql-results+json -- answered as that type\n";

-- format= names the type outright; a browser's Accept, which lists text/html
-- first and */* last, must not turn the reply into text/html.
select TCN_PROBE ('http://localhost:$U{HTTPPORT}/sparql?format=application%2Fsparql-results%2Bjson&query=SELECT%20%3Fx%20%7B%20VALUES%20%3Fx%20%7B%201%20%7D%20%7D', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8', 'mtype');
echo both $if $equ $LAST[1] "application/sparql-results+json" "PASSED" "***FAILED";
echo both ": /sparql SELECT format=json, a browser's Accept -- answered as JSON, not text/html\n";

-- ------------------------------------------------------------------
-- 7. SPARQL federation from this server to its own endpoint.  This is the
--    end to end consequence: with the negotiation broken, no Virtuoso can
--    SERVICE another Virtuoso, because SPARQL_REXEC always sends an Accept
--    naming the result media types.
-- ------------------------------------------------------------------

SPARQL SELECT (COUNT(*) AS ?n) WHERE {
  SERVICE <http://localhost:$U{HTTPPORT}/sparql> { ?s ?p ?o } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": SPARQL SERVICE against this server's own /sparql endpoint\n";

-- ------------------------------------------------------------------
-- cleanup
-- ------------------------------------------------------------------

DB.DBA.VHOST_REMOVE (lpath=>'/tcnfs');
DB.DBA.DAV_DELETE ('/DAV/tcn/style.css', 1, 'dav', 'dav');
DB.DBA.DAV_DELETE ('/DAV/tcn/', 1, 'dav', 'dav');

ECHO BOTH "COMPLETED: HTTP content negotiation tests (tcontneg.sql)\n";
