/*
 *  graph_snapshot.c
 *
 *  Snapshot management for MVCC graph access
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

#include "graph_internal.h"
#include <stdlib.h>
#include <string.h>

#define GRAPH_NODE_HASH_EMPTY UINT64_MAX

static bool
graph_snapshot_node_insert (graph_snapshot_t *snapshot, graph_node_id_t node_id)
{
  uint64_t mask = snapshot->node_hash_capacity - 1;
  uint64_t slot = graph_hash_u64 (node_id) & mask;
  while (snapshot->node_hash_values[slot] != GRAPH_NODE_HASH_EMPTY)
    {
      if (snapshot->node_hash_keys[slot] == node_id)
	return true;
      slot = (slot + 1) & mask;
    }
  if (snapshot->node_map_count >= snapshot->node_count)
    return false;
  snapshot->node_hash_keys[slot] = node_id;
  snapshot->node_hash_values[slot] = snapshot->node_map_count;
  snapshot->node_map[snapshot->node_map_count++] = node_id;
  return true;
}

/* Point an existing hash entry at a new node_map index (after sorting). */
static void
graph_snapshot_node_reindex (graph_snapshot_t *snapshot, graph_node_id_t node_id, uint64_t index)
{
  uint64_t mask = snapshot->node_hash_capacity - 1;
  uint64_t slot = graph_hash_u64 (node_id) & mask;
  while (snapshot->node_hash_values[slot] != GRAPH_NODE_HASH_EMPTY)
    {
      if (snapshot->node_hash_keys[slot] == node_id)
	{
	  snapshot->node_hash_values[slot] = index;
	  return;
	}
      slot = (slot + 1) & mask;
    }
}

static int
graph_snapshot_node_cmp (const void *pa, const void *pb)
{
  graph_node_id_t a = *(const graph_node_id_t *) pa;
  graph_node_id_t b = *(const graph_node_id_t *) pb;
  return (a < b) ? -1 : (a > b) ? 1 : 0;
}

