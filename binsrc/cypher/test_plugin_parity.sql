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
--  openCypher: PL vs C Plugin SPARQL Translation Parity
--
--  For each query in a fixed corpus, compute SPARQL via two paths:
--    1. PL path:     CYP_TO_SPARQL (CYP_PARSE (CYP_TOKENIZE (q)), g)
--    2. Plugin path: OPENCYPHER_PLUGIN_TO_SPARQL (q, g, NULL, 0)  [BIF]
--
--  Both strings are whitespace-normalized and compared byte-for-byte.
--  When the plugin is not loaded, the script prints SKIP and exits 0.
--

create procedure DB.DBA.OPENCYPHER_NORMALIZE_WS (in _s varchar)
{
  -- Trim ends, collapse any run of whitespace (space/tab/CR/LF) to one space.
  declare _out varchar;
  declare _i, _n integer;
  declare _c, _prev integer;

  if (_s is null)
    return '';
  _n := length (_s);
  _out := '';
  _prev := 32;  -- treat leading run as already-collapsed
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
  -- Trim trailing space
  if (length (_out) > 0 and aref (_out, length (_out) - 1) = 32)
    _out := subseq (_out, 0, length (_out) - 1);
  -- Trim leading space (collapsed run could only produce one)
  if (length (_out) > 0 and aref (_out, 0) = 32)
    _out := subseq (_out, 1);
  return _out;
}
;

create procedure DB.DBA.OPENCYPHER_PL_TRANSLATE (in _q varchar, in _g varchar)
{
  declare _tok, _ast any;
  _tok := DB.DBA.CYP_TOKENIZE (_q);
  _ast := DB.DBA.CYP_PARSE (_tok);
  return DB.DBA.CYP_TO_SPARQL (_ast, _g);
}
;

create procedure DB.DBA.OPENCYPHER_RUN_PARITY ()
{
  declare _corpus any;
  declare _i, _n, _pass, _fail integer;
  declare _q, _pl, _cp, _pl_n, _cp_n varchar;
  declare _results any;
  declare _ri integer;
  declare _out varchar;

  if (DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE () = 0)
    return 'SKIP: plugin not loaded - parity test not applicable';

  -- Reset graph so any side-effecting helpers in the PL path stay clean.
  DB.DBA.CYPHER_RESET ();

  _corpus := vector (
    'MATCH (n) RETURN n',
    'MATCH (n:Person) RETURN n.name',
    'MATCH (n:Person) WHERE n.age > 30 RETURN n.name',
    'MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN a.name, b.name',
    'MATCH (n:Person) RETURN n.name ORDER BY n.name SKIP 1 LIMIT 5',
    'MATCH (n) WITH n.city AS city RETURN city',
    'OPTIONAL MATCH (n:Person)-[:WORKS_AT]->(c) RETURN n.name, c.name',
    'CREATE (n:Person {iri: <urn:parity:n>, name: ''X''})',
    'MATCH (a:Person {name:''A''}), (b:Person {name:''B''}) CREATE (a)-[:R]->(b)',
    'MATCH (n:Person) RETURN n UNION MATCH (n:Robot) RETURN n',
    'PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n:foaf:Person) RETURN n.foaf:name'
  );

  _n := length (_corpus);
  _pass := 0;
  _fail := 0;
  _results := vector ('--- Plugin/PL SPARQL parity ---');

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

      _pl := DB.DBA.OPENCYPHER_PL_TRANSLATE (_q, null);
      _cp := DB.DBA.OPENCYPHER_PLUGIN_TO_SPARQL (_q, null, null, 0);
      _pl_n := DB.DBA.OPENCYPHER_NORMALIZE_WS (_pl);
      _cp_n := DB.DBA.OPENCYPHER_NORMALIZE_WS (_cp);

      if (_pl_n = _cp_n)
        {
          _pass := _pass + 1;
          _results := vector_concat (_results,
            vector (sprintf ('PASS[%d] %s', _i, _q)));
        }
      else
        {
          _fail := _fail + 1;
          _results := vector_concat (_results,
            vector (sprintf ('FAIL[%d] %s', _i, _q)));
          _results := vector_concat (_results,
            vector (sprintf ('  PL    : %s', _pl_n)));
          _results := vector_concat (_results,
            vector (sprintf ('  PLUGIN: %s', _cp_n)));
        }
      next_query:;
    }

  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results,
    vector (sprintf ('PLUGIN PARITY: passed %d/%d', _pass, _n)));

  _out := '';
  for (_ri := 0; _ri < length (_results); _ri := _ri + 1)
    _out := concat (_out, aref (_results, _ri), chr(10));

  if (_fail > 0)
    signal ('TEST', sprintf ('Plugin parity failures: %d', _fail));

  return _out;
}
;

SELECT DB.DBA.OPENCYPHER_RUN_PARITY ();
