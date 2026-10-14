--
--  tvvec_space.sql
--
--  Page accounting for a vector index: does the database get the HNSW graph's
--  pages back when the index goes away, and does it report them while it is
--  there?
--
--  Both questions are about pages on disk, so every measurement is taken after
--  a checkpoint: SYS_INDEX_SPACE_STATS reads pages from the file and skips
--  anything still in the checkpoint remap, and st_db_free_pages is only
--  recomputed by a status () call.
--
--  The quantity tracked is used = total - free, never the file size.  A
--  Virtuoso database file grows and never shrinks, so freeing a thousand pages
--  moves the free count and leaves the total exactly where it was.
--
--  Must run on a fresh database.  Pages leaked before the fix are never handed
--  back, so a reused database has no baseline to return to.
--
--  Every threshold here is computed in SQL and asserted as 1 or 0.  isql's $GT
--  and $LT compare with tcscmp (), i.e. as strings, so $GT 999 1000 is true --
--  a threshold asserted with them reports the wrong answer in both directions.
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

echo BOTH "STARTED: VVEC index space accounting\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": init model registry STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- A deterministic in-process model, as in tvvec_crash_recovery.sql: no ONNX
-- plugin and no helper process, so this driver runs on a default build.  64
-- dimensions rather than the 8 the durability fixtures use, because the
-- quantity under test is how many pages the graph occupies.
delete from DB.DBA.ONNX_MODELS where model_name = 'vspc-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vspc-64', 'space accounting test model', 'internal:vspc-64',
          'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vspc-64 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- used = total - free.  status ('') is what recomputes st_db_free_pages
