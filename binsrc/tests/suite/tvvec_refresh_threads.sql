--
--  tvvec_refresh_threads.sql
--
--  A refresh at concurrency N runs its embedding batches on an async queue of
--  N workers, each in a transaction of its own (AQ_SEPARATE_TXN).  A worker
--  that cannot get a thread from the server's async-queue pool does not wait
--  for one: aq_request fails with 42000/CLAQN.  The pool has
--  AsyncQueueMaxThreads threads -- 10 in the stock virtuoso.ini, twice
--  ThreadsPerQuery when unset -- while __vec_embed_concurrency accepts up to
--  32, so a concurrency above the pool failed every time, after the whole
--  enumeration had run.  It has to be lowered to what the pool can give, and
--  the refresh has to say so.
--
--  The pool is lowered to 2 here (__dbf_set ('aq_max_threads', 2)).
--
--  1. Guard: concurrency 2 in a pool of 2 completes.
--  2. Concurrency 32 in a pool of 2 completes, reports the concurrency it
--     used, and leaves every row in the graph embedded right.
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

echo BOTH "STARTED: vector index refresh concurrency and the async-queue pool\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'trt-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('trt-64', 'refresh threads test model', 'internal:trt-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register trt-64 STATE=" $STATE "\n";

create procedure DB.DBA.TRT_TEXT (in k integer) returns varchar
{
  return sprintf ('doc %d %d', mod (k, 32), 32 + mod (k / 32, 32));
}
;

create procedure DB.DBA.TRT_LOAD (in g varchar, in n integer)
{
  declare k integer;
  for (k := 0; k < n; k := k + 1)
    DB.DBA.RDF_QUAD_URI_L (g, sprintf ('urn:trt:%d', k), 'urn:trt:text', DB.DBA.TRT_TEXT (k));
  commit work;
}
;

create procedure DB.DBA.TRT_CREATE (in idx varchar, in g varchar)
{
  declare st, msg varchar;
  st := '00000';
  exec (sprintf ('sparql define input:storage "" drop silent vector index <%s>', idx), st, msg);
  st := '00000';
  exec (sprintf ('sparql define input:storage "" create vector index <%s> on graph <%s> for predicate <urn:trt:text> using model ''trt-64'' with (dimensions = 64, distance = ''cosine'', maintenance = ''manual'')', idx, g),
        st, msg);
  if (st <> '00000')
    signal (st, msg);
}
;

create table DB.DBA.TRT_S (M varchar primary key, S varchar);

--  Refresh IDX at concurrency CONC with the async-queue pool at POOL threads;
--  the error, or '' on success, under TAG, and the refresh's message under
--  TAG || '_msg'.
create procedure DB.DBA.TRT_REFRESH (in idx varchar, in conc integer, in pool integer, in tag varchar)
{
  declare old_pool integer;
  declare err, msg varchar;
  declare r any;
  registry_set ('__vec_embed_concurrency', cast (conc as varchar));
  err := '';
  msg := '';
  old_pool := __dbf_set ('aq_max_threads', pool);
  {
    declare exit handler for sqlstate '*' { err := __SQL_STATE || ' ' || __SQL_MESSAGE; goto done; };
    r := DB.DBA.VEC_INDEX_REFRESH (idx);
    msg := cast (r[0][1] as varchar);
  }
done:
  rollback work;
  __dbf_set ('aq_max_threads', old_pool);
  registry_set ('__vec_embed_concurrency', '');
  insert replacing DB.DBA.TRT_S values (tag, err);
  insert replacing DB.DBA.TRT_S values (tag || '_msg', msg);
  insert replacing DB.DBA.TRT_S values (tag || '_pool', cast (old_pool as varchar));
  commit work;
}
;

create procedure DB.DBA.TRT_GET (in tag varchar) returns varchar
{
  return coalesce ((select S from DB.DBA.TRT_S where M = tag), '<not run>');
}
;

create procedure DB.DBA.TRT_ACTIVE (in idx varchar) returns integer
{
  declare m any;
  m := __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx));
  return cast (get_keyword ('graph_nodes', m, -1) as integer) - cast (get_keyword ('deleted_nodes', m, 0) as integer);
}
;

