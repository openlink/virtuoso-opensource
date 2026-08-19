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
--  openGQL: CREATE VIRTUAL/PHYSICAL PROPERTY GRAPH — DDL execution
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  This module implements the execution path for CREATE VIRTUAL PROPERTY
--  GRAPH (quad-map generation over relational tables) and CREATE PHYSICAL
--  PROPERTY GRAPH (empty named graph for GQL INSERT).  It also provides
--  R2RML export (via the rdb2rdf VAD), materialization, and metadata
--  inspection.
--

----------------------------------------------------------------------
-- Internal: build an IRI template string from a table name and key
-- columns.  If the user supplied an explicit IRI template in the DDL,
-- it is used directly.  Otherwise the template is derived from the
-- data namespace + first key column:
--   http://host/pgraph/pg#table-{col}
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_IRI_TEMPLATE (
  in _data_ns varchar,
  in _tbl_name varchar,
  in _key_cols any)
{
  declare tmpl varchar;
  declare short_name varchar;
  declare dot_pos integer;

  -- Use the unqualified table name for the IRI slug
  short_name := _tbl_name;
  dot_pos := strrchr (_tbl_name, '.');
  if (dot_pos is not null)
    short_name := subseq (_tbl_name, dot_pos + 1);

  if (_key_cols is not null and length (_key_cols) > 0)
    return concat (_data_ns, short_name, '-{', aref (_key_cols, 0), '}');
  -- No key columns: use rowid
  return concat (_data_ns, short_name, '-{__rowid}');
}
;

----------------------------------------------------------------------
-- Internal: get PK columns for a table, falling back to the user-
-- supplied key_cols.  Returns a vector of column name strings.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_GET_PK_COLS (in _tbl_name varchar, in _user_key_cols any)
{
  if (_user_key_cols is not null and length (_user_key_cols) > 0)
    return _user_key_cols;

  -- Introspect via REPL_PK_COLS (same as RDF Views).  It returns a
  -- vector of column descriptors ([ col_name, dtp, default, prec ]) —
  -- project out just the column names so callers get a flat vector of
  -- name strings, matching the user-supplied-key-cols shape.
  declare pk, names any;
  declare i integer;
  pk := DB.DBA.REPL_PK_COLS (_tbl_name);
  if (pk is not null and isarray (pk) and length (pk) > 0)
    {
      names := vector ();
      for (i := 0; i < length (pk); i := i + 1)
        {
          -- isarray() is true for strings too in Virtuoso, so test the
          -- string case first: a descriptor is a [name, dtp, ...] vector.
          if (isstring (aref (pk, i)))
            names := vector_concat (names, vector (aref (pk, i)));
          else
            names := vector_concat (names, vector (aref (aref (pk, i), 0)));
        }
      return names;
    }

  -- No PK found; return a single-element vector with a placeholder
  return vector ('__rowid');
}
;

----------------------------------------------------------------------
-- Internal: get all non-PK columns for a table (candidate properties).
-- Returns a vector of column-name strings.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_GET_ALL_COLS (in _tbl_name varchar)
{
  declare cols any;
  cols := vector ();
  for (select "COLUMN" from TABLE_COLS where "TABLE" = _tbl_name and "COLUMN" <> '_IDN' order by COL_ID) do
    cols := vector_concat (cols, vector ("COLUMN"));
  return cols;
}
;

----------------------------------------------------------------------
-- Internal: normalise a table name to its fully-qualified form
-- (e.g. "products" -> "DB.DBA.products"), matching how names are
-- stored in TABLE_COLS."TABLE".  DDL accepts bare or qualified names;
-- everything downstream (validation, quad-map FROM, aliases, IRI
-- templates, SOURCE/DESTINATION matching, stored metadata) uses the
-- qualified form so the pieces line up.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_QUALIFY_TABLE (in _tbl_name varchar)
{
  declare _q varchar;
  _q := complete_table_name (_tbl_name, 1);
  if (_q is null or length (_q) = 0)
    _q := _tbl_name;
  -- complete_table_name qualifies but preserves the source case; the
  -- catalog stores the name in the server's case mode (unquoted names
  -- fold to upper by default).  Resolve to the canonical stored form so
  -- lookups against TABLE_COLS / SYS_KEYS match.
  for (select KEY_TABLE as _kt from DB.DBA.SYS_KEYS
       where KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null
         and upper (KEY_TABLE) = upper (_q)) do
    {
      return _kt;
    }
  return _q;
}
;

----------------------------------------------------------------------
-- Internal: validate that a table exists.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_VALIDATE_TABLE (in _tbl_name varchar)
{
  declare cnt integer;
  cnt := 0;
  select count (*) into cnt from TABLE_COLS where "TABLE" = _tbl_name;
  if (cnt = 0)
    signal ('GQ200', sprintf ('Table %s does not exist or has no columns', _tbl_name));
}
;

----------------------------------------------------------------------
-- Internal: validate that columns exist in a table.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_VALIDATE_COLS (in _tbl_name varchar, in _cols any)
{
  declare i integer;
  declare col_name varchar;
  if (_cols is null) return;
  for (i := 0; i < length (_cols); i := i + 1)
    {
      -- An element is either a plain column-name string or a
      -- [col, prop] pair.  NB: isarray() is true for strings too in
      -- Virtuoso (a string is a byte array), so test isstring() first.
      if (isstring (aref (_cols, i)))
        col_name := aref (_cols, i);
      else
        col_name := aref (aref (_cols, i), 0);
      if (not exists (select 1 from TABLE_COLS where "TABLE" = _tbl_name and upper ("COLUMN") = upper (col_name)))
        signal ('GQ201', sprintf ('Column %s does not exist in table %s', col_name, _tbl_name));
    }
}
;

----------------------------------------------------------------------
-- Internal: fixed prefix declaration for the pgraph IRI-class /
-- quad-map namespace, prepended to every generated SPARQL statement.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_PFX ()
{
  return 'prefix pgraph: <http://www.openlinksw.com/schemas/opengql/pgraph#>\n';
}
;

----------------------------------------------------------------------
-- Internal: turn the literal two-character "\n" sequences used when
-- building SPARQL text into real newlines.  Virtuoso string literals do
-- NOT interpret "\n", and the SPARQL/DDL tokenizer rejects a literal
-- backslash, so every generated statement is passed through this before
-- exec().
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_NL (in _s varchar)
{
  return replace (_s, '\n', chr (10));
}
;

----------------------------------------------------------------------
-- Internal: reduce a string to a safe QName local part
-- ([A-Za-z0-9_] only) so it can name an IRI class or quad map.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_SANITIZE (in _s varchar)
{
  declare _out varchar;
  declare i, c integer;
  _out := '';
  for (i := 0; i < length (_s); i := i + 1)
    {
      c := aref (_s, i);
      if ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c = 95)
        _out := concat (_out, chr (c));
      else
        _out := concat (_out, '_');
    }
  return _out;
}
;

----------------------------------------------------------------------
-- Internal: the unqualified (short) part of a possibly-qualified
-- table name.  "DB.DBA.PRODUCTS" -> "PRODUCTS".
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_SHORT_NAME (in _tbl_name varchar)
{
  declare dot_pos integer;
  dot_pos := strrchr (_tbl_name, '.');
  if (dot_pos is not null)
    return subseq (_tbl_name, dot_pos + 1);
  return _tbl_name;
}
;

