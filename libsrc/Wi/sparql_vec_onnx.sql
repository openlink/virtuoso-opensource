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
--  ONNX and HTTP embedding model registry, model loading and embedding
--  helpers used by vector indexes.
--

create procedure DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (in _provider varchar)
{
  declare _normalized varchar;
  _normalized := lower (trim (coalesce (_provider, '')));
  if (_normalized in ('openai', 'openai_embedding'))
    return 'openai';
  if (_normalized in ('ollama', 'ollama_embedding'))
    return 'ollama';
  if (_normalized in ('lmstudio', 'lm_studio', 'lmstudio_embedding'))
    return 'lmstudio';
  if (_normalized in ('openai_compatible', 'openai-compatible', 'compatible'))
    return 'openai_compatible';
  return _normalized;
}
;

create procedure DB.DBA.ONNX_HTTP_PROVIDER_DEFAULT_ENDPOINT (in _provider varchar)
{
  declare _normalized varchar;
  _normalized := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_provider);
  if (_normalized = 'openai')
    return 'https://api.openai.com/v1/embeddings';
  if (_normalized = 'ollama')
    return 'http://127.0.0.1:11434/v1/embeddings';
  if (_normalized = 'lmstudio')
    return 'http://127.0.0.1:1234/v1/embeddings';
  return null;
}
;

create procedure DB.DBA.ONNX_PROVIDER_API_KEY_NAME (in _provider varchar)
{
  declare _normalized varchar;
  _normalized := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_provider);
  if (_normalized = 'openai')
    return 'ONNX_API_KEY_OPENAI';
  if (_normalized = 'ollama')
    return 'ONNX_API_KEY_OLLAMA';
  if (_normalized = 'lmstudio')
    return 'ONNX_API_KEY_LMSTUDIO';
  if (_normalized = 'openai_compatible')
    return 'ONNX_API_KEY_OPENAI_COMPATIBLE';
  signal ('22023', 'ONNXP', 'Unsupported HTTP embedding provider');
}
;

create procedure DB.DBA.ONNX_REQUIRE_DBA ()
{
  if (not user_is_dba (user))
    signal ('42000', 'ONNXP', 'ONNX provider API keys are DBA-only');
  return 1;
}
;

create procedure DB.DBA.ONNX_API_KEY_SET (in _key_name varchar, in _api_key varchar)
{
  DB.DBA.ONNX_REQUIRE_DBA ();
  if (_key_name is null or not length (trim (_key_name)))
    signal ('22023', 'ONNXP', 'API key registry name must not be empty');
  -- Only registry names under the prefix are hidden from non-DBA accounts.
  if (not starts_with (trim (_key_name), 'ONNX_API_KEY_'))
    signal ('22023', 'ONNXP', 'API key registry names start with ONNX_API_KEY_: other registry names can be read by every SQL account');
  registry_set (trim (_key_name), coalesce (_api_key, ''));
  return 1;
}
;

create procedure DB.DBA.ONNX_PROVIDER_API_KEY_SET (in _provider varchar, in _api_key varchar)
{
  declare _key_name varchar;
  DB.DBA.ONNX_REQUIRE_DBA ();
  _key_name := DB.DBA.ONNX_PROVIDER_API_KEY_NAME (_provider);
  registry_set (_key_name, coalesce (_api_key, ''));
  return _key_name;
}
;

--  The [ONNX] items that say where a bundled model's files are, e.g.
--  GraniteModelPath and GraniteVocabPath; '' for any other model, whose
--  paths are its own.
create procedure DB.DBA.ONNX_MODEL_INI_ITEM (in _model_name varchar, in _what varchar)
{
  if (_model_name = 'granite-384-local')
    return 'Granite' || _what;
  return '';
}
;

create procedure DB.DBA.ONNX_MODEL_REFRESH (in _model_name varchar)
{
  declare model_path, model_type, output_name, vocab_path, opts varchar;
  declare input_names varchar;
  declare _in_parts any;
  declare max_seq_len, intra_threads, inter_threads integer;
  declare stat, msg varchar;
  declare meta, rows any;
  declare model_handle integer;
  declare _resolved_model, _resolved_vocab varchar;

  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.ONNX_MODELS'))
    return 0;

  stat := '00000';
  exec ('select model_path, model_type, coalesce (output_name, ''''), coalesce (vocab_path, ''''), coalesce (max_seq_len, 0), coalesce (input_names, ''''), coalesce (intra_threads, 0), coalesce (inter_threads, 0) from DB.DBA.ONNX_MODELS where model_name = ?',
      stat, msg, vector (_model_name), 1, meta, rows);
  if (stat <> '00000')
    {
      --  A table made before the thread columns, and not migrated yet:
      --  ONNX_REGISTRY_INIT adds them at the next start.
      stat := '00000';
      exec ('select model_path, model_type, coalesce (output_name, ''''), coalesce (vocab_path, ''''), coalesce (max_seq_len, 0), coalesce (input_names, ''''), 0, 0 from DB.DBA.ONNX_MODELS where model_name = ?',
          stat, msg, vector (_model_name), 1, meta, rows);
    }
  if (stat <> '00000' or rows is null or length (rows) = 0)
    return 0;

  model_path := cast (rows[0][0] as varchar);
  model_type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (cast (rows[0][1] as varchar));
  output_name := cast (rows[0][2] as varchar);
  vocab_path := cast (rows[0][3] as varchar);
  max_seq_len := coalesce (cast (rows[0][4] as integer), 0);
  input_names := cast (rows[0][5] as varchar);
  intra_threads := coalesce (cast (rows[0][6] as integer), 0);
  inter_threads := coalesce (cast (rows[0][7] as integer), 0);

  if (model_type in ('test_embedding', 'vvec_test_embedding', 'unavailable'))
    return 0;
  if (model_type in ('openai', 'ollama', 'lmstudio', 'openai_compatible'))
    {
      update DB.DBA.ONNX_MODELS set handle = null, updated_at = now () where model_name = _model_name;
      return 1;
    }

  -- Resolve to absolute paths, exactly as ONNX_REGISTER_DEFAULT_MODELS does at
  -- bootstrap.  Helper processes inherit the server's working directory, which
  -- is the database directory rather than wherever the model happens to live,
  -- so a relative path stored in ONNX_MODELS would produce a helper that dies
  -- on every request.  Resolving here keeps refresh consistent with bootstrap
  -- instead of quietly loading a model the helpers cannot open.
  _resolved_vocab := null;
  _resolved_model := DB.DBA.ONNX_RESOLVE_PATH (model_path, DB.DBA.ONNX_MODEL_INI_ITEM (_model_name, 'ModelPath'));
  if (_resolved_model is null)
    {
      log_message (sprintf ('ONNX refresh failed for model %s: model file not found: %s',
          _model_name, model_path));
      update DB.DBA.ONNX_MODELS set handle = null, updated_at = now () where model_name = _model_name;
      return 0;
    }
  model_path := _resolved_model;

  if (length (vocab_path))
    {
      _resolved_vocab := DB.DBA.ONNX_RESOLVE_PATH (vocab_path, DB.DBA.ONNX_MODEL_INI_ITEM (_model_name, 'VocabPath'));
      if (_resolved_vocab is null)
        {
          log_message (sprintf ('ONNX refresh failed for model %s: vocab file not found: %s',
              _model_name, vocab_path));
          update DB.DBA.ONNX_MODELS set handle = null, updated_at = now () where model_name = _model_name;
          return 0;
        }
      vocab_path := _resolved_vocab;
    }

  --  The input_names column has been in this table since it was created, and
  --  was never read: every model was loaded as if it were a tokenizer model.
  --  A registered tensor model -- a regressor whose input is called 'features',
  --  say -- therefore got a handle bound to tensors its graph does not contain,
  --  reported success, and failed on every call with 'Inference failed'.
  --
  --  Honour the column: a comma-separated list supplies input=, input2= and
  --  input3= in order.  An empty column keeps the tokenizer pair, so every row
  --  written before this change loads exactly as it did.
  if (length (input_names))
    {
      _in_parts := split_and_decode (input_names, 0, '\0\0,');
      opts := 'input=' || trim (cast (_in_parts[0] as varchar));
      if (length (_in_parts) > 1)
        opts := opts || ';input2=' || trim (cast (_in_parts[1] as varchar));
      if (length (_in_parts) > 2)
        opts := opts || ';input3=' || trim (cast (_in_parts[2] as varchar));
    }
  else
    opts := 'input=input_ids;input2=attention_mask';
  if (length (output_name))
    opts := opts || ';output=' || output_name;
  if (length (vocab_path))
    opts := opts || ';vocab=' || vocab_path;
  if (max_seq_len > 0)
    opts := opts || ';max_seq_len=' || cast (max_seq_len as varchar);
  --  ONNX Runtime's threads per helper; empty, the plugin's default of one
  --  each.  A change loads a new model -- the thread counts are part of the
  --  plugin's reuse key -- and this row's handle moves to it; the one it
  --  replaces stays loaded until ONNX_UNLOAD_MODEL or a restart, since another
  --  caller may hold its handle.
  if (intra_threads > 0)
    opts := opts || ';intra_threads=' || cast (intra_threads as varchar);
  if (inter_threads > 0)
    opts := opts || ';inter_threads=' || cast (inter_threads as varchar);

  stat := '00000';
  exec ('select ONNX_LOAD_MODEL (?, ?)', stat, msg, vector (model_path, opts), 1, meta, rows);
  if (stat <> '00000' or rows is null or length (rows) = 0)
    {
      log_message (sprintf ('ONNX bootstrap failed for model %s: [%s] %s', _model_name, stat, msg));
      update DB.DBA.ONNX_MODELS set handle = null, updated_at = now () where model_name = _model_name;
      return 0;
    }

  model_handle := cast (rows[0][0] as integer);
  -- The resolved paths are deliberately *not* written back to ONNX_MODELS.
  -- Resolution is relative to server configuration (ModelRoot, Plugins
  -- LoadPath, DirsAllowed), so a stored absolute path would silently pin the
  -- catalog to one deployment's layout and stop travelling with a backup.
  -- Keep whatever the operator entered; resolve on each load.
  update DB.DBA.ONNX_MODELS set handle = model_handle, updated_at = now () where model_name = _model_name;
  return model_handle;
}
;

