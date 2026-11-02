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
--  GQL for Virtuoso - parameterized read tests
--
--  With registry __gql_parameterize = 'on', GQL_EXECUTE turns the string
--  literals of a read into bind parameters, so one translation and one
--  compiled plan serve every value of a repeated query shape.  The prepared
--  read API does the same for a template with named $parameters.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_param.sql
--

ECHO "STARTED: GQL parameterized read tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

sparql clear graph <urn:gql:pz>;
create procedure DB.DBA.GQL_PZ_T_LOAD ()
{
  declare _i integer;
  for (_i := 0; _i < 20; _i := _i + 1)
    {
      DB.DBA.GQL_RUN (sprintf ('INSERT (:Review { id: ''r%02d'', stars: %d, text: ''text %d'', kind: ''%s'' })',
        _i, mod (_i, 5) + 1, _i, case when mod (_i, 2) = 0 then 'even' else 'odd' end), 'urn:gql:pz');
      DB.DBA.GQL_RUN (sprintf ('INSERT (:Product { pid: ''p%02d'', name: ''product %d'' })', _i, _i), 'urn:gql:pz');
    }
  for (_i := 0; _i < 20; _i := _i + 1)
    DB.DBA.GQL_RUN (sprintf ('MATCH (r:Review { id: ''r%02d'' }), (p:Product { pid: ''p%02d'' }) INSERT (r)-[:ABOUT]->(p)',
      _i, mod (_i * 7, 20)), 'urn:gql:pz');
  commit work;
}
;
DB.DBA.GQL_PZ_T_LOAD ();

create procedure DB.DBA.GQL_PZ_T_STAT (in _name varchar) returns integer
{
  return aref (__gql_shape_cache_stats (), position (_name, vector ('hits', 'misses', 'puts',
    'evictions', 'generation', 'entries', 'invalidations', 'bytes')) - 1);
}
;

-- Rows GQL_EXECUTE streams for _q, with parameterization on or off.
create procedure DB.DBA.GQL_PZ_T_RUN (in _q varchar, in _pz integer) returns any
{
  declare _st, _msg varchar;
  declare _meta, _data any;
  registry_set ('__gql_parameterize', case when _pz then 'on' else 'off' end);
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector (_q, 'urn:gql:pz'), 100000, _meta, _data);
  registry_set ('__gql_parameterize', 'off');
  if (_st <> '00000')
    signal (_st, _msg);
  if (not isarray (_data))
    return vector ();
  return _data;
}
;

