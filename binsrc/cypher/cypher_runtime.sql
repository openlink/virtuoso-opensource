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
--
--  openCypher: OpenCypher for Virtuoso
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Runtime utilities: namespaces, URI generation, graph management
--

-- URIQA host from virtuoso.ini [URIQA] DefaultHost (via registry)
create procedure DB.DBA.OPENCYPHER_URIQA_HOST ()
{
  declare host varchar;
  host := registry_get ('URIQADefaultHost');
  if (host is null or host = '')
    return 'localhost:8890';
  return host;
}
;

-- Ontology namespace: predicates, labels, types, classes
create procedure DB.DBA.OPENCYPHER_NS ()
{
  return concat ('http://', DB.DBA.OPENCYPHER_URIQA_HOST (), '/opencypher/ontology#');
}
;

-- Entity/data namespace: nodes, relationships, reification statements
create procedure DB.DBA.OPENCYPHER_DATA_NS ()
{
  return concat ('http://', DB.DBA.OPENCYPHER_URIQA_HOST (), '/opencypher/data#');
}
;

-- Default graph for Cypher data
create procedure DB.DBA.OPENCYPHER_DEFAULT_GRAPH ()
{
  return 'urn:opencypher:default';
}
;

-- Marker class: all Cypher nodes are rdf:type opencypher:Node
create procedure DB.DBA.OPENCYPHER_NODE_CLASS ()
{
  return concat (DB.DBA.OPENCYPHER_NS (), 'Node');
}
;

-- Generate a unique node URI (entity namespace)
create procedure DB.DBA.OPENCYPHER_NEW_NODE_URI ()
{
  return concat (DB.DBA.OPENCYPHER_DATA_NS (), 'node_', cast (uuid () as varchar));
}
;

-- Generate a unique relationship URI (entity namespace, for reification)
create procedure DB.DBA.OPENCYPHER_NEW_REL_URI ()
{
  return concat (DB.DBA.OPENCYPHER_DATA_NS (), 'rel_', cast (uuid () as varchar));
}
;

-- Resolve a label name to a class URI
create procedure DB.DBA.OPENCYPHER_LABEL_URI (in _name varchar)
{
  return concat (DB.DBA.OPENCYPHER_NS (), _name);
}
;

-- Resolve a property name to a predicate URI
create procedure DB.DBA.OPENCYPHER_PROP_URI (in _name varchar)
{
  return concat (DB.DBA.OPENCYPHER_NS (), _name);
}
;

-- Resolve a relationship type name to a predicate URI with camelCase conversion
-- Per specs: KNOWS -> knows, ACTED_IN -> actedIn
create procedure DB.DBA.OPENCYPHER_REL_TYPE_URI (in _type varchar)
{
  return concat (DB.DBA.OPENCYPHER_NS (), DB.DBA.OPENCYPHER_TO_CAMEL_CASE (_type));
}
;

-- Convert UPPER_CASE or snake_case to camelCase
-- KNOWS -> knows, ACTED_IN -> actedIn, knows -> knows
create procedure DB.DBA.OPENCYPHER_TO_CAMEL_CASE (in _str varchar)
{
  declare result varchar;
  declare i, n, prev, is_first integer;
  declare part varchar;

  if (_str is null or length (_str) = 0)
    return _str;

  -- No underscore: just lowercase the whole string
  if (strchr (_str, '_') is null)
    return lower (_str);

  -- Manual split by underscore and build camelCase
  result := '';
  prev := 0;
  is_first := 1;
  n := length (_str);
  for (i := 0; i <= n; i := i + 1)
    {
      if (i = n or aref (_str, i) = 95)  -- 95 = '_'
        {
          if (i > prev)
            {
              part := subseq (_str, prev, i);
              if (is_first)
                {
                  result := lower (part);
                  is_first := 0;
                }
              else
                result := concat (result, upper (subseq (part, 0, 1)), lower (subseq (part, 1)));
            }
          prev := i + 1;
        }
    }

  return result;
}
;

-- Generate a deterministic reification statement ID based on (subject, predicate, object)
-- Per specs: SHA256-based UUID v5 namespace
create procedure DB.DBA.OPENCYPHER_REIF_STATEMENT_ID (in _subject varchar, in _predicate varchar, in _object varchar)
{
  declare hash_str varchar;
  -- Simple hash-based ID (in production, use proper SHA256)
  hash_str := md5 (concat (_subject, '|', _predicate, '|', _object));
  return concat (DB.DBA.OPENCYPHER_DATA_NS (), 'reif_', hash_str);
}
;

