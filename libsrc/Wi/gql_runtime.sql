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
--  openGQL: GQL for Virtuoso
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Runtime utilities: namespaces, URI generation, graph management
--

-- URIQA host from virtuoso.ini [URIQA] DefaultHost (via registry)
create procedure DB.DBA.GQL_URIQA_HOST ()
{
  declare host varchar;
  host := registry_get ('URIQADefaultHost');
  if (host is null or host = '')
    return 'localhost:8890';
  return host;
}
;

-- Ontology namespace: predicates, labels, types, classes
create procedure DB.DBA.GQL_NS ()
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/opengql/ontology#');
}
;

-- Entity/data namespace: nodes, edges, reification statements
create procedure DB.DBA.GQL_DATA_NS ()
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/opengql/data#');
}
;

-- Default graph for GQL data
create procedure DB.DBA.GQL_DEFAULT_GRAPH ()
{
  return 'urn:opengql:default';
}
;

-- Reification graph for edge properties
create procedure DB.DBA.GQL_REIF_GRAPH ()
{
  return 'urn:opengql:reif';
}
;

-- Generate a unique node URI (data namespace)
create procedure DB.DBA.GQL_NEW_NODE_URI ()
{
  return concat (DB.DBA.GQL_DATA_NS (), 'node_', cast (uuid () as varchar));
}
;

-- Generate a unique edge URI (data namespace, for reification)
create procedure DB.DBA.GQL_NEW_EDGE_URI ()
{
  return concat (DB.DBA.GQL_DATA_NS (), 'edge_', cast (uuid () as varchar));
}
;

-- Resolve a label name to a class URI
create procedure DB.DBA.GQL_LABEL_URI (in _name varchar)
{
  return concat (DB.DBA.GQL_NS (), _name);
}
;

-- Resolve a property name to a predicate URI
create procedure DB.DBA.GQL_PROP_URI (in _name varchar)
{
  return concat (DB.DBA.GQL_NS (), _name);
}
;

-- Resolve an edge type name to a predicate URI.
create procedure DB.DBA.GQL_EDGE_TYPE_URI (in _type varchar)
{
  return concat (DB.DBA.GQL_NS (), _type);
}
;

-- Convert UPPER_CASE or snake_case to camelCase
-- KNOWS -> knows, ACTED_IN -> actedIn, knows -> knows
-- Fixed loop structure avoids potential aref out-of-bounds at index n.
create procedure DB.DBA.GQL_TO_CAMEL_CASE (in _str varchar)
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
  for (i := 0; i < n; i := i + 1)
    {
      if (aref (_str, i) = 95)  -- 95 = '_'
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
  -- Emit the final segment after the loop
  if (prev < n)
    {
      part := subseq (_str, prev, n);
      if (is_first)
        result := lower (part);
      else
        result := concat (result, upper (subseq (part, 0, 1)), lower (subseq (part, 1)));
    }

  return result;
}
;

-- Version string for diagnostics
create procedure DB.DBA.GQL_VERSION ()
{
  return 'openGQL 0.6.0 - GQL for Virtuoso';
}
;

-- Register namespace prefixes for SPARQL integration
create procedure DB.DBA.GQL_REGISTER_NS ()
{
  DB.DBA.XML_SET_NS_DECL ('opengql', DB.DBA.GQL_NS (), 2);
  DB.DBA.XML_SET_NS_DECL ('opengqld', DB.DBA.GQL_DATA_NS (), 2);
}
;

-- Clear all GQL data in a graph
create procedure DB.DBA.GQL_RESET (in _graph varchar := null)
{
  if (_graph is null)
    _graph := DB.DBA.GQL_DEFAULT_GRAPH ();
  exec (sprintf ('SPARQL CLEAR GRAPH <%s>', _graph));
}
;
