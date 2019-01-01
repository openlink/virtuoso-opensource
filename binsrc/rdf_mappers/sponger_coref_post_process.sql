--
--  $Id$
--
--  Post-processes Sponger generated entity URIs, identifying and
--  linking co-references by adding owl:sameAs links
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

-- Searches the given graph for instances of the given type. Instances with matching values of the specified match property
-- are linked, through owl:sameAs, to a 'canonical' URI for that instance. The canonical URI is generated from the match property.
-- All instances with the same value of the match property should generate the same canonical URI.
-- The match property will typically be some label which uniquely identifies some real-world entity.
-- 
-- Defines:
-- DB.DBA.RM_COREF_PROCESS_SCHEMAS
--   DB.DBA.RM_COREF_SCHEMA_GET_TYPES
-- DB.DBA.RM_COREF_RESOLVE_ALL_GRAPHS_BY_TYPE
--   DB.DBA.RM_COREF_RESOLVE_BY_TYPE_AND_GRAPH
--     DB.DBA.RM_COREF_CANONICAL_URI_MAKE
-- DB.DBA.RM_COREF_CLEAN_SINGLE_SAMEAS_STMTS
-- DB.DBA.RM_COREF_RESOLVER_RESOLVE
-- DB.DBA.RM_COREF_RESOLVER_ENABLE_SELECTED_TYPES

EXEC_STMT(
'create table DB.DBA.RM_COREF_RESOLVE_TYPES (
  CR_TYPE_URI varchar,
  CR_SCHEMA_URI varchar,
  CR_STATE integer default 0,
  CR_STARTED datetime,
  CR_FINISHED datetime,
  primary key (CR_TYPE_URI)
  )', 0)
;

-- CR_STATE:
--   -2: Manually marked. Always skip
--   -1: Error occurred
--    0: Initial state
--    1: To be checked 
--    2: Checking in progress
--    3: Checked

EXEC_STMT(
'create table DB.DBA.RM_COREF_RESOLVE_STATUS (
  CR_GRAPH_URI varchar,
  CR_TYPE_URI varchar,
  CR_MATCH_PROP_URI varchar,
  CR_TYPE_INSTANCES integer default 0,
  CR_STATE integer default 0,
  CR_STARTED datetime,
  CR_FINISHED datetime,
  CR_MESSAGE varchar,
  primary key (CR_GRAPH_URI, CR_TYPE_URI, CR_MATCH_PROP_URI)
  )
  create index RM_COREF_RESOLVE_STAT on DB.DBA.RM_COREF_RESOLVE_STATUS (CR_STATE)', 0)
;

-- CR_STATE:
--   -1: Error occurred
--    0: Initial state
--    1: To be checked 
--    2: Checking in progress
--    3: Checked

commit work;

create procedure DB.DBA.RM_COREF_RESOLVE_ALL_GRAPHS_BY_TYPE (
  in type_uri varchar, 
  in type_domain varchar, 
  in coref_graph_uri varchar, 
  in coref_uri_base varchar, 
  in match_property_uri varchar,
  in ins_batch_size integer := 1000
  )
{

  for select "g", "c"  from (sparql define input:storage "" select distinct ?g count(?s) as ?c where { graph ?g { ?s a `iri (?:type_uri)`; `iri (?:match_property_uri)` ?tag . }}) x do
  {
    declare graph_uri varchar;
    declare _cr_state, type_instance_count integer;

    graph_uri := cast ("g" as varchar);
    type_instance_count := cast ("c" as integer);

    insert soft RM_COREF_RESOLVE_STATUS (CR_GRAPH_URI, CR_TYPE_URI, CR_MATCH_PROP_URI) values (graph_uri, type_uri, match_property_uri);
    _cr_state := (select CR_STATE from RM_COREF_RESOLVE_STATUS where 
                  CR_GRAPH_URI = graph_uri and CR_TYPE_URI = type_uri and CR_MATCH_PROP_URI = match_property_uri);
    if (_cr_state = 3)
    {
      goto next_graph;
    }

    update RM_COREF_RESOLVE_STATUS set CR_STARTED = now(), CR_FINISHED = null, CR_STATE = 2, CR_TYPE_INSTANCES = type_instance_count
      where CR_GRAPH_URI = graph_uri and CR_TYPE_URI = type_uri and CR_MATCH_PROP_URI = match_property_uri;
    commit work;

    declare exit handler for sqlstate '*'
    {
      rollback work;

      update RM_COREF_RESOLVE_STATUS set CR_STATE = -1, CR_MESSAGE = __SQL_MESSAGE
        where CR_GRAPH_URI = graph_uri and CR_TYPE_URI = type_uri and CR_MATCH_PROP_URI = match_property_uri;
      commit work;
      goto next_graph;
    };

    DB.DBA.RM_COREF_RESOLVE_BY_TYPE_AND_GRAPH (type_uri, graph_uri, type_domain, coref_graph_uri, 
      coref_uri_base, match_property_uri, ins_batch_size);

    update RM_COREF_RESOLVE_STATUS set CR_FINISHED = now(), CR_STATE = 3
      where CR_GRAPH_URI = graph_uri and CR_TYPE_URI = type_uri and CR_MATCH_PROP_URI = match_property_uri;
    commit work;

next_graph:;
  }
}
;

