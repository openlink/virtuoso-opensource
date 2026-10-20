--
--  tvvec_refresh_log_limit.sql
--
--  A logged refresh has to fit its work into transactions whose log stays
--  under TransactionAfterImageLimit -- 50 MB by default -- or the server
--  aborts it with 40005/SR325.  The limit is lowered here so that 6,000 and
--  12,000 rows of a 64-dimension test model reach it.
--
--  1. Guard: the default batch of 32 at concurrency 4 fits a 4 MB limit.
--  2. At concurrency 4 the refresh links a wave of 16 batches into the graph
--     in one transaction.  16 batches of 256 are 4,096 rows, about 8 MB of log
--     here: over a 4 MB limit.  Batches of that size became reachable when the
--     batch cap went from 128 to 4,096.  The refresh has to commit as the log
--     fills, and leave the index complete: every row embedded right, and
--     bookkeeping that makes the next refresh find nothing to do.
--  3. At concurrency 1 each batch is one transaction, and a batch of 4,096
--     rows is over the same limit.
--  4. A bulk refresh (build = 'bulk') derives the whole graph at the end, and
--     the fast builder writes all of it in one transaction.  Its up-front
--     check (VEC95) is a lower bound -- 4.6 MB for these 12,000 nodes -- while
--     the fast build logged 21.6 MB, so under a 16 MB limit the refresh failed
--     at commit after building everything.  'auto' has to fall back to the
--     replay rebuild, which commits as it goes, as it already does under the
--     memory cap -- here under a 4 MB limit.  Guard: the same refresh unlogged
--     keeps the fast builder.
--  4b. The fast builder logs each packed page about once, less than the
--     graph's own pages, so the same logged refresh under 16 MB keeps it.
--  5. A bulk build's workers each stage a batch in a transaction of its own,
--     and at batch 4,096 one of them is over a 1 MB limit.
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

echo BOTH "STARTED: vector index refresh under TransactionAfterImageLimit\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'trl-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('trl-64', 'refresh log limit test model', 'internal:trl-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register trl-64 STATE=" $STATE "\n";

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create procedure DB.DBA.TRL_TEXT (in k integer) returns varchar
{
  return sprintf ('doc %d %d', mod (k, 32), 32 + mod (k / 32, 32));
}
;

--  N subjects <urn:trl:TAG:k> in graph G.
create procedure DB.DBA.TRL_LOAD (in g varchar, in tag varchar, in n integer)
{
  declare k integer;
  for (k := 0; k < n; k := k + 1)
    DB.DBA.RDF_QUAD_URI_L (g, sprintf ('urn:trl:%s:%d', tag, k), 'urn:trl:text', DB.DBA.TRL_TEXT (k));
  commit work;
}
;

create procedure DB.DBA.TRL_CREATE (in idx varchar, in g varchar, in build varchar := null)
{
  declare st, msg varchar;
  st := '00000';
  exec (sprintf ('sparql define input:storage "" drop silent vector index <%s>', idx), st, msg);
  st := '00000';
  exec (sprintf ('sparql define input:storage "" create vector index <%s> on graph <%s> for predicate <urn:trl:text> using model ''trl-64'' with (dimensions = 64, distance = ''cosine'', maintenance = ''manual''%s)',
                 idx, g, case when build is null then '' else sprintf (', build = ''%s''', build) end),
        st, msg);
  if (st <> '00000')
    signal (st, msg);
}
;

create table DB.DBA.TRL_M (M varchar primary key, V integer);
create table DB.DBA.TRL_S (M varchar primary key, S varchar);

create procedure DB.DBA.TRL_PUT (in _key varchar, in _val integer)
{
  insert replacing DB.DBA.TRL_M values (_key, _val);
  commit work;
}
;

--  Always one row, so a missing value cannot leave $LAST[1] from before.
create procedure DB.DBA.TRL_GET (in _key varchar) returns integer
{
  return coalesce ((select V from DB.DBA.TRL_M where M = _key), -1);
}
;

