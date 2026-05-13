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
--  openCypher: PL vs C Plugin Pipeline Parity
--
--  The plugin exposes parser, logical plan, and SPARQL generator BIFs.
--  This test compares their externally visible structures/results with the
--  established PL implementation.
--

create procedure DB.DBA.OPENCYPHER_TREE_SUMMARY (in _v any)
{
  declare _i integer;
  declare _out varchar;

  if (_v is null)
    return 'NULL';

  if (isarray (_v))
    {
      _out := '[';
      for (_i := 0; _i < length (_v); _i := _i + 1)
        {
          if (_i > 0)
            _out := concat (_out, ',');
          _out := concat (_out, DB.DBA.OPENCYPHER_TREE_SUMMARY (aref (_v, _i)));
        }
      return concat (_out, ']');
    }

  return concat ('"', cast (_v as varchar), '"');
}
;

create procedure DB.DBA.OPENCYPHER_PHASE8_NORMALIZE_WS (in _s varchar)
{
  declare _out varchar;
  declare _i, _n integer;
  declare _c, _prev integer;

  if (_s is null)
    return '';
  _n := length (_s);
  _out := '';
  _prev := 32;
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      _c := aref (_s, _i);
      if (_c = 32 or _c = 9 or _c = 10 or _c = 13)
        {
          if (_prev <> 32)
            {
              _out := concat (_out, ' ');
              _prev := 32;
            }
        }
      else
        {
          _out := concat (_out, chr (_c));
          _prev := _c;
        }
    }
  if (length (_out) > 0 and aref (_out, length (_out) - 1) = 32)
    _out := subseq (_out, 0, length (_out) - 1);
  if (length (_out) > 0 and aref (_out, 0) = 32)
    _out := subseq (_out, 1);
  return _out;
}
;

create procedure DB.DBA.OPENCYPHER_RUN_PHASE8_PARITY ()
{
  declare _corpus any;
  declare _i, _n, _pass, _fail integer;
  declare _q, _pl, _cp varchar;
  declare _results any;
  declare _ri integer;
  declare _out varchar;

  if (DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE () = 0)
    return 'SKIP: plugin not loaded - phase 8 parity test not applicable';

  _corpus := vector (
    'MATCH (n) RETURN n',
    'MATCH (n:Person {name: ''Alice'', age: 30}) RETURN n.name',
    'MATCH (a:Person)-[:KNOWS]->(b:Person) WHERE a.age >= 21 RETURN a.name, b.name',
    'OPTIONAL MATCH (n:Person)-[:WORKS_AT]->(c) RETURN n.name, c.name',
    'CREATE (n:Person {iri: <urn:phase8:n>, name: ''X''})',
    'MATCH (n) WITH n.city AS city RETURN city',
    'MATCH (n:Person) RETURN n.name ORDER BY n.name SKIP 1 LIMIT 5',
    'MATCH (n:Person) RETURN n UNION MATCH (n:Robot) RETURN n',
    'PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n:foaf:Person) RETURN n.foaf:name',
    'GRAPH <urn:g> { MATCH (n:Person) RETURN n.name AS name } RETURN name',
    'VALUES name {''Alice'', ''Bob''} BIND (name AS n2) RETURN n2',
    'ASK MATCH (n:Person)'
  );

  _n := length (_corpus);
  _pass := 0;
  _fail := 0;
  _results := vector ('--- Plugin pipeline parity ---');

  for (_i := 0; _i < _n; _i := _i + 1)
    {
      _q := aref (_corpus, _i);
      declare exit handler for sqlstate '*'
        {
          _fail := _fail + 1;
          _results := vector_concat (_results,
            vector (sprintf ('FAIL[%d] %s : exception %s %s',
                             _i, _q, __SQL_STATE, __SQL_MESSAGE)));
          goto next_query;
        };

      _pl := DB.DBA.OPENCYPHER_TREE_SUMMARY (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE (_q)));
      _cp := DB.DBA.OPENCYPHER_TREE_SUMMARY (DB.DBA.OPENCYPHER_PLUGIN_PARSE (_q, 0));
      if (_pl = _cp)
        _pass := _pass + 1;
      else
        {
          _fail := _fail + 1;
          _results := vector_concat (_results, vector (sprintf ('FAIL parse[%d] %s', _i, _q)));
          _results := vector_concat (_results, vector (concat ('  PL    : ', _pl)));
          _results := vector_concat (_results, vector (concat ('  PLUGIN: ', _cp)));
        }

      _pl := DB.DBA.OPENCYPHER_TREE_SUMMARY (
               DB.DBA.CYP_PLAN_BUILD (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE (_q))));
      _cp := DB.DBA.OPENCYPHER_TREE_SUMMARY (DB.DBA.OPENCYPHER_PLUGIN_PLAN (_q, 0));
      if (_pl = _cp)
        _pass := _pass + 1;
      else
        {
          _fail := _fail + 1;
          _results := vector_concat (_results, vector (sprintf ('FAIL plan[%d] %s', _i, _q)));
          _results := vector_concat (_results, vector (concat ('  PL    : ', _pl)));
          _results := vector_concat (_results, vector (concat ('  PLUGIN: ', _cp)));
        }

      _pl := DB.DBA.OPENCYPHER_PHASE8_NORMALIZE_WS (
               DB.DBA.CYP_TO_SPARQL (
                 DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE (_q)),
                 null));
      _cp := DB.DBA.OPENCYPHER_PHASE8_NORMALIZE_WS (
               DB.DBA.OPENCYPHER_PLUGIN_GEN_SPARQL (_q, null, 0));
      if (_pl = _cp)
        _pass := _pass + 1;
      else
        {
          _fail := _fail + 1;
          _results := vector_concat (_results, vector (sprintf ('FAIL sparql[%d] %s', _i, _q)));
          _results := vector_concat (_results, vector (concat ('  PL    : ', _pl)));
          _results := vector_concat (_results, vector (concat ('  PLUGIN: ', _cp)));
        }

      _results := vector_concat (_results, vector (sprintf ('PASS[%d] %s', _i, _q)));
      next_query:;
    }

  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results,
    vector (sprintf ('PLUGIN PIPELINE PARITY: passed %d/%d checks',
                     _pass, _n * 3)));

  _out := '';
  for (_ri := 0; _ri < length (_results); _ri := _ri + 1)
    _out := concat (_out, aref (_results, _ri), chr(10));

  if (_fail > 0)
    signal ('TEST', sprintf ('Plugin pipeline parity failures: %d', _fail));

  return _out;
}
;

SELECT DB.DBA.OPENCYPHER_RUN_PHASE8_PARITY ();
