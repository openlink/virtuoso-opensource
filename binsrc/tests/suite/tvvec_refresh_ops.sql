--
--  tvvec_refresh_ops.sql
--
--  How a refresh of an RDF vector index behaves as an operation, rather than
--  what it embeds (tvvec_literal_ids covers that):
--
--  1. It owns its log mode.  A caller who ran log_enable (0) gets an unlogged
--     refresh; one who enabled row autocommit session-wide (log_enable (3))
--     gets a refresh that neither fails nor multiplies the log by committing
--     every graph page touch on its own; and every caller gets its own mode
--     back afterwards.
--  2. A sparse delta -- rows at both ends and in the middle of the key range --
--     re-embeds exactly those rows.  (A guard for the changed-row
--     classification, which is rewritten for speed.)
--  3. It does not lower the ONNX plugin's server-wide max_batch or
--     helper_pool_size, which other work depends on, and it says so when it
--     could not raise them.
--  4. build = 'bulk' links a small delta into the existing graph instead of
--     rebuilding the whole graph for it.
--
--  The transaction log is measured as the size of virtuoso.trx, which a
--  checkpoint truncates.  Each measured refresh runs inside ONE procedure
--  together with its log_enable: between two statements an ordinary commit
--  hands the connection a transaction whose log mode is the connection
--  default (lt_restart, lock.c), so a log_enable in a statement of its own
--  may not reach the refresh at all.
--
--  Every threshold is computed in SQL and asserted as 1 or 0.
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

echo BOTH "STARTED: vector index refresh as an operation\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'tro-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tro-64', 'refresh operations test model', 'internal:tro-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tro-64 STATE=" $STATE "\n";

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--  N subjects <urn:tro:<tag>:k>.  "doc a b" puts 1.0 at a (0..31) and b (32..63).
create procedure DB.DBA.TRO_LOAD (in g varchar, in tag varchar, in n integer)
{
  declare k integer;
  for (k := 0; k < n; k := k + 1)
    DB.DBA.RDF_QUAD_URI_L (g, sprintf ('urn:tro:%s:%d', tag, k), 'urn:tro:text',
        sprintf ('doc %d %d', mod (k, 32), 32 + mod (k / 32, 32)));
  commit work;
}
;

--  Replace subject k's literal.  No variable may share a name with an
--  RDF_QUAD column: PL resolves an unqualified G or S to the column, so
--  "where G = iri_to_id (g)" compares the column with itself and matches
--  every quad in the database.
create procedure DB.DBA.TRO_SET (in _graph varchar, in tag varchar, in k integer, in txt varchar)
{
  declare _subj varchar;
  _subj := sprintf ('urn:tro:%s:%d', tag, k);
  delete from DB.DBA.RDF_QUAD where G = iri_to_id (_graph) and S = iri_to_id (_subj);
  DB.DBA.RDF_QUAD_URI_L (_graph, _subj, 'urn:tro:text', txt);
  commit work;
}
;

create procedure DB.DBA.TRO_METRIC (in idx varchar, in k varchar) returns integer
{
  return cast (get_keyword (k, __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx)), -1) as integer);
}
;

create procedure DB.DBA.TRO_ACTIVE (in idx varchar) returns integer
{
  return DB.DBA.TRO_METRIC (idx, 'graph_nodes') - DB.DBA.TRO_METRIC (idx, 'deleted_nodes');
}
;

create procedure DB.DBA.TRO_ROWS_OF (in r any) returns integer
{
  return cast (regexp_substr ('refreshed, ([0-9]+) rows processed', cast (r[0][1] as varchar), 1) as integer);
}
;

create procedure DB.DBA.TRO_REFRESH (in idx varchar) returns integer
{
  return DB.DBA.TRO_ROWS_OF (DB.DBA.VEC_INDEX_REFRESH (idx));
}
;

