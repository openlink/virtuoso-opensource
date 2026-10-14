--
--  tvvec_hidden_guard.sql
--
--  Regression test for the hidden-embedding-table write guard (vision rules 3/4:
--  public DML must not inject arbitrary vectors into a model-bound index; the
--  managed embedding table is server-owned).
--
--  vvec_create_hidden_guard_triggers puts BEFORE INSERT/UPDATE/DELETE triggers on
--  <index>_vec_embeddings that reject a non-DBA writer with VEC82, while every
--  legitimate write (the DBA-only embedding BIFs, backfill, the async queue worker)
--  runs as DBA and passes.  This test proves both halves.
--
--  Self-contained: in-core 'test_embedding' model, index backfilled on a small
--  populated table -- no ONNX, no SPARQL backfill bootstrap dependency.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software.  GNU GPL v2, 1991.
--

echo BOTH "STARTED: VVEC hidden-table write guard\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'hg-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('hg-8', 'hidden guard test model', 'internal:hg-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register hg-8 STATE=" $STATE "\n";

create table DB.DBA.HG_T (id integer not null primary key, content varchar);
insert into DB.DBA.HG_T values (1, 'positions 1 2');
insert into DB.DBA.HG_T values (2, 'positions 3 4');
CREATE VECTOR INDEX HG_IDX ON DB.DBA.HG_T (content) USING 'hg-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill HG_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Three guard triggers created on the hidden table.
select count (*) from DB.DBA.SYS_TRIGGERS where upper(T_TABLE) =  upper('DB.DBA.HG_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": 3 guard triggers on hidden table=" $LAST[1] "\n";

-- Backfill populated the hidden table as DBA (guard did not block it).
select count (*) from DB.DBA.HG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": backfill rows (DBA write allowed)=" $LAST[1] "\n";

-- DBA may write the hidden table directly (DBA is trusted).
insert into DB.DBA.HG_IDX_vec_embeddings (VE_D_ID, VE_EMBEDDING, EMBED_STATUS, MODEL_ID, UPDATED_AT)
  values (999, 'x', 'ready', 1, now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DBA direct insert allowed STATE=" $STATE "\n";
delete from DB.DBA.HG_IDX_vec_embeddings where VE_D_ID = 999;

-- A non-DBA user, granted every table privilege, is still blocked by the guard.
DB.DBA.USER_CREATE ('hgu', 'hgupass');
grant select, insert, update, delete on DB.DBA.HG_IDX_vec_embeddings to "hgu";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + grant non-dba user STATE=" $STATE "\n";

create procedure DB.DBA.HG_TRY (in op varchar) returns integer
{
  declare exit handler for sqlstate '*'
    {
      __pop_user_id ();
      if (__SQL_MESSAGE like '%VEC82%') return 1;   -- blocked by guard: pass
      return -1;                                    -- some other error: fail
    };
  __set_user_id ('hgu');
  if (op = 'insert')
    insert into DB.DBA.HG_IDX_vec_embeddings (VE_D_ID, VE_EMBEDDING, EMBED_STATUS, MODEL_ID, UPDATED_AT)
      values (777, 'y', 'ready', 1, now ());
  else if (op = 'update')
    update DB.DBA.HG_IDX_vec_embeddings set EMBED_STATUS = 'hacked' where VE_D_ID = 1;
  else
    delete from DB.DBA.HG_IDX_vec_embeddings where VE_D_ID = 1;
  __pop_user_id ();
  return 0;   -- write succeeded: guard failed to block
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create HG_TRY STATE=" $STATE "\n";

select DB.DBA.HG_TRY ('insert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba INSERT rejected (VEC82)=" $LAST[1] "\n";
select DB.DBA.HG_TRY ('update');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba UPDATE rejected (VEC82)=" $LAST[1] "\n";
select DB.DBA.HG_TRY ('delete');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba DELETE rejected (VEC82)=" $LAST[1] "\n";

-- The blocked attempts changed nothing.
select count (*) from DB.DBA.HG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": hidden rows intact after blocked writes=" $LAST[1] "\n";

-- Legitimate DBA embedding BIF still works.
select __VEC_INDEX_INSERT_EMBEDDING ('HG_IDX', 3, vector (0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DBA embedding BIF still works STATE=" $STATE "\n";

-- Dropping the index removes the hidden table and its guard triggers.
DROP TABLE DB.DBA.HG_T;
select count (*) from DB.DBA.SYS_TRIGGERS where upper(T_TABLE) =  upper('DB.DBA.HG_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": guard triggers gone after drop=" $LAST[1] "\n";

echo BOTH "COMPLETED: VVEC hidden-table write guard\n";
