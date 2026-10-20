--
--  tvvec_optimizer_vector_key.sql
--
--  Regression test: the SQL optimizer must never cost a native vector (HNSW)
--  index as an ordinary B-tree candidate.
--
--  A native vector index is registered in SYS_KEYS as a regular secondary key
--  of its base table.  The cost-based optimizer therefore used to pick it up
--  while enumerating candidate indexes for ANY plain SQL query against that
--  table, and sampled it:
--
--    sqlo_choose_index -> dfe_table_cost_ic -> sqlo_inx_sample
--      -> itc_local_sample -> itc_reset -> it_new_root_image
--
--  An HNSW index is not an ordered B-tree and has no samplable page structure,
--  so it_new_root_image dereferenced a root buffer whose content map is NULL
--  and SEGFAULTED THE SERVER (EXC_BAD_ACCESS at address 0x2).
--
--  This bit the SPARQL vector-index backfill hard: VEC_INDEX_CHECK_HASH probes
--  the backing table once per row with
--    select RV_TEXT_HASH from VECSRC_<hex> where RV_ID = <id>
--  -- exactly such a query -- so refreshing a large index killed the server a
--  few seconds in, every time.
--
--  The test is deliberately COMPILE-time only: it needs no embeddings and no
--  ONNX, because the crash happened while compiling the query, before any row
--  was touched.  It uses the in-core deterministic 'test_embedding' model and
--  so runs unconditionally.
--
--  Before the fix every query below crashes the server (the harness reports
--  ***ABORTED because the script cannot run to completion).  After it, they
--  compile and return the right answers.
--
--  Run with:
--    isql <port> dba dba binsrc/tests/suite/tvvec_optimizer_vector_key.sql
--

echo BOTH "STARTED: vector index must not be costed as a B-tree candidate\n";

--  ---- fixtures --------------------------------------------------------------

create table DB.DBA.ONNX_MODELS (
  model_id integer identity,
  model_name varchar,
  description varchar,
  model_path varchar,
  model_type varchar,
  output_name varchar,
  output_shape varchar,
  vocab_path varchar,
  max_seq_len integer,
  handle integer,
  created_at datetime,
  updated_at datetime,
  primary key (model_id)
) if not exists;
create unique index ONNX_MODELS_NAME_IDX on DB.DBA.ONNX_MODELS (model_name) if not exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ensure ONNX_MODELS table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-optinx-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-optinx-8', 'deterministic test model for optimizer vector-key test',
   'internal:vvec-optinx-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-optinx-8 model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  A table shaped like the vector-index backing table (VECSRC_<hex>): an
--  integer primary key, a source text column and a hash column.
drop table DB.DBA.VVEC_OPTINX_DOCS;
create table DB.DBA.VVEC_OPTINX_DOCS (
  RV_ID bigint primary key,
  RV_TEXT varchar,
  RV_TEXT_HASH varbinary,
  RV_UPDATED datetime );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_OPTINX_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into DB.DBA.VVEC_OPTINX_DOCS (RV_ID, RV_TEXT, RV_TEXT_HASH, RV_UPDATED)
  values (1, 'reset password help', cast (md5 ('reset password help') as varbinary), now ());
insert into DB.DBA.VVEC_OPTINX_DOCS (RV_ID, RV_TEXT, RV_TEXT_HASH, RV_UPDATED)
  values (2, 'reset password policy', cast (md5 ('reset password policy') as varbinary), now ());
insert into DB.DBA.VVEC_OPTINX_DOCS (RV_ID, RV_TEXT, RV_TEXT_HASH, RV_UPDATED)
  values (3, 'billing address change', cast (md5 ('billing address change') as varbinary), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed VVEC_OPTINX_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  A deterministic dim-8 probe vector for the ANN check below.
create function DB.DBA.VVEC_OPTINX_MAKE_VEC (in pos integer) returns any
{
  declare vec any;
  declare inx integer;
  vec := make_array (8, 'any');
  for (inx := 0; inx < 8; inx := inx + 1)
    aset (vec, inx, 0);
  if (pos is not null and pos >= 0 and pos < 8)
    aset (vec, pos, 1);
  return vec;
};

CREATE VECTOR INDEX VVEC_OPTINX_IDX
ON DB.DBA.VVEC_OPTINX_DOCS (RV_TEXT)
USING 'vvec-optinx-8'
WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 24);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  The precondition for the crash: the vector index really is registered as a
--  secondary key of the base table, so the cost model does see it.
select count (*) from DB.DBA.SYS_KEYS
 where KEY_TABLE = 'DB.DBA.VVEC_OPTINX_DOCS'
   and KEY_IS_MAIN = 0
   and name_part (KEY_NAME, 2) = 'VVEC_OPTINX_IDX';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": vector index is a secondary key of the base table rows=" $LAST[1] "\n";

--  ---- the regression: plain SQL over a vector-indexed table -----------------

--  1. The exact shape VEC_INDEX_CHECK_HASH uses -- primary-key equality.  This
--     is the query that crashed the server on every large backfill.
select RV_TEXT_HASH from DB.DBA.VVEC_OPTINX_DOCS where RV_ID = 2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": pk-equality select compiles STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select case when RV_TEXT_HASH = cast (md5 ('reset password policy') as varbinary) then 1 else 0 end
  from DB.DBA.VVEC_OPTINX_DOCS where RV_ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": pk-equality select returns the right row flag=" $LAST[1] "\n";

--  2. A range predicate on the primary key -- the keyset-paging shape.
select count (*) from DB.DBA.VVEC_OPTINX_DOCS where RV_ID > 1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": pk-range select rows=" $LAST[1] "\n";

--  3. A predicate on a NON-key column, which makes the optimizer weigh every
--     candidate index rather than going straight to the primary key.
select count (*) from DB.DBA.VVEC_OPTINX_DOCS where RV_TEXT like 'reset%';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": non-key predicate rows=" $LAST[1] "\n";

--  4. A full scan / aggregate.
select count (*) from DB.DBA.VVEC_OPTINX_DOCS;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": full scan rows=" $LAST[1] "\n";

--  5. A self-join, so the table is placed more than once and costed repeatedly.
select count (*) from DB.DBA.VVEC_OPTINX_DOCS a, DB.DBA.VVEC_OPTINX_DOCS b
 where a.RV_ID = b.RV_ID;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": self-join rows=" $LAST[1] "\n";

--  6. Update and delete paths also compile against the same table.
update DB.DBA.VVEC_OPTINX_DOCS set RV_UPDATED = now () where RV_ID = 3;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": update compiles STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  7. The ANN path must still resolve the vector index -- skipping vector keys
--     in the cost model must not disable vector search itself.
select count (*) from (
  select top 2 RV_ID from DB.DBA.VVEC_OPTINX_DOCS
   order by VECTOR_DISTANCE (RV_TEXT, DB.DBA.VVEC_OPTINX_MAKE_VEC (3)) ) x;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": ANN order-by still returns rows=" $LAST[1] "\n";

--  ---- cleanup ---------------------------------------------------------------

drop table DB.DBA.VVEC_OPTINX_DOCS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_OPTINX_DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-optinx-8';

echo BOTH "COMPLETED: vector index must not be costed as a B-tree candidate\n";