graph_error_t
graph_snapshot_build_node_map (graph_snapshot_t *snapshot)
{
  const graph_allocator_t *a;
  graph_base_store_t *base;
  graph_delta_t *delta;
  uint64_t hash_capacity = 16;
  if (!snapshot || !snapshot->graph)
    return GRAPH_ERR_NULL_PTR;
  a = &snapshot->graph->allocator;
  base = snapshot->graph->base;

  /* No hash table at all when the base store's ids are a contiguous run
   * and there is no delta chain.  Then node_map is base->node_ids
   * element for element -- both are the same sorted unique set -- and an
   * index is `id - dense_base`, which graph_snapshot_find_node() below
   * computes instead of probing.
   *
   * The table is 16 bytes per slot at twice the node count, so about
   * 16 MB at 633,432 nodes: allocated, initialised, filled one insert at
   * a time, and then probed once per lookup, all to answer a question
   * subtraction answers.  Skipping it also skips the qsort of node_map
   * and the reindex pass, because base->node_ids arrives sorted.
   *
   * The delta chain is the reason this is conditional and not automatic.
   * A delta can name nodes the base store does not hold, node_map is
   * then the sorted union of the two, and an index is no longer any
   * arithmetic on an id -- so a snapshot with a chain keeps the table. */
  if (base && base->dense_ids && NULL == snapshot->delta_head)
    {
      if (snapshot->node_count)
	{
	  uint64_t n = base->node_count < snapshot->node_count ? base->node_count : snapshot->node_count;
	  snapshot->node_map = graph_alloc (a, snapshot->node_count * sizeof (graph_node_id_t));
	  if (!snapshot->node_map)
	    return GRAPH_ERR_OUT_OF_MEMORY;
	  memcpy (snapshot->node_map, base->node_ids, n * sizeof (graph_node_id_t));
	  snapshot->node_map_count = n;
	}
      return GRAPH_OK;
    }

  while (hash_capacity < snapshot->node_count * 2 + 1)
    hash_capacity <<= 1;
  if (snapshot->node_count)
    snapshot->node_map = graph_alloc (a, snapshot->node_count * sizeof (graph_node_id_t));
  snapshot->node_hash_keys = graph_alloc (a, hash_capacity * sizeof (graph_node_id_t));
  snapshot->node_hash_values = graph_alloc (a, hash_capacity * sizeof (uint64_t));
  if ((snapshot->node_count && !snapshot->node_map) || !snapshot->node_hash_keys || !snapshot->node_hash_values)
    return GRAPH_ERR_OUT_OF_MEMORY;
  snapshot->node_hash_capacity = hash_capacity;
  for (uint64_t i = 0; i < hash_capacity; i++)
    snapshot->node_hash_values[i] = GRAPH_NODE_HASH_EMPTY;
  for (uint64_t i = 0; i < base->node_count; i++)
    if (!graph_snapshot_node_insert (snapshot, base->node_ids[i]))
      return GRAPH_ERR_CORRUPTED;
  delta = snapshot->delta_head;
  while (delta)
    {
      for (uint32_t i = 0; i < delta->addition_count; i++)
	{
	  if (!graph_snapshot_node_insert (snapshot, delta->additions[i].subject) ||
	      !graph_snapshot_node_insert (snapshot, delta->additions[i].object))
	    return GRAPH_ERR_CORRUPTED;
	}
      delta = delta->prev;
    }
  /*
   * Canonicalize node indices: sort by node id so index assignment depends
   * only on the node set, not on how triples were grouped into base store
   * vs deltas.  Node-indexed results (community ids, score payloads) are
   * then reproducible across reloads and compactions.
   */
  if (snapshot->node_map_count > 1)
    qsort (snapshot->node_map, snapshot->node_map_count, sizeof (graph_node_id_t), graph_snapshot_node_cmp);
  for (uint64_t i = 0; i < snapshot->node_map_count; i++)
    graph_snapshot_node_reindex (snapshot, snapshot->node_map[i], i);
  return GRAPH_OK;
}

size_t
graph_snapshot_memory_bytes (const graph_snapshot_t *snapshot)
{
  const graph_base_store_t *base;
  const graph_delta_t *d;
  size_t bytes = sizeof (graph_snapshot_t);
  if (!snapshot)
    return 0;
  bytes += snapshot->node_map_count * sizeof (graph_node_id_t);
  bytes += snapshot->node_hash_capacity * (sizeof (graph_node_id_t) + sizeof (uint64_t));
  if (!snapshot->graph)
    return bytes;
  bytes += sizeof (graph_t);
  base = snapshot->graph->base;
  if (base)
    {
      bytes += base->node_capacity * sizeof (graph_node_id_t);
      bytes += (base->node_capacity + 1) * sizeof (uint64_t);
      bytes += base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix);
      if (base->edges)
	bytes += base->edge_capacity * sizeof (graph_edge_t);
      if (base->has_inverse)
	{
	  bytes += (base->node_capacity + 1) * sizeof (uint64_t) + base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix);
	  if (base->inv_edges)
	    bytes += base->edge_capacity * sizeof (graph_inverse_edge_t);
	}
    }
  for (d = snapshot->delta_head; d; d = d->prev)
    bytes += sizeof (graph_delta_t) +
	(size_t) d->addition_capacity * sizeof (graph_triple_t) + (size_t) d->deletion_capacity * sizeof (graph_triple_t);
  bytes += snapshot->graph->node_index.slot_count * sizeof (graph_node_slot_t);
  return bytes;
}

uint64_t
graph_snapshot_base_build_id (const graph_snapshot_t *snapshot)
{
  if (!snapshot || !snapshot->graph || !snapshot->graph->base)
    return 0;
  return snapshot->graph->base->build_id;
}

