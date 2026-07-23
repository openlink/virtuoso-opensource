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
--  openGQL: GQL for Virtuoso - Golden result-value tests
--
--  Unlike test_gql_translate.sql (which checks the *translated SPARQL text*),
--  this suite executes GQL queries end-to-end and asserts the *returned row
--  values* against hand-authored expected results. It is the local,
--  self-contained golden-row regression net for translation correctness — a
--  translation change that alters a computed answer fails here loudly.
--
--  Expected values are written in Virtuoso's SPARQL-over-RDF result
--  representation (the target semantics of the translator): booleans as
--  1/0, absent/UNDEF as 'null', IRIs as <...>. Rows are compared as a
--  multiset (canonical sort) unless the query has ORDER BY, in which case
--  row order is preserved.
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_golden.sql
--  Requires all GQL modules loaded (see gql_load.sql).
--

ECHO BOTH "STARTED: GQL golden result-value tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

----------------------------------------------------------------------
-- Serialization + assertion helpers
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GOLD_VAL (in v any)
{
  if (v is null) return 'null';
  if (isiri_id (v)) return concat ('<', coalesce (id_to_iri (v), cast (v as varchar)), '>');
  if (isinteger (v)) return cast (v as varchar);
  if (isstring (v)) return v;
  return cast (v as varchar);
}
;

-- Lexical insertion sort for a small varchar vector (result sets here are
-- tiny). Used to canonicalize row order for multiset comparison — the
-- built-in gvector_digit_sort only accepts integer/IRI_ID keys.
create procedure DB.DBA.GQL_GOLD_SORT (in v any)
{
  declare i, j, n integer;
  declare tmp varchar;
  n := length (v);
  for (i := 1; i < n; i := i + 1)
    {
      tmp := aref (v, i);
      j := i - 1;
      while (j >= 0 and aref (v, j) > tmp)
        { aset (v, j + 1, aref (v, j)); j := j - 1; }
      aset (v, j + 1, tmp);
    }
  return v;
}
;

-- Serialize a result set (vector of row-vectors) into a canonical string.
-- _ordered = 0 -> compare as a multiset (rows are sorted); 1 -> preserve
-- the query's row order (for ORDER BY).
create procedure DB.DBA.GQL_GOLD_SER (in rows any, in _ordered integer := 0)
{
  declare i, j integer;
  declare rowstrs any;
  declare rs varchar;
  if (rows is null) return '<null>';
  rowstrs := vector ();
  for (i := 0; i < length (rows); i := i + 1)
    {
      rs := '';
      for (j := 0; j < length (aref (rows, i)); j := j + 1)
        rs := concat (rs, case when j > 0 then '|' else '' end,
                      DB.DBA.GQL_GOLD_VAL (aref (aref (rows, i), j)));
      rowstrs := vector_concat (rowstrs, vector (rs));
    }
  if (not _ordered and length (rowstrs) > 1)
    rowstrs := DB.DBA.GQL_GOLD_SORT (rowstrs);
  rs := '';
  for (i := 0; i < length (rowstrs); i := i + 1)
    rs := concat (rs, case when i > 0 then ' ; ' else '' end, aref (rowstrs, i));
  return concat ('[', rs, ']');
}
;

create procedure DB.DBA.GQL_GOLD_ASSERT (
  in _name varchar, in _gql varchar, in _graph varchar,
  in _expected varchar, in _ordered integer,
  inout _pass integer, inout _fail integer)
{
  declare _actual varchar;
  {
    declare exit handler for sqlstate '*'
      {
        _fail := _fail + 1;
        dbg_obj_print (concat (_name, ' FAIL: signaled ', __SQL_STATE, ' ', __SQL_MESSAGE));
        return;
      };
    _actual := DB.DBA.GQL_GOLD_SER (DB.DBA.GQL_RUN (_gql, _graph), _ordered);
    if (_actual = _expected)
      { _pass := _pass + 1; }
    else
      {
        _fail := _fail + 1;
        dbg_obj_print (concat (_name, ' FAIL: expected ', _expected, ' got ', _actual));
      }
  }
}
;