----------------------------------------------------------------------
-- Internal: resolve a column name to its canonical stored form for a
-- given (qualified) table, case-insensitively.  Quoted column refs in
-- generated SPARQL must use the exact stored case, which is upper by
-- default on a case-insensitive server.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_RESOLVE_COL (in _tbl_name varchar, in _col varchar)
{
  for (select "COLUMN" as _c from TABLE_COLS
       where "TABLE" = _tbl_name and upper ("COLUMN") = upper (_col)) do
    return _c;
  return _col;
}
;

----------------------------------------------------------------------
-- Internal: build the IRI-class argument list from an alias and a
-- vector of column names, e.g. ("oi_s", ["ORDER_ID"]) ->
-- '(oi_s."ORDER_ID")'.  Column names are resolved to canonical case
-- against _tbl_name.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_KEY_ARGS (in _tbl_name varchar, in _alias varchar, in _cols any)
{
  declare _out varchar;
  declare i integer;
  _out := '(';
  for (i := 0; i < length (_cols); i := i + 1)
    {
      if (i > 0) _out := concat (_out, ', ');
      _out := concat (_out, _alias, '."', DB.DBA.GQL_PG_RESOLVE_COL (_tbl_name, aref (_cols, i)), '"');
    }
  return concat (_out, ')');
}
;

----------------------------------------------------------------------
-- Internal: the IRI-class QName for a node table in a property graph,
-- e.g. ("myshop", "PRODUCTS") -> "pgraph:myshop_PRODUCTS".
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_ICLASS (in _pg_name varchar, in _short_name varchar)
{
  return concat ('pgraph:', DB.DBA.GQL_PG_SANITIZE (_pg_name), '_', DB.DBA.GQL_PG_SANITIZE (_short_name));
}
;

----------------------------------------------------------------------
-- Execute CREATE VIRTUAL PROPERTY GRAPH.
--
-- Called from the GQL translator with the parsed DDL structure.
-- Generates and executes quad map SPARQL, then records metadata.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_CREATE_VIRTUAL (
  in _pg_name varchar,
  in _node_tables any,
  in _rel_tables any)
{
  declare _graph_iri, _ontology_ns, _data_ns varchar;
  declare _host varchar;
  declare _def any;
  declare _sparql_text varchar;

  -- Validate: no duplicate PG name
  if (DB.DBA.GQL_PG_DEF_GET (_pg_name) is not null)
    signal ('GQ202', sprintf ('Property graph %s already exists', _pg_name));

  _host := DB.DBA.GQL_URIQA_HOST ();
  _graph_iri := concat ('http://', _host, '/pgraph/', _pg_name);
  _ontology_ns := concat ('http://', _host, '/pgraph/', _pg_name, '/ontology#');
  _data_ns := concat ('http://', _host, '/pgraph/', _pg_name, '#');

  -- Build quad maps (shared with GQL_PG_CREATE_PHYSICAL)
  _sparql_text := DB.DBA.GQL_PG_BUILD_QM (_pg_name, _graph_iri, _ontology_ns, _data_ns,
                                          _node_tables, _rel_tables);

  -- Record metadata in catalog
  _def := vector (
    'node_tables', _node_tables,
    'relationship_tables', _rel_tables
  );
  DB.DBA.GQL_PG_DEF_UPSERT (_pg_name, 'virtual', _graph_iri, _ontology_ns, _data_ns, _def);

  return _sparql_text;
}
;