create procedure DB.DBA.RM_COREF_RESOLVE_BY_TYPE_AND_GRAPH (
  in type_uri varchar, 
  in graph_uri varchar, 
  in type_domain varchar, 
  in coref_graph_uri varchar, 
  in coref_uri_base varchar, 
  in match_property_uri varchar,
  in ins_batch_size integer := 1000
  )
{
  declare qry varchar; 
  declare result, meta, state, message any;
  declare sameAs_triples_dict any;
  declare iTripleBatchSize integer;
  declare sameAs_pred_id any;


  sameAs_pred_id := iri_to_id ('http://www.w3.org/2002/07/owl#sameAs');

  qry := sprintf ('sparql define input:storage "" select ?s ?tag from <%s> where { ?s a <%s> ; <%s> ?tag . }', graph_uri, type_uri, match_property_uri);
  state := '00000';
  exec (qry, state, message, vector(), 0, meta, result);
  if (state <> '00000')
  {
    signal (state, message, 'COREF');
  }

  sameAs_triples_dict := dict_new (ins_batch_size);
  iTripleBatchSize := 0;

  foreach (any str in result) do
  {
    declare entity_uri, entity_tag, canonical_entity_uri varchar;

    if (isstring (str[0]) and isstring (str[1]))
    {
      entity_uri := str[0];
      entity_tag := str[1];

      canonical_entity_uri := DB.DBA.RM_COREF_CANONICAL_URI_MAKE (coref_uri_base, type_domain, type_uri, entity_tag);
      if (canonical_entity_uri is not null)
      {
	declare sameAs_subj_id, sameAs_obj_id any;

        iTripleBatchSize := iTripleBatchSize + 1;
	-- Make owl:sameAs triple
	sameAs_subj_id := iri_to_id (entity_uri);
	sameAs_obj_id := iri_to_id (canonical_entity_uri);
	dict_put (sameAs_triples_dict, vector (sameAs_subj_id, sameAs_pred_id, sameAs_obj_id), 1);
      }

      -- for every ins_batch_size triples
      if (mod (iTripleBatchSize, ins_batch_size) = 0)
      {
	if (dict_size (sameAs_triples_dict))
	{
ins_triples:
	  declare sameAs_triples any;
	  sameAs_triples := dict_list_keys (sameAs_triples_dict, 1);
	  {
	    declare deadl int;
	    deadl := 5;
ins_again:
	    declare exit handler for sqlstate '40001' {
	      deadl := deadl - 1;
	      if (deadl > 0)
	      {
		rollback work;
		goto ins_again;
	      }
	      resignal;
	    };
	    DB.DBA.RDF_INSERT_TRIPLES (coref_graph_uri, sameAs_triples);
	    commit work;
	  } 
	  iTripleBatchSize := 0;
	}
      }
    }
  }

-- Insert last partial batch
if (dict_size (sameAs_triples_dict))
  goto ins_triples;
}
;