create procedure DB.DBA.ONNX_FILE_EXISTS (in _path varchar)
{
  declare _stat any;
  if (_path is null or length (_path) = 0 or _path[0] <> ascii ('/'))
    return 0;
  _stat := file_stat (_path, 3);
  if (isstring (_stat))
    return 1;
  return 0;
}
;

create procedure DB.DBA.ONNX_JOIN_PATH (in _root varchar, in _rel varchar)
{
  if (_root is null or length (_root) = 0 or _rel is null or length (_rel) = 0)
    return null;
  if (_rel[0] = ascii ('/'))
    return _rel;
  if (_root[length (_root) - 1] = ascii ('/'))
    return _root || _rel;
  return _root || '/' || _rel;
}
;

create procedure DB.DBA.ONNX_ABSOLUTE_PATH (in _path varchar)
{
  if (_path is null or length (_path) = 0)
    return null;
  if (_path[0] = ascii ('/'))
    return _path;
  return DB.DBA.ONNX_JOIN_PATH (server_root (), _path);
}
;

create procedure DB.DBA.ONNX_RESOLVE_PATH (in _rel varchar, in _ini_item varchar)
{
  declare _root, _candidate, _raw, _dirs any;
  declare _inx integer;
  if (_rel is null or length (_rel) = 0)
    return null;
  if (_rel[0] = ascii ('/') and DB.DBA.ONNX_FILE_EXISTS (_rel))
    return _rel;

  _raw := case when length (_ini_item) > 0 then virtuoso_ini_item_value ('ONNX', _ini_item) end;
  if (_raw is not null and length (_raw) > 0)
    {
      _candidate := DB.DBA.ONNX_ABSOLUTE_PATH (_raw);
      if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
        return _candidate;
      _root := DB.DBA.ONNX_ABSOLUTE_PATH (virtuoso_ini_item_value ('ONNX', 'ModelRoot'));
      _candidate := DB.DBA.ONNX_JOIN_PATH (_root, _raw);
      if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
        return _candidate;
    }

  _root := DB.DBA.ONNX_ABSOLUTE_PATH (virtuoso_ini_item_value ('ONNX', 'ModelRoot'));
  _candidate := DB.DBA.ONNX_JOIN_PATH (_root, _rel);
  if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
    return _candidate;

  _root := DB.DBA.ONNX_ABSOLUTE_PATH (virtuoso_ini_item_value ('Plugins', 'LoadPath'));
  _candidate := DB.DBA.ONNX_JOIN_PATH (_root, _rel);
  if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
    return _candidate;

  _dirs := split_and_decode (coalesce (virtuoso_ini_item_value ('Parameters', 'DirsAllowed'), ''), 0, '\0\0,');
  _inx := 0;
  while (_inx < length (_dirs))
    {
      _root := DB.DBA.ONNX_ABSOLUTE_PATH (trim (cast (_dirs[_inx] as varchar)));
      _candidate := DB.DBA.ONNX_JOIN_PATH (_root, _rel);
      if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
        return _candidate;
      _inx := _inx + 1;
    }

  _root := DB.DBA.ONNX_ABSOLUTE_PATH (http_root ());
  _candidate := DB.DBA.ONNX_JOIN_PATH (_root, _rel);
  if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
    return _candidate;
  _candidate := DB.DBA.ONNX_JOIN_PATH (_root, '../' || _rel);
  if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
    return _candidate;
  _candidate := DB.DBA.ONNX_JOIN_PATH (_root, '../../' || _rel);
  if (DB.DBA.ONNX_FILE_EXISTS (_candidate))
    return _candidate;

  return null;
}
;

