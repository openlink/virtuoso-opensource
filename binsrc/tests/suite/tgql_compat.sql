--
--  $Id$
--
--  GQL for Virtuoso - what the GQL build must leave alone (server part)
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

ECHO BOTH "STARTED: GQL compatibility tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- S1-S3: the SERVICE handler framework.  A SERVICE whose endpoint matches a
-- row of DB.DBA.SYS_SPARQL_SINV_HANDLER runs that handler's callback instead
-- of a remote request.  The test endpoint is http://localhost:1/, where
-- nothing listens: without the framework the SERVICE fails at once.

select 99;
select count (*) from DB.DBA.SYS_SPARQL_SINV_HANDLER where SSH_PATTERN like 'http://wikiba.se/ontology#%';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": S1 the Wikibase SERVICE handlers are registered: " $LAST[1] "\n";

-- The handler returns one row: every variable the SERVICE binds is
-- <http://example.org/compat/x1>.
create procedure DB.DBA.TGQL_COMPAT_SINV_CB (
  in _ws_endpoint varchar, in _ws_params any, in _qtext varchar, in _qtext_posmap nvarchar,
  in _param_row any, in _expected_vars any, in _handler_opts any)
{
  declare r any;
  declare i integer;
  r := make_array (length (_expected_vars), 'any');
  for (i := 0; i < length (_expected_vars); i := i + 1)
    aset (r, i, iri_to_id ('http://example.org/compat/x1'));
  return vector (r);
}
;