--  Refresh IDX with BATCH texts per embedding call and CONC calls at once, as
--  a caller in log mode MODE, under a TransactionAfterImageLimit of LIM bytes.
--  The error, or '' on success, goes to TRL_S under TAG and the rows the
--  refresh reports processing to TRL_M under TAG.  All in one statement, so no
--  commit in between resets the log mode.
create procedure DB.DBA.TRL_REFRESH (in idx varchar, in batch integer, in conc integer,
    in lim integer, in tag varchar, in mode integer := 1)
{
  declare prev_mode, old_lim, n integer;
  declare err varchar;
  declare r any;
  registry_set ('__vec_embed_batch_size', cast (batch as varchar));
  registry_set ('__vec_embed_concurrency', cast (conc as varchar));
  err := '';
  n := -1;
  old_lim := __dbf_set ('txn_after_image_limit', lim);
  prev_mode := log_enable (null);
  log_enable (mode, 1);
  {
    declare exit handler for sqlstate '*' { err := __SQL_STATE || ' ' || __SQL_MESSAGE; goto done; };
    r := DB.DBA.VEC_INDEX_REFRESH (idx);
    n := cast (regexp_substr ('refreshed, ([0-9]+) rows processed', cast (r[0][1] as varchar), 1) as integer);
  }
done:
  log_enable (prev_mode, 1);
  rollback work;
  __dbf_set ('txn_after_image_limit', old_lim);
  registry_set ('__vec_embed_batch_size', '');
  registry_set ('__vec_embed_concurrency', '');
  insert replacing DB.DBA.TRL_S values (tag, err);
  insert replacing DB.DBA.TRL_M values (tag, n);
  commit work;
}
;

create procedure DB.DBA.TRL_ERR (in tag varchar) returns varchar
{
  return coalesce ((select S from DB.DBA.TRL_S where M = tag), '<not run>');
}
;

create procedure DB.DBA.TRL_METRIC (in idx varchar, in k varchar) returns integer
{
  return cast (get_keyword (k, __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx)), -1) as integer);
}
;

create procedure DB.DBA.TRL_ACTIVE (in idx varchar) returns integer
{
  return DB.DBA.TRL_METRIC (idx, 'graph_nodes') - DB.DBA.TRL_METRIC (idx, 'deleted_nodes');
}
;

--  Rows in the index's bookkeeping table: one per key the refresh finished.
create procedure DB.DBA.TRL_BOOKKEPT (in idx varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  exec (sprintf ('select count (*) from %s', DB.DBA.VEC_INDEX_GENERATE_SOURCE_TABLE (idx)),
        st, msg, vector (), 0, md, rs);
  if (st <> '00000' or length (rs) = 0)
    return -1;
  return rs[0][0];
}
;

--  How many of subjects 0 .. N-1 of TAG are stored as the test embedding of
--  their own text.
create procedure DB.DBA.TRL_RIGHT (in idx varchar, in tag varchar, in n integer) returns integer
{
  declare st, msg, stmt varchar;
  declare md, rs, v, e any;
  declare i, k, good integer;
  stmt := sprintf ('select VE_EMBEDDING from DB.DBA.%s_vec_embeddings where VE_D_ID = ?',
                   DB.DBA.VEC_INDEX_GENERATE_NAME (idx));
  good := 0;
  for (k := 0; k < n; k := k + 1)
    {
      st := '00000';
      exec (stmt, st, msg, vector (iri_id_num (iri_to_id (sprintf ('urn:trl:%s:%d', tag, k)))), 0, md, rs);
      if (st <> '00000' or length (rs) <> 1)
        goto next;
      v := rs[0][0];
      e := __VEC_INDEX_TEST_EMBEDDING (64, DB.DBA.TRL_TEXT (k));
      if (VVEC_DIMENSION (v) <> VVEC_DIMENSION (e))
        goto next;
      for (i := 0; i < VVEC_DIMENSION (e); i := i + 1)
        if (abs (aref (v, i) - aref (e, i)) > 1e-6)
          goto next;
      good := good + 1;
     next:;
    }
  return good;
}
;

--  A search that must find something: the number of hits, -1 on an error.
create procedure DB.DBA.TRL_HITS (in idx varchar) returns integer
{
  declare q any;
  declare i integer;
  declare exit handler for sqlstate '*' { return -1; };
  q := make_array (64, 'any');
  for (i := 0; i < 64; i := i + 1)
    aset (q, i, 0.5e0);
  return length (__VEC_INDEX_SEARCH (DB.DBA.VEC_INDEX_GENERATE_NAME (idx), q, 10, 64));
}
;

create procedure DB.DBA.TRL_FORMAT (in idx varchar) returns varchar
{
  return get_keyword ('format', __VEC_INDEX_PAGE_STATS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx)));
}
;

create procedure DB.DBA.TRL_PAGES (in idx varchar) returns integer
{
  return cast (get_keyword ('node_pages', __VEC_INDEX_PAGE_STATS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx)), -1) as integer);
}
;

--  The transaction log a logged explicit fast rebuild of IDX writes, or -1.
create procedure DB.DBA.TRL_FAST_LOG (in idx varchar) returns integer
{
  declare prev_mode, n integer;
  n := -1;
  commit work;
  prev_mode := log_enable (null);
  log_enable (1, 1);
  {
    declare exit handler for sqlstate '*' { rollback work; goto done; };
    __VEC_INDEX_REBUILD (DB.DBA.VEC_INDEX_GENERATE_NAME (idx), 'fast');
    n := __trx_disk_log_length (0);
    commit work;
  }
done:
  log_enable (prev_mode, 1);
  return n;
}
;

