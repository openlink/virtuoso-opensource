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
-- The RDF view that makes a vector index's own name and description readable
-- through SPARQL, in the graph <urn:vvec:indexes>:
--
--   <the index IRI>  rdfs:label    "Support articles" .
--   <the index IRI>  rdfs:comment  "Semantic search over ..." .
--
-- A VIEW, not emitted triples.  The alternative -- writing the triples on
-- create/alter/drop -- keeps two copies of the truth and has to be rebuilt on
-- every change, and drift here is worse than having nothing: a stale
-- description of an index actively misleads whoever reads it next.  Generated
-- from DB.DBA.SPARQL_VEC_INDEX at query time, they cannot go stale.
--
-- WHY THIS FILE IS SEPARATE FROM sparql_vec_index.sql, which is where
-- everything else about the catalogue lives: quad-map DDL is dispatched to the
-- DB.DBA.RDF_QM_* procedures in sparql_qm.sql, and sparql_vec_index.sql is
-- loaded *before* those exist (it comes second in SQL_FILES_SPARQL, ahead of
-- even sparql.sql).  This file is loaded last, so the machinery it needs is
-- there.  Same reason the vector-index SPARQL_SELECT grants had to move into
-- sparql.sql rather than stay beside the procedures they name.
--
-- SECURITY.  The view carries no grants of its own: it reads
-- DB.DBA.SPARQL_VEC_INDEX, and an RDF view enforces the base table's SQL
-- privileges, so a reader with no grant gets SQ033 naming the column and a
-- reader with `grant select (SVI_IRI, SVI_LABEL)` sees rdfs:label and is
-- refused rdfs:comment.  A fresh install grants nothing, which is the right
-- default: index names and descriptions say what data exists and what it is
-- for, and that is a deployment decision.
--
-- Note that table grants are not the whole control.  An endpoint configured
-- with HP_RUN_VSP_AS = dba and no auth function -- the default /sparql on many
-- development instances -- already runs anonymous requests with DBA rights, and
-- privileges never come into it.  Deciding which endpoint may see
-- <urn:vvec:indexes> is what protects this, not the grants.
--

-- Bump when the mapping below changes shape; a server whose stored value does
-- not match re-installs the view at startup and stores the new one.
create function DB.DBA.VEC_INDEX_META_VIEW_VERSION () returns varchar
{
  return '1';
}
;

-- Run one RDF-metadata DDL statement and report what actually happened.
--
-- Quad-map DDL does NOT fail the statement when an operation inside it fails:
-- it returns one (STATE, MESSAGE) row per operation and the statement itself
-- still reports 00000.  Checking only the statement's SQLSTATE is how a
-- half-created mapping looks like a successful install.  Returns '' on success,
-- otherwise the first failing row as 'SQLSTATE: message'.
create function DB.DBA.VEC_INDEX_META_VIEW_EXEC (in qtext varchar) returns varchar
{
  declare st, msg varchar;
  declare md, rows any;
  declare i integer;

  st := '00000';
  exec (qtext, st, msg, vector (), 100, md, rows);
  if (st <> '00000' and st <> 0)
    return sprintf ('%s: %s', cast (st as varchar), coalesce (msg, ''));
  if (not isarray (rows))
    return '';
  for (i := 0; i < length (rows); i := i + 1)
    {
      if (isarray (rows[i]) and length (rows[i]) > 0)
        {
          declare row_state varchar;
          row_state := cast (rows[i][0] as varchar);
          if (row_state is not null and row_state <> '00000')
            return sprintf ('%s: %s', row_state,
              case when length (rows[i]) > 1 then cast (rows[i][1] as varchar) else '' end);
        }
    }
  return '';
}
;

-- Remove the mapping.
--
-- ORDER MATTERS AND IS NOT THE OBVIOUS ONE: quad map first, then (if there were
-- one) the storage, then the IRI class.  Dropping a quad storage leaves the
-- anonymous quad-map objects underneath it alive, and those pin the IRI class
-- forever -- it can then be neither dropped nor redefined, so the class name is
-- burned for the life of the database and an installer that does it the natural
-- way round breaks its own re-install.  Dropping the map *while its storage
-- still owns it* is what lets the collector reach those objects.
--
-- Here the storage is virtrdf:DefaultQuadStorage, which is never dropped -- the
-- view has to live in the default storage or a plain SPARQL query would not see
-- it without an explicit `define input:storage`.  So the order below is the
-- safe one by construction, but it is written out this way on purpose: the
-- next person to add a map here must add its drop above the class, not below.
create procedure DB.DBA.VEC_INDEX_META_VIEW_DROP () returns varchar
{
  declare err varchar;

  err := DB.DBA.VEC_INDEX_META_VIEW_EXEC (
    'sparql prefix vvec: <http://www.openlinksw.com/schemas/vvec#> drop silent quad map vvec:indexLabelMap .');
  if (err <> '')
    return err;
  err := DB.DBA.VEC_INDEX_META_VIEW_EXEC (
    'sparql prefix vvec: <http://www.openlinksw.com/schemas/vvec#> drop silent quad map vvec:indexCommentMap .');
  if (err <> '')
    return err;
  -- The class last, and only once nothing points at it any more.
  err := DB.DBA.VEC_INDEX_META_VIEW_EXEC (
    'sparql prefix vvec: <http://www.openlinksw.com/schemas/vvec#> drop silent iri class vvec:indexIri .');
  if (err <> '')
    return err;
  registry_set ('__vec_meta_view', '');
  return '';
}
;