create procedure DB.DBA.ONNX_REGISTRY_INIT ()
{
  declare _stat, _msg varchar;
  _stat := '00000';
  exec ('create table DB.DBA.ONNX_MODELS (
    model_id integer identity,
    model_name varchar not null,
    description varchar,
    model_path varchar not null,
    model_type varchar not null,
    input_names varchar,
    input_shapes varchar,
    output_name varchar,
    output_shape varchar,
    vocab_path varchar,
    max_seq_len integer,
    provider_endpoint varchar,
    provider_api_key_name varchar,
    provider_timeout integer,
    provider_dimensions integer,
    provider_insecure integer,
    provider_consecutive_failures integer,
    provider_last_error varchar,
    provider_last_error_at datetime,
    provider_max_batch integer,
    intra_threads integer,
    inter_threads integer,
    handle integer,
    created_at datetime,
    updated_at datetime,
    primary key (model_id))', _stat, _msg);

  _stat := '00000';
  exec ('create unique index ONNX_MODELS_NAME_IDX on DB.DBA.ONNX_MODELS (model_name)', _stat, _msg);

  -- Everything below is schema evolution, for a database created before one of
  -- these columns existed.  It is skipped until ALTER TABLE can actually work.
  --
  -- ALTER TABLE ADD goes through DB.DBA.add_col, which calls DB.DBA.cl_exec.
  -- This procedure runs as an init statement of users.sql, which is the FIRST
  -- bootstrap phase (sqls_define_sys), and cl_exec is not defined until a later
  -- one.  So on a fresh database the add fails with
  --   42001 SR185: Undefined procedure DB.DBA.cl_exec
  -- and ddl_add_col poisons the boot transaction deliberately ("schema could be
  -- inconsistent, do not commit").  The exec() above captures the error text
  -- into _stat and drops it, so nothing is logged -- but the transaction stays
  -- blown, so this statement fails with SR176 and, worse, so does the NEXT init
  -- statement to run: __MAKE_UNICODE3_COLLATIONS, which is how a freshly created
  -- database ended up with no collations at all until its first restart.
  --
  -- Deferring costs nothing: ONNX_BOOTSTRAP_MODELS calls this procedure again
  -- in the AFTER phase, by which point cl_exec exists and the columns are
  -- added.  (Do not write the AFTER directive marker in a comment here: the
  -- awk generator that builds sql_code_sys.c splits the line on it and the
  -- remainder of the comment becomes code.)
  if (__proc_exists ('DB.DBA.cl_exec') is null)
    return 1;

  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_endpoint varchar if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_api_key_name varchar if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_timeout integer if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_dimensions integer if not exists', _stat, _msg);
  -- Provider hardening (prompt 11): per-model TLS-verify opt-out and health state.
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_insecure integer if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_consecutive_failures integer if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_last_error varchar if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_last_error_at datetime if not exists', _stat, _msg);
  -- Inputs per embedding request.  NULL means "use the per-provider default"
  -- from ONNX_HTTP_PROVIDER_MAX_BATCH; set it per model to match a gateway or
  -- self-hosted server with a different limit.
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add provider_max_batch integer if not exists', _stat, _msg);
  -- ONNX Runtime's intra- and inter-op threads per helper for a local model,
  -- passed by ONNX_MODEL_REFRESH; NULL is the plugin's default of one.
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add intra_threads integer if not exists', _stat, _msg);
  _stat := '00000';
  exec ('alter table DB.DBA.ONNX_MODELS add inter_threads integer if not exists', _stat, _msg);
  return 1;
}
;

--  Tell the plugin which directories the operator has declared as model
--  locations.  ONNX_LOAD_MODEL checks the model path before opening it, and
--  DirsAllowed on its own is not the whole policy: ONNX_RESOLVE_PATH (above)
--  resolves a model against [ONNX] ModelRoot and the plugin LoadPath too, and
--  the shipped virtuoso.ini has ModelRoot = ../hosting/onnx-models while
--  DirsAllowed is only '., ../vad/'.  Without this the server refuses its own
--  bundled model at bootstrap and the vector index loses its embedding model.
--
--  Best-effort and deliberately quiet: the plugin may not be loaded at all, and
--  an unset root is not an error -- it just leaves DirsAllowed as the only rule.
create procedure DB.DBA.ONNX_PUBLISH_MODEL_ROOTS ()
{
  declare _roots any;
  declare _inx integer;
  declare _root, _stat, _msg varchar;
  _roots := vector (
    DB.DBA.ONNX_ABSOLUTE_PATH (virtuoso_ini_item_value ('ONNX', 'ModelRoot')),
    DB.DBA.ONNX_ABSOLUTE_PATH (virtuoso_ini_item_value ('Plugins', 'LoadPath')));
  _inx := 0;
  while (_inx < length (_roots))
    {
      _root := cast (_roots[_inx] as varchar);
      if (_root is not null and length (_root) > 0 and _root[0] = ascii ('/'))
        {
          _stat := '00000';
          exec ('select ONNX_CONFIG (''model_root'', ?)', _stat, _msg, vector (_root));
        }
      _inx := _inx + 1;
    }
  return 1;
}
;

--  The bundled embedding model: IBM's granite-embedding-30m-english, as
--  granite-384-local.  It is a RoBERTa encoder with a byte-level BPE
--  tokenizer (vocab.json, and merges.txt beside it), CLS pooling and 512
--  tokens.
create procedure DB.DBA.ONNX_REGISTER_DEFAULT_MODELS ()
{
  declare _model_path, _vocab_path, _helper_path varchar;
  declare _stat, _msg, _failure varchar;
  declare _meta, _rows any;

  DB.DBA.ONNX_REGISTRY_INIT ();
  --  Before anything is loaded, including by a user on a server whose bundled
  --  model is absent.
  DB.DBA.ONNX_PUBLISH_MODEL_ROOTS ();
  _model_path := DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/model.onnx', 'GraniteModelPath');
  _vocab_path := DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/vocab.json', 'GraniteVocabPath');
  _helper_path := DB.DBA.ONNX_RESOLVE_PATH ('onnx_helper', 'HelperPath');

  if (_model_path is null or _vocab_path is null or _helper_path is null)
    {
      _failure := sprintf ('ONNX bootstrap disabled granite-384-local: model=%s vocab=%s helper=%s; configure [ONNX] ModelRoot and HelperPath with installed absolute paths',
        coalesce (_model_path, '<unresolved>'), coalesce (_vocab_path, '<unresolved>'), coalesce (_helper_path, '<unresolved>'));
      log_message (_failure);
      update DB.DBA.ONNX_MODELS set model_type = 'unavailable', handle = null,
        description = _failure, updated_at = now () where model_name = 'granite-384-local';
      return 0;
    }

  _stat := '00000';
  exec ('select ONNX_CONFIG (''helper_path'', ?)', _stat, _msg, vector (_helper_path));
  if (_stat <> '00000')
    {
      _failure := sprintf ('ONNX bootstrap disabled granite-384-local: helper configuration failed for %s: [%s] %s', _helper_path, _stat, _msg);
      log_message (_failure);
      update DB.DBA.ONNX_MODELS set model_type = 'unavailable', handle = null,
        description = _failure, updated_at = now () where model_name = 'granite-384-local';
      return 0;
    }

  _stat := '00000';
  exec ('select count (*) from DB.DBA.ONNX_MODELS where model_name = ?',
      _stat, _msg, vector ('granite-384-local'), 1, _meta, _rows);
  if (_stat = '00000' and _rows is not null and length (_rows) > 0 and cast (_rows[0][0] as integer) = 0)
    {
      _stat := '00000';
      exec ('insert into DB.DBA.ONNX_MODELS
        (model_name, description, model_path, model_type, output_name, output_shape, vocab_path, max_seq_len, created_at, updated_at)
        values (?, ?, ?, ?, ?, ?, ?, ?, now (), now ())',
        _stat, _msg,
        vector ('granite-384-local', 'local bootstrap model', _model_path, 'text_embedding',
                'pooled_output', '1,384', _vocab_path, 512));
    }
  else if (_stat = '00000')
    -- Re-registration runs on every startup to re-resolve the deployment's paths;
    -- max_seq_len is operator tuning, so seed it only when unset, never reset it.
    update DB.DBA.ONNX_MODELS set description = 'local bootstrap model', model_path = _model_path,
      model_type = 'text_embedding', output_name = 'pooled_output', output_shape = '1,384',
      vocab_path = _vocab_path, max_seq_len = coalesce (max_seq_len, 512),
      handle = null, updated_at = now ()
      where model_name = 'granite-384-local';

  return 1;
}
;

create procedure DB.DBA.ONNX_REGISTER_HTTP_EMBED_MODEL (
  in _model_name varchar,
  in _provider varchar,
  in _remote_model varchar,
  in _dimensions integer,
  in _endpoint varchar := null,
  in _api_key_name varchar := null,
  in _timeout integer := 30,
  in _description varchar := null,
  in _insecure integer := 0)
{
  declare _type, _endpoint_value, _key_name, _shape varchar;
  declare _has_key integer;
  DB.DBA.ONNX_REQUIRE_DBA ();
  DB.DBA.ONNX_REGISTRY_INIT ();
  _type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_provider);
  if (_type not in ('openai', 'ollama', 'lmstudio', 'openai_compatible'))
    signal ('22023', 'ONNXP', 'Unsupported HTTP embedding provider');
  if (_model_name is null or not length (trim (_model_name)) or _remote_model is null or not length (trim (_remote_model)))
    signal ('22023', 'ONNXP', 'Provider model alias and remote model name are required');
  if (_dimensions is null or _dimensions <= 0)
    signal ('22023', 'ONNXP', 'Provider embedding dimensions must be positive');
  if (_timeout is null or _timeout <= 0 or _timeout > 300)
    signal ('22023', 'ONNXP', 'Provider timeout must be between 1 and 300 seconds');
  _endpoint_value := trim (coalesce (_endpoint, ''));
  if (not length (_endpoint_value))
    _endpoint_value := DB.DBA.ONNX_HTTP_PROVIDER_DEFAULT_ENDPOINT (_type);
  if (_endpoint_value is null or not length (_endpoint_value))
    signal ('22023', 'ONNXP', 'An endpoint is required for openai_compatible models');
  _key_name := trim (coalesce (_api_key_name, ''));
  if (not length (_key_name) and _type = 'openai')
    _key_name := DB.DBA.ONNX_PROVIDER_API_KEY_NAME (_type);
  -- Issue 6: reject a cleartext-http endpoint to a public host at registration
  -- time (the key may not be set yet, so pass 1 = treat as key-bearing).
  DB.DBA.ONNX_HTTP_REQUIRE_SECURE_ENDPOINT (_endpoint_value, 1);
  _insecure := case when _insecure then 1 else 0 end;
  _shape := sprintf ('1,%d', _dimensions);
  if (exists (select 1 from DB.DBA.ONNX_MODELS where model_name = _model_name))
    update DB.DBA.ONNX_MODELS set
      description = coalesce (_description, sprintf ('HTTP embedding provider=%s model=%s', _type, _remote_model)),
      model_path = trim (_remote_model), model_type = _type, output_shape = _shape,
      provider_endpoint = _endpoint_value, provider_api_key_name = nullif (_key_name, ''),
      provider_timeout = _timeout, provider_dimensions = _dimensions, provider_insecure = _insecure,
      provider_consecutive_failures = 0, provider_last_error = null, handle = null, updated_at = now ()
    where model_name = _model_name;
  else
    insert into DB.DBA.ONNX_MODELS
      (model_name, description, model_path, model_type, output_shape, provider_endpoint,
       provider_api_key_name, provider_timeout, provider_dimensions, provider_insecure, handle, created_at, updated_at)
    values
      (_model_name, coalesce (_description, sprintf ('HTTP embedding provider=%s model=%s', _type, _remote_model)),
       trim (_remote_model), _type, _shape, _endpoint_value, nullif (_key_name, ''), _timeout, _dimensions,
       _insecure, null, now (), now ());
  return 1;
}
;

