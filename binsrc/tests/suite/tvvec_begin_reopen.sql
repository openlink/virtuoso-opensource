--
--  tvvec_begin_reopen.sql
--
--  Restart regression for begin-stage vector index support.
--

echo BOTH "STARTED: VVEC begin reopen\n";

select count (*) from DB.DBA.ONNX_MODELS
 where model_name = 'granite-384-local'
   and handle is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened granite-384-local handle present=" $LAST[1] "\n";

select length (ONNX_MODEL_INFO ((select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local')));
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": reopened granite-384-local model info length=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_BEGIN_IDX', 123, 124);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened nearest row for vector(123,124)=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": reopened managed_rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_BEGIN_IDX_vec_embeddings
 where EMBED_STATUS = 'ready'
   and MODEL_ID is not null
   and UPDATED_AT is not null
   and (SOURCE_HASH is null or SOURCE_HASH is not null);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": reopened begin managed table S9 metadata rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": reopened graph_nodes=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": reopened deleted_nodes=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_BEGIN_IDX'), 'node_pages');
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": reopened node_pages=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_BEGIN_IDX'), 'entry_point_dp');
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": reopened entry_point_dp=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_BEGIN_IDX'), 'queries_tested');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": reopened validate queries_tested=" $LAST[1] " STATE=" $STATE "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_BEGIN_IDX'), 'recall_at_10') >= 0.99 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened validate recall_at_10>=0.99 flag=" $LAST[1] " STATE=" $STATE "\n";

create function DB.DBA.VVEC_REOPEN_ANN_COUNT_INCREASED () returns integer
{
  declare before_val any;
  declare after_val any;
  declare ignored any;
  before_val := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'search_count');
  ignored := exec ('select top 3 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))');
  after_val := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'search_count');
  if (after_val > before_val)
    return 1;
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_REOPEN_ANN_COUNT_INCREASED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_REOPEN_ANN_COUNT_INCREASED ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ANN metrics incremented after reopen\n";

drop function DB.DBA.VVEC_REOPEN_ANN_COUNT_INCREASED;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_REOPEN_ANN_COUNT_INCREASED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_REDUCE_IDX'), 'dimension');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": reopened truncate-reduced vector index dimension=" $LAST[1] "\n";

select aref (aref (__VEC_INDEX_SEARCH ('VVEC_REDUCE_IDX', DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 2, 3), 1, 8), 0), 0);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened truncate-reduced native-dim search top row=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VVEC_REDUCE_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_REDUCE_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DB.DBA.VVEC_REDUCE_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_REDUCE_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index VVEC_BEGIN_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_BEGIN_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_BEGIN_DOCS'
   and name_part (T_NAME, 2) like 'VVEC_BEGIN_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": vector DML triggers after drop index=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_BEGIN_IDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SYS_KEYS entries for VVEC_BEGIN_IDX=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where upper(KEY_TABLE) =  upper('DB.DBA.VVEC_BEGIN_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": hidden table metadata after drop index=" $LAST[1] "\n";

drop table DB.DBA.VVEC_BEGIN_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_BEGIN_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_AUTO_IDX', 5, 6);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened auto nearest row=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened auto managed_rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings
 where SOURCE_HASH is not null or SOURCE_HASH is null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened auto managed table S9 source_hash column rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings
 where SOURCE_HASH is not null
   and EMBED_STATUS = 'ready'
   and MODEL_ID = (select model_id from DB.DBA.ONNX_MODELS where model_name = 'vvec-test-8')
   and UPDATED_AT is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened auto ready hash metadata rows=" $LAST[1] "\n";

drop index VVEC_AUTO_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_AUTO_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_AUTO_DOCS'
   and name_part (T_NAME, 2) like 'VVEC_AUTO_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": auto vector DML triggers after drop=" $LAST[1] "\n";

drop table DB.DBA.VVEC_AUTO_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_AUTO_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC begin reopen\n";