-- Z1: two point lookups that differ only in their literal share one
-- translation, and each returns its own row.
create procedure DB.DBA.GQL_PZ_T_SHARED () returns integer
{
  declare _p1, _p2 integer;
  declare _a, _b any;
  __gql_shape_cache_flush ();
  _a := DB.DBA.GQL_PZ_T_RUN ('MATCH (n:Review { id: ''r03'' }) RETURN n.text AS t', 1);
  _p1 := DB.DBA.GQL_PZ_T_STAT ('puts');
  _b := DB.DBA.GQL_PZ_T_RUN ('MATCH (n:Review { id: ''r07'' }) RETURN n.text AS t', 1);
  _p2 := DB.DBA.GQL_PZ_T_STAT ('puts');
  if (length (_a) = 1 and aref (_a, 0, 0) = 'text 3'
      and length (_b) = 1 and aref (_b, 0, 0) = 'text 7' and _p2 = _p1)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_PZ_T_SHARED ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z1 lookups differing only in a literal share one translation\n";

-- Z2: parameterized and inline execution return the same rows, across the
-- positions the rewrite changes (property maps, =, <>) and those it must
-- leave alone (numbers, LIKE patterns, IN lists, ORDER BY, LIMIT).
create procedure DB.DBA.GQL_PZ_T_SAME (in _q varchar) returns integer
{
  declare _inline, _pz any;
  _inline := DB.DBA.GQL_PZ_T_RUN (_q, 0);
  _pz := DB.DBA.GQL_PZ_T_RUN (_q, 1);
  if (serialize (_inline) = serialize (_pz))
    return 1;
  dbg_obj_print ('GQL_PZ_T_SAME differs', _q, _inline, _pz);
  return 0;
}
;

create procedure DB.DBA.GQL_PZ_T_DIFFERENTIAL () returns integer
{
  declare _qs any;
  declare _i, _ok integer;
  _qs := vector (
    'MATCH (n:Review { id: ''r05'' }) RETURN n.stars AS s, n.text AS t',
    'MATCH (n:Review) WHERE n.kind = ''odd'' RETURN n.id AS id ORDER BY id',
    'MATCH (n:Review) WHERE n.kind <> ''odd'' RETURN n.id AS id ORDER BY id LIMIT 4',
    'MATCH (n:Review) WHERE n.stars = 3 RETURN n.id AS id ORDER BY id',
    'MATCH (n:Review) WHERE n.text LIKE ''text 1%'' RETURN n.id AS id ORDER BY id',
    'MATCH (n:Review) WHERE n.id IN [''r01'', ''r02''] RETURN n.id AS id ORDER BY id',
    'MATCH (r:Review { kind: ''even'' })-[:ABOUT]->(p:Product) RETURN r.id AS r, p.pid AS p ORDER BY r',
    'MATCH (r:Review)-[:ABOUT]->(p:Product { name: ''product 7'' }) RETURN r.id AS r ORDER BY r',
    'MATCH (n:Review { id: ''r09'', kind: ''odd'' }) RETURN n.stars AS s',
    'MATCH (n:Review { id: ''no-such-review'' }) RETURN n.stars AS s',
    'MATCH (n:Review) WHERE n.id = ''it''''s'' OR n.id = ''r10'' RETURN n.id AS id');
  _ok := 1;
  for (_i := 0; _i < length (_qs); _i := _i + 1)
    if (DB.DBA.GQL_PZ_T_SAME (aref (_qs, _i)) = 0)
      _ok := 0;
  return _ok;
}
;

select 0;
select DB.DBA.GQL_PZ_T_DIFFERENTIAL ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z2 parameterized and inline execution return the same rows (11 shapes)\n";

-- Z3: a write is never parameterized: it runs on the inline path, so two
-- identical anonymous-node INSERTs still make two nodes, and the shape is
-- remembered as one to pass through rather than parsed again.
create procedure DB.DBA.GQL_PZ_T_WRITE () returns integer
{
  declare _st, _msg varchar;
  declare _r any;
  sparql clear graph <urn:gql:pz:w>;
  registry_set ('__gql_parameterize', 'on');
  _st := '00000';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector ('INSERT (:Fresh { tag: ''x'' })', 'urn:gql:pz:w'));
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector ('INSERT (:Fresh { tag: ''x'' })', 'urn:gql:pz:w'));
  registry_set ('__gql_parameterize', 'off');
  if (_st <> '00000')
    signal (_st, _msg);
  _r := DB.DBA.GQL_RUN ('MATCH (n:Fresh) RETURN n.tag', 'urn:gql:pz:w');
  if (length (_r) = 2)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_PZ_T_WRITE ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z3 parameterization leaves writes on the inline path\n";

-- Z4: property-graph DDL runs once with parameterization on.
create procedure DB.DBA.GQL_PZ_T_DDL () returns integer
{
  declare _st, _msg varchar;
  DB.DBA.GQL_PG_DROP ('PzDdl', 1);
  registry_set ('__gql_parameterize', 'on');
  _st := '00000';
  exec ('DB.DBA.GQL_EXECUTE (?)', _st, _msg, vector ('CREATE PROPERTY GRAPH PzDdl'));
  registry_set ('__gql_parameterize', 'off');
  if (_st = '00000' and DB.DBA.GQL_PG_DEF_GET ('PzDdl') is not null)
    {
      DB.DBA.GQL_PG_DROP ('PzDdl', 1);
      return 1;
    }
  return 0;
}
;

select 0;
select DB.DBA.GQL_PZ_T_DDL ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z4 property-graph DDL runs once with parameterization on\n";

-- Z5: more literals than one statement may carry bind markers (1000 here;
-- 1001 numbered parameters overrun the SQL compiler's fixed array) is
-- answered on the inline path, not sent as 1,200 parameters.
create procedure DB.DBA.GQL_PZ_T_MANY () returns integer
{
  declare _ses any;
  declare _i integer;
  declare _r any;
  -- 1,001 independent comparisons (a chain of ORs that long overflows the
  -- PL stack in the expression parser, with or without parameters).
  _ses := string_output ();
  http ('MATCH (n:Review { id: ''r04'' }) RETURN n.text AS t', _ses);
  for (_i := 0; _i <= 1000; _i := _i + 1)
    http (sprintf (', ''k'' = ''k'' AS c%d', _i), _ses);
  _r := DB.DBA.GQL_PZ_T_RUN (string_output_string (_ses), 1);
  if (length (_r) = 1 and aref (_r, 0, 0) = 'text 4' and length (aref (_r, 0)) = 1002)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_PZ_T_MANY ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z5 a read with 1002 literals runs inline instead of binding them all\n";

-- Z6: a caller's own parameter whose name looks like an internal one is
-- still the caller's parameter (bound values, not positional markers).
create procedure DB.DBA.GQL_PZ_T_USER_PARAM () returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_PARAMS (concat ('MATCH (n:Review) WHERE n.id = ', chr (36), '__p0 RETURN n.text AS t'),
    'urn:gql:pz', vector (vector ('__p0', 'r06')));
  if (length (_r) = 1 and aref (_r, 0, 0) = 'text 6')
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_PZ_T_USER_PARAM ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z6 a user parameter named __p0 is bound as given\n";

-- Z7: a literal that only looks like a parameter stays a literal.
create procedure DB.DBA.GQL_PZ_T_LOOKALIKE () returns integer
{
  declare _r any;
  DB.DBA.GQL_RUN (concat ('INSERT (:Review { id: ''look'', text: ''', chr (36), 'x ?y'' })'), 'urn:gql:pz');
  _r := DB.DBA.GQL_PZ_T_RUN (concat ('MATCH (n:Review) WHERE n.text = ''', chr (36), 'x ?y'' RETURN n.id AS id'), 1);
  if (length (_r) = 1 and aref (_r, 0, 0) = 'look')
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_PZ_T_LOOKALIKE ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z7 a literal that looks like a parameter is data\n";

-- ------------------------------------------------------------------
-- Z8-Z12: the prepared read API, GQL_PREPARED_PLAN / GQL_PREPARED_PARAMS.
-- A template with named $parameters is translated once per shape; values
-- are bound to positional markers.
-- ------------------------------------------------------------------

create procedure DB.DBA.GQL_PZ_T_PREPARED () returns integer
{
  declare _q, _s1, _s2 varchar;
  declare _v1, _v2 any;
  declare _ok integer;
  _ok := 1;
  _q := concat ('MATCH (n:Review { id: ', chr (36), 'id }) WHERE n.stars = ', chr (36), 'stars RETURN n.text AS t');
  DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('stars', 2), vector (concat (chr (36), 'id'), 'r01')), _s1, _v1);
  if (strstr (_s1, '??') is null or length (_v1) <> 2 or aref (_v1, 0) <> 'r01' or aref (_v1, 1) <> 2)
    _ok := 0;
  -- Same template, other values: the same SPARQL, a new bind vector.
  DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('id', 'r02'), vector ('stars', 3)), _s2, _v2);
  if (_s1 <> _s2 or aref (_v2, 0) <> 'r02')
    _ok := 0;
  -- An injection-shaped value is bound, never written into the SPARQL.
  DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('id', '} UNION { ?s ?p ?o } #'), vector ('stars', 5)), _s2, _v2);
  if (strstr (_s2, 'UNION') is not null)
    _ok := 0;
  return _ok;
}
;

