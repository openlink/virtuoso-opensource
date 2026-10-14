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

--
-- SPARQL Vector Index catalog tables and DBA procedures.
-- These procedures are called by the SPARQL parser via spar_make_qm_sql
-- dispatch, similar to DB.DBA.RDF_QM_* procedures in sparql_qm.sql.
--

-- Catalog table for SPARQL vector indexes.
-- Each row describes one vector index created via SPARQL DDL.

create table DB.DBA.SPARQL_VEC_INDEX (
  SVI_ID integer identity,
  SVI_IRI varchar not null primary key,
  SVI_INTERNAL_NAME varchar not null,
  SVI_SOURCE_TABLE varchar not null,
  SVI_SELECTOR_TYPE varchar not null,    -- 'shorthand' or 'general'
  SVI_SELECTOR_TEXT long varchar,        -- canonical selector text
  SVI_SELECTOR_GRAPH varchar,            -- fixed graph IRI for shorthand
  SVI_SELECTOR_PRED varchar,             -- fixed predicate IRI for shorthand
  SVI_KEY_VAR varchar,                   -- key variable name (general selector)
  SVI_EMBEDDING_VAR varchar,             -- embedding variable name (general selector)
  SVI_WHERE_TEXT long varchar,           -- human-readable WHERE pattern text (general selector)
  SVI_WHERE_PATTERN long varbinary,      -- general selector: PREFIX preamble (namespace decls in scope at create time), prepended when SVI_WHERE_TEXT is re-parsed at refresh/async time; NULL when no local prefixes were declared
  SVI_MODEL_NAME varchar not null,
  SVI_DIMENSIONS integer not null,
  SVI_REDUCE varchar default 'none',         -- 'none' or 'truncate' (Matryoshka)
  SVI_MODEL_DIMENSIONS integer default 0,    -- model native output dim (== SVI_DIMENSIONS when not reduced)
  SVI_DISTANCE varchar default 'cosine',
  SVI_HNSW_M integer default 16,
  SVI_EF_CONSTRUCTION integer default 200,
  SVI_MAINTENANCE varchar default 'manual',
  SVI_REBUILD varchar,                       -- rebuild method: null (default), 'replay', 'fast' or 'auto'
  SVI_BUILD varchar,                         -- backfill method: null/'auto'/'incremental' (default), or 'bulk' (opt-in)
  SVI_DATASET_TEXT varchar,                  -- general selector: the FROM / FROM NAMED clause as written, re-emitted into the enumeration query at refresh time; NULL when none was given
  SVI_SOURCE_KIND varchar default 'text',    -- 'text' (model path) or 'vector' (precomputed-vector passthrough)
  SVI_LABEL varchar,                         -- rdfs:label -- a short human name for the index
  SVI_COMMENT varchar,                       -- rdfs:comment -- what the index is for, in prose
  SVI_OWNER varchar,
  SVI_CREATED datetime,
  SVI_REFRESHED datetime,
  SVI_GENERATION integer default 0,
  SVI_STATE varchar default 'creating',
  SVI_LAST_ERROR long varchar
) if not exists
;

create unique index SPARQL_VEC_INDEX_ID on DB.DBA.SPARQL_VEC_INDEX (SVI_ID)
  if not exists
;

-- Idempotent additive column upgrades for pre-existing databases.
-- The table is created with IF NOT EXISTS above, so on an existing DB these
-- ALTER TABLE statements add the new columns; the IF NOT EXISTS guard makes
-- re-running the script safe.
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_REDUCE varchar default 'none' if not exists
;
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_MODEL_DIMENSIONS integer default 0 if not exists
;
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_REBUILD varchar if not exists
;
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_BUILD varchar if not exists
;

alter table DB.DBA.SPARQL_VEC_INDEX add SVI_DATASET_TEXT varchar if not exists
;
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_SOURCE_KIND varchar default 'text' if not exists
;
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_LABEL varchar if not exists
;
alter table DB.DBA.SPARQL_VEC_INDEX add SVI_COMMENT varchar if not exists
;

-- Trigger catalog for general-selector async maintenance.
-- One row per (index, graph, predicate) dependency pair extracted from the
-- WHERE pattern at parse time.  SVT_PRED_IRI = '' means graph-only fallback
-- (match any predicate in that graph); a real IRI means predicate-precise.
-- The shorthand selector does not populate this table -- it matches via
-- SVI_SELECTOR_GRAPH/SVI_SELECTOR_PRED directly in VEC_INDEX_ENQUEUE_RDF_CHANGE.
create table DB.DBA.SPARQL_VEC_INDEX_TRIGGER (
  SVT_INDEX_IRI varchar not null,
  SVT_GRAPH_IRI varchar not null,
  SVT_PRED_IRI  varchar not null default '',   -- '' = graph-only (match any predicate)
  primary key (SVT_INDEX_IRI, SVT_GRAPH_IRI, SVT_PRED_IRI)
) if not exists
;

-- Work queue for async maintenance
create table DB.DBA.SPARQL_VEC_QUEUE (
  SVQ_ID integer identity,
  SVQ_INDEX_IRI varchar not null,
  SVQ_KEY_ID bigint not null,
  SVQ_QUEUED datetime not null,
  SVQ_RETRIES integer default 0,
  SVQ_STATE varchar default 'pending',
  SVQ_LAST_ERROR long varchar,
  primary key (SVQ_INDEX_IRI, SVQ_KEY_ID)
) if not exists
;

create table DB.DBA.SPARQL_VEC_WORKER (
  SVW_ID integer primary key,
  SVW_ENABLED integer default 0,
  SVW_BATCH_SIZE integer default 100,
  SVW_IDLE_DELAY integer default 5,
  SVW_LAST_RUN datetime,
  SVW_LAST_ERROR long varchar,
  SVW_PROCESSED bigint default 0,
  SVW_UPDATED datetime
) if not exists
;

insert soft DB.DBA.SPARQL_VEC_WORKER
  (SVW_ID, SVW_ENABLED, SVW_BATCH_SIZE, SVW_IDLE_DELAY, SVW_UPDATED)
values (1, 0, 100, 5, now ())
;

-- Generate a collision-resistant internal SQL name from a public IRI.
-- Uses MD5 hash to avoid truncation collisions.
create function DB.DBA.VEC_INDEX_GENERATE_NAME (in idx_iri varchar) returns varchar
{
  declare h varchar;
  h := md5 (idx_iri);
  return sprintf ('VECIDX_%s', upper (h));
}
;

-- Generate the backing source table name.
create function DB.DBA.VEC_INDEX_GENERATE_SOURCE_TABLE (in idx_iri varchar) returns varchar
{
  declare h varchar;
  h := md5 (idx_iri);
  return sprintf ('DB.DBA.VECSRC_%s', h);
}
;

create procedure DB.DBA.VEC_INDEX_BEGIN_MUTATION (
  in idx_iri varchar,
  in op varchar )
{
  declare old_state varchar;

  whenever not found goto not_found;
  select SVI_STATE into old_state
    from DB.DBA.SPARQL_VEC_INDEX
    where SVI_IRI = idx_iri;

  -- 'error' is retryable, and is accepted here alongside 'active'.  A failed
  -- refresh leaves the index in 'error', and admitting only 'active' made that
  -- a dead end: every later attempt failed this guard, so the one state that
  -- most wants a retry was the one state that could not have one without
  -- hand-editing SPARQL_VEC_INDEX.  Nothing about 'error' makes a retry unsafe
  -- -- REFRESH re-derives its work from the selector and skips rows whose text
  -- hash is unchanged, so it resumes rather than redoes.
  --
  -- The in-flight ops ('refreshing', 'dropping', 'draining') are still refused,
  -- which is the real point of this guard: they mean another thread is working
  -- on this index right now.  'creating' and 'dropped' stay refused too.
  update DB.DBA.SPARQL_VEC_INDEX
    set SVI_STATE = op,
        SVI_LAST_ERROR = null
    where SVI_IRI = idx_iri and SVI_STATE in ('active', 'error');
  if (row_count () <> 1)
    signal ('VEC90', sprintf ('Vector index <%s> is busy or not active (state: %s)', idx_iri, old_state));
  DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;
  return;

not_found:;
  signal ('VEC91', sprintf ('Vector index <%s> not found', idx_iri));
}
;

create procedure DB.DBA.VEC_INDEX_END_MUTATION (
  in idx_iri varchar,
  in op varchar,
  in ok integer,
  in err varchar := null )
{
  if (ok)
    update DB.DBA.SPARQL_VEC_INDEX
      set SVI_STATE = 'active',
          SVI_LAST_ERROR = null
      where SVI_IRI = idx_iri and SVI_STATE = op;
  else
    update DB.DBA.SPARQL_VEC_INDEX
      set SVI_STATE = 'error',
          SVI_LAST_ERROR = err
      where SVI_IRI = idx_iri and SVI_STATE = op;
  DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;
}
;

create function DB.DBA.VEC_INDEX_GRAPH_READABLE (
  in graph_iri varchar ) returns integer
{
  declare uid any;
  if (graph_iri is null or graph_iri = '')
    return 0;
  if (user_is_dba (user))
    return 1;
  uid := get_user_id (1);
  if (DB.DBA.RDF_GRAPH_USER_PERMS_ACK (graph_iri, uid, 1))
    return 1;
  return 0;
}
;

-- Begin creating a vector index. Inserts a catalog record in 'creating' state.
create procedure DB.DBA.VEC_INDEX_BEGIN_CREATE (in idx_iri varchar) returns any
{
  declare internal_name, source_table varchar;
  declare STATE, MESSAGE varchar;

  -- Check for duplicate
  if (exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri))
    signal ('VEC01', sprintf ('Vector index <%s> already exists', idx_iri));

  internal_name := DB.DBA.VEC_INDEX_GENERATE_NAME (idx_iri);
  source_table := DB.DBA.VEC_INDEX_GENERATE_SOURCE_TABLE (idx_iri);

  insert into DB.DBA.SPARQL_VEC_INDEX (
    SVI_IRI, SVI_INTERNAL_NAME, SVI_SOURCE_TABLE,
    SVI_SELECTOR_TYPE, SVI_MODEL_NAME, SVI_DIMENSIONS,
    SVI_OWNER, SVI_CREATED, SVI_STATE )
  values (
    idx_iri, internal_name, source_table,
    'pending', '', 0,
    get_user_id (1), now (), 'creating' );

  commit work;
  return vector (vector ('00000', sprintf ('Vector index <%s> creation started', idx_iri)));
}
;

-- Set the selector for a vector index.
-- For shorthand: graph_iri and pred_iri are plain varchar IRIs.
-- For general: graph_iri is the KEY variable name, pred_iri is the EMBEDDING variable name,
--   and where_text is the raw WHERE clause text.
-- Undo a create that was refused after it had started.
--
-- The SPARQL create DDL is a sequence of separate statements -- BEGIN_CREATE,
-- SET_SELECTOR, SET_TRIGGERS, SET_MODEL, SET_OPTIONS, END_CREATE -- each of
-- which commits.  BEGIN_CREATE inserts the catalogue row in state 'creating'
-- and END_CREATE promotes it to 'active', so a refusal in between (VEC77 for an
-- unscopable async pattern is the usual one) left the row behind forever: not
-- active, not droppable through the normal path, and enough to make a second
-- attempt at the same IRI fail with VEC01 "already exists".
--
-- Only a row still in 'creating' is removed, so this can never touch an index
-- that finished building.  Like the other cleanup paths it must not raise --
-- it runs from an error handler, and the original error is the one worth
-- reporting.
create procedure DB.DBA.VEC_INDEX_ABORT_CREATE (in idx_iri varchar)
{
  declare internal_name, source_table, st, msg varchar;
  declare md, rs any;
  declare exit handler for sqlstate '*' { return; };
  whenever not found goto done;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE into internal_name, source_table
    from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri and SVI_STATE = 'creating';
  --  END_CREATE builds the backing table and the native index before it flips
  --  the row to 'active', so an abort has to be able to undo those too --
  --  otherwise a retry at the same IRI regenerates the same internal name and
  --  collides with the objects left behind.  Both drops are tolerated failures:
  --  whichever of them was never reached simply is not there.
  if (internal_name is not null and internal_name <> '')
    {
      st := '00000';
      exec (sprintf ('drop index %s', internal_name), st, msg, vector (), 10000, md, rs);
    }
  if (source_table is not null and source_table <> '')
    DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (source_table);
  delete from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI = idx_iri;
  delete from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri and SVI_STATE = 'creating';
  commit work;
 done:;
}
;

create procedure DB.DBA.VEC_INDEX_SET_SELECTOR (
  in idx_iri varchar,
  in selector_type varchar,
  in graph_iri any,
  in pred_iri any,
  in where_text any := null,
  in where_prefixes any := null,
  in dataset_text any := null ) returns any
{
  declare key_var_name, embedding_var_name varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.VEC_INDEX_ABORT_CREATE (idx_iri);   -- no-op unless still 'creating'
      resignal;
    };

  if (not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri))
    signal ('VEC02', sprintf ('Vector index <%s> not found for selector setup', idx_iri));

  if ('shorthand' = selector_type)
    {
      if (graph_iri is null)
        signal ('VEC03', 'Shorthand vector index selector requires an explicit graph');
      if (pred_iri is null)
        signal ('VEC04', 'Shorthand vector index selector requires an explicit predicate');

      update DB.DBA.SPARQL_VEC_INDEX
      set SVI_SELECTOR_TYPE = 'shorthand',
          SVI_SELECTOR_GRAPH = cast (graph_iri as varchar),
          SVI_SELECTOR_PRED = cast (pred_iri as varchar),
          SVI_SELECTOR_TEXT = sprintf ('GRAPH <%s> { ?s <%s> ?text }', graph_iri, pred_iri),
          SVI_WHERE_PATTERN = null
      where SVI_IRI = idx_iri;
    }
  else if ('general' = selector_type)
    {
      key_var_name := cast (graph_iri as varchar);
      embedding_var_name := cast (pred_iri as varchar);

      if (key_var_name is null or key_var_name = '')
        signal ('VEC07', 'General selector requires a KEY variable');
      if (embedding_var_name is null or embedding_var_name = '')
        signal ('VEC08', 'General selector requires an EMBEDDING variable');
      if (key_var_name = embedding_var_name)
        signal ('VEC09', 'KEY and EMBEDDING variables must be different');
      if (where_text is null or where_text = '')
        signal ('VEC10', 'General selector requires a WHERE pattern');

      update DB.DBA.SPARQL_VEC_INDEX
      set SVI_SELECTOR_TYPE = 'general',
          SVI_KEY_VAR = key_var_name,
          SVI_EMBEDDING_VAR = embedding_var_name,
          SVI_WHERE_TEXT = cast (where_text as varchar),
          SVI_WHERE_PATTERN = where_prefixes,
          SVI_DATASET_TEXT = case when dataset_text is null then null
                                  else cast (dataset_text as varchar) end
      where SVI_IRI = idx_iri;
    }
  else
    signal ('VEC05', sprintf ('Unknown selector type: %s', selector_type));

  commit work;
  return vector (vector ('00000', sprintf ('Selector set for vector index <%s>', idx_iri)));
}
;

-- Set the (graph, predicate) trigger pairs for a general-selector vector index.
-- Called by the SPARQL parser after VEC_INDEX_SET_SELECTOR for general indexes.
-- `pairs` is a flat vector of [graph_iri_1, pred_iri_1, graph_iri_2, pred_iri_2, ...]
-- as produced by spar_vec_extract_trigger_pairs in sparql_tree.c.  An empty pred
-- IRI ('') means graph-only fallback (match any predicate in that graph).  An
-- empty `pairs` means the WHERE pattern is not async-scopable; no rows are
-- stored and VEC_INDEX_SET_OPTIONS later rejects maintenance = 'async' for the
-- general selector with an actionable error.  Runs unconditionally at create
-- time; rows are harmless for manual indexes because the enqueue path filters
-- on SVI_MAINTENANCE = 'async'.
create procedure DB.DBA.VEC_INDEX_SET_TRIGGERS (
  in idx_iri varchar,
  in pairs any ) returns any
{
  declare ctr, len integer;
  declare g_iri, p_iri varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.VEC_INDEX_ABORT_CREATE (idx_iri);   -- no-op unless still 'creating'
      resignal;
    };

  if (not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri))
    signal ('VEC76', sprintf ('Vector index <%s> not found for trigger setup', idx_iri));

  -- Replace any existing trigger rows for this index (re-runnable / re-creation)
  delete from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI = idx_iri;

  len := length (pairs);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    {
      g_iri := cast (pairs[ctr] as varchar);
      p_iri := cast (pairs[ctr + 1] as varchar);
      if (g_iri is not null and g_iri <> '')
        {
          if (p_iri is null)
            p_iri := '';
          insert soft DB.DBA.SPARQL_VEC_INDEX_TRIGGER (SVT_INDEX_IRI, SVT_GRAPH_IRI, SVT_PRED_IRI)
            values (idx_iri, g_iri, p_iri);
        }
    }

  commit work;
  return vector (vector ('00000', sprintf ('Triggers set for vector index <%s> (%d pair(s))', idx_iri, len / 2)));
}
;

-- Parse the output_shape string (e.g. '1,384') and return the last integer.
create function DB.DBA.VEC_INDEX_PARSE_DIMS (in shape_str varchar) returns integer
{
  declare pos integer;
  declare dims integer;
  if (shape_str is null or shape_str = '')
    return 0;
  pos := strrchr (shape_str, 44);
  if (pos is not null)
    dims := cast (subseq (shape_str, pos + 1) as integer);
  else
    dims := cast (shape_str as integer);
  return dims;
}
;

-- Resolve a model name to (runtime_handle, dimensions, model_type).
-- Uses the SQL branch's production ONNX_MODEL_REFRESH for model reloading,
-- which handles all model types including HTTP providers (openai/ollama/
-- lmstudio/openai_compatible). For HTTP providers, handle is 0 but dims
-- are valid from provider_dimensions or output_shape.
-- Returns vector (handle, dims, model_type) or (0, 0, '') if not found.
create function DB.DBA.VEC_INDEX_RESOLVE_MODEL (in model_key varchar) returns any
{
  declare model_id_val, handle_val, dims integer;
  declare shape_str, model_type_val varchar;
  declare provider_dims integer;
  declare refreshed_handle integer;

  whenever not found goto no_model;
  select model_id, handle, output_shape, model_type, provider_dimensions
    into model_id_val, handle_val, shape_str, model_type_val, provider_dims
  from DB.DBA.ONNX_MODELS where model_name = model_key;

  -- Normalize model type for provider dispatch
  model_type_val := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (coalesce (model_type_val, ''));

  -- For HTTP provider models, no local handle is needed
  if (model_type_val in ('openai', 'ollama', 'lmstudio', 'openai_compatible'))
    {
      -- Dimensions come from provider_dimensions or output_shape
      dims := coalesce (provider_dims, DB.DBA.VEC_INDEX_PARSE_DIMS (shape_str));
      if (dims <= 0)
        goto no_model;
      return vector (0, dims, model_type_val);
    }

  -- For test_embedding models, no handle needed
  if (model_type_val in ('test_embedding', 'vvec_test_embedding'))
    {
      dims := DB.DBA.VEC_INDEX_PARSE_DIMS (shape_str);
      if (dims <= 0)
        goto no_model;
      return vector (0, dims, model_type_val);
    }

  -- For local ONNX models, resolve the handle
  dims := DB.DBA.VEC_INDEX_PARSE_DIMS (shape_str);
  if (dims <= 0)
    goto no_model;

  -- If handle is missing or stale, use the production refresh path
  if (handle_val is null or handle_val <= 0)
    {
      refreshed_handle := DB.DBA.ONNX_MODEL_REFRESH (model_key);
      if (refreshed_handle is null or refreshed_handle <= 0)
        goto no_model;
      handle_val := refreshed_handle;
    }

  return vector (handle_val, dims, model_type_val);

no_model:;
  return vector (0, 0, '');
}
;

-- Embed a vector of texts using the model's dispatch path.
-- For HTTP provider models (openai/ollama/lmstudio/openai_compatible), sends
-- the batch as an array `input` in as few requests as the provider's batch
-- limit allows.  This used to loop ONNX_EMBED_TEXT_FOR_MODEL once per text, so
-- the caller assembled a batch and it was immediately unrolled into one HTTPS
-- round-trip per document -- 57,600 requests for the FiQA corpus instead of a
-- few hundred, and the dominant cost of a hosted-model build.
-- For local ONNX models, calls ONNX_EMBED_BATCH with the handle.
-- For test_embedding models, signals an error (test models are not available
-- for ONNX embedding).
-- Returns a vector of embedding vectors, in input order.
create function DB.DBA.VEC_INDEX_EMBED_TEXTS (
  in model_name varchar,
  in model_handle integer,
  in texts any,
  in model_type varchar ) returns any
{
  if (model_type in ('openai', 'ollama', 'lmstudio', 'openai_compatible'))
    return DB.DBA.ONNX_EMBED_BATCH_FOR_MODEL (model_name, texts);

  -- A test_embedding model has no ONNX handle and never will: it stands for a
  -- deterministic vector derived from the text.  VEC_INDEX_REFRESH's own model
  -- check already admits these types, so raising VEC33 here made an index that
  -- could be created impossible to refresh.  The generator is the BIF, not a
  -- reimplementation, so the vectors match the ones the SQL-side insert path
  -- produces for the same text.
  if (model_type in ('test_embedding', 'vvec_test_embedding'))
    {
      declare tv, dims any;
      declare ti, tn integer;
      tn := length (texts);
      dims := DB.DBA.VEC_INDEX_RESOLVE_MODEL (model_name);
      tv := make_array (tn, 'any');
      for (ti := 0; ti < tn; ti := ti + 1)
        aset (tv, ti, __VEC_INDEX_TEST_EMBEDDING (cast (dims[1] as integer), cast (texts[ti] as varchar)));
      return tv;
    }

  -- Local ONNX model — use the batch BIF
  if (model_handle <= 0)
    signal ('VEC33', sprintf ('Model %s has no loaded handle for embedding', model_name));
  return ONNX_EMBED_BATCH (model_handle, texts);
}
;

-- Set the model for a vector index.
create procedure DB.DBA.VEC_INDEX_SET_MODEL (
  in idx_iri varchar,
  in model_name varchar ) returns any
{
  declare dims integer;
  declare resolved any;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.VEC_INDEX_ABORT_CREATE (idx_iri);   -- no-op unless still 'creating'
      resignal;
    };

  if (not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri))
    signal ('VEC06', sprintf ('Vector index <%s> not found for model setup', idx_iri));

  -- Resolve model dimensions from ONNX_MODELS if available
  resolved := DB.DBA.VEC_INDEX_RESOLVE_MODEL (model_name);
  dims := cast (resolved[1] as integer);
  -- If model not found, dims stays 0; dimensions will be validated at END_CREATE

  -- SVI_MODEL_DIMENSIONS records the model's native output dim. SVI_DIMENSIONS
  -- is the stored (possibly reduced) dim; for a non-reduced index they are
  -- equal. SET_OPTIONS may later lower SVI_DIMENSIONS when reduce='truncate'.
  update DB.DBA.SPARQL_VEC_INDEX
  set SVI_MODEL_NAME = model_name,
      SVI_DIMENSIONS = dims,
      SVI_MODEL_DIMENSIONS = dims
  where SVI_IRI = idx_iri;

  commit work;
  return vector (vector ('00000', sprintf ('Model %s set for vector index <%s>', model_name, idx_iri)));
}
;

-- Normalise one free-text catalogue annotation (label, comment).
--
-- These are prose, so there is nothing to validate beyond length: a label may
-- contain anything a person would write.  Blank normalises to NULL, because
-- "set to the empty string" and "never set" describe the same index and the
-- RDF view over the catalogue should emit no triple for either -- an empty
-- literal in a search picker is worse than no literal at all.
create function DB.DBA.VEC_INDEX_META_TEXT (
  in opt_name varchar,
  in val any,
  in max_len integer ) returns varchar
{
  declare s varchar;
  if (val is null)
    return null;
  s := trim (cast (val as varchar));
  if (s = '')
    return null;
  if (length (s) > max_len)
    signal ('VEC26', sprintf ('%s is limited to %d characters (%d given)', opt_name, max_len, length (s)));
  return s;
}
;