----------------------------------------------------------------------
-- Internal: shared quad-map builder used by both CREATE VIRTUAL and
-- CREATE PHYSICAL PROPERTY GRAPH.  Validates all tables/columns, then
-- generates and executes the IRI classes and quad-map definition.
-- Returns the generated SPARQL text (for debugging / dry-run output).
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_BUILD_QM (
  in _pg_name varchar,
  in _graph_iri varchar,
  in _ontology_ns varchar,
  in _data_ns varchar,
  inout _node_tables any,
  inout _rel_tables any)
{
  declare _sparql_text varchar;
  declare i, j integer;

  -- Normalise every table reference to its fully-qualified name so that
  -- validation, quad-map generation, and SOURCE/DESTINATION matching all
  -- compare like with like (see GQL_PG_QUALIFY_TABLE).
  for (i := 0; i < length (_node_tables); i := i + 1)
    {
      declare nt any;
      nt := aref (_node_tables, i);
      aset (nt, 0, DB.DBA.GQL_PG_QUALIFY_TABLE (aref (nt, 0)));
      aset (_node_tables, i, nt);
    }
  for (i := 0; i < length (_rel_tables); i := i + 1)
    {
      declare rt any;
      rt := aref (_rel_tables, i);
      aset (rt, 0, DB.DBA.GQL_PG_QUALIFY_TABLE (aref (rt, 0)));
      aset (rt, 2, DB.DBA.GQL_PG_QUALIFY_TABLE (aref (rt, 2)));  -- SOURCE table
      aset (rt, 4, DB.DBA.GQL_PG_QUALIFY_TABLE (aref (rt, 4)));  -- DESTINATION table
      aset (_rel_tables, i, rt);
    }

  -- Validate all tables and columns exist
  for (i := 0; i < length (_node_tables); i := i + 1)
    {
      declare nt any;
      nt := aref (_node_tables, i);
      DB.DBA.GQL_PG_VALIDATE_TABLE (aref (nt, 0));
      DB.DBA.GQL_PG_VALIDATE_COLS (aref (nt, 0), aref (nt, 1));  -- key cols
      DB.DBA.GQL_PG_VALIDATE_COLS (aref (nt, 0), aref (nt, 3));  -- properties
    }
  for (i := 0; i < length (_rel_tables); i := i + 1)
    {
      declare rt any;
      rt := aref (_rel_tables, i);
      DB.DBA.GQL_PG_VALIDATE_TABLE (aref (rt, 0));
      DB.DBA.GQL_PG_VALIDATE_COLS (aref (rt, 0), aref (rt, 1));  -- key cols
      DB.DBA.GQL_PG_VALIDATE_COLS (aref (rt, 0), aref (rt, 7));  -- properties

      -- Validate source/destination tables are in NODE TABLES
      declare src_tbl, dst_tbl varchar;
      src_tbl := aref (rt, 2);
      dst_tbl := aref (rt, 4);
      declare found_src, found_dst integer;
      found_src := 0;  found_dst := 0;
      for (j := 0; j < length (_node_tables); j := j + 1)
        {
          if (aref (aref (_node_tables, j), 0) = src_tbl) found_src := 1;
          if (aref (aref (_node_tables, j), 0) = dst_tbl) found_dst := 1;
        }
      if (found_src = 0)
        signal ('GQ203', sprintf ('SOURCE table %s is not declared in NODE TABLES', src_tbl));
      if (found_dst = 0)
        signal ('GQ204', sprintf ('DESTINATION table %s is not declared in NODE TABLES', dst_tbl));
    }

  -- ------------------------------------------------------------------
  -- Generate the Virtuoso quad-map definition using IRI classes.
  --
  -- Virtuoso maps relational rows to RDF through IRI classes (templated
  -- IRI constructors) referenced inside an "alter quad storage" block —
  -- not through inline {col} templates.  We declare one IRI class per
  -- node table (keyed on its primary key), then a single quad-map graph
  -- whose body carries the node subject maps (rdf:type + property
  -- triples) and the relationship triples
  -- (source-class -> label -> destination-class).
  -- ------------------------------------------------------------------
  declare _pfx, _qm_qname, _body varchar;
  declare _st, _msg varchar;
  declare _m, _d any;

  _pfx := DB.DBA.GQL_PG_PFX ();
  _qm_qname := concat ('pgraph:qm-', DB.DBA.GQL_PG_SANITIZE (_pg_name));
  _sparql_text := '';

  -- Remove any objects left over from an earlier incomplete run so the
  -- (re)definition below is clean and idempotent.
  _st := '00000'; _msg := '';
  exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop silent quad map ', _qm_qname, ' .')),
        _st, _msg, vector (), 0, _m, _d);

  -- (1) One IRI class per node table, keyed on its primary key.  Key
  -- params are declared varchar/%U — this URL-encodes the column value
  -- and works uniformly for integer and string keys.
  for (i := 0; i < length (_node_tables); i := i + 1)
    {
      declare nt any;
      declare tbl, short_name, slug, cls, tmpl, params varchar;
      declare pk any;
      declare j integer;

      nt := aref (_node_tables, i);
      tbl := aref (nt, 0);
      short_name := DB.DBA.GQL_PG_SHORT_NAME (tbl);
      -- data-IRI slug: first label if declared, else the short table name
      if (aref (nt, 2) is not null and length (aref (nt, 2)) > 0)
        slug := aref (aref (nt, 2), 0);
      else
        slug := short_name;
      cls := DB.DBA.GQL_PG_ICLASS (_pg_name, short_name);
      pk := DB.DBA.GQL_PG_GET_PK_COLS (tbl, aref (nt, 1));

      tmpl := concat (_data_ns, slug);
      params := '';
      for (j := 0; j < length (pk); j := j + 1)
        {
          tmpl := concat (tmpl, '-%U');
          if (j > 0) params := concat (params, ', ');
          params := concat (params, 'in _', DB.DBA.GQL_PG_SANITIZE (aref (pk, j)), ' varchar not null');
        }

      -- drop any stale class of the same name, then (re)create
      _st := '00000'; _msg := '';
      exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop iri class ', cls, ' .')),
            _st, _msg, vector (), 0, _m, _d);
      _st := '00000'; _msg := '';
      exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'create iri class ', cls, ' "', tmpl, '" (', params, ') .')),
            _st, _msg, vector (), 0, _m, _d);
      if (_st <> '00000')
        signal ('GQ205', sprintf ('Failed to create IRI class for %s in property graph %s: %s',
                                  short_name, _pg_name, _msg));
    }

  -- (2) Grant SPARQL read access on every underlying table.
  for (i := 0; i < length (_node_tables); i := i + 1)
    {
      _st := '00000'; _msg := '';
      exec (concat ('grant select on ', aref (aref (_node_tables, i), 0), ' to SPARQL_SELECT'),
            _st, _msg, vector (), 0, _m, _d);
    }
  for (i := 0; i < length (_rel_tables); i := i + 1)
    {
      _st := '00000'; _msg := '';
      exec (concat ('grant select on ', aref (aref (_rel_tables, i), 0), ' to SPARQL_SELECT'),
            _st, _msg, vector (), 0, _m, _d);
    }

  -- (3) The quad-map graph: node subject maps + relationship triples.
  _body := concat ('SPARQL ', _pfx, 'alter quad storage virtrdf:DefaultQuadStorage\n');
  for (i := 0; i < length (_node_tables); i := i + 1)
    _body := concat (_body,
      sprintf ('  from %s as %s\n', aref (aref (_node_tables, i), 0),
               DB.DBA.GQL_PG_TABLE_ALIAS (aref (aref (_node_tables, i), 0))));
  for (i := 0; i < length (_rel_tables); i := i + 1)
    _body := concat (_body,
      sprintf ('  from %s as %s\n', aref (aref (_rel_tables, i), 0),
               DB.DBA.GQL_PG_TABLE_ALIAS (aref (aref (_rel_tables, i), 0))));
  _body := concat (_body, '{\n  create ', _qm_qname,
                   ' as graph iri ("', _graph_iri, '")\n  option (exclusive)\n  {\n');

  -- Node subject maps
  for (i := 0; i < length (_node_tables); i := i + 1)
    {
      declare nt any;
      declare tbl, short_name, alias, cls varchar;
      declare labels, props, pk any;
      declare j, k integer;

      nt := aref (_node_tables, i);
      tbl := aref (nt, 0);
      short_name := DB.DBA.GQL_PG_SHORT_NAME (tbl);
      alias := DB.DBA.GQL_PG_TABLE_ALIAS (tbl);
      cls := DB.DBA.GQL_PG_ICLASS (_pg_name, short_name);
      labels := aref (nt, 2);
      props := aref (nt, 3);
      pk := DB.DBA.GQL_PG_GET_PK_COLS (tbl, aref (nt, 1));

      if (labels is null or length (labels) = 0)
        labels := vector (short_name);

      -- No explicit PROPERTIES: expose every non-key column.
      if (props is null)
        {
          declare all_cols any;
          all_cols := DB.DBA.GQL_PG_GET_ALL_COLS (tbl);
          props := vector ();
          for (k := 0; k < length (all_cols); k := k + 1)
            {
              declare col varchar;
              declare is_pk integer;
              col := aref (all_cols, k);
              is_pk := 0;
              for (j := 0; j < length (pk); j := j + 1)
                if (upper (aref (pk, j)) = upper (col)) is_pk := 1;
              -- Auto-derived property name: lower-case the (case-folded,
              -- upper) column name so the RDF predicate follows the
              -- conventional lower-case form GQL/SPARQL queries use.
              if (is_pk = 0)
                props := vector_concat (props, vector (vector (col, lower (col))));
            }
        }

      -- subject IRI + rdf:type(s).  Multiple types are an object list
      -- ("a <X> , <Y>") — repeating the "a" verb after a comma is invalid.
      _body := concat (_body, '    ', cls, ' ',
                       DB.DBA.GQL_PG_KEY_ARGS (tbl, alias, pk),
                       '\n      a <', _ontology_ns, aref (labels, 0), '>');
      for (j := 1; j < length (labels); j := j + 1)
        _body := concat (_body, ' ,\n        <', _ontology_ns, aref (labels, j), '>');

      -- property triples
      for (k := 0; k < length (props); k := k + 1)
        {
          declare col_name, prop_name varchar;
          col_name := aref (aref (props, k), 0);
          prop_name := aref (aref (props, k), 1);
          if (prop_name is null) prop_name := col_name;
          _body := concat (_body, ' ;\n      <', _ontology_ns, prop_name, '> ',
                           alias, '."', DB.DBA.GQL_PG_RESOLVE_COL (tbl, col_name), '"');
        }
      _body := concat (_body, ' .\n');
    }

  -- Relationship triples: source-class(fk) -> label -> dest-class(fk)
  for (i := 0; i < length (_rel_tables); i := i + 1)
    {
      declare rt any;
      declare tbl, alias, short_name, label varchar;
      declare src_tbl, dst_tbl, src_short, dst_short, src_cls, dst_cls varchar;
      declare src_cols, dst_cols any;
      declare j integer;

      rt := aref (_rel_tables, i);
      tbl := aref (rt, 0);
      alias := DB.DBA.GQL_PG_TABLE_ALIAS (tbl);
      short_name := DB.DBA.GQL_PG_SHORT_NAME (tbl);
      src_tbl := aref (rt, 2);
      dst_tbl := aref (rt, 4);
      src_cols := aref (rt, 3);
      dst_cols := aref (rt, 5);
      label := aref (rt, 6);
      if (label is null) label := short_name;

      src_short := DB.DBA.GQL_PG_SHORT_NAME (src_tbl);
      dst_short := DB.DBA.GQL_PG_SHORT_NAME (dst_tbl);
      src_cls := DB.DBA.GQL_PG_ICLASS (_pg_name, src_short);
      dst_cls := DB.DBA.GQL_PG_ICLASS (_pg_name, dst_short);

      -- The relationship table's foreign-key columns.  Use explicit
      -- SOURCE KEY / DESTINATION KEY when given; otherwise assume the
      -- rel table repeats the referenced node's primary-key column name.
      if (src_cols is null or length (src_cols) = 0)
        {
          for (j := 0; j < length (_node_tables); j := j + 1)
            if (aref (aref (_node_tables, j), 0) = src_tbl)
              src_cols := DB.DBA.GQL_PG_GET_PK_COLS (src_tbl, aref (aref (_node_tables, j), 1));
        }
      if (dst_cols is null or length (dst_cols) = 0)
        {
          for (j := 0; j < length (_node_tables); j := j + 1)
            if (aref (aref (_node_tables, j), 0) = dst_tbl)
              dst_cols := DB.DBA.GQL_PG_GET_PK_COLS (dst_tbl, aref (aref (_node_tables, j), 1));
        }

      _body := concat (_body, '    ', src_cls, ' ',
                       DB.DBA.GQL_PG_KEY_ARGS (tbl, alias, src_cols),
                       '\n      <', _ontology_ns, label, '> ',
                       dst_cls, ' ', DB.DBA.GQL_PG_KEY_ARGS (tbl, alias, dst_cols), ' .\n');
    }

  _body := concat (_body, '  }\n}\n');
  _sparql_text := _body;

  -- Execute the quad map definition.
  _st := '00000'; _msg := '';
  exec (DB.DBA.GQL_PG_NL (_body), _st, _msg, vector (), 0, _m, _d);
  if (_st <> '00000')
    {
      -- best-effort rollback of the partially-created quad map
      declare _st2, _msg2 varchar;
      _st2 := '00000'; _msg2 := '';
      exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop silent quad map ', _qm_qname, ' .')),
            _st2, _msg2, vector (), 0, _m, _d);
      signal ('GQ205', sprintf ('Failed to create quad maps for property graph %s: %s',
                                _pg_name, _msg));
    }

  return _sparql_text;
}
;