select 0;
select DB.DBA.GQL_PZ_T_PREPARED ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z8 a prepared template binds its values to positional markers\n";

-- Z9: GQL_PREPARED_PARAMS returns the rows; a repeat is served from the
-- cache without translating (or validating) again.
create procedure DB.DBA.GQL_PZ_T_PREPARED_RUN () returns integer
{
  declare _q varchar;
  declare _a, _b any;
  declare _p1 integer;
  _q := concat ('MATCH (n:Review { id: ', chr (36), 'id }) RETURN n.text AS t');
  _a := DB.DBA.GQL_PREPARED_PARAMS (_q, 'urn:gql:pz', vector (vector ('id', 'r11')));
  _p1 := DB.DBA.GQL_PZ_T_STAT ('puts');
  _b := DB.DBA.GQL_PREPARED_PARAMS (_q, 'urn:gql:pz', vector (vector ('id', 'r12')));
  if (length (_a) = 1 and aref (_a, 0, 0) = 'text 11' and length (_b) = 1
      and aref (_b, 0, 0) = 'text 12' and DB.DBA.GQL_PZ_T_STAT ('puts') = _p1)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_PZ_T_PREPARED_RUN ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z9 GQL_PREPARED_PARAMS returns rows and reuses its translation\n";

-- Z10: missing, unknown and duplicate parameters are refused.
create procedure DB.DBA.GQL_PZ_T_PREPARED_BAD (in _case integer) returns varchar
{
  declare _q, _s varchar;
  declare _v any;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  _q := concat ('MATCH (n:Review { id: ', chr (36), 'id }) WHERE n.stars = ', chr (36), 'stars RETURN n');
  if (_case = 1)
    DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('id', 'r01')), _s, _v);
  else if (_case = 2)
    DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('id', 'r01'), vector ('stars', 1), vector ('x', 1)), _s, _v);
  else
    DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('id', 'r01'), vector ('id', 'r02'), vector ('stars', 1)), _s, _v);
  return '00000';
}
;