create procedure DB.DBA.ONNX_HTTP_EXTRACT_EMBEDDING (in _response any)
{
  declare _root, _data, _item, _embedding any;
  _root := json_parse (cast (_response as varchar));
  _data := get_keyword ('data', _root);
  if (isarray (_data) and length (_data) > 0)
    {
      _item := _data[0];
      _embedding := get_keyword ('embedding', _item);
    }
  if (_embedding is null or not isarray (_embedding))
    signal ('42000', 'ONNXP', 'OpenAI-compatible embedding response did not include data[0].embedding');
  return _embedding;
}
;

-- Extract the integer status from an HTTP status line, e.g.
-- "HTTP/1.1 429 Too Many Requests" -> 429.  atoi() stops at the first space.
create procedure DB.DBA.ONNX_HTTP_STATUS_CODE (in _status_line varchar) returns integer
{
  declare _sp integer;
  if (_status_line is null)
    return 0;
  _sp := strchr (_status_line, ' ');
  if (_sp is null)
    return 0;
  return atoi (subseq (_status_line, _sp + 1));
}
;

-- Seconds to wait from a numeric Retry-After response header, capped at 30s.
-- The HTTP-date form is not parsed (returns 0 -> caller uses exponential backoff).
create procedure DB.DBA.ONNX_HTTP_RETRY_AFTER (in _response_headers any) returns integer
{
  declare i, _v, _colon integer;
  declare _h varchar;
  if (not isarray (_response_headers))
    return 0;
  for (i := 0; i < length (_response_headers); i := i + 1)
    {
      _h := cast (_response_headers[i] as varchar);
      if (lower (_h) like 'retry-after:%')
        {
          _colon := strchr (_h, ':');
          _v := atoi (trim (subseq (_h, _colon + 1)));
          if (_v > 30)
            _v := 30;
          if (_v < 0)
            _v := 0;
          return _v;
        }
    }
  return 0;
}
;

-- Is a URL host a loopback or RFC1918/link-local/ULA private address, i.e. one
-- to which sending an API key over plain http is acceptable?  Classifies the
-- host LITERAL only (there is no PL DNS resolver), so a hostname other than
-- 'localhost' is treated as non-local.
create procedure DB.DBA.ONNX_HTTP_HOST_IS_LOCAL (in _host varchar) returns integer
{
  declare _h, _rest varchar;
  declare _dot, _second integer;
  _h := lower (trim (coalesce (_host, '')));
  if (_h like '[%]')
    _h := trim (_h, '[]');
  if (_h = 'localhost' or _h = '::1' or _h like '127.%'
      or _h like '10.%' or _h like '192.168.%' or _h like '169.254.%'
      or _h like 'fc%:%' or _h like 'fd%:%' or _h like 'fe80:%')
    return 1;
  if (_h like '172.%')                          -- 172.16.0.0 - 172.31.255.255
    {
      _rest := subseq (_h, 4);
      _dot := strchr (_rest, '.');
      if (_dot is not null and _dot > 0)
        {
          _second := atoi (subseq (_rest, 0, _dot));
          if (_second >= 16 and _second <= 31)
            return 1;
        }
    }
  return 0;
}
;

-- Refuse an endpoint that would carry an API key insecurely: anything that is
-- not https:// is allowed only when it targets a loopback/private host (the real
-- use case is Ollama/LM Studio on a private network).  Called at registration
-- and again at request time (defence in depth).
create procedure DB.DBA.ONNX_HTTP_REQUIRE_SECURE_ENDPOINT (in _url varchar, in _has_key integer)
{
  declare _parts any;
  declare _scheme, _host varchar;
  declare _at, _colon integer;
  if (_url is null or not length (trim (_url)))
    return;
  _parts := WS.WS.PARSE_URI (_url);
  _scheme := lower (cast (_parts[0] as varchar));
  _host := cast (_parts[1] as varchar);
  _at := strchr (_host, '@');                   -- strip userinfo
  if (_at is not null)
    _host := subseq (_host, _at + 1);
  if (_host not like '[%')                       -- strip :port (non-IPv6-literal)
    {
      _colon := strchr (_host, ':');
      if (_colon is not null)
        _host := subseq (_host, 0, _colon);
    }
  if (_scheme = 'https')
    return;
  if (DB.DBA.ONNX_HTTP_HOST_IS_LOCAL (_host))
    return;
  signal ('42000', 'ONNXP',
    sprintf ('HTTP embedding endpoint %s must use https:// -- plain http is allowed only to a loopback or private-network host%s.',
      _url, case when _has_key then ' (refusing to send an API key in cleartext to a public host)' else '' end));
}
;

-- Inputs per request for an OpenAI-compatible /v1/embeddings endpoint.
-- These are deliberately well under each provider's documented ceiling.
-- OpenAI accepts 2048 inputs but also caps a request at 300k tokens, so a
-- 2048-input batch of ordinary documents exceeds the token limit long before
-- the input limit; the win is in going from 1 to ~100, not in reaching 2048.
-- Local servers hold the whole batch in memory, so they get a smaller default.
-- Override per model with ONNX_MODELS.provider_max_batch.
create procedure DB.DBA.ONNX_HTTP_PROVIDER_MAX_BATCH (in _provider varchar)
{
  declare _type varchar;
  _type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_provider);
  if (_type = 'openai')
    return 128;
  if (_type in ('ollama', 'lmstudio'))
    return 32;
  return 32;                                   -- unknown openai_compatible gateway
}
;