--  1 when subject <urn:tro:TAG:K> of IDX is stored as the test embedding of
--  TXT, 0 when as something else, -1 when it has no embedding.  Asserting the
--  stored vector rather than a search's top hit keeps these checks exact: a
--  test vector that shares no position with any other is equidistant from
--  every node, and HNSW cannot navigate a flat landscape to it.
create procedure DB.DBA.TRO_IS (in idx varchar, in tag varchar, in k integer, in txt varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs, v, e any;
  declare i integer;
  st := '00000';
  exec (sprintf ('select VE_EMBEDDING from DB.DBA.%s_vec_embeddings where VE_D_ID = ?', DB.DBA.VEC_INDEX_GENERATE_NAME (idx)),
        st, msg, vector (iri_id_num (iri_to_id (sprintf ('urn:tro:%s:%d', tag, k)))), 0, md, rs);
  if (st <> '00000' or length (rs) = 0)
    return -1;
  v := rs[0][0];
  e := __VEC_INDEX_TEST_EMBEDDING (64, txt);
  if (VVEC_DIMENSION (v) <> VVEC_DIMENSION (e))
    return 0;
  for (i := 0; i < VVEC_DIMENSION (e); i := i + 1)
    if (abs (aref (v, i) - aref (e, i)) > 1e-6)
      return 0;
  return 1;
}
;

create table DB.DBA.TRO_M (M varchar primary key, V integer);

create procedure DB.DBA.TRO_PUT (in _key varchar, in _val integer)
{
  insert replacing DB.DBA.TRO_M values (_key, _val);
  commit work;
}
;

create procedure DB.DBA.TRO_GET (in _key varchar) returns integer
{
  return (select V from DB.DBA.TRO_M where M = _key);
}
;

