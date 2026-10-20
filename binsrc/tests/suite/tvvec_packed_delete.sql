--
--  tvvec_packed_delete.sql
--
--  Phase 7 regression test: verify that DELETE works on a table with a
--  packed-format vector index without crashing.
--

-- Create a small table and vector index
create table DB.DBA.VVEC_DEL_TEST (id integer not null primary key, content varchar);

-- Insert 100 rows with deterministic vectors
create function DB.DBA.VVEC_DEL_RAND_VEC (in seed integer, in dim integer) returns any
{
  declare vec any;
  declare i, c integer;
  declare cx, nx bigint;
  declare cen, noi double precision;
  vec := make_array (dim, 'any');
  c := mod (seed, 200);
  cx := mod (cast (c + 1 as bigint) * 2654435761 + 1013904223, 2147483648);
  nx := mod (cast (seed as bigint) * 40503 + 12345, 2147483648);
  if (cx < 0) cx := cx + 2147483648;
  if (nx < 0) nx := nx + 2147483648;
  for (i := 0; i < dim; i := i + 1)
    {
      cx := mod (cx * 1103515245 + 12345, 2147483648);
      nx := mod (nx * 1103515245 + 12345, 2147483648);
      cen := (cast (cx as double precision) / 2147483648.0) * 2.0 - 1.0;
      noi := ((cast (nx as double precision) / 2147483648.0) * 2.0 - 1.0) * 0.5;
      aset (vec, i, cen + noi);
    }
  return vec;
};

create procedure DB.DBA.VVEC_DEL_SETUP (in dim integer)
{
  declare nm varchar;
  nm := sprintf ('vvec-cmp-%d', dim);
  if (not exists (select 1 from DB.DBA.ONNX_MODELS where model_name = nm))
    insert into DB.DBA.ONNX_MODELS
      (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
    values (nm, 'del test model', sprintf ('internal:%s', nm), 'test_embedding',
            'embedding', sprintf ('1,%d', dim), now (), now ());
};

create procedure DB.DBA.VVEC_DEL_RUN ()
{
  declare i integer;
  declare vec any;
  declare r any;
  declare stats any;
  declare fmt varchar;
  declare total_pages integer;
  declare n_before, n_after integer;

  DB.DBA.VVEC_DEL_SETUP (384);

  -- Create the vector index (after model is set up)
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_DEL_IDX'))
    exec ('CREATE VECTOR INDEX VVEC_DEL_IDX ON DB.DBA.VVEC_DEL_TEST (content) USING ''vvec-cmp-384'' '
      || 'WITH (dimensions=384, distance_metric=''l2'', hnsw_m=16, ef_construction=200)');

  -- Insert 100 rows
  for (i := 1; i <= 100; i := i + 1)
    {
      vec := DB.DBA.VVEC_DEL_RAND_VEC (i, 384);
      insert into DB.DBA.VVEC_DEL_TEST (id, content) values (i, sprintf ('doc %d', i));
      r := __VEC_INDEX_INSERT_EMBEDDING ('VVEC_DEL_IDX', i, vec);
    }

  -- Rebuild into packed format
  r := __VEC_INDEX_REBUILD ('VVEC_DEL_IDX', 'fast');

  -- Check format is packed
  stats := __VEC_INDEX_PAGE_STATS ('VVEC_DEL_IDX');
  fmt := 'unknown';
  total_pages := 0;
  for (i := 0; i < length (stats); i := i + 2)
    {
      if (aref (stats, i) = 'format')
        fmt := aref (stats, i + 1);
      if (aref (stats, i) = 'physical_node_pages')
        total_pages := aref (stats, i + 1);
    }

  result_names ('metric', 'value');
  result ('format', fmt);
  result ('physical_pages', cast (total_pages as varchar));

  n_before := (select count(*) from DB.DBA.VVEC_DEL_TEST);
  result ('rows_before_delete', cast (n_before as varchar));

  -- DELETE 10 rows — this used to crash
  delete from DB.DBA.VVEC_DEL_TEST where id <= 10;

  n_after := (select count(*) from DB.DBA.VVEC_DEL_TEST);
  result ('rows_after_delete', cast (n_after as varchar));
  result ('delete_succeeded', '1');

  -- Search should still work
  vec := DB.DBA.VVEC_DEL_RAND_VEC (50, 384);
  r := __VEC_INDEX_SEARCH ('VVEC_DEL_IDX', vec, 5, 50);
  result ('search_after_delete', cast (length (r) as varchar));
};

call DB.DBA.VVEC_DEL_RUN ();