-- Set options for a vector index.
-- Options arrive as a flat vector of (name, value) pairs.
create procedure DB.DBA.VEC_INDEX_SET_OPTIONS (
  in idx_iri varchar,
  in options any ) returns any
{
  declare ctr, len integer;
  declare opt_name varchar;
  declare opt_value any;
  declare dist varchar;
  declare hnsw_m, ef_c, dims integer;
  declare maint varchar;
  declare reduce_mode varchar;
  declare rebuild_mode varchar;
  declare build_mode varchar;
  declare src_kind varchar;
  declare idx_label, idx_comment varchar;
  declare model_dims integer;
  declare dimensions_seen integer;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.VEC_INDEX_ABORT_CREATE (idx_iri);   -- no-op unless still 'creating'
      resignal;
    };

  if (not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri))
    signal ('VEC07', sprintf ('Vector index <%s> not found for options setup', idx_iri));

  -- Load current values
  dist := 'cosine';
  hnsw_m := 16;
  ef_c := 200;
  maint := 'manual';
  dims := 0;
  reduce_mode := 'none';
  rebuild_mode := null;
  build_mode := null;
  src_kind := 'text';
  model_dims := 0;
  dimensions_seen := 0;
  idx_label := null;
  idx_comment := null;
  select SVI_DIMENSIONS, SVI_DISTANCE, SVI_HNSW_M, SVI_EF_CONSTRUCTION, SVI_MAINTENANCE,
         SVI_REDUCE, SVI_MODEL_DIMENSIONS, SVI_REBUILD, SVI_SOURCE_KIND, SVI_BUILD,
         SVI_LABEL, SVI_COMMENT
    into dims, dist, hnsw_m, ef_c, maint,
         reduce_mode, model_dims, rebuild_mode, src_kind, build_mode,
         idx_label, idx_comment
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
  if (src_kind is null) src_kind := 'text';

  len := length (options);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    {
      opt_name := cast (options[ctr] as varchar);
      opt_value := options[ctr + 1];

      if ('dimensions' = opt_name)
        {
          dims := cast (opt_value as integer);
          if (dims <= 0)
            signal ('VEC08', 'dimensions must be a positive integer');
          dimensions_seen := 1;
        }
      else if ('distance' = opt_name)
        {
          dist := cast (opt_value as varchar);
          if (dist not in ('cosine', 'l1', 'l2'))
            signal ('VEC09', sprintf ('Unsupported distance metric: %s', dist));
        }
      else if ('hnsw_m' = opt_name)
        {
          hnsw_m := cast (opt_value as integer);
          if (hnsw_m <= 0)
            signal ('VEC10', 'hnsw_m must be a positive integer');
        }
      else if ('ef_construction' = opt_name)
        {
          ef_c := cast (opt_value as integer);
          if (ef_c <= 0)
            signal ('VEC11', 'ef_construction must be a positive integer');
        }
      else if ('maintenance' = opt_name)
        {
          maint := cast (opt_value as varchar);
          if (maint not in ('manual', 'async'))
            signal ('VEC12', sprintf ('Unsupported maintenance mode: %s', maint));
        }
      else if ('reduce' = opt_name)
        {
          reduce_mode := cast (opt_value as varchar);
          if (reduce_mode not in ('none', 'truncate'))
            signal ('VEC72', sprintf ('Unsupported reduce mode: %s (expected none or truncate)', reduce_mode));
        }
      else if ('build' = opt_name or 'build_method' = opt_name)
        {
          -- How the initial backfill constructs the graph.  Distinct from
          -- 'rebuild', which only names the method a LATER __VEC_INDEX_REBUILD
          -- uses and has never affected the build -- conflating the two is the
          -- confusion this option exists to end.
          build_mode := lower (cast (opt_value as varchar));
          if (build_mode not in ('incremental', 'bulk', 'auto'))
            signal ('VEC81', sprintf ('Unsupported build method: %s (expected incremental, bulk or auto)', build_mode));
        }
      else if ('rebuild' = opt_name or 'rebuild_method' = opt_name)
        {
          rebuild_mode := lower (cast (opt_value as varchar));
          if (rebuild_mode not in ('replay', 'fast', 'auto'))
            signal ('VEC81', sprintf ('Unsupported rebuild method: %s (expected replay, fast or auto)', rebuild_mode));
        }
      else if ('source_kind' = opt_name)
        {
          src_kind := lower (cast (opt_value as varchar));
          if (src_kind not in ('text', 'vector'))
            signal ('VEC85', sprintf ('Unsupported source_kind: %s (expected text or vector)', src_kind));
        }
      else if ('label' = opt_name)
        {
          -- rdfs:label of the index: a short name a person reads in a picker.
          idx_label := DB.DBA.VEC_INDEX_META_TEXT ('label', opt_value, 255);
        }
      else if ('comment' = opt_name)
        {
          -- rdfs:comment: what the index is for, in a sentence or two.
          idx_comment := DB.DBA.VEC_INDEX_META_TEXT ('comment', opt_value, 2000);
        }
      else
        signal ('VEC13', sprintf ('Unknown vector index option: %s', opt_name));
    }

  -- Reduce-mode validation mirrors the native SQL layer (vvec.c VEC13/VEC19).
  if (reduce_mode = 'truncate')
    {
      -- require dimensions to be provided explicitly (mirror SQL VEC13)
      if (not dimensions_seen)
        signal ('VEC73', 'reduce = truncate requires WITH (dimensions = <n>)');
      -- if the model native dim is known, require 0 < dimensions < native
      if (model_dims > 0)
        {
          if (dims >= model_dims)
            signal ('VEC74', sprintf (
              'reduce = truncate requires dimensions (%d) to be less than the model native output dimension (%d)',
              dims, model_dims));
        }
      -- else: native dim unknown yet (model not resolvable); the native layer
      -- (vvec.c VEC19) will enforce the bound at END_CREATE time.
    }
  else
    {
      -- reduce = 'none': stored dim must equal the model native dim when the
      -- latter is known. If the user did not pass dimensions, dims already
      -- holds the model dim from SET_MODEL, which is correct.
      if (model_dims > 0 and dims <> model_dims)
        signal ('VEC75', sprintf (
          'dimensions (%d) must equal the model native output dimension (%d) when reduce is not truncate',
          dims, model_dims));
    }

  if (dims <= 0)
    signal ('VEC14', 'dimensions is required');
  if (maint = 'async')
    {
      declare sel_type varchar;
      declare trig_count integer;
      select SVI_SELECTOR_TYPE into sel_type
        from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
      if (sel_type = 'shorthand')
        {
          -- Shorthand async: always allowed (graph+predicate are fixed by DDL).
          goto maint_ok;
        }
      if (sel_type = 'general')
        {
          -- General async: allowed only if the WHERE pattern was async-scopable,
          -- i.e. at least one (graph, predicate) trigger row was extracted at
          -- parse time.  Otherwise the change-matching loop has nothing to
          -- match against and incremental maintenance would silently never fire.
          trig_count := (select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER
                          where SVT_INDEX_IRI = idx_iri);
          if (trig_count = 0)
            signal ('VEC77',
              'maintenance = async for a general (KEY/EMBEDDING/WHERE) vector index requires every indexed triple pattern to be scoped to a named graph -- either inside an explicit GRAPH <iri>, or by a FROM <iri> clause on the selector; use maintenance = ''manual'' with periodic REFRESH VECTOR INDEX for patterns that span a variable graph');
        }
    }
maint_ok:;

  update DB.DBA.SPARQL_VEC_INDEX
  set SVI_DIMENSIONS = dims,
      SVI_REDUCE = reduce_mode,
      SVI_DISTANCE = dist,
      SVI_HNSW_M = hnsw_m,
      SVI_EF_CONSTRUCTION = ef_c,
      SVI_MAINTENANCE = maint,
      SVI_REBUILD = rebuild_mode,
      SVI_BUILD = build_mode,
      SVI_SOURCE_KIND = src_kind,
      SVI_LABEL = idx_label,
      SVI_COMMENT = idx_comment
  where SVI_IRI = idx_iri;

  DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;
  return vector (vector ('00000', sprintf ('Options set for vector index <%s>', idx_iri)));
}
;

-- Retitle an existing vector index: rdfs:label and rdfs:comment, after create.
--
-- Callable from SPARQL as sql:VEC_INDEX_SET_METADATA(<iri>, "label", "comment").
--
-- NULL for either argument means "leave that one as it is", so a caller can
-- change the comment without restating the label.  The empty string means
-- "clear it" -- that is the only way to get a value back to unset, and it is
-- why blank is not simply treated as null here.
--
-- TWO gates, answering two different questions:
--
--   * `grant execute` on this procedure -- may this account annotate indexes
--     at all?  That is the outer gate, and a fresh install grants it to nobody:
--     only DBA accounts can annotate until a deployer opens it.
--   * the owner check below -- which indexes?  The procedure runs with
--     definer's rights, so without it a single EXECUTE grant would let that
--     account retitle every index on the instance.  A label is an integrity
--     surface: the console shows it in the search picker, where people choose
--     what to query, so "Public FAQ articles" on an index built over HR records
--     sends the next operator at the wrong data.  Write access to the
--     description should not be broader than the thing being described.
--
-- SVI_OWNER is a varchar holding a numeric user id -- get_user_id (1) returns
-- one as a string too, and every index created before this mattered holds '0'
-- (dba).  Both sides are compared as varchar on purpose: casting one of them to
-- integer is how this check ends up matching nobody and refusing the owner.
create procedure DB.DBA.VEC_INDEX_SET_METADATA (
  in idx_iri varchar,
  in idx_label any := null,
  in idx_comment any := null ) returns varchar
{
  declare owner_id varchar;
  declare lbl, cmt varchar;

  whenever not found goto no_index;
  select coalesce (cast (SVI_OWNER as varchar), '') into owner_id
    from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  if (not user_is_dba (user) and owner_id <> cast (get_user_id (1) as varchar))
    signal ('VEC28', sprintf (
      'Not the owner of vector index <%s>: only its owner or a DBA account may change its label or comment',
      idx_iri));

  if (idx_label is not null)
    {
      lbl := DB.DBA.VEC_INDEX_META_TEXT ('label', idx_label, 255);
      update DB.DBA.SPARQL_VEC_INDEX set SVI_LABEL = lbl where SVI_IRI = idx_iri;
    }
  if (idx_comment is not null)
    {
      cmt := DB.DBA.VEC_INDEX_META_TEXT ('comment', idx_comment, 2000);
      update DB.DBA.SPARQL_VEC_INDEX set SVI_COMMENT = cmt where SVI_IRI = idx_iri;
    }
  commit work;
  return idx_iri;

no_index:;
  signal ('VEC27', sprintf ('Vector index <%s> not found', idx_iri));
}
;

-- End creating a vector index. Creates the backing table and native vector index.
create procedure DB.DBA.VEC_INDEX_END_CREATE (in idx_iri varchar) returns any
{
  declare internal_name, source_table, model_name varchar;
  declare dims, hnsw_m, ef_c integer;
  declare dist, maint, sel_type, reduce_mode, rebuild_mode varchar;
  declare rebuild_opt varchar;
  declare STATE, MESSAGE varchar;
  declare ddl_text varchar;
  declare md, rs any;

  declare exit handler for sqlstate '*'
    {
      DB.DBA.VEC_INDEX_ABORT_CREATE (idx_iri);   -- no-op unless still 'creating'
      resignal;
    };

  STATE := '00000';

  -- Load catalog record
  whenever not found goto not_found;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE, SVI_MODEL_NAME,
         SVI_DIMENSIONS, SVI_DISTANCE, SVI_HNSW_M, SVI_EF_CONSTRUCTION,
         SVI_MAINTENANCE, SVI_SELECTOR_TYPE, SVI_REDUCE, SVI_REBUILD
    into internal_name, source_table, model_name,
         dims, dist, hnsw_m, ef_c,
         maint, sel_type, reduce_mode, rebuild_mode
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  -- Validate required fields
  if (model_name is null or model_name = '')
    signal ('VEC20', sprintf ('Vector index <%s> has no model set', idx_iri));
  if (dims <= 0)
    signal ('VEC21', sprintf ('Vector index <%s> has no dimensions set', idx_iri));
  if (sel_type is null or sel_type = 'pending')
    signal ('VEC22', sprintf ('Vector index <%s> has no selector set', idx_iri));
  if (reduce_mode is null or reduce_mode = '')
    reduce_mode := 'none';

  -- Create the backing source table
  ddl_text := sprintf (
    'create table %s (RV_ID bigint primary key, RV_TEXT varchar, RV_RO_ID bigint, RV_VECTOR any, RV_TEXT_HASH varbinary, RV_UPDATED datetime)',
    source_table );
  STATE := '00000';
  exec (ddl_text, STATE, MESSAGE, vector (), 10000, md, rs);
  if (STATE <> '00000' and STATE <> 0 and STATE <> '42S01')
    signal ('VEC23', sprintf ('Failed to create backing table for vector index <%s>: %s %s', idx_iri, STATE, MESSAGE));

  -- Optional per-index rebuild-method default, forwarded to the native layer
  -- (vvec.c), which validates it and stores it in the index key options.
  rebuild_opt := '';
  if (rebuild_mode is not null and rebuild_mode <> '')
    rebuild_opt := sprintf (', rebuild = ''%s''', rebuild_mode);

  -- Create the native vector index on the source text column.
  -- For reduce='truncate', forward the option to the native layer (vvec.c),
  -- which re-resolves the model native dim and performs the truncate +
  -- L2-renormalize reduction on insert and query. dimensions here is the
  -- reduced (stored) value; the native layer validates it against the model.
  if (reduce_mode = 'truncate')
    ddl_text := sprintf (
      'create vector index %s on %s (RV_TEXT) using ''%s'' with (dimensions = %d, distance_metric = ''%s'', hnsw_m = %d, ef_construction = %d, reduce = ''truncate''%s)',
      internal_name, source_table, model_name, dims, dist, hnsw_m, ef_c, rebuild_opt);
  else
    ddl_text := sprintf (
      'create vector index %s on %s (RV_TEXT) using ''%s'' with (dimensions = %d, distance_metric = ''%s'', hnsw_m = %d, ef_construction = %d%s)',
      internal_name, source_table, model_name, dims, dist, hnsw_m, ef_c, rebuild_opt);
  STATE := '00000';
  exec (ddl_text, STATE, MESSAGE, vector (), 10000, md, rs);
  if (STATE <> '00000' and STATE <> 0 and STATE <> '42S11')
    signal ('VEC24', sprintf ('Failed to create native vector index for <%s>: %s %s', idx_iri, STATE, MESSAGE));

  -- Mark as active
  update DB.DBA.SPARQL_VEC_INDEX
  set SVI_STATE = 'active'
  where SVI_IRI = idx_iri;

  DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;

  -- Make sure the RDF view that publishes this index's label and comment in
  -- <urn:vvec:indexes> exists.  It is installed at server start, but the very
  -- first start of a brand-new database is too early -- see
  -- VEC_INDEX_META_VIEW_INIT -- and this is both the next moment it can be done
  -- and the first moment it is worth doing: an instance with no vector index
  -- has nothing for the view to describe.  A no-op (one registry read) once it
  -- is in.  Guarded and ignored: the index above is created and committed, and
  -- a missing view is not a reason to fail a CREATE.
  {
    declare exit handler for sqlstate '*' { ; };
    DB.DBA.VEC_INDEX_META_VIEW_INIT ();
  }
  return vector (vector ('00000', sprintf ('Vector index <%s> created successfully', idx_iri)));

not_found:;
  signal ('VEC25', sprintf ('Vector index <%s> not found', idx_iri));
}
;

-- Helper: upsert a row into the dynamically-named source table.
create procedure DB.DBA.VEC_INDEX_UPSERT_ROW (
  in source_table varchar,
  in kid bigint,
  in txt varchar,
  in txt_hash varchar )
{
  declare stmt_state, stmt_msg varchar;
  declare ddl_text varchar;
  declare md, rs any;

  -- Keep RV_TEXT null; embeddings are maintained explicitly via __VEC_INDEX_INSERT_BATCH.
  -- The key is BOUND, not interpolated: exec () compiles from scratch on every call
  -- unless it is given a cacheable statement, so interpolating the key produced one
  -- distinct SQL text -- and one full SQL compile -- per row (57,600 of them on a FiQA
  -- rebuild).  With the key as a parameter the text is constant per source table, and
  -- 'use_cache' lets exec () reuse the compiled plan.
  ddl_text := sprintf (
    'insert into %s (RV_ID, RV_TEXT_HASH, RV_UPDATED) values (?, ?, now ())',
    source_table );
  stmt_state := '00000';
  exec (ddl_text, stmt_state, stmt_msg, vector (kid, txt_hash),
        vector ('max_rows', 0, 'use_cache', 1), md, rs);
  if (stmt_state = '23000')
    {
      -- Duplicate key, do update instead
      ddl_text := sprintf (
        'update %s set RV_TEXT_HASH = ?, RV_UPDATED = now () where RV_ID = ?',
        source_table );
      exec (ddl_text, stmt_state, stmt_msg, vector (txt_hash, kid),
            vector ('max_rows', 0, 'use_cache', 1), md, rs);
    }
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (stmt_state))
    signal ('VEC38', sprintf ('Upsert into %s failed: %s %s', source_table, stmt_state, stmt_msg));
}
;

-- Helper: check if a row's text hash matches (returns 1 if update needed, 0 if unchanged).
create function DB.DBA.VEC_INDEX_CHECK_HASH (
  in source_table varchar,
  in kid bigint,
  in txt_hash varchar ) returns integer
{
  declare existing_hash varchar;
  declare stmt_state, stmt_msg varchar;
  declare qr any;
  declare qm any;
  declare qtext varchar;

  -- The key is BOUND, not interpolated.  This runs once per selected row during a
  -- backfill, and exec () recompiles unless handed a cacheable statement, so an
  -- interpolated key meant a full SQL compile per row -- the dominant cost of a large
  -- rebuild.  A constant text plus 'use_cache' compiles it once per source table.
  qtext := sprintf ('select RV_TEXT_HASH from %s where RV_ID = ?', source_table);
  exec (qtext, stmt_state, stmt_msg, vector (kid),
        vector ('max_rows', 0, 'use_cache', 1), qm, qr);
  if ((DB.DBA.VEC_INDEX_EXEC_FAILED (stmt_state)) or length (qr) = 0)
    return 1; -- row doesn't exist, needs insert
  existing_hash := cast (qr[0][0] as varchar);
  if (existing_hash = txt_hash)
    return 0; -- unchanged
  return 1; -- changed
}
;

-- Helper: get all key IDs from the backing source table.
-- Returns a vector of bigint values.
create function DB.DBA.VEC_INDEX_GET_ALL_KEYS (in source_table varchar) returns any
{
  declare stmt_state, stmt_msg varchar;
  declare qr any;
  declare qm any;
  declare qtext varchar;
  declare result any;
  declare ctr, nrows integer;

  qtext := sprintf ('select RV_ID from %s', source_table);
  exec (qtext, stmt_state, stmt_msg, vector (), 1000000, qm, qr);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (stmt_state))
    return vector ();
  nrows := length (qr);
  result := make_array (nrows, 'any');
  for (ctr := 0; ctr < nrows; ctr := ctr + 1)
    aset (result, ctr, cast (qr[ctr][0] as bigint));
  return result;
}
;

-- Helper: delete a row from the backing source table.
create procedure DB.DBA.VEC_INDEX_DELETE_ROW (
  in source_table varchar,
  in kid bigint )
{
  declare stmt_state, stmt_msg varchar;
  declare ddl_text varchar;
  declare md, rs any;

  -- The key is BOUND, not interpolated.  sprintf's %d renders a bigint through a
  -- 32-bit conversion -- iri_id_num () of a blank node is ~4.6e18 and comes out as
  -- "10000" -- so an interpolated delete matched no row.  That is not merely a lost
  -- delete: VEC_INDEX_BACKFILL_PAGED's stale-key loop reselects whatever it failed to
  -- delete, so a single unrenderable key made the refresh spin forever at 100% CPU.
  -- Binding also makes the text constant per source table, so 'use_cache' can reuse
  -- the plan instead of compiling once per stale row.
  ddl_text := sprintf ('delete from %s where RV_ID = ?', source_table);
  stmt_state := '00000';
  exec (ddl_text, stmt_state, stmt_msg, vector (kid),
        vector ('max_rows', 0, 'use_cache', 1), md, rs);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (stmt_state))
    signal ('VEC40', sprintf ('Delete from %s failed: %s %s', source_table, stmt_state, stmt_msg));
}
;

-- Helper: defensively deduplicate a vector of (kid, text) pairs by kid.
-- Keeps the first occurrence of each kid so that a residual duplicate can
-- never feed a duplicate PK into a single transaction.
create function DB.DBA.VEC_INDEX_DEDUP_BATCH (
  in ids any,
  in texts any ) returns any
{
  declare result_ids any;
  declare result_texts any;
  declare seen any;
  declare i, n integer;
  declare kid_key varchar;

  n := length (ids);
  seen := dict_new (n + 1);
  result_ids := make_array (0, 'any');
  result_texts := make_array (0, 'any');
  for (i := 0; i < n; i := i + 1)
    {
      kid_key := cast (ids[i] as varchar);
      if (dict_get (seen, kid_key, 0) = 0)
        {
          dict_put (seen, kid_key, 1);
          result_ids := vector_concat (result_ids, vector (ids[i]));
          result_texts := vector_concat (result_texts, vector (texts[i]));
        }
    }
  return vector (result_ids, result_texts);
}
;

-- Helper: drop a table, swallowing "does not exist".  Runs in its own handler scope so a
-- missing table cannot poison the caller's error state (a failing exec() under an active
-- exit handler otherwise leaves the caller's state variable set and skips later statements).
create procedure DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (in tb varchar)
{
  declare st, msg varchar;
  declare continue handler for sqlstate '*' { return; };
  exec (sprintf ('drop table %s', tb), st, msg);
}
;

-- Helper: commit the work done so far by a backfill.
-- A backfill is a bulk maintenance operation whose transaction would otherwise grow
-- without bound; past TransactionAfterImageLimit the server aborts the refresh (SR325).
-- Kept in its own proc so the commit runs in its own handler scope: a failing
-- exec (..., st, msg) under the caller's active exit handler otherwise poisons the
-- caller's state variable and skips the statement after it.
-- Did an exec () fail?
--
-- exec () reports success as either the string '00000' or the integer 0, which
-- is why the old test compared against both.  Comparing a varchar state against
-- the integer 0 makes the compiler warn (QW004, sqlexp.c:924) and let an aborted
-- statement slip straight through: a 40001 on the enumeration was reported as
-- "0 rows enumerated" rather than raised.  Compare as text instead.
create function DB.DBA.VEC_INDEX_EXEC_FAILED (in st any) returns integer
{
  declare s varchar;
  if (st is null)
    return 0;
  s := cast (st as varchar);
  if (s = '00000' or s = '0' or s = '')
    return 0;
  return 1;
}
;

-- One log line per backfill phase, with its own elapsed time.  Without these a
-- refresh that dies in, or silently produces nothing from, one step looks the
-- same in the log as one that simply had no work to do.
create function DB.DBA.VEC_INDEX_PHASE (in internal_name varchar, in phase varchar, in t0 integer) returns integer
{
  declare t integer;
  t := msec_time ();
  log_message (sprintf ('vector index %s: phase %s took %d ms', internal_name, phase, t - t0));
  return t;
}
;

-- Put this connection in log mode MODE exactly: bit 1 logs, bit 2 is row
-- autocommit.  cli_log_mode () reads back MODE afterwards.
--
-- log_enable () alone cannot promise that: asked to turn logging off while it
-- is already off it returns early, having set row autocommit but without
-- recording the new mode in cli_log_mode (bif_log_enable, sqlbif.c).  Anything
-- reading cli_log_mode () later then sees the previous mode.  Passing through
-- logging-on first makes the second call take the full path.  No statement
-- runs between the two, so nothing is logged in the window.
create procedure DB.DBA.VEC_INDEX_SET_LOG_MODE (in mode integer)
{
  log_enable (bit_or (mode, 1), 1);
  log_enable (mode, 1);
}
;

create procedure DB.DBA.VEC_INDEX_BACKFILL_COMMIT (in internal_name varchar, in log_mode integer := null)
{
  declare st, msg varchar;
  st := '00000';
  exec ('commit work', st, msg);
  -- An ordinary commit restarts the transaction with lt_replicate taken from
  -- cli_replicate unless row autocommit is on (lt_restart, lock.c) -- so a
  -- caller who ran log_enable (0) gets logging back after every commit here,
  -- and log_vec_page () then emits a page image per DPF_VEC page until
  -- TransactionAfterImageLimit aborts the build.  Put the backfill's own mode
  -- back.  LOG_MODE is passed in rather than read from cli_log_mode (): the
  -- backfill runs in a mode of its own, and see VEC_INDEX_SET_LOG_MODE for
  -- why cli_log_mode () is not a reliable record of it.
  DB.DBA.VEC_INDEX_SET_LOG_MODE (coalesce (log_mode, cli_log_mode ()));
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC36', sprintf ('Could not commit backfill progress for <%s>: %s %s', internal_name, st, msg));
}
;

