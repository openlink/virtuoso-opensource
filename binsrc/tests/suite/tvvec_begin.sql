--
--  tvvec_begin.sql
--
--  Bootstrap regression for begin-stage vector index support.
--

echo BOTH "STARTED: VVEC begin bootstrap\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": initialize DB.DBA.ONNX_MODELS result=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, vocab_path, max_seq_len, created_at, updated_at)
values
  ('granite-384-local', 'local bootstrap model', 'onnx-models/granite-embedding-30m-english/model.onnx', 'text_embedding', 'pooled_output', '1,384', 'onnx-models/granite-embedding-30m-english/vocab.json', 512, now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register granite-384-local STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Resolve to an absolute path.  The helper is exec'd from a forked child that
-- inherits the server's working directory -- the database directory, not the
-- build tree -- so a relative path only ever worked when the server happened
-- to be started from the source root.
select ONNX_CONFIG ('helper_path', DB.DBA.ONNX_RESOLVE_PATH ('onnx_helper', 'HelperPath'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": configure ONNX helper path result=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.ONNX_MODEL_REFRESH ('granite-384-local');
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": refresh granite-384-local handle=" $LAST[1] "\n";

-- Likewise absolute: ONNX_LOAD_MODEL now verifies the model and vocab are
-- readable, since in out-of-process mode nothing else would notice a bad path
-- until a helper started dying on every request.
select case when ONNX_LOAD_MODEL (DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/model.onnx', 'GraniteModelPath'),
                 'input=input_ids;input2=attention_mask;output=pooled_output;vocab='
                 || DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/vocab.json', 'GraniteVocabPath') || ';max_seq_len=512') =
                 ONNX_LOAD_MODEL (DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/model.onnx', 'GraniteModelPath'),
                 'input=input_ids;input2=attention_mask;output=pooled_output;vocab='
                 || DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/vocab.json', 'GraniteVocabPath') || ';max_seq_len=512')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": repeated ONNX_LOAD_MODEL reuses loaded handle flag=" $LAST[1] "\n";

select count (*) from DB.DBA.ONNX_MODELS
 where model_name = 'granite-384-local'
   and model_path = 'onnx-models/granite-embedding-30m-english/model.onnx'
   and vocab_path = 'onnx-models/granite-embedding-30m-english/vocab.json'
   and output_shape = '1,384'
   and handle is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": local granite model registry rows=" $LAST[1] "\n";

insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-test-8', 'deterministic vector DML test model', 'internal:vvec-test-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-test-8 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- S15b: a failed create-time backfill must remove every partial vector object.
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-atomic-unready-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-atomic-unready-8', 'intentionally unloaded model for atomic DDL coverage', 'missing:atomic.onnx', 'text_embedding', 'embedding', '1,8', now (), now ());
create table DB.DBA.VVEC_ATOMIC_DOCS (id integer not null primary key, content varchar);
insert into DB.DBA.VVEC_ATOMIC_DOCS values (1, 'atomic create must fail cleanly');
CREATE VECTOR INDEX VVEC_ATOMIC_BAD_IDX
ON DB.DBA.VVEC_ATOMIC_DOCS (content)
USING 'vvec-atomic-unready-8'
WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": failed vector create returns the backfill error STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_ATOMIC_BAD_IDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
select count (*) from DB.DBA.SYS_KEYS where upper(KEY_TABLE) =  upper('DB.DBA.VVEC_ATOMIC_BAD_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_ATOMIC_DOCS' and name_part (T_NAME, 2) like 'VVEC_ATOMIC_BAD_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": failed vector create leaves no key, hidden table, or triggers\n";

create function DB.DBA.VVEC_ATOMIC_NO_STALE_QUERY () returns integer
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  _stat := '00000';
  exec ('select X_SIMILAR (content, ''atomic query'') from DB.DBA.VVEC_ATOMIC_DOCS where id = 1',
        _stat, _msg, vector (), 0, _meta, _rows);
  return case when _stat = '42000' and strstr (_msg, 'VEC01') is null then 1 else 0 end;
};
select DB.DBA.VVEC_ATOMIC_NO_STALE_QUERY ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": failed vector create query takes clean no-index path, never VEC01\n";
drop function DB.DBA.VVEC_ATOMIC_NO_STALE_QUERY;
drop table DB.DBA.VVEC_ATOMIC_DOCS;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-atomic-unready-8';

create function DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (in dim integer, in pos integer, in pos2 integer) returns any
{
  declare vec any;
  declare inx integer;
  vec := make_array (dim, 'any');
  for (inx := 0; inx < dim; inx := inx + 1)
    aset (vec, inx, 0);
  if (pos >= 0 and pos < dim)
    aset (vec, pos, 1);
  if (pos2 is not null and pos2 >= 0 and pos2 < dim)
    aset (vec, pos2, 1);
  return vec;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_MAKE_DIM_VEC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_BEGIN_MAKE_VEC (in pos integer, in pos2 integer) returns any
{
  return DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (384, pos, pos2);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_MAKE_VEC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_BEGIN_KV_GET (in kv any, in key_name varchar) returns any
{
  declare inx integer;
  if (not isvector (kv))
    return null;
  for (inx := 0; inx < length (kv); inx := inx + 2)
    {
      if (cast (aref (kv, inx) as varchar) = key_name)
        return aref (kv, inx + 1);
    }
  return null;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_KV_GET STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_BEGIN_INSERT_ONE (in index_name varchar, in row_id integer, in pos integer, in pos2 integer) returns any
{
  declare vec any;
  vec := DB.DBA.VVEC_BEGIN_MAKE_VEC (pos, pos2);
  return __VEC_INDEX_INSERT_EMBEDDING (index_name, row_id, vec);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_INSERT_ONE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_BEGIN_INSERT_BATCH (in index_name varchar) returns any
{
  declare row_ids any;
  declare vecs any;
  row_ids := vector (2, 3);
  vecs := vector (DB.DBA.VVEC_BEGIN_MAKE_VEC (33, 34), DB.DBA.VVEC_BEGIN_MAKE_VEC (77, null));
  return __VEC_INDEX_INSERT_BATCH (index_name, row_ids, vecs);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_INSERT_BATCH STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_BEGIN_SEARCH_TOP (in index_name varchar, in pos integer, in pos2 integer) returns any
{
  declare res any;
  res := __VEC_INDEX_SEARCH_TEST_EMBEDDING (index_name, pos, pos2, 1, 8);
  return aref (aref (res, 0), 0);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_SEARCH_TOP STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VVEC_REDUCE_DOCS (
  id integer not null primary key,
  content varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_REDUCE_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_REDUCE_NO_OPT_IDX
ON DB.DBA.VVEC_REDUCE_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 4, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": reduced dimension without reduce option rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_REDUCE_NODIM_IDX
ON DB.DBA.VVEC_REDUCE_DOCS (content)
USING 'vvec-test-8'
WITH (reduce = 'truncate', distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": truncate reduction without dimensions rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_REDUCE_TOO_WIDE_IDX
ON DB.DBA.VVEC_REDUCE_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 16, reduce = 'truncate', distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": truncate reduction wider than model rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_REDUCE_IDX
ON DB.DBA.VVEC_REDUCE_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 4, reduce = 'truncate', distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create truncate-reduced vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_REDUCE_IDX'), 'dimension');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": truncate-reduced vector index dimension=" $LAST[1] "\n";

select __VEC_INDEX_INSERT_EMBEDDING ('VVEC_REDUCE_IDX', 1, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 0, 1));
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": truncate-reduced native-dim insert row1 node_dp=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_INSERT_EMBEDDING ('VVEC_REDUCE_IDX', 2, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 2, 3));
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": truncate-reduced native-dim insert row2 node_dp=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select aref (aref (__VEC_INDEX_SEARCH ('VVEC_REDUCE_IDX', DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 2, 3), 1, 8), 0), 0);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": truncate-reduced native-dim search top row=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select cast (__VEC_INDEX_ROW_DISTANCE ('VVEC_REDUCE_IDX', 2, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 2, 3)) as integer);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": truncate-reduced native-dim row distance=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_REDUCE_IDX'), 'queries_tested');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": truncate-reduced validate queries_tested=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VVEC_BEGIN_DOCS (
  id integer not null primary key,
  content varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_BEGIN_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VVEC_BEGIN_DOCS (id, content) values (1, 'reset password help');
insert into DB.DBA.VVEC_BEGIN_DOCS (id, content) values (2, 'reset password policy');
insert into DB.DBA.VVEC_BEGIN_DOCS (id, content) values (3, 'billing address change');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed VVEC_BEGIN_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_BEGIN_IDX
ON DB.DBA.VVEC_BEGIN_DOCS (content)
USING 'granite-384-local'
WITH (dimensions = 384, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_BEGIN_DOCS'
   and name_part (T_NAME, 2) like 'VVEC_BEGIN_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": vector DML triggers created=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_BEGIN_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": hidden table backfilled on create, rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_BEGIN_IDX'), 'metadata_pages');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": metadata_pages=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_BEGIN_IDX'), 'node_pages');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": node_pages after create backfill=" $LAST[1] "\n";

select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VVEC_BEGIN_IDX', 1, 11, -1);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": single internal insert node_dp=" $LAST[1] " STATE=" $STATE "\n";

select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VVEC_BEGIN_IDX', 2, 33, 34);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": second internal insert node_dp=" $LAST[1] " STATE=" $STATE "\n";

select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VVEC_BEGIN_IDX', 3, 77, -1);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": third internal insert node_dp=" $LAST[1] " STATE=" $STATE "\n";

select count (*) from DB.DBA.VVEC_BEGIN_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": ready hidden rows=" $LAST[1] "\n";

-- model_id is no longer in the hidden table, it is in index metadata
select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": managed hidden rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_BEGIN_IDX', 33, 34);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": nearest row for vector(33,34) before update=" $LAST[1] "\n";

select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VVEC_BEGIN_IDX', 2, 123, 124);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": duplicate row_id update path node_dp=" $LAST[1] " STATE=" $STATE "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_BEGIN_IDX', 123, 124);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": nearest row for updated vector(123,124)=" $LAST[1] "\n";

select __VEC_INDEX_INSERT_EMBEDDING ('VVEC_BEGIN_IDX', 9, make_array (10, 'any'));
ECHO BOTH $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": dimension mismatch rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": managed_rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": deleted_nodes=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_BEGIN_IDX'), 'node_pages');
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": node_pages after update=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_BEGIN_IDX'), 'entry_point_dp');
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": entry_point_dp after load=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_BEGIN_IDX'), 'queries_tested');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": validate queries_tested=" $LAST[1] " STATE=" $STATE "\n";

select case when DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_VALIDATE ('VVEC_BEGIN_IDX'), 'recall_at_10') >= 0.99 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": validate recall_at_10>=0.99 flag=" $LAST[1] " STATE=" $STATE "\n";

create table DB.DBA.VVEC_AUTO_DOCS (
  id integer not null primary key,
  content varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_AUTO_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VVEC_AUTO_DOCS (id, content) values (1, 'auto positions 1 2');
insert into DB.DBA.VVEC_AUTO_DOCS (id, content) values (2, 'auto positions 3 4');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed VVEC_AUTO_DOCS before vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_AUTO_IDX
ON DB.DBA.VVEC_AUTO_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create auto vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_AUTO_DOCS'
   and name_part (T_NAME, 2) like 'VVEC_AUTO_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": auto vector DML triggers created=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": auto hidden rows after create backfill=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings
 where SOURCE_HASH is not null or SOURCE_HASH is null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": managed hidden table S9 source_hash column rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings
 where SOURCE_HASH is not null
   and EMBED_STATUS = 'ready'
   and MODEL_ID = (select model_id from DB.DBA.ONNX_MODELS where model_name = 'vvec-test-8')
   and UPDATED_AT is not null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": managed hidden rows carry ready hash metadata=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_AUTO_IDX', 3, 4);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": auto nearest row for vector(3,4)=" $LAST[1] "\n";

insert into DB.DBA.VVEC_AUTO_DOCS (id, content) values (3, 'auto positions 7 0');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S11 deferred insert DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings where VE_D_ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": S11 insert before drain hidden rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_AUTO_IDX' and VQ_PK = 3 and VQ_OP = 'upsert' and VQ_STATE = 'pending';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 insert enqueued pending rows=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 insert drain count=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_AUTO_IDX', 7, 0);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": S11 inserted row ANN top row after drain=" $LAST[1] "\n";

update DB.DBA.VVEC_AUTO_DOCS set content = 'auto positions 0 7' where id = 3;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S11 deferred update DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_AUTO_IDX' and VQ_PK = 3 and VQ_OP = 'upsert' and VQ_STATE = 'pending';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 update enqueued pending rows=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 update drain count=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_AUTO_IDX', 0, 7);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": S11 updated row ANN top row after drain=" $LAST[1] "\n";

delete from DB.DBA.VVEC_AUTO_DOCS where id = 3;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S11 deferred delete DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings where VE_D_ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 delete before drain hidden rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_AUTO_IDX' and VQ_PK = 3 and VQ_OP = 'delete' and VQ_STATE = 'pending';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 delete enqueued pending rows=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S11 delete drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings where VE_D_ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": S11 delete after drain hidden rows=" $LAST[1] "\n";

create function DB.DBA.VVEC_S9_HASH_SKIP_TEST () returns integer
{
  declare before_insert, before_deleted, after_insert, after_deleted, changed_insert, changed_deleted any;
  declare before_hash, after_hash, changed_hash any;
  declare before_updated, after_updated any;
  declare drained integer;
  before_insert := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'insert_count');
  before_deleted := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'deleted_nodes');
  select SOURCE_HASH, UPDATED_AT into before_hash, before_updated
    from DB.DBA.VVEC_AUTO_IDX_vec_embeddings where VE_D_ID = 2;

  update DB.DBA.VVEC_AUTO_DOCS set content = 'auto positions 3 4' where id = 2;
  if ((select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_AUTO_IDX' and VQ_PK = 2 and VQ_STATE = 'pending') <> 1)
    return 14;
  if (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'insert_count') <> before_insert)
    return 10;
  if (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'deleted_nodes') <> before_deleted)
    return 11;
  drained := DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
  if (drained <> 1)
    return 15;
  after_insert := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'insert_count');
  after_deleted := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'deleted_nodes');
  select SOURCE_HASH, UPDATED_AT into after_hash, after_updated
    from DB.DBA.VVEC_AUTO_IDX_vec_embeddings where VE_D_ID = 2;
  if (after_insert <> before_insert)
    return 10;
  if (after_deleted <> before_deleted)
    return 11;
  if (after_hash <> before_hash)
    return 12;
  if (after_updated <> before_updated)
    return 13;

  update DB.DBA.VVEC_AUTO_DOCS set content = 'auto positions 5 6' where id = 2;
  if ((select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_AUTO_IDX' and VQ_PK = 2 and VQ_STATE = 'pending') <> 1)
    return 23;
  if (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'insert_count') <> after_insert)
    return 24;
  drained := DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
  if (drained <> 1)
    return 25;
  changed_insert := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'insert_count');
  changed_deleted := DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'deleted_nodes');
  select SOURCE_HASH into changed_hash
    from DB.DBA.VVEC_AUTO_IDX_vec_embeddings where VE_D_ID = 2;
  if (changed_insert <= after_insert)
    return 20;
  if (changed_deleted <= after_deleted)
    return 21;
  if (changed_hash = after_hash)
    return 22;
  return 1;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_S9_HASH_SKIP_TEST STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_S9_HASH_SKIP_TEST ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S9 unchanged-text update skips re-embed and changed text re-embeds flag=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_AUTO_IDX', 5, 6);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": auto nearest row after update=" $LAST[1] "\n";

delete from DB.DBA.VVEC_AUTO_DOCS where id = 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": auto delete DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_AUTO_IDX' and VQ_PK = 1 and VQ_OP = 'delete' and VQ_STATE = 'pending';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": auto delete enqueued pending rows=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": auto delete drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_AUTO_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": auto hidden rows after delete=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": auto managed rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_AUTO_IDX'), 'deleted_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": auto deleted nodes=" $LAST[1] "\n";

create table DB.DBA.VVEC_QUEUE_DOCS (
  id integer not null primary key,
  content varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_QUEUE_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_QUEUE_IDX
ON DB.DBA.VVEC_QUEUE_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create queue vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_S10_DROP_QUEUE_TRIGGERS () returns integer
{
  declare dropped integer;
  dropped := 0;
  for select T_NAME from DB.DBA.SYS_TRIGGERS
      where T_TABLE = 'DB.DBA.VVEC_QUEUE_DOCS'
        and name_part (T_NAME, 2) like 'VVEC_QUEUE_IDX_VVEC_A_' do
    {
      exec (sprintf ('drop trigger "%I"."%I"."%I"', name_part (T_NAME, 0), name_part (T_NAME, 1), name_part (T_NAME, 2)));
      dropped := dropped + 1;
    }
  return dropped;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_S10_DROP_QUEUE_TRIGGERS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_S10_DROP_QUEUE_TRIGGERS ();
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": dropped queue fixture triggers=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_INIT ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": initialize relational vector SQL queue result=" $LAST[1] "\n";

insert into DB.DBA.VVEC_QUEUE_DOCS (id, content) values (1, 'queue positions 2 3');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S10 seed manual upsert row STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_ENQUEUE ('VVEC_QUEUE_IDX', 1, 'upsert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 enqueue manual upsert result=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 manual upsert drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_QUEUE_IDX_vec_embeddings where VE_D_ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 manual upsert hidden rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_QUEUE_IDX', 2, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 manual upsert ANN top row=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_ENQUEUE ('VVEC_QUEUE_IDX', 1, 'delete');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 enqueue manual delete result=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 manual delete drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_QUEUE_IDX_vec_embeddings where VE_D_ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": S10 manual delete hidden rows=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_WORKER_START (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 worker start result=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_WORKER_STOP ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 worker stop result=" $LAST[1] "\n";

insert into DB.DBA.VVEC_QUEUE_DOCS (id, content) values (2, 'queue positions 4 5');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S10 seed drained upsert row STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_ENQUEUE ('VVEC_QUEUE_IDX', 2, 'upsert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 enqueue drained upsert result=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 manual drain after worker stop count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_QUEUE_IDX_vec_embeddings where VE_D_ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 drained upsert hidden rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_QUEUE_IDX', 4, 5);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": S10 drained upsert ANN top row=" $LAST[1] "\n";

insert into DB.DBA.VVEC_QUEUE_DOCS (id, content) values (3, 'queue positions 6 7');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S10 seed stopped-worker row STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_ENQUEUE ('VVEC_QUEUE_IDX', 3, 'upsert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 stopped-worker enqueue result=" $LAST[1] "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_QUEUE_IDX' and VQ_PK = 3 and VQ_STATE = 'pending';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 stopped-worker pending rows=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_QUEUE_IDX_vec_embeddings where VE_D_ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": S10 stopped-worker hidden rows=" $LAST[1] "\n";

delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_QUEUE_IDX';

select DB.DBA.VEC_SQL_QUEUE_ENQUEUE ('VVEC_NO_SUCH_IDX', 1, 'upsert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 enqueue induced failure result=" $LAST[1] "\n";

insert into DB.DBA.VVEC_QUEUE_DOCS (id, content) values (4, 'queue positions 0 1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S10 seed post-error valid row STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_ENQUEUE ('VVEC_QUEUE_IDX', 4, 'upsert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 enqueue post-error valid row result=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_PROCESS_ONE ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 induced failure process-one count=" $LAST[1] "\n";

select DB.DBA.VEC_SQL_QUEUE_PROCESS_ONE ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 post-error valid process-one count=" $LAST[1] "\n";

select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'VVEC_NO_SUCH_IDX' and VQ_STATE = 'error' and VQ_TRIES = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 induced failure error rows=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_SEARCH_TOP ('VVEC_QUEUE_IDX', 0, 1);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": S10 post-error valid ANN top row=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (DB.DBA.VEC_SQL_WORKER_STATUS (), 'pending');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": S10 worker status pending=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (DB.DBA.VEC_SQL_WORKER_STATUS (), 'error');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": S10 worker status error=" $LAST[1] "\n";

create table DB.DBA.VVEC_LONG_DOCS (
  id integer not null primary key,
  content long varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_LONG_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VVEC_LONG_DOCS (id, content) values (1, 'long varchar positions 1 2');
insert into DB.DBA.VVEC_LONG_DOCS (id, content) values (2, 'long varchar positions 6 7');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed VVEC_LONG_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_LONG_IDX
ON DB.DBA.VVEC_LONG_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create LONG VARCHAR vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VVEC_LONG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": LONG VARCHAR hidden rows after create backfill=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_LONG_DOCS
 order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 6, 7));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": LONG VARCHAR indexed VECTOR_DISTANCE top row=" $LAST[1] "\n";

select id from DB.DBA.VVEC_LONG_DOCS
 where X_SIMILAR (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 6, 7)) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": LONG VARCHAR indexed X_SIMILAR filter row=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_LONG_DOCS
 where X_SIMILAR (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 6, 7), 5) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": LONG VARCHAR indexed X_SIMILAR leading row=" $LAST[1] "\n";

create table DB.DBA.VVEC_BEGIN_QV_COUNT (id integer not null primary key, n integer);
insert into DB.DBA.VVEC_BEGIN_QV_COUNT (id, n) values (1, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create X_SIMILAR query-vector counter STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_BEGIN_COUNTED_VEC () returns any
{
  update DB.DBA.VVEC_BEGIN_QV_COUNT set n = n + 1 where id = 1;
  return DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create X_SIMILAR counted vector function STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 where X_SIMILAR (content, DB.DBA.VVEC_BEGIN_COUNTED_VEC (), 5) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": leading X_SIMILAR counted-vector top row=" $LAST[1] "\n";

select n from DB.DBA.VVEC_BEGIN_QV_COUNT where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": leading X_SIMILAR query vector evaluations=" $LAST[1] "\n";

select cast (VECTOR_DISTANCE (DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6), DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6), 'euclidean') as integer);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": scalar VECTOR_DISTANCE over raw vectors=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": indexed VECTOR_DISTANCE top row=" $LAST[1] "\n";

select cast (VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6)) as integer)
  from DB.DBA.VVEC_AUTO_DOCS where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": indexed VECTOR_DISTANCE exact row distance=" $LAST[1] "\n";

select case when X_SIMILAR (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6)) > 0.99 then 1 else 0 end
  from DB.DBA.VVEC_AUTO_DOCS where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": indexed X_SIMILAR exact row similarity flag=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 where X_SIMILAR (content, 'auto positions 5 6', 5) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": text X_SIMILAR leading top row=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 where X_SIMILAR (content, 'auto positions 5 6', 5) > 0.99
 order by VECTOR_DISTANCE (content, 'auto positions 5 6');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": text VECTOR_DISTANCE top row=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 where X_SIMILAR (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6), 5) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": explicit-vector X_SIMILAR comparison top row=" $LAST[1] "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 where X_SIMILAR (content, 'auto positions 5 6', 5) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": text X_SIMILAR comparison top row=" $LAST[1] "\n";

select __VEC_INDEX_QUERY_TEXT_VECTOR_CALLS (1);
ECHO BOTH $IF $NEQ $STATE ERROR "PASSED" "***FAILED";
ECHO BOTH ": reset text query-vector counter STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 where X_SIMILAR (content, 'auto positions 5 6', 5) > 0.99;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": leading text X_SIMILAR counted top row=" $LAST[1] "\n";

--  The leading-ANN plan no longer routes the query text through
--  __VEC_INDEX_QUERY_TEXT_VECTOR: vvec_search_node embeds it itself
--  (vvec_search_node_input -> vvec_embed_text_for_model), so that BIF's
--  global, single-slot, mutex-guarded cache is off this path entirely and
--  its call counter must stay at 0.
select __VEC_INDEX_QUERY_TEXT_VECTOR_CALLS (1);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": leading text X_SIMILAR bypasses the query-text BIF embeddings=" $LAST[1] "\n";

--  A zero counter on its own is ambiguous: a leading-ANN plan that got
--  cancelled and fell back to the per-row __VEC_INDEX_ROW_SIMILARITY rescan
--  would not call that BIF either.  Pin the plan positively as well, so this
--  check still fails if the fast path is ever lost.
select case when strstr (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS where X_SIMILAR (content, ''auto positions 5 6'', 5) > 0.99'),
  'mode=ann') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": leading text X_SIMILAR keeps the ANN search node flag=" $LAST[1] "\n";

select case when strstr (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS where X_SIMILAR (content, ''auto positions 5 6'', 5) > 0.99'),
  'query_text=') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": leading text X_SIMILAR embeds its own query text flag=" $LAST[1] "\n";

select __VEC_INDEX_QUERY_TEXT_VECTOR_CALLS (1);
ECHO BOTH $IF $NEQ $STATE ERROR "PASSED" "***FAILED";
ECHO BOTH ": reset text query-vector counter before filter STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select case when X_SIMILAR (content, 'auto positions 5 6') > 0.99 then 1 else 0 end
  from DB.DBA.VVEC_AUTO_DOCS where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": filter text X_SIMILAR exact row similarity flag=" $LAST[1] "\n";

select __VEC_INDEX_QUERY_TEXT_VECTOR_CALLS (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": filter text X_SIMILAR query text embeddings=" $LAST[1] "\n";

select X_SIMILAR (n, 'auto positions 5 6') from DB.DBA.VVEC_BEGIN_QV_COUNT where id = 1;
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": text X_SIMILAR without vector index rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select sqlo_vvec_require_ann (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": enable strict ANN STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top 1 id from DB.DBA.VVEC_AUTO_DOCS
 order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": strict ANN TOP row=" $LAST[1] "\n";

select case when X_SIMILAR (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6)) > 0.99 then 1 else 0 end
  from DB.DBA.VVEC_AUTO_DOCS where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": strict ANN indexed X_SIMILAR row similarity flag=" $LAST[1] "\n";

select cast (VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6)) as integer)
  from DB.DBA.VVEC_AUTO_DOCS where id = 2;
ECHO BOTH $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": strict ANN rejects row-distance fallback STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select sqlo_vvec_require_ann (0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": disable strict ANN STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select VECTOR_DISTANCE (DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 1, 2), DB.DBA.VVEC_BEGIN_MAKE_VEC (11, -1));
ECHO BOTH $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": VECTOR_DISTANCE dimension mismatch rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6), 'euclidean')
  from DB.DBA.VVEC_AUTO_DOCS where id = 2;
ECHO BOTH $IF $EQU $STATE 22023 "PASSED" "***FAILED";
ECHO BOTH ": indexed VECTOR_DISTANCE metric mismatch rejected STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- EXPLAIN vector node annotation checks (phase 4)

select case when strstr (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6))'),
  'vector index VVEC_AUTO_IDX') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": explain shows vector index name flag=" $LAST[1] "\n";

