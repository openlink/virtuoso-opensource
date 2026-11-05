/*
 *  graph_quad.c
 *
 *  RDF Quad Adapter Layer
 *
 *  Implements the quad store that wraps the triple-based graph library
 *  to support RDF Quads with graph IRI as first-class scope key.
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#include "graph_quad.h"
#include "graph_internal.h"
#include <string.h>

/* ============================================================================
 * INTERNAL STRUCTURES
 * ============================================================================ */

/* Hash table entry for graph lookup */
typedef struct graph_entry
{
  graph_iri_id_t iri;
  graph_t *graph;
  uint64_t quad_count;
  struct graph_entry *next;
} graph_entry_t;

/* Quad store implementation */
struct quad_store
{
  graph_entry_t **buckets;
  uint64_t bucket_count;
  uint64_t graph_count;
  uint64_t total_quads;
  bool lazy_creation;
  bool has_graph_index;
  graph_allocator_t allocator;

  /* Default graph (always present) */
  graph_t *default_graph;
};

/* Default configuration */
const quad_store_config_t QUAD_STORE_CONFIG_DEFAULT = {
  .initial_graph_capacity = 64,
  .initial_quad_capacity = 65536,
  .build_graph_index = true,
  .lazy_graph_creation = true,
  .allocator = {NULL, NULL, NULL, NULL}
};

/* ============================================================================
 * HASH TABLE HELPERS
 * ============================================================================ */

static uint64_t
hash_iri_id (graph_iri_id_t iri)
{
  /* FNV-1a hash */
  uint64_t h = 14695981039346656037ULL;
  uint8_t *p = (uint8_t *) & iri;
  for (size_t i = 0; i < sizeof (iri); i++)
    {
      h ^= p[i];
      h *= 1099511628211ULL;
    }
  return h;
}

static graph_entry_t *
find_entry (const quad_store_t *store, graph_iri_id_t iri)
{
  if (!store->buckets)
    return NULL;
  uint64_t idx = hash_iri_id (iri) % store->bucket_count;
  graph_entry_t *e = store->buckets[idx];
  while (e)
    {
      if (e->iri == iri)
	return e;
      e = e->next;
    }
  return NULL;
}

static graph_error_t
insert_entry (quad_store_t *store, graph_iri_id_t iri, graph_t *graph)
{
  if (!store->buckets)
    {
      store->bucket_count = 64;
      store->buckets = graph_alloc (&store->allocator, store->bucket_count * sizeof (graph_entry_t *));
      if (!store->buckets)
	return GRAPH_ERR_OUT_OF_MEMORY;
      memset (store->buckets, 0, store->bucket_count * sizeof (graph_entry_t *));
    }

  /* Check load factor and resize if needed */
  if (store->graph_count >= store->bucket_count * 3 / 4)
    {
      uint64_t new_count = store->bucket_count * 2;
      graph_entry_t **new_buckets = graph_alloc (&store->allocator,
	  new_count * sizeof (graph_entry_t *));
      if (!new_buckets)
	return GRAPH_ERR_OUT_OF_MEMORY;
      memset (new_buckets, 0, new_count * sizeof (graph_entry_t *));

      for (uint64_t i = 0; i < store->bucket_count; i++)
	{
	  graph_entry_t *e = store->buckets[i];
	  while (e)
	    {
	      graph_entry_t *next = e->next;
	      uint64_t new_idx = hash_iri_id (e->iri) % new_count;
	      e->next = new_buckets[new_idx];
	      new_buckets[new_idx] = e;
	      e = next;
	    }
	}
      graph_free (&store->allocator, store->buckets, store->bucket_count * sizeof (graph_entry_t *));
      store->buckets = new_buckets;
      store->bucket_count = new_count;
    }

  graph_entry_t *entry = graph_alloc (&store->allocator, sizeof (graph_entry_t));
  if (!entry)
    return GRAPH_ERR_OUT_OF_MEMORY;

  entry->iri = iri;
  entry->graph = graph;
  entry->quad_count = 0;

  uint64_t idx = hash_iri_id (iri) % store->bucket_count;
  entry->next = store->buckets[idx];
  store->buckets[idx] = entry;
  store->graph_count++;

  return GRAPH_OK;
}

/* ============================================================================
 * QUAD STORE LIFECYCLE
 * ============================================================================ */