create procedure DB.DBA.RM_COREF_CANONICAL_URI_MAKE (
  in coref_uri_base varchar,
  in type_domain varchar,
  in type_uri varchar, 
  in tag varchar
  )
{
  declare canonical_uri, type_name, tmp varchar;
  declare indx int;

  -- All Sponger-generated entity URIs are hash URIs
  indx := strrchr (type_uri, '#'); 
  if (indx is null or (indx = length (type_uri) - 1))
    return null;
  type_name := subseq (type_uri, indx + 1);
  tag := trim (tag);
  -- Skip tags > 50 chars, these are probably not true labels, more like descriptions
  if (length (tag) < 2 or length (tag) > 50)
    return null;
  if (regexp_match ('[^A-Za-z0-9 _]', tag) is not null)
  {
    return null;
  }
  tag := replace (tag, ' ', '_'); -- TO DO: Needs extending - what about other chars which must be uri-encoded
  canonical_uri := sprintf ('%s/%s/%s#%s', coref_uri_base, type_domain, type_name, tag); 
  return canonical_uri;
}
;

create procedure DB.DBA.RM_COREF_SCHEMA_GET_TYPES (in schema_uri varchar)
{
  declare qry varchar; 
  declare result, meta, state, message any;
  declare type_uris any;


  qry := sprintf ('sparql define input:storage "" select distinct ?s from <%s> where {{ ?s a owl:Class . } union { ?s a rdfs:Class . }}', schema_uri);
  state := '00000';
  exec (qry, state, message, vector(), 0, meta, result);

  if (state <> '00000')
    return;

  type_uris := vector ();
  foreach (any str in result) do
  {
    declare type_uri varchar;

    if (isstring (str[0]))
    {
      type_uri := str[0];
      -- Skip base classes of xxx#Object
      if (type_uri = schema_uri || '#Object')
        goto next_type;
      type_uris := vector_concat (type_uris, vector (type_uri));
    }
next_type:;
  }
  return type_uris;
}
;