--  Refresh IDX as a caller running in log mode MODE, in one statement.
--  Records the trx growth under <tag>_log, the rows processed under
--  <tag>_rows, and, measured before the mode is put back, the caller's mode
--  as the refresh left it: <tag>_cli (cli_log_mode) and <tag>_trx
--  (log_enable (null), the current transaction's mode).
create procedure DB.DBA.TRO_REFRESH_AS (in idx varchar, in mode integer, in tag varchar)
{
  declare prev_mode, t0, t1, rows_done, cli_after, trx_after integer;
  declare r any;
  prev_mode := log_enable (null);
  t0 := cast (file_stat ('virtuoso.trx', 1) as integer);
  log_enable (mode, 1);
  r := DB.DBA.VEC_INDEX_REFRESH (idx);
  cli_after := cli_log_mode ();
  trx_after := log_enable (null);
  log_enable (prev_mode, 1);
  commit work;
  t1 := cast (file_stat ('virtuoso.trx', 1) as integer);
  rows_done := DB.DBA.TRO_ROWS_OF (r);
  DB.DBA.TRO_PUT (tag || '_log', t1 - t0);
  DB.DBA.TRO_PUT (tag || '_rows', rows_done);
  DB.DBA.TRO_PUT (tag || '_cli', cli_after);
  DB.DBA.TRO_PUT (tag || '_trx', trx_after);
}
;

create procedure DB.DBA.TRO_CREATE (in idx varchar, in g varchar, in build varchar, in rebuild varchar := null)
{
  declare st, msg varchar;
  st := '00000';
  exec (sprintf ('sparql define input:storage "" drop silent vector index <%s>', idx), st, msg);
  st := '00000';
  exec (sprintf ('sparql define input:storage "" create vector index <%s> on graph <%s> for predicate <urn:tro:text> using model ''tro-64'' with (dimensions = 64, distance = ''cosine'', maintenance = ''manual''%s)',
                 idx, g, case when build is null then '' else sprintf (', build = ''%s''', build) end
                 || case when rebuild is null then '' else sprintf (', rebuild = ''%s''', rebuild) end),
        st, msg);
  if (st <> '00000')
    signal (st, msg);
}
;

-- ===========================================================================
-- 1. The refresh owns its log mode
-- ===========================================================================

sparql clear graph <urn:tro:g1>;
sparql clear graph <urn:tro:g0>;
sparql clear graph <urn:tro:g2>;
sparql clear graph <urn:tro:g3>;
DB.DBA.TRO_LOAD ('urn:tro:g1', 'a', 2000);
DB.DBA.TRO_LOAD ('urn:tro:g0', 'b', 2000);
DB.DBA.TRO_LOAD ('urn:tro:g2', 'c', 2000);
DB.DBA.TRO_LOAD ('urn:tro:g3', 'd', 2000);
DB.DBA.TRO_CREATE ('urn:tro:idx1', 'urn:tro:g1', null);
DB.DBA.TRO_CREATE ('urn:tro:idx0', 'urn:tro:g0', null);
DB.DBA.TRO_CREATE ('urn:tro:idx2', 'urn:tro:g2', null);
DB.DBA.TRO_CREATE ('urn:tro:idx3', 'urn:tro:g3', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": four 2000-subject graphs and their indexes STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  The same first refresh four times, in each log mode.  Mode 1 -- logging
--  on, no row autocommit -- is the reference.
checkpoint;
DB.DBA.TRO_REFRESH_AS ('urn:tro:idx1', 1, 'm1');
checkpoint;
DB.DBA.TRO_REFRESH_AS ('urn:tro:idx0', 0, 'm0');
checkpoint;
DB.DBA.TRO_REFRESH_AS ('urn:tro:idx2', 2, 'm2');
checkpoint;
DB.DBA.TRO_REFRESH_AS ('urn:tro:idx3', 3, 'm3');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": refresh in log modes 1, 0, 2 and 3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TRO_GET ('m1_log'), case when DB.DBA.TRO_GET ('m1_log') > 500000 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": control -- a logged refresh grows the log by " $LAST[1] " bytes (expect > 500000)\n";

select DB.DBA.TRO_GET ('m1_rows') + DB.DBA.TRO_GET ('m0_rows') + DB.DBA.TRO_GET ('m2_rows') + DB.DBA.TRO_GET ('m3_rows');
ECHO BOTH $IF $EQU $LAST[1] 8000 "PASSED" "***FAILED";
ECHO BOTH ": every mode embedded all its rows, total=" $LAST[1] " (expect 4 x 2000)\n";

select DB.DBA.TRO_GET ('m0_log'), case when 20 * DB.DBA.TRO_GET ('m0_log') < DB.DBA.TRO_GET ('m1_log') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": a log_enable (0) caller's refresh grows the log by " $LAST[1] " bytes (expect under 5% of the logged run)\n";

select DB.DBA.TRO_GET ('m0_cli');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": and leaves the caller's log mode at 0, cli_log_mode=" $LAST[1] "\n";

select DB.DBA.TRO_GET ('m2_log'), case when 20 * DB.DBA.TRO_GET ('m2_log') < DB.DBA.TRO_GET ('m1_log') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": a log_enable (2) caller's refresh grows the log by " $LAST[1] " bytes (expect under 5% of the logged run)\n";

select DB.DBA.TRO_GET ('m2_trx');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": and leaves the caller in mode 2, log_enable (null)=" $LAST[1] "\n";

--  Row autocommit is right for the one statement the refresh cannot split --
--  the enumeration -- and wrong everywhere else.  At this size the extra log
--  it costs is small (measured 4.55 MB against 4.42 MB before the refresh
--  owned its mode), so this is a guard on the volume; the failure the report
--  saw -- 40001/SR337 at the bookkeeping upsert -- needs a staging table large
--  enough for that upsert to run as parallel fragments, which is the sparse
--  delta over a multi-million-row corpus.
select DB.DBA.TRO_GET ('m3_log'), case when 2 * DB.DBA.TRO_GET ('m3_log') < 3 * DB.DBA.TRO_GET ('m1_log') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": a log_enable (3) caller's refresh grows the log by " $LAST[1] " bytes (expect under 1.5x the mode-1 run)\n";

select DB.DBA.TRO_GET ('m3_trx');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": and leaves the caller in mode 3, log_enable (null)=" $LAST[1] "\n";

-- ===========================================================================
-- 2. A sparse delta re-embeds exactly its rows
-- ===========================================================================

DB.DBA.TRO_SET ('urn:tro:g1', 'a', 0, 'first 40 50');
DB.DBA.TRO_SET ('urn:tro:g1', 'a', 1000, 'middle 41 51');
DB.DBA.TRO_SET ('urn:tro:g1', 'a', 1999, 'last 42 52');
delete from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tro:g1') and S in (iri_to_id ('urn:tro:a:500'), iri_to_id ('urn:tro:a:1500'));
commit work;

select DB.DBA.TRO_REFRESH ('urn:tro:idx1');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": a delta at both ends and the middle re-embeds " $LAST[1] " row(s) (expect 3)\n";

select DB.DBA.TRO_ACTIVE ('urn:tro:idx1');
ECHO BOTH $IF $EQU $LAST[1] 1998 "PASSED" "***FAILED";
ECHO BOTH ": live nodes=" $LAST[1] " (expect 1998: two subjects removed)\n";

select DB.DBA.TRO_IS ('urn:tro:idx1', 'a', 0, 'first 40 50');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the first key carries its new text, got " $LAST[1] "\n";

select DB.DBA.TRO_IS ('urn:tro:idx1', 'a', 1000, 'middle 41 51');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the middle key carries its new text, got " $LAST[1] "\n";

select DB.DBA.TRO_IS ('urn:tro:idx1', 'a', 1999, 'last 42 52');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the last key carries its new text, got " $LAST[1] "\n";

select DB.DBA.TRO_IS ('urn:tro:idx1', 'a', 999, sprintf ('doc %d %d', mod (999, 32), 32 + mod (999 / 32, 32)));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an unchanged neighbour keeps its text, got " $LAST[1] "\n";

select DB.DBA.TRO_IS ('urn:tro:idx1', 'a', 500, 'x') + DB.DBA.TRO_IS ('urn:tro:idx1', 'a', 1500, 'x');
ECHO BOTH $IF $EQU $LAST[1] -2 "PASSED" "***FAILED";
ECHO BOTH ": both removed subjects have no embedding, got " $LAST[1] "\n";

select DB.DBA.TRO_REFRESH ('urn:tro:idx1');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a refresh with nothing changed embeds " $LAST[1] " row(s)\n";

-- ===========================================================================
-- 3. The plugin's server-wide settings are raised, never lowered
-- ===========================================================================

create procedure DB.DBA.TRO_ONNX_READY () returns integer
{
  declare exit handler for sqlstate '*' { return 0; };
  if (__proc_exists ('ONNX_EMBED_BATCH', 2) is null)
    return 0;
  ONNX_EMBED_TEXT_FOR_MODEL ('granite-384-local', 'warm up');
  return 1;
}
;

--  How many 384-wide embeddings one N-text ONNX_EMBED_BATCH returned, or the
--  error text.
create procedure DB.DBA.TRO_BATCH (in n integer) returns varchar
{
  declare texts, r any;
  declare i, good integer;
  declare exit handler for sqlstate '*' { return __SQL_MESSAGE; };
  texts := make_array (n, 'any');
  for (i := 0; i < n; i := i + 1)
    aset (texts, i, sprintf ('sentence %d about plugin settings', i));
  r := ONNX_EMBED_BATCH ((select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local'), texts);
  good := 0;
  for (i := 0; i < length (r); i := i + 1)
    if (VVEC_DIMENSION (r[i]) = 384)
      good := good + 1;
  return cast (good as varchar);
}
;

--  The current value of a plugin setting, or -1.
create procedure DB.DBA.TRO_CFG (in k varchar) returns integer
{
  declare exit handler for sqlstate '*' { return -1; };
  return ONNX_CONFIG (k);
}
;

--  What VEC_INDEX_ONNX_RAISE reports: '' when it raised or had nothing to do,
--  else its note (or the error that it does not exist).
create procedure DB.DBA.TRO_RAISE (in k varchar, in want integer) returns varchar
{
  declare exit handler for sqlstate '*' { return 'ERROR ' || __SQL_MESSAGE; };
  return coalesce (DB.DBA.VEC_INDEX_ONNX_RAISE (k, want), '');
}
;

select DB.DBA.TRO_ONNX_READY ();
ECHO BOTH ": ONNX plugin with granite-384-local available=" $LAST[1] "\n";

--  An operator's setting, larger than any refresh asks for.
select case when DB.DBA.TRO_ONNX_READY () = 0 then 1 else ONNX_CONFIG ('max_batch', 100) end;

--  The refresh asks for its own batch size, 32.
select DB.DBA.TRO_REFRESH ('urn:tro:idx1');

select case when DB.DBA.TRO_ONNX_READY () = 0 then '64' else DB.DBA.TRO_BATCH (64) end;
ECHO BOTH $IF $EQU $LAST[1] 64 "PASSED" "***FAILED";
ECHO BOTH ": after a refresh a 64-text batch still runs -- max_batch was not lowered, got " $LAST[1] "\n";

select case when DB.DBA.TRO_ONNX_READY () = 0 then 100 else DB.DBA.TRO_CFG ('max_batch') end;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": ONNX_CONFIG ('max_batch') reads the setting back, got " $LAST[1] "\n";

select case when DB.DBA.TRO_ONNX_READY () = 0 then 1
  else (case when DB.DBA.TRO_RAISE ('max_batch', 50) = '' then 1 else 0 end) end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": raising max_batch to a lower value is a silent no-op, ok=" $LAST[1] "\n";

select case when DB.DBA.TRO_ONNX_READY () = 0 then 100 else DB.DBA.TRO_CFG ('max_batch') end;
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": and leaves it at 100, got " $LAST[1] "\n";

select case when DB.DBA.TRO_ONNX_READY () = 0 then '' else DB.DBA.TRO_RAISE ('max_batch', 120) end;
select case when DB.DBA.TRO_ONNX_READY () = 0 then 120 else DB.DBA.TRO_CFG ('max_batch') end;
ECHO BOTH $IF $EQU $LAST[1] 120 "PASSED" "***FAILED";
ECHO BOTH ": raising it to a higher value takes effect, got " $LAST[1] "\n";

select case when DB.DBA.TRO_ONNX_READY () = 0 then 0
  else (case when DB.DBA.TRO_RAISE ('helper_pool_size', 40) like '%helper_pool_size%' then 1 else 0 end) end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an out-of-range helper_pool_size comes back as a note naming it, ok=" $LAST[1] "\n";

select case when DB.DBA.TRO_ONNX_READY () = 0 then 1 else ONNX_CONFIG ('max_batch', 32) end;

-- ===========================================================================
-- 4. build = 'bulk' links a small delta instead of rebuilding
-- ===========================================================================

create procedure DB.DBA.TRO_LOAD_BULK ()
{
  declare k integer;
  for (k := 0; k < 200; k := k + 1)
    DB.DBA.RDF_QUAD_URI_L ('urn:tro:g4', sprintf ('urn:tro:e:%d', k), 'urn:tro:text',
        sprintf ('item %d %d', mod (k, 32), 32 + k / 32));
  commit work;
}
;
sparql clear graph <urn:tro:g4>;
DB.DBA.TRO_LOAD_BULK ();
--  rebuild = 'fast' so the graph is packed, as it is for any bulk index of
--  10,000 rows or more: a linked delta then writes into packed records.
DB.DBA.TRO_CREATE ('urn:tro:bulk', 'urn:tro:g4', 'bulk', 'fast');
select DB.DBA.TRO_REFRESH ('urn:tro:bulk');
ECHO BOTH $IF $EQU $LAST[1] 200 "PASSED" "***FAILED";
ECHO BOTH ": bulk first build embedded " $LAST[1] " rows\n";

select DB.DBA.TRO_METRIC ('urn:tro:bulk', 'deleted_nodes') + 10 * (200 - DB.DBA.TRO_ACTIVE ('urn:tro:bulk'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- 200 live nodes, none deleted, got " $LAST[1] "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:tro:bulk')));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the bulk graph is packed, format=" $LAST[1] "\n";

--  Three changes against a 200-node graph: 1.5%.
DB.DBA.TRO_SET ('urn:tro:g4', 'e', 5, 'changed 39 50');
DB.DBA.TRO_SET ('urn:tro:g4', 'e', 100, 'changed 40 51');
DB.DBA.TRO_SET ('urn:tro:g4', 'e', 199, 'changed 41 52');
select DB.DBA.TRO_REFRESH ('urn:tro:bulk');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": the delta re-embedded " $LAST[1] " rows\n";

--  A full rebuild compacts the graph: no deleted nodes.  Linking the delta
--  leaves the three replaced nodes behind as deleted.
select DB.DBA.TRO_METRIC ('urn:tro:bulk', 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": a 1.5% delta was linked, not rebuilt -- deleted_nodes=" $LAST[1] " (0 means the whole graph was rebuilt)\n";

select DB.DBA.TRO_ACTIVE ('urn:tro:bulk');
ECHO BOTH $IF $EQU $LAST[1] 200 "PASSED" "***FAILED";
ECHO BOTH ": live nodes=" $LAST[1] "\n";

select DB.DBA.TRO_IS ('urn:tro:bulk', 'e', 100, 'changed 40 51');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a linked row carries its new text, got " $LAST[1] "\n";

--  Sixty changes: 30%, over the 10% default -- rebuilt.
create procedure DB.DBA.TRO_CHANGE_MANY ()
{
  declare k integer;
  for (k := 0; k < 60; k := k + 1)
    DB.DBA.TRO_SET ('urn:tro:g4', 'e', 10 + k, sprintf ('again %d %d', mod (k, 32), 40 + k / 32));
}
;
DB.DBA.TRO_CHANGE_MANY ();
select DB.DBA.TRO_REFRESH ('urn:tro:bulk');
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": the large delta re-embedded " $LAST[1] " rows\n";

select DB.DBA.TRO_METRIC ('urn:tro:bulk', 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a 30% delta rebuilt the graph, deleted_nodes=" $LAST[1] "\n";

--  0 turns the shortcut off.
registry_set ('__vec_bulk_delta_pct', '0');
DB.DBA.TRO_SET ('urn:tro:g4', 'e', 150, 'single 42 53');
select DB.DBA.TRO_REFRESH ('urn:tro:bulk');
select DB.DBA.TRO_METRIC ('urn:tro:bulk', 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": with __vec_bulk_delta_pct 0 even one change rebuilds, deleted_nodes=" $LAST[1] "\n";
registry_set ('__vec_bulk_delta_pct', '');

-- ===========================================================================
-- Cleanup
-- ===========================================================================
sparql define input:storage "" drop silent vector index <urn:tro:idx1>;
sparql define input:storage "" drop silent vector index <urn:tro:idx0>;
sparql define input:storage "" drop silent vector index <urn:tro:idx2>;
sparql define input:storage "" drop silent vector index <urn:tro:idx3>;
sparql define input:storage "" drop silent vector index <urn:tro:bulk>;
sparql clear graph <urn:tro:g0>;
sparql clear graph <urn:tro:g1>;
sparql clear graph <urn:tro:g2>;
sparql clear graph <urn:tro:g3>;
sparql clear graph <urn:tro:g4>;
drop table DB.DBA.TRO_M;
delete from DB.DBA.ONNX_MODELS where model_name = 'tro-64';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: vector index refresh as an operation\n";