graph_error_t
quad_store_create (const quad_store_config_t *config, quad_store_t **out_store)
{
  if (!out_store)
    return GRAPH_ERR_NULL_PTR;

  const quad_store_config_t *cfg = config ? config : &QUAD_STORE_CONFIG_DEFAULT;

  graph_allocator_t allocator = cfg->allocator.alloc ? cfg->allocator : GRAPH_DEFAULT_ALLOCATOR;
  quad_store_t *store = graph_alloc (&allocator, sizeof (quad_store_t));
  if (!store)
    return GRAPH_ERR_OUT_OF_MEMORY;
  memset (store, 0, sizeof (*store));
  store->allocator = allocator;

  store->lazy_creation = cfg->lazy_graph_creation;
  store->has_graph_index = cfg->build_graph_index;

  /* Create default graph */
  graph_config_t gcfg = GRAPH_CONFIG_DEFAULT;
  gcfg.initial_triple_capacity = cfg->initial_quad_capacity / 4;
  gcfg.allocator = allocator;

  graph_error_t err = graph_create (&gcfg, &store->default_graph);
  if (err != GRAPH_OK)
    {
      graph_free (&allocator, store, sizeof (*store));
      return err;
    }

  /* Pre-allocate bucket array if capacity hint provided */
  if (cfg->initial_graph_capacity > 0)
    {
      store->bucket_count = cfg->initial_graph_capacity;
      store->buckets = graph_alloc (&store->allocator, store->bucket_count * sizeof (graph_entry_t *));
      if (!store->buckets)
	{
	  graph_destroy (store->default_graph);
	  graph_free (&store->allocator, store, sizeof (*store));
	  return GRAPH_ERR_OUT_OF_MEMORY;
	}
      memset (store->buckets, 0, store->bucket_count * sizeof (graph_entry_t *));
    }

  *out_store = store;
  return GRAPH_OK;
}

graph_error_t
quad_store_destroy (quad_store_t *store)
{
  if (!store)
    return GRAPH_ERR_NULL_PTR;

  /* Destroy all named graphs */
  if (store->buckets)
    {
      for (uint64_t i = 0; i < store->bucket_count; i++)
	{
	  graph_entry_t *e = store->buckets[i];
	  while (e)
	    {
	      graph_entry_t *next = e->next;
	      if (e->graph)
		graph_destroy (e->graph);
	      graph_free (&store->allocator, e, sizeof (*e));
	      e = next;
	    }
	}
      graph_free (&store->allocator, store->buckets, store->bucket_count * sizeof (graph_entry_t *));
    }

  /* Destroy default graph */
  if (store->default_graph)
    {
      graph_destroy (store->default_graph);
    }

  {
    graph_allocator_t allocator = store->allocator;
    graph_free (&allocator, store, sizeof (*store));
  }
  return GRAPH_OK;
}

/* ============================================================================
 * GRAPH ACCESS
 * ============================================================================ */

graph_error_t
quad_store_get_graph (quad_store_t *store, graph_iri_id_t graph_iri, bool create_if_missing, graph_t **out_graph)
{
  if (!store || !out_graph)
    return GRAPH_ERR_NULL_PTR;

  /* Special case: default graph */
  if (graph_iri == GRAPH_IRI_ID_DEFAULT || graph_iri == GRAPH_IRI_ID_INVALID)
    {
      *out_graph = store->default_graph;
      return GRAPH_OK;
    }

  /* Look up in hash table */
  graph_entry_t *entry = find_entry (store, graph_iri);
  if (entry)
    {
      *out_graph = entry->graph;
      return GRAPH_OK;
    }

  /* Not found - create if requested */
  if (!create_if_missing)
    {
      *out_graph = NULL;
      return GRAPH_ERR_NOT_FOUND;
    }

  /* Create new graph */
  graph_t *new_graph;
  graph_config_t gcfg = GRAPH_CONFIG_DEFAULT;
  gcfg.allocator = store->allocator;
  graph_error_t err = graph_create (&gcfg, &new_graph);
  if (err != GRAPH_OK)
    return err;

  err = insert_entry (store, graph_iri, new_graph);
  if (err != GRAPH_OK)
    {
      graph_destroy (new_graph);
      return err;
    }

  *out_graph = new_graph;
  return GRAPH_OK;
}