-- Extract every embedding from an OpenAI-compatible response, in the order the
-- inputs were sent.  data[] carries an `index` per item and providers are not
-- required to return them in order, so the result is placed by index rather
-- than appended -- appending would silently pair texts with other texts'
-- vectors, which is far worse than an error.
create procedure DB.DBA.ONNX_HTTP_EXTRACT_EMBEDDINGS (in _response any, in _expected integer)
{
  declare _root, _data, _item, _emb, _result, _filled any;
  declare _i, _n, _idx, _seen integer;
  _root := json_parse (cast (_response as varchar));
  _data := get_keyword ('data', _root);
  if (not isarray (_data))
    signal ('42000', 'ONNXP', 'OpenAI-compatible embedding response did not include a data array');
  _n := length (_data);
  if (_n <> _expected)
    signal ('42000', 'ONNXP',
      sprintf ('OpenAI-compatible embedding response returned %d embeddings for %d inputs', _n, _expected));
  _result := make_array (_expected, 'any');
  -- Occupancy is tracked separately because make_array fills with 0-boxes, not
  -- NULLs, so "is this slot still empty?" cannot be asked of _result itself.
  -- A 'long' array is already zero-filled, which is the "empty" state here.
  _filled := make_array (_expected, 'long');
  _seen := 0;
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      _item := _data[_i];
      _emb := get_keyword ('embedding', _item);
      if (_emb is null or not isarray (_emb))
        signal ('42000', 'ONNXP',
          sprintf ('OpenAI-compatible embedding response item %d has no embedding array', _i));
      _idx := get_keyword ('index', _item);
      -- A provider that omits `index` is taken to have answered in order.
      if (_idx is null)
        _idx := _i;
      _idx := cast (_idx as integer);
      if (_idx < 0 or _idx >= _expected)
        signal ('42000', 'ONNXP',
          sprintf ('OpenAI-compatible embedding response item %d has out-of-range index %d', _i, _idx));
      if (_filled[_idx])
        signal ('42000', 'ONNXP',
          sprintf ('OpenAI-compatible embedding response repeated index %d', _idx));
      aset (_result, _idx, _emb);
      aset (_filled, _idx, 1);
      _seen := _seen + 1;
    }
  if (_seen <> _expected)
    signal ('42000', 'ONNXP',
      sprintf ('OpenAI-compatible embedding response covered %d of %d inputs', _seen, _expected));
  return _result;
}
;

-- Batch form of ONNX_HTTP_EMBED_TEXT: sends `_texts` as a single request with
-- an array `input` and returns a vector of embeddings in the same order.
-- Caller is responsible for chunking to the provider's batch limit.
--
-- Retry, backoff, endpoint/TLS policy and log redaction are identical to the
-- single-text path -- the two differ only in the request body and the response
-- extraction, so keeping them side by side keeps that policy in one shape.
-- A retry re-sends the whole batch: these endpoints are stateless and pure, so
-- re-embedding a text is wasted work but never wrong.
create procedure DB.DBA.ONNX_HTTP_EMBED_BATCH (
  in _provider varchar,
  in _endpoint varchar,
  in _remote_model varchar,
  in _api_key_name varchar,
  in _dimensions integer,
  in _timeout integer,
  in _texts any,
  in _insecure integer := 0,
  in _model_name varchar := null)
{
  declare _type, _url, _key_name, _api_key, _headers, _body, _status varchar;
  declare _response, _response_headers, _embeddings any;
  declare _attempt, _max, _code, _retryable, _has_key, _n, _i integer;
  declare _wait double precision;
  declare _detail, _body_log varchar;

  _n := length (_texts);
  if (_n = 0)
    return vector ();
  _type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_provider);
  _url := trim (coalesce (_endpoint, ''));
  if (not length (_url))
    _url := DB.DBA.ONNX_HTTP_PROVIDER_DEFAULT_ENDPOINT (_type);
  if (_url is null or not length (_url))
    signal ('22023', 'ONNXP', 'No endpoint configured for HTTP embedding provider');
  if (_remote_model is null or not length (trim (_remote_model)))
    signal ('22023', 'ONNXP', 'HTTP embedding provider model name is required');
  _key_name := trim (coalesce (_api_key_name, ''));
  if (not length (_key_name) and _type = 'openai')
    _key_name := DB.DBA.ONNX_PROVIDER_API_KEY_NAME (_type);
  _api_key := null;
  if (length (_key_name))
    _api_key := trim (cast (registry_get (_key_name) as varchar));
  if (_type = 'openai' and (_api_key is null or not length (_api_key)))
    signal ('42000', 'ONNXP', 'OpenAI embedding requires a configured API key');
  _has_key := case when _api_key is not null and length (_api_key) then 1 else 0 end;
  DB.DBA.ONNX_HTTP_REQUIRE_SECURE_ENDPOINT (_url, _has_key);
  _headers := 'Content-Type: application/json\r\nAccept: application/json';
  if (_has_key)
    _headers := _headers || '\r\nAuthorization: Bearer ' || _api_key;
  -- `input` as a JSON array of strings.  obj2json/array2obj emit a JSON array
  -- for a plain vector, so the texts vector is passed through as the value.
  declare _inputs any;
  _inputs := make_array (_n, 'any');
  for (_i := 0; _i < _n; _i := _i + 1)
    aset (_inputs, _i, cast (_texts[_i] as varchar));
  _body := DB.DBA.obj2json (DB.DBA.array2obj (vector ('model', trim (_remote_model), 'input', _inputs)));

  _max := 3;
  _attempt := 0;
  while (_attempt < _max)
    {
      _attempt := _attempt + 1;
      _retryable := 0;
      _code := 0;
      _detail := null;
      _response := null;
      _response_headers := null;
      {
        declare exit handler for sqlstate '*'
          {
            _detail := __SQL_MESSAGE;
            _retryable := 1;
            goto after_call;
          };
        _response := http_client_ext (url=>_url, http_method=>'POST', http_headers=>_headers,
          body=>_body, headers=>_response_headers, n_redirects=>0,
          timeout=>coalesce (_timeout, 30), insecure=>_insecure);
      }
     after_call:
      if (_detail is null)
        {
          if (_response_headers is null or length (_response_headers) = 0)
            {
              _detail := 'no response headers';
              _retryable := 1;
            }
          else
            {
              _status := cast (_response_headers[0] as varchar);
              _code := DB.DBA.ONNX_HTTP_STATUS_CODE (_status);
              if (_code = 200 or _code = 201)
                {
                  _embeddings := DB.DBA.ONNX_HTTP_EXTRACT_EMBEDDINGS (_response, _n);
                  if (_dimensions is not null and _dimensions > 0)
                    {
                      for (_i := 0; _i < _n; _i := _i + 1)
                        {
                          if (length (_embeddings[_i]) <> _dimensions)
                            signal ('22023', 'ONNXP',
                              sprintf ('HTTP embedding dimension %d at batch position %d does not match registered model dimension %d',
                                length (_embeddings[_i]), _i, _dimensions));
                        }
                    }
                  return _embeddings;
                }
              _detail := _status;
              if (_code = 429 or _code = 500 or _code = 502 or _code = 503 or _code = 504)
                _retryable := 1;
            }
        }
      _body_log := '';
      if (_response is not null)
        _body_log := ' body=' || subseq (cast (_response as varchar), 0, 500);
      log_message (sprintf ('ONNX HTTP embedding provider %s model=%s endpoint=%s batch=%d attempt %d/%d failed: %s%s',
          _type, coalesce (_model_name, _remote_model, '?'), _url, _n, _attempt, _max,
          coalesce (_detail, '?'), _body_log));
      if (not _retryable or _attempt >= _max)
        signal ('42000', 'ONNXP',
          sprintf ('HTTP embedding provider batch request (%d inputs) failed after %d attempt(s); see the server log for the provider response.',
            _n, _attempt));
      _wait := DB.DBA.ONNX_HTTP_RETRY_AFTER (_response_headers);
      if (_wait <= 0)
        _wait := case when _attempt = 1 then 0.5 else 1.0 end;
      delay (_wait);
    }
  signal ('42000', 'ONNXP', 'HTTP embedding provider batch request failed; see the server log for the provider response.');
}
;