-- How many embedding batches a backfill runs at once.
--
-- Embedding is the CPU floor of a build and a single caller pins exactly one
-- core: a serial ONNX caller holds one out-of-process helper at a time, so
-- aggregate helper CPU sits at 100% no matter how many cores or helpers exist.
-- Concurrency here is the only thing that lifts that, which is why this and
-- the ONNX helper pool size are raised together in VEC_INDEX_BACKFILL_PAGED --
-- either one alone does nothing.
--
-- Default 4: a real speed-up while leaving most of a small machine to the rest
-- of the server, since a refresh is background maintenance and not the only
-- thing running.  Override with registry_set ('__vec_embed_concurrency', 'N').
-- 1 selects the serial path, which is also the fallback when async_queue is
-- unavailable.
--
-- The ceiling is 32, which is what ONNX_CONFIG ('helper_pool_size') accepts
-- (onnx_plugin.c:3186); one helper per worker is the point, so a higher value
-- here could not be served anyway.  Going above ~16 also needs the server-wide
-- async pool raised -- aq_max_threads defaults to 20 (aqueue.c:36) and is
-- shared with everything else, so 20 embed workers would leave nothing for the
-- rest of the server.  It is a dbf var and not protected, so
--   select __dbf_set ('aq_max_threads', 32);
-- lifts it at runtime.  Leave a few cores for the coordinator and the buffer
-- flusher: on a 24-core box, 20 is a better setting than 24.
-- Resolve the text to embed for one RDF_OBJ id.
--
-- Delegates to the engine's own resolution path rather than reading RDF_OBJ
-- here: rdf_box_from_ro_id () builds an incomplete rdf_box carrying the id, and
-- __ro2sq () calls rb_complete () on it (rdfbox.c).  That is where the RO_LONG
-- blob, the packed-XML case and the RO_VAL-holds-a-checksum-not-the-value case
-- are already handled -- with the checksum actually verified (SR579).  Hand
-- transcribing that logic here got both the blob and the checksum branch wrong.
--
-- The second argument to __ro2sq matters: without it a literal whose type or
-- language is non-default comes back as the BOX, not the string, and every
-- DBpedia rdfs:comment is @en.  Passing 1 forces the plain value.
--
-- NULL means the row disappeared after enumeration. Callers remove any old
-- embedding/source row for that key; SR579 and all other completion failures
-- remain hard errors.
create function DB.DBA.VEC_INDEX_RO_TEXT (in p_ro_id bigint) returns varchar
{
  declare v any;

  if (p_ro_id is null or p_ro_id <= 0)
    return null;

  -- Only a row which disappeared after selector enumeration is a permissible
  -- skip.  In particular, do not hide SR579 checksum failures: silently
  -- omitting a corrupt literal would turn data corruption into an apparently
  -- successful index refresh.
  declare exit handler for sqlstate '*'
    {
      if (strstr (__SQL_MESSAGE, 'SR580') is not null)
        return null;
      resignal;
    };

  v := __ro2sq (rdf_box_from_ro_id (p_ro_id), 1);
  if (v is null)
    return null;
  if (isentity (v))
    return cast (serialize_to_UTF8_xml (v) as varchar);
  return cast (v as varchar);
}
;

-- Add RV_RO_ID to a backing table created before this column existed.
--
-- RV_RO_ID does not replace RV_TEXT: the native index is declared
-- `on VECSRC_<hex> (RV_TEXT)`, so dropping that column would invalidate the
-- index this table exists to host.  RV_TEXT stays exactly as it is -- declared,
-- never written -- and goes when the index itself moves to RDF_OBJ.
create procedure DB.DBA.VEC_INDEX_ENSURE_RO_ID (in source_table varchar)
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  exec (sprintf ('alter table %s add RV_RO_ID bigint if not exists', source_table),
        st, msg, vector (), 0, md, rs);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC38', sprintf ('Could not add RV_RO_ID to %s: %s %s', source_table, st, msg));
}
;

-- Backfill's upsert into the backing table.
--
-- Separate from VEC_INDEX_UPSERT_ROW rather than a signature change to it: that
-- one is on the async incremental path, which still works in text, and a release
-- patch should not destabilise both paths at once. A key first created by the
-- async path leaves RV_RO_ID null, which the set-based changed-row join reads
-- as "re-embed once", so the two converge on their own.
create procedure DB.DBA.VEC_INDEX_UPSERT_ROW_RO (
  in source_table varchar,
  in kid bigint,
  in ro_id bigint,
  in txt_hash any )
{
  declare stmt_state, stmt_msg varchar;
  declare ddl_text varchar;
  declare md, rs any;

  ddl_text := sprintf (
    'insert into %s (RV_ID, RV_RO_ID, RV_TEXT_HASH, RV_UPDATED) values (?, ?, ?, now ())',
    source_table );
  stmt_state := '00000';
  exec (ddl_text, stmt_state, stmt_msg, vector (kid, ro_id, txt_hash),
        vector ('max_rows', 0, 'use_cache', 1), md, rs);
  if (stmt_state = '23000')
    {
      ddl_text := sprintf (
        'update %s set RV_RO_ID = ?, RV_TEXT_HASH = ?, RV_UPDATED = now () where RV_ID = ?',
        source_table );
      exec (ddl_text, stmt_state, stmt_msg, vector (ro_id, txt_hash, kid),
            vector ('max_rows', 0, 'use_cache', 1), md, rs);
    }
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (stmt_state))
    signal ('VEC38', sprintf ('Upsert into %s failed: %s %s', source_table, stmt_state, stmt_msg));
}
;

create procedure DB.DBA.VEC_INDEX_EMBED_CONCURRENCY () returns integer
{
  declare v any;
  declare s varchar;
  declare n integer;
  n := 4;
  v := registry_get ('__vec_embed_concurrency');
  -- An unset key reads back as the integer 0; a key cleared with
  -- registry_set (key, '') reads back as a blank STRING.  Neither means
  -- "serial" -- both mean "use the default" -- and cast ('' as integer)
  -- quietly returns 0 rather than raising, so a blank has to be rejected
  -- before parsing.  Clamping afterwards is not enough: it turned a cleared
  -- setting into concurrency 1, silently reverting to the old serial
  -- behaviour, which is the one value an operator clearing the key cannot
  -- have meant.
  if (isstring (v))
    {
      s := trim (cast (v as varchar));
      if (length (s))
        {
          declare exit handler for sqlstate '*' { n := 4; goto done; };
          n := cast (s as integer);
          if (n < 1)
            n := 4;               -- unparseable or nonsensical: use the default
        }
    }
 done:
  if (n is null or n < 1)
    n := 4;
  if (n > 32)
    n := 32;
  return n;
}
;

-- Texts per model invocation.  The out-of-process helper accepts up to its
-- model's max_texts (4096 by default) and orders a request by token count, so
-- a larger batch lets texts of similar length run together; keep 32 as the
-- compatibility default and allow operators to tune larger batches with
-- registry_set ('__vec_embed_batch_size', 'N').  A model loaded with a smaller
-- max_texts refuses batches over it.
create procedure DB.DBA.VEC_INDEX_EMBED_BATCH_SIZE () returns integer
{
  declare v any;
  declare s varchar;
  declare n integer;
  n := 32;
  v := registry_get ('__vec_embed_batch_size');
  if (isstring (v))
    {
      s := trim (cast (v as varchar));
      if (length (s))
        {
          declare exit handler for sqlstate '*' { n := 32; goto done; };
          n := cast (s as integer);
        }
    }
 done:
  if (n is null or n < 1)
    n := 32;
  if (n > 4096)
    n := 4096;
  return n;
}
;

-- Whether the current transaction has written half the log it may write.
--
-- TransactionAfterImageLimit (50 MB unless configured) aborts a transaction
-- whose log grows past it with 40005/SR325.  The refresh writes embedding
-- batches of up to 4,096 rows, several at a time, and a 16,384-row wave of
-- 384-dimension vectors was over the limit.  What a row costs depends on the
-- dimensions, the graph's degree and how many neighbour pages an insert
-- touches, so no row count bounds it; the log's own size does.  The writers
-- below work in slices of VEC_INDEX_LOG_SLICE () rows and commit when this
-- says so.
--
-- ROOM is __trx_disk_log_length (1) -- what is left under the limit, less a
-- 10,000-byte margin -- as it was when the transaction began; half of it is
-- kept for the slice that crosses the line.  Unlogged, the log does not grow,
-- and with no limit configured ROOM is 2,000,000,000: either way the commits
-- stay as they were.
create procedure DB.DBA.VEC_INDEX_LOG_HALF_USED (in room integer) returns integer
{
  if (__trx_disk_log_length (1) < room / 2)
    return 1;
  return 0;
}
;

-- Rows per write when a batch is written in slices; see VEC_INDEX_LOG_HALF_USED.
create procedure DB.DBA.VEC_INDEX_LOG_SLICE () returns integer
{
  return 256;
}
;

-- Embed one batch on an async_queue worker.
--
-- It must not touch the HNSW graph: aq_wait signals an error if the waiting
-- thread holds database locks. Bulk mode may update only the transactional
-- embeddings table; incremental mode returns vectors for the coordinator to
-- link after all workers in the wave have completed.
--
-- Each worker has its own transaction and must commit it itself.
-- Mark the keys a worker could not resolve, so DRAIN's upsert skips them.
--
-- Called immediately before the worker commits, never before the embed call: a
-- row lock taken here is held to commit, and the embed call is a multi-second
-- out-of-process round trip.  Marking inside the resolution loop held that lock
-- across the whole round trip, and the coordinator's DRAIN scans this same
-- table -- at concurrency 16 that reliably killed DRAIN with 40001/SR337.
create procedure DB.DBA.VEC_INDEX_MARK_SKIPPED (
  in work_tb varchar,
  in missing_ids any,
  in n_missing integer )
{
  declare i integer;
  declare st, msg varchar;
  declare stmt varchar;
  declare md, rs any;

  if (n_missing <= 0)
    return;
  stmt := sprintf ('update %s set BF_DONE = -1 where BF_KID = ?', work_tb);
  for (i := 0; i < n_missing; i := i + 1)
    {
      st := '00000';
      exec (stmt, st, msg, vector (cast (missing_ids[i] as bigint)),
            vector ('max_rows', 0, 'use_cache', 1), md, rs);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal ('VEC36', sprintf ('Could not mark skipped key %s: %s %s',
                                  cast (missing_ids[i] as varchar), st, msg));
    }
}
;

create procedure DB.DBA.VEC_INDEX_EMBED_WORKER (
  in work_tb varchar,
  in internal_name varchar,
  in model_name varchar,
  in model_handle integer,
  in model_type varchar,
  in ids any,
  in ro_ids any,
  in fallback_texts any,
  in bulk integer := 0 )
{
  declare embeds, texts, use_ids, missing_ids any;
  declare i, n, m, n_missing integer;
  declare st, msg varchar;
  declare txt varchar;

  n := length (ids);
  if (n = 0)
    return vector (0, null, null, vector ());
  declare exit handler for sqlstate '*'
    {
      declare rst, rmsg varchar;
      rst := '00000';
      exec ('rollback work', rst, rmsg);   -- never leave a worker's transaction open
      resignal;
    };

  -- Resolve the text HERE, from RDF_OBJ, rather than carrying a copy of the
  -- corpus through the staging table.  Each worker reads only its own slice, so
  -- this fans out with the embedding it feeds.
  texts := make_array (n, 'any');
  use_ids := make_array (n, 'any');
  missing_ids := make_array (n, 'any');
  m := 0;
  n_missing := 0;
  for (i := 0; i < n; i := i + 1)
    {
      if (cast (ro_ids[i] as bigint) > 0)
        txt := DB.DBA.VEC_INDEX_RO_TEXT (cast (ro_ids[i] as bigint));
      else
        txt := cast (fallback_texts[i] as varchar);
      if (txt is null or length (txt) = 0)
        {
          -- Collect only; the scratch-table write happens just before commit.
          aset (missing_ids, n_missing, cast (ids[i] as bigint));
          n_missing := n_missing + 1;
        }
      else
        {
          aset (texts, m, txt);
          aset (use_ids, m, cast (ids[i] as bigint));
          m := m + 1;
        }
    }
  if (m = 0)
    {
      DB.DBA.VEC_INDEX_MARK_SKIPPED (work_tb, missing_ids, n_missing);
      st := '00000';
      exec ('commit work', st, msg);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal ('VEC36', sprintf ('Embed worker could not commit: %s %s', st, msg));
      return vector (0, null, null, subseq (missing_ids, 0, n_missing));
    }
  texts := subseq (texts, 0, m);
  use_ids := subseq (use_ids, 0, m);

  embeds := DB.DBA.VEC_INDEX_EMBED_TEXTS (model_name, model_handle, texts, model_type);
  if (embeds is null or length (embeds) <> m)
    signal ('VEC36', sprintf ('Embedding returned %d vectors for %d texts',
                              case when embeds is null then -1 else length (embeds) end, m));
  -- Bulk workers can write the transactional embeddings table concurrently:
  -- this BIF deliberately does not acquire or mutate the HNSW graph.  In
  -- incremental mode the caller remains the sole graph writer, so return the
  -- bounded batch through aq_wait instead.
  --
  -- In slices, committing as the log fills (VEC_INDEX_LOG_HALF_USED): the
  -- batch is this worker's one transaction, and 4,096 vectors of 3,072 floats
  -- are over the default TransactionAfterImageLimit by themselves.  A slice
  -- committed before a later step fails is staged but not published -- its
  -- keys get no bookkeeping row -- so the next refresh embeds them again, and
  -- staging an embedding that is already there replaces it.
  if (bulk)
    {
      declare j, k, slice, room integer;
      slice := DB.DBA.VEC_INDEX_LOG_SLICE ();
      room := __trx_disk_log_length (1);
      j := 0;
      while (j < m)
        {
          k := j + slice;
          if (k > m)
            k := m;
          if (j = 0 and k = m)
            __VEC_INDEX_STAGE_BATCH (internal_name, use_ids, embeds);
          else
            __VEC_INDEX_STAGE_BATCH (internal_name, subseq (use_ids, j, k), subseq (embeds, j, k));
          j := k;
          if (j < m and DB.DBA.VEC_INDEX_LOG_HALF_USED (room))
            {
              st := '00000';
              exec ('commit work', st, msg);
              if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
                signal ('VEC36', sprintf ('Embed worker could not commit: %s %s', st, msg));
              room := __trx_disk_log_length (1);
            }
        }
    }

  DB.DBA.VEC_INDEX_MARK_SKIPPED (work_tb, missing_ids, n_missing);
  st := '00000';
  exec ('commit work', st, msg);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC36', sprintf ('Embed worker could not commit: %s %s', st, msg));
  if (bulk)
    return vector (m, null, null, subseq (missing_ids, 0, n_missing));
  return vector (m, use_ids, embeds, subseq (missing_ids, 0, n_missing));
}
;

-- Queue one embed batch, retrying while the server-wide aq pool is exhausted:
-- a separate-txn aq signals CLAQN instead of queueing when aq_max_threads are all busy.
create procedure DB.DBA.VEC_INDEX_EMBED_SUBMIT (
  in aq any,
  in internal_name varchar,
  in args any ) returns integer
{
  declare req, claqn, tries integer;

  tries := 0;
  while (1)
    {
      claqn := 0;
      {
        declare exit handler for sqlstate '42000'
          {
            if (strstr (__SQL_MESSAGE, 'CLAQN') is null)
              resignal;
            claqn := 1;
          };
        req := aq_request (aq, 'DB.DBA.VEC_INDEX_EMBED_WORKER', args);
      }
      if (claqn = 0)
        return req;
      if (tries = 0)
        log_message (sprintf ('vector index %s: no free aq thread, waiting to queue an embed batch', internal_name));
      tries := tries + 1;
      if (tries > 600)
        signal ('VEC36', sprintf ('No free aq thread for <%s> after %d retries; raise aq_max_threads or lower __vec_embed_concurrency',
                                  internal_name, tries - 1));
      delay (1);
    }
}
;

-- Complete one wave of parallel embedding: wait for its workers, then drain
-- the vectors they staged into the graph.  Returns the rows inserted.
--
-- The commit before aq_wait is required, not tidiness: aq_wait signals an error
-- if the calling thread holds database locks, and the loop that dispatched this
-- wave has been reading the staging table and writing bookkeeping rows.
--
-- Each request is waited on individually rather than with aq_wait_all so that a
-- failure names the batch that failed; aq_wait_all discards the individual
-- states.  Every request is waited on even after one fails -- returning while a
-- worker still runs would leave it writing to a staging table the error handler
-- is about to drop.
--
-- aq_wait does not raise when the worker failed: it reports through its fourth
-- argument, which is the integer 0 on success and a 3-element error box
-- (tag, sqlstate, message) on failure.  So "is not null" is the wrong test --
-- the success value is a 0-box, not NULL -- and isarray is the right one.
create procedure DB.DBA.VEC_INDEX_BACKFILL_WAVE (
  in aq any,
  in reqs any,
  in pending integer,
  in work_tb varchar,
  in internal_name varchar,
  in source_table varchar,
  in lo_kid bigint,
  in hi_kid bigint,
  in bulk integer := 0,
  in log_mode integer := null,
  in ch_tb varchar := null ) returns integer
{
  declare i, done, slice, room integer;
  declare err, res, results any;
  declare first_err varchar;
  declare published bigint;

  if (pending <= 0)
    return 0;
  DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, log_mode);   -- hold no locks across aq_wait

  first_err := null;
  results := make_array (pending, 'any');
  for (i := 0; i < pending; i := i + 1)
    {
      err := 0;
      {
        -- aq_wait itself can still raise (a queue-level failure, or the
        -- holds-locks guard); treat that the same as a worker error.
        declare exit handler for sqlstate '*'
          {
            if (first_err is null)
              first_err := __SQL_MESSAGE;
            goto next_req;
          };
        res := aq_wait (aq, reqs[i], 1, err);
        aset (results, i, res);
      }
      if (isarray (err) and first_err is null)
        first_err := sprintf ('%s %s',
            case when length (err) > 1 then cast (err[1] as varchar) else '?' end,
            case when length (err) > 2 then cast (err[2] as varchar) else '?' end);
     next_req:;
    }
  if (first_err is not null)
    signal ('VEC36', sprintf ('Parallel embedding failed for <%s>: %s', internal_name, first_err));

  -- All waits complete before graph writes begin, so aq_wait never observes
  -- locks held by the coordinator.  Bulk workers already staged their vectors;
  -- incremental results are linked here, serially, in submission order.
  --
  -- Linked in slices, and published and committed whenever the log is half
  -- full (VEC_INDEX_LOG_HALF_USED): a wave is four batches per worker, and
  -- in one transaction 16 batches of 1,024 384-dimension vectors were over
  -- TransactionAfterImageLimit.  Keys ascend through the wave -- batch by
  -- batch and within each batch -- so once a slice is linked, every key up to
  -- its last is linked or skipped, and (published, that key] can be drained
  -- and committed on its own.  A commit makes that much durable, as the
  -- commit after every serial batch already does.  A batch's vanished keys
  -- are removed before its rows are linked, so that no range is published
  -- while a key in it still has its old embedding.
  done := 0;
  slice := DB.DBA.VEC_INDEX_LOG_SLICE ();
  room := __trx_disk_log_length (1);   -- a fresh transaction: committed above
  published := lo_kid;
  for (i := 0; i < pending; i := i + 1)
    {
      res := results[i];
      if (not isarray (res) or length (res) < 4)
        signal ('VEC36', sprintf ('Embedding worker for <%s> returned an invalid result', internal_name));
      done := done + cast (res[0] as integer);
      -- A literal may disappear from RDF_OBJ after enumeration. Remove any
      -- prior embedding/source row rather than silently retaining stale data.
      if (isarray (res[3]) and length (res[3]) > 0)
        {
          declare mi integer;
          __VEC_INDEX_DELETE_BATCH (internal_name, res[3]);
          for (mi := 0; mi < length (res[3]); mi := mi + 1)
            DB.DBA.VEC_INDEX_DELETE_ROW (source_table, cast (res[3][mi] as bigint));
        }
      if (not bulk and cast (res[0] as integer) > 0)
        {
          declare ids, vecs any;
          declare j, k, n integer;
          ids := res[1];
          vecs := res[2];
          n := length (ids);
          j := 0;
          while (j < n)
            {
              k := j + slice;
              if (k > n)
                k := n;
              if (j = 0 and k = n)
                __VEC_INDEX_INSERT_BATCH (internal_name, ids, vecs);
              else
                __VEC_INDEX_INSERT_BATCH (internal_name, subseq (ids, j, k), subseq (vecs, j, k));
              j := k;
              if (DB.DBA.VEC_INDEX_LOG_HALF_USED (room))
                {
                  declare upto bigint;
                  upto := cast (ids[k - 1] as bigint);
                  DB.DBA.VEC_INDEX_BACKFILL_DRAIN (work_tb, internal_name, source_table, published, upto, bulk, ch_tb);
                  DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, log_mode);
                  published := upto;
                  room := __trx_disk_log_length (1);
                }
            }
        }
    }

  DB.DBA.VEC_INDEX_BACKFILL_DRAIN (work_tb, internal_name, source_table, published, hi_kid, bulk, ch_tb);
  DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, log_mode);
  return done;
}
;

-- Publish source-table bookkeeping for successfully embedded keys in a wave.
create procedure DB.DBA.VEC_INDEX_BACKFILL_DRAIN (
  in work_tb varchar,
  in internal_name varchar,
  in source_table varchar,
  in lo_kid bigint,
  in hi_kid bigint,
  in bulk integer := 0,
  in ch_tb varchar := null ) returns integer
{
  declare st, msg varchar;
  declare meta any;

  -- Bookkeeping, set-based: one statement for the whole wave instead of one
  -- INSERT per document (57,600 of them on a full FiQA build).  The rows are
  -- already in the staging table, so this is a join against it rather than a
  -- values list -- Virtuoso has no multi-row INSERT ... VALUES.
  --
  -- `insert replacing` gives the upsert that VEC_INDEX_UPSERT_ROW open-codes
  -- as insert-then-update-on-23000.  It rewrites the whole row, which is
  -- correct here only because RV_TEXT and RV_VECTOR are deliberately left null
  -- on this path: RV_TEXT is the indexed column and the embedding is held by
  -- the native index, not the backing table.
  --
  -- Only the wave's changed keys are upserted.  CH_TB, when there is one, holds
  -- exactly the keys the classification found changed, so the upsert walks
  -- those and looks each up in staging: its cost follows the delta.  Reading
  -- staging's (lo, hi] range instead would walk every unchanged row in it --
  -- and a sparse delta's single wave spans nearly the whole key range.  With
  -- no CH_TB every staged row is new (a first build) and the range is right.
  -- BF_HASH is populated only for short fallback text; RO_ID is the identity
  -- for long literals. The legacy async path may therefore re-embed a long
  -- literal once when it next sees a null hash, after which its normal hash
  -- bookkeeping converges.
  st := '00000';
  if (ch_tb is null)
    exec (sprintf ('insert replacing %s (RV_ID, RV_RO_ID, RV_TEXT_HASH, RV_UPDATED)'
                   || ' select BF_KID, BF_RO_ID, BF_HASH, now () from %s'
                   || ' where BF_KID > %s and BF_KID <= %s and BF_DONE <> -1',
                   source_table, work_tb,
                   cast (lo_kid as varchar), cast (hi_kid as varchar)),
          st, msg, vector (), 0, meta);
  else
    {
      -- DELETE then INSERT, not INSERT REPLACING.  When the key an INSERT
      -- REPLACING ... SELECT inserts comes from a table that a later step of
      -- the plan filters -- here a lookup that drops every staged row without
      -- a changed key, or with BF_DONE = -1 -- its replace step deletes by the
      -- wrong key: it reads the key by the inserted row's position in a vector
      -- that still holds the dropped rows.  It deletes rows it never inserts,
      -- and fails with 23000/SR175 on an existing row it does.  An engine
      -- defect, filed separately; the two statements below reach the same rows
      -- and are each proportional to the wave's changed keys.  A skipped key's
      -- old row goes with the DELETE, as VEC_INDEX_BACKFILL_WAVE removes it
      -- anyway.
      exec (sprintf ('delete from %s where RV_ID in (select K from %s where K > %s and K <= %s)',
                     source_table, ch_tb, cast (lo_kid as varchar), cast (hi_kid as varchar)),
            st, msg, vector (), 0, meta);
      if (not DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        exec (sprintf ('insert into %s (RV_ID, RV_RO_ID, RV_TEXT_HASH, RV_UPDATED)'
                       || ' select b.BF_KID, b.BF_RO_ID, b.BF_HASH, now () from %s c, %s b'
                       || ' where c.K > %s and c.K <= %s and b.BF_KID = c.K and b.BF_DONE <> -1',
                       source_table, ch_tb, work_tb,
                       cast (lo_kid as varchar), cast (hi_kid as varchar)),
              st, msg, vector (), 0, meta);
    }
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC38', sprintf ('Set-based upsert into %s failed: %s %s', source_table, st, msg));

  return 0;
}
;

-- Helper: embed and store one batch of (key, text) pairs.
-- Dedups the batch by key, embeds the surviving texts in one call, inserts the vectors
-- into the native index, and upserts (key, text, hash) into the backing table.
-- Returns the number of vectors actually written (post-dedup).
create procedure DB.DBA.VEC_INDEX_BACKFILL_FLUSH (
  in internal_name varchar,
  in source_table varchar,
  in model_name varchar,
  in model_handle integer,
  in model_type varchar,
  in batch_ids any,
  in batch_ro_ids any,
  in batch_fallback_texts any,
  in batch_count integer,
  in bulk integer := 0,
  in log_mode integer := null ) returns integer
{
  declare embeds, trimmed_ro, trimmed_ids, trimmed_fallback, texts any;
  declare bi, n, m, j, k, slice, room integer;
  declare txt varchar;

  if (batch_count <= 0)
    return 0;
  trimmed_ids := subseq (batch_ids, 0, batch_count);
  trimmed_ro := subseq (batch_ro_ids, 0, batch_count);
  trimmed_fallback := subseq (batch_fallback_texts, 0, batch_count);
  n := length (trimmed_ids);
  if (n = 0)
    return 0;

  -- Same RDF_OBJ resolution the parallel worker does, for the concurrency = 1
  -- path.  A key whose literal has gone is dropped rather than embedded empty.
  texts := make_array (n, 'any');
  m := 0;
  for (bi := 0; bi < n; bi := bi + 1)
    {
      if (cast (trimmed_ro[bi] as bigint) > 0)
        txt := DB.DBA.VEC_INDEX_RO_TEXT (cast (trimmed_ro[bi] as bigint));
      else
        txt := cast (trimmed_fallback[bi] as varchar);
      if (txt is null or length (txt) = 0)
        {
          __VEC_INDEX_DELETE_EMBEDDING (internal_name, cast (trimmed_ids[bi] as bigint));
          DB.DBA.VEC_INDEX_DELETE_ROW (source_table, cast (trimmed_ids[bi] as bigint));
        }
      else
        {
          aset (texts, m, txt);
          aset (trimmed_ids, m, cast (trimmed_ids[bi] as bigint));
          aset (trimmed_ro, m, cast (trimmed_ro[bi] as bigint));
          m := m + 1;
        }
    }
  if (m = 0)
    return 0;
  texts := subseq (texts, 0, m);
  trimmed_ids := subseq (trimmed_ids, 0, m);
  trimmed_ro := subseq (trimmed_ro, 0, m);

  embeds := DB.DBA.VEC_INDEX_EMBED_TEXTS (model_name, model_handle, texts, model_type);
  -- In slices, each written and recorded before the next, committing as the
  -- log fills (VEC_INDEX_LOG_HALF_USED): the caller commits once per batch,
  -- and a batch of 4,096 rows can be over TransactionAfterImageLimit by
  -- itself.
  slice := DB.DBA.VEC_INDEX_LOG_SLICE ();
  room := __trx_disk_log_length (1);
  j := 0;
  while (j < m)
    {
      k := j + slice;
      if (k > m)
        k := m;
      if (j = 0 and k = m)
        {
          if (bulk)
            __VEC_INDEX_STAGE_BATCH (internal_name, trimmed_ids, embeds);
          else
            __VEC_INDEX_INSERT_BATCH (internal_name, trimmed_ids, embeds);
        }
      else if (bulk)
        __VEC_INDEX_STAGE_BATCH (internal_name, subseq (trimmed_ids, j, k), subseq (embeds, j, k));
      else
        __VEC_INDEX_INSERT_BATCH (internal_name, subseq (trimmed_ids, j, k), subseq (embeds, j, k));
      for (bi := j; bi < k; bi := bi + 1)
        DB.DBA.VEC_INDEX_UPSERT_ROW_RO (source_table,
          cast (trimmed_ids[bi] as bigint),
          cast (trimmed_ro[bi] as bigint),
          md5 (cast (texts[bi] as varchar)));
      j := k;
      if (j < m and DB.DBA.VEC_INDEX_LOG_HALF_USED (room))
        {
          DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, log_mode);
          room := __trx_disk_log_length (1);
        }
    }
  return m;
}
;