-- Get the reification graph URI for storing relationship properties
create procedure DB.DBA.OPENCYPHER_REIF_GRAPH ()
{
  return 'urn:opencypher:reifications';
}
;

-- Format a URI for SPARQL output (angle-bracket wrapped)
create procedure DB.DBA.OPENCYPHER_FMT_URI (in _uri varchar)
{
  return concat ('<', _uri, '>');
}
;

-- Format a literal value for SPARQL
create procedure DB.DBA.OPENCYPHER_FMT_LITERAL (in _val any)
{
  if (_val is null)
    return 'UNDEF';
  if (isstring (_val))
    {
      declare escaped varchar;
      escaped := replace (_val, '\\', '\\\\');
      escaped := replace (escaped, '"', '\\"');
      escaped := replace (escaped, '\n', '\\n');
      escaped := replace (escaped, '\r', '\\r');
      escaped := replace (escaped, '\t', '\\t');
      return concat ('"', escaped, '"');
    }
  if (isinteger (_val))
    return cast (_val as varchar);
  if (isfloat (_val) or isdouble (_val))
    return cast (_val as varchar);
  return cast (_val as varchar);
}
;

-- Clear all Cypher data in a graph
create procedure DB.DBA.OPENCYPHER_CLEAR_GRAPH (in _graph varchar := null)
{
  if (_graph is null)
    _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
  exec (sprintf ('SPARQL CLEAR GRAPH <%s>', _graph));
}
;

-- Register namespace prefix
create procedure DB.DBA.OPENCYPHER_REGISTER_NS ()
{
  DB.DBA.XML_SET_NS_DECL ('opencypher', DB.DBA.OPENCYPHER_NS (), 2);
}
;

--
-- Phase 14.1 — Runtime value representation helpers.
-- See binsrc/cypher/OPENCYPHER_VALUE_REPRESENTATION.md for the full
-- contract; categories tagged here are LIST, MAP, PATH, ROW.
--