----------------------------------------------------------------------
-- Internal: generate a safe alias name from a table name.
-- "DB.DBA.products" -> "products_s"
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_TABLE_ALIAS (in _tbl_name varchar)
{
  declare short_name varchar;
  declare dot_pos integer;
  short_name := _tbl_name;
  dot_pos := strrchr (_tbl_name, '.');
  if (dot_pos is not null)
    short_name := subseq (_tbl_name, dot_pos + 1);
  return concat (short_name, '_s');
}
;

----------------------------------------------------------------------
-- Internal: convert an IRI template like
--   http://host/pgraph/pg#product-{product_no}
-- to a quad map IRI pattern substituting the table alias:
--   http://host/pgraph/pg#product-{products_s.product_no}
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_TMPL_TO_QM (in _tmpl varchar, in _alias varchar)
{
  declare result, col_name, replacement varchar;
  declare search_from, rel_pos, brace_pos, close_rel, close_pos integer;
  result := _tmpl;
  search_from := 0;
  -- Replace each {col} with {alias.col}.  Advance the search cursor past
  -- the text we just inserted — otherwise strchr would re-find the '{'
  -- of the replacement and rewrite it forever.
  while (1)
    {
      rel_pos := strchr (subseq (result, search_from), '{');
      if (rel_pos is null)
        return result;
      brace_pos := search_from + rel_pos;
      close_rel := strchr (subseq (result, brace_pos), '}');
      if (close_rel is null)
        return result;
      close_pos := brace_pos + close_rel;
      col_name := subseq (result, brace_pos + 1, close_pos);
      if (col_name = '__rowid')
        replacement := concat ('{', _alias, '.ROWID}');
      else
        replacement := concat ('{', _alias, '.', col_name, '}');
      result := concat (subseq (result, 0, brace_pos), replacement, subseq (result, close_pos + 1));
      search_from := brace_pos + length (replacement);
    }
  return result;
}
;

----------------------------------------------------------------------
-- Internal: convert a source node IRI template to use the
-- relationship table's source column.  E.g. if the source node
-- template is ...#order-{order_id} and the relationship table's
-- source column is also order_id, we produce ...#order-{oi_s.order_id}.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_TMPL_TO_QM_SRC (
  in _src_tmpl varchar, in _rel_alias varchar, in _src_col varchar)
{
  declare result, replacement varchar;
  declare search_from, rel_pos, brace_pos, close_rel, close_pos integer;
  result := _src_tmpl;
  search_from := 0;
  -- Replace the column name inside each {} with rel_alias.src_col.
  -- Advance past the inserted text so we do not re-scan the replacement.
  replacement := concat ('{', _rel_alias, '.', _src_col, '}');
  while (1)
    {
      rel_pos := strchr (subseq (result, search_from), '{');
      if (rel_pos is null)
        return result;
      brace_pos := search_from + rel_pos;
      close_rel := strchr (subseq (result, brace_pos), '}');
      if (close_rel is null)
        return result;
      close_pos := brace_pos + close_rel;
      result := concat (subseq (result, 0, brace_pos), replacement, subseq (result, close_pos + 1));
      search_from := brace_pos + length (replacement);
    }
  return result;
}
;

----------------------------------------------------------------------
-- Internal: same as above for destination.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_TMPL_TO_QM_DST (
  in _dst_tmpl varchar, in _rel_alias varchar, in _dst_col varchar)
{
  return DB.DBA.GQL_PG_TMPL_TO_QM_SRC (_dst_tmpl, _rel_alias, _dst_col);
}
;