uint64_t
graph_snapshot_find_node (const graph_snapshot_t *snapshot, graph_node_id_t node_id)
{
  uint64_t mask, slot;
  if (!snapshot)
    return UINT64_MAX;
  /* No table means the map is the base store's own node_ids and the
   * index is arithmetic -- see graph_snapshot_build_node_map().  The
   * order matters: a snapshot that has a table must use it, because a
   * delta chain can hold nodes the base store's arithmetic cannot
   * reach. */
  if (!snapshot->node_hash_values || !snapshot->node_hash_capacity)
    {
      if (!snapshot->graph || !snapshot->graph->base)
	return UINT64_MAX;
      return graph_base_node_index (snapshot->graph->base, node_id);
    }
  mask = snapshot->node_hash_capacity - 1;
  slot = graph_hash_u64 (node_id) & mask;
  while (snapshot->node_hash_values[slot] != GRAPH_NODE_HASH_EMPTY)
    {
      if (snapshot->node_hash_keys[slot] == node_id)
	return snapshot->node_hash_values[slot];
      slot = (slot + 1) & mask;
    }
  return UINT64_MAX;
}

uint64_t
graph_snapshot_copy_node_map (const graph_snapshot_t *snapshot, graph_node_id_t *out_nodes, uint64_t capacity)
{
  uint64_t count;
  if (!snapshot || !out_nodes)
    return 0;
  count = snapshot->node_map_count < capacity ? snapshot->node_map_count : capacity;
  memcpy (out_nodes, snapshot->node_map, count * sizeof (graph_node_id_t));
  return count;
}

#include "Dk.h"
/* A dk_mutex_t has no static initializer; the host calls this at startup,
 * before any snapshot exists. */
static dk_mutex_t *graph_snapshot_list_mutex;
void
graph_snapshot_lib_init (void)
{
  if (!graph_snapshot_list_mutex)
    graph_snapshot_list_mutex = mutex_allocate ();
}

#define GRAPH_SNAPSHOT_LIST_LOCK() mutex_enter(graph_snapshot_list_mutex)
#define GRAPH_SNAPSHOT_LIST_UNLOCK() mutex_leave(graph_snapshot_list_mutex)

/* ============================================================================
 * SNAPSHOT CREATION
 * ============================================================================ */

graph_error_t
graph_snapshot_create (graph_t *graph, graph_snapshot_t **out_snapshot)
{
  if (!graph || !out_snapshot)
    return GRAPH_ERR_NULL_PTR;
  if (!graph->initialized)
    return GRAPH_ERR_NOT_INITIALIZED;

  const graph_allocator_t *a = &graph->allocator;
  graph_error_t map_err;

  graph_snapshot_t *snap = graph_alloc (a, sizeof (graph_snapshot_t));
  if (!snap)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (snap, 0, sizeof (*snap));

  snap->id = graph->next_snapshot_id++;
  snap->graph = graph;
  snap->state = GRAPH_SNAP_ACTIVE;

  snap->delta_head = graph->delta_head;
  if (snap->delta_head)
    {
      graph_delta_ref_inc (snap->delta_head);
    }

  snap->node_count = graph->total_nodes;
  snap->triple_count = graph->total_triples;

  map_err = graph_snapshot_build_node_map (snap);
  if (map_err != GRAPH_OK)
    {
      if (snap->node_map)
	graph_free (a, snap->node_map, snap->node_count * sizeof (graph_node_id_t));
      if (snap->node_hash_keys)
	graph_free (a, snap->node_hash_keys, snap->node_hash_capacity * sizeof (graph_node_id_t));
      if (snap->node_hash_values)
	graph_free (a, snap->node_hash_values, snap->node_hash_capacity * sizeof (uint64_t));
      if (snap->delta_head)
	graph_delta_ref_dec (snap->delta_head, a);
      graph_free (a, snap, sizeof (*snap));
      return map_err;
    }

  GRAPH_ATOMIC_STORE (&snap->ref_count, 1);

  graph_snapshot_link (graph, snap);

  *out_snapshot = snap;
  return GRAPH_OK;
}

