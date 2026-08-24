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
--  openGQL: GQL for Virtuoso - Bootstrap / Post-Install Hooks
--
--  Copyright (C) 1998-2026 OpenLink Software
--

create procedure DB.DBA.GQL_BOOTSTRAP_ENDPOINT_GRANTS ()
{
  -- Intentionally left blank.
  -- Endpoint grants are managed manually by the DBA.
  return;
}
;

----------------------------------------------------------------------
-- Node IRI minting
-- Generates a unique IRI for a new node, preferring a deterministic
-- scheme (label+property driven) when labels are present, falling back
-- to a random IRI for unlabeled nodes.
-- IRI scheme: <urn:opengql:node:<label>/<random>
----------------------------------------------------------------------

create procedure DB.DBA.GQL_MINT_NODE_IRI (in _graph varchar, in _labels any, in _props any)
{
  declare label_slug, random_part varchar;
  declare i integer;

  label_slug := '';
  if (_labels is not null and length (_labels) > 0)
    {
      for (i := 0; i < length (_labels); i := i + 1)
        label_slug := concat (label_slug, aref (_labels, i), '/');
    }
  else
    label_slug := '_/';

  -- Use a random IRI suffix for uniqueness; the label prefix makes
  -- IRIs human-readable while the random part prevents collisions.
  return DB.DBA.GQL_NEW_NODE_URI ();
}
;

DB.DBA.GQL_REGISTER_NS ()
;
DB.DBA.GQL_BOOTSTRAP_ENDPOINT_GRANTS ()
;

----------------------------------------------------------------------
-- Schema resolution helper for §17 schema references
----------------------------------------------------------------------

create procedure DB.DBA.GQL_SCHEMA_RESOLVE (in _name varchar)
{
  -- Currently resolves schema names to their IRI form.
  -- In a future phase, this will query the GQL_SCHEMA catalog table
  -- to resolve absolute and relative path references.
  if (_name is null)
    return DB.DBA.GQL_DEFAULT_GRAPH ();
  if (strstr (_name, '://') is not null)
    return _name;
  return concat (DB.DBA.GQL_NS (), 'schema/', _name);
}
;

----------------------------------------------------------------------
-- Graph type enforcement feature flag.
--
-- Returns 0 by design: graph types declared via CREATE GRAPH TYPE are
-- recorded in the catalog as DESCRIPTIVE metadata and are intentionally
-- NOT enforced on write. No code path partially enforces them (this flag
-- is the single gate, and it is off).
--
-- Enforcement is a constraint-validation problem and is planned via SHACL:
-- translate a graph type to a SHACL shapes graph and validate the affected
-- nodes on INSERT/SET. It is deliberately NOT done via OWL/RDFS, which are
-- open-world inference (they enrich/coerce data and cannot reject a write
-- or express required/closed constraints), nor via a bespoke validator.
-- This flag will become configurable (default off) once the SHACL engine
-- is available. See binsrc/gql/gql-limitations.md ("Graph type enforcement").
----------------------------------------------------------------------

create procedure DB.DBA.GQL_ENFORCE_TYPES ()
{
  return 0;
}
;

----------------------------------------------------------------------
-- Property Graph catalog table.
--
-- Stores metadata for both virtual and physical property graphs.
-- Virtual PGs have DEFINITION populated (node/relationship table mappings);
-- physical PGs have DEFINITION = NULL (data is inserted via GQL INSERT).
----------------------------------------------------------------------
create table DB.DBA.GQL_PROPERTY_GRAPH_DEF (
    PG_NAME         varchar not null primary key,
    PG_MODE         varchar not null,        -- 'virtual' or 'physical'
    GRAPH_IRI       varchar not null,
    ONTOLOGY_NS     varchar not null,
    DATA_NS         varchar not null,
    DEFINITION      any,                     -- serialized metadata (virtual only)
    CREATED         datetime,
    IS_MATERIALIZED integer default 0        -- 1=virtual PG synced to physical triples
)
;

----------------------------------------------------------------------
-- Convenience: insert or replace a PG catalog row.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DEF_UPSERT (
  in _pg_name varchar,
  in _pg_mode varchar,
  in _graph_iri varchar,
  in _ontology_ns varchar,
  in _data_ns varchar,
  in _definition any)
{
  if (exists (select 1 from DB.DBA.GQL_PROPERTY_GRAPH_DEF where PG_NAME = _pg_name))
    {
      update DB.DBA.GQL_PROPERTY_GRAPH_DEF
         set PG_MODE = _pg_mode,
             GRAPH_IRI = _graph_iri,
             ONTOLOGY_NS = _ontology_ns,
             DATA_NS = _data_ns,
             DEFINITION = _definition,
             IS_MATERIALIZED = 0
       where PG_NAME = _pg_name;
    }
  else
    {
      insert into DB.DBA.GQL_PROPERTY_GRAPH_DEF
        (PG_NAME, PG_MODE, GRAPH_IRI, ONTOLOGY_NS, DATA_NS, DEFINITION, CREATED, IS_MATERIALIZED)
      values
        (_pg_name, _pg_mode, _graph_iri, _ontology_ns, _data_ns, _definition, now (), 0);
    }
}
;

----------------------------------------------------------------------
-- Convenience: look up a PG catalog row.  Returns a vector or NULL.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DEF_GET (in _pg_name varchar)
{
  declare _pg_mode, _graph_iri, _ontology_ns, _data_ns varchar;
  declare _definition any;
  declare _is_materialized integer;
  whenever not found goto nf;
  select PG_MODE, GRAPH_IRI, ONTOLOGY_NS, DATA_NS, DEFINITION, IS_MATERIALIZED
    into _pg_mode, _graph_iri, _ontology_ns, _data_ns, _definition, _is_materialized
    from DB.DBA.GQL_PROPERTY_GRAPH_DEF
   where PG_NAME = _pg_name;
  return vector (_pg_mode, _graph_iri, _ontology_ns, _data_ns, _definition, _is_materialized);
nf:
  return null;
}
;

----------------------------------------------------------------------
-- Convenience: delete a PG catalog row (idempotent).
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PG_DEF_DELETE (in _pg_name varchar)
{
  delete from DB.DBA.GQL_PROPERTY_GRAPH_DEF where PG_NAME = _pg_name;
}
;