-- Identifies the types for which we might want to resolve co-references
-- by extracting type declarations from selected schemas.
-- Adds an entry to table RM_COREF_RESOLVE_TYPES for each type.
-- Only schemas with a URI matching the given stem are considered.
-- All owl:Class and rdfs:Class instances in the matching schemas are identified as candidate types.
create procedure DB.DBA.RM_COREF_PROCESS_SCHEMAS (in schema_uri_match_stem varchar)
{
  declare schemas any;
  schemas := vector ();

  for (select NS_URL from SYS_XML_PERSISTENT_NS_DECL where NS_URL like schema_uri_match_stem || '%') do
  {
    -- Skip all virt schemas (virtcxml#, virtrdf#, virtrdf-meta-entity-class#)
    if (strstr (NS_URL, 'http://www.openlinksw.com/schemas/virt') is not null)
      goto next_url;
    NS_URL := rtrim (NS_URL, '#/');
    schemas := vector_concat (schemas, vector (NS_URL));
next_url:;
  }

  foreach (any _schema in schemas) do
  {
    declare schema_types any;
    schema_types := DB.DBA.RM_COREF_SCHEMA_GET_TYPES (_schema);
    foreach (any schema_type in schema_types) do
    {
      insert soft RM_COREF_RESOLVE_TYPES (CR_TYPE_URI, CR_SCHEMA_URI, CR_STATE) values (schema_type, _schema, -2);
    }
    commit work;
  }
}
;

-- Remove any single owl:sameAs statements (i.e. a canonical URI has only one referrer), they serve no purpose
create procedure DB.DBA.RM_COREF_CLEAN_SINGLE_SAMEAS_STMTS (in coref_graph_uri varchar := 'http://virtrdf_mapper_coref')
{
  declare qry varchar; 
  declare result, meta, state, message any;

  qry := sprintf ('sparql define input:storage "" select distinct ?o, count(?o) as ?c from <%s> where { ?s ?p ?o }', coref_graph_uri);
  state := '00000';
  exec (qry, state, message, vector(), 0, meta, result);
  if (state <> '00000')
    return;

  foreach (any str in result) do
  {
    declare canonical_uri varchar;
    declare cnt integer;

    if (isstring (str[0]) and isinteger (str[1]))
    {
      canonical_uri := str[0];
      cnt := str[1];
      if (cnt = 1)
      {
        qry := sprintf ('sparql delete from <%s> { ?s ?p ?o } where { ?s owl:sameAs <%s> . ?s ?p ?o . }', coref_graph_uri, canonical_uri);
        state := '00000';
        exec (qry, state, message);
        if (state <> '00000')
	{
          rollback work;
	}
        else
          commit work;
skip_delete:;
      }
    } 
  }
}
;

create procedure DB.DBA.RM_COREF_RESOLVER_ENABLE_SELECTED_TYPES ()
{
  -- update RM_COREF_RESOLVE_TYPES set CR_STATE = 1 where CR_SCHEMA_URI like '%linkedin';
  -- update RM_COREF_RESOLVE_TYPES set CR_STATE = 1 where CR_SCHEMA_URI like '%twitter';
  -- update RM_COREF_RESOLVE_TYPES set CR_STATE = 1 where CR_SCHEMA_URI like '%googleplus';

  -- Some class's labels typically don't form a bounded set or can be so generic that false matches are likely
  -- These instances aren't considered individuals
  -- Examples:
  -- http://www.openlinksw.com/schemas/cv#WorkHistory
  -- http://www.openlinksw.com/schemas/googleplus#ActivityObject
  -- http://www.openlinksw.com/schemas/linkedin#Position
  -- http://www.openlinksw.com/schemas/opengraph#Album
  -- http://www.openlinksw.com/schemas/opengraph#Photo

  declare v_types_to_enable any;

  v_types_to_enable := vector (
    'http://www.openlinksw.com/schemas/cv#Company',
    'http://www.openlinksw.com/schemas/cv#EducationalOrg',
    'http://www.openlinksw.com/schemas/cv#Organization',
    'http://www.openlinksw.com/schemas/cv#Skill',
    'http://www.openlinksw.com/schemas/googleplus#PlaceLived',
    'http://www.openlinksw.com/schemas/linkedin#Company',
    'http://www.openlinksw.com/schemas/linkedin#Skill',
    'http://www.openlinksw.com/schemas/twitter#Application'
  );

  foreach (any type_to_enable in v_types_to_enable) do
  {
    update RM_COREF_RESOLVE_TYPES set CR_STATE = 1 where CR_TYPE_URI = type_to_enable ;
  }
  commit work;
}
;

-- ------------------------------------------------

create procedure DB.DBA.RM_COREF_RESOLVER_RESOLVE (in coref_graph_uri varchar := 'http://virtrdf_mapper_coref', in cr_init_state integer := 0)
{
  declare type_uri varchar; 
  declare graph_uri varchar; 
  declare type_domain varchar; 
  declare coref_uri_base varchar; 
  declare match_property_uri varchar;
  declare batch_size integer;

  coref_uri_base := coref_graph_uri;
  match_property_uri := 'http://www.w3.org/2000/01/rdf-schema#label';
  batch_size := 100;

  if (cr_init_state = 2)
  {
    delete from DB.DBA.RM_COREF_RESOLVE_TYPES;
    commit work;

    -- Identifies the types for which we might want to resolve co-references
    -- by extracting type declarations from selected schemas.
    -- Adds an entry to table RM_COREF_RESOLVE_TYPES for each type.
    -- Only schemas with a URI matching the given stem are considered.
    -- All owl:Class and rdfs:Class instances in the matching schemas are identified as candidate types.
    DB.DBA.RM_COREF_PROCESS_SCHEMAS ('http://www.openlinksw.com/schemas');
    return;

    -- Manually edit DB.DBA.RM_COREF_RESOLVER_ENABLE_SELECTED_TYPES (), setting CR_STATE= 1 for types you want to enable.
  }

  if (cr_init_state = 1)
  {
    update RM_COREF_RESOLVE_TYPES set CR_STARTED = null, CR_FINISHED = null, CR_STATE = 1 where CR_STATE >= -1;
    commit work;
  }

  if (cr_init_state > 0)
  {
    exec (sprintf ('sparql clear graph <%s>', coref_graph_uri));
    delete from DB.DBA.RM_COREF_RESOLVE_STATUS;
    commit work;
  }

  -- For each type, scan all graphs (or those not already processed if resuming a run) and generate owl:sameAs statements
  for (select CR_TYPE_URI as _cr_type_uri, CR_SCHEMA_URI from RM_COREF_RESOLVE_TYPES where CR_STATE = 1) do
  {
    update RM_COREF_RESOLVE_TYPES set CR_STARTED = now(), CR_FINISHED = null, CR_STATE = 2
      where CR_TYPE_URI = _cr_type_uri;
    commit work;

    type_domain := rtrim (trim (CR_SCHEMA_URI), '#/');
    type_domain := subseq (type_domain, strrchr (type_domain, '/') + 1);
    DB.DBA.RM_COREF_RESOLVE_ALL_GRAPHS_BY_TYPE (_cr_type_uri, type_domain, 
      coref_graph_uri, coref_uri_base, match_property_uri, batch_size);

    update RM_COREF_RESOLVE_TYPES set CR_FINISHED = now(), CR_STATE = 3
      where CR_TYPE_URI = _cr_type_uri;
    commit work;
  }
  
}
;

-- cr_init_state controls resetting of entries in table RM_COREF_RESOLVE_TYPES:
--  0 => resume  
--	 Leaves CR_STATE entries unchanged.
--       Resumes processing of types by RM_COREF_RESOLVE_ALL_GRAPHS_BY_TYPE() from a previous run.
--  1 => reset 
--       Resets CR_STATEs >=-1 to 1 
--	 Leaves types manually marked for skipping (CR_STATE = -2) intact.
--       Clears graph <http://virtrdf_mapper_coref>
--       All other types will processed from scratch by RM_COREF_RESOLVE_ALL_GRAPHS_BY_TYPE().
--  2 => clean
--	 Cleans and re-populates table RM_COREF_RESOLVE_TYPES. 
--       Clears graph <http://virtrdf_mapper_coref>
--       Doesn't run RM_COREF_RESOLVE_ALL_GRAPHS_BY_TYPE(), to allow manual marking of types to be skipped.

create procedure DB.DBA.RM_COREF_RESOLVER_INIT ()
{
  DB.DBA.RM_COREF_RESOLVER_RESOLVE (cr_init_state=>2);
  log_message ('DB.DBA.RM_COREF_RESOLVER_INIT: Done');
  log_message ('Edit RM_COREF_RESOLVER_ENABLE_SELECTED_TYPES(), then run RM_COREF_RESOLVER_RUN');
}
;

create procedure DB.DBA.RM_COREF_RESOLVER_RUN (in cr_init_state integer := 0)
{
  DB.DBA.RM_COREF_RESOLVER_ENABLE_SELECTED_TYPES ();

  log_message ('DB.DBA.RM_COREF_RESOLVER_RESOLVE : Start');
  DB.DBA.RM_COREF_RESOLVER_RESOLVE (cr_init_state=>cr_init_state);
  log_message ('DB.DBA.RM_COREF_RESOLVER_RESOLVE : Done');

  log_message ('DB.DBA.RM_COREF_CLEAN_SINGLE_SAMEAS_STMTS : Start');
  DB.DBA.RM_COREF_CLEAN_SINGLE_SAMEAS_STMTS ();
  log_message ('DB.DBA.RM_COREF_CLEAN_SINGLE_SAMEAS_STMTS : Done');
}
;

-- DB.DBA.RM_COREF_RESOLVER_INIT ();
-- DB.DBA.RM_COREF_RESOLVER_RUN (1 / 0);