-- Seed the endpoint's dialect, as the framework does for the Wikibase IRIs,
-- so the compiler does not try to read a service description from it.
create procedure DB.DBA.TGQL_COMPAT_SINV_SETUP ()
{
  declare _state, _msg varchar;
  exec ('jso_triples_del (?, ?, null)', _state, _msg,
    vector ('http://localhost:1/tgql-compat-sinv', 'http://www.openlinksw.com/schemas/virtrdf#dialect'));
  exec ('jso_triple_add (?, ?, ?)', _state, _msg,
    vector ('http://localhost:1/tgql-compat-sinv', 'http://www.openlinksw.com/schemas/virtrdf#dialect', '00007ffe'));
  exec ('sparql define input:storage ""
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    INSERT IN virtrdf: { <http://localhost:1/tgql-compat-sinv> virtrdf:dialect "00007ffe" }', _state, _msg);
  exec ('insert into DB.DBA.SYS_SPARQL_SINV_HANDLER (SSH_PATTERN, SSH_MATCH_KIND, SSH_PRIORITY, SSH_CALLBACK, SSH_ENABLED, SSH_COMMENT)
    values (''http://localhost:1/tgql-compat-sinv'', ''EXACT'', 0, ''DB.DBA.TGQL_COMPAT_SINV_CB'', 1, ''tgql_compat'')', _state, _msg);
}
;

DB.DBA.TGQL_COMPAT_SINV_SETUP ();

select 99;
sparql select count (*) where { service <http://localhost:1/tgql-compat-sinv> { ?x <http://example.org/compat/p> ?o } };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": S2 a SERVICE runs its registered handler, not a remote request: " $LAST[1] " row(s)\n";

-- S3: expected_vars that arrive serialized (through the procedure view)
-- reach the callback as a vector.
create procedure DB.DBA.TGQL_COMPAT_SINV_CB2 (
  in _ws_endpoint varchar, in _ws_params any, in _qtext varchar, in _qtext_posmap nvarchar,
  in _param_row any, in _expected_vars any, in _handler_opts any)
{
  return vector (vector (case when isvector (_expected_vars) then length (_expected_vars) else -1 end));
}
;

select 99;
select aref (aref (DB.DBA.SPARQL_SINV_CALL_HANDLER (vector (0, 'DB.DBA.TGQL_COMPAT_SINV_CB2', null, null, null),
  'http://localhost:1/tgql-compat-sinv', vector (), 'select * where { ?a ?b ?c }', N'', vector (),
  serialize (vector ('a', 'b'))), 0), 0);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": S3 serialized expected_vars reach the handler as a vector of " $LAST[1] "\n";

-- H1, H2: the /sparql pages link their help topics relative to the page,
-- so an endpoint served at another path keeps its users there.
create procedure DB.DBA.TGQL_COMPAT_LINKS_OK (in _page varchar)
{
  declare _body varchar;
  _body := http_get (sprintf ('http://localhost:%s%s',
    cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort'), _page));
  if (strstr (_body, 'href="/sparql/?help=') is not null)
    return 0;
  if (strstr (_body, 'href="?help=') is null)
    return -1;
  return 1;
}
;

select 99;
select DB.DBA.TGQL_COMPAT_LINKS_OK ('/sparql?help=intro');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": H1 /sparql?help=intro links its topics as ?help=... (1), not /sparql/?help=... (0): " $LAST[1] "\n";

select 99;
select DB.DBA.TGQL_COMPAT_LINKS_OK ('/sparql');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": H2 the /sparql form links its topics relative to the page: " $LAST[1] "\n";

-- I1-I10: gql is an ordinary name in SQL -- a column, an alias, a
-- variable, a table -- wherever no GQL statement can start.
drop table DB.DBA.TGQL_COMPAT_T if exists;
create table DB.DBA.TGQL_COMPAT_T (gql integer, x integer, primary key (x));
insert into DB.DBA.TGQL_COMPAT_T (gql, x) values (1, 10);
insert into DB.DBA.TGQL_COMPAT_T (gql, x) values (2, 20);

select 99;
select count (*) from DB.DBA.TGQL_COMPAT_T;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I1 a table with a column named gql takes rows: " $LAST[1] "\n";

select 99;
select gql from DB.DBA.TGQL_COMPAT_T where x = 10;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I2 select gql from ...: " $LAST[1] "\n";

select 99;
select x as gql from DB.DBA.TGQL_COMPAT_T where x = 10;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I3 an alias named gql: " $LAST[1] "\n";

select 99;
select count (*) gql from DB.DBA.TGQL_COMPAT_T;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I4 an alias named gql without AS, before FROM: " $LAST[1] "\n";

select 99;
select gql from DB.DBA.TGQL_COMPAT_T where gql > 0 order by gql desc;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I5 gql in WHERE and ORDER BY: " $LAST[1] "\n";

select 99;
select gql, count (*) from DB.DBA.TGQL_COMPAT_T group by gql having count (*) > 0 order by gql;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I6 gql before GROUP BY's HAVING: " $LAST[1] "\n";

update DB.DBA.TGQL_COMPAT_T set gql = gql + 10 where gql = 1;
select 99;
select gql from DB.DBA.TGQL_COMPAT_T where x = 10;
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I7 update ... set gql = gql + 10: " $LAST[1] "\n";

select 99;
select gql from DB.DBA.TGQL_COMPAT_T where x = 20 for update;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I8 gql before FOR UPDATE: " $LAST[1] "\n";

create procedure DB.DBA.TGQL_COMPAT_VAR ()
{
  declare gql integer;
  gql := 5;
  return gql + 1;
}
;
select 99;
select DB.DBA.TGQL_COMPAT_VAR ();
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I9 a PL variable named gql: " $LAST[1] "\n";

drop table DB.DBA.gql if exists;
create table DB.DBA.gql (a integer primary key);
insert into DB.DBA.gql values (1);
update gql set a = 2;
select 99;
select a from gql;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I10 a table named gql, updated with update gql set ...: " $LAST[1] "\n";
drop table DB.DBA.gql;

-- G1-G8: a GQL statement in SQL still starts with GQL (guards: these pass
-- with gql reserved too).
sparql clear graph <urn:tgql:compat>;
GQL USE GRAPH <urn:tgql:compat> INSERT (:Person {name: 'Ann'}), (:Person {name: 'Bob'});

select 99;
GQL USE GRAPH <urn:tgql:compat> MATCH (p:Person) RETURN count(*) AS c;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G1 GQL USE GRAPH ... INSERT, then MATCH ... RETURN: " $LAST[1] "\n";

select 99;
gql use graph <urn:tgql:compat> match (p:Person) return count(*) as c;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G2 in lower case: " $LAST[1] "\n";

select 99;
GQL FROM <urn:tgql:compat> MATCH (p:Person) RETURN count(*) AS c;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G3 GQL FROM <graph> MATCH ...: " $LAST[1] "\n";

select 99;
GQL
  USE GRAPH <urn:tgql:compat>
  MATCH (p:Person) RETURN count(*) AS c;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G4 GQL, a new line, then the statement: " $LAST[1] "\n";

select 99;
GQL FOR x IN [1, 2, 3] RETURN x AS x;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G5 GQL FOR x IN [...] RETURN x: " $ROWCNT " rows\n";

GQL CREATE PROPERTY GRAPH TgqlCompatPg;
select 99;
select count (*) from DB.DBA.GQL_PROPERTY_GRAPH_DEF where PG_NAME = 'TgqlCompatPg';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G6 GQL CREATE PROPERTY GRAPH: " $LAST[1] "\n";
GQL DROP PROPERTY GRAPH TgqlCompatPg;

create procedure DB.DBA.TGQL_COMPAT_PL_GQL ()
{
  GQL USE GRAPH <urn:tgql:compat> INSERT (:Person {name: 'Cy'});
  return 1;
}
;
select DB.DBA.TGQL_COMPAT_PL_GQL ();
select 99;
GQL USE GRAPH <urn:tgql:compat> MATCH (p:Person) RETURN count(*) AS c;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G7 a GQL statement in a procedure body: " $LAST[1] "\n";

GQL COMMIT;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G8 GQL COMMIT at the end of the text runs: " $STATE "\n";
sparql clear graph <urn:tgql:compat>;

-- Q1-Q3: /sparql tells a GQL request ("gql <statement>") by its first word.
-- Q1: the check reads only the first characters.  Its cost on a query of a
-- megabyte, per call, against one of 40 characters: before, ~700 times (it
-- copied the text twice); now ~20.  The bound, 200, is a ratio, not a time.
create procedure DB.DBA.TGQL_COMPAT_GQL_BODY_RATIO ()
{
  declare big, small, r any;
  declare i, t0, t_big, t_small integer;
  big := concat ('select * where { ?s ?p ?o } # ', repeat ('x', 1000000));
  small := 'select * where { ?s ?p ?o } limit 10';
  r := WS.WS.SPARQL_ENDPOINT_GQL_BODY (big);
  r := WS.WS.SPARQL_ENDPOINT_GQL_BODY (small);
  t0 := msec_time ();
  for (i := 0; i < 1000; i := i + 1)
    r := WS.WS.SPARQL_ENDPOINT_GQL_BODY (big);
  t_big := msec_time () - t0;
  t0 := msec_time ();
  for (i := 0; i < 100000; i := i + 1)
    r := WS.WS.SPARQL_ENDPOINT_GQL_BODY (small);
  t_small := msec_time () - t0;
  if (t_small < 1)
    t_small := 1;
  return (100 * t_big) / t_small;
}
;

select 99;
select case when DB.DBA.TGQL_COMPAT_GQL_BODY_RATIO () < 200 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q1 the GQL check on /sparql costs about the same for a 1 MB query as for 40 characters\n";

-- Q2: what the check returns (guard: unchanged): the statement after the
-- first word, '' for gql alone, null when the text is not GQL.
select 99;
select sum (case when coalesce (WS.WS.SPARQL_ENDPOINT_GQL_BODY (x), '<null>') = y then 1 else 0 end) from (
  select 'gql' as x, '' as y from db.dba.sys_users where u_id = 0 union all
  select '  gql  ', '' from db.dba.sys_users where u_id = 0 union all
  select 'GQL MATCH (n) RETURN n', 'MATCH (n) RETURN n' from db.dba.sys_users where u_id = 0 union all
  select ' gql\tMATCH (n) RETURN n ', '\tMATCH (n) RETURN n' from db.dba.sys_users where u_id = 0 union all
  select 'gqlx', '<null>' from db.dba.sys_users where u_id = 0 union all
  select 'gq', '<null>' from db.dba.sys_users where u_id = 0 union all
  select '', '<null>' from db.dba.sys_users where u_id = 0 union all
  select 'select * where { ?s ?p ?o }', '<null>' from db.dba.sys_users where u_id = 0 union all
  select '\ngql MATCH (n) RETURN n', '<null>' from db.dba.sys_users where u_id = 0) dt;
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q2 the check's answers on nine texts: " $LAST[1] " of 9 as expected\n";

-- Q3: a GQL request over HTTP runs (guard).
sparql clear graph <urn:tgql:compat:q>;
select DB.DBA.GQL_RUN ('INSERT (:Person {name: ''Q1''}), (:Person {name: ''Q2''})', 'urn:tgql:compat:q');
select 99;
select case when strstr (http_get (sprintf ('http://localhost:%s/sparql?default-graph-uri=urn:tgql:compat:q&format=text/csv&query=%U',
    cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort'),
    'gql MATCH (p:Person) RETURN count(*) AS c')), '2') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q3 /sparql?query=gql ... answers the GQL statement\n";
sparql clear graph <urn:tgql:compat:q>;

-- E1-E6: a GQL request on /sparql runs as the SPARQL it translates to, on
-- the endpoint's own result path -- rows streamed with chunked encoding
-- when the format allows (guards).
sparql clear graph <urn:tgql:compat:e>;
select DB.DBA.GQL_RUN ('INSERT (:Person {name: ''E1''}), (:Person {name: ''E2''})', 'urn:tgql:compat:e');

-- The response to GQL _q on /sparql, in the format _fmt (and its headers
-- in _hdr), with &dryrun=1 when _dryrun.
create procedure DB.DBA.TGQL_COMPAT_GQL_GET (in _q varchar, in _fmt varchar, in _dryrun integer, inout _hdr any)
{
  return http_get (sprintf ('http://localhost:%s/sparql?default-graph-uri=urn:tgql:compat:e&format=%U&query=%U%s',
    cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort'), _fmt, concat ('gql ', _q),
    case when _dryrun then '&dryrun=1' else '' end), _hdr);
}
;

-- 1 when _body holds _a and, after it, _b.
create procedure DB.DBA.TGQL_COMPAT_IN_ORDER (in _body varchar, in _a varchar, in _b varchar)
{
  declare pa, pb any;
  pa := strstr (_body, _a);
  pb := strstr (_body, _b);
  if (pa is null or pb is null or pb < pa)
    return 0;
  return 1;
}
;

-- 1 when a line of the response headers _hdr starts with _line.
create procedure DB.DBA.TGQL_COMPAT_HDR_HAS (inout _hdr any, in _line varchar)
{
  if (not isarray (_hdr))
    return 0;
  foreach (any line in _hdr) do
    {
      if (isstring (line) and strcasestr (line, _line) = 0)
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.TGQL_COMPAT_E (in _case integer)
{
  declare body, hdr any;
  hdr := null;
  if (_case = 1)
    {
      body := DB.DBA.TGQL_COMPAT_GQL_GET ('MATCH (p:Person) RETURN p.name AS name ORDER BY name',
        'application/sparql-results+json', 0, hdr);
      if (not DB.DBA.TGQL_COMPAT_HDR_HAS (hdr, 'Transfer-Encoding: chunked'))
        return 0;
      return DB.DBA.TGQL_COMPAT_IN_ORDER (body, '"value": "E1"', '"value": "E2"');
    }
  if (_case = 2)
    {
      body := DB.DBA.TGQL_COMPAT_GQL_GET ('MATCH (p:Person) RETURN p.name AS name ORDER BY name DESC',
        'application/sparql-results+xml', 0, hdr);
      if (strstr (body, '</sparql>') is null)
        return 0;
      return DB.DBA.TGQL_COMPAT_IN_ORDER (body, '>E2<', '>E1<');
    }
  if (_case = 3)
    {
      body := DB.DBA.TGQL_COMPAT_GQL_GET ('MATCH (p:Person {name: ''nobody''}) RETURN p.name AS name',
        'application/sparql-results+json', 0, hdr);
      if (strstr (body, '"bindings"') is null or strstr (body, '"value"') is not null)
        return 0;
      return 1;
    }
  if (_case = 4)
    {
      body := DB.DBA.TGQL_COMPAT_GQL_GET ('MATCH (p:Person) RETURN p.name AS name', 'text/plain', 1, hdr);
      if (strcasestr (body, 'SELECT') is null or strstr (body, 'E1') is not null)
        return 0;
      return 1;
    }
  if (_case = 5)
    {
      declare res integer;
      registry_set ('__gql_generated_sparql_header', 'on');
      {
        declare exit handler for sqlstate '*' { res := 0; };
        body := DB.DBA.TGQL_COMPAT_GQL_GET ('MATCH (p:Person) RETURN count(*) AS c', 'text/csv', 0, hdr);
        res := DB.DBA.TGQL_COMPAT_HDR_HAS (hdr, 'X-Generated-SPARQL:');
      }
      registry_remove ('__gql_generated_sparql_header');
      return res;
    }
  if (_case = 6)
    {
      body := DB.DBA.TGQL_COMPAT_GQL_GET ('MATCH (p:Person) RETURN count(*) AS c', 'text/csv', 0, hdr);
      if (not isarray (hdr) or DB.DBA.TGQL_COMPAT_HDR_HAS (hdr, 'X-Generated-SPARQL:'))
        return 0;
      return 1;
    }
  return -1;
}
;

select 99;
select DB.DBA.TGQL_COMPAT_E (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E1 a GQL statement's rows on /sparql, streamed (chunked) as SPARQL JSON results, in order\n";

select 99;
select DB.DBA.TGQL_COMPAT_E (2);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E2 as SPARQL XML results, complete and in order\n";

select 99;
select DB.DBA.TGQL_COMPAT_E (3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E3 a GQL statement with no rows answers an empty result, not an error\n";

select 99;
select DB.DBA.TGQL_COMPAT_E (4);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E4 dryrun=1 answers the SPARQL, not its rows\n";

select 99;
select DB.DBA.TGQL_COMPAT_E (5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E5 with the registry setting on, the response carries the X-Generated-SPARQL header\n";

select 99;
select DB.DBA.TGQL_COMPAT_E (6);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E6 by default, the response has no X-Generated-SPARQL header\n";
sparql clear graph <urn:tgql:compat:e>;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL compatibility tests\n";
