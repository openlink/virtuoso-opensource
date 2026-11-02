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
--  GQL for Virtuoso - plan and translation reuse tests
--
--  Run via isql: isql <host>:<port> dba dba test_gql_cache.sql
--

ECHO "STARTED: GQL plan and translation reuse tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- ------------------------------------------------------------------
-- P1: GQL executes generated SPARQL through the compiled-plan cache.
--
-- A 30-branch UNION over an empty graph costs milliseconds to compile and
-- nothing to run.  Executed 20 times through GQL_EXEC_SPARQL it costs 20
-- compiles without plan reuse and about one with it.  The text carries a
-- per-run graph IRI so the first, timed execution is always a compile.
-- ------------------------------------------------------------------

create procedure DB.DBA.GQL_CACHE_T_PLAN_SPARQL (in _g varchar, in _branches integer) returns varchar
{
  declare _ses any;
  declare _i integer;
  _ses := string_output ();
  http (sprintf ('sparql select ?s ?o where { graph <%s> { ', _g), _ses);
  for (_i := 0; _i < _branches; _i := _i + 1)
    {
      if (_i > 0)
        http (' UNION ', _ses);
      http (sprintf ('{ ?s <urn:p:a%d> ?x . ?x <urn:p:b%d> ?o . ?o <urn:p:c%d> ?z . FILTER (?z > %d) }',
        _i, _i, _i, _i), _ses);
    }
  http (' } }', _ses);
  return string_output_string (_ses);
}
;

