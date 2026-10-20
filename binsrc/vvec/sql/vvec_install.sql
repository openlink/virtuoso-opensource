-- ============================================================================
--  VVec - Virtuoso Vector Index management dashboard (VSP)
--  vvec_install.sql : the VAD's install SQL.
--
--  Loaded by the VVec VAD (vvec_dav.vad) via VAD_LOAD_SQL_FILE after the
--  engine has uploaded the .vsp pages and the stylesheet into DAV.  It defines
--  the console's helper procedures, rebuilds the inline-CSS emitter from the
--  uploaded stylesheet, and maps the /vvec/ virtual directory.  It reads no
--  files from disk (so it needs no DirsAllowed entry) and uses no DAV password.
--  Idempotent: re-running it (a VAD upgrade) redefines the procedures and the
--  vhost mapping cleanly.
--
--  Install the console with the Conductor VAD manager, or from isql:
--    vad_install ('<path>/vvec_dav.vad', 0);
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Metric label helper (KEY_OPTIONS may store a code or a string).
-- ---------------------------------------------------------------------------
-- Returns HTML-ready output (ASCII entity for the empty case, HTML-escaped
-- otherwise) so callers emit it with raw http(), never http_value. Keeping all
-- emitted bytes ASCII avoids Virtuoso's narrow-string -> UTF-8 double-encoding.
create procedure DB.DBA.VVEC_METRIC_LABEL (in v any)
{
  declare s varchar;
  if (v is null)
    return '&mdash;';
  s := trim (cast (v as varchar));
  if (s = '1') return 'cosine';
  if (s = '2') return 'l2';
  if (s = '3') return 'l1';
  return sprintf ('%V', lower (s));
}
;

-- ---------------------------------------------------------------------------
-- 2. Input validation helpers (defend the DDL string builders).
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_IDENT_OK (in s varchar)
{
  -- A safe SQL identifier for an index name: letter/underscore, then word chars.
  -- (Anchors avoided so the isql command-line loader does not treat the dollar sign as a macro.)
  if (s is null or length (s) = 0 or length (s) > 100)
    return 0;
  if (regexp_match ('^[A-Za-z_]', s) is null)            -- must start with a letter or underscore
    return 0;
  if (regexp_match ('[^A-Za-z0-9_]', s) is not null)     -- reject any other character
    return 0;
  return 1;
}
;

create procedure DB.DBA.VVEC_IRI_OK (in s varchar)
{
  -- An IRI safe to place inside <...> in a SPARQL statement: no ctrl chars,
  -- whitespace, or characters that would break out of the angle brackets.
  declare i, n, c integer;
  if (s is null)
    return 0;
  n := length (s);
  if (n = 0 or n > 2000)
    return 0;
  i := 0;
  while (i < n)
    {
      c := aref (s, i);
      -- reject ctrl/space (<=32) and  < > " \ { } | ^ `
      if (c <= 32 or c = 60 or c = 62 or c = 34 or c = 92 or c = 123 or c = 125 or c = 124 or c = 94 or c = 96)
        return 0;
      i := i + 1;
    }
  return 1;
}
;