-- Helper: backfill a vector index from a selector (key, text) enumeration.
--
-- Scale-safe replacement for enumerating the whole corpus into one capped, in-memory
-- exec() result.  The enumeration is streamed ONCE into a per-index staging table via a
-- projection-only INSERT ... SELECT (no row cap), then processed in bounded keyset pages
-- ordered by the integer key id -- which is a plain indexed column on a real table, so it
-- pages by index seek with bounded memory and is immune to the SPARQL top-k sort window.
-- Stale keys (present in the backing table but no longer selected) are removed with a
-- set-based anti-join against the same staging table.
--
-- enum_select : SQL projecting EXACTLY three columns from the selector's SPARQL derived
--               table, which is read with output:valmode "LONG":
--                 col 1 = integer key id  (iri_id_num (...) over an IRI_ID)
--                 col 2 = the literal's DB.DBA.RDF_OBJ id (rdf_box_ro_id (...)), NOT the
--                         text -- the text is resolved by the embed workers
--                 col 3 = text fallback when col 2 is zero
--               It may repeat a key; the staging INSERT SOFT keeps the first.
-- total_done  : OUT, number of vectors (re)embedded and written.
-- stale_count : OUT, number of stale keys removed.
-- Nodes currently in the HNSW graph, or -1 when that cannot be determined.
-- Read from the root page via __VEC_INDEX_METRICS, so it costs one page read.
create function DB.DBA.VEC_INDEX_GRAPH_NODES (in internal_name varchar) returns integer
{
  declare m any;
  declare st, msg varchar;
  declare meta, rows_out any;

  declare exit handler for sqlstate '*' { return -1; };
  st := '00000';
  exec ('select __VEC_INDEX_METRICS (?)', st, msg, vector (internal_name), 0, meta, rows_out);
  if ((DB.DBA.VEC_INDEX_EXEC_FAILED (st)) or rows_out is null or length (rows_out) = 0)
    return -1;
  m := rows_out[0][0];
  if (not isarray (m))
    return -1;
  return cast (get_keyword ('graph_nodes', m, -1) as integer);
}
;

-- Force the native epoch check and return its health verdict. This is distinct
-- from merely reading graph_nodes: an interrupted rebuild can leave a non-empty
-- partial graph whose root/data epochs disagree, and the in-process verdict may
-- still be the healthy value cached before that rebuild started.
create function DB.DBA.VEC_INDEX_GRAPH_HEALTH (in internal_name varchar) returns integer
{
  declare st, msg varchar;
  declare meta, rows_out any;

  declare exit handler for sqlstate '*' { return -1; };
  st := '00000';
  exec ('select __VEC_INDEX_HEALTH_RECHECK (?)', st, msg,
        vector (internal_name), 0, meta, rows_out);
  if ((DB.DBA.VEC_INDEX_EXEC_FAILED (st)) or rows_out is null or length (rows_out) = 0)
    return -1;
  return cast (rows_out[0][0] as integer);
}
;

-- Live nodes in the HNSW graph (graph_nodes counts a replaced or deleted node
-- until the next rebuild), or -1 when that cannot be determined.
create function DB.DBA.VEC_INDEX_GRAPH_LIVE_NODES (in internal_name varchar) returns integer
{
  declare m any;
  declare st, msg varchar;
  declare meta, rows_out any;

  declare exit handler for sqlstate '*' { return -1; };
  st := '00000';
  exec ('select __VEC_INDEX_METRICS (?)', st, msg, vector (internal_name), 0, meta, rows_out);
  if ((DB.DBA.VEC_INDEX_EXEC_FAILED (st)) or rows_out is null or length (rows_out) = 0)
    return -1;
  m := rows_out[0][0];
  if (not isarray (m))
    return -1;
  return cast (get_keyword ('graph_nodes', m, -1) as integer)
       - cast (get_keyword ('deleted_nodes', m, 0) as integer);
}
;

-- Does table TB have any row at all?  One index probe, not a count.
create function DB.DBA.VEC_INDEX_TABLE_HAS_ROWS (in tb varchar) returns integer
{
  declare st, msg varchar;
  declare meta, rows_out any;
  st := '00000';
  exec (sprintf ('select top 1 1 from %s', tb), st, msg, vector (), 0, meta, rows_out);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC36', sprintf ('Could not read %s: %s %s', tb, st, msg));
  return case when rows_out is not null and length (rows_out) > 0 then 1 else 0 end;
}
;

-- The largest delta, in percent of the graph's live nodes, that a refresh of a
-- build = 'bulk' index links into the existing graph instead of rebuilding it.
-- registry_set ('__vec_bulk_delta_pct', 'N'); 0 means always rebuild.
--
-- It is a cost crossover, not a correctness boundary: an incremental insert
-- and a bulk build produce graphs of the same kind.  A rebuild costs the whole
-- corpus -- 2.2 h for 9.7M nodes on 20 threads -- where linking costs the
-- delta, one node at a time on one thread; at 10% the rebuild is still well
-- ahead on anything but a small graph.
create procedure DB.DBA.VEC_INDEX_BULK_DELTA_PCT () returns integer
{
  declare v any;
  declare s varchar;
  declare n integer;
  n := 10;
  v := registry_get ('__vec_bulk_delta_pct');
  -- An unset key reads back as integer 0 and a cleared one as ''; both mean
  -- the default, not 0.  Only an explicit '0' switches linking off.
  if (isstring (v))
    {
      s := trim (cast (v as varchar));
      if (length (s))
        {
          declare exit handler for sqlstate '*' { n := 10; goto done; };
          n := cast (s as integer);
        }
    }
 done:
  if (n is null or n < 0)
    n := 10;
  if (n > 100)
    n := 100;
  return n;
}
;

-- Raise a server-wide ONNX plugin limit to at least WANT; never lower it.
--
-- max_batch and helper_pool_size belong to the plugin, not to one index: every
-- model and every caller shares them.  A refresh that set them to its own batch
-- size and concurrency lowered whatever an operator had configured above that
-- -- after a refresh with the default batch of 32, an application's 64-text
-- ONNX_EMBED_BATCH failed with "batch too large".  So read the current value
-- first (ONNX_CONFIG with one argument) and only ever raise it.
--
-- Returns NULL when the setting is already high enough, was raised, or the
-- plugin is not loaded at all -- an HTTP-provider install, where exec reports
-- 42001 (undefined procedure) and there is nothing to size.  Otherwise returns
-- a note for the caller to report: a pool that could not be raised makes the
-- refresh slower than asked, and that must not be silent.
create function DB.DBA.VEC_INDEX_ONNX_RAISE (in cfg_key varchar, in want integer) returns varchar
{
  declare st, msg varchar;
  declare meta, rows_out any;
  declare cur integer;
  st := '00000';
  exec ('select ONNX_CONFIG (?)', st, msg, vector (cfg_key), 0, meta, rows_out);
  if (cast (st as varchar) = '42001')
    return null;
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st) or rows_out is null or length (rows_out) = 0)
    return sprintf ('could not read ONNX setting %s (%s %s)', cfg_key, st, msg);
  cur := cast (rows_out[0][0] as integer);
  if (cur >= want)
    return null;
  st := '00000';
  exec ('select ONNX_CONFIG (?, ?)', st, msg, vector (cfg_key, want), 0, meta, rows_out);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    return sprintf ('could not raise ONNX setting %s from %d to %d (%s %s)', cfg_key, cur, want, st, msg);
  return null;
}
;

create procedure DB.DBA.VEC_INDEX_BACKFILL_PAGED (
  in enum_select varchar,
  in internal_name varchar,
  in source_table varchar,
  in model_name varchar,
  in model_handle integer,
  in model_type varchar,
  out total_done integer,
  out stale_count integer,
  out notes varchar,
  in build_mode varchar := null )
{
  declare work_tb, ch_tb varchar;
  declare changed_rows, live_nodes, delta_pct integer;
  declare st, msg varchar;
  declare meta, pg, srows any;
  declare last_kid bigint;
  declare page_sz, np, pi, batch_size, batch_count integer;
  declare batch_ro_ids, batch_ids, batch_fallback_texts any;
  declare concurrency, queue_depth, pending, aq_pool integer;
  declare pool_note varchar;
  declare aq, reqs any;
  declare wave_lo, wave_hi bigint;
  declare bulk integer;
  declare total_rows, next_report, t_start, needs_build, graph_health, t_phase integer;
  declare cur_phase varchar;
  declare caller_mode, work_mode integer;

  total_done := 0;
  stale_count := 0;
  notes := null;
  ch_tb := null;
  page_sz := 10000;   -- rows held in memory per keyset page (bounded regardless of corpus size)
  batch_size := DB.DBA.VEC_INDEX_EMBED_BATCH_SIZE ();
  concurrency := DB.DBA.VEC_INDEX_EMBED_CONCURRENCY ();
  -- Each worker needs a thread of its own from the server's async-queue pool.
  -- The queue is AQ_SEPARATE_TXN, and a request of such a queue that finds
  -- no free thread fails with 42000/CLAQN rather than waiting for one
  -- (aq_request, aqueue.c).  The pool has AsyncQueueMaxThreads threads -- 10
  -- in the stock virtuoso.ini -- so a concurrency above it could only fail,
  -- and only once the enumeration had run.  Use what the pool can give, and
  -- say so.
  pool_note := null;
  aq_pool := sys_stat ('aq_max_threads');
  if (concurrency > 1 and aq_pool >= 1 and concurrency > aq_pool)
    {
      pool_note := sprintf ('embed concurrency %d lowered to %d, the server''s async-queue threads (AsyncQueueMaxThreads)',
                            concurrency, aq_pool);
      concurrency := aq_pool;
    }
  -- Keep several worker-widths queued so a fast helper does not go idle while
  -- the coordinator waits for the slowest request in the current width.  The
  -- returned incremental vectors remain bounded: at the maximum this is 64
  -- batches, and bulk workers return counts rather than vector payloads.
  queue_depth := concurrency * 4;
  if (concurrency <= 1)
    queue_depth := 1;
  if (queue_depth > 64)
    queue_depth := 64;
  bulk := 0;
  total_rows := 0;
  next_report := 0;
  t_start := msec_time ();
  t_phase := t_start;
  cur_phase := 'staging-table';

  -- Per-index staging table.  internal_name is the server-generated VECIDX_<hex> catalog
  -- name -- a safe SQL identifier -- so the table name cannot carry injection.
  work_tb := sprintf ('DB.DBA."%s_BF"', internal_name);

  -- The backfill runs in a log mode of its own and hands the caller's back on
  -- every exit.  It keeps the caller's choice of logging -- log_enable (0) or
  -- (2) means an unlogged refresh -- but never runs with row autocommit except
  -- for the one statement below that needs it.  A caller's session-wide row
  -- autocommit (log_enable (3)) otherwise reaches the bookkeeping upsert,
  -- where a query-fragment branch carrying log bytes finds the main
  -- transaction committing under it and is cancelled: 40001/SR337.  And in the
  -- graph phase it would make every page touch a transaction of its own.
  --
  -- cli_log_mode (), not log_enable (null): the refresh has committed before
  -- getting here (VEC_INDEX_BEGIN_MUTATION), and a commit resets the
  -- transaction's log mode to the connection default unless row autocommit is
  -- on, so log_enable (null) would report logging on for a log_enable (0)
  -- caller -- which is how such a refresh came to be logged end to end.
  caller_mode := cli_log_mode ();
  work_mode := bit_and (caller_mode, 1);

  -- Drop the staging table on any error, then resignal, so an interrupted backfill leaves
  -- no orphaned scratch table behind.
  declare exit handler for sqlstate '*'
    {
      log_message (sprintf ('vector index %s: refresh FAILED during phase %s: %s %s',
          internal_name, coalesce (cur_phase, '<start>'), __SQL_STATE, __SQL_MESSAGE));
      DB.DBA.VEC_INDEX_SET_LOG_MODE (caller_mode);
      if (ch_tb is not null)
        DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (ch_tb);
      DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (work_tb);
      resignal;
    };
  DB.DBA.VEC_INDEX_SET_LOG_MODE (work_mode);

  -- Recreate staging (dropping any leftover from a previously interrupted refresh).
  -- BF_TEXT is populated only for values with no RDF_OBJ row (normally short
  -- literals). BF_HASH identifies those fallback values, and BF_DONE is zero
  -- except for a rare missing/empty value marked -1. Which rows changed is
  -- kept apart, in <BF>C, so that finding them never rewrites this table.
  -- Vector payloads never pass through this scratch table.
  DB.DBA.VEC_INDEX_ENSURE_RO_ID (source_table);
  DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (work_tb);
  exec (sprintf ('create table %s (BF_KID bigint primary key, BF_RO_ID bigint, BF_TEXT varchar, BF_HASH varbinary, BF_DONE integer default 0)', work_tb),
        st, msg, vector (), 0, meta);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC36', sprintf ('Could not create backfill staging table for <%s>: %s %s', internal_name, st, msg));
  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := 'enumerate';

  -- Stream the ENTIRE enumeration into staging in one pass (no row cap; projection only,
  -- which avoids the mis-optimization of SQL predicates over the SPARQL derived key column).
  --
  -- Row autocommit for this one statement, because it is the one that cannot be
  -- split into batches: a single INSERT ... SELECT over the whole corpus is one
  -- transaction whose after-image grows without bound, and past
  -- TransactionAfterImageLimit the server aborts the refresh with SR325.
  -- log_enable's bit 2 is cli_row_autocommit.  Add ONLY that bit and leave
  -- bit 1 as the caller chose it: forcing logging ON is what made this
  -- statement produce the 40001/SR337 + 4000X/MTXNA storm.  The enumeration is
  -- big enough that the optimiser splits it into query fragments, and a
  -- fragment is a transaction branch (aq_qr_func, sqlvrun.c).  A branch with
  -- log bytes must merge them into the main transaction (lt_log_merge,
  -- log.c:949), and under row autocommit the main is committing constantly, so
  -- a branch that arrives while it is not LT_PENDING is blown off with
  -- LTE_CANCEL.  With logging off the branch has no bytes to merge and returns
  -- LTE_OK, so a caller who ran log_enable (2) must keep bit 1 clear.
  --
  -- Deliberately scoped to this statement alone.  Row autocommit across the
  -- graph-insert phase would put every HNSW page touch in its own transaction,
  -- and lt_vvec_page_images is per-transaction, so a page touched by 100
  -- consecutive inserts would log 100 records instead of one coalesced delta --
  -- more log, not less.  That phase is already bounded by
  -- VEC_INDEX_BACKFILL_COMMIT.  cli_row_autocommit is client-level and survives
  -- commits, so it has to be taken away again explicitly.
  DB.DBA.VEC_INDEX_SET_LOG_MODE (bit_or (work_mode, 2));
  exec (sprintf ('insert soft %s (BF_KID, BF_RO_ID, BF_TEXT) %s', work_tb, enum_select),
        st, msg, vector (), 0, meta);
  DB.DBA.VEC_INDEX_SET_LOG_MODE (work_mode);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC36', sprintf ('Selector enumeration failed for <%s>: %s %s', internal_name, st, msg));
  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := 'hash-short-literals';

  -- Only short literals need a text hash for identity. Compute all of them in
  -- one vectored statement; RDF_OBJ-backed literals are compared by RO_ID and
  -- avoid both text materialization and per-row hashing.
  st := '00000';
  exec (sprintf ('update %s set BF_HASH = md5 (BF_TEXT) where BF_RO_ID = 0', work_tb),
        st, msg, vector (), 0, meta);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal ('VEC36', sprintf ('Short-literal hash staging failed for <%s>: %s %s', internal_name, st, msg));
  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := 'classify-changed';

  -- Which staged rows are new or changed.  Written to a side table of keys,
  -- <BF>C, by one read-only anti-join against the backing table -- not by
  -- flagging rows in staging.  The flag was an UPDATE of every UNCHANGED row:
  -- 9.7M writes to find 58 changes, 56 s, and then every keyset page, and every
  -- wave's bookkeeping upsert, still had to scan staging for the few flagged
  -- rows.  The side table is the index on "changed" that staging did not have:
  -- the page loop and the upsert walk it, so their cost follows the delta.
  --
  -- A first build -- an empty backing table -- has every row changed; there
  -- the side table would only copy staging's keys, so it is skipped and the
  -- loop reads staging directly.
  --
  -- A row whose backing entry has no RV_RO_ID (written by the async path)
  -- compares unequal and is re-embedded once, as before.
  if (DB.DBA.VEC_INDEX_TABLE_HAS_ROWS (source_table))
    {
      ch_tb := sprintf ('DB.DBA."%s_BFC"', internal_name);
      DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (ch_tb);
      st := '00000';
      exec (sprintf ('create table %s (K bigint primary key)', ch_tb), st, msg, vector (), 0, meta);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal ('VEC36', sprintf ('Could not create the changed-key table for <%s>: %s %s', internal_name, st, msg));
      -- Row autocommit, as for the enumeration: when most rows changed this is
      -- as large as staging, and one statement cannot be split into batches.
      st := '00000';
      DB.DBA.VEC_INDEX_SET_LOG_MODE (bit_or (work_mode, 2));
      exec (sprintf ('insert soft %s (K) select b.BF_KID from %s b where not exists ('
                     || ' select 1 from %s s where s.RV_ID = b.BF_KID and ('
                     || ' (b.BF_RO_ID > 0 and s.RV_RO_ID = b.BF_RO_ID)'
                     || ' or (b.BF_RO_ID = 0 and s.RV_RO_ID = 0'
                     || ' and s.RV_TEXT_HASH = b.BF_HASH)))',
                     ch_tb, work_tb, source_table),
            st, msg, vector (), 0, meta);
      DB.DBA.VEC_INDEX_SET_LOG_MODE (work_mode);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal ('VEC36', sprintf ('Changed-row classification failed for <%s>: %s %s', internal_name, st, msg));
      changed_rows := DB.DBA.VEC_INDEX_STAGED_ROW_COUNT (ch_tb);
    }
  else
    changed_rows := -1;     -- every staged row; set once total_rows is known
  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := 'embed';

  -- Bound the transaction.  A backfill is a bulk maintenance operation: staging the whole
  -- enumeration and then embedding every row in ONE transaction makes the log after-image
  -- grow without limit, and past TransactionAfterImageLimit (50MB by default) the server
  -- aborts the whole refresh with SR325 -- a 57,600-row FiQA index never got past it.
  -- Committing here, and after every embedded batch below, keeps the transaction bounded
  -- regardless of corpus size.  Partial progress becoming durable is correct for a refresh:
  -- rows already embedded are valid, and a failed run is resumed by re-running REFRESH
  -- (unchanged rows are then skipped by the text-hash check).
  DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, work_mode);

  -- Decide how the graph gets built, now that the enumeration is staged and so
  -- its size is known.
  --   'incremental'  link each batch into the graph as it is embedded (the
  --                  historical behaviour)
  --   'bulk'         stage embeddings only, then derive the whole graph once
  --   'auto'/null    incremental -- bulk is opt-in, see VEC_INDEX_BUILD_IS_BULK
  --                  for why
  total_rows := DB.DBA.VEC_INDEX_STAGED_ROW_COUNT (work_tb);
  if (changed_rows < 0)
    changed_rows := total_rows;
  bulk := DB.DBA.VEC_INDEX_BUILD_IS_BULK (total_rows, internal_name, build_mode);

  -- build = 'bulk' rebuilds the whole graph at the end, so without this a
  -- 58-row delta against a 9.7M-node index cost the full 2.2-hour build.  When
  -- the graph is already there and sound, and the delta is small beside it,
  -- link the delta into it instead -- exactly what build = 'incremental' does,
  -- for this refresh only.  A first build (no side table), an unsound graph and
  -- a large delta still get the rebuild.
  if (bulk and ch_tb is not null and lower (coalesce (build_mode, '')) <> 'stage')
    {
      delta_pct := DB.DBA.VEC_INDEX_BULK_DELTA_PCT ();
      live_nodes := DB.DBA.VEC_INDEX_GRAPH_LIVE_NODES (internal_name);
      if (delta_pct > 0 and live_nodes > 0
          and cast (changed_rows as double precision) * 100 <= cast (delta_pct as double precision) * live_nodes
          and 1 = DB.DBA.VEC_INDEX_GRAPH_HEALTH (internal_name))
        {
          log_message (sprintf ('vector index %s: %d changed row(s) against %d live graph node(s), '
              || 'within __vec_bulk_delta_pct (%d%%) -- linking them into the graph instead of rebuilding it',
              internal_name, changed_rows, live_nodes, delta_pct));
          bulk := 0;
        }
    }

  -- Progress reporting.  A refresh of a real corpus blocks for a long time with
  -- nothing to look at: the 57,600-document FiQA build took 85 minutes and the
  -- only way to see how far along it was, was to poll the internal VECSRC_<hex>
  -- table from a second connection -- a table name the user never chose.  So
  -- report to the server log, which is where an operator can already see it,
  -- roughly every VEC_INDEX_PROGRESS_EVERY rows with a rate and an ETA.
  next_report := DB.DBA.VEC_INDEX_PROGRESS_EVERY ();
  log_message (sprintf ('vector index %s: backfill starting, %d rows enumerated, %d new or changed, build=%s, embed concurrency %d, queue %d, batch %d',
      internal_name, total_rows, changed_rows, case when bulk then 'bulk' else 'incremental' end,
      concurrency, queue_depth, batch_size));

  -- Resolve one literal on this thread before any worker is dispatched.
  --
  -- rb_complete_1 () compiles four queries against DB.DBA.RDF_OBJ into
  -- unsynchronised file statics on first use (rdfbox.c:332), with no mutex --
  -- unlike vvec_compile_text (), which wraps the same sql_compile_static () call
  -- precisely because concurrent compilation is not safe.  The workers all
  -- resolve their first literal at the same moment, so they enter that lazy init
  -- together, compile against the same dbe_key_t at once, and the optimizer's
  -- shared column-statistics update double-frees (itc_col_stat_free,
  -- search.c:3424, reached with upd_col_stats = 1).
  --
  -- One resolution here leaves all four statics non-NULL, so every worker takes
  -- the already-compiled branch and never calls the compiler.  This is a
  -- workaround for a pre-existing race in rdfbox.c, not a fix for it.
  {
    declare warm_ro any;
    declare wst, wmsg varchar;
    declare wmeta, wrows any;
    wst := '00000';
    exec (sprintf ('select top 1 BF_RO_ID from %s where BF_RO_ID > 0', work_tb),
          wst, wmsg, vector (), 0, wmeta, wrows);
    if (not DB.DBA.VEC_INDEX_EXEC_FAILED (wst) and wrows is not null and length (wrows) > 0)
      {
        warm_ro := cast (wrows[0][0] as bigint);
        DB.DBA.VEC_INDEX_RO_TEXT (warm_ro);
      }
  }

  -- Raise the ONNX helper pool to match the embedding concurrency.  These two
  -- must move together: a bigger pool with a serial caller is a no-op (one
  -- helper is held at a time), and concurrent callers against a pool of 2
  -- would just queue on the pool.  Pools grow in place, so this takes effect on
  -- an already-loaded model.  Quiet no-op if the ONNX plugin is not loaded, as
  -- it will not be for an HTTP provider -- and also for a non-DBA caller, since
  -- ONNX_CONFIG is DBA-only ('helper_path' names an executable the server runs)
  -- and exec() compiles as the invoker.  The consequence is a smaller helper
  -- pool, i.e. a slower refresh, never a wrong result.
  --
  -- Both settings are server-wide, so VEC_INDEX_ONNX_RAISE only ever raises
  -- them, and says so when it could not: the result is a slower refresh, not a
  -- wrong one, but the caller asked for this concurrency and should know.
  {
    declare n1, n2 varchar;
    n1 := null;
    if (concurrency > 1)
      n1 := DB.DBA.VEC_INDEX_ONNX_RAISE ('helper_pool_size', concurrency);
    -- The plugin's admission limit has to admit the chosen local batch size.
    n2 := DB.DBA.VEC_INDEX_ONNX_RAISE ('max_batch', batch_size);
    notes := pool_note;
    if (n1 is not null)
      notes := case when notes is null then n1 else notes || '; ' || n1 end;
    if (n2 is not null)
      notes := case when notes is null then n2 else notes || '; ' || n2 end;
    if (notes is not null)
      log_message (sprintf ('vector index %s: %s', internal_name, notes));
  }

  -- Keyset-page over staging, ascending by key id (reliable index seek, bounded memory).
  batch_ro_ids := make_array (batch_size, 'any');
  batch_fallback_texts := make_array (batch_size, 'any');
  batch_ids := make_array (batch_size, 'any');
  batch_count := 0;
  last_kid := -1;   -- key ids are non-negative
  pending := 0;
  -- One queue for the whole backfill: it is empty again once every request in a
  -- wave has been waited on, so there is no reason to rebuild it per wave.
  aq := null;
  if (concurrency > 1)
    -- Flag 4 is AQ_SEPARATE_TXN (aqueue.h:104).  Without it aq_allocate gives
    -- every worker lt_main_trx_no = this thread's trx_no (aqueue.c:781, :133),
    -- tying the workers and the coordinator into one transaction family for the
    -- checkpoint and buffer layers.  Flag 4 zeroes it, which is what makes the
    -- worker's "own transaction, commits it itself" contract actually hold --
    -- and is what every other parallel loader here passes (rdflddir2.sql:413,
    -- system.sql:5064, system2.sql:2403, sparql.sql:16381).
    aq := async_queue (concurrency, 4);
  reqs := make_array (queue_depth, 'any');
  wave_lo := -1;    -- vectors staged for keys in (wave_lo, wave_hi] are undrained
  wave_hi := -1;
  while (1)
    {
      -- last_kid is interpolated as %s, not %d: it is a bigint key id and sprintf's
      -- %d truncates through 32 bits, so a blank-node key (~4.6e18) rendered as
      -- "10000".  The cursor then never advanced past it and this loop re-read and
      -- re-embedded the same page forever.
      -- Walk the changed keys when there is a side table of them, so a page
      -- costs what it returns; otherwise every staged row is new and staging
      -- is walked directly.
      if (ch_tb is null)
        exec (sprintf ('select top %d BF_KID, BF_RO_ID, BF_TEXT from %s where BF_KID > %s order by BF_KID',
                       page_sz, work_tb, cast (last_kid as varchar)),
              st, msg, vector (), 0, meta, pg);
      else
        exec (sprintf ('select top %d b.BF_KID, b.BF_RO_ID, b.BF_TEXT from %s c, %s b'
                       || ' where c.K > %s and b.BF_KID = c.K order by c.K',
                       page_sz, ch_tb, work_tb, cast (last_kid as varchar)),
              st, msg, vector (), 0, meta, pg);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal ('VEC36', sprintf ('Backfill page read failed for <%s>: %s %s', internal_name, st, msg));
      np := length (pg);
      if (np = 0)
        goto embed_done;

      for (pi := 0; pi < np; pi := pi + 1)
        {
          declare kid, ro_id bigint;
          declare fallback_text varchar;

          kid := cast (pg[pi][0] as bigint);
          ro_id := cast (pg[pi][1] as bigint);
          fallback_text := cast (pg[pi][2] as varchar);
          aset (batch_ids, batch_count, kid);
          aset (batch_ro_ids, batch_count, ro_id);
          aset (batch_fallback_texts, batch_count, fallback_text);
          batch_count := batch_count + 1;
          if (batch_count >= batch_size)
            {
              if (concurrency <= 1)
                {
                  total_done := total_done + DB.DBA.VEC_INDEX_BACKFILL_FLUSH (
                    internal_name, source_table, model_name, model_handle, model_type,
                    batch_ids, batch_ro_ids, batch_fallback_texts, batch_count, bulk, work_mode);
                  DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, work_mode);
              if (total_done >= next_report)
                {
                  DB.DBA.VEC_INDEX_PROGRESS_REPORT (internal_name, total_done, changed_rows, t_start);
                  next_report := total_done + DB.DBA.VEC_INDEX_PROGRESS_EVERY ();
                }
                }
              else
                {
                  aset (reqs, pending,
                        DB.DBA.VEC_INDEX_EMBED_SUBMIT (aq, internal_name,
                            vector (work_tb, internal_name, model_name, model_handle, model_type,
                                    subseq (batch_ids, 0, batch_count),
                                    subseq (batch_ro_ids, 0, batch_count),
                                    subseq (batch_fallback_texts, 0, batch_count), bulk)));
                  pending := pending + 1;
                  wave_hi := kid;
                  if (pending >= queue_depth)
                    {
                      total_done := total_done + DB.DBA.VEC_INDEX_BACKFILL_WAVE (
                        aq, reqs, pending, work_tb, internal_name, source_table, wave_lo, wave_hi, bulk, work_mode, ch_tb);
                      wave_lo := wave_hi;
                      pending := 0;
              if (total_done >= next_report)
                {
                  DB.DBA.VEC_INDEX_PROGRESS_REPORT (internal_name, total_done, changed_rows, t_start);
                  next_report := total_done + DB.DBA.VEC_INDEX_PROGRESS_EVERY ();
                }
                    }
                }
              batch_count := 0;
            }
        }
      last_kid := cast (pg[np - 1][0] as bigint);   -- advance cursor to max key id of this page
    }
  embed_done:
  -- Flush the final partial batch.
  if (batch_count > 0)
    {
      if (concurrency <= 1)
        {
          total_done := total_done + DB.DBA.VEC_INDEX_BACKFILL_FLUSH (
            internal_name, source_table, model_name, model_handle, model_type,
            batch_ids, batch_ro_ids, batch_fallback_texts, batch_count, bulk, work_mode);
          DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, work_mode);
        }
      else
        {
          aset (reqs, pending,
                DB.DBA.VEC_INDEX_EMBED_SUBMIT (aq, internal_name,
                    vector (work_tb, internal_name, model_name, model_handle, model_type,
                            subseq (batch_ids, 0, batch_count),
                            subseq (batch_ro_ids, 0, batch_count),
                            subseq (batch_fallback_texts, 0, batch_count), bulk)));
          pending := pending + 1;
          wave_hi := cast (batch_ids[batch_count - 1] as bigint);
        }
      batch_count := 0;
    }
  -- Drain whatever is still in flight.
  if (pending > 0)
    {
      total_done := total_done + DB.DBA.VEC_INDEX_BACKFILL_WAVE (
        aq, reqs, pending, work_tb, internal_name, source_table, wave_lo, wave_hi, bulk, work_mode, ch_tb);
      wave_lo := wave_hi;
      pending := 0;
    }

  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := 'stale-removal';

  -- Stale-key removal: keys in the backing table that are no longer selected.
  -- Set-based anti-join against staging, keyset-paged: each page starts after
  -- the last key of the one before, so the loop reads the backing table once
  -- however many stale keys there are, rather than rescanning it from the
  -- start for every page.
  last_kid := -1;
  while (1)
    {
      exec (sprintf ('select top %d RV_ID from %s where RV_ID > %s and RV_ID not in (select BF_KID from %s) order by RV_ID',
                     page_sz, source_table, cast (last_kid as varchar), work_tb),
            st, msg, vector (), 0, meta, srows);
      if ((DB.DBA.VEC_INDEX_EXEC_FAILED (st)) or length (srows) = 0)
        goto stale_done;
      for (pi := 0; pi < length (srows); pi := pi + 1)
        {
          declare skid bigint;
          skid := cast (srows[pi][0] as bigint);
          __VEC_INDEX_DELETE_EMBEDDING (internal_name, skid);
          DB.DBA.VEC_INDEX_DELETE_ROW (source_table, skid);
          stale_count := stale_count + 1;
          last_kid := skid;
        }
      -- Same transaction bounding as the embed loop: a large stale set would otherwise
      -- accumulate one unbounded after-image.  Committing also shrinks the anti-join for
      -- the next page, which is what makes this loop terminate.
      DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, work_mode);
    }
  stale_done:
  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := 'graph-build';

  -- Bulk mode: nothing has been linked into the graph yet, so derive it now in
  -- one pass from <index>_vec_embeddings.
  --
  -- No method is passed, deliberately.  __VEC_INDEX_REBUILD's own precedence
  -- then applies -- explicit arg > WITH (rebuild = ...) > VVEC_FAST_REBUILD >
  -- 'auto' -- and 'auto' is what gives the memory guard: it picks the fast
  -- parallel builder only while the estimated heap fits under
  -- VVEC_FAST_REBUILD_MAX_BYTES and otherwise falls back to replay, which
  -- builds the same graph from the same rows, just serially.  Forcing 'fast'
  -- here would defeat that guard on exactly the largest corpora.
  --
  -- This runs before the staging table is dropped but after stale removal, so
  -- the graph is derived from the final row set.
  log_message (sprintf ('vector index %s: embedding done, %d rows in %d ms%s',
      internal_name, total_done, msec_time () - t_start,
      case when bulk then '; building graph' else '' end));

  -- Build when this run embedded something, and also when the selector matched
  -- rows but an unchanged/resumed refresh finds either an empty or unhealthy
  -- graph.  Empty catches a run which staged every vector and died before the
  -- rebuild changed the root, when the epoch pair still agrees.  The forced
  -- health recheck catches a rebuild which died after writing part of the graph:
  -- graph_nodes is then non-zero, but graph_epoch and data_epoch disagree.  The
  -- verdict must be forcibly recomputed because this process may have cached OK
  -- before the failed rebuild. total_rows keeps an empty selector from looking
  -- like either recovery case.
  --
  -- The same holds in incremental mode: a graph write no longer re-agrees the
  -- epochs of an index reconciliation has condemned (vvec_write_epoch_sync), so
  -- an incremental refresh that links rows into a condemned graph leaves it
  -- condemned.  A refresh is the operator's way of bringing an index up to
  -- date, so it rebuilds an unusable graph whichever mode built it.
  needs_build := 0;
  graph_health := 1;
  if (bulk and total_done > 0)
    needs_build := 1;
  else if (total_rows > 0)
    {
      graph_health := DB.DBA.VEC_INDEX_GRAPH_HEALTH (internal_name);
      if (graph_health <> 1 or 0 = DB.DBA.VEC_INDEX_GRAPH_NODES (internal_name))
        {
          needs_build := 1;
          log_message (sprintf ('vector index %s: %d staged row(s) with an incomplete or unhealthy graph '
              || '(health %d); building it now',
              internal_name, total_rows, graph_health));
        }
    }
  -- build = 'stage' only embeds; the caller builds the graph later with __VEC_INDEX_REBUILD.
  if (lower (coalesce (build_mode, '')) = 'stage')
    needs_build := 0;
  if (needs_build)
    {
      st := '00000';
      exec ('select __VEC_INDEX_REBUILD (?)', st, msg, vector (internal_name), 0, meta);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal ('VEC36', sprintf ('Bulk graph build failed for <%s>: %s %s', internal_name, st, msg));
      DB.DBA.VEC_INDEX_BACKFILL_COMMIT (internal_name, work_mode);
    }

  t_phase := DB.DBA.VEC_INDEX_PHASE (internal_name, cur_phase, t_phase);
  cur_phase := null;
  if (ch_tb is not null)
    DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (ch_tb);
  DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (work_tb);
  DB.DBA.VEC_INDEX_SET_LOG_MODE (caller_mode);
}
;