sparql clear graph <urn:trl:g6>;
sparql clear graph <urn:trl:g12>;
DB.DBA.TRL_LOAD ('urn:trl:g6', 'a', 6000);
DB.DBA.TRL_LOAD ('urn:trl:g12', 'b', 12000);
sparql select count (*) from <urn:trl:g6> where { ?s <urn:trl:text> ?o };
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": 6,000 literals loaded, count=" $LAST[1] "\n";

-- ===========================================================================
-- 1. Guard: the default batch fits
-- ===========================================================================

DB.DBA.TRL_CREATE ('urn:trl:i1', 'urn:trl:g6');
DB.DBA.TRL_REFRESH ('urn:trl:i1', 32, 4, 4000000, 's1');
select DB.DBA.TRL_ERR ('s1');
ECHO BOTH ": s1 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s1') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": batch 32, concurrency 4 completes under a 4 MB limit, ok=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i1');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 6000 nodes, active=" $LAST[1] "\n";

-- ===========================================================================
-- 2. A wave over the limit, concurrency 4
-- ===========================================================================

DB.DBA.TRL_CREATE ('urn:trl:i2', 'urn:trl:g6');
DB.DBA.TRL_REFRESH ('urn:trl:i2', 256, 4, 4000000, 's2');
select DB.DBA.TRL_ERR ('s2');
ECHO BOTH ": s2 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s2') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": batch 256, concurrency 4 -- a 4,096-row wave -- completes under a 4 MB limit, ok=" $LAST[1] "\n";
select DB.DBA.TRL_GET ('s2');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": it reports 6000 rows processed, rows=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i2');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 6000 nodes, active=" $LAST[1] "\n";
select DB.DBA.TRL_BOOKKEPT ('urn:trl:i2');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": every key is recorded as done, bookkeeping rows=" $LAST[1] "\n";
select DB.DBA.TRL_RIGHT ('urn:trl:i2', 'a', 6000);
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": every row is stored as the embedding of its own text, right=" $LAST[1] "\n";
select DB.DBA.TRL_HITS ('urn:trl:i2');
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": a search finds 10 neighbours, hits=" $LAST[1] "\n";
DB.DBA.TRL_REFRESH ('urn:trl:i2', 256, 4, 4000000, 's2again');
select DB.DBA.TRL_GET ('s2again');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a second refresh finds nothing to do, rows=" $LAST[1] "\n";

-- ===========================================================================
-- 3. A batch over the limit, concurrency 1
-- ===========================================================================

DB.DBA.TRL_CREATE ('urn:trl:i3', 'urn:trl:g6');
DB.DBA.TRL_REFRESH ('urn:trl:i3', 4096, 1, 4000000, 's3');
select DB.DBA.TRL_ERR ('s3');
ECHO BOTH ": s3 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s3') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": batch 4096, concurrency 1 completes under a 4 MB limit, ok=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i3');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 6000 nodes, active=" $LAST[1] "\n";
select DB.DBA.TRL_BOOKKEPT ('urn:trl:i3');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": every key is recorded as done, bookkeeping rows=" $LAST[1] "\n";
select DB.DBA.TRL_RIGHT ('urn:trl:i3', 'a', 6000);
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": every row is stored as the embedding of its own text, right=" $LAST[1] "\n";
DB.DBA.TRL_REFRESH ('urn:trl:i3', 4096, 1, 4000000, 's3again');
select DB.DBA.TRL_GET ('s3again');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a second refresh finds nothing to do, rows=" $LAST[1] "\n";

-- ===========================================================================
-- 4. A bulk build over the limit
-- ===========================================================================