bool
quad_store_graph_exists (const quad_store_t *store, graph_iri_id_t graph_iri)
{
  if (!store)
    return false;
  if (graph_iri == GRAPH_IRI_ID_DEFAULT || graph_iri == GRAPH_IRI_ID_INVALID)
    {
      return true;
    }
  return find_entry (store, graph_iri) != NULL;
}

graph_error_t
quad_store_list_graphs (const quad_store_t *store, graph_iri_id_t *out_iris, uint64_t max_count, uint64_t *out_count)
{
  if (!store || !out_count)
    return GRAPH_ERR_NULL_PTR;

  uint64_t count = 0;

  /* Include default graph */
  if (out_iris && count < max_count)
    {
      out_iris[count] = GRAPH_IRI_ID_DEFAULT;
    }
  count++;

  /* Iterate named graphs */
  if (store->buckets)
    {
      for (uint64_t i = 0; i < store->bucket_count && count < max_count; i++)
	{
	  graph_entry_t *e = store->buckets[i];
	  while (e && count < max_count)
	    {
	      if (out_iris)
		out_iris[count] = e->iri;
	      count++;
	      e = e->next;
	    }
	}
    }

  *out_count = count;
  return GRAPH_OK;
}

uint64_t
quad_store_graph_count (const quad_store_t *store)
{
  if (!store)
    return 0;
  return store->graph_count + 1;	/* +1 for default graph */
}

/* ============================================================================
 * QUAD OPERATIONS
 * ============================================================================ */

graph_error_t
quad_store_add_quad (quad_store_t *store, const graph_quad_t *quad)
{
  if (!store || !quad)
    return GRAPH_ERR_NULL_PTR;

  /* Get or create target graph */
  graph_t *target;
  graph_error_t err = quad_store_get_graph (store, quad->graph,
      store->lazy_creation, &target);
  if (err != GRAPH_OK)
    return err;
  if (!target)
    return GRAPH_ERR_NO_SNAPSHOT;

  /* Convert quad to triple (graph context is implicit in target) */
  graph_triple_t triple = {
    .subject = quad->subject,
    .predicate = quad->predicate,
    .object = quad->object
  };

  err = graph_add_triple (target, &triple);
  if (err == GRAPH_OK)
    {
      store->total_quads++;

      /* Update entry quad count */
      if (quad->graph != GRAPH_IRI_ID_DEFAULT && quad->graph != GRAPH_IRI_ID_INVALID)
	{
	  graph_entry_t *entry = find_entry (store, quad->graph);
	  if (entry)
	    entry->quad_count++;
	}
    }

  return err;
}

graph_error_t
quad_store_remove_quad (quad_store_t *store, const graph_quad_t *quad)
{
  if (!store || !quad)
    return GRAPH_ERR_NULL_PTR;

  graph_t *target;
  graph_error_t err = quad_store_get_graph (store, quad->graph, false, &target);
  if (err != GRAPH_OK)
    return err;
  if (!target)
    return GRAPH_ERR_NOT_FOUND;

  graph_triple_t triple = {
    .subject = quad->subject,
    .predicate = quad->predicate,
    .object = quad->object
  };

  err = graph_remove_triple (target, &triple);
  if (err == GRAPH_OK)
    {
      store->total_quads--;

      if (quad->graph != GRAPH_IRI_ID_DEFAULT && quad->graph != GRAPH_IRI_ID_INVALID)
	{
	  graph_entry_t *entry = find_entry (store, quad->graph);
	  if (entry && entry->quad_count > 0)
	    entry->quad_count--;
	}
    }

  return err;
}

graph_error_t
quad_store_add_quads (quad_store_t *store, const graph_quad_t *quads, uint64_t count, uint64_t *out_added)
{
  if (!store || !quads)
    return GRAPH_ERR_NULL_PTR;

  uint64_t added = 0;
  graph_error_t last_err = GRAPH_OK;

  for (uint64_t i = 0; i < count; i++)
    {
      graph_error_t err = quad_store_add_quad (store, &quads[i]);
      if (err == GRAPH_OK)
	{
	  added++;
	}
      else
	{
	  last_err = err;
	}
    }

  if (out_added)
    *out_added = added;
  return (added == count) ? GRAPH_OK : last_err;
}