create procedure DB.DBA.GQL_CACHE_T_PLAN_REUSED () returns integer
{
  declare _q varchar;
  declare _r any;
  declare _i, _t0, _one, _twenty integer;
  _q := DB.DBA.GQL_CACHE_T_PLAN_SPARQL (sprintf ('urn:gql:plan:%d', msec_time ()), 30);
  _t0 := msec_time ();
  _r := DB.DBA.GQL_EXEC_SPARQL (_q);
  _one := msec_time () - _t0;
  _t0 := msec_time ();
  for (_i := 0; _i < 20; _i := _i + 1)
    _r := DB.DBA.GQL_EXEC_SPARQL (_q);
  _twenty := msec_time () - _t0;
  if (_one < 1)
    _one := 1;
  connection_set ('gql_cache_detail',
    sprintf ('first run %d ms, next 20 runs %d ms', _one, _twenty));
  if (_twenty < 5 * _one)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_PLAN_REUSED ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": P1 repeated SPARQL from GQL reuses its compiled plan\n";
select connection_get ('gql_cache_detail');
ECHO "    " $LAST[1] "\n";

-- ------------------------------------------------------------------
-- C1-C7: the process-wide translation cache primitives.
--
-- __gql_shape_cache_* hold translated templates for every connection.  An
-- entry is served to whoever asks for its key, so only DBA-owned code
-- (the GQL procedures) may read or write them; it must be bounded in
-- entries and bytes; a translation that started before property-graph DDL
-- must not be published after it; and keys are compared as whole strings.
-- ------------------------------------------------------------------

create procedure DB.DBA.GQL_CACHE_T_STAT (in _name varchar) returns integer
{
  declare _s any;
  _s := __gql_shape_cache_stats ();
  return aref (_s, position (_name, vector ('hits', 'misses', 'puts', 'evictions',
    'generation', 'entries', 'invalidations', 'bytes')) - 1);
}
;

-- C2: a put carrying the generation of a lookup made before a flush is
-- refused; one carrying the current generation is stored and read back.
create procedure DB.DBA.GQL_CACHE_T_GENERATION () returns integer
{
  declare _old, _new integer;
  declare _r any;
  _old := __gql_shape_cache_generation ();
  __gql_shape_cache_flush ();
  _new := __gql_shape_cache_generation ();
  if (_new <= _old)
    return 0;
  if (__gql_shape_cache_put ('c2-key', 'stale', _old) <> 0)
    return 0;
  if (aref (__gql_shape_cache_get ('c2-key'), 1) is not null)
    return 0;
  if (__gql_shape_cache_put ('c2-key', vector ('fresh', vector (1, 2)), _new) <> 1)
    return 0;
  _r := __gql_shape_cache_get ('c2-key');
  if (aref (_r, 0) = _new and serialize (aref (_r, 1)) = serialize (vector ('fresh', vector (1, 2))))
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_GENERATION ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C2 a stale-generation put is refused, a current one stored\n";

-- C3: a flush empties the cache and is counted.
create procedure DB.DBA.GQL_CACHE_T_FLUSH () returns integer
{
  declare _inv integer;
  __gql_shape_cache_put ('c3-key', 'v', __gql_shape_cache_generation ());
  _inv := DB.DBA.GQL_CACHE_T_STAT ('invalidations');
  __gql_shape_cache_flush ();
  if (aref (__gql_shape_cache_get ('c3-key'), 1) is null
      and DB.DBA.GQL_CACHE_T_STAT ('entries') = 0
      and DB.DBA.GQL_CACHE_T_STAT ('bytes') = 0
      and DB.DBA.GQL_CACHE_T_STAT ('invalidations') = _inv + 1)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_FLUSH ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C3 a flush empties the cache\n";

-- C4: 2,500 distinct entries never leave more than 2,000 behind.
create procedure DB.DBA.GQL_CACHE_T_BOUNDED () returns integer
{
  declare _i, _g integer;
  __gql_shape_cache_flush ();
  _g := __gql_shape_cache_generation ();
  for (_i := 0; _i < 2500; _i := _i + 1)
    __gql_shape_cache_put (sprintf ('c4-key-%d', _i), sprintf ('value %d', _i), _g);
  if (DB.DBA.GQL_CACHE_T_STAT ('entries') <= 2000
      and DB.DBA.GQL_CACHE_T_STAT ('evictions') > 0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_BOUNDED ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C4 the cache holds at most 2000 entries\n";

-- C5: an entry larger than the per-entry limit is not stored.
create procedure DB.DBA.GQL_CACHE_T_OVERSIZED () returns integer
{
  declare _g, _n integer;
  __gql_shape_cache_flush ();
  _g := __gql_shape_cache_generation ();
  _n := DB.DBA.GQL_CACHE_T_STAT ('entries');
  if (__gql_shape_cache_put ('c5-key', repeat ('x', 70000), _g) = 0
      and aref (__gql_shape_cache_get ('c5-key'), 1) is null
      and DB.DBA.GQL_CACHE_T_STAT ('entries') = _n)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_OVERSIZED ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C5 an oversized entry is not stored\n";

-- C6: keys are compared over their whole length, so two keys that agree
-- up to an embedded NUL are still different keys.
create procedure DB.DBA.GQL_CACHE_T_WHOLE_KEY () returns integer
{
  declare _g integer;
  __gql_shape_cache_flush ();
  _g := __gql_shape_cache_generation ();
  __gql_shape_cache_put (concat ('c6', chr (0), 'one'), 'first', _g);
  if (aref (__gql_shape_cache_get (concat ('c6', chr (0), 'two')), 1) is null
      and aref (__gql_shape_cache_get (concat ('c6', chr (0), 'one')), 1) = 'first')
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_WHOLE_KEY ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C6 keys that differ after a NUL are different keys\n";

-- C7: hits and misses are counted.
create procedure DB.DBA.GQL_CACHE_T_COUNTERS () returns integer
{
  declare _h, _m integer;
  __gql_shape_cache_put ('c7-key', 'v', __gql_shape_cache_generation ());
  _h := DB.DBA.GQL_CACHE_T_STAT ('hits');
  _m := DB.DBA.GQL_CACHE_T_STAT ('misses');
  __gql_shape_cache_get ('c7-key');
  __gql_shape_cache_get ('c7-absent');
  if (DB.DBA.GQL_CACHE_T_STAT ('hits') = _h + 1 and DB.DBA.GQL_CACHE_T_STAT ('misses') = _m + 1)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_CACHE_T_COUNTERS ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C7 hits and misses are counted\n";

-- C1: a user outside the DBA group cannot call the primitives directly:
-- an entry it could publish would be served to every connection.
DB.DBA.USER_DROP ('GQL_CACHE_U', 1);
create user GQL_CACHE_U;
reconnect GQL_CACHE_U;

select __gql_shape_cache_put ('c1-key', 'sparql insert data { <urn:x> <urn:y> <urn:z> }', __gql_shape_cache_generation ());
ECHO $IF $EQU $STATE "42000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C1 a non-DBA user cannot __gql_shape_cache_put (" $STATE ")\n";

select __gql_shape_cache_get ('c1-key');
ECHO $IF $EQU $STATE "42000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C1 a non-DBA user cannot __gql_shape_cache_get (" $STATE ")\n";

select __gql_shape_cache_flush ();
ECHO $IF $EQU $STATE "42000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C1 a non-DBA user cannot __gql_shape_cache_flush (" $STATE ")\n";

reconnect dba;

-- ------------------------------------------------------------------
-- T1-T10: GQL_EXECUTE serves a repeated read from the translation cache.
--
-- Each connection keeps translations in a private cache and publishes them
-- to the shared one; the shared cache's counters (puts, hits, misses) show
-- which path a call took.  Only reads are cached: a write's translation
-- mints node IRIs and must run fresh every time.
-- ------------------------------------------------------------------

sparql clear graph <urn:gql:cache>;
create procedure DB.DBA.GQL_CACHE_T_LOAD ()
{
  declare _i integer;
  for (_i := 0; _i < 12; _i := _i + 1)
    DB.DBA.GQL_RUN (sprintf ('INSERT (:Item { id: ''c%02d'', grp: %d })', _i, mod (_i, 3)),
      'urn:gql:cache');
  commit work;
}
;
DB.DBA.GQL_CACHE_T_LOAD ();

-- Rows GQL_EXECUTE streams, captured by exec-ing the call.
create procedure DB.DBA.GQL_CACHE_T_RUN (in _q varchar) returns any
{
  declare _st, _msg varchar;
  declare _meta, _data any;
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector (_q, 'urn:gql:cache'), 100000, _meta, _data);
  if (_st <> '00000')
    signal (_st, _msg);
  if (not isarray (_data))
    return vector ();  -- exec () gives 0 for no rows
  return _data;
}
;

-- T1, T2: the first call publishes its translation; a repeat on the same
-- connection neither translates nor asks the shared cache.
create procedure DB.DBA.GQL_CACHE_T_FIRST_AND_REPEAT (in _which integer) returns integer
{
  declare _q varchar;
  declare _p0, _p1, _p2, _m1, _m2 integer;
  declare _r1, _r2 any;
  _q := 'MATCH (n:Item) WHERE n.grp = 1 RETURN n.id AS id ORDER BY id';
  _p0 := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _r1 := DB.DBA.GQL_CACHE_T_RUN (_q);
  _p1 := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _m1 := DB.DBA.GQL_CACHE_T_STAT ('misses');
  _r2 := DB.DBA.GQL_CACHE_T_RUN (_q);
  _p2 := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _m2 := DB.DBA.GQL_CACHE_T_STAT ('misses');
  if (_which = 1)
    return case when _p1 = _p0 + 1 then 1 else 0 end;
  if (_which = 2)
    return case when _p1 = _p0 + 1 and _p2 = _p1 and _m2 = _m1 then 1 else 0 end;
  -- T4: the cached answer is the answer.
  return case when length (_r1) = 4 and serialize (_r1) = serialize (_r2) then 1 else 0 end;
}
;

__gql_shape_cache_flush ();
select 0;
select DB.DBA.GQL_CACHE_T_FIRST_AND_REPEAT (1);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T1 the first GQL_EXECUTE of a read publishes its translation\n";

__gql_shape_cache_flush ();
select 0;
select DB.DBA.GQL_CACHE_T_FIRST_AND_REPEAT (2);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T2 a repeat on the same connection is served by its private cache\n";

__gql_shape_cache_flush ();
select 0;
select DB.DBA.GQL_CACHE_T_FIRST_AND_REPEAT (4);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T4 a cached translation returns the same rows\n";

-- T3: a new connection is served by the shared cache.
__gql_shape_cache_flush ();
select length (DB.DBA.GQL_CACHE_T_RUN ('MATCH (n:Item) WHERE n.grp = 2 RETURN n.id AS id ORDER BY id'));
reconnect dba;
create procedure DB.DBA.GQL_CACHE_T_COLD_CONNECTION () returns integer
{
  declare _h, _p integer;
  declare _r any;
  _h := DB.DBA.GQL_CACHE_T_STAT ('hits');
  _p := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _r := DB.DBA.GQL_CACHE_T_RUN ('MATCH (n:Item) WHERE n.grp = 2 RETURN n.id AS id ORDER BY id');
  if (length (_r) = 4 and DB.DBA.GQL_CACHE_T_STAT ('hits') = _h + 1
      and DB.DBA.GQL_CACHE_T_STAT ('puts') = _p)
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_CACHE_T_COLD_CONNECTION ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T3 a new connection is served by the shared cache\n";

-- T5: an INSERT is never served from the cache.  Its translation mints the
-- new node's IRI, so a cached copy would insert the same node again.
create procedure DB.DBA.GQL_CACHE_T_WRITES_RUN_FRESH () returns integer
{
  declare _p integer;
  declare _st, _msg varchar;
  declare _r any;
  sparql clear graph <urn:gql:cache:w>;
  _p := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _st := '00000';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector ('INSERT (:Fresh { tag: ''same'' })', 'urn:gql:cache:w'));
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector ('INSERT (:Fresh { tag: ''same'' })', 'urn:gql:cache:w'));
  if (_st <> '00000')
    signal (_st, _msg);
  _r := DB.DBA.GQL_RUN ('MATCH (n:Fresh) RETURN n', 'urn:gql:cache:w');
  if (length (_r) = 2 and DB.DBA.GQL_CACHE_T_STAT ('puts') = _p)
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_CACHE_T_WRITES_RUN_FRESH ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T5 two identical anonymous-node INSERTs make two nodes\n";

-- T6: property-graph DDL invalidates the cache, whether it comes through
-- GQL or through the catalog procedures directly.
create procedure DB.DBA.GQL_CACHE_T_DDL () returns integer
{
  declare _g0, _g1, _g2 integer;
  declare _st, _msg varchar;
  DB.DBA.GQL_PG_DROP ('CacheT6', 1);
  _g0 := __gql_shape_cache_generation ();
  _st := '00000';
  exec ('DB.DBA.GQL_EXECUTE (?)', _st, _msg, vector ('CREATE PROPERTY GRAPH CacheT6'));
  if (_st <> '00000')
    signal (_st, _msg);
  _g1 := __gql_shape_cache_generation ();
  DB.DBA.GQL_PG_DROP ('CacheT6', 1);
  _g2 := __gql_shape_cache_generation ();
  if (_g1 > _g0 and _g2 > _g1)
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_CACHE_T_DDL ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T6 property-graph DDL and GQL_PG_DROP advance the cache generation\n";

-- T7: the translator's stash variables are inputs a user can set with
-- connection_set.  A value left in them must not shape the next
-- translation, which the shared cache would hand to other connections.
__gql_shape_cache_flush ();
connection_set ('__gql_pg_ontology_ns', 'http://poisoned.example/ontology#');
connection_set ('__gql_pg_is_property_graph', 1);
select 0;
select length (DB.DBA.GQL_CACHE_T_RUN ('MATCH (n:Item) WHERE n.grp = 0 RETURN n.id AS id ORDER BY id'));
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T7 a value left in the translator stash does not shape this connection's query\n";
reconnect dba;
select 0;
select length (DB.DBA.GQL_CACHE_T_RUN ('MATCH (n:Item) WHERE n.grp = 0 RETURN n.id AS id ORDER BY id'));
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T7 nor the translation another connection gets from the cache\n";

-- T8: registry __gql_trans_cache = off turns the cache off.
create procedure DB.DBA.GQL_CACHE_T_OFF () returns integer
{
  declare _p integer;
  declare _r any;
  registry_set ('__gql_trans_cache', 'off');
  __gql_shape_cache_flush ();
  _p := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _r := DB.DBA.GQL_CACHE_T_RUN ('MATCH (n:Item) RETURN n.id AS id ORDER BY id');
  _r := DB.DBA.GQL_CACHE_T_RUN ('MATCH (n:Item) RETURN n.id AS id ORDER BY id');
  registry_set ('__gql_trans_cache', 'on');
  if (length (_r) = 12 and DB.DBA.GQL_CACHE_T_STAT ('puts') = _p)
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_CACHE_T_OFF ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T8 __gql_trans_cache = off disables the cache\n";

-- T10: a query whose translation is too large to cache still runs.
create procedure DB.DBA.GQL_CACHE_T_LARGE () returns integer
{
  declare _ses any;
  declare _i, _p integer;
  declare _r any;
  _ses := string_output ();
  http ('MATCH (n:Item) WHERE n.id = ''c01'' OR n.id = ''', _ses);
  http (repeat ('never', 14000), _ses);
  http (''' RETURN n.id AS id', _ses);
  _p := DB.DBA.GQL_CACHE_T_STAT ('puts');
  _r := DB.DBA.GQL_CACHE_T_RUN (string_output_string (_ses));
  if (length (_r) = 1 and DB.DBA.GQL_CACHE_T_STAT ('puts') = _p)
    return 1;
  return 0;
}
;
select 0;
select DB.DBA.GQL_CACHE_T_LARGE ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T10 a translation too large to cache still runs\n";

-- T9: a user outside the DBA group who may run GQL is served by the cache
-- through the GQL procedures, which call the primitives as their owner.
DB.DBA.USER_DROP ('GQL_CACHE_V', 1);
create user GQL_CACHE_V;
grant SPARQL_SELECT to GQL_CACHE_V;
grant execute on DB.DBA.GQL_EXECUTE to GQL_CACHE_V;
grant execute on DB.DBA.GQL_TRANS_CACHE_STATS to GQL_CACHE_V;
__gql_shape_cache_flush ();
reconnect GQL_CACHE_V;
select aref (DB.DBA.GQL_TRANS_CACHE_STATS (), 2);
SET ARGV[2] $LAST[1];
DB.DBA.GQL_EXECUTE ('MATCH (n:Item) WHERE n.grp = 1 RETURN n.id AS id ORDER BY id', 'urn:gql:cache');
select 0;
select aref (DB.DBA.GQL_TRANS_CACHE_STATS (), 2) - $ARGV[2];
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T9 a non-DBA GQL user's read is translated and published (" $LAST[1] " put)\n";
DB.DBA.GQL_EXECUTE ('MATCH (n:Item) WHERE n.grp = 1 RETURN n.id AS id ORDER BY id', 'urn:gql:cache');
select 0;
select aref (DB.DBA.GQL_TRANS_CACHE_STATS (), 2) - $ARGV[2];
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T9 and its repeat is served by the cache (" $LAST[1] " put)\n";
reconnect dba;

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL plan and translation reuse tests\n";