DB.DBA.TRL_CREATE ('urn:trl:i4', 'urn:trl:g12', 'bulk');
DB.DBA.TRL_REFRESH ('urn:trl:i4', 32, 4, 4000000, 's4');
select DB.DBA.TRL_ERR ('s4');
ECHO BOTH ": s4 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s4') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a logged bulk refresh of 12,000 rows completes under a 4 MB limit, ok=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i4');
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 12000 nodes, active=" $LAST[1] "\n";
select DB.DBA.TRL_FORMAT ('urn:trl:i4');
ECHO BOTH $IF $EQU $LAST[1] legacy "PASSED" "***FAILED";
ECHO BOTH ": built by the replay rebuild, format=" $LAST[1] "\n";
select __VEC_INDEX_HEALTH_RECHECK (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:trl:i4'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the graph is healthy, health=" $LAST[1] "\n";
select DB.DBA.TRL_HITS ('urn:trl:i4');
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": a search finds 10 neighbours, hits=" $LAST[1] "\n";

-- ===========================================================================
-- 4b. The fast builder's log fits
-- ===========================================================================

DB.DBA.TRL_CREATE ('urn:trl:i7', 'urn:trl:g12', 'bulk');
DB.DBA.TRL_REFRESH ('urn:trl:i7', 32, 4, 16000000, 's7');
select DB.DBA.TRL_ERR ('s7');
ECHO BOTH ": s7 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s7') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a logged bulk refresh of 12,000 rows completes under a 16 MB limit, ok=" $LAST[1] "\n";
select DB.DBA.TRL_FORMAT ('urn:trl:i7');
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": and keeps the fast builder, format=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i7');
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 12000 nodes, active=" $LAST[1] "\n";
select DB.DBA.TRL_HITS ('urn:trl:i7');
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": a search finds 10 neighbours, hits=" $LAST[1] "\n";

DB.DBA.TRL_PUT ('fastlog', DB.DBA.TRL_FAST_LOG ('urn:trl:i7'));
select DB.DBA.TRL_GET ('fastlog');
ECHO BOTH ": a logged fast rebuild of 12,000 nodes logs " $LAST[1] " bytes\n";
select DB.DBA.TRL_PAGES ('urn:trl:i7');
ECHO BOTH ": over " $LAST[1] " packed pages\n";
select case when DB.DBA.TRL_GET ('fastlog') > 0
    and DB.DBA.TRL_GET ('fastlog') < DB.DBA.TRL_PAGES ('urn:trl:i7') * 8192 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": it logs less than the graph's own pages, ok=" $LAST[1] "\n";
select DB.DBA.TRL_HITS ('urn:trl:i7');
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": the rebuilt graph finds 10 neighbours, hits=" $LAST[1] "\n";

--  Guard: nothing to fit when nothing is logged.
DB.DBA.TRL_CREATE ('urn:trl:i5', 'urn:trl:g12', 'bulk');
DB.DBA.TRL_REFRESH ('urn:trl:i5', 32, 4, 16000000, 's5', 2);
select DB.DBA.TRL_ERR ('s5');
ECHO BOTH ": s5 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s5') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the same bulk refresh unlogged completes, ok=" $LAST[1] "\n";
select DB.DBA.TRL_FORMAT ('urn:trl:i5');
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": and keeps the fast builder, format=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i5');
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 12000 nodes, active=" $LAST[1] "\n";

-- ===========================================================================
-- 5. A bulk worker's batch over the limit
-- ===========================================================================

--  A bulk build's workers stage their batches in transactions of their own,
--  and a logged one of 4,096 rows is over a 1 MB limit.
DB.DBA.TRL_CREATE ('urn:trl:i6', 'urn:trl:g6', 'bulk');
DB.DBA.TRL_REFRESH ('urn:trl:i6', 4096, 2, 1000000, 's6');
select DB.DBA.TRL_ERR ('s6');
ECHO BOTH ": s6 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRL_ERR ('s6') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a logged bulk refresh at batch 4096, concurrency 2 completes under a 1 MB limit, ok=" $LAST[1] "\n";
select DB.DBA.TRL_ACTIVE ('urn:trl:i6');
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 6000 nodes, active=" $LAST[1] "\n";
select DB.DBA.TRL_RIGHT ('urn:trl:i6', 'a', 6000);
ECHO BOTH $IF $EQU $LAST[1] 6000 "PASSED" "***FAILED";
ECHO BOTH ": every row is stored as the embedding of its own text, right=" $LAST[1] "\n";

select case when sys_stat ('txn_after_image_limit') = 50000000 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TransactionAfterImageLimit is back to 50000000, ok=" $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
sparql define input:storage "" drop silent vector index <urn:trl:i1>;
sparql define input:storage "" drop silent vector index <urn:trl:i2>;
sparql define input:storage "" drop silent vector index <urn:trl:i3>;
sparql define input:storage "" drop silent vector index <urn:trl:i4>;
sparql define input:storage "" drop silent vector index <urn:trl:i5>;
sparql define input:storage "" drop silent vector index <urn:trl:i6>;
sparql define input:storage "" drop silent vector index <urn:trl:i7>;
sparql clear graph <urn:trl:g6>;
sparql clear graph <urn:trl:g12>;
delete from DB.DBA.ONNX_MODELS where model_name = 'trl-64';

echo BOTH "COMPLETED: vector index refresh under TransactionAfterImageLimit\n";
