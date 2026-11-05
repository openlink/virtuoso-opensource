/*
 *  graph_optim.h
 *
 *  Shared optimization infrastructure for graph algorithms
 *
 *  This header provides:
 *    1. Hash-based node lookup (O(1) instead of O(n))
 *    2. Graph caching with TTL
 *    3. Single-node fast paths
 *    4. Streaming iteration helpers
 *
 *  All algorithm files MUST use these shared utilities to ensure
 *  consistent performance characteristics across the library.
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

#ifndef GRAPH_OPTIM_H
#define GRAPH_OPTIM_H

#include "graph.h"
#include "graph_internal.h"
#include <string.h>

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================================================================
 * HASH-BASED NODE INDEX FOR O(1) LOOKUP
 * 
 * Replaces linear O(n) scans in find_node_index() with O(1) hash lookup.
 * Uses open addressing with linear probing for cache efficiency.
 * ============================================================================ */

#define GOPT_HASH_EMPTY     UINT64_MAX
#define GOPT_HASH_DELETED   (UINT64_MAX - 1)
#define GOPT_HASH_LOAD_MAX  0.7

  typedef struct gopt_node_hash
  {
    graph_node_id_t *keys;	/* Node IDs (GOPT_HASH_EMPTY = empty slot) */
    uint64_t *values;		/* Index values */
    uint64_t capacity;		/* Always power of 2 */
    uint64_t count;		/* Number of entries */
    uint64_t mask;		/* capacity - 1 for fast modulo */
    graph_allocator_t allocator;
  } gopt_node_hash_t;

/* Initialize hash table with given capacity (rounded up to power of 2) */
  GRAPH_INLINE graph_error_t gopt_hash_init (gopt_node_hash_t * h, const graph_allocator_t * allocator, uint64_t capacity)
  {
    if (!h || !allocator)
      return GRAPH_ERR_NULL_PTR;

    /* Round up to power of 2 */
    uint64_t cap = 16;
    while (cap < capacity)
       cap *= 2;

     h->allocator = *allocator;
     h->keys = (graph_node_id_t *) graph_alloc (allocator, cap * sizeof (graph_node_id_t));
     h->values = (uint64_t *) graph_alloc (allocator, cap * sizeof (uint64_t));
    if (!h->keys || !h->values)
      {
	if (h->keys)
	  graph_free (allocator, h->keys, cap * sizeof (graph_node_id_t));
	if (h->values)
	  graph_free (allocator, h->values, cap * sizeof (uint64_t));
	h->keys = NULL;
	h->values = NULL;
	return GRAPH_ERR_OUT_OF_MEMORY;
      }

    /* Mark all slots empty */
    for (uint64_t i = 0; i < cap; i++)
      {
	h->keys[i] = GOPT_HASH_EMPTY;
      }

    h->capacity = cap;
    h->count = 0;
    h->mask = cap - 1;
    return GRAPH_OK;
  }

/* Free hash table resources */
  GRAPH_INLINE void gopt_hash_destroy (gopt_node_hash_t * h)
  {
    if (h)
      {
	if (h->keys)
	  graph_free (&h->allocator, h->keys, h->capacity * sizeof (graph_node_id_t));
	if (h->values)
	  graph_free (&h->allocator, h->values, h->capacity * sizeof (uint64_t));
	h->keys = NULL;
	h->values = NULL;
	h->capacity = 0;
	h->count = 0;
      }
  }

/* Hash function for node IDs */
  GRAPH_INLINE uint64_t gopt_hash_node (graph_node_id_t node)
  {
    uint64_t x = (uint64_t) node;
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdULL;
    x ^= x >> 33;
    x *= 0xc4ceb9fe1a85ec53ULL;
    x ^= x >> 33;
    return x;
  }

/* Insert node -> index mapping. Returns false if table is full. */
  GRAPH_INLINE bool gopt_hash_insert (gopt_node_hash_t * h, graph_node_id_t node, uint64_t index)
  {
    if (!h || !h->keys)
      return false;

    /* Check load factor */
    if ((double) h->count / h->capacity > GOPT_HASH_LOAD_MAX)
      {
	/* Resize needed - for simplicity, fail (caller should pre-size) */
	return false;
      }

    uint64_t slot = gopt_hash_node (node) & h->mask;
    uint64_t start = slot;

    do
      {
	if (h->keys[slot] == GOPT_HASH_EMPTY || h->keys[slot] == GOPT_HASH_DELETED)
	  {
	    h->keys[slot] = node;
	    h->values[slot] = index;
	    h->count++;
	    return true;
	  }
	if (h->keys[slot] == node)
	  {
	    /* Already exists, update value */
	    h->values[slot] = index;
	    return true;
	  }
	slot = (slot + 1) & h->mask;
      }
    while (slot != start);

    return false;		/* Table full */
  }

/* Lookup node, returns index or UINT64_MAX if not found */
  GRAPH_INLINE uint64_t gopt_hash_lookup (const gopt_node_hash_t * h, graph_node_id_t node)
  {
    if (!h || !h->keys || h->count == 0)
      return UINT64_MAX;

    uint64_t slot = gopt_hash_node (node) & h->mask;
    uint64_t start = slot;

    do
      {
	if (h->keys[slot] == GOPT_HASH_EMPTY)
	  {
	    return UINT64_MAX;	/* Not found */
	  }
	if (h->keys[slot] == node)
	  {
	    return h->values[slot];
	  }
	slot = (slot + 1) & h->mask;
      }
    while (slot != start);

    return UINT64_MAX;
  }