----------------------------------------------------------------------
-- Fixture: a tiny Person graph
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GOLD_SETUP ()
{
  set isolation='serializable';
  sparql clear graph <urn:gql:gold>;
  commit work;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: "Alice", age: 30 })', 'urn:gql:gold');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: "Bob", age: 25 })', 'urn:gql:gold');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: "Carol", age: 40 })', 'urn:gql:gold');
  commit work;
}
;

----------------------------------------------------------------------
-- Golden cases
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GOLDEN_TESTS ()
{
  declare _pass, _fail integer;
  _pass := 0; _fail := 0;

  DB.DBA.GQL_GOLD_SETUP ();

  -- Expression / literal computation (no graph)
  DB.DBA.GQL_GOLD_ASSERT ('G01 arithmetic',
    'RETURN 1 + 2 AS s, 3 * 4 AS p', null, '[3|12]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G02 and false',
    'RETURN true AND false AS x', null, '[0]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G03 and null',
    'RETURN true AND null AS x', null, '[null]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G04 or',
    'RETURN false OR true AS x', null, '[1]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G05 comparison',
    'RETURN 5 > 3 AS a, 2 <= 2 AS b', null, '[1|1]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G06 coalesce+abs',
    'RETURN coalesce(null, 7) AS c, abs(-5) AS a', null, '[7|5]', 0, _pass, _fail);

  -- List value functions over the Virtuoso vector form (P2-4)
  DB.DBA.GQL_GOLD_ASSERT ('GL1 cardinality',
    'RETURN cardinality([1,2,3]) AS c', null, '[3]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('GL2 size',
    'RETURN size([1,2,3,4]) AS c', null, '[4]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('GL3 trim first n',
    'RETURN cardinality(trim([1,2,3,4], 2)) AS c', null, '[2]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('GL4 trim n<=0 empty',
    'RETURN cardinality(trim([1,2,3], 0)) AS c', null, '[0]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('GL5 trim n>=len whole',
    'RETURN cardinality(trim([1,2,3], 9)) AS c', null, '[3]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G07 string funcs',
    'RETURN upper("ab") AS u, "a" || "b" AS c', null, '[AB|ab]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G08 case',
    'RETURN CASE WHEN 1 > 0 THEN "y" ELSE "n" END AS c', null, '[y]', 0, _pass, _fail);

  -- Aggregation over the fixture graph
  DB.DBA.GQL_GOLD_ASSERT ('G09 count',
    'MATCH (p:Person) RETURN count(p) AS c', 'urn:gql:gold', '[3]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G10 sum',
    'MATCH (p:Person) RETURN sum(p.age) AS s', 'urn:gql:gold', '[95]', 0, _pass, _fail);
  DB.DBA.GQL_GOLD_ASSERT ('G11 min/max',
    'MATCH (p:Person) RETURN min(p.age) AS lo, max(p.age) AS hi', 'urn:gql:gold', '[25|40]', 0, _pass, _fail);

  -- Graph pattern matching + filter (unordered multiset)
  DB.DBA.GQL_GOLD_ASSERT ('G12 filter',
    'MATCH (p:Person) WHERE p.age > 28 RETURN p.name AS n', 'urn:gql:gold', '[Alice ; Carol]', 0, _pass, _fail);

  -- ORDER BY (row order preserved: Bob 25, Alice 30, Carol 40)
  DB.DBA.GQL_GOLD_ASSERT ('G13 order by',
    'MATCH (p:Person) RETURN p.name AS n ORDER BY p.age', 'urn:gql:gold', '[Bob ; Alice ; Carol]', 1, _pass, _fail);

  -- Empty result
  DB.DBA.GQL_GOLD_ASSERT ('G14 empty',
    'MATCH (p:Nobody) RETURN p AS x', 'urn:gql:gold', '[]', 0, _pass, _fail);

  sparql clear graph <urn:gql:gold>;
  commit work;

  dbg_obj_print (concat ('GOLDEN PASS: ', cast (_pass as varchar), '  FAIL: ', cast (_fail as varchar)));
  if (_fail > 0)
    signal ('23000', concat (cast (_fail as varchar), ' golden test(s) failed'));
  return _pass;
}
;

SELECT DB.DBA.GQL_GOLDEN_TESTS ();
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL golden result-value tests\n";

ECHO BOTH "COMPLETED: GQL golden result-value tests\n";