/* ============================================================================
 * SNAPSHOT RELEASE
 * ============================================================================ */

graph_error_t
graph_snapshot_retain (graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return GRAPH_ERR_NULL_PTR;
  if (snapshot->state != GRAPH_SNAP_ACTIVE)
    return GRAPH_ERR_STALE_SNAPSHOT;
  GRAPH_ATOMIC_FETCH_ADD (&snapshot->ref_count, 1);
  return GRAPH_OK;
}

graph_error_t
graph_snapshot_release (graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return GRAPH_ERR_NULL_PTR;

  if (snapshot->state != GRAPH_SNAP_ACTIVE)
    {
      return GRAPH_ERR_STALE_SNAPSHOT;
    }

  int32_t prev_count;
  prev_count = GRAPH_ATOMIC_FETCH_SUB (&snapshot->ref_count, 1);

  if (prev_count == 1)
    {
      graph_t *graph = snapshot->graph;
      const graph_allocator_t *a = &graph->allocator;

      if (snapshot->delta_head)
	{
	  graph_delta_ref_dec (snapshot->delta_head, a);
	}
      if (snapshot->node_map)
	graph_free (a, snapshot->node_map, snapshot->node_count * sizeof (graph_node_id_t));
      if (snapshot->node_hash_keys)
	graph_free (a, snapshot->node_hash_keys, snapshot->node_hash_capacity * sizeof (graph_node_id_t));
      if (snapshot->node_hash_values)
	graph_free (a, snapshot->node_hash_values, snapshot->node_hash_capacity * sizeof (uint64_t));

      graph_snapshot_unlink (graph, snapshot);

      snapshot->state = GRAPH_SNAP_RELEASED;
      graph_free (a, snapshot, sizeof (graph_snapshot_t));
    }

  return GRAPH_OK;
}

/* ============================================================================
 * SNAPSHOT LINKING
 * ============================================================================ */

void
graph_snapshot_link (graph_t *graph, graph_snapshot_t *snap)
{
  if (!graph || !snap)
    return;
  GRAPH_SNAPSHOT_LIST_LOCK ();

  snap->next = graph->snapshot_head;
  snap->prev = NULL;

  if (graph->snapshot_head)
    {
      graph->snapshot_head->prev = snap;
    }
  graph->snapshot_head = snap;
  graph->snapshot_count++;
  GRAPH_SNAPSHOT_LIST_UNLOCK ();
}

void
graph_snapshot_unlink (graph_t *graph, graph_snapshot_t *snap)
{
  if (!graph || !snap)
    return;
  GRAPH_SNAPSHOT_LIST_LOCK ();

  if (snap->prev)
    {
      snap->prev->next = snap->next;
    }
  else
    {
      graph->snapshot_head = snap->next;
    }

  if (snap->next)
    {
      snap->next->prev = snap->prev;
    }

  snap->next = NULL;
  snap->prev = NULL;

  if (graph->snapshot_count > 0)
    {
      graph->snapshot_count--;
    }
  GRAPH_SNAPSHOT_LIST_UNLOCK ();
}

/* ============================================================================
 * SNAPSHOT ACCESSORS
 * ============================================================================ */

graph_snap_id_t
graph_snapshot_get_id (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return GRAPH_SNAP_ID_INVALID;
  return snapshot->id;
}

uint64_t
graph_snapshot_node_count (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;
  return snapshot->node_count;
}

uint64_t
graph_snapshot_triple_count (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return 0;
  return snapshot->triple_count;
}

graph_snap_state_t
graph_snapshot_get_state (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return GRAPH_SNAP_INVALID;
  return snapshot->state;
}

const graph_t *
graph_snapshot_get_graph (const graph_snapshot_t *snapshot)
{
  if (!snapshot)
    return NULL;
  return snapshot->graph;
}