/* Commit, then fold the new delta into the base store.  Compaction is what
 * turns neighbour lookup from a linear scan of every triple into a CSR row,
 * so it is part of committing a bulk load rather than an optional extra.
 * GRAPH_ERR_SNAPSHOT_ACTIVE is not an error here: a graph that still has
 * readers stays on the (correct, slower) delta path until they are done. */
static graph_error_t
quad_store_commit_graph (graph_t *graph)
{
  graph_error_t err = graph_commit (graph);
  if (err != GRAPH_OK)
    return err;
  err = graph_compact (graph);
  if (err == GRAPH_ERR_SNAPSHOT_ACTIVE)
    return GRAPH_OK;
  return err;
}

graph_error_t
quad_store_graph_counts (quad_store_t *store, graph_iri_id_t graph_iri, uint64_t *out_nodes, uint64_t *out_quads)
{
  graph_t *g = NULL;
  graph_error_t err;
  if (!store)
    return GRAPH_ERR_NULL_PTR;
  err = quad_store_get_graph (store, graph_iri, false, &g);
  if (err != GRAPH_OK || !g)
    {
      if (out_nodes)
	*out_nodes = 0;
      if (out_quads)
	*out_quads = 0;
      return GRAPH_ERR_NOT_FOUND;
    }
  if (out_nodes)
    *out_nodes = g->total_nodes;
  if (out_quads)
    *out_quads = g->total_triples;
  return GRAPH_OK;
}

graph_error_t
quad_store_commit (quad_store_t *store)
{
  if (!store)
    return GRAPH_ERR_NULL_PTR;

  /* Commit default graph */
  graph_error_t err = quad_store_commit_graph (store->default_graph);
  if (err != GRAPH_OK)
    return err;

  /* Commit all named graphs */
  if (store->buckets)
    {
      for (uint64_t i = 0; i < store->bucket_count; i++)
	{
	  graph_entry_t *e = store->buckets[i];
	  while (e)
	    {
	      if (e->graph)
		{
		  err = quad_store_commit_graph (e->graph);
		  if (err != GRAPH_OK)
		    return err;
		}
	      e = e->next;
	    }
	}
    }

  return GRAPH_OK;
}

/* ============================================================================
 * STATISTICS
 * ============================================================================ */

graph_error_t
quad_store_get_stats (const quad_store_t *store, quad_store_stats_t *out_stats)
{
  if (!store || !out_stats)
    return GRAPH_ERR_NULL_PTR;

  memset (out_stats, 0, sizeof (*out_stats));

  out_stats->graph_count = quad_store_graph_count (store);
  out_stats->total_quad_count = store->total_quads;

  /* Aggregate stats from all graphs */
  graph_stats_t gstats;

  if (graph_get_stats (store->default_graph, &gstats) == GRAPH_OK)
    {
      out_stats->total_node_count += gstats.node_count;
      out_stats->total_predicate_count += gstats.predicate_count;
      out_stats->memory_bytes += gstats.total_bytes;
    }

  if (store->buckets)
    {
      for (uint64_t i = 0; i < store->bucket_count; i++)
	{
	  graph_entry_t *e = store->buckets[i];
	  while (e)
	    {
	      if (e->graph && graph_get_stats (e->graph, &gstats) == GRAPH_OK)
		{
		  out_stats->total_node_count += gstats.node_count;
		  out_stats->total_predicate_count += gstats.predicate_count;
		  out_stats->memory_bytes += gstats.total_bytes;
		}
	      e = e->next;
	    }
	}
    }

  return GRAPH_OK;
}

/* ============================================================================
 * SCOPED SNAPSHOT (simplified - creates snapshot of first scoped graph)
 * ============================================================================ */

graph_error_t
quad_store_snapshot_create (quad_store_t *store, const quad_scope_t *scope, graph_snapshot_t **out_snapshot)
{
  if (!store || !out_snapshot)
    return GRAPH_ERR_NULL_PTR;

  /* If no scope or empty scope, use default graph */
  if (!scope || scope->graph_count == 0)
    {
      return graph_snapshot_create (store->default_graph, out_snapshot);
    }

  /* Use first graph in scope */
  graph_t *target;
  graph_error_t err = quad_store_get_graph (store, scope->graph_iris[0],
      false, &target);
  if (err != GRAPH_OK)
    return err;
  if (!target)
    return GRAPH_ERR_NOT_FOUND;

  return graph_snapshot_create (target, out_snapshot);
}