----------------------------------------------------------------------
-- Execute CREATE PHYSICAL PROPERTY GRAPH.
-- With NODE TABLES: builds quad maps (same as virtual), materializes
-- the triples into the named graph, then drops the quad maps so the
-- graph is purely physical (writable).  Without NODE TABLES: creates
-- an empty writable named graph.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_CREATE_PHYSICAL (
  in _pg_name varchar,
  in _node_tables any,
  in _rel_tables any)
{
  declare _graph_iri, _ontology_ns, _data_ns varchar;
  declare _host varchar;
  declare _def any;
  declare _st, _msg varchar;
  declare _m, _d any;

  if (DB.DBA.GQL_PG_DEF_GET (_pg_name) is not null)
    signal ('GQ202', sprintf ('Property graph %s already exists', _pg_name));

  _host := DB.DBA.GQL_URIQA_HOST ();
  _graph_iri := concat ('http://', _host, '/pgraph/', _pg_name);
  _ontology_ns := concat ('http://', _host, '/pgraph/', _pg_name, '/ontology#');
  _data_ns := concat ('http://', _host, '/pgraph/', _pg_name, '#');

  -- If no node tables, create an empty writable graph (backward compat).
  if (_node_tables is null or length (_node_tables) = 0)
    {
      _st := '00000'; _msg := '';
      exec (sprintf ('SPARQL CREATE GRAPH <%s>', _graph_iri), _st, _msg, vector (), 0, _m, _d);
      if (_st <> '00000')
        signal ('GQ205', sprintf ('Failed to create graph for property graph %s: %s', _pg_name, _msg));
      DB.DBA.GQL_PG_DEF_UPSERT (_pg_name, 'physical', _graph_iri, _ontology_ns, _data_ns, null);
      return _graph_iri;
    }

  -- --- From-tables path: build quad maps, materialize, drop quad maps ---

  -- Build the quad maps (shared with GQL_PG_CREATE_VIRTUAL).
  DB.DBA.GQL_PG_BUILD_QM (_pg_name, _graph_iri, _ontology_ns, _data_ns,
                          _node_tables, _rel_tables);

  -- Materialize: copy triples from the virtual quad-map graph into the
  -- physical named graph.  Try RDF_VIEW_SYNC_TO_PHYSICAL first; fall
  -- back to SPARQL INSERT INTO GRAPH if that procedure is unavailable
  -- or fails.
  declare _materialized integer;
  _materialized := 0;

  if (__proc_exists ('DB.DBA.RDF_VIEW_SYNC_TO_PHYSICAL') is not null)
    {
      _st := '00000'; _msg := '';
      exec (sprintf ('DB.DBA.RDF_VIEW_SYNC_TO_PHYSICAL (''%s'', 1, null, 1, 1, 0, 0)',
                     _graph_iri),
            _st, _msg, vector (), 0, _m, _d);
      if (_st = '00000')
        _materialized := 1;
    }

  if (_materialized = 0)
    {
      -- SPARQL INSERT INTO GRAPH fallback: query the virtual graph
      -- (backed by quad maps) and copy every triple into the physical
      -- named graph.
      _st := '00000'; _msg := '';
      exec (sprintf (
              'SPARQL INSERT INTO GRAPH <%s> { ?s ?p ?o } WHERE { GRAPH <%s> { ?s ?p ?o } }',
              _graph_iri, _graph_iri),
            _st, _msg, vector (), 0, _m, _d);
      if (_st <> '00000')
        {
          -- Both materialization paths failed.  Drop the quad maps and
          -- signal so the user is left with no partial graph.
          DB.DBA.GQL_PG_DROP_QM (_pg_name, _node_tables);
          signal ('GQ208', sprintf (
            'Failed to materialize property graph %s: %s. Both RDF_VIEW_SYNC_TO_PHYSICAL and SPARQL INSERT fallback failed.',
            _pg_name, _msg));
        }
      _materialized := 1;
    }

  -- Drop the quad maps and IRI classes so the graph is purely physical
  -- (writable).  The data now lives in RDF_QUAD.
  DB.DBA.GQL_PG_DROP_QM (_pg_name, _node_tables);

  -- Record metadata in catalog
  _def := vector (
    'node_tables', _node_tables,
    'relationship_tables', _rel_tables
  );
  DB.DBA.GQL_PG_DEF_UPSERT (_pg_name, 'physical', _graph_iri, _ontology_ns, _data_ns, _def);

  -- Mark as materialized
  update DB.DBA.GQL_PROPERTY_GRAPH_DEF
     set IS_MATERIALIZED = 1
   where PG_NAME = _pg_name;

  return _graph_iri;
}
;

----------------------------------------------------------------------
-- Internal: drop the quad map and IRI classes for a property graph.
-- Used by GQL_PG_CREATE_PHYSICAL (after materialization) and by
-- GQL_PG_DROP (for virtual graphs and materialized physical graphs).
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DROP_QM (
  in _pg_name varchar,
  in _node_tables any)
{
  declare _pfx, _qm_qname varchar;
  declare _st, _msg varchar;
  declare _m, _d any;
  declare i integer;

  _pfx := DB.DBA.GQL_PG_PFX ();
  _qm_qname := concat ('pgraph:qm-', DB.DBA.GQL_PG_SANITIZE (_pg_name));

  -- Drop the quad map graph
  _st := '00000'; _msg := '';
  exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop silent quad map ', _qm_qname, ' .')),
        _st, _msg, vector (), 0, _m, _d);

  -- Drop IRI classes for each node table
  if (_node_tables is not null and isarray (_node_tables))
    {
      for (i := 0; i < length (_node_tables); i := i + 1)
        {
          declare nt any;
          declare tbl, short_name, cls varchar;
          nt := aref (_node_tables, i);
          tbl := aref (nt, 0);
          short_name := DB.DBA.GQL_PG_SHORT_NAME (tbl);
          cls := DB.DBA.GQL_PG_ICLASS (_pg_name, short_name);
          _st := '00000'; _msg := '';
          exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop silent iri class ', cls, ' .')),
                _st, _msg, vector (), 0, _m, _d);
        }
    }
}
;

----------------------------------------------------------------------
-- Execute DROP PROPERTY GRAPH.
-- For virtual PGs: drops quad maps and optionally physical triples.
-- For physical PGs: drops the named graph.
-- Idempotent: if the PG doesn't exist in the catalog, does nothing.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DROP (in _pg_name varchar, in _if_exists integer)
{
  declare meta any;
  declare _pg_mode, _graph_iri varchar;
  declare _def any;
  declare _st, _msg varchar;
  declare _m, _d any;

  meta := DB.DBA.GQL_PG_DEF_GET (_pg_name);
  if (meta is null)
    {
      if (_if_exists) return 'OK';
      signal ('GQ206', sprintf ('Property graph %s does not exist', _pg_name));
    }

  _pg_mode := aref (meta, 0);
  _graph_iri := aref (meta, 1);
  _def := aref (meta, 4);

  -- If materialized, delete physical triples first
  if (aref (meta, 5) = 1)
    {
      _st := '00000'; _msg := '';
      exec (sprintf ('SPARQL CLEAR GRAPH <%s>', _graph_iri), _st, _msg, vector (), 0, _m, _d);
    }

  if (_pg_mode = 'virtual')
    {
      -- Drop the single quad-map graph, then each node IRI class.
      declare _node_tables any;
      declare _pfx, _qm_qname varchar;
      declare i integer;

      _pfx := DB.DBA.GQL_PG_PFX ();
      _qm_qname := concat ('pgraph:qm-', DB.DBA.GQL_PG_SANITIZE (_pg_name));

      _node_tables := null;
      if (_def is not null and isarray (_def))
        {
          declare idx integer;
          for (idx := 0; idx < length (_def); idx := idx + 2)
            if (aref (_def, idx) = 'node_tables') _node_tables := aref (_def, idx + 1);
        }

      -- Remove the quad map first (unlinks it from the storage).
      _st := '00000'; _msg := '';
      exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop silent quad map ', _qm_qname, ' .')),
            _st, _msg, vector (), 0, _m, _d);

      -- Then drop the per-node IRI classes.  Errors are ignored — the
      -- objects may already be gone (idempotent drop).
      if (_node_tables is not null)
        for (i := 0; i < length (_node_tables); i := i + 1)
          {
            declare _short, _cls varchar;
            _short := DB.DBA.GQL_PG_SHORT_NAME (aref (aref (_node_tables, i), 0));
            _cls := DB.DBA.GQL_PG_ICLASS (_pg_name, _short);
            _st := '00000'; _msg := '';
            exec (DB.DBA.GQL_PG_NL (concat ('SPARQL ', _pfx, 'drop iri class ', _cls, ' .')),
                  _st, _msg, vector (), 0, _m, _d);
          }
    }
  else  -- physical
    {
      -- Drop the named graph (clears all triples).
      _st := '00000'; _msg := '';
      exec (sprintf ('SPARQL DROP GRAPH <%s>', _graph_iri), _st, _msg, vector (), 0, _m, _d);

      -- If this physical graph was created from tables (DEFINITION is
      -- non-null), also drop any residual quad maps / IRI classes that
      -- might remain from the build+materialize process.
      if (_def is not null and isarray (_def))
        {
          declare _node_tables any;
          declare idx integer;
          _node_tables := null;
          for (idx := 0; idx < length (_def); idx := idx + 2)
            if (aref (_def, idx) = 'node_tables') _node_tables := aref (_def, idx + 1);
          if (_node_tables is not null)
            DB.DBA.GQL_PG_DROP_QM (_pg_name, _node_tables);
        }
    }

  DB.DBA.GQL_PG_DEF_DELETE (_pg_name);
  return 'OK';
}
;