-- Rows between progress lines.  Deliberately a row count rather than a time
-- interval: the point is a legible, evenly spaced trace of a long build, and a
-- row count keeps the number of log lines proportional to the work rather than
-- to how slow the machine is.  Override with
-- registry_set ('__vec_progress_every', 'N'); 0 silences progress entirely.
create procedure DB.DBA.VEC_INDEX_PROGRESS_EVERY () returns integer
{
  declare v any;
  declare s varchar;
  declare n integer;
  n := 2000;
  v := registry_get ('__vec_progress_every');
  -- A blank string is "use the default", not 0.  cast ('' as integer) returns 0
  -- without raising, and 0 here means "silence progress entirely" -- so parsing
  -- a cleared key would turn it off rather than restore the default.  Only an
  -- explicit '0' silences it.
  if (isstring (v))
    {
      s := trim (cast (v as varchar));
      if (length (s))
        {
          declare exit handler for sqlstate '*' { n := 2000; goto done; };
          n := cast (s as integer);
        }
    }
 done:
  if (n is null or n < 0)
    n := 2000;
  if (n = 0)
    return 1000000000;            -- effectively never
  return n;
}
;

-- One progress line: how far along, how fast, and how much longer.
-- Never lets a reporting failure break a build -- this is observability, and a
-- refresh that dies because it could not describe itself would be worse than
-- one that says nothing.
create procedure DB.DBA.VEC_INDEX_PROGRESS_REPORT (
  in internal_name varchar,
  in done integer,
  in total integer,
  in t_start integer )
{
  declare exit handler for sqlstate '*' { return; };
  declare elapsed_ms, eta_s integer;
  declare rate double precision;
  elapsed_ms := msec_time () - t_start;
  if (elapsed_ms <= 0)
    elapsed_ms := 1;
  rate := (done * 1000.0) / elapsed_ms;
  if (total > done and rate > 0)
    {
      eta_s := cast (((total - done) / rate) as integer);
      log_message (sprintf ('vector index %s: embedded %d of %d rows to embed (%d%%), %.1f rows/s, ~%d s remaining',
          internal_name, done, total, (done * 100) / total, rate, eta_s));
    }
  else
    log_message (sprintf ('vector index %s: embedded %d rows, %.1f rows/s',
        internal_name, done, rate));
}
;

-- Rows in the staged enumeration, for the progress denominator.  Returns 0 if
-- it cannot be determined, which VEC_INDEX_PROGRESS_REPORT treats as "no
-- total" and reports a rate without a percentage or ETA.
create procedure DB.DBA.VEC_INDEX_STAGED_ROW_COUNT (in work_tb varchar) returns integer
{
  declare st, msg varchar;
  declare meta, rows_out any;
  declare exit handler for sqlstate '*' { return 0; };
  st := '00000';
  exec (sprintf ('select count(*) from %s', work_tb), st, msg, vector (), 0, meta, rows_out);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st) or rows_out is null or length (rows_out) = 0)
    return 0;
  return cast (rows_out[0][0] as integer);
}
;

-- Resolve 'incremental' vs 'bulk' for this backfill.
--
-- Bulk is OPT-IN: 'auto' and the default both mean incremental.  That is not
-- timidity about the speed-up, it is a measured behaviour difference.
--
-- Bulk derives the graph with the parallel fast builder, and that builder is
-- non-deterministic: the graph depends on the order threads happen to insert,
-- so two builds of identical data give different graphs.  On a corpus whose
-- nearest neighbours are very close together this is observable in results.
-- Measured on the 10,500-document tvvec_backfill_scale corpus, whose texts
-- differ only by an embedded integer (cosine 0.994 between the two nearest
-- documents), searching for one document's own text returned that document at
-- rank 1 in 1 of 4 fast rebuilds at the default ef_search, and 2 of 3 at
-- ef_search 100 -- while the incremental graph returned it every time.
--
-- So an index built in bulk can rank an exact match below a near-duplicate.
-- That is a property of the fast builder, which __VEC_INDEX_REBUILD has always
-- selected for >= 10,000 rows, and not of this code -- but making it the build
-- default would silently change search results for every large index, which is
-- not a decision a performance change gets to make on the user's behalf.
--
-- WITH (build = 'bulk') is the whole win (see the commit that added it: it
-- removes the incremental linking that a post-refresh rebuild would discard
-- anyway, and packs the graph pages ~4x smaller).  It is the right choice for
-- a large first build whose corpus is not full of near-duplicates, and it is
-- exactly what a user who already follows the documented "rebuild after a
-- large refresh" advice ends up with.
create procedure DB.DBA.VEC_INDEX_BUILD_IS_BULK (
  in staged_rows integer,
  in internal_name varchar,
  in build_mode varchar ) returns integer
{
  declare mode varchar;
  mode := lower (coalesce (build_mode, 'auto'));
  if (mode = 'bulk' or mode = 'stage')
    return 1;
  return 0;                       -- 'incremental', 'auto', or unset
}
;

-- Refresh a vector index.
-- Re-evaluates the selector, embeds changed texts, and updates the native index.
-- For the shorthand selector, executes a SPARQL query to get (key, text) pairs,
-- hashes texts to detect changes, batches embedding via ONNX_EMBED_BATCH,
-- and inserts vectors via __VEC_INDEX_INSERT_BATCH.
create procedure DB.DBA.VEC_INDEX_REFRESH (in idx_iri varchar) returns any
{
  declare internal_name, source_table, model_name, sel_type varchar;
  declare graph_iri, pred_iri varchar;
  declare g_id, p_id any;
  declare dims, model_dims integer;
  declare reduce_mode varchar;
  declare cat_state varchar;
  declare build_mode varchar;
  declare resolved any;
  declare model_handle integer;
  declare model_type varchar;
  declare batch_size integer;
  declare batch_texts any;
  declare batch_ids any;
  declare batch_count integer;
  declare total_done integer;
  declare STATE, MESSAGE varchar;
  declare key_var, embedding_var varchar;
  declare where_pattern_blob any;
  declare where_text varchar;
  declare dataset_text varchar;
  declare existing_keys any;
  declare seen_keys any;
  declare stale_count integer;
  declare si, sn integer;
  declare mutation_started integer;
  declare refresh_note varchar;

  declare exit handler for sqlstate '*'
    {
      if (mutation_started)
        DB.DBA.VEC_INDEX_END_MUTATION (idx_iri, 'refreshing', 0, __SQL_MESSAGE);
      resignal;
    };

  mutation_started := 0;

  -- Load catalog record
  whenever not found goto cat_not_found;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE, SVI_MODEL_NAME,
         SVI_DIMENSIONS, SVI_MODEL_DIMENSIONS, SVI_REDUCE,
         SVI_SELECTOR_TYPE, SVI_STATE,
         SVI_SELECTOR_GRAPH, SVI_SELECTOR_PRED,
         SVI_KEY_VAR, SVI_EMBEDDING_VAR, SVI_WHERE_PATTERN,
         SVI_WHERE_TEXT, SVI_BUILD, SVI_DATASET_TEXT
    into internal_name, source_table, model_name,
         dims, model_dims, reduce_mode,
         sel_type, cat_state,
         graph_iri, pred_iri,
         key_var, embedding_var, where_pattern_blob,
         where_text, build_mode, dataset_text
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  if (cat_state = 'creating')
    signal ('VEC30', sprintf ('Vector index <%s> is still being created', idx_iri));
  if (cat_state = 'dropped')
    signal ('VEC31', sprintf ('Vector index <%s> has been dropped', idx_iri));

  -- Resolve model
  resolved := DB.DBA.VEC_INDEX_RESOLVE_MODEL (model_name);
  model_handle := cast (resolved[0] as integer);
  model_type := cast (resolved[2] as varchar);
  if (model_handle <= 0 and model_type not in ('openai', 'ollama', 'lmstudio', 'openai_compatible', 'test_embedding', 'vvec_test_embedding'))
    signal ('VEC33', sprintf ('Model %s not found in ONNX_MODELS for vector index <%s>', model_name, idx_iri));
  -- The model's native output dim must match the index's native dim. For a
  -- reduced index the stored dim (SVI_DIMENSIONS) is the reduced value, so we
  -- compare against SVI_MODEL_DIMENSIONS when it is known; otherwise we fall
  -- back to SVI_DIMENSIONS (older rows / no reduction) for backward compat.
  if (model_dims > 0)
    {
      if (cast (resolved[1] as integer) <> model_dims)
        signal ('VEC34', sprintf ('Model %s output dimension %d does not match index native dimension %d', model_name, resolved[1], model_dims));
    }
  else
    {
      if (cast (resolved[1] as integer) <> dims)
        signal ('VEC34', sprintf ('Model %s output dimension %d does not match index dimension %d', model_name, resolved[1], dims));
    }

  DB.DBA.VEC_INDEX_BEGIN_MUTATION (idx_iri, 'refreshing');
  mutation_started := 1;

  stale_count := 0;
  total_done := 0;
  refresh_note := null;

  -- For shorthand selector, enumerate (key, text) pairs straight from RDF_QUAD
  if ('shorthand' = sel_type)
    {
      declare enum_select varchar;

      -- The multiple-values-per-subject note used to be produced here by a
      -- GROUP BY ... HAVING over the whole graph.  That is a second full pass
      -- for one informational line, and it ran before the backfill's own clock
      -- started, so it did not even show up in the reported duration.  Dropped:
      -- nothing depended on the count but the note itself, and the enumeration
      -- now collapses repeated subjects through the staging primary key.

      -- Enumerate (key, RDF_OBJ id, fallback text) and backfill (streamed, no row cap).
      --
      -- output:valmode "LONG" makes SPARQL hand back its internal values: ?s is
      -- already an IRI_ID and ?text an rdf_box, so iri_id_num () reads the key
      -- directly with no iri_to_id () round trip per row, and rdf_box_ro_id ()
      -- sees the box it needs.  str (?text) cannot be used -- it destroys that
      -- box -- which is why the text itself is not projected.
      --
      -- No GROUP BY.  A subject with several values of the predicate needs one
      -- row, and BF_KID is already the staging table's primary key, so the
      -- INSERT SOFT collapses the duplicates as it streams.  Grouping in SQL
      -- instead meant materialising every (s, o) pair of the whole graph and
      -- hash-grouping it -- on a corpus with 8.7M multi-valued subjects that is
      -- tens of millions of rows for a result the primary key gives free.
      --
      -- rdf_box_ro_id () returns SQL NULL, not 0, for a value that is not an
      -- rdf_box at all (rdfbox.c:1006 returns a null pointer) -- a plain short
      -- literal with no language or datatype.  Without the coalesce, NULL = 0
      -- is UNKNOWN, fallback_text comes back NULL, and every such literal is
      -- dropped from the index on each refresh.
      -- No SPARQL.  input:storage "" already disables every quad map, so that
      -- query compiled down to exactly this scan -- the SPARQL parse, compile
      -- and generic quad access were pure overhead for a selector whose graph
      -- and predicate are both constants.  RDF_QUAD's primary key is
      -- (P, S, O, G) (sparql.sql:24), so a fixed predicate is one contiguous
      -- range and S, O come back as IRI_ID and rdf_box with no conversion.
      --
      -- Both ids are resolved once, with iri_to_id (..., 0) so a missing IRI is
      -- reported rather than silently created.  They are interpolated as
      -- strings: %d truncates through 32 bits and an IRI id does not fit.
      --
      -- isiri_id (O) excludes IRI objects: this index embeds text, and casting
      -- an IRI_ID to varchar would feed the model a bare number.
      g_id := iri_to_id (graph_iri, 0);
      p_id := iri_to_id (pred_iri, 0);
      if (g_id is null or p_id is null)
        signal ('VEC37', sprintf ('Vector index <%s>: graph <%s> or predicate <%s> is not a known IRI, so the selector matches nothing',
            idx_iri, graph_iri, pred_iri));
      enum_select := sprintf (
        'select iri_id_num (S), coalesce (rdf_box_ro_id (O), 0),' ||
        ' case when coalesce (rdf_box_ro_id (O), 0) = 0 then cast (O as varchar) else null end' ||
        ' from DB.DBA.RDF_QUAD table option (index RDF_QUAD)' ||
        ' where P = iri_id_from_num (%s) and G = iri_id_from_num (%s) and not isiri_id (O)',
        cast (iri_id_num (p_id) as varchar), cast (iri_id_num (g_id) as varchar));
      DB.DBA.VEC_INDEX_BACKFILL_PAGED (enum_select, internal_name, source_table,
        model_name, model_handle, model_type, total_done, stale_count, refresh_note, build_mode);
    }
  else if ('general' = sel_type)
    {
      declare enum_select varchar;
      -- Construct SPARQL query using stored WHERE text
      if (where_text is null or where_text = '')
        signal ('VEC37', sprintf ('No WHERE text stored for general selector of vector index <%s>', idx_iri));

      -- No duplicate-subject pre-scan here either; see the shorthand branch.

      -- Enumerate (key, text) pairs and backfill (streamed, keyset-paged, no row cap).
      --  The dataset clause goes after the projection and before WHERE, which
      --  is where SPARQL wants it; it is empty for a selector written without
      --  FROM, leaving the query byte-identical to what it was before.
      enum_select := sprintf (
        'select iri_id_num ("%s"), coalesce (rdf_box_ro_id ("%s"), 0),' ||
        ' case when coalesce (rdf_box_ro_id ("%s"), 0) = 0 then cast ("%s" as varchar) else null end ' ||
        'from (sparql define input:storage "" define output:valmode "LONG" %s' ||
        'select ?%s ?%s %s%s) as sub',
        key_var, embedding_var, embedding_var, embedding_var,
        coalesce (cast (where_pattern_blob as varchar), ''), key_var, embedding_var,
        coalesce (dataset_text, ''), where_text);
      DB.DBA.VEC_INDEX_BACKFILL_PAGED (enum_select, internal_name, source_table,
        model_name, model_handle, model_type, total_done, stale_count, refresh_note, build_mode);
    }
  else
    signal ('VEC39', sprintf ('Unknown selector type <%s> for vector index <%s>', sel_type, idx_iri));

  -- (Stale-key removal is performed inside VEC_INDEX_BACKFILL_PAGED via a set-based
  -- anti-join against the staging table, and reflected in stale_count above.)

  -- Mark as active with updated generation
  update DB.DBA.SPARQL_VEC_INDEX
  set SVI_REFRESHED = now (),
      SVI_GENERATION = SVI_GENERATION + 1
  where SVI_IRI = idx_iri;

  DB.DBA.VEC_INDEX_END_MUTATION (idx_iri, 'refreshing', 1, null);
  mutation_started := 0;

  -- The backfill's informational note -- today, an ONNX helper pool or batch
  -- limit it could not raise -- goes where an operator looks: the result, and
  -- SVI_LAST_ERROR (after END_MUTATION has cleared it).
  if (refresh_note is not null)
    {
      update DB.DBA.SPARQL_VEC_INDEX
        set SVI_LAST_ERROR = refresh_note
        where SVI_IRI = idx_iri;
      commit work;
    }

  return vector (vector ('00000', sprintf ('Vector index <%s> refreshed, %d rows processed, %d stale keys deleted%s',
    idx_iri, total_done, stale_count,
    case when refresh_note is not null then sprintf ('; %s', refresh_note) else '' end)));

cat_not_found:;
  update DB.DBA.SPARQL_VEC_INDEX
  set SVI_STATE = 'error',
      SVI_LAST_ERROR = 'catalog record not found during refresh'
  where SVI_IRI = idx_iri;
  DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;
  signal ('VEC32', sprintf ('Vector index <%s> not found', idx_iri));
}
;

