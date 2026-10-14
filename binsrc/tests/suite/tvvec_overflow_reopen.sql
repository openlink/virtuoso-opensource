--
--  tvvec_overflow_reopen.sql
--
--  Restart regression for large-vector overflow pages.
--

echo BOTH "STARTED: VVEC overflow reopen\n";

select DB.DBA.VVEC_OVERFLOW_SEARCH_TOP (900, 901);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened overflow nearest row=" $LAST[1] "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_OVERFLOW_IDX'), 'overflow_pages') >= 8 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened overflow pages flag=" $LAST[1] "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_OVERFLOW_IDX'), 'deleted_overflow_pages') >= 4 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened deleted overflow pages flag=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_OVERFLOW_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened overflow managed rows=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_OVERFLOW_DOCS
 order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (2048, 900, 901));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened overflow indexed VECTOR_DISTANCE top row=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_OVERFLOW_IDX'), 'queries_tested');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": reopened overflow validate queries_tested=" $LAST[1] " STATE=" $STATE "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_OVERFLOW_IDX'), 'recall_at_10') >= 0.99 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": reopened overflow validate recall_at_10>=0.99 flag=" $LAST[1] " STATE=" $STATE "\n";

drop index VVEC_OVERFLOW_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_OVERFLOW_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_OVERFLOW_DOCS'
   and name_part (T_NAME, 2) like 'VVEC_OVERFLOW_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": overflow triggers after drop index=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_OVERFLOW_IDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SYS_KEYS entries for VVEC_OVERFLOW_IDX=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where upper(KEY_TABLE) =  upper('DB.DBA.VVEC_OVERFLOW_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": overflow hidden table metadata after drop index=" $LAST[1] "\n";

drop table DB.DBA.VVEC_OVERFLOW_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_OVERFLOW_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop function DB.DBA.VVEC_OVERFLOW_SEARCH_TOP;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_OVERFLOW_SEARCH_TOP STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-test-2048';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete vvec-test-2048 model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC overflow reopen\n";