----------------------------------------------------------------------
-- Materialize a virtual property graph into physical RDF triples.
-- Tries RDF_VIEW_SYNC_TO_PHYSICAL first; falls back to SPARQL INSERT
-- INTO GRAPH if that procedure is unavailable or fails.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_MATERIALIZE (in _pg_name varchar)
{
  declare meta any;
  declare _pg_mode, _graph_iri varchar;
  declare _st, _msg varchar;
  declare _m, _d any;
  declare _materialized integer;

  meta := DB.DBA.GQL_PG_DEF_GET (_pg_name);
  if (meta is null)
    signal ('GQ206', sprintf ('Property graph %s does not exist', _pg_name));
  _pg_mode := aref (meta, 0);
  _graph_iri := aref (meta, 1);

  if (_pg_mode <> 'virtual')
    signal ('GQ207', sprintf ('Property graph %s is not virtual; cannot materialize', _pg_name));

  _materialized := 0;

  -- Try RDF_VIEW_SYNC_TO_PHYSICAL first.
  if (__proc_exists ('DB.DBA.RDF_VIEW_SYNC_TO_PHYSICAL') is not null)
    {
      _st := '00000'; _msg := '';
      exec (sprintf ('DB.DBA.RDF_VIEW_SYNC_TO_PHYSICAL (''%s'', 1, null, 1, 1, 0, 0)',
                     _graph_iri),
            _st, _msg, vector (), 0, _m, _d);
      if (_st = '00000')
        _materialized := 1;
    }

  -- Fallback: SPARQL INSERT INTO GRAPH.
  if (_materialized = 0)
    {
      _st := '00000'; _msg := '';
      exec (sprintf (
              'SPARQL INSERT INTO GRAPH <%s> { ?s ?p ?o } WHERE { GRAPH <%s> { ?s ?p ?o } }',
              _graph_iri, _graph_iri),
            _st, _msg, vector (), 0, _m, _d);
      if (_st <> '00000')
        signal ('GQ208', sprintf (
          'Failed to materialize property graph %s: %s. Both RDF_VIEW_SYNC_TO_PHYSICAL and SPARQL INSERT fallback failed.',
          _pg_name, _msg));
      _materialized := 1;
    }

  update DB.DBA.GQL_PROPERTY_GRAPH_DEF
     set IS_MATERIALIZED = 1
   where PG_NAME = _pg_name;

  return 'OK';
}
;

----------------------------------------------------------------------
-- Dematerialize a virtual property graph (remove physical triples).
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DEMATERIALIZE (in _pg_name varchar)
{
  declare meta any;
  declare _pg_mode, _graph_iri varchar;
  declare _st, _msg varchar;
  declare _m, _d any;

  meta := DB.DBA.GQL_PG_DEF_GET (_pg_name);
  if (meta is null)
    signal ('GQ206', sprintf ('Property graph %s does not exist', _pg_name));
  _pg_mode := aref (meta, 0);
  _graph_iri := aref (meta, 1);

  if (_pg_mode <> 'virtual')
    signal ('GQ207', sprintf ('Property graph %s is not virtual; cannot dematerialize', _pg_name));
  if (aref (meta, 5) <> 1)
    signal ('GQ209', sprintf ('Property graph %s is not materialized', _pg_name));

  _st := '00000'; _msg := '';
  exec (sprintf ('SPARQL CLEAR GRAPH <%s>', _graph_iri), _st, _msg, vector (), 0, _m, _d);

  update DB.DBA.GQL_PROPERTY_GRAPH_DEF
     set IS_MATERIALIZED = 0
   where PG_NAME = _pg_name;

  return 'OK';
}
;