-- Drop a vector index.
-- Removes catalog record, work queue entries, native vector index, and backing table.
create procedure DB.DBA.VEC_INDEX_DROP (in idx_iri varchar, in silent integer) returns any
{
  declare internal_name, source_table, STATE varchar;
  declare MESSAGE varchar;
  declare stmt_state varchar;
  declare ddl_text varchar;
  declare md, rs any;
  declare mutation_started integer;

  declare exit handler for sqlstate '*'
    {
      if (mutation_started)
        DB.DBA.VEC_INDEX_END_MUTATION (idx_iri, 'dropping', 0, __SQL_MESSAGE);
      resignal;
    };

  mutation_started := 0;

  whenever not found goto not_found;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE, SVI_STATE
    into internal_name, source_table, STATE
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  if (STATE = 'active')
    {
      DB.DBA.VEC_INDEX_BEGIN_MUTATION (idx_iri, 'dropping');
      mutation_started := 1;
    }

  -- Drop native vector index (use DROP INDEX since SQL grammar has no DROP VECTOR INDEX)
  -- Skip if state is 'creating' (index was never fully created)
  if (STATE <> 'creating')
    {
      ddl_text := sprintf ('drop index %s', internal_name);
      stmt_state := '00000';
      exec (ddl_text, stmt_state, MESSAGE, vector (), 10000, md, rs);
      -- Tolerate errors silently to avoid crashes from nested exec in QM handler
    }

  -- Drop backing source table
  ddl_text := sprintf ('drop table %s', source_table);
  stmt_state := '00000';
  exec (ddl_text, stmt_state, MESSAGE, vector (), 10000, md, rs);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (stmt_state) and silent = 0 and STATE = 'active')
    signal ('VEC41', sprintf ('Failed to drop backing table for <%s>: %s %s', idx_iri, stmt_state, MESSAGE));

  -- Remove work queue entries
  delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_INDEX_IRI = idx_iri;

  -- Remove general-selector trigger rows
  delete from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI = idx_iri;

  -- Remove catalog record
  delete from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;
  mutation_started := 0;
  return vector (vector ('00000', sprintf ('Vector index <%s> dropped', idx_iri)));

not_found:;
  if (silent = 1)
    return vector (vector ('00000', sprintf ('Vector index <%s> does not exist (silent)', idx_iri)));
  signal ('VEC42', sprintf ('Vector index <%s> not found', idx_iri));
}
;

-- Search a vector index: embed query text and run HNSW search.
-- Returns a vector of (row_id, distance) pairs, sorted by ascending distance.
create function DB.DBA.VEC_INDEX_SEARCH (
  in idx_iri varchar,
  in query_text varchar,
  in limit_count integer := 10,
  in ef_search integer := 100 ) returns any
{
  declare internal_name, cat_state, graph_iri varchar;
  declare query_embed any;
  declare results any;

  if (not user_is_dba (user))
    signal ('VEC54', 'DB.DBA.VEC_INDEX_SEARCH is DBA-only; use the SPARQL vector-search interface for graph-permission checked search');
  if (limit_count <= 0 or limit_count > 10000)
    signal ('VEC55', 'limit must be a positive integer not greater than 10000');
  if (ef_search < limit_count or ef_search > 100000)
    signal ('VEC56', 'ef_search must be at least limit and not greater than 100000');

  whenever not found goto search_not_found;
  select SVI_INTERNAL_NAME, SVI_STATE, SVI_SELECTOR_GRAPH
    into internal_name, cat_state, graph_iri
    from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  if (cat_state <> 'active')
    signal ('VEC50', sprintf ('Vector index <%s> is not active (state: %s)', idx_iri, cat_state));
  if (graph_iri is not null and not DB.DBA.VEC_INDEX_GRAPH_READABLE (graph_iri))
    signal ('VEC57', sprintf ('No read permission for graph <%s>', graph_iri));

  -- Embed the query text using the native vector format (same path as VEC_INDEX_SEARCH_ROWS)
  query_embed := __VEC_INDEX_QUERY_TEXT_VECTOR (internal_name, query_text);
  if (query_embed is null)
    signal ('VEC52', sprintf ('Failed to embed query text for vector index <%s>', idx_iri));

  -- Search the native vector index
  results := __VEC_INDEX_SEARCH (internal_name, query_embed, limit_count, ef_search);

  return results;

search_not_found:;
  signal ('VEC53', sprintf ('Vector index <%s> not found', idx_iri));
}
;

create function DB.DBA.VEC_INDEX_INFER_SEARCH_INDEX (
  in idx_iri any ) returns varchar
{
  declare idx_count integer;
  declare inferred_iri varchar;

  if (idx_iri is not null and cast (idx_iri as varchar) <> '')
    return cast (idx_iri as varchar);

  select count (*), min (SVI_IRI)
    into idx_count, inferred_iri
    from DB.DBA.SPARQL_VEC_INDEX
    where SVI_STATE = 'active';

  if (idx_count = 1)
    return inferred_iri;
  if (idx_count = 0)
    signal ('VEC58', 'bif:vector_search requires an INDEX option because no active vector index can be inferred');
  signal ('VEC59', sprintf ('bif:vector_search requires an INDEX option because %d active vector indexes are available', idx_count));
}
;

create function DB.DBA.VEC_INDEX_VALIDATE_SEARCH_OPTIONS (
  in idx_iri any,
  in score_limit any,
  in distance_limit any,
  in limit_count integer,
  in ef_search integer ) returns varchar
{
  declare resolved_iri, metric varchar;
  declare score_val, distance_val double precision;

  resolved_iri := DB.DBA.VEC_INDEX_INFER_SEARCH_INDEX (idx_iri);

  if (limit_count is null or limit_count <= 0 or limit_count > 10000)
    signal ('VEC55', 'limit must be a positive integer not greater than 10000');
  if (ef_search is null or ef_search < limit_count or ef_search > 100000)
    signal ('VEC56', 'ef_search must be at least limit and not greater than 100000');

  whenever not found goto search_not_found;
  select SVI_DISTANCE
    into metric
    from DB.DBA.SPARQL_VEC_INDEX
    where SVI_IRI = resolved_iri and SVI_STATE = 'active';

  if (score_limit is not null)
    {
      score_val := cast (score_limit as double precision);
      if (not isfinitenumeric (score_val))
        signal ('VEC60', 'score_limit must be finite');
      if ('cosine' = metric)
        {
          if (score_val < 0.0 or score_val > 1.0)
            signal ('VEC61', 'cosine score_limit must be between 0 and 1 inclusive');
        }
      else if (metric in ('l1', 'l2'))
        {
          if (score_val < 0.0 or score_val > 1.0)
            signal ('VEC62', 'l1/l2 score_limit must be between 0 and 1 inclusive');
        }
      else
        signal ('VEC63', sprintf ('Unsupported vector index distance metric: %s', metric));
    }

  if (distance_limit is not null)
    {
      distance_val := cast (distance_limit as double precision);
      if (not isfinitenumeric (distance_val))
        signal ('VEC64', 'distance_limit must be finite');
      if (distance_val < 0.0)
        signal ('VEC65', 'distance_limit must be greater than or equal to 0');
    }

  return resolved_iri;

search_not_found:;
  signal ('VEC53', sprintf ('Vector index <%s> not found or not active', resolved_iri));
}
;

create function DB.DBA.VEC_INDEX_HIT_READABLE (
  in idx_iri varchar,
  in rid bigint,
  in required_graph_iri varchar := null ) returns integer
{
  declare sel_type, graph_iri, pred_iri, key_var, where_text varchar;
  declare where_prefixes_blob any;
  declare q_state, q_msg varchar;
  declare q_meta, qr any;
  declare qtext varchar;

  whenever not found goto not_readable;
  select SVI_SELECTOR_TYPE, SVI_SELECTOR_GRAPH, SVI_SELECTOR_PRED, SVI_KEY_VAR, SVI_WHERE_TEXT, SVI_WHERE_PATTERN
    into sel_type, graph_iri, pred_iri, key_var, where_text, where_prefixes_blob
    from DB.DBA.SPARQL_VEC_INDEX
    where SVI_IRI = idx_iri and SVI_STATE = 'active';

  if (required_graph_iri is not null and required_graph_iri <> '')
    {
      if (not user_is_dba (user) and not DB.DBA.VEC_INDEX_GRAPH_READABLE (required_graph_iri))
        return 0;
    }

  if ('shorthand' = sel_type)
    {
      if (graph_iri is null or pred_iri is null)
        return 0;
      if (required_graph_iri is not null and required_graph_iri <> '' and required_graph_iri <> graph_iri)
        return 0;
      if (not user_is_dba (user) and not DB.DBA.VEC_INDEX_GRAPH_READABLE (graph_iri))
        return 0;
      if (exists (
        select 1
          from DB.DBA.RDF_QUAD
          where G = iri_to_id (graph_iri)
            and P = iri_to_id (pred_iri)
            and S = iri_id_from_num (rid) ))
        return 1;
      return 0;
    }

  if ('general' = sel_type)
    {
      if (key_var is null or key_var = '' or where_text is null or where_text = '')
        return 0;
      qtext := sprintf (
        'select top 1 1 from (sparql define input:storage "" %sselect ?%s %s) as sub where iri_id_num (iri_to_id ("%s")) = %d',
        coalesce (cast (where_prefixes_blob as varchar), ''), key_var, where_text, key_var, rid);
      exec (qtext, q_state, q_msg, vector (), 1, q_meta, qr);
      if (q_state <> '00000' and q_state <> 0)
        return 0;
      if (length (qr) = 0)
        return 0;
      if (required_graph_iri is not null and required_graph_iri <> '' and
        not exists (
          select 1
            from DB.DBA.RDF_QUAD
            where G = iri_to_id (required_graph_iri)
              and S = iri_id_from_num (rid) ))
        return 0;
      return 1;
    }

  return 0;

not_readable:;
  return 0;
}
;

-- One index's hits, as a vector of vector (rid, distance, score) in the index's
-- own best-first order, after the graph-permission and score/distance filters.
--
-- Extracted from VEC_INDEX_SEARCH_ROWS rather than copied, so the single-index
-- path and the multi-index one cannot drift apart: everything that makes a hit
-- visible or not -- the required-graph match, the per-hit readability check
-- that re-runs the selector, the score and distance thresholds -- is decided
-- here, once.
--
-- The caller has already validated the index through
-- VEC_INDEX_VALIDATE_SEARCH_OPTIONS; this re-reads the catalogue row it needs
-- and returns an EMPTY vector, not an error, for the two "you may not see this"
-- cases, which is what makes an unreadable index contribute nothing rather than
-- fail the whole query.
create function DB.DBA.VEC_INDEX_SEARCH_HITS (
  in idx_iri varchar,
  in query_text varchar,
  in limit_count integer,
  in ef_search integer,
  in score_limit double precision := null,
  in distance_limit double precision := null,
  in required_graph_iri varchar := null ) returns any
{
  declare hits, out_hits any;
  declare i, len integer;
  declare row any;
  declare rid bigint;
  declare dist, score double precision;
  declare internal_name, metric, cat_state, sel_type, graph_iri varchar;
  declare query_embed any;

  out_hits := vector ();

  select SVI_INTERNAL_NAME, SVI_DISTANCE, SVI_STATE, SVI_SELECTOR_TYPE, SVI_SELECTOR_GRAPH
    into internal_name, metric, cat_state, sel_type, graph_iri
    from DB.DBA.SPARQL_VEC_INDEX
    where SVI_IRI = idx_iri;

  if (cat_state <> 'active')
    signal ('VEC50', sprintf ('Vector index <%s> is not active (state: %s)', idx_iri, cat_state));
  if (required_graph_iri is not null and required_graph_iri <> '' and 'shorthand' = sel_type and required_graph_iri <> graph_iri)
    return out_hits;
  if (not user_is_dba (user) and 'shorthand' = sel_type and not DB.DBA.VEC_INDEX_GRAPH_READABLE (graph_iri))
    return out_hits;

  query_embed := __VEC_INDEX_QUERY_TEXT_VECTOR (internal_name, query_text);
  if (query_embed is null)
    signal ('VEC52', sprintf ('Failed to embed query text for vector index <%s>', idx_iri));

  hits := __VEC_INDEX_SEARCH (internal_name, query_embed, limit_count, ef_search);
  len := length (hits);
  for (i := 0; i < len; i := i + 1)
    {
      row := hits[i];
      rid := cast (row[0] as bigint);
      dist := cast (row[1] as double precision);
      if (not DB.DBA.VEC_INDEX_HIT_READABLE (idx_iri, rid, required_graph_iri))
        goto next_hit;
      score := DB.DBA.VEC_INDEX_DISTANCE_TO_SCORE (metric, dist);
      if (score_limit is not null and score < score_limit)
        goto next_hit;
      if (distance_limit is not null and dist > distance_limit)
        goto next_hit;
      out_hits := vector_concat (out_hits, vector (vector (rid, dist, score)));
next_hit:;
    }
  return out_hits;
}
;

create procedure DB.DBA.VEC_INDEX_SEARCH_ROWS (
  in idx_iri varchar,
  in query_text varchar,
  in limit_count integer := 10,
  in ef_search integer := 100,
  in score_limit double precision := null,
  in distance_limit double precision := null,
  in required_graph_iri varchar := null )
{
  declare hits any;
  declare i, len integer;
  declare resolved_iri varchar;
  declare result_entity_iid any;
  declare result_distance, result_score double precision;
  result_names (result_entity_iid, result_distance, result_score);

  resolved_iri := DB.DBA.VEC_INDEX_VALIDATE_SEARCH_OPTIONS (idx_iri, score_limit, distance_limit, limit_count, ef_search);

  hits := DB.DBA.VEC_INDEX_SEARCH_HITS (resolved_iri, query_text, limit_count, ef_search,
    score_limit, distance_limit, required_graph_iri);
  len := length (hits);
  for (i := 0; i < len; i := i + 1)
    result (iri_id_from_num (cast (hits[i][0] as bigint)),
      cast (hits[i][1] as double precision),
      cast (hits[i][2] as double precision));
}
;

-- Every index `option (index *)` covers: active, and over a graph the caller may
-- read.
--
-- Expanded HERE, at execution time, not in the SQL generator.  Virtuoso caches
-- a compiled SPARQL plan by query text, so a wildcard resolved at compile time
-- would bake the first caller's set of indexes into the plan every other caller
-- then reuses -- two users running the same `index *` query must get their own
-- answers.
--
-- Correctness does not depend on this filter: a hit from a graph the caller
-- cannot read is dropped per row by VEC_INDEX_HIT_READABLE either way.  What it
-- buys is not doing the work -- an embedding and an ANN search per index -- for
-- indexes that can only return nothing, and not leaking which indexes exist
-- through error messages and timing.
--
-- GENERAL SELECTORS ARE INCLUDED.  They have no SVI_SELECTOR_GRAPH to check --
-- their dataset is free text -- and there is no honest way to filter them here.
-- Excluding them would make `*` quietly mean "some of them"; including them
-- leaves the per-row check to do its job, which it does.
create function DB.DBA.VEC_INDEX_EXPAND_SEARCH_INDEXES () returns any
{
  declare out_list any;
  out_list := vector ();
  for (select SVI_IRI as _iri, SVI_SELECTOR_TYPE as _sel, SVI_SELECTOR_GRAPH as _g
         from DB.DBA.SPARQL_VEC_INDEX
        where SVI_STATE = 'active'
        order by SVI_IRI) do
    {
      if (not user_is_dba (user) and 'shorthand' = _sel
          and not DB.DBA.VEC_INDEX_GRAPH_READABLE (_g))
        goto next_idx;
      out_list := vector_concat (out_list, vector (_iri));
   next_idx:;
    }
  return out_list;
}
;

-- Is hit A better than hit B, under one of the two orderings?
--
-- A hit is vector (rid, distance, score, rank, idx_iri): `rank` is its position
-- within its OWN index's result list, `idx_iri` the index it came from.
--
--   'raw'        highest score first.  The same measurement only when every
--                index shares a model and a metric, which is why the caller is
--                refused a mixed set under this ordering.
--   'relevance'  best position within its own index first, ties broken by
--                score.  Reciprocal-rank fusion in its simplest form: every hit
--                belongs to exactly one list, so 1/(k+rank) is monotonic in
--                rank.  Comparable across models by construction, which raw
--                score is not.
--
-- The last tie-break is the index IRI, so that a query over the same data
-- returns the same order twice rather than whichever index happened to be read
-- first.
create function DB.DBA.VEC_INDEX_HIT_BETTER (in a any, in b any, in ranking_mode varchar) returns integer
{
  declare a_score, b_score double precision;
  declare a_rank, b_rank integer;
  a_score := cast (a[2] as double precision);
  b_score := cast (b[2] as double precision);
  a_rank := cast (a[3] as integer);
  b_rank := cast (b[3] as integer);
  if ('relevance' = ranking_mode)
    {
      if (a_rank <> b_rank)
        return case when a_rank < b_rank then 1 else 0 end;
      if (a_score <> b_score)
        return case when a_score > b_score then 1 else 0 end;
    }
  else
    {
      if (a_score <> b_score)
        return case when a_score > b_score then 1 else 0 end;
      if (a_rank <> b_rank)
        return case when a_rank < b_rank then 1 else 0 end;
    }
  return case when cast (a[4] as varchar) < cast (b[4] as varchar) then 1 else 0 end;
}
;

-- bif:vector_search over several indexes at once:
--
--   option (index (<a>, <b>))            the union of the named indexes
--   option (index *)                     every active index the caller can read
--   option (index (<a>, <b>), ranking raw | relevance)
--
-- `limit` means N results IN TOTAL, not N per index -- which is what a caller
-- writing `limit 10` expects and what it already means for one index.  It costs
-- no accuracy: the top N of the union of each index's top N is exactly the top
-- N of the union of everything.
--
-- A subject that sits in two indexes comes back ONCE, as its best occurrence
-- under the active ordering, with that row's score and distance.  This binds a
-- subject variable: the same subject twice would make `limit 10` return ten
-- rows covering fewer than ten things, and multiply every downstream join.
-- (The VVec console shows one row per index-hit instead, because its job is to
-- show which index a hit came from.  Deliberate difference, not an oversight.)
create procedure DB.DBA.VEC_INDEX_SEARCH_ROWS_MULTI (
  in idx_list any,
  in ranking_mode varchar,
  in query_text varchar,
  in limit_count integer := 10,
  in ef_search integer := 100,
  in score_limit double precision := null,
  in distance_limit double precision := null,
  in required_graph_iri varchar := null )
{
  declare iris, keys, hits, merged, best_of any;
  declare i, j, n, len, kept integer;
  declare iri, ref_model, ref_metric varchar;
  declare model_name, metric varchar;
  declare rid bigint;
  declare hit, cur any;
  declare result_entity_iid any;
  declare result_distance, result_score double precision;
  result_names (result_entity_iid, result_distance, result_score);

  ranking_mode := lower (trim (coalesce (ranking_mode, 'raw')));
  if (ranking_mode not in ('raw', 'relevance'))
    signal ('VEC66', sprintf ('Unsupported ranking mode: %s (expected raw or relevance)', ranking_mode));

  -- Resolve the index set.  '*' is the wildcard; anything else is the list the
  -- caller named, with duplicates collapsed so `index (<a>, <a>)` is `index <a>`.
  if (isstring (idx_list) and idx_list = '*')
    iris := DB.DBA.VEC_INDEX_EXPAND_SEARCH_INDEXES ();
  else if (isvector (idx_list))
    {
      iris := vector ();
      for (i := 0; i < length (idx_list); i := i + 1)
        {
          iri := cast (idx_list[i] as varchar);
          for (j := 0; j < length (iris); j := j + 1)
            if (iris[j] = iri) goto dup_iri;
          iris := vector_concat (iris, vector (iri));
       dup_iri:;
        }
    }
  else
    signal ('VEC67', 'bif:vector_search: the index option resolved to neither a list of IRIs nor the * wildcard');

  -- No accessible index is not an error.  An empty instance and an instance
  -- where you may see nothing have to look the same to the caller, or the
  -- difference between them is readable from the error.
  n := length (iris);
  if (n = 0)
    return;

  -- Per index, exactly the validation the single-index path applies -- so an
  -- index that does not exist, or is not active, fails with the same error
  -- naming the same index.
  for (i := 0; i < n; i := i + 1)
    DB.DBA.VEC_INDEX_VALIDATE_SEARCH_OPTIONS (iris[i], score_limit, distance_limit, limit_count, ef_search);

  -- Comparability.  Raw scores are the same measurement only when the indexes
  -- share a model AND a metric: measured on one instance, one model scores a
  -- nonsense query at 0.47-0.53 while another scores the same query at
  -- 0.56-0.61, so a union ordered by raw score is ordered by model rather than
  -- by relevance.  score_limit and distance_limit are thresholds in those same
  -- units, so they need the same agreement.
  --
  -- Relevance ranking needs none of this, so the refusal names the way out
  -- rather than just the problem.
  if ('raw' = ranking_mode or score_limit is not null or distance_limit is not null)
    {
      ref_model := null; ref_metric := null;
      for (i := 0; i < n; i := i + 1)
        {
          select SVI_MODEL_NAME, SVI_DISTANCE into model_name, metric
            from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = iris[i];
          if (i = 0)
            { ref_model := model_name; ref_metric := metric; }
          else if (model_name <> ref_model)
            signal ('VEC68', sprintf (
              'Vector indexes <%s> and <%s> use different embedding models (%s and %s), so their scores are not comparable. Use ranking relevance to merge them by rank within each index, or drop score_limit / distance_limit.',
              iris[0], iris[i], ref_model, model_name));
          else if (metric <> ref_metric)
            signal ('VEC68', sprintf (
              'Vector indexes <%s> and <%s> use different distance metrics (%s and %s), so their scores are not comparable. Use ranking relevance to merge them by rank within each index, or drop score_limit / distance_limit.',
              iris[0], iris[i], ref_metric, metric));
        }
    }

  -- Search each index, tagging every hit with its position within that index.
  merged := vector ();
  for (i := 0; i < n; i := i + 1)
    {
      hits := DB.DBA.VEC_INDEX_SEARCH_HITS (iris[i], query_text, limit_count, ef_search,
        score_limit, distance_limit, required_graph_iri);
      len := length (hits);
      for (j := 0; j < len; j := j + 1)
        merged := vector_concat (merged, vector (
          vector (hits[j][0], hits[j][1], hits[j][2], j + 1, iris[i])));
    }

  -- One row per subject: the best occurrence wins, and carries its own score
  -- and distance so the row stays internally consistent.
  best_of := dict_new (71);
  len := length (merged);
  for (i := 0; i < len; i := i + 1)
    {
      hit := merged[i];
      rid := cast (hit[0] as bigint);
      cur := dict_get (best_of, rid, null);
      if (cur is null or DB.DBA.VEC_INDEX_HIT_BETTER (hit, cur, ranking_mode))
        dict_put (best_of, rid, hit);
    }
  -- dict_list_keys returns the KEYS -- its second argument is "destructive",
  -- not a mode -- so the surviving hits are fetched back one by one.
  keys := dict_list_keys (best_of, 0);
  merged := vector ();
  for (i := 0; i < length (keys); i := i + 1)
    merged := vector_concat (merged, vector (dict_get (best_of, keys[i], null)));

  -- Partial selection sort: limit_count passes over the merged set rather than
  -- a full sort of it, since only the top limit_count is ever emitted.
  n := length (merged);
  kept := limit_count;
  if (kept > n)
    kept := n;
  for (i := 0; i < kept; i := i + 1)
    {
      declare bestn integer;
      bestn := i;
      for (j := i + 1; j < n; j := j + 1)
        if (DB.DBA.VEC_INDEX_HIT_BETTER (merged[j], merged[bestn], ranking_mode))
          bestn := j;
      if (bestn <> i)
        {
          hit := merged[i];
          aset (merged, i, merged[bestn]);
          aset (merged, bestn, hit);
        }
      hit := merged[i];
      result (iri_id_from_num (cast (hit[0] as bigint)),
        cast (hit[1] as double precision),
        cast (hit[2] as double precision));
    }
}
;