create procedure DB.DBA.ONNX_HTTP_EMBED_TEXT (
  in _provider varchar,
  in _endpoint varchar,
  in _remote_model varchar,
  in _api_key_name varchar,
  in _dimensions integer,
  in _timeout integer,
  in _text varchar,
  in _insecure integer := 0,
  in _model_name varchar := null)
{
  declare _type, _url, _key_name, _api_key, _headers, _body, _status varchar;
  declare _response, _response_headers, _embedding any;
  declare _attempt, _max, _code, _retryable, _has_key integer;
  declare _wait double precision;
  declare _detail, _body_log varchar;
  _type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_provider);
  _url := trim (coalesce (_endpoint, ''));
  if (not length (_url))
    _url := DB.DBA.ONNX_HTTP_PROVIDER_DEFAULT_ENDPOINT (_type);
  if (_url is null or not length (_url))
    signal ('22023', 'ONNXP', 'No endpoint configured for HTTP embedding provider');
  if (_remote_model is null or not length (trim (_remote_model)))
    signal ('22023', 'ONNXP', 'HTTP embedding provider model name is required');
  _key_name := trim (coalesce (_api_key_name, ''));
  if (not length (_key_name) and _type = 'openai')
    _key_name := DB.DBA.ONNX_PROVIDER_API_KEY_NAME (_type);
  _api_key := null;
  if (length (_key_name))
    _api_key := trim (cast (registry_get (_key_name) as varchar));
  if (_type = 'openai' and (_api_key is null or not length (_api_key)))
    signal ('42000', 'ONNXP', 'OpenAI embedding requires a configured API key');
  _has_key := case when _api_key is not null and length (_api_key) then 1 else 0 end;
  -- Issue 6: never carry a key over plain http to a public host.
  DB.DBA.ONNX_HTTP_REQUIRE_SECURE_ENDPOINT (_url, _has_key);
  _headers := 'Content-Type: application/json\r\nAccept: application/json';
  if (_has_key)
    _headers := _headers || '\r\nAuthorization: Bearer ' || _api_key;
  _body := DB.DBA.obj2json (DB.DBA.array2obj (vector ('model', trim (_remote_model), 'input', _text)));

  _max := 3;
  _attempt := 0;
  while (_attempt < _max)
    {
      _attempt := _attempt + 1;
      _retryable := 0;
      _code := 0;
      _detail := null;
      _response := null;
      _response_headers := null;
      -- One attempt, isolated so a connection error/timeout is caught and
      -- classified as retryable rather than aborting the whole call.
      -- n_redirects=>0: the client re-sends request headers (including the
      -- Authorization bearer token) on every redirect hop and does not expose
      -- the target, so a redirect could exfiltrate the API key to an arbitrary
      -- host.  Embedding endpoints do not need redirects, so none are followed.
      -- insecure=>_insecure carries the per-model TLS-verify opt-out (0 = verify).
      {
        declare exit handler for sqlstate '*'
          {
            _detail := __SQL_MESSAGE;
            _retryable := 1;                    -- connection reset / timeout / DNS: transient
            goto after_call;
          };
        _response := http_client_ext (url=>_url, http_method=>'POST', http_headers=>_headers,
          body=>_body, headers=>_response_headers, n_redirects=>0,
          timeout=>coalesce (_timeout, 30), insecure=>_insecure);
      }
     after_call:
      if (_detail is null)                       -- the call returned (no exception)
        {
          if (_response_headers is null or length (_response_headers) = 0)
            {
              _detail := 'no response headers';
              _retryable := 1;
            }
          else
            {
              _status := cast (_response_headers[0] as varchar);
              _code := DB.DBA.ONNX_HTTP_STATUS_CODE (_status);
              if (_code = 200 or _code = 201)
                {
                  _embedding := DB.DBA.ONNX_HTTP_EXTRACT_EMBEDDING (_response);
                  if (_dimensions is not null and _dimensions > 0 and length (_embedding) <> _dimensions)
                    signal ('22023', 'ONNXP',
                      sprintf ('HTTP embedding dimension %d does not match registered model dimension %d',
                        length (_embedding), _dimensions));
                  return _embedding;             -- success
                }
              _detail := _status;
              -- Retryable: 429 + transient 5xx.  Everything else (400/401/403/
              -- 404/...) is terminal and must not be retried.
              if (_code = 429 or _code = 500 or _code = 502 or _code = 503 or _code = 504)
                _retryable := 1;
            }
        }
      -- The provider's status line and body can echo the request (user) text,
      -- so the raw detail is written only to the (operator-only) server log,
      -- never returned to the caller.  The body is truncated to keep the log sane.
      _body_log := '';
      if (_response is not null)
        _body_log := ' body=' || subseq (cast (_response as varchar), 0, 500);
      log_message (sprintf ('ONNX HTTP embedding provider %s model=%s endpoint=%s attempt %d/%d failed: %s%s',
          _type, coalesce (_model_name, _remote_model, '?'), _url, _attempt, _max, coalesce (_detail, '?'), _body_log));
      if (not _retryable or _attempt >= _max)
        signal ('42000', 'ONNXP',
          sprintf ('HTTP embedding provider request failed after %d attempt(s); see the server log for the provider response.',
            _attempt));
      -- Backoff before the next attempt: honour Retry-After, else exponential.
      _wait := DB.DBA.ONNX_HTTP_RETRY_AFTER (_response_headers);
      if (_wait <= 0)
        _wait := case when _attempt = 1 then 0.5 else 1.0 end;
      delay (_wait);
    }
  signal ('42000', 'ONNXP', 'HTTP embedding provider request failed; see the server log for the provider response.');
}
;

-- Per-model provider health, surfaced by VVec.  On success the counter is
-- reset only if it was non-zero (the WHERE makes the common path a no-op write,
-- so a healthy provider adds no row write per embed).  On failure the counter is
-- incremented; _detail is the already-redacted generic error (never the raw
-- provider body).  This rides the caller's transaction -- the authoritative
-- record of every failure, including those in a rolled-back synchronous request,
-- is the server log written by ONNX_HTTP_EMBED_TEXT.
create procedure DB.DBA.ONNX_HTTP_NOTE_RESULT (in _model_name varchar, in _ok integer, in _detail varchar)
{
  declare exit handler for sqlstate '*' { return; };   -- health bookkeeping never breaks an embed
  if (not exists (select 1 from DB.DBA.SYS_COLS
        where "TABLE" = 'DB.DBA.ONNX_MODELS' and lower ("COLUMN") = 'provider_consecutive_failures'))
    return;
  if (_ok)
    update DB.DBA.ONNX_MODELS set provider_consecutive_failures = 0, provider_last_error = null
      where model_name = _model_name and coalesce (provider_consecutive_failures, 0) <> 0;
  else
    update DB.DBA.ONNX_MODELS
      set provider_consecutive_failures = coalesce (provider_consecutive_failures, 0) + 1,
          provider_last_error = subseq (coalesce (_detail, 'error'), 0, 400),
          provider_last_error_at = now ()
      where model_name = _model_name;
}
;

create procedure DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL (in _model_name varchar, in _text varchar)
{
  declare _handle, _dimensions, _insecure integer;
  declare _type, _remote_model, _endpoint, _key_name varchar;
  declare _timeout integer;
  declare _embedding, _meta, _rows any;
  declare _stat, _msg varchar;
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.ONNX_MODELS'))
    signal ('42S02', 'DB.DBA.ONNX_MODELS is not initialized');
  whenever not found goto missing_model;
  select model_type, model_path, provider_endpoint, provider_api_key_name,
         provider_dimensions, provider_timeout, handle, coalesce (provider_insecure, 0)
    into _type, _remote_model, _endpoint, _key_name, _dimensions, _timeout, _handle, _insecure
    from DB.DBA.ONNX_MODELS where model_name = _model_name;
  _type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_type);
  if (_type in ('openai', 'ollama', 'lmstudio', 'openai_compatible'))
    {
      declare exit handler for sqlstate '*'
        {
          DB.DBA.ONNX_HTTP_NOTE_RESULT (_model_name, 0, __SQL_MESSAGE);
          resignal;
        };
      _embedding := DB.DBA.ONNX_HTTP_EMBED_TEXT (_type, _endpoint, _remote_model, _key_name,
          _dimensions, _timeout, _text, _insecure, _model_name);
      DB.DBA.ONNX_HTTP_NOTE_RESULT (_model_name, 1, null);
      return _embedding;
    }
  if (_type in ('test_embedding', 'vvec_test_embedding', 'unavailable'))
    signal ('42000', 'ONNXP', sprintf ('Model %s is not available for ONNX embedding', _model_name));
  if (_handle is null or _handle = 0)
    _handle := DB.DBA.ONNX_MODEL_REFRESH (_model_name);
  if (_handle is null or _handle = 0)
    signal ('42000', 'ONNXP', sprintf ('ONNX model %s is not loaded', _model_name));
  _stat := '00000';
  exec ('select ONNX_EMBED_TEXT (?, ?)', _stat, _msg, vector (_handle, _text), 1, _meta, _rows);
  if (_stat <> '00000')
    signal (_stat, _msg);
  if (_rows is null or length (_rows) = 0)
    return null;
  return _rows[0][0];