----------------------------------------------------------------------
-- Export a virtual property graph as R2RML TTL.
-- Uses the RDF 1.2 reifier pattern: rdf:reifies <<( s p o )>>
-- Requires the rdb2rdf VAD to be installed.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_EXPORT_R2RML (in _pg_name varchar) returns varchar
{
  declare meta any;
  declare _pg_mode, _graph_iri, _ontology_ns, _data_ns varchar;
  declare _def any;
  declare _node_tables, _rel_tables any;
  declare _ttl varchar;
  declare i, j, k integer;

  meta := DB.DBA.GQL_PG_DEF_GET (_pg_name);
  if (meta is null)
    signal ('GQ206', sprintf ('Property graph %s does not exist', _pg_name));

  _pg_mode := aref (meta, 0);
  _graph_iri := aref (meta, 1);
  _ontology_ns := aref (meta, 2);
  _data_ns := aref (meta, 3);
  _def := aref (meta, 4);

  if (_pg_mode <> 'virtual')
    signal ('GQ207', sprintf ('Property graph %s is not virtual; R2RML export is for virtual PGs only', _pg_name));

  -- Check rdb2rdf VAD availability (graceful degradation)
  if (__proc_exists ('DB.DBA.R2RML_MAKE_QM_FROM_G') is null)
    signal ('GQ210', 'R2RML export requires the rdb2rdf VAD to be installed');

  -- Extract node and relationship tables from definition
  _node_tables := vector ();
  _rel_tables := vector ();
  if (_def is not null and isarray (_def))
    {
      for (i := 0; i < length (_def); i := i + 2)
        {
          if (aref (_def, i) = 'node_tables') _node_tables := aref (_def, i + 1);
          if (aref (_def, i) = 'relationship_tables') _rel_tables := aref (_def, i + 1);
        }
    }

  -- Build TTL
  _ttl := '';
  _ttl := concat (_ttl, '@prefix rr: <http://www.w3.org/ns/r2rml#> .\n');
  _ttl := concat (_ttl, '@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n');
  _ttl := concat (_ttl, '@prefix pgraph: <', _ontology_ns, '> .\n\n');

  -- Node table TriplesMaps
  for (i := 0; i < length (_node_tables); i := i + 1)
    {
      declare nt any;
      declare tbl_name, short_name varchar;
      declare key_cols, labels, props any;
      declare iri_tmpl varchar;
      declare dot_pos integer;

      nt := aref (_node_tables, i);
      tbl_name := aref (nt, 0);
      key_cols := DB.DBA.GQL_PG_GET_PK_COLS (tbl_name, aref (nt, 1));
      labels := aref (nt, 2);
      props := aref (nt, 3);

      short_name := tbl_name;
      dot_pos := strrchr (tbl_name, '.');
      if (dot_pos is not null) short_name := subseq (tbl_name, dot_pos + 1);

      iri_tmpl := DB.DBA.GQL_PG_IRI_TEMPLATE (_data_ns, tbl_name, key_cols);

      if (labels is null or length (labels) = 0)
        labels := vector (short_name);

      if (props is null)
        {
          declare all_cols, pk_set any;
          all_cols := DB.DBA.GQL_PG_GET_ALL_COLS (tbl_name);
          props := vector ();
          for (k := 0; k < length (all_cols); k := k + 1)
            {
              declare col varchar;
              declare is_pk integer;
              col := aref (all_cols, k);
              is_pk := 0;
              if (key_cols is not null)
                {
                  declare m integer;
                  for (m := 0; m < length (key_cols); m := m + 1)
                    if (aref (key_cols, m) = col) is_pk := 1;
                }
              if (is_pk = 0)
                props := vector_concat (props, vector (vector (col, null)));
            }
        }

      -- Convert IRI template to R2RML format ({col} stays as {col})
      _ttl := concat (_ttl, '# Node: ', short_name, '\n');
      _ttl := concat (_ttl, sprintf ('<#%s_tm> a rr:TriplesMap ;\n', short_name));
      _ttl := concat (_ttl, sprintf ('    rr:logicalTable [ rr:tableName "%s" ] ;\n', tbl_name));
      _ttl := concat (_ttl, '    rr:subjectMap [\n');
      _ttl := concat (_ttl, sprintf ('        rr:template "%s" ;\n', iri_tmpl));
      _ttl := concat (_ttl, sprintf ('        rr:class pgraph:%s ;\n', aref (labels, 0)));
      for (k := 1; k < length (labels); k := k + 1)
        _ttl := concat (_ttl, sprintf ('        rr:class pgraph:%s ;\n', aref (labels, k)));
      _ttl := concat (_ttl, sprintf ('        rr:graph <%s>\n', _graph_iri));
      _ttl := concat (_ttl, '    ] ;\n');

      for (k := 0; k < length (props); k := k + 1)
        {
          declare col_name, prop_name varchar;
          col_name := aref (aref (props, k), 0);
          prop_name := aref (aref (props, k), 1);
          if (prop_name is null) prop_name := col_name;
          _ttl := concat (_ttl, '    rr:predicateObjectMap [\n');
          _ttl := concat (_ttl, sprintf ('        rr:predicate pgraph:%s ;\n', prop_name));
          _ttl := concat (_ttl, sprintf ('        rr:objectMap [ rr:column "%s" ]\n', col_name));
          if (k < length (props) - 1)
            _ttl := concat (_ttl, '    ] ;\n');
          else
            _ttl := concat (_ttl, '    ] .\n');
        }
      if (length (props) = 0)
        _ttl := concat (_ttl, '    .\n');
      _ttl := concat (_ttl, '\n');
    }

  -- Relationship table TriplesMaps (base + reifier)
  for (i := 0; i < length (_rel_tables); i := i + 1)
    {
      declare rt any;
      declare tbl_name, short_name varchar;
      declare key_cols, props any;
      declare src_table, dst_table, label varchar;
      declare src_cols, dst_cols any;
      declare reifier_named integer;
      declare reifier_iri_tmpl varchar;
      declare src_iri_tmpl, dst_iri_tmpl varchar;
      declare src_key_cols, dst_key_cols any;
      declare dot_pos integer;
      declare src_col, dst_col varchar;

      rt := aref (_rel_tables, i);
      tbl_name := aref (rt, 0);
      key_cols := aref (rt, 1);
      src_table := aref (rt, 2);
      src_cols := aref (rt, 3);
      dst_table := aref (rt, 4);
      dst_cols := aref (rt, 5);
      label := aref (rt, 6);
      props := aref (rt, 7);
      reifier_named := aref (rt, 8);
      reifier_iri_tmpl := aref (rt, 9);

      short_name := tbl_name;
      dot_pos := strrchr (tbl_name, '.');
      if (dot_pos is not null) short_name := subseq (tbl_name, dot_pos + 1);

      -- Get source/dest key cols and IRI templates
      src_key_cols := src_cols;
      dst_key_cols := dst_cols;
      for (k := 0; k < length (_node_tables); k := k + 1)
        {
          declare nt any;
          nt := aref (_node_tables, k);
          if (aref (nt, 0) = src_table)
            src_key_cols := DB.DBA.GQL_PG_GET_PK_COLS (src_table, aref (nt, 1));
          if (aref (nt, 0) = dst_table)
            dst_key_cols := DB.DBA.GQL_PG_GET_PK_COLS (dst_table, aref (nt, 1));
        }

      src_iri_tmpl := DB.DBA.GQL_PG_IRI_TEMPLATE (_data_ns, src_table, src_key_cols);
      dst_iri_tmpl := DB.DBA.GQL_PG_IRI_TEMPLATE (_data_ns, dst_table, dst_key_cols);

      if (label is null) label := short_name;

      src_col := null;  dst_col := null;
      if (src_cols is not null and length (src_cols) > 0) src_col := aref (src_cols, 0);
      if (dst_cols is not null and length (dst_cols) > 0) dst_col := aref (dst_cols, 0);
      if (src_col is null and src_key_cols is not null and length (src_key_cols) > 0)
        src_col := aref (src_key_cols, 0);
      if (dst_col is null and dst_key_cols is not null and length (dst_key_cols) > 0)
        dst_col := aref (dst_key_cols, 0);

      -- Base TriplesMap: relationship triple
      _ttl := concat (_ttl, '# Relationship: ', short_name, ' — base triple\n');
      _ttl := concat (_ttl, sprintf ('<#%s_base_tm> a rr:TriplesMap ;\n', short_name));
      _ttl := concat (_ttl, sprintf ('    rr:logicalTable [ rr:tableName "%s" ] ;\n', tbl_name));
      _ttl := concat (_ttl, '    rr:subjectMap [\n');
      _ttl := concat (_ttl, sprintf ('        rr:template "%s" ;\n', src_iri_tmpl));
      _ttl := concat (_ttl, sprintf ('        rr:graph <%s>\n', _graph_iri));
      _ttl := concat (_ttl, '    ] ;\n');
      _ttl := concat (_ttl, '    rr:predicateObjectMap [\n');
      _ttl := concat (_ttl, sprintf ('        rr:predicate pgraph:%s ;\n', label));
      _ttl := concat (_ttl, '        rr:objectMap [\n');
      _ttl := concat (_ttl, sprintf ('            rr:template "%s"\n', dst_iri_tmpl));
      _ttl := concat (_ttl, '        ]\n');
      _ttl := concat (_ttl, '    ] .\n\n');

      -- Reifier TriplesMap: RDF 1.2 triple term
      declare reifier_tmpl varchar;
      if (reifier_named = 1 and reifier_iri_tmpl is not null)
        reifier_tmpl := reifier_iri_tmpl;
      else
        {
          declare rel_key_cols any;
          rel_key_cols := DB.DBA.GQL_PG_GET_PK_COLS (tbl_name, key_cols);
          reifier_tmpl := DB.DBA.GQL_PG_IRI_TEMPLATE (_data_ns, tbl_name, rel_key_cols);
        }

      -- Build the triple term: <<( src_iri label dst_iri )>>
      declare triple_term varchar;
      triple_term := concat ('<<( ', src_iri_tmpl, ' ', _ontology_ns, label, ' ', dst_iri_tmpl, ' )>>');

      _ttl := concat (_ttl, '# Relationship: ', short_name, ' — reifier (RDF 1.2 triple term)\n');
      _ttl := concat (_ttl, sprintf ('<#%s_reifier_tm> a rr:TriplesMap ;\n', short_name));
      _ttl := concat (_ttl, sprintf ('    rr:logicalTable [ rr:tableName "%s" ] ;\n', tbl_name));
      _ttl := concat (_ttl, '    rr:subjectMap [\n');
      _ttl := concat (_ttl, sprintf ('        rr:template "%s" ;\n', reifier_tmpl));
      _ttl := concat (_ttl, sprintf ('        rr:graph <%s>\n', _graph_iri));
      _ttl := concat (_ttl, '    ] ;\n');
      _ttl := concat (_ttl, '    rr:predicateObjectMap [\n');
      _ttl := concat (_ttl, '        rr:predicate rdf:reifies ;\n');
      _ttl := concat (_ttl, '        rr:objectMap [\n');
      _ttl := concat (_ttl, sprintf ('            rr:template "%s"\n', triple_term));
      _ttl := concat (_ttl, '        ]\n');

      -- Relationship properties
      if (props is not null and length (props) > 0)
        {
          _ttl := concat (_ttl, '    ] ;\n');
          for (k := 0; k < length (props); k := k + 1)
            {
              declare col_name, prop_name varchar;
              col_name := aref (aref (props, k), 0);
              prop_name := aref (aref (props, k), 1);
              if (prop_name is null) prop_name := col_name;
              _ttl := concat (_ttl, '    rr:predicateObjectMap [\n');
              _ttl := concat (_ttl, sprintf ('        rr:predicate pgraph:%s ;\n', prop_name));
              _ttl := concat (_ttl, sprintf ('        rr:objectMap [ rr:column "%s" ]\n', col_name));
              if (k < length (props) - 1)
                _ttl := concat (_ttl, '    ] ;\n');
              else
                _ttl := concat (_ttl, '    ] .\n');
            }
        }
      else
        _ttl := concat (_ttl, '    ] .\n');

      _ttl := concat (_ttl, '\n');
    }

  return _ttl;
}
;