select 0;
select case when DB.DBA.GQL_PZ_T_PREPARED_BAD (1) = 'G4011' and DB.DBA.GQL_PZ_T_PREPARED_BAD (2) = 'G4010'
  and DB.DBA.GQL_PZ_T_PREPARED_BAD (3) = 'G4010' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z10 missing, unknown and duplicate parameters are refused\n";

-- Z11: the prepared read API runs reads only.  A template that writes, or
-- that does anything but read (CLEAR GRAPH, LOAD, CALL), is refused before
-- it is translated.
create procedure DB.DBA.GQL_PZ_T_PREPARED_WRITE (in _q varchar) returns varchar
{
  declare _s varchar;
  declare _v any;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:pz', vector (vector ('id', 'r01')), _s, _v);
  return '00000';
}
;

select 0;
select case when DB.DBA.GQL_PZ_T_PREPARED_WRITE (concat ('INSERT (:Review { id: ', chr (36), 'id })')) = 'G4012'
  and DB.DBA.GQL_PZ_T_PREPARED_WRITE (concat ('MATCH (n { id: ', chr (36), 'id }) DELETE n')) = 'G4012'
  and DB.DBA.GQL_PZ_T_PREPARED_WRITE ('CLEAR GRAPH <urn:gql:pz>') = 'G4012'
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z11 the prepared read API refuses templates that do not only read\n";
sparql select count (*) from <urn:gql:pz> where { ?s ?p ?o };
ECHO $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z11 and the graph is still there\n";

-- Z12: a template with more named parameters than one statement may carry
-- is refused with an explicit error.
create procedure DB.DBA.GQL_PZ_T_PREPARED_MANY () returns varchar
{
  declare _ses any;
  declare _i integer;
  declare _params any;
  declare _s varchar;
  declare _v any;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  _ses := string_output ();
  http ('MATCH (n:Review { id: ''r04'' }) RETURN n.text AS t', _ses);
  vectorbld_init (_params);
  for (_i := 0; _i < 1001; _i := _i + 1)
    {
      http (sprintf (', %sp%d = ''k'' AS c%d', chr (36), _i, _i), _ses);
      vectorbld_acc (_params, vector (sprintf ('p%d', _i), 'k'));
    }
  vectorbld_final (_params);
  DB.DBA.GQL_PREPARED_PLAN (string_output_string (_ses), 'urn:gql:pz', _params, _s, _v);
  return '00000';
}
;

select 0;
select DB.DBA.GQL_PZ_T_PREPARED_MANY ();
ECHO $IF $EQU $LAST[1] "G4013" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z12 a template with 1001 parameters is refused (" $LAST[1] ")\n";

-- Z13, Z14: the translator emits a statement's WHERE patterns before its
-- SELECT expressions, but the text puts SELECT first.  A value must reach
-- the marker of its own literal or parameter, wherever the two appear.
select 0;
select DB.DBA.GQL_PZ_T_SAME ('MATCH (n:Review { id: ''r05'' }) RETURN n.kind = ''odd'' AS isodd, n.id AS id');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z13 literals in RETURN and in the pattern bind to their own markers\n";
select 0;
select length (DB.DBA.GQL_PZ_T_RUN ('MATCH (n:Review { id: ''r05'' }) RETURN n.kind = ''odd'' AS isodd, n.id AS id', 1));
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z13 and the parameterized form finds the row\n";

create procedure DB.DBA.GQL_PZ_T_PREPARED_ORDER () returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_PREPARED_PARAMS (
    concat ('MATCH (n:Review { id: ', chr (36), 'id }) RETURN n.kind = ', chr (36), 'k AS m, n.id AS id'),
    'urn:gql:pz', vector (vector ('id', 'r05'), vector ('k', 'odd')));
  if (length (_r) = 1 and aref (_r, 0, 1) = 'r05' and aref (_r, 0, 0) = 1)
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_PZ_T_PREPARED_ORDER ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z14 prepared parameters in RETURN and in the pattern bind to their own markers\n";

registry_set ('__gql_parameterize', 'off');

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL parameterized read tests\n";