missing_model:
  signal ('42S02', 'ONNXP', sprintf ('Model %s is not present in DB.DBA.ONNX_MODELS', _model_name));
}
;

-- Batch counterpart of ONNX_EMBED_TEXT_FOR_MODEL.  Returns a vector of
-- embeddings, one per input text, in order.
--
-- For an HTTP provider this issues one request per provider_max_batch inputs
-- instead of one request per text.  Health bookkeeping is per chunk, so a
-- provider that starts failing part-way through a large batch is recorded with
-- the same granularity as before.
--
-- For a local ONNX model it hands the whole batch to ONNX_EMBED_BATCH, which is
-- what the caller would have done anyway; having one entry point that batches
-- for every model type is the point, so callers stop having to know which
-- provider is behind a model name.
create procedure DB.DBA.ONNX_EMBED_BATCH_FOR_MODEL (in _model_name varchar, in _texts any)
{
  declare _handle, _dimensions, _insecure, _max_batch integer;
  declare _type, _remote_model, _endpoint, _key_name varchar;
  declare _timeout integer;
  declare _result, _chunk, _part, _meta, _rows any;
  declare _n, _i, _j, _take integer;
  declare _stat, _msg varchar;

  _n := length (_texts);
  if (_n = 0)
    return vector ();
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.ONNX_MODELS'))
    signal ('42S02', 'DB.DBA.ONNX_MODELS is not initialized');
  whenever not found goto missing_model;
  select model_type, model_path, provider_endpoint, provider_api_key_name,
         provider_dimensions, provider_timeout, handle, coalesce (provider_insecure, 0)
    into _type, _remote_model, _endpoint, _key_name, _dimensions, _timeout, _handle, _insecure
    from DB.DBA.ONNX_MODELS where model_name = _model_name;
  _type := DB.DBA.ONNX_HTTP_PROVIDER_NORMALIZE (_type);

  if (_type in ('openai', 'ollama', 'lmstudio', 'openai_compatible'))
    {
      _max_batch := DB.DBA.ONNX_HTTP_MODEL_MAX_BATCH (_model_name, _type);
      _result := make_array (_n, 'any');
      _i := 0;
      while (_i < _n)
        {
          declare exit handler for sqlstate '*'
            {
              DB.DBA.ONNX_HTTP_NOTE_RESULT (_model_name, 0, __SQL_MESSAGE);
              resignal;
            };
          _take := _max_batch;
          if (_i + _take > _n)
            _take := _n - _i;
          _chunk := make_array (_take, 'any');
          for (_j := 0; _j < _take; _j := _j + 1)
            aset (_chunk, _j, cast (_texts[_i + _j] as varchar));
          _part := DB.DBA.ONNX_HTTP_EMBED_BATCH (_type, _endpoint, _remote_model, _key_name,
              _dimensions, _timeout, _chunk, _insecure, _model_name);
          for (_j := 0; _j < _take; _j := _j + 1)
            aset (_result, _i + _j, _part[_j]);
          DB.DBA.ONNX_HTTP_NOTE_RESULT (_model_name, 1, null);
          _i := _i + _take;
        }
      return _result;
    }

  if (_type in ('test_embedding', 'vvec_test_embedding', 'unavailable'))
    signal ('42000', 'ONNXP', sprintf ('Model %s is not available for ONNX embedding', _model_name));
  if (_handle is null or _handle = 0)
    _handle := DB.DBA.ONNX_MODEL_REFRESH (_model_name);
  if (_handle is null or _handle = 0)
    signal ('42000', 'ONNXP', sprintf ('ONNX model %s is not loaded', _model_name));
  -- Chunk for a local model too, the way the provider branch above already
  -- does.  The plugin refuses a batch larger than max_batch -- 32 by default --
  -- so handing it the whole array made this procedure succeed against a remote
  -- provider and fail against a local model at the 33rd text.  Hiding exactly
  -- that difference is what this procedure is for.
  --
  -- 32 is hard-coded because max_batch is write-only from PL: ONNX_CONFIG sets
  -- it and nothing reads it back, so a caller cannot ask what it must respect.
  -- It is the plugin's own default and the chunk sparql_vec_index.sql already
  -- uses, so the two agree on what one embedding call costs.  Raising the
  -- plugin's limit will not raise this one; making it readable is the better
  -- fix and is a separate change.
  _max_batch := 32;
  _result := make_array (_n, 'any');
  _i := 0;
  while (_i < _n)
    {
      _take := _max_batch;
      if (_i + _take > _n)
        _take := _n - _i;
      _chunk := make_array (_take, 'any');
      for (_j := 0; _j < _take; _j := _j + 1)
        aset (_chunk, _j, _texts[_i + _j]);
      _stat := '00000';
      exec ('select ONNX_EMBED_BATCH (?, ?)', _stat, _msg, vector (_handle, _chunk), 1, _meta, _rows);
      if (_stat <> '00000')
        signal (_stat, _msg);
      if (_rows is null or length (_rows) = 0)
        return null;
      _part := _rows[0][0];
      if (_part is null or length (_part) <> _take)
        signal ('22023', 'ONNXP',
            sprintf ('ONNX_EMBED_BATCH returned %d embeddings for %d texts',
                     case when _part is null then 0 else length (_part) end, _take));
      for (_j := 0; _j < _take; _j := _j + 1)
        aset (_result, _i + _j, _part[_j]);
      _i := _i + _take;
    }
  return _result;

missing_model:
  signal ('42S02', 'ONNXP', sprintf ('Model %s is not present in DB.DBA.ONNX_MODELS', _model_name));
}
;

-- Effective inputs-per-request for a model: the per-model override if set,
-- else the provider default.
--
-- The override is read through exec() rather than as static SQL because
-- provider_max_batch does not exist on a database whose ONNX_MODELS predates
-- it.  Static SQL would make the missing column a *compile-time* error, so
-- this procedure would fail to be defined at all on such a database and no
-- runtime guard could save it -- the SYS_COLS check below only protects a
-- statement that is compiled when it runs.
create procedure DB.DBA.ONNX_HTTP_MODEL_MAX_BATCH (in _model_name varchar, in _type varchar)
{
  declare _dflt integer;
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  _dflt := DB.DBA.ONNX_HTTP_PROVIDER_MAX_BATCH (_type);
  if (not exists (select 1 from DB.DBA.SYS_COLS
        where "TABLE" = 'DB.DBA.ONNX_MODELS' and lower ("COLUMN") = 'provider_max_batch'))
    return _dflt;
  _stat := '00000';
  exec ('select provider_max_batch from DB.DBA.ONNX_MODELS where model_name = ?',
      _stat, _msg, vector (_model_name), 0, _meta, _rows);
  if (_stat <> '00000' or _rows is null or length (_rows) = 0)
    return _dflt;
  if (_rows[0][0] is null or cast (_rows[0][0] as integer) < 1)
    return _dflt;
  return cast (_rows[0][0] as integer);
}
;