-- (srvstat.c), so it is called for its side effect and its report discarded.
create procedure DB.DBA.VSPC_USED () returns integer
{
  declare ignore any;
  ignore := status ('');
  return cast (sys_stat ('st_db_pages') as integer)
       - cast (sys_stat ('st_db_free_pages') as integer);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_USED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VSPC_MARK (mk_name varchar not null primary key, mk_used integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_MARK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Reads the page count before writing the mark, so a mark never counts itself.
-- The previous mark's row is in the next reading; one row in one small table is
-- noise against a graph of a thousand pages.
create procedure DB.DBA.VSPC_SET (in nm varchar) returns integer
{
  declare u integer;
  u := DB.DBA.VSPC_USED ();
  delete from DB.DBA.VSPC_MARK where mk_name = nm;
  insert into DB.DBA.VSPC_MARK (mk_name, mk_used) values (nm, u);
  return u;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_SET STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.VSPC_DELTA (in a varchar, in b varchar) returns integer
{
  return (select mk_used from DB.DBA.VSPC_MARK where mk_name = a)
       - (select mk_used from DB.DBA.VSPC_MARK where mk_name = b);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_DELTA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- The graph's own pages as the index space stats report them.  A vector index
-- has no rows, so its pages are reported as blob pages; 0 is also what a
-- missing row means, which is what the stats produced before they counted
-- DPF_VEC at all.
create procedure DB.DBA.VSPC_GRAPH_PAGES (in idx varchar) returns integer
{
  return coalesce ((select ISS_BLOB_PAGES from DB.DBA.SYS_INDEX_SPACE_STATS
                     where upper (ISS_KEY_NAME) = upper (idx)), 0);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_GRAPH_PAGES STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VSPC_T (id integer not null primary key, content varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Ids start at 1: a vector index requires an integer row id and rejects 0.
create procedure DB.DBA.VSPC_SEED (in n integer) returns integer
{
  declare i integer;
  i := 1;
  while (i <= n)
    {
      insert into DB.DBA.VSPC_T (id, content)
        values (i, concat ('doc ', cast (i as varchar), ' body text ',
                           cast (mod (i, 97) as varchar)));
      i := i + 1;
    }
  return n;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_SEED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VSPC_SEED (1000);
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": seed VSPC_T rows=" $LAST[1] " (expect 1000)\n";

-- ===========================================================================
--  PHASE A -- the graph is built, and the stats can see it.
-- ===========================================================================

checkpoint;
select DB.DBA.VSPC_SET ('before_create');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'before_create';
ECHO BOTH ": used pages before create=" $LAST[1] "\n";

CREATE VECTOR INDEX VSPC_IDX ON DB.DBA.VSPC_T (content) USING 'vspc-64'
  WITH (dimensions = 64, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VSPC_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": embeddings after create=" $LAST[1] " (expect 1000)\n";

checkpoint;
select DB.DBA.VSPC_SET ('with_index');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'with_index';
ECHO BOTH ": used pages with index=" $LAST[1] "\n";

-- The measurement is only worth making if the index actually cost something.
-- A thousand 64-dimension vectors at hnsw_m 16 took 1049 pages when this was
-- written; 200 is a floor no build of that index can fall below without the
-- graph being absent.
select DB.DBA.VSPC_DELTA ('with_index', 'before_create') as consumed,
       case when DB.DBA.VSPC_DELTA ('with_index', 'before_create') > 199 then 1 else 0 end as ok;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": index consumed=" $LAST[1] " pages (need >199 for the rest to mean anything)\n";

-- The graph is the largest of the three objects a vector index owns, so its
-- page count has to be a real fraction of what the index consumed.  Before
-- DPF_VEC was counted, SYS_INDEX_SPACE_STATS had no row for this key at all.
select DB.DBA.VSPC_GRAPH_PAGES ('VSPC_IDX') as blob_pages,
       case when DB.DBA.VSPC_GRAPH_PAGES ('VSPC_IDX') > 199 then 1 else 0 end as ok;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": SYS_INDEX_SPACE_STATS ISS_BLOB_PAGES for VSPC_IDX=" $LAST[1] " (expect >199)\n";

-- And it reports no ROW pages, because it has no rows.  key_ki () starts every
-- entry at ki_pages = 1, which is right for a B-tree or column key -- the entry
-- is created while looking at one of its pages -- and wrong for this one, which
-- is created from the DPF_VEC arm and never counts a row page.  ISS_PAGES is
-- ISS_ROW_PAGES + ISS_BLOB_PAGES, so the one page lands in the total a user
-- reads.
select ISS_NROWS, ISS_ROW_PAGES from DB.DBA.SYS_INDEX_SPACE_STATS
  where upper (ISS_KEY_NAME) = 'VSPC_IDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": vector key has no rows, ISS_NROWS=" $LAST[1] " (expect 0)\n";
ECHO BOTH $IF $EQU $LAST[2] 0 "PASSED" "***FAILED";
ECHO BOTH ": vector key reports no row pages, ISS_ROW_PAGES=" $LAST[2] " (expect 0)\n";

-- so the total it contributes is exactly its graph.
select case when (select ISS_PAGES from DB.DBA.SYS_INDEX_SPACE_STATS
                   where upper (ISS_KEY_NAME) = 'VSPC_IDX')
            = (select ISS_BLOB_PAGES from DB.DBA.SYS_INDEX_SPACE_STATS
                   where upper (ISS_KEY_NAME) = 'VSPC_IDX')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": vector key ISS_PAGES equals its ISS_BLOB_PAGES flag=" $LAST[1] "\n";

-- ===========================================================================
--  PHASE B -- a rebuild replaces the graph without accumulating a second one.
--
--  The reset walk and the drop walk are now the same function.  A rebuild that
--  grew the file by another graph's worth would mean the shared walk stopped
--  freeing.
-- ===========================================================================

select __VEC_INDEX_REBUILD ('VSPC_IDX');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": rebuild VSPC_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
select DB.DBA.VSPC_SET ('after_rebuild');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'after_rebuild';
ECHO BOTH ": used pages after rebuild=" $LAST[1] "\n";

select case when DB.DBA.VSPC_DELTA ('after_rebuild', 'with_index') * 2
              < DB.DBA.VSPC_DELTA ('with_index', 'before_create')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": rebuild did not accumulate a second graph flag=" $LAST[1] "\n";

-- ===========================================================================
--  PHASE C -- DROP INDEX gives the graph's pages back.
--
--  This is the leak.  vvec_key_dropped () freed the root and nothing else, and
--  nothing else ever reclaimed the rest: dbs_cpt_extents () finalizes a dropped
--  tree's extents wholesale only for a tree that owns its extent map, and a
--  vector index deliberately stays on the shared one.
--
--  There is no DROP VECTOR INDEX in the grammar; a vector index is dropped with
--  plain DROP INDEX.
-- ===========================================================================

drop index VSPC_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VSPC_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
select DB.DBA.VSPC_SET ('after_drop');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'after_drop';
ECHO BOTH ": used pages after drop=" $LAST[1] "\n";

select DB.DBA.VSPC_DELTA ('after_drop', 'before_create');
ECHO BOTH ": pages not returned by the drop=" $LAST[1] "\n";

-- At least three quarters of what the index cost has to come back.  Measured
-- pre-fix: 1049 consumed, 1007 still held after the drop -- only the hidden
-- table's B-tree came back.  Post-fix 7 are still held: the catalog rows and
-- the mark table.
select case when DB.DBA.VSPC_DELTA ('after_drop', 'before_create') * 4
              < DB.DBA.VSPC_DELTA ('with_index', 'before_create')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": drop returned the graph's pages flag=" $LAST[1] "\n";

-- ===========================================================================
--  PHASE D -- the same through DROP TABLE, which is the other route into
--  key_dropped () and the one a user is more likely to take.
-- ===========================================================================

checkpoint;
select DB.DBA.VSPC_SET ('d_before');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'd_before';
ECHO BOTH ": used pages before second create=" $LAST[1] "\n";

CREATE VECTOR INDEX VSPC_IDX2 ON DB.DBA.VSPC_T (content) USING 'vspc-64'
  WITH (dimensions = 64, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_IDX2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
select DB.DBA.VSPC_SET ('d_with_index');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'd_with_index';
ECHO BOTH ": used pages with second index=" $LAST[1] "\n";

select DB.DBA.VSPC_DELTA ('d_with_index', 'd_before') as consumed,
       case when DB.DBA.VSPC_DELTA ('d_with_index', 'd_before') > 199 then 1 else 0 end as ok;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": second index consumed=" $LAST[1] " pages (need >199)\n";

drop table DB.DBA.VSPC_T;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VSPC_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
select DB.DBA.VSPC_SET ('d_after');
select mk_used from DB.DBA.VSPC_MARK where mk_name = 'd_after';
ECHO BOTH ": used pages after drop table=" $LAST[1] "\n";

select DB.DBA.VSPC_DELTA ('d_after', 'd_before');
ECHO BOTH ": pages not returned by the drop table=" $LAST[1] "\n";

-- Dropping the table frees the base table too, so this delta may well be
-- negative; the assertion is one-sided on purpose.
select case when DB.DBA.VSPC_DELTA ('d_after', 'd_before') * 4
              < DB.DBA.VSPC_DELTA ('d_with_index', 'd_before')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": drop table returned the graph's pages flag=" $LAST[1] "\n";

-- ===========================================================================
--  PHASE E -- a vector-index drop excludes other transactions.
--
--  Dropping a vector index frees its whole HNSW graph (phase C measured 1001
--  pages).  A search walking that graph holds a reference to a page it has
--  already released the latch on, so the drop has to exclude graph readers for
--  the same reason a rebuild does.
--
--  DDL takes the global lock only past MIN_FOR_ATOMIC, which is 10,000 rows
--  (ddlrun.c) -- a threshold about how long a B-tree drop takes, not about
--  whether a concurrent reader is safe.  Every table here is far below it.
--
--  Asserted through what the global lock does to other transactions rather than
--  through timing: srv_global_lock () calls cpt_rollback (LT_KILL_ROLLBACK),
--  which rolls back every other open transaction.  So a background job holding
--  an uncommitted row loses it, and reports SQLSTATE 40001, exactly when the
--  drop was atomic.  Both outcomes are asserted, so the test says which.
-- ===========================================================================

create table DB.DBA.VSPC_KILL (k integer not null primary key, v varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_KILL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Runs in its own thread and transaction under async_queue.  Writes, announces
-- that it is holding, and keeps the transaction open until released -- so it is
-- open across whatever the main thread runs in between.  The spins are bounded
-- so a failure is a failed assertion, not a hung suite.
create procedure DB.DBA.VSPC_HOLD () returns integer
{
  declare i integer;
  declare exit handler for sqlstate '*' { registry_set ('__vspc_err', __SQL_STATE); return -1; };
  insert into DB.DBA.VSPC_KILL (k, v) values (1, 'held');
  registry_set ('__vspc_held', '1');
  i := 0;
  while (i < 400 and registry_get ('__vspc_go') <> '1')
    {
      delay (0.05);
      i := i + 1;
    }
  return 1;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_HOLD STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Runs STMT while VSPC_HOLD is holding an uncommitted row, and reports whether
-- that row survived.  'rows=1' means other transactions were left alone,
-- 'rows=0 err=40001' means the statement took the global lock.
create procedure DB.DBA.VSPC_UNDER_LOAD (in stmt varchar) returns varchar
{
  declare aq any;
  declare i, n integer;
  delete from DB.DBA.VSPC_KILL;
  commit work;
  registry_set ('__vspc_held', '0');
  registry_set ('__vspc_go', '0');
  registry_set ('__vspc_err', '');
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.VSPC_HOLD', vector ());
  i := 0;
  while (i < 400 and registry_get ('__vspc_held') <> '1') { delay (0.05); i := i + 1; }
  if (registry_get ('__vspc_held') <> '1')
    return 'holder never started';
  exec (stmt);
  registry_set ('__vspc_go', '1');
  aq_wait_all (aq);
  n := (select count (*) from DB.DBA.VSPC_KILL);
  return concat ('rows=', cast (n as varchar), ' err=', cast (registry_get ('__vspc_err') as varchar));
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_UNDER_LOAD STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VSPC_E (id integer not null primary key, content varchar);
create procedure DB.DBA.VSPC_E_SEED (in n integer) returns integer
{
  declare i integer;
  i := 1;
  while (i <= n)
    {
      insert into DB.DBA.VSPC_E (id, content)
        values (i, concat ('row ', cast (i as varchar), ' text ', cast (mod (i, 31) as varchar)));
      i := i + 1;
    }
  return n;
};
select DB.DBA.VSPC_E_SEED (300);
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": seed VSPC_E rows=" $LAST[1] " (expect 300, far below MIN_FOR_ATOMIC)\n";

create index VSPC_E_PLAIN on DB.DBA.VSPC_E (content);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_E_PLAIN STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VSPC_E_VEC ON DB.DBA.VSPC_E (content) USING 'vspc-64'
  WITH (dimensions = 64, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VSPC_E_VEC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Control.  A plain B-tree index on 300 rows is below MIN_FOR_ATOMIC, so it is
-- not atomic and must leave other transactions alone.  This is the behaviour
-- being kept, not changed; if it ever reads rows=0 then every small DDL has
-- become atomic, which is not what was asked for.
select DB.DBA.VSPC_UNDER_LOAD ('drop index VSPC_E_PLAIN');
ECHO BOTH $IF $EQU $LAST[1] "rows=1 err=" "PASSED" "***FAILED";
ECHO BOTH ": plain index drop left other transactions alone, " $LAST[1] " (expect rows=1 err=)\n";

-- The assertion.  The same drop on the same table, on a vector index, has to
-- exclude them -- it is freeing a graph a concurrent search may be walking.
select DB.DBA.VSPC_UNDER_LOAD ('drop index VSPC_E_VEC');
ECHO BOTH $IF $EQU $LAST[1] "rows=0 err=40001" "PASSED" "***FAILED";
ECHO BOTH ": vector index drop excluded other transactions, " $LAST[1] " (expect rows=0 err=40001)\n";

drop table DB.DBA.VSPC_E;
drop procedure DB.DBA.VSPC_E_SEED;
drop procedure DB.DBA.VSPC_HOLD;
drop procedure DB.DBA.VSPC_UNDER_LOAD;
drop table DB.DBA.VSPC_KILL;

-- ===========================================================================
--  Cleanup
-- ===========================================================================

drop table DB.DBA.VSPC_MARK;
drop procedure DB.DBA.VSPC_USED;
drop procedure DB.DBA.VSPC_SET;
drop procedure DB.DBA.VSPC_DELTA;
drop procedure DB.DBA.VSPC_GRAPH_PAGES;
drop procedure DB.DBA.VSPC_SEED;
delete from DB.DBA.ONNX_MODELS where model_name = 'vspc-64';

echo BOTH "COMPLETED: VVEC index space accounting\n";