select case when strstr (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6))'),
  'mode=ann') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": explain shows mode=ann flag=" $LAST[1] "\n";

select case when strstr (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6))'),
  'metric=cosine') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": explain shows metric=cosine flag=" $LAST[1] "\n";

select case when strstr (lower (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6))')),
  'source=content') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": explain shows source column flag=" $LAST[1] "\n";

select case when strstr (__vvec_explain_str (
    'select top 1 id from DB.DBA.VVEC_AUTO_DOCS order by VECTOR_DISTANCE (content, DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6))'),
  'dim=8 hnsw_m=8 ef_construction=16') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": explain shows dim/hnsw_m/ef_construction flag=" $LAST[1] "\n";

select case when strstr (__vvec_explain_str (
    'select VECTOR_DISTANCE (DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 1, 2), DB.DBA.VVEC_BEGIN_MAKE_DIM_VEC (8, 5, 6)) from DB.DBA.VVEC_AUTO_DOCS where id = 2'),
  'vector index') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": scalar VECTOR_DISTANCE explain carries no vector index flag=" $LAST[1] "\n";

create table DB.DBA.VVEC_DROP_DOCS (
  id integer not null primary key,
  content varchar
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_DROP_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE VECTOR INDEX VVEC_DROP_IDX
ON DB.DBA.VVEC_DROP_DOCS (content)
USING 'vvec-test-8'
WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create drop vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VVEC_DROP_DOCS (id, content) values (1, 'drop positions 1 2');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop-path insert DML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": drop-path insert drain count=" $LAST[1] "\n";

select count (*) from DB.DBA.VVEC_DROP_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": drop-path hidden rows after insert=" $LAST[1] "\n";

select DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_PAGE_STATS ('VVEC_DROP_IDX'), 'node_pages');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": drop-path node_pages before immediate drop=" $LAST[1] "\n";

drop index VVEC_DROP_IDX;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": immediate drop VVEC_DROP_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SYS_TRIGGERS
 where T_TABLE = 'DB.DBA.VVEC_DROP_DOCS'
   and name_part (T_NAME, 2) like 'VVEC_DROP_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": drop-path triggers after immediate drop=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_DROP_IDX';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": drop-path SYS_KEYS entries after immediate drop=" $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where upper(KEY_TABLE) =  upper('DB.DBA.VVEC_DROP_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": drop-path hidden table metadata after immediate drop=" $LAST[1] "\n";

drop table DB.DBA.VVEC_DROP_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_DROP_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: VVEC begin bootstrap\n";
