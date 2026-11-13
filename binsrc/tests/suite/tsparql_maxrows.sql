--
--  tsparql_maxrows.sql
--
--  The /sparql endpoint's row limit, maxrows or [SPARQL] ResultSetMaxRows, on a
--  streamed result:
--    1. a result cut at the limit has that many rows and says the limit;
--    2. a result under the limit says the limit too;
--    3. a result of exactly the limit;
--    4. a longer result is cut at a limit over a thousand rows, streamed;
--    5. an unlimited result is streamed, all of it, with no limit header.
--  A stream never sends X-SPARQL-MaxRows, which a collected result sends when it
--  reached the limit.
--
--  Needs the HTTP listener, so it runs from thttp.sh.
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

ECHO BOTH "STARTED: SPARQL endpoint row limit headers (tsparql_maxrows.sql)\n";

--  A streamed result sends its headers before its first row, so it cannot say
--  whether the row limit will cut it.  It says what the limit is, in
--  X-SPARQL-MaxRows-Limit: N, sent whenever a limit applies; the client sees
--  from the row count whether the limit was reached.  X-SPARQL-MaxRows stays the
--  collected result's: sent when the result reached the limit.

create procedure TMR_LOAD ()
{
  declare ses any;
  declare i integer;
  ses := string_output ();
  for (i := 1; i <= 1500; i := i + 1)
    http (sprintf ('<urn:tmr:s%d> a <urn:tmr:Matter> .\n', i), ses);
  DB.DBA.TTLP (string_output_string (ses), '', 'urn:tmr:g');
}
;
sparql clear graph <urn:tmr:g>;
TMR_LOAD ();
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tmr:g');
ECHO BOTH $IF $EQU $LAST[1] 1500 "PASSED" "***FAILED";
ECHO BOTH ": loaded " $LAST[1] " triples\n";

create function TMR_PROBE (in qry varchar, in maxrows integer := null) returns varchar
{
  declare hdr, body, lines any;
  declare url, mr, lim, te, ln varchar;
  declare i, n integer;
  declare exit handler for sqlstate '*' { return 'EXC:' || __SQL_STATE || ' ' || __SQL_MESSAGE; };
  url := sprintf ('http://localhost:%s/sparql?query=%U', cast (server_http_port () as varchar), qry);
  if (maxrows is not null)
    url := url || sprintf ('&maxrows=%d', maxrows);
  hdr := null;
  body := http_get (url, hdr, 'GET', 'Accept: text/csv');
  if (not isarray (hdr) or 0 = length (hdr))
    return 'NOHDR';
  mr := '-';
  lim := '-';
  te := '0';
  for (i := 0; i < length (hdr); i := i + 1)
    {
      ln := hdr[i];
      if (isstring (ln) and strstr (lower (ln), 'x-sparql-maxrows:') = 0)
        mr := trim (subseq (ln, 17), ' \r\n\t');
      if (isstring (ln) and strstr (lower (ln), 'x-sparql-maxrows-limit:') = 0)
        lim := trim (subseq (ln, 23), ' \r\n\t');
      if (isstring (ln) and strstr (lower (ln), 'transfer-encoding:') = 0 and strstr (lower (ln), 'chunked') is not null)
        te := '1';
    }
  n := 0;
  lines := split_and_decode (cast (body as varchar), 0, '\0\0\n');
  for (i := 0; i < length (lines); i := i + 1)
    if (strstr (lines[i], '"urn:tmr:s') = 0)
      n := n + 1;
  return sprintf ('rows=%d;maxrows=%s;limit=%s;chunked=%s', n, mr, lim, te);
}
;

select TMR_PROBE ('SELECT ?s WHERE { ?s a <urn:tmr:Matter> } LIMIT 20', 5);
ECHO BOTH $IF $EQU $LAST[1] "rows=5;maxrows=-;limit=5;chunked=1" "PASSED" "***FAILED";
ECHO BOTH ": 1. LIMIT 20 streamed with maxrows 5 gives 5 rows and the limit: " $LAST[1] "\n";

select TMR_PROBE ('SELECT ?s WHERE { ?s a <urn:tmr:Matter> FILTER (?s IN (<urn:tmr:s1>, <urn:tmr:s2>, <urn:tmr:s3>)) }', 5);
ECHO BOTH $IF $EQU $LAST[1] "rows=3;maxrows=-;limit=5;chunked=1" "PASSED" "***FAILED";
ECHO BOTH ": 2. three rows under maxrows 5, the limit is still said: " $LAST[1] "\n";

select TMR_PROBE ('SELECT ?s WHERE { ?s a <urn:tmr:Matter> } LIMIT 5', 5);
ECHO BOTH $IF $EQU $LAST[1] "rows=5;maxrows=-;limit=5;chunked=1" "PASSED" "***FAILED";
ECHO BOTH ": 3. exactly maxrows 5 rows: " $LAST[1] "\n";

select TMR_PROBE ('SELECT ?s WHERE { ?s a <urn:tmr:Matter> }', 1100);
ECHO BOTH $IF $EQU $LAST[1] "rows=1100;maxrows=-;limit=1100;chunked=1" "PASSED" "***FAILED";
ECHO BOTH ": 4. 1500 rows streamed with maxrows 1100, cut there: " $LAST[1] "\n";

select TMR_PROBE ('SELECT ?s WHERE { ?s a <urn:tmr:Matter> }');
ECHO BOTH $IF $EQU $LAST[1] "rows=1500;maxrows=-;limit=-;chunked=1" "PASSED" "***FAILED";
ECHO BOTH ": 5. no limit: all 1500 rows, no limit header: " $LAST[1] "\n";

sparql clear graph <urn:tmr:g>;
drop function TMR_PROBE;
drop procedure TMR_LOAD;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

ECHO BOTH "COMPLETED: SPARQL endpoint row limit headers (tsparql_maxrows.sql)\n";
