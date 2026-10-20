--
--  tvvec_chunked_replay_crash.sql   (phase 1)
--
--  Deterministic crash *in the middle* of a chunked replay rebuild.
--
--  The server for this phase is started with VVEC_TEST_CRASH_AFTER_CHUNK=1 in its
--  environment (see tvvec_chunked_replay_crash.sh).  That fault hook fires inside
--  vvec_replay_rebuild_chunked after the first chunk commits: it checkpoints the
--  PARTIAL graph (so it is durable on disk) and exits uncleanly, before the
--  rebuild's final vvec_epoch_sync runs.
--
--  This phase builds a >VVEC_REPLAY_CHUNK_SIZE (4000) row index so the rebuild
--  spans more than one chunk, checkpoints the healthy pre-rebuild graph, records
--  what phase 2 should see, then launches the rebuild -- which never returns,
--  because the server dies partway through.  isql therefore reports a lost
--  connection on the final statement; the driver expects that.
--
--  Self-contained: in-core 'test_embedding' model, index on an empty table filled
--  with __VEC_INDEX_INSERT_TEST_EMBEDDING.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software.  GNU GPL v2, 1991.
--

echo BOTH "STARTED: VVEC mid-chunk crash (phase 1)\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

create function DB.DBA.TCC_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv)) return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k) return aref (kv, i + 1);
  return null;
};

create function DB.DBA.TCC_SEARCH_BLOCKED (in idx varchar) returns integer
{
  declare c integer;
  declare exit handler for sqlstate '*'
    {
      if (__SQL_MESSAGE like '%VEC80%' or __SQL_MESSAGE like '%inconsistent with its stored embeddings%')
        return 1;
      return -1;
    };
  c := length (__VEC_INDEX_SEARCH_TEST_EMBEDDING (idx, 1, 3, 10, 40));
  return 0;
};

create procedure DB.DBA.TCC_FILL (in idx varchar, in lo integer, in hi integer)
{
  declare i integer;
  for (i := lo; i <= hi; i := i + 1)
    {
      __VEC_INDEX_INSERT_TEST_EMBEDDING (idx, i, mod (i, 8), mod (i * 3, 8));
      if (mod (i - lo + 1, 1000) = 0)
	commit work;
    }
  commit work;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create helpers STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'tcc-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('tcc-8', 'mid-chunk crash test model', 'internal:tcc-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tcc-8 STATE=" $STATE "\n";

create table DB.DBA.TCC_T (id integer not null primary key, content varchar);
CREATE VECTOR INDEX TCC_IDX ON DB.DBA.TCC_T (content) USING 'tcc-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16, rebuild = 'replay');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TCC_IDX (rebuild=replay) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- >1 chunk so the rebuild crosses the boundary and the fault hook (after chunk 1)
-- fires while rows remain unprocessed -- i.e. genuinely mid-rebuild.
DB.DBA.TCC_FILL ('TCC_IDX', 1, 4005);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fill 4005 embeddings STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": healthy before rebuild consistent=" $LAST[1] "\n";

-- Make the healthy pre-rebuild graph durable and its catalog epoch settled.
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": pre-rebuild checkpoint STATE=" $STATE "\n";

-- Record embedding-row count for phase-2 repair assertion.
create table DB.DBA.TCC_EXPECT (E_ID integer primary key, E_ROWS integer);
insert into DB.DBA.TCC_EXPECT (E_ID, E_ROWS)
  values (1, DB.DBA.TCC_KV (__VEC_INDEX_VALIDATE ('TCC_IDX'), 'embedding_rows'));
select E_ROWS from DB.DBA.TCC_EXPECT where E_ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 4005 "PASSED" "***FAILED";
ECHO BOTH ": recorded embedding rows=" $LAST[1] "\n";

echo BOTH "ARMED: launching rebuild that will crash after chunk 1 (server dies now)\n";

-- This never returns: the fault hook checkpoints the partial graph and exits
-- uncleanly after the first chunk commits.  A clean run WITHOUT the env var would
-- instead print a PASSED line here; under the crash env, isql loses the server.
select __VEC_INDEX_REBUILD ('TCC_IDX', 'replay');
ECHO BOTH "***FAILED: rebuild returned -- fault hook did NOT fire (env not set?)\n";