-- Split text into the sentences that summarisation scores.
--
-- A sentence ends at '.', '!' or '?'.  A fragment of _min_length characters or
-- fewer is dropped rather than returned: an abbreviation, an initial or a
-- decimal point ends a "sentence" that is not one, and embedding it would only
-- pull the document centroid towards noise.  20 is the threshold summarisation
-- has always used here; it is a parameter so that unusually terse text can
-- lower it, not because the default is in question.
--
-- This walks the text a character at a time rather than searching for the next
-- terminator.  The cost is linear either way and is dwarfed by the embedding
-- that follows -- a sentence takes tens of milliseconds to embed and tens of
-- microseconds to find -- whereas locate() raises 22023 unless it is told
-- whether it is looking at a narrow or a wide string.
create procedure DB.DBA.ONNX_SUMMARY_SENTENCES (in _txt varchar, in _min_length integer := 20)
{
  declare _res any;
  declare _i, _n, _start, _dot, _bang, _question integer;
  declare _c integer;
  declare _s varchar;

  _res := vector ();
  if (_txt is null)
    return _res;

  -- Read as codepoints, so that the same comparison holds for a narrow and a
  -- wide string.  '.', '!' and '?' are below 128 and agree in both.
  _dot := aref ('.', 0);
  _bang := aref ('!', 0);
  _question := aref ('?', 0);

  _n := length (_txt);
  _start := 0;
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      _c := aref (_txt, _i);
      if (_c = _dot or _c = _bang or _c = _question)
        {
          _s := trim (subseq (_txt, _start, _i + 1));
          if (length (_s) > _min_length)
            _res := vector_concat (_res, vector (_s));
          _start := _i + 1;
        }
    }
  if (_start < _n)
    {
      _s := trim (subseq (_txt, _start, _n));
      if (length (_s) > _min_length)
        _res := vector_concat (_res, vector (_s));
    }
  return _res;
}
;

-- Summarise _txt by keeping the _keep sentences closest to what it is about.
--
-- The method is the one an embedding model already gives us.  Embed every
-- sentence, sum the embeddings to get a point that stands for the document as
-- a whole, then keep the sentences nearest that point by cosine similarity.  A
-- sentence about something else is by construction the furthest from the
-- centroid, so it is the first to go.  The kept sentences are emitted in the
-- order they appear, not in score order, so the result still reads.
--
-- This is extractive, not abstractive: every sentence of the result is a
-- sentence of the input, verbatim.  Nothing can be invented -- and equally,
-- nothing is rephrased or shortened.  An abstractive summary needs an
-- autoregressive decoder, which the single-shot ONNX bridge does not run.
--
-- _keep is a count of sentences, not a ratio or a character budget.  The
-- result has exactly _keep sentences, unless the text does not have more than
-- that to begin with, in which case it comes back unchanged.
--
-- _model_name is any row of DB.DBA.ONNX_MODELS.  The embeddings are taken
-- through ONNX_EMBED_BATCH_FOR_MODEL, which is the one entry point that knows
-- whether a model is local or a remote provider, so summarisation works over
-- either without knowing the difference -- and in one call rather than one per
-- sentence.
create procedure DB.DBA.ONNX_SUMMARIZE (in _txt varchar,
                                        in _keep integer := 3,
                                        in _model_name varchar := 'granite-384-local')
{
  declare _sents, _embs, _emb, _centroid, _scores, _chosen any;
  declare _i, _j, _d, _ns, _pick integer;
  declare _norm, _dot, _len, _x, _top double precision;
  declare _res varchar;

  if (_txt is null)
    return null;
  if (_keep is null or _keep < 1)
    signal ('22023', 'ONNXP',
        'ONNX_SUMMARIZE: the number of sentences to keep must be at least 1');

  _sents := DB.DBA.ONNX_SUMMARY_SENTENCES (_txt);
  _ns := length (_sents);
  if (_ns <= _keep)
    return _txt;

  -- One call for the whole document.  ONNX_EMBED_BATCH_FOR_MODEL chunks
  -- internally, for a local model as well as a remote provider, so a document
  -- of any length is embedded without the caller sizing anything.
  _embs := DB.DBA.ONNX_EMBED_BATCH_FOR_MODEL (_model_name, _sents);
  if (_embs is null or length (_embs) <> _ns)
    signal ('22023', 'ONNXP',
        sprintf ('ONNX_SUMMARIZE: model %s returned %d embeddings for %d sentences',
                 _model_name,
                 case when _embs is null then 0 else length (_embs) end, _ns));
  -- Read the width off the first embedding, so check that one before using it.
  -- The rest are checked against this width as the centroid is accumulated.
  if (aref (_embs, 0) is null or length (aref (_embs, 0)) = 0)
    signal ('22023', 'ONNXP',
        sprintf ('ONNX_SUMMARIZE: model %s returned an empty embedding', _model_name));
  _d := length (aref (_embs, 0));

  -- The sum stands in for the mean: cosine similarity ignores the length of
  -- the vector it is compared against, and every sentence counts once.
  _centroid := make_array (_d, 'double');
  for (_i := 0; _i < _ns; _i := _i + 1)
    {
      _emb := aref (_embs, _i);
      if (_emb is null or length (_emb) <> _d)
        signal ('22023', 'ONNXP',
            sprintf ('ONNX_SUMMARIZE: model %s returned embeddings of differing width',
                     _model_name));
      for (_j := 0; _j < _d; _j := _j + 1)
        aset (_centroid, _j, aref (_centroid, _j) + cast (aref (_emb, _j) as double precision));
    }
  _norm := 0;
  for (_j := 0; _j < _d; _j := _j + 1)
    _norm := _norm + aref (_centroid, _j) * aref (_centroid, _j);
  _norm := sqrt (_norm);

  -- A zero centroid means the sentences cancelled out exactly and no sentence
  -- is more central than another.  Leaving every score at zero makes the
  -- selection below take the first _keep in reading order, which is the honest
  -- answer when the scores carry no information.
  _scores := make_array (_ns, 'double');
  if (_norm > 0)
    {
      for (_i := 0; _i < _ns; _i := _i + 1)
        {
          _emb := aref (_embs, _i);
          _dot := 0;
          _len := 0;
          for (_j := 0; _j < _d; _j := _j + 1)
            {
              _x := cast (aref (_emb, _j) as double precision);
              _dot := _dot + _x * aref (_centroid, _j);
              _len := _len + _x * _x;
            }
          if (_len > 0)
            aset (_scores, _i, _dot / (sqrt (_len) * _norm));
        }
    }

  _chosen := make_array (_ns, 'long');
  for (_i := 0; _i < _keep; _i := _i + 1)
    {
      _pick := -1;
      _top := -2;
      for (_j := 0; _j < _ns; _j := _j + 1)
        if (aref (_chosen, _j) = 0 and aref (_scores, _j) > _top)
          {
            _top := aref (_scores, _j);
            _pick := _j;
          }
      if (_pick >= 0)
        aset (_chosen, _pick, 1);
    }

  _res := '';
  for (_i := 0; _i < _ns; _i := _i + 1)
    if (aref (_chosen, _i) = 1)
      _res := _res || case when _res = '' then '' else ' ' end || aref (_sents, _i);
  return _res;
}
;

create procedure DB.DBA.ONNX_BOOTSTRAP_MODELS ()
{
  declare loaded integer;
  declare stat, msg varchar;
  declare meta, rows any;
  declare inx integer;
  loaded := 0;
  DB.DBA.ONNX_REGISTER_DEFAULT_MODELS ();
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.ONNX_MODELS'))
    return 0;
  stat := '00000';
  exec ('select model_name from DB.DBA.ONNX_MODELS where model_type not in (''test_embedding'', ''vvec_test_embedding'', ''unavailable'')',
      stat, msg, vector (), 0, meta, rows);
  if (stat <> '00000' or rows is null)
    {
      log_message (sprintf ('ONNX bootstrap registry scan skipped: [%s] %s', stat, msg));
      return 0;
    }
  inx := 0;
  while (inx < length (rows))
    {
      if (DB.DBA.ONNX_MODEL_REFRESH (cast (rows[inx][0] as varchar)) <> 0)
	loaded := loaded + 1;
      inx := inx + 1;
    }
  log_message (sprintf ('ONNX bootstrap refreshed %d model(s)', loaded));
  return loaded;
}
;

DB.DBA.ONNX_REGISTRY_INIT ()
;

--!AFTER
DB.DBA.ONNX_BOOTSTRAP_MODELS ()
;