--  How many of subjects 0 .. N-1 are stored as the test embedding of their text.
create procedure DB.DBA.TRT_RIGHT (in idx varchar, in n integer) returns integer
{
  declare st, msg, stmt varchar;
  declare md, rs, v, e any;
  declare i, k, good integer;
  stmt := sprintf ('select VE_EMBEDDING from DB.DBA.%s_vec_embeddings where VE_D_ID = ?',
                   DB.DBA.VEC_INDEX_GENERATE_NAME (idx));
  good := 0;
  for (k := 0; k < n; k := k + 1)
    {
      st := '00000';
      exec (stmt, st, msg, vector (iri_id_num (iri_to_id (sprintf ('urn:trt:%d', k)))), 0, md, rs);
      if (st <> '00000' or length (rs) <> 1)
        goto next;
      v := rs[0][0];
      e := __VEC_INDEX_TEST_EMBEDDING (64, DB.DBA.TRT_TEXT (k));
      if (VVEC_DIMENSION (v) <> VVEC_DIMENSION (e))
        goto next;
      for (i := 0; i < VVEC_DIMENSION (e); i := i + 1)
        if (abs (aref (v, i) - aref (e, i)) > 1e-6)
          goto next;
      good := good + 1;
     next:;
    }
  return good;
}
;

sparql clear graph <urn:trt:g>;
DB.DBA.TRT_LOAD ('urn:trt:g', 3000);

-- ===========================================================================
-- 1. Guard: a concurrency the pool can give
-- ===========================================================================

DB.DBA.TRT_CREATE ('urn:trt:i1', 'urn:trt:g');
DB.DBA.TRT_REFRESH ('urn:trt:i1', 2, 2, 's1');
select DB.DBA.TRT_GET ('s1');
ECHO BOTH ": s1 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRT_GET ('s1') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": concurrency 2 in a pool of 2 threads completes, ok=" $LAST[1] "\n";
select DB.DBA.TRT_ACTIVE ('urn:trt:i1');
ECHO BOTH $IF $EQU $LAST[1] 3000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 3000 nodes, active=" $LAST[1] "\n";

-- ===========================================================================
-- 2. More than the pool can give
-- ===========================================================================

DB.DBA.TRT_CREATE ('urn:trt:i2', 'urn:trt:g');
DB.DBA.TRT_REFRESH ('urn:trt:i2', 32, 2, 's2');
select DB.DBA.TRT_GET ('s2');
ECHO BOTH ": s2 error: '" $LAST[1] "'\n";
select case when DB.DBA.TRT_GET ('s2') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": concurrency 32 in a pool of 2 threads completes, ok=" $LAST[1] "\n";
select DB.DBA.TRT_GET ('s2_msg');
ECHO BOTH ": s2 result: '" $LAST[1] "'\n";
select case when DB.DBA.TRT_GET ('s2_msg') like '%embed concurrency 32 lowered to 2%' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the result says the concurrency was lowered to the pool's 2 threads, ok=" $LAST[1] "\n";
select DB.DBA.TRT_ACTIVE ('urn:trt:i2');
ECHO BOTH $IF $EQU $LAST[1] 3000 "PASSED" "***FAILED";
ECHO BOTH ": its graph holds 3000 nodes, active=" $LAST[1] "\n";
select DB.DBA.TRT_RIGHT ('urn:trt:i2', 3000);
ECHO BOTH $IF $EQU $LAST[1] 3000 "PASSED" "***FAILED";
ECHO BOTH ": every row is stored as the embedding of its own text, right=" $LAST[1] "\n";

select case when sys_stat ('aq_max_threads') = cast (DB.DBA.TRT_GET ('s2_pool') as integer) then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the async-queue pool is back to its own size, ok=" $LAST[1] "\n";

sparql define input:storage "" drop silent vector index <urn:trt:i1>;
sparql define input:storage "" drop silent vector index <urn:trt:i2>;
sparql clear graph <urn:trt:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'trt-64';

echo BOTH "COMPLETED: vector index refresh concurrency and the async-queue pool\n";