----------------------------------------------------------------------
-- Export R2RML TTL into a named graph for SPARQL inspection.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_EXPORT_R2RML_TO_GRAPH (
  in _pg_name varchar, in _graph_iri varchar)
{
  declare _ttl varchar;
  declare _st, _msg varchar;
  declare _m, _d any;

  _ttl := DB.DBA.GQL_PG_EXPORT_R2RML (_pg_name);

  _st := '00000'; _msg := '';
  exec (sprintf ('SPARQL CREATE GRAPH <%s>', _graph_iri), _st, _msg, vector (), 0, _m, _d);
  _st := '00000'; _msg := '';
  exec (sprintf ('DB.DBA.TTLP (?, ?, ?)', _graph_iri), _st, _msg,
        vector (_ttl, _graph_iri, _graph_iri), 0, _m, _d);
  if (_st <> '00000')
    signal ('GQ211', sprintf ('Failed to load R2RML TTL into graph %s: %s', _graph_iri, _msg));

  return 'OK';
}
;

----------------------------------------------------------------------
-- Describe a property graph (human-readable metadata summary).
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DESCRIBE (in _pg_name varchar) returns varchar
{
  declare meta any;
  declare _pg_mode, _graph_iri, _ontology_ns, _data_ns varchar;
  declare _def any;
  declare _node_tables, _rel_tables any;
  declare _result varchar;
  declare i, k integer;

  meta := DB.DBA.GQL_PG_DEF_GET (_pg_name);
  if (meta is null)
    return sprintf ('Property graph %s does not exist', _pg_name);

  _pg_mode := aref (meta, 0);
  _graph_iri := aref (meta, 1);
  _ontology_ns := aref (meta, 2);
  _data_ns := aref (meta, 3);
  _def := aref (meta, 4);

  _result := '';
  _result := concat (_result, sprintf ('Property Graph: %s\n', _pg_name));
  _result := concat (_result, sprintf ('  Mode: %s\n', _pg_mode));
  _result := concat (_result, sprintf ('  Graph IRI: %s\n', _graph_iri));
  _result := concat (_result, sprintf ('  Ontology NS: %s\n', _ontology_ns));
  _result := concat (_result, sprintf ('  Data NS: %s\n', _data_ns));
  if (aref (meta, 5) = 1)
    _result := concat (_result, '  Materialized: yes\n');
  else
    _result := concat (_result, '  Materialized: no\n');

  if (_pg_mode = 'virtual' and _def is not null)
    {
      _node_tables := vector ();
      _rel_tables := vector ();
      if (isarray (_def))
        {
          for (i := 0; i < length (_def); i := i + 2)
            {
              if (aref (_def, i) = 'node_tables') _node_tables := aref (_def, i + 1);
              if (aref (_def, i) = 'relationship_tables') _rel_tables := aref (_def, i + 1);
            }
        }

      _result := concat (_result, sprintf ('\nNode Tables (%d):\n', length (_node_tables)));
      for (i := 0; i < length (_node_tables); i := i + 1)
        {
          declare nt any;
          declare labels, props any;
          nt := aref (_node_tables, i);
          labels := aref (nt, 2);
          props := aref (nt, 3);
          _result := concat (_result, sprintf ('  %s', aref (nt, 0)));
          if (labels is not null and length (labels) > 0)
            {
              _result := concat (_result, ' labels: ');
              for (k := 0; k < length (labels); k := k + 1)
                {
                  if (k > 0) _result := concat (_result, ', ');
                  _result := concat (_result, aref (labels, k));
                }
            }
          if (props is not null and length (props) > 0)
            {
              _result := concat (_result, ' properties: ');
              for (k := 0; k < length (props); k := k + 1)
                {
                  declare col_name, prop_name varchar;
                  col_name := aref (aref (props, k), 0);
                  prop_name := aref (aref (props, k), 1);
                  if (k > 0) _result := concat (_result, ', ');
                  if (prop_name is not null)
                    _result := concat (_result, prop_name);
                  else
                    _result := concat (_result, col_name);
                }
            }
          _result := concat (_result, '\n');
        }

      _result := concat (_result, sprintf ('\nRelationship Tables (%d):\n', length (_rel_tables)));
      for (i := 0; i < length (_rel_tables); i := i + 1)
        {
          declare rt any;
          rt := aref (_rel_tables, i);
          _result := concat (_result,
            sprintf ('  %s: %s -> %s, label=%s',
              aref (rt, 0), aref (rt, 2), aref (rt, 4), aref (rt, 6)));
          if (aref (rt, 8) = 1)
            _result := concat (_result, ', reifier=named');
          else
            _result := concat (_result, ', reifier=anonymous');
          _result := concat (_result, '\n');
        }
    }

  return _result;
}
;
