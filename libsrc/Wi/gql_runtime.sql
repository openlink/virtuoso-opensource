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

----------------------------------------------------------------------
-- [GQL] virtuoso.ini section readers.
--
-- Three items, read on demand (no C recompile -- same mechanism the
-- [SPARQL] section uses via virtuoso_ini_item_value):
--
--   GQLHomeGraph            - IRI of the "home" property graph. When home
--                             mode is active and a query names no graph, its
--                             data lands here. Default: http://<host>/gql/graph
--   GQLHomeOntology         - base IRI of the property-graph vocabulary
--                             (labels, properties, edge types). Terms are
--                             joined to it with '/'. Default:
--                             http://<host>/gql/ontology
--   USEGQLHOMEPROPERTYGRAPH - 1/yes/on/true activates home-property-graph
--                             mode: a query with no FROM / USE GRAPH /
--                             USE ANY GRAPH clause implicitly binds the home
--                             graph (and the home ontology vocabulary),
--                             instead of the union default dataset. Default 0
--                             (off) -- absent config preserves prior behavior.
--
-- USE HOME_PROPERTY_GRAPH is the per-query modifier that binds the home
-- graph regardless of the flag.
----------------------------------------------------------------------

-- Read a single [GQL] ini item; empty/absent -> NULL.
create procedure DB.DBA.GQL_INI_ITEM (in _name varchar)
{
  declare v varchar;
  v := virtuoso_ini_item_value ('GQL', _name);
  if (v is null or v = '')
    return null;
  return v;
}
;

-- Home property graph IRI: [GQL] GQLHomeGraph, else host-derived.
create procedure DB.DBA.GQL_HOME_GRAPH ()
{
  declare v varchar;
  v := DB.DBA.GQL_INI_ITEM ('GQLHomeGraph');
  if (v is not null)
    return v;
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/gql/graph');
}
;

-- Home ontology base IRI: [GQL] GQLHomeOntology, else host-derived.
create procedure DB.DBA.GQL_HOME_ONTOLOGY ()
{
  declare v varchar;
  v := DB.DBA.GQL_INI_ITEM ('GQLHomeOntology');
  if (v is not null)
    return v;
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/gql/ontology');
}
;

-- Home-property-graph mode flag: [GQL] USEGQLHOMEPROPERTYGRAPH. Default off.
create procedure DB.DBA.GQL_HOME_MODE_ENABLED ()
{
  declare v varchar;
  v := DB.DBA.GQL_INI_ITEM ('USEGQLHOMEPROPERTYGRAPH');
  if (v is null)
    return 0;
  v := lower (v);
  if (v = '1' or v = 'yes' or v = 'on' or v = 'true')
    return 1;
  return 0;
}
;

-- Session default graph used when a query names no graph.
-- Home mode on  -> the real home graph (data lands there; writes succeed).
-- Home mode off -> the internal sentinel (union default dataset for reads,
--                  SP031 for un-graphed writes) -- the prior behavior.
create procedure DB.DBA.GQL_SESSION_DEFAULT_GRAPH ()
{
  if (DB.DBA.GQL_HOME_MODE_ENABLED ())
    return DB.DBA.GQL_HOME_GRAPH ();
  return DB.DBA.GQL_DEFAULT_GRAPH ();
}
;

-- Ontology namespace: predicates, labels, types, classes.
-- The home ontology (from [GQL] GQLHomeOntology, else host-derived) is the
-- single vocabulary namespace; terms are joined to it with '/'. The [GQL]
-- mode flag and USE HOME_PROPERTY_GRAPH govern only graph binding, not the
-- vocabulary.
create procedure DB.DBA.GQL_NS ()
{
  return concat (DB.DBA.GQL_HOME_ONTOLOGY (), '/');
}
;

-- Entity/data namespace: nodes, edges, reification statements
create procedure DB.DBA.GQL_DATA_NS ()
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/gql/data/');
}
;

-- Property-graph graph IRI from a bare graph name.
create procedure DB.DBA.GQL_PG_GRAPH_IRI (in _name varchar)
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/pgraph/', _name);
}
;

-- Property-graph ontology namespace from a bare graph name.
create procedure DB.DBA.GQL_PG_ONTOLOGY_NS (in _name varchar)
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/pgraph/', _name, '/ontology#');
}
;

-- Property-graph data namespace from a bare graph name.
create procedure DB.DBA.GQL_PG_DATA_NS (in _name varchar)
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/pgraph/', _name, '#');
}
;