-- Structural gate for the free-form SPARQL group-graph-pattern that the "general
-- selector" on create.vsp interpolates into
--   create vector index <..> key ?k embedding ?e where { <PATTERN> } using ...
-- executed as dba.  A regex cannot constrain SPARQL, so this scans the pattern
-- once, tracking IRI (<...>) and string-literal ('...' "..." '''...''' """...""")
-- state, and rejects anything that could break out of the caller's group and
-- append statements/pragmas:
--   * { } that are unbalanced or ever go negative left-to-right (the injection
--     `?s ?p ?o } ; DROP ... #` is caught the instant the stray `}` drops the
--     depth below zero) -- braces inside IRIs/literals do not count;
--   * a `#` line comment or any control character outside a triple-quoted literal;
--   * an unterminated IRI or string literal, or a stray `\` outside a literal;
--   * the update/DDL keywords that have no place in a selector pattern
--     (INSERT/DELETE/LOAD/CLEAR/DROP/CREATE/COPY/MOVE/ADD/WITH/USING) or a
--     `define` pragma, matched on token boundaries and ignoring IRI/literal text;
--   * anything longer than 4000 chars.
-- `<` is disambiguated from a comparison operator by look-ahead (an IRI ref has
-- no whitespace before its closing `>`), so FILTER (?x < ?y) is still accepted.
-- Returns 1 when the pattern is structurally safe to interpolate, else 0.
create procedure DB.DBA.VVEC_SPARQL_PATTERN_OK (in s varchar)
{
  declare n, i, depth, c, st, j, cj, isiri integer;
  declare norm, u varchar;
  if (s is null or not isstring (s))
    return 0;
  n := length (s);
  if (n = 0 or n > 4000)
    return 0;
  depth := 0;
  st := 0;          -- 0 normal, 1 IRI, 2 '..', 3 "..", 4 '''..''', 5 """.."""
  norm := '';       -- structural text: alnum/_ kept, everything else -> space,
                    -- IRI and literal contents dropped -> used for keyword scan
  i := 0;
  while (i < n)
    {
      c := aref (s, i);
      if (c < 32 and c <> 9 and c <> 10 and c <> 13 and st < 4)
        return 0;   -- control char (tab/nl/cr only tolerated, and only in triple-quotes for others)
      if (st = 0)
        {
          if (c = 35)                       -- '#'
            return 0;
          else if (c = 123) { depth := depth + 1; norm := norm || ' '; }
          else if (c = 125) { depth := depth - 1; if (depth < 0) return 0; norm := norm || ' '; }
          else if (c = 92)                  -- stray backslash outside a literal
            return 0;
          else if (c = 60)                  -- '<' : IRI ref or comparison operator?
            {
              isiri := 0; j := i + 1;
              while (j < n and isiri = 0)
                {
                  cj := aref (s, j);
                  if (cj = 62) isiri := 1;                                   -- '>' before any space -> IRI
                  else if (cj = 32 or cj = 9 or cj = 10 or cj = 13 or cj = 60 or cj = 123 or cj = 125)
                    j := n;                                                  -- whitespace/</{/} first -> operator
                  else j := j + 1;
                }
              if (isiri) st := 1;
              norm := norm || ' ';
            }
          else if (c = 39)                  -- '
            {
              if (i + 2 < n and aref (s, i+1) = 39 and aref (s, i+2) = 39) { st := 4; i := i + 2; }
              else st := 2;
              norm := norm || ' ';
            }
          else if (c = 34)                  -- "
            {
              if (i + 2 < n and aref (s, i+1) = 34 and aref (s, i+2) = 34) { st := 5; i := i + 2; }
              else st := 3;
              norm := norm || ' ';
            }
          else if ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c = 95)
            norm := norm || chr (c);        -- alnum or _
          else
            norm := norm || ' ';            -- punctuation/space -> token boundary
        }
      else if (st = 1)                      -- inside <IRI>
        {
          if (c = 62) st := 0;
          else if (c = 60 or c = 34 or c = 123 or c = 125 or c = 32 or c = 9 or c = 10 or c = 13)
            return 0;                        -- illegal inside an IRI ref
        }
      else if (st = 2)                      -- '...'
        {
          if (c = 92) i := i + 1;            -- escape: skip next char
          else if (c = 39) st := 0;
          else if (c = 10 or c = 13) return 0;
        }
      else if (st = 3)                      -- "..."
        {
          if (c = 92) i := i + 1;
          else if (c = 34) st := 0;
          else if (c = 10 or c = 13) return 0;
        }
      else if (st = 4)                      -- '''...'''
        {
          if (c = 92) i := i + 1;
          else if (c = 39 and i + 2 < n and aref (s, i+1) = 39 and aref (s, i+2) = 39) { st := 0; i := i + 2; }
        }
      else if (st = 5)                      -- """..."""
        {
          if (c = 92) i := i + 1;
          else if (c = 34 and i + 2 < n and aref (s, i+1) = 34 and aref (s, i+2) = 34) { st := 0; i := i + 2; }
        }
      i := i + 1;
    }
  if (depth <> 0 or st <> 0)                -- unbalanced braces / unterminated IRI or literal
    return 0;
  u := ' ' || ucase (norm) || ' ';
  if (u like '% INSERT %' or u like '% DELETE %' or u like '% LOAD %' or u like '% CLEAR %'
      or u like '% DROP %' or u like '% CREATE %' or u like '% COPY %' or u like '% MOVE %'
      or u like '% ADD %' or u like '% WITH %' or u like '% USING %' or u like '% DEFINE %')
    return 0;
  return 1;
}
;

create procedure DB.DBA.VVEC_SPARQL_STR (in s varchar)
{
  -- Escape a value for use inside a SPARQL double-quoted string literal.
  if (s is null)
    return '';
  s := replace (s, chr (92), chr (92) || chr (92));   -- backslash
  s := replace (s, chr (34), chr (92) || chr (34));   -- double quote
  s := replace (s, chr (13), ' ');
  s := replace (s, chr (10), ' ');
  s := replace (s, chr (9),  ' ');
  return s;
}
;

-- ---------------------------------------------------------------------------
-- 3. Enumerate relational (SQL-side) vector indexes.
--    A vector index is a key whose KEY_OPTIONS carry the source column (sc),
--    primary-key column (pk) and model id (mid) markers.
--    Returns rows of: name, table, source_col, pk_col, model, dims, metric,
--                      state, reduce.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_SQL_INDEXES ()
{
  declare res any;
  declare _sc, _pk, _mid, _d, _mt, _st, _rd, _mname varchar;
  res := vector ();
  for (select KEY_NAME as kn, KEY_TABLE as ktb, KEY_OPTIONS as ko
         from DB.DBA.SYS_KEYS
        where KEY_MIGRATE_TO is null and KEY_OPTIONS is not null) do
    {
      _sc  := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'sc') as varchar);
      _pk  := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'pk') as varchar);
      _mid := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'mid') as varchar);
      -- Skip the hidden backing index of a SPARQL vector index: it is a native
      -- vector-index key too, but it belongs to the RDF surface, not the SQL one.
      if (_sc is not null and _pk is not null and _mid is not null
          and not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_INTERNAL_NAME = kn))
        {
          _d  := cast (coalesce (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'd'),
                                 DB.DBA.VEC_SQL_INDEX_OPT (ko, 'dimensions'),
                                 DB.DBA.VEC_SQL_INDEX_OPT (ko, 'dimension')) as varchar);
          _mt := cast (coalesce (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'mt'),
                                 DB.DBA.VEC_SQL_INDEX_OPT (ko, 'distance_metric'),
                                 DB.DBA.VEC_SQL_INDEX_OPT (ko, 'metric')) as varchar);
          _st := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'st') as varchar);
          _rd := cast (coalesce (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'rd'),
                                 DB.DBA.VEC_SQL_INDEX_OPT (ko, 'reduce')) as varchar);
          _mname := coalesce ((select model_name from DB.DBA.ONNX_MODELS where model_id = atoi (_mid)), _mid);
          res := vector_concat (res, vector (
                   vector (kn, ktb, _sc, _pk, _mname, coalesce (_d, ''),
                           DB.DBA.VVEC_METRIC_LABEL (_mt),
                           coalesce (_st, 'active'), coalesce (_rd, 'none'))));
        }
    }
  return res;
}
;

-- ---------------------------------------------------------------------------
-- 4. Look up the base table + source/pk column + bound model for one SQL
--    vector index. Returns vector(table, source_col, pk_col, model) or NULL.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_SQL_INDEX_INFO (in _name varchar)
{
  declare _sc, _pk, _mid, _model, ktb varchar;
  declare ko any;
  whenever not found goto nf;
  select KEY_TABLE, KEY_OPTIONS into ktb, ko
    from DB.DBA.SYS_KEYS
   where KEY_NAME = _name and KEY_MIGRATE_TO is null;
  _sc  := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'sc') as varchar);
  _pk  := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'pk') as varchar);
  _mid := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'mid') as varchar);
  if (_sc is null or _pk is null)
    return null;
  _model := coalesce ((select model_name from DB.DBA.ONNX_MODELS where model_id = atoi (_mid)), _mid);
  return vector (ktb, _sc, _pk, _model);
nf:
  return null;
}
;

-- ---------------------------------------------------------------------------
-- 5. Candidate targets for a new SQL vector index: user base tables with a
--    single-column integer primary key and at least one text column.
--    Returns rows of: table, pk_col, comma-separated char columns.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_SQL_TARGETS ()
{
  declare res, cols any;
  declare kid integer;
  declare ktb, pk_col, pk_dtp, cn varchar;
  declare cd integer;
  res := vector ();
  for (select KEY_ID as k_id, KEY_TABLE as k_tb
         from DB.DBA.SYS_KEYS
        where KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null and KEY_DECL_PARTS = 1
          and KEY_TABLE like 'DB.DBA.%'
          and KEY_TABLE not like 'DB.DBA.SYS[_]%'
          and KEY_TABLE not like 'DB.DBA.RDF[_]%'
          and KEY_TABLE not like 'DB.DBA.VEC[_]%'
          and KEY_TABLE not like 'DB.DBA.ONNX[_]%'
          and KEY_TABLE not like 'DB.DBA.SPARQL[_]%') do
    {
      kid := k_id; ktb := k_tb; pk_col := null; pk_dtp := null;
      for (select tc."COLUMN" as c_n, tc.COL_DTP as c_d
             from DB.DBA.SYS_KEY_PARTS kp, DB.DBA.TABLE_COLS tc
            where kp.KP_KEY_ID = kid and kp.KP_NTH = 0
              and tc."TABLE" = ktb and tc.COL_ID = kp.KP_COL) do
        { pk_col := c_n; pk_dtp := dv_type_title (c_d); }
      -- Require a real, declared integer PK. Virtuoso adds a synthetic "_IDN"
      -- identity key to views / procedure-views / keyless tables; skip those.
      if (pk_col is null or pk_col = '_IDN' or pk_dtp <> 'INTEGER')
        goto next_tbl;
      cols := '';
      for (select tc."COLUMN" as c_n, tc.COL_DTP as c_d
             from DB.DBA.TABLE_COLS tc where tc."TABLE" = ktb order by tc.COL_ID) do
        {
          if (dv_type_title (c_d) in ('VARCHAR', 'LONG VARCHAR'))
            {
              if (cols <> '') cols := cols || ',';
              cols := cols || c_n;
            }
        }
      if (cols <> '')
        res := vector_concat (res, vector (vector (ktb, pk_col, cols)));
     next_tbl:;
    }
  return res;
}
;

-- ---------------------------------------------------------------------------
-- 5b. JSON string escaper (for the table-lookup AJAX endpoint).  Virtuoso SQL
--     string literals do not process backslash escapes, so build the escape
--     sequences from chr() rather than from literal "\" text.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_JSON_ESC (in s varchar)
{
  declare bs, dq varchar;
  if (s is null)
    return '';
  s  := cast (s as varchar);
  bs := chr (92);   -- backslash
  dq := chr (34);   -- double quote
  s := replace (s, bs, bs || bs);
  s := replace (s, dq, bs || dq);
  s := replace (s, chr (13), bs || 'r');
  s := replace (s, chr (10), bs || 'n');
  s := replace (s, chr (9),  bs || 't');
  -- JSON forbids any raw control character in a string, not just the three with
  -- short escapes. A stray one (most likely arriving through a SQL error
  -- message rather than an IRI) would otherwise produce a body that the
  -- client's r.json() rejects outright, turning a reportable error into a
  -- silent "lookup failed".
  {
    declare i, c integer;
    declare outp varchar;
    outp := '';
    i := 0;
    while (i < length (s))
      {
        c := aref (s, i);
        if (c < 32)
          outp := outp || sprintf ('%su%04x', bs, c);
        else
          outp := outp || chr (c);
        i := i + 1;
      }
    s := outp;
  }
  return s;
}
;

-- ---------------------------------------------------------------------------
-- 5c. Resolve a user-typed table name to a create-eligible target.  Applies
--     the SAME rules as VVEC_SQL_TARGETS (single declared INTEGER PK, at
--     least one VARCHAR/LONG VARCHAR column, no system tables) but for one
--     named table, and reports WHY a table is rejected so the UI can explain.
--     Returns vector (status, qualified_table, pk_col, cols_vector, reason):
--       status 'ok'         -> qualified_table, pk_col, cols_vector are set
--       status 'ineligible' -> qualified_table + reason are set
--       status 'notfound'   -> the name matched no base table
--       status 'empty'      -> no name supplied
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_TABLE_LOOKUP (in _name varchar)
{
  declare _tb, _cand, pk_col, pk_dtp, c_name varchar;
  declare _kid, _kdp, c_dtp integer;
  declare _cols any;

  _name := trim (cast (coalesce (_name, '') as varchar));
  if (_name = '')
    return vector ('empty', '', '', vector (), '');

  -- Resolve to a fully-qualified base table.  Accept the name as typed
  -- (case-insensitively) and, when unqualified, also under DB.DBA.
  _tb := null; _kid := null; _kdp := null;
  _cand := 'DB.DBA.' || _name;
  for (select KEY_TABLE as ktb, KEY_ID as kid, KEY_DECL_PARTS as kdp
         from DB.DBA.SYS_KEYS
        where KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null
          and (KEY_TABLE = _name or upper (KEY_TABLE) = upper (_name)
               or KEY_TABLE = _cand or upper (KEY_TABLE) = upper (_cand))
        order by KEY_TABLE) do
    { _tb := ktb; _kid := kid; _kdp := kdp; goto resolved; }
 resolved:;

  if (_tb is null)
    return vector ('notfound', '', '', vector (), '');

  -- Never index server-internal tables (mirror the VVEC_SQL_TARGETS filter).
  if (_tb like 'DB.DBA.SYS[_]%' or _tb like 'DB.DBA.RDF[_]%'
      or _tb like 'DB.DBA.VEC[_]%' or _tb like 'DB.DBA.ONNX[_]%'
      or _tb like 'DB.DBA.SPARQL[_]%' or _tb like 'WS.WS.%')
    return vector ('ineligible', _tb, '', vector (), 'System tables cannot be indexed.');

  -- Require a single, declared, INTEGER primary key (skip the synthetic _IDN
  -- key Virtuoso adds to views / keyless tables).
  if (_kdp <> 1)
    return vector ('ineligible', _tb, '', vector (), 'Requires a single-column primary key.');
  pk_col := null; pk_dtp := null;
  for (select tc."COLUMN" as c_n, tc.COL_DTP as c_d
         from DB.DBA.SYS_KEY_PARTS kp, DB.DBA.TABLE_COLS tc
        where kp.KP_KEY_ID = _kid and kp.KP_NTH = 0
          and tc."TABLE" = _tb and tc.COL_ID = kp.KP_COL) do
    { pk_col := c_n; pk_dtp := dv_type_title (c_d); }
  if (pk_col is null or pk_col = '_IDN' or pk_dtp <> 'INTEGER')
    return vector ('ineligible', _tb, '', vector (), 'The primary key must be a single INTEGER column.');

  -- Collect the embeddable text columns.
  _cols := vector ();
  for (select tc."COLUMN" as c_n, tc.COL_DTP as c_d
         from DB.DBA.TABLE_COLS tc where tc."TABLE" = _tb order by tc.COL_ID) do
    {
      if (dv_type_title (c_d) in ('VARCHAR', 'LONG VARCHAR'))
        _cols := vector_concat (_cols, vector (c_n));
    }
  if (length (_cols) = 0)
    return vector ('ineligible', _tb, pk_col, vector (), 'No VARCHAR or LONG VARCHAR column to embed.');

  return vector ('ok', _tb, pk_col, _cols, '');
}
;

-- ---------------------------------------------------------------------------
-- 5d. JSON rendering of a table lookup, for lookup.vsp.  Emits ASCII-safe JSON
--     with every string value passed through VVEC_JSON_ESC.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_TABLE_LOOKUP_JSON (in _name varchar)
{
  declare _r, _cols any;
  declare _out, _st, _tb, _pk, _reason, dq varchar;
  declare i integer;

  dq := chr (34);
  _r := DB.DBA.VVEC_TABLE_LOOKUP (_name);
  _st := _r[0]; _tb := _r[1]; _pk := _r[2]; _cols := _r[3]; _reason := _r[4];

  _out := '{' || dq || 'status' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_st) || dq;
  if (_st = 'ok')
    {
      _out := _out || ',' || dq || 'table'   || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_tb) || dq;
      _out := _out || ',' || dq || 'pk'      || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_pk) || dq;
      _out := _out || ',' || dq || 'columns' || dq || ':[';
      for (i := 0; i < length (_cols); i := i + 1)
        {
          if (i > 0) _out := _out || ',';
          _out := _out || dq || DB.DBA.VVEC_JSON_ESC (_cols[i]) || dq;
        }
      _out := _out || ']';
    }
  else if (_tb <> '')
    _out := _out || ',' || dq || 'table' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_tb) || dq;
  if (_reason <> '')
    _out := _out || ',' || dq || 'reason' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_reason) || dq;
  _out := _out || '}';
  return _out;
}
;

-- ---------------------------------------------------------------------------
-- 6. Native output dimension of a registered model (for the create form).
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_MODEL_DIM (in _name varchar)
{
  declare _shape, _pdim any;
  declare pos integer;
  whenever not found goto nf;
  select output_shape, provider_dimensions into _shape, _pdim
    from DB.DBA.ONNX_MODELS where model_name = _name;
  if (_pdim is not null and atoi (cast (_pdim as varchar)) > 0)
    return atoi (cast (_pdim as varchar));
  if (_shape is not null)
    {
      -- output_shape like "1,384" -> take the last integer
      declare s varchar;
      s := cast (_shape as varchar);
      pos := strrchr (s, ',');
      if (pos is not null)
        s := subseq (s, pos + 1);
      return atoi (trim (s));
    }
  return 0;
nf:
  return 0;
}
;

-- ---------------------------------------------------------------------------
-- 7. Shared page chrome (sidebar + topbar). Emits everything up to the
--    opening <div class="content">. Call VVEC_FOOT() to close.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_NAV (in href varchar, in label varchar, in ico varchar, in active integer)
{
  http (sprintf ('<a href="%s" class="%s">', href, case when active then 'active' else '' end));
  http (ico);
  http (sprintf ('<span>%V</span></a>', label));
}
;

create procedure DB.DBA.VVEC_HEAD (in _title varchar, in _active varchar)
{
  declare ic_dash, ic_list, ic_add, ic_search, ic_model, ic_maint, ic_ns, ic_key, ic_label, ic_perm varchar;
  declare _usr, _ini, _years varchar;
  declare _yr integer;
  ic_dash   := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/></svg>';
  ic_list   := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="14" y2="18"/><circle cx="18.5" cy="18" r="2.2"/></svg>';
  ic_add    := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>';
  ic_search := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>';
  ic_model  := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="5" width="14" height="14" rx="2"/><path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3"/></svg>';
  ic_maint  := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v4M12 18v4M2 12h4M18 12h4M4.9 4.9l2.8 2.8M16.3 16.3l2.8 2.8M4.9 19.1l2.8-2.8M16.3 7.7l2.8-2.8"/><circle cx="12" cy="12" r="3.2"/></svg>';
  ic_ns     := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4L6.5 20M17.5 4L15 20M4 9h16M3 15h16"/></svg>';
  ic_label  := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.6 13.4 12 22l-9-9V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.4"/></svg>';
  ic_key    := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="7.5" cy="15.5" r="4.5"/><path d="M10.7 12.3 21 2M17 6l3 3M14 9l3 3"/></svg>';
  ic_perm   := '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.5 4.5 5.5v6c0 4.6 3.1 8.6 7.5 10 4.4-1.4 7.5-5.4 7.5-10v-6z"/><path d="m9 12 2.2 2.2L15.5 10"/></svg>';

  http ('<!DOCTYPE html>\n<html lang="en"><head><meta charset="utf-8">');
  http ('<meta name="viewport" content="width=device-width, initial-scale=1">');
  -- Before the stylesheet, before the body: every page here is a full load, so
  -- a theme applied after paint would flash white on every single navigation.
  -- Inline and synchronous is the whole point; a deferred script is too late.
  -- Storage throws outright in some contexts (private windows, blocked site
  -- data), and the catch leaves the default light theme standing.
  http ('<script>try{if(localStorage.getItem("vvec.theme")==="dark")'
        || 'document.documentElement.setAttribute("data-theme","dark");}catch(e){}</script>');
  http (sprintf ('<title>vvec Admin - %V</title>', _title));
  -- Stylesheet is inlined (VVEC_CSS is generated from vvec.css at deploy
  -- time) so the design does not depend on a separate request whose Content-Type
  -- the browser might reject.
  http ('<style>');
  DB.DBA.VVEC_CSS ();
  http ('</style></head><body>');
  http ('<div class="app">');

  -- Sidebar ----------------------------------------------------------------
  http ('<aside class="sidebar">');
  http ('<div class="brand">');
  http ('<span class="name">vvec<small>Powered by Virtuoso</small></span>');
  http ('</div>');

  -- The two things an operator comes here to do sit above the two things they
  -- come here to look after.  Creating an index and searching one are the work;
  -- Overview and the catalogue are where you go when the work is done or has
  -- gone wrong.
  http ('<div class="nav-label">Use</div><nav class="nav">');
  DB.DBA.VVEC_NAV ('create',      'Create Index',      ic_add,    case when _active = 'create'   then 1 else 0 end);
  DB.DBA.VVEC_NAV ('search',      'Similarity Search', ic_search, case when _active = 'search'   then 1 else 0 end);
  http ('</nav>');

  http ('<div class="nav-label">Manage</div><nav class="nav">');
  DB.DBA.VVEC_NAV ('./',          'Overview',          ic_dash,   case when _active = 'overview' then 1 else 0 end);
  DB.DBA.VVEC_NAV ('indexes',     'Manage Indexes',    ic_list,   case when _active = 'indexes'  then 1 else 0 end);
  http ('</nav>');

  http ('<div class="nav-label">Configure</div><nav class="nav">');
  DB.DBA.VVEC_NAV ('models',      'Embedding Models', ic_model, case when _active = 'models' then 1 else 0 end);
  DB.DBA.VVEC_NAV ('apikeys',     'API Keys',           ic_key, case when _active = 'apikeys' then 1 else 0 end);
  DB.DBA.VVEC_NAV ('prefixes',    'Namespace Prefixes', ic_ns, case when _active = 'prefixes' then 1 else 0 end);
  DB.DBA.VVEC_NAV ('labels',      'Labels',            ic_label, case when _active = 'labels' then 1 else 0 end);
  DB.DBA.VVEC_NAV ('permissions', 'Permissions',      ic_perm, case when _active = 'permissions' then 1 else 0 end);
  DB.DBA.VVEC_NAV ('maintenance', 'Maintenance',      ic_maint, case when _active = 'maintenance' then 1 else 0 end);
  http ('</nav>');

  -- A display preference, so it sits after the destinations rather than among
  -- them.  Same switch the results table uses for Raw URL / Entity label.
  http ('<div class="nav-theme"><label class="switch theme-switch" title="Light or dark">');
  http ('<span class="lit">Light</span>');
  http ('<input type="checkbox" id="vd-theme" onchange="vdTheme()">');
  http ('<span class="track"></span><span class="opt">Dark</span></label></div>');

  -- Signed-in user, pinned to the bottom of the sidebar.  Clicking it opens a
  -- menu whose one action is signing out, which ends the session server-side
  -- (VVEC_LOGOUT).
  _usr := DB.DBA.VVEC_USER ();
  _ini := DB.DBA.VVEC_USER_INITIALS (_usr);
  http ('<div class="sidebar-user">');
  http ('<button type="button" class="user-btn" id="vd-user-btn" aria-haspopup="menu" aria-expanded="false" onclick="vdUserToggle (event)">');
  http (sprintf ('<span class="avatar">%V</span>', _ini));
  http (sprintf ('<span class="user-meta"><span class="user-name">%V</span><span class="user-role">DBA account</span></span>', _usr));
  http ('<svg class="user-caret" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"/></svg>');
  http ('</button>');
  http ('<div class="user-menu hidden" id="vd-user-menu" role="menu">');
  http (sprintf ('<div class="user-menu-head">Signed in as <strong>%V</strong></div>', _usr));
  http ('<a class="user-menu-item danger" role="menuitem" href="logout">');
  http ('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>');
  http ('Sign out</a>');
  http ('</div></div>');

  -- Copyright, from the server clock rather than a baked-in constant, so it
  -- does not quietly go stale.  The range only appears once there is one to
  -- show: in the first year "2026-2026" would just read as a bug.
  _yr := year (now ());
  if (_yr > 2026)
    _years := sprintf ('2026-%d', _yr);
  else
    _years := '2026';
  http (sprintf ('<div class="side-legal">Copyright &copy; %s <a href="https://www.openlinksw.com/" target="_blank" rel="noopener">OpenLink Software</a></div>', _years));
  http ('</aside>');

  -- Main -------------------------------------------------------------------
  http ('<div class="main"><div class="content">');
}
;

-- Progressive-enhancement script that turns every native <select> on the page
-- into a custom, fully CSS-styleable dropdown (.vd-select).  The native element
-- is kept in the DOM (hidden) as the form value and the no-JS fallback; the
-- custom UI mirrors its options/optgroups and writes the choice back, firing a
-- native 'change' so existing onchange handlers still run.  Emitted at the end
-- of every page by VVEC_FOOT.  The JavaScript uses only double-quoted string
-- literals so it embeds cleanly inside this single-quoted SQL string.
create procedure DB.DBA.VVEC_SELECT_JS ()
{
  http ('<script>
(function(){
  function enhance(sel){
    if (sel.getAttribute("data-vd") || sel.multiple) return;
    sel.setAttribute("data-vd","1");
    var wrap = document.createElement("div");
    wrap.className = "vd-select";
    sel.parentNode.insertBefore(wrap, sel);
    wrap.appendChild(sel);
    sel.classList.add("vd-native");
    sel.setAttribute("tabindex","-1");
    sel.setAttribute("aria-hidden","true");
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "vd-select-btn";
    btn.setAttribute("aria-haspopup","listbox");
    btn.setAttribute("aria-expanded","false");
    var lab = document.createElement("span");
    lab.className = "vd-select-label";
    btn.appendChild(lab);
    wrap.appendChild(btn);
    var panel = document.createElement("div");
    panel.className = "vd-select-panel";
    panel.setAttribute("role","listbox");
    wrap.appendChild(panel);
    var active = -1;
    function isOpen(){ return wrap.classList.contains("open"); }
    function syncLabel(){
      // With nothing selected fall back to the data-placeholder text, and failing
      // that to a zero-width space: an empty label collapses the button''s line
      // box, which would make the control shorter than the inputs beside it.
      var o = sel.options[sel.selectedIndex];
      var ph = sel.getAttribute("data-placeholder");
      var txt = o ? o.textContent : (ph || "");
      lab.textContent = txt || String.fromCharCode(8203);   // zero-width space
      lab.classList.toggle("placeholder", !o || o.value === "");
    }
    // A select with no option worth choosing (none at all, or all disabled) is
    // not usable yet -- e.g. the text-column list before a table is resolved.
    // Grey it out and stop it opening rather than offering an empty panel.
    function usable(){
      if (sel.disabled) return false;
      for (var i=0;i<sel.options.length;i++){ if (!sel.options[i].disabled) return true; }
      return false;
    }
    function syncState(){
      var on = usable();
      btn.disabled = !on;
      wrap.classList.toggle("disabled", !on);
      if (!on && isOpen()) close();
    }
    function rows(){ return panel.querySelectorAll(".vd-opt:not(.disabled)"); }
    function clearActive(){
      var rs = panel.querySelectorAll(".vd-opt.active");
      for (var i=0;i<rs.length;i++) rs[i].classList.remove("active");
    }
    function setActive(n){
      var rs = rows();
      if (!rs.length) return;
      if (n < 0) n = 0;
      if (n >= rs.length) n = rs.length - 1;
      clearActive(); active = n;
      rs[n].classList.add("active");
      rs[n].scrollIntoView({block:"nearest"});
    }
    function choose(opt){
      sel.value = opt.value; syncLabel();
      sel.dispatchEvent(new Event("change", {bubbles:true}));
      close(); btn.focus();
    }
    function row(opt, selVal){
      var r = document.createElement("div");
      r.className = "vd-opt"; r.textContent = opt.textContent;
      r.setAttribute("role","option");
      if (opt.disabled){ r.classList.add("disabled"); r.setAttribute("aria-disabled","true"); return r; }
      if (opt.value === selVal){ r.classList.add("sel"); r.setAttribute("aria-selected","true"); }
      r._opt = opt;
      r.addEventListener("mousedown", function(ev){ ev.preventDefault(); choose(opt); });
      r.addEventListener("mousemove", function(){
        var rs = rows();
        for (var k=0;k<rs.length;k++){ if (rs[k] === r){ clearActive(); active = k; r.classList.add("active"); break; } }
      });
      return r;
    }
    function rebuild(){
      panel.innerHTML = "";
      var kids = sel.children, selVal = sel.value;
      for (var i=0;i<kids.length;i++){
        var node = kids[i];
        if (node.tagName === "OPTGROUP"){
          var g = document.createElement("div");
          g.className = "vd-optgroup"; g.textContent = node.label;
          panel.appendChild(g);
          var os = node.children;
          for (var j=0;j<os.length;j++) panel.appendChild(row(os[j], selVal));
        } else if (node.tagName === "OPTION"){
          panel.appendChild(row(node, selVal));
        }
      }
    }
    function place(){
      var r = btn.getBoundingClientRect(), gap = 6, margin = 12;
      panel.style.left = r.left + "px";
      panel.style.width = r.width + "px";
      panel.style.maxHeight = "";
      var want = panel.scrollHeight;
      var below = window.innerHeight - r.bottom - gap - margin;
      var above = r.top - gap - margin;
      if (want <= below || below >= above){
        panel.style.maxHeight = Math.max(96, Math.min(288, below)) + "px";
        panel.style.top = (r.bottom + gap) + "px";
      } else {
        var h = Math.max(96, Math.min(288, above));
        panel.style.maxHeight = h + "px";
        panel.style.top = (r.top - gap - Math.min(h, want)) + "px";
      }
    }
    function onWin(){ if (isOpen()) place(); }
    function open(){
      if (isOpen()) return;
      rebuild(); wrap.classList.add("open"); btn.setAttribute("aria-expanded","true");
      place();
      var rs = rows(), start = 0;
      for (var i=0;i<rs.length;i++){ if (rs[i].classList.contains("sel")){ start = i; break; } }
      setActive(start);
      document.addEventListener("mousedown", onDoc, true);
      window.addEventListener("scroll", onWin, true);
      window.addEventListener("resize", onWin);
    }
    function close(){
      wrap.classList.remove("open"); btn.setAttribute("aria-expanded","false");
      clearActive(); active = -1;
      document.removeEventListener("mousedown", onDoc, true);
      window.removeEventListener("scroll", onWin, true);
      window.removeEventListener("resize", onWin);
    }
    function onDoc(ev){ if (!wrap.contains(ev.target)) close(); }
    btn.addEventListener("click", function(){ isOpen() ? close() : open(); });
    btn.addEventListener("keydown", function(ev){
      var k = ev.key;
      if (k === "ArrowDown"){ ev.preventDefault(); isOpen() ? setActive(active + 1) : open(); }
      else if (k === "ArrowUp"){ ev.preventDefault(); isOpen() ? setActive(active - 1) : open(); }
      else if (k === "Enter" || k === " "){
        ev.preventDefault();
        if (isOpen()){ var rs = rows(); if (rs[active] && rs[active]._opt) choose(rs[active]._opt); }
        else open();
      }
      else if (k === "Escape"){ if (isOpen()){ ev.preventDefault(); close(); } }
      else if (k === "Tab"){ close(); }
    });
    var mo = new MutationObserver(function(){ syncLabel(); syncState(); if (isOpen()) rebuild(); });
    mo.observe(sel, {childList:true, subtree:true, attributes:true, attributeFilter:["disabled"]});
    sel.addEventListener("change", function(){ syncLabel(); syncState(); });
    syncLabel();
    syncState();
  }
  function run(root){
    var list = (root || document).getElementsByTagName("select"), arr = [], i;
    for (i=0;i<list.length;i++) arr.push(list[i]);
    for (i=0;i<arr.length;i++) enhance(arr[i]);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function(){ run(document); });
  else run(document);
  window.VVecEnhanceSelects = run;
})();
</script>');
}
;

create procedure DB.DBA.VVEC_FOOT ()
{
  http ('</div></div></div>');
  DB.DBA.VVEC_SELECT_JS ();
  DB.DBA.VVEC_USER_JS ();
  DB.DBA.VVEC_THEME_JS ();
  DB.DBA.VVEC_BEAT_JS ();
  -- Emission order is listener order, and all three of these intercept submit
  -- during the capture phase: validate first, so an invalid form never asks
  -- anything; then confirm, so the question comes before the consequence; then
  -- the insecure-connection guard, which is the last thing between a typed
  -- secret and the wire.  VVEC_WORK_JS listens in the bubble phase and only
  -- ever sees a submit the three of them have let through.
  DB.DBA.VVEC_VALIDATE_JS ();
  DB.DBA.VVEC_CONFIRM ();
  DB.DBA.VVEC_RESIZE_JS ();
  DB.DBA.VVEC_SECRET_GUARD ();
  DB.DBA.VVEC_WORK_JS ();
  http ('</body></html>');
}
;

-- Progress for the operations that actually take time.
--
-- Creating or rebuilding an index embeds every source row, which is seconds of
-- real work, and registering a remote provider or test-embedding calls out over
-- the network.  A button that simply freezes for that long reads as a page that
-- did not respond, so a form carrying data-working says what it is doing and
-- shows the work continuing until the response replaces the page.
--
-- Similarity search deliberately has none of this: it is fast, the answer is
-- the feedback, and an indicator on a sub-second action only makes it feel
-- slower.  Motion here is reserved for waits that are real.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_WORK_JS ()
{
  http ('<script>
(function(){
  function work(f){
    if(!f || f.getAttribute("data-worked") === "1") return;
    var label = f.getAttribute("data-working");
    if(!label) return;
    f.setAttribute("data-worked", "1");
    var b = f.querySelector("button[type=submit]");
    if(b){ b.disabled = true; b.textContent = label; }
    // The moving rule only belongs where the form has a footer to hang it on;
    // an inline form in a table row just gets the button state.
    var slot = f.querySelector(".form-actions");
    if(slot){
      var r = document.createElement("div");
      r.className = "work-rule";
      r.appendChild(document.createElement("i"));
      slot.appendChild(r);
      // Work that can run for minutes needs to say so, and say what happens if
      // the reader does not wait -- otherwise the only safe assumption is that
      // leaving breaks it, which is not true here.
      var note = f.getAttribute("data-working-note");
      if(note){
        var n = document.createElement("div");
        n.className = "work-note";
        n.textContent = note;
        slot.appendChild(n);
      }
    }
  }
  // A form carrying data-beat holds the same floor the confirmation dialog
  // does, for the same reason: it is a critical, infrequent action whose server
  // side is instant.  Storing an API key is one registry write -- without this
  // the working state exists for about as long as the navigation and the
  // operator is left asking whether a secret they typed once actually landed.
  // Deliberately not applied to anything that already takes real time (creating
  // an index, embedding, draining a queue): there the state is visible because
  // the work is, and a floor would be a tax.
  var BEAT = 480;
  document.addEventListener("submit", function(ev){
    // A dialog that cancelled the submit did so in the capture phase, and a
    // prevented event must not start the timer on work that is not happening.
    if(ev.defaultPrevented) return;
    var f = ev.target;
    work(f);
    // hasAttribute, not getAttribute: data-beat is a bare attribute, so its
    // value is the empty string and a truthiness test silently skips the beat.
    if(!f || !f.hasAttribute || !f.hasAttribute("data-beat")) return;
    if(f.getAttribute("data-beaten") === "1"){ f.removeAttribute("data-beaten"); return; }
    ev.preventDefault();
    setTimeout(function(){
      f.setAttribute("data-beaten", "1");
      if(f.requestSubmit) f.requestSubmit(); else f.submit();
    }, BEAT);
  });
  window.vdWork = work;
})();
</script>');
}
;

-- Interception for any form about to send a secret over an unencrypted
-- connection.  Emitted on every page by VVEC_FOOT rather than wired into
-- the two pages that have such a form today, so a form added later cannot
-- forget it.
--
-- The trigger is a password field with something actually typed in it: editing
-- a provider and leaving its key field blank sends no secret and is not
-- interrupted.  The test is window.isSecureContext, which is the browser's own
-- answer to the question being asked and is therefore right in the cases a
-- server-side check gets wrong: it stays true behind a TLS-terminating proxy
-- (where the server only ever sees http) and treats loopback as secure, since
-- nothing typed into http://localhost leaves the machine.
-- The acknowledgement is remembered in localStorage -- per browser and per
-- origin, never on the server -- so one operator dismissing it does not
-- silence the warning for anyone else.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_SECRET_GUARD ()
{
  http ('<div id="sec-modal" class="modal-back hidden" onclick="vdSecBackdrop(event)">');
  http ('<div class="modal">');
  http ('<div class="modal-head"><div><h3>This connection is not encrypted</h3>');
  http ('<div class="sub">This page is not in a secure context, so what you submit crosses the network in the clear.</div></div>');
  http ('<button type="button" class="modal-close" onclick="vdSecCancel()" title="Cancel">&#215;</button></div>');
  http ('<div class="modal-body">');
  http ('<div class="banner warn" style="margin-bottom:14px"><div><strong>The API key you are about to send can be read in transit</strong>');
  http ('<span class="mono">Anything between this browser and the server &mdash; proxies, gateways, anyone on the same network &mdash; sees the value. Put the instance behind <strong>HTTPS</strong> whenever you are not certain the whole path is trusted.</span></div></div>');
  http ('<p style="margin-top:0">You do not have to use a browser for this at all. The same call goes through <span class="mono">isql</span>, or any <strong>ODBC</strong> or <strong>JDBC</strong> client &mdash; each of which can be TLS-encrypted, and <span class="mono">isql</span> on the host itself never leaves the machine:</p>');
  http ('<div class="mono" style="background:var(--border-soft);padding:12px;border-radius:10px;white-space:pre-wrap">DB.DBA.ONNX_API_KEY_SET (''ONNX_API_KEY_OPENAI'', ''sk-...'');</div>');
  http ('<p class="cell-muted" style="margin-bottom:0">Continuing sends the value now. Cancelling leaves the form as it is so you can clear the field or switch to HTTPS.</p>');
  http ('</div>');
  http ('<div class="modal-foot">');
  http ('<label class="sec-ack"><input type="checkbox" id="sec-ack"> Do not warn me again in this browser</label>');
  http ('<div class="row-actions"><button type="button" class="btn sm" onclick="vdSecCancel()">Cancel</button>');
  http ('<button type="button" class="btn sm danger" onclick="vdSecGo()">I understand, continue</button></div></div>');
  http ('</div></div>');

  http ('<script>
(function(){
  var pending = null;
  var KEY = "vvec.insecure-secret-ack";
  function el(id){ return document.getElementById(id); }
  // Storage can throw outright (private windows, blocked site data), so every
  // read and write is guarded and a failure just means the warning still shows.
  function acked(){
    try { return window.localStorage.getItem(KEY) === "1"; } catch(e) { return false; }
  }
  function remember(){
    try { window.localStorage.setItem(KEY, "1"); } catch(e) {}
  }
  window.vdSecForget = function(){
    try { window.localStorage.removeItem(KEY); } catch(e) {}
    window.vdSecSyncNotice();
  };
  // Any page can show whether the warning is currently suppressed, and offer to
  // put it back -- otherwise the checkbox would be a one-way door.
  window.vdSecSyncNotice = function(){
    var n = el("sec-suppressed");
    if(n) n.classList.toggle("hidden", !acked());
  };
  function sendsSecret(f){
    var pw = f.querySelectorAll("input[type=password]"), i;
    for(i = 0; i < pw.length; i++){ if(pw[i].value && pw[i].value.length) return true; }
    return false;
  }
  // Capturing, so this runs before a form''s own onsubmit handler.
  document.addEventListener("submit", function(ev){
    if(window.isSecureContext) return;
    if(acked()) return;
    var f = ev.target;
    if(!f || f.tagName !== "FORM" || !sendsSecret(f)) return;
    ev.preventDefault();
    ev.stopPropagation();
    pending = f;
    var cb = el("sec-ack");
    if(cb) cb.checked = false;
    el("sec-modal").classList.remove("hidden");
  }, true);
  window.vdSecCancel = function(){
    // Cancelling is not acceptance, so the checkbox is deliberately not honoured
    // here -- the preference only sticks when the risk is actually taken on.
    pending = null;
    el("sec-modal").classList.add("hidden");
  };
  window.vdSecBackdrop = function(ev){
    if(ev.target && ev.target.id === "sec-modal") window.vdSecCancel();
  };
  window.vdSecGo = function(){
    var f = pending;
    var cb = el("sec-ack");
    pending = null;
    if(cb && cb.checked) remember();
    el("sec-modal").classList.add("hidden");
    // HTMLFormElement.submit() does not fire submit handlers, so this cannot
    // loop back into the interception above -- which also means the working
    // state has to be entered by hand here.
    if(f){ if(window.vdWork) window.vdWork(f); f.submit(); }
  };
  document.addEventListener("keydown", function(ev){
    if(ev.key === "Escape" && !el("sec-modal").classList.contains("hidden")) window.vdSecCancel();
  });
  if(document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", window.vdSecSyncNotice);
  else
    window.vdSecSyncNotice();
})();
</script>');
}
;

-- The console's own confirmation dialog, replacing window.confirm().
--
-- A native confirm() is the browser's chrome, not this console's: it arrives in
-- the platform's fonts and colours, it cannot say which index is about to be
-- dropped in the console's own terms, and it renders the page underneath inert
-- while it is up.  This is the same modal shell every other dialog here uses.
--
-- A form opts in by carrying data-confirm; nothing else changes at the call
-- site.  The rest are optional: data-confirm-title (heading), data-confirm-ok
-- (the button's label, which should name the act -- "Drop index" reads better
-- than "OK" and is the last thing read before the click), data-confirm-detail
-- (a warning banner for the consequence, kept out of the question itself),
-- data-confirm-note (the small line in the footer -- say "This cannot be
-- undone" only where it is true), and data-confirm-safe for the rare
-- non-destructive case that wants the plain button rather than the red one.
--
-- Accepting re-submits through requestSubmit() rather than submit(), because
-- submit() fires no handlers -- it would skip the insecure-connection guard and
-- the working indicator.  So this listener has to let the second pass through,
-- which is what data-confirmed marks.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_CONFIRM ()
{
  http ('<div id="cf-modal" class="modal-back hidden" onclick="vdCfBackdrop(event)">');
  http ('<div class="modal cf" role="alertdialog" aria-modal="true" aria-labelledby="cf-title" aria-describedby="cf-q">');
  http ('<div class="modal-head"><div><h3 id="cf-title">Are you sure?</h3></div>');
  http ('<button type="button" class="modal-close" onclick="vdCfCancel()" title="Cancel">&#215;</button></div>');
  http ('<div class="modal-body"><p id="cf-q" style="margin:0"></p>');
  -- Not .mono: that class is the console''s inset for a statement it actually
  -- ran, and a consequence written in prose put inside it reads as a box in a
  -- box with nothing to justify the second frame.
  http ('<div id="cf-detail" class="banner warn hidden" style="margin:14px 0 0"><div><span id="cf-detail-text"></span></div></div>');
  http ('</div>');
  http ('<div class="modal-foot"><span class="note" id="cf-note"></span>');
  http ('<div class="row-actions"><button type="button" class="btn sm" id="cf-no" onclick="vdCfCancel()">Cancel</button>');
  http ('<button type="button" class="btn sm danger" id="cf-yes" onclick="vdCfGo()">Continue</button></div></div>');
  http ('<div class="work-rule hidden" id="cf-work"><i></i></div>');
  http ('</div></div>');

  http ('<script>
(function(){
  // An irreversible action that answers instantly reads as an action that did
  // not happen.  Dropping an index is one statement -- the reply can be back
  // before the click has finished -- and a page that simply changes underneath
  // the reader leaves them checking whether it worked.  So the dialog takes the
  // commit, says what it is doing, and holds a beat before submitting.
  //
  // The beat is a floor, not a tax on slow work: the dialog stays in this state
  // until the response replaces the page, so a drop that really takes four
  // seconds shows four seconds of it.  480ms is long enough to be seen and
  // short enough that an operator doing this a few times a day never waits on
  // it.  Nothing on the search path has a dialog, deliberately -- that is the
  // high-frequency surface and the answer is its own feedback.
  var BEAT = 480;
  var pending = null, restore = null;
  function el(id){ return document.getElementById(id); }
  function box(){ return el("cf-modal"); }
  function open(f){
    var yes = el("cf-yes"), det = el("cf-detail"), d = f.getAttribute("data-confirm-detail");
    el("cf-title").textContent = f.getAttribute("data-confirm-title") || "Are you sure?";
    el("cf-q").textContent = f.getAttribute("data-confirm");
    yes.textContent = f.getAttribute("data-confirm-ok") || "Continue";
    yes.classList.toggle("danger", f.getAttribute("data-confirm-safe") !== "1");
    el("cf-detail-text").textContent = d || "";
    det.classList.toggle("hidden", !d);
    // Only the forms that say so get "cannot be undone": a rebuild can simply
    // be run again, and a dialog that overstates one thing is not believed
    // about the next.
    el("cf-note").textContent = f.getAttribute("data-confirm-note") || "";
    yes.disabled = false;
    el("cf-no").disabled = false;
    el("cf-work").classList.add("hidden");
    box().removeAttribute("aria-busy");
    pending = f;
    restore = document.activeElement;
    box().classList.remove("hidden");
    // Cancel takes the focus, not the confirm button: this dialog is in the way
    // of something irreversible, so a reflex Enter should do nothing.
    el("cf-no").focus();
  }
  function close(){
    pending = null;
    box().classList.add("hidden");
    if(restore && restore.focus) restore.focus();
    restore = null;
  }
  // Capturing, so this runs before a form''s own onsubmit handler.
  document.addEventListener("submit", function(ev){
    if(ev.defaultPrevented) return;
    var f = ev.target;
    if(!f || f.tagName !== "FORM" || !f.getAttribute("data-confirm")) return;
    // The pass that the dialog itself started.
    if(f.getAttribute("data-confirmed") === "1"){ f.removeAttribute("data-confirmed"); return; }
    ev.preventDefault();
    ev.stopPropagation();
    open(f);
  }, true);
  // Once committed there is nothing left to cancel, and a dialog that vanishes
  // on a stray Escape while the work is in flight is the exact ambiguity this
  // is here to remove.
  function busy(){ return box().getAttribute("aria-busy") === "true"; }
  window.vdCfCancel = function(){ if(!busy()) close(); };
  window.vdCfBackdrop = function(ev){ if(ev.target && ev.target.id === "cf-modal") window.vdCfCancel(); };
  window.vdCfGo = function(){
    var f = pending;
    if(!f) return;
    var yes = el("cf-yes");
    // The click is answered before the work starts: the choice is taken away,
    // the button says what is happening rather than what to do, and the rule
    // underneath shows it continuing.
    yes.disabled = true;
    el("cf-no").disabled = true;
    yes.textContent = f.getAttribute("data-confirm-working") || (yes.textContent + "...");
    el("cf-work").classList.remove("hidden");
    box().setAttribute("aria-busy", "true");
    setTimeout(function(){
      pending = null;
      f.setAttribute("data-confirmed", "1");
      // The dialog is deliberately left up. It is the loading state now, and it
      // stays until the response replaces the page.
      if(f.requestSubmit){ f.requestSubmit(); return; }
      // Old browsers: submit() skips every handler, so do their work by hand.
      if(window.vdWork) window.vdWork(f);
      f.submit();
    }, BEAT);
  };
  document.addEventListener("keydown", function(ev){
    if(box().classList.contains("hidden")) return;
    if(ev.key === "Escape"){ window.vdCfCancel(); return; }
    if(busy()){ ev.preventDefault(); return; }
    if(ev.key !== "Tab") return;
    // Nothing behind the dialog is reachable while it is up.
    var f = [el("cf-no"), el("cf-yes")], i = f.indexOf(document.activeElement);
    ev.preventDefault();
    f[(i + (ev.shiftKey ? f.length - 1 : 1) + f.length) % f.length].focus();
  });
})();
</script>');
}
;

-- Constraint violations reported in the console''s own type, not the browser''s.
--
-- Every form here is validated on the server and answers in a .banner, but a
-- field carrying min= or type=number is also checked by the browser, which
-- interrupts with a bubble in its own chrome before the request is ever made.
-- Turning validation off entirely would lose a genuinely useful check, so it is
-- kept and only the reporting is taken over: novalidate suppresses the bubble,
-- and the first offending field is marked and captioned where the reader is
-- already looking.
--
-- validationMessage is the browser''s wording, deliberately: it is localised to
-- the reader and accurate about the constraint, and it is text in this page''s
-- own styles rather than a popup drawn over it.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_VALIDATE_JS ()
{
  http ('<script>
(function(){
  function clear(f){
    var i, m = f.querySelectorAll(".field-err");
    for(i = 0; i < m.length; i++) m[i].parentNode.removeChild(m[i]);
    m = f.querySelectorAll(".invalid");
    for(i = 0; i < m.length; i++) m[i].classList.remove("invalid");
  }
  function mark(c){
    var note = document.createElement("span");
    note.className = "field-err";
    note.textContent = c.validationMessage;
    c.classList.add("invalid");
    // Inside a .field the caption belongs under the input, beside its hint;
    // anywhere else, immediately after the control.
    var slot = c.closest ? c.closest(".field") : null;
    if(slot) slot.appendChild(note); else if(c.parentNode) c.parentNode.insertBefore(note, c.nextSibling);
    c.scrollIntoView({block: "center", behavior: "smooth"});
    c.focus();
  }
  function check(f){
    clear(f);
    if(f.checkValidity && f.checkValidity()) return true;
    var i, c;
    for(i = 0; i < f.elements.length; i++){
      c = f.elements[i];
      if(c.willValidate && !c.checkValidity()){ mark(c); return false; }
    }
    return true;
  }
  function arm(){
    var i, fs = document.querySelectorAll("form");
    for(i = 0; i < fs.length; i++) fs[i].noValidate = true;
  }
  // First of the capturing submit handlers: an invalid form should not go on to
  // ask for confirmation or warn about the connection.
  document.addEventListener("submit", function(ev){
    if(ev.defaultPrevented) return;
    var f = ev.target;
    if(!f || f.tagName !== "FORM") return;
    // Belt and braces: a form that somehow missed arm() is armed now, so the
    // browser cannot bubble on the next attempt either.
    f.noValidate = true;
    if(!check(f)){ ev.preventDefault(); ev.stopPropagation(); }
  }, true);
  // A field the reader has started fixing stops being flagged.
  document.addEventListener("input", function(ev){
    var c = ev.target;
    if(!c || !c.classList || !c.classList.contains("invalid")) return;
    c.classList.remove("invalid");
    var slot = c.closest ? c.closest(".field") : null;
    var note = slot ? slot.querySelector(".field-err") : null;
    if(note) note.parentNode.removeChild(note);
  });
  if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", arm); else arm();
})();
</script>');
}
;

-- Column and row resizing, for any table carrying data-resizable.
--
-- The catalogue's column widths are a compromise chosen for the general case,
-- and the general case is not the one in front of the reader: a run of long
-- IRIs wants the Subject column wide, and a run of short ones wants it narrow
-- so the text has the room instead.  Dragging is the direct way to say which.
--
-- A row's height follows the drag directly, and the clamped text is then told
-- how many lines fit in the height that was asked for -- so dragging down both
-- makes the row taller and shows more of the indexed text, and the two do not
-- fight.  Driving the line count instead and letting the row follow is the
-- obvious design and it is wrong: an indexed string is often only four or five
-- lines, so the row grew a little and then stopped however far the pointer
-- went, which reads as broken rather than as finished.
--
-- Nothing is persisted.  This is a reading posture for the answer on screen,
-- not a setting, and a width restored onto a different result set would be
-- wrong more often than right.  Double-click either grip to put it back.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_RESIZE_JS ()
{
  http ('<script>
(function(){
  var MINCOL = 48;
  function freeze(t){
    // Widths are only authoritative under table-layout:fixed, and the auto
    // layout has to be measured before switching or every column jumps.
    if(t.getAttribute("data-frozen") === "1") return;
    var th = t.tHead.rows[0].cells, i, w = [];
    for(i = 0; i < th.length; i++) w.push(th[i].getBoundingClientRect().width);
    t.style.width = t.getBoundingClientRect().width + "px";
    t.style.tableLayout = "fixed";
    for(i = 0; i < th.length; i++) th[i].style.width = w[i] + "px";
    t.setAttribute("data-frozen", "1");
  }
  function thaw(t){
    var th = t.tHead.rows[0].cells, i;
    for(i = 0; i < th.length; i++) th[i].style.width = "";
    t.style.width = "";
    t.style.tableLayout = "";
    t.removeAttribute("data-frozen");
  }
  function dragCol(t, th, ev){
    freeze(t);
    var x0 = ev.clientX, w0 = th.getBoundingClientRect().width;
    document.body.classList.add("resizing-col");
    function move(e){
      var w = Math.max(MINCOL, w0 + (e.clientX - x0));
      th.style.width = w + "px";
    }
    function up(){
      document.removeEventListener("mousemove", move);
      document.removeEventListener("mouseup", up);
      document.body.classList.remove("resizing-col");
    }
    document.addEventListener("mousemove", move);
    document.addEventListener("mouseup", up);
    ev.preventDefault();
  }
  // The drag sets the height of the row, and the text is then told how many lines
  // fit in it.  The other way round -- drag the line count and let the row
  // follow -- was the first attempt and it does not survive contact with real
  // data: an indexed string of 80 characters is five lines, so the row grew by
  // about 50px and then stopped dead however far the pointer went. Resizing has
  // to answer the hand, not the content.
  var MINROW = 30;
  function dragRow(tr, ev){
    var clamp = tr.querySelector(".clamp2");
    var lh = clamp ? (parseFloat(getComputedStyle(clamp).lineHeight) || 18) : 18;
    // Cell padding is above and below the text, so it is not room for a line.
    var cell = tr.cells[0], pad = 0;
    if(cell){
      var cs = getComputedStyle(cell);
      pad = (parseFloat(cs.paddingTop) || 0) + (parseFloat(cs.paddingBottom) || 0);
    }
    var y0 = ev.clientY, h0 = tr.getBoundingClientRect().height;
    document.body.classList.add("resizing-row");
    function move(e){
      var h = Math.max(MINROW, h0 + (e.clientY - y0));
      tr.setAttribute("data-h", "1");
      tr.style.setProperty("--row-h", h + "px");
      // Whatever height was asked for, the text uses it.
      tr.style.setProperty("--lines", Math.max(1, Math.floor((h - pad) / lh)));
    }
    function up(){
      document.removeEventListener("mousemove", move);
      document.removeEventListener("mouseup", up);
      document.body.classList.remove("resizing-row");
    }
    document.addEventListener("mousemove", move);
    document.addEventListener("mouseup", up);
    ev.preventDefault();
  }
  function arm(t){
    var th = t.tHead ? t.tHead.rows[0].cells : [], i, g;
    // Not the last column: it is pinned to the right edge and sized to its
    // contents, so a width dragged onto it would fight the sticky positioning.
    for(i = 0; i < th.length - 1; i++){
      g = document.createElement("span");
      g.className = "col-grip";
      g.title = "Drag to resize this column, double-click to reset";
      th[i].appendChild(g);
    }
    var rows = t.tBodies.length ? t.tBodies[0].rows : [];
    for(i = 0; i < rows.length; i++){
      if(!rows[i].querySelector(".clamp2") || !rows[i].cells.length) continue;
      g = document.createElement("span");
      g.className = "row-grip";
      g.title = "Drag to show more of the text, double-click to reset";
      rows[i].cells[0].appendChild(g);
    }
    t.addEventListener("mousedown", function(ev){
      var c = ev.target;
      if(!c.classList) return;
      if(c.classList.contains("col-grip")) dragCol(t, c.parentNode, ev);
      else if(c.classList.contains("row-grip")) dragRow(c.closest("tr"), ev);
    });
    t.addEventListener("dblclick", function(ev){
      var c = ev.target;
      if(!c.classList) return;
      if(c.classList.contains("col-grip")){ thaw(t); ev.preventDefault(); }
      else if(c.classList.contains("row-grip")){
        var tr = c.closest("tr");
        tr.removeAttribute("data-h");
        tr.style.removeProperty("--row-h");
        tr.style.removeProperty("--lines");
        ev.preventDefault();
      }
    });
  }
  function armAll(){
    var t = document.querySelectorAll("table[data-resizable]"), i;
    for(i = 0; i < t.length; i++) arm(t[i]);
  }
  if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", armAll); else armAll();
})();
</script>');
}
;

-- The theme toggle.  Two states only -- light by default, dark if asked for --
-- and remembered per browser and per origin in localStorage, never on the
-- server: one operator's preference is not an instance-wide setting.
--
-- Deliberately does not follow prefers-color-scheme. Light is the stated
-- default, and a console that turns dark because someone's laptop did at sunset
-- is a console that changed without being asked.
--
-- The label is set from the state on every load, so it stays right on a page
-- rendered with the theme already applied by the head script.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
-- Heartbeat: the signal that this page is still open.
--
-- A session is only alive while its page is, and HTTP gives the server no way
-- to learn that a tab closed.  So the page says so, every 30 seconds, and
-- VVEC_SES_BEAT_S is the grace the server allows before concluding the page is
-- gone.  A pagehide beacon cannot do this job: the console is a set of ordinary
-- server-rendered pages, so pagehide fires on every link click, and it never
-- fires at all on a crash or a force-quit.  Missed beats are the only signal
-- that covers every way a page can stop existing.
--
-- Browsers throttle timers in hidden tabs to roughly once a minute, which the
-- 150s window absorbs; coming back to the foreground beats immediately rather
-- than waiting out an interval that may have been stretched.
--
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_BEAT_JS ()
{
  http ('<script>
(function(){
  function beat(){
    fetch("ping", {credentials:"same-origin", cache:"no-store"}).then(function(r){
      // The session ended while this page sat here -- signed out elsewhere,
      // idled out, or the server restarted. Go to the sign-in page rather than
      // leave a console on screen whose every action would now bounce.
      if(r.status === 401){
        location.replace("login?url=" + encodeURIComponent(location.pathname + location.search));
      }
    }).catch(function(){});
  }
  setInterval(beat, 30000);
  document.addEventListener("visibilitychange", function(){
    if(document.visibilityState === "visible") beat();
  });
})();
</script>');
}
;

create procedure DB.DBA.VVEC_THEME_JS ()
{
  http ('<script>
(function(){
  var KEY = "vvec.theme";
  var root = document.documentElement;
  // The attribute is authoritative -- the head script set it before paint --
  // so the checkbox is brought into line with it rather than the other way
  // round. The CSS positions the track from the same attribute, so nothing
  // moves when this runs.
  function sync(){
    var box = document.getElementById("vd-theme");
    if(box) box.checked = root.getAttribute("data-theme") === "dark";
  }
  window.vdTheme = function(){
    var dark = root.getAttribute("data-theme") === "dark";
    if(dark) root.removeAttribute("data-theme"); else root.setAttribute("data-theme", "dark");
    try { localStorage.setItem(KEY, dark ? "light" : "dark"); } catch(e) {}
    sync();
  };
  sync();
})();
</script>');
}
;

-- The sidebar user menu.  Emitted at the end of every page by VVEC_FOOT.
-- The menu is position:fixed and placed from the button's bounding rect for the
-- same reason the custom <select> panel is: the sidebar sets overflow-y:auto, so
-- a menu that opens upwards past its edge would otherwise be clipped.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_USER_JS ()
{
  http ('<script>
(function(){
  var btn = document.getElementById("vd-user-btn");
  var menu = document.getElementById("vd-user-menu");
  if(!btn || !menu) return;
  function place(){
    var r = btn.getBoundingClientRect();
    menu.style.left = r.left + "px";
    menu.style.width = r.width + "px";
    menu.style.bottom = (window.innerHeight - r.top + 8) + "px";
  }
  function close(){
    menu.classList.add("hidden");
    btn.setAttribute("aria-expanded", "false");
  }
  window.vdUserToggle = function(ev){
    ev.stopPropagation();
    if(menu.classList.contains("hidden")){
      place();
      menu.classList.remove("hidden");
      btn.setAttribute("aria-expanded", "true");
    } else {
      close();
    }
  };
  document.addEventListener("click", function(ev){
    if(!menu.contains(ev.target) && !btn.contains(ev.target)) close();
  });
  document.addEventListener("keydown", function(ev){
    if(ev.key === "Escape") close();
  });
  window.addEventListener("resize", function(){
    if(!menu.classList.contains("hidden")) place();
  });
})();
</script>');
}
;

-- Inline stylesheet emitter. Regenerated from the uploaded stylesheet by the
-- post-install step at the end of this file (section 8);
-- this placeholder is replaced at deploy time with the real stylesheet body.
create procedure DB.DBA.VVEC_CSS ()
{
  http ('');
}
;

-- Is a built index actually holding anything?
--
-- A selector that matches nothing still creates cleanly and still reports
-- ready, so the catalogue would show a healthy green pill on an index that
-- answers every search with no rows.  That is the one state in this table that
-- is actively misleading, and the Create page's warning about it -- the only
-- place it was ever said -- is lost the moment the operator navigates away.
--
-- Probes for one row rather than counting them.  A count is more informative
-- and would be a full scan of the backing table for every row of the
-- catalogue; emptiness is the whole question here and `top 1` answers it at any
-- size.  Anything that goes wrong returns -1, which the pill reads as "do not
-- claim to know" rather than as empty.
create procedure DB.DBA.VVEC_SPARQL_INDEX_EMPTY (in _iri varchar)
{
  declare _srct, _st, _msg varchar;
  declare _meta, _rows any;
  declare exit handler for sqlstate '*' { return -1; };
  _srct := (select SVI_SOURCE_TABLE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _iri);
  if (_srct is null)
    return -1;
  _st := '00000';
  exec (sprintf ('select top 1 1 from "%I"."%I"."%I"',
                 name_part (_srct, 0), name_part (_srct, 1), name_part (_srct, 2)),
        _st, _msg, vector (), 1, _meta, _rows);
  if (_st <> '00000' or not isvector (_rows))
    return -1;
  return case when length (_rows) = 0 then 1 else 0 end;
}
;

-- The relational equivalent: a vector index over a column every row of which is
-- NULL has nothing to embed and nothing to find.
create procedure DB.DBA.VVEC_SQL_INDEX_EMPTY (in _tb varchar, in _col varchar)
{
  declare _st, _msg varchar;
  declare _meta, _rows any;
  declare exit handler for sqlstate '*' { return -1; };
  if (_tb is null or _col is null or _tb = '' or _col = '')
    return -1;
  _st := '00000';
  exec (sprintf ('select top 1 1 from "%I"."%I"."%I" where "%I" is not null',
                 name_part (_tb, 0), name_part (_tb, 1), name_part (_tb, 2), _col),
        _st, _msg, vector (), 1, _meta, _rows);
  if (_st <> '00000' or not isvector (_rows))
    return -1;
  return case when length (_rows) = 0 then 1 else 0 end;
}
;

-- A coloured status pill for an index state.
--
-- The two surfaces have separate vocabularies for the same condition. A
-- relational index rests in 'READY_FOR_INTERNAL_LOAD' or 'READY' (vvec.c:163-165,
-- and the engine accepts either wherever it asks whether an index is usable); an
-- RDF one rests in 'active'. Showing both words in one column invites the reader
-- to look for a difference that is not there, so all three render as **ready**.
--
-- 'active' is deliberately not part of the console's vocabulary. The four
-- transient RDF states -- creating, refreshing, draining, dropping -- already say
-- when an index is not ready, so "ready" is the useful contrast and a second word
-- for it is only noise.
--
-- Only the label is unified. Every comparison against 'active' elsewhere is
-- logic against what the catalogue stores and must keep matching the engine.
create procedure DB.DBA.VVEC_STATE_PILL (in st varchar, in empty integer := 0)
{
  declare cls, lbl, ttl varchar;
  st := lower (coalesce (st, ''));
  cls := case when st in ('active', 'ready', 'ready_for_internal_load') then 'green'
              when st in ('creating', 'refreshing', 'draining', 'dropping') then 'amber'
              when st = 'error' then 'red'
              else 'gray' end;
  lbl := case when st in ('active', 'ready', 'ready_for_internal_load') then 'ready'
              when st = '' then 'unknown'
              else st end;
  ttl := '';
  -- Built and holding nothing is not ready in any sense the reader cares about,
  -- so it does not get the green pill that says everything is fine.
  if (lbl = 'ready' and empty = 1)
    {
      lbl := 'empty';
      cls := 'amber';
      ttl := ' title="Built, but there is nothing in it - the selector matched no rows. Searches return nothing until the source has data and the index is refreshed."';
    }
  http (sprintf ('<span class="pill %s"%s><span class="dot"></span>%V</span>', cls, ttl, lbl));
}
;

-- A laxer name check for model / API-key registry names (allows - . _).
create procedure DB.DBA.VVEC_NAME_OK (in s varchar)
{
  -- Model / API-key registry name: word chars plus dot and dash (no dollar-sign anchor).
  if (s is null or length (s) = 0 or length (s) > 128)
    return 0;
  if (regexp_match ('[^A-Za-z0-9_.-]', s) is not null)
    return 0;
  return 1;
}
;

-- Format a value for display, mapping NULL/empty to an em-dash entity. Returns
-- HTML-ready output (escaped value or ASCII entity) -> emit with raw http().
create procedure DB.DBA.VVEC_DISP (in v any)
{
  declare s varchar;
  if (v is null)
    return '&mdash;';
  s := cast (v as varchar);
  if (length (trim (s)) = 0)
    return '&mdash;';
  return sprintf ('%V', s);
}
;

-- Collect queue / worker statistics for both the SQL and SPARQL surfaces.
-- Returned as a flat keyword vector; read with get_keyword().
create procedure DB.DBA.VVEC_QUEUE_STATS ()
{
  declare st any;
  declare sp, se, sc, srun, sint integer;
  declare slr, sle any;
  declare rp, re, ren, rb, ri, rsusp integer;
  declare rlr, rle, rproc any;

  sp := 0; se := 0; sc := 0; srun := 0; sint := 0; slr := null; sle := null;
  {
    declare exit handler for sqlstate '*' { goto rdf; };
    st  := DB.DBA.VEC_SQL_WORKER_STATUS ();
    sp  := get_keyword ('pending',    st, 0);
    se  := get_keyword ('error',      st, 0);
    sc  := get_keyword ('last_count', st, 0);
    slr := get_keyword ('last_run',   st, null);
    sle := get_keyword ('last_error', st, null);
    srun := case when exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'VEC_SQL_WORKER') then 1 else 0 end;
    sint := coalesce ((select SE_INTERVAL from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'VEC_SQL_WORKER'), 0);
  }
 rdf:
  rp := 0; re := 0; ren := 0; rb := 0; ri := 0; rsusp := 0; rlr := null; rle := null; rproc := 0;
  {
    declare exit handler for sqlstate '*' { goto done; };
    rp := (select count (*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_STATE = 'pending');
    re := (select count (*) from DB.DBA.SPARQL_VEC_QUEUE where SVQ_STATE = 'error');
    select SVW_ENABLED, SVW_BATCH_SIZE, SVW_IDLE_DELAY, SVW_LAST_RUN, SVW_LAST_ERROR, SVW_PROCESSED
      into ren, rb, ri, rlr, rle, rproc
      from DB.DBA.SPARQL_VEC_WORKER where SVW_ID = 1;
    rsusp := DB.DBA.VEC_INDEX_QUEUE_IS_SUSPENDED ();
  }
 done:
  return vector (
    'sql_pending', sp, 'sql_error', se, 'sql_last_count', sc,
    'sql_last_run', slr, 'sql_last_error', sle, 'sql_running', srun, 'sql_interval', sint,
    'rdf_pending', rp, 'rdf_error', re, 'rdf_enabled', ren, 'rdf_batch', rb, 'rdf_idle', ri,
    'rdf_last_run', rlr, 'rdf_last_error', rle, 'rdf_processed', rproc, 'rdf_suspended', rsusp);
}
;

-- ---------------------------------------------------------------------------
-- 7b. Sign-in sessions.
--
--     The console used to sit behind HTTP Digest authentication.  Digest keeps
--     no server-side state: the browser caches the credentials and replays them
--     on every request.  So there was nothing to revoke, signing out could only
--     ask the browser to please forget, and -- the reason this was rewritten --
--     a sign-in outlived the database it had authenticated against.  Deleting
--     virtuoso.db and rebuilding left the operator still signed in, because the
--     only thing ever checked is MD5(user:realm:password), recomputed per
--     request, and a fresh database hands back the same default credential.
--
--     Authentication is now a server-side session, modelled on the Virtuoso
--     Conductor (binsrc/conductor, whose v:login control is compiled by
--     binsrc/vspx/vspx.xsl).  Deleting the row ends the session, for real.
--
--     The password still never crosses the wire.  Signing in is a challenge:
--     the form carries a single-use nonce, the browser sends
--     MD5(nonce || password), and the server recomputes that from the stored
--     credential.  Same scheme as the Conductor (adm_login.vspx plus
--     y_sql_user_password_check).
--
--     Three deliberate departures from the Conductor:
--
--       * The session id travels in a cookie, not in the query string.  The
--         Conductor runs the control in mode="url" and appends ?sid=... to
--         every link, which leaks the session id into Referer headers, browser
--         history and proxy logs.  v:login does support mode="cookie"; the
--         Conductor simply does not use it.
--       * The cookie is HttpOnly and SameSite=Strict, and Secure whenever the
--         request arrived over HTTPS.  It carries no Expires, so it is a
--         session cookie.
--       * A session dies shortly after its page does.  While a console page is
--         open it heartbeats (VVEC_HEAD emits the timer, ping.vsp answers it).
--         When the beats stop -- tab closed, browser quit, machine asleep --
--         the session goes stale within VVEC_SES_BEAT_S seconds.  Nothing else
--         can implement "closing the page signs you out": HTTP has no close
--         event, and a pagehide beacon is unusable here because the console
--         navigates page to page, so it would fire on every link click.
--
--     Three independent windows must all hold for a session to stay valid:
--
--       VS_BEAT    + VVEC_SES_BEAT_S     the page is still open
--       VS_SEEN    + VVEC_SES_IDLE_MIN   somebody is still using it
--       VS_CREATED + VVEC_SES_MAX_H      it has not run forever
--
--     VS_SEEN advances only on a real page request, so a page left open on an
--     unattended screen still times out; the heartbeat advances VS_BEAT alone
--     and so cannot hold a session open indefinitely.
-- ---------------------------------------------------------------------------

-- Session store.  It also holds the one-shot sign-in nonces (VS_KIND = 'N'),
-- which lets a single sweep expire both.  Created through exec() so that
-- re-running this file on upgrade is a no-op rather than an error.
create procedure DB.DBA.VVEC_SESSION_DDL ()
{
  declare _stat, _msg varchar;
  _stat := '00000'; _msg := '';
  exec ('create table DB.DBA.VVEC_SESSION (
           VS_SID     varchar not null,
           VS_KIND    varchar not null,
           VS_UID     varchar,
           VS_IP      varchar,
           VS_CSRF    varchar,
           VS_CREATED datetime not null,
           VS_SEEN    datetime not null,
           VS_BEAT    datetime not null,
           primary key (VS_SID))', _stat, _msg);
  _stat := '00000'; _msg := '';
  exec ('create index VVEC_SESSION_BEAT on DB.DBA.VVEC_SESSION (VS_BEAT)', _stat, _msg);
  return 1;
}
;

select DB.DBA.VVEC_SESSION_DDL ()
;

-- Tuning.  Functions rather than literals, so an operator can redefine one
-- without editing the procedures that read it.
--
-- BEAT_S must comfortably exceed the heartbeat interval in VVEC_HEAD (30s):
-- browsers throttle timers in hidden tabs to roughly once a minute, so the
-- window has to survive two missed beats at the throttled rate.
create function DB.DBA.VVEC_SES_BEAT_S () returns integer   { return 150; }
;
create function DB.DBA.VVEC_SES_IDLE_MIN () returns integer { return 30; }
;
create function DB.DBA.VVEC_SES_MAX_H () returns integer    { return 12; }
;

-- Name of the session cookie.
create function DB.DBA.VVEC_SES_COOKIE () returns varchar { return 'vvec_sid'; }
;

-- 192 bits from the CSPRNG, hex so the value is safe unquoted in a Set-Cookie
-- header and in a hidden form field.
create function DB.DBA.VVEC_SES_RANDOM () returns varchar
{
  return bin2hex (xenc_rand_bytes (24, 0));
}
;

-- user_is_dba raises rather than returning 0 for an account it cannot resolve
-- (a role, a DAV-only account, a name that does not exist), so every caller
-- needs this wrapper.
create function DB.DBA.VVEC_IS_DBA (in _u varchar) returns integer
{
  declare exit handler for sqlstate '*' { return 0; };
  if (_u is null or not isstring (_u) or not length (_u))
    return 0;
  return case when user_is_dba (_u) then 1 else 0 end;
}
;

-- The directory the console is mounted at, so the cookie scope and every
-- redirect are right under /vvec-dev/ or any other mapping it is served from
-- rather than hardcoded to /vvec/.
--
-- Taken from the virtual-directory mapping, not from the request path.
-- Deriving it from the path looked equivalent and was not: the one request
-- that names the directory itself without a trailing slash -- /vvec -- has its
-- last slash at the very front, so the base came out as "/" and every redirect
-- lost the console prefix, sending /vvec to /login instead of /vvec/login.
-- http_map_get('domain') is the vhost lpath, which is the same answer for
-- /vvec, /vvec/ and /vvec/indexes alike.
create function DB.DBA.VVEC_BASE_PATH () returns varchar
{
  declare _p varchar;
  declare _i integer;
  _p := http_map_get ('domain');
  if (isstring (_p) and length (_p))
    {
      -- VHOST_DEFINE stores the lpath without its trailing slash.
      if (_p not like '%/')
        _p := _p || '/';
      return _p;
    }
  -- No mapping to ask (called outside an HTTP context): fall back to the
  -- request path, and treat a path with no directory part as the root.
  _p := http_path ();
  if (_p is null or not isstring (_p) or not length (_p))
    return '/vvec/';
  _i := strrchr (_p, '/');
  if (_i is null)
    return '/vvec/';
  return subseq (_p, 0, _i + 1);
}
;

-- Last path segment of the request, so the guard can recognise the pages that
-- must stay reachable while signed out.  The .vsp suffix is stripped because
-- the clean-URL rewrite may or may not have run by the time the guard is
-- called, and both spellings address the same page.
create function DB.DBA.VVEC_PAGE_NAME () returns varchar
{
  declare _p varchar;
  declare _i integer;
  _p := http_path ();
  if (_p is null or not isstring (_p))
    return '';
  _i := strrchr (_p, '/');
  if (_i is not null)
    _p := subseq (_p, _i + 1);
  if (_p like '%.vsp')
    _p := subseq (_p, 0, length (_p) - 4);
  return _p;
}
;

-- Drop everything past its last valid moment.  Expiry itself is enforced by the
-- lookup in VVEC_SESSION_TOUCH, which simply does not match an out-of-window
-- row, so this is only housekeeping: without it, rows for browsers that never
-- came back would accumulate forever.
create procedure DB.DBA.VVEC_SESSION_GC ()
{
  declare exit handler for sqlstate '*' { ; };
  delete from DB.DBA.VVEC_SESSION
        where VS_KIND = 'S'
          and (datediff ('second', VS_BEAT, now ()) > DB.DBA.VVEC_SES_BEAT_S ()
            or datediff ('minute', VS_SEEN, now ()) > DB.DBA.VVEC_SES_IDLE_MIN ()
            or datediff ('hour', VS_CREATED, now ()) > DB.DBA.VVEC_SES_MAX_H ());
  -- A nonce is single-use and short-lived.  Half an hour is generous for the
  -- time a sign-in page can plausibly sit open in front of somebody.
  delete from DB.DBA.VVEC_SESSION
        where VS_KIND = 'N'
          and datediff ('minute', VS_CREATED, now ()) > 30;
  commit work;
  return 1;
}
;

-- Mint a sign-in nonce and store it.  Redeemed exactly once, by VVEC_LOGIN.
create procedure DB.DBA.VVEC_LOGIN_NONCE ()
{
  declare _n varchar;
  _n := DB.DBA.VVEC_SES_RANDOM ();
  insert into DB.DBA.VVEC_SESSION (VS_SID, VS_KIND, VS_CREATED, VS_SEEN, VS_BEAT)
    values (_n, 'N', now (), now (), now ());
  commit work;
  return _n;
}
;

-- Verify a sign-in and open a session.  Returns the new session id, or NULL.
--
-- _resp is MD5(nonce || password), computed by the browser.  _plain is the
-- fallback the form submits when scripting is off; it is accepted only over
-- HTTPS, because otherwise it would put the password on the wire in clear --
-- which is the one thing the challenge exists to prevent.  (The Conductor
-- accepts its plaintext fallback unconditionally.)
--
-- Authorisation is unchanged from the digest guard this replaces: an enabled,
-- non-role, SQL-enabled account that is a DBA.  This is an operator tool.
create procedure DB.DBA.VVEC_LOGIN (in _user varchar, in _resp varchar,
                                    in _nonce varchar, in _plain varchar)
{
  declare _pwd, _sid varchar;
  declare _ok integer;

  if (_user is null or not isstring (_user) or not length (_user))
    return null;
  if (_nonce is null or not isstring (_nonce) or not length (_nonce))
    return null;

  -- Redeem the nonce.  One row, deleted on use: a replayed sign-in POST finds
  -- nothing and fails, and a nonce minted for one browser cannot be spent
  -- twice.
  delete from DB.DBA.VVEC_SESSION where VS_SID = _nonce and VS_KIND = 'N';
  if (row_count () = 0)
    return null;

  _pwd := null;
  {
    declare exit handler for not found { ; };
    select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into _pwd
      from DB.DBA.SYS_USERS
     where U_NAME = _user and U_IS_ROLE = 0 and U_SQL_ENABLE = 1
       and U_ACCOUNT_DISABLED = 0;
  }
  if (_pwd is null)
    return null;

  _ok := 0;
  if (isstring (_resp) and length (_resp) and lower (_resp) = lower (md5 (_nonce || _pwd)))
    _ok := 1;
  else if (isstring (_plain) and length (_plain) and is_https_ctx () and _plain = _pwd)
    _ok := 1;
  if (not _ok)
    return null;

  if (not DB.DBA.VVEC_IS_DBA (_user))
    return null;

  _sid := DB.DBA.VVEC_SES_RANDOM ();
  insert into DB.DBA.VVEC_SESSION
    (VS_SID, VS_KIND, VS_UID, VS_IP, VS_CSRF, VS_CREATED, VS_SEEN, VS_BEAT)
    values (_sid, 'S', _user, http_client_ip (), DB.DBA.VVEC_SES_RANDOM (),
            now (), now (), now ());
  commit work;
  return _sid;
}
;

-- Validate a session id and, when it holds, advance its clocks.
--
-- _beat_only separates the heartbeat from a page request: a heartbeat proves
-- the page is open (VS_BEAT) but must not claim somebody is using it
-- (VS_SEEN), or an abandoned open tab would never reach the idle timeout.
--
-- Returns the account name, or NULL when there is no live session.
create procedure DB.DBA.VVEC_SESSION_TOUCH (in _sid varchar, in _beat_only integer)
{
  declare _uid varchar;
  -- Nothing this procedure can hit is worth failing a request over: an
  -- unreadable session is an absent session.  Without this, an error here
  -- escapes into ws_auth_check, which can only answer 401 -- losing the
  -- redirect to the sign-in page that the caller would otherwise have sent.
  declare exit handler for sqlstate '*' { return null; };

  if (_sid is null or not isstring (_sid) or not length (_sid))
    return null;

  _uid := null;
  {
    -- NOT FOUND is a completion condition, not an exception, so a generic
    -- sqlstate handler does not catch it; a presented-but-unknown session id
    -- would otherwise raise straight out of the guard.
    declare exit handler for not found { ; };
    select VS_UID into _uid from DB.DBA.VVEC_SESSION
     where VS_SID = _sid
       and VS_KIND = 'S'
       and VS_IP = http_client_ip ()
       and datediff ('second', VS_BEAT, now ()) <= DB.DBA.VVEC_SES_BEAT_S ()
       and datediff ('minute', VS_SEEN, now ()) <= DB.DBA.VVEC_SES_IDLE_MIN ()
       and datediff ('hour', VS_CREATED, now ()) <= DB.DBA.VVEC_SES_MAX_H ();
  }
  if (_uid is null)
    return null;

  -- An account can lose its standing while signed in, so re-check rather than
  -- trust what was true when the session opened.
  if (not exists (select 1 from DB.DBA.SYS_USERS
                   where U_NAME = _uid and U_IS_ROLE = 0
                     and U_SQL_ENABLE = 1 and U_ACCOUNT_DISABLED = 0)
      or not DB.DBA.VVEC_IS_DBA (_uid))
    {
      delete from DB.DBA.VVEC_SESSION where VS_SID = _sid;
      commit work;
      return null;
    }

  if (_beat_only)
    update DB.DBA.VVEC_SESSION set VS_BEAT = now () where VS_SID = _sid;
  else
    update DB.DBA.VVEC_SESSION set VS_BEAT = now (), VS_SEEN = now () where VS_SID = _sid;
  commit work;
  return _uid;
}
;

-- End a session.  This is the thing digest authentication could never do.
create procedure DB.DBA.VVEC_SESSION_END (in _sid varchar)
{
  declare exit handler for sqlstate '*' { return 0; };
  if (_sid is null or not isstring (_sid) or not length (_sid))
    return 0;
  delete from DB.DBA.VVEC_SESSION where VS_SID = _sid;
  commit work;
  return 1;
}
;

-- The session id the browser presented, or NULL.
create function DB.DBA.VVEC_REQUEST_SID (inout _lines any) returns varchar
{
  declare _c any;
  declare _v varchar;
  declare exit handler for sqlstate '*' { return null; };
  _c := DB.DBA.vspx_get_cookie_vec (_lines);
  if (not isvector (_c))
    return null;
  _v := get_keyword (DB.DBA.VVEC_SES_COOKIE (), _c, '');
  if (not isstring (_v) or not length (_v))
    return null;
  return _v;
}
;

-- Emit the session cookie, or expire it when _expire is set.  No Expires on the
-- live cookie, so the browser drops it on exit; the heartbeat window is what
-- actually bounds a session, this only avoids leaving the id on disk.  The
-- header is appended to whatever is already pending, so a caller can set the
-- cookie and redirect in one response.
create procedure DB.DBA.VVEC_SET_COOKIE (in _sid varchar, in _expire integer)
{
  declare _h, _c varchar;
  _c := sprintf ('Set-Cookie: %s=%s; Path=%s; HttpOnly; SameSite=Strict',
                 DB.DBA.VVEC_SES_COOKIE (), _sid, DB.DBA.VVEC_BASE_PATH ());
  if (is_https_ctx ())
    _c := _c || '; Secure';
  if (_expire)
    _c := _c || '; Expires=Thu, 01 Jan 1970 00:00:00 GMT';
  _c := _c || '\r\n';
  _h := http_header_get ();
  if (_h is null)
    _h := '';
  http_header (_h || _c);
  return 1;
}
;

-- A path the sign-in page may send the browser back to.  Only a path inside
-- this console is allowed: an absolute URL, a protocol-relative //host, a
-- traversal or an embedded newline would turn the sign-in page into an open
-- redirect or a header-injection point.
create function DB.DBA.VVEC_SAFE_RETURN (in _url varchar) returns varchar
{
  declare _base varchar;
  _base := DB.DBA.VVEC_BASE_PATH ();
  if (_url is null or not isstring (_url) or length (_url) < length (_base))
    return _base;
  if (strstr (_url, '..') is not null)
    return _base;
  if (strchr (_url, chr (13)) is not null or strchr (_url, chr (10)) is not null)
    return _base;
  if (subseq (_url, 0, length (_base)) <> _base)
    return _base;
  return _url;
}
;

-- ---------------------------------------------------------------------------
-- 7b-i. Authentication guard for the virtual directory, wired as the vhost
--       auth_fn.  Returns 1 to let a request through and 0 to stop it -- and
--       when it stops one it answers with a redirect to the sign-in page
--       rather than the bare 401 the server would otherwise send.  An auth_fn
--       may set its own status: ws_auth_check (libsrc/Wi/http.c) passes
--       "HTTP/1.1 401 Unauthorized" to ws_strses_reply, which prefers
--       ws_status_line when the procedure set one.  Same shape as the shipped
--       WS.VS_U_3.COOKIE_SES_RESTORE tutorial.
-- ---------------------------------------------------------------------------
create function DB.DBA.VVEC_AUTH (in realm varchar) returns integer
{
  declare _sid, _uid, _page, _ret, _qs varchar;

  _page := DB.DBA.VVEC_PAGE_NAME ();
  _sid  := DB.DBA.VVEC_REQUEST_SID (http_request_header ());
  _uid  := DB.DBA.VVEC_SESSION_TOUCH (_sid, case when _page = 'ping' then 1 else 0 end);

  if (_uid is not null)
    {
      -- Pages read the signed-in account from here, exactly as they did under
      -- digest authentication, so nothing downstream had to change.
      connection_set ('SPARQLUserId', _uid);
      connection_set ('VVecSid', _sid);
      -- Reaching the sign-in page while already signed in is a no-op, not a
      -- second session: send them where they were going.
      if (_page = 'login')
        {
          http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf ('Location: %s\r\n',
                                DB.DBA.VVEC_SAFE_RETURN (http_param ('url'))));
          return 0;
        }
      return 1;
    }

  -- Signed out.  The sign-in page has to be reachable, and so does the
  -- signed-out page, which is where a browser lands holding a session that was
  -- just ended.
  if (_page = 'login' or _page = 'logout')
    return 1;

  -- The heartbeat gets a bare 401 rather than a redirect: it is a background
  -- fetch whose page reads the status to notice it has been signed out.
  -- Redirecting it would hand the sign-in page HTML to a caller with no use
  -- for it.
  if (_page = 'ping')
    {
      http_request_status ('HTTP/1.1 401 Unauthorized');
      return 0;
    }

  -- Send them back to the clean URL they asked for, not the .vsp the rewrite
  -- rule turned it into on the way here.
  _ret := http_path ();
  if (_ret like '%.vsp')
    _ret := subseq (_ret, 0, length (_ret) - 4);
  _qs  := http_request_get ('QUERY_STRING');
  if (isstring (_qs) and length (_qs))
    _ret := _ret || '?' || _qs;

  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf ('Location: %slogin?url=%U\r\n',
                        DB.DBA.VVEC_BASE_PATH (), _ret));
  return 0;
}
;

-- ---------------------------------------------------------------------------
-- 7c. CSRF protection for state-changing (POST) requests.
--
--     Now that there is a session, the token is the textbook synchroniser
--     pattern: one unguessable value minted with the session, kept in its row,
--     embedded in every POST form and compared on submission.  It replaces the
--     stateless HMAC-over-a-time-window this console carried while it was
--     under digest authentication, which had to exist only because digest left
--     nowhere to keep a per-session secret.  A token is now worthless the
--     moment its session ends, rather than for another twelve hours.
-- ---------------------------------------------------------------------------

-- The token for the current session; embedded in every POST form.
create function DB.DBA.VVEC_CSRF_TOKEN () returns varchar
{
  declare _sid, _tok varchar;
  declare exit handler for sqlstate '*' { return ''; };
  _sid := connection_get ('VVecSid');
  if (_sid is null or not isstring (_sid))
    return '';
  _tok := null;
  {
    declare exit handler for not found { ; };
    select VS_CSRF into _tok from DB.DBA.VVEC_SESSION
     where VS_SID = _sid and VS_KIND = 'S';
  }
  if (_tok is null)
    return '';
  return _tok;
}
;

-- Authority (host[:port]) of a URL, for the Origin/Referer defence-in-depth check.
create function DB.DBA.VVEC_URL_HOST (in _url varchar) returns varchar
{
  declare _p any;
  declare exit handler for sqlstate '*' { return null; };
  if (_url is null or not isstring (_url) or not length (_url))
    return null;
  _p := WS.WS.PARSE_URI (_url);
  if (isvector (_p) and length (_p) > 1)
    return cast (_p[1] as varchar);
  return null;
}
;

-- The guard called first by every POST handler.  Returns 1 when the request is
-- a legitimate same-origin POST bearing this session token; otherwise emits a
-- 403 and returns 0 (the caller must then return without acting).
create function DB.DBA.VVEC_CSRF_CHECK (in _params any, in _lines any) returns integer
{
  declare _tok, _exp, _host, _origin, _oh varchar;
  -- A state-changing action must never be reachable by GET, which a plain link
  -- or an <img> could trigger with the ambient session cookie.
  if (http_request_get ('REQUEST_METHOD') <> 'POST')
    goto deny;
  _exp := DB.DBA.VVEC_CSRF_TOKEN ();
  _tok := get_keyword ('csrf', _params, '');
  if (not isstring (_exp) or not length (_exp) or _tok <> _exp)
    goto deny;
  -- Defence in depth (not relied on alone): when the browser sends an Origin or
  -- Referer, its host must match the request Host.
  _host   := http_request_header (_lines, 'Host', null, null);
  _origin := http_request_header (_lines, 'Origin', null, null);
  if (_origin is null)
    _origin := http_request_header (_lines, 'Referer', null, null);
  if (_origin is not null and _host is not null)
    {
      _oh := DB.DBA.VVEC_URL_HOST (_origin);
      if (_oh is null or lower (_oh) <> lower (_host))
        goto deny;
    }
  return 1;
 deny:
  http_request_status ('HTTP/1.1 403 Forbidden');
  http ('CSRF validation failed: reload the VVec page and retry.');
  return 0;
}
;
-- ---------------------------------------------------------------------------
-- 7b. Namespace-prefix helpers (the Namespace Prefixes page, and qname
--     expansion for the IRI fields on the Create / Edit pages).
--
--     Virtuoso keeps one server-wide set of persistent namespace prefixes in
--     DB.DBA.SYS_XML_PERSISTENT_NS_DECL; it is the same set the built-in SPARQL
--     query editor lists under "Namespace Prefixes", and the same set a SPARQL
--     query resolves a qname against when it declares no local PREFIX.  Writes
--     go through DB.DBA.XML_SET_NS_DECL / XML_REMOVE_NS_BY_PREFIX with persist
--     = 2 so the in-memory map and the table stay in step.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_PREFIX_OK (in s varchar)
{
  -- A namespace prefix name: letter or underscore, then word chars, dot or dash.
  -- (Anchors avoided so the isql command-line loader does not treat the dollar
  -- sign as a macro.)
  if (s is null or length (s) = 0 or length (s) > 64)
    return 0;
  if (regexp_match ('^[A-Za-z_]', s) is null)
    return 0;
  if (regexp_match ('[^A-Za-z0-9_.-]', s) is not null)
    return 0;
  return 1;
}
;

-- The (namespace IRI, prefix) pairs, longest namespace first so a scan hits the
-- most specific one first -- "schema-https" and "schema" both prefix-match an
-- https://schema.org/ IRI, and the longer namespace is the right answer.
create procedure DB.DBA.VVEC_NS_MAP ()
{
  declare res any;
  res := vector ();
  for (select NS_PREFIX as _p, NS_URL as _u
         from DB.DBA.SYS_XML_PERSISTENT_NS_DECL
        where NS_URL is not null and length (NS_URL) > 0
        order by length (NS_URL) desc) do
    res := vector_concat (res, vector (vector (_u, _p)));
  return res;
}
;

-- The prefixed-name form of an IRI, or '' when no declared prefix covers it.
-- The caller builds the map once (VVEC_NS_MAP) and passes it in, so a list
-- of predicates costs one catalog query rather than one per row.
create procedure DB.DBA.VVEC_QNAME_OF (in _iri varchar, in _map any)
{
  declare i, n, ln integer;
  declare _row any;
  declare _u varchar;
  if (_iri is null or length (_iri) = 0 or not isvector (_map))
    return '';
  n := length (_map);
  for (i := 0; i < n; i := i + 1)
    {
      _row := _map[i];
      _u := _row[0];
      ln := length (_u);
      -- ln < length(_iri) so the local part is never empty
      if (ln > 0 and ln < length (_iri) and subseq (_iri, 0, ln) = _u)
        return _row[1] || ':' || subseq (_iri, ln);
    }
  return '';
}
;

-- Expand a prefixed name ("schema:name") against the instance's declared
-- namespace prefixes, so the Create / Edit forms accept one wherever they accept
-- a full IRI.  This matters because the console writes the value into the DDL
-- inside angle brackets: <schema:name> is not a qname to SPARQL, it is an
-- absolute IRI whose scheme happens to be "schema", so the index is created,
-- reports 'active', and silently matches nothing.
--
-- The value is returned UNCHANGED unless it really looks like a declared
-- prefixed name, so a full IRI, a urn:, or a prefix nobody declared all pass
-- through as typed:
--   * no colon                       -> unchanged
--   * "scheme://..." (local part starts with /) -> unchanged
--   * prefix is not a legal prefix name         -> unchanged
--   * prefix is not in SYS_XML_PERSISTENT_NS_DECL -> unchanged
-- The local part is not constrained beyond that: concatenating it onto the
-- namespace yields the IRI the user meant even when it is not a strict
-- PN_LOCAL.
create procedure DB.DBA.VVEC_EXPAND_QNAME (in s varchar)
{
  declare _c integer;
  declare _pfx, _loc, _ns varchar;
  if (s is null)
    return s;
  s := trim (s);
  if (length (s) = 0)
    return s;
  _c := strchr (s, ':');
  if (_c is null)
    return s;
  _pfx := subseq (s, 0, _c);
  _loc := subseq (s, _c + 1);
  if (length (_loc) > 0 and aref (_loc, 0) = 47)     -- '/' : an absolute IRI
    return s;
  if (length (_pfx) > 0 and DB.DBA.VVEC_PREFIX_OK (_pfx) = 0)
    return s;
  -- The empty prefix (":name") is legal SPARQL and can be declared, so it is
  -- looked up like any other rather than rejected.
  _ns := (select NS_URL from DB.DBA.SYS_XML_PERSISTENT_NS_DECL where NS_PREFIX = _pfx);
  if (_ns is null)
    return s;
  return _ns || _loc;
}
;

-- How many subjects a SPARQL vector index currently holds, or -1 when that
-- cannot be determined.  Used by the Create / Edit pages to catch the quiet
-- failure mode of a selector that matches nothing: the DDL and the refresh both
-- succeed and the index goes 'active', but it is empty and every search against
-- it returns no rows.
create procedure DB.DBA.VVEC_SPARQL_INDEX_ROWS (in _iri varchar)
{
  declare _srct, _st, _msg varchar;
  declare _meta, _rows, _row any;
  declare exit handler for sqlstate '*' { return -1; };
  _srct := (select SVI_SOURCE_TABLE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _iri);
  if (_srct is null)
    return -1;
  _st := '00000';
  exec (sprintf ('select count (*) from "%I"."%I"."%I"',
                 name_part (_srct, 0), name_part (_srct, 1), name_part (_srct, 2)),
        _st, _msg, vector (), 1, _meta, _rows);
  if (_st <> '00000' or not isvector (_rows) or length (_rows) = 0)
    return -1;
  _row := _rows[0];
  if (not isvector (_row) or length (_row) = 0)
    return -1;
  return cast (_row[0] as integer);
}
;

-- ---------------------------------------------------------------------------
-- 7c. Edit-page helpers: read back a full index definition so edit.vsp can
--     prefill the form and rebuild the exact DDL that created it.
-- ---------------------------------------------------------------------------

-- Normalize a stored distance metric to a value the DDL accepts.
create procedure DB.DBA.VVEC_METRIC_VALUE (in v any)
{
  declare s varchar;
  s := lower (trim (coalesce (cast (v as varchar), '')));
  if (s = '1' or s = 'cosine') return 'cosine';
  if (s = '2' or s = 'l2')     return 'l2';
  if (s = '3' or s = 'l1')     return 'l1';
  return 'cosine';
}
;

-- Everything edit.vsp needs about one relational vector index, or NULL when the
-- name is not a SQL vector index.  Returns
--   vector (table, source_col, pk_col, model, dims, metric, hnsw_m,
--           ef_construction, reduce, source_kind, state)
create procedure DB.DBA.VVEC_SQL_INDEX_FULL (in _name varchar)
{
  declare _sc, _pk, _mid, _model, ktb, _rd, _sk, _st varchar;
  declare _dims, _hm, _ef integer;
  declare ko any;
  whenever not found goto nf;
  select KEY_TABLE, KEY_OPTIONS into ktb, ko
    from DB.DBA.SYS_KEYS
   where KEY_NAME = _name and KEY_MIGRATE_TO is null;
  _sc  := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'sc') as varchar);
  _pk  := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'pk') as varchar);
  _mid := cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'mid') as varchar);
  if (_sc is null or _pk is null or _mid is null)
    return null;
  _model := coalesce ((select model_name from DB.DBA.ONNX_MODELS where model_id = atoi (_mid)), _mid);
  -- Each option is stored either under its short marker or under the WITH-clause
  -- spelling, depending on how the index was created; read both (as
  -- VVEC_SQL_INDEXES does) so the form prefills from either.
  _dims  := atoi (coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'd') as varchar),
                            cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'dimensions') as varchar),
                            cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'dimension') as varchar), '0'));
  _hm    := atoi (coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'hm') as varchar),
                            cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'hnsw_m') as varchar), '16'));
  _ef    := atoi (coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'ef') as varchar),
                            cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'ef_construction') as varchar), '200'));
  _rd    := lower (trim (coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'rd') as varchar),
                                   cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'reduce') as varchar), 'none')));
  _sk    := lower (trim (coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'sk') as varchar),
                                   cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'source_kind') as varchar), 'text')));
  _st    := coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'st') as varchar), 'active');
  if (_hm <= 0) _hm := 16;
  if (_ef <= 0) _ef := 200;
  if (_rd not in ('none', 'truncate')) _rd := 'none';
  if (_sk not in ('text', 'vector'))   _sk := 'text';
  return vector (ktb, _sc, _pk, _model, _dims,
                 DB.DBA.VVEC_METRIC_VALUE (
                   coalesce (DB.DBA.VEC_SQL_INDEX_OPT (ko, 'mt'),
                             DB.DBA.VEC_SQL_INDEX_OPT (ko, 'distance_metric'),
                             DB.DBA.VEC_SQL_INDEX_OPT (ko, 'metric'))),
                 _hm, _ef, _rd, _sk, _st);
nf:
  return null;
}
;

-- The inner group-graph-pattern of a stored general selector.  SVI_WHERE_TEXT is
-- kept as the source text from "WHERE" through the matching "}", but the DDL
-- builder re-wraps it as "where { <inner> }", so strip the keyword and the outer
-- braces back off.
create procedure DB.DBA.VVEC_WHERE_INNER (in s any)
{
  declare t varchar;
  declare a, b integer;
  if (s is null)
    return '';
  t := trim (cast (s as varchar));
  if (length (t) = 0)
    return '';
  a := strchr (t, '{');
  b := strrchr (t, '}');
  if (a is null or b is null or b <= a)
    return t;
  return trim (subseq (t, a + 1, b));
}
;

-- Structural gate for a stored PREFIX preamble (SVI_WHERE_PATTERN).  The parser
-- writes it as a run of "PREFIX <name>: <IRI> " declarations that were in scope
-- when the index was created; edit.vsp re-emits it verbatim ahead of the
-- regenerated DDL so a general selector written with local prefixes still
-- resolves.  Accept only that exact shape -- anything else is refused rather
-- than interpolated into a statement that runs as dba.
create procedure DB.DBA.VVEC_PREFIX_PREAMBLE_OK (in s any)
{
  declare t, pfx varchar;
  declare i, n, c integer;
  if (s is null)
    return 1;                                   -- nothing to re-emit
  t := cast (s as varchar);
  n := length (t);
  if (n = 0)
    return 1;
  if (n > 4000)
    return 0;
  i := 0;
  while (i < n)
    {
      -- skip whitespace between declarations
      while (i < n and aref (t, i) <= 32) i := i + 1;
      if (i >= n)
        return 1;
      if (i + 6 > n or ucase (subseq (t, i, i + 6)) <> 'PREFIX')
        return 0;
      i := i + 6;
      if (i >= n or aref (t, i) > 32)           -- "PREFIX" must be followed by a space
        return 0;
      while (i < n and aref (t, i) <= 32) i := i + 1;
      -- prefix name up to the colon (the empty prefix ":" is legal SPARQL)
      pfx := '';
      while (i < n and aref (t, i) <> 58)
        { pfx := pfx || chr (aref (t, i)); i := i + 1; }
      if (i >= n)
        return 0;
      i := i + 1;                               -- the colon
      if (length (pfx) > 0 and DB.DBA.VVEC_PREFIX_OK (pfx) = 0)
        return 0;
      while (i < n and aref (t, i) <= 32) i := i + 1;
      if (i >= n or aref (t, i) <> 60)          -- '<'
        return 0;
      i := i + 1;
      c := i;
      while (i < n and aref (t, i) <> 62)       -- '>'
        i := i + 1;
      if (i >= n)
        return 0;
      if (DB.DBA.VVEC_IRI_OK (subseq (t, c, i)) = 0)
        return 0;
      i := i + 1;
    }
  return 1;
}
;

-- Structural gate for a general selector's dataset clause: a run of
-- "FROM <IRI>" / "FROM NAMED <IRI>" and nothing else.  It is written into the
-- regenerated DDL between the EMBEDDING variable and WHERE, so it gets the same
-- treatment as the WHERE pattern.  An empty clause is valid (most selectors
-- have none).
create procedure DB.DBA.VVEC_DATASET_OK (in s any)
{
  declare t varchar;
  declare i, n, c integer;
  if (s is null)
    return 1;
  t := cast (s as varchar);
  n := length (t);
  if (n = 0)
    return 1;
  if (n > 2000)
    return 0;
  i := 0;
  while (i < n)
    {
      while (i < n and aref (t, i) <= 32) i := i + 1;
      if (i >= n)
        return 1;
      if (i + 4 > n or ucase (subseq (t, i, i + 4)) <> 'FROM')
        return 0;
      i := i + 4;
      if (i >= n or aref (t, i) > 32)
        return 0;
      while (i < n and aref (t, i) <= 32) i := i + 1;
      if (i + 5 <= n and ucase (subseq (t, i, i + 5)) = 'NAMED'
          and i + 5 < n and aref (t, i + 5) <= 32)
        {
          i := i + 5;
          while (i < n and aref (t, i) <= 32) i := i + 1;
        }
      if (i >= n or aref (t, i) <> 60)
        return 0;
      i := i + 1;
      c := i;
      while (i < n and aref (t, i) <> 62)
        i := i + 1;
      if (i >= n)
        return 0;
      if (DB.DBA.VVEC_IRI_OK (subseq (t, c, i)) = 0)
        return 0;
      i := i + 1;
    }
  return 1;
}
;

-- Everything edit.vsp needs about one RDF vector index, or NULL when the IRI is
-- not in the catalog.  Returns
--   vector (0 selector_type, 1 graph, 2 predicate, 3 key_var, 4 embedding_var,
--           5 where_inner, 6 prefix_preamble, 7 dataset_text, 8 model,
--           9 dimensions, 10 distance, 11 hnsw_m, 12 ef_construction,
--          13 maintenance, 14 reduce, 15 build, 16 rebuild, 17 source_kind,
--          18 state)
create procedure DB.DBA.VVEC_SPARQL_INDEX_FULL (in _iri varchar)
{
  declare _sel, _g, _p, _kv, _ev, _wt, _pre, _ds varchar;
  declare _model, _dist, _maint, _reduce, _build, _rebuild, _skind, _state varchar;
  declare _label, _comment varchar;
  declare _dims, _hm, _ef integer;
  whenever not found goto nf;
  select SVI_SELECTOR_TYPE, SVI_SELECTOR_GRAPH, SVI_SELECTOR_PRED,
         SVI_KEY_VAR, SVI_EMBEDDING_VAR,
         cast (SVI_WHERE_TEXT as varchar), cast (SVI_WHERE_PATTERN as varchar), SVI_DATASET_TEXT,
         SVI_MODEL_NAME, SVI_DIMENSIONS, SVI_DISTANCE, SVI_HNSW_M, SVI_EF_CONSTRUCTION,
         SVI_MAINTENANCE, SVI_REDUCE, SVI_BUILD, SVI_REBUILD, SVI_SOURCE_KIND, SVI_STATE,
         SVI_LABEL, SVI_COMMENT
    into _sel, _g, _p, _kv, _ev, _wt, _pre, _ds,
         _model, _dims, _dist, _hm, _ef, _maint, _reduce, _build, _rebuild, _skind, _state,
         _label, _comment
    from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _iri;
  _sel    := lower (trim (coalesce (_sel, 'shorthand')));
  if (_sel not in ('shorthand', 'general')) _sel := 'shorthand';
  _maint  := lower (trim (coalesce (_maint, 'manual')));
  if (_maint not in ('manual', 'async')) _maint := 'manual';
  _reduce := lower (trim (coalesce (_reduce, 'none')));
  if (_reduce not in ('none', 'truncate')) _reduce := 'none';
  _build  := lower (trim (coalesce (_build, 'auto')));
  if (_build not in ('auto', 'incremental', 'bulk')) _build := 'auto';
  _rebuild := lower (trim (coalesce (_rebuild, '')));
  if (_rebuild not in ('replay', 'fast', 'auto')) _rebuild := '';
  _skind  := lower (trim (coalesce (_skind, 'text')));
  if (_skind not in ('text', 'vector')) _skind := 'text';
  if (_hm is null or _hm <= 0) _hm := 16;
  if (_ef is null or _ef <= 0) _ef := 200;
  return vector (_sel, coalesce (_g, ''), coalesce (_p, ''),
                 coalesce (_kv, 'doc'), coalesce (_ev, 'text'),
                 DB.DBA.VVEC_WHERE_INNER (_wt),
                 trim (coalesce (_pre, '')), trim (coalesce (_ds, '')),
                 _model, _dims, DB.DBA.VVEC_METRIC_VALUE (_dist), _hm, _ef,
                 _maint, _reduce, _build, _rebuild, _skind, coalesce (_state, ''),
                 coalesce (_label, ''), coalesce (_comment, ''));
nf:
  return null;
}
;

-- ---------------------------------------------------------------------------
-- 7d. DDL builders.  edit.vsp uses these twice per save: once for the statement
--     that creates the edited definition, and once for the statement that would
--     put the original definition back if that first one fails after the drop.
--     Every argument is validated by the caller against the catalog or a fixed
--     value set; the model name is quote-escaped here as defence in depth (SQL
--     doubles the quote, SPARQL backslashes it).
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_SQL_VEC_DDL (
  in _idx varchar, in _tbl varchar, in _col varchar, in _model varchar,
  in _dims integer, in _metric varchar, in _hm integer, in _ef integer,
  in _reduce varchar, in _skind varchar)
{
  declare _mesc, _skopt varchar;
  _mesc := replace (_model, chr (39), chr (39) || chr (39));
  -- source_kind is written only for a precomputed-vector passthrough index, so
  -- an ordinary text index produces byte-identical DDL to the Create page's.
  if (lower (coalesce (_skind, 'text')) = 'vector')
    _skopt := ', source_kind = ''vector''';
  else
    _skopt := '';
  return sprintf (
    'CREATE VECTOR INDEX "%I" ON "%I"."%I"."%I" ("%I") USING ''%s'' WITH (dimensions = %d, distance_metric = ''%s'', hnsw_m = %d, ef_construction = %d, reduce = ''%s''%s)',
    _idx, name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2), _col,
    _mesc, _dims, _metric, _hm, _ef, _reduce, _skopt);
}
;

-- One free-text value, as a single-quoted SPARQL string literal.
--
-- The label and the comment are prose an operator typed, so unlike every other
-- value in this DDL they can contain a quote, a backslash or a newline -- and a
-- raw newline inside a single-quoted SPARQL literal is a syntax error, not just
-- ugly.  Backslash first, or escaping the quote would then be re-escaped.
create procedure DB.DBA.VVEC_SPARQL_STR (in _s varchar)
{
  declare _t varchar;
  _t := coalesce (_s, '');
  _t := replace (_t, chr (92), chr (92) || chr (92));
  _t := replace (_t, chr (39), chr (92) || chr (39));
  _t := replace (_t, chr (13), chr (92) || 'r');
  _t := replace (_t, chr (10), chr (92) || 'n');
  _t := replace (_t, chr (9),  chr (92) || 't');
  return chr (39) || _t || chr (39);
}
;

create procedure DB.DBA.VVEC_SPARQL_VEC_DDL (
  in _iri varchar, in _seltype varchar, in _graph varchar, in _pred varchar,
  in _keyv varchar, in _embv varchar, in _where varchar,
  in _prefixes varchar, in _dataset varchar, in _model varchar,
  in _dims integer, in _dist varchar, in _hm integer, in _ef integer,
  in _maint varchar, in _reduce varchar, in _build varchar,
  in _rebuild varchar, in _skind varchar,
  in _label varchar := '', in _comment varchar := '')
{
  declare _mesc, _opts, _pre, _ds varchar;
  _mesc := replace (_model, chr (39), chr (92) || chr (39));
  -- A general selector created with local PREFIX declarations stored them in
  -- SVI_WHERE_PATTERN; re-emitting them ahead of the statement puts the same
  -- prefixes back in scope, so the stored WHERE text still resolves.  SPARQL
  -- wants the define pragmas before any PREFIX, hence the position.
  _pre := trim (coalesce (_prefixes, ''));
  if (_pre <> '') _pre := _pre || ' ';
  _ds := trim (coalesce (_dataset, ''));
  if (_ds <> '') _ds := _ds || ' ';
  _opts := sprintf ('dimensions = %d, distance = ''%s'', hnsw_m = %d, ef_construction = %d, maintenance = ''%s'', reduce = ''%s''',
                    _dims, _dist, _hm, _ef, _maint, _reduce);
  -- 'auto' is the server's own default for build, so it is left out entirely
  -- rather than written explicitly (that keeps SVI_BUILD null, as on create).
  if (lower (coalesce (_build, 'auto')) in ('incremental', 'bulk'))
    _opts := _opts || sprintf (', build = ''%s''', lower (_build));
  if (lower (coalesce (_rebuild, '')) in ('replay', 'fast', 'auto'))
    _opts := _opts || sprintf (', rebuild = ''%s''', lower (_rebuild));
  if (lower (coalesce (_skind, 'text')) = 'vector')
    _opts := _opts || ', source_kind = ''vector''';
  -- The label and the comment go in here, not into a separate call after the
  -- CREATE, because this builder is also what the restore-on-failure path
  -- replays: an option this statement does not carry is one a failed edit
  -- silently drops on the way back.  Empty means unset, and an unset value is
  -- written by leaving the option out rather than by passing ''.
  if (trim (coalesce (_label, '')) <> '')
    _opts := _opts || ', label = ' || DB.DBA.VVEC_SPARQL_STR (trim (_label));
  if (trim (coalesce (_comment, '')) <> '')
    _opts := _opts || ', comment = ' || DB.DBA.VVEC_SPARQL_STR (trim (_comment));
  if (_seltype = 'shorthand')
    return sprintf (
      'sparql define input:storage "" %screate vector index <%s> on graph <%s> for predicate <%s> using model ''%s'' with (%s)',
      _pre, _iri, _graph, _pred, _mesc, _opts);
  return sprintf (
    'sparql define input:storage "" %screate vector index <%s> key ?%s embedding ?%s %swhere { %s } using model ''%s'' with (%s)',
    _pre, _iri, _keyv, _embv, _ds, _where, _mesc, _opts);
}
;

-- ---------------------------------------------------------------------------
-- 7c2. Who may annotate an index.  The Permissions page administers exactly one
--      thing: SQL EXECUTE on DB.DBA.VEC_INDEX_SET_METADATA, the procedure that
--      writes a vector index's rdfs:label and rdfs:comment.
--
--      Two gates protect that write and the page has to explain both, because a
--      permission UI that does not say what the permission means is how people
--      over-grant.  EXECUTE answers "may this account annotate indexes at all";
--      the procedure's own owner-or-DBA check answers "which ones".  So an
--      account listed here can retitle the indexes IT created and nothing else,
--      while a DBA account can retitle any -- which is why DBA accounts appear
--      in the page's list but not in this grant table and have no Revoke
--      button: they hold the right by being DBA, and a button that could not
--      take it away would be a lie.
--
--      A fresh install grants EXECUTE to nobody.  Note that phrasing carefully:
--      to NO ONE, not `to nobody` -- `nobody` is a real account (U_ID 5), the
--      identity unauthenticated requests get, and `GRANT ... TO nobody` parses,
--      succeeds, prints nothing at all and opens the procedure to anonymous
--      callers.  It is offered in the grant list like any other account, named
--      for what it is, rather than quietly filtered out.
-- ---------------------------------------------------------------------------

-- GR_EXECUTE from libsrc/Wi/widd.h; SYS_GRANTS.G_OP is that bitmask value.
create procedure DB.DBA.VVEC_GR_EXECUTE () { return 32; }
;

create procedure DB.DBA.VVEC_META_PROC () { return 'DB.DBA.VEC_INDEX_SET_METADATA'; }
;

-- user_is_dba() for a name that may not be usable as a SQL identity.
--
-- The bif RAISES rather than returning 0 for an account with U_SQL_ENABLE = 0
-- -- SR390 "No such user dav in user_is_dba" -- and `dav` is such an account on
-- every Virtuoso.  Walking SYS_USERS and asking the question directly therefore
-- takes the whole page down with a 500 on a stock instance.  Anything the bif
-- will not answer for is not a DBA account for this page's purposes.
create procedure DB.DBA.VVEC_IS_DBA (in _n varchar) returns integer
{
  declare exit handler for sqlstate '*' { return 0; };
  if (user_is_dba (_n))
    return 1;
  return 0;
}
;

-- Everyone holding EXECUTE, as vector (id, name, kind) triples ordered by name.
--
-- kind is 'user', 'role' or 'public'.  A grant to a role is real -- everyone in
-- it inherits the right -- so it is listed rather than hidden, and so is a
-- grant to PUBLIC, which has no SYS_USERS row at all (G_USER 1) and would
-- otherwise vanish from an inner join and from the page along with it.  A grant
-- the page cannot see is the one that gets left behind.
create procedure DB.DBA.VVEC_META_GRANTEES ()
{
  declare _out any;
  _out := vector ();
  for (select g.G_USER as _uid,
              coalesce ((select u.U_NAME from DB.DBA.SYS_USERS u where u.U_ID = g.G_USER),
                        case when g.G_USER = 1 then 'PUBLIC' else sprintf ('user id %d', g.G_USER) end) as _nm,
              coalesce ((select u.U_IS_ROLE from DB.DBA.SYS_USERS u where u.U_ID = g.G_USER), 0) as _role
         from DB.DBA.SYS_GRANTS g
        where g.G_OBJECT = fix_identifier_case (DB.DBA.VVEC_META_PROC ())
          and g.G_OP = DB.DBA.VVEC_GR_EXECUTE ()
        order by 2) do
    {
      _out := vector_concat (_out, vector (vector (_uid, _nm,
        case when _uid = 1 then 'public' when _role = 1 then 'role' else 'user' end)));
    }
  return _out;
}
;

-- The DBA accounts, which may annotate every index by being DBA.
-- user_is_dba() is asked rather than U_ID = 0 or a group test, because that is
-- the exact predicate VEC_INDEX_SET_METADATA itself uses: anything else and the
-- page would describe a rule the server does not enforce.
create procedure DB.DBA.VVEC_META_DBAS ()
{
  declare _out any;
  _out := vector ();
  for (select U_NAME as _nm from DB.DBA.SYS_USERS
        where U_IS_ROLE = 0 order by U_NAME) do
    {
      if (DB.DBA.VVEC_IS_DBA (_nm))
        _out := vector_concat (_out, vector (_nm));
    }
  return _out;
}
;

-- The accounts a Grant may name: enabled login accounts that are not roles, are
-- not already DBA (they have the right already) and do not already hold the
-- grant.  Offered as a list rather than a text box because a mistyped username
-- in GRANT is how someone ends up believing they granted something they did
-- not -- and with `nobody` a real account, a typo can land somewhere much worse
-- than nowhere.
--
-- U_ACCOUNT_DISABLED filters out the service identities Virtuoso ships with --
-- SPARQL, SOAP, XMLA, PROXY and the rest.  They are non-role rows in SYS_USERS
-- and would otherwise fill this list with names nobody can sign in as, which
-- makes the two names that matter harder to find.  A grant already made to one
-- of them still appears in the list of holders above: this hides them from the
-- offer, never from the audit.
--
-- U_SQL_ENABLE filters on the same principle: this permission is EXECUTE on a
-- SQL procedure, and `dav` -- the WebDAV identity, on every Virtuoso -- cannot
-- run SQL at all, so granting it would be a permission that can never be used.
create procedure DB.DBA.VVEC_META_CANDIDATES ()
{
  declare _out any;
  _out := vector ();
  for (select U_NAME as _nm from DB.DBA.SYS_USERS
        where U_IS_ROLE = 0 and coalesce (U_ACCOUNT_DISABLED, 0) = 0
          and coalesce (U_SQL_ENABLE, 0) = 1 order by U_NAME) do
    {
      if (DB.DBA.VVEC_IS_DBA (_nm))
        goto nxt;
      if (exists (select 1 from DB.DBA.SYS_GRANTS g, DB.DBA.SYS_USERS u
                   where g.G_OBJECT = fix_identifier_case (DB.DBA.VVEC_META_PROC ())
                     and g.G_OP = DB.DBA.VVEC_GR_EXECUTE ()
                     and g.G_USER = u.U_ID and u.U_NAME = _nm))
        goto nxt;
      _out := vector_concat (_out, vector (_nm));
   nxt:;
    }
  return _out;
}
;

-- Grant EXECUTE to one named account.  Returns '' on success, else a message.
-- The name is checked against SYS_USERS rather than interpolated as typed: this
-- statement runs as dba, and GRANT takes an identifier, not a bound parameter.
create procedure DB.DBA.VVEC_META_GRANT (in _user varchar) returns varchar
{
  declare _st, _msg varchar;
  _user := trim (coalesce (_user, ''));
  if (not exists (select 1 from DB.DBA.SYS_USERS
                   where U_NAME = _user and U_IS_ROLE = 0
                     and coalesce (U_ACCOUNT_DISABLED, 0) = 0
                     and coalesce (U_SQL_ENABLE, 0) = 1))
    return sprintf ('%s is not an enabled SQL account on this instance.', _user);
  if (DB.DBA.VVEC_IS_DBA (_user))
    return sprintf ('%s is a DBA account and can already annotate every index.', _user);
  _st := '00000';
  exec (sprintf ('grant execute on %s to "%I"', DB.DBA.VVEC_META_PROC (), _user), _st, _msg);
  if (_st <> '00000' and _st <> 0)
    return sprintf ('%s: %s', cast (_st as varchar), coalesce (_msg, ''));
  return '';
}
;

-- Revoke it again.  Accepts anything the page listed, PUBLIC and roles
-- included: a grant made from isql should be removable from here, or the page
-- shows a permission it cannot administer.
create procedure DB.DBA.VVEC_META_REVOKE (in _user varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _found integer;
  declare _g any;
  declare i integer;
  _user := trim (coalesce (_user, ''));
  _found := 0;
  _g := DB.DBA.VVEC_META_GRANTEES ();
  for (i := 0; i < length (_g); i := i + 1)
    if (_g[i][1] = _user) _found := 1;
  if (_found = 0)
    return sprintf ('%s does not hold EXECUTE on this procedure.', _user);
  _st := '00000';
  if (_user = 'PUBLIC')
    exec (sprintf ('revoke execute on %s from PUBLIC', DB.DBA.VVEC_META_PROC ()), _st, _msg);
  else
    exec (sprintf ('revoke execute on %s from "%I"', DB.DBA.VVEC_META_PROC (), _user), _st, _msg);
  if (_st <> '00000' and _st <> 0)
    return sprintf ('%s: %s', cast (_st as varchar), coalesce (_msg, ''));
  return '';
}
;

-- The graphs a general selector reads, pulled out of its FROM / FROM NAMED
-- clauses.  A general selector has no SVI_SELECTOR_GRAPH -- the dataset is free
-- text -- but the graph is still the one part of it an operator recognises at a
-- glance, so the catalogue shows that and puts the rest behind a click.
-- Returns '' when the selector names no dataset at all, which is legal: the
-- query then runs against whatever the default graph set is.
create procedure DB.DBA.VVEC_DATASET_IRIS (in _txt any)
{
  declare _s, _out varchar;
  declare i, j integer;
  _s := coalesce (cast (_txt as varchar), '');
  _out := '';
  i := strchr (_s, '<');
  while (i is not null)
    {
      _s := subseq (_s, i + 1);
      j := strchr (_s, '>');
      if (j is null)
        goto done;
      if (j > 0)
        {
          if (_out <> '')
            _out := _out || ', ';
          _out := _out || subseq (_s, 0, j);
        }
      _s := subseq (_s, j + 1);
      i := strchr (_s, '<');
    }
done:
  return _out;
}
;

-- The two-line target cell of the index catalogue.  A target is always a
-- container and a thing inside it -- table and column, graph and predicate --
-- and squeezing both onto one line meant the column had to be clipped so early
-- that neither half survived.  Two lines shows the whole of each, and the
-- ellipsis only appears when one of them is genuinely too long on its own.
--
-- A general selector has no second half: it is an arbitrary query, which does
-- not fit in a cell and should not be summarised into one.  The graph goes on
-- the first line and the second is the way in to reading the actual query.
create procedure DB.DBA.VVEC_TARGET_CELL (
  in _main varchar, in _sub varchar, in _query any)
{
  http ('<td class="target">');
  if (_main = '')
    http ('<span class="t-main cell-muted">&mdash;</span>');
  else
    http (sprintf ('<span class="t-main" title="%V">%V</span>', _main, _main));
  if (isstring (_query))
    http (sprintf ('<button type="button" class="t-query" data-q="%V" onclick="vdSelShow(this)">(query)</button>', _query));
  else if (_sub <> '')
    http (sprintf ('<span class="t-sub" title="%V">%V</span>', _sub, _sub));
  http ('</td>');
}
;

-- The general selector in full, for the catalogue's "(query)" link.  It is one
-- shared dialog filled from the clicked row rather than one per row: the page
-- lists every index on the instance, and a hidden copy of each query would be
-- paid for on every page load to show at most one of them.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_SELECTOR_MODAL ()
{
  http ('<div id="sel-modal" class="modal-back hidden" onclick="vdSelBackdrop(event)">');
  http ('<div class="modal" role="dialog" aria-modal="true" aria-labelledby="sel-title">');
  http ('<div class="modal-head"><div><h3 id="sel-title">Custom selector</h3>');
  http ('<div class="sub mono" id="sel-iri"></div></div>');
  http ('<button type="button" class="modal-close" onclick="vdSelHide()" title="Close">&#215;</button></div>');
  http ('<div class="modal-body"><pre class="code" id="sel-q"></pre>');
  http ('<p class="cell-muted" style="margin-bottom:0">The key and embedding variables are the two this query binds; everything else is a join the index does not store.</p></div>');
  http ('<div class="modal-foot"><span class="note">Read-only. Change it from the index''s Edit page.</span>');
  http ('<div class="row-actions"><button type="button" class="btn sm" onclick="vdSelHide()">Close</button></div></div>');
  http ('</div></div>');

  http ('<script>
(function(){
  function el(id){ return document.getElementById(id); }
  window.vdSelShow = function(btn){
    var row = btn.closest("tr");
    el("sel-iri").textContent = row ? (row.getAttribute("data-iri") || "") : "";
    // textContent, not innerHTML: this is a query someone stored, and it is
    // being shown as text.
    el("sel-q").textContent = btn.getAttribute("data-q") || "";
    el("sel-modal").classList.remove("hidden");
  };
  window.vdSelHide = function(){ el("sel-modal").classList.add("hidden"); };
  window.vdSelBackdrop = function(ev){ if(ev.target && ev.target.id === "sel-modal") window.vdSelHide(); };
  document.addEventListener("keydown", function(ev){
    if(ev.key === "Escape" && !el("sel-modal").classList.contains("hidden")) window.vdSelHide();
  });
})();
</script>');
}
;

-- ---------------------------------------------------------------------------
-- 7d2. Entity labels.
--
-- A SPARQL result names a subject by its IRI, which is an address and not a
-- name.  What the reader wants to see is what the thing is called, and every
-- dataset says that differently -- rdfs:label, schema:name, skos:prefLabel,
-- dcterms:title, foaf:name.  Rather than teach the console a list, it asks the
-- engine: the properties are declared rdfs:subPropertyOf rdfs:label in a rule
-- graph, the graph is registered as an inference rule set, and a query for
-- rdfs:label under that rule set finds all of them.  The operator edits the
-- list on the Labels page; the console never hard-codes which property a
-- dataset uses for a name.
--
-- This is the same shape the Faceted Browser uses for its own labels
-- (binsrc/fct/sql/facet.sql builds urn:fct:facets and registers it as 'facets').
-- ---------------------------------------------------------------------------

create procedure DB.DBA.VVEC_LABEL_RULE ()  { return 'vvec-labels'; }
;
create procedure DB.DBA.VVEC_LABEL_GRAPH () { return 'urn:vvec:labels'; }
;

-- The properties currently declared as label-bearing, sorted.  rdfs:label
-- itself is not in the list: it is the target the others point at, and it is
-- always matched whether or not anything else is.
create procedure DB.DBA.VVEC_LABEL_PROPS ()
{
  declare _acc any;
  declare exit handler for sqlstate '*' { return vector (); };
  _acc := vector ();
  for (sparql select ?p where { graph <urn:vvec:labels>
         { ?p <http://www.w3.org/2000/01/rdf-schema#subPropertyOf>
              <http://www.w3.org/2000/01/rdf-schema#label> } } order by ?p) do
    {
      _acc := vector_concat (_acc, vector (cast ("p" as varchar)));
    }
  return _acc;
}
;

-- Re-read the graph into the rule set.  Calling rdfs_rule_set with an existing
-- name discards the old rule set and rebuilds it from the graphs registered
-- under that name, so this is the whole of "apply my edit".
create procedure DB.DBA.VVEC_LABEL_SYNC ()
{
  rdfs_rule_set (DB.DBA.VVEC_LABEL_RULE (), DB.DBA.VVEC_LABEL_GRAPH ());
  return 1;
}
;

-- Add one property.  Accepts a qname against the stored prefixes as well as a
-- full IRI, because the operator is reading qnames everywhere else in the
-- console.  Returns '' on success or a message.
create procedure DB.DBA.VVEC_LABEL_ADD (in _p varchar)
{
  declare _iri varchar;
  _iri := DB.DBA.VVEC_EXPAND_QNAME (trim (coalesce (_p, '')));
  if (length (_iri) = 0)
    return 'Enter a property IRI.';
  if (strchr (_iri, ':') is null)
    return 'That is not a property IRI. Give a full IRI, or a qname whose prefix is registered on the Prefixes page.';
  if (DB.DBA.VVEC_IRI_OK (_iri) = 0)
    return 'That IRI contains characters that cannot appear in one.';
  if (_iri = 'http://www.w3.org/2000/01/rdf-schema#label')
    return 'rdfs:label is the property the others resolve to; it is always matched and does not need adding.';
  exec (sprintf ('sparql insert into graph <%s> { <%s> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://www.w3.org/2000/01/rdf-schema#label> }',
                 DB.DBA.VVEC_LABEL_GRAPH (), _iri));
  DB.DBA.VVEC_LABEL_SYNC ();
  return '';
}
;

create procedure DB.DBA.VVEC_LABEL_DEL (in _p varchar)
{
  declare _iri varchar;
  _iri := trim (coalesce (_p, ''));
  if (DB.DBA.VVEC_IRI_OK (_iri) = 0)
    return 'Not a property this console stored.';
  exec (sprintf ('sparql delete from graph <%s> { <%s> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://www.w3.org/2000/01/rdf-schema#label> }',
                 DB.DBA.VVEC_LABEL_GRAPH (), _iri));
  DB.DBA.VVEC_LABEL_SYNC ();
  return '';
}
;

-- Put the common naming properties in on first install, and register the rule
-- set.  Only seeds an empty graph, so an operator who has pruned the list does
-- not get their edits handed back on the next upgrade.
create procedure DB.DBA.VVEC_LABEL_SEED ()
{
  declare exit handler for sqlstate '*' { return 0; };
  if (length (DB.DBA.VVEC_LABEL_PROPS ()) = 0)
    {
      TTLP ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
<http://schema.org/name>                     rdfs:subPropertyOf rdfs:label .
<http://www.w3.org/2004/02/skos/core#prefLabel> rdfs:subPropertyOf rdfs:label .
<http://xmlns.com/foaf/0.1/name>             rdfs:subPropertyOf rdfs:label .
<http://purl.org/dc/terms/title>             rdfs:subPropertyOf rdfs:label .
<http://purl.org/dc/elements/1.1/title>      rdfs:subPropertyOf rdfs:label .
<http://www.w3.org/2004/02/skos/core#altLabel> rdfs:subPropertyOf rdfs:label .
', '', DB.DBA.VVEC_LABEL_GRAPH ());
    }
  DB.DBA.VVEC_LABEL_SYNC ();
  return 1;
}
;

-- Labels for a whole result page in one query.  One round trip rather than one
-- per row: the query is driven from a VALUES list, so each subject is an index
-- lookup and the cost is the number of hits, not the size of the store.
-- A subject with several labels keeps the first the engine returns; the console
-- is naming a row, not enumerating its names.
--
-- Returns a keyword vector for get_keyword, not a dict.  A dict does not
-- survive being returned from a procedure here -- dict_size reports 0 on the
-- returned value and a lookup misses even against the dict''s own key box --
-- and a result page is tens of rows, where the scan costs nothing.
create procedure DB.DBA.VVEC_LABELS (in _keys any)
{
  declare _out, _vals, _meta, _rows any;
  declare _st, _msg, _q, _k varchar;
  declare i, n integer;
  _out := vector ();
  if (not isvector (_keys))
    return _out;
  n := length (_keys);
  _vals := '';
  i := 0;
  while (i < n)
    {
      _k := cast (_keys[i] as varchar);
      if (DB.DBA.VVEC_IRI_OK (_k) = 1)
        _vals := _vals || ' <' || _k || '>';
      i := i + 1;
    }
  if (length (_vals) = 0)
    return _out;
  _q := sprintf ('sparql define input:inference <%s> select ?s ?l where { values ?s {%s } graph ?g { ?s <http://www.w3.org/2000/01/rdf-schema#label> ?l } }',
                 DB.DBA.VVEC_LABEL_RULE (), _vals);
  {
    -- A malformed rule set or a store that cannot answer must cost the results
    -- page nothing: no labels is a fallback, not a failure.
    declare exit handler for sqlstate '*' { return _out; };
    _st := '00000';
    exec (_q, _st, _msg, vector (), 0, _meta, _rows);
  }
  if (not isvector (_rows))
    return _out;
  i := 0;
  while (i < length (_rows))
    {
      declare _r any;
      declare _s, _l varchar;
      _r := _rows[i];
      if (isvector (_r) and length (_r) > 1)
        {
          _s := cast (_r[0] as varchar);
          _l := cast (_r[1] as varchar);
          if (length (_l) > 0 and get_keyword (_s, _out, null) is null)
            _out := vector_concat (_out, vector (_s, _l));
        }
      i := i + 1;
    }
  return _out;
}
;

-- ---------------------------------------------------------------------------
-- 7e. Signed-in user and sign-out.
-- ---------------------------------------------------------------------------

-- The authenticated account.  VVEC_AUTH puts it here once it has validated the
-- session cookie; the fallback only matters if the page is somehow reached with
-- no auth context.
create procedure DB.DBA.VVEC_USER ()
{
  declare _u any;
  _u := connection_get ('SPARQLUserId');
  if (isstring (_u) and length (_u) > 0)
    return _u;
  return 'dba';
}
;

-- Up to two leading characters of the account name, for the sidebar avatar.
create procedure DB.DBA.VVEC_USER_INITIALS (in _u varchar)
{
  declare s varchar;
  s := upper (trim (coalesce (_u, '')));
  if (length (s) = 0)
    return '?';
  if (length (s) = 1)
    return s;
  return subseq (s, 0, 2);
}
;

-- Sign out: end the session, then expire the cookie.
--
-- Under the digest authentication this replaces, there was no session to end
-- and sign-out could only issue a fresh 401 and hope the browser dropped what
-- it had cached.  Now the row goes away and every later request carrying that
-- id simply finds nothing.
create procedure DB.DBA.VVEC_LOGOUT (inout _lines any)
{
  declare _sid varchar;
  _sid := DB.DBA.VVEC_REQUEST_SID (_lines);
  if (_sid is not null)
    DB.DBA.VVEC_SESSION_END (_sid);
  DB.DBA.VVEC_SET_COOKIE ('', 1);
  return 1;
}
;

-- ---------------------------------------------------------------------------
-- 7f. Named-graph lookup (the "Search graphs" picker on the Graph IRI field).
--
--     DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS walks the G index only -- a skip-scan
--     over distinct graph ids -- and adds the explicitly created (still empty)
--     graphs, so its cost tracks the number of GRAPHS, not the number of
--     quads.  It is also exactly what the SPARQL compiler rewrites
--       select distinct ?g where { graph ?g { ?s ?p ?o } }
--     into, so calling it directly costs one SPARQL compilation less per
--     keystroke.  Putting a FILTER inside that group defeats the rewrite and
--     turns the plan back into a full RDF_QUAD scan with a DISTINCT on top, so
--     the substring match is applied out here rather than in SPARQL.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_GRAPHS_JSON (in _q varchar, in _lim integer)
{
  declare _st, _msg, _g, _needle, _out, dq varchar;
  declare _meta, _rows, _row any;
  declare i, n, matched, shown integer;

  dq := chr (34);
  if (_lim is null or _lim <= 0 or _lim > 500)
    _lim := 200;
  _needle := lower (trim (coalesce (_q, '')));

  declare exit handler for sqlstate '*'
    { return '{' || dq || 'error' || dq || ':' || dq ||
             DB.DBA.VVEC_JSON_ESC (__SQL_STATE || ': ' || __SQL_MESSAGE) || dq || '}'; };

  -- The enumeration is bounded so a store with a pathological number of graphs
  -- cannot hang the picker; the response says how many were looked at.
  _st := '00000';
  exec ('DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS (1, 20000)', _st, _msg, vector (), 20000, _meta, _rows);
  if (_st <> '00000')
    return '{' || dq || 'error' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_msg) || dq || '}';
  if (not isvector (_rows))
    _rows := vector ();

  matched := 0; shown := 0;
  _out := '{' || dq || 'graphs' || dq || ':[';
  n := length (_rows);
  for (i := 0; i < n; i := i + 1)
    {
      _row := _rows[i];
      if (not isvector (_row) or length (_row) = 0)
        goto nxt;
      _g := cast (_row[0] as varchar);
      if (_g is null or length (_g) = 0)
        goto nxt;
      if (_needle <> '' and strstr (lower (_g), _needle) is null)
        goto nxt;
      matched := matched + 1;
      if (shown < _lim)
        {
          if (shown > 0)
            _out := _out || ',';
          _out := _out || dq || DB.DBA.VVEC_JSON_ESC (_g) || dq;
          shown := shown + 1;
        }
     nxt:;
    }
  _out := _out || '],' || dq || 'shown'   || dq || ':' || cast (shown as varchar);
  _out := _out || ','  || dq || 'matched' || dq || ':' || cast (matched as varchar);
  _out := _out || ','  || dq || 'scanned' || dq || ':' || cast (n as varchar) || '}';
  return _out;
}
;

-- The named-graph picker.  Unlike the prefix picker its list is not embedded in
-- the page: the number of graphs is unbounded, so the modal fetches from
-- graphs.vsp when it opens and again (debounced) as the search is typed, and
-- the search runs server-side over the whole enumeration rather than over a
-- truncated client-side copy.  Emitted once per page, outside any <form>.
-- Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_GRAPH_PICKER ()
{
  http ('<div id="g-modal" class="modal-back hidden" onclick="vdGraphBackdrop(event)">');
  http ('<div class="modal">');
  http ('<div class="modal-head"><div><h3>Named graphs</h3>');
  http ('<div class="sub">Graphs that hold data on this instance, plus any created empty. Click one to put its IRI in the field.</div></div>');
  http ('<button type="button" class="modal-close" onclick="vdGraphClose()" title="Close">&#215;</button></div>');
  http ('<div class="modal-tools"><input id="g-filter" type="text" placeholder="Search graph IRIs&hellip;" autocomplete="off" oninput="vdGraphSearch()"></div>');
  http ('<div class="modal-body"><div class="ns-list" id="g-list"></div></div>');
  http ('<div class="modal-foot"><span class="note" id="g-note">&nbsp;</span>');
  http ('<button type="button" class="btn sm" onclick="vdGraphClose()">Close</button></div>');
  http ('</div></div>');

  http ('<script>
(function(){
  var tgt = null, timer = null;
  function el(id){ return document.getElementById(id); }
  function render(d){
    var list = el("g-list"), note = el("g-note"), i;
    list.innerHTML = "";
    if(d.error){ note.textContent = "Lookup failed - " + d.error; return; }
    var gs = d.graphs || [];
    if(!gs.length){
      var e = document.createElement("div");
      e.className = "ns-empty";
      e.textContent = d.scanned ? "No graph matches that search." : "No named graphs on this instance.";
      list.appendChild(e);
    }
    for(i = 0; i < gs.length; i++){
      var b = document.createElement("button");
      b.type = "button";
      b.className = "ns-row";
      b.setAttribute("data-uri", gs[i]);
      var u = document.createElement("span");
      u.className = "uri";
      u.textContent = gs[i];
      b.appendChild(u);
      b.addEventListener("click", function(){ window.vdGraphPick(this); });
      list.appendChild(b);
    }
    if(d.matched > d.shown)
      note.textContent = "Showing " + d.shown + " of " + d.matched + " matching graphs - narrow the search to see the rest.";
    else
      note.textContent = d.matched + (d.matched === 1 ? " graph" : " graphs");
  }
  function load(q){
    var note = el("g-note");
    note.textContent = "Searching...";
    // No Accept header: the console is DAV-hosted and only produces text/html,
    // so "Accept: application/json" would make content negotiation answer 406.
    // The body is JSON regardless and is parsed with r.json().
    fetch("graphs?q=" + encodeURIComponent(q || ""), {credentials:"same-origin"})
      .then(function(r){ return r.json(); })
      .then(render)
      .catch(function(){ note.textContent = "Lookup failed - check the server log."; });
  }
  window.vdGraphOpen = function(inputId){
    tgt = document.getElementById(inputId);
    var m = el("g-modal");
    if(!m) return;
    m.classList.remove("hidden");
    var f = el("g-filter");
    if(f){ f.value = ""; f.focus(); }
    load("");
  };
  window.vdGraphClose = function(){
    var m = el("g-modal");
    if(m) m.classList.add("hidden");
  };
  window.vdGraphBackdrop = function(ev){
    if(ev.target && ev.target.id === "g-modal") window.vdGraphClose();
  };
  window.vdGraphSearch = function(){
    if(timer) clearTimeout(timer);
    timer = setTimeout(function(){ load(el("g-filter").value); }, 300);
  };
  window.vdGraphPick = function(btn){
    var uri = btn.getAttribute("data-uri");
    window.vdGraphClose();
    if(!tgt) return;
    tgt.value = uri;
    tgt.focus();
    try { tgt.setSelectionRange(uri.length, uri.length); } catch(e) {}
  };
  document.addEventListener("keydown", function(ev){
    if(ev.key === "Escape") window.vdGraphClose();
  });
})();
</script>');
}
;

-- ---------------------------------------------------------------------------
-- 7g. Predicate lookup for one graph (the "List predicates" picker on the
--     Predicate IRI field of the shorthand selector).
--
--     Only predicates whose objects are STRING literals are offered, because
--     those are the ones a shorthand vector index can embed: a plain literal,
--     an xsd:string, or a language-tagged one.  isLiteral() alone would also
--     return the numeric and dateTime predicates, which are useless to embed.
--
--     There is no (G, P) index on RDF_QUAD -- the five keys are PSOG, POGS, SP,
--     OP and GS -- so any exact answer has to look at the graph's quads; the
--     plan is a POGS scan restricted to G.  The inner LIMIT bounds that scan so
--     a very large graph cannot hang the picker; on anything under the cap the
--     answer is exact.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_PREDICATES_JSON (in _g varchar, in _lim integer)
{
  declare _st, _msg, _p, _q, _out, _sql, dq varchar;
  declare _meta, _rows, _row, _map any;
  declare i, n, shown integer;

  dq := chr (34);
  if (_lim is null or _lim <= 0 or _lim > 1000)
    _lim := 300;

  declare exit handler for sqlstate '*'
    { return '{' || dq || 'error' || dq || ':' || dq ||
             DB.DBA.VVEC_JSON_ESC (__SQL_STATE || ': ' || __SQL_MESSAGE) || dq || '}'; };

  -- Accept a prefixed name here too, so the picker works straight after the
  -- graph field has been typed as "schema:g".
  _g := DB.DBA.VVEC_EXPAND_QNAME (trim (coalesce (_g, '')));
  if (length (_g) = 0)
    return '{' || dq || 'status' || dq || ':' || dq || 'nograph' || dq || '}';
  if (DB.DBA.VVEC_IRI_OK (_g) = 0)
    return '{' || dq || 'status' || dq || ':' || dq || 'badgraph' || dq || ',' ||
           dq || 'graph' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_g) || dq || '}';

  _sql := sprintf (
    'sparql select distinct ?p where { ' ||
      '{ select ?p ?o where { graph <%s> { ?s ?p ?o } } limit 200000 } ' ||
      'filter (isliteral (?o) && (datatype (?o) = <http://www.w3.org/2001/XMLSchema#string> || lang (?o) != "")) ' ||
    '}', _g);
  _st := '00000';
  exec (_sql, _st, _msg, vector (), _lim, _meta, _rows);
  if (_st <> '00000')
    return '{' || dq || 'error' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_msg) || dq || '}';
  if (not isvector (_rows))
    _rows := vector ();

  -- Each predicate is reported with its prefixed-name form when one exists, so
  -- the picker can lead with "schema:name" and keep the full IRI as a subtitle.
  _map := DB.DBA.VVEC_NS_MAP ();
  shown := 0;
  _out := '{' || dq || 'status' || dq || ':' || dq || 'ok' || dq || ',' ||
          dq || 'graph' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_g) || dq || ',' ||
          dq || 'predicates' || dq || ':[';
  n := length (_rows);
  for (i := 0; i < n; i := i + 1)
    {
      _row := _rows[i];
      if (not isvector (_row) or length (_row) = 0)
        goto nxt;
      _p := cast (_row[0] as varchar);
      if (_p is null or length (_p) = 0)
        goto nxt;
      if (shown > 0)
        _out := _out || ',';
      _q := DB.DBA.VVEC_QNAME_OF (_p, _map);
      _out := _out || '{' || dq || 'iri' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_p) || dq ||
                      ',' || dq || 'qname' || dq || ':' || dq || DB.DBA.VVEC_JSON_ESC (_q) || dq || '}';
      shown := shown + 1;
     nxt:;
    }
  _out := _out || '],' || dq || 'count' || dq || ':' || cast (shown as varchar) || '}';
  return _out;
}
;

-- The predicate picker.  Its list depends on whichever graph is in the Graph
-- IRI field at the moment it opens, so it is fetched from predicates.vsp per
-- open and then filtered client-side -- re-running a graph scan on every
-- keystroke would be far too expensive.  Emitted once per page, outside any
-- <form>.  Double-quoted JavaScript strings only, so this embeds cleanly in the
-- single-quoted SQL literal.
create procedure DB.DBA.VVEC_PREDICATE_PICKER ()
{
  http ('<div id="pr-modal" class="modal-back hidden" onclick="vdPredBackdrop(event)">');
  http ('<div class="modal">');
  http ('<div class="modal-head"><div><h3>Predicates with string values</h3>');
  http ('<div class="sub" id="pr-sub">Predicates in the chosen graph whose objects are string literals &mdash; the ones a simple index can embed.</div></div>');
  http ('<button type="button" class="modal-close" onclick="vdPredClose()" title="Close">&#215;</button></div>');
  http ('<div class="modal-tools"><input id="pr-filter" type="text" placeholder="Filter predicates&hellip;" autocomplete="off" oninput="vdPredFilter()"></div>');
  http ('<div class="modal-body"><div class="ns-list" id="pr-list"></div></div>');
  http ('<div class="modal-foot"><span class="note" id="pr-note">&nbsp;</span>');
  http ('<button type="button" class="btn sm" onclick="vdPredClose()">Close</button></div>');
  http ('</div></div>');

  http ('<script>
(function(){
  var tgt = null, all = [];
  function el(id){ return document.getElementById(id); }
  function paint(){
    var list = el("pr-list"), note = el("pr-note"), f = el("pr-filter");
    var q = f ? f.value.toLowerCase() : "", i, shown = 0;
    list.innerHTML = "";
    for(i = 0; i < all.length; i++){
      var iri = all[i].iri, qn = all[i].qname || "";
      // Search matches either spelling, so "schema:name" and the full IRI both find it.
      if(q !== "" && (qn + " " + iri).toLowerCase().indexOf(q) < 0) continue;
      var b = document.createElement("button");
      b.type = "button";
      b.className = "ns-row stack";
      b.setAttribute("data-uri", iri);
      var head = document.createElement("span");
      head.className = "qname";
      head.textContent = qn || iri;
      b.appendChild(head);
      // Only a second line when the head is the short form; otherwise it would
      // just repeat the IRI.
      if(qn){
        var sub = document.createElement("span");
        sub.className = "full";
        sub.textContent = iri;
        b.appendChild(sub);
      }
      b.addEventListener("click", function(){ window.vdPredPick(this); });
      list.appendChild(b);
      shown++;
    }
    if(!shown){
      var e = document.createElement("div");
      e.className = "ns-empty";
      e.textContent = all.length ? "No predicate matches that filter."
                                 : "No predicate in this graph has string values.";
      list.appendChild(e);
    }
    note.textContent = shown + (shown === 1 ? " predicate" : " predicates");
  }
  function fail(msg){
    all = [];
    el("pr-list").innerHTML = "";
    var e = document.createElement("div");
    e.className = "ns-empty";
    e.textContent = msg;
    el("pr-list").appendChild(e);
    el("pr-note").textContent = "";
  }
  function load(g){
    el("pr-note").textContent = "Reading the graph...";
    el("pr-list").innerHTML = "";
    // No Accept header: the console is DAV-hosted and only produces text/html,
    // so "Accept: application/json" would make content negotiation answer 406.
    fetch("predicates?g=" + encodeURIComponent(g), {credentials:"same-origin"})
      .then(function(r){ return r.json(); })
      .then(function(d){
        if(d.error){ fail("Lookup failed - " + d.error); return; }
        if(d.status === "nograph"){ fail("Enter or pick a Graph IRI first."); return; }
        if(d.status === "badgraph"){ fail("That Graph IRI is not usable."); return; }
        all = d.predicates || [];
        el("pr-sub").textContent = "Predicates in <" + d.graph + "> whose objects are string literals.";
        paint();
      })
      .catch(function(){ fail("Lookup failed - check the server log."); });
  }
  window.vdPredOpen = function(inputId, graphInputId){
    tgt = document.getElementById(inputId);
    var gi = document.getElementById(graphInputId);
    var m = el("pr-modal");
    if(!m) return;
    m.classList.remove("hidden");
    var f = el("pr-filter");
    if(f){ f.value = ""; f.focus(); }
    load(gi ? gi.value.trim() : "");
  };
  window.vdPredClose = function(){
    var m = el("pr-modal");
    if(m) m.classList.add("hidden");
  };
  window.vdPredBackdrop = function(ev){
    if(ev.target && ev.target.id === "pr-modal") window.vdPredClose();
  };
  window.vdPredFilter = function(){ if(all.length) paint(); };
  window.vdPredPick = function(btn){
    var uri = btn.getAttribute("data-uri");
    window.vdPredClose();
    if(!tgt) return;
    tgt.value = uri;
    tgt.focus();
    try { tgt.setSelectionRange(uri.length, uri.length); } catch(e) {}
  };
  document.addEventListener("keydown", function(ev){
    if(ev.key === "Escape") window.vdPredClose();
  });
})();
</script>');
}
;

-- ---------------------------------------------------------------------------
-- 7h. Similarity search across one or more indexes.
--     The search page lets several indexes of the SAME surface be queried at
--     once and shows one merged ranking, so the per-index query lives here and
--     the page just merges what comes back.
-- ---------------------------------------------------------------------------

-- Split a separator-joined list into its non-empty, trimmed parts.  The search
-- page joins index ids with '|', which VVEC_IRI_OK rejects inside an IRI, so
-- no valid index id can contain the separator.
create procedure DB.DBA.VVEC_SPLIT (in s varchar, in sep integer)
{
  declare res any;
  declare i, n, start, c integer;
  declare tok varchar;
  res := vector ();
  if (s is null)
    return res;
  n := length (s);
  start := 0;
  i := 0;
  while (i <= n)
    {
      if (i = n)
        c := sep;                      -- treat the end of the string as a separator
      else
        c := aref (s, i);
      if (c = sep)
        {
          tok := trim (subseq (s, start, i));
          if (length (tok) > 0)
            res := vector_concat (res, vector (tok));
          start := i + 1;
        }
      i := i + 1;
    }
  return res;
}
;

-- Exact membership in a separator-joined list.  A LIKE test would be wrong
-- twice over here: "sql:A" is a substring of "sql:AB", and an index IRI may
-- legitimately contain '%' or '_', which LIKE would read as wildcards.
create procedure DB.DBA.VVEC_IN_LIST (in _list varchar, in _val varchar, in sep integer)
{
  declare parts any;
  declare i integer;
  parts := DB.DBA.VVEC_SPLIT (_list, sep);
  for (i := 0; i < length (parts); i := i + 1)
    {
      if (parts[i] = _val)
        return 1;
    }
  return 0;
}
;

-- The model and distance metric an index is bound to, as
--   vector (model, metric)
-- or NULL when the index is unknown.  The search page needs this for indexes
-- that return no hits as well, so it cannot come from the hits themselves.
create procedure DB.DBA.VVEC_INDEX_MODEL (in _side varchar, in _id varchar)
{
  declare info any;
  declare _m, _d varchar;
  if (_side = 'sql')
    {
      info := DB.DBA.VVEC_SQL_INDEX_FULL (_id);
      if (info is null)
        return null;
      return vector (cast (info[3] as varchar), cast (info[5] as varchar));
    }
  whenever not found goto nf;
  select SVI_MODEL_NAME, SVI_DISTANCE into _m, _d
    from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _id;
  return vector (coalesce (_m, ''), DB.DBA.VVEC_METRIC_VALUE (_d));
nf:
  return null;
}
;

-- Run the query against ONE index and return its hits as
--   vector (vector (index_id, key, text, score, distance, rank, model), ...)
-- already ordered best-first.  The rank is the hit's position within THIS
-- index's own result list, which is what makes a cross-model merge orderable:
-- raw scores from different models sit on different baselines, ranks do not.
-- On failure the hits are empty and _err carries the reason, so the caller can
-- report a broken index without losing the results from the others.
create procedure DB.DBA.VVEC_SEARCH_ONE (
  in _side varchar, in _id varchar, in _q varchar, in _k integer, inout _err varchar)
{
  declare _res, _rows, _meta, _row any;
  declare _stat, _emsg, _sqltext varchar;
  declare i, _ef integer;

  _res := vector ();
  _err := '';
  if (_k <= 0)
    _k := 10;
  _ef := case when _k > 100 then _k else 100 end;

  declare exit handler for sqlstate '*'
    { _err := __SQL_STATE || ': ' || __SQL_MESSAGE; return vector (); };

  if (_side = 'sql')
    {
      declare info any;
      declare _tbl, _sc, _pk, _model, _mesc varchar;
      if (DB.DBA.VVEC_IDENT_OK (_id) = 0)
        { _err := 'Not a valid SQL index name'; return vector (); }
      info := DB.DBA.VVEC_SQL_INDEX_INFO (_id);
      if (info is null)
        { _err := 'Unknown SQL vector index'; return vector (); }
      _tbl := info[0]; _sc := info[1]; _pk := info[2]; _model := info[3];
      -- X_SIMILAR / VECTOR_DISTANCE embed a text *literal* but not a bound
      -- parameter, so the query text is bound to ONNX_EMBED_TEXT_FOR_MODEL (an
      -- ordinary function) and the resulting vector is what they compare
      -- against.  The model name comes from the catalog; quote-escaped anyway.
      _mesc := replace (_model, chr (39), chr (39) || chr (39));
      _sqltext := sprintf (
        'SELECT TOP %d "%I" AS pk, "%I" AS content, X_SIMILAR ("%I", qv.v) AS score, VECTOR_DISTANCE ("%I", qv.v) AS distance FROM "%I"."%I"."%I" CROSS JOIN (SELECT DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL (''%s'', ?) AS v) qv ORDER BY VECTOR_DISTANCE ("%I", qv.v)',
        _k, _pk, _sc, _sc, _sc, name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2), _mesc, _sc);
      _stat := '00000';
      exec (_sqltext, _stat, _emsg, vector (_q), _k, _meta, _rows);
      if (_stat <> '00000')
        { _err := _stat || ': ' || _emsg; return vector (); }
      if (not isvector (_rows))
        return _res;
      for (i := 0; i < length (_rows); i := i + 1)
        {
          _row := _rows[i];
          _res := vector_concat (_res, vector (vector (
            _id,
            cast (coalesce (_row[0], '') as varchar),
            cast (coalesce (_row[1], '') as varchar),
            cast (coalesce (_row[2], 0) as double precision),
            cast (coalesce (_row[3], 0) as double precision),
            i + 1,
            _model)));
        }
      return _res;
    }

  -- SPARQL surface
  {
    declare _svi_state, _svi_err, _seltype, _sgraph, _spred varchar;
    declare _kv, _ev, _wtext, _wbody, _wpre, _svi_model varchar;
    if (DB.DBA.VVEC_IRI_OK (_id) = 0)
      { _err := 'Not a valid index IRI'; return vector (); }
    if (not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _id))
      { _err := 'Unknown SPARQL vector index'; return vector (); }
    select SVI_STATE, SVI_SELECTOR_TYPE, SVI_SELECTOR_GRAPH, SVI_SELECTOR_PRED,
           SVI_KEY_VAR, SVI_EMBEDDING_VAR, cast (SVI_WHERE_TEXT as varchar),
           cast (SVI_WHERE_PATTERN as varchar), SVI_MODEL_NAME
      into _svi_state, _seltype, _sgraph, _spred, _kv, _ev, _wtext, _wpre, _svi_model
      from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _id;
    if (_svi_state <> 'active')
      {
        _svi_err := (select SVI_LAST_ERROR from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = _id);
        _err := sprintf ('in ''%s'' state and cannot be searched.%s', _svi_state,
                         case when _svi_err is not null then '  Last error: ' || _svi_err else '' end);
        return vector ();
      }
    -- Everything below is read back out of the catalog and interpolated into a
    -- statement that runs as dba. The Create and Edit pages already gate these
    -- on the way in, but an index can also be created from isql or its
    -- catalogue row edited by hand, so the read path re-checks rather than
    -- trusting what it finds. Every index created through the console passes by
    -- construction.
    if (_seltype = 'shorthand')
      {
        if (DB.DBA.VVEC_IRI_OK (_sgraph) = 0 or DB.DBA.VVEC_IRI_OK (_spred) = 0)
          { _err := 'its stored graph or predicate IRI is not in a form VVec can re-emit'; return vector (); }
        _sqltext := sprintf (
          'sparql define input:storage "" select ?doc ?score ?distance (str(?text) as ?txt) where { ?doc bif:vector_search "%s" option (index <%s>, score ?score, distance ?distance, limit %d, ef_search %d) . graph <%s> { ?doc <%s> ?text } } order by desc(?score)',
          DB.DBA.VVEC_SPARQL_STR (_q), _id, _k, _ef, _sgraph, _spred);
      }
    else
      {
        if (DB.DBA.VVEC_IDENT_OK (_kv) = 0 or DB.DBA.VVEC_IDENT_OK (_ev) = 0)
          { _err := 'its stored key or embedding variable name is not a plain SPARQL variable'; return vector (); }
        _wbody := subseq (_wtext, strchr (_wtext, '{'));   -- "{ ... }" body of the stored WHERE
        if (DB.DBA.VVEC_SPARQL_PATTERN_OK (_wbody) = 0)
          { _err := 'its stored WHERE pattern is not in a form VVec can re-emit'; return vector (); }
        -- A general selector written with local PREFIX declarations stored them
        -- in SVI_WHERE_PATTERN; the stored WHERE body still spells its qnames
        -- with them, so they have to come back into scope or the query fails
        -- with "Undefined namespace prefix".  The preamble comes from the
        -- parser, but it lands in a statement run as dba, so it passes the same
        -- structural gate the Create page applies to a WHERE pattern.
        _wpre := trim (coalesce (_wpre, ''));
        if (DB.DBA.VVEC_PREFIX_PREAMBLE_OK (_wpre) = 0)
          { _err := 'its stored PREFIX preamble is not in a form VVec can re-declare'; return vector (); }
        if (_wpre <> '')
          _wpre := _wpre || ' ';
        -- Key/embedding names are SPARQL variables (word chars, parser-enforced
        -- at create time); emitted after '?' with %s, since identifier quoting
        -- is invalid there.
        _sqltext := sprintf (
          'sparql define input:storage "" %sselect (?%s as ?doc) ?score ?distance (str(?%s) as ?txt) where { ?%s bif:vector_search "%s" option (index <%s>, score ?score, distance ?distance, limit %d, ef_search %d) . %s } order by desc(?score)',
          _wpre, _kv, _ev, _kv, DB.DBA.VVEC_SPARQL_STR (_q), _id, _k, _ef, _wbody);
      }
    _stat := '00000';
    exec (_sqltext, _stat, _emsg, vector (), _k, _meta, _rows);
    if (_stat <> '00000')
      { _err := _stat || ': ' || _emsg; return vector (); }
    if (not isvector (_rows))
      return _res;
    for (i := 0; i < length (_rows); i := i + 1)
      {
        _row := _rows[i];
        _res := vector_concat (_res, vector (vector (
          _id,
          cast (coalesce (_row[0], '') as varchar),
          cast (coalesce (_row[3], '') as varchar),
          cast (coalesce (_row[1], 0) as double precision),
          cast (coalesce (_row[2], 0) as double precision),
          i + 1,
          coalesce (_svi_model, ''))));
      }
    return _res;
  }
}
;

-- The _k best hits across a merged result set, under one of two orderings.
--
--   'score' -- highest raw score first.  Right when every index in the merge
--              shares a model and metric, because then the scores are the same
--              measurement.
--   'rank'  -- each hit's position within its OWN index first, ties broken by
--              score.  This is reciprocal-rank fusion in its simplest form
--              (every hit belongs to exactly one list, so 1/(k+rank) is
--              monotonic in rank): it is what makes a merge across DIFFERENT
--              models meaningful.  Raw cosine is not calibrated between models
--              -- on this data MiniLM scores a nonsense query at 0.46-0.54 and
--              a good match at 0.82, and a model whose baseline sits higher
--              would win on score while matching worse.  Rank is immune to that.
--
-- A partial selection sort: _k passes over n, where n is bounded by
-- (indexes selected * _k), rather than a full sort of the same data.
create procedure DB.DBA.VVEC_TOP_HITS (in _hits any, in _k integer, in _mode varchar)
{
  declare n, i, j, bestn, byrank integer;
  declare _tmp, _a, _b, _res any;
  if (not isvector (_hits))
    return vector ();
  n := length (_hits);
  if (n = 0 or _k <= 0)
    return vector ();
  if (_k > n)
    _k := n;
  byrank := case when _mode = 'rank' then 1 else 0 end;
  _tmp := vector_concat (vector (), _hits);    -- a copy: aset below mutates it
  _res := vector ();
  for (i := 0; i < _k; i := i + 1)
    {
      bestn := i;
      for (j := i + 1; j < n; j := j + 1)
        {
          _a := _tmp[j];
          _b := _tmp[bestn];
          if (byrank)
            {
              if (cast (_a[5] as integer) < cast (_b[5] as integer)
                  or (cast (_a[5] as integer) = cast (_b[5] as integer)
                      and cast (_a[3] as double precision) > cast (_b[3] as double precision)))
                bestn := j;
            }
          else if (cast (_a[3] as double precision) > cast (_b[3] as double precision))
            bestn := j;
        }
      if (bestn <> i)
        {
          _a := _tmp[i];
          aset (_tmp, i, _tmp[bestn]);
          aset (_tmp, bestn, _a);
        }
      _res := vector_concat (_res, vector (_tmp[i]));
    }
  return _res;
}
;

-- ---------------------------------------------------------------------------
-- 7i. API-key registry helpers (the Manage API Keys page).
--
--     Provider keys are not a table: they live in the SQL registry, and a model
--     points at one by name through ONNX_MODELS.provider_api_key_name.  The
--     list is therefore the union of the names models actually reference and
--     any registry entry following the ONNX_API_KEY_ convention, so a key that
--     nothing uses yet is still manageable and a model pointing at a missing
--     key is still visible.  Nothing about a key's value is read or measured:
--     set-ness comes from whether the name appears in the registry listing at
--     all, so no per-key registry_get and no length of a secret.
-- ---------------------------------------------------------------------------
create procedure DB.DBA.VVEC_API_KEYS ()
{
  declare seen, present, names, res, all_kv any;
  declare i, j, n, bestn integer;
  declare nm, mdls, swp varchar;

  seen := dict_new (16);
  present := dict_new (16);
  for (select distinct provider_api_key_name as k from DB.DBA.ONNX_MODELS
        where provider_api_key_name is not null and length (provider_api_key_name) > 0) do
    dict_put (seen, cast (k as varchar), 1);

  -- One pass over the registry listing: the names it contains are the ones that
  -- have a value. The values themselves are stepped over, never inspected.
  all_kv := registry_get_all ();          -- flat [name, value, name, value, ...]
  n := length (all_kv);
  i := 0;
  while (i + 1 < n)
    {
      nm := cast (all_kv[i] as varchar);
      dict_put (present, nm, 1);
      if (nm like 'ONNX[_]API[_]KEY[_]%')
        dict_put (seen, nm, 1);
      i := i + 2;
    }

  names := dict_list_keys (seen, 0);
  n := length (names);
  -- selection sort so the page is stable between loads
  for (i := 0; i < n; i := i + 1)
    {
      bestn := i;
      for (j := i + 1; j < n; j := j + 1)
        {
          if (cast (names[j] as varchar) < cast (names[bestn] as varchar))
            bestn := j;
        }
      if (bestn <> i)
        { swp := cast (names[i] as varchar); aset (names, i, names[bestn]); aset (names, bestn, swp); }
    }

  res := vector ();
  for (i := 0; i < n; i := i + 1)
    {
      nm := cast (names[i] as varchar);
      mdls := '';
      for (select model_name as mnx from DB.DBA.ONNX_MODELS
            where provider_api_key_name = nm order by model_name) do
        {
          if (mdls <> '') mdls := mdls || ', ';
          mdls := mdls || mnx;
        }
      res := vector_concat (res, vector (vector (
        nm,
        case when dict_get (present, nm, 0) = 1 then 1 else 0 end,
        mdls)));
    }
  return res;
}
;

-- ---------------------------------------------------------------------------
-- 8. Post-install wiring (run when the VAD loads this file via
--    VAD_LOAD_SQL_FILE).  By this point the VAD engine has already uploaded the
--    .vsp pages and the stylesheet into DAV under the collection named by the
--    _vvec_path_ registry key (default /DAV/VAD/vvec/).  So there is no
--    filesystem read (no DirsAllowed needed) and no DAV password: we only
--    rebuild the inline-CSS emitter from the uploaded stylesheet and map the
--    /vvec/ virtual directory.  Idempotent -- safe to re-run on upgrade.
-- ---------------------------------------------------------------------------

-- Absolute DAV path of the installed collection (set by the VAD sticker).
create procedure DB.DBA.VVEC_DAV_PATH ()
{
  -- registry_get returns integer 0 (not null) when unset, so test for a string.
  declare _p any;
  _p := registry_get ('_vvec_path_');
  if (isstring (_p) and length (_p) > 0)
    return _p;
  return '/DAV/VAD/vvec/';
}
;

-- Post-install: (a) rebuild the inline-CSS emitter from the uploaded stylesheet
-- so the pages carry their own <style> block, and (b) map the /vvec/ virtual
-- directory (VSP executes as dba behind the DBA-only digest-auth guard).  No
-- filesystem read and no DAV password.  Idempotent -- safe to re-run on upgrade.
create procedure DB.DBA.VVEC_VAD_POSTINSTALL () returns integer
{
  declare _css any;
  declare _stat, _msg varchar;
  -- (a) inline CSS from the uploaded stylesheet; if unreadable the built-in
  --     default emitter remains.
  {
    declare exit handler for sqlstate '*' { ; };
    _css := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES
               where RES_FULL_PATH = DB.DBA.VVEC_DAV_PATH () || 'statics/vvec.css');
    if (_css is not null and length (_css) > 0)
      {
        _stat := '00000';
        exec ('create procedure DB.DBA.VVEC_CSS () { http (' || chr (39) ||
              replace (_css, chr (39), chr (39) || chr (39)) || chr (39) || '); }',
              _stat, _msg);
      }
  }
  -- (a2) retire the old name.  An instance that had the console under /vecdash
  --      still has that mapping and its rewrite rules pointing at a DAV
  --      collection this package no longer writes, so both would 404 while
  --      looking installed.  Dropping them here rather than leaving it to a
  --      manual uninstall means the rename is complete after one vad_install.
  {
    declare exit handler for sqlstate '*' { ; };
    DB.DBA.VHOST_REMOVE (lpath => '/vecdash/');
  }
  {
    declare exit handler for sqlstate '*' { ; };
    delete from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = 'vecdash_rule_list';
    delete from DB.DBA.URL_REWRITE_RULE where URR_RULE like 'vecdash_rule_%';
  }

  -- (a3) retire the stateless-HMAC CSRF helpers.  They existed only because
  --      HTTP Digest left nowhere to keep a per-session secret; the token is
  --      now a column on the session row (section 7c).  An instance upgraded
  --      from an older package still carries them, and the registry secret
  --      they were keyed with, so clear both rather than leave dead code that
  --      reads as live.
  {
    declare exit handler for sqlstate '*' { ; };
    declare _n varchar;
    declare _stat, _msg varchar;
    for select P_NAME from DB.DBA.SYS_PROCEDURES
         where P_NAME in ('DB.DBA.VVEC_CSRF_SECRET', 'DB.DBA.VVEC_CSRF_WINDOW',
                          'DB.DBA.VVEC_CSRF_MAC', 'DB.DBA.VVEC_CSRF_VALID') do
      {
        _stat := '00000'; _msg := '';
        exec ('drop procedure ' || P_NAME, _stat, _msg);
      }
    registry_remove ('VVEC_CSRF_SECRET');
  }

  -- (b) the label rule set, so Entity-label mode has something to resolve
  --     against on a fresh install.  Seeding is skipped when the graph already
  --     has properties in it, so an upgrade never hands back an edit.
  {
    declare exit handler for sqlstate '*' { ; };
    DB.DBA.VVEC_LABEL_SEED ();
  }

  -- (c) the clean URLs.  A page is a page, not a file: /vvec/indexes rather
  --     than /vvec/indexes.vsp.  The implementation is nobody else''s
  --     business, and a URL that names it cannot be changed later without
  --     breaking every link anyone has kept.
  --
  --     Two rules rather than one because the query string has to survive:
  --     the first takes /vvec/<page>?<anything> and the second the bare
  --     /vvec/<page>.  [^/?.] excludes the dot, so /vvec/index.vsp still
  --     resolves directly and is not rewritten into index.vsp.vsp -- the old
  --     URLs keep working, they are just no longer the ones the console emits.
  --     /vvec itself is answered by the server with a 301 to /vvec/, so
  --     the relative links the pages emit always resolve inside the console.
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('vvec_rule_qs', 1,
      '/vvec/([^/?.]+)\\?(.*)', vector ('page', 'qs'), 2,
      '/vvec/%s.vsp?%s', vector ('page', 'qs'), null, null, 2);
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('vvec_rule_page', 1,
      '/vvec/([^/?.]+)', vector ('page'), 1,
      '/vvec/%s.vsp', vector ('page'), null, null, 2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('vvec_rule_list', 1,
      vector ('vvec_rule_qs', 'vvec_rule_page'));

  -- (d) map the console; drop any prior mapping first.
  {
    declare exit handler for sqlstate '*' { ; };
    DB.DBA.VHOST_REMOVE (lpath => '/vvec/');
  }
  -- No `sec`: the guard is not the built-in digest handshake any more, it is
  -- VVEC_AUTH validating a session cookie (section 7b).  `realm` is only the
  -- string handed to that procedure.
  DB.DBA.VHOST_DEFINE (lpath    => '/vvec/',
                       ppath    => DB.DBA.VVEC_DAV_PATH (),
                       is_dav   => 1,
                       vsp_user => 'dba',
                       def_page => 'index.vsp',
                       auth_fn  => 'DB.DBA.VVEC_AUTH',
                       realm    => 'VVec',
                       opts     => vector ('executable', 'yes',
                                           'url_rewrite', 'vvec_rule_list'));

  -- (e) sweep dead sessions.  Expiry is enforced on every request by the
  --     lookup itself, so this only stops rows piling up for browsers that
  --     never came back.  Hourly is ample for that.
  {
    declare exit handler for sqlstate '*' { ; };
    delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'VVEC_SESSION_GC';
    insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
      values ('VVEC_SESSION_GC', now (), 'DB.DBA.VVEC_SESSION_GC ()', 60);
  }

  return 1;
}
;

select DB.DBA.VVEC_VAD_POSTINSTALL ();
