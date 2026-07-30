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
--  openGQL: GQL for Virtuoso - Runtime Smoke Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_runtime.sql
--

create procedure DB.DBA.GQL_RUNTIME_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _val, _val2 varchar;
  declare _host varchar;

  _pass := 0;
  _fail := 0;
  _total := 0;
  _results := vector ();

  -- RT1: GQL_URIQA_HOST returns non-null, non-empty
  _total := _total + 1;
  _host := DB.DBA.GQL_URIQA_HOST ();
  if (_host is not null and length (_host) > 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT1 PASS: GQL_URIQA_HOST non-null non-empty')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('RT1 FAIL: GQL_URIQA_HOST returned null or empty')); }

  -- RT2: GQL_URIQA_HOST contains ':'
  _total := _total + 1;
  if (strstr (_host, ':') is not null or strstr (_host, 'localhost') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT2 PASS: GQL_URIQA_HOST contains host pattern')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('RT2 FAIL: GQL_URIQA_HOST missing expected pattern')); }

  -- RT3: GQL_NS starts with http:// and ends with opengql/ontology#
  _total := _total + 1;
  _val := DB.DBA.GQL_NS ();
  if (subseq (_val, 0, 7) = 'http://' and strstr (_val, 'opengql/ontology#') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT3 PASS: GQL_NS well-formed')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT3 FAIL: GQL_NS = ', _val))); }

  -- RT4: GQL_DATA_NS starts with http:// and ends with opengql/data#
  _total := _total + 1;
  _val := DB.DBA.GQL_DATA_NS ();
  if (subseq (_val, 0, 7) = 'http://' and strstr (_val, 'opengql/data#') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT4 PASS: GQL_DATA_NS well-formed')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT4 FAIL: GQL_DATA_NS = ', _val))); }

  -- RT5: GQL_DEFAULT_GRAPH = urn:opengql:default
  _total := _total + 1;
  _val := DB.DBA.GQL_DEFAULT_GRAPH ();
  if (_val = 'urn:opengql:default')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT5 PASS: GQL_DEFAULT_GRAPH correct')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT5 FAIL: GQL_DEFAULT_GRAPH = ', _val))); }

  -- RT6: GQL_REIF_GRAPH = urn:opengql:reif
  _total := _total + 1;
  _val := DB.DBA.GQL_REIF_GRAPH ();
  if (_val = 'urn:opengql:reif')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT6 PASS: GQL_REIF_GRAPH correct')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT6 FAIL: GQL_REIF_GRAPH = ', _val))); }

  -- RT7: GQL_NEW_NODE_URI starts with data NS and contains node_
  _total := _total + 1;
  _val := DB.DBA.GQL_NEW_NODE_URI ();
  _val2 := DB.DBA.GQL_DATA_NS ();
  if (subseq (_val, 0, length (_val2)) = _val2 and strstr (_val, 'node_') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT7 PASS: GQL_NEW_NODE_URI well-formed')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT7 FAIL: GQL_NEW_NODE_URI = ', _val))); }

  -- RT8: GQL_NEW_EDGE_URI starts with data NS and contains edge_
  _total := _total + 1;
  _val := DB.DBA.GQL_NEW_EDGE_URI ();
  if (subseq (_val, 0, length (_val2)) = _val2 and strstr (_val, 'edge_') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT8 PASS: GQL_NEW_EDGE_URI well-formed')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT8 FAIL: GQL_NEW_EDGE_URI = ', _val))); }

  -- RT9: GQL_NEW_NODE_URI produces unique values
  _total := _total + 1;
  _val := DB.DBA.GQL_NEW_NODE_URI ();
  _val2 := DB.DBA.GQL_NEW_NODE_URI ();
  if (_val <> _val2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT9 PASS: GQL_NEW_NODE_URI produces unique values')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('RT9 FAIL: GQL_NEW_NODE_URI produced duplicate')); }

  -- RT10: GQL_LABEL_URI('Person') ends with Person
  _total := _total + 1;
  _val := DB.DBA.GQL_LABEL_URI ('Person');
  if (strstr (_val, 'Person') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT10 PASS: GQL_LABEL_URI correct')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT10 FAIL: GQL_LABEL_URI = ', _val))); }

  -- RT11: GQL_PROP_URI('name') ends with name
  _total := _total + 1;
  _val := DB.DBA.GQL_PROP_URI ('name');
  if (strstr (_val, 'name') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT11 PASS: GQL_PROP_URI correct')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT11 FAIL: GQL_PROP_URI = ', _val))); }

  -- RT12: GQL_EDGE_TYPE_URI maps an edge type verbatim under the ontology NS.
  -- (camelCasing KNOWS->knows is an opt-in mode via GQL_CTX_FORCE_CAMELCASE,
  -- not the default; the bare resolver concatenates NS + type unchanged, the
  -- same as GQL_LABEL_URI / GQL_PROP_URI.)
  _total := _total + 1;
  _val := DB.DBA.GQL_EDGE_TYPE_URI ('KNOWS');
  if (subseq (_val, 0, length (DB.DBA.GQL_NS ())) = DB.DBA.GQL_NS () and strstr (_val, 'KNOWS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT12 PASS: GQL_EDGE_TYPE_URI verbatim mapping')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT12 FAIL: GQL_EDGE_TYPE_URI = ', _val))); }

  -- RT13: GQL_TO_CAMEL_CASE('ACTED_IN') = actedIn
  _total := _total + 1;
  _val := DB.DBA.GQL_TO_CAMEL_CASE ('ACTED_IN');
  if (_val = 'actedIn')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT13 PASS: ACTED_IN -> actedIn')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT13 FAIL: expected actedIn, got ', _val))); }

  -- RT14: GQL_TO_CAMEL_CASE('KNOWS') = knows (no underscore, just lower)
  _total := _total + 1;
  _val := DB.DBA.GQL_TO_CAMEL_CASE ('KNOWS');
  if (_val = 'knows')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT14 PASS: KNOWS -> knows')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT14 FAIL: expected knows, got ', _val))); }

  -- RT15: GQL_TO_CAMEL_CASE('alreadyCamel') = alreadycamel
  _total := _total + 1;
  _val := DB.DBA.GQL_TO_CAMEL_CASE ('alreadyCamel');
  if (_val = 'alreadycamel')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT15 PASS: alreadyCamel -> alreadycamel')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT15 FAIL: expected alreadycamel, got ', _val))); }

  -- RT16: GQL_VERSION contains openGQL
  _total := _total + 1;
  _val := DB.DBA.GQL_VERSION ();
  if (strstr (_val, 'openGQL') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('RT16 PASS: GQL_VERSION contains openGQL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('RT16 FAIL: GQL_VERSION = ', _val))); }

  -- RT17: GQL_REGISTER_NS does not error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      {
        _fail := _fail + 1;
        _results := vector_concat (_results, vector ('RT17 FAIL: GQL_REGISTER_NS signaled error'));
        goto rt17_done;
      };
    DB.DBA.GQL_REGISTER_NS ();
    _pass := _pass + 1;
    _results := vector_concat (_results, vector ('RT17 PASS: GQL_REGISTER_NS succeeded'));
  }
  rt17_done:;

  -- RT18: GQL_RESET does not error on default graph
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      {
        _fail := _fail + 1;
        _results := vector_concat (_results, vector ('RT18 FAIL: GQL_RESET signaled error'));
        goto rt18_done;
      };
    DB.DBA.GQL_RESET ();
    _pass := _pass + 1;
    _results := vector_concat (_results, vector ('RT18 PASS: GQL_RESET succeeded'));
  }
  rt18_done:;

  -- Summary
  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results, vector (concat ('TOTAL: ', cast (_total as varchar))));
  _results := vector_concat (_results, vector (concat ('PASS:  ', cast (_pass as varchar))));
  _results := vector_concat (_results, vector (concat ('FAIL:  ', cast (_fail as varchar))));

  declare i integer;
  for (i := 0; i < length (_results); i := i + 1)
    dbg_obj_print (aref (_results, i));

  if (_fail > 0)
    signal ('23000', concat (cast (_fail as varchar), ' test(s) failed'));
}
;

SELECT DB.DBA.GQL_RUNTIME_TESTS ();