-- Context-aware ontology namespace: reads 'ontology_ns' from ctx,
-- falls back to GQL_NS() when absent (plain USE GRAPH).
create procedure DB.DBA.GQL_NS_CTX (inout _ctx any)
{
  declare ns varchar;
  ns := DB.DBA.GQL_CTX_GET (_ctx, 'ontology_ns');
  if (ns is not null and ns <> '')
    return ns;
  return DB.DBA.GQL_NS ();
}
;

-- Context-aware data namespace: reads 'data_ns' from ctx,
-- falls back to GQL_DATA_NS() when absent (plain USE GRAPH).
create procedure DB.DBA.GQL_DATA_NS_CTX (inout _ctx any)
{
  declare ns varchar;
  ns := DB.DBA.GQL_CTX_GET (_ctx, 'data_ns');
  if (ns is not null and ns <> '')
    return ns;
  return DB.DBA.GQL_DATA_NS ();
}
;

-- Default graph for GQL data.
-- In property-graph mode the sentinel is http://<host>/pgraph#default;
-- it still means "no graph named -- use union default dataset for reads,
-- SP031 for un-graphed writes", exactly as the old urn:opengql:default did.
create procedure DB.DBA.GQL_DEFAULT_GRAPH ()
{
  return concat ('http://', DB.DBA.GQL_URIQA_HOST (), '/pgraph#default');
}
;

-- Reification graph for edge properties (DEAD CODE -- reification is inline).
-- Retained for API compatibility; not called by any code path.
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

-- Generate a unique node URI using a ctx-aware data namespace.
create procedure DB.DBA.GQL_NEW_NODE_URI_CTX (inout _ctx any)
{
  return concat (DB.DBA.GQL_DATA_NS_CTX (_ctx), 'node_', cast (uuid () as varchar));
}
;

-- Generate a unique edge URI (data namespace, for reification)
create procedure DB.DBA.GQL_NEW_EDGE_URI ()
{
  return concat (DB.DBA.GQL_DATA_NS (), 'edge_', cast (uuid () as varchar));
}
;

-- Generate a unique edge URI using a ctx-aware data namespace.
create procedure DB.DBA.GQL_NEW_EDGE_URI_CTX (inout _ctx any)
{
  return concat (DB.DBA.GQL_DATA_NS_CTX (_ctx), 'edge_', cast (uuid () as varchar));
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
  DB.DBA.XML_SET_NS_DECL ('gql', DB.DBA.GQL_NS (), 2);
  DB.DBA.XML_SET_NS_DECL ('gqld', DB.DBA.GQL_DATA_NS (), 2);
}
;

-- Clear all GQL data in a graph
create procedure DB.DBA.GQL_RESET (in _graph varchar := null)
{
  if (_graph is null)
    _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();
  exec (sprintf ('SPARQL CLEAR GRAPH <%s>', _graph));
}
;

----------------------------------------------------------------------
-- gqlc C plugin capability probe.
--
-- The gqlc plugin (loaded via "Load8 = plain, gqlc" in virtuoso.ini)
-- registers the Unicode-normalization and percentile BIFs used by
-- NORMALIZE / IS NORMALIZED / PERCENTILE_CONT / PERCENTILE_DISC. It can be
-- absent (built with --disable-gqlc, ICU not found, or the Load8 line
-- missing). GQL_HAS_GQLC probes for it once per connection (via exec, so the
-- BIF name is not resolved at this procedure's compile time — the probe
-- itself loads fine on a plugin-less server) and caches the answer on the
-- connection. GQL_REQUIRE_GQLC raises a clear GQ103 when the feature is used
-- but the plugin is missing, instead of a raw "unknown function" error.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_HAS_GQLC ()
{
  declare cached any;
  declare st, msg varchar;
  declare m, d any;
  cached := connection_get ('__gql_has_gqlc');
  if (cached = '1') return 1;
  if (cached = '0') return 0;
  st := '00000'; msg := '';
  exec ('sparql select (bif:GQL_IS_NORMALIZED(''a'') as ?x) where { filter (1=1) }',
    st, msg, vector (), 0, m, d);
  if (st = '00000')
    { connection_set ('__gql_has_gqlc', '1'); return 1; }
  connection_set ('__gql_has_gqlc', '0');
  return 0;
}
;

create procedure DB.DBA.GQL_REQUIRE_GQLC (in _feature varchar)
{
  if (not DB.DBA.GQL_HAS_GQLC ())
    signal ('GQ103',
      concat (_feature, ' requires the gqlc plugin, which is not loaded. ',
        'Build with --enable-gqlc (requires ICU) and add a "Load = plain, gqlc" ',
        'entry to the [Plugins] section of virtuoso.ini.'));
}
;