/* ============================================================================
 * OPTIMIZED NODE MAP BUILDING
 * 
 * Builds node map with O(n) complexity instead of O(n²) by using hash set
 * for duplicate detection during delta traversal.
 * ============================================================================ */

  typedef struct gopt_node_map
  {
    graph_node_id_t *nodes;	/* Array of node IDs */
    uint64_t count;		/* Number of nodes */
    uint64_t capacity;		/* Array capacity */
    gopt_node_hash_t hash;	/* Hash for O(1) lookup */
  } gopt_node_map_t;

/* Initialize node map with capacity */
  GRAPH_INLINE graph_error_t gopt_node_map_init (gopt_node_map_t * m, const graph_allocator_t * allocator, uint64_t capacity)
  {
    if (!m || !allocator)
      return GRAPH_ERR_NULL_PTR;

    m->nodes = (graph_node_id_t *) graph_alloc (allocator, capacity * sizeof (graph_node_id_t));
    if (!m->nodes)
      return GRAPH_ERR_OUT_OF_MEMORY;

    graph_error_t err = gopt_hash_init (&m->hash, allocator, capacity * 2);	/* 2x for load factor */
    if (err != GRAPH_OK)
      {
	graph_free (allocator, m->nodes, capacity * sizeof (graph_node_id_t));
	m->nodes = NULL;
	return err;
      }

    m->count = 0;
    m->capacity = capacity;
    return GRAPH_OK;
  }

/* Free node map resources */
  GRAPH_INLINE void gopt_node_map_destroy (gopt_node_map_t * m)
  {
    if (m)
      {
	if (m->nodes)
	  graph_free (&m->hash.allocator, m->nodes, m->capacity * sizeof (graph_node_id_t));
	gopt_hash_destroy (&m->hash);
	m->nodes = NULL;
	m->count = 0;
      }
  }

/* Add node if not already present. Returns true if added. */
  GRAPH_INLINE bool gopt_node_map_add (gopt_node_map_t * m, graph_node_id_t node)
  {
    if (!m || m->count >= m->capacity)
      return false;

    /* Check if already present using hash (O(1)) */
    if (gopt_hash_lookup (&m->hash, node) != UINT64_MAX)
      {
	return false;		/* Already exists */
      }

    /* Add to array and hash */
    uint64_t idx = m->count;
    m->nodes[idx] = node;
    gopt_hash_insert (&m->hash, node, idx);
    m->count++;
    return true;
  }

/* Lookup node index in O(1) */
  GRAPH_INLINE uint64_t gopt_node_map_lookup (const gopt_node_map_t * m, graph_node_id_t node)
  {
    if (!m)
      return UINT64_MAX;
    return gopt_hash_lookup (&m->hash, node);
  }

/* Build node map from snapshot with O(n) complexity */
  GRAPH_INLINE graph_error_t gopt_build_node_map (const graph_snapshot_t * snap, gopt_node_map_t * m)
  {
    if (!snap || !m)
      return GRAPH_ERR_NULL_PTR;

    const graph_t *graph = snap->graph;
    const graph_base_store_t *base = graph->base;

    /* Add all nodes from base store */
    for (uint64_t i = 0; i < base->node_count && m->count < m->capacity; i++)
      {
	gopt_node_map_add (m, base->node_ids[i]);
      }

    /* Add nodes from deltas (new nodes only) */
    graph_delta_t *delta = snap->delta_head;
    while (delta && m->count < m->capacity)
      {
	for (uint32_t i = 0; i < delta->addition_count && m->count < m->capacity; i++)
	  {
	    gopt_node_map_add (m, delta->additions[i].subject);
	    gopt_node_map_add (m, delta->additions[i].object);
	  }
	delta = delta->prev;
      }

    return GRAPH_OK;
  }

/* The neighbour iterator that used to be here is gone.
 *
 * It was a fifth copy of the walk -- graph_algo.c, the three other
 * algorithm files and this one each had their own -- and it was the copy
 * nothing called: gopt_neighbor_init(), gopt_neighbor_next() and
 * gopt_count_neighbors() had no caller in the tree, which is why the
 * unification that removed the other three missed it.  Only the node map
 * and hash helpers in this file are used.
 *
 * The one copy is graph_neighbor.h.  This one also read the base store's
 * graph_edge_t records per edge, which is exactly what a snapshot whose
 * edges all carry one predicate no longer has.
 *
 * gopt_single_node_degree() went with it: its only two statements were
 * calls to the iterator's counter, it had no caller either, and the
 * degree BIFs read the CSR row lengths directly through
 * graph_base_node_degree() rather than counting neighbours one at a time.
 * ============================================================================ */

/* ============================================================================
 * WORKSPACE WITH EMBEDDED HASH
 * 
 * Extended workspace header that includes the node hash for O(1) lookups.
 * Algorithms should use this instead of linear scans.
 * ============================================================================ */

  typedef struct gopt_workspace_header
  {
    graph_workspace_header_t base;
    gopt_node_hash_t node_hash;	/* O(1) node -> index lookup */
    uint64_t node_count;	/* Actual nodes in map */
  } gopt_workspace_header_t;

/* Calculate workspace size including hash table */
  GRAPH_INLINE size_t gopt_workspace_overhead (uint64_t node_count)
  {
    /* Hash table keys + values, rounded to cache line */
    uint64_t hash_cap = 16;
    while (hash_cap < node_count * 2)
      hash_cap *= 2;

    return GRAPH_ALIGN_UP (sizeof (gopt_workspace_header_t), GRAPH_CACHE_LINE_SIZE) +
	GRAPH_ALIGN_UP (hash_cap * sizeof (graph_node_id_t), GRAPH_CACHE_LINE_SIZE) +
	GRAPH_ALIGN_UP (hash_cap * sizeof (uint64_t), GRAPH_CACHE_LINE_SIZE);
  }

#ifdef __cplusplus
}
#endif

#endif /* GRAPH_OPTIM_H */