-- Convert a native distance to a higher-is-better score, from 0 to 1.
-- cosine: score = 1 - cosine_distance / 2
-- L1/L2:  score = 1 / (1 + distance)
-- The scale SQL's X_SIMILAR and SPARQL's bif:knnSimilar use
-- (vvec_similarity_from_distance, vvec.c), clamped the same way, so one
-- document scores the same on every surface and a threshold means one thing.
-- Cosine used to be 1 - distance, from -1 to 1.
create function DB.DBA.VEC_INDEX_DISTANCE_TO_SCORE (
  in dist_metric varchar,
  in distance double precision ) returns double precision
{
  declare score double precision;
  if ('cosine' = dist_metric)
    score := 1.0 - distance / 2.0;
  else
    score := 1.0 / (1.0 + distance);
  if (score < 0.0)
    return 0.0;
  if (score > 1.0)
    return 1.0;
  return score;
}
;

-- ============== Async Queue Procedures ==============

-- Global flag for suspending queue processing (useful for bulk loads)
-- Stored in registry table for persistence across connections.
create procedure DB.DBA.VEC_INDEX_QUEUE_SUSPEND ()
{
  registry_set ('__vec_queue_suspended', '1');
}
;

create procedure DB.DBA.VEC_INDEX_QUEUE_RESUME ()
{
  registry_set ('__vec_queue_suspended', '0');
}
;

create function DB.DBA.VEC_INDEX_QUEUE_IS_SUSPENDED () returns integer
{
  declare val varchar;
  val := registry_get ('__vec_queue_suspended');
  if (val = '1')
    return 1;
  return 0;
}
;

-- Refresh the registry flag that indicates whether any active async
-- vector indexes exist (shorthand or general).  Called after every state
-- transition on SPARQL_VEC_INDEX so that VEC_INDEX_HAS_ACTIVE_ASYNC() stays
-- current.  The per-triple hot-path guard in TTLP/SPARQL DML reads this flag.
create procedure DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ()
{
  declare cnt integer;
  cnt := (select count(*) from DB.DBA.SPARQL_VEC_INDEX
           where SVI_STATE = 'active'
             and SVI_MAINTENANCE = 'async');
  registry_set ('__vec_active_async', case when cnt > 0 then '1' else '0' end);
  -- Invalidate the cached query plans of the enqueue procedures.  They are
  -- compiled at bootstrap when SPARQL_VEC_INDEX(_TRIGGER) are empty, and the
  -- plan cached then returns no rows once the tables are populated -- so a
  -- change matching an async index was silently never enqueued.  Table-level
  -- __ddl_changed does not clear these; __proc_changed on the procedures does.
  -- This runs on every async-index state transition (create/activate/drop),
  -- exactly when the plans must be re-formed against the populated tables.
  __proc_changed ('DB.DBA.VEC_INDEX_ENQUEUE');
  __proc_changed ('DB.DBA.VEC_INDEX_ENQUEUE_RDF_CHANGE');
  __proc_changed ('DB.DBA.VEC_INDEX_ENQUEUE_RDF_BATCH');
  __proc_changed ('DB.DBA.VEC_INDEX_QUEUE_PROCESS_ONE');
}
;

-- Cheap guard: returns 1 if any active async vector index exists (shorthand or
-- general).  Uses a registry-cached flag so the check is a single in-memory
-- lookup with no SQL query -- safe to call per-triple in the TTLP bulk loader.
create function DB.DBA.VEC_INDEX_HAS_ACTIVE_ASYNC () returns integer
{
  declare val varchar;
  val := registry_get ('__vec_active_async');
  if (val = '1')
    return 1;
  return 0;
}
;

-- Enqueue a key for async maintenance.
-- Deduplicates by (index_iri, key_id) via primary key.
-- If the key already exists in the queue, increments retry count.
create procedure DB.DBA.VEC_INDEX_ENQUEUE (
  in idx_iri varchar,
  in key_id bigint )
{
  declare idx_state varchar;
  declare maint_mode varchar;

  -- Suspension gates draining (VEC_INDEX_QUEUE_PROCESS_ONE), not enqueuing:
  -- a change made while the queue is suspended must still be captured or it
  -- would be lost on resume.  Do not add a suspend guard here.

  -- Check index exists and is async-maintained
  whenever not found goto skip;
  select SVI_STATE, SVI_MAINTENANCE into idx_state, maint_mode
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;
  if (maint_mode <> 'async')
    return;
  if (idx_state <> 'active')
    return;

  -- Upsert into queue (deduplicate by PK)
  insert soft SPARQL_VEC_QUEUE (SVQ_INDEX_IRI, SVQ_KEY_ID, SVQ_QUEUED, SVQ_STATE)
    values (idx_iri, key_id, now (), 'pending');
  -- If insert was suppressed (duplicate), update queued time and reset to pending
  update DB.DBA.SPARQL_VEC_QUEUE
    set SVQ_QUEUED = now (), SVQ_STATE = 'pending'
    where SVQ_INDEX_IRI = idx_iri and SVQ_KEY_ID = key_id;

skip:;
}
;

create procedure DB.DBA.VEC_INDEX_ENQUEUE_RDF_CHANGE (
  in graph_id IRI_ID,
  in subj_id IRI_ID,
  in pred_id IRI_ID )
{
  declare graph_iri, pred_iri varchar;
  declare key_id bigint;

  -- Suspension gates draining (VEC_INDEX_QUEUE_PROCESS_ONE), not enqueuing:
  -- a change made while the queue is suspended must still be captured or it
  -- would be lost on resume.  Do not add a suspend guard here.
  if (not DB.DBA.VEC_INDEX_HAS_ACTIVE_ASYNC ())
    return;

  -- id_to_iri returns an IRI-typed string that does NOT compare equal to a
  -- plain VARCHAR column (SVT_GRAPH_IRI, SVI_SELECTOR_GRAPH, ...), so the match
  -- queries below silently found nothing and no change was ever enqueued.
  -- Cast to varchar so the comparisons work.
  graph_iri := cast (id_to_iri (graph_id) as varchar);
  pred_iri := cast (id_to_iri (pred_id) as varchar);
  key_id := iri_id_num (subj_id);

  -- Shorthand async indexes: match on the fixed (graph, predicate) pair.
  for select SVI_IRI
      from DB.DBA.SPARQL_VEC_INDEX
      where SVI_STATE = 'active'
        and SVI_MAINTENANCE = 'async'
        and SVI_SELECTOR_TYPE = 'shorthand'
        and SVI_SELECTOR_GRAPH = graph_iri
        and SVI_SELECTOR_PRED = pred_iri do
    {
      DB.DBA.VEC_INDEX_ENQUEUE (SVI_IRI, key_id);
    }

  -- General async indexes: match against the (graph, predicate) trigger
  -- dependency set extracted from the WHERE pattern at parse time.  A trigger
  -- row with SVT_PRED_IRI = '' is the graph-only fallback (matches any
  -- predicate in that graph); a row with a real IRI is predicate-precise.
  -- The changed subject is enqueued as the candidate key and the existing
  -- processing path (VEC_INDEX_QUEUE_PROCESS_ONE) re-evaluates the full WHERE
  -- for that single key, upserting if it still matches or deleting if not.
  -- Two plain-equality loops rather than one "SVT_PRED_IRI in ('', pred_iri)"
  -- (or the equivalent OR).  Both the OR and the IN forms compile, at bootstrap
  -- time when SPARQL_VEC_INDEX_TRIGGER is empty, to a plan that then returns no
  -- rows once the table is populated -- so a real change was never enqueued and
  -- every async-general test that relied on it failed.  Simple equality joins
  -- plan correctly across the empty->populated transition.  A subject that
  -- matches both a precise and a graph-only trigger for the same index enqueues
  -- twice, which is harmless: VEC_INDEX_ENQUEUE deduplicates by primary key.
  --
  -- Predicate-precise triggers (SVT_PRED_IRI = the changed predicate):
  for select t.SVT_INDEX_IRI as SVT_INDEX_IRI
      from DB.DBA.SPARQL_VEC_INDEX_TRIGGER t, DB.DBA.SPARQL_VEC_INDEX i
      where t.SVT_GRAPH_IRI = graph_iri
        and t.SVT_PRED_IRI = pred_iri
        and i.SVI_IRI = t.SVT_INDEX_IRI
        and i.SVI_STATE = 'active'
        and i.SVI_MAINTENANCE = 'async'
        and i.SVI_SELECTOR_TYPE = 'general' do
    {
      -- The FOR-loop variable is the unqualified column name; referencing it
      -- as t.SVT_INDEX_IRI raised SQ062 at runtime.
      DB.DBA.VEC_INDEX_ENQUEUE (SVT_INDEX_IRI, key_id);
    }
  -- Graph-only fallback triggers (SVT_PRED_IRI = '', match any predicate):
  for select t.SVT_INDEX_IRI as SVT_INDEX_IRI
      from DB.DBA.SPARQL_VEC_INDEX_TRIGGER t, DB.DBA.SPARQL_VEC_INDEX i
      where t.SVT_GRAPH_IRI = graph_iri
        and t.SVT_PRED_IRI = ''
        and i.SVI_IRI = t.SVT_INDEX_IRI
        and i.SVI_STATE = 'active'
        and i.SVI_MAINTENANCE = 'async'
        and i.SVI_SELECTOR_TYPE = 'general' do
    {
      DB.DBA.VEC_INDEX_ENQUEUE (SVT_INDEX_IRI, key_id);
    }
}
;

create procedure DB.DBA.VEC_INDEX_ENQUEUE_RDF_BATCH (
  in graph_id any,
  in triples any,
  in has_graph integer )
{
  declare ctr, len integer;

  -- Suspension gates draining (VEC_INDEX_QUEUE_PROCESS_ONE), not enqueuing:
  -- a change made while the queue is suspended must still be captured or it
  -- would be lost on resume.  Do not add a suspend guard here.
  if (not DB.DBA.VEC_INDEX_HAS_ACTIVE_ASYNC ())
    return;
  if (triples is null or not isarray (triples))
    return;

  len := length (triples);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      declare t any;
      declare g, s, p any;
      t := triples[ctr];
      if (not isarray (t) or length (t) < 3)
        goto next_triple;
      s := t[0];
      p := t[1];
      if (has_graph and length (t) > 3)
        g := t[3];
      else
        g := graph_id;
      -- The SPARQL update path (SPARQL_INSERT_DICT_CONTENT) passes the graph as
      -- a string, not an IRI_ID, so the isiri_id(g) guard below dropped every
      -- change from `sparql insert data`.  Resolve a string graph to its id.
      if (not isiri_id (g) and isstring (g))
        g := iri_to_id (g, 0);
      if (isiri_id (g) and isiri_id (s) and isiri_id (p))
        DB.DBA.VEC_INDEX_ENQUEUE_RDF_CHANGE (g, s, p);
next_triple: ;
    }
}
;

-- Process a single queue item: re-evaluate selector for one key.
-- Returns 1 if processed, 0 if no item found.
create function DB.DBA.VEC_INDEX_QUEUE_PROCESS_ONE () returns integer
{
  declare idx_iri varchar;
  declare key_id bigint;
  declare qid integer;
  declare internal_name, source_table, model_name, sel_type varchar;
  declare graph_iri, pred_iri varchar;
  declare dims, model_handle integer;
  declare dist_metric, cat_state, model_type varchar;
  declare resolved any;
  declare qtext, q_state, q_msg varchar;
  declare qr, q_meta any;
  declare txt varchar;
  declare txt_hash varchar;
  declare need_update integer;
  declare existing_hash varchar;
  declare embeds any;
  declare key_var, embedding_var, where_text varchar;
  declare where_pattern_blob any;

  if (DB.DBA.VEC_INDEX_QUEUE_IS_SUSPENDED ())
    return 0;

  -- Pick the oldest pending item
  whenever not found goto none;
  select top 1 SVQ_ID, SVQ_INDEX_IRI, SVQ_KEY_ID
    into qid, idx_iri, key_id
  from DB.DBA.SPARQL_VEC_QUEUE where SVQ_STATE = 'pending'
  order by SVQ_QUEUED;

  -- Mark as processing
  update DB.DBA.SPARQL_VEC_QUEUE set SVQ_STATE = 'processing'
    where SVQ_ID = qid;
  commit work;

  -- Load catalog
  whenever not found goto fail;
  select SVI_INTERNAL_NAME, SVI_SOURCE_TABLE, SVI_MODEL_NAME,
         SVI_DIMENSIONS, SVI_DISTANCE, SVI_SELECTOR_TYPE, SVI_STATE,
         SVI_SELECTOR_GRAPH, SVI_SELECTOR_PRED,
         SVI_KEY_VAR, SVI_EMBEDDING_VAR, SVI_WHERE_PATTERN, SVI_WHERE_TEXT
    into internal_name, source_table, model_name,
         dims, dist_metric, sel_type, cat_state,
         graph_iri, pred_iri,
         key_var, embedding_var, where_pattern_blob, where_text
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = idx_iri;

  if (cat_state <> 'active')
    goto done;

  DB.DBA.VEC_INDEX_BEGIN_MUTATION (idx_iri, 'draining');

  -- Resolve model
  resolved := DB.DBA.VEC_INDEX_RESOLVE_MODEL (model_name);
  model_handle := cast (resolved[0] as integer);
  model_type := cast (resolved[2] as varchar);
  if (model_handle <= 0 and model_type not in ('openai', 'ollama', 'lmstudio', 'openai_compatible', 'test_embedding', 'vvec_test_embedding'))
    goto fail;

  -- Re-evaluate the selector for this single key.  Mirror the full-backfill
  -- query shape exactly -- a SPARQL SELECT (one MIN(str()) value per subject)
  -- wrapped as a derived table -- and restrict to this key in the OUTER SQL,
  -- the same way VEC_INDEX_ROW_MATCHES does.  The previous form
  -- ('... from sparql <where_text> filter ...') was invalid both as SQL (?var
  -- column aliases) and as SPARQL (no SELECT projection, filter outside the
  -- group), so every shorthand/general drain failed with SQ074 and left its
  -- queue row stuck in 'error'.  Using MIN(str()) + GROUP BY here also makes the
  -- incremental value match the full backfill exactly for multi-valued subjects.
  if ('shorthand' = sel_type)
    {
      qtext := sprintf (
        'select iri_id_num (iri_to_id ("s")), cast ("text" as varchar) ' ||
        'from (sparql define input:storage "" ' ||
        'select ?s (MIN (str (?text))) as ?text where { graph <%s> { ?s <%s> ?text } } group by ?s) as sub ' ||
        'where iri_id_num (iri_to_id ("s")) = %d',
        graph_iri, pred_iri, key_id);
    }
  else if ('general' = sel_type)
    {
      if (where_text is null or where_text = '')
        goto fail;
      qtext := sprintf (
        'select iri_id_num (iri_to_id ("%s")), cast ("%s" as varchar) ' ||
        'from (sparql define input:storage "" %s' ||
        'select ?%s (MIN (str (?%s))) as ?%s %s group by ?%s) as sub ' ||
        'where iri_id_num (iri_to_id ("%s")) = %d',
        key_var, embedding_var, coalesce (cast (where_pattern_blob as varchar), ''), key_var, embedding_var, embedding_var, where_text, key_var, key_var, key_id);
    }
  else
    goto fail;

  exec (qtext, q_state, q_msg, vector (), 10000, q_meta, qr);
  if (q_state <> '00000' and q_state <> 0)
    goto fail;

  if (length (qr) > 0)
    {
      -- Key still exists in selector results: embed and upsert
      txt := cast (qr[0][1] as varchar);
      txt_hash := md5 (txt);

      -- Check if text changed
      need_update := DB.DBA.VEC_INDEX_CHECK_HASH (source_table, key_id, txt_hash);
      if (need_update)
        {
          embeds := DB.DBA.VEC_INDEX_EMBED_TEXTS (model_name, model_handle, vector (txt), model_type);
          __VEC_INDEX_INSERT_BATCH (internal_name, vector (key_id), embeds);
          DB.DBA.VEC_INDEX_UPSERT_ROW (source_table, key_id, txt, txt_hash);
        }
    }
  else
    {
      -- Key no longer in selector results: delete from index and backing table
      __VEC_INDEX_DELETE_EMBEDDING (internal_name, key_id);
      DB.DBA.VEC_INDEX_DELETE_ROW (source_table, key_id);
    }

done:;
  if (idx_iri is not null)
    DB.DBA.VEC_INDEX_END_MUTATION (idx_iri, 'draining', 1, null);
  -- Mark as done
  delete from DB.DBA.SPARQL_VEC_QUEUE where SVQ_ID = qid;
  commit work;
  return 1;

fail:;
  if (idx_iri is not null)
    DB.DBA.VEC_INDEX_END_MUTATION (idx_iri, 'draining', 0, 'queue item failed');
  -- Increment retry count, mark as error
  update DB.DBA.SPARQL_VEC_QUEUE
    set SVQ_STATE = 'error', SVQ_RETRIES = SVQ_RETRIES + 1,
        SVQ_LAST_ERROR = coalesce (q_msg, 'queue item failed')
    where SVQ_ID = qid;
  commit work;
  return 1;

none:;
  return 0;
}
;

create procedure DB.DBA.VEC_INDEX_WORKER_CONFIGURE (
  in batch_size integer := 100,
  in idle_delay integer := 5 )
{
  if (batch_size <= 0 or batch_size > 10000)
    signal ('VEC70', 'worker batch_size must be between 1 and 10000');
  if (idle_delay < 1 or idle_delay > 3600)
    signal ('VEC71', 'worker idle_delay must be between 1 and 3600 seconds');
  update DB.DBA.SPARQL_VEC_WORKER
    set SVW_BATCH_SIZE = batch_size,
        SVW_IDLE_DELAY = idle_delay,
        SVW_UPDATED = now ()
    where SVW_ID = 1;
  commit work;
}
;

create procedure DB.DBA.VEC_INDEX_WORKER_START ()
{
  update DB.DBA.SPARQL_VEC_WORKER
    set SVW_ENABLED = 1,
        SVW_LAST_ERROR = null,
        SVW_UPDATED = now ()
    where SVW_ID = 1;
  commit work;
}
;

create procedure DB.DBA.VEC_INDEX_WORKER_STOP ()
{
  update DB.DBA.SPARQL_VEC_WORKER
    set SVW_ENABLED = 0,
        SVW_UPDATED = now ()
    where SVW_ID = 1;
  commit work;
}
;

create function DB.DBA.VEC_INDEX_WORKER_RUN_ONCE () returns integer
{
  declare enabled, batch_size, processed integer;
  declare err varchar;
  declare exit handler for sqlstate '*'
    {
      update DB.DBA.SPARQL_VEC_WORKER
        set SVW_LAST_RUN = now (),
            SVW_LAST_ERROR = __SQL_MESSAGE,
            SVW_UPDATED = now ()
        where SVW_ID = 1;
      commit work;
      resignal;
    };

  select SVW_ENABLED, SVW_BATCH_SIZE
    into enabled, batch_size
    from DB.DBA.SPARQL_VEC_WORKER
    where SVW_ID = 1;
  if (enabled <> 1)
    return 0;

  processed := DB.DBA.VEC_INDEX_QUEUE_DRAIN (batch_size);
  update DB.DBA.SPARQL_VEC_WORKER
    set SVW_LAST_RUN = now (),
        SVW_LAST_ERROR = null,
        SVW_PROCESSED = SVW_PROCESSED + processed,
        SVW_UPDATED = now ()
    where SVW_ID = 1;
  commit work;
  return processed;
}
;