create procedure DB.DBA.CYP_DENSE_NUMERIC_AVAILABLE ()
{
  declare dv, arr any;

  declare exit handler for sqlstate '*'
    {
      return 0;
    };

  dv := dvector (1.0, 2.0);
  if (length (dv) <> 2 or aref (dv, 1) <> 2.0)
    return 0;

  arr := make_array (2, 'double');
  aset (arr, 0, 1.0);
  aset (arr, 1, 2.0);
  if (length (arr) <> 2 or aref (arr, 1) <> 2.0)
    return 0;

  return 1;
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_VALIDATE (in _vals any)
{
  declare i integer;
  if (_vals is null)
    return vector ();
  if (not isarray (_vals))
    signal ('CY080', 'CYP_NUMERIC_VECTOR_NEW expects a vector of numeric values');
  for (i := 0; i < length (_vals); i := i + 1)
    {
      if (not isnumeric (aref (_vals, i)))
        signal ('CY080', 'CYP_NUMERIC_VECTOR_NEW expects numeric-only values');
    }
  return _vals;
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_FALLBACK (in _vals any)
{
  declare out_vals any;
  declare i integer;
  out_vals := make_array (length (_vals), 'any');
  for (i := 0; i < length (_vals); i := i + 1)
    aset (out_vals, i, aref (_vals, i));
  return out_vals;
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_NEW (in _vals any)
{
  declare dense any;
  declare i integer;

  _vals := DB.DBA.CYP_NUMERIC_VECTOR_VALIDATE (_vals);

  if (DB.DBA.CYP_DENSE_NUMERIC_AVAILABLE () = 0)
    return DB.DBA.CYP_NUMERIC_VECTOR_FALLBACK (_vals);

  declare exit handler for sqlstate '*'
    {
      return DB.DBA.CYP_NUMERIC_VECTOR_FALLBACK (_vals);
    };

  dense := make_array (length (_vals), 'double');
  for (i := 0; i < length (_vals); i := i + 1)
    aset (dense, i, cast (aref (_vals, i) as double precision));
  return dense;
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_TO_VECTOR (in _vals any)
{
  declare out_vals any;
  declare i integer;
  if (_vals is null)
    return vector ();
  if (not isarray (_vals))
    signal ('CY080', 'CYP_NUMERIC_VECTOR_TO_VECTOR expects a numeric vector');
  out_vals := make_array (length (_vals), 'any');
  for (i := 0; i < length (_vals); i := i + 1)
    aset (out_vals, i, aref (_vals, i));
  return out_vals;
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_SUM (in _vals any)
{
  declare i integer;
  declare total double precision;
  if (_vals is null)
    return 0;
  if (not isarray (_vals))
    signal ('CY080', 'CYP_NUMERIC_VECTOR_SUM expects a numeric vector');
  total := 0;
  for (i := 0; i < length (_vals); i := i + 1)
    {
      if (not isnumeric (aref (_vals, i)))
        signal ('CY080', 'CYP_NUMERIC_VECTOR_SUM expects numeric-only values');
      total := total + cast (aref (_vals, i) as double precision);
    }
  return total;
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_AVG (in _vals any)
{
  if (_vals is null or length (_vals) = 0)
    return null;
  return DB.DBA.CYP_NUMERIC_VECTOR_SUM (_vals) / length (_vals);
}
;

create procedure DB.DBA.CYP_NUMERIC_VECTOR_RANGE (in _start any, in _end any, in _step any := 1)
{
  declare vals any;
  declare cur, stop_v, step_v double precision;

  if (not isnumeric (_start) or not isnumeric (_end) or not isnumeric (_step))
    signal ('CY080', 'CYP_NUMERIC_VECTOR_RANGE expects numeric start, end, and step');

  cur := cast (_start as double precision);
  stop_v := cast (_end as double precision);
  step_v := cast (_step as double precision);
  if (step_v = 0)
    signal ('CY080', 'CYP_NUMERIC_VECTOR_RANGE step must not be zero');

  vals := vector ();
  if (step_v > 0)
    {
      while (cur <= stop_v)
        {
          vals := vector_concat (vals, vector (cur));
          cur := cur + step_v;
        }
    }
  else
    {
      while (cur >= stop_v)
        {
          vals := vector_concat (vals, vector (cur));
          cur := cur + step_v;
        }
    }

  return DB.DBA.CYP_NUMERIC_VECTOR_NEW (vals);
}
;

-- LIST: vector ('LIST', vector (e0, e1, ...))

create procedure DB.DBA.CYP_LIST_IS (in _v any)
{
  if (not isarray (_v)) return 0;
  if (length (_v) < 2) return 0;
  if (aref (_v, 0) <> 'LIST') return 0;
  return 1;
}
;

create procedure DB.DBA.CYP_LIST_NEW (in _elems any)
{
  if (_elems is null)
    _elems := vector ();
  if (not isarray (_elems))
    signal ('CY080', 'CYP_LIST_NEW expects a vector of elements');
  return vector ('LIST', _elems);
}
;

create procedure DB.DBA.CYP_LIST_SIZE (in _l any)
{
  if (DB.DBA.CYP_LIST_IS (_l) = 0)
    signal ('CY080', 'CYP_LIST_SIZE expects a LIST cell');
  return length (aref (_l, 1));
}
;

create procedure DB.DBA.CYP_LIST_GET (in _l any, in _i integer)
{
  declare elems any;
  if (DB.DBA.CYP_LIST_IS (_l) = 0)
    signal ('CY080', 'CYP_LIST_GET expects a LIST cell');
  elems := aref (_l, 1);
  if (_i < 0 or _i >= length (elems))
    return null;
  return aref (elems, _i);
}
;

create procedure DB.DBA.CYP_LIST_APPEND (in _l any, in _v any)
{
  declare elems, out_elems any;
  declare i integer;
  if (DB.DBA.CYP_LIST_IS (_l) = 0)
    signal ('CY080', 'CYP_LIST_APPEND expects a LIST cell');
  elems := aref (_l, 1);
  out_elems := make_array (length (elems) + 1, 'any');
  for (i := 0; i < length (elems); i := i + 1)
    aset (out_elems, i, aref (elems, i));
  aset (out_elems, length (elems), _v);
  return vector ('LIST', out_elems);
}
;

create procedure DB.DBA.CYP_LIST_TO_VECTOR (in _l any)
{
  if (DB.DBA.CYP_LIST_IS (_l) = 0)
    signal ('CY080', 'CYP_LIST_TO_VECTOR expects a LIST cell');
  return aref (_l, 1);
}
;

-- Phase 14.3 — canonical name for list cardinality.  CYP_LIST_SIZE is
-- retained as a back-compat alias for callers that adopted the 14.1
-- name; both delegate to the same vector length.
create procedure DB.DBA.CYP_LIST_LENGTH (in _l any)
{
  if (DB.DBA.CYP_LIST_IS (_l) = 0)
    signal ('CY080', 'CYP_LIST_LENGTH expects a LIST cell');
  return length (aref (_l, 1));
}
;

-- openCypher slicing is half-open: l[start..end] yields elements from
-- index start (inclusive) up to end (exclusive).  Negative indices and
-- NULL bounds follow the openCypher 2024.3 rules: NULL start means 0,
-- NULL end means length(l), and out-of-range bounds clamp.
create procedure DB.DBA.CYP_LIST_SLICE (in _l any, in _start any, in _end any)
{
  declare elems, out_elems any;
  declare n, lo, hi, i integer;
  if (DB.DBA.CYP_LIST_IS (_l) = 0)
    signal ('CY080', 'CYP_LIST_SLICE expects a LIST cell');
  elems := aref (_l, 1);
  n := length (elems);
  if (_start is null) lo := 0; else lo := cast (_start as integer);
  if (_end   is null) hi := n; else hi := cast (_end   as integer);
  if (lo < 0) lo := n + lo;
  if (hi < 0) hi := n + hi;
  if (lo < 0) lo := 0;
  if (hi > n) hi := n;
  if (hi < lo) hi := lo;
  out_elems := make_array (hi - lo, 'any');
  for (i := lo; i < hi; i := i + 1)
    aset (out_elems, i - lo, aref (elems, i));
  return vector ('LIST', out_elems);
}
;

create procedure DB.DBA.CYP_LIST_CONCAT (in _a any, in _b any)
{
  declare ea, eb, out_elems any;
  declare na, nb, i integer;
  if (DB.DBA.CYP_LIST_IS (_a) = 0 or DB.DBA.CYP_LIST_IS (_b) = 0)
    signal ('CY080', 'CYP_LIST_CONCAT expects two LIST cells');
  ea := aref (_a, 1);
  eb := aref (_b, 1);
  na := length (ea);
  nb := length (eb);
  out_elems := make_array (na + nb, 'any');
  for (i := 0; i < na; i := i + 1) aset (out_elems, i, aref (ea, i));
  for (i := 0; i < nb; i := i + 1) aset (out_elems, na + i, aref (eb, i));
  return vector ('LIST', out_elems);
}
;

create procedure DB.DBA.CYP_REVERSE (in _v any)
{
  declare elems, out_elems any;
  declare i, n integer;
  declare s, out_s varchar;

  if (DB.DBA.CYP_LIST_IS (_v))
    {
      elems := aref (_v, 1);
      n := length (elems);
      out_elems := make_array (n, 'any');
      for (i := 0; i < n; i := i + 1)
        aset (out_elems, i, aref (elems, n - i - 1));
      return vector ('LIST', out_elems);
    }

  if (isarray (_v))
    {
      n := length (_v);
      out_elems := make_array (n, 'any');
      for (i := 0; i < n; i := i + 1)
        aset (out_elems, i, aref (_v, n - i - 1));
      return out_elems;
    }

  if (isstring (_v))
    {
      s := cast (_v as varchar);
      n := length (s);
      out_s := '';
      i := n - 1;
      while (i >= 0)
        {
          out_s := concat (out_s, subseq (s, i, i + 1));
          i := i - 1;
        }
      return out_s;
    }

  return null;
}
;

-- MAP: vector ('MAP', keys_vector, values_vector [, dictionary])
-- The optional dictionary is an internal lookup accelerator.  The
-- visible key vector remains authoritative for deterministic key order
-- and for result paths that cannot serialize dictionary references.

create procedure DB.DBA.CYP_MAP_IS (in _v any)
{
  if (not isarray (_v)) return 0;
  if (length (_v) < 3) return 0;
  if (aref (_v, 0) <> 'MAP') return 0;
  return 1;
}
;

create procedure DB.DBA.CYP_MAP_DICT_NEW (in _keys any, in _vals any)
{
  declare d any;
  declare i integer;

  declare exit handler for sqlstate '*'
    {
      return null;
    };

  d := dict_new (length (_keys) + 1);
  for (i := 0; i < length (_keys); i := i + 1)
    dict_put (d, cast (aref (_keys, i) as varchar), aref (_vals, i));
  return d;
}
;

create procedure DB.DBA.CYP_MAP_DICT (in _m any)
{
  if (DB.DBA.CYP_MAP_IS (_m) = 0)
    signal ('CY080', 'CYP_MAP_DICT expects a MAP cell');
  if (length (_m) > 3)
    return aref (_m, 3);
  return null;
}
;

create procedure DB.DBA.CYP_MAP_NEW (in _keys any, in _vals any)
{
  declare d any;
  declare i integer;
  if (_keys is null) _keys := vector ();
  if (_vals is null) _vals := vector ();
  if (not isarray (_keys) or not isarray (_vals))
    signal ('CY080', 'CYP_MAP_NEW expects two parallel vectors');
  if (length (_keys) <> length (_vals))
    signal ('CY080', 'CYP_MAP_NEW key/value vectors must be parallel');
  for (i := 0; i < length (_keys); i := i + 1)
    {
      if (not isstring (aref (_keys, i)))
        signal ('CY080', 'CYP_MAP_NEW expects string keys');
    }
  d := DB.DBA.CYP_MAP_DICT_NEW (_keys, _vals);
  if (d is not null)
    return vector ('MAP', _keys, _vals, d);
  return vector ('MAP', _keys, _vals);
}
;

create procedure DB.DBA.CYP_MAP_KEYS (in _m any)
{
  if (DB.DBA.CYP_MAP_IS (_m) = 0)
    signal ('CY080', 'CYP_MAP_KEYS expects a MAP cell');
  return aref (_m, 1);
}
;

-- Stub: collect predicate IRIs for a subject node IRI.
-- Returns a vector of property-key strings (IRIs).
create procedure DB.DBA.CYP_NODE_KEYS (in _iri varchar)
{
  declare keys, triples any;
  declare q varchar;
  keys := vector ();
  q := sprintf ('SPARQL SELECT DISTINCT ?p WHERE { GRAPH ?g { `iri(%s)` ?p ?o } }', _iri);
  exec (q, null, null, vector (), 0, triples);
  if (isarray (triples))
    {
      declare i integer;
      for (i := 0; i < length (triples); i := i + 1)
        {
          declare row any;
          row := aref (triples, i);
          if (isarray (row) and length (row) > 0)
            keys := vector_concat (keys, vector (aref (row, 0)));
        }
    }
  return keys;
}
;

-- Stub: collect property key-value pairs for a subject node IRI.
-- Returns a MAP cell (vector of keys, vector of values).
create procedure DB.DBA.CYP_NODE_PROPS (in _iri varchar)
{
  declare keys, vals, triples any;
  declare q varchar;
  keys := vector ();
  vals := vector ();
  q := sprintf ('SPARQL SELECT ?p ?o WHERE { GRAPH ?g { `iri(%s)` ?p ?o } }', _iri);
  exec (q, null, null, vector (), 0, triples);
  if (isarray (triples))
    {
      declare i integer;
      for (i := 0; i < length (triples); i := i + 1)
        {
          declare row any;
          row := aref (triples, i);
          if (isarray (row) and length (row) > 1)
            {
              keys := vector_concat (keys, vector (aref (row, 0)));
              vals := vector_concat (vals, vector (aref (row, 1)));
            }
        }
    }
  return vector ('MAP', keys, vals);
}
;

-- Split a string by a delimiter, returning a vector of substrings.
create procedure DB.DBA.CYP_SPLIT (in _str varchar, in _delim varchar)
{
  declare result any;
  declare pos, dlen, slen integer;
  declare idx integer;
  result := vector ();
  if (_str is null) return result;
  dlen := length (_delim);
  if (dlen = 0)
    {
      slen := length (_str);
      for (idx := 0; idx < slen; idx := idx + 1)
        result := vector_concat (result, vector (subseq (_str, idx, 1)));
      return result;
    }
  slen := length (_str);
  pos := 0;
  idx := strstr (_str, _delim);
  while (idx is not null)
    {
      result := vector_concat (result, vector (subseq (_str, pos, idx - pos)));
      pos := idx + dlen;
      if (pos >= slen)
        {
          result := vector_concat (result, vector (''));
          return result;
        }
      idx := strstr (subseq (_str, pos, slen - pos), _delim);
      if (idx is not null)
        idx := idx + pos;
    }
  result := vector_concat (result, vector (subseq (_str, pos, slen - pos)));
  return result;
}
;

create procedure DB.DBA.CYP_PERCENTILE_DISC (in _val any, in _pct any)
{
  return _val;
}
;

create procedure DB.DBA.CYP_PERCENTILE_CONT (in _val any, in _pct any)
{
  return _val;
}
;

-- Evaluate a quantifier (ALL/ANY/NONE/SINGLE) over a runtime vector.
-- Stub: returns 1 (true) for ALL/NONE/ANY, 0 for SINGLE on empty.
create procedure DB.DBA.CYP_QUANT_EVAL (in _kind varchar, in _list any,
    in _var_name varchar, in _pred_sparql varchar)
{
  if (_list is null or not isarray (_list) or length (_list) = 0)
    {
      if (_kind = 'ALL' or _kind = 'NONE') return 1;
      return 0;
    }
  if (_kind = 'ALL' or _kind = 'ANY' or _kind = 'NONE') return 1;
  if (_kind = 'SINGLE') return 1;
  return 0;
}
;

-- Evaluate a list comprehension over a runtime vector.
-- Stub: returns the input list unchanged.
create procedure DB.DBA.CYP_LISTCOMP_EVAL (in _list any,
    in _var_name varchar, in _where_sparql varchar, in _proj_sparql varchar)
{
  return _list;
}
;

create procedure DB.DBA.CYP_MAP_HAS_KEY (in _m any, in _k varchar)
{
  declare keys any;
  declare i integer;
  declare d, v any;
  if (DB.DBA.CYP_MAP_IS (_m) = 0)
    signal ('CY080', 'CYP_MAP_HAS_KEY expects a MAP cell');

  d := DB.DBA.CYP_MAP_DICT (_m);
  if (d is not null)
    {
      declare exit handler for sqlstate '*'
        {
          goto vector_fallback;
        };
      v := dict_get (d, _k, null);
      if (v is not null)
        return 1;
      goto vector_fallback;
    }

vector_fallback:
  keys := aref (_m, 1);
  for (i := 0; i < length (keys); i := i + 1)
    if (aref (keys, i) = _k) return 1;
  return 0;
}
;

create procedure DB.DBA.CYP_MAP_HAS (in _m any, in _k varchar)
{
  return DB.DBA.CYP_MAP_HAS_KEY (_m, _k);
}
;

create procedure DB.DBA.CYP_MAP_GET (in _m any, in _k varchar)
{
  declare keys any;
  declare i integer;
  declare d any;
  if (DB.DBA.CYP_MAP_IS (_m) = 0)
    signal ('CY080', 'CYP_MAP_GET expects a MAP cell');

  d := DB.DBA.CYP_MAP_DICT (_m);
  if (d is not null)
    {
      declare exit handler for sqlstate '*'
        {
          goto vector_fallback;
        };
      if (DB.DBA.CYP_MAP_HAS_KEY (_m, _k))
        return dict_get (d, _k, null);
      return null;
    }

vector_fallback:
  keys := aref (_m, 1);
  for (i := 0; i < length (keys); i := i + 1)
    if (aref (keys, i) = _k) return aref (aref (_m, 2), i);
  return null;
}
;

create procedure DB.DBA.CYP_MAP_TO_VECTOR (in _m any)
{
  declare keys, vals, out_vec any;
  declare i integer;
  if (DB.DBA.CYP_MAP_IS (_m) = 0)
    signal ('CY080', 'CYP_MAP_TO_VECTOR expects a MAP cell');
  keys := aref (_m, 1);
  vals := aref (_m, 2);
  out_vec := vector ();
  for (i := 0; i < length (keys); i := i + 1)
    out_vec := vector_concat (out_vec, vector (aref (keys, i), aref (vals, i)));
  return out_vec;
}
;

create procedure DB.DBA.CYP_MAP_PUT (in _m any, in _k varchar, in _v any)
{
  declare keys, vals, out_keys, out_vals any;
  declare i, found_key integer;
  if (DB.DBA.CYP_MAP_IS (_m) = 0)
    signal ('CY080', 'CYP_MAP_PUT expects a MAP cell');

  keys := aref (_m, 1);
  vals := aref (_m, 2);
  out_keys := vector ();
  out_vals := vector ();
  found_key := 0;

  for (i := 0; i < length (keys); i := i + 1)
    {
      out_keys := vector_concat (out_keys, vector (aref (keys, i)));
      if (aref (keys, i) = _k)
        {
          out_vals := vector_concat (out_vals, vector (_v));
          found_key := 1;
        }
      else
        out_vals := vector_concat (out_vals, vector (aref (vals, i)));
    }

  if (found_key = 0)
    {
      out_keys := vector_concat (out_keys, vector (_k));
      out_vals := vector_concat (out_vals, vector (_v));
    }

  return DB.DBA.CYP_MAP_NEW (out_keys, out_vals);
}
;

-- PATH: vector ('PATH', nodes_vector, rels_vector)
-- Invariant: length (nodes) = length (rels) + 1 (or both empty).

create procedure DB.DBA.CYP_PATH_IS (in _v any)
{
  if (not isarray (_v)) return 0;
  if (length (_v) < 3) return 0;
  if (aref (_v, 0) <> 'PATH') return 0;
  return 1;
}
;

create procedure DB.DBA.CYP_PATH_NEW (in _nodes any, in _rels any)
{
  if (_nodes is null) _nodes := vector ();
  if (_rels  is null) _rels  := vector ();
  if (not isarray (_nodes) or not isarray (_rels))
    signal ('CY080', 'CYP_PATH_NEW expects two vectors');
  if (length (_nodes) = 0 and length (_rels) = 0)
    return vector ('PATH', _nodes, _rels);
  if (length (_nodes) <> length (_rels) + 1)
    signal ('CY080', 'CYP_PATH_NEW invariant: len(nodes) = len(rels) + 1');
  return vector ('PATH', _nodes, _rels);
}
;

create procedure DB.DBA.CYP_PATH_NODES (in _p any)
{
  if (_p is null) return null;
  if (DB.DBA.CYP_PATH_IS (_p) = 0)
    signal ('CY080', 'CYP_PATH_NODES expects a PATH cell');
  return aref (_p, 1);
}
;

create procedure DB.DBA.CYP_PATH_RELS (in _p any)
{
  if (_p is null) return null;
  if (DB.DBA.CYP_PATH_IS (_p) = 0)
    signal ('CY080', 'CYP_PATH_RELS expects a PATH cell');
  return aref (_p, 2);
}
;

create procedure DB.DBA.CYP_PATH_LENGTH (in _p any)
{
  if (DB.DBA.CYP_PATH_IS (_p) = 0)
    signal ('CY080', 'CYP_PATH_LENGTH expects a PATH cell');
  return length (aref (_p, 2));
}
;

-- Append a (rel, dst_node) hop to a path.  Used by future
-- variable-length materialization: starting from a one-node path,
-- repeated calls extend it edge-by-edge while preserving the
-- len(nodes) = len(rels) + 1 invariant.
create procedure DB.DBA.CYP_PATH_APPEND_HOP (in _p any, in _rel any, in _dst any)
{
  declare nodes, rels, out_nodes, out_rels any;
  declare nn, nr, i integer;
  if (DB.DBA.CYP_PATH_IS (_p) = 0)
    signal ('CY080', 'CYP_PATH_APPEND_HOP expects a PATH cell');
  nodes := aref (_p, 1);
  rels  := aref (_p, 2);
  nn := length (nodes);
  nr := length (rels);
  if (nn = 0)
    signal ('CY080', 'CYP_PATH_APPEND_HOP cannot extend an empty path; build with at least one anchor node');
  out_nodes := make_array (nn + 1, 'any');
  out_rels  := make_array (nr + 1, 'any');
  for (i := 0; i < nn; i := i + 1) aset (out_nodes, i, aref (nodes, i));
  aset (out_nodes, nn, _dst);
  for (i := 0; i < nr; i := i + 1) aset (out_rels, i, aref (rels, i));
  aset (out_rels, nr, _rel);
  return vector ('PATH', out_nodes, out_rels);
}
;

-- Path-var metadata accessors.  The translator records one entry per
-- named path with shape
--   vector (name, hop_count, node_terms, rel_terms, has_varlen).
-- Callers should use the helpers below rather than indexing the
-- record directly so the layout can evolve without churning callers
-- (Phase 14.3 step 4).
create procedure DB.DBA.CYP_PATH_VAR_NEW (
  in _name varchar, in _hop_count integer,
  in _node_terms any, in _rel_terms any, in _has_varlen integer)
{
  return vector (_name, _hop_count, _node_terms, _rel_terms, _has_varlen);
}
;

create procedure DB.DBA.CYP_PATH_VAR_NAME (in _pv any)
{
  if (not isarray (_pv) or length (_pv) < 5)
    signal ('CY080', 'CYP_PATH_VAR_NAME expects a path-var record');
  return aref (_pv, 0);
}
;

create procedure DB.DBA.CYP_PATH_VAR_HOP_COUNT (in _pv any)
{
  if (not isarray (_pv) or length (_pv) < 5)
    signal ('CY080', 'CYP_PATH_VAR_HOP_COUNT expects a path-var record');
  return aref (_pv, 1);
}
;

create procedure DB.DBA.CYP_PATH_VAR_NODE_TERMS (in _pv any)
{
  if (not isarray (_pv) or length (_pv) < 5)
    signal ('CY080', 'CYP_PATH_VAR_NODE_TERMS expects a path-var record');
  return aref (_pv, 2);
}
;

create procedure DB.DBA.CYP_PATH_VAR_REL_TERMS (in _pv any)
{
  if (not isarray (_pv) or length (_pv) < 5)
    signal ('CY080', 'CYP_PATH_VAR_REL_TERMS expects a path-var record');
  return aref (_pv, 3);
}
;

create procedure DB.DBA.CYP_PATH_VAR_HAS_VARLEN (in _pv any)
{
  if (not isarray (_pv) or length (_pv) < 5)
    signal ('CY080', 'CYP_PATH_VAR_HAS_VARLEN expects a path-var record');
  return aref (_pv, 4);
}
;

-- ROW: vector ('ROW', aliases_vector, values_vector [, dictionary])
-- ROW mirrors MAP lookup behavior for projected result rows while
-- preserving alias order in the visible vector.

create procedure DB.DBA.CYP_ROW_IS (in _v any)
{
  if (not isarray (_v)) return 0;
  if (length (_v) < 3) return 0;
  if (aref (_v, 0) <> 'ROW') return 0;
  return 1;
}
;

create procedure DB.DBA.CYP_ROW_DICT_NEW (in _aliases any, in _vals any)
{
  declare d any;
  declare i integer;

  declare exit handler for sqlstate '*'
    {
      return null;
    };

  d := dict_new (length (_aliases) + 1);
  for (i := 0; i < length (_aliases); i := i + 1)
    dict_put (d, cast (aref (_aliases, i) as varchar), aref (_vals, i));
  return d;
}
;

create procedure DB.DBA.CYP_ROW_DICT (in _r any)
{
  if (DB.DBA.CYP_ROW_IS (_r) = 0)
    signal ('CY080', 'CYP_ROW_DICT expects a ROW cell');
  if (length (_r) > 3)
    return aref (_r, 3);
  return null;
}
;

create procedure DB.DBA.CYP_ROW_NEW (in _aliases any, in _vals any)
{
  declare d any;
  declare i integer;
  if (_aliases is null) _aliases := vector ();
  if (_vals    is null) _vals    := vector ();
  if (not isarray (_aliases) or not isarray (_vals))
    signal ('CY080', 'CYP_ROW_NEW expects two parallel vectors');
  if (length (_aliases) <> length (_vals))
    signal ('CY080', 'CYP_ROW_NEW alias/value vectors must be parallel');
  for (i := 0; i < length (_aliases); i := i + 1)
    {
      if (not isstring (aref (_aliases, i)))
        signal ('CY080', 'CYP_ROW_NEW expects string aliases');
    }
  d := DB.DBA.CYP_ROW_DICT_NEW (_aliases, _vals);
  if (d is not null)
    return vector ('ROW', _aliases, _vals, d);
  return vector ('ROW', _aliases, _vals);
}
;

create procedure DB.DBA.CYP_ROW_KEYS (in _r any)
{
  if (DB.DBA.CYP_ROW_IS (_r) = 0)
    signal ('CY080', 'CYP_ROW_KEYS expects a ROW cell');
  return aref (_r, 1);
}
;

create procedure DB.DBA.CYP_ROW_GET (in _r any, in _alias varchar)
{
  declare aliases any;
  declare i integer;
  declare d, v any;
  if (DB.DBA.CYP_ROW_IS (_r) = 0)
    signal ('CY080', 'CYP_ROW_GET expects a ROW cell');

  d := DB.DBA.CYP_ROW_DICT (_r);
  if (d is not null)
    {
      declare exit handler for sqlstate '*'
        {
          goto vector_fallback;
        };
      v := dict_get (d, _alias, null);
      if (v is not null)
        return v;
      goto vector_fallback;
    }

vector_fallback:
  aliases := aref (_r, 1);
  for (i := 0; i < length (aliases); i := i + 1)
    if (aref (aliases, i) = _alias) return aref (aref (_r, 2), i);
  return null;
}
;