-- Install (or re-install) the mapping.  Idempotent: it removes whatever is
-- there first, in the order above, so running it twice is running it once.
--
-- One map per column rather than one map with two patterns, because each needs
-- its own IS NOT NULL guard and a `where` clause applies to the whole map.
-- Without the guard a query with a variable predicate -- ?s ?p ?o, which is
-- what anyone exploring this graph writes first -- comes back with rows whose
-- object is NULL for every index that has no comment.  With it, an index
-- without a label simply has no rdfs:label.
--
-- Neither map declares `option (exclusive)`, which would otherwise be the right
-- thing for a graph whose whole content is a view: two maps cannot both claim
-- one graph exclusively -- declare it on both and the second silently wins,
-- leaving the graph with rdfs:label and no rdfs:comment.  The cost of leaving
-- it off is that a reader of <urn:vvec:indexes> also needs SELECT on
-- DB.DBA.RDF_QUAD, since the physical quad store stays in the union for this
-- graph.  Every SPARQL reader has that through the SPARQL_SELECT role, so it
-- changes nothing in practice.
create procedure DB.DBA.VEC_INDEX_META_VIEW_CREATE () returns varchar
{
  declare err varchar;

  err := DB.DBA.VEC_INDEX_META_VIEW_DROP ();
  if (err <> '')
    return err;

  -- "%s" -- the column already holds a whole IRI, so the template is the value.
  -- The parameter must not be called `iri`: that is a keyword in this position
  -- and the DDL is then a syntax error at the parameter name.
  err := DB.DBA.VEC_INDEX_META_VIEW_EXEC (
    'sparql prefix vvec: <http://www.openlinksw.com/schemas/vvec#> ' ||
    'create iri class vvec:indexIri "%s" (in val varchar not null) .');
  if (err <> '')
    return err;

  err := DB.DBA.VEC_INDEX_META_VIEW_EXEC (
    'sparql prefix vvec: <http://www.openlinksw.com/schemas/vvec#> ' ||
    'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
    'alter quad storage virtrdf:DefaultQuadStorage ' ||
    '  from DB.DBA.SPARQL_VEC_INDEX as svil ' ||
    '  where (^{svil.}^.SVI_LABEL is not null) ' ||
    '  { create vvec:indexLabelMap as graph <urn:vvec:indexes> ' ||
    '      { vvec:indexIri (svil.SVI_IRI) rdfs:label svil.SVI_LABEL . } } .');
  if (err <> '')
    return err;

  err := DB.DBA.VEC_INDEX_META_VIEW_EXEC (
    'sparql prefix vvec: <http://www.openlinksw.com/schemas/vvec#> ' ||
    'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
    'alter quad storage virtrdf:DefaultQuadStorage ' ||
    '  from DB.DBA.SPARQL_VEC_INDEX as svic ' ||
    '  where (^{svic.}^.SVI_COMMENT is not null) ' ||
    '  { create vvec:indexCommentMap as graph <urn:vvec:indexes> ' ||
    '      { vvec:indexIri (svic.SVI_IRI) rdfs:comment svic.SVI_COMMENT . } } .');
  if (err <> '')
    return err;

  registry_set ('__vec_meta_view', DB.DBA.VEC_INDEX_META_VIEW_VERSION ());
  return '';
}
;

-- Install the view once, if it is not already there and if it can be.
--
-- Called as a server init statement below, and again from VEC_INDEX_END_CREATE
-- -- because the FIRST start of a brand-new database is too early to do it.
-- Quad-map DDL needs the built-in virtrdf metadata, which Virtuoso keeps in
-- DB.DBA.SYS_CACHED_RESOURCES and populates from resources compiled into the
-- binary; on a fresh database that happens AFTER the SQL init statements have
-- run.  Attempt it then and XML_URI_GET falls through to a real HTTP request
-- for http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl, which is both
-- doomed and not something a server should do while starting up.  So the
-- prerequisite is checked rather than discovered: no cached resource, no
-- attempt, and the next caller -- the next restart, or the first CREATE VECTOR
-- INDEX, whichever comes first -- installs it.
--
-- Cheap enough to call on any path: one registry read once the view is in.
--
-- It must not raise.  As a server init statement an error here would abort the
-- rest of this file; from END_CREATE it would fail a CREATE that has already
-- succeeded.  A failure is logged and the server comes up without the view --
-- nothing about vector search depends on it.
create procedure DB.DBA.VEC_INDEX_META_VIEW_INIT () returns integer
{
  declare err varchar;
  declare exit handler for sqlstate '*'
    {
      log_message (sprintf ('vector index metadata view: not installed (%s %s)',
        __SQL_STATE, __SQL_MESSAGE));
      return 0;
    };

  if (coalesce (registry_get ('__vec_meta_view'), '') = DB.DBA.VEC_INDEX_META_VIEW_VERSION ())
    return 0;

  if (not exists (select 1 from DB.DBA.SYS_CACHED_RESOURCES
                   where CRES_URI = 'http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl'))
    return 0;

  err := DB.DBA.VEC_INDEX_META_VIEW_CREATE ();
  if (err <> '')
    {
      log_message (sprintf ('vector index metadata view: not installed (%s)', err));
      return 0;
    }
  return 1;
}
;

-- Before roll forward it allocates IRI ids unlogged that the replayed log then reuses for other names.
--!AFTER
DB.DBA.VEC_INDEX_META_VIEW_INIT ()
;