create procedure DB.DBA.VEC_INDEX_WORKER_STATUS ()
{
  declare pending_count, error_count integer;
  declare worker_enabled, worker_batch_size, worker_idle_delay integer;
  declare worker_last_run datetime;
  declare worker_last_error long varchar;
  declare worker_processed bigint;
  result_names (worker_enabled, worker_batch_size, worker_idle_delay,
    worker_last_run, worker_last_error, pending_count, error_count,
    worker_processed);

  pending_count := (select count (*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_STATE = 'pending');
  error_count := (select count (*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_STATE = 'error');
  select SVW_ENABLED, SVW_BATCH_SIZE, SVW_IDLE_DELAY, SVW_LAST_RUN,
         SVW_LAST_ERROR, SVW_PROCESSED
    into worker_enabled, worker_batch_size, worker_idle_delay,
         worker_last_run, worker_last_error, worker_processed
    from DB.DBA.SPARQL_VEC_WORKER where SVW_ID = 1;
  result (worker_enabled, worker_batch_size, worker_idle_delay,
    worker_last_run, worker_last_error, pending_count, error_count,
    worker_processed);
}
;

-- Drain the queue: process all pending items.
-- Returns the number of items processed.
create function DB.DBA.VEC_INDEX_QUEUE_DRAIN (in max_items integer := 1000) returns integer
{
  declare processed integer;
  declare rc integer;
  processed := 0;
  while (processed < max_items)
    {
      rc := DB.DBA.VEC_INDEX_QUEUE_PROCESS_ONE ();
      if (rc = 0)
        return processed;
      processed := processed + 1;
    }
  return processed;
}
;

-- NOTE: the 'grant execute on DB.DBA.VEC_INDEX_* to SPARQL_SELECT' statements
-- that used to live here were moved to DB.DBA.RDF_CREATE_SPARQL_ROLES() in
-- sparql.sql.  This file is loaded before that role is created, so the bare
-- grants failed at bootstrap (SR137 Bad user name) and non-DBA bif:vector_search
-- then failed with SR186 (no permission to execute VEC_INDEX_SEARCH_ROWS).

-- Clear state left behind by a server stop in the middle of an operation.
--
-- SVI_STATE holds an in-flight op ('refreshing', 'dropping', 'draining') for
-- exactly as long as one thread is running it, and END_MUTATION is what clears
-- it.  Kill that thread -- stop the server, drop the connection -- and it is
-- never cleared: the index stays 'refreshing' forever and every later attempt
-- fails BEGIN_MUTATION with VEC90, recoverable only by editing the catalogue
-- by hand.  Its _BF staging table is stranded the same way.
--
-- A server that has just started runs no such thread, by definition, so any
-- in-flight state reached here is a leftover.  Demote it to 'error', which
-- REFRESH can now retry, and say so in SVI_LAST_ERROR so the state is
-- self-explaining rather than just "error".
--
-- The staging tables go unconditionally, for every index rather than only the
-- interrupted ones: a backfill drops and recreates its own _BF table on entry,
-- so one that outlived a restart is scratch nobody owns.
--
-- This runs as a server init statement, so it must not raise -- an error here
-- would abort the rest of this file's initialisation.
create procedure DB.DBA.VEC_INDEX_RECOVER_INTERRUPTED ()
{
  declare stranded, names any;
  declare i, n integer;

  declare exit handler for sqlstate '*' { return; };

  stranded := vector ();
  names := vector ();
  for (select SVI_IRI as _iri, SVI_INTERNAL_NAME as _nm, SVI_STATE as _st
         from DB.DBA.SPARQL_VEC_INDEX) do
    {
      if (_nm is not null and length (_nm))
        names := vector_concat (names, vector (_nm));
      if (_st in ('refreshing', 'dropping', 'draining'))
        stranded := vector_concat (stranded, vector (vector (_iri, _st)));
    }

  for (i := 0; i < length (names); i := i + 1)
    DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (sprintf ('DB.DBA."%s_BF"', names[i]));

  n := length (stranded);
  for (i := 0; i < n; i := i + 1)
    {
      update DB.DBA.SPARQL_VEC_INDEX
         set SVI_STATE = 'error',
             SVI_LAST_ERROR = sprintf (
               'Interrupted while %s: the server stopped before the operation finished. Re-run REFRESH to continue.',
               stranded[i][1])
       where SVI_IRI = stranded[i][0];
      log_message (sprintf (
        'vector index <%s>: recovered from an interrupted %s; left in error state, which REFRESH can retry',
        stranded[i][0], stranded[i][1]));
    }

  if (n > 0)
    DB.DBA.VEC_INDEX_REFRESH_ACTIVE_ASYNC_FLAG ();
  commit work;
}
;

-- Rewrite every embedding as a flat float vector, row by row so the INSERT gets the converted value.
create procedure DB.DBA.VEC_INDEX_EMBEDDINGS_TO_FLOAT (
  in _hidden_table varchar,
  in _log_mode integer := 2,
  in _report_every integer := 10000) returns integer
{
  declare _converted, _old_log_mode integer;
  declare _stat, _msg, _ins varchar;
  declare _meta, _row, _handle, _float_vec any;

  _converted := 0;
  _old_log_mode := log_enable (_log_mode, 1);
  declare exit handler for sqlstate '*'
    {
      log_enable (_old_log_mode, 1);
      log_message (sprintf ('vector index %s: conversion failed after %d rows',
                            _hidden_table, _converted));
      resignal;
    };
  _ins := sprintf ('insert replacing %s '
                   || '(VE_D_ID, VE_EMBEDDING, SOURCE_HASH, EMBED_STATUS, MODEL_ID, UPDATED_AT) '
                   || 'values (?, ?, ?, ?, ?, ?)', _hidden_table);
  _stat := '00000';
  exec (sprintf ('select VE_D_ID, VE_EMBEDDING, SOURCE_HASH, EMBED_STATUS, MODEL_ID, UPDATED_AT '
                 || 'from %s', _hidden_table),
        _stat, _msg, vector (), vector ('use_cache', 1), _meta, null, _handle);
  if (_stat <> '00000')
    signal (_stat, _msg);
  while (0 = exec_next (_handle, _stat, _msg, _row))
    {
      _float_vec := VVEC_TO_FLOAT_VECTOR (_row[1]);
      exec (_ins, _stat, _msg,
            vector (_row[0], _float_vec, _row[2], _row[3], _row[4], _row[5]),
            vector ('use_cache', 1));
      if (_stat <> '00000')
        signal (_stat, _msg);
      _converted := _converted + 1;
      if (_report_every > 0 and mod (_converted, _report_every) = 0)
        log_message (sprintf ('vector index %s: converted %d rows',
                              _hidden_table, _converted));
    }
  exec_close (_handle);
  commit work;
  log_enable (_old_log_mode, 1);
  log_message (sprintf ('vector index %s: conversion complete, %d rows',
                        _hidden_table, _converted));
  return _converted;
}
;

-- Vector indexes over RDF literals (DB.DBA.RDF_OBJ), searched with bif:knnSimilar.
--
-- Each one is an ordinary SQL vector index ON DB.DBA.RDF_OBJ (RO_VAL), keyed by RO_ID
-- (source kind 'rdf_obj'); the text embedded is the literal's value, RO_LONG included,
-- as __ro2sq returns it.  Only string literals are embedded: plain, language-tagged and
-- xsd:string (__vec_rdf_obj_is_string_dt), never XML or geometry.  Short plain literals
-- stored inline in RDF_QUAD.O have no RO_ID and so are not covered.
--
-- RDF_OBJ rows are never updated in place, so there is no refresh classification:
-- new RO_IDs are logged in RDF_OBJ_VEC_LOG where literals are created (RDF_OBJ_ADD,
-- L_O_LOOK) and RDF_OBJ_VEC_LOG_DRAIN feeds them to every index.  The bulk loader
-- writes RDF_OBJ with triggers off, which is why these are explicit inserts and not
-- table triggers.

create table DB.DBA.RDF_OBJ_VEC_INDEX (
  RVI_NAME varchar not null primary key,	-- the vector index (key) name on DB.DBA.RDF_OBJ
  RVI_IRI varchar,				-- the name it was created under: an IRI, or RVI_NAME itself
  RVI_MIN_LENGTH integer default 0,		-- skip literals shorter than this many characters
  RVI_LANGS any,				-- vector of language tags, '' = no tag; null = any
  RVI_BUILD varchar default 'bulk',		-- REFRESH build mode: 'bulk' or 'incremental'
  RVI_STATE varchar default 'new',		-- 'new', 'embedding', 'embedded', 'building', 'ready', 'error'
  RVI_LAST_ERROR long varchar,
  RVI_ROWS bigint default 0,
  RVI_OWNER varchar,
  RVI_CREATED datetime,
  RVI_REFRESHED datetime
) if not exists
;

alter table DB.DBA.RDF_OBJ_VEC_INDEX add RVI_IRI varchar if not exists
;

create table DB.DBA.RDF_OBJ_VEC_LOG (
  RVL_RO_ID bigint not null primary key
) if not exists
;

create function DB.DBA.RDF_OBJ_VEC_INDEX_CHECK_NAME (in _name varchar) returns varchar
{
  if (_name is null or regexp_match ('^[A-Za-z0-9_]+\$', _name) is null)
    signal ('42000', 'VEC90', sprintf ('RDF_OBJ vector index key "%s" must consist of letters, digits and underscores.', coalesce (_name, '')));
  return _name;
}
;

-- The key name of the index created as _name, an IRI or a plain name: RDF_OBJ_ followed by the
-- name with every character that is not a letter or digit as '_', so the key and every table
-- named after it start with the table name.  An older key without the prefix is found by its
-- plain name.  vvec_rdf_obj_search_key maps knnSimilar's name the same way.
create function DB.DBA.RDF_OBJ_VEC_INDEX_KEY (in _name varchar) returns varchar
{
  declare _plain, _key varchar;
  if (_name is null or _name = '')
    signal ('42000', 'VEC90', 'An RDF_OBJ vector index needs a name.');
  _plain := DB.DBA.SYS_ALFANUM_NAME (_name);
  if (upper (subseq (_plain, 0, 8)) = 'RDF_OBJ_')
    _key := _plain;
  else
    _key := 'RDF_OBJ_' || _plain;
  if (not exists (select 1 from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _key)
      and exists (select 1 from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _plain))
    return _plain;
  return _key;
}
;

create function DB.DBA.RDF_OBJ_VEC_INDEX_OPTIONS (in _name varchar) returns any
{
  declare _opts any;
  _opts := (select KEY_OPTIONS from DB.DBA.SYS_KEYS
             where KEY_TABLE = 'DB.DBA.RDF_OBJ' and KEY_NAME = _name and KEY_MIGRATE_TO is null);
  if (_opts is null)
    signal ('42S12', 'VEC91', sprintf ('No vector index %s on DB.DBA.RDF_OBJ.', _name));
  if (lower (cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'sk') as varchar)) <> 'rdf_obj')
    signal ('42000', 'VEC91', sprintf ('Index %s on DB.DBA.RDF_OBJ is not a vector index.', _name));
  return _opts;
}
;

create function DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (in _name varchar) returns varchar
{
  return sprintf ('DB.DBA."%s_ROSRC"', DB.DBA.RDF_OBJ_VEC_INDEX_CHECK_NAME (_name));
}
;

-- Called from vvec_index_post_create for a vector index on DB.DBA.RDF_OBJ.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_REGISTER (in _name varchar)
{
  declare st, msg varchar;
  DB.DBA.RDF_OBJ_VEC_INDEX_CHECK_NAME (_name);
  DB.DBA.RDF_OBJ_VEC_INDEX_OPTIONS (_name);
  -- Same shape as a VECSRC_ table: VEC_INDEX_BACKFILL_PAGED keeps its bookkeeping here.
  st := '00000';
  exec (sprintf ('create table %s (RV_ID bigint primary key, RV_TEXT varchar, RV_RO_ID bigint, '
                 || 'RV_VECTOR any, RV_TEXT_HASH varbinary, RV_UPDATED datetime)',
                 DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (_name)), st, msg);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal (st, msg);
  delete from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name;
  insert into DB.DBA.RDF_OBJ_VEC_INDEX (RVI_NAME, RVI_IRI, RVI_STATE, RVI_OWNER, RVI_CREATED)
    values (_name, _name, 'new', user, now ());
}
;

-- Called from vvec_drop_index.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_UNREGISTER (in _name varchar)
{
  delete from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name;
  if (regexp_match ('^[A-Za-z0-9_]+\$', _name) is not null)
    DB.DBA.VEC_INDEX_DROP_TABLE_QUIET (DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (_name));
}
;

-- Create a vector index over RDF literals and, unless _build_now = 0, build it.
-- _opts is a vector of name/value pairs passed to WITH (...), e.g.
-- vector ('distance_metric', 'cosine', 'hnsw_m', 16).
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_CREATE (
  in _name varchar,
  in _model varchar,
  in _opts any := null,
  in _min_length integer := 0,
  in _langs any := null,
  in _build varchar := 'bulk',
  in _build_now integer := 1 )
{
  declare _with, _key, st, msg varchar;
  declare inx integer;
  if (not user_is_dba (user))
    signal ('42000', 'VEC92', 'Creating an RDF_OBJ vector index requires DBA privileges.');
  _key := DB.DBA.RDF_OBJ_VEC_INDEX_KEY (_name);
  {
    declare _other varchar;
    _other := (select coalesce (RVI_IRI, RVI_NAME) from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _key);
    if (_other is not null and _other <> _name)
      signal ('42000', 'VEC97', sprintf ('RDF_OBJ vector index name "%s" collides with the existing index "%s": both map to the key %s. Choose a name that differs in letters or digits.', _name, _other, _key));
    if (_other is not null)
      signal ('42000', 'VEC97', sprintf ('RDF_OBJ vector index "%s" already exists.', _name));
    if (exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.RDF_OBJ' and KEY_NAME = _key))
      signal ('42000', 'VEC97', sprintf ('RDF_OBJ vector index name "%s" maps to the key %s, which already exists on DB.DBA.RDF_OBJ.', _name, _key));
  }
  if (_build not in ('bulk', 'incremental'))
    signal ('42000', 'VEC93', 'RDF_OBJ vector index build must be ''bulk'' or ''incremental''.');
  if (_langs is not null and not isvector (_langs))
    _langs := vector (_langs);
  _with := '';
  if (_opts is not null)
    {
      if (not isvector (_opts) or mod (length (_opts), 2))
        signal ('42000', 'VEC93', 'RDF_OBJ vector index options must be a vector of name/value pairs.');
      for (inx := 0; inx < length (_opts); inx := inx + 2)
        {
          if (regexp_match ('^[A-Za-z_]+\$', cast (_opts[inx] as varchar)) is null)
            signal ('42000', 'VEC93', sprintf ('Bad vector index option name "%s".', cast (_opts[inx] as varchar)));
          _with := _with || case when _with = '' then '' else ', ' end || cast (_opts[inx] as varchar) || ' = '
            || case when isinteger (_opts[inx + 1]) then cast (_opts[inx + 1] as varchar)
                    else '''' || replace (cast (_opts[inx + 1] as varchar), '''', '''''') || '''' end;
        }
      _with := ' with (' || _with || ')';
    }
  st := '00000';
  exec (sprintf ('create vector index "%s" on DB.DBA.RDF_OBJ (RO_VAL) using ''%s''%s',
                 _key, replace (_model, '''', ''''''), _with), st, msg);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal (st, msg);
  update DB.DBA.RDF_OBJ_VEC_INDEX
     set RVI_IRI = _name, RVI_MIN_LENGTH = coalesce (_min_length, 0), RVI_LANGS = _langs, RVI_BUILD = _build
   where RVI_NAME = _key;
  commit work;
  if (_build_now)
    return DB.DBA.RDF_OBJ_VEC_INDEX_REFRESH (_key);
  return 0;
}
;

create procedure DB.DBA.RDF_OBJ_VEC_INDEX_DROP (in _index varchar)
{
  declare _name, st, msg varchar;
  if (not user_is_dba (user))
    signal ('42000', 'VEC92', 'Dropping an RDF_OBJ vector index requires DBA privileges.');
  _name := DB.DBA.RDF_OBJ_VEC_INDEX_KEY (_index);
  st := '00000';
  exec (sprintf ('drop index "%s" DB.DBA.RDF_OBJ', _name), st, msg);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal (st, msg);
  delete from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name;
  commit work;
}
;

-- The WHERE condition, over DB.DBA.RDF_OBJ, selecting the literals index _name embeds.
create function DB.DBA.RDF_OBJ_VEC_INDEX_FILTER_SQL (in _name varchar) returns varchar
{
  declare _min_len, inx integer;
  declare _langs, _tb any;
  declare _cond, _in varchar;
  whenever not found goto no_index;
  select RVI_MIN_LENGTH, RVI_LANGS into _min_len, _langs from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name;
  _cond := 'bit_and (RO_FLAGS, 2) = 0 and __vec_rdf_obj_is_string_dt (RO_DT_AND_LANG) = 1';
  -- RO_VAL is the value itself up to 50 characters and a checksum beyond, when RO_LONG holds it.
  if (_min_len > 0)
    _cond := _cond || sprintf (' and (RO_LONG is not null or length (RO_VAL) >= %d)', _min_len);
  if (isvector (_langs))
    {
      _in := '';
      for (inx := 0; inx < length (_langs); inx := inx + 1)
        {
          if (cast (_langs[inx] as varchar) = '')
            _tb := 257;
          else
            _tb := (select RL_TWOBYTE from DB.DBA.RDF_LANGUAGE where RL_ID = lower (cast (_langs[inx] as varchar)));
          if (_tb is not null)
            _in := _in || case when _in = '' then '' else ', ' end || cast (_tb as varchar);
        }
      if (_in = '')
        _in := '-1';
      _cond := _cond || sprintf (' and bit_and (RO_DT_AND_LANG, 65535) in (%s)', _in);
    }
  return _cond;
no_index:
  signal ('42S12', 'VEC91', sprintf ('RDF_OBJ vector index %s is not registered.', _name));
}
;

create function DB.DBA.RDF_OBJ_VEC_INDEX_MODEL (in _name varchar) returns any
{
  declare _model varchar;
  declare _resolved any;
  _model := cast (DB.DBA.VEC_SQL_INDEX_OPT (DB.DBA.RDF_OBJ_VEC_INDEX_OPTIONS (_name), 'm') as varchar);
  _resolved := DB.DBA.VEC_INDEX_RESOLVE_MODEL (_model);
  if (cast (_resolved[0] as integer) <= 0
      and cast (_resolved[2] as varchar) not in ('openai', 'ollama', 'lmstudio', 'openai_compatible', 'test_embedding', 'vvec_test_embedding'))
    signal ('VEC33', sprintf ('Model %s of RDF_OBJ vector index %s is not loaded.', _model, _name));
  return vector (_model, cast (_resolved[0] as integer), cast (_resolved[2] as varchar));
}
;

-- Embed every eligible literal of DB.DBA.RDF_OBJ not yet embedded into index _name (a key), and
-- remove the ones no longer eligible.  _mode is the backfill's build mode: 'bulk' or
-- 'incremental' also build the graph, 'stage' only embeds.  Literals already embedded are
-- skipped by RO_ID, so a run that stopped part way continues where it left off.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_FILL (in _name varchar, in _mode varchar, in _state_during varchar, in _state_after varchar)
{
  declare _note, _enum varchar;
  declare _done, _stale integer;
  declare _m any;
  _m := DB.DBA.RDF_OBJ_VEC_INDEX_MODEL (_name);
  _enum := sprintf ('select RO_ID, RO_ID, null from DB.DBA.RDF_OBJ table option (index RDF_OBJ) where %s',
                    DB.DBA.RDF_OBJ_VEC_INDEX_FILTER_SQL (_name));
  update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = _state_during, RVI_LAST_ERROR = null where RVI_NAME = _name;
  commit work;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'error', RVI_LAST_ERROR = __SQL_STATE || ' ' || __SQL_MESSAGE
       where RVI_NAME = _name;
      commit work;
      resignal;
    };
  DB.DBA.VEC_INDEX_BACKFILL_PAGED (_enum, _name, DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (_name),
      _m[0], _m[1], _m[2], _done, _stale, _note, _mode);
  update DB.DBA.RDF_OBJ_VEC_INDEX
     set RVI_STATE = _state_after, RVI_REFRESHED = now (), RVI_LAST_ERROR = _note,
         RVI_ROWS = DB.DBA.VEC_INDEX_STAGED_ROW_COUNT (DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (_name))
   where RVI_NAME = _name;
  commit work;
  return vector (_done, _stale);
}
;

-- Embed and build in one call: what CREATE does unless _build_now = 0.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_REFRESH (in _index varchar)
{
  declare _name varchar;
  if (not user_is_dba (user))
    signal ('42000', 'VEC92', 'Refreshing an RDF_OBJ vector index requires DBA privileges.');
  _name := DB.DBA.RDF_OBJ_VEC_INDEX_KEY (_index);
  return DB.DBA.RDF_OBJ_VEC_INDEX_FILL (_name,
      (select RVI_BUILD from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name), 'building', 'ready');
}
;

-- Step 2 of 3 (after CREATE with _build_now = 0): embed only, no graph.  Run it again after an
-- interruption and it continues from the last literals it recorded.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_EMBED (in _index varchar)
{
  declare _name varchar;
  if (not user_is_dba (user))
    signal ('42000', 'VEC92', 'Embedding an RDF_OBJ vector index requires DBA privileges.');
  _name := DB.DBA.RDF_OBJ_VEC_INDEX_KEY (_index);
  if (exists (select 1 from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name and RVI_STATE in ('building', 'embedding')))
    signal ('42000', 'VEC98', sprintf ('RDF_OBJ vector index %s is already being embedded or built.', _index));
  return DB.DBA.RDF_OBJ_VEC_INDEX_FILL (_name, 'stage', 'embedding', 'embedded');
}
;

-- Step 3 of 3: build the graph from every embedding staged so far, in one pass.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_BUILD (in _index varchar)
{
  declare _name, _state, st, msg varchar;
  declare _meta any;
  if (not user_is_dba (user))
    signal ('42000', 'VEC92', 'Building an RDF_OBJ vector index requires DBA privileges.');
  _name := DB.DBA.RDF_OBJ_VEC_INDEX_KEY (_index);
  _state := (select RVI_STATE from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = _name);
  if (_state is null)
    signal ('42S12', 'VEC91', sprintf ('RDF_OBJ vector index %s is not registered.', _index));
  if (_state in ('building', 'embedding'))
    signal ('42000', 'VEC98', sprintf ('RDF_OBJ vector index %s is already being embedded or built.', _index));
  update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'building', RVI_LAST_ERROR = null where RVI_NAME = _name;
  commit work;
  st := '00000';
  exec ('select __VEC_INDEX_REBUILD (?)', st, msg, vector (_name), 0, _meta);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    {
      rollback work;
      update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'error', RVI_LAST_ERROR = st || ' ' || msg where RVI_NAME = _name;
      commit work;
      signal (st, msg);
    }
  update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'ready', RVI_REFRESHED = now () where RVI_NAME = _name;
  commit work;
  return 1;
}
;

-- Hook at the RDF_OBJ_ADD creation sites; L_O_LOOK (vectored) inlines the same insert.
create procedure DB.DBA.RDF_OBJ_VEC_LOG_ADD (in _ro_id bigint, in _dt_and_lang integer)
{
  if (__vec_rdf_obj_is_string_dt (_dt_and_lang) and __vec_rdf_obj_active ())
    insert soft DB.DBA.RDF_OBJ_VEC_LOG (RVL_RO_ID) values (_ro_id);
}
;

-- Embed up to _max_rows logged literals into every ready index, then forget them.
-- Nothing is drained while an index is being embedded, is embedded but not built, or is being
-- built: the literals stay logged until the graph exists to take them.  Returns the number of log rows consumed.
create procedure DB.DBA.RDF_OBJ_VEC_LOG_DRAIN (in _max_rows integer := 1000) returns integer
{
  declare _ids, _names, _rows, _meta, _m, _nulls, _kids any;
  declare _n, inx, jnx, _cnt integer;
  declare _name, _src, st, msg varchar;
  if (exists (select 1 from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_STATE in ('embedding', 'embedded', 'building')))
    return 0;
  st := '00000';
  exec (sprintf ('select top %d RVL_RO_ID from DB.DBA.RDF_OBJ_VEC_LOG order by RVL_RO_ID', _max_rows),
        st, msg, vector (), vector ('max_rows', 0), _meta, _rows);
  if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
    signal (st, msg);
  _n := length (_rows);
  if (_n = 0)
    return 0;
  _ids := make_array (_n, 'any');
  for (inx := 0; inx < _n; inx := inx + 1)
    aset (_ids, inx, cast (_rows[inx][0] as bigint));
  -- Names first: the flush commits, which would close a cursor over the registry.
  _names := (select vector_agg (RVI_NAME) from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_STATE = 'ready');
  if (_names is null)
    _names := vector ();
  for (jnx := 0; jnx < length (_names); jnx := jnx + 1)
    {
      _name := _names[jnx];
      _src := DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (_name);
      st := '00000';
      -- a literal EMBED has already recorded is in the index once it is built; only new ones are embedded
      exec (sprintf ('select RO_ID from DB.DBA.RDF_OBJ where RO_ID between ? and ? and %s'
                     || ' and exists (select 1 from DB.DBA.RDF_OBJ_VEC_LOG where RVL_RO_ID = RO_ID)'
                     || ' and not exists (select 1 from %s s where s.RV_ID = RO_ID)',
                     DB.DBA.RDF_OBJ_VEC_INDEX_FILTER_SQL (_name), _src),
            st, msg, vector (_ids[0], _ids[_n - 1]), vector ('max_rows', 0, 'use_cache', 1), _meta, _rows);
      if (DB.DBA.VEC_INDEX_EXEC_FAILED (st))
        signal (st, msg);
      _cnt := length (_rows);
      if (_cnt > 0)
        {
          _kids := make_array (_cnt, 'any');
          _nulls := make_array (_cnt, 'any');
          for (inx := 0; inx < _cnt; inx := inx + 1)
            aset (_kids, inx, cast (_rows[inx][0] as bigint));
          _m := DB.DBA.RDF_OBJ_VEC_INDEX_MODEL (_name);
          DB.DBA.VEC_INDEX_BACKFILL_FLUSH (_name, _src, _m[0], _m[1], _m[2], _kids, _kids, _nulls, _cnt, 0, null);
        }
    }
  -- By id, not by range: a literal created concurrently may commit inside the range later.
  for (inx := 0; inx < _n; inx := inx + 1)
    delete from DB.DBA.RDF_OBJ_VEC_LOG where RVL_RO_ID = _ids[inx];
  commit work;
  return _n;
}
;

-- RDF_GLOBAL_RESET (hard) empties RDF_OBJ and restarts RDF_RO_ID, so an old embedding
-- would name a different literal after reload.  Empty every index; REFRESH rebuilds.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_RESET_ALL ()
{
  declare _names any;
  declare _name, _hidden varchar;
  declare inx integer;
  delete from DB.DBA.RDF_OBJ_VEC_LOG;
  _names := (select vector_agg (RVI_NAME) from DB.DBA.RDF_OBJ_VEC_INDEX);
  if (_names is null)
    return;
  for (inx := 0; inx < length (_names); inx := inx + 1)
    {
      declare continue handler for sqlstate '*'
        {
          log_message (sprintf ('RDF_OBJ vector index %s: reset failed: %s %s', _name, __SQL_STATE, __SQL_MESSAGE));
        };
      _name := _names[inx];
      _hidden := cast (DB.DBA.VEC_SQL_INDEX_OPT (DB.DBA.RDF_OBJ_VEC_INDEX_OPTIONS (_name), 'ht') as varchar);
      exec (sprintf ('delete from %s', _hidden));
      exec (sprintf ('delete from %s', DB.DBA.RDF_OBJ_VEC_INDEX_SRC_TABLE (_name)));
      __VEC_INDEX_REBUILD (_name);
      update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'new', RVI_ROWS = 0 where RVI_NAME = _name;
    }
  commit work;
}
;

-- Server init: nothing can be building at startup.
create procedure DB.DBA.RDF_OBJ_VEC_INDEX_RECOVER_INTERRUPTED ()
{
  update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'error', RVI_LAST_ERROR = 'build interrupted by server restart; run RDF_OBJ_VEC_INDEX_BUILD or _REFRESH'
   where RVI_STATE = 'building';
  update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'error', RVI_LAST_ERROR = 'embedding interrupted by server restart; run RDF_OBJ_VEC_INDEX_EMBED to continue'
   where RVI_STATE = 'embedding';
  commit work;
}
;

-- Server init: an index found mid-operation at startup was interrupted, since
-- nothing can be running one yet.
DB.DBA.VEC_INDEX_RECOVER_INTERRUPTED ()
;

DB.DBA.RDF_OBJ_VEC_INDEX_RECOVER_INTERRUPTED ()
;
