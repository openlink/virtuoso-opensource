--
--  tvvec_rebuild_guard.sql
--
--  Two things an operator of a large vector index needs from a fast rebuild:
--
--  1. A logged fast rebuild whose transaction log would not fit under
--     TransactionAfterImageLimit fails BEFORE it touches the graph.  The limit
--     only marks the transaction blown off (TXN_CHECK_LOG_IMAGE, log.c), so
--     without a check up front the failure arrives at commit -- after the whole
--     in-memory build and the serialize, with the old graph already reset.  A
--     2-hour build was lost exactly this way.
--  2. The fast builder's memory cap and thread count can be changed without a
--     restart.  Both were getenv-only, and the one way to get more than 8
--     threads from a refresh -- VVEC_FAST_REBUILD -- also forces the method and
--     skips the memory guard.  The registry keys __vec_fast_rebuild_max_bytes
--     and __vec_rebuild_threads override the environment.
--
--  The thread count is observable only in the rebuild's log line, so the
--  driver checks that part.
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

echo BOTH "STARTED: vector index fast-rebuild guards\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'trg-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('trg-64', 'rebuild guard test model', 'internal:trg-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register trg-64 STATE=" $STATE "\n";

create table DB.DBA.TRG_T (ID integer not null primary key, TXT varchar);
CREATE VECTOR INDEX TRG_IDX ON DB.DBA.TRG_T (TXT) USING 'trg-64' WITH (dimensions = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TRG_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.TRG_STAGE (in n integer)
{
  declare ids, vecs, v any;
  declare i, j, b integer;
  b := 0;
  ids := make_array (500, 'any');
  vecs := make_array (500, 'any');
  for (i := 1; i <= n; i := i + 1)
    {
      v := make_array (64, 'any');
      for (j := 0; j < 64; j := j + 1)
        aset (v, j, (rnd (10000) + 1) / 10000.0e0);
      aset (ids, b, i);
      aset (vecs, b, v);
      b := b + 1;
      if (b = 500)
        {
          __VEC_INDEX_STAGE_BATCH ('TRG_IDX', ids, vecs);
          commit work;
          b := 0;
        }
    }
  if (b > 0)
    __VEC_INDEX_STAGE_BATCH ('TRG_IDX', subseq (ids, 0, b), subseq (vecs, 0, b));
  commit work;
}
;
DB.DBA.TRG_STAGE (12000);

create procedure DB.DBA.TRG_KV (in k varchar) returns any
{
  return get_keyword (k, __VEC_INDEX_PAGE_STATS ('TRG_IDX'));
}
;

--  Rebuild as a caller in log mode MODE (in one statement, so no commit in
--  between can reset the mode) and return '' on success or the error.
create procedure DB.DBA.TRG_REBUILD (in mode integer, in method varchar := null, in threads integer := null) returns varchar
{
  declare prev_mode integer;
  declare err varchar;
  prev_mode := log_enable (null);
  err := '';
  log_enable (mode, 1);
  {
    declare exit handler for sqlstate '*' { err := __SQL_STATE || ' ' || __SQL_MESSAGE; goto done; };
    if (method is null)
      __VEC_INDEX_REBUILD ('TRG_IDX');
    else if (threads is null)
      __VEC_INDEX_REBUILD ('TRG_IDX', method);
    else
      __VEC_INDEX_REBUILD ('TRG_IDX', method, threads);
    commit work;
  }
done:
  if (err <> '')
    rollback work;
  log_enable (prev_mode, 1);
  return err;
}
;

--  A search that must find something; the number of hits.
create procedure DB.DBA.TRG_HITS () returns integer
{
  declare q any;
  declare i integer;
  declare exit handler for sqlstate '*' { return -1; };
  q := make_array (64, 'any');
  for (i := 0; i < 64; i := i + 1)
    aset (q, i, 0.5e0);
  return length (__VEC_INDEX_SEARCH ('TRG_IDX', q, 10, 64));
}
;

--  The graph to protect: built once, unlogged.
select DB.DBA.TRG_REBUILD (2, 'fast', 2);
ECHO BOTH ": initial unlogged fast rebuild, error=" $LAST[1] "\n";
select get_keyword ('graph_nodes', __VEC_INDEX_METRICS ('TRG_IDX'));
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- graph_nodes=" $LAST[1] "\n";

-- ===========================================================================
-- 1. A logged fast rebuild that cannot fit fails first, not last
-- ===========================================================================

create table DB.DBA.TRG_M (M varchar primary key, V integer);
create table DB.DBA.TRG_S (M varchar primary key, S varchar);
insert into DB.DBA.TRG_M values ('limit', __dbf_set ('txn_after_image_limit', 1000000));
commit work;
select V from DB.DBA.TRG_M where M = 'limit';
ECHO BOTH ": TransactionAfterImageLimit lowered from " $LAST[1] " to 1000000 bytes\n";

--  12,000 vectors of 64 floats are 3 MB before a single neighbour list: this
--  cannot fit in 1 MB of log, and that is knowable before building anything.
insert replacing DB.DBA.TRG_S values ('refusal', DB.DBA.TRG_REBUILD (1, 'fast', 2));
commit work;
select case when S like '%VEC95%' then 1 else 0 end from DB.DBA.TRG_S where M = 'refusal';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a logged fast rebuild over the limit is refused up front with VEC95, ok=" $LAST[1] "\n";

select S from DB.DBA.TRG_S where M = 'refusal';
ECHO BOTH ": (the refusal reads: " $LAST[1] ")\n";

select __VEC_INDEX_HEALTH_RECHECK ('TRG_IDX');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the old graph was not touched -- health=" $LAST[1] "\n";

select DB.DBA.TRG_HITS ();
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": and it still answers, hits=" $LAST[1] "\n";

select case when DB.DBA.TRG_REBUILD (2, 'fast', 2) = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the same rebuild with log_enable (2) goes through under the same limit, ok=" $LAST[1] "\n";

select get_keyword ('graph_nodes', __VEC_INDEX_METRICS ('TRG_IDX'));
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes=" $LAST[1] "\n";

select __dbf_set ('txn_after_image_limit', (select V from DB.DBA.TRG_M where M = 'limit'));
select case when sys_stat ('txn_after_image_limit') = (select V from DB.DBA.TRG_M where M = 'limit') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TransactionAfterImageLimit restored, ok=" $LAST[1] "\n";

-- ===========================================================================
-- 2. The fast builder's knobs, at runtime
-- ===========================================================================

--  A 1000-byte cap: 'auto' must fall back to replay, which writes one legacy
--  page per node instead of packed pages.
registry_set ('__vec_fast_rebuild_max_bytes', '1000');
select DB.DBA.TRG_REBUILD (2);
select DB.DBA.TRG_KV ('format');
ECHO BOTH $IF $EQU $LAST[1] legacy "PASSED" "***FAILED";
ECHO BOTH ": __vec_fast_rebuild_max_bytes=1000 makes auto fall back to replay, format=" $LAST[1] "\n";

registry_set ('__vec_fast_rebuild_max_bytes', '');
select DB.DBA.TRG_REBUILD (2);
select DB.DBA.TRG_KV ('format');
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": cleared, auto picks the fast builder again, format=" $LAST[1] "\n";

--  Three threads from the registry; an explicit argument still wins.  The
--  driver reads both counts back from the server log.
registry_set ('__vec_rebuild_threads', '3');
select DB.DBA.TRG_REBUILD (2);
select DB.DBA.TRG_REBUILD (2, 'fast', 5);
registry_set ('__vec_rebuild_threads', '');

select get_keyword ('graph_nodes', __VEC_INDEX_METRICS ('TRG_IDX'));
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes after every rebuild=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
drop table DB.DBA.TRG_T;
drop table DB.DBA.TRG_M;
drop table DB.DBA.TRG_S;
delete from DB.DBA.ONNX_MODELS where model_name = 'trg-64';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: vector index fast-rebuild guards\n";
