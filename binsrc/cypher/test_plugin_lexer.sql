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
--  openCypher: PL vs C Plugin Tokenizer Parity
--
--  The plugin tokenizer returns vector(type, value, pos, line, col).
--  CYP_TOKENIZE returns vector(type, value, pos). This test compares
--  the shared type/value/pos contract for a representative query corpus.
--

create procedure DB.DBA.OPENCYPHER_TOKEN_STREAM_SUMMARY (in _tokens any)
{
  declare _i, _n integer;
  declare _tok any;
  declare _out varchar;

  _out := '';
  _n := length (_tokens);
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      _tok := aref (_tokens, _i);
      if (_i > 0)
        _out := concat (_out, chr (10));
      _out := concat (_out,
                      cast (aref (_tok, 0) as varchar),
                      '|',
                      cast (aref (_tok, 1) as varchar),
                      '|',
                      cast (aref (_tok, 2) as varchar));
    }
  return _out;
}
;

create procedure DB.DBA.OPENCYPHER_RUN_LEXER_PARITY ()
{
  declare _corpus any;
  declare _i, _n, _pass, _fail integer;
  declare _q, _pl, _cp varchar;
  declare _results any;
  declare _ri integer;
  declare _out varchar;

  if (DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE () = 0)
    return 'SKIP: plugin not loaded - lexer parity test not applicable';

  _corpus := vector (
    'MATCH (n) RETURN n',
    'MATCH (n:Person {name: ''Alice'', age: 30}) RETURN n.name',
    'MATCH (a)-[:KNOWS]->(b) WHERE a.age >= 21 AND b.age < 50 RETURN a, b',
    'CREATE (n:Person:Employee {iri: <urn:test:n>, `rdfs:label`: "Alice"})',
    'PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (p:foaf:Person) RETURN p.foaf:name',
    'DEFINE input:inference "urn:rules" FROM NAMED <urn:g> MATCH (n) RETURN n',
    'GRAPH <urn:g> { MATCH (n) RETURN n }',
    'SERVICE <http://example.com/sparql> { MATCH (n) RETURN n }',
    'UNWIND [1, 2, 3] AS x RETURN x',
    'VALUES x { 1 2 3 } BIND (x + 1 AS y) RETURN y',
    'MATCH (n) WHERE n.name STARTS WITH ''A'' RETURN n SKIP 1 LIMIT 2',
    'MATCH (n) RETURN n OFFSET 5',
    'MATCH (n) WITH n OFFSET 5 RETURN n',
    'MATCH p = SHORTEST 2 GROUPS (a)-[:KNOWS+]->(b) RETURN p',
    'INSERT DATA { <urn:s> <urn:p> "label"@en }'
  );

  _n := length (_corpus);
  _pass := 0;
  _fail := 0;
  _results := vector ('--- Plugin/PL tokenizer parity ---');

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

      _pl := DB.DBA.OPENCYPHER_TOKEN_STREAM_SUMMARY (DB.DBA.CYP_TOKENIZE (_q));
      _cp := DB.DBA.OPENCYPHER_TOKEN_STREAM_SUMMARY (DB.DBA.OPENCYPHER_PLUGIN_TOKENIZE (_q));

      if (_pl = _cp)
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
          _results := vector_concat (_results, vector (concat ('  PL    : ', _pl)));
          _results := vector_concat (_results, vector (concat ('  PLUGIN: ', _cp)));
        }
      next_query:;
    }

  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results,
    vector (sprintf ('PLUGIN LEXER PARITY: passed %d/%d', _pass, _n)));

  _out := '';
  for (_ri := 0; _ri < length (_results); _ri := _ri + 1)
    _out := concat (_out, aref (_results, _ri), chr(10));

  if (_fail > 0)
    signal ('TEST', sprintf ('Plugin lexer parity failures: %d', _fail));

  return _out;
}
;

SELECT DB.DBA.OPENCYPHER_RUN_LEXER_PARITY ();
