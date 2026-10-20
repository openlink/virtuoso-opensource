--
--  tvvec_overflow.sql
--
--  Large-vector overflow page regression for vector indexes.
--  Run after tvvec_begin.sql so the shared VVEC_BEGIN_* helpers exist.
--

echo BOTH "STARTED: VVEC overflow page tests\n";

insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-test-2048', 'deterministic overflow vector test model', 'internal:vvec-test-2048', 'test_embedding', 'embedding', '1,2048', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-test-2048 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VVEC_OVERFLOW_DOCS (
  id integer not null primary key,
  content varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_OVERFLOW_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_OVERFLOW_IDX
ON DB.DBA.VVEC_OVERFLOW_DOCS (content)
USING 'vvec-test-2048'
WITH (dimensions = 2048, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create overflow vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_OVERFLOW_SEARCH_TOP (in pos integer, in pos2 integer) returns any
{
  declare res any;
  res := __VEC_INDEX_SEARCH_TEST_EMBEDDING ('VVEC_OVERFLOW_IDX', pos, pos2, 1, 16);
  return aref (aref (res, 0), 0);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_OVERFLOW_SEARCH_TOP STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VVEC_OVERFLOW_DOCS (id, content) values (1, 'overflow positions 100 101');
insert into DB.DBA.VVEC_OVERFLOW_DOCS (id, content) values (2, 'overflow positions 300 301');
insert into DB.DBA.VVEC_OVERFLOW_DOCS (id, content) values (3, 'overflow positions 700 701');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": overflow auto insert DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": overflow insert drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_OVERFLOW_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": overflow hidden rows after insert=" $LAST[1] "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_OVERFLOW_IDX'), 'inline_dim_limit') < 2048 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow dimension exceeds inline limit flag=" $LAST[1] "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_OVERFLOW_IDX'), 'overflow_pages') >= 6 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow pages allocated flag=" $LAST[1] "\n";

select DB.DBA.VVEC_OVERFLOW_SEARCH_TOP (300, 301);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": overflow ANN nearest row before update=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_OVERFLOW_DOCS
 order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (2048, 300, 301));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": overflow indexed VECTOR_DISTANCE top row=" $LAST[1] "\n";

select cast (VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (2048, 300, 301)) as integer)
  from DB.DBA.VVEC_OVERFLOW_DOCS where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": overflow indexed VECTOR_DISTANCE exact row distance=" $LAST[1] "\n";

select __VEC_INDEX_INSERT_EMBEDDING ('VVEC_OVERFLOW_IDX', 99, make_array (8, 'any'));
ECHO BOTH $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": overflow dimension mismatch rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_OVERFLOW_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": overflow managed rows after failed insert=" $LAST[1] "\n";

update DB.DBA.VVEC_OVERFLOW_DOCS set content = 'overflow positions 900 901' where id = 2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": overflow update DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow update drain count=" $LAST[1] "\n";

select DB.DBA.VVEC_OVERFLOW_SEARCH_TOP (900, 901);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": overflow ANN nearest row after update=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_OVERFLOW_IDX'), 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow deleted nodes after update=" $LAST[1] "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_OVERFLOW_IDX'), 'deleted_overflow_pages') >= 2 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow deleted pages after update flag=" $LAST[1] "\n";

delete from DB.DBA.VVEC_OVERFLOW_DOCS where id = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": overflow delete DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow delete drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_OVERFLOW_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": overflow hidden rows after delete=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_OVERFLOW_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": overflow managed rows after delete=" $LAST[1] "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_OVERFLOW_IDX'), 'deleted_overflow_pages') >= 4 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": overflow deleted pages after delete flag=" $LAST[1] "\n";

checkpoint;

echo BOTH "COMPLETED: VVEC overflow page tests\n";
