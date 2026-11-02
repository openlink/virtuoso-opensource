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
--
--
--  GQL for Virtuoso - functions and operators
--
--  Each GQL function the documentation lists, run through GQL_RUN, against
--  its value.  F31-F33 need the gqlc plugin and are skipped without it.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_functions.sql
--
ECHO BOTH "STARTED: GQL function tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

-- The first value of the first row, as text; 'NULL', 'no row', 'a vector',
-- or 'error <state>'.
create procedure DB.DBA.GQL_FN_T_VAL (in _q varchar, in _g varchar := null) returns varchar
{
  declare _r, _v any;
  declare exit handler for sqlstate '*' { return concat ('error ', __SQL_STATE); };
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r) or length (_r) < 1)
    return 'no row';
  _v := aref (aref (_r, 0), 0);
  if (_v is null)
    return 'NULL';
  if (isarray (_v) and not isstring (_v))
    return 'a vector';
  return cast (_v as varchar);
}
;

-- 1 when _q gives _expected, or the check needs gqlc and it is not loaded.
create procedure DB.DBA.GQL_FN_T_OK (in _q varchar, in _expected varchar, in _gqlc integer) returns integer
{
  if (_gqlc and not DB.DBA.GQL_HAS_GQLC ())
    return 1;
  if (DB.DBA.GQL_FN_T_VAL (_q, 'urn:gql:fn') = _expected)
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_FN_T_SHOW (in _q varchar, in _gqlc integer) returns varchar
{
  if (_gqlc and not DB.DBA.GQL_HAS_GQLC ())
    return 'skipped, gqlc not loaded';
  return DB.DBA.GQL_FN_T_VAL (_q, 'urn:gql:fn');
}
;

sparql clear graph <urn:gql:fn>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''Alice'', age: 30})-[:knows]->(b:Person {name: ''Bob'', age: 25}), (b)-[:knows]->(c:Person {name: ''Carol'', age: 35})', 'urn:gql:fn');

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN STARTS_WITH(''hello'', ''he'') AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN STARTS_WITH(''hello'', ''he'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F1 STARTS_WITH: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN ENDS_WITH(''hello'', ''lo'') AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN ENDS_WITH(''hello'', ''lo'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F2 ENDS_WITH: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN IS_IRI(IRI(''urn:x'')) AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN IS_IRI(IRI(''urn:x'')) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F3 IS_IRI: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN IS_LITERAL(42) AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN IS_LITERAL(42) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F4 IS_LITERAL: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN IS_NUMERIC(42) AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN IS_NUMERIC(42) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F5 IS_NUMERIC: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN SAME_TERM(1, 1) AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN SAME_TERM(1, 1) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F6 SAME_TERM: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN LANG_MATCHES(''en'', ''en'') AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN LANG_MATCHES(''en'', ''en'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F7 LANG_MATCHES: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN true XOR false AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN true XOR false AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F8 XOR: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN TRIM(''  a  '') AS x', 'a', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN TRIM(''  a  '') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F9 one-argument TRIM: " $LAST[2] " (expected a)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN NULLIF(1, 1) AS x', 'NULL', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN NULLIF(1, 1) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F10 NULLIF of equal values: " $LAST[2] " (expected NULL)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN NULLIF(1, 2) AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN NULLIF(1, 2) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F11 NULLIF of different values: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN [10, 20, 30][1] AS x', '20', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN [10, 20, 30][1] AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F12 a list index (from 0): " $LAST[2] " (expected 20)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN REPLACE(''hello'', ''o'', ''O'') AS x', 'hellO', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN REPLACE(''hello'', ''o'', ''O'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F13 REPLACE: " $LAST[2] " (expected hellO)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN CONTAINS(''hello'', ''ell'') AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN CONTAINS(''hello'', ''ell'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F14 CONTAINS (a, b): " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN YEAR(DATE ''2024-01-15'') AS x', '2024', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN YEAR(DATE ''2024-01-15'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F15 YEAR: " $LAST[2] " (expected 2024)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN MONTH(DATE ''2024-01-15'') AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN MONTH(DATE ''2024-01-15'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F16 MONTH: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN DAY(DATE ''2024-01-15'') AS x', '15', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN DAY(DATE ''2024-01-15'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F17 DAY: " $LAST[2] " (expected 15)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN IF(1 = 1, ''a'', ''b'') AS x', 'a', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN IF(1 = 1, ''a'', ''b'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F18 IF: " $LAST[2] " (expected a)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN YEAR(DATE(''2024-01-15'')) AS x', '2024', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN YEAR(DATE(''2024-01-15'')) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F19 DATE (string): " $LAST[2] " (expected 2024)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN HOURS(TIME(''14:30:00'')) AS x', '14', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN HOURS(TIME(''14:30:00'')) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F20 TIME (string): " $LAST[2] " (expected 14)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN false IMPLIES true AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN false IMPLIES true AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F21 IMPLIES: " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN true IMPLIES false AS x', '0', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN true IMPLIES false AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F22 IMPLIES, false: " $LAST[2] " (expected 0)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN LOG(2, 8) AS x', '3', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN LOG(2, 8) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F23 LOG (base, value): " $LAST[2] " (expected 3)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN OCTET_LENGTH(''héllo'') AS x', '6', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN OCTET_LENGTH(''héllo'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F24 OCTET_LENGTH counts UTF-8 bytes: " $LAST[2] " (expected 6)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN BYTE_LENGTH(''héllo'') AS x', '6', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN BYTE_LENGTH(''héllo'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F25 BYTE_LENGTH: " $LAST[2] " (expected 6)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN HOURS(TIMESTAMP ''2024-01-15T14:30:05'') AS x', '14', 0), DB.DBA.GQL_FN_T_SHOW ('RETURN HOURS(TIMESTAMP ''2024-01-15T14:30:05'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F26 HOURS of a TIMESTAMP literal: " $LAST[2] " (expected 14)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('MATCH (p:Person) FILTER p.name IN [''Alice'', ''Bob''] RETURN count(*) AS x', '2', 0), DB.DBA.GQL_FN_T_SHOW ('MATCH (p:Person) FILTER p.name IN [''Alice'', ''Bob''] RETURN count(*) AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F27 x IN [list]: " $LAST[2] " (expected 2)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('MATCH (p:Person {name: ''Carol''}) RETURN degree_centrality(p, ''out'') AS x', '0', 0), DB.DBA.GQL_FN_T_SHOW ('MATCH (p:Person {name: ''Carol''}) RETURN degree_centrality(p, ''out'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F28 degree_centrality of a node with no edge out: " $LAST[2] " (expected 0)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('MATCH (p:Person {name: ''Alice''}) RETURN degree_centrality(p, ''out'') AS x', '1', 0), DB.DBA.GQL_FN_T_SHOW ('MATCH (p:Person {name: ''Alice''}) RETURN degree_centrality(p, ''out'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F29 degree_centrality of a node with one (guard): " $LAST[2] " (expected 1)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('MATCH (p:Person {name: ''Bob''}) RETURN degree_centrality(p, ''both'') AS x', '2', 0), DB.DBA.GQL_FN_T_SHOW ('MATCH (p:Person {name: ''Bob''}) RETURN degree_centrality(p, ''both'') AS x', 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F30 degree_centrality both ways: " $LAST[2] " (expected 2)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('MATCH (p:Person) RETURN percentile_cont(p.age, 0.5) AS x', '30', 1), DB.DBA.GQL_FN_T_SHOW ('MATCH (p:Person) RETURN percentile_cont(p.age, 0.5) AS x', 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F31 PERCENTILE_CONT over a MATCH: " $LAST[2] " (expected 30)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('MATCH (p:Person) RETURN percentile_disc(p.age, 0.5) AS x', '30', 1), DB.DBA.GQL_FN_T_SHOW ('MATCH (p:Person) RETURN percentile_disc(p.age, 0.5) AS x', 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F32 PERCENTILE_DISC over a MATCH: " $LAST[2] " (expected 30)\n";

select 99, '';
select DB.DBA.GQL_FN_T_OK ('RETURN NORMALIZE(''café'') AS x', 'café', 1), DB.DBA.GQL_FN_T_SHOW ('RETURN NORMALIZE(''café'') AS x', 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F33 NORMALIZE of a non-ASCII literal: " $LAST[2] " (expected café)\n";

select 99, '';
select case when DB.DBA.GQL_FN_T_VAL ('RETURN DURATION(''P1D'') AS x') in ('a vector', 'NULL') or DB.DBA.GQL_FN_T_VAL ('RETURN DURATION(''P1D'') AS x') like 'error%' then 0 else 1 end, DB.DBA.GQL_FN_T_VAL ('RETURN DURATION(''P1D'') AS x');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F34 DURATION is a duration value, not a vector: " $LAST[2] "\n";

select 99, '';
select case when DB.DBA.GQL_FN_T_VAL ('RETURN ST_AREA(bif:st_point(0, 0)) AS x') = 'error G2004' then 1 else 0 end, DB.DBA.GQL_FN_T_VAL ('RETURN ST_AREA(bif:st_point(0, 0)) AS x');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F35 ST_AREA, which Virtuoso does not have, is refused: " $LAST[2] "\n";

sparql clear graph <urn:gql:fn>;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL function tests\n";
